extends Node

## Inside the walls: what the city shelters a Warden from, and what it does not.
##
##   godot --headless --path game res://tools/sanctuary_check.tscn
##
## Owner, 2026-09-17: *"the city base at the center of the battlefield should be
## a place where players should not get attacked from enemies if they are inside
## the city base, and instead enemies will attack the base instead of the player
## ... enemies should not try to keep walking into the city base, once they reach
## its walls around its perimeter then they should begin attacking the city base
## from there ... If players enter the city base while being chased by wildlife
## predators, the predators will leave the player alone ... No wildlife or
## enemies are able to enter the city base either ... And players are hidden to
## enemies and wildlife while within the city base. They are however not immune
## to weather effects while in the city base and disasters can still inflict upon
## the players in the city base."*
##
## **The last sentence is the one that needs a gate most**, because it is the
## half a careful implementation gets wrong by being thorough. Every other rule
## here says "hostile things cannot reach you", and the obvious next step is to
## make the ground safe - at which point a quake, a funnel, a meteor and a flood
## all become things a player sits out behind a wall, and the whole of the
## earth's wrath becomes optional. So the shelter is from *the road's own
## bodies* and from nothing else, and this file checks both directions.
##
## What each check catches:
##
## - **One decider.** Targeting, movement and the wildlife all have to ask the
##   same function, or one of them shelters a hero another is still walking at.
## - **Kept, not just chosen.** A rule written only where a target is picked lets
##   a body that was already chasing somebody follow them through the arch,
##   which is the exact behaviour being removed.
## - **Something else to do.** An enemy that loses its hero must fall through to
##   the town rather than stand still - *"enemies will attack the base
##   instead"*.
## - **In, not out.** A body that somehow starts inside has to be able to leave,
##   or it is pinned there for the rest of the run.
## - **No sanctuary in an arena.** A raid camp and a rift have no city, and a
##   shelter that answered true there would hide a hero from the guardian they
##   came to fight.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_an_arena_shelters_nobody()
	_test_the_walls_are_thicker_than_the_core()
	await _test_a_hero_inside_is_not_a_foe()
	await _test_a_body_may_leave_but_not_enter()
	_test_the_wildlife_asks_the_same_question()
	_test_the_sky_is_not_blocked()
	if _failures == 0:
		print(("[sanctuary] PASS - %d checks: the walls hide a Warden from every "
			+ "body on the road and from nothing in the sky, one function decides "
			+ "it, a chase ends at the arch, and what is inside can still walk "
			+ "out") % _checks)
	else:
		push_error("[sanctuary] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## An arena has no city in it, so nothing there is ever sheltered.
##
## The base class answering `false` is what keeps every rift, raid and dungeon
## from having to learn that a sanctuary exists - and a shelter that answered
## true underground would hide a hero from the guardian they went down to fight.
func _test_an_arena_shelters_nobody() -> void:
	var arena := EnemyField.new()
	add_child(arena)
	_check(not arena.inside_city(Vector2.ZERO),
		"a field with no town called its own origin sheltered - a rift would "
		+ "then hide the player from its own guardian")
	_check(not arena.inside_city(Vector2(9999.0, 9999.0)),
		"a field with no town sheltered a point on the far side of the map")
	arena.queue_free()


## The wall has a thickness.
##
## At exactly `TOWN_RADIUS` a body standing on the line is both inside the
## shelter and inside the reach of what hits the core, so the answer to "am I
## safe" changes with a pixel of drift. A ring the Warden can stand in and read
## is what was asked for.
func _test_the_walls_are_thicker_than_the_core() -> void:
	_check(Balance.CITY_SANCTUARY_RADIUS > Balance.TOWN_RADIUS,
		("the sheltered ring is %.0f against a core of %.0f - at or inside it "
		+ "there is no ground a player can stand on and be safe on")
		% [Balance.CITY_SANCTUARY_RADIUS, Balance.TOWN_RADIUS])


## A hero inside the walls is not something to fight.
##
## **Driven through `_foe_stands`**, which is the funnel both the choosing and
## the keeping of a target go through - checking the picker alone would pass on
## a build where a body already in a chase follows its hero inside.
func _test_a_hero_inside_is_not_a_foe() -> void:
	var field := _Sheltering.new()
	var hero := _Standin.new()
	add_child(hero)
	await get_tree().process_frame
	field.walls_at = Vector2.ZERO

	# Outside: an ordinary foe.
	hero.global_position = Vector2(Balance.CITY_SANCTUARY_RADIUS * 4.0, 0.0)
	_check(not field.inside_city(hero.global_position),
		"a hero four sanctuary-radii out was called sheltered")
	# Inside: gone.
	hero.global_position = Vector2(Balance.CITY_SANCTUARY_RADIUS * 0.2, 0.0)
	_check(field.inside_city(hero.global_position),
		"a hero standing in the middle of the town was not called sheltered")

	# And the source says the rule is asked where a target is *kept*, not only
	# where one is chosen. A source walk, because standing a real `Enemy` up
	# wants a battlefield, a lane and a route - and the content of this check is
	# "the question is asked in the funnel", which is what a source walk sees.
	var code: String = FileAccess.get_file_as_string("res://scenes/battlefield/enemy.gd")
	var funnel: int = code.find("func _foe_stands")
	var after: String = code.substr(funnel, 1400) if funnel >= 0 else ""
	_check(after.contains("inside_city"),
		"`_foe_stands` never asks whether the foe is inside the walls, so a body "
		+ "that had already chosen a hero keeps chasing them through the arch - "
		+ "which is the behaviour being removed rather than a corner of it")

	hero.queue_free()
	field.free()


## Entering is refused; leaving never is.
func _test_a_body_may_leave_but_not_enter() -> void:
	var field := _Sheltering.new()
	await get_tree().process_frame
	field.walls_at = Vector2.ZERO

	_check(not field.step_is_legal(Vector2(Balance.CITY_SANCTUARY_RADIUS * 2.5, 0.0), Vector2(Balance.CITY_SANCTUARY_RADIUS * 0.5, 0.0)),
		"a body walked from open ground into the town - nothing hostile may be "
		+ "in there at all")
	_check(field.step_is_legal(Vector2(Balance.CITY_SANCTUARY_RADIUS * 0.5, 0.0), Vector2(Balance.CITY_SANCTUARY_RADIUS * 2.5, 0.0)),
		"a body already inside the walls could not walk out, so anything that "
		+ "ever ends up in there is pinned for the rest of the run")
	_check(field.step_is_legal(Vector2(Balance.CITY_SANCTUARY_RADIUS * 2.5, 0.0), Vector2(Balance.CITY_SANCTUARY_RADIUS * 3.0, 0.0)),
		"a step between two points well outside the walls was refused")
	_check(field.step_is_legal(Vector2(Balance.CITY_SANCTUARY_RADIUS * 0.5, 0.0), Vector2(Balance.CITY_SANCTUARY_RADIUS * 0.4, 0.0)),
		"a body inside the walls could not move within them, which is a stricter "
		+ "rule than refusing entry and would freeze it on the spot")
	field.free()


## The wildlife asks the field rather than answering for itself.
##
## Two copies of this arithmetic is how the animals end up sheltering somebody
## the enemies are still hunting, and it would show as a wolf politely stopping
## at a line a Bogkin walks straight over.
func _test_the_wildlife_asks_the_same_question() -> void:
	var code: String = FileAccess.get_file_as_string("res://scripts/systems/wildlife.gd")
	_check(code.contains("inside_city"),
		"the wildlife never asks the field about the walls, so a predator "
		+ "chasing a Warden follows them in - the owner's *\"predators will leave "
		+ "the player alone once they enter the city base\"* is unanswered")
	_check(not code.contains("CITY_SANCTUARY_RADIUS"),
		"the wildlife measures the walls itself instead of asking the field. Two "
		+ "answers to one question is how the animals shelter somebody the "
		+ "enemies are still hunting")

	# Every place an animal steps goes through the one clamp. Counted rather
	# than assumed: there are three - the walk, the charge and the swim - and a
	# fourth added later that writes the position directly would walk into town.
	var loose: int = code.count("sprite.global_position += step")
	_check(loose == 0,
		("%d place(s) still move an animal without asking about the walls - one "
		+ "refusal in three copies is two that will not be fixed the next time "
		+ "the first one is") % loose)


## And the sky still reaches in.
##
## **The check that matters most in this file.** Every other rule says hostile
## things cannot reach you, and the thorough next step is to make the ground
## safe - at which point the quake, the funnel, the meteor and the flood all
## become things a player sits out behind a wall, and the earth's wrath becomes
## optional. The owner ruled the other way in as many words.
func _test_the_sky_is_not_blocked() -> void:
	var code: String = FileAccess.get_file_as_string(
		"res://scenes/battlefield/enemy_ground_strike.gd")
	_check(not code.is_empty(), "could not read the ground strike")
	_check(not code.contains("inside_city"),
		"a ground strike asks about the walls, so a Warden standing in the town "
		+ "is immune to the earth - the owner was explicit that *\"disasters can "
		+ "still inflict upon the players in the city base\"*, and a shelter "
		+ "from the sky makes the whole of the wrath a thing you sit out")
	_check(not code.contains("CITY_SANCTUARY_RADIUS"),
		"a ground strike measures the walls, which is the same immunity by "
		+ "another name")


# --- Harness -----------------------------------------------------------------

## The real battlefield, with only the town stubbed.
##
## **The dependency is overridden, never the behaviour.** A harness that
## reimplemented `inside_city` and `step_is_legal` would pass with both of them
## deleted from the game - which is the "tested the function and not the wiring"
## fault this project has shipped twice, in a warm-up that bought nothing and a
## set line the row builder never called.
##
## `Battlefield.inside_city` reads `town_node()`, which on a real field wants a
## built grid, a run and a town scene. That is the only thing standing between
## this gate and the shipping code, so that is the only thing replaced. The node
## is never added to the tree, so `_ready` does not run and nothing else has to
## exist.
class _Sheltering extends Battlefield:
	var walls_at: Vector2 = Vector2.ZERO
	var _core: Node2D = null

	func town_node() -> Node2D:
		if _core == null:
			_core = Node2D.new()
			# **Owned, not merely made.** A `Node2D` that is never added to a tree
			# and never freed is a leaked `CanvasItem`, which the sweep reports as
			# DIRTY rather than as a failure - a gate that leaks is a gate people
			# learn to ignore the colour of. Parented here so freeing the field
			# takes it too.
			add_child(_core)
		_core.global_position = walls_at
		return _core


class _Standin extends Node2D:
	pass


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[sanctuary] " + why)
