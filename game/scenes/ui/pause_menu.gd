class_name PauseMenu
extends CanvasLayer

## Pause overlay. Pauses the tree, so every scope stops together and nothing
## keeps ticking behind it.

@export var panel: Control
@export var resume_button: Button
@export var menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	IconKit.on_button(resume_button, "close", 24.0)
	IconKit.on_button(menu_button, "settings", 24.0)
	resume_button.pressed.connect(toggle)
	menu_button.pressed.connect(func() -> void:
		get_tree().paused = false
		GameDirector.goto_menu())


func toggle() -> void:
	var showing: bool = not panel.visible
	panel.visible = showing
	get_tree().paused = showing
