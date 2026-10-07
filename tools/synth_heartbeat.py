"""Renders the near-death heartbeat, one beat a take.

    python tools/synth_heartbeat.py

Writes `game/audio/sfx/sfx_heartbeat_{1,2,3}.ogg`: a "lub-dub" - two low,
round thumps, the second softer and higher, each a decaying sine with a little
filtered noise for the body's knock. `Vfx` plays one per beat while a Warden is
near death, faster as health falls, on the flat SFX bus so the low-pass that
closes over the world never closes over the heart.

**Synthesised placeholders**, prompted in `docs/SFX_PROMPTS.md` for a recording
to replace them. Mono, Vorbis q5. Seeded, so a re-render writes the same files.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

RATE = 44100
LENGTH = 0.46
TAKES = [
    # seed, the lub's pitch, the dub's pitch, the gap between them in seconds
    (5, 52.0, 66.0, 0.17),
    (9, 48.0, 62.0, 0.18),
    (13, 56.0, 70.0, 0.16),
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


def thump(rng, count: int, start: int, pitch: float, loud: float) -> np.ndarray:
    out = np.zeros(count)
    length = int(RATE * 0.16)
    t = np.arange(length) / RATE
    # A pitch that drops as it decays, which is what makes a thump a thump.
    freq = pitch * (1.0 + 0.6 * np.exp(-t * 40.0))
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    body = np.sin(phase) * np.exp(-t * 22.0)
    knock = rng.standard_normal(length) * np.exp(-t * 90.0)
    b, a = signal.butter(2, 400.0 / (RATE / 2), btype="low")
    knock = signal.lfilter(b, a, knock) * 0.6
    shape = (body + knock) * loud
    attack = int(RATE * 0.004)
    shape[:attack] *= np.linspace(0.0, 1.0, attack)
    end = min(start + length, count)
    out[start:end] += shape[: end - start]
    return out


def render(seed: int, lub: float, dub: float, gap: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    count = int(RATE * LENGTH)
    mixed = thump(rng, count, 0, lub, 1.0) + thump(rng, count, int(RATE * gap), dub, 0.7)
    fade_out = int(RATE * 0.01)
    mixed[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    return mixed / max(np.max(np.abs(mixed)), 1e-9) * 0.8


def main() -> None:
    ffmpeg = find_ffmpeg()
    os.makedirs(OUT, exist_ok=True)
    for index, take in enumerate(TAKES, start=1):
        pcm = (np.clip(render(*take), -1.0, 1.0) * 32767.0).astype(np.int16)
        with tempfile.TemporaryDirectory() as scratch:
            wav_path = os.path.join(scratch, "beat.wav")
            with wave.open(wav_path, "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(2)
                handle.setframerate(RATE)
                handle.writeframes(pcm.tobytes())
            target = os.path.abspath(os.path.join(OUT, "sfx_heartbeat_%d.ogg" % index))
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-ac", "1",
                            "-c:a", "libvorbis", "-q:a", "5", target], check=True)
            print("wrote", target)


if __name__ == "__main__":
    main()
