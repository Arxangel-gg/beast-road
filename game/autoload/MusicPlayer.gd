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
	"steppe_bone_march": "res://audio/music/music_steppe_bone_march.ogg",
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
	_player = AudioStreamPlayer.new()
	_player.bus = &"Master"
	# Music must keep playing while the tree is paused, or opening the pause
	# menu would cut the soundtrack.
	_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_player)
	_player.finished.connect(_on_finished)

	if MetaState.has_signal("save_loaded"):
		MetaState.save_loaded.connect(apply_volume)


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
	_tween.tween_property(_player, "volume_db", _target_db(), FADE_TIME)


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
	if _player == null:
		return
	_kill_tween()
	_player.volume_db = _target_db()


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
