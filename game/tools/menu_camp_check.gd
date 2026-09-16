extends Node

## Somebody out there watching the beast, and the four ways that goes wrong.
##
## Owner brief, 2026-09-15. The vignette is a picture and `menu_shot` is what
## holds the picture; what this holds is the handful of things that are true or
## false rather than nice or ugly, and every one of them is a fault this camp
## actually shipped with during the hour it was built:
##
## - a figure graded until it was black on black;
## - a figure standing on the topmost pixel of an outcrop, which is a blade of
##   grass, so the whole camp floated a sixth of the rock above the ground;
## - a camp pitched under the interface, with the run statistics written across
##   the Warden;
## - and the same camp every visit.

var _failures: int = 0
var _checks: int = 0


func _ready() -> void:
	_test_every_piece_is_on_disk()
	_test_a_figure_is_never_black_on_black()
	_test_the_camp_stands_on_the_ground_it_is_given()
	_test_the_camp_keeps_out_of_the_interface()
	_test_no_two_visits_are_the_same_camp()
	_test_the_ledge_is_furnished()
	_test_no_frame_invents_a_bright_patch()
	_finish()


func _test_every_piece_is_on_disk() -> void:
	for path: String in [MenuCamp.CLIFF_ART, MenuCamp.SIT_ART, MenuCamp.STAND_ART,
			MenuCamp.RIDE_ART, MenuCamp.HORSE_ART]:
		_check(ResourceLoader.exists(path), "%s must exist" % path)
	var camp: MenuCamp = _camp()
	_check(camp.furnished(),
		"every piece must have loaded, or the camp is quietly missing somebody")
	camp.queue_free()


## **The first cut of this was black on black**, and every other number said it
## was fine: the node was there, the sprite was placed, the size was right. The
## Warden was graded the way the beast is - the local ground colour, pushed dark
## - over sprites already drawn as near-silhouettes, and a dark figure times a
## sixth is nothing. The beast survives that grade because it is painted in
## mid-tones. These are not, so the grade has a floor and dark ground warms the
## figure toward its own fire instead of darkening it.
func _test_a_figure_is_never_black_on_black() -> void:
	var fire := Color(1.0, 0.72, 0.36)
	for ground: Color in [Color(0.03, 0.03, 0.05), Color(0.08, 0.07, 0.1),
			Color(0.3, 0.24, 0.2), Color(0.6, 0.52, 0.44)]:
		var shade: Color = MenuCamp.graded_for(ground, fire)
		_check(shade.get_luminance() >= Balance.MENU_CAMP_FLOOR * 0.8,
			("a camp on ground of %0.3f would be multiplied by %0.3f, which over a "
				+ "silhouette is nothing at all")
				% [ground.get_luminance(), shade.get_luminance()])
		_check(shade.get_luminance() <= 1.0,
			"and a modulate may never exceed one (%0.3f)" % shade.get_luminance())
	# Dark ground must warm the figure rather than cool it: it is lit by its own
	# fire down there.
	var dim: Color = MenuCamp.graded_for(Color(0.03, 0.03, 0.05), fire)
	var bright: Color = MenuCamp.graded_for(Color(0.6, 0.52, 0.44), fire)
	_check(dim.r - dim.b > bright.r - bright.b,
		"a camp on dark ground must be warmer than one on lit ground")


## **The lip of the rock, not its topmost pixel.** The outcrop is painted with
## grass along its edge, so its highest pixel is a blade some way above anything
## that could be stood on - and standing the camp there floated it a sixth of
## the rock's height. The surface is measured from the art.
func _test_the_camp_stands_on_the_ground_it_is_given() -> void:
	var cliff: Texture2D = load(MenuCamp.CLIFF_ART) as Texture2D
	_check(cliff != null, "the outcrop must load")
	if cliff == null:
		return
	var surface: float = MenuCamp.surface_of(cliff)
	_check(surface > 0.02,
		("the outcrop's surface must be below its topmost pixel, or the art has "
			+ "no lip and the camp will stand on grass (%0.3f)") % surface)
	_check(surface < 0.5,
		"and it must be in the top half of the rock (%0.3f)" % surface)
	# Cached, because it reads every pixel of the image and the camp is laid out
	# on every resize.
	_check(is_equal_approx(surface, MenuCamp.surface_of(cliff)),
		"and the measurement must be stable between reads")


## The corners are taken: buttons down the left, run statistics down the right.
## A camp pitched into either is a silhouette with words across it.
func _test_the_camp_keeps_out_of_the_interface() -> void:
	var span := Vector2(1920.0, 1080.0)
	for _visit: int in 200:
		var camp: MenuCamp = _camp()
		camp.resize(span)
		var pitched: Dictionary = camp.camp()
		var at: float = float(pitched["at"])
		_check(at >= Balance.MENU_CAMP_BAND.x and at <= Balance.MENU_CAMP_BAND.y,
			"a camp pitched at %0.3f of the width, outside its own band" % at)
		var fire: Vector2 = camp.fire_at()
		if fire != Vector2.ZERO:
			# Read off `Balance` rather than typed here: this bound *is* where the
			# interface ends, and the two used to be able to disagree.
			_check(fire.x > span.x * Balance.MENU_CAMP_CLEAR_OF_INTERFACE.x
					and fire.x < span.x * Balance.MENU_CAMP_CLEAR_OF_INTERFACE.y,
				"a campfire at %0.0f is under the interface" % fire.x)
			_check(fire.y > span.y * 0.5 and fire.y < span.y,
				"and a campfire at %0.0f is off the picture" % fire.y)
		camp.queue_free()


## **A different camp every visit**, which is most of the brief. Counted over
## many, because one visit cannot show variety and five can only show five.
func _test_no_two_visits_are_the_same_camp() -> void:
	var seen: Dictionary = {}
	var poses: Dictionary = {}
	var with_cliff: int = 0
	var without: int = 0
	for _visit: int in 240:
		var camp: MenuCamp = _camp()
		var pitched: Dictionary = camp.camp()
		poses[int(pitched["pose"])] = true
		if bool(pitched["cliff"]):
			with_cliff += 1
		else:
			without += 1
		seen["%d|%s|%s|%s|%s" % [int(pitched["pose"]), str(pitched["cliff"]),
			str(pitched["horse"]), str(pitched["fire"]), str(pitched["side"])]] = true
		camp.queue_free()
	_check(poses.size() == 3,
		"all three things the Warden can be doing must turn up (%d)" % poses.size())
	_check(seen.size() >= 10,
		"the camp must vary between visits: %d arrangements over 240" % seen.size())
	_check(with_cliff > 0 and without > 0,
		("sometimes a cliff and sometimes none, which the brief asks for by name "
			+ "(%d with, %d without)") % [with_cliff, without])


func _camp() -> MenuCamp:
	var node := MenuCamp.new()
	add_child(node)
	return node


func _finish() -> void:
	if _failures == 0:
		print("[menu-camp] PASS - %d checks: every piece on disk, never black on black, standing on the rock's lip, clear of the interface, and a different camp every visit" % _checks)
	else:
		push_error("[menu-camp] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)




## **The ledge has things on it, and they are behind the person.**
##
## Owner, 2026-09-15: "make more props that can also be placed around the cliffs
## for world building". Eleven are authored and two or three are pitched each
## visit, which makes three ways this can be quietly wrong and none of them
## visible in a still: the same prop twice, a prop standing between the viewer
## and the Warden, and a set that is the same set every visit.
func _test_the_ledge_is_furnished() -> void:
	for path: String in MenuCamp.PROP_ART:
		_check(ResourceLoader.exists(path), "%s must exist" % path)
	_check(MenuCamp.PROP_HEIGHT.size() == MenuCamp.PROP_ART.size(),
		("every prop needs its own height against the Warden: %d heights for %d "
			+ "props") % [MenuCamp.PROP_HEIGHT.size(), MenuCamp.PROP_ART.size()])

	var sets: Dictionary = {}
	for _visit: int in 40:
		var camp: MenuCamp = _camp()
		var props: Array = camp.camp().get("props", [])
		_check(props.size() >= Balance.MENU_CAMP_PROPS_MIN
				and props.size() <= Balance.MENU_CAMP_PROPS_MAX,
			"a visit pitched %d props" % props.size())
		var seen: Dictionary = {}
		var ids: Array[int] = []
		for prop: Dictionary in props:
			var which: int = int(prop["art"])
			_check(not seen.has(which),
				"a camp must not own two of the same thing: %s"
					% MenuCamp.PROP_ART[which])
			seen[which] = true
			ids.append(which)
			# Out along the ledge, away from the figure. A crate drawn over the
			# Warden's knees costs the whole vignette for a crate.
			_check(float(prop["out"]) >= 0.8,
				"a prop stands %.2f figure-widths out, which is on top of them"
					% float(prop["out"]))
		ids.sort()
		sets[str(ids)] = true
		camp.queue_free()
	_check(sets.size() >= 20,
		("forty visits pitched %d different sets of props, which is a painted "
			+ "backdrop rather than a camp") % sets.size())




## **No idle frame paints something the base does not have.**
##
## The owner has been looking at a pale egg-shaped smear beside the standing
## Warden since the camp was built, and it was neither lighting nor grading:
## PixelLab's animator had painted a 645-pixel patch of near-white into the
## empty air on `menu_warden_stand_idle_03` and a 365-pixel one on `_idle_04`.
## The cycle showed each of them one frame in five. Every gate in the project
## passed the whole time - a frame with a blob on it is still a frame on disk,
## of the right size, made of real art.
##
## **What separates an artefact from animation is measured.** Every frame in
## every cycle adds pixels the base has none of, because a cloak that moves has
## to; across all four cycles those additions sit between 0.05 and 0.29
## luminance. The two bad patches were at 0.99, against a base whose brightest
## paint is 0.79. So the rule is: a *bright* thing in air the base leaves empty
## is invented, and `tools/scrub_menu_frames.py` removes it.
##
## Checked by area as well as brightness, because a single stray pixel on an
## edge is resampling and not a fault.
func _test_no_frame_invents_a_bright_patch() -> void:
	for stem: String in ["menu_warden_stand", "menu_warden_sit",
			"menu_warden_ride", "menu_fire_horse"]:
		var base_path: String = "res://art/ui/%s.png" % stem
		var base_texture: Texture2D = load(base_path) as Texture2D
		if base_texture == null:
			continue
		var base: Image = base_texture.get_image()
		var ceiling: float = 0.0
		for y: int in base.get_height():
			for x: int in base.get_width():
				var at: Color = base.get_pixel(x, y)
				if at.a >= 0.5:
					ceiling = maxf(ceiling, at.get_luminance())
		for index: int in range(1, 9):
			var frame_path: String = "res://art/ui/%s_idle_%02d.png" % [stem, index]
			if not ResourceLoader.exists(frame_path):
				continue
			var frame: Image = (load(frame_path) as Texture2D).get_image()
			if frame.get_width() != base.get_width() \
					or frame.get_height() != base.get_height():
				continue
			var invented: int = 0
			for y: int in frame.get_height():
				for x: int in frame.get_width():
					var here: Color = frame.get_pixel(x, y)
					if here.a < 0.5 or base.get_pixel(x, y).a >= 0.5:
						continue
					if here.get_luminance() >= ceiling * 1.25:
						invented += 1
			_check(invented < 120,
				("%s paints %d pixels of light into air the base leaves empty, "
					+ "brighter than anything on the figure - run "
					+ "tools/scrub_menu_frames.py") % [frame_path, invented])


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	print("[menu-camp] FAIL: %s" % why)
