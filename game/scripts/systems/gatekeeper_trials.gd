class_name GatekeeperTrials

## **The Gatekeeper's ladder, and what skipping it costs at the summit.**
##
## Owner ruling, 2026-09-17: three optional trials on Acts 3, 5 and 7, each
## unlocked by clearing the one before, and the Gatekeeper itself on Act 9.
## None of them is required to clear an act. **What makes them worth taking is
## the fourth clause: a difficulty whose Gatekeeper has not been beaten fights
## him alongside Kharok at the Final Ascent.** So the ladder is not a side
## quest with a reward bolted on - it is the choice between paying four times
## on the way up, at times you chose, or once at the worst possible moment.
##
## **Per difficulty, and that is the whole reason this persists.** Nightmare
## and Hell each run their own ladder, so a Warden who cleared Normal's
## Gatekeeper still meets him on Nightmare's summit until they beat Nightmare's.
##
## **Working rule 7.** One key is added, `MetaState.gatekeeper`: a tier id to
## how many stages of that tier's ladder are cleared. It is a *run statistic*
## in shape - a record of what has been done, like `best_distance` and
## `rifts_closed` - and it **grants nothing by itself**. What it does is open
## the next trial and take the Gatekeeper off that tier's summit. The power the
## ladder pays out is `MetaState.ascension`, which has its own cap and its own
## bound recorded beside it.
##
## It could not be derived, and that was checked before a key was added: no
## existing statistic records *which* optional detours a Warden took on *which*
## difficulty. `best_distance` answers how far, never what was fought.
##
## Additive: a save written before this has no `gatekeeper` key and reads back
## as an empty ladder on every tier, which is also what a new account is.
## `SAVE_VERSION` does not move.

## Which act opens which rung.
##
## Odd acts with a gap between them: a trial on every act would make the ladder
## the road rather than a detour off it, and consecutive ones would let a
## player clear the whole thing before the campaign has taught them anything.
##
## **All four are trials of the Gate, and none of them is the Gatekeeper.**
## The owner's brief put "the gatekeeper himself" on Act 9, and that collides
## with what ships: `last_terrace.tres` authors `boss_id = "gatekeeper"`, so he
## is *already* Act 10's act boss and `story_act10.tres` tells the player so -
## "the Gate of the Crown holds the last step, and the Gatekeeper has waited
## longer than the Warden has been alive". An optional fight on Act 9 against a
## body the road makes you fight on Act 10 is the same encounter twice.
##
## So the ladder tests you and Act 10 is where you meet him, which is what the
## fiction already said. The mechanic the brief actually turns on is untouched:
## clear all four rungs and he does not stand at the summit; leave any of them
## and he is there beside Kharok.
##
## **Flagged for the owner rather than assumed.** The alternative is a new Act
## 10 boss - art, data and a rewritten act entry - to free the Gatekeeper for
## Act 9, and that is a content decision rather than a wiring one.
const STAGE_ACTS: Array[int] = [3, 5, 7, 9]

## How many rungs a tier's ladder has.
const STAGES: int = 4


## The rung an act offers, or 0 for an act that offers none.
static func stage_for_act(act: int) -> int:
	var at: int = STAGE_ACTS.find(act)
	return at + 1 if at >= 0 else 0


## How many rungs this tier's ladder has been climbed.
static func cleared_on(tier_id: String) -> int:
	return clampi(int(MetaState.gatekeeper.get(tier_id, 0)), 0, STAGES)


## Whether the trial this act offers is the next one owed on this tier.
##
## **A rung is only ever offered in order**, so a Warden cannot meet the
## Gatekeeper on Act 9 having skipped every trial before it - the ladder is
## what the trials are for, and a player who took none of them has not earned
## the argument.
static func may_enter(act: int, tier_id: String) -> bool:
	var stage: int = stage_for_act(act)
	return stage > 0 and stage == cleared_on(tier_id) + 1


## Records a rung climbed, and returns whether it was new.
##
## Refuses anything out of order for the same reason `may_enter` does, so a
## relayed or replayed message cannot skip a tier's ladder to its end.
static func record_cleared(tier_id: String, stage: int) -> bool:
	if stage <= 0 or stage > STAGES:
		return false
	if stage != cleared_on(tier_id) + 1:
		return false
	MetaState.gatekeeper[tier_id] = stage
	MetaState.grant_ascension_rank()
	MetaState.save_game()
	return true


## **Whether the Gatekeeper stands at this tier's summit.**
##
## The owner's own addition and the thing that makes the ladder a decision. A
## tier whose Gatekeeper has been beaten meets Kharok alone; one whose has not
## fights both.
static func guards_the_summit(tier_id: String) -> bool:
	return cleared_on(tier_id) < STAGES


## What the ladder is worth to a Warden who has climbed all of it everywhere.
## Read by the ascension cap, so the two cannot disagree about how many rungs
## exist.
static func total_rungs() -> int:
	return STAGES * maxi(ContentDB.tiers.size(), 1)
