#!/usr/bin/env bash
# Two real processes finding each other on the local network, in both orders.
#
# The order matters and is the whole point: only one program on a machine can
# hold the well-known discovery port, so whoever starts second binds an
# ephemeral one. That copy hears nothing unless the first answers it directly,
# and no single-process test can see it.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
OUT="${TMPDIR:-/tmp}"

pkill -f "Godot_v4.7.1-stable_win64" 2>/dev/null || true
sleep 1

run () {
  "$GODOT" --headless --path "$ROOT/game" res://tools/lobby_check.tscn -- "--role=$1" \
    > "$OUT/lobby_$2_$1.log" 2>&1
}

fails=0
for order in host-first listen-first; do
  echo "--- $order ---"
  if [ "$order" = "host-first" ]; then
    run host "$order" & sleep 3; run listen "$order"
  else
    run listen "$order" & sleep 3; run host "$order"
  fi
  wait
  grep -hE '^\[lobby\]' "$OUT/lobby_${order}_host.log" "$OUT/lobby_${order}_listen.log" 2>/dev/null
  if ! grep -q 'listen PASS' "$OUT/lobby_${order}_listen.log" 2>/dev/null; then
    fails=$((fails+1))
  fi
done

echo
[ "$fails" -eq 0 ] && echo "=== lobby discovery: PASS in both orders ===" \
                   || echo "=== lobby discovery: $fails of 2 orders failed ==="
exit "$fails"
