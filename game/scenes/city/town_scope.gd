class_name TownScope
extends Node2D

## The town (GDD §5), laid out as a ring of plots around the Town Hall — the
## shape in References/Scope1(Town).png.
##
## Construction is gated by distance travelled, not resources and not real time,
## so this scope is mostly a place to make one decision and then go back to
## defending. One build slot at a time, on purpose.

const PLOT_RADIUS: float = 300.0

@export var plot_root: Node2D
@export var hall_sprite: Sprite2D
@export var ground: Sprite2D

## Each scope owns its camera; the run makes the right one current when the
## scope changes, so switching does not leave the view sitting in another scope.
@export var camera: Camera2D


func activate() -> void:
	if camera != null:
		camera.make_current()

## Emitted when the player picks a plot, so the town UI can open on it.
signal plot_selected(building_id: String)

var _plots: Dictionary = {}


func _ready() -> void:
	_setup_ground()
	_build_plots()
	EventBus.construction_completed.connect(_on_construction_completed)
	var hall: BuildingData = ContentDB.building("town_hall")
	if hall != null and ResourceLoader.exists(hall.get_sprite_path()):
		hall_sprite.texture = load(hall.get_sprite_path())


## The town sits on the beast's back, so it gets the same ground as the field.
func _setup_ground() -> void:
	if ground == null:
		return
	var extent: float = 1600.0
	ground.centered = true
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.region_rect = Rect2(-extent, -extent, extent * 2.0, extent * 2.0)
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null and ResourceLoader.exists(terrain.get_sprite_path()):
		ground.texture = load(terrain.get_sprite_path())


## Lays the non-hall buildings evenly around the ring. Their order comes from
## ContentDB, which sorts by plot angle, so adding a seventh building spaces
## itself without anyone editing a scene.
func _build_plots() -> void:
	var buildings: Array[BuildingData] = ContentDB.buildings_sorted()
	var ring: Array[BuildingData] = []
	for b: BuildingData in buildings:
		if not b.is_town_hall:
			ring.append(b)

	for i: int in ring.size():
		var data: BuildingData = ring[i]
		var angle: float = TAU * float(i) / float(maxi(ring.size(), 1)) - PI * 0.5
		var plot := _make_plot(data)
		plot.position = Vector2.RIGHT.rotated(angle) * PLOT_RADIUS
		plot_root.add_child(plot)
		_plots[data.id] = plot
	_refresh_all()


func _make_plot(data: BuildingData) -> Node2D:
	var root := Node2D.new()
	root.name = data.id

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	root.add_child(sprite)

	var button := Button.new()
	button.name = "Hit"
	button.flat = true
	button.size = Vector2(192, 192)
	button.position = Vector2(-96, -96)
	button.tooltip_text = data.display_name
	button.pressed.connect(func() -> void: plot_selected.emit(data.id))
	root.add_child(button)

	var label := Label.new()
	label.name = "Tier"
	label.position = Vector2(-96, 96)
	label.size = Vector2(192, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)

	return root


func refresh() -> void:
	_refresh_all()


func _refresh_all() -> void:
	for id: Variant in _plots:
		_refresh_plot(String(id))


func _refresh_plot(id: String) -> void:
	var plot: Node2D = _plots.get(id, null) as Node2D
	var data: BuildingData = ContentDB.building(id)
	if plot == null or data == null:
		return
	var tier: int = RunState.building_tier(id)
	var sprite := plot.get_node_or_null("Sprite") as Sprite2D
	var label := plot.get_node_or_null("Tier") as Label

	if sprite != null:
		# An unbuilt plot shows the empty-plot marker, not a ghost of the
		# building — the town should read as something you are assembling.
		var unlocked: bool = MetaState.building_unlocked(id)
		var art: String = data.get_sprite_path() if tier > 0 else (
			"res://art/city/plot_empty.png" if unlocked else "res://art/city/plot_locked.png")
		if ResourceLoader.exists(art):
			sprite.texture = load(art)
			sprite.modulate = Color.WHITE if tier > 0 else Color(1, 1, 1, 0.55 if unlocked else 0.34)

	if label != null:
		if tier > 0:
			label.text = "%s  ·  Tier %d" % [data.display_name, tier]
		elif not MetaState.building_unlocked(id):
			label.text = "%s  ·  LOCKED" % data.display_name
		elif _is_building_now(id):
			label.text = "%s  ·  building…" % data.display_name
		else:
			label.text = data.display_name


func _is_building_now(id: String) -> bool:
	return String(RunState.construction.get("id", "")) == id


func _on_construction_completed(building_id: String, _tier: int) -> void:
	_refresh_plot(building_id)


# --- Construction API (called by the town UI) -------------------------------

## Returns "" on success, or the reason the order was refused.
static func try_start_construction(building_id: String) -> String:
	if not RunState.can_build_now():
		return "Town projects are chosen during Preparation."
	if not RunState.construction.is_empty():
		return "Something is already being built."
	var data: BuildingData = ContentDB.building(building_id)
	if data == null:
		return "No such building."
	if not MetaState.building_unlocked(building_id):
		return "%s is not in the construction pool yet." % data.display_name
	var tier: int = RunState.building_tier(building_id)
	if tier >= data.max_tier:
		return "%s is fully built." % data.display_name
	var next_tier: int = tier + 1
	var wood_cost: int = data.wood_cost_at(next_tier)
	if not RunState.can_afford_cost({RunState.WOOD: wood_cost}):
		return "Needs %d Wood." % wood_cost
	RunState.spend_cost({RunState.WOOD: wood_cost})
	RunState.construction = {
		"id": building_id,
		"tier": next_tier,
		"distance_needed": BuildingData.tier_cost(next_tier),
		"distance_done": 0.0,
	}
	EventBus.construction_started.emit(building_id, next_tier)
	return ""


## Loss-making and bounded: there is no route through the Market that increases
## total currency, and every Preparation has a hard trade cap.
static func try_market_trade(from_id: String, to_id: String) -> String:
	if not RunState.can_build_now():
		return "The Market opens during Preparation."
	if RunState.building_tier("market") <= 0:
		return "Build the Trading Market first."
	if from_id == to_id or not RunState.CURRENCIES.has(from_id) \
			or not RunState.CURRENCIES.has(to_id):
		return "Choose two different currencies."
	if RunState.market_trades_remaining <= 0:
		return "No Market exchanges remain this Preparation."
	if not RunState.spend_cost({from_id: Balance.MARKET_TRADE_LOT}):
		return "Needs %d %s." % [Balance.MARKET_TRADE_LOT, RunState.currency_name(from_id)]
	RunState.gain_currency(to_id, Balance.MARKET_TRADE_RETURN)
	RunState.market_trades_remaining -= 1
	EventBus.market_traded.emit(from_id, to_id, Balance.MARKET_TRADE_LOT,
		Balance.MARKET_TRADE_RETURN)
	return ""


static func try_market_service() -> String:
	if not RunState.can_build_now():
		return "Market contracts are chosen during Preparation."
	if RunState.building_tier("market") <= 0:
		return "Build the Trading Market first."
	if RunState.market_service_bought_this_act():
		return "This act's Market contract is already claimed."
	var services: Array[String] = ["field_rations", "stonewright", "war_chest"]
	var id: String = services[clampi(RunState.act - 1, 0, services.size() - 1)]
	var costs: Array[Dictionary] = [
		{RunState.GOLD: 45}, {RunState.WOOD: 55}, {RunState.FOOD: 50},
	]
	var cost: Dictionary = costs[clampi(RunState.act - 1, 0, costs.size() - 1)]
	if not RunState.spend_cost(cost):
		return "Needs %s." % RunState.format_cost(cost)
	match id:
		"field_rations":
			RunState.gain_currency(RunState.FOOD, 32)
		"stonewright":
			RunState.gain_currency(RunState.STONE, 26)
		"war_chest":
			RunState.gain_currency(RunState.GOLD, 40)
	RunState.market_service_act = RunState.act
	RunState.market_service_id = id
	EventBus.market_service_bought.emit(id)
	return ""


static func try_assign_captive(captive_id: String, building_id: String) -> String:
	if not RunState.can_build_now():
		return "Work details are assigned during Preparation."
	var data: BuildingData = ContentDB.building(building_id)
	if data == null or not data.accepts_captives:
		return "That building takes no work detail."
	if RunState.building_tier(building_id) <= 0:
		return "Build it first."
	var captive: CaptiveData = ContentDB.captive(captive_id)
	if captive == null or not captive.can_work_at(building_id):
		return "Not suited to that work."
	var here: int = 0
	for value: Variant in RunState.captive_assignments.values():
		if String(value) == building_id:
			here += 1
	if here >= Balance.CAPTIVES_PER_BUILDING:
		return "No room there."
	RunState.captive_assignments[captive_id] = building_id
	EventBus.captive_assigned.emit(captive_id, building_id)
	return ""


static func try_socket_relic(relic_id: String) -> String:
	if not RunState.can_build_now():
		return "Relic sockets are changed during Preparation."
	if RunState.socketed_relics.size() >= RunState.relic_slot_count():
		return "No free sockets. Upgrade the Town Hall."
	if not RunState.held_relics.has(relic_id):
		return "You do not hold that relic."
	RunState.held_relics.erase(relic_id)
	RunState.socketed_relics.append(relic_id)
	EventBus.relic_socketed.emit(relic_id)
	return ""


static func unsocket_relic(relic_id: String) -> bool:
	if not RunState.can_build_now():
		return false
	if not RunState.socketed_relics.has(relic_id):
		return false
	RunState.socketed_relics.erase(relic_id)
	RunState.held_relics.append(relic_id)
	EventBus.relic_unsocketed.emit(relic_id)
	return true
