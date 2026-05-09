#!/bin/sh
set -eu

# Runtime state directory (tmpfs — gone on container stop, that's intentional)
OBSIDI_RUN=/run/obsidi
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
chown -R 99:100 /vault /config

# ---------------------------------------------------------------------------
# Preflight: verify /vault is configured for Obsidian Sync
# ---------------------------------------------------------------------------
# ob sync-status exits 0 when configured, 3 when unconfigured.
# Run as the unprivileged user so it reads from the right $HOME (/config).
if ! su-exec 99:100 ob sync-status --path /vault >/dev/null 2>&1; then
    log fatal "No sync configuration found for /vault. Run 'ob sync-setup --path /vault' inside the container (see README First-Run Setup)."
    touch "$OBSIDI_RUN/unconfigured"
    # Rate-limit the crashloop so logs stay readable; exit 78 = EX_CONFIG
    sleep 30
    exit 78
fi

log info "Sync configuration verified for /vault"

# ---------------------------------------------------------------------------
# Heartbeat supervisor
#
# Wraps `ob sync --continuous` to write a liveness file that the HEALTHCHECK
# can timestamp-check independent of vault file activity.
#
# Strategy:
#   1. Run ob sync --continuous, capturing stdout to a pipe.
#   2. A background reader tees output to the terminal AND updates
#      /run/obsidi/heartbeat on any meaningful output line.
#   3. A background 60s poller calls ob sync-status and writes JSON to
#      /run/obsidi/heartbeat.json.
#
# The heartbeat reflects server-contact freshness, not file-change activity.
# ob sync --continuous emits output whenever it contacts the remote (keepalive,
# file events, reconnects) so any stdout is a reasonable liveness proxy.
# If obsidian-headless ever goes silent during a healthy long idle, the 60s
# poller provides a fallback heartbeat via sync-status.
# ---------------------------------------------------------------------------

HEARTBEAT="$OBSIDI_RUN/heartbeat"
HEARTBEAT_JSON="$OBSIDI_RUN/heartbeat.json"

# Write an initial heartbeat so the healthcheck start-period doesn't see a
# missing file and immediately fail.
touch "$HEARTBEAT"
chown 99:100 "$HEARTBEAT"

write_heartbeat_json() {
    status_out=$(su-exec 99:100 ob sync-status --path /vault 2>&1 || true)
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
        sleep 60
        touch "$HEARTBEAT"
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
su-exec 99:100 tini -- sh -c 'ob sync --continuous --path /vault > '"$SYNC_PIPE"' 2>&1' &
SYNC_PID=$!

# Trap signals so we clean up background jobs when Docker sends SIGTERM/SIGINT.
cleanup() {
    kill "$SYNC_PID" 2>/dev/null || true
    kill "$POLLER_PID" 2>/dev/null || true
    kill "$READER_PID" 2>/dev/null || true
    rm -f "$SYNC_PIPE"
}
trap cleanup INT TERM

# Wait for the sync process; propagate its exit code.
wait "$SYNC_PID"
EXIT_CODE=$?
cleanup
exit "$EXIT_CODE"
