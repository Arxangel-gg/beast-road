extends Node

## Sound effects: the mixer, and the reason nothing sounds like a machine gun.
##
## Three problems this solves that a bare `AudioStreamPlayer.play()` does not:
##
## 1. **Identical repetition.** A footstep or a sword swing fired forty times a
##    minute at exactly the same pitch stops sounding like a sword and starts
##    sounding like a sample. Every play gets a random pitch inside a per-sound
##    range, and sounds that have variant files pick one at random on top of
##    that. Distinctive one-offs - the war horn, a boss waking up - get almost no
##    variance, because those are supposed to sound the same every time.
##
## 2. **Stacking.** Twelve enemies dying in one frame means twelve death sounds
##    summed on top of each other, which is both deafening and mush. Each sound
##    has a polyphony cap and a retrigger cooldown.
##
## 3. **Mix balance.** Levels were normalised per category at import, but a war
##    horn still needs to be louder than a UI hover. The per-sound trim below is
##    the mixing desk.
##
## Like Vfx, this listens on EventBus rather than being called by gameplay code.

## Voices in the pool. Above this, the oldest finished voice is reused.
const VOICES: int = 24

## Explicit paths, not a directory scan.
##
## This was `DirAccess.open("res://audio/sfx/")` and it is the bug that made
## every sound effect silent in the exported game while working perfectly from
## source. Godot strips the source asset out of the .pck when it imports it and
## leaves a remap behind, so a runtime directory listing of res:// finds nothing
## in an export. Music and ambience were unaffected because they always used
## explicit paths - which is exactly why the soundtrack worked and nothing else
## did.
##
## Regenerate with: python tools/gen_sfx_table.py
const SOUNDS: Dictionary = {
	"sfx_air_shot": "res://audio/sfx/sfx_air_shot.ogg",
	"sfx_boss_spawn": "res://audio/sfx/sfx_boss_spawn.ogg",
	"sfx_construction_done": "res://audio/sfx/sfx_construction_done.ogg",
	"sfx_dash": "res://audio/sfx/sfx_dash.ogg",
	"sfx_earth_shot": "res://audio/sfx/sfx_earth_shot.ogg",
	"sfx_enemy_die": "res://audio/sfx/sfx_enemy_die.ogg",
	"sfx_fire_shot": "res://audio/sfx/sfx_fire_shot.ogg",
	"sfx_footstep_dirt": "res://audio/sfx/sfx_footstep_dirt.ogg",
	"sfx_footstep_heavy": "res://audio/sfx/sfx_footstep_heavy.ogg",
	"sfx_hero_death": "res://audio/sfx/sfx_hero_death.ogg",
	"sfx_hero_hurt": "res://audio/sfx/sfx_hero_hurt.ogg",
	"sfx_hero_swing_1": "res://audio/sfx/sfx_hero_swing_1.ogg",
	"sfx_hero_swing_2": "res://audio/sfx/sfx_hero_swing_2.ogg",
	"sfx_hero_swing_heavy": "res://audio/sfx/sfx_hero_swing_heavy.ogg",
	"sfx_hit_armour": "res://audio/sfx/sfx_hit_armour.ogg",
	"sfx_hit_flesh": "res://audio/sfx/sfx_hit_flesh.ogg",
	"sfx_hit_stone": "res://audio/sfx/sfx_hit_stone.ogg",
	"sfx_raid_ready": "res://audio/sfx/sfx_raid_ready.ogg",
	"sfx_relic_socket": "res://audio/sfx/sfx_relic_socket.ogg",
	"sfx_spell_blink": "res://audio/sfx/sfx_spell_blink.ogg",
	"sfx_spell_cast": "res://audio/sfx/sfx_spell_cast.ogg",
	"sfx_spell_nova": "res://audio/sfx/sfx_spell_nova.ogg",
	"sfx_tower_build": "res://audio/sfx/sfx_tower_build.ogg",
	"sfx_tower_sell": "res://audio/sfx/sfx_tower_sell.ogg",
	"sfx_tower_upgrade": "res://audio/sfx/sfx_tower_upgrade.ogg",
	"sfx_town_damaged": "res://audio/sfx/sfx_town_damaged.ogg",
	"sfx_ui_click": "res://audio/sfx/sfx_ui_click.ogg",
	"sfx_ui_confirm": "res://audio/sfx/sfx_ui_confirm.ogg",
	"sfx_ui_deny": "res://audio/sfx/sfx_ui_deny.ogg",
	"sfx_ui_hover": "res://audio/sfx/sfx_ui_hover.ogg",
	"sfx_war_horn": "res://audio/sfx/sfx_war_horn.ogg",
	"sfx_water_shot": "res://audio/sfx/sfx_water_shot.ogg",
	"sfx_wave_incoming": "res://audio/sfx/sfx_wave_incoming.ogg",
}

## Per-sound mix. `db` trims level, `pitch` is the +/- fraction of pitch drift,
## `limit` caps how many can sound at once, `gap` is the minimum seconds between
## two triggers of the same sound.
##
## This is a mixing desk, not tuning: it lives here rather than in Balance
## because every value is about how one specific recording sits against the
## others, and none of it is a design decision.
const MIX: Dictionary = {
	# --- constant, high-frequency: widest variation ---
	"sfx_footstep_dirt":     {"db": -21.0, "pitch": 0.18, "limit": 4, "gap": 0.04},
	"sfx_footstep_heavy":    {"db": -13.0, "pitch": 0.14, "limit": 3, "gap": 0.06},
	"sfx_hero_swing_1":      {"db": -2.0,  "pitch": 0.14, "limit": 3, "gap": 0.03},
	"sfx_hero_swing_2":      {"db": -2.0,  "pitch": 0.14, "limit": 3, "gap": 0.03},
	"sfx_hero_swing_heavy":  {"db": 0.0,  "pitch": 0.09, "limit": 2, "gap": 0.05},

	# --- impacts: frequent, and the ones that most reveal a repeated sample ---
	"sfx_hit_flesh":         {"db": -3.0,  "pitch": 0.16, "limit": 5, "gap": 0.03},
	"sfx_hit_armour":        {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_hit_stone":         {"db": -4.0, "pitch": 0.16, "limit": 4, "gap": 0.03},
	"sfx_enemy_die":         {"db": -4.0, "pitch": 0.15, "limit": 5, "gap": 0.05},

	# --- tower fire: the most repeated sound in the game by a wide margin ---
	"sfx_fire_shot":         {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_water_shot":        {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_earth_shot":        {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},
	"sfx_air_shot":          {"db": -9.0, "pitch": 0.17, "limit": 4, "gap": 0.05},

	# --- hero ---
	"sfx_hero_hurt":         {"db": -1.0,  "pitch": 0.10, "limit": 2, "gap": 0.15},
	"sfx_hero_death":        {"db": 0.0,  "pitch": 0.05, "limit": 1, "gap": 0.5},
	"sfx_dash":             {"db": -3.0,  "pitch": 0.12, "limit": 2, "gap": 0.05},

	# --- spells ---
	"sfx_spell_cast":        {"db": -2.0,  "pitch": 0.10, "limit": 3, "gap": 0.05},
	"sfx_spell_nova":        {"db": 0.0,  "pitch": 0.08, "limit": 2, "gap": 0.08},
	"sfx_spell_blink":       {"db": -2.0,  "pitch": 0.12, "limit": 2, "gap": 0.05},

	# --- construction and UI: deliberately quiet, they are confirmations ---
	"sfx_tower_build":       {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_upgrade":     {"db": -1.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_tower_sell":        {"db": -3.0,  "pitch": 0.06, "limit": 2, "gap": 0.1},
	"sfx_construction_done": {"db": 0.0,  "pitch": 0.04, "limit": 1, "gap": 0.2},
	"sfx_relic_socket":      {"db": 0.0,  "pitch": 0.04, "limit": 1, "gap": 0.1},
	"sfx_ui_click":          {"db": -7.0, "pitch": 0.07, "limit": 2, "gap": 0.03},
	"sfx_ui_hover":          {"db": -17.0, "pitch": 0.10, "limit": 2, "gap": 0.05},
	"sfx_ui_confirm":        {"db": -4.0, "pitch": 0.05, "limit": 1, "gap": 0.05},
	"sfx_ui_deny":           {"db": -4.0, "pitch": 0.05, "limit": 1, "gap": 0.08},

	# --- events: these are landmarks, so they barely vary and they cut through ---
	"sfx_war_horn":          {"db": 6.0,   "pitch": 0.02, "limit": 1, "gap": 1.0},
	"sfx_boss_spawn":        {"db": 6.0,   "pitch": 0.02, "limit": 1, "gap": 1.0},
	"sfx_raid_ready":        {"db": 3.0,  "pitch": 0.02, "limit": 1, "gap": 0.5},
	"sfx_wave_incoming":     {"db": -1.0,  "pitch": 0.03, "limit": 1, "gap": 0.5},
	"sfx_town_damaged":      {"db": 2.0,  "pitch": 0.12, "limit": 2, "gap": 0.1},
}

## Defaults for any sound not listed above.
const DEFAULT_MIX: Dictionary = {"db": -3.0, "pitch": 0.10, "limit": 3, "gap": 0.04}

## Sounds that come in variants. Asking for the group picks one at random, which
## is a stronger cure for repetition than pitch alone.
const GROUPS: Dictionary = {
	"swing_light": ["sfx_hero_swing_1", "sfx_hero_swing_2"],
	"impact": ["sfx_hit_flesh", "sfx_hit_armour", "sfx_hit_stone"],
}

## Element -> tower fire sound.
const ELEMENT_SHOTS: Array[String] = [
	"sfx_fire_shot", "sfx_water_shot", "sfx_earth_shot", "sfx_air_shot",
]

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []

## id -> how many are sounding, and id -> when it may next trigger.
var _active: Dictionary = {}
var _next_allowed: Dictionary = {}

## The last variant chosen per group, so a group of two never repeats itself
## twice in a row - which is the case pure randomness gets audibly wrong.
var _last_variant: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	AudioBuses.ensure()
	_load_streams()
	_build_voices()

	EventBus.hero_swing_started.connect(_on_swing_started)
	EventBus.hero_attack_landed.connect(_on_attack_landed)
	EventBus.footfall.connect(_on_footfall)
	EventBus.hero_damaged.connect(_on_hero_damaged)
	EventBus.hero_died.connect(func(_at: Vector2) -> void: play("sfx_hero_death"))
	EventBus.hero_dashed.connect(func(_i: float) -> void: play("sfx_dash"))
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.tower_fired.connect(_on_tower_fired)
	EventBus.tower_slot_changed.connect(_on_slot_changed)
	EventBus.town_damaged.connect(func(_a: float, _c: float, _m: float) -> void: play("sfx_town_damaged"))
	EventBus.spell_cast.connect(_on_spell_cast)
	EventBus.war_horn_activated.connect(func(_d: float) -> void: play("sfx_war_horn"))
	EventBus.raid_available.connect(func(_s: float) -> void: play("sfx_raid_ready"))
	EventBus.boss_spawned.connect(func(_id: String, _a: int) -> void: play("sfx_boss_spawn"))
	EventBus.wave_started.connect(func(_n: int, _l: Array) -> void: play("sfx_wave_incoming"))
	EventBus.construction_completed.connect(func(_id: String, _t: int) -> void: play("sfx_construction_done"))
	EventBus.relic_socketed.connect(func(_id: String) -> void: play("sfx_relic_socket"))

	# Buttons are created in code all over the HUD and the panels, so wiring them
	# individually would mean remembering to do it in every new screen. One hook
	# on node_added covers every button in the game, including future ones.
	get_tree().node_added.connect(_on_node_added)
	_wire_existing_buttons(get_tree().root)

	apply_volume()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	if not button.pressed.is_connected(_on_button_pressed):
		button.pressed.connect(_on_button_pressed.bind(button))
	if not button.mouse_entered.is_connected(_on_button_hover):
		button.mouse_entered.connect(_on_button_hover)


func _wire_existing_buttons(node: Node) -> void:
	_on_node_added(node)
	for child: Node in node.get_children():
		_wire_existing_buttons(child)


## A disabled button that still clicks is a lie, so a refused press gets the
## deny sound instead.
func _on_button_pressed(button: BaseButton) -> void:
	if button.disabled:
		play("sfx_ui_deny")
	else:
		play("sfx_ui_click")


func _on_button_hover() -> void:
	play("sfx_ui_hover")


## Live counters, for diagnosing "why is nothing playing".
var _attempts: int = 0
var _starts: int = 0
var _blocked_gap: int = 0
var _blocked_limit: int = 0
var _blocked_voices: int = 0
var _blocked_missing: int = 0


func debug_state() -> Dictionary:
	var busy: int = 0
	for v: AudioStreamPlayer in _voices:
		if v.playing:
			busy += 1
	return {
		"streams": _streams.size(),
		"attempts": _attempts, "starts": _starts,
		"blocked_gap": _blocked_gap, "blocked_limit": _blocked_limit,
		"blocked_voices": _blocked_voices, "blocked_missing": _blocked_missing,
		"voices_busy": busy, "active": _active.duplicate(),
	}


func _load_streams() -> void:
	for id: Variant in SOUNDS:
		var path: String = String(SOUNDS[id])
		if not ResourceLoader.exists(path):
			push_warning("Sfx: missing %s" % path)
			continue
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			continue
		# One-shots must never loop; a looping hit sound never stops.
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = false
		_streams[String(id)] = stream

	# Loud failure. Silent audio that reports success is what let a broken
	# export ship three times.
	if _streams.is_empty():
		push_error("Sfx: no sound effects loaded. Every sound will be silent.")
	elif _streams.size() < SOUNDS.size():
		push_warning("Sfx: loaded %d of %d sounds." % [_streams.size(), SOUNDS.size()])


func _build_voices() -> void:
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = AudioBuses.SFX
		add_child(player)
		_voices.append(player)


## Reads the settings faders. Called by the options screen.
func apply_volume() -> void:
	AudioBuses.apply_volumes()


## Test and shutdown path: release any decoder still owned by a pooled voice.
## Finished voices intentionally retain their stream during play so they can be
## reused cheaply; a soak exits too quickly for the audio server to do this.
func stop_immediately() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null
	_active.clear()


## Plays a sound by id. Silently does nothing if the file is missing, so an
## un-generated sound is an absence rather than a crash.
func play(id: String, extra_db: float = 0.0) -> void:
	_attempts += 1
	var stream: AudioStream = _streams.get(id, null) as AudioStream
	if stream == null:
		_blocked_missing += 1
		return

	var mix: Dictionary = MIX.get(id, DEFAULT_MIX)
	var now: float = float(Time.get_ticks_msec()) / 1000.0

	if now < float(_next_allowed.get(id, 0.0)):
		_blocked_gap += 1
		return
	if int(_active.get(id, 0)) >= int(mix.get("limit", 3)):
		_blocked_limit += 1
		return

	var voice: AudioStreamPlayer = _free_voice()
	if voice == null:
		_blocked_voices += 1
		return
	_starts += 1

	var drift: float = float(mix.get("pitch", 0.1))
	voice.stream = stream
	# Pitch drift is symmetric in ratio, not in cents, which is close enough at
	# these small ranges and much easier to reason about.
	voice.pitch_scale = 1.0 + randf_range(-drift, drift)
	voice.volume_db = float(mix.get("db", -8.0)) + extra_db
	voice.play()

	_next_allowed[id] = now + float(mix.get("gap", 0.04))
	_active[id] = int(_active.get(id, 0)) + 1
	# Decrementing on `finished` keeps the count honest without polling.
	var release: Callable = func() -> void:
		_active[id] = maxi(int(_active.get(id, 0)) - 1, 0)
	voice.finished.connect(release, CONNECT_ONE_SHOT)


## Plays one of a group's variants, never the same one twice running.
func play_group(group: String, extra_db: float = 0.0) -> void:
	var options: Array = GROUPS.get(group, []) as Array
	if options.is_empty():
		return
	var choice: String = String(options[randi() % options.size()])
	if options.size() > 1 and choice == String(_last_variant.get(group, "")):
		# One re-roll is enough: it removes the obvious back-to-back repeat
		# without making the sequence feel artificially alternating.
		choice = String(options[randi() % options.size()])
	_last_variant[group] = choice
	play(choice, extra_db)


func _free_voice() -> AudioStreamPlayer:
	for voice: AudioStreamPlayer in _voices:
		if not voice.playing:
			return voice
	return null


# ==============================================================================
# EventBus reactions
# ==============================================================================

## Every swing, hit or miss. This is the sound the player is owed for pressing
## the button.
func _on_swing_started(chain_step: int, _at: Vector2) -> void:
	if chain_step >= Balance.HERO_CHAIN_LENGTH - 1:
		play("sfx_hero_swing_heavy")
	else:
		play_group("swing_light")


## Only the impact here - the whoosh already played when the swing started.
## One impact per swing however many it caught, with a small boost for a wide
## hit: six overlapping impacts is noise, not weight.
func _on_attack_landed(_chain_step: int, targets: int, _at: Vector2) -> void:
	play_group("impact", minf(float(targets - 1) * 1.2, 4.0))


## Footsteps are throttled hard. Forty walking enemies would otherwise be a
## continuous gravel roar, so only the hero and genuinely heavy things are heard.
func _on_footfall(_at: Vector2, mass: float) -> void:
	if mass >= Balance.ANIM_SHAKE_MASS_THRESHOLD:
		play("sfx_footstep_heavy")
	elif mass <= Balance.ANIM_MASS_HERO:
		play("sfx_footstep_dirt")


func _on_hero_damaged(_amount: float, _from: Vector2) -> void:
	play("sfx_hero_hurt")


func _on_enemy_died(_enemy_id: String, _at: Vector2) -> void:
	play("sfx_enemy_die")


func _on_tower_fired(lane: int, slot: int, _at: Vector2) -> void:
	var tower: TowerData = RunState.tower_in_slot(lane, slot)
	if tower == null:
		return
	var index: int = clampi(int(tower.element), 0, ELEMENT_SHOTS.size() - 1)
	play(ELEMENT_SHOTS[index])


func _on_slot_changed(lane: int, slot: int) -> void:
	# Built or upgraded versus sold, told apart by whether anything is there now.
	if RunState.slot_is_empty(lane, slot):
		play("sfx_tower_sell")
	elif RunState.level_in_slot(lane, slot) > 1:
		play("sfx_tower_upgrade")
	else:
		play("sfx_tower_build")


func _on_spell_cast(spell_id: String, _slot: int, _at: Vector2) -> void:
	match spell_id:
		"rift_step":
			play("sfx_spell_blink")
		"cinder_nova", "tremor":
			play("sfx_spell_nova")
		_:
			play("sfx_spell_cast")
