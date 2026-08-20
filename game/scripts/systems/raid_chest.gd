class_name RaidChest
extends Node2D

## A chest in a raid camp. Opened by standing on it; locked ones need a key.
##
## No prompt and no button. A raid is sixty seconds of being chased, and a
## chest that needs a keypress needs the player to stop being chased to press
## it — so proximity opens it and the decision stays "is it worth going there",
## which is the decision the camp's shape was built to pose.

const GROUP: StringName = &"raid_chests"
const SUPPLY_ART_ID: String = "supplies"
const RELIC_ART_ID: String = "relic"

var locked: bool = false

var _opened: bool = false
var _sprite: Sprite2D
var _glow: Sprite2D
var _life: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	_glow = Sprite2D.new()
	_glow.texture = LightKit.falloff_texture()
	_glow.modulate = Balance.LOOT_GLOW_COLOUR if not locked \
		else Balance.RAID_LOCKED_GLOW
	_glow.scale = Vector2.ONE * (Balance.RAID_CHEST_GLOW
		/ maxf(LightKit.falloff_texture().get_width(), 1.0))
	_glow.z_index = -1
	add_child(_glow)

	_sprite = Sprite2D.new()
	var art: String = art_path()
	if ResourceLoader.exists(art):
		_sprite.texture = load(art)
	_sprite.texture_filter = Graphics.canvas_filter() as CanvasItem.TextureFilter
	_sprite.add_to_group(Graphics.FILTER_GROUP)
	if locked:
		# Locked ones read cold until they are opened, so a player can tell
		# across the camp whether they need to go and find a key first.
		_sprite.modulate = Balance.RAID_LOCKED_TINT
	add_child(_sprite)
	ShadowKit.add_contact(self, _sprite)


## The common chest is provisions; the locked high-ground cache is the premium
## relic silhouette. Keeping the convention in one function lets the release
## gate exercise the same choice the player sees instead of duplicating it.
func art_path() -> String:
	var art_id: String = RELIC_ART_ID if locked else SUPPLY_ART_ID
	return Balance.LOOT_ART_FORMAT % art_id


func _process(delta: float) -> void:
	if _opened:
		return
	_life += delta
	if _sprite != null:
		_sprite.position.y = sin(_life * 2.2) * 2.0
	var hero: Node2D = get_tree().get_first_node_in_group(&"hero") as Node2D
	if hero == null or not is_instance_valid(hero):
		return
	if hero.global_position.distance_to(global_position) > Balance.RAID_REACH:
		return
	if locked and not RunState.spend_raid_key():
		return
	_open()


func _open() -> void:
	_opened = true
	var reward: int = Balance.RAID_LOCKED_CHEST_REWARD if locked \
		else Balance.RAID_CHEST_REWARD
	var tier: CampaignTierData = RunState.tier()
	if tier != null:
		reward = int(round(float(reward) * tier.loot_scale))
	# Paid as scattered drops rather than straight into the purse, so opening a
	# chest is a thing that happens on the ground in front of the player instead
	# of a number changing in the corner of the screen.
	var field: EnemyField = _field()
	for _piece: int in Balance.RAID_CHEST_PIECES:
		var share: int = maxi(1, reward / Balance.RAID_CHEST_PIECES)
		var currency: String = RunState.CURRENCIES[
			RunState.rng("raids").randi_range(0, RunState.CURRENCIES.size() - 1)]
		if field != null:
			field.spawn_loot(currency, share, global_position)
	# A locked chest always carries gear; an unlocked one sometimes does. That is
	# what makes finding the key worth the detour rather than a slower way to the
	# same coins.
	var tier_order: int = tier.order if tier != null else 0
	if locked or RunState.rng("raids").randf() < Balance.GEAR_CHEST_CHANCE:
		var piece: Dictionary = Stash.roll(ContentDB.gear_sorted(), tier_order,
			RunState.rng("raids"))
		if not piece.is_empty() and MetaState.take_gear(piece):
			var kind: GearData = ContentDB.gear(String(piece["kind"]))
			EventBus.preparation_warning.emit("%s  %s  ·  taken to the stash"
				% [Stash.rarity_name(piece), kind.display_name if kind else "Gear"])

	Sfx.play("sfx_relic_socket")
	Vfx.ring(global_position, Balance.RAID_CHEST_GLOW * 0.8,
		Balance.LOOT_GLOW_COLOUR, 0.5, 5.0)
	EventBus.raid_chest_opened.emit(locked)
	queue_free()


func _field() -> EnemyField:
	var parent: Node = get_parent()
	while parent != null:
		if parent is EnemyField:
			return parent as EnemyField
		parent = parent.get_parent()
	return null
