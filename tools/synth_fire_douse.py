"""Renders the hiss of a fire put out by water.

    python tools/synth_fire_douse.py

Writes `game/audio/sfx/sfx_fire_douse_{1,2,3}.ogg`: three takes of a short
steam hiss - a bright burst of high noise that thins and falls away, a soft
low puff under its front, and a few crackles as the last of the flame dies.
`Wildfire._burn_out` plays one where rain, snow, hail or a flood puts a fire
out (2026-10-01), so the moment reads as water winning rather than as a fire
simply ending.

**Synthesised placeholders**, listed in `gen_sfx_prompts.PLACEHOLDER_IDS` with a
prompt for the recording that should replace them. Mono, Vorbis q5, as every
one-shot is (`tools/import_audio.py`). Seeded, so a re-render writes the same
files.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

RATE = 44100
TAKES = [
    # seed, length in seconds, the hiss's low and high band edges in Hz
    (5, 0.95, 2400.0, 9000.0),
    (13, 1.10, 2100.0, 8200.0),
    (29, 0.85, 2800.0, 9800.0),
]
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "audio", "sfx")


def find_ffmpeg() -> str:
    for candidate in ("ffmpeg", r"C:\ffmpeg-7.1.1-essentials_build\bin\ffmpeg.exe"):
        try:
            subprocess.run([candidate, "-version"], capture_output=True, check=True)
            return candidate
        except (OSError, subprocess.CalledProcessError):
            continue
    raise SystemExit("ffmpeg not found")


def render(seed: int, length: float, low: float, high: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    count = int(RATE * length)
    t = np.arange(count) / RATE
    share = t / length
    # The hiss: high noise, loud at once and thinning away - steam leaving.
    noise = rng.standard_normal(count)
    b, a = signal.butter(3, (low / (RATE / 2), min(high / (RATE / 2), 0.98)), btype="bandpass")
    hiss = signal.lfilter(b, a, noise)
    hiss /= max(np.max(np.abs(hiss)), 1e-9)
    # A breath of flutter in the hiss, so it is steam and not a radio.
    flutter = 1.0 + 0.18 * np.sin(2.0 * np.pi * (9.0 + 5.0 * share) * t + seed)
    hiss_env = np.exp(-share * 3.2) * (1.0 - np.exp(-t / 0.012))
    # The puff: low noise under the front, the water landing on the coals.
    low_noise = rng.standard_normal(count)
    b2, a2 = signal.butter(2, 380.0 / (RATE / 2), btype="lowpass")
    puff = signal.lfilter(b2, a2, low_noise)
    puff /= max(np.max(np.abs(puff)), 1e-9)
    puff_env = np.exp(-t / 0.09) * (1.0 - np.exp(-t / 0.004))
    # A few crackles as the flame dies, early and thinning.
    crackle = np.zeros(count)
    for _ in range(9):
        at = int(rng.uniform(0.02, 0.55) * count)
        width = int(RATE * rng.uniform(0.002, 0.006))
        if at + width < count:
            crackle[at:at + width] += rng.standard_normal(width) * np.hanning(width) * rng.uniform(0.4, 0.9)
    mixed = hiss * hiss_env * flutter * 0.85 + puff * puff_env * 0.55 + crackle * 0.5
    fade_out = int(RATE * 0.02)
    mixed[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    return mixed / max(np.max(np.abs(mixed)), 1e-9) * 0.7


def main() -> None:
    ffmpeg = find_ffmpeg()
    os.makedirs(OUT, exist_ok=True)
    for index, take in enumerate(TAKES, start=1):
        data = render(*take)
        pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype(np.int16)
        with tempfile.TemporaryDirectory() as scratch:
            wav_path = os.path.join(scratch, "douse.wav")
            with wave.open(wav_path, "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(2)
                handle.setframerate(RATE)
                handle.writeframes(pcm.tobytes())
            target = os.path.abspath(os.path.join(OUT, "sfx_fire_douse_%d.ogg" % index))
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-ac", "1",
                            "-c:a", "libvorbis", "-q:a", "5", target], check=True)
            print("wrote", target)


if __name__ == "__main__":
    main()
