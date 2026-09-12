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
	CursorKit.use_default()

## Emitted when the player picks a plot, so the town UI can open on it.
signal plot_selected(building_id: String)

## Emitted when the player picks a merchant standing in the town.
signal merchant_selected(merchant_id: String)

var _plots: Dictionary = {}

## Per-building idle phase, so no two plots swell together. Keyed by building id
## because the plots themselves are rebuilt when the town changes.
var _idle_phases: Dictionary = {}
var _plot_idle_frames: Dictionary = {}
var _hall_idle_frames: Array[Texture2D] = []
var _idle_time: float = 0.0

## **How far to slide the view so the open panel does not sit on the ring.**
##
## `UiMetrics.dock_panel` docks the building sheet down the *left* of the screen
## at `UI_SIDE_PANEL_*` width - 680x1036 of a 1920x1080 screen, by design, not by
## accident. The plot ring is centred on the viewport, so the left of the ring
## lands underneath it: measured 2026-09-08, the watchtower plot sits at x
## 564-756 against a panel reaching x 702, and a click on it is swallowed by the
## panel rather than opening the building.
##
## Reported from play as buildings that cannot be selected. It reads as "some of
## them" because it depends on which plot the ring rotation happens to put on the
## left, and on how wide the dock is at that resolution - so a player sees a
## couple of dead buildings rather than an obvious layout fault.
##
## The camera slides instead of the panel shrinking: the sheet is a reading
## surface and narrowing it to clear the ring would cost the thing it is for.
var _view_inset: float = 0.0


## Called by the run when the building sheet opens or closes. Pixels of screen
## the sheet has taken, or 0.
func set_view_inset(pixels: float) -> void:
	_view_inset = maxf(pixels, 0.0)


func _ready() -> void:
	_setup_ground()
	_grounds = TownGrounds.new()
	_grounds.name = "Grounds"
	add_child(_grounds)
	move_child(_grounds, 1)
	_grounds.rebuild()
	EventBus.act_started.connect(func(_act: int, _terrain: String) -> void:
		_setup_ground()
		if _grounds != null:
			_grounds.rebuild())
	_build_plots()
	EventBus.construction_completed.connect(_on_construction_completed)
	# A merchant is drawn only while they are actually standing there, so every
	# signal that changes who is present has to redraw the yard. Through the bus
	# rather than a call from the run: the town does not know `MerchantYard`
	# exists and does not need to (working rule 5).
	EventBus.merchant_arrived.connect(func(_id: String) -> void: _refresh_merchants())
	EventBus.merchant_departed.connect(func(_id: String) -> void: _refresh_merchants())
	EventBus.merchant_stock_changed.connect(func(_id: String) -> void: _refresh_merchants())
	EventBus.merchant_settled.connect(func(_id: String) -> void: _refresh_merchants())
	_refresh_hall()
	_refresh_merchants()


## The town sits on the beast's back, so it gets the same ground as the field.
func _setup_ground() -> void:
	if ground == null:
		return
	var extent: float = 1600.0
	ground.centered = true
	ground.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	ground.region_enabled = true
	ground.material = TerrainSeam.material()
	ground.region_rect = Rect2(-extent, -extent, extent * 2.0, extent * 2.0)
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null and ResourceLoader.exists(terrain.get_sprite_path()):
		ground.texture = load(terrain.get_sprite_path())


## Lays the non-hall buildings evenly around the ring. Their order comes from
## ContentDB, which sorts by plot angle, so adding a seventh building spaces
## itself without anyone editing a scene.
## The town's idle.
##
## Authored frame loops carry the visible motion. The old breathe remains only
## for an unbuilt marker or a missing sequence, so art can arrive incrementally
## without leaving the scope frozen.
##
## Written straight to the sprite rather than through a channel sum, because
## nothing else animates a plot - if that ever changes this has to move to
## SpriteAnimator's model, the way the tower's did when the beast step arrived.
func _process(delta: float) -> void:
	_idle_time += delta
	# Half the inset, so the ring ends up centred in what is left of the screen
	# rather than shoved against the right edge. Eased rather than snapped: the
	# panel opens on a click and a hard jump reads as the town teleporting.
	if camera != null:
		var wanted: float = -_view_inset * 0.5
		camera.offset.x = move_toward(camera.offset.x, wanted,
			maxf(absf(camera.offset.x - wanted), 60.0) * delta * 6.0)
	var swing: float = _idle_time * Balance.STRUCTURE_IDLE_RATE * TAU
	for id: Variant in _plots:
		var plot: Node2D = _plots[id] as Node2D
		if plot == null:
			continue
		var sprite := plot.get_node_or_null("Sprite") as Sprite2D
		if sprite == null or sprite.texture == null:
			continue
		var phase: float = float(_idle_phases.get(id, 0.0)) + swing
		var frames: Array = _plot_idle_frames.get(String(id), [])
		if not frames.is_empty() and RunState.building_tier(String(id)) > 0:
			var clock: float = _idle_time * Balance.STRUCTURE_IDLE_FRAME_RATE \
				+ float(_idle_phases.get(id, 0.0)) / TAU * float(frames.size())
			var frame: int = int(floor(clock)) % frames.size()
			sprite.texture = frames[frame] as Texture2D
			sprite.scale = Vector2.ONE
			sprite.rotation = 0.0
		else:
			sprite.scale = Vector2.ONE * (1.0 + sin(phase) * Balance.STRUCTURE_IDLE_SCALE)
			sprite.rotation = deg_to_rad(sin(phase * 0.63) * Balance.STRUCTURE_IDLE_SWAY)

	if hall_sprite != null and not _hall_idle_frames.is_empty():
		var hall_frame: int = int(floor(_idle_time * Balance.STRUCTURE_IDLE_FRAME_RATE)) \
			% _hall_idle_frames.size()
		hall_sprite.texture = _hall_idle_frames[hall_frame]
		hall_sprite.scale = Vector2.ONE
	elif hall_sprite != null:
		# The hall swells a little less: it is the biggest thing on screen and the
		# same fraction on it is a much larger movement.
		var swell: float = 1.0 + sin(swing) * Balance.STRUCTURE_IDLE_SCALE * 0.6
		hall_sprite.scale = Vector2.ONE * swell

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
	# Scattered so the town breathes out of step. In unison it reads as the whole
	# screen pulsing rather than as a place with people in it.
	_idle_phases[data.id] = randf() * TAU

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


# --- The merchants' corner ---------------------------------------------------
#
# Visitors stand *inside* the ring rather than taking a plot on it. Three
# reasons, in order of how much they cost to get wrong:
#
# 1. There are eight plots and nine buildings, and the ring is laid out by
#    dividing the circle by however many buildings exist. A merchant on the ring
#    would move every building in town every time one arrived.
# 2. A plot is a thing you commission and keep. A merchant is a thing that
#    turns up and leaves. Drawing them the same way says the wrong thing about
#    both.
# 3. The building sheet docks down the left of the screen, which is the fault
#    `set_view_inset` exists to correct. Standing the visitors on the right of
#    the inner circle keeps them clear of it even before the camera slides.

## The clear annulus between the Town Hall and the plot ring.
##
## Measured rather than chosen: the hall is a 192px sprite at the centre, so it
## reaches radius 96; the plots sit at radius 300 with 192px sprites, so they
## begin at radius 204. That leaves a band a hundred pixels wide, and a 128px
## merchant centred in it clears both. The first placement used 178 and put the
## Alchemist through the Woodcutter's roof.
const MERCHANT_RADIUS: float = 150.0

## Where each visitor stands, by arrival order.
##
## Along the bottom of the inner circle, for two reasons that are both about
## what else is on the screen. The building sheet docks down the *left* and the
## camera slides the town right to clear it - so anything parked on the right
## can be pushed toward the edge, and anything on the left starts underneath the
## panel. The bottom is the one arc neither thing touches.
##
## Fixed angles rather than a division of the arc, so the second merchant
## arriving never moves the first. A shop that walks across the screen when its
## neighbour turns up is the ring's own layout problem, one radius in.
const MERCHANT_ANGLES: Array[float] = [48.0, 90.0, 132.0]

## Vertical offset of each visitor's caption, by the same index.
##
## Staggered because the captions are 192px wide and three merchants on a
## 150-radius arc are only about 100px apart: at one height they overprint into
## an unreadable smear, which is what the first screenshot of three visitors
## showed. Three rows is the cheapest fix that keeps every name legible and
## still leaves each caption under its own merchant.
const MERCHANT_LABEL_ROWS: Array[float] = [58.0, 86.0, 114.0]

var _merchant_nodes: Dictionary = {}
## The land around the ring: the region's trees, plants and a worn circle
## of ground, laid from the seed. See `TownGrounds`.
var _grounds: TownGrounds = null


func _refresh_merchants() -> void:
	var here: Array[String] = MerchantYard.in_town()
	for key: Variant in _merchant_nodes.keys():
		if not here.has(String(key)):
			var gone := _merchant_nodes[key] as Node2D
			if is_instance_valid(gone):
				gone.queue_free()
			_merchant_nodes.erase(key)

	for i: int in here.size():
		var id: String = here[i]
		var data: MerchantData = ContentDB.merchant(id)
		if data == null:
			continue
		var node := _merchant_nodes.get(id, null) as Node2D
		if node == null or not is_instance_valid(node):
			node = _make_merchant(data)
			plot_root.add_child(node)
			_merchant_nodes[id] = node
		node.position = Vector2.RIGHT.rotated(
			deg_to_rad(MERCHANT_ANGLES[i % MERCHANT_ANGLES.size()])) * MERCHANT_RADIUS
		var tag := node.get_node_or_null("Tag") as Label
		if tag != null:
			tag.position = Vector2(-96.0,
				MERCHANT_LABEL_ROWS[i % MERCHANT_LABEL_ROWS.size()])
		_dress_merchant(id, node)


func _make_merchant(data: MerchantData) -> Node2D:
	var root := Node2D.new()
	root.name = "merchant_%s" % data.id

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	if ResourceLoader.exists(data.get_sprite_path()):
		sprite.texture = load(data.get_sprite_path())
	root.add_child(sprite)

	var button := Button.new()
	button.name = "Hit"
	button.flat = true
	button.size = Vector2(128, 128)
	button.position = Vector2(-64, -64)
	button.tooltip_text = data.display_name
	button.pressed.connect(func() -> void: merchant_selected.emit(data.id))
	root.add_child(button)

	var label := Label.new()
	label.name = "Tag"
	label.size = Vector2(192, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(label)

	_idle_phases[root.name] = randf() * TAU
	return root


func _dress_merchant(id: String, node: Node2D) -> void:
	var label := node.get_node_or_null("Tag") as Label
	if label == null:
		return
	var data: MerchantData = ContentDB.merchant(id)
	var left: int = MerchantYard.waves_left(id)
	if left < 0:
		label.text = "%s  ·  resident" % data.display_name
		label.modulate = Color("cbb682")
	else:
		# The countdown is the whole reason a traveller is interesting, so it is
		# on the sprite rather than inside the sheet. An offer you have to open a
		# panel to discover is expiring is an offer that expires unnoticed.
		label.text = "%s  ·  leaves in %d" % [data.display_name, left]
		label.modulate = Color("d98f5a") if left <= 1 else Color("b8ae98")


func refresh() -> void:
	_refresh_all()
	_refresh_merchants()


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
		var art: String = data.get_sprite_path_for_tier(tier) if tier > 0 else (
			"res://art/city/plot_empty.png" if unlocked else "res://art/city/plot_locked.png")
		if ResourceLoader.exists(art):
			sprite.texture = load(art)
			sprite.modulate = Color.WHITE if tier > 0 else Color(1, 1, 1, 0.55 if unlocked else 0.34)
		_plot_idle_frames[id] = GameData.load_idle_frames(art) if tier > 0 else []

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
	if building_id == "town_hall":
		_refresh_hall()
	else:
		_refresh_plot(building_id)


func _refresh_hall() -> void:
	var hall: BuildingData = ContentDB.building("town_hall")
	if hall == null or hall_sprite == null:
		return
	var art: String = hall.get_sprite_path_for_tier(RunState.building_tier(hall.id))
	if ResourceLoader.exists(art):
		hall_sprite.texture = load(art)
	_hall_idle_frames = GameData.load_idle_frames(art)


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
		return "Duties are assigned during Preparation."
	var data: BuildingData = ContentDB.building(building_id)
	if data == null or not data.accepts_captives:
		return "That building takes no duty."
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
