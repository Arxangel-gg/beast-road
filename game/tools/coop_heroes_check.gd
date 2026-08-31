extends Node

## Two heroes on one field: they exist, they move independently, and the phase
## rules bind both the same way.
##
##   godot --headless --path game res://tools/coop_heroes_check.tscn
##
## Step 3 of `docs/COOP_DESIGN.md`. Separate from `coop_check.tscn` on purpose:
## that one is about the wire and needs no game, this one needs a real Run and
## has nothing to say about sockets. Mixing them would make each slower and
## neither clearer.
##
## What this is really defending is the seam. The hero reads its intentions from
## a `HeroInput` rather than from `Input`, and if that ever regresses to a
## per-call-site "is this hero mine" test, the partner's hero starts twitching
## whenever the local player walks — which is exactly the kind of bug that is
## obvious in co-op and invisible to everyone testing alone.

## Fixed, so a failure is reproducible. See `breather_check` for what an unseeded
## harness costs.
const SEED: int = 173205080

var _failures: int = 0
var _run: Node = null
var _field: Battlefield = null


func _ready() -> void:
	MetaState.settings["tutorial_seen"] = true
	MetaState.story_intro_seen = true
	RunState.reset(false, SEED)
	GameDirector.run_active = true
	_run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate()
	add_child(_run)
	for _f: int in 16:
		await get_tree().process_frame
	_field = _run.get("battlefield") as Battlefield
	# A live scope marks its own hero present when it activates. This harness
	# drives the field directly without entering a phase that does, so it says
	# so itself - being in the world is something a scope grants now, not
	# something a hero has merely by existing.
	if _field != null and _field.hero != null:
		_field.hero.set_present(true)

	_test_alone_there_is_one_hero()
	await _test_a_partner_appears_and_is_remote()
	await _test_the_two_move_independently()
	await _test_buttons_latch_rather_than_drop()
	await _test_the_phase_binds_both()
	await _test_a_partner_leaving_leaves_nothing_held()
	await _test_a_battlefield_built_mid_session_finds_its_partner()
	# Before the revive test, which deliberately ends the run on its third wipe
	# and leaves nothing standing to be found.
	await _test_the_field_can_see_both_heroes()
	await _test_going_down_costs_nothing_until_both_do()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[coop-heroes] PASS - one hero alone, two in company, independent, "
			+ "phase-bound, revived without a wound, and both of them findable")
	get_tree().quit(_failures)


## A single-player run is untouched by any of this.
func _test_alone_there_is_one_hero() -> void:
	_check(_field != null, "the harness needs a battlefield")
	if _field == null:
		return
	_check(_field.hero != null, "the local hero must exist")
	_check(_field.partner_hero() == null, "there must be no partner in a solo run")
	_check(_field.heroes().size() == 1, "and exactly one hero on the field")
	_check(_field.hero.input is LocalHeroInput,
		"a solo hero must be driven locally, not by an empty source")

	# **The roster speaks in single player too**, and that is the path the game
	# actually takes. This harness used to build a field and count heroes
	# without ever letting the roster fire, so it agreed with a friendlier
	# version of the game than the one people play - and a phantom second hero
	# stood at the town for weeks, taking wildlife bites and emitting
	# `hero_damaged`, which plays the hurt sound and the blood vignette no matter
	# which hero it came from. Reported repeatedly as "something invisible at the
	# city hurts me wherever I stand".
	# **No await.** The signal is synchronous, and awaiting here yields to
	# `_ready`, which runs the next test and spawns the partner this check would
	# then blame on the roster. A gate that races the suite it belongs to reports
	# whichever finished first.
	Coop.party().roster_changed.emit()
	_check(_field.heroes().size() == 1,
		"a roster change in a solo run must not conjure a second hero, saw %d"
			% _field.heroes().size())
	_check(_field.partner_hero() == null,
		"and must not leave a partner standing at the town")


## The partner's hero is an ordinary hero with a different source.
func _test_a_partner_appears_and_is_remote() -> void:
	var partner: Hero = _spawn_partner()
	_check(partner != null, "a partner hero must be spawnable")
	if partner == null:
		return
	await get_tree().process_frame
	_check(_field.partner_hero() == partner, "the battlefield must know about it")
	_check(_field.heroes().size() == 2, "and count two heroes")
	_check(partner.input is RemoteHeroInput,
		"the partner must be driven from the wire, never from this keyboard")
	_check(_field.hero.input is LocalHeroInput,
		"and spawning one must not have changed who drives the local hero")
	# The group answers "whose health does the HUD show". Two claimants makes it
	# a coin flip - the same ambiguity the raid hero is kept out of the group to
	# avoid.
	_check(not partner.is_in_group(Hero.GROUP),
		"the partner must not claim the hero group")
	_check(get_tree().get_nodes_in_group(Hero.GROUP).size() <= 1,
		"exactly one hero may be the HUD's subject")


## The whole point: one moves, the other does not.
func _test_the_two_move_independently() -> void:
	var partner: Hero = _field.partner_hero()
	if partner == null:
		_check(false, "the harness needs a partner to move")
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	var remote := partner.input as RemoteHeroInput
	var partner_from: Vector2 = partner.global_position
	var local_from: Vector2 = _field.hero.global_position

	# A held stick, pushed right, for several physics frames.
	for _f: int in 20:
		remote.apply([Vector2.RIGHT, Vector2.RIGHT, 0])
		await get_tree().physics_frame

	_check(partner.global_position.distance_to(partner_from) > 20.0,
		"a partner told to walk must walk, moved %.1f"
			% partner.global_position.distance_to(partner_from))
	# The local hero has no input in a headless run, so it must be exactly where
	# it was. If it moved, the two heroes are sharing a source.
	_check(_field.hero.global_position.distance_to(local_from) < 1.0,
		"the local hero must not move because its partner did")


## A press that lands between physics frames must not be lost.
##
## Packets and frames do not line up. Assigning the button mask instead of
## latching it drops presses that arrive in the gap — an attack that never comes
## out, every few seconds, for no reason the player can see.
func _test_buttons_latch_rather_than_drop() -> void:
	var partner: Hero = _field.partner_hero()
	if partner == null:
		return
	var remote := partner.input as RemoteHeroInput

	# Two snapshots before a single read, which is the case that drops a press.
	remote.apply([Vector2.ZERO, Vector2.RIGHT, HeroInput.BUTTON_ATTACK])
	remote.apply([Vector2.ZERO, Vector2.RIGHT, HeroInput.BUTTON_DASH])
	_check(remote.pressed(HeroInput.BUTTON_ATTACK),
		"an attack that arrived before the next tick must survive to be read")
	_check(remote.pressed(HeroInput.BUTTON_DASH),
		"and so must a dash arriving in the same gap")
	# Edges, not levels: read once, gone.
	_check(not remote.pressed(HeroInput.BUTTON_ATTACK),
		"a press must be consumed by reading, or one tap attacks forever")
	await get_tree().process_frame


## Neither hero may act in a phase the other cannot.
##
## Nothing special was written to make this true — the phase is read from
## `RunState`, which both heroes share. The check exists because a later change
## could easily give the partner its own path and break it, and the failure would
## look like "the guest can attack during Preparation", which is a cheat rather
## than a glitch.
func _test_the_phase_binds_both() -> void:
	var partner: Hero = _field.partner_hero()
	if partner == null:
		return
	for phase: RunState.Phase in [RunState.Phase.PREPARATION, RunState.Phase.ROAD_BATTLE]:
		RunState.set_phase(phase)
		await get_tree().physics_frame
		_check(_field.hero.can_fight() == partner.can_fight(),
			"both heroes must agree on whether combat is allowed in phase %d" % int(phase))
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)


## A partner leaving must not leave a hero holding a direction.
func _test_a_partner_leaving_leaves_nothing_held() -> void:
	var partner: Hero = _field.partner_hero()
	if partner == null:
		return
	var remote := partner.input as RemoteHeroInput
	remote.apply([Vector2.RIGHT, Vector2.RIGHT, HeroInput.BUTTON_ATTACK])
	_field.get_node("CoopHeroes").call("despawn_partner")
	await get_tree().process_frame

	_check(_field.partner_hero() == null, "the partner must leave the field")
	_check(_field.heroes().size() == 1, "leaving a run alone with one hero")
	_check(remote.move() == Vector2.ZERO,
		"a departed partner must not leave a walk direction behind: a remote hero "
		+ "still holding one walks into a wall forever")
	_check(not remote.pressed(HeroInput.BUTTON_ATTACK),
		"nor an unspent press")


## A battlefield built while a partner is *already* connected must still get one.
##
## This is the bug that made co-op look broken from a player's seat, and it was
## invisible to every check here because they all spawn the partner by hand.
##
## Partner spawning was purely signal-driven, and both announcements - the host's
## `coop_partner_joined`, the guest's CONNECTED - fire while the players are
## still in the *menu*. `CoopHeroes` is built by `Battlefield._ready()`, long
## after, so it listened for something that had already happened and heard
## nothing. Neither player got a partner hero, so neither could see the other;
## and with no `_remote` on the host, the guest's input went nowhere and its hero
## was corrected back to spawn on every state packet - "the guest cannot move".
##
## Two of the three things reported from play, one missing line.
func _test_a_battlefield_built_mid_session_finds_its_partner() -> void:
	var heroes: Node = _field.get_node_or_null("CoopHeroes")
	if heroes == null:
		_check(false, "the battlefield must build its CoopHeroes system")
		return
	heroes.call("despawn_partner")
	await get_tree().process_frame
	_check(_field.partner_hero() == null, "the harness starts from no partner")

	# A fresh CoopHeroes, standing in for the one a rebuilt scope would create,
	# with a partner already present rather than about to arrive.
	var rebuilt := CoopHeroes.new()
	rebuilt.name = "CoopHeroesRebuilt"
	rebuilt.field = _field
	_field.add_child(rebuilt)
	await get_tree().process_frame

	# Playing alone here, so nothing should appear - the check is that it *asks*
	# rather than waits, and asks the right question.
	_check(not Coop.partner_present(), "this harness plays alone")
	_check(rebuilt.call("partner") == null,
		"a system built with nobody connected must not conjure a partner")
	_check(rebuilt.has_method("spawn_partner"),
		"and must be able to spawn one the moment it is asked, not only when told")
	rebuilt.queue_free()
	await get_tree().process_frame


func _spawn_partner() -> Hero:
	var heroes: Node = _field.get_node_or_null("CoopHeroes")
	if heroes == null:
		_check(false, "the battlefield must build its CoopHeroes system")
		return null
	return heroes.call("spawn_partner") as Hero


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("[coop-heroes] %s" % why)


## The revive rules, which are almost entirely about what does *not* happen.
##
## Owner's re-cut, 2026-08-25, replacing a design where dying in co-op still cost
## a Wound and a partner only sped the respawn up. The rules now:
##
## * one player down costs the run **nothing** - no Wound, and no clock that
##   would quietly stand them back up without anybody helping
## * a partner who reaches them returns them **where they fell**, fragile
## * both down at once costs **one** Wound between them, not one each
## * three Wounds ends the run, exactly as in solo play
##
## Every one of those is a negative or an off-by-one, which is why this exists:
## none of them would announce itself by failing visibly in a normal run, and
## the double-charge in particular would just look like a run that ended early.
func _test_going_down_costs_nothing_until_both_do() -> void:
	# Re-read and re-spawn rather than assuming: the tests above deliberately
	# take a partner away and rebuild the battlefield, and a harness that assumed
	# its own earlier state would be testing the previous test.
	_field = _run.get("battlefield") as Battlefield
	if _field == null or _field.hero == null:
		_check(false, "the harness needs a battlefield for the revive rules")
		return
	var partner: Hero = _field.partner_hero()
	if partner == null:
		partner = _spawn_partner()
	if partner == null:
		_check(false, "the harness needs both heroes for the revive rules")
		return
	await get_tree().process_frame
	var hero: Hero = _field.hero
	RunState.hero_wounds = 0

	var fell_at := Vector2(120.0, -40.0)
	hero.global_position = fell_at
	hero.go_down(fell_at)
	_check(hero.is_downed(), "a hero who goes down must be downed")
	_check(not hero.is_alive(), "and must not be standing")
	_check(RunState.hero_wounds == 0,
		"going down alone must cost no Wound, got %d" % RunState.hero_wounds)

	# A full respawn delay of waiting must not get them up. Nothing but a person
	# should, and a clock left running here is the whole bug.
	for _f: int in 90:
		await get_tree().process_frame
	_check(hero.is_downed(), "a downed hero must not stand up on a timer")

	hero.set_revive_progress(1.0)
	hero.revive_in_place()
	_check(hero.is_alive(), "a revived hero must be on their feet")
	_check(hero.global_position.distance_to(fell_at) < 1.0,
		"and must come back where they fell, not at the spawn")
	_check(RunState.hero_wounds == 0, "a revive must still cost no Wound")

	# Both down: one Wound between them, and both back up.
	RunState.hero_wounds = 0
	hero.go_down(hero.global_position)
	partner.go_down(partner.global_position)
	EventBus.coop_team_wipe.emit()
	await get_tree().process_frame
	_check(RunState.hero_wounds == 1,
		"a wipe must cost exactly one Wound between the pair, got %d"
			% RunState.hero_wounds)
	_check(hero.is_alive() and partner.is_alive(),
		"and must put both players back on their feet")

	# The third Wound ends the run, exactly as it does alone. Left until last:
	# ending the run tears down what everything above is standing on.
	RunState.hero_wounds = Balance.HERO_MAX_WOUNDS - 1
	hero.go_down(hero.global_position)
	partner.go_down(partner.global_position)
	EventBus.coop_team_wipe.emit()
	await get_tree().process_frame
	_check(RunState.hero_wounds == Balance.HERO_MAX_WOUNDS,
		"the last wipe must take the final Wound")
	_check(not GameDirector.run_active,
		"and %d Wounds must end the run" % Balance.HERO_MAX_WOUNDS)


## Everything that looks for "a hero" must be able to find either one.
##
## This is the bug that made co-op look finished and play broken. `hero_node()`
## answers "this machine's player" - the camera follows it, the HUD describes it
## - and enemies were asking it. So every enemy in a two-player game walked past
## the guest as though they were not there: no aggro, no melee, no ranged fire
## and therefore no damage at all. The loot had the same fault for the same
## reason and flew to the host over a guest standing on top of it.
##
## The distinction is worth keeping and worth testing, because both halves are
## reasonable-looking calls that mean opposite things.
func _test_the_field_can_see_both_heroes() -> void:
	_field = _run.get("battlefield") as Battlefield
	if _field == null or _field.hero == null:
		_check(false, "the harness needs a battlefield")
		return
	var partner: Hero = _field.partner_hero()
	if partner == null:
		partner = _spawn_partner()
	if partner == null:
		return
	await get_tree().process_frame

	# Every hero is in the all-heroes group; exactly one holds the active group.
	# Asked of the field rather than counted in the group: a harness that has
	# spawned and discarded partners leaves the group holding more than the field
	# does, and the field is the thing enemies actually ask.
	_check(_field.heroes().size() == 2,
		"the field must hold both heroes, holds %d" % _field.heroes().size())
	_check(get_tree().get_nodes_in_group(Hero.GROUP_ANY).size() >= 2,
		"and both must be findable as heroes")
	_check(get_tree().get_nodes_in_group(Hero.GROUP).size() <= 1,
		"but only one may be the *active* hero: that group answers a different "
			+ "question and the camera reads it")

	_field.hero.global_position = Vector2(-600.0, 0.0)
	partner.global_position = Vector2(600.0, 0.0)
	await get_tree().process_frame
	_check(_field.nearest_hero(Vector2(500.0, 0.0)) == partner,
		"an enemy beside the partner must be offered the partner")
	_check(_field.nearest_hero(Vector2(-500.0, 0.0)) == _field.hero,
		"and one beside the local hero must be offered that one")

	# And a hero whose body is down is not somebody to walk at.
	partner.go_down(partner.global_position)
	await get_tree().process_frame
	_check(_field.nearest_hero(Vector2(500.0, 0.0)) == _field.hero,
		"a downed hero must not be offered as a target, however close they are")
	_check(_field.hero_is_alive(),
		"and the field must still report a hero alive while one of them stands")
	partner.respawn_from_wipe()
	await get_tree().process_frame
