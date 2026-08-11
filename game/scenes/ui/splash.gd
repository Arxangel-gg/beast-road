class_name Splash
extends Control

## Studio splash. Holds for SPLASH_DURATION, then hands off to the menu.
## Any key or click skips it — never make someone watch a logo twice.

@export var logo: TextureRect

var _left: float = 0.0


func _ready() -> void:
	_left = Balance.SPLASH_DURATION
	modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.4)


func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		_advance()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed():
		_advance()


func _advance() -> void:
	set_process(false)
	set_process_unhandled_input(false)
	GameDirector.goto_menu()
