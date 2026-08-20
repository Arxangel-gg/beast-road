class_name WeatherData
extends GameData

## One weather state and what it does to the four elements.
##
## Weather is authored rather than emergent, and it is per element rather than
## per tower: GDD §20 promises "a player who learns one element can read the
## other", so weather that singled out named towers would break the thing the
## element grid exists to guarantee.
##
## It reinforces regional identity rather than fighting it. v4 describes Act I as
## rain-heavy, Act II as a bright desert of mirage storms, and Act III as a
## frozen approach where "weather suppresses visibility" — so each region's
## weather pool is drawn from what that region already is, and a Heatwave in the
## Sunglass Waste is the desert being more itself for a while.

## Damage multipliers, one per TowerData.Element, in enum order:
## FIRE, WATER, EARTH, AIR.
##
## A multiplier rather than an additive bonus, because the terrain's favoured
## element is already additive — stacking two additives on the same tower is how
## a "+40%" turns out to be +95% and nobody can see why from either number.
@export var element_scale: Array[float] = [1.0, 1.0, 1.0, 1.0]

## Which acts may roll this. Empty means any.
@export var acts: Array[int] = []

## Relative likelihood against the others eligible for the act.
@export_range(0.0, 10.0) var weight: float = 1.0

## World tint while it holds, multiplied over the day/night grade.
@export var tint: Color = Color.WHITE

## How much darker the field reads, for the readability gate to account for.
@export_range(0.0, 1.0) var gloom: float = 0.0

## Player-facing one-liner for the HUD announcement.
@export var effect_line: String = ""


func scale_for(element: int) -> float:
	if element < 0 or element >= element_scale.size():
		return 1.0
	return element_scale[element]


## Whether this weather can appear in the given act.
func allows_act(act: int) -> bool:
	return acts.is_empty() or acts.has(act)
