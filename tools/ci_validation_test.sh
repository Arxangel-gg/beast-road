#!/usr/bin/env bash
# Exercise the actual workflow reporters under errexit/pipefail, without Godot.
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."

# **The fixture output goes through a file, not the environment.**
#
# It used to be `printf '%s\n' "$FIXTURE_OUTPUT"`, with the text passed as an
# environment variable. That works on Windows and fails on Linux - the exact
# class of bug this file exists to catch, caught here on this step's first ever
# run on a runner.
#
# Linux caps a *single* env string at MAX_ARG_STRLEN (32 pages, 128 KiB). The
# `many` fixture is 12000 error lines, roughly 480 KiB, so execve returned E2BIG
# and bash exited 126 - "cannot execute" - before a line of reporter logic ran.
# The test then read 126 against an expected 1 and looked like a reporter fault.
#
# A file has no such limit, and is closer to the real thing anyway: the
# reporters read a log off disk, not out of the environment.
godot() { cat "$FIXTURE_OUTPUT_FILE"; return "$FIXTURE_STATUS"; }
timeout() { shift; "$@"; }
export -f godot timeout
FIXTURE_OUTPUT_FILE="$(mktemp)"
export FIXTURE_OUTPUT_FILE
trap 'rm -f "$FIXTURE_OUTPUT_FILE"' EXIT

cases=0
for workflow in guard release; do
  function_name=check
  invocation='check fixture'
  if [[ "$workflow" == release ]]; then
    function_name=run_godot_clean
    invocation='run_godot_clean --headless fixture'
  fi
  helper=$(sed -n "/^          ${function_name}() {/,/^          }$/p" ".github/workflows/$workflow.yml" | sed 's/^          //')
  [[ -n "$helper" ]] || { echo "Missing $workflow reporter"; exit 1; }
  for fixture in clean silent_failure warning_failure error warning cascade many tool_finding crash; do
    status=0
    output='[fixture] PASS'
    expected=1
    case "$fixture" in
      clean) expected=0 ;;
      silent_failure) status=7; output='no recognizable diagnostic' ;;
      warning_failure) status=1; output='WARNING: fixture dependency' ;;
      error) output='ERROR: fixture root cause' ;;
      warning) output='WARNING: fixture warning' ;;
      cascade) output='SCRIPT ERROR: failed to compile depended scripts' ;;
      many) output=$(awk 'BEGIN { for (i=0;i<12000;i++) print "ERROR: repeated fixture diagnostic " i }') ;;
      # What every gate under tools/ actually prints when it fails. The
      # indent is deliberate there - it keeps a tool's own finding from
      # being read as the engine failing - and it made the finding
      # invisible to a reporter that anchors, so the gates that had
      # already said what was wrong were the ones annotating nothing.
      tool_finding) status=1; output=$'Floor tiles: 2 problems
  ERROR: jungle_base median luminance 19' ;;
      # What actually broke the v0.6.2 Guard run: a gate that passed, printed
      # its PASS line, and then segfaulted inside engine shutdown. `timeout`
      # reports 128+11 for SIGSEGV, and the log holds no ERROR: and no FAIL
      # because a crash prints neither.
      crash) status=139; output='[menu-layout] PASS - 10 screen openings across 2 phone shapes' ;;
    esac
    set +e
    printf '%s\n' "$output" > "$FIXTURE_OUTPUT_FILE"
    result=$(FIXTURE_STATUS="$status" bash -c "set -euo pipefail
$helper
$invocation" 2>&1)
    actual=$?
    set -e
    if [[ "$actual" -ne "$expected" ]]; then
      echo "$workflow/$fixture returned $actual, wanted $expected"
      exit 1
    fi
    if [[ "$expected" -eq 1 && "$result" != *'::error title='* ]]; then
      echo "$workflow/$fixture hid its failure instead of annotating it"
      exit 1
    fi
    if [[ "$fixture" == silent_failure && "$result" != *'7'* ]]; then
      echo "$workflow lost the original exit status"
      exit 1
    fi
    if [[ "$fixture" == tool_finding && "$result" != *'median luminance 19'* ]]; then
      echo "$workflow did not quote an indented tool finding"
      exit 1
    fi
    if [[ "$fixture" == crash && "$workflow" == guard ]]; then
      if [[ "$result" != *'SIGSEGV'* ]]; then
        echo "guard did not name the signal a crashed gate died on"
        exit 1
      fi
      if [[ "$result" != *'menu-layout'* ]]; then
        echo "guard did not quote the last output line before the crash"
        exit 1
      fi
    fi
    cases=$((cases + 1))
  done
done
echo "[ci-reporters] PASS - $cases cases; failures retain annotations under pipefail"
