extends Node

## Sound effects: the mixer, and the reason nothing sounds like a machine gun.
##
## Three problems this solves that a bare `AudioStreamPlayer.play()` does not:
##
## 1. **Identical repetition.** A footstep or a sword swing fired forty times a
##    minute at exactly the same pitch stops sounding like a sword and starts
##    sounding like a sample. Every play gets a random pitch inside a per-sound
##    range, and sounds that have variant files pick one at random on top of
##    that. Distinctive one-offs - the war horn, a boss waking up - get almost no
##    variance, because those are supposed to sound the same every time.
##
## 2. **Stacking.** Twelve enemies dying in one frame means twelve death sounds
##    summed on top of each other, which is both deafening and mush. Each sound
##    has a polyphony cap and a retrigger cooldown.
##
## 3. **Mix balance.** Levels were normalised per category at import, but a war
##    horn still needs to be louder than a UI hover. The per-sound trim below is
##    the mixing desk.
##
## Like Vfx, this listens on EventBus rather than being called by gameplay code.

## Voices in the pool. Above this, the oldest finished voice is reused.
const VOICES: int = 24

## Explicit paths, not a directory scan.
##
## This was `DirAccess.open("res://audio/sfx/")` and it is the bug that made
## every sound effect silent in the exported game while working perfectly from
## source. Godot strips the source asset out of the .pck when it imports it and
## leaves a remap behind, so a runtime directory listing of res:// finds nothing
## in an export. Music and ambience were unaffected because they always used
## explicit paths - which is exactly why the soundtrack worked and nothing else
## did.
##
## Regenerate with: python tools/gen_sfx_table.py
const SOUNDS: Dictionary = {
	# **The earth was silent.** These seven were recorded, placed on disk and
	# named by the systems that throw them - `Meteor`, `WeatherSky` and
	# `Tornado` all call them by id - and none of them was ever registered
	# here, so every quake, tornado, thunderclap and meteor since the wrath
	# system was built played nothing at all. `Sfx.play` counts a missing id
	# and returns, which is the right behaviour and is also why nobody noticed:
	# there is no error, only silence where a sound should be. Found on
	# 2026-09-15 by `audio_verify` gaining a check that every stand-in carries
	# its own mix row - the rows were there and the sounds were not.
	"sfx_meteor_impact": "res://audio/sfx/sfx_meteor_impact.ogg",
	"sfx_meteor_whistle": "res://audio/sfx/sfx_meteor_whistle.ogg",
	"sfx_quake": "res://audio/sfx/sfx_quake.ogg",
	"sfx_thunder_far": "res://audio/sfx/sfx_thunder_far.ogg",
	"sfx_thunder_near": "res://audio/sfx/sfx_thunder_near.ogg",
	"sfx_tornado": "res://audio/sfx/sfx_tornado.ogg",
	"sfx_wildfire": "res://audio/sfx/sfx_wildfire.ogg",
	"sfx_achievement": "res://audio/sfx/sfx_achievement.ogg",
	"sfx_air_shot_1": "res://audio/sfx/sfx_air_shot_1.ogg",
	"sfx_air_shot_2": "res://audio/sfx/sfx_air_shot_2.ogg",
	"sfx_air_shot_3": "res://audio/sfx/sfx_air_shot_3.ogg",
	"sfx_boss_fall": "res://audio/sfx/sfx_boss_fall.ogg",
	"sfx_boss_spawn": "res://audio/sfx/sfx_boss_spawn.ogg",
	"sfx_boss_stinger": "res://audio/sfx/sfx_boss_stinger.ogg",
	"sfx_camp_razed": "res://audio/sfx/sfx_camp_razed.ogg",
	"sfx_chest_open": "res://audio/sfx/sfx_chest_open.ogg",
	"sfx_chieftain_roar": "res://audio/sfx/sfx_chieftain_roar.ogg",
	"sfx_companion_down": "res://audio/sfx/sfx_companion_down.ogg",
	"sfx_companion_return": "res://audio/sfx/sfx_companion_return.ogg",
	"sfx_companion_strike": "res://audio/sfx/sfx_companion_strike.ogg",
	"sfx_companion_summon": "res://audio/sfx/sfx_companion_summon.ogg",
	"sfx_construction_done": "res://audio/sfx/sfx_construction_done.ogg",
	"sfx_dash_1": "res://audio/sfx/sfx_dash_1.ogg",
	"sfx_dash_2": "res://audio/sfx/sfx_dash_2.ogg",
	"sfx_dash_3": "res://audio/sfx/sfx_dash_3.ogg",
	"sfx_drown": "res://audio/sfx/sfx_drown.ogg",
	"sfx_dungeon_collapse": "res://audio/sfx/sfx_dungeon_collapse.ogg",
	"sfx_dungeon_exit": "res://audio/sfx/sfx_dungeon_exit.ogg",
	"sfx_earth_shot_1": "res://audio/sfx/sfx_earth_shot_1.ogg",
	"sfx_earth_shot_2": "res://audio/sfx/sfx_earth_shot_2.ogg",
	"sfx_earth_shot_3": "res://audio/sfx/sfx_earth_shot_3.ogg",
	"sfx_enemy_die_1": "res://audio/sfx/sfx_enemy_die_1.ogg",
	"sfx_enemy_die_2": "res://audio/sfx/sfx_enemy_die_2.ogg",
	"sfx_enemy_die_3": "res://audio/sfx/sfx_enemy_die_3.ogg",
	"sfx_fire_shot_1": "res://audio/sfx/sfx_fire_shot_1.ogg",
	"sfx_fire_shot_2": "res://audio/sfx/sfx_fire_shot_2.ogg",
	"sfx_fire_shot_3": "res://audio/sfx/sfx_fire_shot_3.ogg",
	"sfx_fish_bite": "res://audio/sfx/sfx_fish_bite.ogg",
	"sfx_fish_cast": "res://audio/sfx/sfx_fish_cast.ogg",
	"sfx_fish_cast_charge": "res://audio/sfx/sfx_fish_cast_charge.ogg",
	"sfx_fish_escape": "res://audio/sfx/sfx_fish_escape.ogg",
	"sfx_fish_hook": "res://audio/sfx/sfx_fish_hook.ogg",
	"sfx_fish_land": "res://audio/sfx/sfx_fish_land.ogg",
	"sfx_fish_miss": "res://audio/sfx/sfx_fish_miss.ogg",
	"sfx_fish_nibble": "res://audio/sfx/sfx_fish_nibble.ogg",
	"sfx_fish_reel": "res://audio/sfx/sfx_fish_reel.ogg",
	"sfx_fish_snap": "res://audio/sfx/sfx_fish_snap.ogg",
	"sfx_fish_splash": "res://audio/sfx/sfx_fish_splash.ogg",
	"sfx_footstep_dirt_1": "res://audio/sfx/sfx_footstep_dirt_1.ogg",
	"sfx_footstep_dirt_2": "res://audio/sfx/sfx_footstep_dirt_2.ogg",
	"sfx_footstep_dirt_3": "res://audio/sfx/sfx_footstep_dirt_3.ogg",
	"sfx_footstep_heavy": "res://audio/sfx/sfx_footstep_heavy.ogg",
	"sfx_fork_open": "res://audio/sfx/sfx_fork_open.ogg",
	"sfx_hero_death": "res://audio/sfx/sfx_hero_death.ogg",
	"sfx_hero_hurt_1": "res://audio/sfx/sfx_hero_hurt_1.ogg",
	"sfx_hero_hurt_2": "res://audio/sfx/sfx_hero_hurt_2.ogg",
	"sfx_hero_hurt_3": "res://audio/sfx/sfx_hero_hurt_3.ogg",
	"sfx_hero_swing_1": "res://audio/sfx/sfx_hero_swing_1.ogg",
	"sfx_hero_swing_2": "res://audio/sfx/sfx_hero_swing_2.ogg",
	"sfx_hero_swing_heavy_1": "res://audio/sfx/sfx_hero_swing_heavy_1.ogg",
	"sfx_hero_swing_heavy_2": "res://audio/sfx/sfx_hero_swing_heavy_2.ogg",
	"sfx_hit_armour_1": "res://audio/sfx/sfx_hit_armour_1.ogg",
	"sfx_hit_armour_2": "res://audio/sfx/sfx_hit_armour_2.ogg",
	"sfx_hit_armour_3": "res://audio/sfx/sfx_hit_armour_3.ogg",
	"sfx_hit_flesh_1": "res://audio/sfx/sfx_hit_flesh_1.ogg",
	"sfx_hit_flesh_2": "res://audio/sfx/sfx_hit_flesh_2.ogg",
	"sfx_hit_flesh_3": "res://audio/sfx/sfx_hit_flesh_3.ogg",
	"sfx_hit_stone_1": "res://audio/sfx/sfx_hit_stone_1.ogg",
	"sfx_hit_stone_2": "res://audio/sfx/sfx_hit_stone_2.ogg",
	"sfx_hit_stone_3": "res://audio/sfx/sfx_hit_stone_3.ogg",
	"sfx_loot_collect_1": "res://audio/sfx/sfx_loot_collect_1.ogg",
	"sfx_loot_collect_2": "res://audio/sfx/sfx_loot_collect_2.ogg",
	"sfx_loot_collect_3": "res://audio/sfx/sfx_loot_collect_3.ogg",
	"sfx_loot_drop_1": "res://audio/sfx/sfx_loot_drop_1.ogg",
	"sfx_loot_drop_2": "res://audio/sfx/sfx_loot_drop_2.ogg",
	"sfx_loot_drop_3": "res://audio/sfx/sfx_loot_drop_3.ogg",
	"sfx_party_accept": "res://audio/sfx/sfx_party_accept.ogg",
	"sfx_party_decline": "res://audio/sfx/sfx_party_decline.ogg",
	"sfx_party_prompt": "res://audio/sfx/sfx_party_prompt.ogg",
	"sfx_profession_level": "res://audio/sfx/sfx_profession_level.ogg",
	"sfx_raid_extract": "res://audio/sfx/sfx_raid_extract.ogg",
	"sfx_raid_ready": "res://audio/sfx/sfx_raid_ready.ogg",
	"sfx_raid_window": "res://audio/sfx/sfx_raid_window.ogg",
	"sfx_relic_socket": "res://audio/sfx/sfx_relic_socket.ogg",
	"sfx_spell_blink": "res://audio/sfx/sfx_spell_blink.ogg",
	"sfx_spell_cast_1": "res://audio/sfx/sfx_spell_cast_1.ogg",
	"sfx_spell_cast_2": "res://audio/sfx/sfx_spell_cast_2.ogg",
	"sfx_spell_cast_3": "res://audio/sfx/sfx_spell_cast_3.ogg",
	"sfx_spell_nova": "res://audio/sfx/sfx_spell_nova.ogg",
	"sfx_story_open": "res://audio/sfx/sfx_story_open.ogg",
	"sfx_story_panel_1": "res://audio/sfx/sfx_story_panel_1.ogg",
	"sfx_story_panel_2": "res://audio/sfx/sfx_story_panel_2.ogg",
	"sfx_story_panel_3": "res://audio/sfx/sfx_story_panel_3.ogg",
	"sfx_swim_enter": "res://audio/sfx/sfx_swim_enter.ogg",
	"sfx_swim_exit": "res://audio/sfx/sfx_swim_exit.ogg",
	"sfx_swim_stroke": "res://audio/sfx/sfx_swim_stroke.ogg",
	"sfx_tower_build_1": "res://audio/sfx/sfx_tower_build_1.ogg",
	"sfx_tower_build_2": "res://audio/sfx/sfx_tower_build_2.ogg",
	"sfx_tower_build_3": "res://audio/sfx/sfx_tower_build_3.ogg",
	"sfx_tower_sell_1": "res://audio/sfx/sfx_tower_sell_1.ogg",
	"sfx_tower_sell_2": "res://audio/sfx/sfx_tower_sell_2.ogg",
	"sfx_tower_sell_3": "res://audio/sfx/sfx_tower_sell_3.ogg",
	"sfx_tower_upgrade_1": "res://audio/sfx/sfx_tower_upgrade_1.ogg",
	"sfx_tower_upgrade_2": "res://audio/sfx/sfx_tower_upgrade_2.ogg",
	"sfx_tower_upgrade_3": "res://audio/sfx/sfx_tower_upgrade_3.ogg",
	"sfx_town_damaged": "res://audio/sfx/sfx_town_damaged.ogg",
	"sfx_ui_click_1": "res://audio/sfx/sfx_ui_click_1.ogg",
	"sfx_ui_click_2": "res://audio/sfx/sfx_ui_click_2.ogg",
	"sfx_ui_click_3": "res://audio/sfx/sfx_ui_click_3.ogg",
	"sfx_ui_confirm": "res://audio/sfx/sfx_ui_confirm.ogg",
	"sfx_ui_deny": "res://audio/sfx/sfx_ui_deny.ogg",
	"sfx_ui_hover_1": "res://audio/sfx/sfx_ui_hover_1.ogg",
	"sfx_ui_hover_2": "res://audio/sfx/sfx_ui_hover_2.ogg",
	"sfx_ui_hover_3": "res://audio/sfx/sfx_ui_hover_3.ogg",
	"sfx_ui_hover_4": "res://audio/sfx/sfx_ui_hover_4.ogg",
	"sfx_ui_hover_5": "res://audio/sfx/sfx_ui_hover_5.ogg",
	"sfx_ui_move_1": "res://audio/sfx/sfx_ui_move_1.ogg",
	"sfx_ui_move_2": "res://audio/sfx/sfx_ui_move_2.ogg",
	"sfx_ui_move_3": "res://audio/sfx/sfx_ui_move_3.ogg",
	"sfx_war_horn": "res://audio/sfx/sfx_war_horn.ogg",
	"sfx_water_bite": "res://audio/sfx/sfx_water_bite.ogg",
	"sfx_water_shot_1": "res://audio/sfx/sfx_water_shot_1.ogg",
	"sfx_water_shot_2": "res://audio/sfx/sfx_water_shot_2.ogg",
	"sfx_water_shot_3": "res://audio/sfx/sfx_water_shot_3.ogg",
	"sfx_wave_incoming": "res://audio/sfx/sfx_wave_incoming.ogg",
	"sfx_well_drink": "res://audio/sfx/sfx_well_drink.ogg",
	"sfx_wildlife_badger_1": "res://audio/sfx/sfx_wildlife_badger_1.ogg",
	"sfx_wildlife_badger_2": "res://audio/sfx/sfx_wildlife_badger_2.ogg",
	"sfx_wildlife_badger_3": "res://audio/sfx/sfx_wildlife_badger_3.ogg",
	"sfx_wildlife_badger_4": "res://audio/sfx/sfx_wildlife_badger_4.ogg",
	"sfx_wildlife_bear_1": "res://audio/sfx/sfx_wildlife_bear_1.ogg",
	"sfx_wildlife_bear_2": "res://audio/sfx/sfx_wildlife_bear_2.ogg",
	"sfx_wildlife_bear_3": "res://audio/sfx/sfx_wildlife_bear_3.ogg",
	"sfx_wildlife_bear_4": "res://audio/sfx/sfx_wildlife_bear_4.ogg",
	"sfx_wildlife_bear_5": "res://audio/sfx/sfx_wildlife_bear_5.ogg",
	"sfx_wildlife_bear_6": "res://audio/sfx/sfx_wildlife_bear_6.ogg",
	"sfx_wildlife_bear_7": "res://audio/sfx/sfx_wildlife_bear_7.ogg",
	"sfx_wildlife_bear_8": "res://audio/sfx/sfx_wildlife_bear_8.ogg",
	"sfx_wildlife_boar_1": "res://audio/sfx/sfx_wildlife_boar_1.ogg",
	"sfx_wildlife_boar_2": "res://audio/sfx/sfx_wildlife_boar_2.ogg",
	"sfx_wildlife_boar_3": "res://audio/sfx/sfx_wildlife_boar_3.ogg",
	"sfx_wildlife_boar_4": "res://audio/sfx/sfx_wildlife_boar_4.ogg",
	"sfx_wildlife_deer_1": "res://audio/sfx/sfx_wildlife_deer_1.ogg",
	"sfx_wildlife_deer_2": "res://audio/sfx/sfx_wildlife_deer_2.ogg",
	"sfx_wildlife_deer_3": "res://audio/sfx/sfx_wildlife_deer_3.ogg",
	"sfx_wildlife_deer_4": "res://audio/sfx/sfx_wildlife_deer_4.ogg",
	"sfx_wildlife_fox_1": "res://audio/sfx/sfx_wildlife_fox_1.ogg",
	"sfx_wildlife_fox_2": "res://audio/sfx/sfx_wildlife_fox_2.ogg",
	"sfx_wildlife_fox_3": "res://audio/sfx/sfx_wildlife_fox_3.ogg",
	"sfx_wildlife_fox_4": "res://audio/sfx/sfx_wildlife_fox_4.ogg",
	"sfx_wildlife_hawk_1": "res://audio/sfx/sfx_wildlife_hawk_1.ogg",
	"sfx_wildlife_hawk_2": "res://audio/sfx/sfx_wildlife_hawk_2.ogg",
	"sfx_wildlife_hawk_3": "res://audio/sfx/sfx_wildlife_hawk_3.ogg",
	"sfx_wildlife_hawk_4": "res://audio/sfx/sfx_wildlife_hawk_4.ogg",
	"sfx_wildlife_rabbit_1": "res://audio/sfx/sfx_wildlife_rabbit_1.ogg",
	"sfx_wildlife_rabbit_2": "res://audio/sfx/sfx_wildlife_rabbit_2.ogg",
	"sfx_wildlife_rabbit_3": "res://audio/sfx/sfx_wildlife_rabbit_3.ogg",
	"sfx_wildlife_rabbit_4": "res://audio/sfx/sfx_wildlife_rabbit_4.ogg",
	"sfx_wildlife_raccoon_1": "res://audio/sfx/sfx_wildlife_raccoon_1.ogg",
	"sfx_wildlife_raccoon_2": "res://audio/sfx/sfx_wildlife_raccoon_2.ogg",
	"sfx_wildlife_raccoon_3": "res://audio/sfx/sfx_wildlife_raccoon_3.ogg",
	"sfx_wildlife_raccoon_4": "res://audio/sfx/sfx_wildlife_raccoon_4.ogg",
	"sfx_wildlife_raven_1": "res://audio/sfx/sfx_wildlife_raven_1.ogg",
	"sfx_wildlife_raven_2": "res://audio/sfx/sfx_wildlife_raven_2.ogg",
	"sfx_wildlife_raven_3": "res://audio/sfx/sfx_wildlife_raven_3.ogg",
	"sfx_wildlife_raven_4": "res://audio/sfx/sfx_wildlife_raven_4.ogg",
	"sfx_wildlife_squirrel_1": "res://audio/sfx/sfx_wildlife_squirrel_1.ogg",
	"sfx_wildlife_squirrel_2": "res://audio/sfx/sfx_wildlife_squirrel_2.ogg",
	"sfx_wildlife_squirrel_3": "res://audio/sfx/sfx_wildlife_squirrel_3.ogg",
	"sfx_wildlife_squirrel_4": "res://audio/sfx/sfx_wildlife_squirrel_4.ogg",
	"sfx_wildlife_viper_1": "res://audio/sfx/sfx_wildlife_viper_1.ogg",
	"sfx_wildlife_viper_2": "res://audio/sfx/sfx_wildlife_viper_2.ogg",
	"sfx_wildlife_viper_3": "res://audio/sfx/sfx_wildlife_viper_3.ogg",
	"sfx_wildlife_viper_4": "res://audio/sfx/sfx_wildlife_viper_4.ogg",
	"sfx_wildlife_wolf_1": "res://audio/sfx/sfx_wildlife_wolf_1.ogg",
	"sfx_wildlife_wolf_2": "res://audio/sfx/sfx_wildlife_wolf_2.ogg",
	"sfx_wildlife_wolf_3": "res://audio/sfx/sfx_wildlife_wolf_3.ogg",
	"sfx_wildlife_wolf_4": "res://audio/sfx/sfx_wildlife_wolf_4.ogg",
	"sfx_wildlife_wolf_5": "res://audio/sfx/sfx_wildlife_wolf_5.ogg",
	"sfx_wildlife_wolf_6": "res://audio/sfx/sfx_wildlife_wolf_6.ogg",
	"sfx_wildlife_wolf_7": "res://audio/sfx/sfx_wildlife_wolf_7.ogg",
	"sfx_wildlife_wolf_8": "res://audio/sfx/sfx_wildlife_wolf_8.ogg",
}

## Per-sound mix. `db` trims level, `pitch` is the +/- fraction of pitch drift,
## `limit` caps how many can sound at once, `gap` is the minimum seconds between
## two triggers of the same sound.
##
## This is a mixing desk, not tuning: it lives here rather than in Balance
## because every value is about how one specific recording sits against the
## others, and none of it is a design decision.
const MIX: Dictionary = {
	"sfx_wildfire":                {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_tornado":                 {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_thunder_near":            {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_thunder_far":             {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_quake":                   {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_meteor_whistle":          {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_meteor_impact":           {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_air_shot_1":            {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_air_shot_2":            {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_air_shot_3":            {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_boss_spawn":            {"db": 6.0,   "pitch": 0.02, "limit": 1, "gap": 1.0},
	"sfx_construction_done":     {"db": 0.0,  "pitch": 0.04, "limit": 1, "gap": 0.2},
	"sfx_dash_1":                {"db": -3.0,  "pitch": 0.12, "limit": 2, "gap": 0.05},
	"sfx_dash_2":                {"db": -3.0,  "pitch": 0.12, "limit": 2, "gap": 0.05},
	"sfx_dash_3":                {"db": -3.0,  "pitch": 0.12, "limit": 2, "gap": 0.05},
	"sfx_earth_shot_1":          {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_earth_shot_2":          {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_earth_shot_3":          {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_enemy_die_1":           {"db": -4.0, "pitch": 0.15, "limit": 5, "gap": 0.05},
	"sfx_enemy_die_2":           {"db": -4.0, "pitch": 0.15, "limit": 5, "gap": 0.05},
	"sfx_enemy_die_3":           {"db": -4.0, "pitch": 0.15, "limit": 5, "gap": 0.05},
	"sfx_fire_shot_1":           {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_fire_shot_2":           {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_fire_shot_3":           {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_footstep_dirt_1":       {"db": -21.0, "pitch": 0.18, "limit": 4, "gap": 0.04},
	"sfx_footstep_dirt_2":       {"db": -21.0, "pitch": 0.18, "limit": 4, "gap": 0.04},
	"sfx_footstep_dirt_3":       {"db": -21.0, "pitch": 0.18, "limit": 4, "gap": 0.04},
	"sfx_footstep_heavy":        {"db": -13.0, "pitch": 0.14, "limit": 3, "gap": 0.06},
	"sfx_hero_death":            {"db": 0.0,  "pitch": 0.05, "limit": 1, "gap": 0.5},
	"sfx_hero_hurt_1":           {"db": -1.0,  "pitch": 0.10, "limit": 2, "gap": 0.15},
	"sfx_hero_hurt_2":           {"db": -1.0,  "pitch": 0.10, "limit": 2, "gap": 0.15},
	"sfx_hero_hurt_3":           {"db": -1.0,  "pitch": 0.10, "limit": 2, "gap": 0.15},
	"sfx_hero_swing_1":          {"db": -2.0,  "pitch": 0.14, "limit": 3, "gap": 0.03},
	"sfx_hero_swing_2":          {"db": -2.0,  "pitch": 0.14, "limit": 3, "gap": 0.03},
	"sfx_hero_swing_heavy_1":    {"db": 0.0,  "pitch": 0.09, "limit": 2, "gap": 0.05},
	"sfx_hero_swing_heavy_2":    {"db": 0.0,  "pitch": 0.09, "limit": 2, "gap": 0.05},
	"sfx_hit_armour_1":          {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_hit_armour_2":          {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_hit_armour_3":          {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_hit_flesh_1":           {"db": -3.0,  "pitch": 0.16, "limit": 5, "gap": 0.03},
	"sfx_hit_flesh_2":           {"db": -3.0,  "pitch": 0.16, "limit": 5, "gap": 0.03},
	"sfx_hit_flesh_3":           {"db": -3.0,  "pitch": 0.16, "limit": 5, "gap": 0.03},
	"sfx_hit_stone_1":           {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_hit_stone_2":           {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_hit_stone_3":           {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_loot_collect_1":        {"db": -9.0, "pitch": 0.13, "limit": 4, "gap": 0.03},
	"sfx_loot_collect_2":        {"db": -9.0, "pitch": 0.13, "limit": 4, "gap": 0.03},
	"sfx_loot_collect_3":        {"db": -9.0, "pitch": 0.13, "limit": 4, "gap": 0.03},
	"sfx_loot_drop_1":           {"db": -13.0, "pitch": 0.16, "limit": 3, "gap": 0.05},
	"sfx_loot_drop_2":           {"db": -13.0, "pitch": 0.16, "limit": 3, "gap": 0.05},
	"sfx_loot_drop_3":           {"db": -13.0, "pitch": 0.16, "limit": 3, "gap": 0.05},
	"sfx_raid_ready":            {"db": 3.0,  "pitch": 0.02, "limit": 1, "gap": 0.5},
	"sfx_relic_socket":          {"db": 0.0,  "pitch": 0.04, "limit": 1, "gap": 0.1},
	"sfx_spell_blink":           {"db": -2.0,  "pitch": 0.12, "limit": 2, "gap": 0.05},
	"sfx_spell_cast_1":          {"db": -2.0,  "pitch": 0.10, "limit": 3, "gap": 0.05},
	"sfx_spell_cast_2":          {"db": -2.0,  "pitch": 0.10, "limit": 3, "gap": 0.05},
	"sfx_spell_cast_3":          {"db": -2.0,  "pitch": 0.10, "limit": 3, "gap": 0.05},
	"sfx_spell_nova":            {"db": 0.0,  "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_story_open":            {"db": -4.0, "pitch": 0.0, "limit": 1, "gap": 0.5},
	"sfx_story_panel_1":         {"db": -7.0, "pitch": 0.04, "limit": 1, "gap": 0.25},
	"sfx_story_panel_2":         {"db": -7.0, "pitch": 0.04, "limit": 1, "gap": 0.25},
	"sfx_story_panel_3":         {"db": -7.0, "pitch": 0.04, "limit": 1, "gap": 0.25},
	"sfx_tower_build_1":         {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_build_2":         {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_build_3":         {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_sell_1":          {"db": -3.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_sell_2":          {"db": -3.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_sell_3":          {"db": -3.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_upgrade_1":       {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_upgrade_2":       {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_upgrade_3":       {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_town_damaged":          {"db": 2.0,  "pitch": 0.12, "limit": 2, "gap": 0.1},
	"sfx_ui_click_1":            {"db": -7.0, "pitch": 0.07, "limit": 2, "gap": 0.03},
	"sfx_ui_click_2":            {"db": -7.0, "pitch": 0.07, "limit": 2, "gap": 0.03},
	"sfx_ui_click_3":            {"db": -7.0, "pitch": 0.07, "limit": 2, "gap": 0.03},
	"sfx_ui_confirm":            {"db": -4.0, "pitch": 0.05, "limit": 1, "gap": 0.05},
	"sfx_ui_deny":               {"db": -4.0, "pitch": 0.05, "limit": 1, "gap": 0.08},
	"sfx_ui_hover_1":            {"db": -17.0, "pitch": 0.10, "limit": 2, "gap": 0.05},
	"sfx_ui_hover_2":            {"db": -17.0, "pitch": 0.10, "limit": 2, "gap": 0.05},
	"sfx_ui_hover_3":            {"db": -17.0, "pitch": 0.10, "limit": 2, "gap": 0.05},
	"sfx_ui_hover_4":            {"db": -17.0, "pitch": 0.10, "limit": 2, "gap": 0.05},
	"sfx_ui_hover_5":            {"db": -17.0, "pitch": 0.10, "limit": 2, "gap": 0.05},
	"sfx_ui_move_1":             {"db": -12.0, "pitch": 0.07, "limit": 1, "gap": 0.04},
	"sfx_ui_move_2":             {"db": -12.0, "pitch": 0.07, "limit": 1, "gap": 0.04},
	"sfx_ui_move_3":             {"db": -12.0, "pitch": 0.07, "limit": 1, "gap": 0.04},
	"sfx_war_horn":              {"db": 6.0,   "pitch": 0.02, "limit": 1, "gap": 1.0},
	"sfx_water_shot_1":          {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_water_shot_2":          {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_water_shot_3":          {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_fish_cast":            {"db": -14.0, "pitch": 0.08, "limit": 1, "gap": 0.20},
	"sfx_fish_splash":          {"db": -13.0, "pitch": 0.10, "limit": 2, "gap": 0.10},
	"sfx_fish_nibble":          {"db": -18.0, "pitch": 0.12, "limit": 1, "gap": 0.30},
	"sfx_fish_bite":            {"db": -10.0, "pitch": 0.05, "limit": 1, "gap": 0.30},
	"sfx_fish_hook":            {"db": -12.0, "pitch": 0.06, "limit": 1, "gap": 0.30},
	"sfx_fish_reel":            {"db": -16.1, "pitch": 0.10, "limit": 2, "gap": 0.05},
	"sfx_fish_land":            {"db": -10.0, "pitch": 0.05, "limit": 1, "gap": 0.50},
	"sfx_fish_snap":            {"db": -11.0, "pitch": 0.05, "limit": 1, "gap": 0.50},
	"sfx_fish_escape":          {"db": -14.0, "pitch": 0.08, "limit": 1, "gap": 0.50},
	"sfx_profession_level":     {"db": -8.0, "pitch": 0.00, "limit": 1, "gap": 1.00},
	"sfx_boss_stinger":         {"db": -4.0, "pitch": 0.00, "limit": 1, "gap": 2.00},
	"sfx_boss_fall":            {"db": -5.0, "pitch": 0.00, "limit": 1, "gap": 2.00},
	# The water, the camps, the companions and the rest of 2026-09-12.
	"sfx_swim_enter":           {"db": -11.0, "pitch": 0.08, "limit": 2, "gap": 0.30},
	"sfx_swim_exit":            {"db": -14.0, "pitch": 0.08, "limit": 2, "gap": 0.30},
	"sfx_swim_stroke":          {"db": -16.0, "pitch": 0.14, "limit": 2, "gap": 0.20},
	"sfx_water_bite":           {"db": -10.0, "pitch": 0.06, "limit": 1, "gap": 0.40},
	"sfx_drown":                {"db": -8.0, "pitch": 0.02, "limit": 1, "gap": 1.00},
	"sfx_fish_cast_charge":     {"db": -16.0, "pitch": 0.04, "limit": 1, "gap": 0.30},
	"sfx_fish_miss":            {"db": -14.0, "pitch": 0.08, "limit": 1, "gap": 0.30},
	"sfx_camp_razed":           {"db": -6.0, "pitch": 0.03, "limit": 1, "gap": 1.00},
	"sfx_fork_open":            {"db": -5.0, "pitch": 0.02, "limit": 1, "gap": 1.50},
	"sfx_companion_summon":     {"db": -10.0, "pitch": 0.04, "limit": 1, "gap": 0.50},
	"sfx_companion_down":       {"db": -10.0, "pitch": 0.04, "limit": 1, "gap": 0.50},
	"sfx_companion_return":     {"db": -10.0, "pitch": 0.04, "limit": 1, "gap": 0.50},
	"sfx_companion_strike":     {"db": -15.4, "pitch": 0.14, "limit": 3, "gap": 0.08},
	"sfx_well_drink":           {"db": -11.0, "pitch": 0.05, "limit": 1, "gap": 0.50},
	"sfx_party_prompt":         {"db": -8.0, "pitch": 0.00, "limit": 1, "gap": 0.50},
	"sfx_party_accept":         {"db": -8.0, "pitch": 0.00, "limit": 1, "gap": 0.30},
	"sfx_party_decline":        {"db": -10.0, "pitch": 0.00, "limit": 1, "gap": 0.30},
	"sfx_achievement":          {"db": -6.0, "pitch": 0.00, "limit": 1, "gap": 1.50},
	"sfx_dungeon_collapse":     {"db": -4.0, "pitch": 0.02, "limit": 1, "gap": 2.00},
	"sfx_chest_open":           {"db": -8.0, "pitch": 0.04, "limit": 1, "gap": 0.50},
	"sfx_dungeon_exit":         {"db": -8.0, "pitch": 0.03, "limit": 1, "gap": 1.00},
	"sfx_raid_window":          {"db": -7.0, "pitch": 0.00, "limit": 1, "gap": 1.00},
	"sfx_chieftain_roar":       {"db": -4.0, "pitch": 0.04, "limit": 1, "gap": 1.50},
	"sfx_raid_extract":         {"db": -7.0, "pitch": 0.03, "limit": 1, "gap": 1.00},
	"sfx_wave_incoming":         {"db": -1.0,  "pitch": 0.03, "limit": 1, "gap": 0.5},
	"sfx_wildlife_badger":       {"db": -11.0, "pitch": 0.08, "limit": 1, "gap": 3.0},
	"sfx_wildlife_bear":         {"db": -8.0,  "pitch": 0.05, "limit": 1, "gap": 4.0},
	"sfx_wildlife_boar":         {"db": -9.0,  "pitch": 0.07, "limit": 1, "gap": 3.0},
	"sfx_wildlife_deer":         {"db": -12.0, "pitch": 0.08, "limit": 1, "gap": 4.0},
	"sfx_wildlife_fox":          {"db": -13.0, "pitch": 0.10, "limit": 1, "gap": 3.5},
	"sfx_wildlife_hawk":         {"db": -12.0, "pitch": 0.07, "limit": 1, "gap": 3.0},
	"sfx_wildlife_rabbit":       {"db": -16.0, "pitch": 0.10, "limit": 1, "gap": 3.5},
	"sfx_wildlife_raccoon":      {"db": -14.0, "pitch": 0.10, "limit": 1, "gap": 3.5},
	"sfx_wildlife_raven":        {"db": -14.0, "pitch": 0.08, "limit": 1, "gap": 3.0},
	"sfx_wildlife_squirrel":     {"db": -17.0, "pitch": 0.12, "limit": 1, "gap": 3.5},
	"sfx_wildlife_viper":        {"db": -13.0, "pitch": 0.10, "limit": 1, "gap": 2.5},
	"sfx_wildlife_wolf":         {"db": -10.0, "pitch": 0.06, "limit": 1, "gap": 3.0},
}

## Defaults for any sound not listed above.
## **Which of these are stand-ins.** Synthesised, not recorded, and listed here
## rather than only in `docs/SFX_PROMPTS.md` so that something in the game can
## check them - the way `asset_report` knows which art is still a placeholder.
##
## They were measured on 2026-09-15 and the set played **eight decibels louder
## than the 139 real recordings** (-17.3 against -25.2 effective, weighted by
## the level `MIX` actually plays each at). Eight decibels is about twice as
## loud: every fishing cue, every disaster and every boss stinger jumped out of
## the mix, and seven of them had no mix row at all so they played at the
## loudest default there is. `tools/level_placeholders.py` brought the set onto
## the corpus - the two means are now 0.2 dB apart - and `audio_verify` holds
## the part of that a gate can see: a stand-in must carry its own row, and that
## row must be quieter than the default.
const PLACEHOLDERS: Array[String] = [
	"sfx_achievement", "sfx_boss_fall", "sfx_boss_stinger",
	"sfx_camp_razed", "sfx_chest_open", "sfx_chieftain_roar",
	"sfx_companion_down", "sfx_companion_return", "sfx_companion_strike",
	"sfx_companion_summon", "sfx_drown", "sfx_dungeon_collapse",
	"sfx_dungeon_exit", "sfx_fish_bite", "sfx_fish_cast",
	"sfx_fish_cast_charge", "sfx_fish_escape", "sfx_fish_hook",
	"sfx_fish_land", "sfx_fish_miss", "sfx_fish_nibble",
	"sfx_fish_reel", "sfx_fish_snap", "sfx_fish_splash",
	"sfx_fork_open", "sfx_meteor_impact", "sfx_meteor_whistle",
	"sfx_party_accept", "sfx_party_decline", "sfx_party_prompt",
	"sfx_profession_level", "sfx_quake", "sfx_raid_extract",
	"sfx_raid_window", "sfx_swim_enter", "sfx_swim_exit",
	"sfx_swim_stroke", "sfx_thunder_far", "sfx_thunder_near",
	"sfx_tornado", "sfx_water_bite", "sfx_well_drink",
	"sfx_wildfire",
]


const DEFAULT_MIX: Dictionary = {"db": -3.0, "pitch": 0.10, "limit": 3, "gap": 0.04}

## Sounds that come in variants. Asking for the group picks one at random, which
## is a stronger cure for repetition than pitch alone.
## Sounds recorded as several takes, rotated per play.
##
## Named for the base sound, which is what makes this transparent: `play()`
## falls through to a group of the same name, so every existing call site keeps
## working unchanged while the takes rotate underneath it. Adding a second take
## to a sound is a data change, not a code change.
## An anchor no tile can have, so "nothing was just broken" is not a real slot.
const NO_ANCHOR: Vector2i = Vector2i(-9999, -9999)

## The tile whose tower was broken a moment ago, consumed by the very next
## `tower_changed`. See `_on_tower_destroyed`.
var _broken: Vector2i = NO_ANCHOR


const GROUPS: Dictionary = {
	"sfx_air_shot": ["sfx_air_shot_1", "sfx_air_shot_2", "sfx_air_shot_3"],
	"sfx_dash": ["sfx_dash_1", "sfx_dash_2", "sfx_dash_3"],
	"sfx_earth_shot": ["sfx_earth_shot_1", "sfx_earth_shot_2", "sfx_earth_shot_3"],
	"sfx_enemy_die": ["sfx_enemy_die_1", "sfx_enemy_die_2", "sfx_enemy_die_3"],
	"sfx_fire_shot": ["sfx_fire_shot_1", "sfx_fire_shot_2", "sfx_fire_shot_3"],
	"sfx_footstep_dirt": ["sfx_footstep_dirt_1", "sfx_footstep_dirt_2", "sfx_footstep_dirt_3"],
	"sfx_hero_hurt": ["sfx_hero_hurt_1", "sfx_hero_hurt_2", "sfx_hero_hurt_3"],
	"sfx_hero_swing_heavy": ["sfx_hero_swing_heavy_1", "sfx_hero_swing_heavy_2"],
	"sfx_hit_armour": ["sfx_hit_armour_1", "sfx_hit_armour_2", "sfx_hit_armour_3"],
	"sfx_hit_flesh": ["sfx_hit_flesh_1", "sfx_hit_flesh_2", "sfx_hit_flesh_3"],
	"sfx_hit_stone": ["sfx_hit_stone_1", "sfx_hit_stone_2", "sfx_hit_stone_3"],
	"sfx_loot_collect": ["sfx_loot_collect_1", "sfx_loot_collect_2", "sfx_loot_collect_3"],
	"sfx_loot_drop": ["sfx_loot_drop_1", "sfx_loot_drop_2", "sfx_loot_drop_3"],
	"sfx_spell_cast": ["sfx_spell_cast_1", "sfx_spell_cast_2", "sfx_spell_cast_3"],
	"sfx_story_panel": ["sfx_story_panel_1", "sfx_story_panel_2", "sfx_story_panel_3"],
	"sfx_tower_build": ["sfx_tower_build_1", "sfx_tower_build_2", "sfx_tower_build_3"],
	"sfx_tower_sell": ["sfx_tower_sell_1", "sfx_tower_sell_2", "sfx_tower_sell_3"],
	"sfx_tower_upgrade": ["sfx_tower_upgrade_1", "sfx_tower_upgrade_2", "sfx_tower_upgrade_3"],
	"sfx_ui_click": ["sfx_ui_click_1", "sfx_ui_click_2", "sfx_ui_click_3"],
	"sfx_ui_hover": ["sfx_ui_hover_1", "sfx_ui_hover_2", "sfx_ui_hover_3", "sfx_ui_hover_4", "sfx_ui_hover_5"],
	"sfx_ui_move": ["sfx_ui_move_1", "sfx_ui_move_2", "sfx_ui_move_3"],
	"sfx_water_shot": ["sfx_water_shot_1", "sfx_water_shot_2", "sfx_water_shot_3"],
	"sfx_wildlife_badger": ["sfx_wildlife_badger_1", "sfx_wildlife_badger_2", "sfx_wildlife_badger_3", "sfx_wildlife_badger_4"],
	"sfx_wildlife_bear": ["sfx_wildlife_bear_1", "sfx_wildlife_bear_2", "sfx_wildlife_bear_3", "sfx_wildlife_bear_4", "sfx_wildlife_bear_5", "sfx_wildlife_bear_6", "sfx_wildlife_bear_7", "sfx_wildlife_bear_8"],
	"sfx_wildlife_boar": ["sfx_wildlife_boar_1", "sfx_wildlife_boar_2", "sfx_wildlife_boar_3", "sfx_wildlife_boar_4"],
	"sfx_wildlife_deer": ["sfx_wildlife_deer_1", "sfx_wildlife_deer_2", "sfx_wildlife_deer_3", "sfx_wildlife_deer_4"],
	"sfx_wildlife_fox": ["sfx_wildlife_fox_1", "sfx_wildlife_fox_2", "sfx_wildlife_fox_3", "sfx_wildlife_fox_4"],
	"sfx_wildlife_hawk": ["sfx_wildlife_hawk_1", "sfx_wildlife_hawk_2", "sfx_wildlife_hawk_3", "sfx_wildlife_hawk_4"],
	"sfx_wildlife_rabbit": ["sfx_wildlife_rabbit_1", "sfx_wildlife_rabbit_2", "sfx_wildlife_rabbit_3", "sfx_wildlife_rabbit_4"],
	"sfx_wildlife_raccoon": ["sfx_wildlife_raccoon_1", "sfx_wildlife_raccoon_2", "sfx_wildlife_raccoon_3", "sfx_wildlife_raccoon_4"],
	"sfx_wildlife_raven": ["sfx_wildlife_raven_1", "sfx_wildlife_raven_2", "sfx_wildlife_raven_3", "sfx_wildlife_raven_4"],
	"sfx_wildlife_squirrel": ["sfx_wildlife_squirrel_1", "sfx_wildlife_squirrel_2", "sfx_wildlife_squirrel_3", "sfx_wildlife_squirrel_4"],
	"sfx_wildlife_viper": ["sfx_wildlife_viper_1", "sfx_wildlife_viper_2", "sfx_wildlife_viper_3", "sfx_wildlife_viper_4"],
	"sfx_wildlife_wolf": ["sfx_wildlife_wolf_1", "sfx_wildlife_wolf_2", "sfx_wildlife_wolf_3", "sfx_wildlife_wolf_4", "sfx_wildlife_wolf_5", "sfx_wildlife_wolf_6", "sfx_wildlife_wolf_7", "sfx_wildlife_wolf_8"],
	"swing_light": ["sfx_hero_swing_1", "sfx_hero_swing_2"],
	"impact": ["sfx_hit_flesh", "sfx_hit_armour", "sfx_hit_stone"],
}

## Element -> tower fire sound.
const ELEMENT_SHOTS: Array[String] = [
	"sfx_fire_shot", "sfx_water_shot", "sfx_earth_shot", "sfx_air_shot",
]

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []

## id -> how many are sounding, and id -> when it may next trigger.
var _active: Dictionary = {}
var _next_allowed: Dictionary = {}

## The last variant chosen per group, so a group of two never repeats itself
## twice in a row - which is the case pure randomness gets audibly wrong.
var _last_variant: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioBuses.ensure()
	_load_streams()
	_build_voices()

	EventBus.hero_swing_started.connect(_on_swing_started)
	EventBus.hero_attack_landed.connect(_on_attack_landed)
	EventBus.footfall.connect(_on_footfall)
	EventBus.hero_damaged.connect(_on_hero_damaged)
	EventBus.hero_died.connect(func(_at: Vector2) -> void: play("sfx_hero_death"))
	EventBus.hero_dashed.connect(func(_i: float) -> void: play("sfx_dash"))
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.tower_destroyed.connect(_on_tower_destroyed)
	EventBus.tower_changed.connect(_on_tower_changed)
	EventBus.town_damaged.connect(func(_a: float, _c: float, _m: float) -> void: play("sfx_town_damaged"))
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.war_horn_activated.connect(func(_d: float) -> void: play("sfx_war_horn"))
	EventBus.raid_available.connect(func(_s: float) -> void: play("sfx_raid_ready"))
	EventBus.boss_spawned.connect(func(_id: String, _a: int) -> void: play("sfx_boss_spawn"))
	# The boss phase has new visual weight but no dedicated recording. Layering
	# two existing low-frequency cues gives it matching audio punctuation without
	# adding an untracked asset to the production manifest.
	EventBus.boss_phase_changed.connect(func(_id: String, _p: int, _name: String) -> void:
		play("sfx_boss_spawn", -4.0)
		play("sfx_spell_nova", -2.0))
	EventBus.wave_started.connect(func(_n: int, _l: Array) -> void: play("sfx_wave_incoming"))
	EventBus.construction_completed.connect(func(_id: String, _t: int) -> void: play("sfx_construction_done"))
	EventBus.relic_socketed.connect(func(_id: String) -> void: play("sfx_relic_socket"))

	# The four completions that finished in silence.
	#
	# Layered from cues that already ship rather than adding four recordings to
	# the manifest, which is the same call the boss phase change made and for the
	# same reason: an untracked asset is worse than a composite that works.
	#
	# A wave clearing is *relief*, so it is the quietest of the four and is the
	# only one that does not get a second layer - celebrating survival as hard as
	# a kill would flatten the difference between them.
	EventBus.wave_cleared.connect(func(_wave: int) -> void:
		play("sfx_ui_confirm", -6.0))
	EventBus.boss_defeated.connect(func(_id: String, _act: int) -> void:
		play("sfx_spell_nova")
		play("sfx_relic_socket", -3.0))
	EventBus.hero_levelled.connect(func(_l: int, _a: int, _s: int) -> void:
		play("sfx_relic_socket")
		play("sfx_loot_collect_1", -4.0))
	EventBus.hero_respawned.connect(func(_at: Vector2) -> void:
		play("sfx_construction_done", -8.0))

	# Buttons are created in code all over the HUD and the panels, so wiring them
	# individually would mean remembering to do it in every new screen. One hook
	# on node_added covers every button in the game, including future ones.
	get_tree().node_added.connect(_on_node_added)
	_wire_existing_buttons(get_tree().root)

	apply_volume()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed.bind(button))
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover)


func _wire_existing_buttons(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_wire_existing_buttons(child)


## A disabled button that still clicks is a lie, so a refused press gets the
## deny sound instead.
func _on_button_pressed(button: BaseButton) -> void:
	if button.disabled:
		play("sfx_ui_deny")
	else:
		play("sfx_ui_click")


func _on_button_hover() -> void:
	play("sfx_ui_hover")


## Live counters, for diagnosing "why is nothing playing".
var _attempts: int = 0
var _starts: int = 0
var _blocked_gap: int = 0
var _blocked_limit: int = 0
var _blocked_voices: int = 0
var _blocked_missing: int = 0


func debug_state() -> Dictionary:
	var busy: int = 0
	for v: AudioStreamPlayer in _voices:
		if v.playing:
			busy += 1
	return {
		"streams": _streams.size(),
		"attempts": _attempts, "starts": _starts,
		"blocked_gap": _blocked_gap, "blocked_limit": _blocked_limit,
		"blocked_voices": _blocked_voices, "blocked_missing": _blocked_missing,
		"voices_busy": busy, "active": _active.duplicate(),
	}


func _load_streams() -> void:
	for id: Variant in SOUNDS:
		var path: String = String(SOUNDS[id])
		if not ResourceLoader.exists(path):
			push_warning("Sfx: missing %s" % path)
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			continue
		# One-shots must never loop; a looping hit sound never stops.
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		_streams[String(id)] = stream

	# Loud failure. Silent audio that reports success is what let a broken
	# export ship three times.
	if _streams.is_empty():
		push_error("Sfx: no sound effects loaded. Every sound will be silent.")
	elif _streams.size() < SOUNDS.size():
		push_warning("Sfx: loaded %d of %d sounds." % [_streams.size(), SOUNDS.size()])


func _build_voices() -> void:
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = AudioBuses.SFX
		add_child(player)
		_voices.append(player)


## Reads the settings faders. Called by the options screen.
func apply_volume() -> void:
	AudioBuses.apply_volumes()


## Test and shutdown path: release any decoder still owned by a pooled voice.
## Finished voices intentionally retain their stream during play so they can be
## reused cheaply; a soak exits too quickly for the audio server to do this.
## The tree coming down takes every voice with it. A sound started by the
## last thing a headless gate did - a blood hit, a companion's strike - was
## still decoding at quit and read as four leaked ObjectDB instances, only
## on the runs where it had not finished (2026-09-12). Every gate cannot be
## trusted to remember; the autoload can.
func _exit_tree() -> void:
	stop_immediately()
	# The audio thread releases a stopped playback on its next mix step. A
	# quit that tears the server down before that step reports the playback
	# as four leaked ObjectDB instances, and it is a coin toss (2026-09-12:
	# five of eight verbose runs of a gate that never stopped the music).
	# A short blocking pause here, at process exit only, lets the step run.
	OS.delay_msec(Balance.AUDIO_EXIT_SETTLE_MSEC)


func stop_immediately() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	_active.clear()


## Plays a sound by id. Silently does nothing if the file is missing, so an
## un-generated sound is an absence rather than a crash.
## Where the player is listening from, in world units, and whether anybody is.
##
## Published by whatever is watching the field and by nothing else. Headless
## there is no camera and no ear, so `play_at` is exactly `play` and every gate
## hears what it always heard.
var _ear: Vector2 = Vector2.ZERO
var _listening: bool = false


## The camera is watching here. Called each frame by the rig.
func listen_from(point: Vector2) -> void:
	_ear = point
	_listening = true


## Nobody is watching a field any more - a menu, a scope change, a gate.
func stop_listening() -> void:
	_listening = false


## Whether a position is being taken into account at all. For the gate.
func is_listening() -> bool:
	return _listening


## **A sound that happens somewhere.**
##
## The same recording as `play`, quieter by how far it is from what the camera
## is watching. Past `SFX_CUTOFF` it is dropped rather than played inaudibly,
## which hands the voice back to something the player can hear - on a field of a
## hundred torches, four camps and forty bodies that is most of the value.
##
## **It decides nothing.** A dropped sound changes no state: the caller has
## already done whatever it did, and this is the last thing it does. With no ear
## this is `play`, unchanged, which is what keeps the gates honest.
func play_at(id: String, at: Vector2, extra_db: float = 0.0) -> void:
	if not _listening:
		play(id, extra_db)
		return
	var away: float = _ear.distance_to(at)
	if away > Balance.SFX_CUTOFF:
		return
	play(id, extra_db + distance_db(away))


## How much quieter a sound is at this distance. Flat inside `SFX_NEAR`, falling
## to `SFX_FAR_DB` by `SFX_FAR`, and no further - a floor rather than a curve
## running off to silence, because a distant tower should still be *there*.
## One of a group's takes, placed. The same `play_at` rules.
func play_group_at(group: String, at: Vector2, extra_db: float = 0.0) -> void:
	if not _listening:
		play_group(group, extra_db)
		return
	var away: float = _ear.distance_to(at)
	if away > Balance.SFX_CUTOFF:
		return
	play_group(group, extra_db + distance_db(away))


## **The sound a piece of gear of `rarity` makes when it arrives.**
##
## Deeper and louder the rarer it is, on `LOOT_RARITY_PITCH_DROP` and
## `LOOT_RARITY_DB` - the ladder a player has already learned from hundreds of
## drops off the ground. `extra_shift` is the caller's own pitch on top: the
## ground pickup adds its streak, the forge adds nothing.
##
## **One place, because it was about to be two.** The Smithy plays a piece
## coming off the anvil and the drop plays one coming off the road, and two
## copies of "what does rarity sound like" is how one of them ends up not
## knowing about a rarity that was added. The same argument
## `EnemyGroundStrike.strike_the_players` and `Stash.may_break` are single
## functions for.
func gear_arrived(rarity: int, extra_shift: float = 0.0) -> void:
	var shift: float = extra_shift - float(rarity) * Balance.LOOT_RARITY_PITCH_DROP
	play_group("sfx_loot_collect", float(rarity) * Balance.LOOT_RARITY_DB, shift)


func distance_db(away: float) -> float:
	var span: float = maxf(Balance.SFX_FAR - Balance.SFX_NEAR, 1.0)
	var out: float = clampf((away - Balance.SFX_NEAR) / span, 0.0, 1.0)
	return Balance.SFX_FAR_DB * out


## `pitch_shift` is a *ratio* on top of the mix's own drift: 0.05 is five
## percent sharp. Threaded through rather than set by the caller afterwards,
## because the voice is chosen, started and released in here and a caller has
## no handle on it.
func play(id: String, extra_db: float = 0.0, pitch_shift: float = 0.0) -> void:
	_attempts += 1
	var stream: AudioStream = _streams.get(id, null) as AudioStream
	if stream == null:
		# A sound recorded as several takes lives under `<id>_1..N` with a group
		# named for the base id. Falling through here is what lets every existing
		# call site keep asking for the sound it always asked for: adding takes
		# becomes a data change instead of a rename across a dozen scripts.
		if GROUPS.has(id):
			play_group(id, extra_db)
			return
		_blocked_missing += 1
		return
	_play_stream(id, stream, id, extra_db, pitch_shift)


## Starts one resolved recording. `mix_id` may be its variation group, allowing
## all takes to share one loudness, cooldown and polyphony budget. Wildlife
## calls need this: otherwise four quiet variants each inherit the much louder
## default and can bypass one another's cooldown.
func _play_stream(id: String, stream: AudioStream, mix_id: String,
		extra_db: float, pitch_shift: float = 0.0) -> void:
	var mix: Dictionary = MIX.get(mix_id, MIX.get(id, DEFAULT_MIX))
	var limiter_id: String = mix_id if MIX.has(mix_id) else id

	var now: float = float(Time.get_ticks_msec()) / 1000.0

	if now < float(_next_allowed.get(limiter_id, 0.0)):
		_blocked_gap += 1
		return
	if int(_active.get(limiter_id, 0)) >= int(mix.get("limit", 3)):
		_blocked_limit += 1
		return

	var voice: AudioStreamPlayer = _free_voice()
	if voice == null:
		_blocked_voices += 1
		return
	_starts += 1

	var drift: float = float(mix.get("pitch", 0.1))
	voice.stream = stream
	# Pitch drift is symmetric in ratio, not in cents, which is close enough at
	# these small ranges and much easier to reason about.
	voice.pitch_scale = maxf((1.0 + randf_range(-drift, drift))
		* (1.0 + pitch_shift), 0.05)
	voice.volume_db = float(mix.get("db", -8.0)) + extra_db
	voice.play()

	_next_allowed[limiter_id] = now + float(mix.get("gap", 0.04))
	_active[limiter_id] = int(_active.get(limiter_id, 0)) + 1
	# Decrementing on `finished` keeps the count honest without polling.
	var release: Callable = func() -> void:
		_active[limiter_id] = maxi(int(_active.get(limiter_id, 0)) - 1, 0)
	voice.finished.connect(release, CONNECT_ONE_SHOT)


## Plays one of a group's variants, never the same one twice running.
func play_group(group: String, extra_db: float = 0.0, pitch_shift: float = 0.0) -> void:
	var options: Array = GROUPS.get(group, []) as Array
	if options.is_empty():
		return
	var index: int = randi() % options.size()
	var choice: String = String(options[index])
	if options.size() > 1 and choice == String(_last_variant.get(group, "")):
		# Select uniformly from every index except the previous one. A simple
		# re-roll can land on the same take again, contradicting the audible
		# guarantee this group exists to provide.
		index = (index + 1 + randi() % (options.size() - 1)) % options.size()
		choice = String(options[index])
	_last_variant[group] = choice
	if GROUPS.has(choice):
		play_group(choice, extra_db, pitch_shift)
		return
	var stream: AudioStream = _streams.get(choice, null) as AudioStream
	if stream == null:
		_blocked_missing += 1
		return
	# A group-level row is intentional mix policy for every take. Groups without
	# one retain their established per-variation mix rows.
	var mix_id: String = variation_mix_id(group, choice)
	_play_stream(choice, stream, mix_id, extra_db, pitch_shift)


## Side-effect-free resolution shared with the release gate. Keeping this
## policy inspectable avoids starting a real decoder merely to prove which
## cooldown/mix key a variation will use during a short headless validation.
func variation_mix_id(group: String, choice: String) -> String:
	return group if MIX.has(group) else choice


func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice
	return null


# ==============================================================================
# EventBus reactions
# ==============================================================================

## Every swing, hit or miss. This is the sound the player is owed for pressing
## the button.
func _on_swing_started(chain_step: int, at: Vector2) -> void:
	if chain_step >= Balance.HERO_CHAIN_LENGTH - 1:
		play_at("sfx_hero_swing_heavy", at)
	else:
		play_group_at("swing_light", at)


## Only the impact here - the whoosh already played when the swing started.
## One impact per swing however many it caught, with a small boost for a wide
## hit: six overlapping impacts is noise, not weight.
func _on_attack_landed(_chain_step: int, targets: int, at: Vector2, hide: int = 0) -> void:
	play_group_at(hit_group_for(hide), at, minf(float(targets - 1) * 1.2, 4.0))


## Which impact a blow makes, by what it landed on. Flesh cracks, armour
## rings, stone chips; a spirit takes the flesh sound, softer, because a
## fourth recording is not what makes it read as a spirit - the sparks do.
static func hit_group_for(hide: int) -> String:
	match hide:
		EnemyData.Hide.ARMOUR:
			return "sfx_hit_armour"
		EnemyData.Hide.STONE:
			return "sfx_hit_stone"
	return "sfx_hit_flesh"


## Footsteps are throttled hard. Forty walking enemies would otherwise be a
## continuous gravel roar, so only the hero and genuinely heavy things are heard.
func _on_footfall(at: Vector2, mass: float) -> void:
	if mass >= Balance.ANIM_SHAKE_MASS_THRESHOLD:
		play_at("sfx_footstep_heavy", at)
	elif mass <= Balance.ANIM_MASS_HERO:
		play_at("sfx_footstep_dirt", at)


func _on_hero_damaged(_amount: float, _from: Vector2, _at: Vector2) -> void:
	play("sfx_hero_hurt")


func _on_enemy_died(_enemy_id: String, at: Vector2) -> void:
	play_at("sfx_enemy_die", at)


func _on_tower_fired(anchor: Vector2i, at: Vector2) -> void:
	var tower: TowerData = RunState.tower_at(anchor)
	if tower == null:
		return
	var index: int = clampi(int(tower.element), 0, ELEMENT_SHOTS.size() - 1)
	play_at(ELEMENT_SHOTS[index], at)


## **A tower was broken.** Stone coming down, where it came down.
##
## `tower_destroyed` is emitted immediately before `tower_changed` and Godot's
## signals are synchronous, so this runs to completion first and the anchor it
## leaves behind is consumed by the very next handler. That is the whole lifetime
## of `_broken`: it exists because an empty tile cannot say *why* it is empty.
func _on_tower_destroyed(anchor: Vector2i, at: Vector2) -> void:
	_broken = anchor
	play_group_at("sfx_hit_stone", at, 2.0)


func _on_tower_changed(anchor: Vector2i) -> void:
	# **Broken is not sold.** This told the two apart by whether the tile is empty
	# now, and a tower smashed by a siege breed empties its tile exactly as a sale
	# does - so losing a tower to the enemy played a dismantle-and-refund noise.
	if anchor == _broken:
		_broken = NO_ANCHOR
		return
	# Built or upgraded versus sold, told apart by whether anything is there now.
	if RunState.tile_is_empty(anchor):
		play("sfx_tower_sell")
	elif RunState.level_at(anchor) > 1:
		play("sfx_tower_upgrade")
	else:
		play("sfx_tower_build")


func _on_spell_cast(spell_id: String, _slot: int, at: Vector2) -> void:
	match spell_id:
		"rift_step":
			play_at("sfx_spell_blink", at)
		"cinder_nova", "tremor":
			play_at("sfx_spell_nova", at)
		_:
			play_at("sfx_spell_cast", at)
