class_name Graphics
extends RefCounted

## What a player can turn down to get their frames back.
##
## The options here are not a generic graphics menu copied from somewhere. They
## are the six things that actually cost this game frames, measured from what a
## soak reports on a populated battlefield:
##
##   24 shadow-casting lights   each torch runs a PCF13 shadow pass
##   ~290 contact shadows       one shader quad under every unit and plant
##   ~50 particle systems       embers and smoke on every flame
##   32 foliage band meshes     hundreds of plants batched by depth
##   1 cloud shadow layer       a full-field scrolling noise shader
##   uncapped frame rate        a laptop rendering 300 fps to cook itself
##
## The measured order varies with scene population. Foliage used to dominate
## until it was batched; cast shadows remain an effective option whose absence
## costs little: the game looks flatter at night and plays identically.
##
## **Nothing here changes gameplay.** Foliage is decoration, shadows are
## decoration, particles are decoration. A player on Low sees the same enemies at
## the same speeds in the same places as a player on High. That is a rule, not an
## accident — the moment a quality setting changes what is reachable or readable,
## it stops being a quality setting and becomes difficulty.
##
## Tier values live here rather than in `Balance.gd` on purpose. Balance is
## gameplay tuning, surfaced in the Update Manager and argued about in playtests;
## these are presentation budgets and belong with the code that spends them.

const KEY_PRESET: String = "graphics_preset"
const KEY_CAST_SHADOWS: String = "graphics_cast_shadows"
const KEY_CONTACT_SHADOWS: String = "graphics_contact_shadows"
const KEY_PARTICLES: String = "graphics_particles"
const KEY_FOLIAGE: String = "graphics_foliage"
const KEY_CLOUDS: String = "graphics_clouds"
const KEY_FPS_CAP: String = "graphics_fps_cap"

## Lifts the night toward daylight, for players whose screen is darker than the
## one this was graded on.
##
## Deliberately *not* in PRESETS. A quality preset is about what the machine can
## afford; this is about what the person can see, and folding it into Low/High
## would mean picking a preset silently changed how bright the game is.
const KEY_BRIGHTNESS: String = "display_brightness"

## Smooths the pixel art instead of drawing it hard-edged.
##
## Off by default, and it should stay off for most people: the art is authored as
## pixel art and nearest-neighbour is what it was drawn for. It exists because a
## 32px road tile drawn at twelve times its size is a lot of hard edges, and some
## players genuinely prefer them softened - and because the alternative to an
## option is a forum argument.
const KEY_SMOOTHING: String = "display_smoothing"

## Canvas items whose filter follows the setting.
const FILTER_GROUP: StringName = &"scaled_pixel_art"

## How far the darkest grade may be lifted toward white. Not to 1.0: at a full
## lift the day/night cycle stops existing, and a setting that can erase a core
## system is a setting that will be used to erase it by accident.
const BRIGHTNESS_MAX_LIFT: float = 0.55

## World tints that must be re-graded when brightness changes.
const TINT_GROUP: StringName = &"world_tint"

const PRESET_LOW: String = "low"
const PRESET_MEDIUM: String = "medium"
const PRESET_HIGH: String = "high"
const PRESET_ULTRA: String = "ultra"
const PRESET_CUSTOM: String = "custom"

## What each preset sets. `custom` is absent on purpose: it is not a preset, it
## is the label the UI shows once a player has touched an individual switch.
const PRESETS: Dictionary = {
	PRESET_LOW: {
		KEY_CAST_SHADOWS: false,
		KEY_CONTACT_SHADOWS: false,
		KEY_PARTICLES: 0.35,
		KEY_FOLIAGE: 0.25,
		KEY_CLOUDS: false,
	},
	PRESET_MEDIUM: {
		KEY_CAST_SHADOWS: false,
		KEY_CONTACT_SHADOWS: true,
		KEY_PARTICLES: 0.7,
		KEY_FOLIAGE: 0.6,
		KEY_CLOUDS: true,
	},
	PRESET_HIGH: {
		KEY_CAST_SHADOWS: true,
		KEY_CONTACT_SHADOWS: true,
		KEY_PARTICLES: 1.0,
		KEY_FOLIAGE: 0.6,
		KEY_CLOUDS: true,
	},
	# For machines with power to spare. High is the authored look; Ultra pushes
	# the two things that genuinely reward more of them - undergrowth density and
	# particle count - past what the art was tuned for.
	#
	# Only those two. Shadows and clouds are already on at High and there is no
	# "more on"; turning some other knob up to fill out the preset would be
	# decoration on a settings screen rather than something on the screen.
	PRESET_ULTRA: {
		KEY_CAST_SHADOWS: true,
		KEY_CONTACT_SHADOWS: true,
		KEY_PARTICLES: MAX_DENSITY,
		KEY_FOLIAGE: 1.45,
		KEY_CLOUDS: true,
	},
}

## Frame cap choices. 0 is uncapped.
##
## A cap is not only for weak machines. An uncapped 2D game on a strong one will
## happily render several hundred frames a second into a laptop's thermal limit
## and then stutter, which reads to the player as the game being badly optimised.
const FPS_CHOICES: Array[int] = [0, 30, 60, 120, 144]

## The ceiling for the density multipliers.
##
## Above 1.0 on purpose, so Ultra can mean more than High rather than the same
## thing with a different label. Clamped all the same: foliage is a real node
## count and particles are real emitters, and "unbounded" is how a quality
## setting becomes a way to hang somebody's machine.
const MAX_DENSITY: float = 1.75

## Applied when the save has nothing. High, because the machine that cannot
## handle it will tell its owner within a minute and the option is one screen
## away — whereas a player who never discovers the settings should not be
## quietly given the worst-looking version of the game.
const DEFAULT_PRESET: String = PRESET_HIGH

## The same question, answered differently in a browser.
##
## The argument for High rests on the player staying long enough to find the
## settings screen, which is a fair bet from someone who downloaded and installed
## a game. It is a bad bet on the web: the same machine runs slower there —
## WebGL2 through `gl_compatibility`, one thread, no driver-level shader cache —
## and the cost of closing a tab is nothing. Medium is what a first minute should
## look like when leaving is free.
const DEFAULT_PRESET_WEB: String = PRESET_MEDIUM


## The preset a save with no graphics block starts on.
static func default_preset() -> String:
	return DEFAULT_PRESET_WEB if OS.has_feature("web") else DEFAULT_PRESET


## The live settings, held here rather than read from the save.
##
## This class must not touch `MetaState`. It is reached from `ShadowKit`,
## `Flame` and `Foliage`, and anything those are reachable from is also loaded by
## the headless tools — which run under `run_tool.gd`, replacing the main loop,
## where no autoload exists and naming one is a compile error. `UserSettings`
## owns persistence; this owns the values.
static var _chosen: Dictionary = {}


static func preset() -> String:
	return String(_chosen.get(KEY_PRESET, default_preset()))


## Reads one switch, falling back through the current preset to High.
static func _value(key: String) -> Variant:
	if _chosen.has(key):
		return _chosen[key]
	var from: Dictionary = PRESETS.get(preset(), PRESETS[PRESET_HIGH])
	return from.get(key, (PRESETS[PRESET_HIGH] as Dictionary).get(key))


## Everything worth saving, for UserSettings to write.
static func to_dictionary() -> Dictionary:
	return _chosen.duplicate()


static func from_dictionary(values: Dictionary) -> void:
	_chosen = values.duplicate()
	apply_runtime()


# --- What the systems ask ----------------------------------------------------

## Real cast shadows from torches. The most expensive thing in the renderer and
## the cheapest to lose.
static func cast_shadows() -> bool:
	return bool(_value(KEY_CAST_SHADOWS)) and Balance.SHADOW_CAST_ENABLED


## High uses a crisp five-tap penumbra: it suits the harsh road lighting and is
## the 60 FPS authored target. Ultra spends the extra GPU budget on the softer
## thirteen-tap filter, making that tier visibly richer rather than just denser.
static func shadow_filter() -> Light2D.ShadowFilter:
	return Light2D.SHADOW_FILTER_PCF13 if preset() == PRESET_ULTRA \
		else Light2D.SHADOW_FILTER_PCF5


## Moving silhouettes multiply every torch shadow pass. High retains tower and
## town occlusion plus the soft grounding pool under every unit; Ultra opts into
## casting the hero/enemies themselves for the fully cinematic look.
static func shadow_cull_mask() -> int:
	var mask: int = Balance.SHADOW_LAYER_SCENERY
	if preset() == PRESET_ULTRA:
		mask |= Balance.SHADOW_LAYER_UNITS
	return mask


## The soft pool under every unit. Cheaper than cast shadows, and worth more:
## without it sprites read as stickers sliding over the floor.
static func contact_shadows() -> bool:
	return bool(_value(KEY_CONTACT_SHADOWS))


## Multiplier on every particle emitter's amount.
static func particle_scale() -> float:
	return clampf(float(_value(KEY_PARTICLES)), 0.0, MAX_DENSITY)


## Multiplier on the foliage scatter count.
static func foliage_scale() -> float:
	return clampf(float(_value(KEY_FOLIAGE)), 0.0, MAX_DENSITY)


## How far to lift the world tint toward white, 0.0 to BRIGHTNESS_MAX_LIFT.
##
## A lift rather than a multiply, because it has to raise the *floor*. Scaling a
## near-black tint by a gain leaves it near-black - which is exactly the case a
## brightness control exists for.
static func brightness_lift() -> float:
	var stored: Variant = _value(KEY_BRIGHTNESS)
	if stored == null:
		return 0.0
	return clampf(float(stored), 0.0, BRIGHTNESS_MAX_LIFT)


## The world tint as the player should actually see it.
##
## Every scope that tints for time of day goes through here, so the setting
## cannot be honoured on the battlefield and quietly ignored in the town.
static func graded(tint: Color) -> Color:
	return tint.lerp(Color.WHITE, brightness_lift())


## The texture filter scaled pixel art should use.
static func canvas_filter() -> int:
	var stored: Variant = _value(KEY_SMOOTHING)
	if stored != null and stored:
		return CanvasItem.TEXTURE_FILTER_LINEAR
	return CanvasItem.TEXTURE_FILTER_NEAREST


static func cloud_shadows() -> bool:
	return bool(_value(KEY_CLOUDS))


## Scales a count and never returns zero for a non-zero request — a system that
## asks for particles and gets none looks broken rather than economical.
static func scaled(amount: int, scale: float) -> int:
	if amount <= 0:
		return 0
	return maxi(int(round(float(amount) * scale)), 1)


# --- Applying ----------------------------------------------------------------

## Writes a whole preset. Individual switches are cleared rather than
## overwritten, so a later preset change is not silently ignored because a stale
## explicit value is still sitting in the save.
static func apply_preset(name: String) -> void:
	_chosen[KEY_PRESET] = name
	for key: String in [KEY_CAST_SHADOWS, KEY_CONTACT_SHADOWS,
			KEY_PARTICLES, KEY_FOLIAGE, KEY_CLOUDS]:
		_chosen.erase(key)
	apply_runtime()


## Sets one switch and marks the preset custom, because it no longer is one.
static func set_switch(key: String, value: Variant) -> void:
	_chosen[key] = value
	_chosen[KEY_PRESET] = PRESET_CUSTOM
	apply_runtime()


## A display preference, which is not part of any preset.
##
## Separate from `set_switch` because that one knocks the preset to Custom, and
## it should: touching shadows means you are no longer on High. Brightness is not
## a quality trade-off - it is about the screen in front of the player - so
## turning it up must not silently unlabel their chosen preset.
static func set_display(key: String, value: Variant) -> void:
	_chosen[key] = value
	apply_runtime()


## Applies everything to the game that is currently running.
##
## This used to set only the frame cap, on the reasoning that shadows, foliage
## and particle counts are read when a scope is built and so "apply on the next
## battlefield". That was wrong, and wrong in the way that matters: a player opens
## settings mid-run, turns everything down, closes the panel, and the game looks
## and performs exactly the same. From where they are sitting the setting does
## nothing — and the one player who most needs it is the one whose frame rate is
## already bad enough to go looking.
##
## Nothing here rebuilds a scope. Shadows and occluders are hidden rather than
## deleted, particle emitters keep their nodes and change their counts, and only
## the foliage is re-scattered — which is a plain rebuild of decoration that owns
## no state.
static func apply_runtime() -> void:
	Engine.max_fps = fps_cap()
	apply_to_scene()


## Pushes quality at whatever is on screen now.
static func apply_to_scene() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return

	var show_contact: bool = contact_shadows()
	for node: Node in tree.get_nodes_in_group(ShadowKit.GROUP):
		var shadow := node as CanvasItem
		if shadow != null:
			shadow.visible = show_contact

	var show_casters: bool = cast_shadows()
	for node: Node in tree.get_nodes_in_group(ShadowKit.CASTER_GROUP):
		var occluder := node as LightOccluder2D
		if occluder != null:
			occluder.visible = show_casters

	# Re-filter scaled pixel art, so the smoothing toggle takes effect on the
	# field being looked at rather than on the next one built.
	var filter: int = canvas_filter()
	for node: Node in tree.get_nodes_in_group(FILTER_GROUP):
		var item := node as CanvasItem
		if item != null:
			item.texture_filter = filter as CanvasItem.TextureFilter

	# Re-grade anything tinting for time of day, so brightness takes effect on
	# the field the player is looking at rather than on the next one built.
	for node: Node in tree.get_nodes_in_group(TINT_GROUP):
		var tint := node as CanvasModulate
		if tint != null:
			tint.color = graded(DayNight.tint)

	_walk(tree.root, show_casters)


## Lights, particles, clouds and foliage, in one pass.
static func _walk(from: Node, show_casters: bool) -> void:
	var light := from as PointLight2D
	if light != null and from.is_in_group(LightKit.SHADOW_GROUP):
		light.shadow_filter = shadow_filter()
		light.shadow_item_cull_mask = shadow_cull_mask()
		# Only touch lights that were set up to cast in the first place; the hero
		# and tower lights never do, and switching them on would light the field
		# from inside every sprite.
		var tier_allows: bool = not from.is_in_group(LightKit.ULTRA_SHADOW_GROUP) \
			or preset() == PRESET_ULTRA
		light.shadow_enabled = show_casters and tier_allows

	var clouds := from as CloudShadows
	if clouds != null:
		clouds.visible = cloud_shadows()

	var flame := from as Flame
	if flame != null:
		flame.refresh_quality()

	var foliage := from as Foliage
	if foliage != null:
		foliage.refresh_quality()
		# Its clumps are rebuilt wholesale; nothing below is worth walking.
		return

	for child: Node in from.get_children():
		_walk(child, show_casters)


static func fps_cap() -> int:
	return int(_chosen.get(KEY_FPS_CAP, 0))


static func set_fps_cap(value: int) -> void:
	_chosen[KEY_FPS_CAP] = value
	apply_runtime()


static func fps_label(value: int) -> String:
	return "Uncapped" if value <= 0 else "%d" % value
