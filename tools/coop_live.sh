#!/usr/bin/env bash
# Runs the co-op live check as two real game processes over a real socket.
#
#   bash tools/coop_live.sh
#
# The in-process gate (coop_check.tscn) is what runs on every push; this is the
# one that proves the *shipping* path. Two processes share nothing - separate
# autoloads, separate RunState, separate MultiplayerAPI, separate clocks - so a
# fact that only worked because both sides read the same object fails here and
# passes there.
#
# Not in guard.yml on purpose: it needs two processes and a real port, and a
# port collision on a shared runner would make it flaky. A flaky gate is worse
# than an absent one.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
SCENE="res://tools/coop_live_check.tscn"
OUT="${TMPDIR:-/tmp}"

run () {
  "$GODOT" --headless --path "$ROOT/game" "$SCENE" -- "--role=$1" \
    > "$OUT/coop_live_$1.log" 2>&1
  echo $? > "$OUT/coop_live_$1.exit"
}

echo "starting host and guest..."
run host &
HOST_PID=$!
# The guest dials with its own patience window, so a head start is not required;
# a short stagger just keeps the logs readable.
sleep 1
run guest &
GUEST_PID=$!

wait $HOST_PID
wait $GUEST_PID

fails=0
for role in host guest; do
  status="$(cat "$OUT/coop_live_$role.exit" 2>/dev/null || echo 99)"
  echo "--- $role (exit $status) ---"
  grep -E '^\[live\]|ERROR|WARNING' "$OUT/coop_live_$role.log" | head -20
  if [ "$status" != "0" ]; then fails=$((fails+1)); fi
done

echo
if [ "$fails" -eq 0 ]; then
  echo "=== co-op live: PASS on two processes ==="
else
  echo "=== co-op live: $fails of 2 processes failed ==="
fi
exit "$fails"
