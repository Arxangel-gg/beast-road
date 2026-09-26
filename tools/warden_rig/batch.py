"""Animate a layer of the modular Warden through PixelLab's REST API.

    python batch.py plan <layer>                  what it would buy, and the cost
    python batch.py run <layer> [--facings f,g] [--clips 0,3] [--dry]
    python batch.py fetch <layer>                 collect finished jobs only
    python batch.py balance -                     the account's generations left
    python batch.py reroll <layer> <facing>/<clip> ...   buy named jobs again, new seed
        [--ref <png>]   ...started from this frame rather than the layer's rotation
        [--depth]       ...sending each joint's true depth (see rig.project)

The key is read from PIXELLAB_API_KEY, or from ~/.pixellab/api_key (or
api_key.txt, which is what Notepad saves), and is never printed, logged or
written anywhere else. The owner puts it there; nothing here asks for it.

Why a script. One skeleton job carries a reference frame and up to fifteen
eighteen-joint skeletons, and a layer is eight facings of eight clips - sixty-four
jobs. Pasted through a chat tool that is several megabytes of numbers per layer;
here it is a loop.

**Every job is in a ledger** (`ledger/<layer>.json`), keyed by facing and clip,
with its id, what was asked and where the frames landed. A run can be stopped at
any point and started again: a completed job is never bought twice, a pending
one is polled rather than resubmitted, and a failed one is resubmitted once and
then reported. That is the rule the art ledger has held since 2026-09-14 - a
frame that can be re-fetched is a frame that was not lost.
"""
from __future__ import annotations

import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request

import animations
import rig

HERE = os.path.dirname(os.path.abspath(__file__))
API = "https://api.pixellab.ai/v2"
MAX_IN_FLIGHT = 16          # PixelLab allows 20 at Tier 3; four are left for hand work
SUBMIT_GAP = 0.6            # seconds between submissions ("too many too quickly")
POLL_EVERY = 12.0
COST = {3: 2, 8: 3, 15: 4}  # generations by frame count, from the endpoint's own doc
STALE_MINUTES = 45          # a job the queue has held this long is resubmitted once


def _stale(entry: dict) -> bool:
    try:
        started = time.mktime(time.strptime(entry.get("submitted", ""), "%Y-%m-%dT%H:%M:%S"))
    except ValueError:
        return False
    return time.time() - started > STALE_MINUTES * 60


def cost_of(frames: int) -> int:
    for limit in sorted(COST):
        if frames <= limit:
            return COST[limit]
    return COST[15]


KEY_FILES = [os.path.join(os.path.expanduser("~"), ".pixellab", name)
             for name in ("api_key", "api_key.txt")]


def _key() -> str:
    """The key, from PIXELLAB_API_KEY or from a file the owner made at
    ~/.pixellab/api_key. Read here and used in one header; never printed,
    logged, echoed on an error or written anywhere else."""
    key = os.environ.get("PIXELLAB_API_KEY", "").strip()
    for path in KEY_FILES:
        if key:
            break
        if os.path.exists(path):
            # utf-8-sig: Notepad may write a byte-order mark, which would ride
            # into the header and read as a wrong key rather than a missing one.
            with open(path, encoding="utf-8-sig") as f:
                key = f.read().strip()
    if not key:
        sys.exit("No PixelLab key: set PIXELLAB_API_KEY, or put the key alone in %s." % KEY_FILES[0])
    return key


def _request(method: str, path: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(API + path, data=data, method=method, headers={
        "Authorization": "Bearer " + _key(),
        "Content-Type": "application/json",
    })
    for attempt in range(5):
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode())
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")[:300]
            if e.code in (429, 502, 503, 504) and attempt < 4:
                time.sleep(5.0 * (attempt + 1))
                continue
            raise RuntimeError("%s %s -> %d %s" % (method, path, e.code, text))
        except urllib.error.URLError:
            if attempt < 4:
                time.sleep(5.0 * (attempt + 1))
                continue
            raise
    raise RuntimeError("unreachable")


def layers() -> dict:
    with open(os.path.join(HERE, "layers.json"), encoding="utf-8") as f:
        return json.load(f)


def frames_for(body: str) -> dict:
    with open(os.path.join(HERE, "frames_%s.json" % body), encoding="utf-8") as f:
        return {k: rig.Frame(**v) for k, v in json.load(f).items()}


def ledger_path(layer: str) -> str:
    os.makedirs(os.path.join(HERE, "ledger"), exist_ok=True)
    return os.path.join(HERE, "ledger", layer + ".json")


def load_ledger(layer: str) -> dict:
    path = ledger_path(layer)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    return {}


def save_ledger(layer: str, ledger: dict) -> None:
    tmp = ledger_path(layer) + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(ledger, f, indent=1, sort_keys=True)
    os.replace(tmp, ledger_path(layer))


def _reference(layer: str, facing: str, override: str | None = None) -> str:
    path = override or os.path.join(HERE, "refs", layer, facing + ".png")
    if not os.path.exists(path):
        sys.exit("no reference frame at %s - fetch the layer's rotations first" % path)
    with open(path, "rb") as f:
        return base64.b64encode(f.read()).decode()


def uses_depth(layer: str, spec: dict, key: str, entry: dict) -> bool:
    """Whether a job sends each joint's true depth. A job's own flag wins; a
    layer drawn over another (`follows`) takes the flag of the same job there,
    because two states land on the same pixels only from the same keypoints;
    otherwise the layer's default."""
    if "depth" in entry:
        return bool(entry["depth"])
    if spec.get("follows"):
        return bool(load_ledger(spec["follows"]).get(key, {}).get("depth", False))
    return bool(spec.get("depth", False))


def job_body(layer: str, spec: dict, facing: str, clip: list, seed: int | None = None,
             ref: str | None = None, depth: bool = False) -> dict:
    body = rig.BODIES[spec["body"]]
    frame = frames_for(spec["body"])[facing]
    rest = rig.project(rig.solve(rig.Pose(), body), facing, frame, depth)
    poses, _ = animations.clip_poses(clip)
    return {
        "description": spec["description"],
        "action": animations.action_of(clip),
        "direction": facing,
        "view": "low top-down",
        "first_frame": {"type": "base64", "base64": _reference(layer, facing, ref), "format": "png"},
        "first_frame_keypoints": rest,
        "keypoints": [rig.project(rig.solve(p, body), facing, frame, depth) for p in poses],
        "seed": spec.get("seed", 7) if seed is None else seed,
        "no_background": True,
    }


def slots(layer: str, facings: list, clips: list) -> list:
    return [(f, c) for f in facings for c in clips]


def plan(layer: str) -> None:
    spec = layers()[layer]
    total = 0
    for i, clip in enumerate(animations.CLIPS):
        n = len(animations.clip_poses(clip)[0])
        total += cost_of(n) * len(rig.ROW_ORDER)
        print("clip %d %-32s %2d frames  %d gens x 8 facings" % (i, "+".join(clip), n, cost_of(n)))
    print("%s (%s): %d generations for the whole layer" % (layer, spec["body"], total))


def _images_of(response: dict) -> list:
    last = response.get("last_response") or {}
    images = last.get("images") or last.get("frames") or []
    out = []
    for image in images:
        if isinstance(image, dict) and image.get("base64"):
            out.append(base64.b64decode(image["base64"]))
        elif isinstance(image, dict) and image.get("url"):
            req = urllib.request.Request(image["url"], headers={"User-Agent": "wilderhold-rig"})
            with urllib.request.urlopen(req, timeout=120) as r:
                out.append(r.read())
        elif isinstance(image, str):
            out.append(base64.b64decode(image))
    return out


def _store(layer: str, facing: str, clip_index: int, images: list) -> str:
    folder = os.path.join(HERE, "cache", layer, "clip%d" % clip_index, facing)
    os.makedirs(folder, exist_ok=True)
    for i, data in enumerate(images):
        with open(os.path.join(folder, "%02d.png" % i), "wb") as f:
            f.write(data)
    return folder


def balance() -> None:
    reply = _request("GET", "/balance")
    sub = reply.get("subscription") or {}
    print("generations left: %s of %s (%s)" % (sub.get("generations"), sub.get("total"), sub.get("plan")))


def run(layer: str, facings: list, clip_ids: list, dry: bool, submit: bool = True) -> None:
    spec = layers()[layer]
    ledger = load_ledger(layer)
    todo = [(f, c) for f, c in slots(layer, facings, clip_ids)
            if ledger.get("%s/%d" % (f, c), {}).get("status") != "completed"]
    spend = sum(cost_of(len(animations.clip_poses(animations.CLIPS[c])[0])) for _, c in todo
                if ledger.get("%s/%d" % (_, c), {}).get("status") != "processing")
    print("%s: %d jobs to finish, about %d generations to buy" % (layer, len(todo), spend))
    if dry:
        return
    pending = [(f, c) for f, c in todo]
    if not submit:
        # Collect only: a job never submitted stays unbought.
        pending = [(f, c) for f, c in pending
                   if ledger.get("%s/%d" % (f, c), {}).get("status") == "processing"]
    while pending:
        in_flight = [k for k, v in ledger.items() if v.get("status") == "processing"]
        for facing, c in list(pending):
            key = "%s/%d" % (facing, c)
            entry = ledger.get(key, {})
            if entry.get("status") == "processing":
                continue
            if len(in_flight) >= MAX_IN_FLIGHT or not submit:
                break
            if entry.get("attempts", 0) >= 2:
                print("giving up on %s after two failures: %s" % (key, entry.get("error")))
                pending.remove((facing, c))
                continue
            depth = uses_depth(layer, spec, key, entry)
            seed = entry.get("seed")
            if seed is None and spec.get("follows"):
                # A layer drawn over a body takes that body's seed as well as its
                # depth, job by job: a base take bought again on a new seed has to
                # be followed on that seed, or the two stop landing on one pixel.
                seed = load_ledger(spec["follows"]).get(key, {}).get("seed")
                if seed is not None:
                    entry["seed"] = seed
            body = job_body(layer, spec, facing, animations.CLIPS[c], seed, entry.get("ref"), depth)
            try:
                response = _request("POST", "/animate-with-skeleton-v3", body)
            except RuntimeError as refused:
                # The account runs about twenty jobs at once across every tool
                # buying on it - the head states included - so a refusal waits
                # for a slot rather than ending the run.
                print("not taken yet", key, str(refused)[:120])
                break
            ledger[key] = {"status": "processing", "job": response["background_job_id"],
                           "clip": animations.CLIPS[c], "attempts": entry.get("attempts", 0) + 1,
                           "submitted": time.strftime("%Y-%m-%dT%H:%M:%S")}
            for kept in ("seed", "ref"):
                if kept in entry:
                    ledger[key][kept] = entry[kept]
            ledger[key]["depth"] = depth
            save_ledger(layer, ledger)
            in_flight.append(key)
            print("submitted", key, response["background_job_id"])
            time.sleep(SUBMIT_GAP)
        time.sleep(POLL_EVERY)
        for key in [k for k, v in ledger.items() if v.get("status") == "processing"]:
            entry = ledger[key]
            try:
                status = _request("GET", "/background-jobs/" + entry["job"])
            except RuntimeError as e:
                # 423 is PixelLab's "still in the queue"; anything else is
                # reported and asked again next round rather than ending the run.
                if "-> 423" not in str(e):
                    print("poll", key, str(e)[:160])
                status = {"status": "processing"}
            if status["status"] == "processing" and _stale(entry):
                status = {"status": "failed", "last_response": "no answer in %d minutes" % STALE_MINUTES}
            if status["status"] == "completed":
                images = _images_of(status)
                facing, c = key.split("/")
                expected = len(animations.clip_poses(animations.CLIPS[int(c)])[0])
                if len(images) != expected:
                    entry.update(status="failed", error="%d frames for %d" % (len(images), expected))
                else:
                    entry.update(status="completed", folder=_store(layer, facing, int(c), images))
                    pending = [p for p in pending if "%s/%d" % p != key]
                    print("completed", key)
            elif status["status"] == "failed":
                entry.update(status="failed", error=str(status.get("last_response"))[:200])
                print("failed", key, entry["error"])
            save_ledger(layer, ledger)
    print("done:", sum(1 for v in ledger.values() if v.get("status") == "completed"), "completed")


def reroll(layer: str, keys: list) -> None:
    """Mark finished jobs to be bought again on a new seed. Their frames are
    kept under `rejected/` rather than overwritten unseen, so the new take can
    be judged against the one it replaces.

    `--ref <png>` starts the new take from another frame of the same rest pose
    - the idle's first frame, say - where the rotation itself leaves something
    undecided that the other clips decided one way: a lantern the rotation
    hides behind the hip, drawn on the right by five clips and on the left by
    the sixth, is the case this exists for."""
    spec = layers()[layer]
    ledger = load_ledger(layer)
    ref = None
    depth = "--depth" in keys
    keys = [k for k in keys if k != "--depth"]
    if "--ref" in keys:
        at = keys.index("--ref")
        ref = os.path.abspath(keys[at + 1])
        if not os.path.exists(ref):
            sys.exit("no reference frame at %s" % ref)
        keys = keys[:at] + keys[at + 2:]
    for key in keys:
        entry = ledger.get(key)
        if entry is None:
            sys.exit("no job %s in the %s ledger" % (key, layer))
        facing, c = key.split("/")
        src = os.path.join(HERE, "cache", layer, "clip" + c, facing)
        if os.path.isdir(src):
            dst = os.path.join(HERE, "cache", layer, "rejected", "clip" + c, facing,
                               "seed%d" % entry.get("seed", spec.get("seed", 7)))
            os.makedirs(os.path.dirname(dst), exist_ok=True)
            if not os.path.exists(dst):
                os.replace(src, dst)
        entry["seed"] = entry.get("seed", spec.get("seed", 7)) + 101
        if ref:
            entry["ref"] = ref
        if depth:
            entry["depth"] = True
        entry["status"] = "reroll"
        entry["attempts"] = 0
        print("reroll", key, "seed", entry["seed"])
    save_ledger(layer, ledger)


def main() -> None:
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    command, layer = sys.argv[1], sys.argv[2]
    args = sys.argv[3:]
    facings = rig.ROW_ORDER
    clip_ids = list(range(len(animations.CLIPS)))
    dry = "--dry" in args
    for i, a in enumerate(args):
        if a == "--facings":
            facings = args[i + 1].split(",")
        if a == "--clips":
            clip_ids = [int(x) for x in args[i + 1].split(",")]
    if command == "plan":
        plan(layer)
    elif command == "run":
        run(layer, facings, clip_ids, dry)
    elif command == "fetch":
        run(layer, facings, clip_ids, dry=False, submit=False)
    elif command == "balance":
        balance()
    elif command == "reroll":
        reroll(layer, args)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
