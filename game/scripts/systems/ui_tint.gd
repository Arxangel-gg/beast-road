class_name UiTint
extends RefCounted

## Grades the interface to the place the player is standing in.
##
## **Owner brief, 2026-09-14:** tint the menu's interface to match its own look,
## and do the same for every act and time of day, so the interface is adaptive
## without ever becoming hard to read.
##
## The second half of that sentence is the whole design. A tint strong enough to
## be noticed is strong enough to hurt, so this changes **frames and never
## text**: it re-tints `StyleBoxTexture.modulate_color`, which is the ornate
## button and panel art, and leaves every font colour exactly as the theme set
## it. A player never has to read a word through this.
##
## It is also *shifted* rather than *dimmed*. The tint is pulled toward the
## scene's hue and then renormalised back to the brightness it started at, so a
## night act does not hand over a dark interface on top of a dark screen - which
## is the failure mode that makes adaptive UI a bad idea in most games.

## How far the frame art may travel toward the scene's hue.
##
## Measured on the menu, 2026-09-14. At 0.30 the shift was real but almost
## invisible against grey button art - the band moved from (110, 104, 112) to
## (115, 103, 107). At 0.50 it reads as warm without the buttons ceasing to
## look like the same buttons, which is the line this must not cross: the
## interface should belong to the scene, not be repainted by it. [TUNE]
const REACH: float = 0.50

## Controls that have opted in. A group rather than a walk from the root,
## because the HUD rebuilds parts of itself and a cached list would go stale.
const GROUP: StringName = &"ui_tinted"


## The colour the interface should lean toward, for the scope being shown.
##
## Read from the world rather than typed in per act: the day/night tint already
## carries the hour, and the terrain carries the region. Ten acts times a day's
## worth of hours is far too many numbers to author, and every one of them would
## be a number that could disagree with the sky it is sitting under.
static func for_the_world() -> Color:
	var hour: Color = DayNight.tint
	var ground: Color = Color(1.0, 1.0, 1.0)
	var terrain: TerrainData = ContentDB.terrain(RunState.terrain_id)
	if terrain != null:
		ground = terrain.grade_tint
	# The hour matters more than the ground: an interface should read as being
	# lit by the same light as everything else, and the region is a flavour on
	# top of that rather than the main ingredient.
	return hour.lerp(ground, 0.35)


## Applies a tint to everything in the group, and remembers it for anything
## that joins later.
##
## **Refuses work it does not need to do.** `DayNight.phase_changed` fires every
## frame the sun moves, and repainting a hundred-odd controls at sixty hertz to
## follow a colour that takes minutes to cross a shade would be the most
## expensive thing on the screen. Below `STEP` the tint is simply not worth
## re-laying, and a caller that has just built new controls passes `force`.
static func apply(tree: SceneTree, wanted: Color, force: bool = false) -> void:
	var settled: Color = _normalised(wanted)
	if not force and _moved(settled, _wanted) < STEP:
		return
	_wanted = settled
	for node: Node in tree.get_nodes_in_group(GROUP):
		var control := node as Control
		if control != null:
			paint(control)


## Puts every frame-drawing control under `root` into the group, and paints it.
##
## Walked rather than listed, because the HUD builds its bars and panels in a
## dozen functions and a list of them is a list that goes stale. Controls that
## are already enrolled are cheap to revisit: `paint` reuses the stylebox it
## made the first time.
static func enrol(tree: SceneTree, root: Node) -> void:
	_gather(root)
	for node: Node in tree.get_nodes_in_group(GROUP):
		var control := node as Control
		if control != null:
			paint(control)


static func _gather(from: Node) -> void:
	for child: Node in from.get_children():
		if child is Button or child is PanelContainer or child is Panel:
			var control := child as Control
			if not control.is_in_group(GROUP):
				control.add_to_group(GROUP)
		_gather(child)


## How far apart two tints are, summed across the channels.
static func _moved(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)


## Below this, a re-tint is not worth walking the tree for.
const STEP: float = 0.012


## The tint currently in force, for a control that has just been built.
static func current() -> Color:
	return _wanted


## Re-tints one control's frame art, leaving its text alone.
##
## Every stylebox it owns is duplicated before it is touched. They come from a
## shared `Theme` resource, so tinting one in place would tint every button in
## the game - including the ones on a screen that is not being graded at all.
static func paint(control: Control) -> void:
	if control == null:
		return
	for slot: String in _SLOTS:
		var existing: StyleBox = control.get_theme_stylebox(slot)
		if existing == null:
			continue
		var textured := existing as StyleBoxTexture
		if textured == null:
			continue
		var own: StyleBoxTexture = textured
		if not textured.has_meta(&"ui_tint_owned"):
			own = textured.duplicate() as StyleBoxTexture
			own.set_meta(&"ui_tint_owned", true)
			own.set_meta(&"ui_tint_base", textured.modulate_color)
			control.add_theme_stylebox_override(slot, own)
		var base: Color = own.get_meta(&"ui_tint_base", Color.WHITE) as Color
		own.modulate_color = base * _wanted


## Keeps the tint's own brightness at one.
##
## **This is what stops an adaptive interface becoming an unreadable one.** Deep
## night is (0.13, 0.17, 0.33); used directly it would take the buttons to a
## fifth of their value on the darkest screen in the game. Divided by its own
## luminance it keeps the *hue* - cold and blue - and hands back none of the
## darkness.
static func _normalised(tint: Color) -> Color:
	var value: float = 0.2126 * tint.r + 0.7152 * tint.g + 0.0722 * tint.b
	if value <= 0.01:
		return Color.WHITE
	var lifted: Color = Color(tint.r / value, tint.g / value, tint.b / value)
	return Color.WHITE.lerp(lifted, REACH)


## The stylebox slots a button or a panel actually draws itself from.
const _SLOTS: Array[String] = ["normal", "hover", "pressed", "focus",
	"disabled", "panel"]

static var _wanted: Color = Color.WHITE
