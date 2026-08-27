#!/usr/bin/env bash
# A host and two guests meeting through one real room on the live service.
#
# `room.sh` proves two machines can meet. This proves the room itself holds
# more than two, which is a different claim and the one that broke: a single
# `guest_token` column, a single WebRTCPeerConnection, and fixed peer ids 1 and
# 2 meant the third player had nowhere to sit, however well the first two got on.
#
# Not in CI - it needs somebody else's service to be up.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
OUT="${TMPDIR:-/tmp}"
CODE="$OUT/party_room_code.txt"
WANT="${WANT:-3}"
rm -f "$CODE"

run () {
  "$GODOT" --headless --path "$ROOT/game" res://tools/room_check.tscn -- \
    "--role=$1" "--want=$WANT" "--code-file=$CODE" > "$OUT/party_room_$2.log" 2>&1
}

pkill -f "Godot_v4.7.1-stable_win64" 2>/dev/null || true
sleep 1

echo "one room, $WANT players..."
run host host & PIDS="$!"
sleep 4
for n in $(seq 2 "$WANT"); do
  run guest "guest$n" & PIDS="$PIDS $!"
  # Staggered, so the seat assignment is exercised rather than a dead heat.
  sleep 2
done
for p in $PIDS; do wait "$p"; done

fails=0
for who in host $(seq -f "guest%g" 2 "$WANT"); do
  echo "--- $who ---"
  grep -E '^\[room\]' "$OUT/party_room_$who.log" | head -8
  bad="$(grep -cE "^\[room\] FAIL " "$OUT/party_room_$who.log" 2>/dev/null)" || true
  [ "${bad:-0}" != "0" ] && fails=$((fails+1))
done

if [ "$fails" = "0" ]; then
  echo
  echo "=== one room, $WANT players: PASS ==="
  exit 0
fi
echo
echo "=== one room, $WANT players: FAIL ==="
exit 1
