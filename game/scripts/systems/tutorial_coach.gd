class_name TutorialCoach
extends PanelContainer

## Teaches a first-time player, once, without ever taking the game away.
##
## Deliberately not a scripted tutorial level. This game's first minute is
## already a safe one - Preparation spawns nothing and nothing walks until Ride
## On - so what a new player is missing is not protection, it is a sentence. Each
## prompt appears when its subject first becomes relevant, says one thing, and
## retires on a timer.
##
## **A card at the edge, not a banner across the middle.** The first version was
## 860 pixels wide and centred, which is a modal in everything but name: it sat
## over the battlefield the prompt was describing, and there was no way to get
## rid of it. This one is a narrow column against the left edge, clear of the
## build panel on the right and the command bar along the bottom, with a close
## button and a "stop showing these" beside it. Nothing blocks input; nothing has
## to be acknowledged for the game to continue.
##
## Seen-ness lives in settings rather than in the unlock pool. It is not
## progress, it is a preference about being told things, and it belongs with the
## other preferences - which also makes "show me again" a toggle rather than a
## save migration. Erasing saved data clears it too, because somebody starting
## the game over means to start it over.

const SETTING_KEY: String = "tutorial_seen"

## Fades over this long, so a card arriving mid-wave is noticed without snapping.
const FADE: float = 0.22

## Width of the card. Narrow enough to leave the field readable, wide enough for
## two short sentences at a size somebody will actually read.
const WIDTH: float = 330.0

var _steps: Array[TutorialStepData] = []
var _fired: Dictionary = {}
var _label: Label
var _left: float = 0.0
var _enabled: bool = false


func _ready() -> void:
	name = "TutorialCoach"
	_enabled = not bool(MetaState.settings.get(SETTING_KEY, false))
	visible = false
	modulate.a = 0.0

	# Low against the left edge. The right belongs to the build panel, the bottom
	# strip to the command bar, and the top to the seed line, the resources and
	# the boss bar - this corner is the one margin nothing else claims.
	# tools/layout_check found the first two placements sitting on the message
	# line and then on the seed readout, which is what that gate is for.
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offset_left = 24.0
	offset_right = 24.0 + WIDTH
	# Both offsets, not just the bottom one. With a bottom preset the top offset
	# is measured from the bottom edge as well, so leaving it at zero describes a
	# box running from the bottom of the screen *upwards past the top of itself* -
	# which is how the card ended up in the top-left corner twice.
	offset_top = -210.0
	offset_bottom = -210.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(WIDTH - 28.0, 0.0)
	_label.add_theme_font_size_override("font_size", 16)
	column.add_child(_label)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	column.add_child(buttons)

	var dismiss := Button.new()
	dismiss.text = "Got it"
	dismiss.focus_mode = Control.FOCUS_NONE
	dismiss.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dismiss.pressed.connect(_hide_card)
	buttons.add_child(dismiss)

	var never := Button.new()
	never.text = "Stop these"
	never.focus_mode = Control.FOCUS_NONE
	never.tooltip_text = "Turn the tutorial off. Settings can turn it back on."
	never.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	never.pressed.connect(func() -> void:
		_enabled = false
		_retire()
		_hide_card())
	buttons.add_child(never)

	if not _enabled:
		set_process(false)
		return

	_load_steps()
	EventBus.run_started.connect(func() -> void:
		_fire(TutorialStepData.Trigger.RUN_STARTED))
	EventBus.tower_changed.connect(func(_anchor: Vector2i) -> void:
		_fire(TutorialStepData.Trigger.TOWER_BUILT))
	EventBus.wave_started.connect(func(_wave: int, _lanes: Array) -> void:
		_fire(TutorialStepData.Trigger.WAVE_STARTED))
	EventBus.crossroad_reached.connect(func(_segment: int) -> void:
		_fire(TutorialStepData.Trigger.CROSSROAD_REACHED))
	EventBus.command_changed.connect(_on_command_changed)
	EventBus.preparation_changed.connect(_on_preparation_changed)


## Sorted once, so two steps sharing a trigger keep their authored order rather
## than whatever order the directory happened to list them in.
func _load_steps() -> void:
	for value: Variant in ContentDB.tutorial_steps.values():
		var step := value as TutorialStepData
		if step != null:
			_steps.append(step)
	_steps.sort_custom(func(a: TutorialStepData, b: TutorialStepData) -> bool:
		return a.order < b.order)


## Called by the HUD when the build panel opens: a UI event rather than a run
## event, so it does not belong on the bus.
func build_panel_opened() -> void:
	_fire(TutorialStepData.Trigger.BUILD_PANEL_OPENED)


func _on_command_changed(current: float, _maximum: float) -> void:
	if current > 0.0:
		_fire(TutorialStepData.Trigger.COMMAND_READY)


func _on_preparation_changed(seconds_left: float, _ready: bool) -> void:
	# Only a between-wave breather runs a clock; the opening one sits at zero.
	if seconds_left > 0.0:
		_fire(TutorialStepData.Trigger.BREATHER_OPENED)


## Each trigger teaches once per account. A lesson repeated is a lesson the
## player has already proved they did not need.
func _fire(trigger: int) -> void:
	if not _enabled or _fired.has(trigger):
		return
	for step: TutorialStepData in _steps:
		if step.trigger != trigger:
			continue
		_fired[trigger] = true
		_show(step)
		return


func _show(step: TutorialStepData) -> void:
	_label.text = step.body
	_left = step.seconds
	visible = true
	set_process(true)
	create_tween().tween_property(self, "modulate:a", 1.0, FADE)
	if _fired.size() >= _steps.size():
		_retire()


func _hide_card() -> void:
	_left = 0.0
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE)
	fade.tween_callback(func() -> void:
		visible = false
		set_process(false))


## Every lesson has been shown, or the player asked for them to stop. Written
## immediately: somebody who saw all seven and then crashed should not be taught
## the game a second time.
func _retire() -> void:
	MetaState.settings[SETTING_KEY] = true
	MetaState.save_game()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left <= 0.0:
		_hide_card()
