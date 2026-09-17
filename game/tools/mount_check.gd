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
## - **It is not new speed.** A gallop may not exceed what a sprint already
##   reaches. **Measured through `Hero.move_speed()`** rather than read off the
##   resource, because the resource is what a careless edit changes and the
##   function is what the game actually uses. A gate that read `MountData.gallop`
##   back would pass on a build where the hero multiplied it a second time.
## - **It cannot fight.** Mounted, the Warden may not swing, cast, loose, gather,
##   fish or take an egg - and the whole of that refusal lives in one mask, so
##   what this checks is that the mask covers the doors and that `can_fight()`
##   answers no before any phase is read.
## - **It spends the horse's wind and never the Warden's SP.** A mount drinking
##   from SP would make the pool the Warden sprints on a shared resource, which
##   is a coupling nobody asked for.
##
## **The ways this goes wrong:**
##
## - **A gallop that outruns a sprint.** Then a mount is a movement upgrade, and
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
		print(("[mount] PASS - %d checks: a gallop is no faster than a sprint, a "
			+ "rider cannot fight, attacking gets them down and lets the swing "
			+ "through, SP is untouched, and the stable never creates") % _checks)
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
		_check(kind.gallop <= Balance.MOUNT_SPEED_CEILING + 0.001,
			("%s gallops at %.2f against a ceiling of %.2f - a mount faster than "
				+ "a sprint is new speed, which is a scale nobody is tuning")
				% [kind.id, kind.gallop, Balance.MOUNT_SPEED_CEILING])
		_check(kind.gallop >= kind.speed,
			"%s gallops slower than it walks" % kind.id)
		_check(kind.speed > 1.0,
			"%s is no faster than walking, so there is no reason to be on it"
				% kind.id)
		_check(kind.price > 0, "%s is free" % kind.id)
		_check(kind.stamina > 0.0 and kind.stamina_drain > 0.0,
			("%s has no wind to spend, so its gallop is a speed setting rather "
				+ "than a resource") % kind.id)
		_check(kind.stamina_regen > 0.0,
			"%s never gets its wind back, so it gallops once a run" % kind.id)
		_check(not kind.display_name.is_empty(),
			"%s has no name to sell it under" % kind.id)
		_check(ResourceLoader.exists(kind.get_sprite_path()),
			"%s has no painting at %s" % [kind.id, kind.get_sprite_path()])

	# **The ceiling is the sprint, and that is the design rather than a
	# coincidence.** If somebody ever raises one without the other, a mount
	# quietly becomes faster or slower than the thing it is defined against.
	_check(is_equal_approx(Balance.MOUNT_SPEED_CEILING, Balance.HERO_SPRINT_SPEED),
		("the mount ceiling is %.2f and a sprint is %.2f - they are the same "
			+ "number on purpose") % [Balance.MOUNT_SPEED_CEILING,
			Balance.HERO_SPRINT_SPEED])

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
	# `balance_test` requires a controller binding for every rebindable action
	# and the pad is full - every face, shoulder, stick, dpad and misc button
	# already does something. So the mount key follows the minimap's precedent:
	# a key, and a button in the bar that a thumb and a pad can reach. Asserted
	# here so that adding it to the list fails with a reason rather than with
	# "Mount has no controller binding" from a gate three files away.
	_check(InputMap.has_action(&"mount"), "the mount key must be in the input map")
	for row: Dictionary in KeyBindings.REBINDABLE:
		_check(StringName(row.get("action", &"")) != &"mount",
			"the mount key is not rebindable - the pad has no button left to "
				+ "give it, and the action bar's Ride button is how a pad mounts")

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

	_check(galloping <= sprinting + 0.01,
		("a gallop moves at %.1f against a sprint's %.1f - a mount is the speed "
			+ "the Warden already had, not a new one") % [galloping, sprinting])
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

	# --- SP is the Warden's and the wind is the horse's -----------------------
	var sp_before: float = who.stamina
	var wind_before: float = who.mount_wind
	_check(wind_before > 0.0, "a freshly mounted horse has no wind")
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
	_check(who.mount_wind < wind_before,
		"three seconds of galloping spent no wind at all (%.1f -> %.1f)"
			% [wind_before, who.mount_wind])
	_check(is_equal_approx(who.stamina, sp_before),
		("galloping took the Warden's SP from %.1f to %.1f - a mount's wind is "
			+ "its own") % [sp_before, who.stamina])

	# And it comes back.
	var spent: float = who.mount_wind
	who.velocity = Vector2.ZERO
	reins.hold = 0
	for _rest: int in 80:
		who.call("_tick_mount", 0.1)
	who.input = hands
	_check(who.mount_wind > spent,
		"a horse standing still got none of its wind back (%.1f -> %.1f)"
			% [spent, who.mount_wind])

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
