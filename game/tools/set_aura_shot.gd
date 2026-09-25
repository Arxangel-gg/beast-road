extends Node

## Photographs what wearing a whole matched set looks like.
##
##   godot --path game res://tools/set_aura_shot.tscn
##
## **Nothing had ever seen it.** `gear_set_check` proves `worn_set()` answers
## the set and that the aura node is ticking, which is the wiring - and the
## owner's brief for sets was *"wearing a full set should have a visual vfx game
## juicy effect on players"*, which is not a thing a bool can answer. The ring
## was in fact drawing nothing at all from the day the forge catalogue landed
## until 2026-09-22, because `SetAura._look` read `found.colour` off a
## `GearSetData` that declares `aura_colour` - a runtime error that aborted the
## function before it ever set `visible`. Every number in that gate stayed
## green. Only a photograph closes that gap, so here is one.
##
## Three panels, one above the next, all of the same Warden:
##
##   1. **nothing worn** - the floor a set is read against
##   2. **the moment it completes** - the arrival motes, which fire once
##   3. **settled** - the slow ring turning at the feet
##
## Written to `user://set_aura_shot.png`. Diagnostic only, never a gate.

const PANEL := Vector2i(760, 420)
const PANELS: int = 3
## Long enough for `SetAura.RE_READ` to come round plus a margin, because the
## aura asks on its own slow clock rather than listening - so a capture taken
## on the frame the gear changed photographs the frame before it noticed.
const NOTICE_MARGIN: float = 0.1
## Where in the mote burst's own life the arrival panel is taken. Early, since
## the sheet frays away and the last cells are nearly empty.
const ARRIVAL_AT: float = 0.18
## How long the settled panel waits, so the ring is somewhere else in its turn
## than it was on the arrival frame and the two panels are not one picture.
const SETTLE_AT: float = 1.6

var _hero: Hero = null
var _stand := Vector2.ZERO


func _ready() -> void:
	# **On the real battlefield rather than a plate**, because a plate cannot
	# answer the one question a plate raised: the ring draws at `z_index = -1`
	# and a plate at zero hid it outright. Terrain, roads and the treeline are
	# all below a y-sorted hero, so -1 should sit on the ground and above them -
	# should, which is not the same as does.
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--field":
			await _on_the_road()
			return
	get_window().size = PANEL
	# One content unit to one pixel, for the reason `blood_shot` records: a
	# photograph at half scale is a model of the thing rather than the thing.
	get_viewport().set_content_scale_size(PANEL)
	MetaState.hold_saves()
	RunState.reset(false, 20260922)

	var plate := ColorRect.new()
	plate.color = Color(0.17, 0.18, 0.16)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	# **Under the aura, which draws at `z_index = -1`.** A plate at the default
	# zero is in front of it, and the first three runs of this tool photographed
	# an empty floor for exactly that reason - the same z-order trap that once
	# hid a mount and a campfire. On a real battlefield the ground is far below;
	# here the plate has to be told.
	plate.z_index = -10
	add_child(plate)
	var stage := Node2D.new()
	add_child(stage)
	# The motes are a forge sheet and a forge sheet needs somewhere to live;
	# `Vfx.world` is null outside a battlefield and `forge_play` returns on the
	# first line, which would photograph a ring arriving in silence.
	var world_before: Node2D = Vfx.world
	Vfx.world = stage

	var hero: Hero = (load("res://scenes/hero/hero.tscn") as PackedScene) \
		.instantiate() as Hero
	# **Feet high enough that the ring at them is in frame.** The aura is drawn
	# on the ground at `GEAR_SET_AURA_RADIUS`, so a Warden centred in the panel
	# has the one thing being photographed below its bottom edge - which is what
	# the first run of this tool produced.
	var stand := Vector2(float(PANEL.x) * 0.5,
		float(PANEL.y) - Balance.GEAR_SET_AURA_RADIUS * 2.6)
	hero.position = stand
	_hero = hero
	_stand = stand
	stage.add_child(hero)
	# **A Warden does not stay where it is put.** Measured: it settles 68.8
	# units below the position it is given, because the body drops onto its own
	# feet anchor after placement - the same thing `RiftArena._spawn` puts back
	# for a body dealt into a maze. Guessing the offset is how the first two
	# runs of this tool photographed the ring below the bottom edge, so it is
	# read off the settled body instead.
	await _settle(2)
	hero.position.y -= hero.global_position.y - stand.y

	var target: GearSetData = _a_set_worth_photographing()
	var caption: String = "no set" if target == null else target.display_name
	var tag := Label.new()
	tag.position = Vector2(16.0, 12.0)
	tag.add_theme_font_size_override("font_size", 15)
	stage.add_child(tag)

	var sheet := Image.create(PANEL.x, PANEL.y * PANELS, false, Image.FORMAT_RGBA8)
	var stash_before: Array = MetaState.stash.duplicate(true)
	var equipped_before: Dictionary = MetaState.equipped.duplicate()
	MetaState.equipped = {}
	Modifiers.rebuild()

	# 1. NOTHING WORN.
	tag.text = "1 · nothing worn"
	await _settle(4)
	await _blit(sheet, 0)

	# 2. THE MOMENT IT COMPLETES. Worn through the stash door the player uses,
	# so this photographs the same path a run takes rather than a second one.
	if target != null:
		for member: String in target.members:
			var kind: GearData = ContentDB.gear(member)
			if kind == null:
				continue
			MetaState.receive_gear(Stash.make(member, 0, 1))
			MetaState.equip(kind.slot, MetaState.stash.size() - 1)
		Modifiers.rebuild()
	tag.text = "2 · %s completes" % caption
	await get_tree().create_timer(SetAura.RE_READ + NOTICE_MARGIN).timeout
	await get_tree().create_timer(ARRIVAL_AT).timeout
	await _blit(sheet, 1)

	# 3. SETTLED.
	tag.text = "3 · %s worn" % caption
	await get_tree().create_timer(SETTLE_AT).timeout
	await _blit(sheet, 2)

	var path: String = ProjectSettings.globalize_path("user://set_aura_shot.png")
	sheet.save_png(path)
	var shown: GearSetData = hero.worn_set()
	print("[set-aura] %s -> %s" % [
		"nothing showing" if shown == null else shown.id, path])

	MetaState.stash = stash_before
	MetaState.equipped = equipped_before
	Modifiers.rebuild()
	Vfx.world = world_before
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)


## The widest set on the roster, because more pieces is a longer walk to the
## thing being photographed and the whole point is that finishing one is rare.
func _a_set_worth_photographing() -> GearSetData:
	var best: GearSetData = null
	for one: GearSetData in ContentDB.gear_sets_sorted():
		if best == null or one.members.size() > best.members.size():
			best = one
	return best


func _settle(frames: int) -> void:
	for _frame: int in frames:
		await get_tree().process_frame


func _blit(sheet: Image, row: int) -> void:
	await RenderingServer.frame_post_draw
	if _hero != null and is_instance_valid(_hero):
		var aura: SetAura = _hero.get_node_or_null("SetAura") as SetAura
		print(("[set-aura] panel %d: hero at %s; aura %s vis=%s z=%d at %s "
			+ "set=%s particles=%.2f")
			% [row + 1, _hero.global_position,
				"missing" if aura == null else "present",
				"?" if aura == null else str(aura.visible),
				0 if aura == null else aura.z_index,
				Vector2.INF if aura == null else aura.global_position,
				"none" if aura == null or aura.worn_set() == null
					else aura.worn_set().id,
				Graphics.particle_scale()])
	var frame: Image = get_viewport().get_texture().get_image()
	if frame.get_format() != sheet.get_format():
		frame.convert(sheet.get_format())
	sheet.blit_rect(frame, Rect2i(Vector2i.ZERO, PANEL),
		Vector2i(0, PANEL.y * row))


## The aura where it is actually played: a Warden standing on a built road.
##
## Cropped around the hero off the **canvas transform** rather than the world
## position, which is the coordinate mistake the tail probe and the shot plate
## each made once - a camera makes the two disagree.
func _on_the_road() -> void:
	const FIELD := Vector2i(1280, 720)
	const CROP := Vector2i(420, 360)
	get_window().size = FIELD
	get_viewport().set_content_scale_size(FIELD)
	MetaState.hold_saves()
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene) \
		.instantiate() as Run
	add_child(run)
	for _frame: int in 30:
		await get_tree().process_frame
	var hero: Hero = run.battlefield.hero if run.battlefield != null else null
	if hero == null:
		push_error("[set-aura] no hero on the field")
		get_tree().quit(1)
		return
	var target: GearSetData = _a_set_worth_photographing()
	MetaState.equipped = {}
	for member: String in target.members:
		var kind: GearData = ContentDB.gear(member)
		if kind == null:
			continue
		MetaState.receive_gear(Stash.make(member, 0, 1))
		MetaState.equip(kind.slot, MetaState.stash.size() - 1)
	Modifiers.rebuild()
	await get_tree().create_timer(SetAura.RE_READ + SETTLE_AT).timeout
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var at: Vector2 = hero.get_viewport_transform() * hero.global_position
	var box := Rect2i(Vector2i(at) - CROP / 2, CROP)
	box = box.intersection(Rect2i(Vector2i.ZERO, frame.get_size()))
	var crop: Image = frame.get_region(box)
	crop.resize(box.size.x * 2, box.size.y * 2, Image.INTERPOLATE_NEAREST)
	var path: String = ProjectSettings.globalize_path("user://set_aura_field.png")
	crop.save_png(path)
	# The whole frame beside the crop, because a 2x magnified corner of a field
	# is a model of the field: the first field run showed hard-edged blocks in
	# the ground and there was no way to tell a terrain seam from a fog cell
	# from a crop.
	frame.save_png(ProjectSettings.globalize_path("user://set_aura_whole.png"))
	print("[set-aura] field: %s at %s -> %s" % [
		"nothing" if hero.worn_set() == null else hero.worn_set().id, at, path])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	get_tree().quit(0)
