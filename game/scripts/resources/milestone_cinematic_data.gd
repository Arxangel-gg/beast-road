class_name MilestoneCinematicData
extends GameData

## One first-view travel or boss milestone (GDD v4 §6 and §51 M5).
##
## The director owns when a signal arrives and the overlay owns how it is shown.
## This resource owns every word and every content association, so adding or
## revising a milestone remains a data change.

enum Trigger {
	ACT_STARTED,
	BOSS_SPAWNED,
	BOSS_DEFEATED,
}

enum Presentation {
	REGION,
	BOSS,
	SUMMIT,
}

@export var trigger: Trigger = Trigger.ACT_STARTED

## Terrain id for ACT_STARTED, boss id for the two boss signals.
@export var trigger_id: String = ""

## Small line above the title. Kept here because it is player-facing copy.
@export var eyebrow: String = ""

## The visual composition and, by convention, the sprite folder/prefix.
@export var presentation: Presentation = Presentation.REGION

## Act backdrop used behind a boss portrait. Act 4 resolves to summit art.
@export_range(1, 4, 1) var act: int = 1


func get_sprite_path() -> String:
	match presentation:
		Presentation.BOSS:
			return derive_path("bosses", "boss_", id)
		Presentation.SUMMIT:
			return derive_path("bg", "", id)
		_:
			return derive_path("bg", "macro_", id)


func get_backdrop_path() -> String:
	if presentation != Presentation.BOSS:
		return get_sprite_path()
	if act >= 4:
		return derive_path("bg", "", "summit")
	return derive_path("bg", "macro_", "act%d" % act)


func matches(wanted_trigger: Trigger, wanted_id: String) -> bool:
	return trigger == wanted_trigger and trigger_id == wanted_id
