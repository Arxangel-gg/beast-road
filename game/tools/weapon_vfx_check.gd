extends Node

## The weapon has to be visible in the swing and in the shot.
##
## This gate exists because the obvious harness lies. `regression_check` already
## emits `hero_swing_resolved`, and it passed the day the blade was written —
## but `Vfx.world` is null there, so `blade_sweep` returned on its first line and
## the gate was agreeing with a game where no blade is ever drawn. Anything
## testing a cosmetic has to bind a world first, and then look for the node.
##
## Three things are checked and each has failed at least once in this codebase:
##   - the blade appears at all, and only when something is equipped
##   - it is turned to lead along the swing rather than sitting at the angle its
##     art was painted at (four of six sprites once faced the wrong way)
##   - both effects clean themselves up, because a tween that frees its own node
##     is the usual source of a leak report

var _failures: int = 0
var _stage: Node2D = null
var _layer: Node2D = null


func _ready() -> void:
	# **Held for the whole run.** This gate edits MetaState in place - a wiped
	# stash, a drained Tools purse, a reset flag - and any save reached while
	# that scratch state is live overwrites a real player's file. One did, on
	# 2026-08-31, and a stash is the one thing here that cannot be restored.
	MetaState.hold_saves()
	await get_tree().process_frame
	_stage = Node2D.new()
	add_child(_stage)
	Vfx.bind_world(_stage)
	_layer = _stage.get_node_or_null("VfxLayer") as Node2D
	_check(_layer != null, "Vfx must create a scoped effect layer")

	var old_stash: Array = MetaState.stash.duplicate(true)
	var old_equipped: Dictionary = MetaState.equipped.duplicate(true)
	var old_ranged: String = RunState.ranged_id

	_test_unarmed_draws_nothing()
	_test_weapon_variety()
	_test_weapon_art_faces_the_same_way()
	_test_starting_weapon()
	await _test_blade_sweep()
	_test_blade_tint()
	await _test_bow_loose()

	MetaState.stash = old_stash
	MetaState.equipped = old_equipped
	RunState.ranged_id = old_ranged
	Vfx.clear()
	Vfx.bind_world(null)
	Sfx.stop_immediately()
	_stage.queue_free()
	# Effects own live tweens; two frames lets the deferred frees land so the
	# gate measures cleanup rather than its own teardown.
	await get_tree().process_frame
	await get_tree().process_frame
	if _failures == 0:
		print("[weapon-vfx] PASS - the blade leads the swing, the bow kicks on release, both clean up")
	else:
		push_error("[weapon-vfx] FAIL - %d problem(s)" % _failures)
	get_tree().quit(0 if _failures == 0 else 1)


## A new account starts holding the tier-0 weapon, and only once.
##
## Two failures to keep apart. Granting nothing puts a new player through their
## first act empty-handed, which is the bug this was added to fix. Granting it
## every launch is worse: a weapon has a sale price, so a re-seed on load would
## be a Marks printer, and that kind of exploit is invisible until somebody has
## already farmed it.
func _test_starting_weapon() -> void:
	var kind: GearData = ContentDB.gear(MetaState.STARTING_WEAPON)
	_check(kind != null, "the starting weapon %s must exist" % MetaState.STARTING_WEAPON)
	if kind == null:
		return
	_check(kind.slot == GearData.Slot.WEAPON, "the starting weapon must be a weapon")
	_check(kind.min_tier == 0, "the starting weapon must be reachable at the first tier")

	# A fresh account, simulated the way `_ready` builds one.
	MetaState.stash = []
	MetaState.equipped = {}
	MetaState.settings[MetaState.STARTING_GEAR_KEY] = false
	MetaState._seed_starting_gear()
	_check(MetaState.stash.size() == 1, "a new account must be given exactly one piece")
	var worn: Dictionary = MetaState.equipped_piece(GearData.Slot.WEAPON)
	_check(not worn.is_empty(), "the starting weapon must be worn, not merely owned")
	_check(String(worn.get("kind", "")) == MetaState.STARTING_WEAPON,
		"the worn piece must be the starting weapon")

	# Every launch after the first must change nothing.
	MetaState._seed_starting_gear()
	MetaState._seed_starting_gear()
	_check(MetaState.stash.size() == 1,
		"the starting weapon must be granted once, not once per launch (stash held %d)"
			% MetaState.stash.size())


## Weapon character is bought with cadence, never given away.
##
## Working rule 7 keeps hero power on one capped scale: gear grants attribute
## points, not raw stats. A weapon that simply reached further would be raw
## power under another name, and the cap would stop meaning anything. So reach
## and swing speed must multiply to 1 - a maul reaches and is slow, a short
## blade is quick and must be close, and over a second neither out-damages the
## other. This is the assertion that keeps it that way; without it the pair
## would drift into a stat line one tuning pass at a time.
func _test_weapon_variety() -> void:
	var weapons: int = 0
	var reaches: Dictionary = {}
	for kind: GearData in ContentDB.gear_kinds.values():
		if kind.slot != GearData.Slot.WEAPON:
			continue
		weapons += 1
		reaches[kind.reach_scale] = true
		var product: float = kind.reach_scale * kind.swing_scale
		_check(absf(product - 1.0) < 0.01,
			"%s reaches %.2f and swings %.2f, which is %.3f of a baseline weapon - reach must be paid for"
				% [kind.id, kind.reach_scale, kind.swing_scale, product])
	_check(weapons >= 2, "there must be more than one weapon for variety to mean anything")
	_check(reaches.size() >= 2,
		"every weapon reaches the same distance, so the slot is a stat and not a choice")


## An empty weapon slot still swings. It must not swing a phantom.
func _test_unarmed_draws_nothing() -> void:
	MetaState.stash = []
	MetaState.equipped = {}
	Vfx.clear()
	Vfx.blade_sweep(Vector2.ZERO, Vector2.RIGHT, 200.0, 90.0, null, Color.WHITE)
	_check(_sprites().is_empty(), "an empty weapon slot must draw no blade")


func _test_blade_sweep() -> void:
	var kind: GearData = _any_weapon()
	_check(kind != null, "the gate needs at least one weapon kind to test with")
	if kind == null:
		return
	MetaState.stash = [Stash.make(kind.id, 0)]
	MetaState.equipped = {GearData.Slot.WEAPON: 0}
	Vfx.clear()
	await get_tree().process_frame

	var aim := Vector2.RIGHT
	var reach: float = Balance.HERO_ATTACK_RANGE[0]
	EventBus.hero_swing_resolved.emit(Vector2.ZERO, aim, reach, 0)
	await get_tree().process_frame

	var blades: Array[Sprite2D] = _sprites()
	_check(not blades.is_empty(), "an equipped weapon must appear in the swing")
	if blades.is_empty():
		return

	# The blade rides inside the reach and leads along it. Both are checked in
	# world space, because the pivot's rotation is what carries the sprite and a
	# local-space assertion would pass with the pivot facing anywhere.
	var blade: Sprite2D = blades[0]
	var offset: float = blade.global_position.length()
	_check(offset > reach * 0.3 and offset < reach,
		"the blade must ride inside the reach, not at the hero or past the tip (was %.0f of %.0f)"
			% [offset, reach])

	# Art painted on the up-right diagonal, turned to lead. The comparison is
	# against the *radius the blade is standing on*, not against the aim: the
	# blade is partway through an arc when this runs, so the aim is up to half
	# an arc away from where the point should be looking, and a tolerance loose
	# enough to allow that is loose enough to accept any rotation at all. The
	# first version of this check compared against the aim, and scored the bug
	# it was written to catch *better* than the fix.
	var radial: Vector2 = blade.global_position.normalized()
	var points: Vector2 = Vector2.RIGHT.rotated(blade.global_rotation
		+ deg_to_rad(Balance.VFX_BLADE_ART_DEGREES))
	var off_by: float = absf(points.angle_to(radial))
	_check(off_by < deg_to_rad(12.0),
		"the blade must point along the radius it rides, not sit at its art angle (off by %.0f deg)"
			% rad_to_deg(off_by))

	# The ribbon, not a rope. A `Line2D` along one radius draws the path of a
	# single point on the blade and reads as something swung on a chain; a
	# sword's trail is the area the edge swept, from the hilt out to the point.
	# Owner report, 2026-09-01.
	var ribbons: Array[Polygon2D] = []
	for child: Node in _layer.get_children():
		if child is Polygon2D and child.name == &"BladeRibbon":
			ribbons.append(child as Polygon2D)
	_check(not ribbons.is_empty(), "the swing must leave a swept ribbon behind the edge")
	_check(_line_trails() == 0,
		"the old single-radius line trail must be gone, found %d" % _line_trails())
	for ribbon: Polygon2D in ribbons:
		_measure_ribbon(ribbon, reach)

	await _settle()
	_check(_sprites().is_empty(), "the blade must free itself when the swing ends")


func _test_bow_loose() -> void:
	var weapon: RangedWeaponData = null
	for candidate: RangedWeaponData in ContentDB.ranged_weapons.values():
		weapon = candidate
		break
	_check(weapon != null, "the gate needs a ranged weapon to test with")
	if weapon == null:
		return
	RunState.ranged_id = weapon.id
	Vfx.clear()
	await get_tree().process_frame

	var heading := Vector2.UP
	EventBus.hero_loosed.emit(Vector2.ZERO, heading, "")
	await get_tree().process_frame
	var bows: Array[Sprite2D] = _sprites()
	_check(not bows.is_empty(), "loosing a shot must show the weapon that loosed it")
	if bows.is_empty():
		return

	# Same rule as the blade, from the weapon's own painted angle rather than a
	# shared constant: the two weapons disagree, which is why it is data.
	var bow: Sprite2D = bows[0]
	var points: Vector2 = Vector2.RIGHT.rotated(bow.global_rotation \
		+ deg_to_rad(weapon.art_degrees))
	_check(absf(points.angle_to(heading)) < deg_to_rad(12.0),
		"the bow must face the shot it just took")

	await _settle()
	_check(_sprites().is_empty(), "the bow must free itself after the release")


## Sprites currently alive in the effect layer, at any depth.
func _sprites() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if _layer == null:
		return out
	var stack: Array[Node] = [_layer]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child: Node in node.get_children():
			if child is Sprite2D:
				out.append(child as Sprite2D)
			stack.append(child)
	return out


## Long enough for the slowest of the two effects to finish and free.
func _settle() -> void:
	await get_tree().create_timer(maxf(
		Balance.VFX_SLASH_LIFE * Balance.VFX_BLADE_LIFE_SCALE * 3.0,
		Balance.VFX_BOW_LIFE * 3.0) + 0.2).timeout
	await get_tree().process_frame


func _any_weapon() -> GearData:
	for kind: GearData in ContentDB.gear_kinds.values():
		if kind.slot == GearData.Slot.WEAPON and ResourceLoader.exists(kind.get_sprite_path()):
			return kind
	return null


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	print("[weapon-vfx] %s" % message)


## How many single-radius line trails the effect layer holds. Zero is the answer:
## `slash` draws a wedge and `blade_sweep` draws a ribbon, and a `Line2D` here
## would mean the old rope-shaped trail had come back.
func _line_trails() -> int:
	var found: int = 0
	for child: Node in _layer.get_children():
		if child is Line2D:
			found += 1
	return found


## The ribbon must actually span the blade, hilt to point.
##
## Checked as a measurement rather than as "a polygon exists", because the shape
## is the whole complaint: a strip with no width between its two radii is a line
## with extra vertices, and would look exactly like the trail being replaced.
func _measure_ribbon(ribbon: Polygon2D, reach: float) -> void:
	var shape: PackedVector2Array = ribbon.polygon
	_check(shape.size() >= 8,
		"the ribbon needs both edges, got %d points" % shape.size())
	if shape.size() < 8:
		return
	var nearest: float = INF
	var furthest: float = 0.0
	for point: Vector2 in shape:
		nearest = minf(nearest, point.length())
		furthest = maxf(furthest, point.length())
	var hilt: float = reach * Balance.VFX_BLADE_TRAIL_HILT
	var tip: float = reach * Balance.VFX_BLADE_TRAIL_TIP
	_check(absf(nearest - hilt) < reach * 0.08,
		"the inner edge must sit at the hilt radius %.0f, sits at %.0f" % [hilt, nearest])
	_check(absf(furthest - tip) < reach * 0.08,
		"the outer edge must reach the point at %.0f, reaches %.0f" % [tip, furthest])
	_check(furthest - nearest > reach * 0.3,
		"the ribbon must have real width between hilt and point, has %.0f"
			% (furthest - nearest))
	# Faded toward the tail, which is what makes the shape read as speed rather
	# than as a painted crescent.
	var shades: PackedColorArray = ribbon.vertex_colors
	_check(shades.size() == shape.size(),
		"every ribbon vertex needs its own shade, %d colours for %d points"
			% [shades.size(), shape.size()])
	if shades.size() == shape.size() and shades.size() > 2:
		_check(shades[0].a < shades[shades.size() / 2 - 1].a,
			"the tail of the ribbon must be fainter than its leading edge")


## The trail must be the colour of the weapon, not the colour of its rarity.
##
## Reported as "matching its color" (owner, 2026-09-01). The tint used to come
## from the rarity band, so a Fine maul and a Fine sabre cut identical green -
## the one piece of feedback that could have said what is in the hero's hand
## instead repeated a fact the player learned when they picked it up.
func _test_blade_tint() -> void:
	var kinds: Array[GearData] = []
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind != null and kind.slot == GearData.Slot.WEAPON \
				and ResourceLoader.exists(kind.get_sprite_path()):
			kinds.append(kind)
	_check(kinds.size() >= 2,
		"the gate needs two weapons with art to tell their colours apart")
	if kinds.size() < 2:
		return
	var seen: Dictionary = {}
	for kind: GearData in kinds:
		var texture := load(kind.get_sprite_path()) as Texture2D
		var tint: Color = Vfx.blade_tint(texture, Color.MAGENTA)
		_check(tint != Color.MAGENTA,
			"%s must yield a colour from its art rather than the fallback" % kind.id)
		_check(tint.v >= 0.55,
			"%s must yield a colour bright enough to read as a trail (v %.2f)"
				% [kind.id, tint.v])
		seen[tint.to_html(false)] = true
	# Not every weapon has to differ, but they cannot all be the same colour or
	# the sampling has collapsed to a constant and the rarity bug is back in a
	# new costume.
	_check(seen.size() > 1,
		"%d weapons must not all sample to one colour" % kinds.size())

	# And it must be cached: this reads an image, and a swing happens three
	# times a second.
	var first := load(kinds[0].get_sprite_path()) as Texture2D
	var once: Color = Vfx.blade_tint(first, Color.MAGENTA)
	var twice: Color = Vfx.blade_tint(first, Color.MAGENTA)
	_check(once == twice, "the sampled colour must be stable between swings")


## Every weapon icon is drawn on the same diagonal.
##
## `Vfx.blade_sweep` turns the sprite back by `VFX_BLADE_ART_DEGREES` so its
## point leads along the arc, and that single number is only correct because
## every melee icon in the set is painted hilt-low-left, point-high-right. A
## weapon drawn the other way swings backwards - hilt first - and nothing else
## in the project would notice.
##
## Measured rather than eyeballed. This gate exists because a contact sheet was
## read wrong *in both directions* on 2026-09-01: an axe that was already correct
## looked mirrored, was flipped, and the flip is what broke it. The alpha
## centroid does not have an opinion.
##
## A perfectly symmetric design - crossed dirks, an X - has no diagonal to get
## wrong and reads the same at any rotation, so equality passes.
func _test_weapon_art_faces_the_same_way() -> void:
	var checked: int = 0
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind == null or kind.slot != GearData.Slot.WEAPON:
			continue
		var path: String = kind.get_sprite_path()
		if not ResourceLoader.exists(path):
			continue
		var texture := load(path) as Texture2D
		if texture == null:
			continue
		var image: Image = texture.get_image()
		if image == null:
			continue
		checked += 1
		var top: float = 0.0
		var bottom: float = 0.0
		var top_count: int = 0
		var bottom_count: int = 0
		var half: int = image.get_height() / 2
		for y: int in image.get_height():
			for x: int in image.get_width():
				if image.get_pixel(x, y).a < 0.5:
					continue
				if y < half:
					top += float(x)
					top_count += 1
				else:
					bottom += float(x)
					bottom_count += 1
		if top_count == 0 or bottom_count == 0:
			_check(false, "%s has nothing drawn in half its canvas" % kind.id)
			continue
		var top_x: float = top / float(top_count)
		var bottom_x: float = bottom / float(bottom_count)
		_check(top_x >= bottom_x - 0.5,
			("%s is painted with its point low-left and its hilt high-right, which "
				+ "is the mirror of every other weapon - it will swing hilt-first "
				+ "(top %.1f, bottom %.1f)") % [kind.id, top_x, bottom_x])
	_check(checked >= 4,
		"only %d weapon icons were measured, so the convention is barely held" % checked)
