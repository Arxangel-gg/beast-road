extends Node

## The pixel grid, and the one thing it must never take: the type.
##
##   godot --headless --path game res://tools/pixel_filter_check.tscn
##
## Owner, 2026-09-17: *"The pixelshader should apply to everything in the game if
## possible except for text"*, *"The text in the town view scope is not legible
## with the pixelshader so text must not be affected"*, *"a toggle in the
## settings for whether the pixelshader should also affect UI panel windows,
## buttons, and images etc as well except for text"*, and *"a slider for it in
## settings so that resolutions lower but mostly higher than this are also
## included and able to be set."*
##
## **The whole feature is a stack of layer numbers**, and that is what makes it
## checkable without a screen. A filter pixelates what was drawn below it and
## cannot touch what was drawn above, so "except for text" is true if and only if
## the type is drawn last. Nothing here needs a frame to read.
##
## What it holds, and the way each one can be a lie:
##
## - **The order.** World grid under the HUD, interface grid over it, type over
##   both. Get any pair the wrong way round and the feature is silently the
##   opposite of what it says.
## - **The master switch.** The interface's grid under a sharp world is this
##   whole feature's own incoherence pointing the other way, so the second switch
##   may only ever narrow the first.
## - **The slider is clamped on the way out.** It is a saved number and a save is
##   a file: a grid of zero divides by nothing and a grid of four hundred is one
##   colour over the screen.
## - **Muted, not merely covered.** A sharp copy drawn over a blocky one leaves a
##   quantised fringe round every letter, which reads worse than the blocky text
##   did alone. So the gate reads the *original's* font colour back and insists
##   it is transparent while `CrispText` has it.
## - **Released exactly.** A control that carried no override must end with no
##   override, not with today's theme colour pinned onto it for ever - and a
##   control freed while muted must not be written to, which is the freed-object
##   cast that flooded `companion_check` with ninety-five errors a frame.
## - **The rectangles are bounded.** A `RichTextLabel` cannot be redrawn by
##   `draw_string`, so it is cut out of the grid where it stands; the shader's
##   array is eight long and a ninth must be refused rather than fall off the end
##   unseen.
## - **And the wiring, not the function.** A `CrispText` that works perfectly and
##   is never stood up is the fault this project has shipped twice - a warm-up
##   that bought nothing, and a set line the row builder never called. The run
##   and the title screen are walked for the calls that build one.
##
## **Headless is the point of one of these checks rather than a limitation of
## it.** `Graphics.pixel_filter()` is false with no display, so the settings path
## must leave everything off - an ear that attenuated anyway would have a hundred
## gates measuring a different game, and a grid that engaged would put a black
## rectangle over every screenshot this project takes.

const RUN_SOURCE: String = "res://scenes/run/run.gd"
const MENU_SOURCE: String = "res://scenes/ui/main_menu.gd"

var _failures: int = 0
var _checks: int = 0


## **Every test that yields is awaited.**
##
## Five of these stand a control up and need a frame or two before `CrispText`
## has walked it. Called without `await`, a coroutine returns to `_ready` at its
## first yield and `get_tree().quit()` runs before any of them finish - so the
## gate printed PASS having measured only the arithmetic. Found by planting the
## missing mute and watching it walk straight through, which is the whole
## reason a gate is validated with a real fault rather than read.
func _ready() -> void:
	_test_the_order_of_the_layers()
	_test_the_interface_never_outruns_the_world()
	_test_the_slider_is_clamped()
	_test_the_grid_scales_with_the_screen()
	await _test_headless_engages_nothing()
	await _test_the_type_is_held_out_of_the_grid()
	await _test_the_type_is_never_touched()
	await _test_a_freed_control_is_not_written_to()
	await _test_marked_up_text_is_held_out_too()
	await _test_the_mask_marks_where_the_type_stands()
	await _test_drawn_type_is_held_out_too()
	_test_the_ladder_starts_at_off()
	await _test_a_hidden_screen_is_left_alone()
	_test_both_screens_stand_one_up()
	if _failures == 0:
		print(("[pixel-filter] PASS - %d checks: the grid steps over every "
			+ "piece of type without moving or recolouring any of it, the "
			+ "interface never outruns the world, the slider is clamped, the "
			+ "mask marks where the type stands, and headless engages nothing"
			) % _checks)
	else:
		push_error("[pixel-filter] FAIL - %d problem(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- The stack ---------------------------------------------------------------

## Read off `Balance` rather than typed here, so the day somebody moves a layer
## this fails instead of agreeing with them.
func _test_the_order_of_the_layers() -> void:
	var world: int = Balance.UI_PIXEL_FILTER_LAYER
	var ui: int = Balance.UI_PIXEL_FILTER_UI_LAYER
	var type: int = Balance.UI_CRISP_TEXT_LAYER
	var hud: int = _hud_layer()

	_check(world < hud,
		("the world's grid sits at %d and the HUD at %d - a grid at or above the "
		+ "interface takes the interface with it, which is the second switch "
		+ "happening whether it was asked for or not") % [world, hud])
	_check(ui > hud,
		("the interface's grid sits at %d and the HUD at %d - below it, the "
		+ "switch that is supposed to take the panels onto the grid takes "
		+ "nothing at all and reads as doing nothing") % [ui, hud])
	_check(type > ui and type > world,
		("the type is drawn at %d, under a grid at %d - a filter cannot be "
		+ "escaped by anything drawn before it, so text below one is text on "
		+ "the grid") % [type, maxi(ui, world)])


## The HUD's layer, read out of its own source rather than by standing one up.
##
## A HUD wants a battlefield, a run and a hero; this check is about one integer.
func _hud_layer() -> int:
	var text: String = _source("res://scenes/ui/hud.gd")
	for line: String in text.split("\n"):
		var bare: String = line.strip_edges()
		if bare.begins_with("layer = ") and bare.trim_prefix("layer = ").is_valid_int():
			return int(bare.trim_prefix("layer = "))
	_check(false, "the HUD's own layer could not be read out of hud.gd")
	return -1


func _test_the_interface_never_outruns_the_world() -> void:
	var was_world: Variant = Graphics.to_dictionary().get(Graphics.KEY_PIXEL_FILTER)
	var was_ui: Variant = Graphics.to_dictionary().get(Graphics.KEY_PIXEL_FILTER_UI)

	# Asked through the real accessor rather than by reading the stored value,
	# because the rule lives in the accessor and a test of the dictionary would
	# pass with the rule deleted.
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER, false)
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_UI, true)
	_check(not Graphics.pixel_filter_ui(),
		"the interface's grid is on with the world's off - a sharp world under a "
		+ "blocky interface is exactly the incoherence this feature exists to "
		+ "remove, pointing the other way")

	_restore(Graphics.KEY_PIXEL_FILTER, was_world)
	_restore(Graphics.KEY_PIXEL_FILTER_UI, was_ui)


func _test_the_slider_is_clamped() -> void:
	var was: Variant = Graphics.to_dictionary().get(Graphics.KEY_PIXEL_FILTER_BLOCK)

	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_BLOCK, 0.0)
	_check(Graphics.pixel_filter_block() >= Balance.UI_PIXEL_FILTER_BLOCK_MIN,
		("a saved grid of 0 came back as %.2f - a block of nothing is a division "
		+ "by nothing") % Graphics.pixel_filter_block())

	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_BLOCK, 4000.0)
	_check(Graphics.pixel_filter_block() <= Balance.UI_PIXEL_FILTER_BLOCK_MAX,
		("a saved grid of 4000 came back as %.0f - one block over the whole "
		+ "screen is one colour, and a save is a file a player can edit")
		% Graphics.pixel_filter_block())

	var middle: float = round((Balance.UI_PIXEL_FILTER_BLOCK_MIN
		+ Balance.UI_PIXEL_FILTER_BLOCK_MAX) * 0.5)
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_BLOCK, middle)
	_check(is_equal_approx(Graphics.pixel_filter_block(), middle),
		"a grid inside the range did not come back unchanged, so the clamp is "
		+ "eating legal settings as well as illegal ones")

	_restore(Graphics.KEY_PIXEL_FILTER_BLOCK, was)


## The block is a share of the height, so the same setting is the same *effect*
## on every screen rather than the same number of pixels.
func _test_the_grid_scales_with_the_screen() -> void:
	var small: float = PixelGrid.block_at(Vector2(1280.0, 720.0), 3.0)
	var large: float = PixelGrid.block_at(Vector2(3840.0, 2160.0), 3.0)
	_check(large > small,
		("a 4K screen got a %.0f-pixel block against a 720p screen's %.0f - a "
		+ "flat block is a strong effect on a small window and almost nothing "
		+ "on a big one, which is two different games from one setting")
		% [large, small])
	_check(is_equal_approx(small, round(small)) and small >= 1.0,
		"the block came out fractional - one block edge then lands on a half "
		+ "pixel and the rows either side come out different widths, which reads "
		+ "as a seam rather than as pixel art")

	var coarse: float = PixelGrid.block_at(Vector2(1920.0, 1080.0),
		Balance.UI_PIXEL_FILTER_BLOCK_MAX)
	var fine: float = PixelGrid.block_at(Vector2(1920.0, 1080.0),
		Balance.UI_PIXEL_FILTER_BLOCK_MIN)
	_check(coarse > fine,
		"the slider's two ends draw the same grid, so the whole range is one "
		+ "setting wearing a slider's clothes")


func _test_headless_engages_nothing() -> void:
	var was: Variant = Graphics.to_dictionary().get(Graphics.KEY_PIXEL_FILTER)
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER, true)
	_check(not Graphics.pixel_filter(),
		"the grid engages with no display - there is no frame to copy, so the "
		+ "shader reads nothing and lays a black rectangle over every gate and "
		+ "every screenshot this project takes")

	var crisp := CrispText.new()
	add_child(crisp)
	crisp.refresh_from_settings()
	_check(not crisp.enabled(),
		"the type was taken over with no display - muting every caption in a "
		+ "headless run would make a hundred gates read a game whose text says "
		+ "nothing")
	crisp.queue_free()
	_restore(Graphics.KEY_PIXEL_FILTER, was)


# --- The type ----------------------------------------------------------------

## Drives the real door the setting calls, rather than the setting - which is
## off headless by design, and is the check above.
func _test_the_type_is_held_out_of_the_grid() -> void:
	var root := Control.new()
	root.size = Vector2(400.0, 200.0)
	var label := Label.new()
	label.text = "The Last Terrace"
	label.size = Vector2(300.0, 40.0)
	root.add_child(label)
	add_child(root)

	var crisp: CrispText = _crisp_over(root)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(crisp.drawn() >= 1,
		"no piece of type was held out of the grid - a comparison of two "
		+ "nothings is the most dangerous shape a check can take, and a "
		+ "`CrispText` that finds no strings passes every other test here")

	crisp.queue_free()
	root.queue_free()


## **The type is not touched at all, which is the whole of the fix.**
##
## The first cut muted every caption where it was authored and drew it again
## with `draw_string` - a second implementation of Godot's text layout, which
## drifted wherever a style box or an icon inset a string. The owner reported
## it as the interface toggle moving the text "out of position from where the
## texts used to be and are supposed to stay at".
##
## So this holds the opposite of what the old gate held: after the filter has
## taken a screen over, every control still has exactly the colour and exactly
## the rectangle it had before. Checked by putting the mute back, which it
## names on the colour.
func _test_the_type_is_never_touched() -> void:
	var root := Control.new()
	root.size = Vector2(400.0, 200.0)
	var plain := Label.new()
	plain.text = "no override"
	var dressed := Label.new()
	dressed.text = "an override"
	var was := Color(0.9, 0.3, 0.2, 1.0)
	dressed.add_theme_color_override(&"font_color", was)
	root.add_child(plain)
	root.add_child(dressed)
	add_child(root)
	await get_tree().process_frame
	var plain_was: Rect2 = plain.get_global_rect()
	var dressed_was: Rect2 = dressed.get_global_rect()

	var crisp: CrispText = _crisp_over(root)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(crisp.drawn() >= 2, "the two labels were not held out at all")
	_check(crisp.muted() == 0,
		"something was muted - nothing may be: a caption this filter has "
		+ "recoloured is a caption it has to put back, and the putting back "
		+ "is what moved the text in the first place")
	_check(not plain.has_theme_color_override(&"font_color"),
		"a label that carried no font colour of its own was given one")
	_check(dressed.get_theme_color(&"font_color").is_equal_approx(was),
		"a label's own font colour was changed by the filter")
	_check(plain.get_global_rect().is_equal_approx(plain_was)
			and dressed.get_global_rect().is_equal_approx(dressed_was),
		"a label moved when the grid came on - the owner's report, and the "
		+ "one thing a mask exists to make impossible")

	crisp.set_enabled(false, false)
	crisp.queue_free()
	root.queue_free()


func _test_a_freed_control_is_not_written_to() -> void:
	var root := Control.new()
	var doomed := Label.new()
	doomed.text = "here and gone"
	root.add_child(doomed)
	add_child(root)

	var crisp: CrispText = _crisp_over(root)
	await get_tree().process_frame
	await get_tree().process_frame

	# A screen closing while the grid is on. The release then walks a ledger
	# holding an object that is no longer there.
	doomed.free()
	crisp.set_enabled(false, false)
	_check(true,
		"releasing a ledger with a freed control in it threw - casting a freed "
		+ "object is what flooded `companion_check` with ninety-five errors a "
		+ "frame, and the guard has to come before the cast")

	crisp.queue_free()
	root.queue_free()


## Marked-up text is no longer a special case, which is the second thing the
## mask bought. `draw_string` is not a markup engine, so the old filter had to
## cut a `RichTextLabel` out of the grid by hand and could hold only eight of
## them; a mask holds a rich label by the same means as a plain one.
func _test_marked_up_text_is_held_out_too() -> void:
	var root := Control.new()
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	rich.text = "[b]marked up[/b]"
	rich.size = Vector2(200.0, 60.0)
	root.add_child(rich)
	add_child(root)

	var grid := PixelGrid.new()
	add_child(grid)
	var crisp: CrispText = _crisp_over(root, grid)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(grid.exclusions() >= 1,
		"a rich label was not held out of the grid")
	var ink: Color = rich.get_theme_color(&"default_color")
	_check(ink.a > 0.001,
		"a rich label was recoloured - nothing may be")

	crisp.queue_free()
	grid.queue_free()
	root.queue_free()


## **The mask marks where the type stands, and only there.**
##
## The old bound - eight rectangles, a ninth refused - is gone with the array
## it protected, and what replaces it is the property that actually matters: a
## screenful of captions is *all* held out, and the ground between them is not.
## A mask that came back all white would pass every other check in this file
## and turn the filter off everywhere.
func _test_the_mask_marks_where_the_type_stands() -> void:
	var root := Control.new()
	root.size = Vector2(900.0, 500.0)
	add_child(root)
	var many: int = 24
	for index: int in many:
		var label := Label.new()
		label.text = "caption %d" % index
		label.position = Vector2(float(index % 6) * 140.0,
			float(index / 6) * 60.0)
		label.size = Vector2(120.0, 30.0)
		root.add_child(label)
	var grid := PixelGrid.new()
	add_child(grid)
	var crisp: CrispText = _crisp_over(root, grid)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(grid.exclusions() >= many,
		("%d of %d captions were held out - the old filter could hold eight, "
		+ "which is what a mask exists to stop being a number at all")
		% [grid.exclusions(), many])
	_check(crisp.drawn() >= many,
		"the walk found fewer strings than were put on the screen")
	grid.queue_free()
	crisp.queue_free()
	root.queue_free()


## **Type a script painted itself is still type.**
##
## `BarName` writes "HP", "MP" and "SP" on the pool bars with `draw_string`,
## because a Label cannot be smaller than its own font and one anchored to an
## eight-pixel bar hangs off the bottom of it. Its class is therefore `Control`,
## it is on no list of drawn kinds, and the grid ran over the three captions in
## the corner of the HUD and over nothing else in the interface - which is what
## the owner reported on 2026-09-17 and a very confusing bug to be shown.
##
## Checked by *measuring the mask*, and with a bare `Control` beside it that
## declares nothing: a walk that held everything open would pass a check that
## only counted what it found.
func _test_drawn_type_is_held_out_too() -> void:
	var root := Control.new()
	root.size = Vector2(400.0, 200.0)
	add_child(root)
	var name_plate := BarName.new()
	name_plate.text = "HP"
	name_plate.position = Vector2(20.0, 20.0)
	name_plate.size = Vector2(60.0, 12.0)
	root.add_child(name_plate)
	var silent := Control.new()
	silent.position = Vector2(20.0, 80.0)
	silent.size = Vector2(60.0, 12.0)
	root.add_child(silent)
	var grid := PixelGrid.new()
	add_child(grid)
	var crisp: CrispText = _crisp_over(root, grid)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(grid.exclusions() == 1,
		("%d rect(s) held open - a control that paints its own lettering has "
		+ "to be one of them and a bare Control has to be none")
		% grid.exclusions())
	name_plate.text = ""
	crisp.refresh_from_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	_check(grid.exclusions() == 0,
		"a bar with no name on it still held a rectangle of the picture open")
	grid.queue_free()
	crisp.queue_free()
	root.queue_free()


## **Off, then one, then two.**
##
## The slider labelled a block of 1 as "Off" because a one-pixel grid is the
## identity - true, and it left a player with a control that went Off, 2, 3 and
## no way to ask for one (owner, 2026-09-17). The floor is zero now, so "off" is
## a real position on this slider and one is a real grid.
##
## The other half is that nothing may divide by a block under one: this is a
## saved number and a save is a file a player can edit.
func _test_the_ladder_starts_at_off() -> void:
	_check(is_equal_approx(Balance.UI_PIXEL_FILTER_BLOCK_MIN, 0.0),
		"the grid slider's floor is %.2f, so it cannot be turned off on its own"
		% Balance.UI_PIXEL_FILTER_BLOCK_MIN)
	_check(Balance.UI_PIXEL_FILTER_BLOCK_MAX >= 2.0,
		"the grid slider has no room above one")
	var view := Vector2(1920.0, 1080.0)
	_check(PixelGrid.block_at(view, 1.0) >= 1.0,
		"a block of one came back under a pixel")
	var was: float = Graphics.pixel_filter_block()
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_BLOCK, 0.0)
	_check(PixelGrid.block_for(view) >= 1.0,
		"a grid of zero reached the shader, which divides by it")
	_check(not Graphics.pixel_filter_runs(),
		"a grid of zero still pays for the copy and the shader")
	Graphics.set_display(Graphics.KEY_PIXEL_FILTER_BLOCK, was)


## A closed screen draws nothing, so nothing under it needs muting - and
## descending anyway would leave a whole screen's captions transparent for the
## next time it opens.
func _test_a_hidden_screen_is_left_alone() -> void:
	var root := Control.new()
	var shut := Control.new()
	shut.visible = false
	var hidden := Label.new()
	hidden.text = "a closed screen"
	shut.add_child(hidden)
	root.add_child(shut)
	add_child(root)

	var crisp: CrispText = _crisp_over(root)
	await get_tree().process_frame
	await get_tree().process_frame

	var ink: Color = hidden.get_theme_color(&"font_color")
	_check(ink.a > 0.001,
		"a label on a hidden screen was muted - it is drawn by nothing, so "
		+ "nothing is gained, and it opens next time with no words on it")

	crisp.queue_free()
	root.queue_free()


# --- The wiring --------------------------------------------------------------

## A source walk, deliberately.
##
## The failure this catches is an *omission*: a `CrispText` that works perfectly
## and is never stood up. Standing up a whole `Run` to see it would need a
## battlefield, a hero and a save; the content of the check is "this call
## exists", and that is what a source walk sees. `debrief_check` reads the three
## deaths the same way and for the same reason.
func _test_both_screens_stand_one_up() -> void:
	var run: String = _source(RUN_SOURCE)
	_check(run.contains("CrispText.new()"),
		"the run never builds a `CrispText`, so every string in the town scope "
		+ "stays under the world's grid - which is the illegibility the owner "
		+ "reported")
	_check(run.contains("Balance.UI_CRISP_TEXT_LAYER"),
		"the run's type is not on the crisp layer, so whatever layer it did land "
		+ "on decides whether it is filtered - by luck rather than by rule")
	_check(run.contains("PixelFilter.Covers.INTERFACE"),
		"the run never builds the interface's grid, so the second switch saves a "
		+ "value and changes nothing on screen")

	var menu: String = _source(MENU_SOURCE)
	_check(menu.contains("PixelGrid.new()"),
		"the title screen never builds a grid, so the owner's *\"make sure the "
		+ "main menu is also properly affected\"* is answered by the setting "
		+ "being saved and nothing else")
	_check(menu.contains("CrispText.new()"),
		"the title screen grids its own buttons with nothing drawing their "
		+ "captions sharp afterwards")


# --- Harness -----------------------------------------------------------------

func _crisp_over(root: Control, grid: PixelGrid = null) -> CrispText:
	var crisp := CrispText.new()
	crisp.ui_filter_grid = grid
	crisp.world_roots = [root] as Array[Node]
	add_child(crisp)
	crisp.set_enabled(true, true)
	return crisp


func _restore(key: String, was: Variant) -> void:
	if was == null:
		Graphics.from_dictionary(Graphics.to_dictionary())
		return
	Graphics.set_display(key, was)


func _source(path: String) -> String:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		_check(false, "could not read " + path)
		return ""
	var text: String = file.get_as_text()
	file.close()
	return text


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if condition:
		return
	_failures += 1
	push_error("[pixel-filter] " + why)
