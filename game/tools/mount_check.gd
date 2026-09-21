extends Node

## Mounts: bought, saddled, ridden, and got off.
##
##   godot --headless --path game res://tools/mount_check.tscn
##
## Owner brief, 2026-09-17: *"I'd eventually also like to add mounts that
## players can ride and the ability to get mounts from a vendor at the Hold with
## the right resources ... And mounts should also have sprint ability. But
## players need to dismount to fight and they dismount when they attack and
## start fighting where they dismounted."*
##
## **The bound is one sentence and it is what this gate exists to hold: a mount
## is movement and nothing else.** This project has refused a third power scale
## about a dozen times - spirit traits, discipline depth, synergies, omens, fish,
## professions, materials, set bonuses - and every one of those refusals was
## about a scale nobody was tuning. A mount is safe from that objection only for
## as long as three things stay true, and each of them is checkable:
##
## - **It is bounded speed.** A gallop outruns a sprint (owner re-cut,
##   2026-09-21) and may not exceed `Balance.MOUNT_GALLOP_CEILING`. **Measured
##   through `Hero.move_speed()`** rather than read off the resource, because the
##   resource is what a careless edit changes and the function is what the game
##   actually uses. A gate that read `MountData.gallop` back would pass on a
##   build where the hero multiplied it a second time.
## - **It cannot fight.** Mounted, the Warden may not swing, cast, loose, gather,
##   fish or take an egg - and the whole of that refusal lives in one mask, so
##   what this checks is that the mask covers the doors and that `can_fight()`
##   answers no before any phase is read.
## - **It spends the rider's SP, at the mount's own rate, and no further than
##   `MOUNT_GALLOP_RANGE` on a pool.** This invariant *was* the opposite - "the
##   horse's wind and never the Warden's SP" - and was amended deliberately on
##   2026-09-21 when the owner ruled that a mounted sprint costs SP. Amending a
##   gate's invariant is the one change that makes every later run agree with
##   the bug it was built to catch, so it is recorded in CLAUDE.md and here.
##   What replaces it is measured: the drain through the real tick against the
##   authored rate, an unsprinted mount spending nothing, and a rider who
##   empties the pool arriving winded and refused a gallop until the floor.
##
## **The ways this goes wrong:**
##
## - **A gallop past the ceiling, or a pool that carries it past the range.**
##   Then a mount is a free crossing of the map, and
##   every distance in this game - aggro, reach, the gap between roads - was
##   tuned against a Warden who could not cross ground that fast.
## - **A rider who can swing.** Then the dismount rule is decoration and a mount
##   is simply a faster fighter.
## - **An attack press that is swallowed.** The owner's words are that they
##   *"dismount when they attack and start fighting where they dismounted"*. A
##   dismount that ate the press is a button that reads as broken.
## - **A mount key that mutes itself.** Then the Warden cannot get off, which is
##   the one state this feature must never reach.
## - **A dangling saddled id.** A name in the save with no `MountData` behind it
##   is a hero riding nothing.
## - **A shop that creates.** Buying must spend exactly the price and never less.
## - **A paddock where every horse does the same thing.** Then it is one
##   animation drawn five times rather than a stable.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_the_bounds_are_authored()
	_test_the_stable_door()
	_test_a_dangling_name()
	await _test_the_field()
	await _test_the_paddock()
	MetaState.resume_saves()
	if _failures == 0:
		print(("[mount] PASS - %d checks: a gallop is bounded in speed and reach, "
			+ "a rider cannot fight, attacking gets them down and lets the swing "
			+ "through, a gallop spends SP at its own rate, and the stable never "
			+ "creates") % _checks)
	else:
		push_error("[mount] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- The numbers, before anything is stood up --------------------------------


## **Read from the data, not from the code.** The ceiling is checked again on a
## live hero below; this is the cheaper half, and it names the offending file.
func _test_the_bounds_are_authored() -> void:
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	_check(stock.size() >= 2,
		"a stable with %d mount in it is a slot rather than a stable" % stock.size())
	for kind: MountData in stock:
		_check(kind.gallop <= Balance.MOUNT_GALLOP_CEILING + 0.001,
			("%s gallops at %.2f against a ceiling of %.2f - a mount past the "
				+ "ceiling is a free crossing of the map, which every distance in "
				+ "this game was tuned against nobody having")
				% [kind.id, kind.gallop, Balance.MOUNT_GALLOP_CEILING])
		_check(kind.gallop > Balance.HERO_SPRINT_SPEED,
			("%s gallops at %.2f and the Warden sprints at %.2f - a horse the "
				+ "rider's own legs beat is one nobody would buy")
				% [kind.id, kind.gallop, Balance.HERO_SPRINT_SPEED])
		_check(kind.gallop > kind.speed,
			"%s gallops no faster than it walks" % kind.id)
		# **Reach, tuned against speed.** How far one full pool carries this
		# animal at a gallop: over the Warden's own sprint or the mount is
		# pointless, under the range or it is a free crossing.
		var reach: float = Balance.HERO_MOVE_SPEED * kind.gallop \
			* Balance.HERO_STAMINA_MAX / maxf(kind.sprint_drain, 0.001)
		var on_foot: float = Balance.HERO_MOVE_SPEED * Balance.HERO_SPRINT_SPEED \
			* Balance.HERO_STAMINA_MAX / Balance.HERO_STAMINA_DRAIN
		_check(reach <= Balance.MOUNT_GALLOP_RANGE,
			("%s carries a full pool %.0f units against a range of %.0f - its "
				+ "gallop and its drain are not tuned against each other")
				% [kind.id, reach, Balance.MOUNT_GALLOP_RANGE])
		_check(reach > on_foot,
			("%s carries a full pool %.0f units and the Warden's own legs carry "
				+ "it %.0f - there is no reason to be on it") % [kind.id, reach, on_foot])
		_check(kind.speed > 1.0,
			"%s is no faster than walking, so there is no reason to be on it"
				% kind.id)
		_check(kind.price > 0, "%s is free" % kind.id)
		_check(kind.sprint_drain > 0.0,
			("%s spends no SP to gallop, so its gallop is a speed setting rather "
				+ "than a resource") % kind.id)
		_check(not kind.display_name.is_empty(),
			"%s has no name to sell it under" % kind.id)
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no painting at %s" % [kind.id, kind.get_sprite_path()])

	# **The ceiling is above the sprint and stated**, which is the whole of the
	# 2026-09-21 re-cut: a mount is faster than the Warden on foot, by a number
	# written in `Balance` rather than implied by whichever mount is fastest.
	_check(Balance.MOUNT_GALLOP_CEILING > Balance.HERO_SPRINT_SPEED,
		("the mount ceiling is %.2f and a sprint is %.2f - a ceiling under the "
			+ "sprint makes every mount a slower way to run")
			% [Balance.MOUNT_GALLOP_CEILING, Balance.HERO_SPRINT_SPEED])

	# **The mute must not contain the way out.**
	_check(Hero.MOUNTED_MUTE & HeroInput.BUTTON_MOUNT == 0,
		"the mount key is muted while mounted, so the Warden cannot get off")
	for door: int in [HeroInput.BUTTON_ATTACK, HeroInput.HOLD_ATTACK,
			HeroInput.BUTTON_RANGED, HeroInput.BUTTON_INTERACT,
			HeroInput.HOLD_INTERACT]:
		_check(Hero.MOUNTED_MUTE & door != 0,
			"a rider can still reach door %d - gathering, fishing, shooting and "
				% door + "swinging are all one refusal or none")
	# **Not rebindable, and that is the decision rather than an omission.**
	# Keyboard binding is editable; controllers retain the focusable Ride action.
	_check(InputMap.has_action(&"mount"), "the mount key must be in the input map")
	var mount_rebindable: bool = false
	for row: Dictionary in KeyBindings.REBINDABLE:
		mount_rebindable = mount_rebindable or StringName(row.get("action", &"")) == &"mount"
	_check(mount_rebindable, "mount must appear in Settings key bindings")

	# The gallop is the sprint key, which is the owner's own clause, so it may
	# not be muted.
	_check(Hero.MOUNTED_MUTE & HeroInput.HOLD_SPRINT == 0,
		"the sprint key is muted while mounted, so a mount cannot gallop")


# --- The shop ----------------------------------------------------------------


## **A shop that creates would print Marks**, which is the bound
## `exchange_check` holds over the Ledger, in a second place.
func _test_the_stable_door() -> void:
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		return
	var kind: MountData = stock[0]
	MetaState.mounts.clear()
	MetaState.mount_saddled = ""

	MetaState.marks = kind.price - 1
	_check(not MetaState.buy_mount(kind.id),
		"the stable sold a %s to somebody a Mark short" % kind.display_name)
	_check(MetaState.marks == kind.price - 1,
		"a refused purchase still moved the purse to %d" % MetaState.marks)
	_check(MetaState.mounts.is_empty(),
		"a refused purchase still put a mount in the stable")

	MetaState.marks = kind.price + 25
	_check(MetaState.buy_mount(kind.id), "the stable refused an affordable mount")
	_check(MetaState.marks == 25,
		"buying a %d-Mark mount left %d of %d" % [kind.price, MetaState.marks,
			kind.price + 25])
	_check(MetaState.owns_mount(kind.id), "a bought mount is not owned")
	# The first one is saddled outright: a stable that made you buy a horse and
	# then press a second button to sit on it reads as the purchase not working.
	_check(MetaState.mount_saddled == kind.id,
		"the first mount bought was not saddled")

	_check(not MetaState.buy_mount(kind.id), "the stable sold the same mount twice")
	_check(MetaState.marks == 25, "a refused second purchase moved the purse")

	_check(not MetaState.saddle_mount("a_horse_that_does_not_exist"),
		"the stable saddled a mount nobody owns")
	_check(MetaState.saddle_mount(""), "the Warden may not choose to walk")
	_check(MetaState.saddled_mount() == null,
		"unsaddling left a mount under the Warden")

	# **Nothing but Marks and the stable moved.** A mount that granted an
	# attribute, a level or a currency would be the third power scale arriving
	# through a movement feature.
	var level: int = MetaState.hero_level
	var points: int = MetaState.hero_attribute_points
	var shards: int = MetaState.shards
	MetaState.marks = 100000
	for one: MountData in stock:
		MetaState.buy_mount(one.id)
	_check(MetaState.hero_level == level,
		"buying every mount in the stable moved the hero's level")
	_check(MetaState.hero_attribute_points == points,
		"buying every mount in the stable granted attribute points")
	_check(MetaState.shards == shards,
		"buying every mount in the stable moved the Shards")


## **A name with nothing behind it reads as on foot**, rather than as a hero
## riding null - which is the rule the pen applies to a dangling `taken`.
func _test_a_dangling_name() -> void:
	MetaState.mounts.clear()
	MetaState.mount_saddled = ""
	var written: Dictionary = {
		"owned": ["a_horse_that_does_not_exist"],
		"saddled": "a_horse_that_does_not_exist",
	}
	MetaState.call("_read_stable", written)
	_check(MetaState.mounts.is_empty(),
		"a mount the roster does not have was kept: %s" % [MetaState.mounts])
	_check(MetaState.mount_saddled.is_empty(),
		"a saddled name with no mount behind it survived the read")
	_check(MetaState.saddled_mount() == null,
		"a dangling name still answered with a mount")


# --- The field ---------------------------------------------------------------


func _test_the_field() -> void:
	var stock: Array[MountData] = ContentDB.mounts_sorted()
	if stock.is_empty():
		return
	var kind: MountData = stock[stock.size() - 1]
	MetaState.mounts.clear()
	MetaState.mounts.append(kind.id)
	MetaState.mount_saddled = kind.id

	var run: Run = (load("res://scenes/run/run.tscn") as PackedScene).instantiate() as Run
	add_child(run)
	for _frame: int in 20:
		await get_tree().process_frame
	var field: Battlefield = run.battlefield
	_check(field != null, "there must be a field")
	if field == null:
		run.queue_free()
		return
	RunState.set_phase(RunState.Phase.ROAD_BATTLE)
	field.resume()
	field.wave_director.stop()
	# **Nothing must be near**, or the danger rule refuses the mount and the
	# whole of this test measures a refusal. The same reason `raccoon_check`
	# stops the road before it watches a thief.
	var animals: Node = field.get_node_or_null("Wildlife")
	if animals != null and animals.has_method("clear"):
		animals.call("clear")
		animals.process_mode = Node.PROCESS_MODE_DISABLED
	for _settle: int in 3:
		await get_tree().process_frame

	var who: Hero = field.hero
	_check(who != null, "there must be a hero to put on a horse")
	if who == null:
		await _leave(run)
		return
	who.global_position = Vector2(4000.0, 4000.0)

	# --- It is not new speed --------------------------------------------------
	#
	# Measured off `move_speed()` three times on one hero, so bonuses, gear,
	# Swiftness and the flood are identical in all three readings and only the
	# thing under test differs.
	var walking: float = who.move_speed()
	_check(walking > 0.0, "a hero standing still has no speed at all")
	who.set("_sprinting", true)
	var sprinting: float = who.move_speed()
	who.set("_sprinting", false)

	_check(who.mount(), "the Warden refused to mount on empty ground")
	_check(who.is_mounted(), "the Warden mounted and is not mounted")
	var riding: float = who.move_speed()
	who.set("_galloping", true)
	var galloping: float = who.move_speed()
	who.set("_galloping", false)

	_check(galloping > sprinting,
		("a gallop moves at %.1f against a sprint's %.1f - a mount is faster than "
			+ "the Warden on foot, or it is not worth Marks") % [galloping, sprinting])
	_check(galloping <= walking * Balance.MOUNT_GALLOP_CEILING + 0.01,
		("a gallop moves at %.1f against a walk of %.1f and a ceiling of x%.2f - "
			+ "the hero is applying something the gate did not author")
			% [galloping, walking, Balance.MOUNT_GALLOP_CEILING])
	_check(riding > walking,
		"riding at %.1f is no faster than walking at %.1f" % [riding, walking])
	_check(galloping > riding,
		"a gallop at %.1f is no faster than a walk on the same animal at %.1f"
			% [galloping, riding])

	# --- A rider cannot fight -------------------------------------------------
	_check(not who.can_fight(),
		"a mounted Warden may still fight, which makes the dismount rule "
			+ "decoration")
	_check(who.input.muted != 0, "a mounted Warden's input is not muted at all")
	# Driven rather than read: the mask is what the eight interact call sites
	# ask through, so what matters is that asking through it answers no.
	_check(not who.input.held(HeroInput.HOLD_ATTACK),
		"a mounted Warden's held attack still reads true")

	# --- A gallop spends SP at the mount's own rate ---------------------------
	#
	# **Amended 2026-09-21.** This block used to hold that galloping left the
	# Warden's SP exactly where it was; the owner ruled the other way. What it
	# holds now is the *rate*: the drop over a measured stretch of the real
	# tick against what the mount authored, so a hero draining at the runner's
	# rate, or twice, or not at all, is named rather than passed.
	who.stamina = Balance.HERO_STAMINA_MAX
	who.set("_winded", false)
	var sp_before: float = who.stamina
	# **Asked for through the real input, not set by hand.** `_tick_gallop`
	# decides whether the horse is running from the sprint key and the hero's
	# own velocity, so setting `_galloping` and calling it simply had the
	# function set it straight back to false - which is the gate reporting a
	# working feature as broken, and is why it drives the door rather than the
	# flag.
	#
	# **`_tick_mount` rather than `_tick_gallop`**, which is the same lesson one
	# layer out: the climb into the saddle is counted down by the outer tick, so
	# calling the inner one left `_mount_up_left` at its full 0.45 for ever and
	# the horse was still being got onto three seconds later.
	var reins := PressedInput.new(who)
	reins.hold = HeroInput.HOLD_SPRINT
	reins.muted = Hero.MOUNTED_MUTE
	var hands: HeroInput = who.input
	who.input = reins
	who.velocity = Vector2(200.0, 0.0)
	for _tick: int in 30:
		who.call("_tick_mount", 0.1)
	_check(who.is_galloping(),
		"the sprint key was down and moving and the horse never galloped")
	# Thirty ticks of a tenth; the first few are the climb into the saddle
	# (`MOUNT_UP_SECONDS`), which spends nothing. So the stretch actually run
	# is three seconds less the climb, and the drop is that stretch at the
	# mount's own rate - measured to within a tick either side.
	var steed: MountData = who.mounted_kind()
	var ran: float = 3.0 - Balance.MOUNT_UP_SECONDS
	var expected: float = steed.sprint_drain * ran
	var dropped: float = sp_before - who.stamina
	_check(dropped > 0.0,
		"three seconds of galloping spent no SP at all (%.1f -> %.1f)"
			% [sp_before, who.stamina])
	_check(absf(dropped - expected) <= steed.sprint_drain * 0.15,
		("galloping on %s spent %.1f SP over %.2f s against an authored %.1f a "
			+ "second (expected about %.1f) - the rate the stable sells is not "
			+ "the rate the hero pays") % [steed.id, dropped, ran, steed.sprint_drain, expected])

	# **A walk in the saddle spends nothing.** The key up, still moving: SP
	# rests and comes back, exactly as it does on foot.
	var spent: float = who.stamina
	reins.hold = 0
	for _walk: int in 20:
		who.call("_tick_mount", 0.1)
	_check(not who.is_galloping(), "the key came up and the horse kept galloping")
	_check(who.stamina >= spent,
		"a mount walking with the key up drained SP (%.1f -> %.1f)"
			% [spent, who.stamina])
	who.velocity = Vector2.ZERO
	for _rest: int in 40:
		who.call("_tick_mount", 0.1)
	_check(who.stamina > spent,
		"a rider standing still got none of their SP back (%.1f -> %.1f)"
			% [spent, who.stamina])

	# **Spend it all and you arrive winded**, and winded refuses the gallop
	# until the floor - the runner's rule, on the same pool, so a rider cannot
	# gallop what their legs could not run.
	who.stamina = 0.5
	who.velocity = Vector2(200.0, 0.0)
	reins.hold = HeroInput.HOLD_SPRINT
	for _last: int in 3:
		who.call("_tick_mount", 0.1)
	_check(bool(who.get("_winded")), "the pool ran out in the saddle and the rider is not winded")
	_check(not who.is_galloping(), "winded, and the horse is still at a gallop")
	who.stamina = Balance.HERO_SPRINT_FLOOR * 0.5
	for _refused: int in 5:
		who.call("_tick_mount", 0.1)
	_check(not who.is_galloping(),
		"a winded rider under the floor was allowed to gallop on the key alone")
	who.stamina = Balance.HERO_SPRINT_FLOOR + 1.0
	reins.hold = 0
	who.call("_tick_mount", 0.1)
	_check(not bool(who.get("_winded")), "SP came back over the floor and the rider stayed winded")
	reins.hold = HeroInput.HOLD_SPRINT
	for _again: int in 3:
		who.call("_tick_mount", 0.1)
	_check(who.is_galloping(), "over the floor with the key down, the horse would not gallop")
	who.stamina = Balance.HERO_STAMINA_MAX
	who.set("_winded", false)
	reins.hold = 0
	who.call("_tick_mount", 0.1)
	who.input = hands

	# --- The dismount, and the swing it lets through --------------------------
	#
	# **Driven through the real tick with a real press**, rather than by calling
	# `dismount()`. What the owner asked for is that the button does two things,
	# and a gate that called the second one by hand would pass on a build where
	# the press was swallowed.
	_check(who.is_mounted(), "the Warden fell off before the dismount test")
	var pressing := PressedInput.new(who)
	pressing.press = HeroInput.BUTTON_ATTACK
	var was: HeroInput = who.input
	who.input = pressing
	pressing.muted = Hero.MOUNTED_MUTE
	who.call("_tick_mount", 0.016)
	_check(not who.is_mounted(),
		"pressing attack did not get the Warden off the horse")
	_check(pressing.muted == 0,
		"the Warden got down and the mute stayed on, so the swing that asked "
			+ "for it cannot land")
	# The press is still there to be read, which is what "start fighting where
	# they dismounted" means: the mute came off, the button was not consumed.
	_check(pressing.pressed(HeroInput.BUTTON_ATTACK),
		"the dismount swallowed the attack press")
	_check(who.can_fight() or not RunState.is_command_combat(),
		"a Warden on their feet in a fight still may not fight")
	who.input = was

	# --- The refusals ---------------------------------------------------------
	who.set("_mount_wait", 0.0)
	MetaState.mount_saddled = ""
	_check(not who.mount(), "the Warden mounted with nothing saddled")
	MetaState.mount_saddled = kind.id

	who.set("_mount_wait", 0.0)
	who.set("_swimming", true)
	_check(not who.mount(), "the Warden rode into deep water")
	who.set("_swimming", false)

	# And a ride that ends because the ground changed under it.
	who.set("_mount_wait", 0.0)
	_check(who.mount(), "the Warden refused to mount on dry ground")
	who.set("_swimming", true)
	who.call("_tick_mount", 0.016)
	_check(not who.is_mounted(),
		"the water came up over the knee and the Warden stayed in the saddle")
	who.set("_swimming", false)

	# --- What throws a rider, and what does not (owner, 2026-09-21) ---------
	#
	# **Yuri's footfall does not.** `_may_stay_mounted` used to refuse the
	# saddle while `_beast_stun_left` ran, and every step of the beast sets
	# that, so a rider was thrown four times a minute by the ground under them
	# - the same fault the fishing line paid for, where the shove never settled
	# under a stillness threshold. Driven through the real signal and the real
	# tick, the way `structure_check` sends a stray step on purpose.
	who.set("_mount_wait", 0.0)
	who.set("_mount_thrown_left", 0.0)
	_check(who.mount(), "the Warden refused to mount before the footfall test")
	EventBus.beast_step_landed.emit(Vector2(14.0, 5.0), 1.0)
	_check(float(who.get("_beast_stun_left")) > 0.0,
		"the footfall did not stun the Warden, so this test measures nothing")
	for _tick: int in 6:
		who.call("_tick_mount", 0.016)
	_check(who.is_mounted(), "Yuri's footfall threw the Warden from the saddle")

	# **A blow does**, through the real health component, and the saddle then
	# closes for `MOUNT_HURT_COOLDOWN` - refusing out loud, and opening again
	# on its own.
	var hp_before_blow: float = who.health.current_hp
	_check(who.health.take_damage(5.0, who.global_position + Vector2(40.0, 0.0)),
		"the probe's blow did not land, so the throw cannot be measured")
	_check(who.health.current_hp < hp_before_blow, "the blow took no health")
	_check(not who.is_mounted(), "a blow that landed left the Warden in the saddle")
	_check(who.mount_cooldown_left() > 0.0
		and is_equal_approx(who.mount_cooldown_left(), Balance.MOUNT_HURT_COOLDOWN),
		"the throw did not start the cooldown (%.2f)" % who.mount_cooldown_left())
	_check(who.mount_cooldown_ratio() > 0.99,
		"a rider just thrown reads a ratio of %.2f rather than one" % who.mount_cooldown_ratio())
	who.set("_mount_wait", 0.0)
	_check(not who.mount(), "the Warden mounted while thrown")
	# And a blow to somebody on foot costs nothing: the cooldown is a price for
	# being caught riding, not a tax on being hit.
	who.set("_mount_thrown_left", 0.0)
	who.health.take_damage(5.0, who.global_position + Vector2(40.0, 0.0))
	_check(who.mount_cooldown_left() == 0.0,
		"a blow to a Warden on foot started the mount cooldown")
	# The clock runs down through the real tick and the saddle opens.
	who.set("_mount_thrown_left", Balance.MOUNT_HURT_COOLDOWN)
	var ticks: int = int(ceil(Balance.MOUNT_HURT_COOLDOWN / 0.1)) + 2
	for _tick: int in ticks:
		who.call("_tick_mount", 0.1)
	_check(who.mount_cooldown_left() == 0.0 and who.mount_cooldown_ratio() == 0.0,
		"the cooldown never ran out (%.2f left)" % who.mount_cooldown_left())
	who.set("_mount_wait", 0.0)
	_check(who.mount(), "the saddle stayed closed after the cooldown ran out")
	who.dismount()

	# **The mirror throws on the same fact.** A guest's Warden never runs
	# `_on_damaged` - health arrives as a fraction and is assigned - so the
	# throw has to be read off the drop, in `CoopHeroes._apply_health`. Driven
	# on a bare instance of the applier, which reads nothing but the hero.
	who.set("_mount_wait", 0.0)
	who.set("_mount_thrown_left", 0.0)
	who.health.revive()
	_check(who.mount(), "the Warden refused to mount before the mirror test")
	var mirror := CoopHeroes.new()
	mirror.call("_apply_health", who, 1.0)
	_check(who.is_mounted(), "a health report that took nothing threw the rider")
	mirror.call("_apply_health", who, 0.6)
	_check(not who.is_mounted(), "a mirrored drop in health left the Warden in the saddle")
	_check(who.mount_cooldown_left() > 0.0, "the mirrored throw started no cooldown")
	mirror.free()
	who.set("_mount_thrown_left", 0.0)
	who.set("_mount_wait", 0.0)

	# **The ring shows for the throw and only for the throw.** Read off the
	# real HUD in the run's tree, driven through the same refresh the frame
	# calls, and then asked again after the clock runs out - a ring that could
	# be turned on but never off would pass a check that only looked once.
	var hud: HUD = _find_hud(run)
	_check(hud != null, "the run stood up no HUD to draw the ring on")
	if hud != null:
		var ring := hud.get("_ride_cooldown") as Control
		_check(ring != null, "the HUD carries no ride cooldown ring")
		if ring != null:
			hud.call("_update_ride_button")
			_check(not ring.visible, "the ring shows with no cooldown running")
			_check(who.mount(), "the Warden refused to mount before the ring test")
			who.health.take_damage(5.0, who.global_position + Vector2(40.0, 0.0))
			hud.call("_update_ride_button")
			_check(ring.visible, "a thrown rider's ring is not showing")
			_check(hud.get("_ride_button").disabled,
				"the ride button is pressable while the rider is thrown")
			for _tick: int in ticks:
				who.call("_tick_mount", 0.1)
			hud.call("_update_ride_button")
			_check(not ring.visible, "the ring is still showing after the cooldown ran out")
			_check(not hud.get("_ride_button").disabled,
				"the ride button stayed disabled after the cooldown ran out")
	who.set("_mount_thrown_left", 0.0)
	who.set("_mount_wait", 0.0)
	who.health.revive()

	# --- The climb into the saddle ------------------------------------------
	#
	# `MOUNT_UP_SECONDS` was a clock with nothing on the end of it until the
	# rider was given a climb to spend it on. A climb stuck at zero leaves the
	# Warden standing at the horse's feet for the whole ride - plain in play and
	# invisible to every number in this file, which is what a check is for.
	var rig := who.get_node_or_null("MountRig") as MountRig
	_check(rig != null, "the hero must carry a mount rig")
	if rig != null:
		who.set("_mount_wait", 0.0)
		if not who.is_mounted():
			who.mount()
		_check(rig.climbed() < 1.0,
			"the Warden was in the saddle on the frame they pressed the key")
		for _frame: int in 90:
			await get_tree().process_frame
		_check(rig.climbed() >= 1.0,
			"a second and a half after mounting the climb is %.2f of the way up"
				% rig.climbed())
		# Back on their feet, so the test after this one starts where it expects
		# to. A harness that leaves state behind is the fault that made the act
		# doctrines measure the widest board as the narrowest.
		who.dismount()
		who.set("_mount_wait", 0.0)

	# --- A hero who falls comes off ------------------------------------------
	#
	# **The one ending `_tick_mount` cannot reach.** `_physics_process` returns
	# on its first line for a hero who is not standing, so the tick that ends
	# every other ride stops running the frame they fall. Left alone, the corpse
	# is drawn on a horse and its input stays muted - so the revive brings back a
	# Warden who cannot swing. Found by asking what else stops the tick rather
	# than by anything failing: the gate was green with the hole in it.
	who.set("_mount_wait", 0.0)
	who.set("_swimming", false)
	_check(who.mount(), "the Warden refused to mount before the death test")
	who.go_down(who.global_position)
	_check(not who.is_mounted(),
		"a Warden who went down is still drawn sitting on a horse")
	_check(who.input == null or who.input.muted == 0,
		"a Warden who went down kept a muted input, so a revive brings back "
			+ "somebody who cannot swing")

	await _leave(run)


# --- The paddock -------------------------------------------------------------


## **Five horses, five clocks.** A paddock where everything is doing the same
## thing is one animation drawn five times, which is the whole reason to draw a
## paddock rather than list one - the argument `PenYard` was built under.
func _test_the_paddock() -> void:
	var paddock := StablePaddock.new()
	add_child(paddock)
	await get_tree().process_frame
	_check(paddock.standing() == Balance.STABLE_HORSES,
		"the paddock stood %d horses against %d"
			% [paddock.standing(), Balance.STABLE_HORSES])
	# Driven rather than waited out, which is the seam `PenYard` and
	# `MusicPlayer` both expose: waiting forty seconds to prove five animals
	# differ is a test of the clock.
	var seen: Dictionary = {}
	for _pass: int in 40:
		paddock.drive(1.0)
		var shape: String = ""
		for index: int in paddock.standing():
			shape += str(paddock.pose_at(index))
		seen[shape] = true
	_check(seen.size() > 1,
		"forty seconds of paddock produced %d arrangement(s) - every horse is "
			% seen.size() + "on one clock")
	var together: bool = true
	for shape: String in seen:
		if shape.length() > 1 and shape.count(shape[0]) != shape.length():
			together = false
			break
	_check(not together,
		"every horse in the paddock was always doing the same thing")
	paddock.queue_free()


# --- Plumbing ----------------------------------------------------------------


## An input that reports one press, so the dismount can be driven the way a
## player drives it. Extends the base rather than the local source, because the
## local one reads the keyboard and there is nobody at it.
class PressedInput extends HeroInput:
	var press: int = 0
	var hold: int = 0

	func _read_press(button: int) -> bool:
		return press & button != 0

	func _read_hold(mask: int) -> bool:
		return hold & mask != 0

	func is_local() -> bool:
		return true


func _find_hud(root: Node) -> HUD:
	if root is HUD:
		return root as HUD
	for child: Node in root.get_children():
		var found: HUD = _find_hud(child)
		if found != null:
			return found
	return null


func _leave(run: Run) -> void:
	run.queue_free()
	for _frame: int in 4:
		await get_tree().process_frame


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[mount] " + why)
