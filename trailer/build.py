#!/usr/bin/env python
"""Cuts, titles, scores and encodes the Wilderhold trailer.

Everything on screen was filmed from the running game by trailer/capture.sh
(one Movie Maker recording a shot, in trailer/work). This script reads the edit
in trailer/edit.json and makes:

  trailer/out/wilderhold_trailer_master.mov   ProRes 422 HQ, PCM 24-bit, 1080p60 - the archival master
  trailer/out/wilderhold_trailer.mp4          H.264 High, AAC, 1080p60, web-ready - the standalone film
  game/video/trailer.ogv                      Theora + Vorbis, 720p30 - what the game plays at startup
  trailer/contact_sheet.jpg                   a frame from every cut, with its timecode and title
  trailer/qa.json                             durations, loudness, true peak, sizes - measured, not assumed

    python trailer/build.py            # everything
    python trailer/build.py --preview  # a quick 540p30 cut to trailer/work/preview.mp4
    python trailer/build.py --encode   # the deliveries again from the master on disk

The score is the game's own main theme (game/audio/music/music_menu.ogg): its
quiet opening under the first act of the edit and its build under the second,
joined at the place where the two sound most alike. The world's own sound -
every blow, horn and strike filmed with the picture - sits underneath it.
"""

import json
import os
import subprocess
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TRAILER = os.path.join(ROOT, "trailer")
WORK = os.path.join(TRAILER, "work")
OUT = os.path.join(TRAILER, "out")
FFDIR = os.environ.get("FFMPEG_DIR", "C:/ffmpeg-7.1.1-essentials_build/bin")
FF = os.path.join(FFDIR, "ffmpeg")
PROBE = os.path.join(FFDIR, "ffprobe")
FONT = os.path.join(ROOT, "game", "fonts", "Cinzel-Variable.ttf")
W, H = 1920, 1080


def run(args, quiet=True):
    result = subprocess.run(args, capture_output=True, text=True)
    if result.returncode != 0:
        sys.stderr.write(result.stderr[-4000:])
        raise SystemExit("ffmpeg failed: " + " ".join(args[:6]) + " ...")
    return result


def roll_frame(shot):
    """The frame the harness said the shot was ready on (the calibration flash's frame)."""
    with open(os.path.join(WORK, shot + ".log"), encoding="utf-8", errors="replace") as log:
        for line in log:
            if line.startswith("[trailer] roll "):
                return int(line.split()[2])
    raise SystemExit("no roll in %s.log - film it again with trailer/capture.sh %s" % (shot, shot))


def title_card(text, path, size=78, weight=600, tracking=0.08):
    """A title as a transparent 1920x1080 PNG: Cinzel, tracked, with a soft shadow
    and a thin ember rule beneath - the game's own Title face."""
    font = ImageFont.truetype(FONT, size)
    font.set_variation_by_axes([weight])
    spacing = size * tracking
    widths = [font.getlength(ch) for ch in text]
    total = sum(widths) + spacing * (len(text) - 1)
    ascent, descent = font.getmetrics()
    x0 = (W - total) / 2.0
    y0 = H * 0.70 - (ascent + descent) / 2.0
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    text_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ds = ImageDraw.Draw(shadow)
    dt = ImageDraw.Draw(text_layer)
    x = x0
    for ch, cw in zip(text, widths):
        ds.text((x + 3, y0 + 4), ch, font=font, fill=(0, 0, 0, 210))
        dt.text((x, y0), ch, font=font, fill=(244, 232, 208, 255))
        x += cw + spacing
    shadow = shadow.filter(ImageFilter.GaussianBlur(9))
    rule_y = int(y0 + ascent + descent + size * 0.32)
    half = int(min(total * 0.42, 360))
    for dx in range(-half, half):
        fade = 1.0 - abs(dx) / float(half)
        alpha = int(200 * fade * fade)
        for dy, k in ((0, 1.0), (1, 0.45)):
            text_layer.putpixel((W // 2 + dx, rule_y + dy), (232, 163, 61, int(alpha * k)))
    card = Image.alpha_composite(shadow, text_layer)
    card.save(path)


def decode(path, rate):
    result = subprocess.run([FF, "-v", "error", "-i", path, "-ac", "1", "-ar", str(rate),
                             "-f", "f32le", "-"], capture_output=True)
    return np.frombuffer(result.stdout, dtype=np.float32)


def best_seam(music, a_end, b_from, search, seam):
    """Where to begin section B so the crossfade joins two moments that sound alike:
    the start of B's window whose spectrum best matches the tail of A."""
    rate = 11025
    signal = decode(music, rate)
    n, hop = 2048, 512

    def spectrum(at, length):
        start = int(at * rate)
        chunk = signal[start:start + int(length * rate)]
        frames = [np.abs(np.fft.rfft(chunk[i:i + n] * np.hanning(n)))
                  for i in range(0, max(len(chunk) - n, 1), hop)]
        mean = np.mean(frames, axis=0) if frames else np.zeros(n // 2 + 1)
        return mean / (np.linalg.norm(mean) + 1e-9)

    tail = spectrum(a_end - seam, seam)
    best, best_at = -1.0, b_from
    for step in np.arange(-search, search + 0.001, 0.1):
        at = b_from + step
        if at < 0:
            continue
        score = float(np.dot(tail, spectrum(at, seam)))
        if score > best:
            best, best_at = score, at
    return round(best_at, 2), best


def build(preview=False):
    with open(os.path.join(TRAILER, "edit.json"), encoding="utf-8") as f:
        edit = json.load(f)
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(WORK, exist_ok=True)
    fps = 30 if preview else 60
    scale_w, scale_h = (960, 540) if preview else (W, H)
    cuts = edit["cuts"]
    grade = edit.get("grade", "")

    # --- the picture and the world's sound, cut by cut ---------------------------
    inputs, chains, timeline = [], [], []
    for index, cut in enumerate(cuts):
        roll = roll_frame(cut["shot"])
        start = (roll + 2) / 60.0 + float(cut.get("in", 0.0))
        length = float(cut["len"])
        inputs += ["-ss", "%.4f" % start, "-t", "%.4f" % (length + 0.6),
                   "-i", os.path.join(WORK, cut["shot"] + ".avi")]
        crop = cut.get("crop")
        # Trimmed first, the frame rate stated last: xfade refuses a stream
        # whose rate the trim has left unknown.
        vf = ["trim=duration=%.4f,setpts=PTS-STARTPTS" % length]
        if crop:
            vf.append("crop=%d:%d:%d:%d" % tuple(crop))
        vf.append("scale=%d:%d:flags=lanczos" % (scale_w, scale_h))
        if cut.get("grade", grade):
            vf.append(cut.get("grade", grade))
        vf.append("setsar=1,format=yuv420p,fps=%d,settb=AVTB" % fps)
        chains.append("[%d:v]%s[v%d]" % (index, ",".join(vf), index))
        gain = float(cut.get("sfx_db", 0.0))
        chains.append("[%d:a]aresample=48000,atrim=duration=%.4f,asetpts=PTS-STARTPTS,volume=%.1fdB[a%d]"
                      % (index, length, gain, index))
        timeline.append((length, cut))
    # **Laid on a timeline rather than chained.** Each cut is placed at its own
    # start over a black ground and the next lies on top of it, fading in where
    # the edit asks for a dissolve. Chained xfades froze a picture whenever a
    # stream came up a frame short of its offset; an overlay cannot.
    starts = []
    for index, cut in enumerate(cuts):
        if index == 0:
            starts.append(0.0)
        else:
            starts.append(starts[-1] + float(cuts[index - 1]["len"]) - float(cut.get("dissolve", 0.0)))
    total = starts[-1] + float(cuts[-1]["len"])
    chains.append("color=c=black:s=%dx%d:r=%d:d=%.4f,format=yuv420p,settb=AVTB[base]"
                  % (scale_w, scale_h, fps, total))
    v_prev = "base"
    audio = []
    for index, cut in enumerate(cuts):
        d = float(cut.get("dissolve", 0.0)) if index > 0 else 0.0
        lay = "[v%d]" % index
        if d > 0.0:
            chains.append("[v%d]format=yuva420p,fade=in:st=0:d=%.3f:alpha=1[f%d]" % (index, d, index))
            lay = "[f%d]" % index
        chains.append("%ssetpts=PTS+%.4f/TB[p%d]" % (lay, starts[index], index))
        chains.append("[%s][p%d]overlay=eof_action=pass:format=auto[o%d]" % (v_prev, index, index))
        v_prev = "o%d" % index
        # Its sound fades in over the dissolve (or a breath) and out over the next.
        nxt = cuts[index + 1] if index + 1 < len(cuts) else None
        d_out = max(float(nxt.get("dissolve", 0.0)) if nxt else 0.0, 0.03)
        length = float(cut["len"])
        delay = int(round(starts[index] * 1000.0))
        chains.append("[a%d]afade=in:st=0:d=%.3f,afade=out:st=%.3f:d=%.3f,adelay=%d|%d[d%d]"
                      % (index, max(d, 0.03), max(length - d_out, 0.0), d_out, delay, delay, index))
        audio.append("[d%d]" % index)
    chains.append("%samix=inputs=%d:normalize=0:duration=longest,atrim=duration=%.4f[world_raw]"
                  % ("".join(audio), len(audio), total))
    a_prev = "world_raw"

    # --- titles -----------------------------------------------------------------
    titles = [c for c in timeline if c[1].get("title")]
    for number, (_, cut) in enumerate(titles):
        png = os.path.join(WORK, "title_%02d.png" % number)
        title_card(cut["title"], png, size=int(cut.get("title_size", 74)))
        inputs += ["-loop", "1", "-framerate", str(fps), "-t", "%.3f" % total, "-i", png]
    first_title = len(cuts)
    v_now = v_prev
    for number, (_, cut) in enumerate(titles):
        at = starts[cuts.index(cut)] + float(cut.get("t_in", 0.6))
        hold = float(cut.get("t_len", 2.6))
        fade = 0.45
        label = "t%d" % number
        chains.append("[%d:v]scale=%d:%d,format=rgba,fade=in:st=%.3f:d=%.2f:alpha=1,"
                      "fade=out:st=%.3f:d=%.2f:alpha=1[%s]"
                      % (first_title + number, scale_w, scale_h, at, fade, at + hold - fade, fade, label))
        chains.append("[%s][%s]overlay=0:0:format=auto:shortest=0[vt%d]" % (v_now, label, number))
        v_now = "vt%d" % number
    fade_in = float(edit.get("fade_in", 0.8))
    fade_out = float(edit.get("fade_out", 1.2))
    chains.append("[%s]trim=duration=%.4f,fade=in:st=0:d=%.2f,fade=out:st=%.3f:d=%.2f[vout]"
                  % (v_now, total, fade_in, total - fade_out, fade_out))

    # --- the score ----------------------------------------------------------------
    music = edit["music"]
    track = os.path.join(ROOT, music["file"])
    sections = music["sections"]
    seam = float(music.get("seam", 2.0))
    b_from, likeness = best_seam(track, float(sections[0]["to"]), float(sections[1]["from"]),
                                 float(music.get("search", 4.0)), seam)
    a_len = float(sections[0]["to"]) - float(sections[0]["from"])
    b_len = total - a_len + seam + 0.5
    inputs += ["-i", track]
    music_index = sum(1 for x in inputs if x == "-i") - 1
    chains.append("[%d:a]asplit=2[ma][mb]" % music_index)
    chains.append("[ma]atrim=start=%.3f:end=%.3f,asetpts=PTS-STARTPTS[m1]"
                  % (float(sections[0]["from"]), float(sections[0]["to"])))
    chains.append("[mb]atrim=start=%.3f:duration=%.3f,asetpts=PTS-STARTPTS[m2]" % (b_from, b_len))
    chains.append("[m1][m2]acrossfade=d=%.2f:c1=qsin:c2=qsin,aresample=48000,"
                  "volume=%.1fdB,afade=in:st=0:d=1.2,afade=out:st=%.3f:d=%.2f,atrim=duration=%.4f[score]"
                  % (seam, float(music.get("gain_db", 0.0)), total - float(music.get("fade_out", 3.0)),
                     float(music.get("fade_out", 3.0)), total))
    chains.append("[%s]volume=%.1fdB,afade=in:st=0:d=0.6,afade=out:st=%.3f:d=%.2f[world]"
                  % (a_prev, float(edit.get("sfx_db", -10.0)), total - fade_out, fade_out))
    chains.append("[score][world]amix=inputs=2:normalize=0:duration=first[mix]")

    graph = ";".join(chains)
    if os.environ.get("TRAILER_DEBUG"):
        print(chr(10).join(chains))
        print(" ".join(inputs))
    mezz = os.path.join(WORK, "preview.mp4" if preview else "mezzanine.mov")
    codec = (["-c:v", "libx264", "-preset", "veryfast", "-crf", "22", "-c:a", "aac", "-b:a", "192k"]
             if preview else
             ["-c:v", "prores_ks", "-profile:v", "3", "-pix_fmt", "yuv422p10le", "-c:a", "pcm_s24le"])
    run([FF, "-v", "error", "-y"] + inputs + ["-filter_complex", graph, "-map", "[vout]", "-map", "[mix]",
                                               "-r", str(fps)] + codec + [mezz])
    print("cut: %.2fs, %d cuts, %d titles, seam at %.2fs of the score (likeness %.3f) -> %s"
          % (total, len(cuts), len(titles), b_from, likeness, mezz))
    if preview:
        return
    finish(edit, mezz, total, timeline, starts)


def loudness(path):
    result = subprocess.run([FF, "-hide_banner", "-nostats", "-i", path, "-af",
                             "loudnorm=I=-14:TP=-1.0:LRA=11:print_format=json", "-f", "null", "-"],
                            capture_output=True, text=True)
    text = result.stderr
    return json.loads(text[text.rindex("{"):text.rindex("}") + 1])


def finish(edit, mezz, total, timeline, starts):
    # Two-pass loudness: measure, then normalise linearly to -14 LUFS, -1 dBTP.
    target = edit.get("loudness", {"I": -14.0, "TP": -1.0})
    measured = loudness(mezz)
    norm = ("loudnorm=I=%.1f:TP=%.1f:LRA=11:measured_I=%s:measured_TP=%s:measured_LRA=%s:"
            "measured_thresh=%s:offset=%s:linear=true:print_format=summary"
            % (target["I"], target["TP"], measured["input_i"], measured["input_tp"], measured["input_lra"],
               measured["input_thresh"], measured["target_offset"]))
    master = os.path.join(OUT, "wilderhold_trailer_master.mov")
    run([FF, "-v", "error", "-y", "-i", mezz, "-c:v", "copy", "-af", norm + ",aresample=48000",
         "-c:a", "pcm_s24le", master])
    encode(edit, master, total, timeline, starts)


def encode(edit, master, total, timeline, starts):
    """The two delivery encodes from the master, the contact sheet and the QA.

    Sized by measurement rather than by a quality number: this footage is
    dithered pixel art, which a constant quality spends without limit on - the
    first build at CRF 16 and Theora q7 came out at 555 MB and 174 MB. The MP4
    is capped at YouTube's own 1080p60 rate; the game's copy gets a bitrate
    chosen by comparing frames against the master, and a light temporal
    denoise, because Theora spends most of its bits on dither."""
    mp4 = os.path.join(OUT, "wilderhold_trailer.mp4")
    run([FF, "-v", "error", "-y", "-i", master, "-c:v", "libx264", "-preset", "slow", "-crf", "20",
         "-maxrate", "12M", "-bufsize", "24M", "-g", "120",
         "-profile:v", "high", "-pix_fmt", "yuv420p", "-movflags", "+faststart",
         "-c:a", "aac", "-b:a", "320k", "-ar", "48000", mp4])
    ogv = os.path.join(ROOT, "game", "video", "trailer.ogv")
    os.makedirs(os.path.dirname(ogv), exist_ok=True)
    runtime = edit.get("runtime", {"width": 1280, "height": 720, "fps": 30, "kbps": 3600, "aq": 4})
    run([FF, "-v", "error", "-y", "-i", master,
         "-vf", "scale=%d:%d:flags=lanczos,fps=%d,hqdn3d=0.8:0.8:3:3"
         % (runtime["width"], runtime["height"], runtime["fps"]),
         "-c:v", "libtheora", "-b:v", "%dk" % runtime["kbps"], "-g", str(runtime["fps"] * 2),
         "-c:a", "libvorbis", "-q:a", str(runtime["aq"]), "-ar", "48000", "-ac", "2", ogv])
    sheet(timeline, starts, mp4)
    qa(edit, master, mp4, ogv, total)


def sheet(timeline, starts, mp4):
    """A frame from the middle of every cut, labelled with its timecode and title."""
    tiles = []
    for index, (length, cut) in enumerate(timeline):
        at = starts[index] + min(length * 0.55, length - 0.2)
        png = os.path.join(WORK, "sheet_%02d.png" % index)
        run([FF, "-v", "error", "-y", "-ss", "%.3f" % at, "-i", mp4, "-frames:v", "1",
             "-vf", "scale=480:270", png])
        tile = Image.open(png).convert("RGB")
        draw = ImageDraw.Draw(tile)
        label = "%05.2fs  %s%s" % (starts[index], cut["shot"], ("  - " + cut["title"]) if cut.get("title") else "")
        draw.rectangle((0, 246, 480, 270), fill=(0, 0, 0))
        draw.text((6, 251), label, fill=(240, 230, 210))
        tiles.append(tile)
    columns = 4
    rows = (len(tiles) + columns - 1) // columns
    board = Image.new("RGB", (480 * columns, 270 * rows), (12, 12, 12))
    for index, tile in enumerate(tiles):
        board.paste(tile, ((index % columns) * 480, (index // columns) * 270))
    board.save(os.path.join(TRAILER, "contact_sheet.jpg"), quality=86)


def probe(path):
    out = run([PROBE, "-v", "error", "-show_entries", "format=duration,size:stream=codec_name,width,height,"
               "r_frame_rate,sample_rate,channels", "-of", "json", path]).stdout
    return json.loads(out)


def qa(edit, master, mp4, ogv, total):
    final = loudness(mp4)
    report = {
        "edit_seconds": round(total, 3),
        "cuts": len(edit["cuts"]),
        "loudness_target": edit.get("loudness", {"I": -14.0, "TP": -1.0}),
        "mp4_measured": {"integrated_lufs": float(final["input_i"]), "true_peak_dbtp": float(final["input_tp"]),
                         "lra": float(final["input_lra"])},
        "files": {},
    }
    for path in (master, mp4, ogv):
        info = probe(path)
        report["files"][os.path.relpath(path, ROOT).replace("\\", "/")] = {
            "seconds": round(float(info["format"]["duration"]), 3),
            "megabytes": round(int(info["format"]["size"]) / 1048576.0, 1),
            "streams": info["streams"],
        }
    with open(os.path.join(TRAILER, "qa.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2)
    print(json.dumps({k: report[k] for k in ("edit_seconds", "mp4_measured")}, indent=2))
    for name, info in report["files"].items():
        print("%-46s %6.2fs %7.1f MB" % (name, info["seconds"], info["megabytes"]))


def encode_only():
    """`--encode`: the deliveries again from the master already on disk."""
    with open(os.path.join(TRAILER, "edit.json"), encoding="utf-8") as f:
        edit = json.load(f)
    cuts = edit["cuts"]
    starts = []
    for index, cut in enumerate(cuts):
        starts.append(0.0 if index == 0 else
                      starts[-1] + float(cuts[index - 1]["len"]) - float(cut.get("dissolve", 0.0)))
    total = starts[-1] + float(cuts[-1]["len"])
    timeline = [(float(c["len"]), c) for c in cuts]
    encode(edit, os.path.join(OUT, "wilderhold_trailer_master.mov"), total, timeline, starts)


if __name__ == "__main__":
    if "--encode" in sys.argv:
        encode_only()
    else:
        build(preview="--preview" in sys.argv)
