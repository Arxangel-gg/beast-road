extends Node

## The soundtrack follows the situation, and the battlefield is a playlist.
##
## The owner asked for twelve songs an act, shuffled, with a boss theme an act
## and proper crossfades (2026-09-11). Most of those songs do not exist yet and
## will arrive one file at a time, so the behaviour has to be right before any
## of them do - and it has four ways to be quietly wrong:
##
## - a slot with no file warns or errors, which makes the game unplayable
##   until the last song is written;
## - an act with no songs goes silent instead of playing what it always did;
## - a song ends and the player restarts it rather than dealing the next;
## - a boss theme starts and never hands back, or hands back before the boss
##   has fallen.
##
## The playlist is dealt through `MusicPlayer.test_slots`, a documented seam,
## because copying audio into `user://` to prove this would be a test of the
## importer. The files it names are the shipped one-off tracks.

var _failures: int = 0
var _checked: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	RunState.reset(false, 20260911)
	await get_tree().process_frame

	_test_situations()
	_test_an_act_without_songs_plays_what_it_had()
	_test_a_playlist_is_dealt_shuffled_and_advanced()
	_test_a_scope_change_resumes_the_song()
	_test_the_boss_holds_the_floor_and_hands_back()
	_test_the_crossfade_is_a_crossfade()
	_test_the_cues_are_registered()

	MusicPlayer.test_slots.clear()
	MusicPlayer.stop_immediately()
	Sfx.stop_immediately()
	GameDirector.run_active = false
	for _f: int in 10:
		await get_tree().process_frame
	Sfx.stop_immediately()
	MetaState.resume_saves()
	if _failures > 0:
		push_error("[music] FAIL - %d of %d" % [_failures, _checked])
		get_tree().quit(1)
		return
	print("[music] PASS - %d checks: situations, the playlist, the boss and the crossfade" % _checked)
	get_tree().quit(0)


func _test_situations() -> void:
	GameDirector.run_active = false
	GameDirector.current_scope = GameDirector.Scope.TOWN
	_check(MusicPlayer.for_situation() == "menu", "no run is the menu")
	GameDirector.run_active = true
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	_check(MusicPlayer.for_situation() == MusicPlayer.BATTLE, "the battlefield is the playlist")
	GameDirector.current_scope = GameDirector.Scope.RAID
	_check(MusicPlayer.for_situation() == "raid", "a raid is the raid theme")
	GameDirector.current_scope = GameDirector.Scope.TOWN
	_check(MusicPlayer.for_situation() == "town", "the town is the town theme")
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD


## No song for an act: the regional track it always had, and nothing said.
func _test_an_act_without_songs_plays_what_it_had() -> void:
	MusicPlayer.test_slots.clear()
	MusicPlayer.stop_immediately()
	RunState.act = 1
	RunState.terrain_id = "jungle"
	MusicPlayer.play(MusicPlayer.BATTLE)
	var state: Dictionary = MusicPlayer.playlist_state()
	_check(int(state["songs"]) == 0, "act 1 has no songs on disk yet; found %d" % int(state["songs"]))
	_check(MusicPlayer.current_track() == "battle_jungle",
		"with no songs the jungle plays its battle track, not '%s'" % MusicPlayer.current_track())
	# A region past the third has no track of its own; it rotates through the
	# three rather than falling silent or playing Act I's forever.
	RunState.act = 5
	RunState.terrain_id = "hollow_marches"
	MusicPlayer.play(MusicPlayer.BATTLE)
	_check(MusicPlayer.current_track() == "battle_desert",
		"act 5 with no songs rotates to the desert track, not '%s'" % MusicPlayer.current_track())


func _test_a_playlist_is_dealt_shuffled_and_advanced() -> void:
	MusicPlayer.stop_immediately()
	var songs: Array = [MusicPlayer.TRACKS["menu"], MusicPlayer.TRACKS["town"],
		MusicPlayer.TRACKS["crossroad"], MusicPlayer.TRACKS["victory"]]
	MusicPlayer.test_slots = {3: songs}
	RunState.act = 3
	RunState.terrain_id = "snow"
	MusicPlayer.play(MusicPlayer.BATTLE)
	var state: Dictionary = MusicPlayer.playlist_state()
	_check(int(state["songs"]) == songs.size(), "four songs were given and %d dealt" % int(state["songs"]))
	_check(bool(state["in_playlist"]), "the battlefield must be playing from the list")
	_check(String(MusicPlayer.current_track()).begins_with("act_3_song_"),
		"the current track must be a song of the act, not '%s'" % MusicPlayer.current_track())
	# Shuffled: over several deals the first song is not always the same one.
	var firsts: Dictionary = {}
	for _deal: int in 12:
		MusicPlayer._deal_playlist(3)
		firsts[MusicPlayer._playlist[0]] = true
	_check(firsts.size() > 1, "twelve deals opened with the same song every time - the list is not shuffled")
	# Advanced on the end of a song, and wrapping.
	MusicPlayer.play(MusicPlayer.BATTLE)
	var seen: Dictionary = {}
	for _song: int in songs.size() + 1:
		seen[MusicPlayer.current_track()] = true
		MusicPlayer._on_finished(MusicPlayer._players[MusicPlayer._active])
	_check(seen.size() == songs.size(),
		"playing through the list must visit every song once before wrapping; visited %d of %d"
			% [seen.size(), songs.size()])
	_check(bool(MusicPlayer.playlist_state()["in_playlist"]), "and stay in the list after wrapping")


## Leaving the field and coming back keeps the song; a new act deals anew.
func _test_a_scope_change_resumes_the_song() -> void:
	var before: String = MusicPlayer.current_track()
	GameDirector.current_scope = GameDirector.Scope.TOWN
	MusicPlayer.follow_situation()
	_check(MusicPlayer.current_track() == "town", "the town takes the floor")
	GameDirector.current_scope = GameDirector.Scope.BATTLEFIELD
	MusicPlayer.follow_situation()
	_check(MusicPlayer.current_track() == before,
		"coming back to the field must resume '%s', not deal '%s'" % [before, MusicPlayer.current_track()])
	RunState.act = 4
	MusicPlayer.test_slots[4] = [MusicPlayer.TRACKS["raid"], MusicPlayer.TRACKS["defeat"]]
	MusicPlayer.follow_situation()
	_check(int(MusicPlayer.playlist_state()["act"]) == 4, "a new act deals a new list")
	_check(String(MusicPlayer.current_track()).begins_with("act_4_song_"),
		"and plays from it, not '%s'" % MusicPlayer.current_track())


func _test_the_boss_holds_the_floor_and_hands_back() -> void:
	var song: String = MusicPlayer.current_track()
	MusicPlayer.play_boss(4)
	_check(bool(MusicPlayer.playlist_state()["boss"]), "the boss must hold the floor")
	_check(MusicPlayer.current_track() == "boss_act_4",
		"act 4 has no theme of its own yet, so the boss theme plays as 'boss_act_4'; got '%s'"
			% MusicPlayer.current_track())
	# The playlist does not steal it back while the boss stands.
	MusicPlayer.play(MusicPlayer.BATTLE)
	_check(MusicPlayer.current_track() == "boss_act_4", "a scope change under a boss must not resume the songs")
	MusicPlayer._on_finished(MusicPlayer._players[MusicPlayer._active])
	_check(MusicPlayer.current_track() == "boss_act_4", "a boss theme loops rather than advancing the list")
	MusicPlayer._boss_fell()
	_check(not bool(MusicPlayer.playlist_state()["boss"]), "the boss falling releases the floor")
	_check(bool(MusicPlayer.playlist_state()["in_playlist"]), "and the songs come back")
	_check(String(MusicPlayer.current_track()).begins_with("act_4_song_"),
		"resumed the act's list, not '%s' (was '%s')" % [MusicPlayer.current_track(), song])
	_check(MusicPlayer.is_crossfading(), "the hand-back is a crossfade, not a cut")


func _test_the_crossfade_is_a_crossfade() -> void:
	MusicPlayer.stop_immediately()
	MusicPlayer.play("menu")
	MusicPlayer.play("town")
	var playing: int = 0
	for player: AudioStreamPlayer in MusicPlayer._players:
		if player.playing:
			playing += 1
	_check(playing == 2, "a crossfade has both players running for a moment; %d were" % playing)
	_check(MusicPlayer.is_crossfading(), "and reports itself as one")


func _test_the_cues_are_registered() -> void:
	for id: String in ["sfx_boss_stinger", "sfx_boss_fall"]:
		_check(Sfx.SOUNDS.has(id), "the boss cue %s is not registered" % id)
		_check(ResourceLoader.exists(String(Sfx.SOUNDS.get(id, ""))),
			"the boss cue %s has no file at %s" % [id, str(Sfx.SOUNDS.get(id, ""))])
	_check(Balance.MUSIC_PLAYLIST_SLOTS >= 12, "the owner asked for twelve songs an act")
	_check(Balance.MUSIC_BOSS_FADE > MusicPlayer.FADE_TIME, "a boss arrives slower than a scope change")


func _check(passed: bool, message: String) -> void:
	_checked += 1
	if passed:
		return
	_failures += 1
	print("[music] %s" % message)
