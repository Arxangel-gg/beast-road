#!/usr/bin/env bash
# Films the trailer's shots from the real game, one process a shot, with Godot's
# Movie Maker in a windowed, unfocusable window beyond every monitor - so a
# capture never takes the screen it runs on.
#
#   trailer/capture.sh [shot ...]       # every shot in trailer/shots.json if none named
#
# Each shot lands in trailer/work/<id>.avi (MJPEG at 0.96, PCM at 48 kHz, 60 fps)
# with its log beside it; the log carries `[trailer] roll <frame>`, which is
# where trailer/build.py cuts the warm-up off. Saves are held and the profile is
# a scratch one under trailer/work, so the account on this machine is untouched.
set -u
here="$(cd "$(dirname "$0")/.." && pwd)"
godot="$here/Godot_v4.7.1-stable_win64.exe/Godot_v4.7.1-stable_win64_console.exe"
work="$here/trailer/work"
profile="$work/profile"
override="$here/game/override.cfg"
mkdir -p "$work" "$profile"
if [ "$#" -eq 0 ]; then
	set -- $(python -c "import json,sys;print(' '.join(s['id'] for s in json.load(open(sys.argv[1]))['shots']))" "$here/trailer/shots.json")
fi
if [ -e "$override" ]; then
	echo "refusing: $override already exists and is not ours" >&2
	exit 2
fi
printf '[display]\n\nwindow/size/mode=0\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\nwindow/size/no_focus=true\n\n[editor]\n\nmovie_writer/mjpeg_quality=0.96\nmovie_writer/mix_rate=48000\n' > "$override"
trap 'rm -f "$override"' EXIT INT TERM HUP
native="$(cygpath -m "$work" 2>/dev/null || echo "$work")"
for shot in "$@"; do
	echo "== $shot"
	rm -f "$work/$shot.avi"
	APPDATA="$profile" LOCALAPPDATA="$profile" timeout 900 "$godot" --path "$here/game" \
		--position 20000,20000 --write-movie "$native/$shot.avi" --fixed-fps 60 \
		res://tools/trailer_capture.tscn -- --shot="$shot" > "$work/$shot.log" 2>&1
	grep -E "\[trailer\]" "$work/$shot.log" || echo "   no roll printed - see $work/$shot.log"
	grep -cE "^(ERROR|WARNING)" "$work/$shot.log" | sed 's/^/   error lines: /'
done
