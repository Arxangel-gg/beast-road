"""Rewrites the SOUNDS table in game/autoload/Sfx.gd from what is on disk.

Run after adding sound effects. The table has to be explicit rather than a
runtime directory scan, because Godot strips imported source assets out of the
.pck and a res:// listing therefore finds nothing in an exported build.
"""
import io, os, re

R = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX = os.path.join(R, "game", "audio", "sfx")
TARGET = os.path.join(R, "game", "autoload", "Sfx.gd")

ids = sorted(x[:-4] for x in os.listdir(SFX) if x.endswith(".ogg"))
rows = "
".join('	"%s": "res://audio/sfx/%s.ogg",' % (i, i) for i in ids)
s = io.open(TARGET, encoding="utf-8").read()
s = re.sub(r"const SOUNDS: Dictionary = \{.*?
\}",
           "const SOUNDS: Dictionary = {
%s
}" % rows, s, flags=re.S)
io.open(TARGET, "w", encoding="utf-8", newline="
").write(s)
print("SOUNDS table rewritten with %d entries" % len(ids))
