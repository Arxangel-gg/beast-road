# The Wilderhold trailer

About 75 seconds, cut from footage of the game running. Nothing in it is mocked
up: every shot is a seeded road, staged through the same doors a player's road
uses, with a scripted Warden at the controls and a camera the capture harness
owns. Titles are added in the edit, set in the game's own Title face (Cinzel).

## Rebuilding it

```bash
trailer/capture.sh            # films every shot in shots.json (or name a few)
python trailer/build.py       # cuts, titles, scores, normalises and encodes
```

`capture.sh` films each shot in its own Godot process, using Movie Maker at
1920x1080 and 60 fps. The window is windowed, cannot take focus, and sits beyond
every monitor, so a capture never covers the screen it runs on. Saves are held,
the profile is a scratch one under `trailer/work/profile`, and the music bus is
muted, because the edit adds the score. Shots are written to
`trailer/work/<id>.avi`, each with a log beside it; the log's
`[trailer] roll <frame>` line is where `build.py` cuts the warm-up.

`build.py --preview` makes a fast 540p30 cut at `trailer/work/preview.mp4`, for
judging the edit.

| File | What it is | In git |
|---|---|---|
| `shots.json` | the shot list: stage, act, seed, layout, light, weather, camera | yes |
| `edit.json` | the cut: which shot, where it starts, how long, dissolves, titles, the score | yes |
| `capture.sh`, `build.py` | the pipeline | yes |
| `contact_sheet.jpg` | a frame from every cut, labelled with its timecode | yes |
| `qa.json` | measured durations, loudness, true peak and file sizes | yes |
| `out/wilderhold_trailer.mp4` | H.264 High, AAC 320k, 1080p60, faststart: the standalone film | no |
| `out/wilderhold_trailer_master.mov` | ProRes 422 HQ with 24-bit PCM: the archival master | no |
| `../game/video/trailer.ogv` | Theora and Vorbis at 720p30: the film the game plays at startup | yes |

The capture harness is `game/tools/trailer_capture.gd`. The startup player is
`game/scenes/ui/trailer_player.gd`, and `game/tools/trailer_check.gd` holds the
rules it plays by.

## The shot list

Every shot is on one of the newer battlefield layouts. Classic's pinwheel roads
are not shown, because a trailer is a first impression.

| Shot | Act and layout | What it shows |
|---|---|---|
| beast | I | Yuri walking at dawn with the city on his back |
| town | I | the Town on the beast, every building raised |
| wide | IV, Four Rings | the whole field from above: four roads, a defence on each |
| build | I, Citadel | Preparation: towers rising one after another, then climbing |
| warden | II, Keep | the Warden in the thick of it, the Arsenal turning |
| spells | IV, Beast-Axis | a lance, a falling stone, a volley, a nova |
| crossroad | II, Keep | a fork: the road's cards dealt |
| tornado | II, Keep | a funnel walking through a wave, lifting what it catches |
| storm | III, Confluence | night rain, lightning walking the road, the ground breaking |
| dragon | VI, Citadel | a dragon crossing the field, breathing |
| boss | I, Four Rings | an act boss stepping onto the road, and the Warden meeting it |
| peak | X, Citadel | the last act at its height: forty towers, the whole Arsenal |
| menu | - | the main menu, as the trailer gives way to it |

## The score

The score is the game's main theme (`game/audio/music/music_menu.ogg`). Its quiet
opening plays under the first act of the edit, then the theme's own build plays
under the second. The join is placed where the two passages sound most alike:
`build.py` compares their spectra across a few seconds. The theme's drop lands
on the main menu, which is also where the game's menu music begins. The world's
own sound, filmed with the picture, sits about 9 dB under the score. The mix is
normalised in two passes to -14 LUFS integrated and -1 dBTP; `qa.json` records
what was measured.

## In the game

- It plays once per launch, between the splash and the main menu. It plays only
  if the setting is on (Settings › Game › Trailer), and never on the web, where
  a browser blocks sound until the player has interacted. It also does not play
  for a player who has turned screen flashes down.
- **Watch trailer** on the main menu plays it at any time.
- Escape, Enter, Space, a pad's A, B, Start or Back, or the Skip button ends it.
- It always gives up and moves on to the menu, with a line in the log, if the
  file is missing, if the stream stops moving for 2.5 seconds, if playback
  stops, or if it runs past its own length.
- It plays on the music bus, letterboxed to 16:9.

## QA notes

Measured on the last build; `qa.json` has the full numbers.

- The startup rules, every skip, and the fail-open behaviour are gated by
  `trailer_check`, on both CI bars.
- The runtime OGV's length is gated (60 to 90 seconds). Godot 4.7.1's
  `VideoStreamPlayer` was checked decoding it headless.
- Headless Godot does not route mouse hover to a button, so the gate cannot
  push a real click onto Skip. Instead it checks that nothing above the button
  takes clicks, then presses it.
