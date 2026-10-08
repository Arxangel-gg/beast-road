class_name TrailerPlan
extends RefCounted

## **A trailer, dealt** (owner, 2026-10-07: "make the trailers procedurally
## generated in game at game launch instead of a pre-recorded video. The player
## at any part in the trailer should be procedurally randomized to the
## expectation of where they would naturally be at that point. The battlefields
## should also be procedurally made to be at the points in those moments. And
## the moments shouldn't all be in the same act every time").
##
## A plan is **one Warden's journey in three roads**: one walked early, one in
## the middle of a career, one far along. Each is a different act, layout, seed
## and light; each has the board, the Arsenal and the spells a Warden would have
## by then; and the Warden is the same person on all three - the body, the face,
## the hair and the skin rolled once - in the gear that point of the journey
## would have put on them (`ProceduralWarden`). Between them the moments
## (`TrailerMomentData`) are dealt by where in a cut they belong, with no moment
## shown twice and the last one always a climax.
##
## Pure: everything comes from `seed`, so the gate deals a hundred trailers and
## reads them without standing one up, and a launch deals a different one by
## being handed a different seed.

## The acts each road may be walked in: early, middle, late.
const ROAD_ACTS: Array = [[1, 3], [4, 7], [8, 11]]
## The keys of a look that are the person rather than their clothes: these are
## rolled once for the trailer and worn on every road.
const PERSON: Array[String] = [WardenLook.KEY_BODY, WardenLook.KEY_HAIR,
	WardenLook.KEY_HAIR_COLOUR, WardenLook.KEY_BEARD, WardenLook.KEY_SKIN]


static func make(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(hash("trailer-plan:%d" % seed))
	var person: Dictionary = ProceduralWarden.roll("trailer:%d" % seed, _first_tier(), 1)["look"]
	var roads: Array = []
	var used: Array[String] = []
	var total: float = 0.0
	for road: int in ROAD_ACTS.size():
		var span: Array = ROAD_ACTS[road]
		var act: int = rng.randi_range(int(span[0]), int(span[1]))
		var tier: String = _tier_for(rng, road)
		var warden: Dictionary = ProceduralWarden.roll("trailer:%d:%d" % [seed, road], tier, act)
		var look: Dictionary = (warden["look"] as Dictionary).duplicate()
		for key: String in PERSON:
			look[key] = person[key]
		warden["look"] = WardenLook.clean(look)
		var pool: Array[String] = MapModes.random_pool()
		var moments: Array = _deal(rng, road, act, used)
		for moment: Dictionary in moments:
			total += float(moment["seconds"])
		var weathers: Array[WeatherData] = ContentDB.weathers_for_act(act)
		var weather: String = ""
		if not weathers.is_empty() and rng.randf() < 0.3:
			weather = weathers[rng.randi_range(0, weathers.size() - 1)].id
		roads.append({
			"act": act,
			"tier": tier,
			"map": pool[rng.randi_range(0, pool.size() - 1)] if not pool.is_empty() else MapModes.FALLBACK,
			"varied": rng.randf() < 0.6,
			"seed": rng.randi_range(1, 2147483646),
			"weather": weather,
			"warden": warden,
			"moments": moments,
			"line": _road_line(rng),
		})
	return {"seed": seed, "roads": roads, "seconds": total}


## The moments a road shows, from the ones whose acts it is walked in: the
## opening on the first road, the build-up and the body on the first two, the
## body and the climax on the last - which always ends on a climax.
static func _deal(rng: RandomNumberGenerator, road: int, act: int, used: Array[String]) -> Array:
	var places: Array[int] = []
	match road:
		0:
			places = [TrailerMomentData.Place.OPEN, TrailerMomentData.Place.EARLY]
			if rng.randf() < 0.6:
				places.append(TrailerMomentData.Place.MIDDLE)
		1:
			places = [TrailerMomentData.Place.MIDDLE, TrailerMomentData.Place.MIDDLE]
			if rng.randf() < 0.65:
				places.append(TrailerMomentData.Place.MIDDLE)
		_:
			places = [TrailerMomentData.Place.MIDDLE if rng.randf() < 0.5 else TrailerMomentData.Place.LATE,
				TrailerMomentData.Place.LATE]
	var out: Array = []
	for place: int in places:
		var moment: TrailerMomentData = _pick(rng, place, act, used)
		if moment == null:
			continue
		used.append(moment.id)
		out.append(_instance(rng, moment))
	return out


static func _pick(rng: RandomNumberGenerator, place: int, act: int, used: Array[String]) -> TrailerMomentData:
	var fits: Array[TrailerMomentData] = []
	var weights: Array[float] = []
	for value: Variant in ContentDB.trailer_moments.values():
		var moment := value as TrailerMomentData
		if moment == null or int(moment.place) != place or used.has(moment.id):
			continue
		if act < moment.first_act or act > moment.last_act:
			continue
		fits.append(moment)
		weights.append(maxf(moment.weight, 0.0))
	if fits.is_empty():
		return null
	fits_sort(fits, weights)
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	var roll: float = rng.randf() * total
	for index: int in fits.size():
		roll -= weights[index]
		if roll <= 0.0:
			return fits[index]
	return fits[fits.size() - 1]


## Sorted by id, so a seed deals the same moments whatever order the folder
## was read in.
static func fits_sort(fits: Array[TrailerMomentData], weights: Array[float]) -> void:
	var pairs: Array = []
	for index: int in fits.size():
		pairs.append([fits[index], weights[index]])
	pairs.sort_custom(func(a: Array, b: Array) -> bool:
		return (a[0] as TrailerMomentData).id < (b[0] as TrailerMomentData).id)
	for index: int in pairs.size():
		fits[index] = pairs[index][0]
		weights[index] = float(pairs[index][1])


## One moment as it will be filmed: how long, how the camera moves, how light,
## and which line, if any.
static func _instance(rng: RandomNumberGenerator, moment: TrailerMomentData) -> Dictionary:
	var near: float = rng.randf_range(moment.zoom_min, moment.zoom_max)
	var far: float = rng.randf_range(moment.zoom_min, moment.zoom_max)
	var line: String = ""
	if not moment.lines.is_empty() and rng.randf() < moment.line_chance:
		line = moment.lines[rng.randi_range(0, moment.lines.size() - 1)]
	return {
		"id": moment.id,
		"seconds": rng.randf_range(moment.seconds_min, moment.seconds_max),
		"zoom_from": near,
		"zoom_to": far,
		"daylight": rng.randf_range(moment.daylight_min, moment.daylight_max),
		"line": line,
		# The camera's way of moving and where it leans, and the Warden's own
		# temper for the shot - how restless, how bold - are rolled here so the
		# stage only has to follow them.
		"drift": Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)),
		"restless": rng.randf(),
		"bold": rng.randf(),
		"dice": rng.randi_range(1, 2147483646),
	}


## The first road is walked on the Long Road; the middle one usually is; the
## last is as often on a harder road as not.
static func _tier_for(rng: RandomNumberGenerator, road: int) -> String:
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	if tiers.is_empty():
		return ""
	match road:
		0:
			return tiers[0].id
		1:
			return tiers[mini(1, tiers.size() - 1)].id if rng.randf() < 0.35 else tiers[0].id
	var pick: float = rng.randf()
	var index: int = 0 if pick < 0.3 else (1 if pick < 0.65 else 2)
	return tiers[mini(index, tiers.size() - 1)].id


static func _first_tier() -> String:
	var tiers: Array[CampaignTierData] = ContentDB.tiers_sorted()
	return tiers[0].id if not tiers.is_empty() else ""


static func _road_line(rng: RandomNumberGenerator) -> String:
	var text: TrailerText = ContentDB.trailer_text()
	if text == null or text.road_lines.is_empty():
		return ""
	return text.road_lines[rng.randi_range(0, text.road_lines.size() - 1)]
