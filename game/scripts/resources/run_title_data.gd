class_name RunTitleData
extends GameData

## A name for the run a player just finished.
##
## Owner request, 2026-09-02: reconstruct the final build at the end of a run and
## give it a title — "The Frozen Hunter", "The Walking Inferno" — because that
## screenshot is the one people share.
##
## ## Named from what actually happened
##
## Every title is chosen from two facts the run already recorded: which element
## the player's towers ended up being, and which way they were playing. Nothing
## is invented and nothing is rolled - two players who built the same way get the
## same name, which is what makes it a description rather than a fortune cookie.
##
## ## Why this is data
##
## Working rule 3: adding a title is adding a `.tres`. The alternative is a match
## statement with sixteen arms in the results screen, which is the shape that
## stops being extended the moment somebody wants a seventeenth.

## How the player spent the run. The second half of the name.
##
## Deliberately few and deliberately coarse. This is read off counts the run
## already keeps - it is a summary, not a classifier, and a fifth axis would need
## a fifth thing to be tracked before it could ever be true.
enum Axis {
	## Towers standing at the end outnumbered everything else about the build.
	TOWERS,
	## A spirit walked the whole way.
	COMPANION,
	## Neither - the hero did it themselves.
	BLADE,
}

## Which element this title wants, as a `TowerData.Element`, or -1 for a run that
## never settled on one.
@export var element: int = -1

@export var axis: Axis = Axis.BLADE


func get_sprite_path() -> String:
	return ""


## Whether this title describes that run.
func matches(run_element: int, run_axis: Axis) -> bool:
	return element == run_element and axis == run_axis
