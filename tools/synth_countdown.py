"""Renders the breather's countdown: a tick, a warning tick and a final beat.

    python tools/synth_countdown.py

Writes `game/audio/sfx/sfx_countdown_tick_1.ogg`, `sfx_countdown_warn_1.ogg` and
`sfx_countdown_final_1.ogg` (owner, 2026-10-08: "Countdown SFX for the last 10
seconds of preparation with increasing indication for the last 5 and especially
the last 3"). The HUD plays the tick on 10 to 6, the warning on 5 and 4, and the
final beat on 3, 2 and 1, each a little higher than the last.

- **tick**: a dry wooden clock tick - a short filtered click.
- **warn**: a brighter wood block with a short ring, an octave above.
- **final**: a low drum struck under a small bell, the one a player hears from
  across the room.

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
OUT = os.path.join(os.path.dirname(__file__), "..", "game", "audio", "sfx")


def find_ffmpeg() -> str:
    for candidate in ("ffmpeg", r"C:\ffmpeg-7.1.1-essentials_build\bin\ffmpeg.exe"):
        try:
            subprocess.run([candidate, "-version"], capture_output=True, check=True)
            return candidate
        except (OSError, subprocess.CalledProcessError):
            continue
    raise SystemExit("ffmpeg not found")


def tone(length: float, freq: float, decay: float, drop: float = 0.0) -> np.ndarray:
    t = np.arange(int(RATE * length)) / RATE
    f = freq * (1.0 + drop * np.exp(-t * 35.0))
    return np.sin(2.0 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * decay)


def click(rng, length: float, centre: float, decay: float) -> np.ndarray:
    count = int(RATE * length)
    t = np.arange(count) / RATE
    noise = rng.standard_normal(count)
    b, a = signal.butter(2, [centre * 0.6 / (RATE / 2), min(centre * 1.6 / (RATE / 2), 0.99)], btype="band")
    return signal.lfilter(b, a, noise) * np.exp(-t * decay)


def finish(mixed: np.ndarray, loud: float) -> np.ndarray:
    attack = int(RATE * 0.002)
    mixed[:attack] *= np.linspace(0.0, 1.0, attack)
    tail = int(RATE * 0.01)
    mixed[-tail:] *= np.linspace(1.0, 0.0, tail)
    return mixed / max(np.max(np.abs(mixed)), 1e-9) * loud


def render_tick() -> np.ndarray:
    rng = np.random.default_rng(31)
    length = 0.12
    mixed = click(rng, length, 2400.0, 70.0) * 0.9 + tone(length, 1700.0, 60.0) * 0.35
    return finish(mixed, 0.55)


def render_warn() -> np.ndarray:
    rng = np.random.default_rng(37)
    length = 0.2
    mixed = click(rng, length, 3200.0, 60.0) * 0.6 + tone(length, 880.0, 22.0) * 0.8 \
        + tone(length, 1320.0, 30.0) * 0.35
    return finish(mixed, 0.7)


def render_final() -> np.ndarray:
    rng = np.random.default_rng(41)
    length = 0.55
    drum = tone(length, 70.0, 9.0, drop=0.9)
    body = click(rng, length, 260.0, 18.0) * 0.5
    bell = (tone(length, 1180.0, 7.0) * 0.5 + tone(length, 2950.0, 11.0) * 0.18)
    mixed = drum * 1.0 + body + bell * 0.55
    return finish(mixed, 0.85)


def write(ffmpeg: str, name: str, samples: np.ndarray) -> None:
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype(np.int16)
    with tempfile.TemporaryDirectory() as scratch:
        wav_path = os.path.join(scratch, "take.wav")
        with wave.open(wav_path, "wb") as handle:
            handle.setnchannels(1)
            handle.setsampwidth(2)
            handle.setframerate(RATE)
            handle.writeframes(pcm.tobytes())
        target = os.path.abspath(os.path.join(OUT, name + ".ogg"))
        subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-ac", "1",
                        "-c:a", "libvorbis", "-q:a", "5", target], check=True)
        print("wrote", target)


def main() -> None:
    ffmpeg = find_ffmpeg()
    os.makedirs(OUT, exist_ok=True)
    write(ffmpeg, "sfx_countdown_tick_1", render_tick())
    write(ffmpeg, "sfx_countdown_warn_1", render_warn())
    write(ffmpeg, "sfx_countdown_final_1", render_final())


if __name__ == "__main__":
    main()
