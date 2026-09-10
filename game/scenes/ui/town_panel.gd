class_name TownPanel
extends CanvasLayer

const KeywordTextScript = preload("res://scripts/systems/keyword_text.gd")

## The town's management surface (GDD §5).
##
## Opens on whichever plot the player clicked. Everything it does goes through
## TownScope's static API, which is the part that was already tested — this
## script only draws what RunState says and offers the moves that are legal.
##
## One build slot at a time is enforced by the API, not here, so the panel can
## never disagree with the run about what is under construction.
##
## ## Docked left, above the HUD, bounded by the screen
##
## Three reports in one message - "too far to the right, even going off screen",
## "after upgrading a building the close button doesn't work", "should be on the
## left side along with all other building panels" - were two faults.
##
## The sheet was anchored to the *right* edge at a fixed 428 units wide, and a
## `Control` grows from its top-left when its content needs more than its offsets
## describe. A cost line like "Build tier 1 · 80 Wood · 150 distance" reports a
## 412-unit minimum on its own, and considerably more at touch font sizes - so
## the sheet grew off the right of the screen, taking the right half of every row
## with it. `UiMetrics.dock_panel` gives it a rect measured from the screen and
## `UiMetrics.wrap_row` makes every row wrap instead of widen, so the content can
## no longer push the container around.
##
## And it sat on **layer 8 while the HUD is on layer 20**, so the combat rail was
## drawn over it and, far worse, took the taps first: the Close button was
## underneath the right-hand scope rail. That is the whole of "the close button
## doesn't work". It is layer 24 now - a sheet opened from the world is modal
## over the interface, not under it.

@export var panel: PanelContainer
@export var title: Label
@export var subtitle: Label
@export var tabs: HBoxContainer
@export var notice: Label
@export var body: RichTextLabel
@export var actions: VBoxContainer
@export var progress: ProgressBar
@export var progress_label: Label
@export var scroll: ScrollContainer
@export var close_button: Button

var _building_id: String = ""

## The Mansion's sub-page. A phone cannot show levelling, a loadout, this road's
## offers and the whole tree in one column and have any of it be readable.
enum Mansion { HERO, TRAINING, TREE }
var _mansion_page: int = Mansion.HERO

## Which ability slot the player is currently choosing for, or -1.
var _slot_focus: int = -1

## Which discipline the tree page is filtered to, or -1 for all.
var _tree_filter: int = -1


func _ready() -> void:
	panel.visible = false
	UiMetrics.prepare_scroll(scroll, TouchInput.is_showing())
	close_button.pressed.connect(close)
	_fit()
	get_viewport().size_changed.connect(_fit)
	EventBus.construction_started.connect(func(_id: String, _t: int) -> void: _refresh())
	EventBus.construction_progress.connect(_on_progress)
	EventBus.construction_completed.connect(func(_id: String, _t: int) -> void: _refresh())
	EventBus.relic_socketed.connect(func(_id: String) -> void: _refresh())
	EventBus.relic_unsocketed.connect(func(_id: String) -> void: _refresh())
	EventBus.captive_assigned.connect(func(_c: String, _b: String) -> void: _refresh())
	EventBus.discipline_trained.connect(func(_id: String, _food: int) -> void: _refresh())
	EventBus.discipline_equipped.connect(func(_slot: int, _id: String) -> void: _refresh())
	EventBus.discipline_respecced.connect(func(_food: int, _uses: int) -> void: _refresh())


func _fit() -> void:
	UiMetrics.dock_panel(panel)


## Which merchant this sheet is showing, or "" when it is showing a building.
##
## A separate field rather than a prefixed building id. The whole sheet keys off
## `ContentDB.building(_building_id)`, and smuggling a merchant through that
## lookup as `"merchant:alchemist"` would mean every one of those callers now has
## a string it has to know not to trust.
var _merchant_id: String = ""


## Opens a merchant's shelf. Same panel, same dock, same close button - a
## visitor is a thing in the town, not a modal that takes the screen.
func open_merchant(merchant_id: String) -> void:
	_merchant_id = merchant_id
	_building_id = ""
	panel.visible = true
	_fit()
	_clear_notice()
	_refresh()


func open(building_id: String) -> void:
	_merchant_id = ""
	if building_id != _building_id:
		# A different plot is a different subject: the page, the slot being
		# chosen for and any complaint about the last one all belong to the sheet
		# the player just closed.
		_mansion_page = Mansion.HERO
		_slot_focus = -1
		_tree_filter = -1
	_building_id = building_id
	panel.visible = true
	_fit()
	_clear_notice()
	_refresh()


## Emitted when the sheet stops covering the screen, so the town can slide back.
signal closed


## Made on first use and kept: the stash is ninety-six rows and rebuilding it
## every visit is a stutter in the middle of a wave.
var _stash: StashScreen = null

## Kept for the same reason, and reached from the same place.
var _ledger: ExchangeScreen = null


func _open_stash() -> void:
	if _stash == null or not is_instance_valid(_stash):
		_stash = StashScreen.new()
		add_child(_stash)
		# The sheet under it is showing worn attributes that the stash can
		# change, so it has to be redrawn when the stash closes.
		_stash.closed.connect(_refresh)
	_stash.open()


## **The Ledger, reachable from inside a run - which is where it matters most.**
##
## Orders fill on road travelled and on nothing else, so the middle of a journey
## is exactly when a line gets met. A marketplace that could only be opened from
## the main menu would mean quitting to the menu to find out, which is the one
## thing the design is arranged to avoid: the Ledger pays you for playing.
##
## Beside the stash rather than anywhere else because it is the stash's other
## half. "Is this sword worth keeping", "should I break it", and "what would a
## caravan give me for it" are one decision asked from three directions.
func _open_ledger() -> void:
	if _ledger == null or not is_instance_valid(_ledger):
		_ledger = ExchangeScreen.new()
		add_child(_ledger)
		_ledger.closed.connect(_refresh)
	_ledger.open()


func close() -> void:
	panel.visible = false
	closed.emit()


## How much screen the docked sheet is taking, or 0 when it is not showing.
## The town uses this to move the plot ring out from under it.
func docked_width() -> float:
	if panel == null or not panel.visible:
		return 0.0
	return panel.size.x + panel.position.x


func is_open() -> bool:
	return panel.visible


func _on_progress(building_id: String, ratio: float) -> void:
	if building_id != String(RunState.construction.get("id", "")):
		return
	progress.value = ratio
	progress_label.text = "%d%%" % int(ratio * 100.0)


# --- Row factories -----------------------------------------------------------
#
# Every control in this sheet comes from one of these. That is not tidiness: a
# row built by hand is a row that forgot to wrap, and one such row is enough to
# push the whole panel off the screen again.

func _row(text: String, height: float = 44.0) -> Button:
	var button := Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = height
	UiMetrics.wrap_row(button)
	return button


func _line(text: String, size: int = 14, colour: Color = Color("b8ae98")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	UiMetrics.wrap_row(label)
	return label


func _heading(text: String) -> Label:
	return _line(text.to_upper(), 16, Color("e8a33d"))


func _note(text: String) -> void:
	actions.add_child(_line(text, 15))


## A complaint the player must actually be able to read.
##
## **This is why the Mansion was unreadable.** Every rejection in this sheet was
## written as `_note(problem)` followed by `_refresh()`, and `_refresh()` frees
## every child of the actions column - so the explanation was destroyed on the
## frame it was created. Pressing a card did nothing, said nothing, and left the
## player to guess which of four separate requirements they had failed. The
## notice lives outside the column and survives the rebuild.
func _flash(text: String) -> void:
	if text.is_empty():
		_clear_notice()
		return
	notice.text = "!  %s" % text
	notice.add_theme_color_override("font_color", Color("e2705a"))
	notice.visible = true


func _clear_notice() -> void:
	notice.text = ""
	notice.visible = false


## Runs a move and keeps whatever it had to say about refusing.
func _attempt(problem: String) -> void:
	_flash(problem)
	_refresh()


# --- Drawing -----------------------------------------------------------------

func _refresh() -> void:
	for child: Node in tabs.get_children():
		tabs.remove_child(child)
		child.queue_free()
	tabs.visible = false
	for child: Node in actions.get_children():
		actions.remove_child(child)
		child.queue_free()

	if not _merchant_id.is_empty():
		_show_merchant()
		return

	var data: BuildingData = ContentDB.building(_building_id)
	if data == null:
		title.text = "—"
		subtitle.text = ""
		body.text = ""
		return

	var tier: int = RunState.building_tier(_building_id)
	title.text = data.display_name
	subtitle.text = "Tier %d of %d" % [tier, data.max_tier] if tier > 0 else "Not built"

	var lines: PackedStringArray = [data.description]
	if tier > 0:
		lines.append("Now: %s" % _effect_text(data, tier))
	if tier < data.max_tier:
		lines.append("Next: %s" % _effect_text(data, tier + 1))
	KeywordTextScript.apply(body, "\n".join(lines))

	_show_construction(data, tier)

	# Buildings that do something beyond a tier number get their own controls.
	match data.effect:
		BuildingData.Effect.RELIC_SLOTS:
			_show_relics()
		BuildingData.Effect.CAPTIVE_LABOUR:
			_show_captives()
		BuildingData.Effect.BLUEPRINTS:
			_show_crafting()
		BuildingData.Effect.MARKET:
			_show_market()
		BuildingData.Effect.HERO_UPGRADE:
			_show_mansion()
		_:
			pass


func _show_construction(data: BuildingData, tier: int) -> void:
	var busy_with: String = String(RunState.construction.get("id", ""))
	var building_this: bool = busy_with == _building_id

	progress.visible = building_this
	progress_label.visible = building_this
	if building_this:
		var done: float = float(RunState.construction.get("distance_done", 0.0))
		var needed: float = maxf(float(RunState.construction.get("distance_needed", 1.0)), 1.0)
		progress.value = done / needed
		progress_label.text = "%d of %d distance" % [int(done), int(needed)]
		return
	if not RunState.can_build_now():
		_note("Read only during battle. Return in Preparation to make changes.")
		return

	if tier >= data.max_tier:
		_note("Fully built.")
		return

	var distance_cost: float = BuildingData.tier_cost(tier + 1)
	var wood_cost: int = data.wood_cost_at(tier + 1)
	var button := _row("Build tier %d\n%d Wood  ·  %d distance" % [
		tier + 1, wood_cost, int(distance_cost)], 52.0)
	button.disabled = not busy_with.is_empty() \
		or not RunState.can_afford_cost({RunState.WOOD: wood_cost}) \
		or not MetaState.building_unlocked(data.id)
	button.pressed.connect(func() -> void:
		_attempt(TownScope.try_start_construction(_building_id)))
	actions.add_child(button)

	if not busy_with.is_empty():
		var other: BuildingData = ContentDB.building(busy_with)
		_note("Already building %s. One at a time." % (other.display_name if other != null else busy_with))
	elif not RunState.can_afford_cost({RunState.WOOD: wood_cost}):
		_note("Needs %d Wood. You have %d." % [wood_cost, RunState.currency(RunState.WOOD)])
	elif not MetaState.building_unlocked(data.id):
		_note("Unlock this plot through its account milestone; it will still begin unbuilt each run.")


## Which bow is in hand.
##
## **A weapon system you cannot equip from a menu is not finished**, and this was
## missing: a bow arrived only by learning its plan, and only if the hero held
## none already, so a player who learned a second plan could never reach it.
##
## At the Forge because that is where the plan became an object. Only what is
## known is listed - an unlearned weapon is not a locked row to covet, it is a
## discovery that has not happened yet.
func _show_armoury() -> void:
	var known: Array[RangedWeaponData] = []
	var ids: Array = ContentDB.ranged_weapons.keys()
	ids.sort()
	for id: Variant in ids:
		var weapon := ContentDB.ranged_weapons[id] as RangedWeaponData
		if weapon != null and (weapon.starting_kit
				or MetaState.knows_recipe("ranged", weapon.id)):
			known.append(weapon)
	if known.is_empty():
		return
	if not RunState.can_build_now():
		return
	actions.add_child(_heading("Armoury"))
	for weapon: RangedWeaponData in known:
		var held: bool = RunState.ranged_id == weapon.id
		# The numbers that distinguish them, because "Shortbow" and "Heavy
		# Crossbow" say nothing about which one answers the situation.
		var row := _row("%s%s\n%d dmg  ·  %.2fs draw  ·  %d reach" % [
			"◆ " if held else "", weapon.display_name, int(weapon.damage),
			weapon.draw_time, int(weapon.effective_range)], 50.0)
		row.tooltip_text = weapon.description
		row.disabled = held
		var wanted: String = weapon.id
		row.pressed.connect(func() -> void:
			RunState.ranged_id = wanted
			# The nocked ammunition must fit the new weapon: a crossbow holding
			# arrows fires nothing and reads as a broken button.
			var fits: Array[AmmoData] = RunState.ammo_for_weapon(wanted)
			var still_good: bool = false
			for kind: AmmoData in fits:
				if kind.id == RunState.ammo_id:
					still_good = true
			if not still_good:
				RunState.ammo_id = fits[0].id if not fits.is_empty() else ""
			EventBus.ammo_changed.emit(RunState.ammo_id,
				RunState.ammo_count(RunState.ammo_id))
			_attempt(""))
		actions.add_child(row)
	# Putting it down is a real choice: a bow slows the draw and the quiver is
	# room that could hold something else.
	if not RunState.ranged_id.is_empty():
		var stow := _row("Sling it across your back", 40.0)
		stow.tooltip_text = "Fight with the chain alone. The quiver keeps what it holds."
		stow.pressed.connect(func() -> void:
			RunState.ranged_id = ""
			EventBus.ammo_changed.emit("", 0)
			_attempt(""))
		actions.add_child(stow)


## Ammunition, made at the Forge (owner decision, 2026-08-31).
##
## **Here rather than on the HUD.** A crafting button in the combat bar would
## have to fit a phone's bottom row beside five others, and making arrows is not
## a combat decision - it is the same mode of thought as buying a tower, which is
## why it belongs in the same place.
##
## Only what the player knows. An unlearned recipe is not shown greyed out: a
## list of things you cannot have is a worse advertisement for blueprints than
## finding one is.
func _show_crafting() -> void:
	_show_armoury()
	if RunState.ranged_id.is_empty():
		return
	var weapon := ContentDB.ranged_weapons.get(RunState.ranged_id, null) as RangedWeaponData
	if weapon == null:
		return
	actions.add_child(_heading("Quiver"))
	_note("%s  ·  %d of %d carried" % [weapon.display_name,
		RunState.ammo_bulk_used(), Balance.AMMO_CAPACITY])
	if not RunState.can_build_now():
		return
	for kind: AmmoData in RunState.ammo_for_weapon(RunState.ranged_id):
		if not kind.known_from_the_start \
				and not MetaState.knows_recipe("ammo", kind.id):
			continue
		var make := _row("%s\n%d for %s" % [kind.display_name, kind.craft_batch,
			RunState.format_cost(kind.craft_cost)], 46.0)
		make.tooltip_text = kind.description
		make.disabled = not RunState.can_afford_cost(kind.craft_cost) \
			or RunState.ammo_room() < kind.craft_batch * kind.bulk
		# Held, not captured: a lambda copies the loop variable by value, and
		# every button would otherwise craft whatever the last one was.
		var making: String = kind.id
		make.pressed.connect(func() -> void: _attempt(RunState.craft_ammo(making, 1)))
		actions.add_child(make)


# --- Merchants ---------------------------------------------------------------
#
# Three things a shop has to say, and the reason each is on the page rather than
# in a tooltip:
#
# - **What it costs**, on the row, before it is pressed. A price the player finds
#   out by being refused is the Hero Mansion fault again.
# - **How long they are here.** A traveller who leaves is the only pressure this
#   screen has; hiding the countdown makes the whole system a shop that happens
#   to be closed sometimes.
# - **How close they are to staying.** The settle threshold is the progression
#   the owner asked for - things unlocked by playing - and progress towards it
#   that the player cannot see is progress they cannot aim at.

func _show_merchant() -> void:
	var data: MerchantData = ContentDB.merchant(_merchant_id)
	if data == null:
		title.text = "—"
		subtitle.text = ""
		body.text = ""
		return

	var resident: bool = MerchantYard.settled(_merchant_id)
	var left: int = MerchantYard.waves_left(_merchant_id)
	title.text = data.display_name
	subtitle.text = "Lives here" if resident else "Leaves in %d wave%s" % [
		left, "" if left == 1 else "s"]

	var lines: PackedStringArray = [data.description]
	if not data.greeting.is_empty():
		lines.append("
\"%s\"" % data.greeting)
	if resident:
		lines.append("
Settled in town. Restocks every Preparation, every run.")
	else:
		var done: int = MerchantYard.trades_done(_merchant_id)
		lines.append("
Business done: %d of %d different goods. Buy %d more and they stay for good."
			% [done, data.settle_trades, maxi(data.settle_trades - done, 0)])
	KeywordTextScript.apply(body, "
".join(lines))

	actions.add_child(_heading("On the cart"))
	if not RunState.can_build_now():
		_note("The road is moving. Trade happens in Preparation.")
	var shelf: Array = MerchantYard.stock(_merchant_id)
	if shelf.is_empty():
		_note("The cart is empty. Come back next Preparation.")
		return
	for index: int in shelf.size():
		_merchant_row(shelf[index] as Dictionary, index)


func _merchant_row(offer: Dictionary, index: int) -> void:
	var cost: Dictionary = offer.get("cost", {}) as Dictionary
	var taken: bool = MerchantYard.sold(_merchant_id, index)
	var row := _row("%s%s  —  %s" % [
		"SOLD  ·  " if taken else "", String(offer.get("label", "")),
		RunState.format_cost(cost)], 48.0)
	row.tooltip_text = String(offer.get("detail", ""))
	row.disabled = taken or not RunState.can_build_now() 		or not RunState.can_afford_cost(cost)
	# Disabled buttons carry no tooltip in Godot, and an unaffordable row is
	# exactly the one a player wants explained. The price is already in the
	# label, so the row still says why - which the four silent refusals above
	# did not.
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var merchant: String = _merchant_id
	row.pressed.connect(func() -> void:
		var problem: String = MerchantYard.buy(merchant, index)
		if problem.is_empty():
			_flash("Bought: %s" % String(offer.get("label", "")))
			Sfx.play("sfx_ui_confirm", 2.0)
		else:
			_attempt(problem)
		_refresh())
	actions.add_child(row)


func _show_market() -> void:
	if RunState.building_tier("market") <= 0:
		return
	actions.add_child(_heading("Exchange"))
	_note("Exchanges left this Preparation: %d   ·   %d given → %d received" % [
		RunState.market_trades_remaining, Balance.MARKET_TRADE_LOT,
		Balance.MARKET_TRADE_RETURN])
	if not RunState.can_build_now():
		return
	for pair: Array in [[RunState.WOOD, RunState.GOLD], [RunState.FOOD, RunState.GOLD],
			[RunState.GOLD, RunState.STONE], [RunState.STONE, RunState.WOOD]]:
		var from_id: String = pair[0]
		var to_id: String = pair[1]
		var trade := _row("%d %s  →  %d %s" % [Balance.MARKET_TRADE_LOT,
			RunState.currency_name(from_id), Balance.MARKET_TRADE_RETURN,
			RunState.currency_name(to_id)], 42.0)
		trade.disabled = RunState.market_trades_remaining <= 0 \
			or not RunState.can_afford_cost({from_id: Balance.MARKET_TRADE_LOT})
		trade.pressed.connect(func() -> void:
			_attempt(TownScope.try_market_trade(from_id, to_id)))
		actions.add_child(trade)
	var service := _row("Act %d contract" % RunState.act, 46.0)
	service.tooltip_text = "One rotating bounded service per act. Never a free conversion loop."
	service.disabled = RunState.market_service_bought_this_act()
	service.pressed.connect(func() -> void: _attempt(TownScope.try_market_service()))
	actions.add_child(service)


# --- The Hero Mansion --------------------------------------------------------
#
# Reported as: "I still have no idea what is going on with the Hero Mansion",
# "very unintuitive and confusing", "players are not capable of properly figuring
# it out". The mechanics underneath were sound; nothing about them was ever
# *said*. Four faults, all of presentation:
#
# 1. Every explanation of a refusal was destroyed on the frame it was written -
#    see `_flash`. A player who pressed an offer they could not afford got
#    silence, four separate times, for four different reasons.
# 2. With the Mansion unbuilt the entire page was one sentence, and attribute
#    points - the reward for levelling - could not be spent at all, because the
#    attribute block sat behind the same early return. Levelling up therefore
#    produced a number that went up and nothing to do with it.
# 3. The four ability slots were drawn as permanently disabled buttons. A control
#    that can never be pressed reads as broken, not as a display.
# 4. The only view of the tree was three randomly rotated offers. Twenty-seven
#    nodes exist; a player could not see that, could not see what a discipline
#    was, and had no way to want anything in particular.
#
# The rules are unchanged - they are checked by `discipline_check` and
# `balance_test`. What is different is that the sheet now says all of them out
# loud, before the player presses anything.

const SLOT_NAMES: Array[String] = ["Attack", "Defense", "Power", "Ultimate"]


func _show_mansion() -> void:
	var tier: int = RunState.building_tier("sanctum")
	# The level line lives in the pinned subtitle rather than at the top of each
	# page. It is the same sentence on all three, and repeating it cost the
	# discipline list a fifth of a phone's scroll window.
	subtitle.text = "%s   ·   level %d" % [subtitle.text, RunState.hero_level]
	if RunState.hero_level < Balance.HERO_MAX_LEVEL:
		subtitle.text += "   ·   %d%% to %d" % [
			int(RunState.hero_level_progress() * 100.0), RunState.hero_level + 1]


	var page_names: Array[String] = ["Hero", "Training", "Disciplines"]
	for page: int in page_names.size():
		var tab := Button.new()
		tab.text = page_names[page]
		tab.toggle_mode = true
		tab.button_pressed = _mansion_page == page
		tab.custom_minimum_size = Vector2(0.0, 42.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 13)
		tab.pressed.connect(func() -> void:
			_mansion_page = page
			_slot_focus = -1
			_clear_notice()
			_refresh())
		tabs.add_child(tab)
	# Pinned above the scroll rather than scrolling with the page. These are the
	# Mansion's navigation, and navigation that scrolls out of reach is not
	# navigation - a player two screens into the discipline list had to scroll back
	# up to leave it.
	tabs.visible = true

	match _mansion_page:
		Mansion.TRAINING:
			_mansion_training(tier)
		Mansion.TREE:
			_mansion_tree(tier)
		_:
			_mansion_hero(tier)


## Level, the four attributes, and the four ability slots — everything the hero
## *is* right now. Available whether or not the Mansion is built, because an
## earned attribute point is a reward already paid for, and making the player
## build a plot before they can spend it turns levelling up into an IOU.
func _mansion_hero(tier: int) -> void:
	_note("Every kill on the road is experience. Each level brings an attribute "
		+ "point, and every %d levels a skill point for training abilities."
		% Balance.HERO_SKILL_POINT_EVERY)
	actions.add_child(_heading("Attributes"))
	if RunState.hero_attribute_points > 0:
		_note("%d point%s to place. One arrives with every level." % [
			RunState.hero_attribute_points,
			"" if RunState.hero_attribute_points == 1 else "s"])
	else:
		_note("No points to place. The next level brings one.")

	var names: Array[String] = ["Might", "Vigour", "Swiftness", "Focus"]
	var blurbs: Array[String] = [
		"Damage on every swing and every shot.",
		"Maximum health.",
		"Movement and swing speed.",
		"Command generation and spell power.",
	]
	var spendable: bool = RunState.hero_attribute_points > 0
	for index: int in names.size():
		var placed: int = RunState.hero_attributes[index]
		var total: int = RunState.attribute(index)
		var worn: int = total - placed
		var row := _row("%s%s  %d%s\n%s" % ["+  " if spendable else "", names[index],
			total, "   (%d placed + %d worn)" % [placed, worn] if worn > 0 else "",
			blurbs[index]], 54.0)
		row.disabled = not spendable
		row.pressed.connect(func() -> void:
			_attempt(RunState.spend_attribute_point(index)))
		actions.add_child(row)

	# **The stash, reachable from inside a run.**
	#
	# `StashScreen` said in as many words that it was "reached from the main
	# menu, not from a run: gear persists and a run does not pause for shopping".
	# The objection was the *pause*, and the town already answers it: the
	# battlefield keeps simulating while a scope is open, so shopping here costs
	# the same road time as building here does. Owner request, 2026-09-09.
	#
	# In the Mansion rather than on the combat bar for the same reason: the
	# Mansion is where the hero is edited, and putting a full gear screen one
	# click from the fight would invite swapping between waves as a routine
	# rather than as a visit.
	actions.add_child(_heading("Gear"))
	var worn_pieces: int = MetaState.equipped.size()
	_note("%d worn, %d in the stash. Changing gear here costs road time, the "
		% [worn_pieces, MetaState.stash.size()]
		+ "same as building does — the road does not stop for it.")
	var stash_row := _row("Open the stash  ·  %d Marks  ·  %d Shards"
		% [MetaState.marks, MetaState.shards], 54.0)
	stash_row.pressed.connect(_open_stash)
	actions.add_child(stash_row)

	var standing: int = 0
	var met: int = 0
	for order: ExchangeOrder in Exchange.orders():
		if order.stage == ExchangeOrder.Stage.FILLED:
			met += 1
		elif order.is_open():
			standing += 1
	# The count is on the button because a met line is the one thing worth
	# interrupting a player for: Marks or gear are sitting there unclaimed.
	var ledger_caption: String = "The Long Ledger"
	if met > 0:
		ledger_caption += "  ·  %d met" % met
	elif standing > 0:
		ledger_caption += "  ·  %d standing" % standing
	else:
		ledger_caption += "  ·  sell gear to passing caravans"
	var ledger_row := _row(ledger_caption, 54.0)
	ledger_row.pressed.connect(_open_ledger)
	actions.add_child(ledger_row)

	actions.add_child(_heading("Abilities"))
	_note("Four slots. What sits in one is cast from the combat bar.")
	for slot: int in Balance.HERO_MAX_SPELL_SLOTS:
		var equipped: DisciplineNodeData = RunState.discipline_node_in_slot(slot)
		var unlocked: bool = slot < 2 or RunState.act >= slot
		var what: String = "empty  —  choose"
		if equipped != null:
			what = equipped.display_name
		elif not unlocked:
			what = "unlocks after the Act %d boss" % slot
		var row := _row("%s  ·  %s" % [SLOT_NAMES[slot], what], 48.0)
		if equipped != null and ResourceLoader.exists(equipped.get_sprite_path()):
			UiMetrics.row_icon(row, load(equipped.get_sprite_path()), 32)

		if equipped != null:
			row.tooltip_text = equipped.description
		row.disabled = not unlocked
		var wanted: int = slot
		row.pressed.connect(func() -> void:
			_slot_focus = wanted
			_mansion_page = Mansion.TRAINING
			_clear_notice()
			_refresh())
		actions.add_child(row)

	if tier <= 0:
		actions.add_child(_heading("Training"))
		_note("Build the Hero Mansion to train new abilities. The attributes above "
			+ "are yours to place either way.")


## This road's offers, the trained loadout, and — when a slot was pressed on the
## Hero page — the list of what may go into it.
func _mansion_training(tier: int) -> void:
	if _slot_focus >= 0:
		_mansion_slot_picker()
		return

	actions.add_child(_heading("Training"))
	if tier <= 0:
		_note("The Hero Mansion is not built. Building it opens discipline "
			+ "training and reveals this road's offers.")
		return

	_note("Skill points %d   ·   Food %d   ·   trained %d of %d" % [
		RunState.hero_skill_points, RunState.currency(RunState.FOOD),
		RunState.trained_discipline_nodes.size(), RunState.discipline_cap()])
	_note("A node costs one skill point — one arrives every %d levels — and its "
		% Balance.HERO_SKILL_POINT_EVERY
		+ "Food. Only the three offers below can be trained on this road; the "
		+ "next road offers three more.")

	# **What committing to a discipline has bought.**
	#
	# Depth gates which nodes can be offered at all, and a rule the player cannot
	# see is a rule they experience as the game being arbitrary - the offers
	# simply look different this road and nothing says why. Reported as the tree
	# being unintuitive, so the standing is shown before the offers that it
	# decided.
	var depth: Dictionary = RunState.discipline_depth()
	var tree_names: Array[String] = ["Blood", "Holy", "Berserk"]
	actions.add_child(_heading("Your disciplines"))
	var deepest: int = 0
	for which: int in tree_names.size():
		deepest = maxi(deepest, int(depth.get(which, 0)))
	for which: int in tree_names.size():
		var have: int = int(depth.get(which, 0))
		var locked: int = 0
		var open_now: int = 0
		for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
			if node.discipline != which or RunState.trained_discipline_nodes.has(node.id):
				continue
			if have < node.required_depth():
				locked += 1
			else:
				open_now += 1
		var line: String = "%s  ·  %d trained  ·  %d open" % [
			tree_names[which], have, open_now]
		if locked > 0:
			line += "  ·  %d deeper node%s need%s more here" % [
				locked, "" if locked == 1 else "s", "s" if locked == 1 else ""]
		_note(line)
	if deepest == 0:
		_note("Every discipline starts with three nodes open. Training in one "
			+ "opens its deeper nodes; spreading wide keeps all three shallow.")

	if RunState.discipline_offers.is_empty():
		RunState.refresh_discipline_offers()
	actions.add_child(_heading("This road's offers"))
	if RunState.discipline_offers.is_empty():
		_note("Nothing left to offer at Mansion tier %d. Raise it for deeper nodes."
			% tier)
	for id: String in RunState.discipline_offers:
		var offered: DisciplineNodeData = ContentDB.discipline_node(id)
		if offered == null:
			continue
		var blocker: String = _training_blocker(offered)
		var card := _row("%s\n%s · %s · %d Food\n%s%s" % [
			offered.display_name, offered.discipline_name(), offered.slot_name(),
			offered.food_cost, offered.description,
			"\n— %s" % blocker if not blocker.is_empty() else ""], 78.0)
		if ResourceLoader.exists(offered.get_sprite_path()):
			UiMetrics.row_icon(card, load(offered.get_sprite_path()), 40)

		card.disabled = not blocker.is_empty()
		card.pressed.connect(func() -> void: _attempt(RunState.try_train_discipline(id)))
		actions.add_child(card)

	if RunState.trained_discipline_nodes.is_empty():
		return
	actions.add_child(_heading("Trained"))
	for id: String in RunState.trained_discipline_nodes:
		var trained: DisciplineNodeData = ContentDB.discipline_node(id)
		if trained == null:
			continue
		var equipped: bool = RunState.equipped_discipline_slots.has(id)
		var where: String = "equipped" if equipped else (
			trained.slot_name().to_lower() if trained.is_active_slot() else "always on")
		var row := _row("%s%s  ·  %s" % ["◆ " if equipped else "",
			trained.display_name, where], 44.0)
		if ResourceLoader.exists(trained.get_sprite_path()):
			UiMetrics.row_icon(row, load(trained.get_sprite_path()), 30)

		row.tooltip_text = trained.description
		row.disabled = not trained.is_active_slot() or equipped \
			or not trained.is_slot_unlocked(RunState.act)
		row.pressed.connect(func() -> void: _attempt(RunState.try_equip_discipline(id)))
		actions.add_child(row)

	var respec := _row("Respec disciplines  ·  %d Food" % RunState.discipline_respec_cost(), 46.0)
	respec.tooltip_text = "Return to the curated Attack and Defense starters. Cost rises each use."
	respec.disabled = not RunState.is_preparation() \
		or not RunState.can_afford_cost({RunState.FOOD: RunState.discipline_respec_cost()})
	respec.pressed.connect(func() -> void: _attempt(RunState.try_respec_disciplines()))
	actions.add_child(respec)


## What may go into the slot the player pressed. A slot that cannot be filled
## says why, rather than presenting an empty list.
func _mansion_slot_picker() -> void:
	var slot: int = clampi(_slot_focus, 0, SLOT_NAMES.size() - 1)
	actions.add_child(_heading("%s slot" % SLOT_NAMES[slot]))

	var back := _row("←  Back", 40.0)
	back.pressed.connect(func() -> void:
		_slot_focus = -1
		_mansion_page = Mansion.HERO
		_clear_notice()
		_refresh())
	actions.add_child(back)

	var found: int = 0
	for id: String in RunState.trained_discipline_nodes:
		var node: DisciplineNodeData = ContentDB.discipline_node(id)
		if node == null or node.slot_index() != slot:
			continue
		found += 1
		var here: bool = RunState.equipped_discipline_slots[slot] == id
		var row := _row("%s%s\n%s" % ["◆ " if here else "", node.display_name,
			node.description], 60.0)
		if ResourceLoader.exists(node.get_sprite_path()):
			UiMetrics.row_icon(row, load(node.get_sprite_path()), 34)

		row.disabled = here or not RunState.is_preparation() \
			or not node.is_slot_unlocked(RunState.act)
		row.pressed.connect(func() -> void:
			var problem: String = RunState.try_equip_discipline(id)
			_slot_focus = -1
			_mansion_page = Mansion.HERO
			_attempt(problem))
		actions.add_child(row)

	if found == 0:
		_note("Nothing trained for this slot yet. Train a %s node on the Training "
			% SLOT_NAMES[slot].to_lower() + "page — the Disciplines page shows "
			+ "which ones exist.")
	elif not RunState.is_preparation():
		_note("Loadout changes are available only in Preparation.")


## Every node in the game, with its state. Not a shop — a map.
##
## The offers are three of twenty-seven and they rotate, so without this page a
## player has no way to learn that a discipline *is* anything, or to decide they
## want a particular ultimate two roads from now. Nothing here can be pressed to
## buy; it exists so that what the Training page offers means something.
func _mansion_tree(tier: int) -> void:
	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 4)
	for which: int in Balance.DISCIPLINE_IDS.size() + 1:
		var index: int = which - 1
		var tab := Button.new()
		tab.text = "All" if index < 0 else ["Blood", "Holy", "Berserk"][index]
		tab.toggle_mode = true
		tab.button_pressed = _tree_filter == index
		tab.custom_minimum_size = Vector2(0.0, 40.0)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 12)
		tab.pressed.connect(func() -> void:
			_tree_filter = index
			_refresh())
		filters.add_child(tab)
	actions.add_child(filters)
	_note("Blood trades health for damage. Holy shields and cleanses. Berserk "
		+ "breaks formations. Mix them freely — nothing locks you to one.")

	_show_synergies()

	var last: int = -1
	for node: DisciplineNodeData in ContentDB.discipline_nodes_sorted():
		if _tree_filter >= 0 and int(node.discipline) != _tree_filter:
			continue
		if int(node.discipline) != last:
			last = int(node.discipline)
			actions.add_child(_heading(node.discipline_name()))
		var state: String = "may be offered on a later road"
		var tint: Color = Color("b8ae98")
		if RunState.trained_discipline_nodes.has(node.id):
			state = "trained"
			tint = Color("9fd48a")
		elif node.mansion_tier > tier:
			state = "needs Mansion tier %d" % node.mansion_tier
		elif RunState.discipline_offers.has(node.id):
			state = "offered on this road"
			tint = Color("e8a33d")
		actions.add_child(_line("%s  ·  %s\n%s\n%s" % [node.display_name,
			node.slot_name(), node.description, state], 13, tint))


## Pairs of nodes that do something together, and how close the hero is to each.
##
## **On the page, not in a tooltip, and not a surprise.** A synergy the player
## discovers by accident is not a build - it is a coincidence. The whole reason
## stage two exists is to give a reason to take a *particular* path rather than
## the deepest one, and that only works if the paths are legible before they are
## walked. So every synergy is listed from the first visit, with its
## requirements named and its progress counted.
##
## Sorted by how close it is. A player two nodes away wants to see the one they
## are one node away from first.
func _show_synergies() -> void:
	var all: Array[SynergyData] = Synergies.all_sorted()
	if all.is_empty():
		return
	actions.add_child(_heading("Synergies"))
	_note("Two trained nodes doing something together. None of them raises a "
		+ "number — they change when an effect fires, or what it fires on.")
	var rows: Array[SynergyData] = all.duplicate()
	rows.sort_custom(func(a: SynergyData, b: SynergyData) -> bool:
		var mine: int = Synergies.progress(a.id)
		var theirs: int = Synergies.progress(b.id)
		if mine != theirs:
			return mine > theirs
		return a.id < b.id)
	for data: SynergyData in rows:
		var done: int = Synergies.progress(data.id)
		var need: int = data.requires.size()
		var live: bool = Synergies.active(data.id)
		var tint: Color = Color("9fd48a") if live else (
			Color("e8a33d") if done > 0 else Color("8f877a"))
		var state: String = "ACTIVE" if live else "%d of %d trained" % [done, need]
		var body: String = "%s  ·  %s
%s" % [data.display_name, state, data.description]
		if not live and not data.hint.is_empty():
			body += "
%s" % data.hint
		actions.add_child(_line(body, 13, tint))


## The one requirement standing in the way, in the order the rules are checked,
## so the card can say it before the player presses.
func _training_blocker(node: DisciplineNodeData) -> String:
	if not RunState.is_preparation():
		return "Preparation only"
	if RunState.trained_discipline_nodes.size() >= RunState.discipline_cap():
		return "%d trained is the limit at level %d" % [
			RunState.discipline_cap(), RunState.hero_level]
	if RunState.hero_skill_points <= 0:
		return "needs a skill point — one every %d levels" % Balance.HERO_SKILL_POINT_EVERY
	if RunState.building_tier("sanctum") < node.mansion_tier:
		return "needs Hero Mansion tier %d" % node.mansion_tier
	if not RunState.can_afford_cost({RunState.FOOD: node.food_cost}):
		return "needs %d Food, you have %d" % [node.food_cost,
			RunState.currency(RunState.FOOD)]
	return ""


## Relic sockets. Only socketed relics do anything at all, which is the entire
## reason the Town Hall exists.
func _show_relics() -> void:
	var used: int = RunState.socketed_relics.size()
	var total: int = RunState.relic_slot_count()
	actions.add_child(_heading("Sockets  %d / %d" % [used, total]))

	for relic_id: String in RunState.socketed_relics:
		var relic: RelicData = ContentDB.relics.get(relic_id, null) as RelicData
		if relic == null:
			continue
		var row := _row("◆ %s   —   remove" % relic.display_name, 42.0)
		row.tooltip_text = relic.description
		row.disabled = not RunState.can_build_now()
		row.pressed.connect(func() -> void:
			TownScope.unsocket_relic(relic_id)
			_attempt(""))
		actions.add_child(row)

	for relic_id: String in RunState.held_relics:
		var relic: RelicData = ContentDB.relics.get(relic_id, null) as RelicData
		if relic == null:
			continue
		var row := _row("◇ %s   —   socket" % relic.display_name, 42.0)
		row.tooltip_text = relic.description
		row.disabled = used >= total or not RunState.can_build_now()
		row.pressed.connect(func() -> void:
			_attempt(TownScope.try_socket_relic(relic_id)))
		actions.add_child(row)

	if RunState.socketed_relics.is_empty() and RunState.held_relics.is_empty():
		_note("No relics yet. Take one from a war camp.")

	for core_id: String in RunState.boss_cores:
		var core: RelicData = ContentDB.relics.get(core_id, null) as RelicData
		if core != null:
			_note("◆ %s  —  always active" % core.display_name)


## Oathbound leaders won from war camps and assigned a one-run duty. Internal
## save names remain compatible with v3; no captivity framing reaches players.
func _show_captives() -> void:
	var here: int = 0
	for value: Variant in RunState.captive_assignments.values():
		if String(value) == _building_id:
			here += 1
	actions.add_child(_heading("Assigned  %d / %d" % [here, Balance.CAPTIVES_PER_BUILDING]))
	if not RunState.can_build_now():
		_note("Read only during battle.")
		return

	if RunState.captives.is_empty():
		_note("No Oathbound leader yet. Complete a raid.")
		return

	for captive_id: String in RunState.captives:
		var captive: CaptiveData = ContentDB.captive(captive_id)
		if captive == null:
			continue
		var assigned_to: String = String(RunState.captive_assignments.get(captive_id, ""))
		if assigned_to == _building_id:
			var held := _row("%s   —   working here" % captive.display_name, 42.0)
			held.disabled = true
			actions.add_child(held)
			continue
		# The verb is data, not a string literal: the framing of this system is
		# explicitly unsettled (GDD §6.3).
		var row := _row("%s %s" % [captive.acquire_verb, captive.display_name], 42.0)
		row.pressed.connect(func() -> void:
			_attempt(TownScope.try_assign_captive(captive_id, _building_id)))
		actions.add_child(row)


func _effect_text(data: BuildingData, tier: int) -> String:
	var amount: float = data.effect_at(tier)
	match data.effect:
		BuildingData.Effect.RELIC_SLOTS:
			var slots: int = int(amount)
			return "%d relic socket%s" % [slots, "" if slots == 1 else "s"]
		BuildingData.Effect.RESOURCE_RATE:
			return "+%d%% resources from walking" % int(amount * 100.0)
		BuildingData.Effect.HERO_UPGRADE:
			return "+%d%% hero health, speed and cooldowns" % int(amount * 100.0)
		BuildingData.Effect.CAPTIVE_LABOUR:
			var details: int = int(amount)
			return "%d dut%s" % [details, "y" if details == 1 else "ies"]
		BuildingData.Effect.BLUEPRINTS:
			return "tower mastery level %d unlocked" % clampi(
				Balance.TOWER_BASE_LEVEL_CAP + tier, 1, Balance.TOWER_MAX_LEVEL)
		BuildingData.Effect.WAVE_FORESIGHT:
			match tier:
				1:
					return "formation lanes and road threat values revealed"
				2:
					return "wave scale, intent and road reward depth revealed"
				_:
					return "signature threats and exact road rewards revealed"
		BuildingData.Effect.PRODUCTION:
			return "%.2f %s per distance" % [amount, RunState.currency_name(data.produced_currency)]
		BuildingData.Effect.TREASURY_CACHE:
			return "up to %d of each currency cached for the next run" % int(amount)
		BuildingData.Effect.MARKET:
			return "%d bounded exchanges per Preparation" % Balance.MARKET_TRADES_PER_PREPARATION
		_:
			return "%.2f" % amount
