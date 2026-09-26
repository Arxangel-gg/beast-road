extends Node

## Photographs the dressed Warden, which no headless gate can see.
##
##   godot --path game res://tools/dress_shot.tscn -- <out dir>
##
## `dress_check` proves every armour and cape layer is cut to its body's cells
## with no empty frame; it cannot say whether plate reads as plate, whether a
## cape hangs from the shoulders or whether the two bodies look like one game.
## Both bodies bare, in light armour, in heavy armour, in the long cape, and in
## heavy armour under the cape, on the stage the Warden's Glass uses - so the
## picture is what the road draws - at four facings, one photograph each.
## Diagnostic only, never a gate.

const SIZE := Vector2i(1800, 900)
const FACINGS: Array = [["south", 2], ["south_east", 1], ["east", 0], ["north", 6]]
## Name, armour class, cape shape; "" wears none.
const OUTFITS: Array = [
	["bare", "", ""],
	["light", "light", ""],
	["heavy", "heavy", ""],
	["cape", "", "long"],
	["heavy_cape", "heavy", "long"],
]
const WEAPON: String = "coalpaint_edge"


func _ready() -> void:
	get_window().size = SIZE
	get_viewport().set_content_scale_size(SIZE)
	MetaState.hold_saves()
	var out: String = "user://"
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.17, 0.19, 0.18)
	backdrop.anchor_right = 1.0
	backdrop.anchor_bottom = 1.0
	add_child(backdrop)
	var grid := GridContainer.new()
	grid.columns = OUTFITS.size()
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	add_child(grid)
	var stages: Array[WardenStage] = []
	for body: int in [0, 1]:
		for entry: Array in OUTFITS:
			var stage := WardenStage.new()
			stage.turntable = false
			stage.custom_minimum_size = Vector2(float(SIZE.x) / float(OUTFITS.size()), float(SIZE.y) / 2.0)
			grid.add_child(stage)
			var look: Dictionary = WardenLook.plain()
			look[WardenLook.KEY_BODY] = body
			look[WardenLook.KEY_HAIR] = 10 if body == 0 else 17
			look[WardenLook.KEY_HAIR_COLOUR] = 4
			look[WardenLook.KEY_SKIN] = 5
			var outfit: Dictionary = WardenDress.outfit(look, ContentDB.gear(WEAPON),
				_armour(String(entry[1])), _cape(String(entry[2])), null)
			stage.animator().dress(outfit)
			WardenLook.dress(stage.sprite(), look)
			stage.animator().play("idle", true)
			stages.append(stage)
			print("[dress-shot] %s %s wears %s, cape %s" % [WardenDress.BODIES[body], entry[0],
				outfit["body_layer"], outfit["cape_layer"]])
	for facing: Array in FACINGS:
		for stage: WardenStage in stages:
			stage.face(int(facing[1]))
		for _frame: int in 30:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var frame: Image = get_viewport().get_texture().get_image()
		var path: String = out.path_join("dress_%s.png" % String(facing[0]))
		frame.save_png(path)
		print("[dress-shot] saved ", path)
	MetaState.resume_saves()
	# A clean quit: nothing playing, nothing standing, a few frames to let go.
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	grid.queue_free()
	for _frame: int in 10:
		await get_tree().process_frame
	get_tree().quit()


## The first armour of a class, or none.
func _armour(cls: String) -> GearData:
	if cls.is_empty():
		return null
	for piece: GearData in ContentDB.gear_sorted():
		if piece.slot == GearData.Slot.ARMOUR and piece.look == cls:
			return piece
	return null


## The first cape of a shape, or none.
func _cape(shape: String) -> GearData:
	if shape.is_empty():
		return null
	for piece: GearData in ContentDB.gear_sorted():
		if piece.slot == GearData.Slot.CAPE and piece.look == shape:
			return piece
	return null
