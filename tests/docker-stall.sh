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

[ "$FAILS" -eq 0 ] && echo "ALL PASS" || echo "$FAILS FAILED"
[ "$FAILS" -eq 0 ]
