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
	"sfx_meteor_impact_1": "res://audio/sfx/sfx_meteor_impact_1.ogg",
	"sfx_meteor_impact_2": "res://audio/sfx/sfx_meteor_impact_2.ogg",
	"sfx_meteor_impact_3": "res://audio/sfx/sfx_meteor_impact_3.ogg",
	"sfx_meteor_impact_4": "res://audio/sfx/sfx_meteor_impact_4.ogg",
	"sfx_meteor_impact_5": "res://audio/sfx/sfx_meteor_impact_5.ogg",
	"sfx_meteor_impact_6": "res://audio/sfx/sfx_meteor_impact_6.ogg",
	"sfx_meteor_impact_7": "res://audio/sfx/sfx_meteor_impact_7.ogg",
	"sfx_meteor_impact_8": "res://audio/sfx/sfx_meteor_impact_8.ogg",
	"sfx_meteor_impact_9": "res://audio/sfx/sfx_meteor_impact_9.ogg",
	"sfx_meteor_impact_10": "res://audio/sfx/sfx_meteor_impact_10.ogg",
	"sfx_meteor_impact_11": "res://audio/sfx/sfx_meteor_impact_11.ogg",
	"sfx_meteor_impact_12": "res://audio/sfx/sfx_meteor_impact_12.ogg",
	"sfx_meteor_whistle_1": "res://audio/sfx/sfx_meteor_whistle_1.ogg",
	"sfx_meteor_whistle_2": "res://audio/sfx/sfx_meteor_whistle_2.ogg",
	"sfx_meteor_whistle_3": "res://audio/sfx/sfx_meteor_whistle_3.ogg",
	"sfx_meteor_whistle_4": "res://audio/sfx/sfx_meteor_whistle_4.ogg",
	"sfx_meteor_whistle_5": "res://audio/sfx/sfx_meteor_whistle_5.ogg",
	"sfx_meteor_whistle_6": "res://audio/sfx/sfx_meteor_whistle_6.ogg",
	"sfx_meteor_whistle_7": "res://audio/sfx/sfx_meteor_whistle_7.ogg",
	"sfx_meteor_whistle_8": "res://audio/sfx/sfx_meteor_whistle_8.ogg",
	"sfx_quake_1": "res://audio/sfx/sfx_quake_1.ogg",
	"sfx_quake_2": "res://audio/sfx/sfx_quake_2.ogg",
	"sfx_quake_3": "res://audio/sfx/sfx_quake_3.ogg",
	"sfx_quake_4": "res://audio/sfx/sfx_quake_4.ogg",
	"sfx_quake_5": "res://audio/sfx/sfx_quake_5.ogg",
	"sfx_quake_6": "res://audio/sfx/sfx_quake_6.ogg",
	"sfx_quake_7": "res://audio/sfx/sfx_quake_7.ogg",
	"sfx_quake_8": "res://audio/sfx/sfx_quake_8.ogg",
	"sfx_quake_9": "res://audio/sfx/sfx_quake_9.ogg",
	"sfx_quake_10": "res://audio/sfx/sfx_quake_10.ogg",
	"sfx_quake_11": "res://audio/sfx/sfx_quake_11.ogg",
	"sfx_quake_12": "res://audio/sfx/sfx_quake_12.ogg",
	"sfx_quake_13": "res://audio/sfx/sfx_quake_13.ogg",
	"sfx_quake_14": "res://audio/sfx/sfx_quake_14.ogg",
	"sfx_quake_15": "res://audio/sfx/sfx_quake_15.ogg",
	"sfx_quake_16": "res://audio/sfx/sfx_quake_16.ogg",
	"sfx_thunder_far_1": "res://audio/sfx/sfx_thunder_far_1.ogg",
	"sfx_thunder_far_2": "res://audio/sfx/sfx_thunder_far_2.ogg",
	"sfx_thunder_far_3": "res://audio/sfx/sfx_thunder_far_3.ogg",
	"sfx_thunder_far_4": "res://audio/sfx/sfx_thunder_far_4.ogg",
	"sfx_thunder_far_5": "res://audio/sfx/sfx_thunder_far_5.ogg",
	"sfx_thunder_far_6": "res://audio/sfx/sfx_thunder_far_6.ogg",
	"sfx_thunder_near_1": "res://audio/sfx/sfx_thunder_near_1.ogg",
	"sfx_thunder_near_2": "res://audio/sfx/sfx_thunder_near_2.ogg",
	"sfx_thunder_near_3": "res://audio/sfx/sfx_thunder_near_3.ogg",
	"sfx_thunder_near_4": "res://audio/sfx/sfx_thunder_near_4.ogg",
	"sfx_thunder_near_5": "res://audio/sfx/sfx_thunder_near_5.ogg",
	"sfx_thunder_near_6": "res://audio/sfx/sfx_thunder_near_6.ogg",
	"sfx_thunder_near_7": "res://audio/sfx/sfx_thunder_near_7.ogg",
	"sfx_thunder_near_8": "res://audio/sfx/sfx_thunder_near_8.ogg",
	"sfx_thunder_near_9": "res://audio/sfx/sfx_thunder_near_9.ogg",
	"sfx_thunder_near_10": "res://audio/sfx/sfx_thunder_near_10.ogg",
	"sfx_thunder_near_11": "res://audio/sfx/sfx_thunder_near_11.ogg",
	"sfx_thunder_near_12": "res://audio/sfx/sfx_thunder_near_12.ogg",
	"sfx_thunder_near_13": "res://audio/sfx/sfx_thunder_near_13.ogg",
	"sfx_thunder_near_14": "res://audio/sfx/sfx_thunder_near_14.ogg",
	"sfx_thunder_near_15": "res://audio/sfx/sfx_thunder_near_15.ogg",
	"sfx_thunder_near_16": "res://audio/sfx/sfx_thunder_near_16.ogg",
	"sfx_thunder_near_17": "res://audio/sfx/sfx_thunder_near_17.ogg",
	"sfx_thunder_near_18": "res://audio/sfx/sfx_thunder_near_18.ogg",
	"sfx_thunder_near_19": "res://audio/sfx/sfx_thunder_near_19.ogg",
	"sfx_thunder_near_20": "res://audio/sfx/sfx_thunder_near_20.ogg",
	"sfx_thunder_near_21": "res://audio/sfx/sfx_thunder_near_21.ogg",
	"sfx_thunder_near_22": "res://audio/sfx/sfx_thunder_near_22.ogg",
	"sfx_thunder_near_23": "res://audio/sfx/sfx_thunder_near_23.ogg",
	"sfx_thunder_near_24": "res://audio/sfx/sfx_thunder_near_24.ogg",
	"sfx_thunder_near_25": "res://audio/sfx/sfx_thunder_near_25.ogg",
	"sfx_thunder_near_26": "res://audio/sfx/sfx_thunder_near_26.ogg",
	"sfx_thunder_near_27": "res://audio/sfx/sfx_thunder_near_27.ogg",
	"sfx_thunder_near_28": "res://audio/sfx/sfx_thunder_near_28.ogg",
	"sfx_thunder_near_29": "res://audio/sfx/sfx_thunder_near_29.ogg",
	"sfx_thunder_near_30": "res://audio/sfx/sfx_thunder_near_30.ogg",
	"sfx_thunder_near_31": "res://audio/sfx/sfx_thunder_near_31.ogg",
	"sfx_thunder_near_32": "res://audio/sfx/sfx_thunder_near_32.ogg",
	"sfx_tornado_1": "res://audio/sfx/sfx_tornado_1.ogg",
	"sfx_tornado_2": "res://audio/sfx/sfx_tornado_2.ogg",
	"sfx_tornado_3": "res://audio/sfx/sfx_tornado_3.ogg",
	"sfx_tornado_4": "res://audio/sfx/sfx_tornado_4.ogg",
	"sfx_tornado_5": "res://audio/sfx/sfx_tornado_5.ogg",
	"sfx_tornado_6": "res://audio/sfx/sfx_tornado_6.ogg",
	"sfx_tornado_7": "res://audio/sfx/sfx_tornado_7.ogg",
	"sfx_tornado_8": "res://audio/sfx/sfx_tornado_8.ogg",
	"sfx_tornado_9": "res://audio/sfx/sfx_tornado_9.ogg",
	"sfx_tornado_10": "res://audio/sfx/sfx_tornado_10.ogg",
	"sfx_tornado_11": "res://audio/sfx/sfx_tornado_11.ogg",
	"sfx_tornado_12": "res://audio/sfx/sfx_tornado_12.ogg",
	"sfx_tornado_13": "res://audio/sfx/sfx_tornado_13.ogg",
	"sfx_tornado_14": "res://audio/sfx/sfx_tornado_14.ogg",
	"sfx_tornado_15": "res://audio/sfx/sfx_tornado_15.ogg",
	"sfx_tornado_16": "res://audio/sfx/sfx_tornado_16.ogg",
	"sfx_tornado_17": "res://audio/sfx/sfx_tornado_17.ogg",
	"sfx_tornado_18": "res://audio/sfx/sfx_tornado_18.ogg",
	"sfx_tornado_19": "res://audio/sfx/sfx_tornado_19.ogg",
	"sfx_tornado_20": "res://audio/sfx/sfx_tornado_20.ogg",
	"sfx_tornado_21": "res://audio/sfx/sfx_tornado_21.ogg",
	"sfx_tornado_22": "res://audio/sfx/sfx_tornado_22.ogg",
	"sfx_tornado_23": "res://audio/sfx/sfx_tornado_23.ogg",
	"sfx_tornado_24": "res://audio/sfx/sfx_tornado_24.ogg",
	"sfx_tornado_25": "res://audio/sfx/sfx_tornado_25.ogg",
	"sfx_tornado_26": "res://audio/sfx/sfx_tornado_26.ogg",
	"sfx_tornado_27": "res://audio/sfx/sfx_tornado_27.ogg",
	"sfx_tornado_28": "res://audio/sfx/sfx_tornado_28.ogg",
	"sfx_tornado_29": "res://audio/sfx/sfx_tornado_29.ogg",
	"sfx_tornado_30": "res://audio/sfx/sfx_tornado_30.ogg",
	"sfx_tornado_31": "res://audio/sfx/sfx_tornado_31.ogg",
	"sfx_tornado_32": "res://audio/sfx/sfx_tornado_32.ogg",
	"sfx_tornado_33": "res://audio/sfx/sfx_tornado_33.ogg",
	"sfx_tornado_34": "res://audio/sfx/sfx_tornado_34.ogg",
	"sfx_tornado_35": "res://audio/sfx/sfx_tornado_35.ogg",
	"sfx_tornado_36": "res://audio/sfx/sfx_tornado_36.ogg",
	"sfx_wildfire_1": "res://audio/sfx/sfx_wildfire_1.ogg",
	"sfx_wildfire_2": "res://audio/sfx/sfx_wildfire_2.ogg",
	"sfx_wildfire_3": "res://audio/sfx/sfx_wildfire_3.ogg",
	"sfx_wildfire_4": "res://audio/sfx/sfx_wildfire_4.ogg",
	"sfx_wildfire_5": "res://audio/sfx/sfx_wildfire_5.ogg",
	"sfx_wildfire_6": "res://audio/sfx/sfx_wildfire_6.ogg",
	"sfx_wildfire_7": "res://audio/sfx/sfx_wildfire_7.ogg",
	"sfx_wildfire_8": "res://audio/sfx/sfx_wildfire_8.ogg",
	"sfx_wildfire_9": "res://audio/sfx/sfx_wildfire_9.ogg",
	"sfx_wildfire_10": "res://audio/sfx/sfx_wildfire_10.ogg",
	"sfx_wildfire_11": "res://audio/sfx/sfx_wildfire_11.ogg",
	"sfx_wildfire_12": "res://audio/sfx/sfx_wildfire_12.ogg",
	"sfx_wildfire_13": "res://audio/sfx/sfx_wildfire_13.ogg",
	"sfx_wildfire_14": "res://audio/sfx/sfx_wildfire_14.ogg",
	"sfx_wildfire_15": "res://audio/sfx/sfx_wildfire_15.ogg",
	"sfx_wildfire_16": "res://audio/sfx/sfx_wildfire_16.ogg",
	"sfx_wildfire_17": "res://audio/sfx/sfx_wildfire_17.ogg",
	"sfx_wildfire_18": "res://audio/sfx/sfx_wildfire_18.ogg",
	"sfx_wildfire_19": "res://audio/sfx/sfx_wildfire_19.ogg",
	"sfx_wildfire_20": "res://audio/sfx/sfx_wildfire_20.ogg",
	"sfx_wildfire_21": "res://audio/sfx/sfx_wildfire_21.ogg",
	"sfx_wildfire_22": "res://audio/sfx/sfx_wildfire_22.ogg",
	"sfx_wildfire_23": "res://audio/sfx/sfx_wildfire_23.ogg",
	"sfx_wildfire_24": "res://audio/sfx/sfx_wildfire_24.ogg",
	"sfx_wildfire_25": "res://audio/sfx/sfx_wildfire_25.ogg",
	"sfx_wildfire_26": "res://audio/sfx/sfx_wildfire_26.ogg",
	"sfx_wildfire_27": "res://audio/sfx/sfx_wildfire_27.ogg",
	"sfx_wildfire_28": "res://audio/sfx/sfx_wildfire_28.ogg",
	"sfx_wildfire_29": "res://audio/sfx/sfx_wildfire_29.ogg",
	"sfx_wildfire_30": "res://audio/sfx/sfx_wildfire_30.ogg",
	"sfx_wildfire_31": "res://audio/sfx/sfx_wildfire_31.ogg",
	"sfx_wildfire_32": "res://audio/sfx/sfx_wildfire_32.ogg",
	"sfx_wildfire_33": "res://audio/sfx/sfx_wildfire_33.ogg",
	"sfx_wildfire_34": "res://audio/sfx/sfx_wildfire_34.ogg",
	"sfx_wildfire_35": "res://audio/sfx/sfx_wildfire_35.ogg",
	"sfx_wildfire_36": "res://audio/sfx/sfx_wildfire_36.ogg",
	"sfx_wildfire_37": "res://audio/sfx/sfx_wildfire_37.ogg",
	"sfx_wildfire_38": "res://audio/sfx/sfx_wildfire_38.ogg",
	"sfx_wildfire_39": "res://audio/sfx/sfx_wildfire_39.ogg",
	"sfx_wildfire_40": "res://audio/sfx/sfx_wildfire_40.ogg",
	"sfx_wildfire_41": "res://audio/sfx/sfx_wildfire_41.ogg",
	"sfx_wildfire_42": "res://audio/sfx/sfx_wildfire_42.ogg",
	"sfx_wildfire_43": "res://audio/sfx/sfx_wildfire_43.ogg",
	"sfx_wildfire_44": "res://audio/sfx/sfx_wildfire_44.ogg",
	"sfx_wildfire_45": "res://audio/sfx/sfx_wildfire_45.ogg",
	"sfx_wildfire_46": "res://audio/sfx/sfx_wildfire_46.ogg",
	"sfx_wildfire_47": "res://audio/sfx/sfx_wildfire_47.ogg",
	"sfx_wildfire_48": "res://audio/sfx/sfx_wildfire_48.ogg",
	"sfx_wildfire_49": "res://audio/sfx/sfx_wildfire_49.ogg",
	"sfx_wildfire_50": "res://audio/sfx/sfx_wildfire_50.ogg",
	"sfx_wildfire_51": "res://audio/sfx/sfx_wildfire_51.ogg",
	"sfx_wildfire_52": "res://audio/sfx/sfx_wildfire_52.ogg",
	"sfx_wildfire_53": "res://audio/sfx/sfx_wildfire_53.ogg",
	"sfx_wildfire_54": "res://audio/sfx/sfx_wildfire_54.ogg",
	"sfx_wildfire_55": "res://audio/sfx/sfx_wildfire_55.ogg",
	"sfx_wildfire_56": "res://audio/sfx/sfx_wildfire_56.ogg",
	"sfx_wildfire_57": "res://audio/sfx/sfx_wildfire_57.ogg",
	"sfx_wildfire_58": "res://audio/sfx/sfx_wildfire_58.ogg",
	"sfx_wildfire_59": "res://audio/sfx/sfx_wildfire_59.ogg",
	"sfx_wildfire_60": "res://audio/sfx/sfx_wildfire_60.ogg",
	"sfx_wildfire_61": "res://audio/sfx/sfx_wildfire_61.ogg",
	"sfx_wildfire_62": "res://audio/sfx/sfx_wildfire_62.ogg",
	"sfx_wildfire_63": "res://audio/sfx/sfx_wildfire_63.ogg",
	"sfx_wildfire_64": "res://audio/sfx/sfx_wildfire_64.ogg",
	"sfx_wildfire_65": "res://audio/sfx/sfx_wildfire_65.ogg",
	"sfx_wildfire_66": "res://audio/sfx/sfx_wildfire_66.ogg",
	"sfx_wildfire_67": "res://audio/sfx/sfx_wildfire_67.ogg",
	"sfx_wildfire_68": "res://audio/sfx/sfx_wildfire_68.ogg",
	"sfx_wildfire_69": "res://audio/sfx/sfx_wildfire_69.ogg",
	"sfx_wildfire_70": "res://audio/sfx/sfx_wildfire_70.ogg",
	"sfx_wildfire_71": "res://audio/sfx/sfx_wildfire_71.ogg",
	"sfx_wildfire_72": "res://audio/sfx/sfx_wildfire_72.ogg",
	"sfx_wildfire_73": "res://audio/sfx/sfx_wildfire_73.ogg",
	"sfx_wildfire_74": "res://audio/sfx/sfx_wildfire_74.ogg",
	"sfx_wildfire_75": "res://audio/sfx/sfx_wildfire_75.ogg",
	"sfx_wildfire_76": "res://audio/sfx/sfx_wildfire_76.ogg",
	"sfx_achievement_1": "res://audio/sfx/sfx_achievement_1.ogg",
	"sfx_achievement_2": "res://audio/sfx/sfx_achievement_2.ogg",
	"sfx_achievement_3": "res://audio/sfx/sfx_achievement_3.ogg",
	"sfx_air_shot_1": "res://audio/sfx/sfx_air_shot_1.ogg",
	"sfx_air_shot_2": "res://audio/sfx/sfx_air_shot_2.ogg",
	"sfx_air_shot_3": "res://audio/sfx/sfx_air_shot_3.ogg",
	"sfx_boss_fall_1": "res://audio/sfx/sfx_boss_fall_1.ogg",
	"sfx_boss_fall_2": "res://audio/sfx/sfx_boss_fall_2.ogg",
	"sfx_boss_fall_3": "res://audio/sfx/sfx_boss_fall_3.ogg",
	"sfx_boss_fall_4": "res://audio/sfx/sfx_boss_fall_4.ogg",
	"sfx_boss_fall_5": "res://audio/sfx/sfx_boss_fall_5.ogg",
	"sfx_boss_fall_6": "res://audio/sfx/sfx_boss_fall_6.ogg",
	"sfx_boss_fall_7": "res://audio/sfx/sfx_boss_fall_7.ogg",
	"sfx_boss_fall_8": "res://audio/sfx/sfx_boss_fall_8.ogg",
	"sfx_boss_fall_9": "res://audio/sfx/sfx_boss_fall_9.ogg",
	"sfx_boss_fall_10": "res://audio/sfx/sfx_boss_fall_10.ogg",
	"sfx_boss_fall_11": "res://audio/sfx/sfx_boss_fall_11.ogg",
	"sfx_boss_spawn": "res://audio/sfx/sfx_boss_spawn.ogg",
	"sfx_boss_stinger_1": "res://audio/sfx/sfx_boss_stinger_1.ogg",
	"sfx_boss_stinger_2": "res://audio/sfx/sfx_boss_stinger_2.ogg",
	"sfx_boss_stinger_3": "res://audio/sfx/sfx_boss_stinger_3.ogg",
	"sfx_boss_stinger_4": "res://audio/sfx/sfx_boss_stinger_4.ogg",
	"sfx_camp_razed_1": "res://audio/sfx/sfx_camp_razed_1.ogg",
	"sfx_camp_razed_2": "res://audio/sfx/sfx_camp_razed_2.ogg",
	"sfx_camp_razed_3": "res://audio/sfx/sfx_camp_razed_3.ogg",
	"sfx_camp_razed_4": "res://audio/sfx/sfx_camp_razed_4.ogg",
	"sfx_camp_razed_5": "res://audio/sfx/sfx_camp_razed_5.ogg",
	"sfx_camp_razed_6": "res://audio/sfx/sfx_camp_razed_6.ogg",
	"sfx_camp_razed_7": "res://audio/sfx/sfx_camp_razed_7.ogg",
	"sfx_camp_razed_8": "res://audio/sfx/sfx_camp_razed_8.ogg",
	"sfx_camp_razed_9": "res://audio/sfx/sfx_camp_razed_9.ogg",
	"sfx_camp_razed_10": "res://audio/sfx/sfx_camp_razed_10.ogg",
	"sfx_camp_razed_11": "res://audio/sfx/sfx_camp_razed_11.ogg",
	"sfx_camp_razed_12": "res://audio/sfx/sfx_camp_razed_12.ogg",
	"sfx_chest_open_1": "res://audio/sfx/sfx_chest_open_1.ogg",
	"sfx_chest_open_2": "res://audio/sfx/sfx_chest_open_2.ogg",
	"sfx_chest_open_3": "res://audio/sfx/sfx_chest_open_3.ogg",
	"sfx_chieftain_roar_1": "res://audio/sfx/sfx_chieftain_roar_1.ogg",
	"sfx_chieftain_roar_2": "res://audio/sfx/sfx_chieftain_roar_2.ogg",
	"sfx_chieftain_roar_3": "res://audio/sfx/sfx_chieftain_roar_3.ogg",
	"sfx_chieftain_roar_4": "res://audio/sfx/sfx_chieftain_roar_4.ogg",
	"sfx_chieftain_roar_5": "res://audio/sfx/sfx_chieftain_roar_5.ogg",
	"sfx_chieftain_roar_6": "res://audio/sfx/sfx_chieftain_roar_6.ogg",
	"sfx_chieftain_roar_7": "res://audio/sfx/sfx_chieftain_roar_7.ogg",
	"sfx_chieftain_roar_8": "res://audio/sfx/sfx_chieftain_roar_8.ogg",
	"sfx_companion_down_1": "res://audio/sfx/sfx_companion_down_1.ogg",
	"sfx_companion_down_2": "res://audio/sfx/sfx_companion_down_2.ogg",
	"sfx_companion_down_3": "res://audio/sfx/sfx_companion_down_3.ogg",
	"sfx_companion_down_4": "res://audio/sfx/sfx_companion_down_4.ogg",
	"sfx_companion_down_5": "res://audio/sfx/sfx_companion_down_5.ogg",
	"sfx_companion_down_6": "res://audio/sfx/sfx_companion_down_6.ogg",
	"sfx_companion_down_7": "res://audio/sfx/sfx_companion_down_7.ogg",
	"sfx_companion_down_8": "res://audio/sfx/sfx_companion_down_8.ogg",
	"sfx_companion_down_9": "res://audio/sfx/sfx_companion_down_9.ogg",
	"sfx_companion_down_10": "res://audio/sfx/sfx_companion_down_10.ogg",
	"sfx_companion_down_11": "res://audio/sfx/sfx_companion_down_11.ogg",
	"sfx_companion_down_12": "res://audio/sfx/sfx_companion_down_12.ogg",
	"sfx_companion_return_1": "res://audio/sfx/sfx_companion_return_1.ogg",
	"sfx_companion_return_2": "res://audio/sfx/sfx_companion_return_2.ogg",
	"sfx_companion_return_3": "res://audio/sfx/sfx_companion_return_3.ogg",
	"sfx_companion_return_4": "res://audio/sfx/sfx_companion_return_4.ogg",
	"sfx_companion_return_5": "res://audio/sfx/sfx_companion_return_5.ogg",
	"sfx_companion_return_6": "res://audio/sfx/sfx_companion_return_6.ogg",
	"sfx_companion_return_7": "res://audio/sfx/sfx_companion_return_7.ogg",
	"sfx_companion_return_8": "res://audio/sfx/sfx_companion_return_8.ogg",
	"sfx_companion_return_9": "res://audio/sfx/sfx_companion_return_9.ogg",
	"sfx_companion_return_10": "res://audio/sfx/sfx_companion_return_10.ogg",
	"sfx_companion_return_11": "res://audio/sfx/sfx_companion_return_11.ogg",
	"sfx_companion_return_12": "res://audio/sfx/sfx_companion_return_12.ogg",
	"sfx_companion_strike_1": "res://audio/sfx/sfx_companion_strike_1.ogg",
	"sfx_companion_strike_2": "res://audio/sfx/sfx_companion_strike_2.ogg",
	"sfx_companion_strike_3": "res://audio/sfx/sfx_companion_strike_3.ogg",
	"sfx_companion_strike_4": "res://audio/sfx/sfx_companion_strike_4.ogg",
	"sfx_companion_strike_5": "res://audio/sfx/sfx_companion_strike_5.ogg",
	"sfx_companion_strike_6": "res://audio/sfx/sfx_companion_strike_6.ogg",
	"sfx_companion_strike_7": "res://audio/sfx/sfx_companion_strike_7.ogg",
	"sfx_companion_strike_8": "res://audio/sfx/sfx_companion_strike_8.ogg",
	"sfx_companion_strike_9": "res://audio/sfx/sfx_companion_strike_9.ogg",
	"sfx_companion_strike_10": "res://audio/sfx/sfx_companion_strike_10.ogg",
	"sfx_companion_strike_11": "res://audio/sfx/sfx_companion_strike_11.ogg",
	"sfx_companion_strike_12": "res://audio/sfx/sfx_companion_strike_12.ogg",
	"sfx_companion_summon_1": "res://audio/sfx/sfx_companion_summon_1.ogg",
	"sfx_companion_summon_2": "res://audio/sfx/sfx_companion_summon_2.ogg",
	"sfx_companion_summon_3": "res://audio/sfx/sfx_companion_summon_3.ogg",
	"sfx_companion_summon_4": "res://audio/sfx/sfx_companion_summon_4.ogg",
	"sfx_companion_summon_5": "res://audio/sfx/sfx_companion_summon_5.ogg",
	"sfx_companion_summon_6": "res://audio/sfx/sfx_companion_summon_6.ogg",
	"sfx_companion_summon_7": "res://audio/sfx/sfx_companion_summon_7.ogg",
	"sfx_companion_summon_8": "res://audio/sfx/sfx_companion_summon_8.ogg",
	"sfx_companion_summon_9": "res://audio/sfx/sfx_companion_summon_9.ogg",
	"sfx_companion_summon_10": "res://audio/sfx/sfx_companion_summon_10.ogg",
	"sfx_companion_summon_11": "res://audio/sfx/sfx_companion_summon_11.ogg",
	"sfx_companion_summon_12": "res://audio/sfx/sfx_companion_summon_12.ogg",
	"sfx_companion_summon_13": "res://audio/sfx/sfx_companion_summon_13.ogg",
	"sfx_companion_summon_14": "res://audio/sfx/sfx_companion_summon_14.ogg",
	"sfx_companion_summon_15": "res://audio/sfx/sfx_companion_summon_15.ogg",
	"sfx_companion_summon_16": "res://audio/sfx/sfx_companion_summon_16.ogg",
	"sfx_construction_done": "res://audio/sfx/sfx_construction_done.ogg",
	"sfx_dash_1": "res://audio/sfx/sfx_dash_1.ogg",
	"sfx_dash_2": "res://audio/sfx/sfx_dash_2.ogg",
	"sfx_dash_3": "res://audio/sfx/sfx_dash_3.ogg",
	"sfx_drown_1": "res://audio/sfx/sfx_drown_1.ogg",
	"sfx_drown_2": "res://audio/sfx/sfx_drown_2.ogg",
	"sfx_drown_3": "res://audio/sfx/sfx_drown_3.ogg",
	"sfx_drown_4": "res://audio/sfx/sfx_drown_4.ogg",
	"sfx_drown_5": "res://audio/sfx/sfx_drown_5.ogg",
	"sfx_drown_6": "res://audio/sfx/sfx_drown_6.ogg",
	"sfx_drown_7": "res://audio/sfx/sfx_drown_7.ogg",
	"sfx_drown_8": "res://audio/sfx/sfx_drown_8.ogg",
	"sfx_dungeon_collapse_1": "res://audio/sfx/sfx_dungeon_collapse_1.ogg",
	"sfx_dungeon_collapse_2": "res://audio/sfx/sfx_dungeon_collapse_2.ogg",
	"sfx_dungeon_collapse_3": "res://audio/sfx/sfx_dungeon_collapse_3.ogg",
	"sfx_dungeon_collapse_4": "res://audio/sfx/sfx_dungeon_collapse_4.ogg",
	"sfx_dungeon_collapse_5": "res://audio/sfx/sfx_dungeon_collapse_5.ogg",
	"sfx_dungeon_collapse_6": "res://audio/sfx/sfx_dungeon_collapse_6.ogg",
	"sfx_dungeon_collapse_7": "res://audio/sfx/sfx_dungeon_collapse_7.ogg",
	"sfx_dungeon_collapse_8": "res://audio/sfx/sfx_dungeon_collapse_8.ogg",
	"sfx_dungeon_exit_1": "res://audio/sfx/sfx_dungeon_exit_1.ogg",
	"sfx_dungeon_exit_2": "res://audio/sfx/sfx_dungeon_exit_2.ogg",
	"sfx_dungeon_exit_3": "res://audio/sfx/sfx_dungeon_exit_3.ogg",
	"sfx_dungeon_exit_4": "res://audio/sfx/sfx_dungeon_exit_4.ogg",
	"sfx_dungeon_exit_5": "res://audio/sfx/sfx_dungeon_exit_5.ogg",
	"sfx_dungeon_exit_6": "res://audio/sfx/sfx_dungeon_exit_6.ogg",
	"sfx_dungeon_exit_7": "res://audio/sfx/sfx_dungeon_exit_7.ogg",
	"sfx_dungeon_exit_8": "res://audio/sfx/sfx_dungeon_exit_8.ogg",
	"sfx_dungeon_exit_9": "res://audio/sfx/sfx_dungeon_exit_9.ogg",
	"sfx_dungeon_exit_10": "res://audio/sfx/sfx_dungeon_exit_10.ogg",
	"sfx_dungeon_exit_11": "res://audio/sfx/sfx_dungeon_exit_11.ogg",
	"sfx_dungeon_exit_12": "res://audio/sfx/sfx_dungeon_exit_12.ogg",
	"sfx_dungeon_exit_13": "res://audio/sfx/sfx_dungeon_exit_13.ogg",
	"sfx_dungeon_exit_14": "res://audio/sfx/sfx_dungeon_exit_14.ogg",
	"sfx_dungeon_exit_15": "res://audio/sfx/sfx_dungeon_exit_15.ogg",
	"sfx_dungeon_exit_16": "res://audio/sfx/sfx_dungeon_exit_16.ogg",
	"sfx_dungeon_exit_17": "res://audio/sfx/sfx_dungeon_exit_17.ogg",
	"sfx_dungeon_exit_18": "res://audio/sfx/sfx_dungeon_exit_18.ogg",
	"sfx_dungeon_exit_19": "res://audio/sfx/sfx_dungeon_exit_19.ogg",
	"sfx_dungeon_exit_20": "res://audio/sfx/sfx_dungeon_exit_20.ogg",
	"sfx_earth_shot_1": "res://audio/sfx/sfx_earth_shot_1.ogg",
	"sfx_earth_shot_2": "res://audio/sfx/sfx_earth_shot_2.ogg",
	"sfx_earth_shot_3": "res://audio/sfx/sfx_earth_shot_3.ogg",
	"sfx_enemy_die_1": "res://audio/sfx/sfx_enemy_die_1.ogg",
	"sfx_enemy_die_2": "res://audio/sfx/sfx_enemy_die_2.ogg",
	"sfx_enemy_die_3": "res://audio/sfx/sfx_enemy_die_3.ogg",
	"sfx_fire_shot_1": "res://audio/sfx/sfx_fire_shot_1.ogg",
	"sfx_fire_shot_2": "res://audio/sfx/sfx_fire_shot_2.ogg",
	"sfx_fire_shot_3": "res://audio/sfx/sfx_fire_shot_3.ogg",
	"sfx_fish_bite_1": "res://audio/sfx/sfx_fish_bite_1.ogg",
	"sfx_fish_bite_2": "res://audio/sfx/sfx_fish_bite_2.ogg",
	"sfx_fish_bite_3": "res://audio/sfx/sfx_fish_bite_3.ogg",
	"sfx_fish_bite_4": "res://audio/sfx/sfx_fish_bite_4.ogg",
	"sfx_fish_bite_5": "res://audio/sfx/sfx_fish_bite_5.ogg",
	"sfx_fish_bite_6": "res://audio/sfx/sfx_fish_bite_6.ogg",
	"sfx_fish_bite_7": "res://audio/sfx/sfx_fish_bite_7.ogg",
	"sfx_fish_bite_8": "res://audio/sfx/sfx_fish_bite_8.ogg",
	"sfx_fish_cast_1": "res://audio/sfx/sfx_fish_cast_1.ogg",
	"sfx_fish_cast_2": "res://audio/sfx/sfx_fish_cast_2.ogg",
	"sfx_fish_cast_3": "res://audio/sfx/sfx_fish_cast_3.ogg",
	"sfx_fish_cast_4": "res://audio/sfx/sfx_fish_cast_4.ogg",
	"sfx_fish_cast_5": "res://audio/sfx/sfx_fish_cast_5.ogg",
	"sfx_fish_cast_6": "res://audio/sfx/sfx_fish_cast_6.ogg",
	"sfx_fish_cast_7": "res://audio/sfx/sfx_fish_cast_7.ogg",
	"sfx_fish_cast_8": "res://audio/sfx/sfx_fish_cast_8.ogg",
	"sfx_fish_cast_9": "res://audio/sfx/sfx_fish_cast_9.ogg",
	"sfx_fish_cast_10": "res://audio/sfx/sfx_fish_cast_10.ogg",
	"sfx_fish_cast_11": "res://audio/sfx/sfx_fish_cast_11.ogg",
	"sfx_fish_cast_12": "res://audio/sfx/sfx_fish_cast_12.ogg",
	"sfx_fish_cast_charge_1": "res://audio/sfx/sfx_fish_cast_charge_1.ogg",
	"sfx_fish_cast_charge_2": "res://audio/sfx/sfx_fish_cast_charge_2.ogg",
	"sfx_fish_cast_charge_3": "res://audio/sfx/sfx_fish_cast_charge_3.ogg",
	"sfx_fish_cast_charge_4": "res://audio/sfx/sfx_fish_cast_charge_4.ogg",
	"sfx_fish_cast_charge_5": "res://audio/sfx/sfx_fish_cast_charge_5.ogg",
	"sfx_fish_cast_charge_6": "res://audio/sfx/sfx_fish_cast_charge_6.ogg",
	"sfx_fish_cast_charge_7": "res://audio/sfx/sfx_fish_cast_charge_7.ogg",
	"sfx_fish_cast_charge_8": "res://audio/sfx/sfx_fish_cast_charge_8.ogg",
	"sfx_fish_cast_charge_9": "res://audio/sfx/sfx_fish_cast_charge_9.ogg",
	"sfx_fish_cast_charge_10": "res://audio/sfx/sfx_fish_cast_charge_10.ogg",
	"sfx_fish_cast_charge_11": "res://audio/sfx/sfx_fish_cast_charge_11.ogg",
	"sfx_fish_cast_charge_12": "res://audio/sfx/sfx_fish_cast_charge_12.ogg",
	"sfx_fish_escape_1": "res://audio/sfx/sfx_fish_escape_1.ogg",
	"sfx_fish_escape_2": "res://audio/sfx/sfx_fish_escape_2.ogg",
	"sfx_fish_escape_3": "res://audio/sfx/sfx_fish_escape_3.ogg",
	"sfx_fish_escape_4": "res://audio/sfx/sfx_fish_escape_4.ogg",
	"sfx_fish_escape_5": "res://audio/sfx/sfx_fish_escape_5.ogg",
	"sfx_fish_escape_6": "res://audio/sfx/sfx_fish_escape_6.ogg",
	"sfx_fish_escape_7": "res://audio/sfx/sfx_fish_escape_7.ogg",
	"sfx_fish_escape_8": "res://audio/sfx/sfx_fish_escape_8.ogg",
	"sfx_fish_hook_1": "res://audio/sfx/sfx_fish_hook_1.ogg",
	"sfx_fish_hook_2": "res://audio/sfx/sfx_fish_hook_2.ogg",
	"sfx_fish_hook_3": "res://audio/sfx/sfx_fish_hook_3.ogg",
	"sfx_fish_hook_4": "res://audio/sfx/sfx_fish_hook_4.ogg",
	"sfx_fish_hook_5": "res://audio/sfx/sfx_fish_hook_5.ogg",
	"sfx_fish_hook_6": "res://audio/sfx/sfx_fish_hook_6.ogg",
	"sfx_fish_hook_7": "res://audio/sfx/sfx_fish_hook_7.ogg",
	"sfx_fish_hook_8": "res://audio/sfx/sfx_fish_hook_8.ogg",
	"sfx_fish_land_1": "res://audio/sfx/sfx_fish_land_1.ogg",
	"sfx_fish_land_2": "res://audio/sfx/sfx_fish_land_2.ogg",
	"sfx_fish_land_3": "res://audio/sfx/sfx_fish_land_3.ogg",
	"sfx_fish_land_4": "res://audio/sfx/sfx_fish_land_4.ogg",
	"sfx_fish_land_5": "res://audio/sfx/sfx_fish_land_5.ogg",
	"sfx_fish_land_6": "res://audio/sfx/sfx_fish_land_6.ogg",
	"sfx_fish_land_7": "res://audio/sfx/sfx_fish_land_7.ogg",
	"sfx_fish_land_8": "res://audio/sfx/sfx_fish_land_8.ogg",
	"sfx_fish_miss_1": "res://audio/sfx/sfx_fish_miss_1.ogg",
	"sfx_fish_miss_2": "res://audio/sfx/sfx_fish_miss_2.ogg",
	"sfx_fish_miss_3": "res://audio/sfx/sfx_fish_miss_3.ogg",
	"sfx_fish_miss_4": "res://audio/sfx/sfx_fish_miss_4.ogg",
	"sfx_fish_miss_5": "res://audio/sfx/sfx_fish_miss_5.ogg",
	"sfx_fish_miss_6": "res://audio/sfx/sfx_fish_miss_6.ogg",
	"sfx_fish_miss_7": "res://audio/sfx/sfx_fish_miss_7.ogg",
	"sfx_fish_miss_8": "res://audio/sfx/sfx_fish_miss_8.ogg",
	"sfx_fish_nibble_1": "res://audio/sfx/sfx_fish_nibble_1.ogg",
	"sfx_fish_nibble_2": "res://audio/sfx/sfx_fish_nibble_2.ogg",
	"sfx_fish_nibble_3": "res://audio/sfx/sfx_fish_nibble_3.ogg",
	"sfx_fish_nibble_4": "res://audio/sfx/sfx_fish_nibble_4.ogg",
	"sfx_fish_nibble_5": "res://audio/sfx/sfx_fish_nibble_5.ogg",
	"sfx_fish_nibble_6": "res://audio/sfx/sfx_fish_nibble_6.ogg",
	"sfx_fish_nibble_7": "res://audio/sfx/sfx_fish_nibble_7.ogg",
	"sfx_fish_nibble_8": "res://audio/sfx/sfx_fish_nibble_8.ogg",
	"sfx_fish_reel_1": "res://audio/sfx/sfx_fish_reel_1.ogg",
	"sfx_fish_reel_2": "res://audio/sfx/sfx_fish_reel_2.ogg",
	"sfx_fish_reel_3": "res://audio/sfx/sfx_fish_reel_3.ogg",
	"sfx_fish_reel_4": "res://audio/sfx/sfx_fish_reel_4.ogg",
	"sfx_fish_snap_1": "res://audio/sfx/sfx_fish_snap_1.ogg",
	"sfx_fish_snap_2": "res://audio/sfx/sfx_fish_snap_2.ogg",
	"sfx_fish_snap_3": "res://audio/sfx/sfx_fish_snap_3.ogg",
	"sfx_fish_snap_4": "res://audio/sfx/sfx_fish_snap_4.ogg",
	"sfx_fish_splash_1": "res://audio/sfx/sfx_fish_splash_1.ogg",
	"sfx_fish_splash_2": "res://audio/sfx/sfx_fish_splash_2.ogg",
	"sfx_fish_splash_3": "res://audio/sfx/sfx_fish_splash_3.ogg",
	"sfx_fish_splash_4": "res://audio/sfx/sfx_fish_splash_4.ogg",
	"sfx_fish_splash_5": "res://audio/sfx/sfx_fish_splash_5.ogg",
	"sfx_fish_splash_6": "res://audio/sfx/sfx_fish_splash_6.ogg",
	"sfx_fish_splash_7": "res://audio/sfx/sfx_fish_splash_7.ogg",
	"sfx_fish_splash_8": "res://audio/sfx/sfx_fish_splash_8.ogg",
	"sfx_footstep_dirt_1": "res://audio/sfx/sfx_footstep_dirt_1.ogg",
	"sfx_footstep_dirt_2": "res://audio/sfx/sfx_footstep_dirt_2.ogg",
	"sfx_footstep_dirt_3": "res://audio/sfx/sfx_footstep_dirt_3.ogg",
	"sfx_footstep_heavy": "res://audio/sfx/sfx_footstep_heavy.ogg",
	"sfx_fork_open_1": "res://audio/sfx/sfx_fork_open_1.ogg",
	"sfx_fork_open_2": "res://audio/sfx/sfx_fork_open_2.ogg",
	"sfx_fork_open_3": "res://audio/sfx/sfx_fork_open_3.ogg",
	"sfx_fork_open_4": "res://audio/sfx/sfx_fork_open_4.ogg",
	"sfx_fork_open_5": "res://audio/sfx/sfx_fork_open_5.ogg",
	"sfx_fork_open_6": "res://audio/sfx/sfx_fork_open_6.ogg",
	"sfx_fork_open_7": "res://audio/sfx/sfx_fork_open_7.ogg",
	"sfx_fork_open_8": "res://audio/sfx/sfx_fork_open_8.ogg",
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
	"sfx_party_accept_1": "res://audio/sfx/sfx_party_accept_1.ogg",
	"sfx_party_accept_2": "res://audio/sfx/sfx_party_accept_2.ogg",
	"sfx_party_accept_3": "res://audio/sfx/sfx_party_accept_3.ogg",
	"sfx_party_accept_4": "res://audio/sfx/sfx_party_accept_4.ogg",
	"sfx_party_accept_5": "res://audio/sfx/sfx_party_accept_5.ogg",
	"sfx_party_accept_6": "res://audio/sfx/sfx_party_accept_6.ogg",
	"sfx_party_decline_1": "res://audio/sfx/sfx_party_decline_1.ogg",
	"sfx_party_decline_2": "res://audio/sfx/sfx_party_decline_2.ogg",
	"sfx_party_decline_3": "res://audio/sfx/sfx_party_decline_3.ogg",
	"sfx_party_decline_4": "res://audio/sfx/sfx_party_decline_4.ogg",
	"sfx_party_decline_5": "res://audio/sfx/sfx_party_decline_5.ogg",
	"sfx_party_decline_6": "res://audio/sfx/sfx_party_decline_6.ogg",
	"sfx_party_prompt_1": "res://audio/sfx/sfx_party_prompt_1.ogg",
	"sfx_party_prompt_2": "res://audio/sfx/sfx_party_prompt_2.ogg",
	"sfx_party_prompt_3": "res://audio/sfx/sfx_party_prompt_3.ogg",
	"sfx_party_prompt_4": "res://audio/sfx/sfx_party_prompt_4.ogg",
	"sfx_party_prompt_5": "res://audio/sfx/sfx_party_prompt_5.ogg",
	"sfx_party_prompt_6": "res://audio/sfx/sfx_party_prompt_6.ogg",
	"sfx_party_prompt_7": "res://audio/sfx/sfx_party_prompt_7.ogg",
	"sfx_party_prompt_8": "res://audio/sfx/sfx_party_prompt_8.ogg",
	"sfx_profession_level_1": "res://audio/sfx/sfx_profession_level_1.ogg",
	"sfx_profession_level_2": "res://audio/sfx/sfx_profession_level_2.ogg",
	"sfx_profession_level_3": "res://audio/sfx/sfx_profession_level_3.ogg",
	"sfx_profession_level_4": "res://audio/sfx/sfx_profession_level_4.ogg",
	"sfx_profession_level_5": "res://audio/sfx/sfx_profession_level_5.ogg",
	"sfx_profession_level_6": "res://audio/sfx/sfx_profession_level_6.ogg",
	"sfx_profession_level_7": "res://audio/sfx/sfx_profession_level_7.ogg",
	"sfx_profession_level_8": "res://audio/sfx/sfx_profession_level_8.ogg",
	"sfx_raid_extract_1": "res://audio/sfx/sfx_raid_extract_1.ogg",
	"sfx_raid_extract_2": "res://audio/sfx/sfx_raid_extract_2.ogg",
	"sfx_raid_extract_3": "res://audio/sfx/sfx_raid_extract_3.ogg",
	"sfx_raid_extract_4": "res://audio/sfx/sfx_raid_extract_4.ogg",
	"sfx_raid_extract_5": "res://audio/sfx/sfx_raid_extract_5.ogg",
	"sfx_raid_extract_6": "res://audio/sfx/sfx_raid_extract_6.ogg",
	"sfx_raid_extract_7": "res://audio/sfx/sfx_raid_extract_7.ogg",
	"sfx_raid_extract_8": "res://audio/sfx/sfx_raid_extract_8.ogg",
	"sfx_raid_extract_9": "res://audio/sfx/sfx_raid_extract_9.ogg",
	"sfx_raid_extract_10": "res://audio/sfx/sfx_raid_extract_10.ogg",
	"sfx_raid_extract_11": "res://audio/sfx/sfx_raid_extract_11.ogg",
	"sfx_raid_extract_12": "res://audio/sfx/sfx_raid_extract_12.ogg",
	"sfx_raid_ready": "res://audio/sfx/sfx_raid_ready.ogg",
	"sfx_raid_window_1": "res://audio/sfx/sfx_raid_window_1.ogg",
	"sfx_raid_window_2": "res://audio/sfx/sfx_raid_window_2.ogg",
	"sfx_raid_window_3": "res://audio/sfx/sfx_raid_window_3.ogg",
	"sfx_raid_window_4": "res://audio/sfx/sfx_raid_window_4.ogg",
	"sfx_raid_window_5": "res://audio/sfx/sfx_raid_window_5.ogg",
	"sfx_raid_window_6": "res://audio/sfx/sfx_raid_window_6.ogg",
	"sfx_raid_window_7": "res://audio/sfx/sfx_raid_window_7.ogg",
	"sfx_raid_window_8": "res://audio/sfx/sfx_raid_window_8.ogg",
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
	"sfx_swim_enter_1": "res://audio/sfx/sfx_swim_enter_1.ogg",
	"sfx_swim_enter_2": "res://audio/sfx/sfx_swim_enter_2.ogg",
	"sfx_swim_enter_3": "res://audio/sfx/sfx_swim_enter_3.ogg",
	"sfx_swim_enter_4": "res://audio/sfx/sfx_swim_enter_4.ogg",
	"sfx_swim_enter_5": "res://audio/sfx/sfx_swim_enter_5.ogg",
	"sfx_swim_enter_6": "res://audio/sfx/sfx_swim_enter_6.ogg",
	"sfx_swim_enter_7": "res://audio/sfx/sfx_swim_enter_7.ogg",
	"sfx_swim_enter_8": "res://audio/sfx/sfx_swim_enter_8.ogg",
	"sfx_swim_exit_1": "res://audio/sfx/sfx_swim_exit_1.ogg",
	"sfx_swim_exit_2": "res://audio/sfx/sfx_swim_exit_2.ogg",
	"sfx_swim_exit_3": "res://audio/sfx/sfx_swim_exit_3.ogg",
	"sfx_swim_exit_4": "res://audio/sfx/sfx_swim_exit_4.ogg",
	"sfx_swim_exit_5": "res://audio/sfx/sfx_swim_exit_5.ogg",
	"sfx_swim_exit_6": "res://audio/sfx/sfx_swim_exit_6.ogg",
	"sfx_swim_exit_7": "res://audio/sfx/sfx_swim_exit_7.ogg",
	"sfx_swim_exit_8": "res://audio/sfx/sfx_swim_exit_8.ogg",
	"sfx_swim_stroke_1": "res://audio/sfx/sfx_swim_stroke_1.ogg",
	"sfx_swim_stroke_2": "res://audio/sfx/sfx_swim_stroke_2.ogg",
	"sfx_swim_stroke_3": "res://audio/sfx/sfx_swim_stroke_3.ogg",
	"sfx_swim_stroke_4": "res://audio/sfx/sfx_swim_stroke_4.ogg",
	"sfx_swim_stroke_5": "res://audio/sfx/sfx_swim_stroke_5.ogg",
	"sfx_swim_stroke_6": "res://audio/sfx/sfx_swim_stroke_6.ogg",
	"sfx_swim_stroke_7": "res://audio/sfx/sfx_swim_stroke_7.ogg",
	"sfx_swim_stroke_8": "res://audio/sfx/sfx_swim_stroke_8.ogg",
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
	"sfx_enemy_call_beast_1": "res://audio/sfx/sfx_enemy_call_beast_1.ogg",
	"sfx_enemy_call_beast_2": "res://audio/sfx/sfx_enemy_call_beast_2.ogg",
	"sfx_enemy_call_beast_3": "res://audio/sfx/sfx_enemy_call_beast_3.ogg",
	"sfx_enemy_call_beast_4": "res://audio/sfx/sfx_enemy_call_beast_4.ogg",
	"sfx_enemy_call_beast_5": "res://audio/sfx/sfx_enemy_call_beast_5.ogg",
	"sfx_enemy_call_beast_6": "res://audio/sfx/sfx_enemy_call_beast_6.ogg",
	"sfx_enemy_call_beast_7": "res://audio/sfx/sfx_enemy_call_beast_7.ogg",
	"sfx_enemy_call_beast_8": "res://audio/sfx/sfx_enemy_call_beast_8.ogg",
	"sfx_enemy_call_beast_9": "res://audio/sfx/sfx_enemy_call_beast_9.ogg",
	"sfx_enemy_call_beast_10": "res://audio/sfx/sfx_enemy_call_beast_10.ogg",
	"sfx_enemy_call_beast_11": "res://audio/sfx/sfx_enemy_call_beast_11.ogg",
	"sfx_enemy_call_beast_12": "res://audio/sfx/sfx_enemy_call_beast_12.ogg",
	"sfx_enemy_call_beast_13": "res://audio/sfx/sfx_enemy_call_beast_13.ogg",
	"sfx_enemy_call_beast_14": "res://audio/sfx/sfx_enemy_call_beast_14.ogg",
	"sfx_enemy_call_beast_15": "res://audio/sfx/sfx_enemy_call_beast_15.ogg",
	"sfx_enemy_call_beast_16": "res://audio/sfx/sfx_enemy_call_beast_16.ogg",
	"sfx_enemy_call_beast_17": "res://audio/sfx/sfx_enemy_call_beast_17.ogg",
	"sfx_enemy_call_beast_18": "res://audio/sfx/sfx_enemy_call_beast_18.ogg",
	"sfx_enemy_call_beast_19": "res://audio/sfx/sfx_enemy_call_beast_19.ogg",
	"sfx_enemy_call_beast_20": "res://audio/sfx/sfx_enemy_call_beast_20.ogg",
	"sfx_enemy_call_beast_21": "res://audio/sfx/sfx_enemy_call_beast_21.ogg",
	"sfx_enemy_call_beast_22": "res://audio/sfx/sfx_enemy_call_beast_22.ogg",
	"sfx_enemy_call_beast_23": "res://audio/sfx/sfx_enemy_call_beast_23.ogg",
	"sfx_enemy_call_beast_24": "res://audio/sfx/sfx_enemy_call_beast_24.ogg",
	"sfx_enemy_call_beast_25": "res://audio/sfx/sfx_enemy_call_beast_25.ogg",
	"sfx_enemy_call_beast_26": "res://audio/sfx/sfx_enemy_call_beast_26.ogg",
	"sfx_enemy_call_beast_27": "res://audio/sfx/sfx_enemy_call_beast_27.ogg",
	"sfx_enemy_call_beast_28": "res://audio/sfx/sfx_enemy_call_beast_28.ogg",
	"sfx_enemy_call_beast_29": "res://audio/sfx/sfx_enemy_call_beast_29.ogg",
	"sfx_enemy_call_beast_30": "res://audio/sfx/sfx_enemy_call_beast_30.ogg",
	"sfx_enemy_call_beast_31": "res://audio/sfx/sfx_enemy_call_beast_31.ogg",
	"sfx_enemy_call_beast_32": "res://audio/sfx/sfx_enemy_call_beast_32.ogg",
	"sfx_enemy_call_beast_33": "res://audio/sfx/sfx_enemy_call_beast_33.ogg",
	"sfx_enemy_call_beast_34": "res://audio/sfx/sfx_enemy_call_beast_34.ogg",
	"sfx_enemy_call_beast_35": "res://audio/sfx/sfx_enemy_call_beast_35.ogg",
	"sfx_enemy_call_beast_36": "res://audio/sfx/sfx_enemy_call_beast_36.ogg",
	"sfx_enemy_call_horde_1": "res://audio/sfx/sfx_enemy_call_horde_1.ogg",
	"sfx_enemy_call_horde_2": "res://audio/sfx/sfx_enemy_call_horde_2.ogg",
	"sfx_enemy_call_horde_3": "res://audio/sfx/sfx_enemy_call_horde_3.ogg",
	"sfx_enemy_call_horde_4": "res://audio/sfx/sfx_enemy_call_horde_4.ogg",
	"sfx_enemy_call_horde_5": "res://audio/sfx/sfx_enemy_call_horde_5.ogg",
	"sfx_enemy_call_horde_6": "res://audio/sfx/sfx_enemy_call_horde_6.ogg",
	"sfx_enemy_call_horde_7": "res://audio/sfx/sfx_enemy_call_horde_7.ogg",
	"sfx_enemy_call_horde_8": "res://audio/sfx/sfx_enemy_call_horde_8.ogg",
	"sfx_enemy_call_horde_9": "res://audio/sfx/sfx_enemy_call_horde_9.ogg",
	"sfx_enemy_call_horde_10": "res://audio/sfx/sfx_enemy_call_horde_10.ogg",
	"sfx_enemy_call_horde_11": "res://audio/sfx/sfx_enemy_call_horde_11.ogg",
	"sfx_enemy_call_horde_12": "res://audio/sfx/sfx_enemy_call_horde_12.ogg",
	"sfx_enemy_call_horde_13": "res://audio/sfx/sfx_enemy_call_horde_13.ogg",
	"sfx_enemy_call_horde_14": "res://audio/sfx/sfx_enemy_call_horde_14.ogg",
	"sfx_enemy_call_horde_15": "res://audio/sfx/sfx_enemy_call_horde_15.ogg",
	"sfx_enemy_call_horde_16": "res://audio/sfx/sfx_enemy_call_horde_16.ogg",
	"sfx_enemy_call_horde_17": "res://audio/sfx/sfx_enemy_call_horde_17.ogg",
	"sfx_enemy_call_horde_18": "res://audio/sfx/sfx_enemy_call_horde_18.ogg",
	"sfx_enemy_call_horde_19": "res://audio/sfx/sfx_enemy_call_horde_19.ogg",
	"sfx_enemy_call_horde_20": "res://audio/sfx/sfx_enemy_call_horde_20.ogg",
	"sfx_enemy_call_horde_21": "res://audio/sfx/sfx_enemy_call_horde_21.ogg",
	"sfx_enemy_call_horde_22": "res://audio/sfx/sfx_enemy_call_horde_22.ogg",
	"sfx_enemy_call_horde_23": "res://audio/sfx/sfx_enemy_call_horde_23.ogg",
	"sfx_enemy_call_horde_24": "res://audio/sfx/sfx_enemy_call_horde_24.ogg",
	"sfx_enemy_call_horde_25": "res://audio/sfx/sfx_enemy_call_horde_25.ogg",
	"sfx_enemy_call_horde_26": "res://audio/sfx/sfx_enemy_call_horde_26.ogg",
	"sfx_enemy_call_horde_27": "res://audio/sfx/sfx_enemy_call_horde_27.ogg",
	"sfx_enemy_call_horde_28": "res://audio/sfx/sfx_enemy_call_horde_28.ogg",
	"sfx_enemy_call_horde_29": "res://audio/sfx/sfx_enemy_call_horde_29.ogg",
	"sfx_enemy_call_horde_30": "res://audio/sfx/sfx_enemy_call_horde_30.ogg",
	"sfx_enemy_call_horde_31": "res://audio/sfx/sfx_enemy_call_horde_31.ogg",
	"sfx_enemy_call_horde_32": "res://audio/sfx/sfx_enemy_call_horde_32.ogg",
	"sfx_enemy_call_horn_1": "res://audio/sfx/sfx_enemy_call_horn_1.ogg",
	"sfx_enemy_call_horn_2": "res://audio/sfx/sfx_enemy_call_horn_2.ogg",
	"sfx_enemy_call_horn_3": "res://audio/sfx/sfx_enemy_call_horn_3.ogg",
	"sfx_enemy_call_horn_4": "res://audio/sfx/sfx_enemy_call_horn_4.ogg",
	"sfx_enemy_call_siege_1": "res://audio/sfx/sfx_enemy_call_siege_1.ogg",
	"sfx_enemy_call_siege_2": "res://audio/sfx/sfx_enemy_call_siege_2.ogg",
	"sfx_enemy_call_siege_3": "res://audio/sfx/sfx_enemy_call_siege_3.ogg",
	"sfx_enemy_call_siege_4": "res://audio/sfx/sfx_enemy_call_siege_4.ogg",
	"sfx_enemy_call_swarm_1": "res://audio/sfx/sfx_enemy_call_swarm_1.ogg",
	"sfx_enemy_call_swarm_2": "res://audio/sfx/sfx_enemy_call_swarm_2.ogg",
	"sfx_enemy_call_swarm_3": "res://audio/sfx/sfx_enemy_call_swarm_3.ogg",
	"sfx_enemy_call_swarm_4": "res://audio/sfx/sfx_enemy_call_swarm_4.ogg",
	"sfx_enemy_call_wraith_1": "res://audio/sfx/sfx_enemy_call_wraith_1.ogg",
	"sfx_enemy_call_wraith_2": "res://audio/sfx/sfx_enemy_call_wraith_2.ogg",
	"sfx_enemy_call_wraith_3": "res://audio/sfx/sfx_enemy_call_wraith_3.ogg",
	"sfx_enemy_call_wraith_4": "res://audio/sfx/sfx_enemy_call_wraith_4.ogg",
	"sfx_enemy_call_wraith_5": "res://audio/sfx/sfx_enemy_call_wraith_5.ogg",
	"sfx_enemy_call_wraith_6": "res://audio/sfx/sfx_enemy_call_wraith_6.ogg",
	"sfx_enemy_call_wraith_7": "res://audio/sfx/sfx_enemy_call_wraith_7.ogg",
	"sfx_enemy_call_wraith_8": "res://audio/sfx/sfx_enemy_call_wraith_8.ogg",
	"sfx_enemy_call_wraith_9": "res://audio/sfx/sfx_enemy_call_wraith_9.ogg",
	"sfx_enemy_call_wraith_10": "res://audio/sfx/sfx_enemy_call_wraith_10.ogg",
	"sfx_enemy_call_wraith_11": "res://audio/sfx/sfx_enemy_call_wraith_11.ogg",
	"sfx_enemy_call_wraith_12": "res://audio/sfx/sfx_enemy_call_wraith_12.ogg",
	"sfx_enemy_call_wraith_13": "res://audio/sfx/sfx_enemy_call_wraith_13.ogg",
	"sfx_enemy_call_wraith_14": "res://audio/sfx/sfx_enemy_call_wraith_14.ogg",
	"sfx_enemy_call_wraith_15": "res://audio/sfx/sfx_enemy_call_wraith_15.ogg",
	"sfx_enemy_call_wraith_16": "res://audio/sfx/sfx_enemy_call_wraith_16.ogg",
	"sfx_enemy_call_wraith_17": "res://audio/sfx/sfx_enemy_call_wraith_17.ogg",
	"sfx_enemy_call_wraith_18": "res://audio/sfx/sfx_enemy_call_wraith_18.ogg",
	"sfx_enemy_call_wraith_19": "res://audio/sfx/sfx_enemy_call_wraith_19.ogg",
	"sfx_enemy_call_wraith_20": "res://audio/sfx/sfx_enemy_call_wraith_20.ogg",
	"sfx_enemy_call_wraith_21": "res://audio/sfx/sfx_enemy_call_wraith_21.ogg",
	"sfx_enemy_call_wraith_22": "res://audio/sfx/sfx_enemy_call_wraith_22.ogg",
	"sfx_enemy_call_wraith_23": "res://audio/sfx/sfx_enemy_call_wraith_23.ogg",
	"sfx_enemy_call_wraith_24": "res://audio/sfx/sfx_enemy_call_wraith_24.ogg",
	"sfx_enemy_call_wraith_25": "res://audio/sfx/sfx_enemy_call_wraith_25.ogg",
	"sfx_enemy_call_wraith_26": "res://audio/sfx/sfx_enemy_call_wraith_26.ogg",
	"sfx_enemy_call_wraith_27": "res://audio/sfx/sfx_enemy_call_wraith_27.ogg",
	"sfx_enemy_call_wraith_28": "res://audio/sfx/sfx_enemy_call_wraith_28.ogg",
	"sfx_enemy_call_wraith_29": "res://audio/sfx/sfx_enemy_call_wraith_29.ogg",
	"sfx_enemy_call_wraith_30": "res://audio/sfx/sfx_enemy_call_wraith_30.ogg",
	"sfx_enemy_call_wraith_31": "res://audio/sfx/sfx_enemy_call_wraith_31.ogg",
	"sfx_enemy_call_wraith_32": "res://audio/sfx/sfx_enemy_call_wraith_32.ogg",
	"sfx_enemy_call_wraith_33": "res://audio/sfx/sfx_enemy_call_wraith_33.ogg",
	"sfx_enemy_call_wraith_34": "res://audio/sfx/sfx_enemy_call_wraith_34.ogg",
	"sfx_enemy_call_wraith_35": "res://audio/sfx/sfx_enemy_call_wraith_35.ogg",
	"sfx_enemy_call_wraith_36": "res://audio/sfx/sfx_enemy_call_wraith_36.ogg",
	"sfx_enemy_call_wraith_37": "res://audio/sfx/sfx_enemy_call_wraith_37.ogg",
	"sfx_enemy_call_wraith_38": "res://audio/sfx/sfx_enemy_call_wraith_38.ogg",
	"sfx_enemy_call_wraith_39": "res://audio/sfx/sfx_enemy_call_wraith_39.ogg",
	"sfx_enemy_call_wraith_40": "res://audio/sfx/sfx_enemy_call_wraith_40.ogg",
	"sfx_enemy_call_wraith_41": "res://audio/sfx/sfx_enemy_call_wraith_41.ogg",
	"sfx_enemy_call_wraith_42": "res://audio/sfx/sfx_enemy_call_wraith_42.ogg",
	"sfx_enemy_call_wraith_43": "res://audio/sfx/sfx_enemy_call_wraith_43.ogg",
	"sfx_enemy_call_wraith_44": "res://audio/sfx/sfx_enemy_call_wraith_44.ogg",
	"sfx_enemy_call_wraith_45": "res://audio/sfx/sfx_enemy_call_wraith_45.ogg",
	"sfx_enemy_call_wraith_46": "res://audio/sfx/sfx_enemy_call_wraith_46.ogg",
	"sfx_enemy_call_wraith_47": "res://audio/sfx/sfx_enemy_call_wraith_47.ogg",
	"sfx_enemy_call_wraith_48": "res://audio/sfx/sfx_enemy_call_wraith_48.ogg",
	"sfx_enemy_call_wraith_49": "res://audio/sfx/sfx_enemy_call_wraith_49.ogg",
	"sfx_enemy_call_wraith_50": "res://audio/sfx/sfx_enemy_call_wraith_50.ogg",
	"sfx_enemy_call_wraith_51": "res://audio/sfx/sfx_enemy_call_wraith_51.ogg",
	"sfx_enemy_call_wraith_52": "res://audio/sfx/sfx_enemy_call_wraith_52.ogg",
	"sfx_pen_graze_1": "res://audio/sfx/sfx_pen_graze_1.ogg",
	"sfx_pen_graze_2": "res://audio/sfx/sfx_pen_graze_2.ogg",
	"sfx_pen_graze_3": "res://audio/sfx/sfx_pen_graze_3.ogg",
	"sfx_pen_graze_4": "res://audio/sfx/sfx_pen_graze_4.ogg",
	"sfx_pen_settle_1": "res://audio/sfx/sfx_pen_settle_1.ogg",
	"sfx_pen_settle_2": "res://audio/sfx/sfx_pen_settle_2.ogg",
	"sfx_pen_settle_3": "res://audio/sfx/sfx_pen_settle_3.ogg",
	"sfx_pen_settle_4": "res://audio/sfx/sfx_pen_settle_4.ogg",
	"sfx_wildlife_ash_hound_1": "res://audio/sfx/sfx_wildlife_ash_hound_1.ogg",
	"sfx_wildlife_ash_hound_2": "res://audio/sfx/sfx_wildlife_ash_hound_2.ogg",
	"sfx_wildlife_ash_hound_3": "res://audio/sfx/sfx_wildlife_ash_hound_3.ogg",
	"sfx_wildlife_ash_hound_4": "res://audio/sfx/sfx_wildlife_ash_hound_4.ogg",
	"sfx_wildlife_barkfang_wolverine_1": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_1.ogg",
	"sfx_wildlife_barkfang_wolverine_2": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_2.ogg",
	"sfx_wildlife_barkfang_wolverine_3": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_3.ogg",
	"sfx_wildlife_barkfang_wolverine_4": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_4.ogg",
	"sfx_wildlife_barkfang_wolverine_5": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_5.ogg",
	"sfx_wildlife_barkfang_wolverine_6": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_6.ogg",
	"sfx_wildlife_barkfang_wolverine_7": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_7.ogg",
	"sfx_wildlife_barkfang_wolverine_8": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_8.ogg",
	"sfx_wildlife_barkfang_wolverine_9": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_9.ogg",
	"sfx_wildlife_barkfang_wolverine_10": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_10.ogg",
	"sfx_wildlife_barkfang_wolverine_11": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_11.ogg",
	"sfx_wildlife_barkfang_wolverine_12": "res://audio/sfx/sfx_wildlife_barkfang_wolverine_12.ogg",
	"sfx_wildlife_barkjack_woodpecker_1": "res://audio/sfx/sfx_wildlife_barkjack_woodpecker_1.ogg",
	"sfx_wildlife_barkjack_woodpecker_2": "res://audio/sfx/sfx_wildlife_barkjack_woodpecker_2.ogg",
	"sfx_wildlife_barkjack_woodpecker_3": "res://audio/sfx/sfx_wildlife_barkjack_woodpecker_3.ogg",
	"sfx_wildlife_barkjack_woodpecker_4": "res://audio/sfx/sfx_wildlife_barkjack_woodpecker_4.ogg",
	"sfx_wildlife_barkjack_woodpecker_5": "res://audio/sfx/sfx_wildlife_barkjack_woodpecker_5.ogg",
	"sfx_wildlife_barkjack_woodpecker_6": "res://audio/sfx/sfx_wildlife_barkjack_woodpecker_6.ogg",
	"sfx_wildlife_barkjack_woodpecker_7": "res://audio/sfx/sfx_wildlife_barkjack_woodpecker_7.ogg",
	"sfx_wildlife_blight_collapse_1": "res://audio/sfx/sfx_wildlife_blight_collapse_1.ogg",
	"sfx_wildlife_blight_collapse_2": "res://audio/sfx/sfx_wildlife_blight_collapse_2.ogg",
	"sfx_wildlife_blight_collapse_3": "res://audio/sfx/sfx_wildlife_blight_collapse_3.ogg",
	"sfx_wildlife_blight_collapse_4": "res://audio/sfx/sfx_wildlife_blight_collapse_4.ogg",
	"sfx_wildlife_blight_collapse_5": "res://audio/sfx/sfx_wildlife_blight_collapse_5.ogg",
	"sfx_wildlife_blight_collapse_6": "res://audio/sfx/sfx_wildlife_blight_collapse_6.ogg",
	"sfx_wildlife_blight_collapse_7": "res://audio/sfx/sfx_wildlife_blight_collapse_7.ogg",
	"sfx_wildlife_blight_collapse_8": "res://audio/sfx/sfx_wildlife_blight_collapse_8.ogg",
	"sfx_wildlife_blight_frenzy_1": "res://audio/sfx/sfx_wildlife_blight_frenzy_1.ogg",
	"sfx_wildlife_blight_frenzy_2": "res://audio/sfx/sfx_wildlife_blight_frenzy_2.ogg",
	"sfx_wildlife_blight_frenzy_3": "res://audio/sfx/sfx_wildlife_blight_frenzy_3.ogg",
	"sfx_wildlife_blight_frenzy_4": "res://audio/sfx/sfx_wildlife_blight_frenzy_4.ogg",
	"sfx_wildlife_blight_frenzy_5": "res://audio/sfx/sfx_wildlife_blight_frenzy_5.ogg",
	"sfx_wildlife_blight_frenzy_6": "res://audio/sfx/sfx_wildlife_blight_frenzy_6.ogg",
	"sfx_wildlife_blight_frenzy_7": "res://audio/sfx/sfx_wildlife_blight_frenzy_7.ogg",
	"sfx_wildlife_blight_frenzy_8": "res://audio/sfx/sfx_wildlife_blight_frenzy_8.ogg",
	"sfx_wildlife_blight_warning_1": "res://audio/sfx/sfx_wildlife_blight_warning_1.ogg",
	"sfx_wildlife_blight_warning_2": "res://audio/sfx/sfx_wildlife_blight_warning_2.ogg",
	"sfx_wildlife_blight_warning_3": "res://audio/sfx/sfx_wildlife_blight_warning_3.ogg",
	"sfx_wildlife_blight_warning_4": "res://audio/sfx/sfx_wildlife_blight_warning_4.ogg",
	"sfx_wildlife_blight_warning_5": "res://audio/sfx/sfx_wildlife_blight_warning_5.ogg",
	"sfx_wildlife_blight_warning_6": "res://audio/sfx/sfx_wildlife_blight_warning_6.ogg",
	"sfx_wildlife_blight_warning_7": "res://audio/sfx/sfx_wildlife_blight_warning_7.ogg",
	"sfx_wildlife_blight_warning_8": "res://audio/sfx/sfx_wildlife_blight_warning_8.ogg",
	"sfx_wildlife_blight_warning_9": "res://audio/sfx/sfx_wildlife_blight_warning_9.ogg",
	"sfx_wildlife_blight_warning_10": "res://audio/sfx/sfx_wildlife_blight_warning_10.ogg",
	"sfx_wildlife_blight_warning_11": "res://audio/sfx/sfx_wildlife_blight_warning_11.ogg",
	"sfx_wildlife_blight_warning_12": "res://audio/sfx/sfx_wildlife_blight_warning_12.ogg",
	"sfx_wildlife_bog_crane_1": "res://audio/sfx/sfx_wildlife_bog_crane_1.ogg",
	"sfx_wildlife_bog_crane_2": "res://audio/sfx/sfx_wildlife_bog_crane_2.ogg",
	"sfx_wildlife_bog_crane_3": "res://audio/sfx/sfx_wildlife_bog_crane_3.ogg",
	"sfx_wildlife_bog_crane_4": "res://audio/sfx/sfx_wildlife_bog_crane_4.ogg",
	"sfx_wildlife_bog_crane_5": "res://audio/sfx/sfx_wildlife_bog_crane_5.ogg",
	"sfx_wildlife_bog_crane_6": "res://audio/sfx/sfx_wildlife_bog_crane_6.ogg",
	"sfx_wildlife_bog_crane_7": "res://audio/sfx/sfx_wildlife_bog_crane_7.ogg",
	"sfx_wildlife_bog_crane_8": "res://audio/sfx/sfx_wildlife_bog_crane_8.ogg",
	"sfx_wildlife_bog_crane_9": "res://audio/sfx/sfx_wildlife_bog_crane_9.ogg",
	"sfx_wildlife_bog_crane_10": "res://audio/sfx/sfx_wildlife_bog_crane_10.ogg",
	"sfx_wildlife_bog_crane_11": "res://audio/sfx/sfx_wildlife_bog_crane_11.ogg",
	"sfx_wildlife_bog_crane_12": "res://audio/sfx/sfx_wildlife_bog_crane_12.ogg",
	"sfx_wildlife_bond_1": "res://audio/sfx/sfx_wildlife_bond_1.ogg",
	"sfx_wildlife_bond_2": "res://audio/sfx/sfx_wildlife_bond_2.ogg",
	"sfx_wildlife_bond_3": "res://audio/sfx/sfx_wildlife_bond_3.ogg",
	"sfx_wildlife_bond_4": "res://audio/sfx/sfx_wildlife_bond_4.ogg",
	"sfx_wildlife_cliff_goat_1": "res://audio/sfx/sfx_wildlife_cliff_goat_1.ogg",
	"sfx_wildlife_cliff_goat_2": "res://audio/sfx/sfx_wildlife_cliff_goat_2.ogg",
	"sfx_wildlife_cliff_goat_3": "res://audio/sfx/sfx_wildlife_cliff_goat_3.ogg",
	"sfx_wildlife_cliff_goat_4": "res://audio/sfx/sfx_wildlife_cliff_goat_4.ogg",
	"sfx_wildlife_cliff_goat_5": "res://audio/sfx/sfx_wildlife_cliff_goat_5.ogg",
	"sfx_wildlife_cliff_goat_6": "res://audio/sfx/sfx_wildlife_cliff_goat_6.ogg",
	"sfx_wildlife_cliff_goat_7": "res://audio/sfx/sfx_wildlife_cliff_goat_7.ogg",
	"sfx_wildlife_cliff_goat_8": "res://audio/sfx/sfx_wildlife_cliff_goat_8.ogg",
	"sfx_wildlife_cliff_goat_9": "res://audio/sfx/sfx_wildlife_cliff_goat_9.ogg",
	"sfx_wildlife_cliff_goat_10": "res://audio/sfx/sfx_wildlife_cliff_goat_10.ogg",
	"sfx_wildlife_cliff_goat_11": "res://audio/sfx/sfx_wildlife_cliff_goat_11.ogg",
	"sfx_wildlife_cliff_goat_12": "res://audio/sfx/sfx_wildlife_cliff_goat_12.ogg",
	"sfx_wildlife_copper_pheasant_1": "res://audio/sfx/sfx_wildlife_copper_pheasant_1.ogg",
	"sfx_wildlife_copper_pheasant_2": "res://audio/sfx/sfx_wildlife_copper_pheasant_2.ogg",
	"sfx_wildlife_copper_pheasant_3": "res://audio/sfx/sfx_wildlife_copper_pheasant_3.ogg",
	"sfx_wildlife_copper_pheasant_4": "res://audio/sfx/sfx_wildlife_copper_pheasant_4.ogg",
	"sfx_wildlife_death_amphibian_1": "res://audio/sfx/sfx_wildlife_death_amphibian_1.ogg",
	"sfx_wildlife_death_amphibian_2": "res://audio/sfx/sfx_wildlife_death_amphibian_2.ogg",
	"sfx_wildlife_death_amphibian_3": "res://audio/sfx/sfx_wildlife_death_amphibian_3.ogg",
	"sfx_wildlife_death_amphibian_4": "res://audio/sfx/sfx_wildlife_death_amphibian_4.ogg",
	"sfx_wildlife_death_amphibian_5": "res://audio/sfx/sfx_wildlife_death_amphibian_5.ogg",
	"sfx_wildlife_death_amphibian_6": "res://audio/sfx/sfx_wildlife_death_amphibian_6.ogg",
	"sfx_wildlife_death_amphibian_7": "res://audio/sfx/sfx_wildlife_death_amphibian_7.ogg",
	"sfx_wildlife_death_amphibian_8": "res://audio/sfx/sfx_wildlife_death_amphibian_8.ogg",
	"sfx_wildlife_death_bird_1": "res://audio/sfx/sfx_wildlife_death_bird_1.ogg",
	"sfx_wildlife_death_bird_2": "res://audio/sfx/sfx_wildlife_death_bird_2.ogg",
	"sfx_wildlife_death_bird_3": "res://audio/sfx/sfx_wildlife_death_bird_3.ogg",
	"sfx_wildlife_death_bird_4": "res://audio/sfx/sfx_wildlife_death_bird_4.ogg",
	"sfx_wildlife_death_bird_5": "res://audio/sfx/sfx_wildlife_death_bird_5.ogg",
	"sfx_wildlife_death_bird_6": "res://audio/sfx/sfx_wildlife_death_bird_6.ogg",
	"sfx_wildlife_death_bird_7": "res://audio/sfx/sfx_wildlife_death_bird_7.ogg",
	"sfx_wildlife_death_bird_8": "res://audio/sfx/sfx_wildlife_death_bird_8.ogg",
	"sfx_wildlife_death_bird_9": "res://audio/sfx/sfx_wildlife_death_bird_9.ogg",
	"sfx_wildlife_death_bird_10": "res://audio/sfx/sfx_wildlife_death_bird_10.ogg",
	"sfx_wildlife_death_bird_11": "res://audio/sfx/sfx_wildlife_death_bird_11.ogg",
	"sfx_wildlife_death_bird_12": "res://audio/sfx/sfx_wildlife_death_bird_12.ogg",
	"sfx_wildlife_death_chitin_1": "res://audio/sfx/sfx_wildlife_death_chitin_1.ogg",
	"sfx_wildlife_death_chitin_2": "res://audio/sfx/sfx_wildlife_death_chitin_2.ogg",
	"sfx_wildlife_death_chitin_3": "res://audio/sfx/sfx_wildlife_death_chitin_3.ogg",
	"sfx_wildlife_death_chitin_4": "res://audio/sfx/sfx_wildlife_death_chitin_4.ogg",
	"sfx_wildlife_death_chitin_5": "res://audio/sfx/sfx_wildlife_death_chitin_5.ogg",
	"sfx_wildlife_death_chitin_6": "res://audio/sfx/sfx_wildlife_death_chitin_6.ogg",
	"sfx_wildlife_death_chitin_7": "res://audio/sfx/sfx_wildlife_death_chitin_7.ogg",
	"sfx_wildlife_death_chitin_8": "res://audio/sfx/sfx_wildlife_death_chitin_8.ogg",
	"sfx_wildlife_death_large_beast_1": "res://audio/sfx/sfx_wildlife_death_large_beast_1.ogg",
	"sfx_wildlife_death_large_beast_2": "res://audio/sfx/sfx_wildlife_death_large_beast_2.ogg",
	"sfx_wildlife_death_large_beast_3": "res://audio/sfx/sfx_wildlife_death_large_beast_3.ogg",
	"sfx_wildlife_death_large_beast_4": "res://audio/sfx/sfx_wildlife_death_large_beast_4.ogg",
	"sfx_wildlife_death_large_beast_5": "res://audio/sfx/sfx_wildlife_death_large_beast_5.ogg",
	"sfx_wildlife_death_large_beast_6": "res://audio/sfx/sfx_wildlife_death_large_beast_6.ogg",
	"sfx_wildlife_death_large_beast_7": "res://audio/sfx/sfx_wildlife_death_large_beast_7.ogg",
	"sfx_wildlife_death_large_beast_8": "res://audio/sfx/sfx_wildlife_death_large_beast_8.ogg",
	"sfx_wildlife_death_large_beast_9": "res://audio/sfx/sfx_wildlife_death_large_beast_9.ogg",
	"sfx_wildlife_death_large_beast_10": "res://audio/sfx/sfx_wildlife_death_large_beast_10.ogg",
	"sfx_wildlife_death_large_beast_11": "res://audio/sfx/sfx_wildlife_death_large_beast_11.ogg",
	"sfx_wildlife_death_large_beast_12": "res://audio/sfx/sfx_wildlife_death_large_beast_12.ogg",
	"sfx_wildlife_death_large_beast_13": "res://audio/sfx/sfx_wildlife_death_large_beast_13.ogg",
	"sfx_wildlife_death_large_beast_14": "res://audio/sfx/sfx_wildlife_death_large_beast_14.ogg",
	"sfx_wildlife_death_large_beast_15": "res://audio/sfx/sfx_wildlife_death_large_beast_15.ogg",
	"sfx_wildlife_death_large_beast_16": "res://audio/sfx/sfx_wildlife_death_large_beast_16.ogg",
	"sfx_wildlife_death_reptile_1": "res://audio/sfx/sfx_wildlife_death_reptile_1.ogg",
	"sfx_wildlife_death_reptile_2": "res://audio/sfx/sfx_wildlife_death_reptile_2.ogg",
	"sfx_wildlife_death_reptile_3": "res://audio/sfx/sfx_wildlife_death_reptile_3.ogg",
	"sfx_wildlife_death_reptile_4": "res://audio/sfx/sfx_wildlife_death_reptile_4.ogg",
	"sfx_wildlife_death_reptile_5": "res://audio/sfx/sfx_wildlife_death_reptile_5.ogg",
	"sfx_wildlife_death_reptile_6": "res://audio/sfx/sfx_wildlife_death_reptile_6.ogg",
	"sfx_wildlife_death_reptile_7": "res://audio/sfx/sfx_wildlife_death_reptile_7.ogg",
	"sfx_wildlife_death_reptile_8": "res://audio/sfx/sfx_wildlife_death_reptile_8.ogg",
	"sfx_wildlife_death_shell_1": "res://audio/sfx/sfx_wildlife_death_shell_1.ogg",
	"sfx_wildlife_death_shell_2": "res://audio/sfx/sfx_wildlife_death_shell_2.ogg",
	"sfx_wildlife_death_shell_3": "res://audio/sfx/sfx_wildlife_death_shell_3.ogg",
	"sfx_wildlife_death_shell_4": "res://audio/sfx/sfx_wildlife_death_shell_4.ogg",
	"sfx_wildlife_death_shell_5": "res://audio/sfx/sfx_wildlife_death_shell_5.ogg",
	"sfx_wildlife_death_shell_6": "res://audio/sfx/sfx_wildlife_death_shell_6.ogg",
	"sfx_wildlife_death_shell_7": "res://audio/sfx/sfx_wildlife_death_shell_7.ogg",
	"sfx_wildlife_death_shell_8": "res://audio/sfx/sfx_wildlife_death_shell_8.ogg",
	"sfx_wildlife_death_small_beast_1": "res://audio/sfx/sfx_wildlife_death_small_beast_1.ogg",
	"sfx_wildlife_death_small_beast_2": "res://audio/sfx/sfx_wildlife_death_small_beast_2.ogg",
	"sfx_wildlife_death_small_beast_3": "res://audio/sfx/sfx_wildlife_death_small_beast_3.ogg",
	"sfx_wildlife_death_small_beast_4": "res://audio/sfx/sfx_wildlife_death_small_beast_4.ogg",
	"sfx_wildlife_death_small_beast_5": "res://audio/sfx/sfx_wildlife_death_small_beast_5.ogg",
	"sfx_wildlife_death_small_beast_6": "res://audio/sfx/sfx_wildlife_death_small_beast_6.ogg",
	"sfx_wildlife_death_small_beast_7": "res://audio/sfx/sfx_wildlife_death_small_beast_7.ogg",
	"sfx_wildlife_death_small_beast_8": "res://audio/sfx/sfx_wildlife_death_small_beast_8.ogg",
	"sfx_wildlife_death_small_beast_9": "res://audio/sfx/sfx_wildlife_death_small_beast_9.ogg",
	"sfx_wildlife_death_small_beast_10": "res://audio/sfx/sfx_wildlife_death_small_beast_10.ogg",
	"sfx_wildlife_death_small_beast_11": "res://audio/sfx/sfx_wildlife_death_small_beast_11.ogg",
	"sfx_wildlife_death_small_beast_12": "res://audio/sfx/sfx_wildlife_death_small_beast_12.ogg",
	"sfx_wildlife_dune_fennec_1": "res://audio/sfx/sfx_wildlife_dune_fennec_1.ogg",
	"sfx_wildlife_dune_fennec_2": "res://audio/sfx/sfx_wildlife_dune_fennec_2.ogg",
	"sfx_wildlife_dune_fennec_3": "res://audio/sfx/sfx_wildlife_dune_fennec_3.ogg",
	"sfx_wildlife_dune_fennec_4": "res://audio/sfx/sfx_wildlife_dune_fennec_4.ogg",
	"sfx_wildlife_egg_hatch_1": "res://audio/sfx/sfx_wildlife_egg_hatch_1.ogg",
	"sfx_wildlife_egg_hatch_2": "res://audio/sfx/sfx_wildlife_egg_hatch_2.ogg",
	"sfx_wildlife_egg_hatch_3": "res://audio/sfx/sfx_wildlife_egg_hatch_3.ogg",
	"sfx_wildlife_egg_hatch_4": "res://audio/sfx/sfx_wildlife_egg_hatch_4.ogg",
	"sfx_wildlife_egg_hatch_5": "res://audio/sfx/sfx_wildlife_egg_hatch_5.ogg",
	"sfx_wildlife_egg_hatch_6": "res://audio/sfx/sfx_wildlife_egg_hatch_6.ogg",
	"sfx_wildlife_egg_hatch_7": "res://audio/sfx/sfx_wildlife_egg_hatch_7.ogg",
	"sfx_wildlife_egg_hatch_8": "res://audio/sfx/sfx_wildlife_egg_hatch_8.ogg",
	"sfx_wildlife_egg_take_1": "res://audio/sfx/sfx_wildlife_egg_take_1.ogg",
	"sfx_wildlife_egg_take_2": "res://audio/sfx/sfx_wildlife_egg_take_2.ogg",
	"sfx_wildlife_egg_take_3": "res://audio/sfx/sfx_wildlife_egg_take_3.ogg",
	"sfx_wildlife_egg_take_4": "res://audio/sfx/sfx_wildlife_egg_take_4.ogg",
	"sfx_wildlife_fall_heavy_1": "res://audio/sfx/sfx_wildlife_fall_heavy_1.ogg",
	"sfx_wildlife_fall_heavy_2": "res://audio/sfx/sfx_wildlife_fall_heavy_2.ogg",
	"sfx_wildlife_fall_heavy_3": "res://audio/sfx/sfx_wildlife_fall_heavy_3.ogg",
	"sfx_wildlife_fall_heavy_4": "res://audio/sfx/sfx_wildlife_fall_heavy_4.ogg",
	"sfx_wildlife_fall_heavy_5": "res://audio/sfx/sfx_wildlife_fall_heavy_5.ogg",
	"sfx_wildlife_fall_heavy_6": "res://audio/sfx/sfx_wildlife_fall_heavy_6.ogg",
	"sfx_wildlife_fall_heavy_7": "res://audio/sfx/sfx_wildlife_fall_heavy_7.ogg",
	"sfx_wildlife_fall_heavy_8": "res://audio/sfx/sfx_wildlife_fall_heavy_8.ogg",
	"sfx_wildlife_fall_heavy_9": "res://audio/sfx/sfx_wildlife_fall_heavy_9.ogg",
	"sfx_wildlife_fall_heavy_10": "res://audio/sfx/sfx_wildlife_fall_heavy_10.ogg",
	"sfx_wildlife_fall_light_1": "res://audio/sfx/sfx_wildlife_fall_light_1.ogg",
	"sfx_wildlife_fall_light_2": "res://audio/sfx/sfx_wildlife_fall_light_2.ogg",
	"sfx_wildlife_fall_light_3": "res://audio/sfx/sfx_wildlife_fall_light_3.ogg",
	"sfx_wildlife_fall_light_4": "res://audio/sfx/sfx_wildlife_fall_light_4.ogg",
	"sfx_wildlife_fall_light_5": "res://audio/sfx/sfx_wildlife_fall_light_5.ogg",
	"sfx_wildlife_fall_light_6": "res://audio/sfx/sfx_wildlife_fall_light_6.ogg",
	"sfx_wildlife_fall_light_7": "res://audio/sfx/sfx_wildlife_fall_light_7.ogg",
	"sfx_wildlife_fall_light_8": "res://audio/sfx/sfx_wildlife_fall_light_8.ogg",
	"sfx_wildlife_fall_light_9": "res://audio/sfx/sfx_wildlife_fall_light_9.ogg",
	"sfx_wildlife_frost_elk_1": "res://audio/sfx/sfx_wildlife_frost_elk_1.ogg",
	"sfx_wildlife_frost_elk_2": "res://audio/sfx/sfx_wildlife_frost_elk_2.ogg",
	"sfx_wildlife_frost_elk_3": "res://audio/sfx/sfx_wildlife_frost_elk_3.ogg",
	"sfx_wildlife_frost_elk_4": "res://audio/sfx/sfx_wildlife_frost_elk_4.ogg",
	"sfx_wildlife_frost_elk_5": "res://audio/sfx/sfx_wildlife_frost_elk_5.ogg",
	"sfx_wildlife_frost_elk_6": "res://audio/sfx/sfx_wildlife_frost_elk_6.ogg",
	"sfx_wildlife_frost_elk_7": "res://audio/sfx/sfx_wildlife_frost_elk_7.ogg",
	"sfx_wildlife_frost_elk_8": "res://audio/sfx/sfx_wildlife_frost_elk_8.ogg",
	"sfx_wildlife_glass_lizard_1": "res://audio/sfx/sfx_wildlife_glass_lizard_1.ogg",
	"sfx_wildlife_glass_lizard_2": "res://audio/sfx/sfx_wildlife_glass_lizard_2.ogg",
	"sfx_wildlife_glass_lizard_3": "res://audio/sfx/sfx_wildlife_glass_lizard_3.ogg",
	"sfx_wildlife_glass_lizard_4": "res://audio/sfx/sfx_wildlife_glass_lizard_4.ogg",
	"sfx_wildlife_glimmerfox_1": "res://audio/sfx/sfx_wildlife_glimmerfox_1.ogg",
	"sfx_wildlife_glimmerfox_2": "res://audio/sfx/sfx_wildlife_glimmerfox_2.ogg",
	"sfx_wildlife_glimmerfox_3": "res://audio/sfx/sfx_wildlife_glimmerfox_3.ogg",
	"sfx_wildlife_griffon_1": "res://audio/sfx/sfx_wildlife_griffon_1.ogg",
	"sfx_wildlife_griffon_2": "res://audio/sfx/sfx_wildlife_griffon_2.ogg",
	"sfx_wildlife_griffon_3": "res://audio/sfx/sfx_wildlife_griffon_3.ogg",
	"sfx_wildlife_griffon_4": "res://audio/sfx/sfx_wildlife_griffon_4.ogg",
	"sfx_wildlife_griffon_5": "res://audio/sfx/sfx_wildlife_griffon_5.ogg",
	"sfx_wildlife_griffon_6": "res://audio/sfx/sfx_wildlife_griffon_6.ogg",
	"sfx_wildlife_griffon_7": "res://audio/sfx/sfx_wildlife_griffon_7.ogg",
	"sfx_wildlife_griffon_8": "res://audio/sfx/sfx_wildlife_griffon_8.ogg",
	"sfx_wildlife_hedgehog_1": "res://audio/sfx/sfx_wildlife_hedgehog_1.ogg",
	"sfx_wildlife_hedgehog_2": "res://audio/sfx/sfx_wildlife_hedgehog_2.ogg",
	"sfx_wildlife_hedgehog_3": "res://audio/sfx/sfx_wildlife_hedgehog_3.ogg",
	"sfx_wildlife_hedgehog_4": "res://audio/sfx/sfx_wildlife_hedgehog_4.ogg",
	"sfx_wildlife_hedgehog_5": "res://audio/sfx/sfx_wildlife_hedgehog_5.ogg",
	"sfx_wildlife_hedgehog_6": "res://audio/sfx/sfx_wildlife_hedgehog_6.ogg",
	"sfx_wildlife_hedgehog_7": "res://audio/sfx/sfx_wildlife_hedgehog_7.ogg",
	"sfx_wildlife_hedgehog_8": "res://audio/sfx/sfx_wildlife_hedgehog_8.ogg",
	"sfx_wildlife_hedgehog_9": "res://audio/sfx/sfx_wildlife_hedgehog_9.ogg",
	"sfx_wildlife_hedgehog_10": "res://audio/sfx/sfx_wildlife_hedgehog_10.ogg",
	"sfx_wildlife_hedgehog_11": "res://audio/sfx/sfx_wildlife_hedgehog_11.ogg",
	"sfx_wildlife_hedgehog_12": "res://audio/sfx/sfx_wildlife_hedgehog_12.ogg",
	"sfx_wildlife_heron_1": "res://audio/sfx/sfx_wildlife_heron_1.ogg",
	"sfx_wildlife_heron_2": "res://audio/sfx/sfx_wildlife_heron_2.ogg",
	"sfx_wildlife_heron_3": "res://audio/sfx/sfx_wildlife_heron_3.ogg",
	"sfx_wildlife_heron_4": "res://audio/sfx/sfx_wildlife_heron_4.ogg",
	"sfx_wildlife_heron_5": "res://audio/sfx/sfx_wildlife_heron_5.ogg",
	"sfx_wildlife_heron_6": "res://audio/sfx/sfx_wildlife_heron_6.ogg",
	"sfx_wildlife_heron_7": "res://audio/sfx/sfx_wildlife_heron_7.ogg",
	"sfx_wildlife_heron_8": "res://audio/sfx/sfx_wildlife_heron_8.ogg",
	"sfx_wildlife_heron_9": "res://audio/sfx/sfx_wildlife_heron_9.ogg",
	"sfx_wildlife_heron_10": "res://audio/sfx/sfx_wildlife_heron_10.ogg",
	"sfx_wildlife_heron_11": "res://audio/sfx/sfx_wildlife_heron_11.ogg",
	"sfx_wildlife_heron_12": "res://audio/sfx/sfx_wildlife_heron_12.ogg",
	"sfx_wildlife_hit_chitin_1": "res://audio/sfx/sfx_wildlife_hit_chitin_1.ogg",
	"sfx_wildlife_hit_chitin_2": "res://audio/sfx/sfx_wildlife_hit_chitin_2.ogg",
	"sfx_wildlife_hit_chitin_3": "res://audio/sfx/sfx_wildlife_hit_chitin_3.ogg",
	"sfx_wildlife_hit_chitin_4": "res://audio/sfx/sfx_wildlife_hit_chitin_4.ogg",
	"sfx_wildlife_hit_chitin_5": "res://audio/sfx/sfx_wildlife_hit_chitin_5.ogg",
	"sfx_wildlife_hit_chitin_6": "res://audio/sfx/sfx_wildlife_hit_chitin_6.ogg",
	"sfx_wildlife_hit_chitin_7": "res://audio/sfx/sfx_wildlife_hit_chitin_7.ogg",
	"sfx_wildlife_hit_chitin_8": "res://audio/sfx/sfx_wildlife_hit_chitin_8.ogg",
	"sfx_wildlife_hit_feather_1": "res://audio/sfx/sfx_wildlife_hit_feather_1.ogg",
	"sfx_wildlife_hit_feather_2": "res://audio/sfx/sfx_wildlife_hit_feather_2.ogg",
	"sfx_wildlife_hit_feather_3": "res://audio/sfx/sfx_wildlife_hit_feather_3.ogg",
	"sfx_wildlife_hit_feather_4": "res://audio/sfx/sfx_wildlife_hit_feather_4.ogg",
	"sfx_wildlife_hit_feather_5": "res://audio/sfx/sfx_wildlife_hit_feather_5.ogg",
	"sfx_wildlife_hit_feather_6": "res://audio/sfx/sfx_wildlife_hit_feather_6.ogg",
	"sfx_wildlife_hit_feather_7": "res://audio/sfx/sfx_wildlife_hit_feather_7.ogg",
	"sfx_wildlife_hit_feather_8": "res://audio/sfx/sfx_wildlife_hit_feather_8.ogg",
	"sfx_wildlife_hit_feather_9": "res://audio/sfx/sfx_wildlife_hit_feather_9.ogg",
	"sfx_wildlife_hit_feather_10": "res://audio/sfx/sfx_wildlife_hit_feather_10.ogg",
	"sfx_wildlife_hit_feather_11": "res://audio/sfx/sfx_wildlife_hit_feather_11.ogg",
	"sfx_wildlife_hit_feather_12": "res://audio/sfx/sfx_wildlife_hit_feather_12.ogg",
	"sfx_wildlife_hit_fur_1": "res://audio/sfx/sfx_wildlife_hit_fur_1.ogg",
	"sfx_wildlife_hit_fur_2": "res://audio/sfx/sfx_wildlife_hit_fur_2.ogg",
	"sfx_wildlife_hit_fur_3": "res://audio/sfx/sfx_wildlife_hit_fur_3.ogg",
	"sfx_wildlife_hit_fur_4": "res://audio/sfx/sfx_wildlife_hit_fur_4.ogg",
	"sfx_wildlife_hit_fur_5": "res://audio/sfx/sfx_wildlife_hit_fur_5.ogg",
	"sfx_wildlife_hit_fur_6": "res://audio/sfx/sfx_wildlife_hit_fur_6.ogg",
	"sfx_wildlife_hit_fur_7": "res://audio/sfx/sfx_wildlife_hit_fur_7.ogg",
	"sfx_wildlife_hit_fur_8": "res://audio/sfx/sfx_wildlife_hit_fur_8.ogg",
	"sfx_wildlife_hit_fur_9": "res://audio/sfx/sfx_wildlife_hit_fur_9.ogg",
	"sfx_wildlife_hit_fur_10": "res://audio/sfx/sfx_wildlife_hit_fur_10.ogg",
	"sfx_wildlife_hit_fur_11": "res://audio/sfx/sfx_wildlife_hit_fur_11.ogg",
	"sfx_wildlife_hit_fur_12": "res://audio/sfx/sfx_wildlife_hit_fur_12.ogg",
	"sfx_wildlife_hit_scale_1": "res://audio/sfx/sfx_wildlife_hit_scale_1.ogg",
	"sfx_wildlife_hit_scale_2": "res://audio/sfx/sfx_wildlife_hit_scale_2.ogg",
	"sfx_wildlife_hit_scale_3": "res://audio/sfx/sfx_wildlife_hit_scale_3.ogg",
	"sfx_wildlife_hit_scale_4": "res://audio/sfx/sfx_wildlife_hit_scale_4.ogg",
	"sfx_wildlife_hit_scale_5": "res://audio/sfx/sfx_wildlife_hit_scale_5.ogg",
	"sfx_wildlife_hit_scale_6": "res://audio/sfx/sfx_wildlife_hit_scale_6.ogg",
	"sfx_wildlife_hit_scale_7": "res://audio/sfx/sfx_wildlife_hit_scale_7.ogg",
	"sfx_wildlife_hit_scale_8": "res://audio/sfx/sfx_wildlife_hit_scale_8.ogg",
	"sfx_wildlife_hit_scale_9": "res://audio/sfx/sfx_wildlife_hit_scale_9.ogg",
	"sfx_wildlife_hit_scale_10": "res://audio/sfx/sfx_wildlife_hit_scale_10.ogg",
	"sfx_wildlife_hit_scale_11": "res://audio/sfx/sfx_wildlife_hit_scale_11.ogg",
	"sfx_wildlife_hit_scale_12": "res://audio/sfx/sfx_wildlife_hit_scale_12.ogg",
	"sfx_wildlife_hit_shell_1": "res://audio/sfx/sfx_wildlife_hit_shell_1.ogg",
	"sfx_wildlife_hit_shell_2": "res://audio/sfx/sfx_wildlife_hit_shell_2.ogg",
	"sfx_wildlife_hit_shell_3": "res://audio/sfx/sfx_wildlife_hit_shell_3.ogg",
	"sfx_wildlife_hit_shell_4": "res://audio/sfx/sfx_wildlife_hit_shell_4.ogg",
	"sfx_wildlife_hit_shell_5": "res://audio/sfx/sfx_wildlife_hit_shell_5.ogg",
	"sfx_wildlife_hit_shell_6": "res://audio/sfx/sfx_wildlife_hit_shell_6.ogg",
	"sfx_wildlife_hollowhorn_1": "res://audio/sfx/sfx_wildlife_hollowhorn_1.ogg",
	"sfx_wildlife_hollowhorn_2": "res://audio/sfx/sfx_wildlife_hollowhorn_2.ogg",
	"sfx_wildlife_hollowhorn_3": "res://audio/sfx/sfx_wildlife_hollowhorn_3.ogg",
	"sfx_wildlife_hollowhorn_4": "res://audio/sfx/sfx_wildlife_hollowhorn_4.ogg",
	"sfx_wildlife_hollowhorn_5": "res://audio/sfx/sfx_wildlife_hollowhorn_5.ogg",
	"sfx_wildlife_hollowhorn_6": "res://audio/sfx/sfx_wildlife_hollowhorn_6.ogg",
	"sfx_wildlife_hollowhorn_7": "res://audio/sfx/sfx_wildlife_hollowhorn_7.ogg",
	"sfx_wildlife_hollowhorn_8": "res://audio/sfx/sfx_wildlife_hollowhorn_8.ogg",
	"sfx_wildlife_hurt_amphibian_1": "res://audio/sfx/sfx_wildlife_hurt_amphibian_1.ogg",
	"sfx_wildlife_hurt_amphibian_2": "res://audio/sfx/sfx_wildlife_hurt_amphibian_2.ogg",
	"sfx_wildlife_hurt_amphibian_3": "res://audio/sfx/sfx_wildlife_hurt_amphibian_3.ogg",
	"sfx_wildlife_hurt_amphibian_4": "res://audio/sfx/sfx_wildlife_hurt_amphibian_4.ogg",
	"sfx_wildlife_hurt_amphibian_5": "res://audio/sfx/sfx_wildlife_hurt_amphibian_5.ogg",
	"sfx_wildlife_hurt_amphibian_6": "res://audio/sfx/sfx_wildlife_hurt_amphibian_6.ogg",
	"sfx_wildlife_hurt_amphibian_7": "res://audio/sfx/sfx_wildlife_hurt_amphibian_7.ogg",
	"sfx_wildlife_hurt_amphibian_8": "res://audio/sfx/sfx_wildlife_hurt_amphibian_8.ogg",
	"sfx_wildlife_hurt_amphibian_9": "res://audio/sfx/sfx_wildlife_hurt_amphibian_9.ogg",
	"sfx_wildlife_hurt_amphibian_10": "res://audio/sfx/sfx_wildlife_hurt_amphibian_10.ogg",
	"sfx_wildlife_hurt_amphibian_11": "res://audio/sfx/sfx_wildlife_hurt_amphibian_11.ogg",
	"sfx_wildlife_hurt_amphibian_12": "res://audio/sfx/sfx_wildlife_hurt_amphibian_12.ogg",
	"sfx_wildlife_hurt_bird_1": "res://audio/sfx/sfx_wildlife_hurt_bird_1.ogg",
	"sfx_wildlife_hurt_bird_2": "res://audio/sfx/sfx_wildlife_hurt_bird_2.ogg",
	"sfx_wildlife_hurt_bird_3": "res://audio/sfx/sfx_wildlife_hurt_bird_3.ogg",
	"sfx_wildlife_hurt_bird_4": "res://audio/sfx/sfx_wildlife_hurt_bird_4.ogg",
	"sfx_wildlife_hurt_bird_5": "res://audio/sfx/sfx_wildlife_hurt_bird_5.ogg",
	"sfx_wildlife_hurt_bird_6": "res://audio/sfx/sfx_wildlife_hurt_bird_6.ogg",
	"sfx_wildlife_hurt_bird_7": "res://audio/sfx/sfx_wildlife_hurt_bird_7.ogg",
	"sfx_wildlife_hurt_bird_8": "res://audio/sfx/sfx_wildlife_hurt_bird_8.ogg",
	"sfx_wildlife_hurt_bird_9": "res://audio/sfx/sfx_wildlife_hurt_bird_9.ogg",
	"sfx_wildlife_hurt_bird_10": "res://audio/sfx/sfx_wildlife_hurt_bird_10.ogg",
	"sfx_wildlife_hurt_bird_11": "res://audio/sfx/sfx_wildlife_hurt_bird_11.ogg",
	"sfx_wildlife_hurt_bird_12": "res://audio/sfx/sfx_wildlife_hurt_bird_12.ogg",
	"sfx_wildlife_hurt_reptile_1": "res://audio/sfx/sfx_wildlife_hurt_reptile_1.ogg",
	"sfx_wildlife_hurt_reptile_2": "res://audio/sfx/sfx_wildlife_hurt_reptile_2.ogg",
	"sfx_wildlife_hurt_reptile_3": "res://audio/sfx/sfx_wildlife_hurt_reptile_3.ogg",
	"sfx_wildlife_hurt_reptile_4": "res://audio/sfx/sfx_wildlife_hurt_reptile_4.ogg",
	"sfx_wildlife_hurt_reptile_5": "res://audio/sfx/sfx_wildlife_hurt_reptile_5.ogg",
	"sfx_wildlife_hurt_reptile_6": "res://audio/sfx/sfx_wildlife_hurt_reptile_6.ogg",
	"sfx_wildlife_hurt_reptile_7": "res://audio/sfx/sfx_wildlife_hurt_reptile_7.ogg",
	"sfx_wildlife_hurt_reptile_8": "res://audio/sfx/sfx_wildlife_hurt_reptile_8.ogg",
	"sfx_wildlife_hurt_reptile_9": "res://audio/sfx/sfx_wildlife_hurt_reptile_9.ogg",
	"sfx_wildlife_hurt_reptile_10": "res://audio/sfx/sfx_wildlife_hurt_reptile_10.ogg",
	"sfx_wildlife_hurt_reptile_11": "res://audio/sfx/sfx_wildlife_hurt_reptile_11.ogg",
	"sfx_wildlife_hurt_reptile_12": "res://audio/sfx/sfx_wildlife_hurt_reptile_12.ogg",
	"sfx_wildlife_hurt_small_beast_1": "res://audio/sfx/sfx_wildlife_hurt_small_beast_1.ogg",
	"sfx_wildlife_hurt_small_beast_2": "res://audio/sfx/sfx_wildlife_hurt_small_beast_2.ogg",
	"sfx_wildlife_hurt_small_beast_3": "res://audio/sfx/sfx_wildlife_hurt_small_beast_3.ogg",
	"sfx_wildlife_hurt_small_beast_4": "res://audio/sfx/sfx_wildlife_hurt_small_beast_4.ogg",
	"sfx_wildlife_hurt_small_beast_5": "res://audio/sfx/sfx_wildlife_hurt_small_beast_5.ogg",
	"sfx_wildlife_hurt_small_beast_6": "res://audio/sfx/sfx_wildlife_hurt_small_beast_6.ogg",
	"sfx_wildlife_hurt_small_beast_7": "res://audio/sfx/sfx_wildlife_hurt_small_beast_7.ogg",
	"sfx_wildlife_hurt_small_beast_8": "res://audio/sfx/sfx_wildlife_hurt_small_beast_8.ogg",
	"sfx_wildlife_hurt_small_beast_9": "res://audio/sfx/sfx_wildlife_hurt_small_beast_9.ogg",
	"sfx_wildlife_hurt_small_beast_10": "res://audio/sfx/sfx_wildlife_hurt_small_beast_10.ogg",
	"sfx_wildlife_hurt_small_beast_11": "res://audio/sfx/sfx_wildlife_hurt_small_beast_11.ogg",
	"sfx_wildlife_hurt_small_beast_12": "res://audio/sfx/sfx_wildlife_hurt_small_beast_12.ogg",
	"sfx_wildlife_hurt_small_beast_13": "res://audio/sfx/sfx_wildlife_hurt_small_beast_13.ogg",
	"sfx_wildlife_hurt_small_beast_14": "res://audio/sfx/sfx_wildlife_hurt_small_beast_14.ogg",
	"sfx_wildlife_hurt_small_beast_15": "res://audio/sfx/sfx_wildlife_hurt_small_beast_15.ogg",
	"sfx_wildlife_hurt_small_beast_16": "res://audio/sfx/sfx_wildlife_hurt_small_beast_16.ogg",
	"sfx_wildlife_jackal_1": "res://audio/sfx/sfx_wildlife_jackal_1.ogg",
	"sfx_wildlife_jackal_2": "res://audio/sfx/sfx_wildlife_jackal_2.ogg",
	"sfx_wildlife_jackal_3": "res://audio/sfx/sfx_wildlife_jackal_3.ogg",
	"sfx_wildlife_jackal_4": "res://audio/sfx/sfx_wildlife_jackal_4.ogg",
	"sfx_wildlife_jackal_5": "res://audio/sfx/sfx_wildlife_jackal_5.ogg",
	"sfx_wildlife_jackal_6": "res://audio/sfx/sfx_wildlife_jackal_6.ogg",
	"sfx_wildlife_jackal_7": "res://audio/sfx/sfx_wildlife_jackal_7.ogg",
	"sfx_wildlife_jackal_8": "res://audio/sfx/sfx_wildlife_jackal_8.ogg",
	"sfx_wildlife_lynx_1": "res://audio/sfx/sfx_wildlife_lynx_1.ogg",
	"sfx_wildlife_lynx_2": "res://audio/sfx/sfx_wildlife_lynx_2.ogg",
	"sfx_wildlife_lynx_3": "res://audio/sfx/sfx_wildlife_lynx_3.ogg",
	"sfx_wildlife_lynx_4": "res://audio/sfx/sfx_wildlife_lynx_4.ogg",
	"sfx_wildlife_marsh_otter_1": "res://audio/sfx/sfx_wildlife_marsh_otter_1.ogg",
	"sfx_wildlife_marsh_otter_2": "res://audio/sfx/sfx_wildlife_marsh_otter_2.ogg",
	"sfx_wildlife_marsh_otter_3": "res://audio/sfx/sfx_wildlife_marsh_otter_3.ogg",
	"sfx_wildlife_marsh_otter_4": "res://audio/sfx/sfx_wildlife_marsh_otter_4.ogg",
	"sfx_wildlife_marsh_otter_5": "res://audio/sfx/sfx_wildlife_marsh_otter_5.ogg",
	"sfx_wildlife_marsh_otter_6": "res://audio/sfx/sfx_wildlife_marsh_otter_6.ogg",
	"sfx_wildlife_marsh_otter_7": "res://audio/sfx/sfx_wildlife_marsh_otter_7.ogg",
	"sfx_wildlife_marsh_otter_8": "res://audio/sfx/sfx_wildlife_marsh_otter_8.ogg",
	"sfx_wildlife_mireback_alligator_1": "res://audio/sfx/sfx_wildlife_mireback_alligator_1.ogg",
	"sfx_wildlife_mireback_alligator_2": "res://audio/sfx/sfx_wildlife_mireback_alligator_2.ogg",
	"sfx_wildlife_mireback_alligator_3": "res://audio/sfx/sfx_wildlife_mireback_alligator_3.ogg",
	"sfx_wildlife_mireback_alligator_4": "res://audio/sfx/sfx_wildlife_mireback_alligator_4.ogg",
	"sfx_wildlife_mireback_alligator_5": "res://audio/sfx/sfx_wildlife_mireback_alligator_5.ogg",
	"sfx_wildlife_mireback_alligator_6": "res://audio/sfx/sfx_wildlife_mireback_alligator_6.ogg",
	"sfx_wildlife_mireback_alligator_7": "res://audio/sfx/sfx_wildlife_mireback_alligator_7.ogg",
	"sfx_wildlife_mireback_alligator_8": "res://audio/sfx/sfx_wildlife_mireback_alligator_8.ogg",
	"sfx_wildlife_mireback_alligator_9": "res://audio/sfx/sfx_wildlife_mireback_alligator_9.ogg",
	"sfx_wildlife_mireback_alligator_10": "res://audio/sfx/sfx_wildlife_mireback_alligator_10.ogg",
	"sfx_wildlife_mireback_alligator_11": "res://audio/sfx/sfx_wildlife_mireback_alligator_11.ogg",
	"sfx_wildlife_mireback_alligator_12": "res://audio/sfx/sfx_wildlife_mireback_alligator_12.ogg",
	"sfx_wildlife_mireback_alligator_13": "res://audio/sfx/sfx_wildlife_mireback_alligator_13.ogg",
	"sfx_wildlife_moonstag_1": "res://audio/sfx/sfx_wildlife_moonstag_1.ogg",
	"sfx_wildlife_moonstag_2": "res://audio/sfx/sfx_wildlife_moonstag_2.ogg",
	"sfx_wildlife_moonstag_3": "res://audio/sfx/sfx_wildlife_moonstag_3.ogg",
	"sfx_wildlife_moonstag_4": "res://audio/sfx/sfx_wildlife_moonstag_4.ogg",
	"sfx_wildlife_nest_lay_1": "res://audio/sfx/sfx_wildlife_nest_lay_1.ogg",
	"sfx_wildlife_nest_lay_2": "res://audio/sfx/sfx_wildlife_nest_lay_2.ogg",
	"sfx_wildlife_nest_lay_3": "res://audio/sfx/sfx_wildlife_nest_lay_3.ogg",
	"sfx_wildlife_nest_lay_4": "res://audio/sfx/sfx_wildlife_nest_lay_4.ogg",
	"sfx_wildlife_nest_lay_5": "res://audio/sfx/sfx_wildlife_nest_lay_5.ogg",
	"sfx_wildlife_nest_lay_6": "res://audio/sfx/sfx_wildlife_nest_lay_6.ogg",
	"sfx_wildlife_nest_lay_7": "res://audio/sfx/sfx_wildlife_nest_lay_7.ogg",
	"sfx_wildlife_nest_lay_8": "res://audio/sfx/sfx_wildlife_nest_lay_8.ogg",
	"sfx_wildlife_oreback_pangolin_1": "res://audio/sfx/sfx_wildlife_oreback_pangolin_1.ogg",
	"sfx_wildlife_oreback_pangolin_2": "res://audio/sfx/sfx_wildlife_oreback_pangolin_2.ogg",
	"sfx_wildlife_oreback_pangolin_3": "res://audio/sfx/sfx_wildlife_oreback_pangolin_3.ogg",
	"sfx_wildlife_oreback_pangolin_4": "res://audio/sfx/sfx_wildlife_oreback_pangolin_4.ogg",
	"sfx_wildlife_phoenix_1": "res://audio/sfx/sfx_wildlife_phoenix_1.ogg",
	"sfx_wildlife_phoenix_2": "res://audio/sfx/sfx_wildlife_phoenix_2.ogg",
	"sfx_wildlife_phoenix_3": "res://audio/sfx/sfx_wildlife_phoenix_3.ogg",
	"sfx_wildlife_phoenix_4": "res://audio/sfx/sfx_wildlife_phoenix_4.ogg",
	"sfx_wildlife_phoenix_5": "res://audio/sfx/sfx_wildlife_phoenix_5.ogg",
	"sfx_wildlife_phoenix_6": "res://audio/sfx/sfx_wildlife_phoenix_6.ogg",
	"sfx_wildlife_phoenix_7": "res://audio/sfx/sfx_wildlife_phoenix_7.ogg",
	"sfx_wildlife_phoenix_8": "res://audio/sfx/sfx_wildlife_phoenix_8.ogg",
	"sfx_wildlife_phoenix_9": "res://audio/sfx/sfx_wildlife_phoenix_9.ogg",
	"sfx_wildlife_phoenix_10": "res://audio/sfx/sfx_wildlife_phoenix_10.ogg",
	"sfx_wildlife_phoenix_11": "res://audio/sfx/sfx_wildlife_phoenix_11.ogg",
	"sfx_wildlife_phoenix_12": "res://audio/sfx/sfx_wildlife_phoenix_12.ogg",
	"sfx_wildlife_ptarmigan_1": "res://audio/sfx/sfx_wildlife_ptarmigan_1.ogg",
	"sfx_wildlife_ptarmigan_2": "res://audio/sfx/sfx_wildlife_ptarmigan_2.ogg",
	"sfx_wildlife_ptarmigan_3": "res://audio/sfx/sfx_wildlife_ptarmigan_3.ogg",
	"sfx_wildlife_ptarmigan_4": "res://audio/sfx/sfx_wildlife_ptarmigan_4.ogg",
	"sfx_wildlife_ptarmigan_5": "res://audio/sfx/sfx_wildlife_ptarmigan_5.ogg",
	"sfx_wildlife_ptarmigan_6": "res://audio/sfx/sfx_wildlife_ptarmigan_6.ogg",
	"sfx_wildlife_ptarmigan_7": "res://audio/sfx/sfx_wildlife_ptarmigan_7.ogg",
	"sfx_wildlife_ptarmigan_8": "res://audio/sfx/sfx_wildlife_ptarmigan_8.ogg",
	"sfx_wildlife_ptarmigan_9": "res://audio/sfx/sfx_wildlife_ptarmigan_9.ogg",
	"sfx_wildlife_ptarmigan_10": "res://audio/sfx/sfx_wildlife_ptarmigan_10.ogg",
	"sfx_wildlife_ptarmigan_11": "res://audio/sfx/sfx_wildlife_ptarmigan_11.ogg",
	"sfx_wildlife_ptarmigan_12": "res://audio/sfx/sfx_wildlife_ptarmigan_12.ogg",
	"sfx_wildlife_rift_out_1": "res://audio/sfx/sfx_wildlife_rift_out_1.ogg",
	"sfx_wildlife_rift_out_2": "res://audio/sfx/sfx_wildlife_rift_out_2.ogg",
	"sfx_wildlife_rift_out_3": "res://audio/sfx/sfx_wildlife_rift_out_3.ogg",
	"sfx_wildlife_rift_out_4": "res://audio/sfx/sfx_wildlife_rift_out_4.ogg",
	"sfx_wildlife_saltpan_monitor_1": "res://audio/sfx/sfx_wildlife_saltpan_monitor_1.ogg",
	"sfx_wildlife_saltpan_monitor_2": "res://audio/sfx/sfx_wildlife_saltpan_monitor_2.ogg",
	"sfx_wildlife_saltpan_monitor_3": "res://audio/sfx/sfx_wildlife_saltpan_monitor_3.ogg",
	"sfx_wildlife_savage_arrival_1": "res://audio/sfx/sfx_wildlife_savage_arrival_1.ogg",
	"sfx_wildlife_savage_arrival_2": "res://audio/sfx/sfx_wildlife_savage_arrival_2.ogg",
	"sfx_wildlife_savage_arrival_3": "res://audio/sfx/sfx_wildlife_savage_arrival_3.ogg",
	"sfx_wildlife_savage_arrival_4": "res://audio/sfx/sfx_wildlife_savage_arrival_4.ogg",
	"sfx_wildlife_savage_arrival_5": "res://audio/sfx/sfx_wildlife_savage_arrival_5.ogg",
	"sfx_wildlife_savage_arrival_6": "res://audio/sfx/sfx_wildlife_savage_arrival_6.ogg",
	"sfx_wildlife_savage_arrival_7": "res://audio/sfx/sfx_wildlife_savage_arrival_7.ogg",
	"sfx_wildlife_savage_arrival_8": "res://audio/sfx/sfx_wildlife_savage_arrival_8.ogg",
	"sfx_wildlife_screestalker_1": "res://audio/sfx/sfx_wildlife_screestalker_1.ogg",
	"sfx_wildlife_screestalker_2": "res://audio/sfx/sfx_wildlife_screestalker_2.ogg",
	"sfx_wildlife_screestalker_3": "res://audio/sfx/sfx_wildlife_screestalker_3.ogg",
	"sfx_wildlife_snow_hare_1": "res://audio/sfx/sfx_wildlife_snow_hare_1.ogg",
	"sfx_wildlife_snow_hare_2": "res://audio/sfx/sfx_wildlife_snow_hare_2.ogg",
	"sfx_wildlife_snow_hare_3": "res://audio/sfx/sfx_wildlife_snow_hare_3.ogg",
	"sfx_wildlife_snow_hare_4": "res://audio/sfx/sfx_wildlife_snow_hare_4.ogg",
	"sfx_wildlife_snow_hare_5": "res://audio/sfx/sfx_wildlife_snow_hare_5.ogg",
	"sfx_wildlife_snow_hare_6": "res://audio/sfx/sfx_wildlife_snow_hare_6.ogg",
	"sfx_wildlife_snow_hare_7": "res://audio/sfx/sfx_wildlife_snow_hare_7.ogg",
	"sfx_wildlife_snow_hare_8": "res://audio/sfx/sfx_wildlife_snow_hare_8.ogg",
	"sfx_wildlife_snow_lynx_1": "res://audio/sfx/sfx_wildlife_snow_lynx_1.ogg",
	"sfx_wildlife_snow_lynx_2": "res://audio/sfx/sfx_wildlife_snow_lynx_2.ogg",
	"sfx_wildlife_snow_lynx_3": "res://audio/sfx/sfx_wildlife_snow_lynx_3.ogg",
	"sfx_wildlife_snow_lynx_4": "res://audio/sfx/sfx_wildlife_snow_lynx_4.ogg",
	"sfx_wildlife_snow_lynx_5": "res://audio/sfx/sfx_wildlife_snow_lynx_5.ogg",
	"sfx_wildlife_snow_lynx_6": "res://audio/sfx/sfx_wildlife_snow_lynx_6.ogg",
	"sfx_wildlife_snow_lynx_7": "res://audio/sfx/sfx_wildlife_snow_lynx_7.ogg",
	"sfx_wildlife_snow_lynx_8": "res://audio/sfx/sfx_wildlife_snow_lynx_8.ogg",
	"sfx_wildlife_stag_1": "res://audio/sfx/sfx_wildlife_stag_1.ogg",
	"sfx_wildlife_stag_2": "res://audio/sfx/sfx_wildlife_stag_2.ogg",
	"sfx_wildlife_stag_3": "res://audio/sfx/sfx_wildlife_stag_3.ogg",
	"sfx_wildlife_stag_4": "res://audio/sfx/sfx_wildlife_stag_4.ogg",
	"sfx_wildlife_stag_5": "res://audio/sfx/sfx_wildlife_stag_5.ogg",
	"sfx_wildlife_stag_6": "res://audio/sfx/sfx_wildlife_stag_6.ogg",
	"sfx_wildlife_stag_7": "res://audio/sfx/sfx_wildlife_stag_7.ogg",
	"sfx_wildlife_stag_8": "res://audio/sfx/sfx_wildlife_stag_8.ogg",
	"sfx_wildlife_steppe_horse_1": "res://audio/sfx/sfx_wildlife_steppe_horse_1.ogg",
	"sfx_wildlife_steppe_horse_2": "res://audio/sfx/sfx_wildlife_steppe_horse_2.ogg",
	"sfx_wildlife_steppe_horse_3": "res://audio/sfx/sfx_wildlife_steppe_horse_3.ogg",
	"sfx_wildlife_steppe_horse_4": "res://audio/sfx/sfx_wildlife_steppe_horse_4.ogg",
	"sfx_wildlife_steppe_horse_5": "res://audio/sfx/sfx_wildlife_steppe_horse_5.ogg",
	"sfx_wildlife_steppe_horse_6": "res://audio/sfx/sfx_wildlife_steppe_horse_6.ogg",
	"sfx_wildlife_steppe_horse_7": "res://audio/sfx/sfx_wildlife_steppe_horse_7.ogg",
	"sfx_wildlife_steppe_horse_8": "res://audio/sfx/sfx_wildlife_steppe_horse_8.ogg",
	"sfx_wildlife_steppe_marmot_1": "res://audio/sfx/sfx_wildlife_steppe_marmot_1.ogg",
	"sfx_wildlife_steppe_marmot_2": "res://audio/sfx/sfx_wildlife_steppe_marmot_2.ogg",
	"sfx_wildlife_steppe_marmot_3": "res://audio/sfx/sfx_wildlife_steppe_marmot_3.ogg",
	"sfx_wildlife_steppe_marmot_4": "res://audio/sfx/sfx_wildlife_steppe_marmot_4.ogg",
	"sfx_wildlife_steppe_marmot_5": "res://audio/sfx/sfx_wildlife_steppe_marmot_5.ogg",
	"sfx_wildlife_steppe_marmot_6": "res://audio/sfx/sfx_wildlife_steppe_marmot_6.ogg",
	"sfx_wildlife_steppe_marmot_7": "res://audio/sfx/sfx_wildlife_steppe_marmot_7.ogg",
	"sfx_wildlife_steppe_marmot_8": "res://audio/sfx/sfx_wildlife_steppe_marmot_8.ogg",
	"sfx_wildlife_steppe_marmot_9": "res://audio/sfx/sfx_wildlife_steppe_marmot_9.ogg",
	"sfx_wildlife_trail_sign_1": "res://audio/sfx/sfx_wildlife_trail_sign_1.ogg",
	"sfx_wildlife_trail_sign_2": "res://audio/sfx/sfx_wildlife_trail_sign_2.ogg",
	"sfx_wildlife_trail_sign_3": "res://audio/sfx/sfx_wildlife_trail_sign_3.ogg",
	"sfx_wildlife_trail_sign_4": "res://audio/sfx/sfx_wildlife_trail_sign_4.ogg",
	"sfx_wildlife_wing_large_1": "res://audio/sfx/sfx_wildlife_wing_large_1.ogg",
	"sfx_wildlife_wing_large_2": "res://audio/sfx/sfx_wildlife_wing_large_2.ogg",
	"sfx_wildlife_wing_large_3": "res://audio/sfx/sfx_wildlife_wing_large_3.ogg",
	"sfx_wildlife_wing_large_4": "res://audio/sfx/sfx_wildlife_wing_large_4.ogg",
	"sfx_wildlife_wing_large_5": "res://audio/sfx/sfx_wildlife_wing_large_5.ogg",
	"sfx_wildlife_wing_large_6": "res://audio/sfx/sfx_wildlife_wing_large_6.ogg",
	"sfx_wildlife_wing_large_7": "res://audio/sfx/sfx_wildlife_wing_large_7.ogg",
	"sfx_wildlife_wing_large_8": "res://audio/sfx/sfx_wildlife_wing_large_8.ogg",
	"sfx_wildlife_wing_small_1": "res://audio/sfx/sfx_wildlife_wing_small_1.ogg",
	"sfx_wildlife_wing_small_2": "res://audio/sfx/sfx_wildlife_wing_small_2.ogg",
	"sfx_wildlife_wing_small_3": "res://audio/sfx/sfx_wildlife_wing_small_3.ogg",
	"sfx_wildlife_wing_small_4": "res://audio/sfx/sfx_wildlife_wing_small_4.ogg",
	"sfx_wildlife_wing_small_5": "res://audio/sfx/sfx_wildlife_wing_small_5.ogg",
	"sfx_wildlife_wing_small_6": "res://audio/sfx/sfx_wildlife_wing_small_6.ogg",
	"sfx_wildlife_wing_small_7": "res://audio/sfx/sfx_wildlife_wing_small_7.ogg",
	"sfx_wildlife_wing_small_8": "res://audio/sfx/sfx_wildlife_wing_small_8.ogg",
	"sfx_wildlife_hurt_large_beast_1": "res://audio/sfx/sfx_wildlife_hurt_large_beast_1.ogg",
	"sfx_wildlife_hurt_large_beast_2": "res://audio/sfx/sfx_wildlife_hurt_large_beast_2.ogg",
	"sfx_wildlife_hurt_large_beast_3": "res://audio/sfx/sfx_wildlife_hurt_large_beast_3.ogg",
	"sfx_wildlife_hurt_large_beast_4": "res://audio/sfx/sfx_wildlife_hurt_large_beast_4.ogg",
	"sfx_wildlife_hurt_large_beast_5": "res://audio/sfx/sfx_wildlife_hurt_large_beast_5.ogg",
	"sfx_wildlife_hurt_large_beast_6": "res://audio/sfx/sfx_wildlife_hurt_large_beast_6.ogg",
	"sfx_wildlife_hurt_large_beast_7": "res://audio/sfx/sfx_wildlife_hurt_large_beast_7.ogg",
	"sfx_wildlife_hurt_large_beast_8": "res://audio/sfx/sfx_wildlife_hurt_large_beast_8.ogg",
	"sfx_wildlife_hurt_large_beast_9": "res://audio/sfx/sfx_wildlife_hurt_large_beast_9.ogg",
	"sfx_wildlife_hurt_large_beast_10": "res://audio/sfx/sfx_wildlife_hurt_large_beast_10.ogg",
	"sfx_wildlife_hurt_large_beast_11": "res://audio/sfx/sfx_wildlife_hurt_large_beast_11.ogg",
	"sfx_wildlife_hurt_large_beast_12": "res://audio/sfx/sfx_wildlife_hurt_large_beast_12.ogg",
	"sfx_wildlife_hurt_large_beast_13": "res://audio/sfx/sfx_wildlife_hurt_large_beast_13.ogg",
	"sfx_wildlife_hurt_large_beast_14": "res://audio/sfx/sfx_wildlife_hurt_large_beast_14.ogg",
	"sfx_wildlife_hurt_large_beast_15": "res://audio/sfx/sfx_wildlife_hurt_large_beast_15.ogg",
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
	"sfx_water_bite_1": "res://audio/sfx/sfx_water_bite_1.ogg",
	"sfx_water_bite_2": "res://audio/sfx/sfx_water_bite_2.ogg",
	"sfx_water_bite_3": "res://audio/sfx/sfx_water_bite_3.ogg",
	"sfx_water_bite_4": "res://audio/sfx/sfx_water_bite_4.ogg",
	"sfx_water_bite_5": "res://audio/sfx/sfx_water_bite_5.ogg",
	"sfx_water_bite_6": "res://audio/sfx/sfx_water_bite_6.ogg",
	"sfx_water_bite_7": "res://audio/sfx/sfx_water_bite_7.ogg",
	"sfx_water_bite_8": "res://audio/sfx/sfx_water_bite_8.ogg",
	"sfx_water_shot_1": "res://audio/sfx/sfx_water_shot_1.ogg",
	"sfx_water_shot_2": "res://audio/sfx/sfx_water_shot_2.ogg",
	"sfx_water_shot_3": "res://audio/sfx/sfx_water_shot_3.ogg",
	"sfx_wave_incoming": "res://audio/sfx/sfx_wave_incoming.ogg",
	"sfx_well_drink_1": "res://audio/sfx/sfx_well_drink_1.ogg",
	"sfx_well_drink_2": "res://audio/sfx/sfx_well_drink_2.ogg",
	"sfx_well_drink_3": "res://audio/sfx/sfx_well_drink_3.ogg",
	"sfx_well_drink_4": "res://audio/sfx/sfx_well_drink_4.ogg",
	"sfx_well_drink_5": "res://audio/sfx/sfx_well_drink_5.ogg",
	"sfx_well_drink_6": "res://audio/sfx/sfx_well_drink_6.ogg",
	"sfx_well_drink_7": "res://audio/sfx/sfx_well_drink_7.ogg",
	"sfx_well_drink_8": "res://audio/sfx/sfx_well_drink_8.ogg",
	"sfx_well_drink_9": "res://audio/sfx/sfx_well_drink_9.ogg",
	"sfx_well_drink_10": "res://audio/sfx/sfx_well_drink_10.ogg",
	"sfx_well_drink_11": "res://audio/sfx/sfx_well_drink_11.ogg",
	"sfx_well_drink_12": "res://audio/sfx/sfx_well_drink_12.ogg",
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
	"sfx_wildlife_frog_1": "res://audio/sfx/sfx_wildlife_frog_1.ogg",
	"sfx_wildlife_frog_2": "res://audio/sfx/sfx_wildlife_frog_2.ogg",
	"sfx_wildlife_frog_3": "res://audio/sfx/sfx_wildlife_frog_3.ogg",
	"sfx_wildlife_frog_4": "res://audio/sfx/sfx_wildlife_frog_4.ogg",
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
	"sfx_wildlife_frog":         {"db": -13.0, "pitch": 0.12, "limit": 2, "gap": 0.25},
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
const PLACEHOLDERS: Array[String] = []


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
	"sfx_achievement": ["sfx_achievement_1", "sfx_achievement_2", "sfx_achievement_3"],
	"sfx_boss_fall": ["sfx_boss_fall_1", "sfx_boss_fall_2", "sfx_boss_fall_3", "sfx_boss_fall_4", "sfx_boss_fall_5", "sfx_boss_fall_6", "sfx_boss_fall_7", "sfx_boss_fall_8", "sfx_boss_fall_9", "sfx_boss_fall_10", "sfx_boss_fall_11"],
	"sfx_boss_stinger": ["sfx_boss_stinger_1", "sfx_boss_stinger_2", "sfx_boss_stinger_3", "sfx_boss_stinger_4"],
	"sfx_camp_razed": ["sfx_camp_razed_1", "sfx_camp_razed_2", "sfx_camp_razed_3", "sfx_camp_razed_4", "sfx_camp_razed_5", "sfx_camp_razed_6", "sfx_camp_razed_7", "sfx_camp_razed_8", "sfx_camp_razed_9", "sfx_camp_razed_10", "sfx_camp_razed_11", "sfx_camp_razed_12"],
	"sfx_chest_open": ["sfx_chest_open_1", "sfx_chest_open_2", "sfx_chest_open_3"],
	"sfx_chieftain_roar": ["sfx_chieftain_roar_1", "sfx_chieftain_roar_2", "sfx_chieftain_roar_3", "sfx_chieftain_roar_4", "sfx_chieftain_roar_5", "sfx_chieftain_roar_6", "sfx_chieftain_roar_7", "sfx_chieftain_roar_8"],
	"sfx_companion_down": ["sfx_companion_down_1", "sfx_companion_down_2", "sfx_companion_down_3", "sfx_companion_down_4", "sfx_companion_down_5", "sfx_companion_down_6", "sfx_companion_down_7", "sfx_companion_down_8", "sfx_companion_down_9", "sfx_companion_down_10", "sfx_companion_down_11", "sfx_companion_down_12"],
	"sfx_companion_return": ["sfx_companion_return_1", "sfx_companion_return_2", "sfx_companion_return_3", "sfx_companion_return_4", "sfx_companion_return_5", "sfx_companion_return_6", "sfx_companion_return_7", "sfx_companion_return_8", "sfx_companion_return_9", "sfx_companion_return_10", "sfx_companion_return_11", "sfx_companion_return_12"],
	"sfx_companion_strike": ["sfx_companion_strike_1", "sfx_companion_strike_2", "sfx_companion_strike_3", "sfx_companion_strike_4", "sfx_companion_strike_5", "sfx_companion_strike_6", "sfx_companion_strike_7", "sfx_companion_strike_8", "sfx_companion_strike_9", "sfx_companion_strike_10", "sfx_companion_strike_11", "sfx_companion_strike_12"],
	"sfx_companion_summon": ["sfx_companion_summon_1", "sfx_companion_summon_2", "sfx_companion_summon_3", "sfx_companion_summon_4", "sfx_companion_summon_5", "sfx_companion_summon_6", "sfx_companion_summon_7", "sfx_companion_summon_8", "sfx_companion_summon_9", "sfx_companion_summon_10", "sfx_companion_summon_11", "sfx_companion_summon_12", "sfx_companion_summon_13", "sfx_companion_summon_14", "sfx_companion_summon_15", "sfx_companion_summon_16"],
	"sfx_drown": ["sfx_drown_1", "sfx_drown_2", "sfx_drown_3", "sfx_drown_4", "sfx_drown_5", "sfx_drown_6", "sfx_drown_7", "sfx_drown_8"],
	"sfx_dungeon_collapse": ["sfx_dungeon_collapse_1", "sfx_dungeon_collapse_2", "sfx_dungeon_collapse_3", "sfx_dungeon_collapse_4", "sfx_dungeon_collapse_5", "sfx_dungeon_collapse_6", "sfx_dungeon_collapse_7", "sfx_dungeon_collapse_8"],
	"sfx_dungeon_exit": ["sfx_dungeon_exit_1", "sfx_dungeon_exit_2", "sfx_dungeon_exit_3", "sfx_dungeon_exit_4", "sfx_dungeon_exit_5", "sfx_dungeon_exit_6", "sfx_dungeon_exit_7", "sfx_dungeon_exit_8", "sfx_dungeon_exit_9", "sfx_dungeon_exit_10", "sfx_dungeon_exit_11", "sfx_dungeon_exit_12", "sfx_dungeon_exit_13", "sfx_dungeon_exit_14", "sfx_dungeon_exit_15", "sfx_dungeon_exit_16", "sfx_dungeon_exit_17", "sfx_dungeon_exit_18", "sfx_dungeon_exit_19", "sfx_dungeon_exit_20"],
	"sfx_fish_bite": ["sfx_fish_bite_1", "sfx_fish_bite_2", "sfx_fish_bite_3", "sfx_fish_bite_4", "sfx_fish_bite_5", "sfx_fish_bite_6", "sfx_fish_bite_7", "sfx_fish_bite_8"],
	"sfx_fish_cast": ["sfx_fish_cast_1", "sfx_fish_cast_2", "sfx_fish_cast_3", "sfx_fish_cast_4", "sfx_fish_cast_5", "sfx_fish_cast_6", "sfx_fish_cast_7", "sfx_fish_cast_8", "sfx_fish_cast_9", "sfx_fish_cast_10", "sfx_fish_cast_11", "sfx_fish_cast_12"],
	"sfx_fish_cast_charge": ["sfx_fish_cast_charge_1", "sfx_fish_cast_charge_2", "sfx_fish_cast_charge_3", "sfx_fish_cast_charge_4", "sfx_fish_cast_charge_5", "sfx_fish_cast_charge_6", "sfx_fish_cast_charge_7", "sfx_fish_cast_charge_8", "sfx_fish_cast_charge_9", "sfx_fish_cast_charge_10", "sfx_fish_cast_charge_11", "sfx_fish_cast_charge_12"],
	"sfx_fish_escape": ["sfx_fish_escape_1", "sfx_fish_escape_2", "sfx_fish_escape_3", "sfx_fish_escape_4", "sfx_fish_escape_5", "sfx_fish_escape_6", "sfx_fish_escape_7", "sfx_fish_escape_8"],
	"sfx_fish_hook": ["sfx_fish_hook_1", "sfx_fish_hook_2", "sfx_fish_hook_3", "sfx_fish_hook_4", "sfx_fish_hook_5", "sfx_fish_hook_6", "sfx_fish_hook_7", "sfx_fish_hook_8"],
	"sfx_fish_land": ["sfx_fish_land_1", "sfx_fish_land_2", "sfx_fish_land_3", "sfx_fish_land_4", "sfx_fish_land_5", "sfx_fish_land_6", "sfx_fish_land_7", "sfx_fish_land_8"],
	"sfx_fish_nibble": ["sfx_fish_nibble_1", "sfx_fish_nibble_2", "sfx_fish_nibble_3", "sfx_fish_nibble_4", "sfx_fish_nibble_5", "sfx_fish_nibble_6", "sfx_fish_nibble_7", "sfx_fish_nibble_8"],
	"sfx_fish_reel": ["sfx_fish_reel_1", "sfx_fish_reel_2", "sfx_fish_reel_3", "sfx_fish_reel_4"],
	"sfx_fish_snap": ["sfx_fish_snap_1", "sfx_fish_snap_2", "sfx_fish_snap_3", "sfx_fish_snap_4"],
	"sfx_fish_splash": ["sfx_fish_splash_1", "sfx_fish_splash_2", "sfx_fish_splash_3", "sfx_fish_splash_4", "sfx_fish_splash_5", "sfx_fish_splash_6", "sfx_fish_splash_7", "sfx_fish_splash_8"],
	"sfx_fork_open": ["sfx_fork_open_1", "sfx_fork_open_2", "sfx_fork_open_3", "sfx_fork_open_4", "sfx_fork_open_5", "sfx_fork_open_6", "sfx_fork_open_7", "sfx_fork_open_8"],
	"sfx_meteor_impact": ["sfx_meteor_impact_1", "sfx_meteor_impact_2", "sfx_meteor_impact_3", "sfx_meteor_impact_4", "sfx_meteor_impact_5", "sfx_meteor_impact_6", "sfx_meteor_impact_7", "sfx_meteor_impact_8", "sfx_meteor_impact_9", "sfx_meteor_impact_10", "sfx_meteor_impact_11", "sfx_meteor_impact_12"],
	"sfx_meteor_whistle": ["sfx_meteor_whistle_1", "sfx_meteor_whistle_2", "sfx_meteor_whistle_3", "sfx_meteor_whistle_4", "sfx_meteor_whistle_5", "sfx_meteor_whistle_6", "sfx_meteor_whistle_7", "sfx_meteor_whistle_8"],
	"sfx_party_accept": ["sfx_party_accept_1", "sfx_party_accept_2", "sfx_party_accept_3", "sfx_party_accept_4", "sfx_party_accept_5", "sfx_party_accept_6"],
	"sfx_party_decline": ["sfx_party_decline_1", "sfx_party_decline_2", "sfx_party_decline_3", "sfx_party_decline_4", "sfx_party_decline_5", "sfx_party_decline_6"],
	"sfx_party_prompt": ["sfx_party_prompt_1", "sfx_party_prompt_2", "sfx_party_prompt_3", "sfx_party_prompt_4", "sfx_party_prompt_5", "sfx_party_prompt_6", "sfx_party_prompt_7", "sfx_party_prompt_8"],
	"sfx_profession_level": ["sfx_profession_level_1", "sfx_profession_level_2", "sfx_profession_level_3", "sfx_profession_level_4", "sfx_profession_level_5", "sfx_profession_level_6", "sfx_profession_level_7", "sfx_profession_level_8"],
	"sfx_quake": ["sfx_quake_1", "sfx_quake_2", "sfx_quake_3", "sfx_quake_4", "sfx_quake_5", "sfx_quake_6", "sfx_quake_7", "sfx_quake_8", "sfx_quake_9", "sfx_quake_10", "sfx_quake_11", "sfx_quake_12", "sfx_quake_13", "sfx_quake_14", "sfx_quake_15", "sfx_quake_16"],
	"sfx_raid_extract": ["sfx_raid_extract_1", "sfx_raid_extract_2", "sfx_raid_extract_3", "sfx_raid_extract_4", "sfx_raid_extract_5", "sfx_raid_extract_6", "sfx_raid_extract_7", "sfx_raid_extract_8", "sfx_raid_extract_9", "sfx_raid_extract_10", "sfx_raid_extract_11", "sfx_raid_extract_12"],
	"sfx_raid_window": ["sfx_raid_window_1", "sfx_raid_window_2", "sfx_raid_window_3", "sfx_raid_window_4", "sfx_raid_window_5", "sfx_raid_window_6", "sfx_raid_window_7", "sfx_raid_window_8"],
	"sfx_swim_enter": ["sfx_swim_enter_1", "sfx_swim_enter_2", "sfx_swim_enter_3", "sfx_swim_enter_4", "sfx_swim_enter_5", "sfx_swim_enter_6", "sfx_swim_enter_7", "sfx_swim_enter_8"],
	"sfx_swim_exit": ["sfx_swim_exit_1", "sfx_swim_exit_2", "sfx_swim_exit_3", "sfx_swim_exit_4", "sfx_swim_exit_5", "sfx_swim_exit_6", "sfx_swim_exit_7", "sfx_swim_exit_8"],
	"sfx_swim_stroke": ["sfx_swim_stroke_1", "sfx_swim_stroke_2", "sfx_swim_stroke_3", "sfx_swim_stroke_4", "sfx_swim_stroke_5", "sfx_swim_stroke_6", "sfx_swim_stroke_7", "sfx_swim_stroke_8"],
	"sfx_thunder_far": ["sfx_thunder_far_1", "sfx_thunder_far_2", "sfx_thunder_far_3", "sfx_thunder_far_4", "sfx_thunder_far_5", "sfx_thunder_far_6"],
	"sfx_thunder_near": ["sfx_thunder_near_1", "sfx_thunder_near_2", "sfx_thunder_near_3", "sfx_thunder_near_4", "sfx_thunder_near_5", "sfx_thunder_near_6", "sfx_thunder_near_7", "sfx_thunder_near_8", "sfx_thunder_near_9", "sfx_thunder_near_10", "sfx_thunder_near_11", "sfx_thunder_near_12", "sfx_thunder_near_13", "sfx_thunder_near_14", "sfx_thunder_near_15", "sfx_thunder_near_16", "sfx_thunder_near_17", "sfx_thunder_near_18", "sfx_thunder_near_19", "sfx_thunder_near_20", "sfx_thunder_near_21", "sfx_thunder_near_22", "sfx_thunder_near_23", "sfx_thunder_near_24", "sfx_thunder_near_25", "sfx_thunder_near_26", "sfx_thunder_near_27", "sfx_thunder_near_28", "sfx_thunder_near_29", "sfx_thunder_near_30", "sfx_thunder_near_31", "sfx_thunder_near_32"],
	"sfx_tornado": ["sfx_tornado_1", "sfx_tornado_2", "sfx_tornado_3", "sfx_tornado_4", "sfx_tornado_5", "sfx_tornado_6", "sfx_tornado_7", "sfx_tornado_8", "sfx_tornado_9", "sfx_tornado_10", "sfx_tornado_11", "sfx_tornado_12", "sfx_tornado_13", "sfx_tornado_14", "sfx_tornado_15", "sfx_tornado_16", "sfx_tornado_17", "sfx_tornado_18", "sfx_tornado_19", "sfx_tornado_20", "sfx_tornado_21", "sfx_tornado_22", "sfx_tornado_23", "sfx_tornado_24", "sfx_tornado_25", "sfx_tornado_26", "sfx_tornado_27", "sfx_tornado_28", "sfx_tornado_29", "sfx_tornado_30", "sfx_tornado_31", "sfx_tornado_32", "sfx_tornado_33", "sfx_tornado_34", "sfx_tornado_35", "sfx_tornado_36"],
	"sfx_water_bite": ["sfx_water_bite_1", "sfx_water_bite_2", "sfx_water_bite_3", "sfx_water_bite_4", "sfx_water_bite_5", "sfx_water_bite_6", "sfx_water_bite_7", "sfx_water_bite_8"],
	"sfx_well_drink": ["sfx_well_drink_1", "sfx_well_drink_2", "sfx_well_drink_3", "sfx_well_drink_4", "sfx_well_drink_5", "sfx_well_drink_6", "sfx_well_drink_7", "sfx_well_drink_8", "sfx_well_drink_9", "sfx_well_drink_10", "sfx_well_drink_11", "sfx_well_drink_12"],
	"sfx_wildfire": ["sfx_wildfire_1", "sfx_wildfire_2", "sfx_wildfire_3", "sfx_wildfire_4", "sfx_wildfire_5", "sfx_wildfire_6", "sfx_wildfire_7", "sfx_wildfire_8", "sfx_wildfire_9", "sfx_wildfire_10", "sfx_wildfire_11", "sfx_wildfire_12", "sfx_wildfire_13", "sfx_wildfire_14", "sfx_wildfire_15", "sfx_wildfire_16", "sfx_wildfire_17", "sfx_wildfire_18", "sfx_wildfire_19", "sfx_wildfire_20", "sfx_wildfire_21", "sfx_wildfire_22", "sfx_wildfire_23", "sfx_wildfire_24", "sfx_wildfire_25", "sfx_wildfire_26", "sfx_wildfire_27", "sfx_wildfire_28", "sfx_wildfire_29", "sfx_wildfire_30", "sfx_wildfire_31", "sfx_wildfire_32", "sfx_wildfire_33", "sfx_wildfire_34", "sfx_wildfire_35", "sfx_wildfire_36", "sfx_wildfire_37", "sfx_wildfire_38", "sfx_wildfire_39", "sfx_wildfire_40", "sfx_wildfire_41", "sfx_wildfire_42", "sfx_wildfire_43", "sfx_wildfire_44", "sfx_wildfire_45", "sfx_wildfire_46", "sfx_wildfire_47", "sfx_wildfire_48", "sfx_wildfire_49", "sfx_wildfire_50", "sfx_wildfire_51", "sfx_wildfire_52", "sfx_wildfire_53", "sfx_wildfire_54", "sfx_wildfire_55", "sfx_wildfire_56", "sfx_wildfire_57", "sfx_wildfire_58", "sfx_wildfire_59", "sfx_wildfire_60", "sfx_wildfire_61", "sfx_wildfire_62", "sfx_wildfire_63", "sfx_wildfire_64", "sfx_wildfire_65", "sfx_wildfire_66", "sfx_wildfire_67", "sfx_wildfire_68", "sfx_wildfire_69", "sfx_wildfire_70", "sfx_wildfire_71", "sfx_wildfire_72", "sfx_wildfire_73", "sfx_wildfire_74", "sfx_wildfire_75", "sfx_wildfire_76"],
	"sfx_enemy_call_beast": ["sfx_enemy_call_beast_1", "sfx_enemy_call_beast_2", "sfx_enemy_call_beast_3", "sfx_enemy_call_beast_4", "sfx_enemy_call_beast_5", "sfx_enemy_call_beast_6", "sfx_enemy_call_beast_7", "sfx_enemy_call_beast_8", "sfx_enemy_call_beast_9", "sfx_enemy_call_beast_10", "sfx_enemy_call_beast_11", "sfx_enemy_call_beast_12", "sfx_enemy_call_beast_13", "sfx_enemy_call_beast_14", "sfx_enemy_call_beast_15", "sfx_enemy_call_beast_16", "sfx_enemy_call_beast_17", "sfx_enemy_call_beast_18", "sfx_enemy_call_beast_19", "sfx_enemy_call_beast_20", "sfx_enemy_call_beast_21", "sfx_enemy_call_beast_22", "sfx_enemy_call_beast_23", "sfx_enemy_call_beast_24", "sfx_enemy_call_beast_25", "sfx_enemy_call_beast_26", "sfx_enemy_call_beast_27", "sfx_enemy_call_beast_28", "sfx_enemy_call_beast_29", "sfx_enemy_call_beast_30", "sfx_enemy_call_beast_31", "sfx_enemy_call_beast_32", "sfx_enemy_call_beast_33", "sfx_enemy_call_beast_34", "sfx_enemy_call_beast_35", "sfx_enemy_call_beast_36"],
	"sfx_enemy_call_horde": ["sfx_enemy_call_horde_1", "sfx_enemy_call_horde_2", "sfx_enemy_call_horde_3", "sfx_enemy_call_horde_4", "sfx_enemy_call_horde_5", "sfx_enemy_call_horde_6", "sfx_enemy_call_horde_7", "sfx_enemy_call_horde_8", "sfx_enemy_call_horde_9", "sfx_enemy_call_horde_10", "sfx_enemy_call_horde_11", "sfx_enemy_call_horde_12", "sfx_enemy_call_horde_13", "sfx_enemy_call_horde_14", "sfx_enemy_call_horde_15", "sfx_enemy_call_horde_16", "sfx_enemy_call_horde_17", "sfx_enemy_call_horde_18", "sfx_enemy_call_horde_19", "sfx_enemy_call_horde_20", "sfx_enemy_call_horde_21", "sfx_enemy_call_horde_22", "sfx_enemy_call_horde_23", "sfx_enemy_call_horde_24", "sfx_enemy_call_horde_25", "sfx_enemy_call_horde_26", "sfx_enemy_call_horde_27", "sfx_enemy_call_horde_28", "sfx_enemy_call_horde_29", "sfx_enemy_call_horde_30", "sfx_enemy_call_horde_31", "sfx_enemy_call_horde_32"],
	"sfx_enemy_call_horn": ["sfx_enemy_call_horn_1", "sfx_enemy_call_horn_2", "sfx_enemy_call_horn_3", "sfx_enemy_call_horn_4"],
	"sfx_enemy_call_siege": ["sfx_enemy_call_siege_1", "sfx_enemy_call_siege_2", "sfx_enemy_call_siege_3", "sfx_enemy_call_siege_4"],
	"sfx_enemy_call_swarm": ["sfx_enemy_call_swarm_1", "sfx_enemy_call_swarm_2", "sfx_enemy_call_swarm_3", "sfx_enemy_call_swarm_4"],
	"sfx_enemy_call_wraith": ["sfx_enemy_call_wraith_1", "sfx_enemy_call_wraith_2", "sfx_enemy_call_wraith_3", "sfx_enemy_call_wraith_4", "sfx_enemy_call_wraith_5", "sfx_enemy_call_wraith_6", "sfx_enemy_call_wraith_7", "sfx_enemy_call_wraith_8", "sfx_enemy_call_wraith_9", "sfx_enemy_call_wraith_10", "sfx_enemy_call_wraith_11", "sfx_enemy_call_wraith_12", "sfx_enemy_call_wraith_13", "sfx_enemy_call_wraith_14", "sfx_enemy_call_wraith_15", "sfx_enemy_call_wraith_16", "sfx_enemy_call_wraith_17", "sfx_enemy_call_wraith_18", "sfx_enemy_call_wraith_19", "sfx_enemy_call_wraith_20", "sfx_enemy_call_wraith_21", "sfx_enemy_call_wraith_22", "sfx_enemy_call_wraith_23", "sfx_enemy_call_wraith_24", "sfx_enemy_call_wraith_25", "sfx_enemy_call_wraith_26", "sfx_enemy_call_wraith_27", "sfx_enemy_call_wraith_28", "sfx_enemy_call_wraith_29", "sfx_enemy_call_wraith_30", "sfx_enemy_call_wraith_31", "sfx_enemy_call_wraith_32", "sfx_enemy_call_wraith_33", "sfx_enemy_call_wraith_34", "sfx_enemy_call_wraith_35", "sfx_enemy_call_wraith_36", "sfx_enemy_call_wraith_37", "sfx_enemy_call_wraith_38", "sfx_enemy_call_wraith_39", "sfx_enemy_call_wraith_40", "sfx_enemy_call_wraith_41", "sfx_enemy_call_wraith_42", "sfx_enemy_call_wraith_43", "sfx_enemy_call_wraith_44", "sfx_enemy_call_wraith_45", "sfx_enemy_call_wraith_46", "sfx_enemy_call_wraith_47", "sfx_enemy_call_wraith_48", "sfx_enemy_call_wraith_49", "sfx_enemy_call_wraith_50", "sfx_enemy_call_wraith_51", "sfx_enemy_call_wraith_52"],
	"sfx_pen_graze": ["sfx_pen_graze_1", "sfx_pen_graze_2", "sfx_pen_graze_3", "sfx_pen_graze_4"],
	"sfx_pen_settle": ["sfx_pen_settle_1", "sfx_pen_settle_2", "sfx_pen_settle_3", "sfx_pen_settle_4"],
	"sfx_wildlife_ash_hound": ["sfx_wildlife_ash_hound_1", "sfx_wildlife_ash_hound_2", "sfx_wildlife_ash_hound_3", "sfx_wildlife_ash_hound_4"],
	"sfx_wildlife_barkfang_wolverine": ["sfx_wildlife_barkfang_wolverine_1", "sfx_wildlife_barkfang_wolverine_2", "sfx_wildlife_barkfang_wolverine_3", "sfx_wildlife_barkfang_wolverine_4", "sfx_wildlife_barkfang_wolverine_5", "sfx_wildlife_barkfang_wolverine_6", "sfx_wildlife_barkfang_wolverine_7", "sfx_wildlife_barkfang_wolverine_8", "sfx_wildlife_barkfang_wolverine_9", "sfx_wildlife_barkfang_wolverine_10", "sfx_wildlife_barkfang_wolverine_11", "sfx_wildlife_barkfang_wolverine_12"],
	"sfx_wildlife_barkjack_woodpecker": ["sfx_wildlife_barkjack_woodpecker_1", "sfx_wildlife_barkjack_woodpecker_2", "sfx_wildlife_barkjack_woodpecker_3", "sfx_wildlife_barkjack_woodpecker_4", "sfx_wildlife_barkjack_woodpecker_5", "sfx_wildlife_barkjack_woodpecker_6", "sfx_wildlife_barkjack_woodpecker_7"],
	"sfx_wildlife_blight_collapse": ["sfx_wildlife_blight_collapse_1", "sfx_wildlife_blight_collapse_2", "sfx_wildlife_blight_collapse_3", "sfx_wildlife_blight_collapse_4", "sfx_wildlife_blight_collapse_5", "sfx_wildlife_blight_collapse_6", "sfx_wildlife_blight_collapse_7", "sfx_wildlife_blight_collapse_8"],
	"sfx_wildlife_blight_frenzy": ["sfx_wildlife_blight_frenzy_1", "sfx_wildlife_blight_frenzy_2", "sfx_wildlife_blight_frenzy_3", "sfx_wildlife_blight_frenzy_4", "sfx_wildlife_blight_frenzy_5", "sfx_wildlife_blight_frenzy_6", "sfx_wildlife_blight_frenzy_7", "sfx_wildlife_blight_frenzy_8"],
	"sfx_wildlife_blight_warning": ["sfx_wildlife_blight_warning_1", "sfx_wildlife_blight_warning_2", "sfx_wildlife_blight_warning_3", "sfx_wildlife_blight_warning_4", "sfx_wildlife_blight_warning_5", "sfx_wildlife_blight_warning_6", "sfx_wildlife_blight_warning_7", "sfx_wildlife_blight_warning_8", "sfx_wildlife_blight_warning_9", "sfx_wildlife_blight_warning_10", "sfx_wildlife_blight_warning_11", "sfx_wildlife_blight_warning_12"],
	"sfx_wildlife_bog_crane": ["sfx_wildlife_bog_crane_1", "sfx_wildlife_bog_crane_2", "sfx_wildlife_bog_crane_3", "sfx_wildlife_bog_crane_4", "sfx_wildlife_bog_crane_5", "sfx_wildlife_bog_crane_6", "sfx_wildlife_bog_crane_7", "sfx_wildlife_bog_crane_8", "sfx_wildlife_bog_crane_9", "sfx_wildlife_bog_crane_10", "sfx_wildlife_bog_crane_11", "sfx_wildlife_bog_crane_12"],
	"sfx_wildlife_bond": ["sfx_wildlife_bond_1", "sfx_wildlife_bond_2", "sfx_wildlife_bond_3", "sfx_wildlife_bond_4"],
	"sfx_wildlife_cliff_goat": ["sfx_wildlife_cliff_goat_1", "sfx_wildlife_cliff_goat_2", "sfx_wildlife_cliff_goat_3", "sfx_wildlife_cliff_goat_4", "sfx_wildlife_cliff_goat_5", "sfx_wildlife_cliff_goat_6", "sfx_wildlife_cliff_goat_7", "sfx_wildlife_cliff_goat_8", "sfx_wildlife_cliff_goat_9", "sfx_wildlife_cliff_goat_10", "sfx_wildlife_cliff_goat_11", "sfx_wildlife_cliff_goat_12"],
	"sfx_wildlife_copper_pheasant": ["sfx_wildlife_copper_pheasant_1", "sfx_wildlife_copper_pheasant_2", "sfx_wildlife_copper_pheasant_3", "sfx_wildlife_copper_pheasant_4"],
	"sfx_wildlife_death_amphibian": ["sfx_wildlife_death_amphibian_1", "sfx_wildlife_death_amphibian_2", "sfx_wildlife_death_amphibian_3", "sfx_wildlife_death_amphibian_4", "sfx_wildlife_death_amphibian_5", "sfx_wildlife_death_amphibian_6", "sfx_wildlife_death_amphibian_7", "sfx_wildlife_death_amphibian_8"],
	"sfx_wildlife_death_bird": ["sfx_wildlife_death_bird_1", "sfx_wildlife_death_bird_2", "sfx_wildlife_death_bird_3", "sfx_wildlife_death_bird_4", "sfx_wildlife_death_bird_5", "sfx_wildlife_death_bird_6", "sfx_wildlife_death_bird_7", "sfx_wildlife_death_bird_8", "sfx_wildlife_death_bird_9", "sfx_wildlife_death_bird_10", "sfx_wildlife_death_bird_11", "sfx_wildlife_death_bird_12"],
	"sfx_wildlife_death_chitin": ["sfx_wildlife_death_chitin_1", "sfx_wildlife_death_chitin_2", "sfx_wildlife_death_chitin_3", "sfx_wildlife_death_chitin_4", "sfx_wildlife_death_chitin_5", "sfx_wildlife_death_chitin_6", "sfx_wildlife_death_chitin_7", "sfx_wildlife_death_chitin_8"],
	"sfx_wildlife_death_large_beast": ["sfx_wildlife_death_large_beast_1", "sfx_wildlife_death_large_beast_2", "sfx_wildlife_death_large_beast_3", "sfx_wildlife_death_large_beast_4", "sfx_wildlife_death_large_beast_5", "sfx_wildlife_death_large_beast_6", "sfx_wildlife_death_large_beast_7", "sfx_wildlife_death_large_beast_8", "sfx_wildlife_death_large_beast_9", "sfx_wildlife_death_large_beast_10", "sfx_wildlife_death_large_beast_11", "sfx_wildlife_death_large_beast_12", "sfx_wildlife_death_large_beast_13", "sfx_wildlife_death_large_beast_14", "sfx_wildlife_death_large_beast_15", "sfx_wildlife_death_large_beast_16"],
	"sfx_wildlife_death_reptile": ["sfx_wildlife_death_reptile_1", "sfx_wildlife_death_reptile_2", "sfx_wildlife_death_reptile_3", "sfx_wildlife_death_reptile_4", "sfx_wildlife_death_reptile_5", "sfx_wildlife_death_reptile_6", "sfx_wildlife_death_reptile_7", "sfx_wildlife_death_reptile_8"],
	"sfx_wildlife_death_shell": ["sfx_wildlife_death_shell_1", "sfx_wildlife_death_shell_2", "sfx_wildlife_death_shell_3", "sfx_wildlife_death_shell_4", "sfx_wildlife_death_shell_5", "sfx_wildlife_death_shell_6", "sfx_wildlife_death_shell_7", "sfx_wildlife_death_shell_8"],
	"sfx_wildlife_death_small_beast": ["sfx_wildlife_death_small_beast_1", "sfx_wildlife_death_small_beast_2", "sfx_wildlife_death_small_beast_3", "sfx_wildlife_death_small_beast_4", "sfx_wildlife_death_small_beast_5", "sfx_wildlife_death_small_beast_6", "sfx_wildlife_death_small_beast_7", "sfx_wildlife_death_small_beast_8", "sfx_wildlife_death_small_beast_9", "sfx_wildlife_death_small_beast_10", "sfx_wildlife_death_small_beast_11", "sfx_wildlife_death_small_beast_12"],
	"sfx_wildlife_dune_fennec": ["sfx_wildlife_dune_fennec_1", "sfx_wildlife_dune_fennec_2", "sfx_wildlife_dune_fennec_3", "sfx_wildlife_dune_fennec_4"],
	"sfx_wildlife_egg_hatch": ["sfx_wildlife_egg_hatch_1", "sfx_wildlife_egg_hatch_2", "sfx_wildlife_egg_hatch_3", "sfx_wildlife_egg_hatch_4", "sfx_wildlife_egg_hatch_5", "sfx_wildlife_egg_hatch_6", "sfx_wildlife_egg_hatch_7", "sfx_wildlife_egg_hatch_8"],
	"sfx_wildlife_egg_take": ["sfx_wildlife_egg_take_1", "sfx_wildlife_egg_take_2", "sfx_wildlife_egg_take_3", "sfx_wildlife_egg_take_4"],
	"sfx_wildlife_fall_heavy": ["sfx_wildlife_fall_heavy_1", "sfx_wildlife_fall_heavy_2", "sfx_wildlife_fall_heavy_3", "sfx_wildlife_fall_heavy_4", "sfx_wildlife_fall_heavy_5", "sfx_wildlife_fall_heavy_6", "sfx_wildlife_fall_heavy_7", "sfx_wildlife_fall_heavy_8", "sfx_wildlife_fall_heavy_9", "sfx_wildlife_fall_heavy_10"],
	"sfx_wildlife_fall_light": ["sfx_wildlife_fall_light_1", "sfx_wildlife_fall_light_2", "sfx_wildlife_fall_light_3", "sfx_wildlife_fall_light_4", "sfx_wildlife_fall_light_5", "sfx_wildlife_fall_light_6", "sfx_wildlife_fall_light_7", "sfx_wildlife_fall_light_8", "sfx_wildlife_fall_light_9"],
	"sfx_wildlife_frost_elk": ["sfx_wildlife_frost_elk_1", "sfx_wildlife_frost_elk_2", "sfx_wildlife_frost_elk_3", "sfx_wildlife_frost_elk_4", "sfx_wildlife_frost_elk_5", "sfx_wildlife_frost_elk_6", "sfx_wildlife_frost_elk_7", "sfx_wildlife_frost_elk_8"],
	"sfx_wildlife_glass_lizard": ["sfx_wildlife_glass_lizard_1", "sfx_wildlife_glass_lizard_2", "sfx_wildlife_glass_lizard_3", "sfx_wildlife_glass_lizard_4"],
	"sfx_wildlife_glimmerfox": ["sfx_wildlife_glimmerfox_1", "sfx_wildlife_glimmerfox_2", "sfx_wildlife_glimmerfox_3"],
	"sfx_wildlife_griffon": ["sfx_wildlife_griffon_1", "sfx_wildlife_griffon_2", "sfx_wildlife_griffon_3", "sfx_wildlife_griffon_4", "sfx_wildlife_griffon_5", "sfx_wildlife_griffon_6", "sfx_wildlife_griffon_7", "sfx_wildlife_griffon_8"],
	"sfx_wildlife_hedgehog": ["sfx_wildlife_hedgehog_1", "sfx_wildlife_hedgehog_2", "sfx_wildlife_hedgehog_3", "sfx_wildlife_hedgehog_4", "sfx_wildlife_hedgehog_5", "sfx_wildlife_hedgehog_6", "sfx_wildlife_hedgehog_7", "sfx_wildlife_hedgehog_8", "sfx_wildlife_hedgehog_9", "sfx_wildlife_hedgehog_10", "sfx_wildlife_hedgehog_11", "sfx_wildlife_hedgehog_12"],
	"sfx_wildlife_heron": ["sfx_wildlife_heron_1", "sfx_wildlife_heron_2", "sfx_wildlife_heron_3", "sfx_wildlife_heron_4", "sfx_wildlife_heron_5", "sfx_wildlife_heron_6", "sfx_wildlife_heron_7", "sfx_wildlife_heron_8", "sfx_wildlife_heron_9", "sfx_wildlife_heron_10", "sfx_wildlife_heron_11", "sfx_wildlife_heron_12"],
	"sfx_wildlife_hit_chitin": ["sfx_wildlife_hit_chitin_1", "sfx_wildlife_hit_chitin_2", "sfx_wildlife_hit_chitin_3", "sfx_wildlife_hit_chitin_4", "sfx_wildlife_hit_chitin_5", "sfx_wildlife_hit_chitin_6", "sfx_wildlife_hit_chitin_7", "sfx_wildlife_hit_chitin_8"],
	"sfx_wildlife_hit_feather": ["sfx_wildlife_hit_feather_1", "sfx_wildlife_hit_feather_2", "sfx_wildlife_hit_feather_3", "sfx_wildlife_hit_feather_4", "sfx_wildlife_hit_feather_5", "sfx_wildlife_hit_feather_6", "sfx_wildlife_hit_feather_7", "sfx_wildlife_hit_feather_8", "sfx_wildlife_hit_feather_9", "sfx_wildlife_hit_feather_10", "sfx_wildlife_hit_feather_11", "sfx_wildlife_hit_feather_12"],
	"sfx_wildlife_hit_fur": ["sfx_wildlife_hit_fur_1", "sfx_wildlife_hit_fur_2", "sfx_wildlife_hit_fur_3", "sfx_wildlife_hit_fur_4", "sfx_wildlife_hit_fur_5", "sfx_wildlife_hit_fur_6", "sfx_wildlife_hit_fur_7", "sfx_wildlife_hit_fur_8", "sfx_wildlife_hit_fur_9", "sfx_wildlife_hit_fur_10", "sfx_wildlife_hit_fur_11", "sfx_wildlife_hit_fur_12"],
	"sfx_wildlife_hit_scale": ["sfx_wildlife_hit_scale_1", "sfx_wildlife_hit_scale_2", "sfx_wildlife_hit_scale_3", "sfx_wildlife_hit_scale_4", "sfx_wildlife_hit_scale_5", "sfx_wildlife_hit_scale_6", "sfx_wildlife_hit_scale_7", "sfx_wildlife_hit_scale_8", "sfx_wildlife_hit_scale_9", "sfx_wildlife_hit_scale_10", "sfx_wildlife_hit_scale_11", "sfx_wildlife_hit_scale_12"],
	"sfx_wildlife_hit_shell": ["sfx_wildlife_hit_shell_1", "sfx_wildlife_hit_shell_2", "sfx_wildlife_hit_shell_3", "sfx_wildlife_hit_shell_4", "sfx_wildlife_hit_shell_5", "sfx_wildlife_hit_shell_6"],
	"sfx_wildlife_hollowhorn": ["sfx_wildlife_hollowhorn_1", "sfx_wildlife_hollowhorn_2", "sfx_wildlife_hollowhorn_3", "sfx_wildlife_hollowhorn_4", "sfx_wildlife_hollowhorn_5", "sfx_wildlife_hollowhorn_6", "sfx_wildlife_hollowhorn_7", "sfx_wildlife_hollowhorn_8"],
	"sfx_wildlife_hurt_amphibian": ["sfx_wildlife_hurt_amphibian_1", "sfx_wildlife_hurt_amphibian_2", "sfx_wildlife_hurt_amphibian_3", "sfx_wildlife_hurt_amphibian_4", "sfx_wildlife_hurt_amphibian_5", "sfx_wildlife_hurt_amphibian_6", "sfx_wildlife_hurt_amphibian_7", "sfx_wildlife_hurt_amphibian_8", "sfx_wildlife_hurt_amphibian_9", "sfx_wildlife_hurt_amphibian_10", "sfx_wildlife_hurt_amphibian_11", "sfx_wildlife_hurt_amphibian_12"],
	"sfx_wildlife_hurt_bird": ["sfx_wildlife_hurt_bird_1", "sfx_wildlife_hurt_bird_2", "sfx_wildlife_hurt_bird_3", "sfx_wildlife_hurt_bird_4", "sfx_wildlife_hurt_bird_5", "sfx_wildlife_hurt_bird_6", "sfx_wildlife_hurt_bird_7", "sfx_wildlife_hurt_bird_8", "sfx_wildlife_hurt_bird_9", "sfx_wildlife_hurt_bird_10", "sfx_wildlife_hurt_bird_11", "sfx_wildlife_hurt_bird_12"],
	"sfx_wildlife_hurt_reptile": ["sfx_wildlife_hurt_reptile_1", "sfx_wildlife_hurt_reptile_2", "sfx_wildlife_hurt_reptile_3", "sfx_wildlife_hurt_reptile_4", "sfx_wildlife_hurt_reptile_5", "sfx_wildlife_hurt_reptile_6", "sfx_wildlife_hurt_reptile_7", "sfx_wildlife_hurt_reptile_8", "sfx_wildlife_hurt_reptile_9", "sfx_wildlife_hurt_reptile_10", "sfx_wildlife_hurt_reptile_11", "sfx_wildlife_hurt_reptile_12"],
	"sfx_wildlife_hurt_small_beast": ["sfx_wildlife_hurt_small_beast_1", "sfx_wildlife_hurt_small_beast_2", "sfx_wildlife_hurt_small_beast_3", "sfx_wildlife_hurt_small_beast_4", "sfx_wildlife_hurt_small_beast_5", "sfx_wildlife_hurt_small_beast_6", "sfx_wildlife_hurt_small_beast_7", "sfx_wildlife_hurt_small_beast_8", "sfx_wildlife_hurt_small_beast_9", "sfx_wildlife_hurt_small_beast_10", "sfx_wildlife_hurt_small_beast_11", "sfx_wildlife_hurt_small_beast_12", "sfx_wildlife_hurt_small_beast_13", "sfx_wildlife_hurt_small_beast_14", "sfx_wildlife_hurt_small_beast_15", "sfx_wildlife_hurt_small_beast_16"],
	"sfx_wildlife_jackal": ["sfx_wildlife_jackal_1", "sfx_wildlife_jackal_2", "sfx_wildlife_jackal_3", "sfx_wildlife_jackal_4", "sfx_wildlife_jackal_5", "sfx_wildlife_jackal_6", "sfx_wildlife_jackal_7", "sfx_wildlife_jackal_8"],
	"sfx_wildlife_lynx": ["sfx_wildlife_lynx_1", "sfx_wildlife_lynx_2", "sfx_wildlife_lynx_3", "sfx_wildlife_lynx_4"],
	"sfx_wildlife_marsh_otter": ["sfx_wildlife_marsh_otter_1", "sfx_wildlife_marsh_otter_2", "sfx_wildlife_marsh_otter_3", "sfx_wildlife_marsh_otter_4", "sfx_wildlife_marsh_otter_5", "sfx_wildlife_marsh_otter_6", "sfx_wildlife_marsh_otter_7", "sfx_wildlife_marsh_otter_8"],
	"sfx_wildlife_mireback_alligator": ["sfx_wildlife_mireback_alligator_1", "sfx_wildlife_mireback_alligator_2", "sfx_wildlife_mireback_alligator_3", "sfx_wildlife_mireback_alligator_4", "sfx_wildlife_mireback_alligator_5", "sfx_wildlife_mireback_alligator_6", "sfx_wildlife_mireback_alligator_7", "sfx_wildlife_mireback_alligator_8", "sfx_wildlife_mireback_alligator_9", "sfx_wildlife_mireback_alligator_10", "sfx_wildlife_mireback_alligator_11", "sfx_wildlife_mireback_alligator_12", "sfx_wildlife_mireback_alligator_13"],
	"sfx_wildlife_moonstag": ["sfx_wildlife_moonstag_1", "sfx_wildlife_moonstag_2", "sfx_wildlife_moonstag_3", "sfx_wildlife_moonstag_4"],
	"sfx_wildlife_nest_lay": ["sfx_wildlife_nest_lay_1", "sfx_wildlife_nest_lay_2", "sfx_wildlife_nest_lay_3", "sfx_wildlife_nest_lay_4", "sfx_wildlife_nest_lay_5", "sfx_wildlife_nest_lay_6", "sfx_wildlife_nest_lay_7", "sfx_wildlife_nest_lay_8"],
	"sfx_wildlife_oreback_pangolin": ["sfx_wildlife_oreback_pangolin_1", "sfx_wildlife_oreback_pangolin_2", "sfx_wildlife_oreback_pangolin_3", "sfx_wildlife_oreback_pangolin_4"],
	"sfx_wildlife_phoenix": ["sfx_wildlife_phoenix_1", "sfx_wildlife_phoenix_2", "sfx_wildlife_phoenix_3", "sfx_wildlife_phoenix_4", "sfx_wildlife_phoenix_5", "sfx_wildlife_phoenix_6", "sfx_wildlife_phoenix_7", "sfx_wildlife_phoenix_8", "sfx_wildlife_phoenix_9", "sfx_wildlife_phoenix_10", "sfx_wildlife_phoenix_11", "sfx_wildlife_phoenix_12"],
	"sfx_wildlife_ptarmigan": ["sfx_wildlife_ptarmigan_1", "sfx_wildlife_ptarmigan_2", "sfx_wildlife_ptarmigan_3", "sfx_wildlife_ptarmigan_4", "sfx_wildlife_ptarmigan_5", "sfx_wildlife_ptarmigan_6", "sfx_wildlife_ptarmigan_7", "sfx_wildlife_ptarmigan_8", "sfx_wildlife_ptarmigan_9", "sfx_wildlife_ptarmigan_10", "sfx_wildlife_ptarmigan_11", "sfx_wildlife_ptarmigan_12"],
	"sfx_wildlife_rift_out": ["sfx_wildlife_rift_out_1", "sfx_wildlife_rift_out_2", "sfx_wildlife_rift_out_3", "sfx_wildlife_rift_out_4"],
	"sfx_wildlife_saltpan_monitor": ["sfx_wildlife_saltpan_monitor_1", "sfx_wildlife_saltpan_monitor_2", "sfx_wildlife_saltpan_monitor_3"],
	"sfx_wildlife_savage_arrival": ["sfx_wildlife_savage_arrival_1", "sfx_wildlife_savage_arrival_2", "sfx_wildlife_savage_arrival_3", "sfx_wildlife_savage_arrival_4", "sfx_wildlife_savage_arrival_5", "sfx_wildlife_savage_arrival_6", "sfx_wildlife_savage_arrival_7", "sfx_wildlife_savage_arrival_8"],
	"sfx_wildlife_screestalker": ["sfx_wildlife_screestalker_1", "sfx_wildlife_screestalker_2", "sfx_wildlife_screestalker_3"],
	"sfx_wildlife_snow_hare": ["sfx_wildlife_snow_hare_1", "sfx_wildlife_snow_hare_2", "sfx_wildlife_snow_hare_3", "sfx_wildlife_snow_hare_4", "sfx_wildlife_snow_hare_5", "sfx_wildlife_snow_hare_6", "sfx_wildlife_snow_hare_7", "sfx_wildlife_snow_hare_8"],
	"sfx_wildlife_snow_lynx": ["sfx_wildlife_snow_lynx_1", "sfx_wildlife_snow_lynx_2", "sfx_wildlife_snow_lynx_3", "sfx_wildlife_snow_lynx_4", "sfx_wildlife_snow_lynx_5", "sfx_wildlife_snow_lynx_6", "sfx_wildlife_snow_lynx_7", "sfx_wildlife_snow_lynx_8"],
	"sfx_wildlife_stag": ["sfx_wildlife_stag_1", "sfx_wildlife_stag_2", "sfx_wildlife_stag_3", "sfx_wildlife_stag_4", "sfx_wildlife_stag_5", "sfx_wildlife_stag_6", "sfx_wildlife_stag_7", "sfx_wildlife_stag_8"],
	"sfx_wildlife_steppe_horse": ["sfx_wildlife_steppe_horse_1", "sfx_wildlife_steppe_horse_2", "sfx_wildlife_steppe_horse_3", "sfx_wildlife_steppe_horse_4", "sfx_wildlife_steppe_horse_5", "sfx_wildlife_steppe_horse_6", "sfx_wildlife_steppe_horse_7", "sfx_wildlife_steppe_horse_8"],
	"sfx_wildlife_steppe_marmot": ["sfx_wildlife_steppe_marmot_1", "sfx_wildlife_steppe_marmot_2", "sfx_wildlife_steppe_marmot_3", "sfx_wildlife_steppe_marmot_4", "sfx_wildlife_steppe_marmot_5", "sfx_wildlife_steppe_marmot_6", "sfx_wildlife_steppe_marmot_7", "sfx_wildlife_steppe_marmot_8", "sfx_wildlife_steppe_marmot_9"],
	"sfx_wildlife_trail_sign": ["sfx_wildlife_trail_sign_1", "sfx_wildlife_trail_sign_2", "sfx_wildlife_trail_sign_3", "sfx_wildlife_trail_sign_4"],
	"sfx_wildlife_wing_large": ["sfx_wildlife_wing_large_1", "sfx_wildlife_wing_large_2", "sfx_wildlife_wing_large_3", "sfx_wildlife_wing_large_4", "sfx_wildlife_wing_large_5", "sfx_wildlife_wing_large_6", "sfx_wildlife_wing_large_7", "sfx_wildlife_wing_large_8"],
	"sfx_wildlife_wing_small": ["sfx_wildlife_wing_small_1", "sfx_wildlife_wing_small_2", "sfx_wildlife_wing_small_3", "sfx_wildlife_wing_small_4", "sfx_wildlife_wing_small_5", "sfx_wildlife_wing_small_6", "sfx_wildlife_wing_small_7", "sfx_wildlife_wing_small_8"],
	"sfx_fish_miss": ["sfx_fish_miss_1", "sfx_fish_miss_2", "sfx_fish_miss_3", "sfx_fish_miss_4", "sfx_fish_miss_5", "sfx_fish_miss_6", "sfx_fish_miss_7", "sfx_fish_miss_8"],
	"sfx_wildlife_hurt_large_beast": ["sfx_wildlife_hurt_large_beast_1", "sfx_wildlife_hurt_large_beast_2", "sfx_wildlife_hurt_large_beast_3", "sfx_wildlife_hurt_large_beast_4", "sfx_wildlife_hurt_large_beast_5", "sfx_wildlife_hurt_large_beast_6", "sfx_wildlife_hurt_large_beast_7", "sfx_wildlife_hurt_large_beast_8", "sfx_wildlife_hurt_large_beast_9", "sfx_wildlife_hurt_large_beast_10", "sfx_wildlife_hurt_large_beast_11", "sfx_wildlife_hurt_large_beast_12", "sfx_wildlife_hurt_large_beast_13", "sfx_wildlife_hurt_large_beast_14", "sfx_wildlife_hurt_large_beast_15"],
	"sfx_ui_click": ["sfx_ui_click_1", "sfx_ui_click_2", "sfx_ui_click_3"],
	"sfx_ui_hover": ["sfx_ui_hover_1", "sfx_ui_hover_2", "sfx_ui_hover_3", "sfx_ui_hover_4", "sfx_ui_hover_5"],
	"sfx_ui_move": ["sfx_ui_move_1", "sfx_ui_move_2", "sfx_ui_move_3"],
	"sfx_water_shot": ["sfx_water_shot_1", "sfx_water_shot_2", "sfx_water_shot_3"],
	"sfx_wildlife_badger": ["sfx_wildlife_badger_1", "sfx_wildlife_badger_2", "sfx_wildlife_badger_3", "sfx_wildlife_badger_4"],
	"sfx_wildlife_bear": ["sfx_wildlife_bear_1", "sfx_wildlife_bear_2", "sfx_wildlife_bear_3", "sfx_wildlife_bear_4", "sfx_wildlife_bear_5", "sfx_wildlife_bear_6", "sfx_wildlife_bear_7", "sfx_wildlife_bear_8"],
	"sfx_wildlife_boar": ["sfx_wildlife_boar_1", "sfx_wildlife_boar_2", "sfx_wildlife_boar_3", "sfx_wildlife_boar_4"],
	"sfx_wildlife_deer": ["sfx_wildlife_deer_1", "sfx_wildlife_deer_2", "sfx_wildlife_deer_3", "sfx_wildlife_deer_4"],
	"sfx_wildlife_fox": ["sfx_wildlife_fox_1", "sfx_wildlife_fox_2", "sfx_wildlife_fox_3", "sfx_wildlife_fox_4"],
	"sfx_wildlife_frog": ["sfx_wildlife_frog_1", "sfx_wildlife_frog_2", "sfx_wildlife_frog_3", "sfx_wildlife_frog_4"],
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
func play_at(id: String, at: Vector2, extra_db: float = 0.0,
		pitch_shift: float = 0.0) -> void:
	if not _listening:
		play(id, extra_db, pitch_shift)
		return
	var away: float = _ear.distance_to(at)
	if away > Balance.SFX_CUTOFF:
		return
	play(id, extra_db + distance_db(away), pitch_shift)


## How much quieter a sound is at this distance. Flat inside `SFX_NEAR`, falling
## to `SFX_FAR_DB` by `SFX_FAR`, and no further - a floor rather than a curve
## running off to silence, because a distant tower should still be *there*.
## One of a group's takes, placed. The same `play_at` rules.
## **Which sounds are positional, and which are deliberately not.**
##
## The rule is one question: *can this happen somewhere the player is not?*
##
## **Positional** - a body, an animal, a companion, a tower, a torch, a camp
## being razed, a rock landing, a death stone, a chest in a vault. In co-op each
## machine calls `listen_from` with **its own camera** every frame, so two
## players hear the same event at the distance each of them is standing from it.
##
## **Deliberately flat**, and each for a reason rather than an oversight:
##
## - **The interface.** A click, a purse, a confirm. It happens at the player.
## - **Anything the player is standing in.** Fishing is the clearest case - the
##   hero is *at* the pond - and so are their own swing, their own draught and
##   their own upgrade press.
## - **A telegraph.** `EnemyGroundStrike._tell` warns about a blow that is about
##   to land, and `JuiceDirector.Priority.TELEGRAPH` exists to say a warning is
##   never turned down. Quietening one by distance would contradict that in the
##   one place it matters most.
## - **The wall being hit**, at +4 dB. It is the loss condition, and a player out
##   at a far camp is exactly who needs to hear it.
## - **An announcement**: a boss arriving, a fork opening, distant thunder. These
##   come with a banner and are about the road rather than about a place on it.
##
## **Nothing about sound crosses the wire**, and nothing should: a sound is the
## local consequence of a fact that was relayed. Sending the sound itself would
## double it on the host and desynchronise it everywhere else.


func play_group_at(group: String, at: Vector2, extra_db: float = 0.0,
		pitch_shift: float = 0.0) -> void:
	if not _listening:
		play_group(group, extra_db, pitch_shift)
		return
	var away: float = _ear.distance_to(at)
	if away > Balance.SFX_CUTOFF:
		return
	play_group(group, extra_db + distance_db(away), pitch_shift)


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
