"""Bring the synthesised placeholders onto the recorded corpus's loudness.

**Measured before believing it.** Of the 182 sound effects on disk, 43 are
marked in `docs/SFX_PROMPTS.md` as synthesised placeholders awaiting a real
recording. Decoded and weighted by the level `Sfx.MIX` actually plays each one
at, the two sets sit eight decibels apart:

    placeholder  n= 43  effective mean -17.3 dB
    recorded     n=139  effective mean -25.2 dB

Eight decibels is about twice as loud. Every fishing cue, every disaster and
every boss stinger in the game jumps out of the mix, and seven of them have no
mix entry at all so they play at the loudest default there is. That is the kind
of fault a player hears in the first minute and nobody has flagged it, because
no gate could hear it either.

**Corrected in the mix table rather than by re-encoding the audio**, for three
reasons: it is where this project already keeps loudness decisions, it is
visible in a diff, and it survives the recordings that will one day replace
these files - a real take of the same event wants roughly the same level.

**The shift is uniform, which is deliberate.** The placeholders include things
that are *supposed* to be the loudest events in the game - a quake, near
thunder, a boss falling - and flattening the set onto the corpus mean would take
that away. Moving the whole set down by the difference in means keeps every
placeholder's rank against its neighbours and only stops the set as a whole
from shouting.

  python tools/level_placeholders.py [--check]
"""

from __future__ import annotations

import argparse
import pathlib
import re

import numpy as np
import soundfile as sf

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "SFX_PROMPTS.md"
SFX = ROOT / "game" / "autoload" / "Sfx.gd"
AUDIO = ROOT / "game" / "audio" / "sfx"
DEFAULT_DB = -3.0
# Where the placeholders and the recordings met when this was measured. Applied
# as a shift rather than a target so the set keeps its own internal order.
SHIFT_DB = -8.0
# **With a floor, taken from the corpus rather than chosen.** A uniform shift is
# right for the set and wrong for its quietest members: a swim stroke already
# sitting near the bottom would have landed four decibels under the quietest
# recording in the game and simply stopped being audible. Nothing is pushed
# below where the recorded corpus's own quietest tenth sits.
FLOOR_PERCENTILE = 10.0


def placeholders() -> set[str]:
    doc = DOC.read_text(encoding="utf-8")
    return set(re.findall(
        r"\|\s*`(sfx_[a-z0-9_]+\.ogg)`\s*\*\*\(synthesised placeholder", doc))


def effective(name: str, db: float) -> float | None:
    path = AUDIO / name
    if not path.exists():
        return None
    data, _ = sf.read(path, always_2d=True)
    mono = data.mean(axis=1)
    if mono.size == 0:
        return None
    rms = float(np.sqrt((mono ** 2).mean()))
    if rms <= 0.0:
        return None
    return 20.0 * np.log10(rms) + db


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report and write nothing")
    args = parser.parse_args()

    code = SFX.read_text(encoding="utf-8")
    held = placeholders()
    entries = {m.group(1): (float(m.group(2)), m.group(0))
               for m in re.finditer(r'"(sfx_[a-z0-9_]+)":\s*\{"db":\s*(-?[\d.]+)', code)}

    # The floor, measured off the recordings this set is being matched to.
    recorded: list[float] = []
    for path in sorted(AUDIO.glob("*.ogg")):
        if path.name in held:
            continue
        level = effective(path.name, entries.get(path.stem, (DEFAULT_DB, ""))[0])
        if level is not None:
            recorded.append(level)
    floor = float(np.percentile(np.array(recorded), FLOOR_PERCENTILE)) if recorded else -40.0
    print("the corpus quietest tenth sits at %+.1f dB; nothing goes below it"
          % floor)

    changed = 0
    added = 0
    for name in sorted(held):
        stem = name[:-4]
        current, text = entries.get(stem, (DEFAULT_DB, ""))
        before_level = effective(name, current)
        wanted = round(current + SHIFT_DB, 1)
        if before_level is not None and before_level + SHIFT_DB < floor:
            wanted = round(current + (floor - before_level), 1)
        before = before_level
        after = effective(name, wanted)
        if before is None:
            print("  %-30s MISSING FROM DISK" % name)
            continue
        if text:
            new_text = text.replace('{"db": %s' % _render(current),
                                    '{"db": %s' % _render(wanted), 1)
            if new_text == text:
                print("  %-30s could not rewrite its entry" % name)
                continue
            if not args.check:
                code = code.replace(text, new_text, 1)
            changed += 1
        else:
            # No entry at all, so it was playing at the loudest default there
            # is. One is written for it, at the same shifted level.
            line = ('\t"%s":%s{"db": %s, "pitch": 0.08, "limit": 2, "gap": 0.08},\n'
                    % (stem, " " * max(1, 28 - len(stem)), _render(wanted)))
            if not args.check:
                code = code.replace("const MIX: Dictionary = {\n",
                                    "const MIX: Dictionary = {\n" + line, 1)
            added += 1
        print("  %-30s %+6.1f -> %+6.1f dB effective   (%s)"
              % (name, before, after, "authored" if text else "new entry"))

    if not args.check:
        SFX.write_text(code, encoding="utf-8")
    print("\n%d entries shifted, %d written for sounds that had none%s"
          % (changed, added, " (check only)" if args.check else ""))
    return 0


def _render(value: float) -> str:
    text = ("%g" % value)
    return text if "." in text else text + ".0"


if __name__ == "__main__":
    raise SystemExit(main())
