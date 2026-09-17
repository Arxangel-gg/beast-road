class_name HoldYard
extends Node2D

## **The Hold, as a place you walk in rather than a column of buttons.**
##
## Owner ruling, 2026-09-17: *"The whole hold ideally should be an actual map
## that players can jump into and it should have a central square area that has
## the forge managed by a blacksmith npc ... also in the square should be the
## vendor's shop ... other useful things like pens ... the stash ... something
## to use as the global leaderboard ... chronicles ... the codex, which should
## also not be too far from the pens ... a way to interact with something to
## rename themselves ... and their professions."*
##
## `IDEAS_REVIEW` §4 refused a hub as "the grammar of a map you hold, and this
## map walks", and that reading still stands for the *world* - the town rides
## the beast and nothing standing still may compete with it. **A yard between
## runs is not a place on the road**, so the refusal does not reach it, and the
## doors are the doors that already existed.
##
## **Every station is a button that already worked.** `HubScreen.adopt` keeps
## each door's own handler; this stands a building where that door is and
## presses the same button when the Warden walks up to it. So nothing that
## opened before opens differently now, and a door added to the menu tomorrow
## gets a building tomorrow without anybody editing a second list.
##
## **It is one screen wide and never scrolls.** The whole yard is visible at
## once, which is what a lobby is for - a hub you have to explore to find the
## stash in is a worse menu, not a better place. The camera is therefore a
## scale rather than a camera, and every phone shape gets the same yard.
##
## **Nothing here is authority.** The yard draws seats; it does not own them.
## Who is standing in one, what they are called and where they are is
## `HoldSession`'s, which is the host's. A simulated Warden holds no state at
## all - it is a figure with a name, and the moment a real player takes its
## seat the figure becomes them.

## The yard in its own units. A shape rather than a resolution: it is fitted to
## whatever screen it is drawn on, so this decides the *proportions* of the
## place and nothing about how big anybody's Hold is.
const YARD: Vector2 = Vector2(2200.0, 1040.0)

## Where the road out is, and where the Warden stands when the Hold opens.
const ENTRY: Vector2 = Vector2(0.0, 400.0)

## The ground the Hold stands on. The lore's Hold is a valley with farmland in
## it (see `world_first_cut`), which is the greenest ground the game owns.
const GROUND_ART: String = "res://art/terrain/terrain_jungle.png"
const GRASS_ART: String = "res://art/foliage/grass_jungle.png"

## What stands where, and which door it is.
##
## `door` is the name of the button `HubScreen.adopt` was handed, so this table
## and the menu's own door list cannot drift apart: a station naming a door that
## was never adopted simply stands there with nothing to press, and a station
## with **no** door at all is one the screen answers itself - the Warden's stone
## is the card, which is where the rename and the professions live.
##
## Laid out as a place rather than as a grid. The square is in the middle with
## the forge on one side and the market on the other; the stash and the hall are
## up against the unfinished wall at the back; the watchtower holds the west
## corner; the pens run east down their own path with the codex beside them, per
## the owner's own "not too far from the pens"; and the road out is the gap in
## the south where the Warden came in.
const STATIONS: Array[Dictionary] = [
	{"id": "smithy", "door": "Smithy", "art": "res://art/city/building_forge.png",
		"label": "The Furnace", "at": Vector2(-330.0, -150.0)},
	{"id": "anvil", "door": "Smithy", "art": "res://art/battlefield/smithy.png",
		"label": "The Anvil", "at": Vector2(-150.0, 30.0)},
	{"id": "vendor", "door": "Vendor", "art": "res://art/city/building_market.png",
		"label": "The Market", "at": Vector2(300.0, -150.0)},
	{"id": "ledger", "door": "Ledger", "art": "res://art/battlefield/camp_rack.png",
		"label": "The Long Ledger", "at": Vector2(470.0, 30.0)},
	{"id": "stash", "door": "Stash", "art": "res://art/city/building_treasury.png",
		"label": "The Stash", "at": Vector2(-760.0, -250.0)},
	{"id": "chronicle", "door": "Chronicle", "art": "res://art/city/building_town_hall.png",
		"label": "The Chronicle", "at": Vector2(-30.0, -330.0)},
	{"id": "leaderboard", "door": "Leaderboard", "art": "res://art/city/building_watchtower.png",
		"label": "The Board", "at": Vector2(-980.0, 60.0)},
	{"id": "codex", "door": "Codex", "art": "res://art/city/building_sanctum.png",
		"label": "The Codex", "at": Vector2(760.0, -260.0)},
	{"id": "pen", "door": "Pen", "art": "res://art/city/building_granary.png",
		"label": "The Pens", "at": Vector2(560.0, -300.0)},
	{"id": "card", "door": "", "art": "res://art/battlefield/war_totem.png",
		"label": "The Warden's Stone", "at": Vector2(60.0, 120.0)},
	{"id": "road", "door": "", "art": "res://art/city/plot_locked.png",
		"label": "The Road Out", "at": Vector2(-180.0, 430.0)},
	{"id": "stable", "door": "Stable", "art": "res://art/city/building_granary_tier_02.png",
		"label": "The Stable", "at": Vector2(-700.0, 90.0)},
	{"id": "coop", "door": "Coop", "art": "res://art/city/plot_empty.png",
		"label": "The Gate", "at": Vector2(-420.0, 330.0)},
]

## The people who live here rather than pass through.
##
## **They are their station's face.** A market with a stall and nobody behind it
## is scenery; the same stall with somebody standing at it is somewhere to go.
## Pressing Interact on the person opens the same door the building does, which
## is why they carry a `door` and not a conversation.
##
## `yields_to` is the blacksmith's rule and the owner's own words: *"if the
## player wants to use it the blacksmith will back away from interacting with
## those and keep sharpening a sword or an axe and pacing around randomly
## procedurally until he is free to use the anvil and furnace again."*
const RESIDENTS: Array[Dictionary] = [
	{"id": "smith", "door": "Smithy", "art": "res://art/city/merchant_relic_peddler.png",
		"name": "Orden", "label": "Orden, who keeps the fire in",
		"at": Vector2(-250.0, -20.0), "beat": 70.0,
		"yields_to": ["smithy", "anvil"], "aside": Vector2(-560.0, 60.0)},
	{"id": "keeper", "door": "Vendor", "art": "res://art/city/merchant_quartermaster.png",
		"name": "Tessel", "label": "Tessel, who keeps the market",
		"at": Vector2(330.0, -30.0), "beat": 84.0,
		"yields_to": [], "aside": Vector2.ZERO},
	{"id": "steward", "door": "Pen", "art": "res://art/city/merchant_alchemist.png",
		"name": "Wren", "label": "Wren, who minds the pens",
		"at": Vector2(660.0, -140.0), "beat": 96.0,
		"yields_to": [], "aside": Vector2.ZERO},
	{"id": "stabler", "door": "Stable", "art": "res://art/city/merchant_stabler.png",
		"name": "Halric", "label": "Halric, who keeps the horses",
		"at": Vector2(-640.0, 170.0), "beat": 78.0,
		"yields_to": [], "aside": Vector2.ZERO},
]

## Names for the Wardens whose seats nobody has taken.
##
## They are **not** other accounts and nothing about them is read: a simulated
## Warden is a figure with a name walking between the same buildings the player
## walks between, and it exists so the Hold is somewhere people are rather than
## somewhere people might be. The moment a real player arrives, one of these
## stops being simulated and starts being them.
const SIM_NAMES: Array[String] = [
	"Halvern", "Iska", "Rue", "Corwin", "Nessa", "Thane", "Adair", "Briar",
	"Marrow", "Fen", "Oyelle", "Sabra",
]

## The pens, down their own path: one per seat, gated, side by side, east of the
## square. Laid from a rule rather than a table so a Hold that ever seats more
## players simply gets more pens.
## Where the horses stand: west of the square, in front of the stable and
## clear of the gate at (-420, 330) and the road out at (-180, 430). The
## paddock is `Balance.STABLE_PADDOCK` across, so it reaches x = -960 at the
## far rail, which leaves the watchtower its corner.
## The fire in the middle of the square, and the torches down the paths.
##
## **Placed against what is already here rather than scattered.** The fire is
## in the open middle where nothing else stands; the torches are at the mouth
## of each path and beside the two doors furthest from the centre, which is
## where a person actually needs to see. A ring of torches at even spacing
## reads as a decoration; lighting the places people walk reads as a camp.
const FIRE_AT: Vector2 = Vector2(0.0, 40.0)
const TORCHES: Array[Vector2] = [
	Vector2(-330.0, 210.0), Vector2(330.0, 210.0),
	Vector2(-680.0, 60.0), Vector2(700.0, 40.0),
	Vector2(-120.0, -250.0), Vector2(160.0, -250.0),
]

const PADDOCK_AT: Vector2 = Vector2(-700.0, 330.0)

const PEN_FIRST: Vector2 = Vector2(180.0, 330.0)
const PEN_SIZE: Vector2 = Vector2(250.0, 180.0)
const PEN_GAP: float = 36.0

signal entered(station_id: String)
## The Warden walked somewhere. The session relays this; the yard does not.
signal walked(at: Vector2, facing: Vector2)

var _ground: Texture2D = null
var _grass: Texture2D = null
var _actors: Node2D = null
var _stations: Array[Dictionary] = []
var _residents: Array[Dictionary] = []
var _seats: Array[Dictionary] = []
var _pens: Array[Dictionary] = []
## The horses, in their field west of the square (owner brief, 2026-09-17:
## *"the most aesthetic solution in The Hold for it like a stable or
## something and animated horses with AI and a vendor at it"*). A picture of
## the stock, read by nothing - see `StablePaddock`.
var _paddock: StablePaddock = null
var _grass_at: Array[Vector2] = []
## The animal the Warden has taken out of the pen, walking with them.
##
## Owner brief, 2026-09-17: *"Players can still choose a companion to take
## with them on an expedition and when they do that companion starts
## following them from the pen and will go with the player as they move
## around the hold, including onto their next run."* It is a picture of
## `MetaState.pen_taken` and reads nothing: the pen decides who is out, and
## this draws whoever that is at the Warden's heel.
var _heel: Sprite2D = null
var _heel_at: Vector2 = Vector2.ZERO
var _rng := RandomNumberGenerator.new()
var _focus: String = ""
var _walk_to: Vector2 = Vector2.INF
var _relay_clock: float = 0.0
var _clock: float = 0.0
## Off while a door is open over the Hold, so the Warden does not walk away
## under a screen nobody can see them through.
var _driving: bool = true
## The sky over the Hold, and the fires under it.
var _sky: CanvasModulate = null
var _fires: Array[Node2D] = []
var _lights: Array[PointLight2D] = []
## A dash in progress, and the rest after one.
var _dash_left: float = 0.0
var _dash_way: Vector2 = Vector2.ZERO
var _dash_rest: float = 0.0


func _ready() -> void:
	name = "HoldYard"
	_rng.seed = hash("hold-yard")
	if ResourceLoader.exists(GROUND_ART):
		_ground = load(GROUND_ART) as Texture2D
	if ResourceLoader.exists(GRASS_ART):
		_grass = load(GRASS_ART) as Texture2D
	_actors = Node2D.new()
	_actors.name = "Actors"
	_actors.y_sort_enabled = true
	add_child(_actors)
	_scatter_grass()
	_build_stations()
	_build_residents()
	_build_pens()
	_build_paddock()
	_build_seats()
	_build_heel()
	_build_sky()
	_build_fires()
	set_process(true)


# ---------------------------------------------------------------- the place


func _scatter_grass() -> void:
	# Clear of the path, so the yard reads as kept rather than abandoned. Its
	# own dice, on the yard's own seed, because a tuft of grass is decoration
	# and decoration never touches a run's stream.
	_grass_at.clear()
	for _index: int in Balance.HOLD_GRASS_TUFTS:
		var at := Vector2(_rng.randf_range(-YARD.x * 0.5, YARD.x * 0.5),
			_rng.randf_range(-YARD.y * 0.5, YARD.y * 0.5))
		if absf(at.y - 120.0) < 80.0 or absf(at.x - ENTRY.x) < 90.0:
			continue
		_grass_at.append(at)


func _build_stations() -> void:
	for entry: Dictionary in STATIONS:
		var sprite: Sprite2D = _stand(String(entry["art"]), entry["at"] as Vector2)
		if sprite == null:
			continue
		var station: Dictionary = entry.duplicate(true)
		station["node"] = sprite
		station["button"] = null
		# **Every building breathes on its own authored frames.** Owner,
		# 2026-09-17: *"anything that would be better animated at the hold
		# should be"*. The city buildings have carried three idle frames each
		# since they were drawn and the Hold was the one place standing them
		# still, so this is art the game already owns being used twice.
		station["base"] = sprite.texture
		station["idle"] = GameData.load_idle_frames(String(entry["art"]))
		# Its own phase, off its own id: a square where five buildings pulse
		# together reads as one animation rather than as a place.
		station["clock"] = float(absi(hash(String(entry["id"]))) % 997) * 0.01
		_stations.append(station)


func _build_residents() -> void:
	for entry: Dictionary in RESIDENTS:
		var sprite: Sprite2D = _stand(String(entry["art"]), entry["at"] as Vector2)
		if sprite == null:
			continue
		var person: Dictionary = entry.duplicate(true)
		person["node"] = sprite
		person["home"] = entry["at"] as Vector2
		person["to"] = entry["at"] as Vector2
		person["clock"] = _rng.randf() * 10.0
		person["left"] = _rng.randf_range(Balance.HOLD_NPC_PAUSE.x, Balance.HOLD_NPC_PAUSE.y)
		person["stood_aside"] = false
		_residents.append(person)


## One sprite standing with its feet on a point, so the yard can sort by Y and
## a Warden may walk behind a building.
func _stand(art: String, at: Vector2) -> Sprite2D:
	if not ResourceLoader.exists(art):
		return null
	var texture: Texture2D = load(art) as Texture2D
	if texture == null:
		return null
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
	sprite.position = at
	_actors.add_child(sprite)
	return sprite


## One pen a seat, side by side down the path, each with its own gate and its
## own plate. A Warden sees their own animals in theirs and everybody else's in
## theirs, and may touch nobody's but their own (owner, 2026-09-17).
func _build_pens() -> void:
	for index: int in Balance.HOLD_SEATS:
		var at: Vector2 = PEN_FIRST + Vector2(
			float(index) * (PEN_SIZE.x + PEN_GAP), 0.0)
		var pen := PenYard.new()
		pen.name = "Pen%d" % index
		pen.position = at
		_actors.add_child(pen)
		pen.set_stage(PEN_SIZE - Vector2(40.0, 52.0))

		var plate := Label.new()
		plate.position = at + Vector2(-PEN_SIZE.x * 0.5, -PEN_SIZE.y * 0.5 - 30.0)
		plate.custom_minimum_size = Vector2(PEN_SIZE.x, 0.0)
		plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		plate.add_theme_font_size_override("font_size", 14)
		plate.add_theme_color_override("font_color", Color("b8ae98"))
		plate.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		plate.add_theme_constant_override("outline_size", 4)
		add_child(plate)
		_pens.append({"at": at, "yard": pen, "plate": plate})


## The paddock, in front of the stable and inside the fence it draws itself.
##
## Below the buildings in the actor layer so a Warden may walk behind the far
## rail, exactly as they may walk behind a pen.
func _build_paddock() -> void:
	_paddock = StablePaddock.new()
	_paddock.position = PADDOCK_AT
	_actors.add_child(_paddock)
	_paddock.set_stage(Balance.STABLE_PADDOCK)


## The paddock, for the screen that re-reads it after a purchase and for the
## gate. Null before `_ready`.
func paddock() -> StablePaddock:
	return _paddock


# ---------------------------------------------------------------- the people


func _build_seats() -> void:
	_seats.clear()
	for index: int in Balance.HOLD_SEATS:
		_seats.append(_stand_warden(index))
	_seats[0]["kind"] = HoldSession.Seat.LOCAL
	_seats[0]["name"] = MetaState.player_name if not MetaState.player_name.is_empty() else "Oathless"
	_seats[0]["at"] = ENTRY
	_place(_seats[0])
	for index: int in range(1, _seats.size()):
		_seats[index]["kind"] = HoldSession.Seat.SIMULATED
		_seats[index]["name"] = SIM_NAMES[
			absi(hash(MetaState.play_code + str(index))) % SIM_NAMES.size()]
		_place(_seats[index])
	_relabel()


## A Warden: the hero's own sheets, a name over their head, and their own clock.
func _stand_warden(index: int) -> Dictionary:
	var root := Node2D.new()
	root.name = "Warden%d" % index
	_actors.add_child(root)

	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.offset = Vector2(0.0, -float(HeroAnimator.CELL_H) * 0.5 + Balance.HOLD_WARDEN_FOOT)
	root.add_child(sprite)

	var animator := HeroAnimator.new()
	animator.sprite = sprite
	root.add_child(animator)
	animator.play("idle")

	var tag := Label.new()
	tag.position = Vector2(-90.0, -float(HeroAnimator.CELL_H) - 6.0)
	tag.custom_minimum_size = Vector2(180.0, 0.0)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override("font_size", 15)
	tag.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	tag.add_theme_constant_override("outline_size", 5)
	root.add_child(tag)

	var own := RandomNumberGenerator.new()
	own.seed = absi(hash("hold-seat:%d" % index))
	var home: Vector2 = _somewhere(own)
	return {
		"kind": HoldSession.Seat.EMPTY,
		"name": "",
		"title": "",
		"node": root,
		"sprite": sprite,
		"animator": animator,
		"tag": tag,
		"at": home,
		"to": home,
		"facing": Vector2.DOWN,
		"rng": own,
		"left": own.randf_range(Balance.HOLD_NPC_PAUSE.x, Balance.HOLD_NPC_PAUSE.y),
	}


## Somewhere a Warden might plausibly be standing: in front of one of the
## buildings rather than anywhere in the rectangle. A figure standing in the
## middle of an empty yard reads as a bug.
func _somewhere(own: RandomNumberGenerator) -> Vector2:
	if STATIONS.is_empty():
		return ENTRY
	var pick: Dictionary = STATIONS[own.randi() % STATIONS.size()]
	return (pick["at"] as Vector2) + Vector2(own.randf_range(-110.0, 110.0),
		own.randf_range(90.0, 170.0))


func _place(seat: Dictionary) -> void:
	var node := seat["node"] as Node2D
	if node != null:
		node.position = seat["at"] as Vector2


func _relabel() -> void:
	for index: int in _seats.size():
		var seat: Dictionary = _seats[index]
		var tag := seat["tag"] as Label
		var node := seat["node"] as Node2D
		if tag == null or node == null:
			continue
		var kind: int = int(seat["kind"])
		node.visible = kind != HoldSession.Seat.EMPTY
		tag.text = String(seat["name"])
		match kind:
			HoldSession.Seat.LOCAL:
				tag.add_theme_color_override("font_color", Color("e8a33d"))
			HoldSession.Seat.REMOTE:
				tag.add_theme_color_override("font_color", Color("9fd2b4"))
			_:
				# A simulated Warden is named in the same grey the interface uses
				# for anything that is not the player's, so nobody is ever fooled
				# into thinking an empty seat is a person.
				tag.add_theme_color_override("font_color", Color("9aa5a2"))
		if index < _pens.size():
			var plate := _pens[index]["plate"] as Label
			if plate != null:
				plate.text = ("%s's pen" % String(seat["name"])
					if kind != HoldSession.Seat.EMPTY else "")


## The animal out of the pen, if there is one. Rebuilt rather than hidden
## when the pen changes, because which creature it is is the whole point.
func _build_heel() -> void:
	if _heel != null and is_instance_valid(_heel):
		_heel.queue_free()
	_heel = null
	var uid: String = MetaState.pen_taken
	if uid.is_empty():
		return
	var species: String = ""
	for kept: Variant in MetaState.pen:
		if kept is Dictionary and String((kept as Dictionary).get("uid", "")) == uid:
			species = String((kept as Dictionary).get("species", ""))
	var kind := ContentDB.wildlife_kinds.get(species, null) as WildlifeData
	if kind == null:
		return
	var art: String = kind.get_sprite_path()
	if not ResourceLoader.exists(art):
		return
	_heel = Sprite2D.new()
	_heel.name = "Companion"
	_heel.texture = load(art) as Texture2D
	_heel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_heel.centered = true
	_heel.offset = Vector2(0.0, -float(_heel.texture.get_height()) * 0.5)
	_heel.scale = Vector2.ONE * clampf(kind.scale * 0.8, 0.6, 2.2)
	# Its own coat, off its own name: the fox at your heel is the fox in the
	# pen, which is what `Phenotype` is for.
	Phenotype.dress(ActorPolish.attach(_heel), kind, absi(hash(uid)))
	_heel_at = warden_at() + Vector2(-70.0, 30.0)
	_heel.position = _heel_at
	_actors.add_child(_heel)


## It follows rather than sticks: a sprite pinned to the Warden's hip reads
## as an attachment, and a few units of lag reads as an animal.
## The Hold's own light, following the sun.
##
## Owner, 2026-09-17: *"There should be a time of day at the hold matched to
## the Host's time of day."*
##
## **Its own `CanvasModulate`, visible only while the Hold is**, which is
## exactly what `RaidArena._tint_node` does and for the reason written there:
## the only other one in the game belongs to the battlefield and is hidden
## with it, so a place without one is played in whatever light the last scope
## happened to leave behind.
##
## **Floored well above the road's night.** The battlefield's dark is a
## difficulty setting; this one is a mood, and a player reading a stash must
## not have to squint at it - which is the interface tint's bound arriving
## through the scenery.
func _build_sky() -> void:
	_sky = CanvasModulate.new()
	_sky.name = "HoldSky"
	add_child(_sky)
	_follow_the_sun()


func _follow_the_sun() -> void:
	if _sky == null or not is_instance_valid(_sky):
		return
	var tint: Color = DayNight.tint
	# Lifted toward white by the floor rather than clamped per channel, so the
	# *hue* of the hour survives - a Hold at dusk is warm and a Hold at midnight
	# is blue, and both are readable.
	_sky.color = tint.lerp(Color.WHITE, Balance.HOLD_NIGHT_FLOOR)


## The fire in the square and the torches down the paths.
##
## **Lit always, seen at night.** A `Flame` costs the same at noon and the
## light does nothing against a bright sky, so nothing here switches: what
## changes is that the `CanvasModulate` above stops washing it out. A fire
## that appeared at dusk would be a fire somebody lit, and nobody did.
func _build_fires() -> void:
	_fires.clear()
	_lights.clear()
	_stand_fire(FIRE_AT, Balance.HOLD_FIRE_REACH, Balance.HOLD_FIRE_ENERGY, 1.35)
	for at: Vector2 in TORCHES:
		_stand_fire(at, Balance.HOLD_TORCH_REACH, Balance.HOLD_TORCH_ENERGY, 0.7)


func _stand_fire(at: Vector2, reach: float, energy: float, size: float) -> void:
	var flame := Flame.new()
	flame.position = at
	flame.scale = Vector2(size, size)
	# Above the ground and below the people, so somebody standing in front of
	# the fire is in front of it.
	flame.z_index = -1
	add_child(flame)
	_fires.append(flame)

	# `LightKit` rather than a hand-rolled `PointLight2D`: it owns the falloff
	# texture, the additive blend that lights a sprite instead of washing it out,
	# and the flicker driver. A second copy of any of those is a torch here that
	# behaves unlike every torch on the road.
	var light: PointLight2D = LightKit.add_light(flame,
		Color(1.0, 0.86, 0.66), reach, energy, 0.18)
	_lights.append(light)


func _tick_heel(delta: float) -> void:
	if _heel == null or not is_instance_valid(_heel):
		return
	var want: Vector2 = warden_at() + Vector2(-70.0, 30.0)
	var step: Vector2 = want - _heel_at
	if step.length() > 26.0:
		_heel_at += step.normalized() * Balance.HOLD_WALK_SPEED * 0.92 * delta
		_heel.flip_h = step.x < 0.0
	_heel.position = _heel_at


# ---------------------------------------------------------------- the seats


## The session's word on who is standing here. The yard never decides this.
func set_seat(index: int, kind: int, who: String, title: String = "") -> void:
	if index < 0 or index >= _seats.size():
		return
	_seats[index]["kind"] = kind
	_seats[index]["name"] = who
	_seats[index]["title"] = title
	if kind == HoldSession.Seat.SIMULATED and who.is_empty():
		_seats[index]["name"] = SIM_NAMES[absi(hash("sim%d" % index)) % SIM_NAMES.size()]
	_relabel()


## What is kept in a seat's pen. This machine's own comes off the save; a
## stranger's is what the host was told, and is drawn and never touched.
func set_pen(index: int, roster: Array) -> void:
	if index < 0 or index >= _pens.size():
		return
	var pen := _pens[index]["yard"] as PenYard
	if pen != null:
		pen.stand_these(roster)


## Where a seat that is not this machine's is standing. Relayed, never rolled.
func move_seat(index: int, at: Vector2, facing: Vector2) -> void:
	if index <= 0 or index >= _seats.size():
		return
	_seats[index]["to"] = at
	_seats[index]["facing"] = facing


func seat_kind(index: int) -> int:
	if index < 0 or index >= _seats.size():
		return HoldSession.Seat.EMPTY
	return int(_seats[index]["kind"])


func seat_name(index: int) -> String:
	if index < 0 or index >= _seats.size():
		return ""
	return String(_seats[index]["name"])


func seats() -> int:
	return _seats.size()


func warden_at() -> Vector2:
	return _seats[0]["at"] as Vector2 if not _seats.is_empty() else ENTRY


# ---------------------------------------------------------------- the doors


## Hands a station the button it presses. Called by `HubScreen` for every door
## it adopted, so a station with no door is a building with nothing inside it
## rather than a crash.
func bind(door: String, button: Button) -> void:
	for index: int in _stations.size():
		if String(_stations[index]["door"]) == door:
			_stations[index]["button"] = button


func bound(door: String) -> bool:
	for station: Dictionary in _stations:
		if String(station["door"]) == door:
			return station["button"] != null
	return false


## What the Warden is standing close enough to use, or "".
func focus() -> String:
	return _focus


func focus_label() -> String:
	for station: Dictionary in _stations:
		if String(station["id"]) == _focus:
			return String(station["label"])
	for person: Dictionary in _residents:
		if String(person["id"]) == _focus:
			return String(person["label"])
	return ""


## Opens whatever the Warden is standing at. Public so the touch prompt and the
## screen's own list can use the same door the keyboard does.
##
## `entered` is emitted either way, because a station with no button is one the
## screen answers itself - the Warden's stone is the card.
func use_focus() -> void:
	if _focus.is_empty():
		return
	var door: String = ""
	for station: Dictionary in _stations:
		if String(station["id"]) == _focus:
			door = String(station["door"])
	for person: Dictionary in _residents:
		if String(person["id"]) == _focus:
			door = String(person["door"])
	entered.emit(_focus)
	if not door.is_empty():
		_press(door)


func _press(door: String) -> void:
	for station: Dictionary in _stations:
		if String(station["door"]) != door:
			continue
		var button := station["button"] as Button
		if button != null and is_instance_valid(button):
			button.pressed.emit()
			return


# ---------------------------------------------------------------- the walking


## Stops the Warden while a door is open over the yard. The figures keep their
## own clocks: a Hold that froze solid behind a screen would come back with
## everybody standing exactly where they were, which reads as a photograph.
func set_driving(on: bool) -> void:
	_driving = on
	if not on:
		_walk_to = Vector2.INF


func _process(delta: float) -> void:
	_clock += delta
	_drive_warden(delta)
	for index: int in range(1, _seats.size()):
		_drift(_seats[index], delta)
	for person: Dictionary in _residents:
		_mind_the_stall(person, delta)
	_tick_heel(delta)
	_breathe(delta)
	_follow_the_sun()
	_find_focus()
	queue_redraw()


func _drive_warden(delta: float) -> void:
	var seat: Dictionary = _seats[0]
	# **The dash first, because it overrides where the player is pointing.**
	# Owner, 2026-09-17: *"Players should still be able to right click dash in
	# the Hold."* It is the same press the road reads, so nobody has to learn a
	# second one - and it spends nothing, because there is nothing here to
	# escape and a cost with nothing on the other side of it is just a tax.
	_dash_rest = maxf(_dash_rest - delta, 0.0)
	if _dash_left > 0.0:
		_dash_left = maxf(_dash_left - delta, 0.0)
		_step(seat, _dash_way, delta,
			Balance.HOLD_DASH_DISTANCE / Balance.HOLD_DASH_SECONDS)
		_relay(delta)
		return
	var way := Vector2.ZERO
	if _driving:
		way = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
		if way.length_squared() > 0.01:
			_walk_to = Vector2.INF
		elif _walk_to != Vector2.INF:
			var step: Vector2 = _walk_to - (seat["at"] as Vector2)
			if step.length() > 16.0:
				way = step.normalized()
			else:
				_walk_to = Vector2.INF
	if _driving and _dash_rest <= 0.0 and Input.is_action_just_pressed(&"dash"):
		# Dashing where they are pointing, or where they are facing if they are
		# standing still - a dash that went nowhere because no key was down is a
		# press that did nothing.
		_dash_way = way if way.length_squared() > 0.01 \
			else (seat["facing"] as Vector2)
		if _dash_way.length_squared() > 0.01:
			_dash_left = Balance.HOLD_DASH_SECONDS
			_dash_rest = Balance.HOLD_DASH_REST
			_walk_to = Vector2.INF
			Sfx.play_group("sfx_dash")
	_step(seat, way, delta, Balance.HOLD_WALK_SPEED)
	_relay(delta)


## A walked step is sent on a threshold and a clock, never every frame - the
## same rule the wind is relayed under, and for the same reason: a position at
## frame rate is a clock wearing a threshold's clothes.
func _relay(delta: float) -> void:
	_relay_clock += delta
	if _relay_clock < Balance.HOLD_RELAY_INTERVAL:
		return
	_relay_clock = 0.0
	walked.emit(_seats[0]["at"] as Vector2, _seats[0]["facing"] as Vector2)


## A seat this machine does not drive: a simulated Warden wanders between the
## buildings on its own clock, and a real one eases toward wherever it was last
## said to be. Neither ever decides anything.
func _drift(seat: Dictionary, delta: float) -> void:
	if int(seat["kind"]) == HoldSession.Seat.EMPTY:
		return
	if int(seat["kind"]) == HoldSession.Seat.SIMULATED:
		seat["left"] = float(seat["left"]) - delta
		if float(seat["left"]) <= 0.0:
			var own := seat["rng"] as RandomNumberGenerator
			seat["to"] = _somewhere(own)
			seat["left"] = own.randf_range(Balance.HOLD_NPC_PAUSE.x,
				Balance.HOLD_NPC_PAUSE.y)
	var step: Vector2 = (seat["to"] as Vector2) - (seat["at"] as Vector2)
	var way: Vector2 = step.normalized() if step.length() > 12.0 else Vector2.ZERO
	_step(seat, way, delta, Balance.HOLD_WALK_SPEED * 0.72)


## One figure moving: the frames, the facing, and the edge of the yard.
func _step(seat: Dictionary, way: Vector2, delta: float, speed: float) -> void:
	var at: Vector2 = seat["at"] as Vector2
	if way.length_squared() > 0.01:
		at += way.normalized() * speed * delta
		seat["facing"] = way.normalized()
	at.x = clampf(at.x, -YARD.x * 0.5 + 40.0, YARD.x * 0.5 - 40.0)
	at.y = clampf(at.y, -YARD.y * 0.5 + 40.0, YARD.y * 0.5 - 40.0)
	seat["at"] = at
	var node := seat["node"] as Node2D
	if node != null:
		node.position = at
	var animator := seat["animator"] as HeroAnimator
	if animator == null:
		return
	animator.set_facing(seat["facing"] as Vector2)
	animator.play("walk" if way.length_squared() > 0.01 else "idle")


## The people who keep the stalls: mostly standing where they belong, sometimes
## a short errand behind their own building and back.
##
## **They turn to whoever is at their counter.** That is half the AI and it is
## the half that matters: a figure that never acknowledges the player is
## furniture, and one that wanders off mid-sentence is worse than furniture.
##
## **And the blacksmith gives up the anvil.** The owner's own rule: a Warden who
## comes to use the furnace or the anvil finds Orden stepping back to his bench,
## pacing and working an edge until the tools are free again. He is *told* by
## nothing - he reads where the Warden is standing, which is the same thing a
## person at an anvil would do.
func _mind_the_stall(person: Dictionary, delta: float) -> void:
	var sprite := person["node"] as Sprite2D
	if sprite == null:
		return
	person["clock"] = float(person["clock"]) + delta
	var home: Vector2 = person["home"] as Vector2
	var warden: Vector2 = _seats[0]["at"] as Vector2
	var yielding: bool = _warden_wants_the_tools(person)
	person["stood_aside"] = yielding
	if yielding:
		# Back to the bench, and never still: pacing is what says "waiting" at
		# this size, and a figure standing motionless beside a working player
		# reads as one that has stopped running.
		var aside: Vector2 = person["aside"] as Vector2
		person["to"] = aside + Vector2(sin(float(person["clock"]) * 0.7) * 46.0,
			cos(float(person["clock"]) * 0.53) * 22.0)
	elif warden.distance_to(sprite.position) < Balance.HOLD_REACH * 1.6:
		person["to"] = home
		sprite.flip_h = warden.x < sprite.position.x
	else:
		person["left"] = float(person["left"]) - delta
		if float(person["left"]) <= 0.0:
			person["left"] = _rng.randf_range(Balance.HOLD_NPC_PAUSE.x,
				Balance.HOLD_NPC_PAUSE.y)
			person["to"] = home + Vector2(_rng.randf_range(-70.0, 70.0),
				_rng.randf_range(-40.0, 40.0))
	var step: Vector2 = (person["to"] as Vector2) - sprite.position
	if step.length() > 4.0:
		sprite.position += step.normalized() * Balance.HOLD_WALK_SPEED * 0.35 * delta
	# Breathing, at the rate the stalls' own people work: a sprite that is
	# perfectly still beside a Warden that is animated reads as a cardboard cut
	# out, and a bob is the whole of the difference at this size.
	sprite.position.y += sin(float(person["clock"]) * float(person["beat"]) * 0.02) * 0.05


## Whether the Warden is at one of the tools this person works.
func _warden_wants_the_tools(person: Dictionary) -> bool:
	var wants: Array = person.get("yields_to", []) as Array
	if wants.is_empty():
		return false
	var warden: Vector2 = _seats[0]["at"] as Vector2
	for id: Variant in wants:
		var at: Vector2 = station_at(String(id))
		if at != Vector2.INF and warden.distance_to(at) < Balance.HOLD_REACH * 1.5:
			return true
	return false


## Whether a resident has stepped back from their tools. For the gate.
func stood_aside(id: String) -> bool:
	for person: Dictionary in _residents:
		if String(person["id"]) == id:
			return bool(person.get("stood_aside", false))
	return false


## The buildings' own idle frames, each on its own clock.
##
## Slow: a forge that flickers at the rate a fire does reads as an alarm at
## this size, and a Hold is somewhere you stand about in. A station with no
## frames on disk simply keeps its base, which is what every one of them did
## before this.
func _breathe(delta: float) -> void:
	for station: Dictionary in _stations:
		var frames: Array = station.get("idle", []) as Array
		if frames.is_empty():
			continue
		var sprite := station["node"] as Sprite2D
		if sprite == null:
			continue
		station["clock"] = float(station["clock"]) + delta
		# The base is frame zero, so a three-frame sheet is a four-step loop
		# that returns to the pose the building was drawn in.
		var step: int = int(float(station["clock"]) * Balance.HOLD_IDLE_FPS) \
			% (frames.size() + 1)
		sprite.texture = (station["base"] as Texture2D) if step == 0 \
			else frames[step - 1] as Texture2D


## What is in reach, nearest first. A building and its keeper answer the same
## door, so standing between them is never ambiguous about what happens.
func _find_focus() -> void:
	var warden: Vector2 = _seats[0]["at"] as Vector2 if not _seats.is_empty() else ENTRY
	var best: String = ""
	var nearest: float = Balance.HOLD_REACH
	for person: Dictionary in _residents:
		var sprite := person["node"] as Sprite2D
		if sprite == null:
			continue
		var away: float = warden.distance_to(sprite.position)
		if away < nearest:
			nearest = away
			best = String(person["id"])
	for station: Dictionary in _stations:
		var node := station["node"] as Node2D
		if node == null:
			continue
		# A station with no door is one the screen answers itself; a station
		# whose door was never adopted is a building with nothing in it.
		if station["button"] == null and not String(station["door"]).is_empty():
			continue
		var away: float = warden.distance_to(node.position + Vector2(0.0, 40.0))
		if away < nearest:
			nearest = away
			best = String(station["id"])
	_focus = best


## A tap or a click walks there, which is the only way a thumb can move in a
## place with no stick. The point arrives in yard units; the screen converts.
func walk_toward(at: Vector2) -> void:
	if not _driving:
		return
	_walk_to = at


# ---------------------------------------------------------------- the drawing


func _draw() -> void:
	var half: Vector2 = YARD * 0.5
	var rect := Rect2(-half, YARD)
	if _ground != null:
		draw_texture_rect(_ground, rect, true, Color(0.72, 0.78, 0.68))
	else:
		draw_rect(rect, Color(0.16, 0.19, 0.14), true)

	# The paths. Drawn rather than tiled, for the reason the pen's ground is: it
	# is bands of trodden earth under a dozen sprites, and a painting of one
	# would be a manifest row for something nobody looks at.
	var earth := Color(0.29, 0.24, 0.17, 0.55)
	draw_rect(Rect2(-half.x + 60.0, 70.0, YARD.x - 120.0, 130.0), earth, true)
	draw_rect(Rect2(ENTRY.x - 80.0, 70.0, 160.0, half.y - 70.0), earth, true)
	draw_rect(Rect2(PEN_FIRST.x - 220.0, 190.0,
		float(_pens.size()) * (PEN_SIZE.x + PEN_GAP) + 120.0, 90.0), earth, true)

	# The wall that was never finished (see `world_first_cut`): it runs out
	# halfway across, which is the one thing about this place a player should be
	# able to read without being told.
	var stone := Color(0.34, 0.35, 0.33)
	draw_rect(Rect2(-half.x, -half.y, YARD.x * 0.6, 52.0), stone, true)
	draw_rect(Rect2(-half.x, -half.y, YARD.x * 0.6, 52.0),
		stone.darkened(0.35), false, 3.0)
	for index: int in 5:
		var broken := Rect2(-half.x + YARD.x * 0.6 + float(index) * 66.0,
			-half.y, 46.0, 52.0 - float(index) * 10.0)
		draw_rect(broken, stone.darkened(0.1), true)

	_draw_pens()

	for at: Vector2 in _grass_at:
		if _grass != null:
			draw_texture(_grass, at - _grass.get_size() * Vector2(0.5, 1.0),
				Color(1.0, 1.0, 1.0, 0.85))
		else:
			draw_circle(at, 7.0, Color(0.22, 0.3, 0.18, 0.7))

	# Shadows, on the ground under everybody rather than on each sprite: a
	# shadow belongs to the earth, and drawing it here is also what keeps it
	# from ever being sorted in front of the thing casting it.
	for station: Dictionary in _stations:
		var node := station["node"] as Node2D
		if node != null:
			_shadow(node.position, 54.0, 16.0)
	for person: Dictionary in _residents:
		var sprite := person["node"] as Sprite2D
		if sprite != null:
			_shadow(sprite.position, 22.0, 8.0)
	if _heel != null and is_instance_valid(_heel):
		_shadow(_heel.position, 18.0, 7.0)
	for index: int in _seats.size():
		var seat: Dictionary = _seats[index]
		if int(seat["kind"]) == HoldSession.Seat.EMPTY:
			continue
		var stood: Vector2 = seat["at"] as Vector2
		_shadow(stood, 24.0, 9.0)
		# **The same colour this Warden is everywhere else** (owner, 2026-09-17:
		# *"the players/playerNPCs should still have their color assigned vfx"*).
		# Read off `Balance.PARTY_COLOURS` by seat rather than rolled here, so the
		# blue Warden in the Hold is the blue Warden on the road - a second table
		# of colours is how one of them ends up disagreeing.
		var mine: Color = Balance.PARTY_COLOURS[index % Balance.PARTY_COLOURS.size()]
		# Flattened for the reason every ring at the feet in this game is: the
		# camera looks down and slightly along, and a true circle reads as a hoop
		# standing up. It breathes on the seat's own clock so four Wardens are
		# four marks rather than one drawn four times.
		var breath: float = 0.42 + 0.14 * sin(_clock * 1.7 + float(index) * 1.9)
		draw_set_transform(stood, 0.0, Vector2(1.0, 0.36))
		draw_arc(Vector2.ZERO, 30.0, 0.0, TAU, 28,
			Color(mine.r, mine.g, mine.b, breath), 2.5)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# What is in reach, marked on the ground. A ring rather than a floating
	# icon, because the thing being pointed at is a place to stand.
	var lit: Vector2 = _focus_point()
	if lit != Vector2.INF:
		var pulse: float = 0.55 + 0.25 * sin(_clock * 3.4)
		draw_arc(lit, Balance.HOLD_REACH * 0.5, 0.0, TAU, 40,
			Color(0.91, 0.64, 0.24, pulse), 3.0)


## A fence a post at a time, with a gate on the path side: a rectangle of line
## reads as a diagram, and the gap is what says which side you walk in from.
func _draw_pens() -> void:
	var timber := Color(0.38, 0.29, 0.19)
	for pen: Dictionary in _pens:
		var at: Vector2 = pen["at"] as Vector2
		var box := Rect2(at - PEN_SIZE * 0.5, PEN_SIZE)
		draw_rect(box, Color(0.20, 0.21, 0.15, 0.55), true)
		# **The near rail only.** A pen drawn as a closed rectangle puts a fence
		# between the player and the animals they came to look at; the far side
		# is the treeline behind it. The gate is the two missing posts in the
		# middle, which is the whole of "there is a way in".
		var posts: int = 9
		var foot: float = box.position.y + box.size.y
		var span: float = box.size.x / float(posts)
		var last: Vector2 = Vector2.INF
		for index: int in posts + 1:
			var gate: bool = index >= 4 and index <= 5
			var here := Vector2(box.position.x + span * float(index), foot)
			if not gate:
				# A post's height wanders a little, from its own place rather than
				# from a roll: a fence of identical posts is a comb.
				var tall: float = 26.0 + sin(here.x * 0.07) * 3.0
				_fence_post(here, tall, timber)
				if last != Vector2.INF:
					_fence_rail(last - Vector2(0.0, 20.0), here - Vector2(0.0, 20.0),
						timber)
			last = here if not gate else Vector2.INF


func _focus_point() -> Vector2:
	if _focus.is_empty():
		return Vector2.INF
	for person: Dictionary in _residents:
		if String(person["id"]) == _focus:
			return (person["node"] as Sprite2D).position
	for station: Dictionary in _stations:
		if String(station["id"]) == _focus:
			return (station["node"] as Node2D).position
	return Vector2.INF


## A shadow with a soft edge, which is the whole of what was wrong with it.
##
## Owner, 2026-09-17: *"shadows need to be improved at the hold."*
##
## **`draw_circle` cannot have a soft edge**, because one colour for the
## whole shape *is* a hard edge - the third time this project has paid for
## that finding, after the swim sheen, the menu campfire and the blood. So it
## is a fan of triangles with a colour per vertex: solid at the middle,
## transparent at the rim, handed to one `canvas_item_add_triangle_array`.
## That is one draw call rather than one per shadow, and it is *fewer* than
## the circles it replaces.
##
## Flattened, because the camera looks down and slightly along - a true circle
## at the feet reads as a hoop standing up, which is the reasoning the set
## aura is drawn under.
func _shadow(at: Vector2, wide: float, tall: float) -> void:
	var steps: int = 14
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var indices: PackedInt32Array = []
	var middle := Color(0.0, 0.0, 0.0, 0.30)
	var rim := Color(0.0, 0.0, 0.0, 0.0)
	points.append(at)
	colours.append(middle)
	for step: int in steps + 1:
		var angle: float = TAU * float(step) / float(steps)
		points.append(at + Vector2(cos(angle) * wide, sin(angle) * tall))
		colours.append(rim)
	for step: int in steps:
		indices.append_array([0, step + 1, step + 2])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours)


## A fence post and the rails either side of it, with a thickness.
##
## Owner, 2026-09-17: *"assets made so that pens can have proper fences."*
##
## **Drawn rather than generated, and that is the launcher's lesson applied.**
## Two passes were spent there laying the menu's own textures flat, and the
## owner's verdict was that they *"just lower the quality and polish"* -
## because the menu's frame gets its look from a shader and a wobble, and
## copying the art without the machinery reads flatter than the thing it
## copied. A fence is posts, rails, a lit side and a shadow; all four are
## arithmetic, and arithmetic that moves beats a texture that does not.
func _fence_post(foot: Vector2, tall: float, timber: Color) -> void:
	var wide: float = 5.0
	var head: Vector2 = foot - Vector2(0.0, tall)
	# The shadow first, so the post stands on it.
	_shadow(foot, wide * 1.8, wide * 0.7)
	# The body, with the left face lit and the right in shade: one light in
	# this place and it is overhead and a little to the left, which is the
	# same direction the ledges' banks are shaded from on the road.
	draw_colored_polygon(PackedVector2Array([
		head - Vector2(wide * 0.5, 0.0), head + Vector2(0.0, 0.0),
		foot + Vector2(0.0, 0.0), foot - Vector2(wide * 0.5, 0.0)]),
		timber.lightened(0.18))
	draw_colored_polygon(PackedVector2Array([
		head, head + Vector2(wide * 0.5, 0.0),
		foot + Vector2(wide * 0.5, 0.0), foot]),
		timber.darkened(0.22))
	# A cap, so the top is an end rather than a cut.
	draw_line(head - Vector2(wide * 0.6, 0.0), head + Vector2(wide * 0.6, 0.0),
		timber.lightened(0.34), 2.0)


## The rails between two posts, sagging a little.
##
## The sag is what stops a fence reading as a diagram: a rail fixed at both
## ends and left for a season does not stay straight, and two of them at
## different sags say more about the place than a third rail would.
func _fence_rail(left: Vector2, right: Vector2, timber: Color) -> void:
	for rung: int in 2:
		var up: float = 0.62 - float(rung) * 0.34
		var sag: float = 2.0 + float(rung) * 1.5
		var from := Vector2(left.x, left.y - up * 10.0)
		var to := Vector2(right.x, right.y - up * 10.0)
		var middle := (from + to) * 0.5 + Vector2(0.0, sag)
		# Three segments rather than a curve: at this size a quadratic and two
		# straight lines through the same midpoint are the same picture, and one
		# of them costs nothing.
		draw_line(from, middle, timber.darkened(0.08), 3.0)
		draw_line(middle, to, timber.darkened(0.08), 3.0)


# ---------------------------------------------------------------- for the gate


## Drive the yard by hand, for a gate with no minutes to spend.
func advance(seconds: float, steps: int = 30) -> void:
	var step: float = seconds / maxf(float(steps), 1.0)
	for _index: int in steps:
		_process(step)


## Put the Warden somewhere, for a gate and for the entry.
func stand_warden(at: Vector2) -> void:
	if _seats.is_empty():
		return
	_seats[0]["at"] = at
	_place(_seats[0])
	_find_focus()


## Where a station stands, for a gate and for anything that wants to send the
## Warden to one.
func station_at(id: String) -> Vector2:
	for station: Dictionary in _stations:
		if String(station["id"]) == id:
			return (station["node"] as Node2D).position + Vector2(0.0, 70.0)
	return Vector2.INF


func station_ids() -> Array[String]:
	var out: Array[String] = []
	for station: Dictionary in _stations:
		out.append(String(station["id"]))
	return out


func pens() -> int:
	return _pens.size()
