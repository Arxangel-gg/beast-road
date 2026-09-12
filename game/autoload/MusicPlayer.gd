extends Node

## Background music, held across scene changes.
##
## Autoloaded, so the track survives splash -> menu -> run without restarting.
## Asking for the track that is already playing does nothing, which is what lets
## every scene declare what it wants in `_ready` without stuttering the audio on
## every transition.
##
## **The battlefield is a playlist, as of 2026-09-11.** The owner asked for
## "maybe 12 songs for each act, a shuffled playlist for each act, and boss
## fight music for each act with proper crossfading transitions". So an act's
## music is up to `Balance.MUSIC_PLAYLIST_SLOTS` files at `PLAYLIST_FORMAT`,
## shuffled once when the act opens and played end to end, and a boss has its
## own track at `BOSS_FORMAT` that arrives on a slow crossfade under a stinger
## and hands back to the playlist when the boss falls.
##
## **A slot that has no file is skipped, quietly.** The slots exist so the
## soundtrack can grow by dropping a file in; a list of a hundred and thirty
## names with warnings for every absent one would make the game unplayable
## until the last song was written. An act with no playlist at all falls back
## to the regional battle track it always had, and a boss with no track of its
## own falls back to the one boss theme. Nothing is silent that was not
## silent before.
##
## Volume is read from MetaState.settings so the options screen controls it, and
## it is applied in decibels because that is what a fader actually is.

## Track id -> file, for the one-off situations. Ids are what scenes ask for;
## paths never appear elsewhere.
const TRACKS: Dictionary = {
	"battle_jungle": "res://audio/music/music_battle_jungle.ogg",
	"battle_desert": "res://audio/music/music_battle_desert.ogg",
	"battle_snow": "res://audio/music/music_battle_snow.ogg",
	"boss": "res://audio/music/music_boss.ogg",
	"crossroad": "res://audio/music/music_crossroad.ogg",
	"defeat": "res://audio/music/music_defeat.ogg",
	"menu": "res://audio/music/music_menu.ogg",
	"raid": "res://audio/music/music_raid.ogg",
	"snow_bone_march": "res://audio/music/music_snow_bone_march.ogg",
	"town": "res://audio/music/music_town.ogg",
	"victory": "res://audio/music/music_victory.ogg",
}

## Where an act's songs and its boss's theme live. `%02d` is the act, then the
## slot; the prompt sheet (`docs/SFX_PROMPTS.md`) names every one of them.
const PLAYLIST_FORMAT: String = "res://audio/music/music_act%02d_%02d.ogg"
const BOSS_FORMAT: String = "res://audio/music/music_boss_act%02d.ogg"

## The id `for_situation` answers for the battlefield. Not a file: the playlist
## decides which file, and `follow_situation` knows to ask it.
const BATTLE: String = "battle"

## Seconds to fade between tracks, and out to silence.
const FADE_TIME: float = 1.2

## Below this the player is muted outright — -80 dB is silence, but a fader
## sitting at 0.0 should not leave a stream running at inaudible volume.
const SILENCE_DB: float = -60.0

## Two players, swapped on every change. A single player cannot crossfade: the
## moment you assign a new stream the old one stops dead, so "fade in the new
## track" was really "hard-cut, then fade up from silence". Two players let the
## outgoing track fall away while the incoming one rises.
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
var _current: String = ""
var _tween: Tween

## The act's shuffled songs, as paths, and where in them we are. `_playlist_act`
## is what tells a scope change from an act change: the former resumes the
## same list, the latter deals a new one.
var _playlist: Array[String] = []
var _playlist_act: int = 0
var _playlist_index: int = -1
## Whether the track playing is one of the playlist's, so `finished` advances
## it rather than restarting it.
var _in_playlist: bool = false
## Where the field's song was when something else took the floor, so a scope
## change back does not start it over.
var _playlist_position: float = 0.0
## While a boss holds the floor the playlist waits; the boss falling hands
## back to it.
var _boss_holding: bool = false

## **A seam for `music_check`.** Act -> the song paths to deal, instead of
## reading `PLAYLIST_FORMAT` off the disk. Empty in the game. It exists because
## the playlist's behaviour - deal, shuffle, advance on `finished`, resume on a
## scope change - has to be provable before the first song is written, and a
## gate that copied audio files around to prove it would be testing the
## importer.
var test_slots: Dictionary = {}


func _ready() -> void:
	AudioBuses.ensure()
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = AudioBuses.MUSIC
		# Music must keep playing while the tree is paused, or opening the pause
		# menu would cut the soundtrack.
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = SILENCE_DB
		player.finished.connect(_on_finished.bind(player))
		add_child(player)
		_players.append(player)

	if MetaState.has_signal("save_loaded"):
		MetaState.save_loaded.connect(apply_volume)

	# The soundtrack follows the situation rather than the scene, so a scope
	# change swaps the track without every scene having to know a filename.
	EventBus.scope_changed.connect(func(_scope: int) -> void: follow_situation())
	EventBus.act_started.connect(func(_a: int, _t: String) -> void: follow_situation())
	EventBus.run_started.connect(func() -> void:
		_boss_holding = false
		follow_situation())
	EventBus.boss_spawned.connect(func(_id: String, act: int) -> void: play_boss(act))
	EventBus.boss_defeated.connect(func(_id: String, _act: int) -> void: _boss_fell())
	EventBus.raid_started.connect(func() -> void: play("raid"))
	EventBus.rift_started.connect(func(_k: int, _s: int, _n: int) -> void: play("raid"))
	EventBus.crossroad_reached.connect(func(_s: int) -> void: play("crossroad"))
	EventBus.run_ended.connect(func(victory: bool, _s: Dictionary) -> void:
		_boss_holding = false
		play("victory" if victory else "defeat"))
	AudioBuses.apply_volumes()


## Starts `track_id`, crossfading from whatever is playing. Re-requesting the
## current track is a no-op. `BATTLE` is answered by the act's playlist.
func play(track_id: String, fade: float = FADE_TIME) -> void:
	if track_id == BATTLE:
		_play_battle()
		return
	if track_id == _current and _players[_active].playing:
		return
	if not TRACKS.has(track_id):
		push_warning("MusicPlayer: unknown track '%s'" % track_id)
		return
	var path: String = TRACKS[track_id]
	if not ResourceLoader.exists(path):
		push_warning("MusicPlayer: missing file %s" % path)
		return
	_start(track_id, path, true, fade)
	_in_playlist = false


## The boss's own theme, on a slow fade under a stinger. The playlist waits.
func play_boss(act: int) -> void:
	_boss_holding = true
	Sfx.play("sfx_boss_stinger")
	var path: String = BOSS_FORMAT % act
	if not ResourceLoader.exists(path):
		path = String(TRACKS["boss"])
		if not ResourceLoader.exists(path):
			return
	_start("boss_act_%d" % act, path, true, Balance.MUSIC_BOSS_FADE)
	_in_playlist = false


## The boss fell: the playlist takes the floor back, slowly, under the fanfare.
func _boss_fell() -> void:
	if not _boss_holding:
		return
	_boss_holding = false
	Sfx.play("sfx_boss_fall")
	if GameDirector.run_active and for_situation() == BATTLE:
		_play_battle(Balance.MUSIC_BOSS_FADE)


## The act's songs, dealt once per act and played end to end.
func _play_battle(fade: float = FADE_TIME) -> void:
	if _boss_holding:
		return
	var act: int = maxi(RunState.act, 1)
	var fresh: bool = act != _playlist_act or _playlist.is_empty()
	if fresh:
		_deal_playlist(act)
	if _playlist.is_empty():
		# No song for this act at all: the regional track it always had.
		var fallback: String = _battle_track()
		_in_playlist = false
		if fallback != _current or not _players[_active].playing:
			_start(fallback, String(TRACKS[fallback]), true, fade)
		return
	# Resuming the same list (a scope change back to the field) keeps the song
	# that was playing, from where it was; only a new act or an ended song
	# moves on.
	if not fresh and _in_playlist and _players[_active].playing:
		return
	if not fresh and _playlist_index >= 0:
		_resume(fade)
		return
	_advance(fade)


## Every slot that has a file, shuffled. Not the run's seeded stream: which
## song plays first is not something a seed should reproduce, and drawing on
## a named stream here would move every roll made after it.
func _deal_playlist(act: int) -> void:
	_playlist.clear()
	_playlist_act = act
	_playlist_index = -1
	if test_slots.has(act):
		for path: Variant in (test_slots[act] as Array):
			_playlist.append(String(path))
	else:
		for slot: int in range(1, Balance.MUSIC_PLAYLIST_SLOTS + 1):
			var path: String = PLAYLIST_FORMAT % [act, slot]
			if ResourceLoader.exists(path):
				_playlist.append(path)
	_playlist.shuffle()


func _advance(fade: float = FADE_TIME) -> void:
	if _playlist.is_empty():
		return
	_playlist_index = (_playlist_index + 1) % _playlist.size()
	_playlist_position = 0.0
	_resume(fade)


## The song at the current index, from where it was left.
func _resume(fade: float = FADE_TIME) -> void:
	if _playlist.is_empty() or _playlist_index < 0:
		return
	var path: String = _playlist[_playlist_index]
	_in_playlist = true
	# One song loops; a list plays through and `finished` deals the next.
	_start("act_%d_song_%d" % [_playlist_act, _playlist_index + 1], path,
		_playlist.size() == 1, fade, _playlist_position)


## The crossfade itself. `loop` is false for a playlist song so its end is an
## event; everything else loops, because a menu theme that stopped would leave
## the game silent for the rest of the sitting.
func _start(track_id: String, path: String, loop: bool, fade: float,
		from_position: float = 0.0) -> void:
	# Leaving a playlist song for something else: remember where it was.
	if _in_playlist and not track_id.begins_with("act_") and not _players.is_empty():
		_playlist_position = _players[_active].get_playback_position()
	_current = track_id
	var stream: AudioStream = load(path)
	# Vorbis was chosen over MP3 for exactly this: MP3 carries encoder padding
	# that puts an audible gap at every loop point.
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop

	var outgoing: AudioStreamPlayer = _players[_active]
	_active = 1 - _active
	var incoming: AudioStreamPlayer = _players[_active]

	_kill_tween()
	incoming.stream = stream
	incoming.volume_db = SILENCE_DB
	incoming.play(from_position)

	# Equal-power-ish: both curves are eased so the sum does not dip in the
	# middle, which is what makes a linear crossfade sound like a gap.
	_tween = create_tween()
	_tween.set_parallel(true)
	_tween.tween_property(incoming, "volume_db", Balance.MUSIC_DB, fade)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	if outgoing.playing:
		_tween.tween_property(outgoing, "volume_db", SILENCE_DB, fade)\
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
		_tween.chain().tween_callback(outgoing.stop)


## Picks the track for the current moment. Callers name a situation, never a
## file, so re-scoring the game is editing this function.
func for_situation() -> String:
	# Scope is only meaningful inside a run, but a run scene opened directly -
	# from the editor, or by a test - has never been through start_run(), and
	# falling back to the menu theme there is wrong. Trust the scope instead.
	if not GameDirector.run_active and GameDirector.current_scope == GameDirector.Scope.BATTLEFIELD:
		if not RunState.terrain_id.is_empty():
			return BATTLE
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
	return BATTLE


## The regional track an act had before it had a playlist. Acts past the
## third rotate through the three, so a new region is never the wrong
## region's *one* song forever.
func _battle_track() -> String:
	var terrain: String = RunState.terrain_id
	if TRACKS.has("battle_" + terrain):
		return "battle_" + terrain
	var rotation: Array[String] = ["battle_jungle", "battle_desert", "battle_snow"]
	return rotation[posmod(maxi(RunState.act, 1) - 1, rotation.size())]


## Plays whatever the moment calls for. Safe to call repeatedly.
func follow_situation() -> void:
	play(for_situation())


func stop() -> void:
	_current = ""
	_in_playlist = false
	_boss_holding = false
	_kill_tween()
	_tween = create_tween()
	_tween.set_parallel(true)
	for player: AudioStreamPlayer in _players:
		if player.playing:
			_tween.tween_property(player, "volume_db", SILENCE_DB, FADE_TIME)\
				.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween.chain().tween_callback(func() -> void:
		for player: AudioStreamPlayer in _players:
			player.stop())


## Test and shutdown path: release decoder resources now instead of waiting for
## a fade that will never finish once the scene tree begins quitting.
func stop_immediately() -> void:
	_current = ""
	_in_playlist = false
	_boss_holding = false
	_playlist.clear()
	_playlist_act = 0
	_kill_tween()
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
		player.volume_db = SILENCE_DB


func current_track() -> String:
	return _current


## How many songs the current act's playlist holds, and which is playing.
## For the audio overlay and the gate.
func playlist_state() -> Dictionary:
	return {"act": _playlist_act, "songs": _playlist.size(), "index": _playlist_index,
		"in_playlist": _in_playlist, "boss": _boss_holding}


## Called by the options screen whenever a slider moves.
func apply_volume() -> void:
	# Volume is a property of the bus, not of the player. Doing it here as well
	# meant the fader was applied twice and the crossfade fought the slider.
	AudioBuses.apply_volumes()


## True while a crossfade is in flight. Used by the audio overlay.
func is_crossfading() -> bool:
	return _tween != null and _tween.is_valid()


func _target_db() -> float:
	var master: float = float(MetaState.settings.get("master_volume", 1.0))
	var music: float = float(MetaState.settings.get("music_volume", 0.8))
	var linear: float = clampf(master * music, 0.0, 1.0)
	if linear <= 0.001:
		return SILENCE_DB
	return linear_to_db(linear)


## A song ended. In a playlist that is the cue for the next one; anywhere
## else the stream loops itself, and a decoder that reports finished anyway
## should not leave the game silent for the rest of the run.
func _on_finished(player: AudioStreamPlayer) -> void:
	if player != _players[_active] or _current.is_empty():
		return
	if _in_playlist and _playlist.size() > 1 and not _boss_holding:
		_advance()
		return
	player.play()


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
