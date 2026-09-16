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

# Vorbis quality.
#
# **Music sits at 1, and that is a size decision made on purpose.** Eighty-eight
# songs at q4 were 222 MB of a 300 MB game, and the owner asked for the download
# back (2026-09-13). q1 is roughly 80 kbps stereo: on a track playing under
# combat, footsteps, a war horn and weather it is not the thing anybody will
# hear, and it takes better than a third off every file. Sound effects stay at 5
# because they are short, sharp and exposed - a cymbal artefact on a sword swing
# is audible in a way a slightly softer string pad is not.
QUALITY = {"music": 1, "ambience": 3, "sfx": 5}

# **Measured on 2026-09-16, so the next size conversation starts from a number.**
# Re-encoding one shipped 2-minute track at each setting, against its current
# size: q0 is 82%, q1 is 96%, q2 is 105%. So dropping music to q0 would take
# about 18% off - roughly 25 MB of today's 139 MB, and nearer 45 MB once the
# sixty-one act songs and ten boss themes still to be written have landed.
#
# It is left at 1 deliberately. That saving is a *quality* decision on a
# commissioned soundtrack rather than a technical one, and re-encoding an
# existing lossy file adds generation loss on top of the setting - so the honest
# move is to change this before a batch is imported, never afterwards. Everything
# else in this file only ever removes waste: a one-shot's unusable second
# channel, dead air, a file heavier than the setting beside it.


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
        # **One-shots are mono, and that is correctness before it is size.**
        # `Sfx` plays every effect through a plain `AudioStreamPlayer` and does
        # its own distance attenuation in `play_at`; nothing ever pans a stream.
        # A stereo one-shot therefore stores a second channel the game can never
        # use, at roughly twice the bytes. Music and ambience stay stereo - they
        # are beds and the width is the point.
        *(["-ac", "1"] if kind == "sfx" else []),
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


VARIATION = re.compile(r"^(.*?)[_ -]*#(\d+)-(\d+)$")


def parse_generated(stem: str) -> tuple:
    """`sfx_boss_fall_-_a_bo_#2-17895` -> ("sfx_boss_fall", 2, "17895").

    **ElevenLabs names a file after the prompt, not after the sound**, so a batch
    arrives as `<id>_-_<first words of the prompt>_#<variation>-<timestamp>.wav`.
    The id is the part before the prompt text, which is recovered by matching the
    longest known id that the stem starts with - guessing at the underscore would
    cut `sfx_boss_fall` down to `sfx_boss`.

    Returns ("", 0, "") for anything that is not a generated take, so an ordinary
    hand-named file still imports exactly as it did.
    """
    match = VARIATION.match(stem)
    if not match:
        return ("", 0, "")
    return (match.group(1), int(match.group(2)), match.group(3))


def known_ids() -> list:
    """Every sound id the prompts doc knows, longest first."""
    ids = []
    if os.path.exists(MANIFEST):
        text = io.open(MANIFEST, encoding="utf-8").read()
        ids = re.findall(r"^\|\s*`([a-z0-9_]+)`", text, re.M)
    return sorted(set(ids), key=len, reverse=True)


def id_from_prompt_name(stem: str, ids: list) -> str:
    """The longest known id this generated filename begins with."""
    cleaned = stem.rstrip("_- ")
    for known in ids:
        if cleaned == known:
            return known
        # Any non-id character may follow: a generator writes the prompt after
        # the id, and one batch arrived with the extension typed into the prompt
        # box as well ("sfx_wildlife_frog.og_#1-..."). Matching only on "_" lost
        # that whole sound in silence.
        if cleaned.startswith(known) and not cleaned[len(known):len(known) + 1].isalnum():
            return known
    return ""


## How many takes of one sound are kept.
#
# **Three, and the rest are thrown away deliberately.** A generator hands back
# four or more takes of every prompt and it is tempting to ship them all, but
# variety in this game comes from two axes multiplied together: the sample, and
# the per-play pitch drift every MIX row already carries. Three samples against a
# 0.08 drift is more distinct outcomes than anybody can hear in a session, and
# the fourth take is pure download.
VARIATIONS_PER_SOUND = 3


def install_generated_batch(ffmpeg, folder, manifest):
    """A folder of generated takes -> numbered variations in the game.

    Handles the shape a generator actually produces: several takes per prompt,
    named after the prompt, with a variation number and a timestamp. Takes are
    grouped by the sound they belong to, one kept per variation number (the
    earliest, so a re-run of this is stable), and installed as `<id>_1.ogg` and
    up when more than one survives.
    """
    ids = known_ids()
    batch = {}
    for entry in sorted(os.listdir(folder)):
        stem, ext = os.path.splitext(entry)
        if ext.lower() not in (".mp3", ".wav", ".ogg", ".flac", ".m4a"):
            continue
        prompt_stem, variation, stamp = parse_generated(stem)
        if not prompt_stem:
            prompt_stem, variation, stamp = stem, 1, ""
        sound = id_from_prompt_name(prompt_stem, ids)
        if not sound:
            print("  ? cannot place %s" % entry)
            continue
        batch.setdefault(sound, {}).setdefault(variation, []).append((stamp, entry))

    installed = []
    for sound in sorted(batch):
        kind = kind_of(sound, manifest)
        if not kind:
            print("  ? %s is not in the manifest" % sound)
            continue
        # **Only one-shots get variations.** Music and ambience are single
        # looping beds addressed by an exact filename - `Ambience.BEDS` maps
        # "downpour" to one file - so installing `weather_downpour_1.ogg` would
        # leave the bed the game asks for missing, and the region silent.
        wanted = VARIATIONS_PER_SOUND if kind == "sfx" else 1
        # **A wildlife voice wants four.** `audio_verify` has required it of
        # every species since they were recorded - an animal that vocalises
        # often needs a longer loop than a one-shot fired once a run.
        if sound.startswith("sfx_wildlife_"):
            wanted = max(wanted, 4)
        chosen = []
        for variation in sorted(batch[sound]):
            chosen.append(sorted(batch[sound][variation])[0][1])
            if len(chosen) >= wanted:
                break
        out = os.path.join(AUDIO, kind)
        os.makedirs(out, exist_ok=True)
        for index, entry in enumerate(chosen, 1):
            name = sound if len(chosen) == 1 else "%s_%d" % (sound, index)
            dst = os.path.join(out, name + ".ogg")
            code, err = convert(ffmpeg, os.path.join(folder, entry), dst, kind)
            if code != 0 or not os.path.exists(dst):
                print("  x %s: %s" % (name, (err or "ffmpeg failed").splitlines()[-1]))
                continue
            installed.append((name, kind, os.path.getsize(dst)))
        print("  %-24s %-9s %d take%s" % (
            sound, kind, len(chosen), "" if len(chosen) == 1 else "s"))
    return installed


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
        if os.path.isdir(path):
            # A folder is a generated batch: several takes per prompt, named
            # after the prompt rather than after the sound.
            print("BATCH %s" % entry)
            for name, kind, after in install_generated_batch(ffmpeg, path, manifest):
                installed.append((name, kind, 0, after, duration(ffmpeg,
                    os.path.join(AUDIO, kind, name + ".ogg"))))
            continue
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
