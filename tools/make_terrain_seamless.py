"""Make approved terrain paintings wrap without visible rectangular seams.

Periodic-plus-smooth decomposition (Moisan 2011) removes the edge discontinuity
while preserving the original interior detail. This is not a blur or a crop: it
solves the low-frequency correction whose only job is to make opposite edges
agree, leaving the high-frequency painted material intact.
"""

from pathlib import Path

import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TERRAINS = ROOT / "game/art/terrain"


def periodic_component(channel: np.ndarray) -> np.ndarray:
    height, width = channel.shape
    boundary = np.zeros_like(channel, dtype=np.float64)

    vertical = channel[0, :] - channel[-1, :]
    boundary[0, :] += vertical
    boundary[-1, :] -= vertical

    horizontal = channel[:, 0] - channel[:, -1]
    boundary[:, 0] += horizontal
    boundary[:, -1] -= horizontal

    yy, xx = np.meshgrid(np.arange(height), np.arange(width), indexing="ij")
    denominator = 2.0 * np.cos(2.0 * np.pi * xx / width)
    denominator += 2.0 * np.cos(2.0 * np.pi * yy / height) - 4.0
    denominator[0, 0] = 1.0

    smooth_fft = np.fft.fft2(boundary) / denominator
    smooth_fft[0, 0] = 0.0
    smooth = np.fft.ifft2(smooth_fft).real
    return channel - smooth


def feather_opposite_edges(image: np.ndarray, pixels: int = 40) -> None:
    """Force exact boundary agreement, fading the correction into the tile."""
    height, width, _ = image.shape
    for offset in range(min(pixels, width // 2)):
        weight = (1.0 - offset / pixels) ** 2
        opposite = width - 1 - offset
        mean = (image[:, offset, :] + image[:, opposite, :]) * 0.5
        image[:, offset, :] = image[:, offset, :] * (1.0 - weight) + mean * weight
        image[:, opposite, :] = image[:, opposite, :] * (1.0 - weight) + mean * weight
    for offset in range(min(pixels, height // 2)):
        weight = (1.0 - offset / pixels) ** 2
        opposite = height - 1 - offset
        mean = (image[offset, :, :] + image[opposite, :, :]) * 0.5
        image[offset, :, :] = image[offset, :, :] * (1.0 - weight) + mean * weight
        image[opposite, :, :] = image[opposite, :, :] * (1.0 - weight) + mean * weight


for path in sorted(TERRAINS.glob("terrain_*.png")):
    image = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64)
    result = image.copy()
    for index in range(3):
        result[:, :, index] = periodic_component(image[:, :, index])
    feather_opposite_edges(result)
    result[:, :, :3] = np.clip(result[:, :, :3], 0.0, 255.0)
    Image.fromarray(result.astype(np.uint8), "RGBA").save(path)
    print(f"made seamless: {path.relative_to(ROOT)}")
