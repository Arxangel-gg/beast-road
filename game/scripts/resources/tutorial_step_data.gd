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
