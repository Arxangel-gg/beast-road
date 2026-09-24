class_name DungeonAir
extends Node2D

## The air of the deep (2026-09-14): dust hanging in a dungeon's corridors and
## water dripping from a ceiling nobody can see; violet embers rising through
## a rift's cavern.
##
## One node and one `_draw`, around whatever the camera is looking at: a
## pool of motes that wander, respawned on the far side when they leave the
## view, and a drip now and then that falls, lands with a ring and a wet tick.
## It is the difference between a place and a picture of one, and it costs a
## few dozen textured quads a frame. Nothing reads it.

var kind: int = RiftArena.Kind.DUNGEON
var camera: Camera2D = null
var layout: DungeonLayout = null

var _motes: Array[Dictionary] = []
var _drips: Array[Dictionary] = []
var _drip_in: float = 0.0
var _rng := RandomNumberGenerator.new()
var _running: bool = false


func _ready() -> void:
	z_index = Balance.DUNGEON_AIR_Z
	y_sort_enabled = false
	# Decoration's own dice: nothing here may move a roll that matters.
	_rng.randomize()


## A stage opened: the air is that kind's, over that floor.
func begin(which: int, floor_layout: DungeonLayout) -> void:
	kind = which
	layout = floor_layout
	_running = true
	_motes.clear()
	_drips.clear()
	var view: Rect2 = _view()
	for _i: int in Balance.DUNGEON_MOTES:
		_motes.append(_new_mote(view, true))
	_drip_in = _rng.randf_range(Balance.DUNGEON_DRIP_SECONDS.x, Balance.DUNGEON_DRIP_SECONDS.y)
	if kind == RiftArena.Kind.RIFT:
		var additive: CanvasItemMaterial = LightKit.additive_material()
		material = additive
	else:
		material = null
	queue_redraw()


func stop() -> void:
	_running = false
	_motes.clear()
	_drips.clear()
	queue_redraw()


func mote_count() -> int:
	return _motes.size()


func _view() -> Rect2:
	if camera == null or not is_instance_valid(camera):
		return Rect2(-960.0, -540.0, 1920.0, 1080.0)
	var size: Vector2 = get_viewport_rect().size / camera.zoom
	return Rect2(camera.get_screen_center_position() - size * 0.5, size)


func _new_mote(view: Rect2, anywhere: bool) -> Dictionary:
	var rising: bool = kind == RiftArena.Kind.RIFT
	var at: Vector2
	if anywhere or not rising:
		at = Vector2(_rng.randf_range(view.position.x, view.end.x),
			_rng.randf_range(view.position.y, view.end.y))
	else:
		# An ember is born low in the view and rises through it.
		at = Vector2(_rng.randf_range(view.position.x, view.end.x), view.end.y + 20.0)
	var velocity: Vector2
	if rising:
		velocity = Vector2(_rng.randf_range(-8.0, 8.0), -_rng.randf_range(16.0, 42.0))
	else:
		velocity = Vector2.RIGHT.rotated(_rng.randf() * TAU) * _rng.randf_range(4.0, 12.0)
	return {
		"at": at, "vel": velocity,
		"size": _rng.randf_range(2.0, 5.0) if rising else _rng.randf_range(3.0, 7.0),
		"phase": _rng.randf() * TAU,
		"alpha": _rng.randf_range(0.3, 0.7) if rising else _rng.randf_range(0.14, 0.34),
	}


func _process(delta: float) -> void:
	if not _running:
		return
	var view: Rect2 = _view().grow(40.0)
	for index: int in _motes.size():
		var mote: Dictionary = _motes[index]
		var at: Vector2 = mote["at"]
		var phase: float = float(mote["phase"]) + delta
		at += (mote["vel"] as Vector2) * delta + Vector2(sin(phase * 0.9), cos(phase * 0.7)) * 6.0 * delta
		if not view.has_point(at):
			_motes[index] = _new_mote(view, false)
			if kind == RiftArena.Kind.DUNGEON:
				# Dust drifts back in from whichever edge it left by.
				var fresh: Dictionary = _motes[index]
				var spot: Vector2 = fresh["at"]
				if at.x < view.position.x:
					spot.x = view.end.x - 2.0
				elif at.x > view.end.x:
					spot.x = view.position.x + 2.0
				if at.y < view.position.y:
					spot.y = view.end.y - 2.0
				elif at.y > view.end.y:
					spot.y = view.position.y + 2.0
				fresh["at"] = spot
			continue
		mote["at"] = at
		mote["phase"] = phase
	if kind == RiftArena.Kind.DUNGEON:
		_tick_drips(delta, view)
	queue_redraw()


func _tick_drips(delta: float, view: Rect2) -> void:
	_drip_in -= delta
	if _drip_in <= 0.0:
		_drip_in = _rng.randf_range(Balance.DUNGEON_DRIP_SECONDS.x, Balance.DUNGEON_DRIP_SECONDS.y)
		for _try: int in 6:
			var at := Vector2(_rng.randf_range(view.position.x, view.end.x),
				_rng.randf_range(view.position.y, view.end.y))
			if layout == null or layout.is_open(at):
				_drips.append({"at": at, "t": 0.0})
				break
	var index: int = 0
	while index < _drips.size():
		var drip: Dictionary = _drips[index]
		drip["t"] = float(drip["t"]) + delta
		if float(drip["t"]) >= Balance.DUNGEON_DRIP_FALL:
			var at: Vector2 = drip["at"]
			Vfx.ring(at, 14.0, Color(0.8, 0.9, 1.0, 0.55), 0.45, 1.5)
			Sfx.play("sfx_fish_nibble", -14.0)
			_drips.remove_at(index)
			continue
		index += 1


func _draw() -> void:
	if not _running:
		return
	var dot: Texture2D = Flame.dot_texture()
	var tint: Color = Color(0.82, 0.55, 1.0) if kind == RiftArena.Kind.RIFT else Color(0.8, 0.76, 0.68)
	for mote: Dictionary in _motes:
		var size: float = float(mote["size"])
		var alpha: float = float(mote["alpha"]) * (0.6 + 0.4 * sin(float(mote["phase"]) * 1.7))
		draw_texture_rect(dot, Rect2((mote["at"] as Vector2) - Vector2.ONE * size, Vector2.ONE * size * 2.0),
			false, Color(tint, alpha))
	for drip: Dictionary in _drips:
		var u: float = clampf(float(drip["t"]) / Balance.DUNGEON_DRIP_FALL, 0.0, 1.0)
		var y: float = lerpf(-170.0, 0.0, u * u)
		var at: Vector2 = drip["at"]
		draw_line(at + Vector2(0.0, y - 9.0), at + Vector2(0.0, y), Color(0.82, 0.9, 1.0, 0.75), 1.5)
