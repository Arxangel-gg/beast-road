"""Renders the party's ping sounds, three takes of each.

    python tools/synth_ping.py

Writes `game/audio/sfx/sfx_ping_{1,2,3}.ogg` and `sfx_ping_alert_{1,2,3}.ogg`.
A ping is a word put on the field for the party (triage of 2026-10-07, item
63), so it is heard flat - it is a person speaking, not a thing happening at a
place - and it has to be told from every sound of the fight at once: two short
bell-like notes for an ordinary ping, a rising fifth that says "look"; three
quicker, brighter ones for a warning, falling, that says "careful".

**Synthesised placeholders**, prompted in `docs/SFX_PROMPTS.md` for a recording
to replace them. Mono, Vorbis q5. Seeded, so a re-render writes the same files.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "audio", "sfx")
# name, length, notes as (start seconds, pitch in Hz, loudness)
SOUNDS = {
    "sfx_ping": (0.42, [
        [(0.0, 880.0, 0.8), (0.085, 1318.5, 1.0)],
        [(0.0, 830.6, 0.8), (0.09, 1244.5, 1.0)],
        [(0.0, 932.3, 0.8), (0.08, 1396.9, 1.0)],
    ]),
    "sfx_ping_alert": (0.46, [
        [(0.0, 1567.9, 1.0), (0.07, 1318.5, 0.9), (0.14, 1046.5, 0.85)],
        [(0.0, 1661.2, 1.0), (0.068, 1396.9, 0.9), (0.136, 1108.7, 0.85)],
        [(0.0, 1480.0, 1.0), (0.072, 1244.5, 0.9), (0.144, 987.8, 0.85)],
    ]),
}


def find_ffmpeg() -> str:
    for candidate in ("ffmpeg", r"C:\ffmpeg-7.1.1-essentials_build\bin\ffmpeg.exe"):
        try:
            subprocess.run([candidate, "-version"], capture_output=True, check=True)
            return candidate
        except (OSError, subprocess.CalledProcessError):
            continue
    raise SystemExit("ffmpeg not found")


def bell(count: int, start: int, pitch: float, loud: float) -> np.ndarray:
    """A struck note: a fundamental and two inharmonic partials, each dying at
    its own rate, which is what separates a bell from a beep."""
    out = np.zeros(count)
    length = min(int(RATE * 0.34), count - start)
    if length <= 0:
        return out
    t = np.arange(length) / RATE
    tone = (np.sin(2.0 * np.pi * pitch * t) * np.exp(-t * 11.0)
            + 0.45 * np.sin(2.0 * np.pi * pitch * 2.76 * t) * np.exp(-t * 24.0)
            + 0.22 * np.sin(2.0 * np.pi * pitch * 5.40 * t) * np.exp(-t * 40.0))
    attack = int(RATE * 0.003)
    tone[:attack] *= np.linspace(0.0, 1.0, attack)
    out[start:start + length] += tone * loud
    return out


def render(length: float, notes: list) -> np.ndarray:
    count = int(RATE * length)
    mixed = np.zeros(count)
    for start, pitch, loud in notes:
        mixed += bell(count, int(RATE * start), pitch, loud)
    fade_out = int(RATE * 0.02)
    mixed[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    return mixed / max(np.max(np.abs(mixed)), 1e-9) * 0.8


def main() -> None:
    ffmpeg = find_ffmpeg()
    os.makedirs(OUT, exist_ok=True)
    for name, (length, takes) in SOUNDS.items():
        for index, notes in enumerate(takes, start=1):
            pcm = (np.clip(render(length, notes), -1.0, 1.0) * 32767.0).astype(np.int16)
            with tempfile.TemporaryDirectory() as scratch:
                wav_path = os.path.join(scratch, "ping.wav")
                with wave.open(wav_path, "wb") as handle:
                    handle.setnchannels(1)
                    handle.setsampwidth(2)
                    handle.setframerate(RATE)
                    handle.writeframes(pcm.tobytes())
                target = os.path.abspath(os.path.join(OUT, "%s_%d.ogg" % (name, index)))
                subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-ac", "1",
                                "-c:a", "libvorbis", "-q:a", "5", target], check=True)
                print("wrote", target)


if __name__ == "__main__":
    main()
