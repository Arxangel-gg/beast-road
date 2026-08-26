#!/usr/bin/env bash
# Two processes meeting through a real room on the live service.
#
# The only harness that covers the whole WebRTC path as a player uses it -
# open a room, hand over the code, enter it, exchange offer and answer through
# the table, gather routes, open a channel. `webrtc_check` deliberately wires
# the two connections together instead, so the routing between them only exists
# here.
#
# Not in CI. It depends on a third party being up, and a check that goes red
# when somebody else's service is down is a check everybody learns to ignore.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
OUT="${TMPDIR:-/tmp}"
CODE="$OUT/room_code.txt"
rm -f "$CODE"

run () {
  "$GODOT" --headless --path "$ROOT/game" res://tools/room_check.tscn -- \
    "--role=$1" "--code-file=$CODE" > "$OUT/room_$1.log" 2>&1
}

pkill -f "Godot_v4.7.1-stable_win64" 2>/dev/null || true
sleep 1

echo "opening a room and joining it..."
run host & HOST=$!
sleep 4
run guest & GUEST=$!
wait $HOST; wait $GUEST

fails=0
for who in host guest; do
  echo "--- $who ---"
  grep -E '^\[room\]' "$OUT/room_$who.log" | head -10
  bad="$(grep -cE "^\[room\] FAIL " "$OUT/room_$who.log" 2>/dev/null)" || true
  bad="${bad:-0}"
  [ "$bad" != "0" ] && fails=$((fails+1))
done

echo
[ "$fails" -eq 0 ] && echo "=== a real room: PASS on two processes ===" \
                   || echo "=== a real room: $fails of 2 failed ==="
exit "$fails"
