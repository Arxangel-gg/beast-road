extends Node

## Owns scene flow and the run lifecycle (GDD §9).
##
## Splash -> Menu -> Run -> win/lose -> unlock payout -> Menu. Nothing else
## calls `change_scene_to_file`; systems ask here so there is one place that
## knows what state the game is in.

## The four scopes the player moves between during a run, plus the overlays
## that suspend them.
enum Scope {
	BATTLEFIELD,
	TOWN,
	BEAST,
	RAID,
	CROSSROAD,
}

const SPLASH_SCENE: String = "res://scenes/ui/splash.tscn"
const MENU_SCENE: String = "res://scenes/ui/main_menu.tscn"
const RUN_SCENE: String = "res://scenes/run/run.tscn"

var current_scope: Scope = Scope.BATTLEFIELD

## True between run_started and run_ended.
var run_active: bool = false

## Whether this player's Preparation is currently a build phase or a fight.
##
## **Local to this machine, deliberately.** In co-op one player can be laying
## traps while the other clears the wolves off the north road, and a shared flag
## would make that impossible. Nothing about it crosses the wire and nothing in
## `RunState` holds it - it is a choice about what your own mouse does, in the
## same family as `current_scope`.
##
## Lives here rather than in the cursor or the hero because both of them ask it
## and neither owns it, and a rule that two systems have to agree on belongs in
## one place. See `Hero.can_fight` and `PlacementCursor._is_active`.
var build_mode: bool = true


## Switches between laying things down and swinging at things.
func set_build_mode(building: bool) -> void:
	if build_mode == building:
		return
	build_mode = building
	EventBus.build_mode_changed.emit(building)


func toggle_build_mode() -> void:
	set_build_mode(not build_mode)


## Why a run ended without being played to a conclusion.
##
## Distinct from `end_run`, which records a result. This is for a run that simply
## stopped existing - today only because a co-op host went away.
var abandoned_reason: String = ""


func abandon_run(reason: String) -> void:
	if not run_active:
		return
	# Deliberately **not** `end_run(false)`. That writes a defeat into the record,
	# raises the defeat screen and offers a score for a run nobody finished. The
	# player did not lose; the session went away, and calling that a loss would
	# put a phantom run on a leaderboard.
	abandoned_reason = reason
	run_active = false
	goto_menu()


## Pauses or resumes for both players.
##
## Pausing has to be shared or it is not pausing: one player halts while the
## other keeps fighting a wave that is still walking on a machine which has
## stopped simulating it, and they come back to two different battlefields.
##
## Either player may do it. A pause is not an authority decision - it is somebody
## needing to stop - and making the guest ask permission to put the game down
## would be the wrong kind of correct.
func set_paused(paused: bool) -> void:
	if get_tree().paused == paused:
		return
	# Nothing outside a run is pausable, and nothing outside a run may pause a
	# partner. A menu that could stop somebody else's game is a menu with reach
	# it should not have.
	if not run_active and paused:
		return
	get_tree().paused = paused
	if not Coop.partner_present():
		return
	# Applied here first and announced second, on both sides. Needing to put the
	# game down is not an authority decision, so a guest must not wait for
	# permission to stop - but the host has to be told, or one player halts while
	# the other keeps fighting a wave that is still walking on a machine which has
	# stopped simulating it.
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.PAUSE, [paused])
		return
	EventBus.coop_paused.emit(paused)


## The host's run ended, so this one does too.
##
## The guest builds its own summary from its own `RunState` rather than being
## sent one: the two mirror each other, and a summary that travelled would have
## to carry a hero, a stash and a tier the guest already has better copies of.
func _on_coop_run_ended(victory: bool) -> void:
	if not Coop.is_guest():
		return
	end_run(victory)


## Somebody skipped a cinematic, so both of us skip it.
##
## Either player may. Sitting through the rest of an opening alone because your
## friend skipped theirs is the same failure as the original bug, only quieter:
## it leaves the two of you arriving at the battlefield a minute apart.
func skip_cinematic() -> void:
	if not Coop.partner_present():
		return
	if Coop.is_guest():
		var relay: CoopRelay = Coop.relay()
		if relay != null:
			relay.request(CoopRelay.Request.SKIP_CINEMATIC)
		return
	EventBus.coop_cinematic_skipped.emit()


## A guest asked for something that is not the battlefield's to grant.
##
## Pause and cinematic skips are handled here rather than in `CoopWorld` because
## that router needs a battlefield to exist, and a cinematic plays before there
## is one - which is exactly when a skip request arrives.
func _on_coop_request(kind: int, args: Array, _from: int) -> void:
	if not Coop.is_host():
		return
	match kind:
		CoopRelay.Request.PAUSE:
			if args.size() == 1:
				set_paused(bool(args[0]))
		CoopRelay.Request.SKIP_CINEMATIC:
			EventBus.coop_cinematic_skipped.emit()


func _on_coop_paused(paused: bool) -> void:
	# Applied directly rather than through `set_paused`, which would announce it
	# straight back and leave the two machines telling each other to pause for as
	# long as anyone cared to watch.
	get_tree().paused = paused
	# And the panel comes with it. A game that simply stops, with no menu and no
	# cause, is worse than a menu somebody else opened - and either player being
	# able to resume means both need something to resume *from*.
	for node: Node in get_tree().get_nodes_in_group(&"pause_menu"):
		if node.has_method("set_showing"):
			node.call("set_showing", paused)


## The host started a run, so this guest starts the same one.
##
## The *same* one: the seed travels, because both machines have to roll an
## identical world. The guest's RunState mirrors the host's, and a mirror of a
## different world is not a mirror - it is two games sharing a socket.
##
## Guest-only. On the host `start_run` is what announced this, and acting on it
## again would restart the run it just began.
func _on_coop_run_started(seed_value: int) -> void:
	if Coop.is_host() or run_active:
		return
	start_run(seed_value)


## A co-op session failed while a run was live.
##
## Only a *guest* can be orphaned this way: a host owns the run and its session
## ending is its own decision. `is_host()` answers true for a lone player too, so
## this cannot fire for someone who was never networked.
func _on_coop_failed(reason: String) -> void:
	if run_active and not Coop.is_host():
		abandon_run(reason)


func _ready() -> void:
	EventBus.boss_defeated.connect(_on_boss_felled)
	# Navigation belongs here, not in the network layer. `Coop` reports that the
	# session is gone; deciding that this means leaving the run is this node's
	# job, and keeping it so is what stops the co-op layer being able to change
	# scenes out from under whatever is running.
	EventBus.coop_failed.connect(_on_coop_failed)
	# The guest follows the host into the run. Without this, co-op connected two
	# people who then sat in two separate menus - which is what "co-op is not
	# fully integrated" looked like from the outside, and it was right.
	EventBus.coop_run_started.connect(_on_coop_run_started)
	EventBus.coop_paused.connect(_on_coop_paused)
	# Every Preparation opens ready to build, which is what the phase is for.
	# Staying in fight mode from the last one would have a player click three
	# times at a tower slot before working out why nothing is happening.
	# Preparation opens ready to build and *closes* ready to fight.
	#
	# Staying in build mode past the horn left a player holding a grid overlay
	# that swallows clicks, with a wave walking in - reported from play as build
	# menus still open when the round started. The mode follows the phase in both
	# directions now, on every machine, because each player holds their own.
	EventBus.phase_changed.connect(func(now: int, _before: int) -> void:
		set_build_mode(now == RunState.Phase.PREPARATION))
	EventBus.coop_request_received.connect(_on_coop_request)
	EventBus.coop_run_ended.connect(_on_coop_run_ended)
	CursorKit.apply()


func _exit_tree() -> void:
	CursorKit.clear()


func goto_splash() -> void:
	_change(SPLASH_SCENE)


func goto_menu() -> void:
	run_active = false
	get_tree().paused = false
	Engine.time_scale = 1.0
	CursorKit.use_default()
	# **The session ends with the run.**
	#
	# It used to outlive it, and the consequences were not obvious: a guest still
	# reading its results screen could pause a host who had already reached the
	# main menu, and every button there went dead with no visible cause. The
	# relay also went on exchanging hero positions and world clocks for a run
	# that no longer existed.
	#
	# Two players who want another run make another session, which is one button
	# and unambiguous about what they are joining.
	Coop.leave()
	_change(MENU_SCENE)


## The opening cinematic, played on the way into a player's first run.
##
## Here rather than in `Run._ready()`, and the distinction is not cosmetic: every
## headless tool instantiates `run.tscn` directly, so an intro living in the run
## scene played - and paused the tree for eighteen seconds - inside the balance
## test, the layout check and the snuff soak. All three failed, and none of them
## failed for a reason that had anything to do with what they were testing.
##
## This is the door a *player* comes through. Tools do not use it.
func _play_intro() -> void:
	if StoryIntro.already_seen():
		return
	var intro := StoryIntro.new()
	intro.name = "StoryIntro"
	get_tree().root.add_child(intro)
	await intro.play()
	intro.queue_free()


func start_run(requested_seed: int = 0) -> void:
	var consumed_cache: bool = not MetaState.resource_cache.is_empty()
	# The world is rolled and announced **before** the cinematic, not after.
	#
	# The intro is eighteen seconds and it used to run first, so the host played
	# its whole opening before telling the guest a run had begun - and the guest
	# then started its own eighteen seconds. One player watched a cinematic while
	# the other watched a menu, and they arrived on the battlefield most of a
	# minute apart. Told first, both cinematics play at once and both players
	# arrive together.
	#
	# Announced *after* the reset, because the seed sent has to be the one
	# actually rolled: a fresh run requests 0 and `RunState` picks, so announcing
	# the request would send a zero and have the guest roll a world of its own.
	RunState.reset(true, requested_seed)
	if Coop.is_host() and Coop.partner_present():
		EventBus.coop_run_started.emit(RunState.run_seed)
	# The party is playing, so it is not looking for anybody. The row goes now
	# rather than at the end of the run - a table that only empties when somebody
	# remembers is a table full of games nobody can join.
	Coop.directory().withdraw()

	await _play_intro()

	# Consuming Treasury carry-over is a real transaction. Persist it now so a
	# crash/restart cannot spend the same cache repeatedly.
	if consumed_cache:
		MetaState.save_game()
	run_active = true
	current_scope = Scope.BATTLEFIELD
	get_tree().paused = false
	Engine.time_scale = 1.0
	_change(RUN_SCENE)


## Ends the run, pays out unlocks, and records statistics. `victory` is true
## only when the Act 3 boss died.
func end_run(victory: bool) -> void:
	if not run_active:
		return
	run_active = false
	# A run is one shared thing, so it ends for both. Announced before the
	# summary is built: the guest has its own summary to build from its own
	# RunState, and waiting would leave it standing in its town with no report.
	if Coop.is_host() and Coop.partner_present():
		EventBus.coop_run_ended.emit(victory)

	var summary: Dictionary = {
		"victory": victory,
		"seed": RunState.run_seed,
		"roads": RunState.road_history.duplicate(true),
		"distance": RunState.distance_travelled,
		"act": RunState.act,
		# The wave the run reached, which is the leaderboard's main progress
		# term. `act` alone cannot carry it: two runs both "lost in Act II" are
		# not the same run.
		"wave": RunState.wave_number,
		"kills": RunState.enemies_killed,
		"last_blow": RunState.last_blow_line(),
		"deaths": RunState.hero_deaths,
		"raids": RunState.raids_completed,
		"chieftains": RunState.chieftains_taken,
		"time": RunState.run_time_seconds,
		"planning_time": RunState.planning_time_seconds,
		"resources_earned": RunState.resources_earned,
		"resources_spent": RunState.resources_spent,
		"currency_earned": RunState.currency_earned.duplicate(true),
		"currency_spent": RunState.currency_spent.duplicate(true),
		"towers_built": RunState.towers_built,
		"tower_upgrades": RunState.tower_upgrades,
		"towers_sold": RunState.towers_sold,
		"towers_lost": RunState.towers_lost,
		"town_damage": RunState.town_damage_taken,
		"town_hits": RunState.town_hits_taken,
		"peak_pressure": RunState.peak_lane_pressure,
		"most_common_wave": RunState.most_common_wave_archetype(),
		"wave_archetypes": RunState.wave_archetype_counts.duplicate(true),
		"command_earned": RunState.command_earned,
		"command_orders": RunState.command_orders_used.duplicate(true),
		"wounds": RunState.wounds_suffered,
		"hearthmends": RunState.hearthmends_used,
	}
	var unlocks: Array[String] = _pay_out_unlocks(victory)

	MetaState.runs_started += 1
	if victory:
		MetaState.runs_won += 1
		MetaState.act3_cleared = true
	# Chronicle rewards are one-time Tools. Bank them before ordinary run Tools
	# are spent so both payouts pass through the same roster purchase path.
	var completed: Array[String] = MetaState.complete_chronicle(summary)
	var chronicle_tools: int = 0
	for id: String in completed:
		var objective: ChronicleObjectiveData = ContentDB.chronicle_objective(id)
		if objective != null:
			chronicle_tools += objective.tool_reward
		EventBus.unlock_earned.emit("chronicle", id)
	# Tools for depth, and the roster they buy. Before the statistics, so the
	# debrief's unlock list already contains anything they paid for.
	var roster: Array[String] = MetaState.award_tools(RunState.act, victory)
	for id: String in roster:
		EventBus.unlock_earned.emit("tower", id)
		unlocks.append("tower:" + id)
	if victory:
		MetaState.award_sigil()

	MetaState.best_distance = maxf(MetaState.best_distance, RunState.distance_travelled)
	MetaState.total_enemies_killed += RunState.enemies_killed
	_bank_treasury_cache()
	MetaState.save_game()
	# Payout values are captured after payout. Previously the debrief showed the
	# balance and Legacy rank from before the run and omitted roster purchases.
	summary["tools"] = MetaState.tools
	summary["sigils"] = MetaState.sigils
	summary["unlocks"] = unlocks
	summary["chronicle"] = completed
	summary["chronicle_tools"] = chronicle_tools

	EventBus.run_ended.emit(victory, summary)


## Felling an act boss widens the roster by one tower, permanently.
##
## v4 §35: elements are never gated - the account opens able to build all four
## and every fusion. What is earned is the *roster*, the eight later towers that
## widen each element from two roles to four. Tied to act bosses so the toolkit
## grows at the pace the run does, and so a new player meets one new tower at a
## time instead of sixteen at once.
## Kept as the moment the *run* records depth; the roster itself is now bought
## with Tools when the run ends (v4 §35). Felling a boss used to unlock a tower
## outright, which meant a run that died in Act III with a boss down paid the
## same as one that cleared the act - and a currency the player can see going up
## reads as progress in a way a silent unlock does not.
func _on_boss_felled(_boss_id: String, _act: int) -> void:
	pass


## Everything the player touched this run enters the pool of things that *can*
## appear in future runs. Nothing carries over as power (GDD §10).
func _pay_out_unlocks(victory: bool) -> Array[String]:
	var earned: Array[String] = []

	for key: Variant in RunState.towers:
		var id: String = String(RunState.towers[key].get("tower_id", ""))
		if id.is_empty() or MetaState.unlocked_towers.has(id):
			continue
		MetaState.unlocked_towers.append(id)
		earned.append("tower:" + id)
		EventBus.unlock_earned.emit("tower", id)

	for relic_id: String in RunState.held_relics + RunState.socketed_relics:
		if MetaState.unlocked_relics.has(relic_id):
			continue
		MetaState.unlocked_relics.append(relic_id)
		earned.append("relic:" + relic_id)
		EventBus.unlock_earned.emit("relic", relic_id)

	# Reaching an act at all unlocks its terrain for future runs.
	for a: int in range(1, RunState.act + 1):
		var t: TerrainData = ContentDB.terrain_for_act(a)
		if t == null or MetaState.unlocked_terrains.has(t.id):
			continue
		MetaState.unlocked_terrains.append(t.id)
		earned.append("terrain:" + t.id)
		EventBus.unlock_earned.emit("terrain", t.id)

	if victory:
		for value: Variant in ContentDB.spells.values():
			var s := value as SpellData
			if s == null or MetaState.unlocked_spells.has(s.id):
				continue
			MetaState.unlocked_spells.append(s.id)
			earned.append("spell:" + s.id)

	# Milestone buildings enter the construction pool; they do not begin built.
	var milestones: Dictionary = {
		"treasury": RunState.act >= 2,
		"market": RunState.act >= 3,
		"watchtower": victory,
		"scavenging_post": RunState.chieftains_taken > 0,
	}
	for id: Variant in milestones:
		if bool(milestones[id]) and MetaState.unlock_building(String(id)):
			earned.append("building:" + String(id))

	return earned


func quit_game() -> void:
	MetaState.save_game()
	get_tree().quit()


func _bank_treasury_cache() -> void:
	var tier: int = RunState.building_tier("treasury")
	if tier <= 0:
		MetaState.resource_cache.clear()
		return
	var cap: int = MetaState.treasury_cap(Balance.TREASURY_CACHE_PER_TIER[clampi(
		tier - 1, 0, Balance.TREASURY_CACHE_PER_TIER.size() - 1)])
	MetaState.resource_cache.clear()
	for id: String in RunState.CURRENCIES:
		MetaState.resource_cache[id] = mini(RunState.currency(id), cap)


func _change(path: String) -> void:
	# Deferred: this is routinely called from a signal handler inside the scene
	# being torn down, and changing scenes from inside one is a crash.
	get_tree().call_deferred("change_scene_to_file", path)
