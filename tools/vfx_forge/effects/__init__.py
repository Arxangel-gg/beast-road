"""Every effect the forge can render, one file each.

**Adding an effect is adding a file** - working rule 3 applied to art, and
what `docs/VFX_FORGE.md` §4 asked for in as many words. Nothing lists the
effects; `catalogue()` reads the folder, so a file dropped here is in the
command line, in the app's list and in `--all` without anything being edited.

A module declares two things:

    SPEC = {
        "frames": 16,      # cells in the sheet
        "size": 96,        # pixels a cell
        "variants": 3,     # how many takes to render
        "why": "one line: what this is drawn for",
    }

    def build(f):          # f is a forge_kit.Forge
        return f.Look(mask=..., tone=...)

**The dividing line is `docs/VFX_FORGE.md` §3 and it is not negotiable**: a
sheet is allowed when the effect's size is fixed decoration. Anything whose
size is a gameplay number - a range ring, a ground telegraph, blood, a
footfall - stays procedural and must not be authored here.
"""

from __future__ import annotations

import importlib
import os
import pkgutil

HERE = os.path.dirname(os.path.abspath(__file__))

DEFAULTS = {"frames": 16, "size": 96, "variants": 1, "why": ""}


def names() -> list:
    """Every effect id on disk, sorted."""
    found = []
    for entry in pkgutil.iter_modules([HERE]):
        if not entry.name.startswith("_"):
            found.append(entry.name)
    return sorted(found)


def spec(effect_id: str) -> dict:
    """An effect's declared shape, with the defaults filled in.

    Imported rather than parsed, so a `SPEC` that does not evaluate is an
    error at the moment somebody lists the catalogue rather than half an hour
    into a batch render.
    """
    module = importlib.import_module("%s.%s" % (__name__, effect_id))
    out = dict(DEFAULTS)
    out.update(getattr(module, "SPEC", {}))
    out["id"] = effect_id
    return out


def catalogue() -> list:
    """Every effect with its spec, for the CLI and the app."""
    return [spec(name) for name in names()]
