"""Make Sfx.gd agree with what is actually in game/audio/sfx.

Run this after `tools/import_audio.py`:

    python tools/import_audio.py NewSFX
    python tools/register_sfx.py
    <godot> --headless --path game --import

Idempotent by construction: it reads the folder and rewrites SOUNDS, GROUPS and
PLACEHOLDERS to match, rather than applying a diff. Run it after any import -
a batch with more takes than last time grows the groups, a batch with fewer
shrinks them, and running it twice changes nothing the second time.

The MIX row keyed on the base id is deliberately untouched. `variation_mix_id`
returns the group when MIX has it, so one authored row keeps governing every
take as a single audible event - which is what stops eight variations of a
wildfire crackle tripling the voices one blaze may start.
"""
import io
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_GD = os.path.join(ROOT, "game", "autoload", "Sfx.gd")
SFX_DIR = os.path.join(ROOT, "game", "audio", "sfx")

raw = io.open(SFX_GD, encoding="utf-8").read()
raw_gd = raw

# What is on disk: base id -> the take numbers beside it.
takes = {}
singles = set()
for name in sorted(os.listdir(SFX_DIR)):
    if not name.endswith(".ogg"):
        continue
    stem = name[:-4]
    hit = re.match(r"^(sfx_[a-z0-9_]+?)_(\d+)$", stem)
    if hit:
        takes.setdefault(hit.group(1), set()).add(int(hit.group(2)))
    else:
        singles.add(stem)

# Takes that some *other* group already claims are not a group of their own.
# `sfx_hero_swing_1/2` are members of "swing_light", and inventing a
# "sfx_hero_swing" group beside it would be a second name for one sound that
# nothing plays.
claimed = set()
for members in re.findall(r'^	"[a-z0-9_]+": \[([^\]]*)\],', raw_gd, re.M):
    claimed.update(re.findall(r'"([a-z0-9_]+)"', members))

# A base id with takes is a group; its own single file must not also exist, or
# `play` finds the stream first and the group is never reached.
grouped = {}
for base, numbers in takes.items():
    if base in singles:
        continue
    if any("%s_%d" % (base, n) in claimed for n in numbers) and not re.search(
            r'^	"%s": \[' % re.escape(base), raw_gd, re.M):
        continue
    grouped[base] = sorted(numbers)

changed = []
for base, numbers in sorted(grouped.items()):
    members = ", ".join('"%s_%d"' % (base, n) for n in numbers)
    entry = '\t"%s": [%s],\n' % (base, members)
    existing = re.search(r'^\t"%s": \[[^\]]*\],\n' % re.escape(base), raw, re.M)
    if existing:
        if existing.group(0) != entry:
            raw = raw[:existing.start()] + entry + raw[existing.end():]
            changed.append((base, len(numbers), "grew"))
        continue
    # New group: drop the old single row from SOUNDS and add one row per take.
    single_row = '\t"%s": "res://audio/sfx/%s.ogg",\n' % (base, base)
    rows = "".join('\t"%s_%d": "res://audio/sfx/%s_%d.ogg",\n' % (base, n, base, n)
                   for n in numbers)
    if single_row in raw:
        raw = raw.replace(single_row, rows, 1)
    elif not re.search(r'^\t"%s_1":' % re.escape(base), raw, re.M):
        anchor = '\t"sfx_ui_click_1":'
        at = raw.index(anchor)
        raw = raw[:at] + rows + raw[at:]
    at = raw.index('\t"sfx_ui_click": [')
    raw = raw[:at] + entry + raw[at:]
    changed.append((base, len(numbers), "new"))

# SOUNDS must name every take that exists and nothing that does not.
for base, numbers in sorted(grouped.items()):
    for n in numbers:
        row = '\t"%s_%d": "res://audio/sfx/%s_%d.ogg",\n' % (base, n, base, n)
        if row not in raw:
            after = '\t"%s_%d": "res://audio/sfx/%s_%d.ogg",\n' % (base, n - 1, base, n - 1)
            at = raw.index(after) + len(after) if after in raw else raw.index('\t"sfx_ui_click_1":')
            raw = raw[:at] + row + raw[at:]

# Any SOUNDS row pointing at a file that is gone.
dropped = 0
for row in re.findall(r'^\t"(sfx_[a-z0-9_]+)": "res://audio/sfx/([a-z0-9_]+)\.ogg",\n', raw, re.M):
    sound_id, filename = row
    if not os.path.exists(os.path.join(SFX_DIR, filename + ".ogg")):
        raw = re.sub(r'^\t"%s": "res://audio/sfx/%s\.ogg",\n' % (
            re.escape(sound_id), re.escape(filename)), "", raw, count=1, flags=re.M)
        dropped += 1

# PLACEHOLDERS: only ids that are still a single synthesised file.
block = re.search(r"const PLACEHOLDERS: Array\[String\] = \[\n(.*?)\n\]\n", raw, re.S)
if block:
    ids = re.findall(r'"([a-z0-9_]+)"', block.group(1))
    still = [i for i in ids if i not in grouped]
    lines = ["\t" + ", ".join('"%s"' % i for i in still[n:n + 3]) + ","
             for n in range(0, len(still), 3)]
    body = "\n".join(lines).rstrip(",")
    raw = (raw[:block.start()]
           + "const PLACEHOLDERS: Array[String] = [\n%s,\n]\n" % body
           + raw[block.end():])

io.open(SFX_GD, "w", encoding="utf-8", newline="").write(raw)
print("groups on disk: %d" % len(grouped))
print("changed: %d   stale SOUNDS rows dropped: %d" % (len(changed), dropped))
for base, count, why in changed:
    print("   %-26s %2d takes (%s)" % (base, count, why))
