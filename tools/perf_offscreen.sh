#!/usr/bin/env bash
# A windowed performance measurement that never covers the owner's screen and
# never takes their keyboard (2026-09-30).
#
# Three windowed runs in this project ended because the window opened over what
# the owner was doing and a keypress meant for something else reached it. The
# window here is created beyond every monitor (`--position`) and cannot be
# focused (`display/window/size/no_focus`, through a temporary `override.cfg`
# that is removed on exit whatever happens), and `perf_check --offscreen`
# keeps it there. The renderer still draws every frame, so the GPU and the
# frame time are real.
#
#   tools/perf_offscreen.sh <profile dir> <tool> [tool args...]
#   tools/perf_offscreen.sh /tmp/prof res://tools/perf_check.tscn --act=10 --build --loadout
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
godot="$here/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
profile="$1"; shift
tool="$1"; shift
override="$here/game/override.cfg"
if [ -e "$override" ]; then
	echo "refusing: $override already exists and is not ours" >&2
	exit 2
fi
printf '[display]\n\nwindow/size/no_focus=true\n' > "$override"
trap 'rm -f "$override"' EXIT INT TERM HUP
mkdir -p "$profile"
APPDATA="$profile" LOCALAPPDATA="$profile" "$godot" --path "$here/game" \
	--position 20000,20000 "$tool" -- --offscreen "$@"
