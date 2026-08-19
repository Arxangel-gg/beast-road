class_name TutorialCoach
extends PanelContainer

## Teaches a first-time player, once, without ever taking the game away.
##
## Deliberately not a scripted tutorial level. This game's first minute is
## already a safe one - Preparation does not spawn anything, and nothing walks
## until Ride On - so the thing a new player is missing is not protection, it is
## a sentence. Each prompt appears at the moment its subject first becomes
## relevant, says one thing, and retires on a timer.
##
## Nothing here blocks input, pauses, or requires acknowledgement. A prompt that
## has to be dismissed is a prompt that interrupts the player who already
## understood it, and that player is the one most likely to be replaying.
##
## Seen-ness is stored in settings rather than in the unlock pool: it is not
## progress, it is a preference about being told things, and it belongs with the
## other preferences. That also means "show me again" is a settings toggle
## rather than a save migration.

const SETTING_KEY: String = "tutorial_seen"

## Fades in and out over this long, so an arriving prompt is noticed without
## snapping into the middle of a fight.
const FADE: float = 0.25

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
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Low and central, above the command bar rather than below the boss bar. The
	# top of the screen is already the message line's, and two things explaining
	# themselves in the same strip is how a player ends up reading neither -
	# tools/layout_check caught exactly that overlap.
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	offset_left = -430.0
	offset_right = 430.0
	offset_bottom = -186.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	_label = Label.new()
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 19)
	add_child(_label)

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


## Called from the HUD when the build panel opens, because that is a UI event
## rather than a run event and does not belong on the bus.
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


## Every lesson has been shown once, so this account never sees them again.
## Written immediately: a player who saw all seven and then crashed should not
## be taught the game a second time.
func _retire() -> void:
	MetaState.settings[SETTING_KEY] = true
	MetaState.save_game()


func _process(delta: float) -> void:
	if _left <= 0.0:
		return
	_left -= delta
	if _left > 0.0:
		return
	var fade: Tween = create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE)
	fade.tween_callback(func() -> void:
		visible = false
		set_process(false))
