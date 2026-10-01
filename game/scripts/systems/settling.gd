class_name Settling
extends Node

## **The road settles after a held wave** (2026-09-30). The last of the
## second-rank juice the 2026-09-15 triage deferred: "music drops, dust drifts,
## embers remain". The music half was built on 2026-09-23 (`AudioBuses.set_calm`
## eases the music in Preparation); this is the rest.
##
## During a wave it counts where bodies fell, by cell. When the wave is held,
## the cells where most fell hang with a slow dust haze drifting on the wind and
## a few embers smouldering up out of the ground for `SETTLE_SECONDS`, thinning
## as they go - so the place the fight was is visible for a moment after it,
## rather than the road snapping back to clean the frame the last body drops.
##
## **A look and never a fact.** It reads only where bodies fell and changes no
## number; `Graphics.particle_scale` and `JuiceDirector` (COSMETIC) thin it, the
## records are the ink's own (`Vfx.haze`, `Vfx.mote`) and never nodes, and it
## draws only where the camera can see. A new wave stops it at once. It is a
## child of the field, so a raid freezes it with the field (working rule 8).

var field: Node2D = null

## Cell (Vector2i) to how many bodies fell there this wave.
var _fallen: Dictionary = {}
## The spots settling now: {at, left, clock}.
var _spots: Array[Dictionary] = []


func _ready() -> void:
	name = "Settling"
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)


func _on_enemy_died(_enemy_id: String, at: Vector2) -> void:
	var cell := Vector2i(floori(at.x / Balance.SETTLE_CELL), floori(at.y / Balance.SETTLE_CELL))
	_fallen[cell] = int(_fallen.get(cell, 0)) + 1


func _on_wave_started(_wave_number: int, _lanes: Array) -> void:
	_fallen.clear()
	_spots.clear()


func _on_wave_cleared(_wave_number: int) -> void:
	var cells: Array = _fallen.keys()
	cells.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(_fallen[a]) > int(_fallen[b]))
	_spots.clear()
	for cell: Variant in cells:
		if _spots.size() >= Balance.SETTLE_SPOTS:
			break
		if int(_fallen[cell]) < Balance.SETTLE_MIN_FALLEN:
			break
		var corner := cell as Vector2i
		_spots.append({
			"at": (Vector2(corner) + Vector2(0.5, 0.5)) * Balance.SETTLE_CELL,
			"left": Balance.SETTLE_SECONDS,
			"clock": 0.0,
		})
	_fallen.clear()


## The spots settling now, for the gate.
func spots() -> Array[Dictionary]:
	return _spots


func _process(delta: float) -> void:
	if _spots.is_empty():
		return
	var thin: float = Graphics.particle_scale() * JuiceDirector.weight(JuiceDirector.Priority.COSMETIC)
	var wind: Vector2 = RunState.wind
	for index: int in range(_spots.size() - 1, -1, -1):
		var spot: Dictionary = _spots[index]
		spot["left"] = float(spot["left"]) - delta
		if float(spot["left"]) <= 0.0:
			_spots.remove_at(index)
			continue
		spot["clock"] = float(spot["clock"]) + delta
		var every: float = 1.0 / maxf(Balance.SETTLE_HZ * thin, 0.01)
		if float(spot["clock"]) < every:
			continue
		spot["clock"] = 0.0
		var fading: float = float(spot["left"]) / Balance.SETTLE_SECONDS
		var at: Vector2 = spot["at"] as Vector2
		var scatter := Vector2(randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * Balance.SETTLE_CELL * 0.45
		Vfx.haze(at + scatter, wind * Balance.SETTLE_WIND_CARRY + Vector2(0.0, -16.0),
			Color(0.62, 0.56, 0.48, 0.4 * fading), randf_range(22.0, 34.0), Balance.SETTLE_HAZE_LIFE)
		if randf() < Balance.SETTLE_EMBER_CHANCE * fading:
			Vfx.mote(at + scatter * 0.6, Vector2(randf_range(-10.0, 10.0), -randf_range(30.0, 56.0)),
				Color(1.0, 0.62, 0.28, 1.0), randf_range(3.0, 4.6), randf_range(1.6, 2.6))
