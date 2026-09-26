"""Head dressings - hair and beards - for the modular Warden.

    python heads.py buy <id>           queue the chroma-key state for one option
    python heads.py fetch              collect every bought state that finished
    python heads.py cut <id>           key the dressing out of its eight rotations
    python heads.py preview <id> <out> the base wearing the cut in four colours
    python heads.py install <id> ...   lay cuts into the game's sheets and table
    python heads.py list               what is authored, bought and cut

Owner, 2026-09-26: *"8 hairstyles, beards yes, code sway, one face"*. A style
is a state of the body's own base, drawn in chroma-key green, so it can be
keyed out cleanly and coloured at runtime: its light and dark are mapped onto
whatever hair colour the player chose, black and white included.

The options are `heads.json`; the ledger of what was bought is
`ledger/heads.json`, so a state is never bought twice.
"""
from __future__ import annotations

import json
import os
import sys
import time
import urllib.request

import numpy as np
from PIL import Image

import batch
import rig

HERE = os.path.dirname(os.path.abspath(__file__))
OPTIONS = os.path.join(HERE, "heads.json")
LEDGER = os.path.join(HERE, "ledger", "heads.json")
CACHE = os.path.join(HERE, "cache", "heads")

KEY_PROMPT = (
    "{style} Paint the {what} in a single flat vivid chroma-key green (pure bright "
    "green like #20E020), shaded only with lighter and darker greens - no brown, "
    "black, grey or skin tones in the {what} at all. Everything else stays exactly "
    "the same: same face, same pose in every direction, same off-white tunic, belt, "
    "lantern at the hip, trousers and boots, both hands still empty fists holding "
    "nothing."
)

# A pixel is key when green leads the other two by this much, and by this ratio.
KEY_LEAD = 18
KEY_RATIO = 1.3
# A new, dark pixel beside the key is its outline: the generator draws hair
# with a dark edge, and an edge left behind makes a style read as painted on.
OUTLINE_REACH = 2
OUTLINE_DIFF = 60
OUTLINE_DARK = 110
# How far from the head point a green part may start, in figure heights.
HEAD_REACH = 0.16
# The game's sheet: eight cells in `rig.ROW_ORDER`, one a facing, each this
# size with the head point at ANCHOR. Fixed, so every sheet is one size the
# asset manifest can name, and the runtime needs no offset table.
CELL = (64, 96)
ANCHOR = (32, 28)
GAME = os.path.normpath(os.path.join(HERE, "..", "..", "game"))
MANIFEST = os.path.normpath(os.path.join(HERE, "..", "..", "docs", "ASSET_MANIFEST.md"))
MANIFEST_HEADING = "### 5.34 Head dressings of 2026-09-26"
MANIFEST_BEFORE = "### 5.33 Held weapons"
MANIFEST_INTRO = """Hairstyles and beards for the modular Warden (owner, 2026-09-26: eight
hairstyles a body, beards, the sway in code, one face). Each is a state of its
body's own base drawn in chroma-key green, keyed to grey by
`tools/warden_rig/heads.py`, and laid out as eight cells in the rig's facing
order with the head point at the same place in each. Coloured at runtime by
`hair_tint.gdshader`, so a sheet is every hair colour at once. Rows are written
by the install step itself, one per sheet it lays, so the manifest and the
folder cannot disagree.
"""


def _load(path: str, default):
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return default


def _save(path: str, data) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=1, sort_keys=True)
    os.replace(tmp, path)


def options() -> dict:
    return {o["id"]: o for o in _load(OPTIONS, [])}


def buy(option_id: str) -> None:
    option = options()[option_id]
    ledger = _load(LEDGER, {})
    if ledger.get(option_id, {}).get("state"):
        print("already bought", option_id, ledger[option_id]["state"])
        return
    base = batch.layers()[option["body"] + "_base"]["character_id"]
    what = "beard" if option["kind"] == "beard" else "hair"
    body = {
        "character_id": base,
        "edit_description": KEY_PROMPT.format(style=option["prompt"], what=what),
        "state_name": "Key: " + option["id"],
        "seed": 7,
        "no_background": True,
    }
    reply = batch._request("POST", "/create-character-state", body)
    state = reply.get("character_id") or reply.get("id")
    ledger[option_id] = {"state": state, "status": "processing",
                         "bought": time.strftime("%Y-%m-%dT%H:%M:%S")}
    _save(LEDGER, ledger)
    print("bought", option_id, state)


def record(option_id: str, state: str) -> None:
    """A state bought by hand (the pilot) goes in the ledger like any other."""
    ledger = _load(LEDGER, {})
    ledger[option_id] = {"state": state, "status": "processing",
                         "bought": time.strftime("%Y-%m-%dT%H:%M:%S")}
    _save(LEDGER, ledger)


def fetch() -> None:
    ledger = _load(LEDGER, {})
    for option_id, entry in sorted(ledger.items()):
        if entry.get("status") == "completed":
            continue
        reply = batch._request("GET", "/characters/" + entry["state"])
        if reply.get("status") != "completed":
            print(option_id, reply.get("status"))
            continue
        urls = reply.get("rotation_urls") or {}
        folder = os.path.join(CACHE, option_id)
        os.makedirs(folder, exist_ok=True)
        for facing in rig.ROW_ORDER:
            url = urls.get(facing) or urls.get(facing.replace("-", "_"))
            # The file host refuses a request with no User-Agent (403).
            req = urllib.request.Request(url, headers={"User-Agent": "wilderhold-rig"})
            with urllib.request.urlopen(req, timeout=120) as r:
                data = r.read()
            with open(os.path.join(folder, facing + ".png"), "wb") as f:
                f.write(data)
        entry["status"] = "completed"
        _save(LEDGER, ledger)
        print("fetched", option_id)


def head_point(body: str, facing: str) -> tuple:
    """The rig's head socket in the rest pose the rotations are drawn in."""
    b = rig.BODIES[body]
    frame = batch.frames_for(body)[facing]
    head = rig.sockets(rig.solve(rig.Pose(), b), facing, frame)["head"]
    return head["x"], head["y"], frame.stature


def _dilate(mask: np.ndarray, reach: int) -> np.ndarray:
    out = mask.copy()
    for dy in range(-reach, reach + 1):
        for dx in range(-reach, reach + 1):
            out |= np.roll(np.roll(mask, dy, 0), dx, 1)
    return out


def _components(mask: np.ndarray) -> list:
    seen = np.zeros_like(mask)
    h, w = mask.shape
    parts = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if seen[y0, x0]:
            continue
        stack = [(y0, x0)]
        seen[y0, x0] = True
        pixels = []
        while stack:
            y, x = stack.pop()
            pixels.append((y, x))
            for ny, nx in ((y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)):
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    stack.append((ny, nx))
        parts.append(pixels)
    return parts


def key(state: Image.Image, base: Image.Image, head: tuple) -> tuple:
    """The dressing's shade and alpha, and a report of what else moved."""
    s = np.asarray(state.convert("RGBA")).astype(int)
    b = np.asarray(base.convert("RGBA")).astype(int)
    r, g, bl, a = s[..., 0], s[..., 1], s[..., 2], s[..., 3]
    others = np.maximum(r, bl)
    green = (a >= 100) & (g - others >= KEY_LEAD) & (g >= KEY_RATIO * np.maximum(others, 1))
    hx, hy, stature = head
    reach = HEAD_REACH * stature
    keep = np.zeros_like(green)
    for part in _components(green):
        ys = np.array([p[0] for p in part])
        xs = np.array([p[1] for p in part])
        if np.min(np.hypot(xs - hx, ys - hy)) <= reach:
            keep[ys, xs] = True
    stray = int(green.sum() - keep.sum())
    diff = np.abs(s[..., :3] - b[..., :3]).sum(axis=2)
    new = (a >= 100) & ((b[..., 3] < 100) | (diff >= OUTLINE_DIFF))
    outline = new & _dilate(keep, OUTLINE_REACH) & ~keep & (s[..., :3].max(axis=2) < OUTLINE_DARK)
    mask = keep | outline
    lum = 0.299 * r + 0.587 * g + 0.114 * bl
    shade = np.where(keep, g / 255.0, lum / 255.0 * 0.6)
    # The rest of the figure should be the base, near enough pixel for pixel,
    # or the dressing will not sit on the body it is laid over.
    rest = ~_dilate(mask, 3)
    figure = rest & ((a >= 100) | (b[..., 3] >= 100))
    changed = rest & ((np.abs(a - b[..., 3]) >= 100) | ((a >= 100) & (diff >= 90)))
    moved = float(changed.sum()) / max(float(figure.sum()), 1.0)
    out = np.zeros(s.shape, dtype=np.uint8)
    v = np.clip(shade * 255.0, 0, 255).astype(np.uint8)
    out[..., 0] = v
    out[..., 1] = v
    out[..., 2] = v
    out[..., 3] = np.where(mask, 255, 0).astype(np.uint8)
    return Image.fromarray(out, "RGBA"), {"stray_key": stray, "outline": int(outline.sum()),
                                          "pixels": int(mask.sum()), "body_moved": round(moved, 4)}


def colour(shade: Image.Image, tint: tuple) -> Image.Image:
    """The runtime's gradient map, for previews: dark, then the tint, then a lit tint."""
    s = np.asarray(shade).astype(float)
    v = s[..., 0] / 255.0
    t = np.array(tint, dtype=float) / 255.0
    dark = t * 0.22
    lit = t + (1.0 - t) * 0.35
    lo = np.clip(v / 0.55, 0, 1)[..., None]
    hi = np.clip((v - 0.55) / 0.45, 0, 1)[..., None]
    rgb = np.where(v[..., None] < 0.55, dark + (t - dark) * lo, t + (lit - t) * hi)
    out = np.zeros(s.shape, dtype=np.uint8)
    out[..., :3] = np.clip(rgb * 255.0, 0, 255).astype(np.uint8)
    out[..., 3] = s[..., 3].astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def cut(option_id: str) -> dict:
    option = options()[option_id]
    body = option["body"]
    folder = os.path.join(CACHE, option_id)
    report = {}
    for facing in rig.ROW_ORDER:
        state = Image.open(os.path.join(folder, facing + ".png")).convert("RGBA")
        base = Image.open(os.path.join(HERE, "refs", body + "_base", facing + ".png")).convert("RGBA")
        head = head_point(body, facing)
        shade, info = key(state, base, head)
        box = shade.getbbox()
        info["box"] = box
        info["offset"] = [round(box[0] - head[0], 2), round(box[1] - head[1], 2)] if box else None
        report[facing] = info
        shade.save(os.path.join(folder, facing + "_shade.png"))
    _save(os.path.join(folder, "cut.json"), report)
    return report


TINTS = ((74, 46, 30), (24, 20, 20), (214, 180, 110), (150, 52, 30))


def preview(option_id: str, out: str) -> None:
    """Each facing: the key state, the bald base, then the base wearing the cut
    in four hair colours."""
    option = options()[option_id]
    folder = os.path.join(CACHE, option_id)
    zoom = 2
    rows = []
    for facing in rig.ROW_ORDER:
        state = Image.open(os.path.join(folder, facing + ".png")).convert("RGBA")
        base = Image.open(os.path.join(HERE, "refs", option["body"] + "_base", facing + ".png")).convert("RGBA")
        shade = Image.open(os.path.join(folder, facing + "_shade.png")).convert("RGBA")
        panels = [state, base]
        for tint in TINTS:
            p = base.copy()
            p.alpha_composite(colour(shade, tint))
            panels.append(p)
        rows.append(panels)
    box = None
    for panels in rows:
        for p in panels:
            b = p.getbbox()
            if b:
                box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]),
                                             max(box[2], b[2]), max(box[3], b[3]))
    top = max(box[1] - 4, 0)
    crop = (box[0] - 4, top, box[2] + 4, top + int((box[3] - top) * 0.55))
    cw, ch = crop[2] - crop[0], crop[3] - crop[1]
    sheet = Image.new("RGBA", (cw * zoom * 6, ch * zoom * len(rows)), (46, 50, 44, 255))
    for j, panels in enumerate(rows):
        for i, p in enumerate(panels):
            sheet.alpha_composite(p.crop(crop).resize((cw * zoom, ch * zoom), Image.NEAREST),
                                  (i * cw * zoom, j * ch * zoom))
    sheet.save(out)
    print("saved", out)


def install(option_ids: list) -> None:
    table_path = os.path.join(GAME, "data", "dress", "heads.json")
    table = _load(table_path, {})
    table["cell"] = list(CELL)
    table["anchor"] = list(ANCHOR)
    entries = table.setdefault("options", {})
    authored = options()
    out_dir = os.path.join(GAME, "art", "hero", "dress", "head")
    os.makedirs(out_dir, exist_ok=True)
    for option_id in option_ids:
        option = authored[option_id]
        folder = os.path.join(CACHE, option_id)
        sheet = Image.new("RGBA", (CELL[0] * len(rig.ROW_ORDER), CELL[1]), (0, 0, 0, 0))
        clipped = 0
        for i, facing in enumerate(rig.ROW_ORDER):
            shade = Image.open(os.path.join(folder, facing + "_shade.png")).convert("RGBA")
            hx, hy, _ = head_point(option["body"], facing)
            left = int(round(hx)) - ANCHOR[0]
            top = int(round(hy)) - ANCHOR[1]
            window = shade.crop((left, top, left + CELL[0], top + CELL[1]))
            whole = int((np.asarray(shade)[..., 3] > 0).sum())
            kept = int((np.asarray(window)[..., 3] > 0).sum())
            clipped += whole - kept
            sheet.alpha_composite(window, (i * CELL[0], 0))
        if clipped:
            print("WARNING %s: %d pixels fall outside the %dx%d cell" % (option_id, clipped, CELL[0], CELL[1]))
        sheet.save(os.path.join(out_dir, "head_%s.png" % option_id))
        # The slot is the option's place among its body's options of its kind,
        # counted from one: nought is bald, or clean-shaven.
        siblings = [o["id"] for o in authored.values()
                    if o["body"] == option["body"] and o["kind"] == option["kind"]]
        entries[option_id] = {"body": option["body"], "kind": option["kind"],
                              "slot": siblings.index(option_id) + 1, "name": option["name"],
                              "sway": option.get("sway", 0.0)}
        print("installed", option_id, "slot", entries[option_id]["slot"])
    os.makedirs(os.path.dirname(table_path), exist_ok=True)
    with open(table_path, "w", encoding="utf-8") as f:
        json.dump(table, f, indent=1, sort_keys=True)
    _write_manifest(sorted(entries))


def _write_manifest(option_ids: list) -> None:
    """The section listing every installed sheet, rewritten whole each time."""
    with open(MANIFEST, encoding="utf-8", newline="") as f:
        raw = f.read()
    crlf = "\r\n" in raw
    text = raw.replace("\r\n", "\n")
    rows = ["| File | Size | Type | Placeholder colour |", "|------|------|------|--------------------|"]
    rows += ["| `head_%s.png` | %d×%d | T | `#3A3128` |" % (i, CELL[0] * len(rig.ROW_ORDER), CELL[1])
             for i in option_ids]
    section = "%s — `res://art/hero/dress/head/`\n\n%s\n%s\n\n" % (
        MANIFEST_HEADING, MANIFEST_INTRO, "\n".join(rows))
    start = text.find(MANIFEST_HEADING)
    if start >= 0:
        end = text.find("\n### ", start + 1)
        text = text[:start] + section + text[end + 1:]
    else:
        at = text.find(MANIFEST_BEFORE)
        if at < 0:
            raise SystemExit("no %r in the manifest to put the head dressings before" % MANIFEST_BEFORE)
        text = text[:at] + section + text[at:]
    with open(MANIFEST, "w", encoding="utf-8", newline="") as f:
        f.write(text.replace("\n", "\r\n") if crlf else text)
    print("manifest: %d head sheets listed" % len(option_ids))


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    command = sys.argv[1]
    if command == "buy":
        buy(sys.argv[2])
    elif command == "record":
        record(sys.argv[2], sys.argv[3])
    elif command == "fetch":
        fetch()
    elif command == "cut":
        print(json.dumps(cut(sys.argv[2]), indent=1))
    elif command == "preview":
        preview(sys.argv[2], sys.argv[3])
    elif command == "install":
        install(sys.argv[2:])
    elif command == "list":
        ledger = _load(LEDGER, {})
        for option_id, option in options().items():
            print("%-26s %-6s %-5s %s" % (option_id, option["body"], option["kind"],
                                          ledger.get(option_id, {}).get("status", "-")))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
