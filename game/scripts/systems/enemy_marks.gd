class_name EnemyMarks
extends RefCounted

## **The one door every mark is rolled through** (2026-09-25).
##
## Marks used to be rolled inside `WaveDirector`, uniformly from the act's pool,
## by the waves and by nothing else. Three callers want them now - the waves,
## the bosses and the tiers' marked commons - and two copies of "which mark
## comes up" is how one of them ends up ignoring the weather.
##
## **The weather chooses.** A mark that names the weather the road is under is
## `Balance.MARK_WEATHER_FAVOUR` times likelier, so a snowfall brings the
## Rimewarded and a heatwave the Emberclad: two of the game's systems reading
## each other, and the road telling the player something. **One draw a pick
## whatever the weights**, so the stream every later roll comes from is exactly
## as far along as it was - and when nothing is favoured the pick is the same
## modulo it always was, so a seeded run under a clear sky with no favoured mark
## deals what it always dealt.


## Every mark this act may wear, in a stable order.
static func pool(act: int) -> Array[EnemyAffixData]:
	var out: Array[EnemyAffixData] = []
	var ids: Array = ContentDB.affixes.keys()
	ids.sort()
	for id: Variant in ids:
		var affix := ContentDB.affixes[id] as EnemyAffixData
		if affix != null and affix.from_act <= act:
			out.append(affix)
	return out


## How strongly the current weather favours a mark: one, or the favour.
static func weight(affix: EnemyAffixData, weather: String) -> float:
	if affix == null:
		return 0.0
	if not weather.is_empty() and affix.favoured_weather.has(weather):
		return Balance.MARK_WEATHER_FAVOUR
	return 1.0


## Distinct marks, never the same one twice on a body.
static func roll(count: int, act: int, weather: String,
		rng: RandomNumberGenerator) -> Array[EnemyAffixData]:
	var available: Array[EnemyAffixData] = pool(act)
	var worn: Array[EnemyAffixData] = []
	for _i: int in mini(count, available.size()):
		var weights: PackedFloat32Array = []
		var total: float = 0.0
		var even: bool = true
		for affix: EnemyAffixData in available:
			var w: float = weight(affix, weather)
			weights.append(w)
			total += w
			if not is_equal_approx(w, 1.0):
				even = false
		var draw: int = rng.randi()
		var pick: int = draw % available.size()
		if not even and total > 0.0:
			# The same draw, read as a point along the weights.
			var at: float = float(draw % 1000003) / 1000003.0 * total
			pick = available.size() - 1
			for index: int in available.size():
				at -= weights[index]
				if at < 0.0:
					pick = index
					break
		worn.append(available[pick])
		available.remove_at(pick)
	return worn


## **What share of the ordinary road bodies a tier marks**, lifted by the
## earth's anger and capped. Zero on Normal, which is where every curve in this
## project is measured, so nothing measured there moves.
##
## The lift is a sign rather than a readout: the wrath is never shown, and more
## of the road wearing marks is one of the ways the world says it is angry.
static func marked_share(tier: CampaignTierData, wrath: float) -> float:
	if tier == null or tier.marked_share <= 0.0:
		return 0.0
	var lifted: float = tier.marked_share * (1.0 + maxf(wrath, 0.0) * Balance.MARK_WRATH_LIFT)
	return minf(lifted, Balance.MARK_SHARE_CEILING)
