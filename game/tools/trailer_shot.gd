extends Node

## **Photographs the live trailer** (2026-10-07): deals one (`--seed=N`, or the
## clock), plays it, and saves a frame every `--every=` seconds into
## `user://trailer_shots/`, with the moment being filmed in the file's name. A
## diagnostic, not a gate: a trailer is judged by eye.
##
##   tools/perf_offscreen.sh <profile> res://tools/trailer_shot.tscn -- --seed=7 --every=0.8

var _player: TrailerPlayer = null
var _every: float = 0.8
var _next: float = 0.6
var _clock: float = 0.0
var _count: int = 0
var _out: String = "user://trailer_shots/"


func _ready() -> void:
	var seed: int = 0
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--every="):
			_every = float(argument.trim_prefix("--every="))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	_player = (load("res://scenes/ui/trailer_player.tscn") as PackedScene).instantiate() as TrailerPlayer
	_player.leaves = false
	_player.plan_seed = seed
	_player.ended.connect(_on_ended)
	add_child(_player)


func _process(delta: float) -> void:
	_clock += delta / maxf(Engine.time_scale, 0.01)
	if _player == null or _clock < _next:
		return
	_next = _clock + _every
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(960, 540, Image.INTERPOLATE_LANCZOS)
	var label: String = _player.filmed[_player.filmed.size() - 1] if not _player.filmed.is_empty() else "card"
	image.save_png(_out + "%03d_%s.png" % [_count, label])
	_count += 1


func _on_ended(why: String) -> void:
	print("[trailer-shot] %s, %d frames, filmed %s" % [why, _count, ", ".join(_player.filmed)])
	_player = null
	await get_tree().create_timer(0.3).timeout
	Sfx.stop_immediately()
	MusicPlayer.stop_immediately()
	Ambience.stop_immediately()
	get_tree().quit(0)
