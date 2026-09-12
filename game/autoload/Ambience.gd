extends Node

## The ambience bed: wind, water, the beast breathing.
##
## Separate from MusicPlayer because it crossfades on a different trigger. Music
## follows the *situation* - menu, battle, boss. Ambience follows the *place*,
## which changes only when the terrain does, so the two would fight if they
## shared a player.
##
## Mixed on its own bus since 2026-09-12 (owner brief): the ambience has a
## slider, and so does the weather, which plays here too - the rain, the snow
## wind, the dust and the heat are beds like the region's, chosen by the
## weather rather than the place, and crossfaded on the same rule.

const BEDS: Dictionary = {
	"jungle": "res://audio/ambience/ambience_jungle.ogg",
	"beast_walk": "res://audio/ambience/ambience_beast_walk.ogg",
	"desert": "res://audio/ambience/ambience_desert.ogg",
	"snow": "res://audio/ambience/ambience_snow.ogg",
	# The seven regions of 2026-09-11. Named so the file can be dropped in;
	# until it is, `play` finds nothing and the region is quiet.
	"hollow_marches": "res://audio/ambience/ambience_hollow_marches.ogg",
	"rustwood": "res://audio/ambience/ambience_rustwood.ogg",
	"saltpan": "res://audio/ambience/ambience_saltpan.ogg",
	"iron_steppe": "res://audio/ambience/ambience_iron_steppe.ogg",
	"glass_fields": "res://audio/ambience/ambience_glass_fields.ogg",
	"ashen_reach": "res://audio/ambience/ambience_ashen_reach.ogg",
	"last_terrace": "res://audio/ambience/ambience_last_terrace.ogg",
}

## One bed per weather that makes a sound. Clear weather has none, so it
## stops the bed rather than playing silence.
const WEATHER_BEDS: Dictionary = {
	"downpour": "res://audio/ambience/weather_downpour.ogg",
	"snowfall": "res://audio/ambience/weather_snowfall.ogg",
	"duststorm": "res://audio/ambience/weather_duststorm.ogg",
	"heatwave": "res://audio/ambience/weather_heatwave.ogg",
}

const FADE_TIME: float = 2.5

var _player: AudioStreamPlayer
var _current: String = ""
var _tween: Tween
var _weather_player: AudioStreamPlayer
var _weather_current: String = ""
var _weather_tween: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	AudioBuses.ensure()
	_player.bus = AudioBuses.AMBIENCE
	add_child(_player)
	_weather_player = AudioStreamPlayer.new()
	_weather_player.bus = AudioBuses.WEATHER
	add_child(_weather_player)
	EventBus.act_started.connect(_on_act_started)
	EventBus.run_started.connect(func() -> void:
		play(RunState.terrain_id)
		play_weather(RunState.weather_id))
	EventBus.weather_changed.connect(play_weather)
	EventBus.run_ended.connect(func(_won: bool, _summary: Dictionary) -> void: stop_weather())


## `bed_id` accepts a terrain id ("jungle") or a bed id. Unknown ids stop the bed
## rather than erroring, so a terrain without ambience is simply quiet.
func play(bed_id: String) -> void:
	var key: String = bed_id.trim_prefix("ambience_")
	if key == _current:
		return
	if not BEDS.has(key) or not ResourceLoader.exists(String(BEDS[key])):
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


## The weather's own bed. Unknown or silent weather stops it.
func play_weather(weather_id: String) -> void:
	if weather_id == _weather_current:
		return
	if not WEATHER_BEDS.has(weather_id) or not ResourceLoader.exists(String(WEATHER_BEDS[weather_id])):
		stop_weather()
		return
	_weather_current = weather_id
	var stream: AudioStream = load(WEATHER_BEDS[weather_id]) as AudioStream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_kill_weather_tween()
	_weather_player.stream = stream
	_weather_player.volume_db = -60.0
	_weather_player.play()
	_weather_tween = create_tween()
	_weather_tween.tween_property(_weather_player, "volume_db", Balance.WEATHER_DB, FADE_TIME)


func stop_weather() -> void:
	if _weather_current.is_empty() and not _weather_player.playing:
		return
	_weather_current = ""
	_kill_weather_tween()
	_weather_tween = create_tween()
	_weather_tween.tween_property(_weather_player, "volume_db", -60.0, FADE_TIME)
	_weather_tween.tween_callback(_weather_player.stop)


func _kill_weather_tween() -> void:
	if _weather_tween != null and _weather_tween.is_valid():
		_weather_tween.kill()


## The tree coming down takes the decoders with it. A weather bed started by
## the run (`weather_changed`) that was still playing when a headless gate
## quit read as four leaked ObjectDB instances - the stream, its playback and
## the two Ogg sequences - and only on the runs where the fade had not
## finished, which is what made it intermittent (2026-09-12).
func _exit_tree() -> void:
	stop_immediately()


## Test and shutdown path: drop the decoder immediately when no fade can be
## observed, preventing misleading resource-leak warnings in automated soaks.
func stop_immediately() -> void:
	_current = ""
	_kill_tween()
	_player.stop()
	_player.stream = null
	_player.volume_db = -60.0
	_weather_current = ""
	_kill_weather_tween()
	if _weather_player != null:
		_weather_player.stop()
		_weather_player.stream = null
		_weather_player.volume_db = -60.0


func _on_act_started(_act: int, terrain_id: String) -> void:
	play(terrain_id)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
