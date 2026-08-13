from pathlib import Path
from collections import deque
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BUILDINGS = Path(r"C:\Users\Hamed\.codex\generated_images\019ff81a-e2d3-7c91-8f1d-a04c9792ac34\exec-94d175a9-feef-4eb3-8e22-fefc3a0d9b67.png")
ICONS = Path(r"C:\Users\Hamed\.codex\generated_images\019ff81a-e2d3-7c91-8f1d-a04c9792ac34\exec-819fe05b-776f-4fe6-93a5-c448f6fab3ab.png")


def keyed(source: Image.Image) -> Image.Image:
    """Remove only border-connected chroma, preserving art-coloured interiors."""
    image = source.convert("RGBA")
    pixels = image.load()
    width, height = image.size
    candidate = [[False] * width for _ in range(height)]
    for y in range(height):
        for x in range(width):
            r, g, b, _ = pixels[x, y]
            candidate[y][x] = g > 60 and g - max(r, b) > 12

    background = [[False] * width for _ in range(height)]
    queue = deque()
    for x in range(width):
        queue.extend(((x, 0), (x, height - 1)))
    for y in range(height):
        queue.extend(((0, y), (width - 1, y)))
    while queue:
        x, y = queue.popleft()
        if x < 0 or x >= width or y < 0 or y >= height:
            continue
        if background[y][x] or not candidate[y][x]:
            continue
        background[y][x] = True
        queue.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    for y in range(image.height):
        for x in range(image.width):
            r, g, b, _ = pixels[x, y]
            if background[y][x]:
                pixels[x, y] = (r, min(g, max(r, b) + 4), b, 0)
                continue
            # Decontaminate the two-pixel antialias fringe adjacent to the keyed
            # exterior without cutting holes in olive roofs or green produce.
            near_background = False
            for ny in range(max(0, y - 2), min(height, y + 3)):
                for nx in range(max(0, x - 2), min(width, x + 3)):
                    if background[ny][nx]:
                        near_background = True
                        break
                if near_background:
                    break
            if near_background and g > max(r, b):
                g = min(g, max(r, b) + 4)
            pixels[x, y] = (r, g, b, 255)
    return image


def trim_and_fit(image: Image.Image, size: tuple[int, int], pad: int) -> Image.Image:
    box = image.getbbox()
    if box is None:
        return Image.new("RGBA", size)
    image = image.crop(box)
    scale = min((size[0] - pad * 2) / image.width, (size[1] - pad * 2) / image.height)
    target = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
    image = image.resize(target, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", size)
    canvas.alpha_composite(image, ((size[0] - target[0]) // 2, size[1] - target[1] - pad))
    return canvas


def split(source: Path, names: list[str], destination: Path, size: tuple[int, int], pad: int) -> None:
    atlas = Image.open(source)
    cell_width = atlas.width / len(names)
    destination.mkdir(parents=True, exist_ok=True)
    for index, name in enumerate(names):
        left = round(index * cell_width)
        right = round((index + 1) * cell_width)
        cell = keyed(atlas.crop((left, 0, right, atlas.height)))
        trim_and_fit(cell, size, pad).save(destination / name, optimize=True)


split(BUILDINGS,
      ["building_woodcutter.png", "building_treasury.png", "building_market.png"],
      ROOT / "game" / "art" / "city", (192, 192), 5)
split(ICONS,
      ["ui_wood.png", "ui_food.png", "ui_gold.png", "ui_stone.png"],
      ROOT / "game" / "art" / "icons" / "ui", (128, 128), 8)
