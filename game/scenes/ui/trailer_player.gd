class_name TrailerPlayer
extends Control

## **The trailer, between the studio splash and the main menu** (owner,
## 2026-10-01), **made live at every launch** (owner, 2026-10-07: "make the
## trailers procedurally generated in game at game launch instead of a
## pre-recorded video ... Hyper epic trailers that are super aesthetically
## appealing and exciting and procedurally randomized for all").
##
## A trailer is dealt (`TrailerPlan`) - one Warden's journey over three roads in
## three different acts, layouts, lights and seeds, the Warden dressed for each
## point of it - and filmed as it happens (`TrailerStage`): every frame is the
## game. Cards on black name each road while the next one stands up under them;
## the moments are cut together with flashes; a line is laid over some of them;
## a big enough blow drops the world into slow motion for a breath; and the
## wordmark closes it.
##
## Played once a launch at most (`GameDirector.trailer_shown`), and only when it
## would be welcome: the setting is on, this is not the web (a browser refuses
## sound before a gesture), and the player has not turned the screen flashes
## down. **It always lets go**: any of Escape, Enter, Space, a pad's face, Start
## or Back, or the Skip button ends it at once; a road that will not stand up is
## skipped; a machine too slow to show it well (`TRAILER_MIN_FPS`) and a
## trailer past `TRAILER_LONGEST` go straight to the menu.
##
## **Nothing is kept.** Saves are held for the whole of it and the account is
## read back from the disk when it ends, exactly as a sandbox road's is; every
## road is `RunState.sandbox`; the score, the thumb controls and the light are
## given back.

## **Seams for `trailer_check`.** Headless the startup trailer is never played
## (there is no screen), and a gate that wants to drive the decision says so;
## `leaves` lets a gate end the trailer without the scene being replaced; `pace`
## runs every card and moment that many times faster in real time; `plan_seed`
## deals a chosen trailer rather than one from the clock.
static var play_in_tests: bool = false
## **How many trailers are on the screen**, read by anything on the road below
## that answers a skip key of its own (2026-10-08). The road a trailer films is
## the player's own descendant, and `_input` reaches descendants first - so the
## road's chat heard Enter before the player did, opened, and swallowed it, and
## a trailer the player asked to leave went on filming with the saves held. The
## release sweep caught it under load, when the road stood up before the press.
static var showing: int = 0
var leaves: bool = true
var pace: float = 1.0
var plan_seed: int = 0

signal ended(reason: String)

## Why it ended: "finished", "skipped", "slow", "timeout", "empty".
var reason: String = ""
## The plan being played, and how many moments were actually filmed.
var plan: Dictionary = {}
var filmed: Array[String] = []

var _stage: TrailerStage = null
## **First refusal on every key** (2026-10-08). `_input` is called in reverse
## tree order, so the road this player films - its own descendant - and anything
## added to the root after it hears a key before the player does; the release
## sweep caught Enter swallowed that way under load, with the trailer left
## filming and the saves held. One catcher kept as the root's last child is
## called before everything else in the tree, whatever stands up below.
var _keys: KeyCatcher = null
var _layer: CanvasLayer = null
var _cover: ColorRect = null
var _flash: ColorRect = null
var _bars: Array[ColorRect] = []
var _title: Label = null
var _card_big: Label = null
var _card_small: Label = null
var _card_line: Label = null
var _logo: TextureRect = null
var _skip: Button = null
var _done: bool = false
var _elapsed: float = 0.0
var _phase_was: float = 0.18
var _held: bool = false
var _slowmo_left: float = 0.0
var _slowmo_rest: float = 0.0
var _frames: int = 0
var _frame_time: float = 0.0


## The trailer is made, not loaded: always there.
static func available() -> bool:
	return true


## Whether the trailer opens this launch, on the way out of the splash.
static func should_autoplay() -> bool:
	if GameDirector.trailer_shown:
		return false
	if DisplayServer.get_name() == "headless" and not play_in_tests:
		return false
	if OS.has_feature("web"):
		return false
	if not UserSettings.trailer_at_startup():
		return false
	if JuiceDirector.flash_scale() < Balance.TRAILER_REDUCED_FLASH:
		return false
	return available()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Nothing the road does may pause the trailer that is filming it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A click anywhere that is not the Skip button lands here and nowhere else:
	# nothing on the road below is the player's to press.
	mouse_filter = Control.MOUSE_FILTER_STOP
	MetaState.hold_saves()
	_held = true
	showing += 1
	_phase_was = DayNight.phase
	# The clock's owner at one, so every give-back below (`GameSpeed.restore`)
	# returns to the world's own pace rather than to a fast-forward left on.
	GameSpeed.reset()
	TouchInput.held_off = true
	MusicPlayer.hold_score("menu")
	MetaState.settings["tutorial_seen"] = true
	for beat: MilestoneCinematicData in ContentDB.milestone_cinematics_sorted():
		MetaState.mark_milestone_cinematic_seen(beat.id)
	_stage = TrailerStage.new()
	_stage.name = "Stage"
	add_child(_stage)
	_keys = KeyCatcher.new()
	_keys.name = "TrailerKeys"
	_keys.player = self
	_keys.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(_keys)
	_build_overlay()
	EventBus.camera_impact.connect(_on_impact)
	var dealt: int = plan_seed if plan_seed != 0 else int(Time.get_unix_time_from_system() * 1000.0) ^ Time.get_ticks_usec()
	plan = TrailerPlan.make(absi(dealt) % 2147483646 + 1)
	print("[trailer] dealt %s" % _summary())
	_play.call_deferred()


func _summary() -> String:
	var parts: PackedStringArray = []
	for road: Dictionary in plan.get("roads", []) as Array:
		var ids: PackedStringArray = []
		for moment: Dictionary in road["moments"] as Array:
			ids.append(String(moment["id"]))
		parts.append("act %d %s %s [%s]" % [int(road["act"]), String(road["tier"]), String(road["map"]),
			", ".join(ids)])
	return " | ".join(parts)


# --- The film -----------------------------------------------------------------

func _play() -> void:
	var text: TrailerText = ContentDB.trailer_text()
	_show_card(text.opening if text != null else "", "", "")
	Sfx.play("sfx_war_horn")
	var roads: Array = plan.get("roads", []) as Array
	for index: int in roads.size():
		var road: Dictionary = roads[index]
		if index > 0:
			_show_card(_act_title(int(road["act"])), _region(int(road["act"])), String(road.get("line", "")))
			Sfx.play("sfx_boss_stinger")
		var card_from: float = _elapsed
		var stood: bool = await _stage.stand_up(road)
		if _done:
			return
		await _hold_until(card_from + Balance.TRAILER_CARD_SECONDS / pace)
		if _done:
			return
		if not stood:
			continue
		var first: bool = true
		for dealt: Dictionary in road["moments"] as Array:
			await _film(dealt, first)
			first = false
			if _done:
				return
			if not _fast_enough():
				_end("slow")
				return
	if filmed.is_empty():
		_end("empty")
		return
	await _closing()
	if not _done:
		_end("finished")


## One moment: staged out of sight, cut to, a line laid over it, rolled.
func _film(dealt: Dictionary, after_card: bool) -> void:
	if not after_card:
		await _dip(true)
	if _done:
		return
	await _stage.prepare(dealt)
	if _done:
		return
	_hide_card()
	_reveal(after_card)
	filmed.append(String(dealt.get("id", "")))
	var seconds: float = float(dealt.get("seconds", 5.0)) / pace
	var line: String = String(dealt.get("line", ""))
	if not line.is_empty():
		_lay_title(line, seconds)
	_frames = 0
	_frame_time = 0.0
	await _stage.roll(seconds)


## The wordmark, the tagline, and the last breath before the menu.
func _closing() -> void:
	await _dip(true)
	_stage.take_down()
	var text: TrailerText = ContentDB.trailer_text()
	_show_card("", "", text.tagline if text != null else "")
	if _logo != null:
		_logo.visible = true
		_logo.modulate.a = 0.0
		_logo.scale = Vector2.ONE * 1.12
		var rise: Tween = create_tween().set_parallel(true)
		rise.tween_property(_logo, "modulate:a", 1.0, 0.7 / pace)
		rise.tween_property(_logo, "scale", Vector2.ONE, 1.6 / pace).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	Sfx.play("sfx_boss_fall")
	await _hold_until(_elapsed + Balance.TRAILER_CLOSING_SECONDS / pace)


# --- Cuts, cards and titles ------------------------------------------------------

## To black, quickly - the cut's first half.
func _dip(_quick: bool) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_cover, "color:a", 1.0, Balance.TRAILER_CUT_SECONDS * 0.5 / pace)
	await tween.finished


## Out of black onto the moment, with a flash and a whoosh - or, after a card,
## a slower rise as the road is shown for the first time.
func _reveal(after_card: bool) -> void:
	var tween: Tween = create_tween()
	var seconds: float = (0.55 if after_card else Balance.TRAILER_CUT_SECONDS * 0.5) / pace
	tween.tween_property(_cover, "color:a", 0.0, seconds)
	_kick_flash(0.22 if after_card else 0.32)
	Sfx.play("sfx_dash")


func _kick_flash(strength: float) -> void:
	if _flash == null:
		return
	var scale: float = clampf(JuiceDirector.flash_scale(), 0.0, 1.0)
	_flash.color.a = strength * scale
	var fade: Tween = create_tween()
	fade.tween_property(_flash, "color:a", 0.0, 0.2 / pace).set_ease(Tween.EASE_OUT)


func _show_card(big: String, small: String, line: String) -> void:
	_cover.color.a = 1.0
	for label: Label in [_card_big, _card_small, _card_line]:
		label.modulate.a = 0.0
	_card_big.text = big
	_card_small.text = small
	_card_line.text = line
	_card_big.scale = Vector2.ONE * 1.18
	var show: Tween = create_tween().set_parallel(true)
	show.tween_property(_card_big, "modulate:a", 1.0, 0.35 / pace)
	show.tween_property(_card_big, "scale", Vector2.ONE, 0.9 / pace).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	show.tween_property(_card_small, "modulate:a", 1.0, 0.5 / pace).set_delay(0.15 / pace)
	show.tween_property(_card_line, "modulate:a", 0.9, 0.6 / pace).set_delay(0.45 / pace)


func _hide_card() -> void:
	for label: Label in [_card_big, _card_small, _card_line]:
		var fade: Tween = create_tween()
		fade.tween_property(label, "modulate:a", 0.0, 0.2 / pace)


## A line over a moment: rising into place a little after the cut, held, and
## gone before the next.
func _lay_title(line: String, seconds: float) -> void:
	_title.text = line
	_title.modulate.a = 0.0
	_title.pivot_offset = _title.size * 0.5
	_title.scale = Vector2.ONE * 1.06
	var hold: float = maxf(seconds - 1.4 / pace, 0.3 / pace)
	var tween: Tween = create_tween()
	tween.tween_interval(0.35 / pace)
	tween.set_parallel(true)
	tween.tween_property(_title, "modulate:a", 1.0, 0.45 / pace)
	tween.tween_property(_title, "scale", Vector2.ONE, 1.2 / pace).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(hold)
	tween.tween_property(_title, "modulate:a", 0.0, 0.4 / pace)


func _hold_until(at: float) -> void:
	while _elapsed < at and not _done:
		await get_tree().process_frame


## A heavy blow during a moment drops the world to `TRAILER_SLOWMO_SCALE` for a
## breath - not every blow, and never two in quick succession.
func _on_impact(_at: Vector2, power: float) -> void:
	if _done or power < Balance.TRAILER_SLOWMO_FROM or _slowmo_rest > 0.0:
		return
	if _stage == null or not _stage.is_rolling():
		return
	_slowmo_left = Balance.TRAILER_SLOWMO_SECONDS / pace
	_slowmo_rest = Balance.TRAILER_SLOWMO_REST / pace
	Engine.time_scale = Balance.TRAILER_SLOWMO_SCALE


func _process(delta: float) -> void:
	_keep_the_keys()
	if _done:
		return
	var real: float = delta / maxf(Engine.time_scale, 0.01)
	_elapsed += real
	_slowmo_rest -= real
	if _slowmo_left > 0.0:
		_slowmo_left -= real
		if _slowmo_left <= 0.0:
			GameSpeed.restore()
	if _stage != null and _stage.is_rolling():
		_frames += 1
		_frame_time += real
	_process_embers()
	if _elapsed >= Balance.TRAILER_LONGEST / pace:
		_end("timeout")


## Whether the last moment ran at a frame rate worth showing. Said in the log
## for every moment, so a trailer cut short says which moment was too heavy.
func _fast_enough() -> bool:
	if _frames < 30 or _frame_time <= 0.0:
		return true
	var rate: float = float(_frames) / _frame_time
	print("[trailer] %s at %.0f fps" % [filmed[filmed.size() - 1] if not filmed.is_empty() else "?", rate])
	if pace > 1.0:
		return true
	# **Lighter before giving up**: a slow moment makes the rest lighter, and
	# only a moment slow after that ends the trailer.
	if rate < Balance.TRAILER_MIN_FPS * Balance.TRAILER_LIGHTEN_MARGIN and not _stage.light:
		_stage.light = true
		print("[trailer] lightening the rest")
		return true
	return rate >= Balance.TRAILER_MIN_FPS


# --- Leaving ------------------------------------------------------------------

## Ends the trailer at the player's word.
func skip() -> void:
	_end("skipped")


## A key, read before anything else in the tree hears it (`KeyCatcher`). Not
## the player's own `_input`: the road below is its descendant and `_input`
## reaches a descendant first - and the road answers Enter and Escape of its own.
func read_key(event: InputEvent) -> void:
	if _done:
		return
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode in [KEY_ESCAPE, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
			get_viewport().set_input_as_handled()
			skip()
		return
	var pad := event as InputEventJoypadButton
	if pad != null and pad.pressed:
		if pad.button_index in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_START, JOY_BUTTON_BACK]:
			get_viewport().set_input_as_handled()
			skip()


## A click or a tap anywhere but the button brings the Skip button up to full,
## so a player who did not see it in the corner is shown where it is.
func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	var click := event as InputEventMouseButton
	if (touch != null and touch.pressed) or (click != null and click.pressed):
		if _skip != null:
			_skip.modulate.a = 1.0
			_skip.grab_focus()
		accept_event()


func _end(why: String) -> void:
	if _done:
		return
	_done = true
	reason = why
	print("[trailer] ended: %s at %.1fs, %d moments" % [why, _elapsed, filmed.size()])
	if _stage != null:
		_stage.cancelled = true
	ended.emit(why)
	if not leaves:
		_restore()
		return
	var seen: bool = why == "finished" or why == "skipped"
	if not seen or not is_inside_tree():
		_restore()
		GameDirector.goto_menu()
		return
	var fade: Tween = create_tween()
	fade.tween_property(_cover, "color:a", 1.0, Balance.TRAILER_FADE_SECONDS)
	fade.tween_callback(func() -> void:
		_restore()
		GameDirector.goto_menu())


## **Everything the trailer borrowed, given back**: the road taken down, the
## clock, the light, the score, the thumb controls, and the account read back
## from the disk it was never written to.
func _restore() -> void:
	if _stage != null:
		_stage.take_down()
	GameSpeed.reset()
	GameDirector.run_active = false
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	DayNight.set_underground(false)
	DayNight.call("_apply", _phase_was)
	Sfx.stop_immediately()
	Ambience.stop_immediately()
	Vfx.clear()
	TouchInput.held_off = false
	MusicPlayer.release_score()
	if EventBus.camera_impact.is_connected(_on_impact):
		EventBus.camera_impact.disconnect(_on_impact)
	if _held:
		_held = false
		MetaState.resume_saves()
		MetaState.load_save()
	ProceduralWarden.forget()
	RunState.reset()


func _exit_tree() -> void:
	showing = maxi(showing - 1, 0)
	if _keys != null and is_instance_valid(_keys):
		_keys.queue_free()
	_keys = null
	# A scene change that did not come through `_end` (a gate freeing the
	# player) still gives everything back.
	if not _done:
		_done = true
		_restore()


# --- The overlay -----------------------------------------------------------------

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = Balance.TRAILER_LAYER
	add_child(_layer)
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(root)
	# The bars a cinema screen has: the moments are framed wider than the
	# screen, which is most of what makes them read as film.
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		root.add_child(bar)
		_bars.append(bar)
	_fit_bars()
	get_viewport().size_changed.connect(_fit_bars)
	_title = _label(root, UiFonts.Role.TITLE, 44, Color(1.0, 0.93, 0.78))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_title.offset_left = -900.0
	_title.offset_right = 900.0
	_title.offset_top = -260.0
	_title.offset_bottom = -190.0
	# **The flash under the cover**: it lights the world as the cover lifts off
	# it, rather than lighting the black and reading as a grey frame.
	_flash = ColorRect.new()
	_flash.color = Color(1.0, 0.96, 0.88, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_flash.material = add
	root.add_child(_flash)
	_cover = ColorRect.new()
	_cover.color = Color.BLACK
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(_cover)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 14)
	root.add_child(column)
	_card_big = _label(column, UiFonts.Role.TITLE, 72, Color(1.0, 0.9, 0.7))
	_card_small = _label(column, UiFonts.Role.HEADING, 30, Color(0.86, 0.82, 0.74))
	_card_line = _label(column, UiFonts.Role.FLAVOUR, 26, Color(0.78, 0.74, 0.68))
	_card_big.resized.connect(func() -> void: _card_big.pivot_offset = _card_big.size * 0.5)
	var wordmark: Texture2D = load("res://art/ui/ui_logo.png") as Texture2D \
		if ResourceLoader.exists("res://art/ui/ui_logo.png") else null
	if wordmark != null:
		_logo = TextureRect.new()
		_logo.texture = wordmark
		_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		_logo.offset_left = -520.0
		_logo.offset_right = 520.0
		_logo.offset_top = -300.0
		_logo.offset_bottom = 80.0
		_logo.pivot_offset = Vector2(520.0, 190.0)
		_logo.visible = false
		root.add_child(_logo)
	_build_embers(root)
	_build_skip(root)
	UiJuice.enrol.call_deferred(get_tree(), self)


## **Embers rising over the cards**: a slow drift of sparks up from the bottom
## of the black, lit while a card is up and let go when the road shows. Additive
## and as many as the particle setting allows.
var _embers: CPUParticles2D = null


func _build_embers(parent: Control) -> void:
	_embers = CPUParticles2D.new()
	_embers.amount = maxi(int(round(56.0 * Graphics.particle_scale())), 8)
	_embers.lifetime = 4.2
	_embers.preprocess = 2.0
	_embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_embers.direction = Vector2.UP
	_embers.spread = 18.0
	_embers.gravity = Vector2(0.0, -14.0)
	_embers.initial_velocity_min = 38.0
	_embers.initial_velocity_max = 92.0
	_embers.scale_amount_min = 1.6
	_embers.scale_amount_max = 3.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.72, 0.32, 0.0))
	ramp.add_point(0.15, Color(1.0, 0.66, 0.28, 0.9))
	ramp.set_color(ramp.get_point_count() - 1, Color(1.0, 0.4, 0.14, 0.0))
	_embers.color_ramp = ramp
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_embers.material = add
	_embers.emitting = true
	parent.add_child(_embers)
	_place_embers()
	get_viewport().size_changed.connect(_place_embers)


func _place_embers() -> void:
	if _embers == null:
		return
	var view: Vector2 = get_viewport_rect().size
	_embers.position = Vector2(view.x * 0.5, view.y + 12.0)
	_embers.emission_rect_extents = Vector2(view.x * 0.5, 8.0)


func _process_embers() -> void:
	if _embers != null:
		_embers.modulate.a = clampf(_cover.color.a, 0.0, 1.0)


func _label(parent: Control, role: UiFonts.Role, size: int, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.75))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 3)
	label.add_theme_constant_override("shadow_outline_size", 10)
	UiFonts.set_role(label, role, size)
	parent.add_child(label)
	return label


func _fit_bars() -> void:
	if _bars.size() < 2:
		return
	var view: Vector2 = get_viewport_rect().size
	var tall: float = maxf((view.y - view.x / Balance.TRAILER_ASPECT) * 0.5, 0.0)
	_bars[0].offset_bottom = tall
	_bars[1].offset_top = -tall


func _build_skip(parent: Control) -> void:
	var text: TrailerText = ContentDB.trailer_text()
	_skip = Button.new()
	_skip.name = "Skip"
	_skip.text = text.skip if text != null else "Skip"
	_skip.focus_mode = Control.FOCUS_ALL
	_skip.tooltip_text = text.skip_hint if text != null else ""
	# A thumb's size on a touch layout, a button's otherwise.
	_skip.custom_minimum_size = Vector2(176.0, 92.0) if TouchInput.is_showing() \
		else Vector2(150.0, 52.0)
	_skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_skip.offset_right = -Balance.TRAILER_SKIP_MARGIN
	_skip.offset_bottom = -Balance.TRAILER_SKIP_MARGIN
	_skip.offset_left = _skip.offset_right - _skip.custom_minimum_size.x
	_skip.offset_top = _skip.offset_bottom - _skip.custom_minimum_size.y
	_skip.modulate.a = 0.0
	IconKit.on_button(_skip, "pressure_arrow", 22)
	_skip.pressed.connect(skip)
	parent.add_child(_skip)
	var show: Tween = create_tween()
	show.tween_interval(Balance.TRAILER_SKIP_DELAY)
	show.tween_property(_skip, "modulate:a", Balance.TRAILER_SKIP_ALPHA, 0.4)


func _act_title(act: int) -> String:
	const NUMERALS: Array[String] = ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI"]
	var text: TrailerText = ContentDB.trailer_text()
	var form: String = text.act_card if text != null else "Act %s"
	return form % NUMERALS[clampi(act - 1, 0, NUMERALS.size() - 1)]


func _region(act: int) -> String:
	var terrain: TerrainData = ContentDB.terrain_for_act(act)
	return terrain.display_name if terrain != null else ""


## Keeps the catcher the root's last child, so it is called first: anything
## added to the root after the trailer began - an overlay, a road's own layer -
## would otherwise hear a key before it.
func _keep_the_keys() -> void:
	if _keys == null or not is_instance_valid(_keys) or not _keys.is_inside_tree():
		return
	var parent: Node = _keys.get_parent()
	if parent != null and _keys.get_index() != parent.get_child_count() - 1:
		parent.move_child(_keys, -1)


## The trailer's ears: one node that does nothing but hand the player every key.
class KeyCatcher extends Node:
	var player: Node = null

	func _input(event: InputEvent) -> void:
		if player != null and is_instance_valid(player):
			player.call("read_key", event)
