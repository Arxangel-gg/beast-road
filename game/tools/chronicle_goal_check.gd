extends Node

## Scratch account changes are held in memory throughout. No real save is
## loaded, written or replaced; persistence is exercised through its serializer
## and settings reader on a fresh MetaState instance outside the scene tree.

const TEST_SEED: int = 193807
const UNKNOWN_ID: String = "chronicle-check-no-such-deed"

var _failures: PackedStringArray = []
var _writes: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	var saved_settings: Dictionary = MetaState.settings.duplicate(true)
	var saved_completed: Array[String] = MetaState.completed_objectives.duplicate()
	var saved_tools: int = MetaState.tools
	var saved_active: bool = GameDirector.run_active
	var saved_mirror: Dictionary = RunState.chronicle_host_progress.duplicate(true)
	MetaState.save_written.connect(_on_save_written)
	_test_snapshot_validation()
	_test_reward_summary()
	_test_authored_statuses()
	_test_pin_and_payout()
	_test_settings_round_trip()
	await _test_guest_settlement()
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	_check(_writes == 0 and MetaState.saves_held(),
		"pinning and payout tests must never write the real save")
	MetaState.settings = saved_settings
	MetaState.completed_objectives = saved_completed
	MetaState.tools = saved_tools
	GameDirector.run_active = saved_active
	RunState.chronicle_host_progress = saved_mirror
	MetaState.save_written.disconnect(_on_save_written)
	MetaState.resume_saves()
	for failure: String in _failures:
		push_error("[chronicle goal] " + failure)
	print("[chronicle goal] %s — snapshots, guest end lifecycle, authored statuses and persistent pin" % (
		"PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _snapshot() -> Dictionary:
	return {
		"seed": TEST_SEED, "act": Balance.FINAL_ASCENT_ACT,
		"victory": true, "final": true, "kills": 1200,
		"towers_built": 14, "tower_upgrades": 16, "raids": 3,
		"chieftains": 2, "wounds": 0, "town_damage": 0.0,
	}


func _test_snapshot_validation() -> void:
	var valid: Dictionary = _snapshot()
	_check(ChronicleGoals.validated_progress(valid, TEST_SEED) == valid,
		"the summit's final snapshot must validate without changing its values")
	for act: int in range(1, Balance.FINAL_ASCENT_ACT + 1):
		var regional: Dictionary = valid.duplicate(true)
		regional["act"] = act
		_check(not ChronicleGoals.validated_progress(regional, TEST_SEED).is_empty(),
			"all regional acts and the summit must be accepted: %d" % act)
	for key: String in valid:
		var missing: Dictionary = valid.duplicate(true)
		missing.erase(key)
		_check(ChronicleGoals.validated_progress(missing, TEST_SEED).is_empty(),
			"missing %s must reject the whole snapshot" % key)
	var integer_keys: Array[String] = ["seed", "act"]
	integer_keys.append_array(ChronicleGoals.COUNTERS)
	for key: String in integer_keys:
		for wrong: Variant in [1.0, "1", true, null]:
			_reject_value(valid, key, wrong, "non-integer " + key)
	for key: String in ["victory", "final"]:
		for wrong: Variant in [0, 1, "true", null]:
			_reject_value(valid, key, wrong, "non-boolean " + key)
	for key: String in ChronicleGoals.COUNTERS:
		_reject_value(valid, key, -1, "negative " + key)
	for act: int in [-1, 0, Balance.FINAL_ASCENT_ACT + 1]:
		_reject_value(valid, "act", act, "out-of-range act")
	for wrong: Variant in [-0.01, NAN, INF, -INF, "0", true, null]:
		_reject_value(valid, "town_damage", wrong, "invalid town damage")
	_check(ChronicleGoals.validated_progress(valid, TEST_SEED + 1).is_empty(),
		"another run's seed must never be accepted")
	var integral_damage: Dictionary = valid.duplicate(true)
	integral_damage["town_damage"] = 12
	var normalized: Dictionary = ChronicleGoals.validated_progress(integral_damage, TEST_SEED)
	_check(normalized.get("town_damage") is float and normalized.get("town_damage") == 12.0,
		"finite integral damage must normalize to the real damage metric")
	var extra: Dictionary = valid.duplicate(true)
	extra["tools"] = 99999
	extra["unlocks"] = ["not-an-award"]
	var clean: Dictionary = ChronicleGoals.validated_progress(extra, TEST_SEED)
	_check(clean == valid and not clean.has("tools") and not clean.has("unlocks"),
		"wire extras must be discarded rather than becoming reward instructions")
	clean["kills"] = 0
	_check(extra["kills"] == valid["kills"], "validation must return independent measurements")
	var local: Dictionary = ChronicleGoals.local_progress()
	_check(local.get("seed") == RunState.run_seed and local.get("kills") == RunState.enemies_killed
		and local.get("wounds") == RunState.wounds_suffered
		and local.get("town_damage") == RunState.town_damage_taken
		and not bool(local.get("final", true)),
		"periodic local progress must read RunState and must not claim a final result")


func _reject_value(valid: Dictionary, key: String, value: Variant, description: String) -> void:
	var bad: Dictionary = valid.duplicate(true)
	bad[key] = value
	_check(ChronicleGoals.validated_progress(bad, TEST_SEED).is_empty(),
		"snapshot must reject " + description)


func _test_reward_summary() -> void:
	var mirrored: Dictionary = _snapshot()
	var local: Dictionary = {"seed": TEST_SEED, "victory": true, "kills": 0, "personal": 17}
	var before: PackedByteArray = var_to_bytes(local)
	_check(ChronicleGoals.reward_summary(local, false, {}) == local,
		"solo/host payout must retain its ordinary completed-run summary")
	_check(ChronicleGoals.reward_summary(local, true, mirrored) == mirrored,
		"guest payout must use the matching final host measurements, not puppet counters")
	_check(ChronicleGoals.reward_summary(local, true, {}).is_empty(),
		"an unsynchronized guest must receive no inferred flawless award")
	var periodic: Dictionary = mirrored.duplicate(true)
	periodic["final"] = false
	_check(ChronicleGoals.reward_summary(local, true, periodic).is_empty(),
		"an older periodic snapshot is not sufficient evidence for payout")
	var wrong_seed: Dictionary = mirrored.duplicate(true)
	wrong_seed["seed"] = TEST_SEED + 1
	_check(ChronicleGoals.reward_summary(local, true, wrong_seed).is_empty(),
		"a previous run's final snapshot cannot pay the current run")
	var defeat: Dictionary = mirrored.duplicate(true)
	defeat["victory"] = false
	_check(ChronicleGoals.reward_summary(local, true, defeat).is_empty(),
		"a defeated snapshot cannot authorize a victory payout")
	var local_defeat: Dictionary = {"seed": TEST_SEED, "victory": false}
	_check(ChronicleGoals.reward_summary(local_defeat, true, mirrored).is_empty(),
		"a victorious snapshot cannot authorize a defeat payout")
	_check(ChronicleGoals.reward_summary(local_defeat, true, defeat) == defeat,
		"matching final defeat measurements still earn non-victory deeds")
	_check(var_to_bytes(local) == before, "reward selection must not mutate the local summary")


func _test_authored_statuses() -> void:
	_check(ContentDB.ui_texts.get("chronicle_text") == ChronicleGoals.COPY,
		"Chronicle copy must be registered by its authored content ID")
	var objectives: Array[ChronicleObjectiveData] = ContentDB.chronicle_objectives_sorted()
	_check(not objectives.is_empty(), "authored Chronicle objectives must exist")
	for objective: ChronicleObjectiveData in objectives:
		var met: Dictionary = _meeting_summary(objective)
		_check(objective.is_met(met), "the fixture must meet " + objective.id)
		_check(ChronicleGoals.status_for(objective, met) == ChronicleGoals.COPY.eligible,
			"a met deed must be eligible, never immediately paid: " + objective.id)
		_check(ChronicleGoals.status_for(objective, {}) == ChronicleGoals.COPY.waiting,
			"missing host progress must never imply a met deed: " + objective.id)
		var missed: Dictionary = met.duplicate(true)
		var key: String = objective.summary_key()
		if objective.comparison == ChronicleObjectiveData.Comparison.AT_MOST:
			missed[key] = objective.target + 1.0
			_check(ChronicleGoals.status_for(objective, missed) == ChronicleGoals.COPY.failed,
				"an exceeded irreversible condition must say try next run: " + objective.id)
		elif objective.target > 0.0:
			missed[key] = maxf(0.0, objective.target - 1.0)
			var expected_progress: String = ChronicleGoals.COPY.progress % [
				int(missed[key]), int(ceil(objective.target))]
			_check(ChronicleGoals.status_for(objective, missed).contains(expected_progress)
				and ChronicleGoals.status_for(objective, missed) != ChronicleGoals.COPY.eligible,
				"unfinished cumulative deeds must show measurable progress: " + objective.id)
		if objective.minimum_act > 1:
			var early: Dictionary = met.duplicate(true)
			early["act"] = objective.minimum_act - 1
			_check(ChronicleGoals.status_for(objective, early).contains(
				ChronicleGoals.COPY.act_gate % objective.minimum_act),
				"minimum-act gates must stay visible: " + objective.id)
		if objective.requires_victory:
			var live: Dictionary = met.duplicate(true)
			live["victory"] = false
			_check(ChronicleGoals.status_for(objective, live).contains(
				ChronicleGoals.COPY.victory_required),
				"meeting a threshold must not hide its victory requirement: " + objective.id)
		var expected_reward: String = (ChronicleGoals.COPY.reward_one
			if objective.tool_reward == 1 else ChronicleGoals.COPY.reward) % objective.tool_reward
		_check(ChronicleGoals.reward_text(objective) == expected_reward,
			"reward text must use authored quantity and singular/plural: " + objective.id)


func _meeting_summary(objective: ChronicleObjectiveData) -> Dictionary:
	var summary: Dictionary = _snapshot()
	summary["act"] = maxi(objective.minimum_act, int(ceil(objective.target))) \
		if objective.metric == ChronicleObjectiveData.Metric.ACT_REACHED else objective.minimum_act
	summary[objective.summary_key()] = objective.target \
		if objective.metric != ChronicleObjectiveData.Metric.ACT_REACHED else summary["act"]
	return summary


func _test_pin_and_payout() -> void:
	var objectives: Array[ChronicleObjectiveData] = ContentDB.chronicle_objectives_sorted()
	if objectives.is_empty():
		return
	MetaState.completed_objectives = []
	MetaState.tools = 0
	MetaState.settings[ChronicleGoals.SETTING] = ""
	var goal: ChronicleObjectiveData = objectives[0]
	_check(Chronicle.select(goal.id) and Chronicle.selected_id() == goal.id,
		"an unfinished authored deed must be selectable")
	_check(not Chronicle.select(UNKNOWN_ID) and Chronicle.selected_id() == goal.id,
		"an unknown ID must be refused without replacing a valid pin")
	GameDirector.run_active = false
	_check(Chronicle.hud_text().is_empty(), "an inactive run must never display stale goal text")
	GameDirector.run_active = true
	_check(Chronicle.hud_text().contains(goal.display_name), "an active pin must be named on the HUD")
	_check(MetaState.tools == 0 and MetaState.completed_objectives.is_empty(),
		"pinning and reading progress must not award Tools or complete deeds")
	_check(Chronicle.select("") and Chronicle.selected_id().is_empty(), "a pin must be removable")
	_check(Chronicle.hud_text().is_empty(), "an unpinned goal must leave no HUD text")
	MetaState.settings[ChronicleGoals.SETTING] = 42
	_check(Chronicle.selected_id().is_empty(), "a malformed saved preference must not become a goal")
	MetaState.settings[ChronicleGoals.SETTING] = UNKNOWN_ID
	_check(Chronicle.selected_id().is_empty(), "removed content must not leave an invalid goal")
	_check(Chronicle.select(goal.id), "the valid goal must remain selectable after bad saved data")
	var all_met: Dictionary = _snapshot()
	var expected: Array[String] = []
	var reward: int = 0
	for objective: ChronicleObjectiveData in objectives:
		expected.append(objective.id)
		reward += objective.tool_reward
		var key: String = objective.summary_key()
		all_met[key] = maxf(float(all_met.get(key, 0.0)), objective.target) \
			if objective.comparison == ChronicleObjectiveData.Comparison.AT_LEAST \
			else minf(float(all_met.get(key, objective.target)), objective.target)
	var earned: Array[String] = MetaState.complete_chronicle(all_met)
	_check(earned == expected and MetaState.tools == mini(reward, Balance.TOOLS_MAX),
		"run-end payout must award every met deed, not only the pin")
	var tools_after: int = MetaState.tools
	_check(MetaState.complete_chronicle(all_met).is_empty() and MetaState.tools == tools_after,
		"repeated settlement must never pay a deed twice")
	_check(not Chronicle.select(goal.id), "completed deeds cannot be newly selected")
	_check(Chronicle.hud_text().is_empty(), "an earned pin must leave the active HUD")
	_check(Chronicle.select(""), "an earned pin must still be removable")


func _test_settings_round_trip() -> void:
	var objectives: Array[ChronicleObjectiveData] = ContentDB.chronicle_objectives_sorted()
	if objectives.is_empty():
		return
	var id: String = objectives[0].id
	MetaState.settings[ChronicleGoals.SETTING] = id
	RunState.chronicle_host_progress = {"private_run_counter": 12345}
	var serialized: String = MetaState.serialized_save()
	var payload: Dictionary = JSON.parse_string(serialized) as Dictionary
	var settings: Dictionary = payload.get("settings", {}) as Dictionary
	_check(settings.get(ChronicleGoals.SETTING) == id,
		"the selected ID must serialize as a local setting")
	_check(not serialized.contains("private_run_counter")
		and not payload.has("chronicle_host_progress"),
		"authoritative run measurements must never leak into the persistent schema")
	var script: GDScript = load("res://autoload/MetaState.gd") as GDScript
	var fresh: Node = script.new() as Node
	fresh.call("hold_saves")
	var defaults: Dictionary = fresh.get("settings") as Dictionary
	_check(defaults.has(ChronicleGoals.SETTING) and defaults[ChronicleGoals.SETTING] == "",
		"a fresh process must declare the setting before load rejects unknown keys")
	settings["unknown_chronicle_test_setting"] = "must not load"
	fresh.call("_read_settings", settings)
	var restored: Dictionary = fresh.get("settings") as Dictionary
	_check(restored.get(ChronicleGoals.SETTING) == id,
		"the shipping settings reader must restore a pin into fresh defaults")
	_check(not restored.has("unknown_chronicle_test_setting"),
		"adding the pin must not weaken unknown-setting rejection")
	fresh.free()


func _on_save_written() -> void:
	_writes += 1


## Exercise the shipping director and relay, not only the summary selector:
## a relayed fatal wipe precedes the final counters on the reliable channel.
func _test_guest_settlement() -> void:
	var summaries: Array[Dictionary] = []
	var capture: Callable = func(_victory: bool, summary: Dictionary) -> void:
		summaries.append(summary.duplicate(true))
	EventBus.run_ended.connect(capture)
	var relay: CoopRelay = Coop.relay()
	var saved_state: int = Coop._state
	var heroes := CoopHeroes.new()
	EventBus.coop_team_wipe.connect(heroes._on_team_wipe)
	for victory: bool in [false, true]:
		Coop._state = Coop.State.OFFLINE
		RunState.reset(false, TEST_SEED)
		RunState.act = Balance.FINAL_ASCENT_ACT
		RunState.hero_wounds = RunState.max_wounds() - 1
		MetaState.completed_objectives.clear()
		GameDirector.run_active = true
		Coop._state = Coop.State.CONNECTED
		var before: int = summaries.size()
		var runs_before: int = MetaState.runs_started
		GameDirector.end_run(victory)
		GameDirector._on_coop_run_ended(victory)
		_send_fact(relay, CoopRelay.Fact.TEAM_WIPE, [])
		_check(GameDirector.run_active and summaries.size() == before
			and MetaState.runs_started == runs_before and MetaState.completed_objectives.is_empty(),
			"local end, synthetic end and relayed fatal wipe must not settle a guest")
		var ending: EndingScreen = null
		if victory:
			ending = load("res://scenes/ui/ending_screen.tscn").instantiate() as EndingScreen
			add_child(ending)
			ending.play()
			ending._finish()
			_check(ending.visible and ending.finish_button.disabled
				and ending.finish_button.text == ending.waiting_for_host_text
				and GameDirector.run_active,
				"guest ending must visibly wait without dismissing or paying early")
		var final_summary: Dictionary = _snapshot()
		final_summary["victory"] = victory
		final_summary["wounds"] = RunState.max_wounds()
		_send_fact(relay, CoopRelay.Fact.CHRONICLE_PROGRESS, [final_summary])
		_send_fact(relay, CoopRelay.Fact.RUN_ENDED, ["true"])
		_send_fact(relay, CoopRelay.Fact.RUN_ENDED, [victory], 2)
		_check(GameDirector.run_active, "malformed or non-host terminal facts must be ignored")
		_send_fact(relay, CoopRelay.Fact.RUN_ENDED, [victory])
		_check(not GameDirector.run_active and summaries.size() == before + 1
			and MetaState.runs_started == runs_before + 1,
			"host terminal fact must settle the guest exactly once")
		if summaries.size() > before:
			var result: Dictionary = summaries.back()
			_check(result.get("kills") == final_summary["kills"],
				"guest recap must use final shared kills instead of zero puppet kills")
			var expected: Array[String] = []
			for objective: ChronicleObjectiveData in ContentDB.chronicle_objectives_sorted():
				if objective.is_met(final_summary):
					expected.append(objective.id)
			_check(result.get("chronicle") == expected and not expected.is_empty(),
				"guest must receive all eligible final deeds on victory and defeat")
		_send_fact(relay, CoopRelay.Fact.RUN_ENDED, [victory])
		_check(summaries.size() == before + 1 and MetaState.runs_started == runs_before + 1,
			"duplicate terminal facts must not duplicate rewards or records")
		if ending != null:
			_check(not ending.visible and not get_tree().paused,
				"host settlement must dismiss the guest ending and unpause the debrief")
			# Let the interrupted narrative coroutine observe dismissal and exit.
			await get_tree().create_timer(EndingScreen.LINE_GAP + 0.1).timeout
			ending.queue_free()
			await get_tree().process_frame
	EventBus.coop_team_wipe.disconnect(heroes._on_team_wipe)
	heroes.free()
	EventBus.run_ended.disconnect(capture)
	Coop._state = saved_state


func _send_fact(relay: CoopRelay, kind: int, args: Array, sender: int = 1) -> void:
	relay._on_packet(sender, var_to_bytes([CoopRelay.TAG_FACT, kind, args]))


func _check(condition: bool, description: String) -> void:
	if not condition:
		_failures.append(description)
