"""Converts audio_inbox/ into game/audio/, via ffmpeg.

Three things happen here, and each of them is load-bearing:

1. **Everything becomes OGG Vorbis.** Godot cannot loop an MP3 seamlessly - the
   format pads the start and end of every file, so a looping MP3 audibly ticks.
   OGG has no such padding.

2. **Loudness is normalised per category, not globally.** A war horn and an
   ambience bed should not arrive at the same level. Music sits under gameplay,
   ambience sits under the music, one-shots sit on top. Normalising everything
   to one target is what makes a mix where the player rides the volume slider.

3. **One-shots get their silence trimmed.** A generated sound effect usually has
   a few hundred milliseconds of dead air at the front, which turns every hit
   into a hit that arrives late. Music is *not* trimmed - cutting its head off
   would break the loop.

Run:  python tools/import_audio.py
      python tools/import_audio.py sfx_new_take_1.mp3 sfx_new_take_2.wav

Passing filenames limits the conversion to those inbox entries. This keeps a
new recording batch from needlessly re-encoding every previously imported
master while preserving the original no-argument full-inbox workflow.
"""
import io
import os
import re
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INBOX = os.path.join(ROOT, "audio_inbox")
AUDIO = os.path.join(ROOT, "game", "audio")
MANIFEST = os.path.join(AUDIO, "AUDIO_MANIFEST.md")

# Integrated loudness targets in LUFS. Lower is quieter.
TARGETS = {
    "music": -19.0,
    "ambience": -27.0,
    "sfx": -14.0,
}

# Vorbis quality. 4 is transparent enough for game audio and roughly halves the
# size of the mp3s coming in.
QUALITY = {"music": 4, "ambience": 3, "sfx": 5}


def find_ffmpeg() -> str:
    exe = shutil.which("ffmpeg")
    if exe:
        return exe
    for guess in (
        r"C:\ffmpeg-7.1.1-essentials_build\bin\ffmpeg.exe",
        r"C:\ffmpeg\bin\ffmpeg.exe",
    ):
        if os.path.exists(guess):
            return guess
    return ""


def read_manifest() -> dict:
    """id -> kind, from the generated audio manifest."""
    out = {}
    if not os.path.exists(MANIFEST):
        return out
    text = io.open(MANIFEST, encoding="utf-8").read()
    for row in re.finditer(r"^\|\s*`([a-z0-9_]+)`\s*\|\s*`[^`]+`\s*\|\s*(\w+)\s*\|", text, re.M):
        out[row.group(1)] = row.group(2)
    return out


def kind_of(name: str, manifest: dict) -> str:
    if name in manifest:
        return manifest[name]
    # Fall back to the prefix, so a file named correctly still lands correctly
    # even if the manifest has not been regenerated.
    if name.startswith("music_"):
        return "music"
    if name.startswith("ambience_"):
        return "ambience"
    if name.startswith("sfx_"):
        return "sfx"
    return ""


def convert(ffmpeg: str, src: str, dst: str, kind: str) -> tuple:
    filters = []
    if kind == "sfx":
        # Trim dead air from both ends. A generated one-shot usually opens with
        # a few hundred ms of nothing, which makes every impact land late.
        filters.append(
            "silenceremove=start_periods=1:start_duration=0:start_threshold=-50dB"
            ":detection=peak,areverse,"
            "silenceremove=start_periods=1:start_duration=0:start_threshold=-50dB"
            ":detection=peak,areverse"
        )
    filters.append("loudnorm=I=%.1f:TP=-1.5:LRA=11" % TARGETS[kind])

    cmd = [
        ffmpeg, "-y", "-hide_banner", "-loglevel", "error",
        "-i", src,
        "-af", ",".join(filters),
        "-c:a", "libvorbis", "-q:a", str(QUALITY[kind]),
        "-ar", "44100",
        dst,
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    return proc.returncode, (proc.stderr or "").strip()


def duration(ffmpeg: str, path: str) -> float:
    beside = os.path.join(os.path.dirname(ffmpeg), "ffprobe.exe")
    probe = beside if os.path.exists(beside) else (shutil.which("ffprobe") or "")
    if not probe:
        return 0.0
    try:
        out = subprocess.run(
            [probe, "-v", "error", "-show_entries", "format=duration",
             "-of", "csv=p=0", path],
            capture_output=True, text=True).stdout.strip()
        return float(out)
    except (ValueError, OSError):
        return 0.0


def main() -> int:
    ffmpeg = find_ffmpeg()
    if not ffmpeg:
        print("ffmpeg not found. Install it or add it to PATH.")
        return 1
    print("ffmpeg:", ffmpeg)

    manifest = read_manifest()
    installed, skipped, failed = [], [], []

    entries = sorted(sys.argv[1:]) if len(sys.argv) > 1 else sorted(os.listdir(INBOX))
    for entry in entries:
        # Arguments are inbox filenames, never arbitrary paths. Keeping the
        # source root fixed prevents a typo from writing an unrelated recording
        # into the shipping audio tree.
        if os.path.basename(entry) != entry:
            skipped.append((entry, "must be a filename in audio_inbox/"))
            continue
        path = os.path.join(INBOX, entry)
        if not os.path.isfile(path):
            continue
        stem, ext = os.path.splitext(entry)
        if ext.lower() not in (".mp3", ".wav", ".ogg", ".flac", ".m4a"):
            skipped.append((entry, "not an audio file"))
            continue

        name = stem.strip()
        kind = kind_of(name, manifest)
        if not kind:
            skipped.append((entry, "cannot tell what this is - rename it to an id from SFX_PROMPTS.md"))
            continue

        folder = os.path.join(AUDIO, kind)
        os.makedirs(folder, exist_ok=True)
        dst = os.path.join(folder, name + ".ogg")

        code, err = convert(ffmpeg, path, dst, kind)
        if code != 0 or not os.path.exists(dst):
            failed.append((entry, err.splitlines()[-1] if err else "ffmpeg failed"))
            continue

        before = os.path.getsize(path)
        after = os.path.getsize(dst)
        installed.append((name, kind, before, after, duration(ffmpeg, dst)))

    print("\nINSTALLED - %d" % len(installed))
    total_before = total_after = 0
    for name, kind, before, after, secs in installed:
        total_before += before
        total_after += after
        print("  %-26s %-9s %6.1fs  %5.0f KB -> %5.0f KB" % (
            name, kind, secs, before / 1024.0, after / 1024.0))

    if skipped:
        print("\nSKIPPED - %d" % len(skipped))
        for entry, why in skipped:
            print("  %s - %s" % (entry, why))
    if failed:
        print("\nFAILED - %d" % len(failed))
        for entry, why in failed:
            print("  %s - %s" % (entry, why))

    if total_before:
        print("\ntotal %.1f MB -> %.1f MB  (%.0f%% of original)" % (
            total_before / 1048576.0, total_after / 1048576.0,
            100.0 * total_after / total_before))
    return 1 if failed else 0


sys.exit(main())
