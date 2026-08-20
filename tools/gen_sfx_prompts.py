"""Builds docs/SFX_PROMPTS.md and game/audio/AUDIO_MANIFEST.md.

Audio is kept separate from ASSET_MANIFEST.md because the rules differ: sounds
have loudness and length constraints instead of pixel dimensions, and they come
from different tools.

A note that belongs at the top of the output, not buried here: **Suno is a music
generator.** It writes songs. It is the right tool for the soundtrack and for
long ambience beds, and the wrong tool for a 200 ms sword impact - asking it for
one gets you a two-minute track that happens to start with a clang. Per-sound
recommendations are in the table.
"""
import io
import os

ROOT = "E:/Arxangel/GameDev/BeastRoad/"
OUT = ROOT + "docs/SFX_PROMPTS.md"
MANIFEST = ROOT + "game/audio/AUDIO_MANIFEST.md"

MUSIC_STEM = (
    "Instrumental game soundtrack, no vocals, no lyrics, no singing. "
    "Dark grim-fantasy orchestral with sparse hand percussion, low strings, "
    "and a lone wind instrument carrying the melody. Muted, weathered, patient - "
    "the sound of a long march across hostile country, not a battle anthem. "
    "It must loop: begin and end on the same sustained chord with no fade-in or "
    "fade-out. Keep the mix uncluttered so it can sit under gameplay for a long "
    "time without becoming tiring."
)

AMBIENCE_STEM = (
    "Ambient background loop for a video game, no melody, no drums, no vocals. "
    "Texture and atmosphere only, at low volume, meant to sit far underneath "
    "gameplay. Seamless loop with no fade at either end."
)

# (id, folder, kind, length, tool, subject, why)
# kind: music | ambience | sfx
ROWS = [
    # ---------------- music ----------------
    ("music_menu", "music", "music", "1:30-2:30", "Suno",
     "the main menu theme: slow, wide and a little mournful, a low drone under a "
     "single bone flute, distant drums that never quite arrive, the sound of "
     "somewhere you are about to leave"),
    ("music_battle_jungle", "music", "music", "2:00-3:00", "Suno",
     "combat music for the Verdant Maw, a rain-heavy jungle: wet low toms,"
     " damp skin drums, detuned strings under a steady insistent pulse,"
     " ember warmth pushing through cold rain"),
    ("music_battle_desert", "music", "music", "2:00-3:00", "Suno",
     "combat music for the Sunglass Waste, a desert of fused sand: brittle"
     " high metallic tones, bowed glass, thin dry percussion, heat shimmer"
     " and a sharp nervous energy"),
    ("music_battle_snow", "music", "music", "2:00-3:00", "Suno",
     "combat music for the White Teeth, a frozen mountain approach: driving"
     " low toms, war drums under a storm, hard bright metal struck in"
     " rhythm, the most aggressive track in the game"),
    ("music_raid", "music", "music", "2:00-3:00", "Suno",
     "music for raiding an enemy camp: fast, relentless, tribal drums and a "
     "rising drone, dangerous and exciting rather than grim"),
    ("music_boss", "music", "music", "2:00-3:00", "Suno",
     "boss music: enormous and slow, deep brass, a choir of low male voices "
     "humming wordlessly, the sense of something far too large"),
    ("music_town", "music", "music", "2:00-3:00", "Suno",
     "quiet music for the town between fights: warm, sparse, a single stringed "
     "instrument and soft room tone, safe but tired"),
    ("music_crossroad", "music", "music", "1:00-1:30", "Suno",
     "a short reflective piece for choosing which road to take: unresolved, "
     "hanging, a question rather than an answer"),
    ("music_victory", "music", "music", "0:30-1:00", "Suno",
     "the run is won: the same bone flute from the menu, but resolved and warm "
     "for the first time, restrained rather than triumphant"),
    ("music_defeat", "music", "music", "0:30-1:00", "Suno",
     "the town has fallen: everything drops away to one held low note and "
     "silence, no drums, no resolution"),

    # ---------------- ambience ----------------
    ("ambience_jungle", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Verdant Maw at dusk: heavy rain on broad leaves, water running off"
     " stone, distant frogs and insects, far-off birds through the canopy"),
    ("ambience_desert", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Sunglass Waste: thin high wind over fused sand, faint crystalline"
     " ticking as the ground cools, a distant mirage-storm hiss, nothing"
     " living"),
    ("ambience_snow", "ambience", "ambience", "0:60-2:00", "Suno",
     "the White Teeth: steady mountain wind carrying dry snow, a low moan"
     " across stone, ice shifting somewhere far below, sparse and vast"),
    ("ambience_beast_walk", "ambience", "ambience", "0:60-2:00", "Suno",
     "the inside of an enormous walking creature heard from its back: a slow "
     "deep heartbeat, groaning bone, leather and chain shifting with each step"),

    # ---------------- one-shots ----------------
    ("sfx_hero_swing_1", "sfx", "sfx", "0.3s", "ElevenLabs",
     "a single fast blade swing through air, dry, close, no impact"),
    ("sfx_hero_swing_2", "sfx", "sfx", "0.3s", "ElevenLabs",
     "a second blade swing, slightly lower pitch, so consecutive swings do not "
     "sound identical"),
    ("sfx_hero_swing_heavy", "sfx", "sfx", "0.5s", "ElevenLabs",
     "a heavy committed two-handed swing, slower and deeper, with weight behind it"),
    ("sfx_hit_flesh", "sfx", "sfx", "0.3s", "ElevenLabs",
     "a blade striking flesh, wet and dull, no scream"),
    ("sfx_hit_armour", "sfx", "sfx", "0.3s", "ElevenLabs",
     "a blade striking iron plate, a bright ringing clang with a short tail"),
    ("sfx_hit_stone", "sfx", "sfx", "0.3s", "ElevenLabs",
     "a blade striking stone, a sharp crack with grit"),
    ("sfx_enemy_die", "sfx", "sfx", "0.6s", "ElevenLabs",
     "a creature collapsing: a short guttural exhale and a soft body fall"),
    ("sfx_hero_hurt", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a sharp pained grunt from an armoured figure taking a hit, muffled behind a mask"),
    ("sfx_hero_death", "sfx", "sfx", "1.2s", "ElevenLabs",
     "a body in armour hitting the ground hard and going still"),
    ("sfx_dash", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a fast cloth-and-air whoosh, a figure moving suddenly, slightly unnatural"),
    ("sfx_footstep_dirt", "sfx", "sfx", "0.2s", "ElevenLabs",
     "one boot step on damp packed earth, close and dry"),
    ("sfx_footstep_heavy", "sfx", "sfx", "0.4s", "ElevenLabs",
     "one enormous armoured footfall, deep and thudding, with a small debris settle"),

    ("sfx_tower_build", "sfx", "sfx", "1.0s", "ElevenLabs",
     "stone and timber being set into place and locking together, solid and final"),
    ("sfx_tower_upgrade", "sfx", "sfx", "1.0s", "ElevenLabs",
     "the same structure being reinforced: heavier stone, a low resonant confirm"),
    ("sfx_tower_sell", "sfx", "sfx", "0.8s", "ElevenLabs",
     "a small structure being dismantled, wood and stone coming apart"),
    ("sfx_fire_shot", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a gout of flame launched, a short roaring burst"),
    ("sfx_water_shot", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a shard of ice launched, crystalline and cold with a thin whistle"),
    ("sfx_earth_shot", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a heavy stone shard launched, low and blunt"),
    ("sfx_air_shot", "sfx", "sfx", "0.4s", "ElevenLabs",
     "an electrical arc discharging, a short crackling snap"),

    ("sfx_spell_cast", "sfx", "sfx", "0.6s", "ElevenLabs",
     "a generic magical incantation resolving, breathy and low, not sparkly"),
    ("sfx_spell_nova", "sfx", "sfx", "1.0s", "ElevenLabs",
     "a burst of fire and ash expanding outward from a point"),
    ("sfx_spell_blink", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a body displacing through space, an inward rush then a soft pop"),

    ("sfx_war_horn", "sfx", "sfx", "2.5s", "ElevenLabs",
     "an enormous bone war horn sounded once, long and low, echoing across open "
     "ground - the most recognisable sound in the game"),
    ("sfx_raid_ready", "sfx", "sfx", "1.5s", "ElevenLabs",
     "a low ominous swell announcing an opportunity, rising then holding"),
    ("sfx_boss_spawn", "sfx", "sfx", "3.0s", "ElevenLabs",
     "something vast waking and announcing itself: a deep roar with a long tail"),
    ("sfx_town_damaged", "sfx", "sfx", "1.0s", "ElevenLabs",
     "timber splintering and stone cracking as a wall is struck"),
    ("sfx_wave_incoming", "sfx", "sfx", "1.5s", "ElevenLabs",
     "a distant drum signal warning of an approaching group, three strikes"),

    ("sfx_ui_click", "sfx", "sfx", "0.15s", "ElevenLabs",
     "a small dry wooden click for a button press, understated"),
    ("sfx_ui_hover", "sfx", "sfx", "0.1s", "ElevenLabs",
     "a very quiet paper or cloth brush for hovering a button"),
    ("sfx_ui_confirm", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a warm low confirmation tone, a single struck wooden block"),
    ("sfx_ui_deny", "sfx", "sfx", "0.3s", "ElevenLabs",
     "a dull refused thud, clearly negative but not harsh"),
    ("sfx_relic_socket", "sfx", "sfx", "0.8s", "ElevenLabs",
     "a heavy stone object seating into a socket with a resonant lock"),
    ("sfx_construction_done", "sfx", "sfx", "1.2s", "ElevenLabs",
     "a building finished: a final hammer strike and a satisfied settle"),
    ("sfx_ui_move", "sfx", "sfx", "0.12s", "ElevenLabs",
     "a very short soft tick for moving between options, quieter than the click"),
    ("sfx_loot_drop", "sfx", "sfx", "0.35s", "ElevenLabs",
     "a small handful of coins landing on packed dirt, dry and close, no ring;"
     " six of these may land within a second so it must not sparkle — record 3 takes, saved as _1.._3; they rotate"),
    ("sfx_loot_collect", "sfx", "sfx", "0.3s", "ElevenLabs",
     "picking up coins: a short bright chime with a cloth rustle under it,"
     " satisfying and small, repeatable many times a minute without fatigue — record 3 takes, saved as _1.._3; they rotate"),
    ("sfx_story_open", "sfx", "sfx", "3.0s", "ElevenLabs",
     "the opening of a story: a deep slow swell of low strings and a distant"
     " horn, rising then settling, sets a solemn tone"),
    ("sfx_story_panel", "sfx", "sfx", "1.4s", "ElevenLabs",
     "a cinematic panel arriving: a soft low whoosh with a faint paper or"
     " parchment turn inside it, understated, plays four times in a row — record 3 takes, saved as _1.._3; they rotate"),
]


def stem_for(kind: str) -> str:
    if kind == "music":
        return MUSIC_STEM
    if kind == "ambience":
        return AMBIENCE_STEM
    return ""


def still_missing() -> list:
    """Which prompted sounds have no file yet, read off disk rather than tracked.

    A hand-maintained "to record" list is wrong the moment somebody drops a file
    in, and then it is worse than useless: it sends you to record something you
    already have.
    """
    root = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "audio")
    out = []
    for entry in ROWS:
        folder = os.path.join(root, entry[2])
        # A numbered take satisfies the row. Several of these are deliberately
        # recorded three times over and rotated by Sfx.GROUPS, so insisting on a
        # bare `name.ogg` would report a sound as missing while three takes of it
        # sat in the folder.
        found = os.path.exists(os.path.join(folder, entry[0] + ".ogg"))
        if not found:
            for take in range(1, 9):
                if os.path.exists(os.path.join(folder, "%s_%d.ogg" % (entry[0], take))):
                    found = True
                    break
        if not found:
            out.append(entry)
    return out


def main() -> None:
    out = []
    a = out.append
    a("# BEAST ROAD - Sound & Music Prompts\n")
    a("> **Generated by `tools/gen_sfx_prompts.py`. Do not edit by hand.**\n")

    outstanding = still_missing()
    a("")
    a("## STILL TO RECORD (%d)\n" % len(outstanding))
    if not outstanding:
        a("Nothing. Every prompted sound below has a file on disk.\n")
    else:
        a("Everything the game asks for and does not have, checked against")
        a("`game/audio/` when this file was generated. The game is *silent* in")
        a("these places rather than broken - `Sfx.play` returns quietly on a")
        a("missing stream - so none of these block a build.\n")
        a("| File | Folder | Length | Tool | Prompt |")
        a("|---|---|---|---|---|")
        for name, kind, folder, length, tool, prompt in outstanding:
            a("| `%s.ogg` | `%s` | %s | %s | %s |" % (name, folder, length, tool, prompt))
        a("")
    a("---")
    a("")
    a("## Read this first: Suno is a music tool\n")
    a("Suno writes *songs*. It is the right tool for the ten music tracks and the")
    a("four ambience beds below, and the wrong tool for a 200 ms sword impact -")
    a("ask it for one and you get a two-minute track that happens to open with a")
    a("clang.\n")
    a("For the one-shots, use a sound-effect generator instead. **ElevenLabs Sound")
    a("Effects** (elevenlabs.io/sound-effects) is free-tier friendly and takes the")
    a("same plain-English prompts. **Freesound.org** is the other good option if you")
    a("would rather use recorded audio - check each licence.\n")
    a("You can absolutely try these in Suno. Just trim hard afterwards, and expect")
    a("to throw most of them away.\n")
    a("---\n")
    a("## Where the files go\n")
    a("```")
    a("game/audio/music/      music_*.ogg      long, looping")
    a("game/audio/ambience/   ambience_*.ogg   long, looping, quiet")
    a("game/audio/sfx/        sfx_*.ogg        short one-shots")
    a("```\n")
    a("**Drop whatever you generate into `audio_inbox/` and I will convert,")
    a("normalise, trim and file it.** Name it after the `id` column - extension does")
    a("not matter, mp3/wav/ogg/flac all fine. The conversion is not optional busywork:")
    a("Godot cannot loop an MP3 seamlessly (the format pads the start and end of every")
    a("file), so anything that loops has to become OGG.\n")
    a("---\n")

    for kind, title, blurb in [
        ("music", "Music", "One track per situation. All ten go through Suno."),
        ("ambience", "Ambience", "Quiet beds under the music. Suno, but ask for no melody."),
        ("sfx", "Sound effects", "One-shots. Use ElevenLabs Sound Effects, not Suno."),
    ]:
        rows = [r for r in ROWS if r[2] == kind]
        a("## %s - %d files\n" % (title, len(rows)))
        a(blurb + "\n")
        for rid, folder, k, length, tool, subject in [(r[0], r[1], r[2], r[3], r[4], r[5]) for r in rows]:
            a("### `%s`\n" % rid)
            a("`%s`  -  target length **%s**  -  suggested tool: **%s**\n" % (
                "game/audio/%s/%s.ogg" % (folder, rid), length, tool))
            a("```text")
            stem = stem_for(k)
            a((stem + " " if stem else "") + subject.strip() + ".")
            a("```\n")
        a("---\n")

    a("## After you generate\n")
    a("1. Drop the files in `audio_inbox/`, named after the id.")
    a("2. Tell me, and I will run the conversion: trim silence, normalise to a")
    a("   consistent loudness, convert to OGG, and set loop points on the ones")
    a("   that loop.")
    a("3. Anything missing keeps using silence - the game does not crash on a")
    a("   missing sound, it just does not play one.\n")

    io.open(OUT, "w", encoding="utf-8", newline="\n").write("\n".join(out))
    print("wrote", OUT)

    # A machine-readable list so the importer knows what it is looking at.
    m = ["# Audio manifest\n",
         "Generated by `tools/gen_sfx_prompts.py`. One row per sound the game looks for.\n",
         "| id | path | kind | loops |", "|----|------|------|-------|"]
    for r in ROWS:
        loops = "yes" if r[2] in ("music", "ambience") else "no"
        m.append("| `%s` | `game/audio/%s/%s.ogg` | %s | %s |" % (r[0], r[1], r[0], r[2], loops))
    io.open(MANIFEST, "w", encoding="utf-8", newline="\n").write("\n".join(m) + "\n")
    print("wrote", MANIFEST)
    print("  %d music, %d ambience, %d sfx" % (
        len([r for r in ROWS if r[2] == "music"]),
        len([r for r in ROWS if r[2] == "ambience"]),
        len([r for r in ROWS if r[2] == "sfx"])))


main()
