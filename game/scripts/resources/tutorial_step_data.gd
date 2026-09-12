class_name TutorialStepData
extends GameData

## One coach prompt for a first-time player (GDD §52: the game has to teach
## itself).
##
## Content, not logic, because CLAUDE.md §3 keeps the vocabulary in data and §9
## keeps player-facing strings out of scripts. Adding a lesson is adding a file.
##
## A step is "show this line when that happens, and stop showing it once the
## player has done the thing". The coach owns *when*; this owns *what*.

## What makes the step appear. One EventBus moment each, named rather than
## wired, so a step can be re-ordered without touching the coach.
enum Trigger {
	## The first Preparation of the run.
	RUN_STARTED,
	## The build panel was opened on a tile.
	BUILD_PANEL_OPENED,
	## A tower was built anywhere.
	TOWER_BUILT,
	## A formation started walking.
	WAVE_STARTED,
	## Command charge became spendable for the first time.
	COMMAND_READY,
	## A between-wave breather opened.
	BREATHER_OPENED,
	## The first crossroad.
	CROSSROAD_REACHED,
	## The road is weakened and a raid may be entered.
	RAID_AVAILABLE,
	## The first piece of gear has dropped.
	GEAR_FOUND,
	## The hero levelled for the first time this account.
	LEVEL_UP,
	## The first spell went off.
	SPELL_CAST,
	## The first arrow was loosed.
	ARROW_LOOSED,
	## A travelling merchant arrived.
	MERCHANT_ARRIVED,
	## An act boss fell; portents are about to be offered.
	BOSS_FELLED,
	## The town scope was opened for the first time.
	TOWN_OPENED,
	## A wild animal's spirit was met for the first time.
	SPIRIT_MET,
	## Something was pulled out of a pond for the first time.
	FISH_CAUGHT,
	## The hero first stood by water that could be fished (2026-09-11).
	POND_NEAR,
	## The hero first stood by a rift gate or a dungeon mouth.
	GATE_NEAR,
}

@export var trigger: Trigger = Trigger.RUN_STARTED

## Lower runs earlier when two steps share a trigger.
@export var order: int = 0

## The line itself. Two short sentences at most: this is read mid-run, over a
## battlefield, by somebody who has never seen the game before.
@export_multiline var body: String = ""

## Seconds on screen before it retires on its own. A prompt that waits for
## acknowledgement blocks a player who already understood it.
@export var seconds: float = 7.0
