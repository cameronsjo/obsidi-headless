#!/bin/sh
# Runs entrypoint.sh's supervisor against a fake `ob` (plus pass-through fakes
# for su-exec, tini, chown) in a temp dir. No root, Docker, or network needed.
#   sh tests/stall-watchdog.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
FAILS=0
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/bin" "$TMP/vault" "$TMP/config"
cat > "$TMP/bin/su-exec" <<'F'
#!/bin/sh
shift
exec "$@"
F
cat > "$TMP/bin/tini" <<'F'
#!/bin/sh
shift
exec "$@"
F
printf '#!/bin/sh\nexit 0\n' > "$TMP/bin/chown"
cat > "$TMP/bin/ob" <<'F'
#!/bin/sh
case "$1" in
    --version) echo fake; exit 0 ;;
    sync-status) echo "Vault: fake"; exit 0 ;;
esac
# sync --continuous
echo "Connecting..."
case "$FAKE_OB_MODE" in
    chatty) while :; do sleep 1; echo "tick"; done ;;
    hang)   exec sleep 300 ;;
esac
F
chmod +x "$TMP/bin/"*

fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }
pass() { echo "PASS: $*"; }

# start_case <name> <mode> [stall-seconds]; sets PID, LOG, RUN
start_case() {
    RUN="$TMP/$1.run"; LOG="$TMP/$1.log"
    FAKE_OB_MODE="$2" OBSIDI_RUN="$RUN" OBSIDI_VAULT="$TMP/vault" \
        OBSIDI_CONFIG="$TMP/config" OBSIDI_STALL_SECONDS="$3" \
        OBSIDI_WATCHDOG_INTERVAL=1 OBSIDI_POLL_INTERVAL=1 PATH="$TMP/bin:$PATH" \
        sh "$ROOT/entrypoint.sh" > "$LOG" 2>&1 &
    PID=$!
}

# Case (a): output every second keeps the supervisor up past the stall limit.
start_case chatty chatty 4
sleep 10
if kill -0 "$PID" 2>/dev/null; then pass "chatty ob survives past the 4s stall limit"
else fail "chatty ob was killed"; fi
kill -TERM "$PID" 2>/dev/null; wait "$PID" 2>/dev/null
if grep -q 'no output from ob sync' "$LOG"; then fail "watchdog fired on chatty ob"; fi

# Case (b): one line then silence exits non-zero within limit + slack.
LIMIT=4
start_case hang hang "$LIMIT"
i=0
while kill -0 "$PID" 2>/dev/null && [ "$i" -lt $((LIMIT + 20)) ]; do sleep 1; i=$((i + 1)); done
if kill -0 "$PID" 2>/dev/null; then
    fail "hung ob not stopped within $((LIMIT + 20))s"
    kill -KILL "$PID" 2>/dev/null
else
    wait "$PID"; rc=$?
    if [ "$rc" -ne 0 ]; then pass "hung ob stopped the script (rc=$rc) after ${i}s"
    else fail "script exited 0 on a stall"; fi
    if grep -q 'no output from ob sync for [0-9]*s (limit 4s); exiting so the container restarts' "$LOG"
    then pass "stall log line present"; else fail "stall log line missing"; fi
fi

# Case (c): invalid OBSIDI_STALL_SECONDS falls back to 900 with a log line.
start_case badenv chatty abc
sleep 3
kill -TERM "$PID" 2>/dev/null; wait "$PID" 2>/dev/null
if grep -q "OBSIDI_STALL_SECONDS='abc' is not a positive integer; using 900" "$LOG"
then pass "invalid stall value falls back to 900"; else fail "no fallback log line"; fi

[ "$FAILS" -eq 0 ] && echo "ALL PASS" || echo "$FAILS FAILED"
[ "$FAILS" -eq 0 ]
