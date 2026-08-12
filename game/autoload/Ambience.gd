extends Node

## The ambience bed: wind, water, the beast breathing.
##
## Separate from MusicPlayer because it crossfades on a different trigger. Music
## follows the *situation* - menu, battle, boss. Ambience follows the *place*,
## which changes only when the terrain does, so the two would fight if they
## shared a player.
##
## Mixed on the Music bus deliberately: someone who turns the music down wants
## the whole background down, not just the melody.

const BEDS: Dictionary = {
	"ashfen": "res://audio/ambience/ambience_ashfen.ogg",
	"beast_walk": "res://audio/ambience/ambience_beast_walk.ogg",
	"saltglass": "res://audio/ambience/ambience_saltglass.ogg",
	"steppe": "res://audio/ambience/ambience_steppe.ogg",
}

const FADE_TIME: float = 2.5

var _player: AudioStreamPlayer
var _current: String = ""
var _tween: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	AudioBuses.ensure()
	_player.bus = AudioBuses.MUSIC
	add_child(_player)
	EventBus.act_started.connect(_on_act_started)
	EventBus.run_started.connect(func() -> void: play(RunState.terrain_id))


## `bed_id` accepts a terrain id ("ashfen") or a bed id. Unknown ids stop the bed
## rather than erroring, so a terrain without ambience is simply quiet.
func play(bed_id: String) -> void:
	var key: String = bed_id.trim_prefix("ambience_")
	if key == _current:
		return
	if not BEDS.has(key):
		stop()
		return
	_current = key

	var stream: AudioStream = load(BEDS[key]) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true

	_kill_tween()
	_player.stream = stream
	_player.volume_db = -60.0
	_player.play()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", Balance.AMBIENCE_DB, FADE_TIME)


func stop() -> void:
	_current = ""
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", -60.0, FADE_TIME)
	_tween.tween_callback(_player.stop)


func _on_act_started(_act: int, terrain_id: String) -> void:
	play(terrain_id)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
