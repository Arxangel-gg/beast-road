extends Node

## Photographs a Warden on a horse, which nothing did.
##
##   godot --path game res://tools/mount_shot.tscn
##
## Diagnostic only, never a gate. `mount_check` holds every rule a mount has -
## the ceiling, the refusal to fight, the dismount, the wind - and every one of
## them is a number. **The seat is not.** How high the rider sits, whether the
## hooves are on the ground the Warden was standing on, whether the horse turns
## with its rider: all of that is arithmetic that agrees with itself and can
## still be plainly wrong on screen, which is the mistake this project spent six
## passes on with Yuri's tail before anybody photographed it.
##
## Four plates, each written to `user://mount_shot_<what>.png`:
##
##  - `seated`  - the Warden on each mount in the stable, side by side, facing
##    the camera, so the seat heights can be compared against each other and
##    against the animal's own back;
##  - `turning` - one mount through all eight facings with its rider, because
##    the rider and the mount take their heading from two different functions
##    and the failure is that they disagree;
##  - `walking` - a walk cycle, to see the legs move and the gear stay put;
##  - `ground`  - a mounted and an unmounted Warden on one line, which is the
##    one picture that answers "are the hooves on the same ground as the boots".
##
## **The rider is the real Warden**, read out of `hero_idle.png` the way
## `HeroAnimator` reads it - the same eight rows, the same cell, turning with
## the mount.
##
## The first cut used `hero_base.png`, an older single painting, and the owner
## caught it in a heartbeat: *"ours has the lantern"*. That was worth more than
## a corrected screenshot. `MountRig` measures the rider to find their hips,
## and a region-enabled sprite's `texture` is the **whole sheet** - so with the
## real Warden it measured about 1270 tall, put the hips 571 up and seated
## them at the horse's feet. Photographing a stand-in had hidden a bug in the
## thing itself. **Photograph what ships.**

const SIZE := Vector2i(1280, 720)
## A line to read the feet against. Not decoration: "the hooves are on the
## ground" is a claim about one pixel row and the eye cannot hold it without a
## reference.
const GROUND_TINT := Color(0.85, 0.78, 0.45, 0.55)

## The Warden's own idle sheet and its cell, matching `HeroAnimator`. Read
## rather than re-derived, so a repack of the hero moves this too.
const RIDER_SHEET: String = "res://art/hero/hero_idle.png"

var _stage: Node2D = null
var _ground: float = 0.0


func _ready() -> void:
	get_window().size = SIZE
	# One content unit to one pixel, so the sprites are photographed at the size
	# they are drawn rather than through the project's own content scale - the
	# lesson `blood_shot` records, where every mark came out half size.
	get_viewport().set_content_scale_size(SIZE)
	RunState.reset(false, 20260917)

	var plate := ColorRect.new()
	plate.color = Color(0.15, 0.17, 0.13)
	plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(plate)

	_stage = Node2D.new()
	# **Lifted above the plate, because the mount draws below its rider.**
	# `MountRig` sits at `z_index = -1` so a horse is behind the person on it
	# from every angle - which on a bare diagnostic plate at z 0 puts it behind
	# the *plate*, and the first run of this tool photographed four Wardens
	# sitting on nothing. `blood_shot` records the same trap with
	# `BLOOD_GROUND_Z`; a diagnostic that draws nothing looks exactly like a
	# feature that draws nothing.
	_stage.z_index = 10
	add_child(_stage)
	_ground = float(SIZE.y) * 0.72

	var rule := Line2D.new()
	rule.add_point(Vector2(0.0, _ground))
	rule.add_point(Vector2(float(SIZE.x), _ground))
	rule.width = 1.0
	rule.default_color = GROUND_TINT
	_stage.add_child(rule)

	await get_tree().process_frame
	await _seated()
	await _turning()
	await _walking()
	await _ground_line()

	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 10:
		await get_tree().process_frame
	get_tree().quit(0)


## Every mount in the stable, with a Warden on each.
func _seated() -> void:
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		print("[mount-shot] the stable is empty")
		return
	var made: Array[Node2D] = []
	for index: int in stock.size():
		var across: float = float(SIZE.x) * (float(index) + 0.5) / float(stock.size())
		made.append(_pose(stock[index], Vector2(across, _ground), Vector2.DOWN,
			"idle"))
	await _shot("seated")
	_clear(made)


## One mount through all eight facings, rider and all.
##
## The rider takes its facing from `HeroAnimator` and the mount from `MountRig`,
## and those are two functions with the same index order - which is exactly the
## arrangement that goes quietly wrong. Eight pictures in one is how that is
## read in a second rather than argued about.
func _turning() -> void:
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		return
	var kind: MountData = stock[mini(1, stock.size() - 1)]
	var made: Array[Node2D] = []
	for index: int in 8:
		var angle: float = TAU * float(index) / 8.0
		var across: float = float(SIZE.x) * (float(index) + 0.5) / 8.0
		made.append(_pose(kind, Vector2(across, _ground),
			Vector2.from_angle(angle), "walk"))
	await _shot("turning")
	_clear(made)


## A walk cycle, sampled across its own length.
func _walking() -> void:
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		return
	var kind: MountData = stock[mini(1, stock.size() - 1)]
	var made: Array[Node2D] = []
	for index: int in 6:
		var across: float = float(SIZE.x) * (float(index) + 0.5) / 6.0
		var rig: Node2D = _pose(kind, Vector2(across, _ground), Vector2.RIGHT,
			"walk")
		# Each one driven a different distance into the cycle, so one picture
		# holds the whole stride instead of six copies of frame zero.
		var rider := rig as MountRig
		if rider != null:
			for _step: int in index * 3:
				rider._process(0.03)
		made.append(rig)
	await _shot("walking")
	_clear(made)


## A mounted Warden beside one on foot.
##
## The only picture that answers the question the arithmetic cannot: are the
## hooves on the same line as the boots. Every mount floated above it once, and
## nothing said so.
func _ground_line() -> void:
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		return
	var made: Array[Node2D] = []
	made.append(_pose(stock[0], Vector2(float(SIZE.x) * 0.35, _ground),
		Vector2.DOWN, "idle"))
	made.append(_warden(Vector2(float(SIZE.x) * 0.62, _ground), Vector2.DOWN))
	await _shot("ground")
	_clear(made)


## A mount with a Warden on it, standing on `at`.
##
## Built out of the real `MountRig` and the real hero sprite rather than out of
## two textures placed by hand: the whole question is whether *those two*
## agree, and a picture of something else answers nothing.
func _pose(kind: MountData, at: Vector2, facing: Vector2, state: String) -> Node2D:
	var root := Node2D.new()
	root.position = at
	_stage.add_child(root)

	var rider: Sprite2D = _warden_sprite(facing)
	root.add_child(rider)

	var rig := MountRig.new()
	rig.rider = rider
	root.add_child(rig)
	rig.show_mount(kind)
	rig.set_facing(facing)
	rig.play(state)
	# Straight into the saddle: the climb is its own subject and a photograph
	# caught part-way up would read as the seat being wrong.
	rig._climb = 1.0
	rig._process(0.016)
	return root


## A Warden on their own feet, for the comparison.
func _warden(at: Vector2, _facing: Vector2) -> Node2D:
	var root := Node2D.new()
	root.position = at
	_stage.add_child(root)
	root.add_child(_warden_sprite(Vector2.DOWN))
	return root


## The Warden, facing a direction, as `HeroAnimator` would draw them.
##
## The row is picked with the same expression the animator uses - index 0 is
## east and grows clockwise because screen Y grows downward - so this picture
## and the game cannot disagree about which way the rider is looking.
func _warden_sprite(facing: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if not ResourceLoader.exists(RIDER_SHEET):
		return sprite
	sprite.texture = load(RIDER_SHEET) as Texture2D
	sprite.region_enabled = true
	var step: float = TAU / float(HeroAnimator.DIRECTION_COUNT)
	var row: int = posmod(int(round(facing.angle() / step)),
		HeroAnimator.DIRECTION_COUNT)
	sprite.region_rect = Rect2(0.0, float(row * HeroAnimator.CELL_H),
		float(HeroAnimator.CELL_W), float(HeroAnimator.CELL_H))
	# Feet on the node, which is what the hero's own sprite does.
	sprite.offset = Vector2(0.0, -float(HeroAnimator.CELL_H) * 0.5)
	return sprite


func _clear(made: Array[Node2D]) -> void:
	for node: Node2D in made:
		node.queue_free()


func _shot(what: String) -> void:
	for _settle: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var frame: Image = get_viewport().get_texture().get_image()
	var path: String = "user://mount_shot_%s.png" % what
	frame.save_png(ProjectSettings.globalize_path(path))
	print("%s -> %s" % [what, ProjectSettings.globalize_path(path)])
