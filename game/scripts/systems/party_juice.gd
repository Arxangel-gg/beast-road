class_name PartyJuice
extends Node

## A partner's moment, sent and drawn.
##
## Owner brief, 2026-09-16: "Leveling up vfx game juice should be replicated so
## players see teammates who level up as well! Profession events need to be
## replicated properly as well!"
##
## Neither crossed the wire before this. A partner who levelled, landed a rare
## fish or broke open a geode did it in silence on the other machine - the one
## moment in a co-op run most worth sharing, and the only evidence was a bar
## moving somewhere off-screen.
##
## **This node is both halves and nothing else.** It hears the local player's own
## level and craft events and says so; it hears a partner's and draws it over
## their body. It is the only listener on those three facts.
##
## **Drawn, never granted**, and that is the bound rather than a description. A
## hero level and a craft level are *account* things - they live in `MetaState`,
## they belong to whoever earned them, and my run is not changed by my partner's
## level. So what arrives is a seat number and something to draw. Nothing here
## reads a table, awards experience, or touches `MetaState` at all. That is also
## why these are facts and not requests: a request is a guest asking the host to
## *do* something and coming back with an amount read off the host's own tables,
## which is the rule the fish, the crop and the egg are asked under because a
## number in that message would be a currency printer. Nothing here asks.
##
## Solo, it costs one signal connection and never sends: `Coop.partner_present()`
## is false and the relay is not there to send through.

## Where the party's bodies are found.
var heroes: Node = null


func _ready() -> void:
	name = "PartyJuice"
	# Ours, going out.
	EventBus.hero_levelled.connect(_on_local_levelled)
	EventBus.craft_levelled.connect(_on_local_craft_levelled)
	EventBus.gathered.connect(_on_local_gathered)
	EventBus.fish_caught.connect(_on_local_fish)
	# Theirs, coming in.
	EventBus.coop_partner_levelled.connect(_on_partner_levelled)
	EventBus.coop_partner_craft_levelled.connect(_on_partner_craft_levelled)
	EventBus.coop_partner_worked.connect(_on_partner_worked)


# --- Ours, going out ------------------------------------------------------------

## **Sent only when there is somebody to hear it.** Solo this is a branch that
## fails on its first condition every time; the local flourish is `Vfx`'s own
## and has been since levels existed.
func _telling() -> bool:
	return Coop.partner_present() and Coop.relay() != null


func _my_seat() -> int:
	var mine: Hero = _local_hero()
	return mine.party_slot if mine != null else 1


func _on_local_levelled(level: int, _attributes: int, _skills: int) -> void:
	if _telling():
		EventBus.coop_partner_levelled.emit(_my_seat(), level)


func _on_local_craft_levelled(craft: String, level: int) -> void:
	if _telling():
		EventBus.coop_partner_craft_levelled.emit(_my_seat(), craft, level)


## What was pulled out of the ground. The *sender* composes the icon and the
## line, because only the sender knows whether it was an ore or a log - and
## composing it here rather than on arrival means the receiving machine needs no
## table at all, which is what keeps this side purely cosmetic.
func _on_local_gathered(material_id: String, amount: int) -> void:
	if not _telling():
		return
	var kind: MaterialData = ContentDB.material(material_id)
	if kind == null:
		return
	EventBus.coop_partner_worked.emit(_my_seat(), kind.get_sprite_path(),
		"+%d %s" % [amount, kind.display_name], Balance.PARTY_JUICE_MATERIAL)


func _on_local_fish(fish_id: String, food: int) -> void:
	if not _telling():
		return
	var kind: FishData = ContentDB.fish(fish_id)
	if kind == null:
		return
	EventBus.coop_partner_worked.emit(_my_seat(), kind.get_sprite_path(),
		"%s  ·  +%d Food" % [kind.display_name, food], kind.rarity_colour())


# --- Theirs, coming in ----------------------------------------------------------

func _on_partner_levelled(seat: int, level: int) -> void:
	var body: Node2D = _body(seat)
	if body == null:
		return
	var at: Vector2 = body.global_position
	Vfx.rays(at, Balance.PARTY_JUICE_LEVEL, 10, 96.0)
	Vfx.spark(at, Balance.PARTY_JUICE_LEVEL, 14, Vector2.UP, 190.0)
	Vfx.ring(at, 110.0, Color(Balance.PARTY_JUICE_LEVEL, 0.7), 0.5, 4.0)
	Vfx.word(at + Vector2(0.0, -70.0), "LEVEL %d" % level,
		Balance.PARTY_JUICE_LEVEL, 28)
	# Quieter than your own: it is somebody else's moment and you are still in a
	# fight. The same reasoning the distance ear is built on.
	Sfx.play_at("sfx_ui_confirm", at, Balance.PARTY_JUICE_QUIETER)


func _on_partner_craft_levelled(seat: int, craft: String, level: int) -> void:
	var body: Node2D = _body(seat)
	if body == null:
		return
	var at: Vector2 = body.global_position
	Vfx.ring(at, 86.0, Color(Balance.PARTY_JUICE_CRAFT, 0.6), 0.45, 3.0)
	Vfx.word(at + Vector2(0.0, -58.0), "%s %d" % [craft.capitalize(), level],
		Balance.PARTY_JUICE_CRAFT, 22)
	Sfx.play_at("sfx_ui_confirm", at, Balance.PARTY_JUICE_QUIETER)


func _on_partner_worked(seat: int, icon: String, line: String, colour: Color) -> void:
	var body: Node2D = _body(seat)
	if body == null:
		return
	Vfx.prize(body.global_position + Vector2(0.0, -20.0), icon, line, colour)


# --- Finding a body -------------------------------------------------------------

## **A partner's body, and never your own.**
##
## This node emits the three facts *and* listens to them, so without this guard
## the local player's own level would be drawn twice: once by `Vfx`, which has
## owned that flourish since levels existed, and again here on the way past. The
## seat is the thing that tells them apart.
##
## A seat with nobody in it - a partner who has left, or not arrived - draws
## nothing rather than drawing at the origin, which is where a missing body would
## otherwise put a level-up flourish.
func _body(seat: int) -> Node2D:
	var mine: Hero = _local_hero()
	if mine != null and mine.party_slot == seat:
		return null
	if heroes != null and heroes.has_method("body_for_slot"):
		var held: Variant = heroes.call("body_for_slot", seat)
		if held != null and is_instance_valid(held as Object):
			return held as Node2D
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero != null and is_instance_valid(hero) and hero.party_slot == seat:
			return hero
	return null


func _local_hero() -> Hero:
	for node: Node in get_tree().get_nodes_in_group(Hero.GROUP_ANY):
		var hero := node as Hero
		if hero != null and is_instance_valid(hero) and hero.is_local_player():
			return hero
	return null
