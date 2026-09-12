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
import re

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

    # ---------------- wildlife: current recording priority ----------------
    ("sfx_wildlife_badger", "sfx", "sfx", "0.7s", "ElevenLabs",
     "one isolated badger warning churr, compact and rough, no attack impact, no background"),
    ("sfx_wildlife_bear", "sfx", "sfx", "1.2s", "ElevenLabs",
     "one restrained brown bear threat huff rising into a short growl, powerful but not a cinematic monster roar, no background"),
    ("sfx_wildlife_boar", "sfx", "sfx", "0.8s", "ElevenLabs",
     "one wild boar territorial snort and short angry grunt, dry and close, no hoof impact, no background"),
    ("sfx_wildlife_deer", "sfx", "sfx", "0.8s", "ElevenLabs",
     "one alert deer bark, natural field-recording character, isolated with no forest ambience"),
    ("sfx_wildlife_fox", "sfx", "sfx", "0.7s", "ElevenLabs",
     "one quiet red fox contact bark, wary rather than distressed, isolated with no background"),
    ("sfx_wildlife_hawk", "sfx", "sfx", "0.9s", "ElevenLabs",
     "one sharp hawk cry passing overhead, natural and brief, no wing loop, no background"),
    ("sfx_wildlife_rabbit", "sfx", "sfx", "0.35s", "ElevenLabs",
     "one very soft rabbit alarm squeak with a tiny breath, subtle and natural, no background"),
    ("sfx_wildlife_raccoon", "sfx", "sfx", "0.7s", "ElevenLabs",
     "one curious raccoon chitter and short trill, natural, isolated, no background"),
    ("sfx_wildlife_raven", "sfx", "sfx", "0.8s", "ElevenLabs",
     "one dry raven croak, weathered and distant enough to sit in a battlefield mix, isolated, no background"),
    ("sfx_wildlife_squirrel", "sfx", "sfx", "0.5s", "ElevenLabs",
     "one small squirrel warning chatter, quick and restrained, isolated, no background"),
    ("sfx_wildlife_viper", "sfx", "sfx", "0.6s", "ElevenLabs",
     "one close viper warning hiss with a tiny dry scale rustle, no bite impact, no background"),
    ("sfx_wildlife_wolf", "sfx", "sfx", "1.0s", "ElevenLabs",
     "one low wolf threat growl ending in a short bark, pack animal not fantasy monster, isolated, no background"),
    # ---------------- act playlists (2026-09-11) ----------------
    # Twelve songs an act, shuffled and played end to end by MusicPlayer. A
    # slot without a file is simply not in the shuffle, so these can be
    # written one at a time and each one goes live the moment it is dropped in.
    ("music_act01_01", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act01_02", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act01_03", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act01_04", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act01_05", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act01_06", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act01_07", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act01_08", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act01_09", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act01_10", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act01_11", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act01_12", "music", "music", "2:00-3:00", "Suno",
     "act 1, the Verdant Maw, a rain-heavy jungle - jungle: wet low toms, damp skin drums, detuned strings under a steady insistent pulse, ember warmth pushing through cold rain. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act02_01", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act02_02", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act02_03", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act02_04", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act02_05", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act02_06", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act02_07", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act02_08", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act02_09", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act02_10", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act02_11", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act02_12", "music", "music", "2:00-3:00", "Suno",
     "act 2, the Sunglass Waste, a desert of fused sand - desert: brittle high metallic tones, bowed glass, thin dry percussion, heat shimmer and a sharp nervous energy. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act03_01", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act03_02", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act03_03", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act03_04", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act03_05", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act03_06", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act03_07", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act03_08", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act03_09", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act03_10", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act03_11", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act03_12", "music", "music", "2:00-3:00", "Suno",
     "act 3, the White Teeth, a frozen mountain approach - snow: driving low toms, war drums under a storm, hard bright metal struck in rhythm. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act04_01", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act04_02", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act04_03", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act04_04", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act04_05", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act04_06", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act04_07", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act04_08", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act04_09", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act04_10", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act04_11", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act04_12", "music", "music", "2:00-3:00", "Suno",
     "act 4, the Hollow Marches, a drowned fog-bound marsh - hollow marches: low bowed strings, dripping wet percussion, distant fog horns, a reed flute that never resolves, everything damp and close. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act05_01", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act05_02", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act05_03", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act05_04", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act05_05", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act05_06", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act05_07", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act05_08", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act05_09", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act05_10", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act05_11", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act05_12", "music", "music", "2:00-3:00", "Suno",
     "act 5, the Rustwood, a forest of iron-stained trees - rustwood: rusted bells, scraped and bowed metal, creaking wood, slow hammer rhythms like a forge heard through trees. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act06_01", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act06_02", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act06_03", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act06_04", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act06_05", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act06_06", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act06_07", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act06_08", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act06_09", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act06_10", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act06_11", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act06_12", "music", "music", "2:00-3:00", "Suno",
     "act 6, the Saltpan Mire, a white salt flat under a flat sky - saltpan: wide dry drones, a glassy wordless choir, cracked shell rattles, heat and emptiness, very little low end. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act07_01", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act07_02", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act07_03", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act07_04", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act07_05", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act07_06", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act07_07", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act07_08", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act07_09", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act07_10", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act07_11", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act07_12", "music", "music", "2:00-3:00", "Suno",
     "act 7, the Iron Steppe, horse-lord grassland - iron steppe: galloping frame drums, throat-song drones, a horsehead fiddle, hooves in the mix, wide and fast. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act08_01", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act08_02", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act08_03", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act08_04", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act08_05", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act08_06", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act08_07", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act08_08", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act08_09", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act08_10", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act08_11", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act08_12", "music", "music", "2:00-3:00", "Suno",
     "act 8, the Glass Fields, frozen ground strewn with broken glass - glass fields: crystalline bells, glass harmonica, high brittle shimmer, sparse sub pulses, cold and clear. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act09_01", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act09_02", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act09_03", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act09_04", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act09_05", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act09_06", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act09_07", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act09_08", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act09_09", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act09_10", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act09_11", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act09_12", "music", "music", "2:00-3:00", "Suno",
     "act 9, the Ashen Reach, volcanic ash under an ember sky - ashen reach: deep sub drones, crackling ember textures, low brass, cinder-dry percussion, slow and enormous. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    ("music_act10_01", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 1 of 12, 'the march in': the act opens: purposeful, mid-tempo, the theme stated plainly"),
    ("music_act10_02", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 2 of 12, 'first blood': the first real fight: faster, the drums come forward"),
    ("music_act10_03", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 3 of 12, 'the long middle': steady and patient, a groove that can sit under twenty minutes of play"),
    ("music_act10_04", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 4 of 12, 'night falls': darker and sparser, the melody drops an octave, space between the hits"),
    ("music_act10_05", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 5 of 12, 'dawn on the road': a lighter variation, the same theme with the tension eased"),
    ("music_act10_06", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 6 of 12, 'the siege': the heaviest track of the act, relentless, every drum in the kit"),
    ("music_act10_07", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 7 of 12, 'a lull': almost ambient, the theme hinted on one instrument over a drone"),
    ("music_act10_08", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 8 of 12, 'dread': slow and menacing, dissonant, something is coming"),
    ("music_act10_09", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 9 of 12, 'the rally': rising, hopeful under the grit, the one the player hums"),
    ("music_act10_10", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 10 of 12, 'the dirge': a funeral pace, low voices, for the waves after a loss"),
    ("music_act10_11", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 11 of 12, 'the hunt': quick and light-footed, syncopated, predatory"),
    ("music_act10_12", "music", "music", "2:00-3:00", "Suno",
     "act 10, the Last Terrace, the stone stair before the gate - last terrace: stone-hall reverb, a solemn low choir, great slow drums, an ascending motif that keeps climbing. Song 12 of 12, 'the last wave': the act's climax: the theme at full force, building toward the boss"),
    # ---------------- boss themes, one an act ----------------
    ("music_boss_act01", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 1, Rakka Coal-Eye, Wolf Marshal - a wolf-horde warlord: pounding war drums, howling brass, a driving pack rhythm. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act02", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 2, Veyr of the Sunglass, Dune Seer - a mirage sorcerer: shimmering glass tones over a slow heavy pulse, uncanny and hot. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act03", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 3, Mogrun White-Maw, Avalanche King - a giant of the snows: colossal drums, avalanche-low brass, ice cracking in rhythm. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act04", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 4, Hollow Ard, the Mistwarden - a marsh revenant: fog horns, dripping strings, a slow dread that never lets up. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act05", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 5, The Rustmother - an iron matriarch: hammer-on-anvil percussion, scraped metal, a grinding industrial march. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act06", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 6, The Brinefather - a drowned salt giant: a wordless choir over crushing sub bass, tidal and enormous. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act07", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 7, Khatun Var, Who Rides Last - a steppe khan: galloping drums at full tilt, throat-song, a fiddle screaming over it. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act08", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 8, The Shatterfather - a colossus of glass: crystalline bells at brutal volume, glass breaking in rhythm, cold fury. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act09", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 9, Ashgild the Unquenched - a cinder titan: volcanic sub drones, roaring brass, ember crackle, the biggest track in the game. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    ("music_boss_act10", "music", "music", "2:00-3:00", "Suno",
     "boss music for act 10, The Gatekeeper - the last guardian: solemn choir at full strength, great drums, the ascending motif finally resolving. Enormous and slow to start, then relentless; the act's own palette pushed to its limit"),
    # ---------------- ambience for acts IV to X ----------------
    ("ambience_hollow_marches", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Hollow Marches: still water, dripping reeds, frogs and unseen things moving in fog, a distant bittern"),
    ("ambience_rustwood", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Rustwood: wind through iron leaves that ring faintly, creaking trunks, flakes falling, no birds"),
    ("ambience_saltpan", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Saltpan Mire: hot flat wind across salt crust, faint crystalline crackle, brine hissing, vast and empty"),
    ("ambience_iron_steppe", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Iron Steppe: grass in a strong wind, distant hooves and horses, a far horn, wide open"),
    ("ambience_glass_fields", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Glass Fields: cold wind over broken glass, high tinkling, ice creaking, a hollow whistle"),
    ("ambience_ashen_reach", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Ashen Reach: low volcanic rumble, ash falling like dry snow, ember pops, hot wind"),
    ("ambience_last_terrace", "ambience", "ambience", "0:60-2:00", "Suno",
     "the Last Terrace: mountain wind around stone, a deep hum from the gate, distant bells, very high altitude"),
    # ---------------- fishing and professions ----------------
    ("sfx_fish_cast", "sfx", "sfx", "0.5s", "ElevenLabs",
     "a fishing line cast: a short whip of line through air and the rod's soft flex, no splash"),
    ("sfx_fish_splash", "sfx", "sfx", "0.6s", "ElevenLabs",
     "a small float landing in still water: a soft plop with a little ripple wash"),
    ("sfx_fish_nibble", "sfx", "sfx", "0.2s", "ElevenLabs",
     "a tiny bob of a float on water: one soft wet tick, barely there"),
    ("sfx_fish_bite", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a fish taking the bait: a sharp tug and a quick splash, urgent"),
    ("sfx_fish_hook", "sfx", "sfx", "0.3s", "ElevenLabs",
     "the hook set: a taut line snapping tight with a short twang"),
    ("sfx_fish_reel", "sfx", "sfx", "0.15s", "ElevenLabs",
     "one click of a fishing reel ratchet, dry and mechanical, for repeating"),
    ("sfx_fish_land", "sfx", "sfx", "0.8s", "ElevenLabs",
     "a fish pulled out of the water onto a bank: a big splash, a wet slap, a bright little chime"),
    ("sfx_fish_snap", "sfx", "sfx", "0.4s", "ElevenLabs",
     "a fishing line snapping: a sharp crack and the loose line whipping away"),
    ("sfx_fish_escape", "sfx", "sfx", "0.5s", "ElevenLabs",
     "a fish getting away: a low plop and a receding splash, a little sad"),
    ("sfx_profession_level", "sfx", "sfx", "1.2s", "ElevenLabs",
     "a skill level gained: a warm four-note rising chime on wood and bell, modest and pleased"),
    # ---------------- boss cues ----------------
    ("sfx_boss_stinger", "sfx", "sfx", "2.0s", "ElevenLabs",
     "a boss arrival stinger: one enormous low orchestral hit with a long dark tail and a deep drum under it, for a crossfade to begin under"),
    ("sfx_boss_fall", "sfx", "sfx", "2.5s", "ElevenLabs",
     "a boss defeated fanfare: a short solemn brass and choir resolution, three rising notes, restrained rather than triumphant"),
    # ---------------- weather (2026-09-12) ----------------
    ("weather_downpour", "ambience", "ambience", "0:60-2:00", "Suno",
     "heavy rain on leaves and packed earth, steady, with the occasional distant roll of thunder and water running off a roof; no wind howl"),
    ("weather_snowfall", "ambience", "ambience", "0:60-2:00", "Suno",
     "a snowfall: a muffled, hushed wind, the faint hiss of falling snow, an occasional creak of frozen wood; very quiet and soft"),
    ("weather_duststorm", "ambience", "ambience", "0:60-2:00", "Suno",
     "a duststorm: a dry rushing wind full of grit, sand hissing against stone, gusts rising and falling; harsh and airy"),
    ("weather_heatwave", "ambience", "ambience", "0:60-2:00", "Suno",
     "a heatwave: a shimmering high drone, cicadas, a very slow hot breath of wind, the crack of drying ground; oppressive stillness"),
    # ---------------- swimming and the water (2026-09-12) ----------------
    ("sfx_swim_enter", "sfx", "sfx", "0.7s", "ElevenLabs",
     "a person falling into a pond: a full body splash with a deep plunge and the water closing over"),
    ("sfx_swim_exit", "sfx", "sfx", "0.6s", "ElevenLabs",
     "a person climbing out of water: a wet surge and heavy dripping off cloth"),
    ("sfx_swim_stroke", "sfx", "sfx", "0.3s", "ElevenLabs",
     "one swimming stroke: an arm pulling through calm water with a small wash, for repeating"),
    ("sfx_water_bite", "sfx", "sfx", "0.4s", "ElevenLabs",
     "something under the water biting a swimmer: a sudden churn, a wet snap and a short pained gasp"),
    ("sfx_drown", "sfx", "sfx", "1.8s", "ElevenLabs",
     "a drowning: a choked gasp, water rushing over, bubbles rising and going quiet, a slow sink"),
    ("sfx_fish_cast_charge", "sfx", "sfx", "0.6s", "ElevenLabs",
     "a fishing rod drawing back for a long cast: the line tightening and the rod creaking under tension, rising"),
    ("sfx_fish_miss", "sfx", "sfx", "0.3s", "ElevenLabs",
     "a fishing float landing on dry ground instead of water: a dull little thump and a rattle of line"),
    # ---------------- camps and the fork (2026-09-12) ----------------
    ("sfx_camp_razed", "sfx", "sfx", "1.4s", "ElevenLabs",
     "a raider camp falling: a collapsing tent, scattered embers, a low satisfied drum hit and a short brass note"),
    ("sfx_fork_open", "sfx", "sfx", "1.6s", "ElevenLabs",
     "a road barrier of logs and stakes tumbling apart: heavy timber crashing, rope snapping, rocks rolling, then a deep open chord"),
    # ---------------- companions (2026-09-12) ----------------
    ("sfx_companion_summon", "sfx", "sfx", "0.9s", "ElevenLabs",
     "a spirit animal arriving: a soft rush of wind with a warm three-note chime and a faint animal breath"),
    ("sfx_companion_down", "sfx", "sfx", "0.8s", "ElevenLabs",
     "a spirit animal beaten and dissolving: a falling two-note sigh and a scatter of soft sparks"),
    ("sfx_companion_return", "sfx", "sfx", "0.8s", "ElevenLabs",
     "a spirit animal re-forming beside its keeper: a rising three-note chime, bright and quick"),
    ("sfx_companion_strike", "sfx", "sfx", "0.2s", "ElevenLabs",
     "an animal's bite landing: a short snap of teeth with a small impact thud, for repeating"),
    # ---------------- the well, the party, achievements (2026-09-12) ----------------
    ("sfx_well_drink", "sfx", "sfx", "0.9s", "ElevenLabs",
     "drinking from a stone well: a ladle dipped, water poured and swallowed, two soft bell notes of relief"),
    ("sfx_party_prompt", "sfx", "sfx", "0.7s", "ElevenLabs",
     "a party invitation arriving: two clear ascending notes on a hunting horn, close and polite"),
    ("sfx_party_accept", "sfx", "sfx", "0.6s", "ElevenLabs",
     "a party member accepting: a bright three-note affirmative chime"),
    ("sfx_party_decline", "sfx", "sfx", "0.5s", "ElevenLabs",
     "a party member declining: a single soft falling note, not unkind"),
    ("sfx_achievement", "sfx", "sfx", "1.4s", "ElevenLabs",
     "an achievement earned: a warm four-note fanfare on bells and low brass with a short shimmering tail"),
    # ---------------- the dungeon and the raid (2026-09-12) ----------------
    ("sfx_dungeon_collapse", "sfx", "sfx", "2.2s", "ElevenLabs",
     "a dungeon collapsing: stone grinding and cracking, a deep rumble building to a crash, dust settling"),
    ("sfx_chest_open", "sfx", "sfx", "1.0s", "ElevenLabs",
     "a heavy iron-bound chest opening: a lock clunk, the lid creaking wide, a bright spill of coins and a chime"),
    ("sfx_dungeon_exit", "sfx", "sfx", "1.1s", "ElevenLabs",
     "stepping through a rift back to daylight: a rising whoosh of air, a soft chord opening, birdsong arriving"),
    ("sfx_raid_window", "sfx", "sfx", "1.0s", "ElevenLabs",
     "an extraction window opening: a war horn's two-note call answered by a second horn, urgent"),
    ("sfx_chieftain_roar", "sfx", "sfx", "1.2s", "ElevenLabs",
     "a raider chieftain's roar: a huge guttural bellow with a metallic edge, echoing"),
    ("sfx_raid_extract", "sfx", "sfx", "1.0s", "ElevenLabs",
     "extracting from a raid: a rush of wind through a gap, a rising note, then quiet"),
]

WILDLIFE_IDS = {row[0] for row in ROWS if row[0].startswith("sfx_wildlife_")}

# Synthesised stand-ins written by the agent so a registered id has *something*
# at its path (a registered sound with no file is a boot WARNING, and the release
# gate fails on any warning). They are the audio equivalent of a magenta
# placeholder PNG and are listed as owed until a real recording overwrites them.
PLACEHOLDER_IDS = {
    "sfx_fish_cast", "sfx_fish_splash", "sfx_fish_nibble", "sfx_fish_bite", "sfx_fish_hook",
    "sfx_fish_reel", "sfx_fish_land", "sfx_fish_snap", "sfx_fish_escape", "sfx_profession_level",
    "sfx_boss_stinger", "sfx_boss_fall",
    # 2026-09-12
    "weather_downpour", "weather_snowfall", "weather_duststorm", "weather_heatwave",
    "sfx_swim_enter", "sfx_swim_exit", "sfx_swim_stroke", "sfx_water_bite", "sfx_drown",
    "sfx_fish_cast_charge", "sfx_fish_miss", "sfx_camp_razed", "sfx_fork_open",
    "sfx_companion_summon", "sfx_companion_down", "sfx_companion_return", "sfx_companion_strike",
    "sfx_well_drink", "sfx_party_prompt", "sfx_party_accept", "sfx_party_decline",
    "sfx_achievement", "sfx_dungeon_collapse", "sfx_chest_open", "sfx_dungeon_exit",
    "sfx_raid_window", "sfx_chieftain_roar", "sfx_raid_extract",
}


def stem_for(kind: str) -> str:
    if kind == "music":
        return MUSIC_STEM
    if kind == "ambience":
        return AMBIENCE_STEM
    return ""


def _audio_root() -> str:
    return os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "audio")


def _on_disk() -> set:
    """Every sound that exists, whichever folder it landed in."""
    have = set()
    root = _audio_root()
    for folder in ("sfx", "music", "ambience"):
        directory = os.path.join(root, folder)
        if not os.path.isdir(directory):
            continue
        for name in os.listdir(directory):
            if name.endswith(".ogg"):
                have.add(os.path.splitext(name)[0])
    return have


def _present(sound_id: str, have: set) -> bool:
    """A numbered take satisfies an id: several sounds are recorded three times
    over and rotated by `Sfx.GROUPS`."""
    if sound_id in have:
        return True
    prefix = sound_id + "_"
    return any(h.startswith(prefix) and h[len(prefix):].isdigit() for h in have)


# Names that match the sound pattern and are not sounds. Kept as an explicit
# list rather than by making the scan cleverer: two settings keys are the entire
# problem, and a deny-list somebody can read beats a regex nobody can.
NOT_SOUNDS = {"sfx_volume", "music_volume", "ambience_volume", "weather_volume"}


def named_by_the_game() -> dict:
    """Every sound id the game mentions, and the first place it mentions it.

    **This is the half a hand-written prompt list cannot know about.** `ROWS` is
    maintained by hand, so a sound added to the game and never added here is
    invisible to it: the doc says nothing is outstanding while the game plays
    silence. Read off the source instead - every sfx_, music_ or ambience_
    string literal in a script or a resource, wherever it appears.

    Deliberately a dumb text scan. It over-reports at worst, which costs
    somebody ten seconds; under-reporting costs a sound nobody notices is
    missing until a player says the game feels dead.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    game = os.path.join(root, "game")
    literal = re.compile('"((?:sfx|music|ambience)_[a-z0-9_]+)"')
    found = {}
    for base, _dirs, files in os.walk(game):
        if ".godot" in base or (os.sep + "audio") in base:
            continue
        for name in files:
            if not (name.endswith(".gd") or name.endswith(".tres")):
                continue
            path = os.path.join(base, name)
            try:
                text = io.open(path, encoding="utf-8").read()
            except (OSError, UnicodeDecodeError):
                continue
            for number, line in enumerate(text.splitlines(), 1):
                for match in literal.finditer(line):
                    if match.group(1) in NOT_SOUNDS:
                        continue
                    found.setdefault(match.group(1), "%s:%d" % (
                        os.path.relpath(path, root).replace(os.sep, "/"), number))
    return found


def unprompted_and_missing() -> list:
    """Sounds the game asks for that have neither a file nor a prompt."""
    have = _on_disk()
    prompted = set(row[0] for row in ROWS)
    out = []
    for sound_id, where in sorted(named_by_the_game().items()):
        if _present(sound_id, have) or sound_id in prompted:
            continue
        out.append((sound_id, where))
    return out


def prompted_but_unused() -> list:
    """Prompts for sounds nothing in the game plays any more."""
    named = named_by_the_game()
    return sorted(row[0] for row in ROWS if row[0] not in named)


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
        if not found or entry[0] in PLACEHOLDER_IDS:
            out.append(entry)
    return out


def main() -> None:
    out = []
    a = out.append
    a("# BEAST ROAD - Sound & Music Prompts\n")
    a("> **Generated by `tools/gen_sfx_prompts.py`. Do not edit by hand.**\n")

    orphans = unprompted_and_missing()
    a("")
    a("## NEEDS A PROMPT AND A SOUND (%d)\n" % len(orphans))
    a("**Start here.** Sounds the game already asks for by name that have no file")
    a("*and* no prompt written below - almost always something added recently")
    a("whose sound nobody got to. The game plays silence there, so nothing errors")
    a("and nothing fails a build: this list is the only way to find them.")
    a("")
    if not orphans:
        a("Nothing outstanding. Every sound the game names has either a file or a")
        a("prompt below.")
        a("")
    else:
        a("| Sound | First asked for at |")
        a("|---|---|")
        for sound_id, where in orphans:
            a("| `%s` | `%s` |" % (sound_id, where))
        a("")
        a("Add a row for each in `tools/gen_sfx_prompts.py` and re-run it, or")
        a("record them now and drop them in `audio_inbox/`.")
        a("")
    a("---")
    a("")

    outstanding = still_missing()
    wildlife = [row for row in outstanding if row[0] in WILDLIFE_IDS]
    a("")
    a("## 🔴 PRIORITY — WILDLIFE SFX TO GENERATE NEXT (%d)\n" % len(wildlife))
    a("These calls are already wired to arrivals and hostile strikes. Missing")
    a("files remain safely silent; adding the named OGG enables them without a")
    a("code change. Record these before the general backlog.\n")
    if wildlife:
        a("| File | Length | Prompt |")
        a("|---|---|---|")
        for name, _kind, _folder, length, _tool, prompt in wildlife:
            a("| **`%s.ogg`** | %s | **%s** |" % (name, length, prompt))
    else:
        a("All wildlife calls are present on disk.")
    a("")
    a("---")
    a("")
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
            note = " **(synthesised placeholder on disk - replace)**" if name in PLACEHOLDER_IDS else ""
            a("| `%s.ogg`%s | `%s` | %s | %s | %s |" % (name, note, folder, length, tool, prompt))
        a("")
    a("---")
    a("")
    unused = prompted_but_unused()
    a("## PROMPTED BUT NEVER PLAYED (%d)\n" % len(unused))
    a("Prompts for sounds nothing in the game names by literal. Not a fault - a")
    a("few are chosen from data rather than written into code - but worth a")
    a("glance before recording one, in case it is for something that was cut.")
    a("")
    a(", ".join("`%s`" % name for name in unused) if unused else "None.")
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
        ("music", "Music", "The one-off situations, then twelve songs an act and a boss theme an act. All through Suno; MusicPlayer shuffles whatever is on disk."),
        ("ambience", "Ambience", "Quiet beds under the music, one per region. Suno, but ask for no melody."),
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
