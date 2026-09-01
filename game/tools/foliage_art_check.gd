extends Node

## Everything that should move, moves - and everything that should not, does not.
##
##   godot --headless --path game res://tools/foliage_art_check.tscn
##
## Owner direction, 2026-09-01: "not all foliage has idle animations + wind
## shader combo active but should unless they're a static foliage asset like a
## rock or something that does not get animated. Flowers should be animated both
## ways, same for trees but each asset's wind shader should be tuned for what it
## is."
##
## Three rules come out of that sentence and all three are checkable:
##
## 1. **A kind that sways has frames.** `Balance.FOLIAGE_KIND_SWAY` already says
##    which kinds move; anything above zero should also carry an authored idle
##    sequence, because the shader bends what is drawn and the frames are what
##    make a plant breathe. `FOLIAGE_IDLE_EXEMPT` names the one asset that could
##    not be generated and says why.
## 2. **A kind that does not sway has none.** A rock that breathes is a bug, and
##    a stray `prop_rock_idle_01.png` would produce one silently.
## 3. **The tuning is actually different per kind.** A per-kind table whose values
##    are all 1.0 is a table nobody tuned, and would pass every other check here
##    while looking exactly like the bug it was written to fix.
##
## Frames are checked for existence and for *size*, because a sequence whose
## frames are a different canvas from the base does not animate - it jumps.

var _failures: int = 0
var _checked: int = 0

const FOLIAGE_DIR: String = "res://art/foliage"


func _ready() -> void:
	_test_kinds_that_sway_have_frames()
	_test_kinds_that_do_not_sway_have_none()
	_test_frames_match_their_base()
	_test_the_tuning_is_tuned()

	if _failures == 0:
		print("[foliage-art] PASS - %d sequences, every swaying kind animated and "
			% _checked + "every still one left alone")
	else:
		push_error("[foliage-art] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Every regional kind, shared prop and tree that the sway table says moves.
func _animatable() -> PackedStringArray:
	var wanted := PackedStringArray()
	for region: String in ["jungle", "desert", "snow"]:
		# The region's own plant is the baseline kind, keyed as "" in the table.
		if float(Balance.FOLIAGE_KIND_SWAY.get("", 1.0)) > 0.0:
			wanted.append("plant_%s" % region)
		for kind: String in Foliage.REGIONAL_KINDS:
			if float(Balance.FOLIAGE_KIND_SWAY.get(kind, 1.0)) > 0.0:
				wanted.append("plant_%s_%s" % [region, kind])
		# Trees carry their own table and every region in it moves.
		if float(Balance.FOLIAGE_TREE_SWAY.get(region, 1.0)) > 0.0:
			wanted.append("tree_%s" % region)
			for variant: int in range(1, 5):
				wanted.append("tree_%s_%02d" % [region, variant])
	for kind: String in Foliage.SHARED_KINDS:
		if float(Balance.FOLIAGE_KIND_SWAY.get(kind, 1.0)) > 0.0:
			wanted.append("prop_%s" % kind)
	return wanted


func _test_kinds_that_sway_have_frames() -> void:
	for stem: String in _animatable():
		if not ResourceLoader.exists("%s/%s.png" % [FOLIAGE_DIR, stem]):
			# A kind named in the table with no art at all is a different fault,
			# and `run_tool.gd -- report` owns it.
			continue
		if Balance.FOLIAGE_IDLE_EXEMPT.has(stem):
			continue
		_checked += 1
		for frame: int in range(1, 4):
			var path: String = "%s/%s_idle_%02d.png" % [FOLIAGE_DIR, stem, frame]
			_check(ResourceLoader.exists(path),
				"%s sways but has no frame %d, so it leans without ever breathing"
					% [stem, frame])


## The still props, named rather than derived, because "everything else" would
## quietly stop checking anything the moment a kind was renamed.
func _test_kinds_that_do_not_sway_have_none() -> void:
	var still: int = 0
	for kind: String in Foliage.SHARED_KINDS:
		if float(Balance.FOLIAGE_KIND_SWAY.get(kind, 1.0)) > 0.0:
			continue
		still += 1
		_check(not ResourceLoader.exists("%s/prop_%s_idle_01.png" % [FOLIAGE_DIR, kind]),
			"prop_%s has a sway of zero and an idle sequence, which is a rock that breathes"
				% kind)
	_check(still >= 4,
		"at least four props must be genuinely still, found %d - a field where "
			% still + "everything moves reads as underwater")


## A sequence on a different canvas from its base does not animate, it jumps.
func _test_frames_match_their_base() -> void:
	var directory: DirAccess = DirAccess.open(FOLIAGE_DIR)
	if directory == null:
		_check(false, "the foliage directory must be readable")
		return
	for file: String in directory.get_files():
		# Plants, props and trees follow the base-plus-continuation convention.
		# The butterfly does not - it is a creature with `_side_` and `_fly_`
		# sequences and no single base pose - and `ambient_life` owns it.
		if not file.ends_with(".png") or not file.contains("_idle_"):
			continue
		if not (file.begins_with("plant_") or file.begins_with("prop_")
				or file.begins_with("tree_")):
			continue
		var stem: String = file.get_basename().split("_idle_")[0]
		var base_path: String = "%s/%s.png" % [FOLIAGE_DIR, stem]
		if not ResourceLoader.exists(base_path):
			_check(false, "%s animates something that does not exist" % file)
			continue
		var base := load(base_path) as Texture2D
		var frame := load("%s/%s" % [FOLIAGE_DIR, file]) as Texture2D
		if base == null or frame == null:
			continue
		_check(base.get_size() == frame.get_size(),
			"%s is %s and its base is %s - a sequence must share one canvas"
				% [file, frame.get_size(), base.get_size()])


## A per-kind table whose values are all the same is a table nobody tuned.
func _test_the_tuning_is_tuned() -> void:
	var kind_values: Dictionary = {}
	for kind: Variant in Balance.FOLIAGE_KIND_SWAY:
		kind_values[float(Balance.FOLIAGE_KIND_SWAY[kind])] = true
	_check(kind_values.size() >= 5,
		"per-kind sway has %d distinct values, which is not tuning" % kind_values.size())

	var tree_values: Dictionary = {}
	for region: Variant in Balance.FOLIAGE_TREE_SWAY:
		tree_values[float(Balance.FOLIAGE_TREE_SWAY[region])] = true
	for region: String in ["jungle", "desert", "snow"]:
		_check(Balance.FOLIAGE_TREE_SWAY.has(region),
			"the %s canopy has no sway of its own" % region)
	_check(tree_values.size() == Balance.FOLIAGE_TREE_SWAY.size(),
		"two regions share a canopy sway, so the tree tuning is decorative")

	# And the materials really do differ, rather than the table being read by
	# nobody. Two regions asked for, two materials back, and not the same object.
	var jungle: ShaderMaterial = Foliage.canopy_material("jungle")
	var snow: ShaderMaterial = Foliage.canopy_material("snow")
	_check(jungle != snow, "every region must get its own canopy material")
	if jungle != null and snow != null:
		_check(jungle.get_shader_parameter("sway_reach")
			!= snow.get_shader_parameter("sway_reach"),
			"a jungle broadleaf and a snow conifer must not lean by the same angle")


func _check(condition: bool, why: String) -> void:
	if condition:
		return
	_failures += 1
	print("[foliage-art] %s" % why)
