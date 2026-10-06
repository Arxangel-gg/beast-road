class_name MapModes
extends RefCounted

## The battlefield layouts a road may be laid on, and the one place their names
## live.
##
## Owner, 2026-09-23: *"settings dropdown options for the best different map
## modes ... including the new map modes and current map mode, so all
## variations can be tested and current method can be preserved to revisit as
## needed."* The shipped map was kept, laid exactly as it always was, until
## 2026-10-06, when the owner retired it for players (see `AUTHORED`); every
## other mode is a new core laid by `MapLayouts` inside the same outskirts.
##
## And the same day: *"an option that will randomly use any of the map modes
## except for the original ... Any of the random maps it makes should also have
## procedural variations."* So **Random is a choice, never a road**: it is
## resolved once, when a road begins, into one of the other layouts laid with
## its proportions rolled from the seed (`resolve`). What the road carries is
## the layout it got and whether it was varied - so a banked front, a guest and
## a rejoin all build the map that was actually rolled.
##
## **A mode is a fact about a road, not a preference about a machine.** The
## setting only chooses the layout of the *next new* road: a banked front comes
## back on the map it was banked on (`Expedition` carries it), a guest walks the
## host's map (`CoopRelay` carries it beside the seed), and the Walk is always
## Keep, its stops placed against the field's own landmarks. Two machines
## building one road from two settings is two games sharing a socket.
##
## Referenced by `BattleGrid`, which the headless `--script` tools load - so
## this class must never reach an autoload. The setting itself is read in
## `UserSettings.map_mode`, which may.

## **The authored core, kept as the gates' reference ground and reachable by no
## player door** (owner, 2026-10-06: "remove the classic completely from the
## game so that players do not get the swastika shaped map ever again").
## Hundreds of checks stand bodies, ponds and towers on the authored map by
## coordinate, so it stays the field a bare `RunState.reset()` lays; but it is
## not in `ALL`, `sanitise` turns it into Keep, and every door a player's road
## goes through - `start_run`, a banked front, a relayed road, the Walk -
## sanitises. `map_mode_check` holds that.
const AUTHORED: String = "authored"
## What the retired layout was called in a banked front or an old setting. It
## reads as Keep now, and a front banked on it comes home on Keep.
const LEGACY_CLASSIC: String = "classic"
const KEEP: String = "keep"
const CITADEL: String = "citadel"
const BEAST_AXIS: String = "beast_axis"
const CONFLUENCE: String = "confluence"
const FOUR_RINGS: String = "confluence_rings"
const WILD: String = "wild"
## A choice in the dropdown and never a road: see `resolve`.
const RANDOM: String = "random"

## Every layout a road can be laid on. `label` is what the dropdown says;
## `blurb` is the line under it.
const ALL: Array[Dictionary] = [
	{"id": KEEP, "label": "Keep",
		"blurb": "Two walls. Every road reaches the outer wall and doubles back along the inner one to a gate - towers between the walls hit the same column twice."},
	{"id": CITADEL, "label": "Citadel",
		"blurb": "One wall, two gates east and west. Every road arrives at a bastion; north and south ride the wall to a gate."},
	{"id": BEAST_AXIS, "label": "Beast-Axis",
		"blurb": "Shaped like the beast: a spine through the town, ribs across it, a bow and a stern. The flanks cut through the ribs."},
	{"id": CONFLUENCE, "label": "Confluence",
		"blurb": "Roads gather east and west. North and south roads split and join the two braided trunks that lead to the town."},
	{"id": FOUR_RINGS, "label": "Confluence: Four Rings",
		"blurb": "Every road has a braided ring of its own - north, east, south and west - each looping round an island before it reaches the town."},
	{"id": WILD, "label": "Wild Roads",
		"blurb": "Laid new for every road from its seed: a different network each time, always mirrored left to right."},
]

## What the dropdown offers: Random first, then every layout.
const RANDOM_CHOICE: Dictionary = {"id": RANDOM, "label": "Random",
	"blurb": "Any layout, chosen for each new road - and laid with its own proportions, so no two roads are quite the same map."}


## A layout this build knows, or Keep. A save or a packet may hold anything,
## and an unknown layout - or Random, which is a choice rather than a map - must
## never reach the grid.
static func sanitise(id: Variant) -> String:
	var text: String = String(id) if id is String else ""
	for entry: Dictionary in ALL:
		if String(entry["id"]) == text:
			return text
	# Keep: the plainest of the laid-out battlefields, and a fixed one, so a
	# front, a setting or a relayed road that names nothing the game has is
	# laid the same way every time rather than rolled.
	return KEEP


## A choice the dropdown may hold: any layout, or Random.
static func sanitise_choice(id: Variant) -> String:
	if id is String and String(id) == RANDOM:
		return RANDOM
	return sanitise(id)


## The dropdown's entries, in order: Random, then every layout.
static func choices() -> Array[Dictionary]:
	# Random first: it is the default, and the one choice that is not a layout.
	var out: Array[Dictionary] = [RANDOM_CHOICE]
	for entry: Dictionary in ALL:
		out.append(entry)
	return out


## Every layout Random may deal: every one of them.
static func random_pool() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in ALL:
		out.append(String(entry["id"]))
	return out


## What a choice lays on a road that begins with `road_seed`: `[layout, varied]`.
##
## A named layout is laid as designed, so a tester who picks the Keep plays the
## Keep. Random deals any layout and lays it varied. Its own
## generator rather than one of the run's named streams, because drawing from a
## stream moves every roll after it.
static func resolve(choice: String, road_seed: int) -> Array:
	if choice != RANDOM:
		return [sanitise(choice), false]
	var pool: Array[String] = random_pool()
	var rng := RandomNumberGenerator.new()
	rng.seed = road_seed * 7919 + 2026
	return [pool[rng.randi_range(0, pool.size() - 1)], true]


static func label_of(id: String) -> String:
	if id == RANDOM:
		return String(RANDOM_CHOICE["label"])
	for entry: Dictionary in ALL:
		if String(entry["id"]) == id:
			return String(entry["label"])
	return String(ALL[0]["label"])


static func blurb_of(id: String) -> String:
	if id == RANDOM:
		return String(RANDOM_CHOICE["blurb"])
	for entry: Dictionary in ALL:
		if String(entry["id"]) == id:
			return String(entry["blurb"])
	return ""


## Every layout a road can be laid on. Neither Random nor the authored
## reference is one.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for entry: Dictionary in ALL:
		out.append(String(entry["id"]))
	return out
