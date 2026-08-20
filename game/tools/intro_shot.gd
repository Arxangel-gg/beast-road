extends Node

## Renders one panel of the opening cinematic so it can be looked at.
## Diagnostic only, never a gate.

func _ready() -> void:
	RunState.reset()
	MetaState.story_intro_seen = false
	var intro := StoryIntro.new()
	add_child(intro)
	var panel: int = 0
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		panel = clampi(int(args[0]), 0, StoryIntro.PANELS.size() - 1)
	intro.visible = true
	# Started, not awaited. `_show` ends by fading the panel back out, so awaiting
	# it captures the black frame between panels - which is correct behaviour and
	# a useless screenshot.
	intro.call("_show", StoryIntro.PANELS[panel])
	await get_tree().create_timer(StoryIntro.FADE + 0.6, true, false, true).timeout
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("user://intro_shot.png")
	print("[intro] panel %d -> %s" % [panel,
		ProjectSettings.globalize_path("user://intro_shot.png")])
	get_tree().quit(0)
