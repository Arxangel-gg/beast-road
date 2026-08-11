extends Node

## The single source of truth for the current run (GDD §11, rule 1).
##
## No system caches run data locally. If a value describes "this run", it lives
## here and everything else reads it back out. Everything in this object is
## destroyed on death — persistence is MetaState's job and its schema is
## deliberately tiny (GDD §7).
##
## Stage 1 does not use any of this. It is here so that later stages have one
## obvious place to put run data instead of inventing a second one.

## Distance travelled since the run began, in distance units. Drives
## construction progress, difficulty scaling, and act boundaries.
var distance_travelled: float = 0.0

## Current beast walking speed in units/sec, floored at BEAST_SPEED_FLOOR.
var beast_speed: float = Balance.BEAST_BASE_SPEED

## 1-based act number.
var act: int = 1

## 0-based index of the segment within the current act.
var segment: int = 0

## The single pooled currency. GDD §8 caps the run at three progression axes:
## this, relics, and blueprints.
var resources: int = 0

## Relic ids currently socketed in the Town Hall. Only socketed relics do
## anything (GDD §3.2).
var socketed_relics: Array[String] = []

## Relic ids held but not socketed.
var held_relics: Array[String] = []

## Boss core ids. Permanent, always-active, never socketed (GDD §6).
var boss_cores: Array[String] = []

## Tower blueprint ids unlocked for this run.
var blueprints: Array[String] = []

## Tower id in each of the four ring slots, N/E/S/W. Empty string = empty slot.
## Swappable only between segments, never mid-combat (GDD §3.1).
var tower_loadout: Array[String] = ["", "", "", ""]

## Spell ids the hero has equipped, max HERO_MAX_SPELL_SLOTS.
var equipped_spells: Array[String] = []

## Terrain id of the current segment; sets the dominant breed and modifiers.
var terrain_id: String = ""

## Building tiers, keyed by building id. 0 = not built.
var building_tiers: Dictionary = {}

## Number of times the war horn has been blown. Each use permanently escalates
## enemy strength for the rest of the run.
var war_horn_uses: int = 0

## Raid charge, normalised 0..1. A full bar unlocks a raid.
var raid_charge: float = 0.0

## Run statistics, handed to MetaState when the run ends.
var enemies_killed: int = 0
var hero_deaths: int = 0


## Wipes everything. Called at the start of a run, never mid-run — death wipes
## the run entirely (GDD §2, decision 3).
func reset() -> void:
	distance_travelled = 0.0
	beast_speed = Balance.BEAST_BASE_SPEED
	act = 1
	segment = 0
	resources = 0
	socketed_relics.clear()
	held_relics.clear()
	boss_cores.clear()
	blueprints.clear()
	tower_loadout = ["", "", "", ""]
	equipped_spells.clear()
	terrain_id = ""
	building_tiers.clear()
	war_horn_uses = 0
	raid_charge = 0.0
	enemies_killed = 0
	hero_deaths = 0


## Multiplier applied to enemy HP and damage from accumulated war horn uses.
func enemy_escalation_multiplier() -> float:
	return 1.0 + float(war_horn_uses) * Balance.WAR_HORN_ESCALATION_PER_USE
