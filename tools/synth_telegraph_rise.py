"""Renders the telegraph riser, the anticipation a warned blow swells with.

    python tools/synth_telegraph_rise.py

Writes `game/audio/sfx/sfx_telegraph_rise_{1,2,3}.ogg`: three takes of a short
swell that *ends* where the blow lands - band-passed noise sweeping upward under
a soft tonal glide, rising in loudness to the last instant and cut with a few
milliseconds of fade so nothing clicks. `EnemyGroundStrike` starts one so that
it finishes on the frame the blow resolves, which is what makes it anticipation
rather than a second warning.

**Synthesised placeholders**, listed in `Sfx.PLACEHOLDERS` and in
`docs/SFX_PROMPTS.md` with a prompt for the recording that should replace them.
Mono, Vorbis q5, as every one-shot is (`tools/import_audio.py`). Seeded, so a
re-render writes the same files.
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

RATE = 44100
LENGTH = 0.72
TAKES = [
    # seed, low and high of the sweep in Hz, the glide's start and end in Hz
    (11, 380.0, 3200.0, 196.0, 588.0),
    (23, 320.0, 2800.0, 174.0, 523.0),
    (37, 440.0, 3600.0, 220.0, 660.0),
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


def render(seed: int, low: float, high: float, glide_from: float, glide_to: float) -> np.ndarray:
    rng = np.random.default_rng(seed)
    count = int(RATE * LENGTH)
    t = np.arange(count) / RATE
    share = t / LENGTH
    # The swell: slow at first, steepest at the end, which is how a thing
    # coming down on you sounds.
    envelope = share ** 2.6
    # Noise through a band-pass whose centre climbs, in blocks so the filter
    # can move.
    noise = rng.standard_normal(count)
    out = np.zeros(count)
    block = 512
    state = None
    for start in range(0, count, block):
        end = min(start + block, count)
        centre = low * (high / low) ** (start / count)
        band = (centre * 0.7 / (RATE / 2), min(centre * 1.4 / (RATE / 2), 0.98))
        b, a = signal.butter(2, band, btype="bandpass")
        if state is None:
            state = signal.lfilter_zi(b, a) * 0.0
        chunk, state = signal.lfilter(b, a, noise[start:end], zi=state)
        out[start:end] = chunk
    out /= max(np.max(np.abs(out)), 1e-9)
    # A tonal glide underneath, quieter, so it reads as rising rather than as
    # wind.
    freq = glide_from * (glide_to / glide_from) ** share
    phase = 2.0 * np.pi * np.cumsum(freq) / RATE
    tone = np.sin(phase) * 0.35 + np.sin(phase * 2.0) * 0.12
    # A shudder that quickens toward the end.
    shudder = 1.0 + 0.25 * np.sin(2.0 * np.pi * (6.0 + 20.0 * share) * t)
    mixed = (out * 0.8 + tone) * envelope * shudder
    # Faded in over the first 10 ms and out over the last 6, so neither end
    # clicks.
    fade_in = int(RATE * 0.010)
    fade_out = int(RATE * 0.006)
    mixed[:fade_in] *= np.linspace(0.0, 1.0, fade_in)
    mixed[-fade_out:] *= np.linspace(1.0, 0.0, fade_out)
    peak = np.max(np.abs(mixed))
    return mixed / peak * 0.7


def main() -> None:
    ffmpeg = find_ffmpeg()
    os.makedirs(OUT, exist_ok=True)
    for index, take in enumerate(TAKES, start=1):
        data = render(*take)
        pcm = (np.clip(data, -1.0, 1.0) * 32767.0).astype(np.int16)
        with tempfile.TemporaryDirectory() as scratch:
            wav_path = os.path.join(scratch, "rise.wav")
            with wave.open(wav_path, "wb") as handle:
                handle.setnchannels(1)
                handle.setsampwidth(2)
                handle.setframerate(RATE)
                handle.writeframes(pcm.tobytes())
            target = os.path.abspath(os.path.join(OUT, "sfx_telegraph_rise_%d.ogg" % index))
            subprocess.run([ffmpeg, "-y", "-loglevel", "error", "-i", wav_path, "-ac", "1",
                            "-c:a", "libvorbis", "-q:a", "5", target], check=True)
            print("wrote", target)


if __name__ == "__main__":
    main()
