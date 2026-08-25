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

	_test_alone_there_is_one_hero()
	await _test_a_partner_appears_and_is_remote()
	await _test_the_two_move_independently()
	await _test_buttons_latch_rather_than_drop()
	await _test_the_phase_binds_both()
	await _test_a_partner_leaving_leaves_nothing_held()
	await _test_a_battlefield_built_mid_session_finds_its_partner()

	if _run != null and is_instance_valid(_run):
		_run.queue_free()
	_run = null
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _f: int in 20:
		await get_tree().process_frame
	if _failures == 0:
		print("[coop-heroes] PASS - one hero alone, two in company, independent, phase-bound")
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
