class_name WardShell
extends Node2D

## **A ward is a shell of light round the Warden** (owner, 2026-10-01: *"Player
## needs a shield visualizer that is juicy and aesthetically appealing and
## affected by amount of shield visually"*). The bar's bright segment says how
## much ward there is to somebody reading the bar; this says it to somebody
## watching the fight.
##
## **How much is the whole picture.** The shell's strength is the ward's share
## of the most a Warden may hold (`HEALTH_SHIELD_CEILING`), eased on the screen
## so a ward that arrives in steps rises rather than flickers: a sliver is a thin
## rim, a full ward is a thick bright shell with lit seams and a band of light
## climbing it, and the shell itself grows by `WARD_SHELL_GROWTH` between the
## two. What is left of the ward it last rose to is drawn as cells going dark,
## so a ward being worn through looks worn through.
##
## **It answers what happens to it.** A blow it pays for flashes where it
## landed and sends a ripple round the shell; a ward granted runs a bright rim
## in from the edge; a ward emptied breaks into shards with a ring of its own.
##
## **Read by nothing.** No number, no roll, no message: the fog's bound and the
## set aura's. Every Warden wears their own, so a partner's ward is seen too.

const SHADER: Shader = preload("res://scripts/shaders/ward_shell.gdshader")
## The quad's size over the shell's; `ward_shell.gdshader` holds the same.
const HALO: float = 1.16

var hero: Hero = null

var _material: ShaderMaterial = null
var _shown: float = 0.0
var _presence: float = 0.0
var _peak: float = 0.0
var _last: float = 0.0
var _flash: float = 0.0
var _rise: float = 0.0
var _hit_dir: Vector2 = Vector2.ZERO
var _struck_from: Vector2 = Vector2.INF
var _white: Texture2D = null


func _ready() -> void:
	name = "WardShell"
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter("tint", Balance.WARD_NUMBER_COLOUR)
	_material.set_shader_parameter("seed", fmod(float(get_instance_id() % 997) * 0.618, 7.0))
	material = _material
	var image := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	_white = ImageTexture.create_from_image(image)
	if hero != null and hero.health != null:
		hero.health.shield_changed.connect(_on_shield_changed)
		hero.health.damaged.connect(_on_damaged)
		_last = hero.health.shield()
	visible = false


## Where the blow came from, kept for the shield's own reading of it: a blow
## the ward pays for in full is still reported as `damaged`, with nothing taken.
func _on_damaged(_amount: float, from: Vector2) -> void:
	_struck_from = from


func _on_shield_changed(remaining: float) -> void:
	var ceiling: float = maxf(_ceiling(), 1.0)
	if remaining > _last + 0.5:
		_rise = 1.0
		_peak = maxf(_peak, remaining) if _last > 0.5 else remaining
	elif remaining < _last - 0.01:
		var taken: float = _last - remaining
		_flash = minf(_flash + Balance.WARD_SHELL_FLASH_FLOOR
			+ taken / ceiling * Balance.WARD_SHELL_FLASH_PER_SHARE, 1.0)
		_hit_dir = _direction_of(_struck_from)
		if remaining <= 0.5 and _last > 0.5:
			_break()
	_last = maxf(remaining, 0.0)


func _ceiling() -> float:
	if hero == null or hero.health == null:
		return 1.0
	return hero.health.max_hp * Balance.HEALTH_SHIELD_CEILING


## How much ward this is, as a share of the most a Warden may hold.
func strength_target() -> float:
	return clampf(_last / maxf(_ceiling(), 1.0), 0.0, 1.0)


## The shell's own centre, round the body rather than at the feet the Hero's
## origin stands on - and in the saddle with its rider.
func _centre() -> Vector2:
	var lift: float = hero.combat_origin().y - hero.global_position.y if hero != null else -68.0
	var seat: Vector2 = MountRig.seat_of(hero.sprite) if hero != null and hero.sprite != null \
		else Vector2.ZERO
	return Vector2(seat.x, lift * Balance.WARD_SHELL_CENTRE + seat.y)


func _radius() -> Vector2:
	return Balance.WARD_SHELL_RADIUS * (1.0 + Balance.WARD_SHELL_GROWTH * _shown)


func _direction_of(from: Vector2) -> Vector2:
	if from == Vector2.INF or hero == null:
		return Vector2.ZERO
	var toward: Vector2 = from - (hero.global_position + _centre())
	if toward.length_squared() < 1.0:
		return Vector2.ZERO
	var radius: Vector2 = _radius()
	return Vector2(toward.x / radius.x, toward.y / radius.y).limit_length(1.0)


## The ward is spent: the shell breaks into shards, a ring leaves it and the
## glass rings once.
func _break() -> void:
	if hero == null:
		return
	var at: Vector2 = hero.global_position + _centre()
	var colour: Color = Balance.WARD_NUMBER_COLOUR
	var shards: int = maxi(int(round(Balance.WARD_SHELL_SHARDS * Graphics.particle_scale())), 3)
	Vfx.spark(at, colour.lightened(0.25), shards, Vector2.ZERO, 260.0)
	Vfx.ring(at, _radius().x * 1.35, Color(colour, 0.75), 0.32, 3.0)
	Vfx.flash_at(at, colour, _radius().x * 1.1)
	Sfx.play_group_at("sfx_hit_armour", at)


func _process(delta: float) -> void:
	if hero == null or not is_instance_valid(hero) or hero.health == null:
		visible = false
		return
	var target: float = strength_target()
	var rate: float = Balance.WARD_SHELL_RISE if target > _shown else Balance.WARD_SHELL_FALL
	_shown = move_toward(_shown, target, rate * delta)
	var wanted: float = 1.0 if _last > 0.5 and not hero.health.is_dead else 0.0
	_presence = move_toward(_presence, wanted, delta / Balance.WARD_SHELL_FADE)
	_flash = maxf(_flash - delta / Balance.WARD_SHELL_FLASH_SECONDS, 0.0)
	_rise = maxf(_rise - delta / Balance.WARD_SHELL_RISE_SECONDS, 0.0)
	if _last <= 0.5:
		_peak = 0.0
	visible = _presence > 0.001
	if not visible:
		return
	var integrity: float = clampf(_last / _peak, 0.0, 1.0) if _peak > 0.5 else 1.0
	# A ward too thin to pick out still says it is there.
	var strength: float = maxf(_shown, Balance.WARD_SHELL_STRENGTH_FLOOR)
	_material.set_shader_parameter("strength", strength)
	_material.set_shader_parameter("presence", _presence)
	_material.set_shader_parameter("integrity", integrity)
	_material.set_shader_parameter("flash", _flash)
	_material.set_shader_parameter("hit_dir", _hit_dir)
	_material.set_shader_parameter("rise", _rise)
	queue_redraw()


func _draw() -> void:
	# Drawn `HALO` times the shell, which the shader takes back out, so the glow
	# round it has somewhere to fall.
	var radius: Vector2 = _radius() * HALO
	var centre: Vector2 = _centre()
	draw_texture_rect(_white, Rect2(centre - radius, radius * 2.0), false)


## For the gate: the shell's eased strength, presence and what it last saw.
func shown() -> float:
	return _shown


func presence() -> float:
	return _presence


func flash_level() -> float:
	return _flash


func radius() -> Vector2:
	return _radius()
