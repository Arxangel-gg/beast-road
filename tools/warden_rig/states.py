"""The layers drawn over a body - armour worn, a cape - bought as states of it.

    python states.py buy <layer>      buy the state `LAYERS` names for <layer>
    python states.py buy-all          buy every layer here not yet bought
    python states.py fetch            fetch every finished state's rotations
    python states.py sheet <out.png>  each layer's eight rotations beside its base

Owner, 2026-09-26: armour and the long cape, both bodies, now. A layer is a
PixelLab state of its body's own base - the same person, the same pose in
every direction, wearing the thing - and its eight rotations become the layer's
reference frames (`refs/<layer>/`), which `batch.py` animates to the very
skeleton the base was animated to. `layers.json` gets the layer with
`follows` naming the base, so each job takes the base job's seed and depth
and the two land on the same pixels.

**A cape is drawn in chroma-key green**, like the hair: `pack.py` keys it to a
grey shade and the game colours it by the cape kind's own colour, so one cape
serves every cape in the game.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.request

from PIL import Image, ImageDraw

import batch
import rig

HERE = os.path.dirname(os.path.abspath(__file__))
LAYERS_PATH = os.path.join(HERE, "layers.json")

KEEP = ("Everything else stays exactly the same: the same bald head and face, the "
        "same pose in every direction, the dark leather belt with the glowing iron "
        "lantern at the left hip, and both hands bare, closed in empty fists, "
        "holding nothing.")

_LIGHT = ("Dress {p} in light armour over the off-white linen tunic: a fitted dark "
          "brown leather jerkin with buckled straps across the chest, dark leather "
          "bracers on the forearms stopping at the wrists, and dark leather guards "
          "strapped over the shins of the boots. ")
_HEAVY = ("Dress {p} in heavy armour: a polished steel breastplate over a chainmail "
          "shirt, rounded steel pauldrons on the shoulders, steel vambraces on the "
          "forearms stopping at the wrists, and steel greaves over the shins. ")
_CAPE = ("Give {p} a long cape, fastened at both shoulders and hanging down the back "
         "to the calves. Paint the whole cape in a single flat vivid chroma-key green "
         "(pure bright green like #20E020), shaded only with lighter and darker greens "
         "- no brown, black, grey or skin tones in the cape at all. ")

_ANIMATE = {
    "light": "a dark brown leather jerkin, dark leather bracers and shin guards over an off-white linen tunic",
    "heavy": "a steel breastplate over chainmail, steel pauldrons, vambraces and greaves",
    "cape_long": "a long flat bright green cape hanging from the shoulders, over an off-white linen tunic",
}

## Every layer this file buys: its body, the edit that makes it, and the noun
## phrase `batch.py` animates it with.
LAYERS: dict = {}
for _body, _p, _who in (("male", "him", "male"), ("female", "her", "female")):
    for _name, _edit in (("light", _LIGHT), ("heavy", _HEAVY), ("cape_long", _CAPE)):
        LAYERS["%s_%s" % (_body, _name)] = {
            "body": _body,
            "edit": _edit.format(p=_p) + KEEP,
            "description": ("bald lean %s warden in %s, grey-brown trousers, dark leather belt with a "
                            "glowing iron lantern at the left hip, brown leather boots, both hands closed "
                            "in empty fists, holding nothing") % (_who, _ANIMATE[_name]),
        }


def _load() -> dict:
    with open(LAYERS_PATH, encoding="utf-8") as f:
        return json.load(f)


def _save(spec: dict) -> None:
    tmp = LAYERS_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8", newline="\n") as f:
        json.dump(spec, f, indent=1)
        f.write("\n")
    os.replace(tmp, LAYERS_PATH)


def buy(layer: str) -> None:
    wanted = LAYERS[layer]
    spec = _load()
    if spec.get(layer, {}).get("character_id"):
        print("already bought", layer, spec[layer]["character_id"])
        return
    base = spec[wanted["body"] + "_base"]
    reply = batch._request("POST", "/create-character-state", {
        "character_id": base["character_id"],
        "edit_description": wanted["edit"],
        "state_name": "Layer: " + layer,
        "seed": 7,
        "no_background": True,
    })
    state = reply.get("character_id") or reply.get("id")
    spec[layer] = {"body": wanted["body"], "character_id": state, "description": wanted["description"],
                   "seed": 7, "follows": wanted["body"] + "_base", "depth": False, "state": "processing"}
    _save(spec)
    print("bought", layer, state)


def fetch() -> None:
    spec = _load()
    for layer, entry in spec.items():
        if entry.get("state") != "processing":
            continue
        try:
            reply = batch._request("GET", "/characters/" + entry["character_id"])
        except RuntimeError as busy:
            print(layer, "still drawing" if "423" in str(busy) else busy)
            continue
        if reply.get("status") not in (None, "completed"):
            print(layer, reply.get("status"))
            continue
        urls = reply.get("rotation_urls") or {}
        if len(urls) < len(rig.ROW_ORDER):
            print(layer, "rotations not ready")
            continue
        folder = os.path.join(HERE, "refs", layer)
        os.makedirs(folder, exist_ok=True)
        for facing in rig.ROW_ORDER:
            url = urls.get(facing) or urls.get(facing.replace("-", "_"))
            req = urllib.request.Request(url, headers={"User-Agent": "wilderhold-rig"})
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            with open(os.path.join(folder, facing + ".png"), "wb") as f:
                f.write(data)
        entry["state"] = "completed"
        _save(spec)
        print("fetched", layer)


def buy_all() -> None:
    for layer in LAYERS:
        buy(layer)
    while True:
        fetch()
        waiting = [k for k in LAYERS if _load().get(k, {}).get("state") != "completed"]
        if not waiting:
            print("all layer states in")
            return
        print("%d waiting" % len(waiting), flush=True)
        time.sleep(30)


def sheet(out: str) -> None:
    rows = [layer for layer in LAYERS if os.path.isdir(os.path.join(HERE, "refs", layer))]
    cell = (150, 190)
    canvas = Image.new("RGBA", (cell[0] * 8, cell[1] * (len(rows) + 2)), (46, 50, 44, 255))
    d = ImageDraw.Draw(canvas)
    for r, layer in enumerate(["male_base", "female_base"] + rows):
        for i, facing in enumerate(rig.ROW_ORDER):
            path = os.path.join(HERE, "refs", layer, facing + ".png")
            if os.path.exists(path):
                im = Image.open(path).convert("RGBA").crop((29, 8, 179, 198))
                canvas.alpha_composite(im, (i * cell[0], r * cell[1]))
        d.text((4, r * cell[1] + 2), layer, fill=(255, 255, 255))
    canvas.save(out)
    print("saved", out)


def main() -> None:
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "buy":
        buy(sys.argv[2])
    elif command == "buy-all":
        buy_all()
    elif command == "fetch":
        fetch()
    elif command == "sheet":
        sheet(sys.argv[2])
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
