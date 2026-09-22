#!/usr/bin/env bash
#
# Run CI's gates locally, derived from the workflows rather than from a list.
#
#   tools/sweep.sh <scratch-dir> [guard|release]
#
# **Why this parses the workflow instead of listing the gates.** A hand-kept
# list of what to run before publishing rots silently: it goes on passing while
# CI grows a gate it has never heard of, and you only find out when the publish
# fails. Three publishes died that way. The workflow is the only thing that
# cannot disagree with CI about what CI runs, so the list is read out of it
# every time.
#
# It takes the whole call, whatever shape it is:
#   guard.yml    check "some name" --headless --path game res://tools/x.tscn
#   release.yml  run_godot_clean --headless --path game res://tools/x.tscn
#
# **Including the `--script` tools**, which are gates too:
#   check "battlefield grid" --headless --path game --script res://tools/x.gd
#   run_godot_clean --headless --path game --script res://tools/run_tool.gd -- audit
#
# That has always been true — everything after the keyword is handed to Godot —
# and this comment used to name only the two `.tscn` shapes, which read as a
# statement that a `--script` line was invisible here. It cost a session:
# `grid_check` and `raid_layout_check` are `--script` tools, they were on
# neither workflow, and the first move planned to fix that was to teach this
# parser a shape it already knew. A comment that understates a tool is the same
# fault as one that overstates it — both send somebody to the wrong place.
#
# **It runs against an isolated profile.** `APPDATA` is pointed at the scratch
# directory, so a gate that writes to `user://` cannot touch the player's real
# save. That is not paranoia: 24 tools were found writing to the owner's live
# save in this project, and one of them ate three pieces of gear.
#
# A gate "passes" only if it exits 0 *and* prints no ERROR or WARNING. CI holds
# the same bar, and a gate that prints PASS while a script error scrolled past
# above it is the exact failure this project has hit more than once.

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

GODOT="$(find "$ROOT" -maxdepth 2 -name 'Godot_v*_console.exe' -print -quit)"
if [ -z "$GODOT" ] || [ ! -f "$GODOT" ]; then
  echo "No Godot console executable found under $ROOT." >&2
  echo "Expected something like Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe" >&2
  exit 2
fi

if [ $# -lt 1 ]; then
  echo "usage: tools/sweep.sh <scratch-dir> [guard|release]" >&2
  exit 2
fi
SCRATCH="$1"; shift
WHICH="${1:-guard}"

mkdir -p "$SCRATCH/logs" "$SCRATCH/appdata"
: > "$SCRATCH/results.tsv"

# The player's save lives under APPDATA. Point it somewhere disposable.
export APPDATA="$SCRATCH/appdata"
export LOCALAPPDATA="$SCRATCH/appdata"

extract() {
  # $1 = workflow file, $2 = the shell function CI calls
  python - "$1" "$2" <<'PY'
import sys
src = open(sys.argv[1], encoding="utf-8").read()
kw = sys.argv[2]
for line in src.splitlines():
    s = line.strip()
    if s.startswith("#") or not s.startswith(kw + " "):
        continue
    print(s[len(kw):].strip())
PY
}

run_one() {
  local raw="$1" idx="$2"
  local name args
  if [[ "$raw" == \"* ]]; then
    # check "human name" <godot args...>
    name="$(printf '%s' "$raw" | sed -E 's/^"([^"]*)".*/\1/')"
    args="$(printf '%s' "$raw" | sed -E 's/^"[^"]*"[[:space:]]*//')"
  else
    # release.yml has no human name, so it is read off the script being run.
    # `run_tool.gd` is three different gates depending on its subcommand, and
    # naming them all "run_tool" makes the summary say which one failed only by
    # accident of ordering — so the subcommand after `--` joins the name.
    name="$(printf '%s' "$raw" | grep -oE 'res://tools/[a-z_0-9]+' | head -1)"
    [ -z "$name" ] && name="godot"
    local sub
    sub="$(printf '%s' "$raw" | sed -nE 's/.* -- +([a-z0-9-]+).*/\1/p')"
    [ -n "$sub" ] && name="$name -- $sub"
    args="$raw"
  fi
  local slug log status verdict why
  slug="$(printf '%s' "$name" | tr -c 'a-zA-Z0-9' '_')"
  log="$SCRATCH/logs/${idx}_${slug}.log"

  # shellcheck disable=SC2086
  eval timeout 600 "\"$GODOT\"" $args > "$log" 2>&1
  status=$?

  verdict="PASS"; why=""
  if [ "$status" -eq 124 ]; then
    verdict="TIMEOUT"
  elif [ "$status" -ne 0 ]; then
    verdict="EXIT$status"
    why="$(awk '/^(SCRIPT )?ERROR:|^WARNING:|FAIL/ && !/depended scripts/ { print; exit }' "$log")"
  elif grep -Eq '^(SCRIPT )?ERROR:|^WARNING:' "$log"; then
    # Exit 0 is not enough. A gate can print its own PASS line while a script
    # error scrolled past above it.
    verdict="DIRTY"
    why="$(awk '/^(SCRIPT )?ERROR:|^WARNING:/ && !/depended scripts/ { print; exit }' "$log")"
  fi
  printf '%s\t%s\t%s\t%s\n' "$verdict" "$name" "${why:0:200}" "$log" >> "$SCRATCH/results.tsv"
  printf '%-8s %s %s\n' "$verdict" "$name" "${why:0:140}"
}

case "$WHICH" in
  guard)   mapfile -t CALLS < <(extract "$ROOT/.github/workflows/guard.yml" check) ;;
  release) mapfile -t CALLS < <(extract "$ROOT/.github/workflows/release.yml" run_godot_clean) ;;
  *) echo "unknown sweep '$WHICH' (expected guard or release)" >&2; exit 2 ;;
esac

if [ "${#CALLS[@]}" -eq 0 ]; then
  echo "Parsed 0 gates out of $WHICH.yml — the workflow's shape has changed and" >&2
  echo "this script is now lying about coverage. Fix the parser before trusting it." >&2
  exit 2
fi

echo "Derived ${#CALLS[@]} gates from $WHICH.yml"
i=0
for c in "${CALLS[@]}"; do
  i=$((i + 1))
  run_one "$c" "$(printf '%02d' $i)"
done

echo
echo "=== SUMMARY ($WHICH) ==="
awk -F'\t' '$1!="PASS"' "$SCRATCH/results.tsv" || true
echo "pass: $(awk -F'\t' '$1=="PASS"' "$SCRATCH/results.tsv" | wc -l) / ${#CALLS[@]}"
awk -F'\t' '$1!="PASS"' "$SCRATCH/results.tsv" | grep -q . && exit 1
exit 0
