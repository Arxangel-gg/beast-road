extends Node

## Matched sets: assembled, paid, bounded, and visible.
##
##   godot --headless --path game res://tools/gear_set_check.tscn
##
## Owner brief, 2026-09-15: *"set items similar to Diablo's style which grant
## extra bonuses at appropriate increments ... a wide variety of sets ... wearing
## a full set should have a visual vfx game juicy effect on players"*.
##
## **The bound is the omen bound once more**: a set tier may only move a number
## `Modifiers` already resolves, and every tier lands in the same flat table a
## socketed relic feeds. What a set *costs* is choice - slots locked to
## particular kinds - and never attribute points, which stay the capped scale
## levelling shares (working rule 7).
##
## **Six ways a set is a lie, and five of them are silent:**
##
## - **It cannot be assembled.** Two members in one slot, or a member that is not
##   a gear kind at all, and the set is content nobody will ever see complete -
##   the failure this project has shipped more than any other.
## - **It is never dealt.** A member kind that `Stash.roll` cannot produce is a
##   piece that does not drop, so the set is unfinishable for a different reason.
## - **A tier charges nothing.** A misspelt `Modifiers` key lands under a name
##   nothing reads: the panel still says the words and the player still gave up
##   the slots. This is exactly the fault `omen_check` caught on its first run.
## - **A fraction of a countable thing.** `Tower` reads `chain_targets` with
##   `int()` and `RunState` rounds `wave_foresight`, so 0.6 of either is a tier
##   that takes the slots and hands out nothing.
## - **It out-runs what it replaced.** A set worth more than the legendary
##   affixes those slots could have carried makes matching the only correct play,
##   and the ten-act curve was tuned with neither. Measured against the affix
##   ceiling rather than asserted.
## - **A kind in two sets.** Then wearing it advances both, which is not a
##   decision, and neither set is what its panel says it is.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_every_set_can_be_assembled()
	_test_every_tier_charges_something()
	_test_the_ceiling()
	_test_the_row_says_which_set_a_piece_is_in()
	await _test_wearing_one()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[gear-set] PASS - %d checks over %d sets: each can be assembled "
			+ "and dealt, each tier moves a number something reads, none "
			+ "out-runs the affixes it replaced, and a finished one shows")
			% [_checks, ContentDB.gear_sets.size()])
	else:
		push_error("[gear-set] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## **A set that cannot be completed is content nobody meets.**
func _test_every_set_can_be_assembled() -> void:
	var sets: Array[GearSetData] = ContentDB.gear_sets_sorted()
	_check(sets.size() >= 6,
		"only %d sets, which is not the wide variety the brief asked for"
			% sets.size())
	var claimed: Dictionary = {}
	for one: GearSetData in sets:
		_check(one.members.size() >= 2,
			"%s has %d member, which is a piece rather than a set"
				% [one.id, one.members.size()])
		var slots: Dictionary = {}
		for member: String in one.members:
			var kind: GearData = ContentDB.gear(member)
			_check(kind != null,
				"%s names %s, which is not a gear kind" % [one.id, member])
			if kind == null:
				continue
			_check(not slots.has(kind.slot),
				("%s wants two pieces in the %s slot, so it can never be "
					+ "completed") % [one.id, GearData.Slot.keys()[kind.slot]])
			slots[kind.slot] = true
			_check(not claimed.has(member),
				"%s is in both %s and %s, so wearing it advances two sets"
					% [member, claimed.get(member, "?"), one.id])
			claimed[member] = one.id
			# **And it has to actually drop.** A member the roll can never
			# produce is a set that is unfinishable for a second reason.
			_check(kind.weight > 0.0,
				"%s names %s, which never drops" % [one.id, member])
		_check(one.members.size() <= GearData.Slot.size(),
			"%s has more members than a hero has slots" % one.id)


## **A tier that charges nothing is the fault `omen_check` caught on day one.**
func _test_every_tier_charges_something() -> void:
	var keys: Dictionary = {}
	for name: String in Modifiers.keys_in_use():
		keys[name] = true
	for one: GearSetData in ContentDB.gear_sets_sorted():
		_check(one.tier_count() >= 2,
			("%s offers %d tier, and an increment needs at least two")
				% [one.id, one.tier_count()])
		_check(one.tier_counts.size() == one.tier_effects.size()
				and one.tier_counts.size() == one.tier_magnitudes.size()
				and one.tier_counts.size() == one.tier_lines.size(),
			("%s has tiers of different lengths - counts %d, effects %d, "
				+ "magnitudes %d, lines %d") % [one.id, one.tier_counts.size(),
				one.tier_effects.size(), one.tier_magnitudes.size(),
				one.tier_lines.size()])
		var previous: int = 0
		for tier: int in one.tier_count():
			var wants: int = one.tier_counts[tier]
			_check(wants > previous,
				"%s tier %d wants %d pieces after a tier that wanted %d"
					% [one.id, tier, wants, previous])
			previous = wants
			_check(wants <= one.members.size(),
				"%s tier %d wants %d pieces out of %d - it can never open"
					% [one.id, tier, wants, one.members.size()])
			var key: String = one.tier_effects[tier]
			_check(keys.has(key),
				("%s tier %d moves '%s', which nothing in Modifiers reads - the "
					+ "player pays the slots and gets nothing")
					% [one.id, tier, key])
			_check(not is_zero_approx(one.tier_magnitudes[tier]),
				"%s tier %d moves %s by nothing" % [one.id, tier, key])
			if one.is_counted(tier):
				var amount: float = one.tier_magnitudes[tier]
				_check(is_equal_approx(amount, roundf(amount)),
					("%s tier %d grants %.2f of %s, which is counted with int() "
						+ "and rounds away") % [one.id, tier, amount, key])
			_check(not one.tier_lines[tier].strip_edges().is_empty(),
				"%s tier %d says nothing to the player" % [one.id, tier])
		_check(one.aura_colour.a > 0.0,
			"%s has an invisible aura, so finishing it shows nothing" % one.id)


## **A set must not out-run what wearing it gave up.**
func _test_the_ceiling() -> void:
	# What the slots a set occupies could have carried instead: the affix
	# ceiling, on every piece, at the counts the top rarities roll. Measured
	# rather than asserted, so the day either ceiling moves this still means
	# what it says.
	var best_affixes: int = 0
	for count: int in Balance.GEAR_LEGENDARY_COUNT:
		best_affixes = maxi(best_affixes, count)
	for one: GearSetData in ContentDB.gear_sets_sorted():
		var total: float = 0.0
		for tier: int in one.tier_count():
			var amount: float = absf(one.tier_magnitudes[tier])
			if one.is_counted(tier):
				continue
			_check(amount <= Balance.GEAR_SET_CEILING + 0.0001,
				"%s tier %d moves %.3f against a ceiling of %.3f"
					% [one.id, tier, amount, Balance.GEAR_SET_CEILING])
			total += amount
		var replaced: float = float(one.members.size()) \
			* float(best_affixes) * Balance.GEAR_LEGENDARY_CEILING
		_check(total <= replaced,
			("%s is worth %.2f across its tiers against the %.2f of affixes "
				+ "its %d slots gave up - matching would be the only play")
				% [one.id, total, replaced, one.members.size()])


## **Driven through the real equip door**, because the failure worth catching is
## a set counted by pieces rather than by kinds, or one whose tiers never reach
## `Modifiers` at all.
func _test_wearing_one() -> void:
	var target: GearSetData = null
	for one: GearSetData in ContentDB.gear_sets_sorted():
		if one.members.size() >= 3:
			target = one
			break
	_check(target != null, "a set of three or more is needed to wear")
	if target == null:
		return
	var key: String = target.tier_effects[0]
	var stash_before: Array = MetaState.stash.duplicate(true)
	var equipped_before: Dictionary = MetaState.equipped.duplicate()
	MetaState.equipped = {}
	Modifiers.rebuild()
	var before: float = Modifiers.value(key)

	# One piece at a time, through the stash the player uses.
	var worn: int = 0
	for member: String in target.members:
		var kind: GearData = ContentDB.gear(member)
		if kind == null:
			continue
		MetaState.receive_gear(Stash.make(member, 0, 1))
		MetaState.equip(kind.slot, MetaState.stash.size() - 1)
		worn += 1
		Modifiers.rebuild()
		_check(Modifiers.set_pieces_worn(target.id) == worn,
			"wearing %d pieces of %s counted as %d"
				% [worn, target.id, Modifiers.set_pieces_worn(target.id)])
		if worn < target.tier_counts[0]:
			_check(is_equal_approx(Modifiers.value(key), before),
				("%s paid its first tier at %d pieces, before the %d it asks "
					+ "for") % [target.id, worn, target.tier_counts[0]])
		elif worn == target.tier_counts[0]:
			_check(not is_equal_approx(Modifiers.value(key), before),
				("%s reached %d pieces and moved '%s' by nothing - the tier is "
					+ "authored and read by nobody")
					% [target.id, worn, key])

	# **A finished set shows.** Through the hero's own node rather than by
	# reading the table again: the brief asked for something the player can see.
	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var hero: Hero = run.battlefield.hero if run.battlefield != null else null
	_check(hero != null, "a hero is needed to wear it")
	if hero != null:
		for _settle: int in 4:
			await get_tree().process_frame
		var shown: GearSetData = hero.worn_set()
		_check(shown != null and shown.id == target.id,
			("a hero in a whole set shows %s") % ["nothing" if shown == null
				else shown.id])
		# And taking one off puts it away again.
		var aura: SetAura = hero.get_node_or_null("SetAura") as SetAura
		_check(aura != null, "the hero must carry the aura node")
		_check(aura == null or aura.is_processing(),
			("the aura is not ticking, so it could never notice anything - "
				+ "process mode %d") % (0 if aura == null else aura.process_mode))
		MetaState.equipped.erase(ContentDB.gear(target.members[0]).slot)
		Modifiers.rebuild()
		var waited: float = 0.0
		while waited < SetAura.RE_READ * 3.0 and hero.worn_set() != null:
			await get_tree().process_frame
			waited += get_process_delta_time()
		_check(hero.worn_set() == null,
			"the aura stayed on %.2fs after a piece came off" % waited)
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	run.queue_free()
	for _frame: int in 12:
		await get_tree().process_frame
	MetaState.stash = stash_before
	MetaState.equipped = equipped_before
	Modifiers.rebuild()


## **A set says so on the piece, before it is finished.**
##
## `Modifiers.set_pieces_worn` documented itself as "for the screens and the
## gate" and was called by the gate and by nothing else, so the only thing that
## ever told a player a set existed was the aura at their feet once it was
## already complete. A player looking for the fourth Emberwind piece had no way
## to know they held three.
##
## Driven through `GearRow.set_text`, which is the string the stash actually
## draws, rather than through `set_pieces_worn` - the count was never the part
## that was missing.
func _test_the_row_says_which_set_a_piece_is_in() -> void:
	var target: GearSetData = null
	for one: GearSetData in ContentDB.gear_sets_sorted():
		if not one.members.is_empty():
			target = one
			break
	_check(target != null, "no set has members")
	if target == null:
		return
	var member: GearData = ContentDB.gear(String(target.members[0]))
	_check(member != null, "%s names a member that is not gear" % target.id)
	if member == null:
		return
	# **Read off a real row, not off the helper.**
	#
	# The first cut of this called `GearRow.set_text` directly, so removing the
	# call site in the row builder left it passing - it tested the function and
	# not the wiring, which is the exact failure `audio_verify` was extended for
	# this morning. It builds the row the stash builds and reads the label back.
	var row: HBoxContainer = GearRow.build({
		"kind": member.id, "rarity": 0, "level": 1, "uid": "gate",
	})
	_check(row != null, "the stash could not build a row for %s" % member.id)
	var said: String = _row_detail(row)
	if row != null:
		row.queue_free()
	_check(said.contains(target.display_name),
		("a piece of %s does not name its set on the row, so the only way to find "
			+ "the next piece is to have noticed the last one: \"%s\"")
			% [target.display_name, said])
	_check(said.contains("/%d" % target.members.size()),
		"and it does not say how many the set takes: \"%s\"" % said)
	# A piece in no set says nothing, rather than "none 0/0".
	for value: Variant in ContentDB.gear_kinds.values():
		var loner := value as GearData
		if loner == null or ContentDB.gear_set_of(loner.id) != null:
			continue
		var plain: HBoxContainer = GearRow.build({
			"kind": loner.id, "rarity": 0, "level": 1, "uid": "gate",
		})
		var plain_text: String = _row_detail(plain)
		if plain != null:
			plain.queue_free()
		_check(not plain_text.contains("/"),
			"%s is in no set and its row still printed set text: \"%s\""
				% [loner.id, plain_text])
		break


## The second line of a built row - slot, level, bonuses, price, and the set.
static func _row_detail(row: HBoxContainer) -> String:
	if row == null:
		return ""
	for child: Node in row.get_children():
		var column := child as VBoxContainer
		if column == null:
			continue
		var lines: PackedStringArray = []
		for inner: Node in column.get_children():
			var label := inner as Label
			if label != null:
				lines.append(label.text)
		if lines.size() >= 2:
			return lines[1]
	return ""


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[gear-set] " + why)
