class_name HazardPlant
extends Node2D

## One harmful plant on the field (`HazardPlantData`, laid by `HazardPlants`).
##
## **Every blow but the thorns' is the mortar's blow**: a pod's burst, a mound's
## bite and a spit's splash each stand up an `EnemyGroundStrike` - the node every
## ranged breed's ground blow is thrown through - so the tell is drawn at the
## radius the blow will use, the riser swells toward it, the debrief names the
## plant, and the blow reaches the players, the bodies and the animals through
## the doors every other blow uses. Thorns are always out and are their own
## tell: they cut on a clock, and slow whoever is in them through
## `Vfx.ground_slow`, the one door a mover asks about the ground.
##
## **It wounds a body and never kills one** (`HAZARD_BODY_FLOOR`): a plant
## beside a camp would otherwise farm it for a purse nobody earned. An animal
## may die of one, as the cycle - nobody is paid and the earth does not mind.
##
## The host decides what it hurts. A guest's plants wake and close on what they
## see and hurt nobody - its heroes are the host's.

enum State { HIDDEN, WAKING, OUT, CLOSING, CUT }

var data: HazardPlantData = null
var field: Node = null

var state: int = State.OUT
## Blows this plant has thrown, and the times it was cut down. For the gate.
var blows: int = 0
var cut_downs: int = 0
var hp: float = 0.0

var _left: float = 0.0
var _cool: float = 0.0
var _tick: float = 0.0
var _idle_since: float = 0.0
var _frame_clock: float = 0.0
var _sprite: Sprite2D = null
var _base: Texture2D = null
var _hidden: Texture2D = null
var _idle: Array[Texture2D] = []
var _attack: Array[Texture2D] = []
var _target: Node2D = null
var _flinch: float = 0.0


func setup(plant: HazardPlantData, on: Node, phase: float) -> void:
	data = plant
	field = on
	hp = plant.max_hp
	_frame_clock = phase
	state = State.HIDDEN if plant.starts_hidden() else State.OUT


func _ready() -> void:
	add_to_group(HazardPlants.PLANT_GROUP)
	_sprite = Sprite2D.new()
	_sprite.name = "Plant"
	_sprite.centered = true
	add_child(_sprite)
	var path: String = data.get_sprite_path() if data != null else ""
	_base = load(path) as Texture2D if ResourceLoader.exists(path) else null
	var shut: String = data.hidden_path() if data != null else ""
	_hidden = load(shut) as Texture2D if not shut.is_empty() and ResourceLoader.exists(shut) else _base
	_idle = GameData.load_idle_frames(path) if not path.is_empty() else []
	_attack = GameData.load_attack_frames(path) if not path.is_empty() else []
	if data != null:
		_sprite.scale = Vector2.ONE * data.scale
	# Feet on the ground: the painting stands on the plant's own spot.
	_sprite.offset = Vector2(0.0, -(_base.get_height() * 0.5 - 6.0)) if _base != null else Vector2.ZERO
	_wear()
	EventBus.hero_swing_resolved.connect(_on_swing)


func _process(delta: float) -> void:
	if data == null:
		return
	_frame_clock += delta
	_flinch = maxf(_flinch - delta * 4.0, 0.0)
	_cool = maxf(_cool - delta, 0.0)
	match state:
		State.CUT:
			_left -= delta
			if _left <= 0.0:
				hp = data.max_hp
				state = State.HIDDEN if data.starts_hidden() else State.OUT
				Vfx.dust(global_position, Color(data.tint, 0.6), 4, 20.0)
		State.HIDDEN:
			if data.behaviour == HazardPlantData.Behaviour.SPORES:
				# A spent pod regrows when it has rested.
				if _cool <= 0.0:
					state = State.OUT
					Vfx.dust(global_position, Color(data.tint, 0.5), 3, 16.0)
			elif _cool <= 0.0:
				var near: Node2D = _nearest(data.spit_range if data.behaviour == HazardPlantData.Behaviour.SPITTER else data.trigger)
				if near != null:
					_wake(near)
		State.WAKING:
			_left -= delta
			if _left <= 0.0:
				state = State.OUT
				_idle_since = 0.0
				if data.behaviour == HazardPlantData.Behaviour.SPORES:
					# Spent: the pod has burst, and lies spent while it rests.
					state = State.HIDDEN
					_cool = data.cooldown
					_burst()
		State.OUT:
			_tick_out(delta)
		State.CLOSING:
			_left -= delta
			if _left <= 0.0:
				state = State.HIDDEN
	_wear()


## What it does while it is out.
func _tick_out(delta: float) -> void:
	match data.behaviour:
		HazardPlantData.Behaviour.THORNS:
			_tick -= delta
			if _tick <= 0.0:
				_tick = Balance.HAZARD_CONTACT_TICK
				_cut_the_waders()
		HazardPlantData.Behaviour.SPITTER:
			var near: Node2D = _nearest(data.spit_range)
			if near == null:
				_idle_since += delta
				if _idle_since >= data.out_seconds:
					_close()
				return
			_idle_since = 0.0
			if _cool <= 0.0:
				_spit(near)
		HazardPlantData.Behaviour.SPORES:
			if _cool <= 0.0:
				var near_pod: Node2D = _nearest(data.trigger)
				if near_pod != null:
					_wake(near_pod)
		HazardPlantData.Behaviour.SNAPPER:
			_idle_since += delta
			if _idle_since >= Balance.HAZARD_SNAP_LINGER:
				_close()
		_:
			_close()


## **Waking**: a pod swells and bursts, a mound rears and bites, a bud opens.
func _wake(near: Node2D) -> void:
	_target = near
	match data.behaviour:
		HazardPlantData.Behaviour.SPORES, HazardPlantData.Behaviour.SNAPPER:
			state = State.WAKING
			_left = data.telegraph
			_throw(global_position, data.telegraph)
			Sfx.play_at("sfx_hit_flesh" if data.behaviour == HazardPlantData.Behaviour.SNAPPER else "sfx_earth_shot",
				global_position, -8.0)
		HazardPlantData.Behaviour.SPITTER:
			state = State.WAKING
			_left = Balance.HAZARD_OPEN_SECONDS
			_cool = Balance.HAZARD_OPEN_SECONDS
		_:
			state = State.OUT


func _close() -> void:
	state = State.CLOSING
	_left = Balance.HAZARD_CLOSE_SECONDS
	_cool = data.cooldown


## **A pod bursts**: a cloud of its own colour hangs where it was and drifts
## with the wind. A picture - the blow was the strike the swelling stood up.
func _burst() -> void:
	var wind: Vector2 = RunState.wind * 20.0
	for index: int in 7:
		var off := Vector2.from_angle(TAU * float(index) / 7.0) * data.reach * 0.45
		Vfx.haze(global_position + off, wind + off * 0.3, Color(data.tint, 0.55), data.reach * 0.7, 2.6)
	Vfx.ring(global_position, data.reach, Color(data.tint, 0.7), 0.3, 4.0)


## **A spit**: a glob lobbed at where the thing will be, landing as a blow at
## the spit's own radius after the spit's own flight.
func _spit(at: Node2D) -> void:
	_cool = data.cooldown
	var aim: Vector2 = at.global_position
	var mover := at as CharacterBody2D
	if mover != null:
		aim += mover.velocity * data.telegraph * Balance.HAZARD_SPIT_LEAD
	var from: Vector2 = global_position + Vector2(0.0, -(_base.get_height() * 0.6 * data.scale if _base != null else 30.0))
	Vfx.streak(from, aim, data.telegraph, data.tint, "", Balance.VFX_STREAK_SIZE, Balance.HAZARD_SPIT_ARC, "lob")
	_throw(aim, data.telegraph)
	Sfx.play_at("sfx_water_shot", global_position, -6.0)
	_flinch = 1.0


## Stands up the blow: a ground strike at `at`, landing in `delay`.
func _throw(at: Vector2, delay: float) -> void:
	blows += 1
	if Coop.is_guest():
		return
	var strike := EnemyGroundStrike.new()
	strike.name = "PlantStrike"
	strike.shape = EnemyGroundStrike.Shape.CIRCLE
	strike.reach = data.reach
	strike.delay = maxf(delay, 0.05)
	strike.damage = _hero_blow()
	strike.tint = data.tint
	strike.blamed_on = data.display_name
	strike.hurts_bodies = data.body_share > 0.0
	strike.body_share = data.body_share
	strike.body_floor_share = Balance.HAZARD_BODY_FLOOR
	strike.body_field = field as EnemyField
	strike.animal_share = data.animal_share
	# **Under the plants, never the field's effect root**: that root is frozen in
	# Preparation - the very time a Warden is out gathering - so a pod swollen
	# then would have burst at the start of the next wave. The plants freeze
	# with the field for a raid, which is the only freeze a blow should wait on.
	var home := get_parent() as Node2D
	strike.position = at - home.global_position if home != null else at
	get_parent().add_child(strike)


## What a blow takes off a Warden: a share of the pool a Warden has.
func _hero_blow() -> float:
	var hero: Hero = null
	if field != null and "hero" in field:
		hero = field.get("hero") as Hero
	var pool: Health = Health.of(hero) if hero != null else null
	return (pool.max_hp if pool != null else Balance.HERO_MAX_HP) * data.hero_share


## **Thorns cut whatever is in them**, on a clock: Wardens, bodies off the road
## and animals, each a share of its own pool, a body never below the floor.
func _cut_the_waders() -> void:
	if Coop.is_guest():
		return
	var cut: bool = false
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not who.is_alive() or who.global_position.distance_to(global_position) > data.reach:
			continue
		var health: Health = Health.of(who)
		if health == null or not health.accepts_damage():
			continue
		var amount: float = health.max_hp * data.hero_share
		RunState.note_blow(data.display_name, amount)
		health.take_damage(amount, who.global_position)
		cut = true
	var enemies := field as EnemyField
	if enemies != null and data.body_share > 0.0:
		for body: Enemy in enemies.enemies_near(global_position, data.reach):
			if not is_instance_valid(body) or body.is_doomed():
				continue
			var pool: Health = Health.of(body)
			if pool == null:
				continue
			var amount: float = minf(pool.max_hp * data.body_share, pool.current_hp - pool.max_hp * Balance.HAZARD_BODY_FLOOR)
			if amount <= 0.0:
				continue
			DamageLedger.credit_as(DamageLedger.DEEP)
			body.take_damage(amount, global_position, 0.0)
			cut = true
	if data.animal_share > 0.0 and field != null and field.has_method("wildlife"):
		var wild: Wildlife = field.call("wildlife") as Wildlife
		if wild != null and wild.wound_where(func(at: Vector2) -> bool:
				return at.distance_to(global_position) <= data.reach, data.animal_share, "cycle", {}) > 0:
			cut = true
	if cut:
		blows += 1
		_flinch = 1.0
		Vfx.spark(global_position + Vector2(0.0, -14.0), data.tint, 4, Vector2.UP, 90.0)


## **The slow a mover feels standing at `at`**, 1.0 outside the thorns.
func slow_at(at: Vector2) -> float:
	if data == null or data.slow >= 1.0 or state == State.CUT:
		return 1.0
	return data.slow if at.distance_to(global_position) <= data.reach else 1.0


## The nearest thing inside `radius` this plant would wake for or spit at: a
## Warden not sheltered in the town, or a body **off the road**. Never an
## animal - an animal is hurt only when it is caught in a blow or wades into
## thorns - and never a body walking its route: a spitter in reach of a far
## leg would otherwise wound every column that came down it, which is a free
## tower the curve never priced.
func _nearest(radius: float) -> Node2D:
	var best: Node2D = null
	var best_d: float = radius * radius
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var who := node as Hero
		if who == null or not who.is_alive():
			continue
		if field != null and field.has_method("inside_city") and bool(field.call("inside_city", who.global_position)):
			continue
		var d: float = who.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = who
	var enemies := field as EnemyField
	if enemies != null:
		for body: Enemy in enemies.enemies_near(global_position, sqrt(best_d)):
			if is_instance_valid(body) and not body.is_doomed() and not _on_road(body.global_position):
				var d: float = body.global_position.distance_squared_to(global_position)
				if d < best_d:
					best_d = d
					best = body
	return best


## Whether a point is on a road or a tile beside one.
func _on_road(at: Vector2) -> bool:
	var grid: BattleGrid = field.get("grid") as BattleGrid if field != null and "grid" in field else null
	if grid == null:
		return false
	var tile: Vector2i = BattleGrid.world_to_tile(at)
	for dx: int in range(-1, 2):
		for dy: int in range(-1, 2):
			if grid.cell_at(tile + Vector2i(dx, dy)) == BattleGrid.Cell.ROAD:
				return true
	return false


## **A Warden can cut a plant down**, and it grows back.
func _on_swing(at: Vector2, aim: Vector2, reach: float, _step: int, _weapon_id: String, _own: bool) -> void:
	if state == State.CUT or data == null or Coop.is_guest():
		return
	var toward: Vector2 = global_position - at
	if toward.length() > reach + Balance.HAZARD_CUT_REACH:
		return
	if toward.length() > 8.0 and toward.normalized().dot(aim.normalized()) < 0.2:
		return
	hp -= Balance.HERO_ATTACK_DAMAGE[0]
	_flinch = 1.0
	Vfx.spark(global_position + Vector2(0.0, -16.0), data.tint, 6, toward.normalized(), 140.0)
	if hp <= 0.0:
		state = State.CUT
		_left = Balance.HAZARD_REGROW_SECONDS
		cut_downs += 1
		Vfx.dust(global_position, Color(data.tint.r * 0.6, data.tint.g * 0.6, data.tint.b * 0.5, 0.9), 8, 34.0)
		Sfx.play_at("sfx_footstep_heavy", global_position, -2.0)


## The painting for the state, the frame for the clock, and a flinch.
func _wear() -> void:
	if _sprite == null:
		return
	var texture: Texture2D = _base
	match state:
		State.HIDDEN, State.CUT:
			texture = _hidden
		State.WAKING, State.CLOSING:
			var frames: Array[Texture2D] = _attack if not _attack.is_empty() else _idle
			if not frames.is_empty():
				var through: float = 1.0 - clampf(_left / maxf(data.telegraph if state == State.WAKING else Balance.HAZARD_CLOSE_SECONDS, 0.01), 0.0, 1.0)
				if state == State.CLOSING:
					through = 1.0 - through
				texture = frames[clampi(int(through * float(frames.size())), 0, frames.size() - 1)]
		State.OUT:
			if not _idle.is_empty():
				var all: int = _idle.size() + 1
				var index: int = int(_frame_clock * Balance.HAZARD_FRAME_RATE) % all
				texture = _base if index == 0 else _idle[index - 1]
	if texture != null and _sprite.texture != texture:
		_sprite.texture = texture
	_sprite.modulate.a = 0.45 if state == State.CUT else 1.0
	var swell: float = 0.0
	if state == State.WAKING and data.behaviour == HazardPlantData.Behaviour.SPORES:
		swell = 0.25 * (1.0 - clampf(_left / maxf(data.telegraph, 0.01), 0.0, 1.0))
	_sprite.scale = Vector2.ONE * data.scale * (1.0 + swell + 0.06 * _flinch * sin(_frame_clock * 40.0))
	# A breath of its own on top of any painted loop, so a plant without one is
	# never a sticker, and two of a kind do not sway in step.
	_sprite.rotation = 0.0 if state == State.CUT else sin(_frame_clock * 1.6) * 0.035 * (1.0 + _flinch)
