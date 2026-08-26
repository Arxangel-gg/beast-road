#!/usr/bin/env bash
# A host that waits longer than the handshake timeout, and a guest that turns
# up afterwards.
#
# This is the shape of the bug that broke web co-op for four builds. The host
# armed the same 45s deadline as the guest, so a host waiting for a friend to
# read six characters out of a chat window failed on its own - and `_fail`
# closes the room on the way out, so the friend who finally typed the code was
# told "no game is waiting on that code" while the host's screen still said it
# was hosting.
#
# `room.sh` could never see it: its guest joins four seconds in. The delay is
# the entire test, which is why it is a separate script and why it is slow.
#
# Not in CI, for the same reason as room.sh - it needs somebody else's service
# to be up.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
OUT="${TMPDIR:-/tmp}"
CODE="$OUT/patient_code.txt"
# Comfortably past HANDSHAKE_TIMEOUT (45s), and past the two minute room sweep
# would be better still - but the sweep only runs when somebody else opens or
# enters a room, and a test that depends on other players is not a test.
LATE="${LATE:-55}"
rm -f "$CODE"

run () {
  "$GODOT" --headless --path "$ROOT/game" res://tools/room_check.tscn -- \
    "--role=$1" "--code-file=$CODE" > "$OUT/patient_$1.log" 2>&1
}

pkill -f "Godot_v4.7.1-stable_win64" 2>/dev/null || true
sleep 1

echo "hosting, then joining ${LATE}s later (handshake timeout is 45s)..."
run host & HOST=$!
sleep "$LATE"
run guest & GUEST=$!
wait $HOST; wait $GUEST

fails=0
for who in host guest; do
  echo "--- $who ---"
  grep -E '^\[room\]' "$OUT/patient_$who.log" | head -10
  bad="$(grep -cE "^\[room\] FAIL " "$OUT/patient_$who.log" 2>/dev/null)" || true
  [ "${bad:-0}" != "0" ] && fails=$((fails+1))
done

if [ "$fails" = "0" ]; then
  echo
  echo "=== a patient host: PASS - the guest arrived ${LATE}s late and still connected ==="
  exit 0
fi
echo
echo "=== a patient host: FAIL ==="
exit 1
