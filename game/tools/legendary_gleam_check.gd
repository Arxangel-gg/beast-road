extends Node

## **Legendary gear gleams** (owner, 2026-10-07). Holds the ladder - nothing
## below the first rarity that wears a legendary affix, rising to the top, the
## top rung's sheen prismatic - then stands the real stash up and reads which
## icons wear a gleam, builds a stash row, the Market's ware row and the
## comparison card, dresses a Warden's hand with a legendary weapon and an
## ordinary one, and sheds motes off a legendary tip at the particle scale and
## none at a scale of nothing. Headless never compiles a shader, so the
## picture is `stash_shot`'s; this holds the wiring.

var _failures: int = 0
var _checks: int = 0
var _stash_before: Array = []
var _equipped_before: Dictionary = {}


func _ready() -> void:
	MetaState.hold_saves()
	_stash_before = MetaState.stash.duplicate(true)
	_equipped_before = MetaState.equipped.duplicate()
	_test_the_ladder()
	await _test_the_stash()
	_test_the_rows()
	_test_the_hand()
	_test_the_wiring()
	MetaState.stash = _stash_before
	MetaState.equipped = _equipped_before
	_finish()


func _test_the_ladder() -> void:
	var first: int = -1
	for rarity: int in Balance.GEAR_LEGENDARY_COUNT.size():
		if Balance.GEAR_LEGENDARY_COUNT[rarity] > 0:
			first = rarity
			break
	_check(first == Balance.GEAR_GLEAM_FROM_RARITY,
		"the gleam starts at rarity %d and the legendary affixes at %d" % [Balance.GEAR_GLEAM_FROM_RARITY, first])
	var top: int = Stash.RARITY_NAMES.size() - 1
	var last: float = -1.0
	for rarity: int in Stash.RARITY_NAMES.size():
		var strength: float = LegendaryGleam.tier(rarity)
		if rarity < Balance.GEAR_GLEAM_FROM_RARITY:
			_check(strength == 0.0, "%s gleams" % Stash.RARITY_NAMES[rarity])
			_check(LegendaryGleam.material_for(rarity, "x") == null, "%s wears a gleam" % Stash.RARITY_NAMES[rarity])
		else:
			_check(strength > last, "%s gleams no harder than the rung below" % Stash.RARITY_NAMES[rarity])
			last = strength
	_check(is_equal_approx(LegendaryGleam.tier(top), 1.0), "the top rung does not gleam fully")
	var crown: ShaderMaterial = LegendaryGleam.material_for(top, "crown")
	_check(crown != null and float(crown.get_shader_parameter("prismatic")) > 0.99,
		"the top rung's sheen is not prismatic")
	var runed: ShaderMaterial = LegendaryGleam.material_for(Balance.GEAR_GLEAM_FROM_RARITY, "a")
	_check(runed != null and float(runed.get_shader_parameter("prismatic")) == 0.0,
		"the first legendary rung is prismatic")
	var other: ShaderMaterial = LegendaryGleam.material_for(Balance.GEAR_GLEAM_FROM_RARITY, "b")
	_check(runed != null and other != null
			and float(runed.get_shader_parameter("seed")) != float(other.get_shader_parameter("seed")),
		"two pieces gleam in step")


func _test_the_stash() -> void:
	MetaState.stash = []
	MetaState.equipped = {}
	var weapon: GearData = _kind_in(GearData.Slot.WEAPON)
	var helmet: GearData = _kind_in(GearData.Slot.HELMET)
	if weapon == null or helmet == null:
		_check(false, "no weapon or helmet to stock")
		return
	MetaState.receive_gear(Stash.make(weapon.id, Stash.RARITY_NAMES.size() - 2, 1))
	MetaState.equip(weapon.slot, MetaState.stash.size() - 1)
	MetaState.receive_gear(Stash.make(helmet.id, 1, 1))
	var screen := StashScreen.new()
	add_child(screen)
	await get_tree().process_frame
	screen.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var gleaming: int = 0
	var wrong: int = 0
	for node: Node in _all(screen):
		var icon := node as TextureRect
		if icon == null:
			continue
		var rarity: int = LegendaryGleam.rarity_of(icon)
		if rarity < 0:
			continue
		gleaming += 1
		if rarity < Balance.GEAR_GLEAM_FROM_RARITY:
			wrong += 1
	print("[gleam] %d icons gleam on the stash" % gleaming)
	_check(gleaming >= 2, "a worn legendary weapon gleams on %d icons, wanted its row and its tile" % gleaming)
	_check(wrong == 0, "%d icons gleam for pieces below the legendary rungs" % wrong)
	screen.hide_screen()
	screen.queue_free()
	await get_tree().process_frame


func _test_the_rows() -> void:
	var weapon: GearData = _kind_in(GearData.Slot.WEAPON)
	if weapon == null:
		return
	var legendary: Dictionary = Stash.make(weapon.id, Balance.GEAR_GLEAM_FROM_RARITY, 1)
	var plain: Dictionary = Stash.make(weapon.id, 0, 1)
	_check(_gleams(GearRow.build(legendary)) == 1, "a legendary stash row's icon does not gleam")
	_check(_gleams(GearRow.build(plain)) == 0, "a Rough stash row's icon gleams")
	var vendor := VendorScreen.new()
	add_child(vendor)
	var ware: Control = vendor.call("_ware_row", legendary, 0) as Control
	_check(_gleams(ware) == 1, "a legendary ware on the Market's shelf does not gleam")
	var ordinary: Control = vendor.call("_ware_row", plain, 0) as Control
	_check(_gleams(ordinary) == 0, "a Rough ware gleams")
	vendor.queue_free()
	var compare := GearCompare.new()
	add_child(compare)
	compare.show_pair(legendary)
	_check(_gleams_in(compare) >= 1, "a legendary piece on the comparison card does not gleam")
	compare.queue_free()


func _test_the_hand() -> void:
	var weapon: GearData = _kind_in(GearData.Slot.WEAPON)
	if weapon == null:
		return
	var body := Sprite2D.new()
	add_child(body)
	var dress: DressLayers = DressLayers.attach(body)
	var outfit: Dictionary = WardenDress.outfit(WardenLook.plain(), weapon, null, null, null)
	if String(outfit.get("held", "")).is_empty():
		_check(false, "%s has no held picture to gleam" % weapon.id)
		return
	outfit["held_rarity"] = Stash.RARITY_NAMES.size() - 1
	dress.wear(outfit)
	_check(dress.held_gleam() != null, "a legendary weapon in the hand wears no gleam")
	var strips: Array[Sprite2D] = []
	for node: Node in _all(dress) + _all(dress.behind):
		var strip := node as Sprite2D
		if strip != null and String(strip.name).begins_with("Weapon"):
			strips.append(strip)
	_check(not strips.is_empty(), "the hand has no strips")
	var all_one: bool = true
	for strip: Sprite2D in strips:
		all_one = all_one and strip.material == dress.held_gleam()
	_check(all_one, "the strips of one weapon wear different gleams - the sheen would break at the fist")
	# Motes off the tip, at the scale and at none.
	if not strips.is_empty():
		strips[0].visible = true
		_check(dress.tip_in_world() != Vector2.INF, "a drawn weapon has no tip")
		var shed: int = 0
		for _i: int in 60:
			shed += dress.shed(1.0 / 30.0)
		_check(shed >= 1, "a legendary tip shed no mote in two seconds")
		var held: Dictionary = Graphics.to_dictionary()
		Graphics.set_switch(Graphics.KEY_PARTICLES, 0.0)
		var none: int = 0
		for _i: int in 60:
			none += dress.shed(1.0 / 30.0)
		_check(none == 0, "%d motes shed at a particle scale of nothing" % none)
		Graphics.from_dictionary(held)
	# An ordinary weapon wears nothing, and takes the gleam off.
	outfit["held_rarity"] = 0
	dress.wear(outfit)
	_check(dress.held_gleam() == null, "a Rough weapon in the hand gleams")
	var left: int = 0
	for strip: Sprite2D in strips:
		if strip.material != null:
			left += 1
	_check(left == 0, "%d strips kept a legendary gleam after an ordinary weapon was worn" % left)
	body.queue_free()


func _test_the_wiring() -> void:
	for path: String in ["res://scenes/hero/hero.gd", "res://scripts/components/warden_stage.gd"]:
		_check(FileAccess.get_file_as_string(path).contains("outfit[\"held_rarity\"]"),
			"%s dresses a Warden without saying how rare the weapon is" % path.get_file())
	var shader: String = FileAccess.get_file_as_string(LegendaryGleam.SHADER)
	for name: String in ["rarity_colour", "tier", "prismatic", "seed", "sweep_seconds"]:
		var declared := RegEx.create_from_string("uniform [a-z0-9]+ " + name + "[ :;=]")
		_check(declared.search(shader) != null, "the gleam shader has no uniform %s" % name)


func _gleams(root: Node) -> int:
	var count: int = 0
	for node: Node in _all(root):
		if node is CanvasItem and LegendaryGleam.rarity_of(node as CanvasItem) >= 0:
			count += 1
	if root.get_parent() == null and root is Node:
		root.queue_free()
	return count


## Counts without freeing: for a node the harness keeps.
func _gleams_in(root: Node) -> int:
	var count: int = 0
	for node: Node in _all(root):
		if node is CanvasItem and LegendaryGleam.rarity_of(node as CanvasItem) >= 0:
			count += 1
	return count


func _kind_in(slot: int) -> GearData:
	for value: Variant in ContentDB.gear_kinds.values():
		var kind := value as GearData
		if kind != null and kind.slot == slot and not kind.trophy:
			return kind
	return null


func _all(from: Node) -> Array[Node]:
	var out: Array[Node] = [from]
	for child: Node in from.get_children(true):
		out.append_array(_all(child))
	return out


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		push_error("legendary_gleam_check: " + message)


func _finish() -> void:
	if _failures == 0:
		print("legendary_gleam_check: PASS (%d checks)" % _checks)
	else:
		print("legendary_gleam_check: FAIL (%d of %d)" % [_failures, _checks])
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	for child: Node in get_children():
		child.queue_free()
	for _i: int in 20:
		await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)
