extends Node

## Background music, held across scene changes.
##
## Autoloaded, so the track survives splash -> menu -> run without restarting.
## Asking for the track that is already playing does nothing, which is what lets
## every scene declare what it wants in `_ready` without stuttering the audio on
## every transition.
##
## Volume is read from MetaState.settings so the options screen controls it, and
## it is applied in decibels because that is what a fader actually is.

## Track id -> file. Ids are what scenes ask for; paths never appear elsewhere.
const TRACKS: Dictionary = {
	"battle_ashfen": "res://audio/music/music_battle_ashfen.ogg",
	"battle_saltglass": "res://audio/music/music_battle_saltglass.ogg",
	"battle_steppe": "res://audio/music/music_battle_steppe.ogg",
	"boss": "res://audio/music/music_boss.ogg",
	"crossroad": "res://audio/music/music_crossroad.ogg",
	"defeat": "res://audio/music/music_defeat.ogg",
	"menu": "res://audio/music/music_menu.ogg",
	"raid": "res://audio/music/music_raid.ogg",
	"steppe_bone_march": "res://audio/music/music_steppe_bone_march.ogg",
	"town": "res://audio/music/music_town.ogg",
	"victory": "res://audio/music/music_victory.ogg",
}

## Seconds to fade between tracks, and out to silence.
const FADE_TIME: float = 1.2

## Below this the player is muted outright — -80 dB is silence, but a fader
## sitting at 0.0 should not leave a stream running at inaudible volume.
const SILENCE_DB: float = -60.0

var _player: AudioStreamPlayer
var _current: String = ""
var _tween: Tween


func _ready() -> void:
	AudioBuses.ensure()
	_player = AudioStreamPlayer.new()
	_player.bus = AudioBuses.MUSIC
	# Music must keep playing while the tree is paused, or opening the pause
	# menu would cut the soundtrack.
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_on_finished)

	if MetaState.has_signal("save_loaded"):
		MetaState.save_loaded.connect(apply_volume)

	# The soundtrack follows the situation rather than the scene, so a scope
	# change swaps the track without every scene having to know a filename.
	EventBus.scope_changed.connect(func(_scope: int) -> void: follow_situation())
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: follow_situation())
	EventBus.run_started.connect(follow_situation)
	EventBus.boss_spawned.connect(func(_id: String, _a: int) -> void: play("boss"))
	EventBus.raid_started.connect(func() -> void: play("raid"))
	EventBus.crossroad_reached.connect(func(_s: int) -> void: play("crossroad"))
	EventBus.run_ended.connect(func(victory: bool, _s: Dictionary) -> void:
		play("victory" if victory else "defeat"))
	AudioBuses.apply_volumes()


## Starts `track_id`, crossfading from whatever is playing. Re-requesting the
## current track is a no-op.
func play(track_id: String) -> void:
	if track_id == _current and _player.playing:
		return
	if not TRACKS.has(track_id):
		push_warning("MusicPlayer: unknown track '%s'" % track_id)
		return

	var path: String = TRACKS[track_id]
	if not ResourceLoader.exists(path):
		push_warning("MusicPlayer: missing file %s" % path)
		return

	_current = track_id
	var stream: AudioStream = load(path)
	# Vorbis was chosen over MP3 for exactly this: MP3 carries encoder padding
	# that puts an audible gap at every loop point.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true

	_kill_tween()
	_player.stream = stream
	_player.volume_db = SILENCE_DB
	_player.play()

	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", Balance.MUSIC_DB, FADE_TIME)


## Picks the track for the current moment. Callers name a situation, never a
## file, so re-scoring the game is editing this function.
func for_situation() -> String:
	# Scope is only meaningful inside a run, but a run scene opened directly -
	# from the editor, or by a test - has never been through start_run(), and
	# falling back to the menu theme there is wrong. Trust the scope instead.
	if not GameDirector.run_active and GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD:
		if not RunState.terrain_id.is_empty():
			return _battle_track()
		return "menu"
	if not GameDirector.run_active:
		return "menu"
	match GameDirector.current_scope:
		GameDirector.Scope.RAID:
			return "raid"
		GameDirector.Scope.TOWN:
			return "town"
		GameDirector.Scope.CROSSROAD:
			return "crossroad"
		_:
			pass
	return _battle_track()


func _battle_track() -> String:
	var terrain: String = RunState.terrain_id
	if TRACKS.has("battle_" + terrain):
		return "battle_" + terrain
	return "battle_ashfen"


## Plays whatever the moment calls for. Safe to call repeatedly.
func follow_situation() -> void:
	play(for_situation())


func stop() -> void:
	_current = ""
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENCE_DB, FADE_TIME)
	_tween.tween_callback(_player.stop)


func current_track() -> String:
	return _current


## Called by the options screen whenever a slider moves.
func apply_volume() -> void:
	# Volume is a property of the bus, not of the player. Doing it here as well
	# meant the fader was applied twice and the crossfade fought the slider.
	AudioBuses.apply_volumes()


func _target_db() -> float:
	var master: float = float(MetaState.settings.get("master_volume", 1.0))
	var music: float = float(MetaState.settings.get("music_volume", 0.8))
	var linear: float = clampf(master * music, 0.0, 1.0)
	if linear <= 0.001:
		return SILENCE_DB
	return linear_to_db(linear)


## Belt and braces: the stream loops itself, but a decoder that reports finished
## should not leave the game silent for the rest of the run.
func _on_finished() -> void:
	if not _current.is_empty():
		_player.play()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
