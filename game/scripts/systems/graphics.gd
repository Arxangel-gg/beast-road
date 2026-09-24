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
## The level the frame-time governor measured the device down (or back up) to,
## kept apart from the player's own choice so the two never overwrite each
## other: `KEY_PRESET` is what the player said, this is what the frame said.
const KEY_AUTO_PRESET: String = "graphics_auto_preset"
const KEY_CAST_SHADOWS: String = "graphics_cast_shadows"
const KEY_CONTACT_SHADOWS: String = "graphics_contact_shadows"
const KEY_PARTICLES: String = "graphics_particles"
## Whether flood water reads and bends the ground beneath it. A frame copy
## while the field is flooded; off on Low, where the water is a flat sheet.
const KEY_WATER_REFRACTION: String = "graphics_water_refraction"
const KEY_RANK_SHEEN: String = "graphics_rank_sheen"
## Seeded coats on the wildlife. A look and nothing else - see `Phenotype`.
const KEY_PHENOTYPE: String = "graphics_phenotype"
## The fish swimming in the ponds. A look and nothing else - see `PondFish`,
## which says which single thing about them is read and why that is bounded.
const KEY_POND_FISH: String = "graphics_pond_fish"
const KEY_FOLIAGE: String = "graphics_foliage"
const KEY_CLOUDS: String = "graphics_clouds"
const KEY_FPS_CAP: String = "graphics_fps_cap"
## Whether the frame rate is shown on the battlefield (owner, 2026-09-17).
##
## **Off by default.** A frame counter is a developer's readout: a player who
## wants one knows to ask, and one nobody asked for teaches everybody else to
## watch a number instead of the road.
const KEY_FPS_SHOW: String = "graphics_fps_show"

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
## The fog of war, the colour grade and the minimap (2026-09-12): display
## preferences rather than quality switches, so none of them unlabels a preset.
const KEY_FOG: String = "fog_of_war"
const KEY_GRADE: String = "color_grade"
## The bloom inside the grade's pass (2026-09-24). A look, never a fact.
const KEY_BLOOM: String = "bloom"
const KEY_MINIMAP: String = "minimap"
## **Attack range rings, each kind its own switch** (owner, 2026-09-22): the
## ring a tower draws when it fires and the one an enemy draws after it attacks.
const KEY_RANGE_TOWERS: String = "range_rings_towers"
const KEY_RANGE_ENEMIES: String = "range_rings_enemies"
## Plants laid over by whatever walks through them (2026-09-17). A look and
## nothing else - `TrampleField` is read by the foliage shader and by no
## number in the game - so a weak machine can have the whole thing back for
## a small image and a texture sample, and the run is identical without it.
const KEY_FOLIAGE_TRAMPLE: String = "foliage_trample"
## **One grid over the whole world** (owner, 2026-09-17). The finished frame is
## snapped to a single block size, so the sprites' own pixels and everything
## the engine draws beside them - blood, flame, rings, fills - read as one
## material instead of two. A look and nothing else: it is over the world and
## under the interface, nothing reads it, and the run is identical without it.
const KEY_PIXEL_FILTER: String = "pixel_filter"

## Whether that grid also covers the interface - the plates, the buttons, the
## icons and the art on them, but never the type (owner, 2026-09-17).
##
## **Off by default**, deliberately. The world's grid has shipped and been
## played; this one changes the look of every screen in the game, and a
## preference that rearranges the interface on somebody who never asked for
## it is a preference imposed rather than offered.
const KEY_PIXEL_FILTER_UI: String = "pixel_filter_ui"

## How coarse the grid is, in blocks at the reference height.
##
## A number rather than a switch because the right answer is a taste: the
## owner asked for *"resolutions lower but mostly higher than this"*, so the
## shipped 3.0 sits near the bottom of a range that runs to 8.
const KEY_PIXEL_FILTER_BLOCK: String = "pixel_filter_block"

## Canvas items whose filter follows the setting.
const FILTER_GROUP: StringName = &"scaled_pixel_art"
const POND_FISH_GROUP: StringName = &"pond_fish"
## Nodes that read a display preference of their own and need telling when
## one changes. `apply_to_scene` calls `refresh_from_settings` on each.
## Without it the minimap switch in the video settings changed the saved
## value and nothing on screen, which is how a setting reads as broken.
const SETTINGS_GROUP: StringName = &"reads_display_settings"

## How far the darkest grade may be lifted toward white. Not to 1.0: at a full
## lift the day/night cycle stops existing, and a setting that can erase a core
## system is a setting that will be used to erase it by accident.
const BRIGHTNESS_MAX_LIFT: float = 0.55

## How far past the tint the slider may push, as a share of the lift.
##
## This is the half that reaches daylight. At full lift it is a gain of about
## 1.28, which is a readable field rather than a washed-out one - the point is
## that the setting does something at every hour, not that the default look
## changes. The default lift is still zero and the shipped game is untouched.
const BRIGHTNESS_DAY_GAIN: float = 0.50

## World tints that must be re-graded when brightness changes.
const TINT_GROUP: StringName = &"world_tint"

const PRESET_LOW: String = "low"
const PRESET_MEDIUM: String = "medium"
const PRESET_HIGH: String = "high"
const PRESET_ULTRA: String = "ultra"
const PRESET_CUSTOM: String = "custom"
## Low to Ultra, the order the governor steps along.
const PRESET_LADDER: Array[String] = [PRESET_LOW, PRESET_MEDIUM, PRESET_HIGH, PRESET_ULTRA]

## What each preset sets. `custom` is absent on purpose: it is not a preset, it
## is the label the UI shows once a player has touched an individual switch.
const PRESETS: Dictionary = {
	PRESET_LOW: {
		KEY_CAST_SHADOWS: false,
		KEY_CONTACT_SHADOWS: false,
		KEY_PARTICLES: 0.35,
		KEY_FOLIAGE: 0.25,
		KEY_CLOUDS: false,
		KEY_WATER_REFRACTION: false,
	},
	PRESET_MEDIUM: {
		KEY_CAST_SHADOWS: false,
		KEY_CONTACT_SHADOWS: true,
		KEY_PARTICLES: 0.7,
		KEY_FOLIAGE: 0.6,
		KEY_CLOUDS: true,
		KEY_WATER_REFRACTION: true,
	},
	PRESET_HIGH: {
		KEY_CAST_SHADOWS: true,
		KEY_CONTACT_SHADOWS: true,
		KEY_PARTICLES: 1.0,
		KEY_FOLIAGE: 0.6,
		KEY_CLOUDS: true,
		KEY_WATER_REFRACTION: true,
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
		KEY_WATER_REFRACTION: true,
	},
}

## Frame cap choices. 0 is uncapped.
##
## A cap is not only for weak machines. An uncapped 2D game on a strong one will
## happily render several hundred frames a second into a laptop's thermal limit
## and then stutter, which reads to the player as the game being badly optimised.
const FPS_CHOICES: Array[int] = [0, 15, 30, 60, 120, 144, 165, 240]

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


## **The first launch picks a preset for the machine it is on** (2026-09-21,
## roadmap §7.2: "performance auto-detect on first launch, choosing a preset
## rather than starting everyone at High"). High is still the answer for a
## discrete card, for the reason above `DEFAULT_PRESET`; what changed is that an
## integrated chip is not handed the most expensive version of the game and
## left to find the settings screen, and a software renderer is handed the
## cheapest. A player who has ever chosen a preset is never second-guessed:
## this is only read when the save holds no choice.
##
## Adapter names rather than benchmarks, because a benchmark on the first
## frame is a stutter on the first frame, and the names are stable enough to
## be a table. Kept short on purpose - a list that tried to know every card
## would be wrong about the next one - and asked once, since `preset()` is
## read on every switch and a driver string is not free to fetch.
const INTEGRATED_GPU_MARKS: Array[String] = ["intel", "uhd graphics",
	"hd graphics", "iris", "radeon(tm) graphics", "radeon graphics", "vega "]
const SOFTWARE_GPU_MARKS: Array[String] = ["llvmpipe", "swiftshader",
	"microsoft basic", "softpipe", "warp"]
static var _machine_preset: String = ""


## Pure, so a gate can ask it about machines nobody is sitting at.
static func preset_for_machine(adapter: String, web: bool, mobile: bool) -> String:
	if web:
		return DEFAULT_PRESET_WEB
	if mobile:
		return PRESET_LOW
	var name: String = adapter.to_lower()
	if name.is_empty():
		return DEFAULT_PRESET
	for mark: String in SOFTWARE_GPU_MARKS:
		if name.contains(mark):
			return PRESET_LOW
	for mark: String in INTEGRATED_GPU_MARKS:
		if name.contains(mark):
			return PRESET_MEDIUM
	return DEFAULT_PRESET


## The preset a save with no graphics block starts on.
static func default_preset() -> String:
	if _machine_preset.is_empty():
		_machine_preset = preset_for_machine(RenderingServer.get_video_adapter_name(),
			OS.has_feature("web"), OS.has_feature("mobile"))
	return _machine_preset


## What the settings screen says under the presets, so an automatic choice is
## visible rather than silent. Empty where there is no adapter to name.
static func machine_note() -> String:
	var adapter: String = RenderingServer.get_video_adapter_name().strip_edges()
	if adapter.is_empty():
		return ""
	var note: String = "Chosen for this machine: %s" % adapter
	if is_automatic() and not governed_preset().is_empty():
		note += " · measured down to %s in play" % governed_preset().capitalize()
	return note


## The live settings, held here rather than read from the save.
##
## This class must not touch `MetaState`. It is reached from `ShadowKit`,
## `Flame` and `Foliage`, and anything those are reachable from is also loaded by
## the headless tools — which run under `run_tool.gd`, replacing the main loop,
## where no autoload exists and naming one is a compile error. `UserSettings`
## owns persistence; this owns the values.
static var _chosen: Dictionary = {}


static func preset() -> String:
	return String(_chosen.get(KEY_PRESET, _chosen.get(KEY_AUTO_PRESET, default_preset())))


## Whether the player has never chosen a preset, so the machine and the frame
## decide it (`QualityGovernor`).
static func is_automatic() -> bool:
	return not _chosen.has(KEY_PRESET)


## What the governor measured the device to, or empty.
static func governed_preset() -> String:
	return String(_chosen.get(KEY_AUTO_PRESET, ""))


## The governor's step: remembered under its own key, never as the player's.
static func govern(name: String) -> void:
	if not PRESETS.has(name):
		return
	_chosen[KEY_AUTO_PRESET] = name
	apply_runtime()


## Hands the choice back to the machine and the frame ("Auto" on the settings
## screen): the player's preset and every switch they set are forgotten.
static func set_automatic() -> void:
	_chosen.erase(KEY_PRESET)
	_chosen.erase(KEY_AUTO_PRESET)
	for key: String in [KEY_CAST_SHADOWS, KEY_CONTACT_SHADOWS,
			KEY_PARTICLES, KEY_FOLIAGE, KEY_CLOUDS]:
		_chosen.erase(key)
	apply_runtime()


## How many posts share one real light on the road. One on every preset but
## Low, where a phone cannot afford a hundred lights and every third carries.
static func torch_light_every() -> int:
	return Balance.TORCH_LIGHT_EVERY_LOW if preset() == PRESET_LOW else 1


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


## Whether flood water bends the ground beneath it. Off headless: there is
## no frame to read.
static func water_refraction() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return bool(_value(KEY_WATER_REFRACTION))


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
	var lift: float = brightness_lift()
	if lift <= 0.0:
		return tint
	# **Toward white, and then past it.**
	#
	# Lerping toward white was the whole of this, and it meant the setting did
	# nothing at all during the day: the midday stop is Color(1, 1, 1) by
	# design - "midday, unfiltered" - so lerping it toward white returns the
	# same white. Measured at both ends of the slider on 2026-09-13: day read
	# (1.0, 1.0, 1.0) at zero lift and (1.0, 1.0, 1.0) at maximum, while night
	# moved (0.13, 0.17, 0.33) to (0.61, 0.63, 0.70). So a player who found the
	# game too dark and dragged brightness to the top saw their setting work
	# only after dusk - which is the half of the cycle they were not complaining
	# about.
	#
	# A CanvasModulate multiplies, and its colour may exceed one, so the gain is
	# what reaches the hours that are already unfiltered. The lerp is kept for
	# the coloured hours: it pulls dusk and night back toward neutral rather
	# than merely making them a brighter blue.
	var lifted: Color = tint.lerp(Color.WHITE, lift)
	var gain: float = 1.0 + lift * BRIGHTNESS_DAY_GAIN
	return Color(lifted.r * gain, lifted.g * gain, lifted.b * gain, tint.a)


## The texture filter scaled pixel art should use.
static func canvas_filter() -> int:
	var stored: Variant = _value(KEY_SMOOTHING)
	if stored != null and stored:
		return CanvasItem.TEXTURE_FILTER_LINEAR
	return CanvasItem.TEXTURE_FILTER_NEAREST


static func cloud_shadows() -> bool:
	return bool(_value(KEY_CLOUDS))


## Four-sample actor outlines and local loot shaders. Low sheds the texture
## reads; every other tier retains the readability pass.
static func polish_shaders() -> bool:
	return preset() != PRESET_LOW


## One screen-sized regional pass is reserved for the authored High target and
## Ultra. Medium keeps every gameplay-readable local shader without this fill.
static func regional_post_processing() -> bool:
	return preset() == PRESET_HIGH or preset() == PRESET_ULTRA


static func regional_post_scale() -> float:
	return 1.0 if preset() == PRESET_ULTRA else Balance.REGION_GRADE_HIGH_SCALE


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
	# **The physics tick follows the display** (2026-09-24). The Warden moves
	# in `_physics_process`; at sixty ticks a 144 Hz screen watched a hero
	# stepping at sixty while the road moved at 144. Headless there is no
	# display and the rate is the floor, so no gate measures a different game.
	Engine.physics_ticks_per_second = physics_rate()
	Engine.max_physics_steps_per_frame = Balance.PHYSICS_STEPS_PER_FRAME_MAX
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

	# Anything that reads a preference directly is told, rather than left to
	# notice on its next scope change.
	for node: Node in tree.get_nodes_in_group(SETTINGS_GROUP):
		if node.has_method("refresh_from_settings"):
			node.call("refresh_from_settings")

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


## Whether to draw the frame rate. See `KEY_FPS_SHOW`.
static func fps_shown() -> bool:
	return bool(_chosen.get(KEY_FPS_SHOW, false))


static func fps_cap() -> int:
	return int(_chosen.get(KEY_FPS_CAP, 0))


static func set_fps_cap(value: int) -> void:
	_chosen[KEY_FPS_CAP] = value
	apply_runtime()


static func fps_label(value: int) -> String:
	return "Uncapped" if value <= 0 else "%d" % value


## How many lights may cast shadows at once (`LightKit.budget_shadows`):
## the nearest few to what the camera watches. Zero wherever cast shadows
## are off; a custom preset that casts gets High's.
static func shadow_light_budget() -> int:
	if not cast_shadows():
		return 0
	if preset() == PRESET_ULTRA:
		return Balance.SHADOW_LIGHT_BUDGET_ULTRA
	return Balance.SHADOW_LIGHT_BUDGET_HIGH


## The physics tick rate for this display and this frame cap.
static func physics_rate() -> int:
	var refresh: float = -1.0
	if not DisplayServer.get_name() == "headless":
		refresh = DisplayServer.screen_get_refresh_rate()
	return physics_rate_for(refresh, fps_cap())


## Pure over the two numbers, for the gate: the display's refresh (negative
## when unknown) capped by the player's frame cap (zero when uncapped),
## inside `PHYSICS_RATE_MIN` and `PHYSICS_RATE_MAX`.
static func physics_rate_for(refresh: float, cap: int) -> int:
	var wanted: float = refresh if refresh > 0.0 else float(Balance.PHYSICS_RATE_MIN)
	if cap > 0:
		wanted = minf(wanted, float(cap)) if refresh > 0.0 else float(cap)
	return clampi(roundi(wanted), Balance.PHYSICS_RATE_MIN, Balance.PHYSICS_RATE_MAX)


## Whether the frame-wide colour grade runs. Off headless - a screen read on
## a server with no screen is a wasted pass - and off when the player turns
## it off in the video settings.
static func grade_enabled() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return bool(_chosen.get(KEY_GRADE, true))


## Whether bright things bleed light (2026-09-24). It rides the grade's pass, so
## it needs the grade; it asks the renderer for the screen's mip chain, so it is
## off by default on Low, where every full-screen cost counts.
static func bloom() -> bool:
	return grade_enabled() and bloom_chosen()


## The switch itself, apart from whether the grade is on to carry it - what the
## settings screen shows and the gate reads, headless included.
static func bloom_chosen() -> bool:
	return bool(_chosen.get(KEY_BLOOM, preset() != PRESET_LOW))


## Whether a big blow throws a real light for a moment (2026-09-24). Off on
## Low with the shadows and the refraction, for the same reason: a light
## re-draws everything under it.
static func light_bursts() -> bool:
	return preset() != PRESET_LOW


## Whether the fog of war covers the field. On by default; a player who
## wants the whole road visible turns it off in the video settings.
static func fog_of_war() -> bool:
	return bool(_chosen.get(KEY_FOG, true))


## Whether foliage is laid over by what walks through it. On by default.
static func foliage_trample() -> bool:
	return bool(_chosen.get(KEY_FOLIAGE_TRAMPLE, true))


## Whether the frame is snapped to one pixel grid. On by default: it is the
## look the art was drawn for, and the setting is there for anybody who
## prefers the soft edges - and for a machine that would rather not pay for a
## screen copy.
##
## **Never headless**, where there is no frame to copy. `flood_sheen` is under
## the same rule and for the same reason: a screen-reading shader with nothing
## to read draws a black rectangle over the game.
static func pixel_filter() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return bool(_chosen.get(KEY_PIXEL_FILTER, true))


## Whether the interface is snapped to that same grid. **Never without the
## world's**: a sharp world under a blocky interface is the incoherence this
## whole feature exists to remove, pointing the other way. So the world's
## switch is the master and this one only ever narrows it.
static func pixel_filter_ui() -> bool:
	return pixel_filter() and bool(_chosen.get(KEY_PIXEL_FILTER_UI, false))


## Whether the filter has anything to do at all.
##
## A block under one is the identity - every screen pixel is its own block - so
## running the copy, the shader and the mask for it is paying the whole cost of
## the feature to change nothing. Asked here rather than at each of the three
## places that used to compare the number themselves.
static func pixel_filter_runs() -> bool:
	return pixel_filter() and pixel_filter_block() >= 1.0


## How big one block is, at `Balance.UI_PIXEL_FILTER_REFERENCE_HEIGHT`.
##
## Clamped on the way out rather than trusted, because this is a saved number
## and a save is a file a player can edit: a grid of zero divides by nothing
## and a grid of four hundred is one colour over the whole screen.
static func pixel_filter_block() -> float:
	var want: float = float(_chosen.get(KEY_PIXEL_FILTER_BLOCK,
		Balance.UI_PIXEL_FILTER_BLOCK))
	return clampf(want, Balance.UI_PIXEL_FILTER_BLOCK_MIN,
		Balance.UI_PIXEL_FILTER_BLOCK_MAX)


## Whether elites, rare animals and shinies wear their rank in light.
##
## On by default. It is a *look* and nothing reads it, so switching it off
## changes no number anywhere - which is what makes it safe to give a weak
## machine, and the same bound the fog is held to.
static func rank_sheen() -> bool:
	return bool(_chosen.get(KEY_RANK_SHEEN, true))


## Whether every animal wears a coat of its own.
##
## On by default, and off changes no number anywhere: nothing in the game reads
## a phenotype - not rarity, not the collection, not the hunt, not loot - which
## is the same bound the rank sheen and the fog are held to.
static func phenotypes() -> bool:
	return bool(_chosen.get(KEY_PHENOTYPE, true))


## Whether the ponds have fish visibly swimming in them.
static func pond_fish() -> bool:
	return bool(_chosen.get(KEY_POND_FISH, true))


## Whether the minimap is shown. M toggles it in play as well.
static func minimap_shown() -> bool:
	return bool(_chosen.get(KEY_MINIMAP, true))


static func tower_rings_shown() -> bool:
	return bool(_chosen.get(KEY_RANGE_TOWERS, true))


static func enemy_rings_shown() -> bool:
	return bool(_chosen.get(KEY_RANGE_ENEMIES, true))
