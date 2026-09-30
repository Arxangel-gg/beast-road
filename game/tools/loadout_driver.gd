extends Node

## **The whole Warden, at once** (2026-09-30, owner: *"60+fps even during the
## peaks of the heaviest waves of the last act and while the player is using
## all of their augments and skill abilities including ultimate abilities"*).
##
## Shared by `perf_check --loadout` and `perf_bisect --loadout`, so a bisect
## ranks what the same frame the check failed on is made of. It fills the hand
## with `CARDS` at their last level through the one door a draft takes a card
## through, slots `SPELLS` with the ultimate last, and every frame has the
## Warden stand at the thickest part of the fight swinging and casting every
## slot the moment it comes off cooldown, on a pool that never runs dry and a
## body that never falls - so what is measured is the load and not a Warden
## who died of it.

const CARDS: Array[String] = ["sunwheel", "stormcrown", "worldbreaker",
	"arcane_missiles", "flame_trail", "pyre_spirits", "sentry_wisps", "emberline"]
const SPELLS: Array[String] = ["thorn_volley", "ember_fall", "cinder_nova", "beasts_breath"]
## How often the Warden is stood again beside the body nearest the town.
const MOVE_SECONDS: float = 1.5

var cards: Array[String] = CARDS.duplicate()
var spells: Array[String] = SPELLS.duplicate()
var _warden: Hero = null
var _move_left: float = 0.0


## `--cards=a,b` and `--spells=a,b` replace the lists, so a cost can be
## bisected by what is held rather than guessed at. An empty list holds or
## casts nothing.
func read_arguments(arguments: PackedStringArray) -> void:
	for argument: String in arguments:
		if not (argument.begins_with("--cards=") or argument.begins_with("--spells=")):
			continue
		var named: Array[String] = []
		for piece: String in argument.split("=")[1].split(",", false):
			named.append(piece.strip_edges())
		if argument.begins_with("--cards="):
			cards = named
		else:
			spells = named


func arm() -> void:
	for id: String in cards:
		var card: RoadCardData = ContentDB.road_card(id)
		if card == null:
			push_warning("--loadout: no card '%s'" % id)
			continue
		for _level: int in card.max_level():
			RunState.take_road_card(id)
	RunState.equipped_spells.clear()
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		RunState.equipped_spells.append(spells[slot] if slot < spells.size() else "")
	EventBus.spells_changed.emit()
	var levels: PackedStringArray = []
	for id: String in RunState.road_cards:
		levels.append("%s %d" % [id, RunState.card_level(id)])
	print("[loadout] %s; spells %s" % [", ".join(levels), ", ".join(spells)])


func _process(delta: float) -> void:
	if not RunState.is_command_combat():
		return
	if _warden == null or not is_instance_valid(_warden):
		_warden = _find_warden()
		if _warden == null:
			return
		_warden.health.floor_hp = _warden.health.max_hp * 0.5
	var nearest: Enemy = null
	var best: float = INF
	for body: Node in get_tree().get_nodes_in_group(Enemy.GROUP):
		var enemy: Enemy = body as Enemy
		if enemy == null or not is_instance_valid(enemy):
			continue
		var gap: float = enemy.global_position.length_squared()
		if gap < best:
			best = gap
			nearest = enemy
	if nearest == null:
		return
	_move_left -= delta
	if _move_left <= 0.0:
		_move_left = MOVE_SECONDS
		# Beside the body nearest the town, a step back toward the wall - which
		# is where the wave is thickest once the road has brought it in.
		_warden.global_position = nearest.global_position - nearest.global_position.normalized() * 70.0
		_warden.velocity = Vector2.ZERO
	var aim: Vector2 = (nearest.global_position - _warden.global_position).normalized()
	if aim == Vector2.ZERO:
		aim = Vector2.RIGHT
	_warden.mana = _warden.mana_max()
	_warden.attack.request()
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		if _warden.spells.is_ready(slot):
			_warden.spells.try_cast(slot, aim, _warden.combat_origin())


func _find_warden() -> Hero:
	var pending: Array[Node] = [get_tree().root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Battlefield:
			var heroes: Array[Hero] = (node as Battlefield).heroes()
			return heroes[0] if not heroes.is_empty() else null
		pending.append_array(node.get_children())
	return null
