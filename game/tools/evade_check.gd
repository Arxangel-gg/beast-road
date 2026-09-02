extends Node

## Perfect Evade (owner request, 2026-09-02).
##
## A dash that answers a blow is worth more than one thrown a second early, and
## the only difference between them is *when* - so this is measured from the
## moment the i-frames began rather than from the input.
##
## Six promises. The first two are the design bound and the rest are how it
## fails quietly - and every one of them fails *silently*, because a reward that
## stops being granted looks exactly like a player who is not good at it:
##
## 1. **The reward is tempo, never damage.** Working rule 7 keeps hero power on
##    one capped scale. A dodge that hit harder would be a second scale nobody
##    is tuning against.
## 2. **One refund per dash.** A hero standing in a crowd evades several blows
##    inside one window; refunding each of them makes dashing free for standing
##    in the worst place on the field, which is the opposite of a skill ceiling.
## 3. **Late dodges do not count.** A blow arriving near the end of the window
##    is a player who dashed early and got lucky.
## 4. **A dodged blow deals no damage** - the whole feature is built on a signal
##    that fires from inside the branch that refuses damage, so if it ever fired
##    from the wrong place the hero would be taking hits it announced as evaded.
## 5. **An ordinary hit is not an evade.** No i-frames, no signal.
## 6. **The haste expires.** A window to answer in, not a buff to carry.

var _failures: int = 0
var _ran: int = 0


func _ready() -> void:
	# Seeded: `reset()` draws a random one, and anything that measures an
	# outcome is measuring the weather without it.
	RunState.reset(false, 20260902)
	await _test_a_read_dodge_pays()
	await _test_a_late_dodge_does_not()
	await _test_one_refund_per_dash()
	await _test_the_haste_expires()
	_test_the_bound_is_tempo_not_damage()
	_finish()


## 1, 4 and 5. The signal fires where damage is refused, and only there.
func _test_a_read_dodge_pays() -> void:
	var health: Health = _health()
	add_child(health)
	var heard: Array[float] = []
	health.evaded.connect(func(into: float, _from: Vector2) -> void:
		heard.append(into))

	# No i-frames: an ordinary hit, no evade.
	var before: float = health.current_hp
	_check(health.take_damage(10.0, Vector2.ZERO), "an ordinary hit must land")
	_check(health.current_hp < before, "and must actually cost health")
	_check(heard.is_empty(), "a hit that landed is not an evade")

	# I-framed: refused, and announced.
	health.add_invulnerability(Balance.HERO_DASH_IFRAMES)
	var held: float = health.current_hp
	_check(not health.take_damage(10.0, Vector2.ZERO),
		"an i-framed blow must be refused")
	_check(is_equal_approx(health.current_hp, held),
		"and must cost nothing - the evade signal fires from inside the branch "
			+ "that refuses damage, so this failing means it fires elsewhere")
	_check(heard.size() == 1, "and must be announced exactly once")
	_check(heard[0] <= Balance.HERO_PERFECT_EVADE_WINDOW,
		"a blow at the very start of the window reads as %.3fs in" % heard[0])

	health.queue_free()
	await _settle()
	_ran += 1


## 3. Dashing early and standing there is not a read.
func _test_a_late_dodge_does_not() -> void:
	var health: Health = _health()
	add_child(health)
	var heard: Array[float] = []
	health.evaded.connect(func(into: float, _from: Vector2) -> void:
		heard.append(into))
	health.add_invulnerability(Balance.HERO_DASH_IFRAMES)

	# Wind the window most of the way down, the way a second of standing there
	# would, then take the blow.
	health.set("_invulnerable_left",
		Balance.HERO_DASH_IFRAMES - Balance.HERO_PERFECT_EVADE_WINDOW * 2.0)
	health.take_damage(10.0, Vector2.ZERO)
	_check(heard.size() == 1, "the blow must still be announced as evaded")
	_check(heard[0] > Balance.HERO_PERFECT_EVADE_WINDOW,
		"but must read as late - %.3fs in against a window of %.3fs"
			% [heard[0], Balance.HERO_PERFECT_EVADE_WINDOW])

	health.queue_free()
	await _settle()
	_ran += 1


## 2. One refund per dash, however many blows arrive.
func _test_one_refund_per_dash() -> void:
	var hero: Hero = _hero()
	if hero == null:
		return
	hero.call("_try_dash")
	var after_dash: float = hero.get("_dash_cooldown_left")
	_check(after_dash > 0.0, "a dash must go on cooldown")

	hero.call("_on_evaded", 0.0, Vector2.ZERO)
	var once: float = hero.get("_dash_cooldown_left")
	_check(once < after_dash,
		"a read dodge must give some of the dash back: %.2f -> %.2f"
			% [after_dash, once])

	# Three more blows in the same window buy nothing further.
	for _blow: int in 3:
		hero.call("_on_evaded", 0.0, Vector2.ZERO)
	_check(is_equal_approx(float(hero.get("_dash_cooldown_left")), once),
		"a crowd must not refund the same dash again and again: %.2f -> %.2f"
			% [once, float(hero.get("_dash_cooldown_left"))])

	# And the refund never finishes the cooldown outright.
	_check(once > 0.0,
		"one perfect evade must not hand the dash straight back")

	hero.queue_free()
	await _settle()
	_ran += 1


## 6. The window to answer in closes.
func _test_the_haste_expires() -> void:
	var attack := load("res://scenes/hero/hero_attack.gd").new() as Node
	add_child(attack)
	_check(is_equal_approx(float(attack.call("_haste_scale")), 1.0),
		"an ordinary swing runs at its own pace")
	attack.call("grant_haste", Balance.HERO_EVADE_HASTE_SECONDS)
	_check(float(attack.call("_haste_scale")) < 1.0,
		"a read dodge must quicken the next swings")
	attack.set("_evade_haste_left", 0.0)
	_check(is_equal_approx(float(attack.call("_haste_scale")), 1.0),
		"and it must run out - a window to answer in, not a buff to carry")
	attack.queue_free()
	await _settle()
	_ran += 1


## 1, as a rule about the constants rather than about a body.
func _test_the_bound_is_tempo_not_damage() -> void:
	_check(Balance.HERO_EVADE_HASTE_SCALE < 1.0
			and Balance.HERO_EVADE_HASTE_SCALE > 0.5,
		"haste scales phase durations, so it is below one and not by half")
	_check(Balance.HERO_PERFECT_EVADE_WINDOW < Balance.HERO_DASH_IFRAMES * 0.5,
		"the read window must be well inside the i-frames, or every dodge is "
			+ "perfect and the skill is not one")
	_check(Balance.HERO_EVADE_REFUND > 0.0 and Balance.HERO_EVADE_REFUND < 1.0,
		"a refund of the whole cooldown is a dash with no cooldown")
	_check(Balance.HERO_EVADE_HASTE_SECONDS <= 4.0,
		"the answer window must not outlive the moment that opened it")
	_ran += 1


# --- harness -----------------------------------------------------------------

func _health() -> Health:
	var health := Health.new()
	health.max_hp = 100.0
	return health


func _hero() -> Hero:
	var scene: PackedScene = load("res://scenes/hero/hero.tscn")
	var hero := scene.instantiate() as Hero
	if hero == null:
		_check(false, "the hero scene must instantiate")
		return null
	add_child(hero)
	return hero


func _settle() -> void:
	for _frame: int in 4:
		await get_tree().process_frame


func _finish() -> void:
	Sfx.stop_immediately()
	for _frame: int in 30:
		await get_tree().process_frame
	if _failures == 0 and _ran == 5:
		print("[evade] PASS - a read dodge buys tempo and never damage, a late "
			+ "one buys nothing, a crowd refunds one dash once, and the answer "
			+ "window closes")
	elif _failures == 0:
		push_error("[evade] FAIL - only %d of 5 tests ran" % _ran)
		get_tree().quit(1)
		return
	else:
		push_error("[evade] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[evade] FAIL: %s" % why)
