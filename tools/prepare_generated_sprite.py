"""Fit a transparent generated cutout into a production sprite canvas.

Usage:
    python tools/prepare_generated_sprite.py SOURCE.png DEST.png 192

Chroma removal remains the responsibility of Codex's imagegen helper. This
step only trims transparent margin, adds stable gameplay padding and performs
an alpha-correct Lanczos downsample so transparent RGB cannot create dark
fringes around the sprite.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def alpha_correct_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    # The generator sometimes returns a very broad soft matte. Colours with
    # almost-zero alpha are visually absent but expand getbbox to the canvas,
    # leaving the actual unit tiny after fitting. Strip only that invisible
    # haze; retain real antialiasing above the threshold.
    clipped_alpha = alpha.point(lambda value: 0 if value <= 10 else value)
    rgba.putalpha(clipped_alpha)
    # Pillow's RGBA Lanczos path is premultiplied internally. Clearing invisible
    # RGB first prevents generated matte colours from bleeding into the edge.
    clean = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    clean.alpha_composite(rgba)
    return clean.resize(size, Image.Resampling.LANCZOS)


def prepare(source: Path, destination: Path, canvas_size: int) -> None:
    image = Image.open(source).convert("RGBA")
    alpha = image.getchannel("A")
    alpha_threshold = alpha.point(lambda value: 255 if value > 10 else 0)
    bounds = alpha_threshold.getbbox()
    if bounds is None:
        raise ValueError(f"{source} has no visible subject")

    subject = image.crop(bounds)
    max_subject = int(round(canvas_size * 0.92))
    scale = min(max_subject / subject.width, max_subject / subject.height)
    fitted_size = (
        max(1, int(round(subject.width * scale))),
        max(1, int(round(subject.height * scale))),
    )
    subject = alpha_correct_resize(subject, fitted_size)

    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    at = ((canvas_size - subject.width) // 2, (canvas_size - subject.height) // 2)
    canvas.alpha_composite(subject, at)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)

    corner_alpha = [
        canvas.getpixel((0, 0))[3],
        canvas.getpixel((canvas_size - 1, 0))[3],
        canvas.getpixel((0, canvas_size - 1))[3],
        canvas.getpixel((canvas_size - 1, canvas_size - 1))[3],
    ]
    visible = sum(1 for value in canvas.getchannel("A").getdata() if value > 10)
    coverage = visible / float(canvas_size * canvas_size)
    if max(corner_alpha) != 0 or not 0.05 <= coverage <= 0.85:
        raise ValueError(
            f"invalid output: corner alpha={corner_alpha}, coverage={coverage:.3f}"
        )
    print(f"{destination}: {canvas_size}x{canvas_size}, coverage={coverage:.3f}")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        raise SystemExit("usage: prepare_generated_sprite.py SOURCE DEST SIZE")
    prepare(Path(sys.argv[1]), Path(sys.argv[2]), int(sys.argv[3]))
