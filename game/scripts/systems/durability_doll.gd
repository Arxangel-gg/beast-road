class_name DurabilityDoll
extends Control

## **The mannequin that warns** (owner, 2026-10-07: "a diablo2 style mannequin
## that shows gear durability that is damaged highlighting them in yellow and red
## as appropriate").
##
## A small figure laid out of the worn pieces' own icons, in the places a body
## wears them - helmet over amulet over armour, weapon and shield either side,
## gloves and ring, boots at the foot - shown only while something worn has worn
## yellow or broken red, as Diablo II's was. A whole piece is drawn faint so the
## figure reads as a body; a worn one in yellow; a broken one in red, breathing.
## A readout: it reads `MetaState` and changes nothing.

## Where each slot sits, as a share of the doll's box: x, y, and its square.
const PLACES: Dictionary = {
	GearData.Slot.HELMET: Vector3(0.5, 0.10, 0.22),
	GearData.Slot.AMULET: Vector3(0.75, 0.24, 0.14),
	GearData.Slot.CAPE: Vector3(0.25, 0.24, 0.16),
	GearData.Slot.ARMOUR: Vector3(0.5, 0.40, 0.30),
	GearData.Slot.WEAPON: Vector3(0.14, 0.48, 0.24),
	GearData.Slot.OFFHAND: Vector3(0.86, 0.48, 0.24),
	GearData.Slot.GLOVES: Vector3(0.18, 0.72, 0.18),
	GearData.Slot.RING: Vector3(0.82, 0.70, 0.13),
	GearData.Slot.CHARM: Vector3(0.82, 0.86, 0.13),
	GearData.Slot.BOOTS: Vector3(0.5, 0.86, 0.24),
}

var _icons: Dictionary = {}
var _bands: Dictionary = {}
var _clock: float = 0.0


func _ready() -> void:
	name = "DurabilityDoll"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "Worn gear. Yellow gives half its benefits, red nothing - mend it at the Smith in the Hold."
	EventBus.gear_wear_changed.connect(func(_slot: int, _band: int) -> void: refresh())
	EventBus.stash_changed.connect(refresh)
	refresh()


## Reads what is worn and how worn it is, and shows the doll only if something is.
func refresh() -> void:
	_bands = MetaState.worn_damage()
	_icons.clear()
	for slot: Variant in PLACES:
		var piece: Dictionary = MetaState.equipped_piece(int(slot))
		if piece.is_empty():
			continue
		var kind: GearData = ContentDB.gear(String(piece.get("kind", "")))
		if kind != null and ResourceLoader.exists(kind.get_sprite_path()):
			_icons[int(slot)] = load(kind.get_sprite_path()) as Texture2D
	visible = not _bands.is_empty()
	queue_redraw()


## The slots worn yellow or red now. For the gate.
func shown_bands() -> Dictionary:
	return _bands


func _process(delta: float) -> void:
	if not visible:
		return
	_clock += delta
	# Only a broken piece breathes; nothing else here moves.
	for band: Variant in _bands.values():
		if int(band) >= 2:
			queue_redraw()
			return


func _draw() -> void:
	var box: Vector2 = size
	draw_rect(Rect2(Vector2.ZERO, box), Color(0.05, 0.06, 0.06, 0.42))
	for slot: Variant in PLACES:
		var place: Vector3 = PLACES[slot]
		var side: float = place.z * box.x
		var at := Vector2(place.x * box.x, place.y * box.y) - Vector2(side, side) * 0.5
		var band: int = int(_bands.get(int(slot), 0))
		var colour: Color = Color(1.0, 1.0, 1.0, 0.22)
		if band == 1:
			colour = Color(GearRow.durability_colour(1), 0.95)
		elif band == 2:
			var breath: float = 0.65 + 0.35 * sin(_clock * TAU * 1.2)
			colour = Color(GearRow.durability_colour(2), breath)
		var icon: Texture2D = _icons.get(int(slot), null)
		if icon != null:
			draw_texture_rect(icon, Rect2(at, Vector2(side, side)), false, colour)
		if band > 0:
			draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(side + 2.0, side + 2.0)),
				Color(colour, 0.85), false, 1.0)
