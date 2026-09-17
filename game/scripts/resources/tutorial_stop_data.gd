class_name TutorialStopData
extends GameData

## **A place on the Walk.** One stop teaches one thing and opens the way to the
## next (owner brief, 2026-09-17; the beat sheet is `docs/TUTORIAL_DESIGN.md`).
##
## **Its own enum, deliberately.** `TutorialStepData.Trigger` is indexed by
## number out of twenty shipped `.tres` files, and adding a member to it in the
## middle once shifted twelve tutorial steps by one - a new player was told
## about raids when they found gear and was never told about rift gates at all.
## The Walk grows nothing over there.
##
## **What a stop is, and is not.** It is a position, a thing to do, and words.
## It grants nothing: everything the Walk pays out is written once, by
## `TutorialGrants`, at the chain or at the skip. A stop that paid its own
## reward would be a partial Walk that could be farmed by quitting at the good
## ones.

## What finishes a stop.
##
## Appended to, never inserted, for exactly the reason above.
enum Done {
	ENTERED,        ## standing inside `radius` is enough
	KILLED,         ## `count` bodies down
	GATHERED,       ## a node worked to empty
	CAUGHT,         ## a fish landed
	CRAFTED,        ## the bench used
	LOOSED,         ## `count` arrows away
	CAST,           ## `count` spells away
	BONDED,         ## a spirit answered
	SCREEN_CLOSED,  ## a door was opened and shut
	BUILT,          ## a tower placed
	UPGRADED,       ## a tower taken up a level
	WAVE_HELD,      ## the scripted wave is down
	CHAIN_CUT,      ## the anchor
}

## Where it sits in the order. The Walk runs them by this, so a stop inserted
## later needs no other file edited.
@export var order: int = 0

## **What kind of place it is**, rather than where.
##
## `TutorialWalk` asks the live field where the nearest one of these is:
## `"road"` (a share of the way along it, see `along`), `"pond"`, `"trunk"`,
## `"seam"`, `"build"` and `"town"`. A hand-typed grid coordinate is a number
## nobody can check without looking at the screen, and this project has shipped
## three placement faults that every number agreed about and a photograph
## refused. A named landmark cannot resolve to unreachable ground, because the
## ground it resolves to is ground the field already built.
@export var anchor: String = "road"

## How far along the road, when the anchor is the road. 0 is the far end the
## Warden starts from; 1 is the gate.
@export_range(0.0, 1.0) var along: float = 0.0

## How close is close enough, in world units.
@export var radius: float = 96.0

@export var done: Done = Done.ENTERED
@export var count: int = 1

## The imperative. Shown when the stop is reached.
@export_multiline var instruction: String = ""
## A second line, shown once the objective is met - the thing that only makes
## sense after you have done it once.
@export_multiline var instruction_two: String = ""
## The world. Shown on a first walk and suppressed on a replay, because a
## player walking it again wants the rules and not the story a second time.
@export_multiline var aside: String = ""

## How long a line stands before the next may replace it.
@export var seconds: float = 9.0

## The gate this stop unbars, or "". Gating is by path rather than by invisible
## wall: a stile, an unbarred door, a plank across the race.
@export var opens: String = ""
