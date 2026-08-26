#!/usr/bin/env bash
# Two real game processes, connecting through the main menu the way a player does.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="$ROOT/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
OUT="${TMPDIR:-/tmp}"
run () {
  "$GODOT" --headless --path "$ROOT/game" res://tools/coop_ui_check.tscn -- "--role=$1" \
    > "$OUT/coop_ui_$1.log" 2>&1
  echo $? > "$OUT/coop_ui_$1.exit"
}
# Any Godot left over from an interrupted run is still holding the port, and the
# next attempt then fails to host and "proves" co-op is broken. Killed rather
# than worked around: a harness that is flaky for a reason unrelated to what it
# tests is worse than no harness.
pkill -f "Godot_v4.7.1-stable_win64" 2>/dev/null || true
sleep 1

echo "launching two instances..."
run host & HOST=$!
sleep 6
run guest & GUEST=$!
wait $HOST; wait $GUEST
# Judged on the printed assertions, not on exit codes.
#
# Pressing Begin replaces the current scene, and the harness *is* the current
# scene - so both processes are freed mid-run and have no clean exit to give.
# A failed check prints "[coop-ui] <role>: <why>"; anything else is progress.
fails=0
for role in host guest; do
  echo "--- $role ---"
  grep -E '^\[coop-ui\]' "$OUT/coop_ui_$role.log" | head -24
  # `grep -c` exits 1 when it counts nothing, so the old `|| echo 0` fallback
  # appended a *second* zero and the two-line result is not the string "0" - a
  # clean run reported "2 of 2 failed" while both processes printed PASS.
  # Counted with the exit status ignored and compared as a number.
  bad="$(grep -cE "^\[coop-ui\] $role: " "$OUT/coop_ui_$role.log" 2>/dev/null)" || true
  [ "${bad:-0}" -gt 0 ] && fails=$((fails+1))
done

# Both sides must have reached the run, and in the same world.
hs="$(grep -oE 'host in run, seed [0-9]+' "$OUT/coop_ui_host.log" | grep -oE '[0-9]+$')"
gs="$(grep -oE 'guest in run, seed [0-9]+' "$OUT/coop_ui_guest.log" | grep -oE '[0-9]+$')"
echo
if [ -n "$hs" ] && [ "$hs" = "$gs" ]; then
  echo "both players entered the same run, seed $hs"
else
  echo "SEED MISMATCH: host='$hs' guest='$gs' - they are not in the same world"
  fails=$((fails+1))
fi
echo
[ "$fails" -eq 0 ] && echo "=== co-op through the menu: PASS on two processes ===" \
                   || echo "=== co-op through the menu: $fails of 2 failed ==="
exit "$fails"
