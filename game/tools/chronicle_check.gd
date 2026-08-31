extends Node

## Production gate for the bounded objective layer.
##
## Uses only in-memory account state and restores it before exit. It never calls
## save_game(), so the developer's real save is not read back or overwritten.

func _ready() -> void:
	# **Held for the whole run.** This gate edits MetaState in place - a wiped
	# stash, a drained Tools purse, a reset flag - and any save reached while
	# that scratch state is live overwrites a real player's file. One did, on
	# 2026-08-31, and a stash is the one thing here that cannot be restored.
	MetaState.hold_saves()
	var objectives: Array[ChronicleObjectiveData] = ContentDB.chronicle_objectives_sorted()
	var ids: Dictionary = {}
	var orders: Dictionary = {}
	# A floor, not an exact count. Pinned to 8 this failed the moment six more
	# deeds were authored - a gate that has to be edited to add content is a
	# gate that teaches people to edit gates.
	var content_ok: bool = objectives.size() >= 8
	var total_reward: int = 0
	for objective: ChronicleObjectiveData in objectives:
		content_ok = content_ok and not objective.id.is_empty()
		content_ok = content_ok and not objective.display_name.is_empty()
		content_ok = content_ok and not objective.description.is_empty()
		content_ok = content_ok and objective.tool_reward > 0
		content_ok = content_ok and not ids.has(objective.id)
		content_ok = content_ok and not orders.has(objective.order)
		ids[objective.id] = true
		orders[objective.order] = true
		total_reward += objective.tool_reward
	print("[chronicle] content=%d unique=%s one-time Tools=%d" % [
		objectives.size(), str(content_ok), total_reward])

	var first_road: Dictionary = {
		"act": 1,
		"victory": false,
		"towers_built": 0,
		"tower_upgrades": 0,
		"chieftains": 0,
		"town_damage": 0.0,
		"wounds": 0,
	}
	var premature: int = 0
	for objective: ChronicleObjectiveData in objectives:
		if objective.is_met(first_road):
			premature += 1

	# **Derived from the content, not written out.** Hand-written, this summary
	# satisfied whichever deeds existed when it was typed: six new ones were
	# authored and the "a full clear completes everything" invariant quietly
	# started testing 8 of 14. The summary is now built by asking each objective
	# what would satisfy it, so adding a deed extends the run that has to meet
	# it and the gate never needs editing to accept new content.
	var full_clear: Dictionary = _summary_meeting_everything(objectives)

	var before_completed: Array[String] = MetaState.completed_objectives.duplicate()
	var before_tools: int = MetaState.tools
	MetaState.completed_objectives = []
	MetaState.tools = 0
	var earned: Array[String] = MetaState.complete_chronicle(full_clear)
	var after_first: int = MetaState.tools
	var repeated: Array[String] = MetaState.complete_chronicle(full_clear)
	var after_second: int = MetaState.tools
	var serialized: Dictionary = JSON.parse_string(MetaState.serialized_save()) as Dictionary
	var saved_ids: Array = (serialized.get("chronicle", {}) as Dictionary).get(
		"completed", []) as Array
	var persistence_ok: bool = int(serialized.get("version", 0)) == MetaState.SAVE_VERSION \
		and saved_ids.size() == objectives.size()
	MetaState.completed_objectives = before_completed
	MetaState.tools = before_tools

	var one_time: bool = earned.size() == objectives.size() and repeated.is_empty() \
		and after_first == total_reward and after_second == after_first
	print("[chronicle] first-road completions=%d, full-clear=%d, repeat=%d" % [
		premature, earned.size(), repeated.size()])
	print("[chronicle] one-time=%s persistence=%s" % [str(one_time), str(persistence_ok)])

	var sink_ok: bool = _test_tools_have_somewhere_to_go()

	if not content_ok or premature != 0 or not one_time or not persistence_ok 			or not sink_ok:
		push_error("Chronicle objective gate failed")
		get_tree().quit(1)
		return
	for _frame: int in 5:
		await get_tree().process_frame
	get_tree().quit(0)


## Tools must never be awarded with nothing to buy.
##
## The eight roster towers cost 32 of the 40 Tools a player may hold, so once the
## roster was complete every later run banked Tools against a cap that bought
## nothing - and kept telling the player they had earned some. A currency that
## accumulates toward nothing is worse than no currency at all.
##
## Two properties, and the second is the one that rots: that a fresh account has
## somewhere to spend, and that spending everything actually *reaches* the
## finished state rather than stalling with Tools in hand. The second is checked
## by draining it, because a fall-through that silently stops one shelf early
## would satisfy any assertion written about the start.
func _test_tools_have_somewhere_to_go() -> bool:
	var towers: Array[String] = MetaState.unlocked_towers.duplicate()
	var plans: Array[String] = MetaState.unlocked_blueprints.duplicate()
	var held: int = MetaState.tools

	# **Builds the account it tests rather than reading the one that is here.**
	# Run against the developer's own save this reported a fresh account with
	# nothing to buy, because that account already owns everything - and it would
	# have passed on a clean machine, which is how a gate ends up only being true
	# where nobody runs it.
	MetaState.unlocked_towers = MetaState.STARTING_TOWERS.duplicate()
	MetaState.unlocked_blueprints = []
	MetaState.tools = 0

	var ok: bool = MetaState.tools_have_a_sink()
	if not ok:
		push_error("[chronicle] a fresh account has nothing to spend Tools on")

	# Drain it. Every award must either unlock something or refuse to pay out.
	var spins: int = 0
	while MetaState.tools_have_a_sink() and spins < 200:
		spins += 1
		var bought: Array[String] = MetaState.award_tools(3, true)
		if bought.is_empty() and MetaState.tools >= Balance.TOOLS_MAX:
			ok = false
			push_error("[chronicle] Tools capped at %d with %s still unbought"
				% [MetaState.tools, "content"])
			break
	if spins >= 200:
		ok = false
		push_error("[chronicle] Tools never reach a finished account")
	# A finished account banks nothing rather than banking silently.
	var before: int = MetaState.tools
	MetaState.award_tools(3, true)
	if MetaState.tools != before:
		ok = false
		push_error("[chronicle] a finished account is still being awarded Tools")
	print("[chronicle] Tools drained in %d runs; finished account banks nothing" % spins)

	MetaState.unlocked_towers = towers
	MetaState.unlocked_blueprints = plans
	MetaState.tools = held
	return ok


## The most demanding run the Chronicle describes: enough of every metric to
## satisfy every deed at once.
##
## `AT_MOST` deeds want a floor rather than a ceiling - "no town damage" is met
## by zero - so those pull the value down while `AT_LEAST` deeds push it up. A
## metric nobody measures stays absent, which is what a real summary would do.
func _summary_meeting_everything(objectives: Array[ChronicleObjectiveData]) -> Dictionary:
	var out: Dictionary = {"act": 1, "victory": true}
	for objective: ChronicleObjectiveData in objectives:
		out["act"] = maxi(int(out["act"]), objective.minimum_act)
		var key: String = objective.summary_key()
		if key == "act":
			out["act"] = maxi(int(out["act"]), int(ceil(objective.target)))
			continue
		var wanted: float = objective.target
		if out.has(key):
			wanted = maxf(float(out[key]), objective.target) 				if objective.comparison == ChronicleObjectiveData.Comparison.AT_LEAST 				else minf(float(out[key]), objective.target)
		out[key] = wanted
	return out
