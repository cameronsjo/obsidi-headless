#!/bin/sh
set -eu

# Runtime state directory (tmpfs — gone on container stop, that's intentional)
# Paths are overridable so tests/stall-watchdog.sh can run the supervisor
# against a fake `ob` in a temp dir; production uses the defaults.
OBSIDI_RUN="${OBSIDI_RUN:-/run/obsidi}"
OBSIDI_VAULT="${OBSIDI_VAULT:-/vault}"
OBSIDI_CONFIG="${OBSIDI_CONFIG:-/config}"
mkdir -p "$OBSIDI_RUN"
chown 99:100 "$OBSIDI_RUN"

log() {
    # Structured JSON log to stdout so Docker log drivers capture it cleanly
    level="$1"; shift
    printf '{"level":"%s","ts":"%s","msg":"%s"}\n' \
        "$level" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*"
}

log info "Starting obsidi-headless sync container"
log info "obsidian-headless version: $(su-exec 99:100 ob --version 2>/dev/null || echo 'unknown')"

# ---------------------------------------------------------------------------
# Preflight: fix volume permissions (entrypoint runs as root)
# ---------------------------------------------------------------------------
chown -R 99:100 "$OBSIDI_VAULT" "$OBSIDI_CONFIG"

# ---------------------------------------------------------------------------
# Preflight: verify /vault is configured for Obsidian Sync
# ---------------------------------------------------------------------------
# ob sync-status exits 0 when configured, 3 when unconfigured.
# Run as the unprivileged user so it reads from the right $HOME (/config).
if ! su-exec 99:100 ob sync-status --path "$OBSIDI_VAULT" >/dev/null 2>&1; then
    log fatal "No sync configuration found for $OBSIDI_VAULT. Run 'ob sync-setup --path /vault' inside the container (see README First-Run Setup)."
    touch "$OBSIDI_RUN/unconfigured"
    # Rate-limit the crashloop so logs stay readable; exit 78 = EX_CONFIG
    sleep 30
    exit 78
fi

log info "Sync configuration verified for $OBSIDI_VAULT"

# ---------------------------------------------------------------------------
# Heartbeat supervisor
#
# Wraps `ob sync --continuous` to write a liveness file that the HEALTHCHECK
# can timestamp-check independent of vault file activity.
#
# Strategy:
#   1. Run ob sync --continuous, capturing stdout to a pipe.
#   2. A background reader tees output to the terminal AND updates
#      /run/obsidi/heartbeat on every output line. Nothing else touches it.
#   3. A background 60s poller calls ob sync-status and writes JSON to
#      /run/obsidi/heartbeat.json. It does NOT touch the heartbeat file: a
#      poller that did would mask a hung sync (ob sync-status prints only
#      static config, never connection state).
#   4. A stall watchdog checks the heartbeat age every 60s. Past
#      OBSIDI_STALL_SECONDS (default 900) it kills the sync process, the
#      script exits non-zero, and the restart policy brings the container back.
#
# A healthy ob sync --continuous prints a line at least every 30s, so silence
# means a stall. The HEALTHCHECK (300s) reports unhealthy in the window before
# the watchdog fires.
# ---------------------------------------------------------------------------

HEARTBEAT="$OBSIDI_RUN/heartbeat"
HEARTBEAT_JSON="$OBSIDI_RUN/heartbeat.json"
STALLED="$OBSIDI_RUN/stalled"

# Positive-integer env knob with a logged fallback.
positive_int() {
    name="$1"; value="$2"; default="$3"
    case "$value" in
        ''|*[!0-9]*|0*)
            log warn "$name='$value' is not a positive integer; using $default" >&2
            echo "$default" ;;
        *) echo "$value" ;;
    esac
}
STALL_SECONDS=$(positive_int OBSIDI_STALL_SECONDS "${OBSIDI_STALL_SECONDS:-900}" 900)
WATCHDOG_INTERVAL=$(positive_int OBSIDI_WATCHDOG_INTERVAL "${OBSIDI_WATCHDOG_INTERVAL:-60}" 60)
POLL_INTERVAL=$(positive_int OBSIDI_POLL_INTERVAL "${OBSIDI_POLL_INTERVAL:-60}" 60)

# Write an initial heartbeat so the healthcheck start-period doesn't see a
# missing file and immediately fail.
touch "$HEARTBEAT"
chown 99:100 "$HEARTBEAT"

write_heartbeat_json() {
    status_out=$(su-exec 99:100 ob sync-status --path "$OBSIDI_VAULT" 2>&1 || true)
    # Extract "Vault:" line for a display name; fall back to path if absent
    remote_vault=$(printf '%s' "$status_out" | grep -m1 'Vault:' | sed 's/.*Vault: //' | tr -d '[:space:]' || echo 'unknown')
    printf '{"ts":"%s","state":"syncing","remote_vault":"%s"}\n' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$remote_vault" \
        > "$HEARTBEAT_JSON"
    chown 99:100 "$HEARTBEAT_JSON"
}

write_heartbeat_json

# Poller: runs ob sync-status every 60s to confirm the remote is reachable.
# Runs as root so it can write to /run/obsidi; su-exec is used for the ob call.
heartbeat_poller() {
    while true; do
        sleep "$POLL_INTERVAL"
        write_heartbeat_json
    done
}

heartbeat_poller &
POLLER_PID=$!

# Run ob sync --continuous as the unprivileged user via su-exec + tini.
# stdout is piped through a reader that updates the heartbeat file on any line.
# We use a named pipe so exec semantics are preserved for signal handling.
SYNC_PIPE="$OBSIDI_RUN/sync.pipe"
mkfifo "$SYNC_PIPE"
chown 99:100 "$SYNC_PIPE"

# Reader: stamp heartbeat on every output line from ob sync.
# `stdbuf -oL` is not available on Alpine/busybox; we rely on the fact that
# ob sync --continuous writes line-buffered output to a tty-ish pipe.
(
    while IFS= read -r line; do
        printf '%s\n' "$line"
        touch "$HEARTBEAT"
    done < "$SYNC_PIPE"
) &
READER_PID=$!

# Run ob sync --continuous, redirecting stdout into the named pipe.
# We do NOT exec here so the shell stays alive to run the cleanup trap.
# tini is launched as a child; Docker sends SIGTERM to PID 1 (this shell),
# which the trap converts into a clean shutdown of all children.
# shellcheck disable=SC2016  # $1 must expand in the inner shell, not here
su-exec 99:100 tini -- sh -c 'exec ob sync --continuous --path "$1" > '"$SYNC_PIPE"' 2>&1' sh "$OBSIDI_VAULT" &
SYNC_PID=$!

# Stall watchdog: kill the sync process when the reader has not stamped the
# heartbeat for STALL_SECONDS. The initial touch above is the grace period.
file_mtime() {
    stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0
}
stall_watchdog() {
    while true; do
        sleep "$WATCHDOG_INTERVAL"
        age=$(( $(date +%s) - $(file_mtime "$HEARTBEAT") ))
        if [ "$age" -gt "$STALL_SECONDS" ]; then
            log fatal "obsidi: no output from ob sync for ${age}s (limit ${STALL_SECONDS}s); exiting so the container restarts"
            touch "$STALLED"
            kill "$SYNC_PID" 2>/dev/null || true
            return 0
        fi
    done
}
stall_watchdog &
WATCHDOG_PID=$!

# Trap signals so we clean up background jobs when Docker sends SIGTERM/SIGINT.
cleanup() {
    kill "$SYNC_PID" 2>/dev/null || true
    kill "$POLLER_PID" 2>/dev/null || true
    kill "$WATCHDOG_PID" 2>/dev/null || true
    kill "$READER_PID" 2>/dev/null || true
    rm -f "$SYNC_PIPE"
}
trap cleanup INT TERM

# Wait for the sync process; propagate its exit code.
wait "$SYNC_PID"
EXIT_CODE=$?
cleanup
# A watchdog kill must exit non-zero whatever the killed process reported.
if [ -f "$STALLED" ] && [ "$EXIT_CODE" -eq 0 ]; then
    EXIT_CODE=1
fi
exit "$EXIT_CODE"
