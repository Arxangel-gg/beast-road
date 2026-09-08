"""Download approved PixelLab jobs for review before installing their frames.

No authentication is needed for the job-specific result URLs. Generation is
performed through PixelLab MCP, never by this script. Keep its job ledger.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.request import urlopen
from urllib.error import HTTPError

from PIL import Image, ImageDraw


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("ledger", type=Path)
    parser.add_argument("--folder", default="enemies", choices=["enemies", "bosses", "wildlife", "towers"])
    parser.add_argument("--install-reviewed", action="store_true",
                        help="Install complete packages after contact-sheet review")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    stage = root / ".codex-art-20260907" / args.folder
    stage.mkdir(parents=True, exist_ok=True)
    rows = []
    pending_count = 0
    for job in json.loads(args.ledger.read_text(encoding="utf-8"))["jobs"]:
        asset = job["id"]
        sequence = job.get("sequence", "idle")
        count = job.get("frames_to_ship", 3)
        if not re.fullmatch(r"[a-z0-9_]+", asset) or sequence not in {"idle", "move", "attack"}:
            raise ValueError("Invalid asset or sequence name")
        if not isinstance(count, int) or not 1 <= count <= 8:
            raise ValueError("Sequence must contain 1-8 continuation frames")
        if not re.fullmatch(r"[a-f0-9-]{36}", job["job_id"]):
            raise ValueError("Invalid PixelLab job id")
        base = Image.open(root / "game/art" / args.folder / f"{asset}.png").convert("RGBA")
        frames = [base]
        pending = False
        for index in range(1, count + 1):
            target = stage / f"{asset}_{sequence}_{index:02}.png"
            # **A staged frame is only a cache hit if it came from *this* job.**
            #
            # This used to be a bare `if not target.exists()`, which is right
            # for resuming an interrupted download and silently wrong the moment
            # a package is regenerated: the rejected frames sit at exactly the
            # paths the replacement wants, so the new job is never fetched and
            # the contact sheet shows the art you just rejected. That happened
            # on 2026-09-08 to five tower packages, and the sheet was identical
            # enough to the first one to look like the model had ignored the
            # prompt rather than like nothing had downloaded.
            #
            # The job id is written beside each frame and compared. A stale
            # sidecar, or none at all, re-fetches.
            stamp = target.with_suffix(".job")
            fresh = (target.exists() and stamp.exists()
                     and stamp.read_text(encoding="utf-8").strip() == job["job_id"])
            if not fresh:
                url = f'https://api.pixellab.ai/mcp/images/{job["job_id"]}/download?index={index}'
                try:
                    with urlopen(url, timeout=60) as response:
                        target.write_bytes(response.read())
                except HTTPError as error:
                    if error.code != 423:
                        raise
                    print(f"Still processing: {asset}")
                    pending = True
                    break
                stamp.write_text(job["job_id"], encoding="utf-8")
            with Image.open(target) as source:
                frame = source.convert("RGBA")
            if frame.size != base.size:
                # Boss art uses a 192-native lattice displayed at 384px.
                if base.size != (384, 384) or frame.size != (192, 192):
                    raise ValueError(f"Unexpected frame size: {asset}: {frame.size}")
                frame = frame.resize(base.size, Image.Resampling.NEAREST)
                frame.save(target)
            if not frame.getchannel("A").getbbox():
                raise ValueError(f"Empty frame: {target}")
            frames.append(frame)
        if pending:
            pending_count += 1
            continue
        if args.install_reviewed:
            targets = [stage / f"{asset}_{sequence}_{index:02}.png" for index in range(1, count + 1)]
            if sequence == "idle":
                subprocess.run([sys.executable, str(root / "tools/lock_animation_region.py"),
                                str(root / "game/art" / args.folder / f"{asset}.png"),
                                *(str(target) for target in targets), "--align-ground"], check=True)
            for target in targets:
                shutil.copy2(target, root / "game/art" / args.folder / target.name)
            frames = [base] + [Image.open(target).convert("RGBA") for target in targets]
        row = Image.new("RGB", (200 * len(frames), 225), (24, 29, 32))
        ImageDraw.Draw(row).text((4, 4), asset, fill=(230, 220, 195))
        for index, frame in enumerate(frames):
            preview = frame.resize((192, 192), Image.Resampling.NEAREST)
            row.paste(preview, (index * 200, 25), preview)
        rows.append(row)
    # Small enough to inspect every sprite at native resolution.
    for offset in range(0, len(rows), 4):
        chunk = rows[offset:offset + 4]
        sheet = Image.new("RGB", (max(row.width for row in chunk), 225 * len(chunk)))
        for index, row in enumerate(chunk):
            sheet.paste(row, (0, index * 225))
        sheet.save(stage / f"review_{offset // 4:02}.png")
    action = "Installed reviewed" if args.install_reviewed else "Staged"
    print(f"{action} {len(rows)} packages in {stage}")
    if pending_count and args.install_reviewed:
        raise SystemExit(f"Incomplete installation: {pending_count} jobs still processing")


if __name__ == "__main__":
    main()
