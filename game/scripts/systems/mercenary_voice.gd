class_name MercenaryVoice
extends Node

## **The company talks** (owner, 2026-10-07; stage four of
## `docs/MERCENARIES_2026-10-07.md`). Listens to what the road already
## announces - a wave, a boss, a Herald, a frenzy, the wall struck, a dragon,
## the earth stirring, the night - and has the mercenary who would notice it
## say so, and now and then something of its own.
##
## **Restrained**, the list's own word for an announcer: each mercenary waits
## `MERC_BARK_GAP` between lines and the company waits `MERC_COMPANY_GAP`, and an
## alert outranks both, because a warning held back for politeness is not a
## warning. A line shows over the speaker's head and in the party's feed.
##
## Every line is data (`data/merc_lines`); this node only decides who speaks.

var company: MercenaryCompany = null
var _since: Dictionary = {}
var _company_quiet: float = 999.0
var _idle_left: float = 0.0
var _hurt: Dictionary = {}
var _down: Dictionary = {}
var _dice := RandomNumberGenerator.new()


func _ready() -> void:
	name = "MercenaryVoice"
	_dice.seed = absi(hash("mercenary-voice:%d" % RunState.run_seed))
	_idle_left = _dice.randf_range(Balance.MERC_IDLE_SECONDS.x, Balance.MERC_IDLE_SECONDS.y)
	# Named methods, never lambdas: a lambda on an autoload's signal outlives
	# this node when the road is torn down, and errors on every later emit.
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.wave_cleared.connect(_on_wave_cleared)
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.herald_rose.connect(_on_herald_rose)
	EventBus.wildlife_blighted.connect(_on_blighted)
	EventBus.town_struck.connect(_on_town_struck)
	EventBus.dragon_overhead.connect(_on_dragon)
	EventBus.wrath_warned.connect(_on_wrath_warned)
	EventBus.hero_died.connect(_on_warden_died)
	EventBus.mercenary_fell.connect(_on_fell)
	EventBus.weather_changed.connect(_on_weather)
	EventBus.crossroad_reached.connect(_on_crossroad)
	EventBus.camp_cleared.connect(_on_camp_cleared)
	DayNight.night_changed.connect(_on_night_changed)


func _on_wave_started(_wave: int, _lanes: Array) -> void:
	_anyone("wave_start")


func _on_wave_cleared(_wave: int) -> void:
	_anyone("wave_held")


func _on_boss_spawned(_id: String, _act: int) -> void:
	_anyone("boss_coming")


func _on_boss_defeated(_id: String, _act: int) -> void:
	_anyone("boss_fell")


func _on_herald_rose(at: Vector2) -> void:
	_nearest("herald", at)


func _on_blighted(_kind: String, at: Vector2) -> void:
	_nearest("blighted", at, true)


func _on_town_struck(_from: Vector2) -> void:
	_anyone("wall_struck")


func _on_dragon(_seconds: float) -> void:
	_anyone("dragon")


func _on_wrath_warned(_kind: String, at: Vector2, _seconds: float) -> void:
	_nearest("earth_warning", at)


func _on_warden_died(at: Vector2) -> void:
	_nearest("warden_down", at)


func _on_weather(_id: String) -> void:
	_anyone("weather")


func _on_crossroad(_segment: int) -> void:
	_anyone("crossroad")


func _on_camp_cleared(_lane: int, _tier: int) -> void:
	_anyone("camp_cleared")


func _on_night_changed(night: bool) -> void:
	_anyone("night" if night else "day")


## What one moment says in one mouth: a line of its file, the names filled in.
## Static, so the Inn and a gate can ask without a road.
static func line_for(moment: String, speaker: String, dice: RandomNumberGenerator) -> String:
	var data: MercLineData = ContentDB.merc_line(moment)
	if data == null or data.lines.is_empty():
		return ""
	var line: String = data.lines[dice.randi_range(0, data.lines.size() - 1)]
	var warden: String = MetaState.player_name if not MetaState.player_name.is_empty() else "Warden"
	return line.replace("{warden}", warden).replace("{name}", speaker)


## Has `uid` say `moment`, if the moment is spoken and the speaker may speak.
## Returns what was said, or "".
func say(uid: String, moment: String, force: bool = false) -> String:
	var data: MercLineData = ContentDB.merc_line(moment)
	var body: Hero = company.body(uid) if company != null else null
	if data == null or body == null or not body.is_alive():
		return ""
	if not force and not data.alert:
		if _company_quiet < Balance.MERC_COMPANY_GAP or float(_since.get(uid, 999.0)) < Balance.MERC_BARK_GAP:
			return ""
	if not force and _dice.randf() > data.chance:
		return ""
	var speaker: String = String(RunState.company_row(uid).get("name", ""))
	var text: String = line_for(moment, speaker, _dice)
	if text.is_empty():
		return ""
	_since[uid] = 0.0
	_company_quiet = 0.0
	SpeechBubble.say(body, text, data.alert)
	EventBus.mercenary_said.emit(uid, speaker, text, data.alert)
	return text


func _process(delta: float) -> void:
	_company_quiet += delta
	for uid: Variant in _since:
		_since[uid] = float(_since[uid]) + delta
	if company == null:
		return
	# A mercenary notices its own state: hurt, and up again.
	for body: Hero in company.bodies():
		var uid: String = body.mercenary_uid
		var alive: bool = body.is_alive()
		if bool(_down.get(uid, false)) and alive:
			_down[uid] = false
			say(uid, "got_up", true)
		var share: float = body.health.current_hp / maxf(body.health.max_hp, 1.0) if body.health != null else 1.0
		if alive and share <= Balance.MERC_RETREAT_SHARE and not bool(_hurt.get(uid, false)):
			_hurt[uid] = true
			say(uid, "hurt")
		elif share >= Balance.MERC_RECOVER_SHARE:
			_hurt[uid] = false
	# And now and then, something of its own.
	_idle_left -= delta
	if _idle_left <= 0.0:
		_idle_left = _dice.randf_range(Balance.MERC_IDLE_SECONDS.x, Balance.MERC_IDLE_SECONDS.y)
		_anyone("idle")


func _on_fell(uid: String, _at: Vector2, _left: int) -> void:
	_down[uid] = true
	for body: Hero in company.bodies() if company != null else []:
		if body.mercenary_uid != uid and body.is_alive():
			say(body.mercenary_uid, "partner_down")
			return


## A mercenary on its feet, at random, says it.
func _anyone(moment: String) -> void:
	if company == null:
		return
	var standing: Array[Hero] = []
	for body: Hero in company.bodies():
		if body.is_alive():
			standing.append(body)
	if standing.is_empty():
		return
	say(standing[_dice.randi_range(0, standing.size() - 1)].mercenary_uid, moment)


## The mercenary nearest `at` says it - the one who would have seen it - and
## with `in_sight` only one close enough to have.
func _nearest(moment: String, at: Vector2, in_sight: bool = false) -> void:
	if company == null:
		return
	var best: Hero = null
	var best_d: float = INF
	for body: Hero in company.bodies():
		if not body.is_alive():
			continue
		var d: float = body.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = body
	if best == null or (in_sight and best_d > Balance.MERC_NOTICE_RADIUS):
		return
	say(best.mercenary_uid, moment)
