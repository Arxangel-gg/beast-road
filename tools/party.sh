#!/usr/bin/env bash
# One host and N-1 guests, in N real processes. Default three.
#
# Two processes cannot test a party: the whole two-to-four change is about
# seating being keyed on a slot rather than on the word "partner", and with two
# players a wrong seat and a right one are the same number.
set -u
WANT="${1:-3}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
OUT="${TMPDIR:-/tmp}"

run () {
  "$GODOT" --headless --path "$ROOT/game" res://tools/party_check.tscn -- \
    "--role=$1" "--players=$WANT" > "$OUT/party_$2.log" 2>&1
}

# Anything left holding the port from an interrupted run makes the next attempt
# fail to host and "prove" that parties are broken.
pkill -f "Godot_v4.7.1-stable_win64" 2>/dev/null || true
sleep 1

echo "launching $WANT instances..."
run host host & PIDS="$!"
sleep 5
for i in $(seq 2 "$WANT"); do
  run guest "guest$i" & PIDS="$PIDS $!"
  sleep 2
done
for pid in $PIDS; do wait "$pid"; done

fails=0
names="host"
for i in $(seq 2 "$WANT"); do names="$names guest$i"; done
for who in $names; do
  echo "--- $who ---"
  grep -E '^\[party\]' "$OUT/party_$who.log" | head -8
  # `grep -c` prints 0 and exits 1 when nothing matches, so a `|| echo 0`
  # fallback appends a *second* zero and a clean run reads as a failure.
  bad="$(grep -cE "^\[party\] [a-z0-9]+: " "$OUT/party_$who.log" 2>/dev/null)" || true
  bad="${bad:-0}"
  [ "$bad" != "0" ] && fails=$((fails+1))
done

echo
[ "$fails" -eq 0 ] && echo "=== a party of $WANT: PASS on $WANT processes ===" \
                   || echo "=== a party of $WANT: $fails of $WANT failed ==="
exit "$fails"
