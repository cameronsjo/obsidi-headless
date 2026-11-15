#!/bin/sh
# Real-container check of the stall watchdog: real su-exec + tini, fake `ob`
# first on PATH, small limits. Needs a working docker daemon.
#   sh tests/docker-stall.sh
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
BASE=obh-stall-base:test
IMG=obh-stall-fake:test
NAME=obh-stall-test
FAILS=0
cleanup() { docker rm -f "$NAME" >/dev/null 2>&1; rm -rf "$TMP"; }
trap cleanup EXIT

fail() { echo "FAIL: $*"; FAILS=$((FAILS + 1)); }
pass() { echo "PASS: $*"; }

docker build -q -t "$BASE" "$ROOT" >/dev/null || { echo "FAIL: image build"; exit 1; }
cp "$ROOT/tests/fake-ob.sh" "$TMP/ob"
chmod 755 "$TMP/ob"
printf 'FROM %s\nCOPY ob /fakebin/ob\n' "$BASE" > "$TMP/Dockerfile"
docker build -q -t "$IMG" "$TMP" >/dev/null || { echo "FAIL: fake image build"; exit 1; }

STALL=5; GRACE=1; KILL=3
docker rm -f "$NAME" >/dev/null 2>&1
docker run -d --name "$NAME" \
    -e FAKE_OB_MODE=hang -e OBSIDI_STALL_SECONDS=$STALL -e OBSIDI_STARTUP_GRACE=$GRACE \
    -e OBSIDI_WATCHDOG_INTERVAL=1 -e OBSIDI_KILL_GRACE=$KILL -e OBSIDI_POLL_INTERVAL=1 \
    -e PATH=/fakebin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$IMG" >/dev/null || { echo "FAIL: docker run"; exit 1; }

LIMIT=$((STALL + GRACE + KILL + 20))
i=0
while [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = true ] && [ "$i" -lt "$LIMIT" ]; do
    sleep 1; i=$((i + 1))
done
RC=$(docker inspect -f '{{.State.ExitCode}}' "$NAME")
if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = true ]; then
    fail "container still running after ${LIMIT}s"
elif [ "$RC" -ne 0 ]; then pass "container exited non-zero (rc=$RC) after ${i}s"
else fail "container exited 0 on a stall"; fi
if docker logs "$NAME" 2>&1 | grep -q 'no output from ob sync'; then pass "stall log line present"
else fail "stall log line missing"; fi

# Restart: /run/obsidi persists in the stopped container, like a non-tmpfs run dir.
docker start "$NAME" >/dev/null
sleep 3
if [ "$(docker inspect -f '{{.State.Running}}' "$NAME")" = true ]; then pass "second docker start comes up"
else fail "second docker start exited (rc=$(docker inspect -f '{{.State.ExitCode}}' "$NAME"))"; fi

# Ownership preflight and the synced stamp, in the real image as root:
# an entry already owned by 99:100 keeps its ctime (chown(2) would bump it),
# a root-owned entry is fixed, and the stamp appears world-readable for a
# read-only monitor running as another uid.
NAME2=obh-stamp-test
docker rm -f "$NAME2" >/dev/null 2>&1
# shellcheck disable=SC2016  # expanded inside the container
docker run -d --name "$NAME2" --entrypoint sh \
    -e FAKE_OB_MODE=synced -e OBSIDI_POLL_INTERVAL=1 \
    -e PATH=/fakebin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    "$IMG" -c 'mkdir -p /vault/dir && touch /vault/dir/owned /vault/rootowned \
        && chown 99:100 /vault /vault/dir /vault/dir/owned \
        && echo keep > /tmp/victim && chown 99:100 /run/obsidi \
        && ln -s /tmp/victim /run/obsidi/heartbeat && ln -s /tmp/victim /run/obsidi/heartbeat.json \
        && sleep 2 \
        && stat -c %Z /vault/dir/owned > /tmp/before && exec /entrypoint.sh' >/dev/null \
    || { echo "FAIL: docker run (stamp)"; exit 1; }
sleep 6
before=$(docker exec "$NAME2" cat /tmp/before)
after=$(docker exec "$NAME2" stat -c %Z /vault/dir/owned)
owner=$(docker exec "$NAME2" stat -c %u:%g /vault/rootowned)
mode=$(docker exec "$NAME2" stat -c %a /run/obsidi/synced 2>/dev/null || echo missing)
if [ -n "$before" ] && [ "$before" = "$after" ]; then pass "correctly owned entry keeps its ctime ($after)"
else fail "correctly owned entry ctime changed: $before -> $after"; fi
if [ "$owner" = 99:100 ]; then pass "root-owned entry chowned to 99:100"
else fail "root-owned entry is $owner"; fi
if [ "$mode" = 644 ]; then pass "synced stamp present, mode 644"
else fail "synced stamp mode: $mode"; fi
# Symlinks planted in the run dir (as uid 99 could when it owned the
# directory) are removed, not followed: the target keeps its content and owner.
victim=$(docker exec "$NAME2" sh -c 'cat /tmp/victim; stat -c %u:%g /tmp/victim')
if [ "$victim" = "keep
0:0" ]; then pass "planted symlinks in the run dir are not followed"
else fail "planted symlink target changed: $victim"; fi
rundir=$(docker exec "$NAME2" stat -c %u:%a /run/obsidi)
pipe=$(docker exec "$NAME2" stat -c %u:%a /run/obsidi/sync.pipe)
if [ "$rundir" = 0:755 ] && [ "$pipe" = 99:600 ]; then pass "run dir root 0755, pipe uid 99 0600"
else fail "run dir $rundir, pipe $pipe"; fi
entry=$(docker exec "$NAME2" stat -c %u:%a /entrypoint.sh)
if [ "$entry" = 0:755 ]; then pass "entrypoint is root-owned 0755"
else fail "entrypoint is $entry"; fi
docker rm -f "$NAME2" >/dev/null 2>&1

[ "$FAILS" -eq 0 ] && echo "ALL PASS" || echo "$FAILS FAILED"
[ "$FAILS" -eq 0 ]
