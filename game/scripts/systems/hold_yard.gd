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
## Derived from the map rather than authored beside it: a yard whose size
## disagreed with the ground in it is the fault the two tables had.
const YARD: Vector2 = Vector2(MAP_W * CELL, MAP_H * CELL)

## Where the road out is, and where the Warden stands when the Hold opens.
const ENTRY: Vector2i = Vector2i(18, 23)

## The ground the Hold stands on. The lore's Hold is a valley with farmland in
## it (see `world_first_cut`), which is the greenest ground the game owns.
const GROUND_ART: String = "res://art/terrain/terrain_jungle.png"
const GRASS_ART: String = "res://art/foliage/grass_jungle.png"
const POND_ART: String = "res://art/battlefield/pond_tiles_jungle.png"
const FOLIAGE_FORMAT: String = "res://art/foliage/plant_jungle_%s.png"

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
		"label": "The Furnace", "cell": Vector2i(9, 13)},
	{"id": "anvil", "door": "Smithy", "art": "res://art/battlefield/smithy.png",
		"label": "The Anvil", "cell": Vector2i(12, 14)},
	{"id": "vendor", "door": "Vendor", "art": "res://art/city/building_market.png",
		"label": "The Market", "cell": Vector2i(23, 13)},
	{"id": "ledger", "door": "Ledger", "art": "res://art/battlefield/camp_rack.png",
		"label": "The Long Ledger", "cell": Vector2i(32, 9)},
	{"id": "stash", "door": "Stash", "art": "res://art/city/building_treasury.png",
		"label": "The Stash", "cell": Vector2i(11, 4)},
	{"id": "chronicle", "door": "Chronicle", "art": "res://art/city/building_town_hall.png",
		"label": "The Chronicle", "cell": Vector2i(18, 3)},
	{"id": "leaderboard", "door": "Leaderboard", "art": "res://art/city/building_watchtower.png",
		"label": "The Board", "cell": Vector2i(5, 9)},
	{"id": "codex", "door": "Codex", "art": "res://art/city/building_sanctum.png",
		"label": "The Codex", "cell": Vector2i(25, 4)},
	{"id": "pen", "door": "Pen", "art": "res://art/city/building_granary.png",
		"label": "The Pens", "cell": Vector2i(12, 19)},
	{"id": "card", "door": "", "art": "res://art/battlefield/war_totem.png",
		"label": "The Warden's Stone", "cell": Vector2i(18, 9)},
	{"id": "road", "door": "", "art": "res://art/city/plot_locked.png",
		"label": "The Road Out", "cell": Vector2i(18, 24)},
	{"id": "stable", "door": "Stable", "art": "res://art/city/building_granary_tier_02.png",
		"label": "The Stable", "cell": Vector2i(8, 20)},
	{"id": "coop", "door": "Coop", "art": "res://art/city/plot_empty.png",
		"label": "The Gate", "cell": Vector2i(22, 21)},
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
##
## **`art` is theirs and `stall` is the shop's, and that separation is the whole
## of a bug the owner reported.** Until 2026-09-17 these four pointed straight at
## `art/city/merchant_*.png`, which are the travelling merchant's *stalls*: each
## one is a diorama with a round cobblestone plinth, a table, a handcart or a
## pair of barrels painted into it. That is right on a shop panel and on a road
## stall, and wrong on a person who walks - the Hold drew four figures each
## standing on its own private disc of pavement, sliding it about the yard.
##
## So the residents have their own paintings now, with nothing under the boots,
## and `stall` is what they fall back to if one is missing - a figure on a
## plinth is a worse Hold than it should be, and no figure at all is not a Hold.
const RESIDENTS: Array[Dictionary] = [
	{"id": "smith", "door": "Smithy", "art": "res://art/city/hold_smith.png",
		"stall": "res://art/city/merchant_relic_peddler.png",
		"name": "Orden", "label": "Orden, who keeps the fire in",
		"cell": Vector2i(11, 13), "beat": 70.0,
		"yields_to": ["smithy", "anvil"], "aside": Vector2i(8, 15)},
	{"id": "keeper", "door": "Vendor", "art": "res://art/city/hold_keeper.png",
		"stall": "res://art/city/merchant_quartermaster.png",
		"name": "Tessel", "label": "Tessel, who keeps the market",
		"cell": Vector2i(24, 14), "beat": 84.0,
		"yields_to": [], "aside": Vector2i(26, 15)},
	{"id": "steward", "door": "Pen", "art": "res://art/city/hold_steward.png",
		"stall": "res://art/city/merchant_alchemist.png",
		"name": "Wren", "label": "Wren, who minds the pens",
		"cell": Vector2i(15, 20), "beat": 96.0,
		"yields_to": [], "aside": Vector2i(15, 20)},
	{"id": "stabler", "door": "Stable", "art": "res://art/city/hold_stabler.png",
		"stall": "res://art/city/merchant_stabler.png",
		"name": "Halric", "label": "Halric, who keeps the horses",
		"cell": Vector2i(9, 21), "beat": 78.0,
		"yields_to": [], "aside": Vector2i(9, 21)},
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
const FIRE_AT: Vector2i = Vector2i(17, 12)
const TORCHES: Array[Vector2i] = [
	Vector2i(11, 15), Vector2i(24, 15), Vector2i(18, 10),
	Vector2i(8, 9), Vector2i(29, 9), Vector2i(12, 19),
	Vector2i(26, 19), Vector2i(18, 22),
]

## **The Hold is cut into a hillside, and this is where the steps are.**
##
## Owner, 2026-09-17: *"a tileset environment with multi-elevations and
## platforms designed for each area and a thoughtful and carefully planned
## outline for the Hold's layout and design"*, so that the place reads as *"a
## fortified shelter camp"*. A camp on one flat rectangle is a car park.
##
## Three shelves, and the plan is the layout that was already here rather than
## a new one laid over it:
##
## - **The shelf**, under the unfinished wall, holds the things worth putting
##   behind stone: the Stash, the Chronicle, the Codex and the pen house.
## - **The square** is the middle, where the forge, the market, the anvil, the
##   Ledger, the stable, the board and the Warden's Stone are, and where the
##   people stand.
## - **The lower yard** is the pens and the road out - the ground you arrive
##   on, so a Warden coming home *climbs into* the Hold.
##
## **Every boundary runs east to west, and that is not a shortcut.** The
## camera looks down and slightly along, so a south-facing bank is the only
## face a player can ever see; a north one would be drawn behind the shelf
## that owns it. The raid camp reached the same conclusion on 2026-09-13 and
## this is its bank art, tinted, in a place with no tile grid to bake it into.
##
## **The ground itself, painted rather than banded.**
##
## Owner, 2026-09-17: the Hold must not be *"3 straight elevation steps that
## stretch horizontally"* but a place laid out like Nahantu, big enough for
## four Wardens to roam. The first cut was two tables - the y of each edge and
## the stretch of each edge you were allowed to cross - and **every shape those
## two can describe is a band across the screen**.
##
## A cell is `CELL` units. `.` is the valley floor, `1` and `2` are shelves,
## `^ v < >` are flights climbing toward the arrow, `~` is water and a space is
## hillside nobody walks on. A flight reads its own low and high side off its
## neighbours, so the stairs and the ground cannot disagree - which is the whole
## reason the two tables went.
##
## Painted by `tools/hold_map.py`: blobs for the shelves, then a flight cut into
## the middle of every long run of boundary, then every pocket the road cannot
## reach pruned back to hillside. Ground nobody can stand on is not ground, and
## a stair authored where nobody walks strands a third of a yard while every
## number in the table still reads as correct.
const MAP: Array[String] = [
	"                                      ",
	"            2222222222222             ",
	"         2222222222222222222          ",
	"        222222222222222222222         ",
	"        222222222222222222222         ",
	"        222222222222222222222         ",
	"          21111222222221111    22     ",
	"   22222211111112222222111111222222   ",
	"  .222222<111111122221111111>222222.  ",
	"  .222222<111111222222111111>222222.  ",
	" ..222222<111111222222111111>222222.. ",
	" ..222222111111111^^^1111111112222... ",
	" ....11111111111111111111111111...... ",
	" ....11111111111111111111111~~~...... ",
	" .....111111111111111111111~~~....... ",
	" ......11111111111111111111.......... ",
	" .........^^^..111111..^^^.>11111<... ",
	"  ...............^^^.......>11111<..  ",
	"  .........................>11111<..  ",
	"   ...........................1....   ",
	"    ..............................    ",
	"    ..............................    ",
	"     ............................     ",
	"       ........................       ",
	"         ....................         ",
	"             ............             ",
]

const MAP_W: int = 38
const MAP_H: int = 26
const CELL: float = 96.0

## The middle of a cell, in the flat plane everything else is placed in.
##
## Static, because the tables here are constants and a constant cannot call a
## method - so every table holds *cells* and everything that reads one converts
## through here. One conversion, so a place can never be authored in two
## coordinate systems at once.
static func at_cell(cell: Vector2i) -> Vector2:
	return Vector2(-YARD.x * 0.5, -YARD.y * 0.5) \
		+ (Vector2(cell) + Vector2(0.5, 0.5)) * CELL

const BANK_ART: String = "res://art/raid/raid_cliff_face.png"

## **The flights, and they are the same two pieces every place in the game
## uses.** Owner, 2026-09-17: *"the stair solution should also apply to
## dungeons with the correct adaptations for each environment"* - so one
## staircase is drawn climbing away from the camera, one climbing across it,
## and the side one is mirrored for the other direction. A staircase going
## the other way is the same staircase.
##
## The adaptation is the tint, exactly as the bank's is: earth for a valley,
## cut stone for a rift. A second painting per environment is a second thing
## that can disagree with the first.
const STAIR_NORTH_ART: String = "res://art/terrain/stair_earth_north.png"
const STAIR_SIDE_ART: String = "res://art/terrain/stair_earth_east.png"

## **The Wang sheets each shelf is laid with.**
##
## Owner, 2026-09-17: a shelf painted as a quad of one texture has a hard edge
## by construction. The valley floor is the soil sheet; the plaza is turf laid
## over it, and the sanctum behind the wall is an old flagstone courtyard laid
## over the turf - so each shelf is a *different place* rather than the same
## ground a rise higher, and every join between them is authored art.
const TILE_ART: Array[String] = [
	"",
	"res://art/terrain/hold_turf.png",
	"res://art/terrain/hold_flags.png",
]

## **Where the ground is worn through, and how wide.**
##
## A route is a spine the yard has been walked along for years, not a band
## laid on a plan: the wobble is in the authored points rather than added,
## so the same path is drawn every frame and none of it shimmers.
##
## A segment whose two ends stand on different shelves is not drawn at all -
## that gap is where the stair is, and a strip stretched down a bank face
## would be a path painted over a cliff.
const ROUTES: Array[Dictionary] = [
	# The road in, from the gate up the central flight to the plaza and on up the
	# grand stair onto the promontory.
	{"wide": 54.0, "cells": [
		Vector2i(18, 24), Vector2i(18, 22), Vector2i(18, 20), Vector2i(18, 19),
		Vector2i(18, 18), Vector2i(18, 17), Vector2i(18, 16), Vector2i(18, 15),
		Vector2i(18, 14), Vector2i(18, 13), Vector2i(19, 12), Vector2i(19, 11),
		Vector2i(19, 10)]},
	# The plaza itself, west to east past the furnace, the anvil and the market.
	{"wide": 50.0, "cells": [
		Vector2i(7, 14), Vector2i(11, 13), Vector2i(15, 13), Vector2i(19, 12),
		Vector2i(23, 13), Vector2i(26, 14)]},
	# The two side flights down to the lower yard.
	{"wide": 40.0, "cells": [
		Vector2i(11, 14), Vector2i(11, 15), Vector2i(11, 16), Vector2i(11, 17),
		Vector2i(11, 19)]},
	{"wide": 40.0, "cells": [
		Vector2i(24, 14), Vector2i(24, 15), Vector2i(24, 16), Vector2i(24, 18),
		Vector2i(24, 20)]},
	# Up the side stairs onto the two outcrops.
	{"wide": 36.0, "cells": [
		Vector2i(11, 9), Vector2i(10, 9), Vector2i(9, 9), Vector2i(8, 9),
		Vector2i(6, 9)]},
	{"wide": 36.0, "cells": [
		Vector2i(26, 9), Vector2i(27, 9), Vector2i(28, 9), Vector2i(29, 9),
		Vector2i(31, 9)]},
	# The sanctum behind the wall: the Stash, the Chronicle and the Codex.
	{"wide": 44.0, "cells": [
		Vector2i(18, 8), Vector2i(18, 6), Vector2i(18, 5), Vector2i(18, 4),
		Vector2i(14, 4), Vector2i(11, 4)]},
	{"wide": 38.0, "cells": [
		Vector2i(18, 4), Vector2i(22, 4), Vector2i(25, 4)]},
	# Along the pens, and out to the stable and its paddock.
	{"wide": 32.0, "cells": [
		Vector2i(11, 19), Vector2i(14, 19), Vector2i(17, 19), Vector2i(20, 19),
		Vector2i(23, 19)]},
	{"wide": 34.0, "cells": [
		Vector2i(11, 19), Vector2i(9, 20), Vector2i(9, 22)]},
]

## How far the ground keeps going past the walkable yard.
##
## The Warden is clamped to `YARD`; the *picture* is not, and a slab that
## stops where the walking does is a diagram. What is out there is more
## valley, falling into shadow - see `_fall_away`.
const OVERSCAN: float = 620.0

## **The cloth hung about the Hold**, on the wall it was meant to defend, over
## the market, at the gate and either side of the grand stair.
##
## Each names a cell rather than a point, so a banner cannot be hung over a
## cliff; the colours are the Hold's own - the Warden's red, the market's
## faded awning, the smith's soot-dark - rather than a palette invented here.
const BANNERS: Array[Dictionary] = [
	{"cell": Vector2i(15, 6), "cloth": Color(0.52, 0.16, 0.14), "length": 118.0},
	{"cell": Vector2i(22, 6), "cloth": Color(0.52, 0.16, 0.14), "length": 118.0},
	{"cell": Vector2i(17, 10), "cloth": Color(0.44, 0.34, 0.12), "length": 92.0},
	{"cell": Vector2i(21, 10), "cloth": Color(0.44, 0.34, 0.12), "length": 92.0},
	{"cell": Vector2i(24, 12), "cloth": Color(0.46, 0.24, 0.12), "length": 84.0,
		"exposure": 0.7},
	{"cell": Vector2i(10, 12), "cloth": Color(0.22, 0.24, 0.30), "length": 84.0,
		"exposure": 0.7},
	{"cell": Vector2i(17, 18), "cloth": Color(0.52, 0.16, 0.14), "length": 76.0,
		"width": 26.0},
	{"cell": Vector2i(20, 18), "cloth": Color(0.52, 0.16, 0.14), "length": 76.0,
		"width": 26.0},
]

const PADDOCK_AT: Vector2i = Vector2i(9, 22)

## **Far enough in that the last one is on the ground.** Photographed at
## 2026-09-17: four pens from x=180 at 286 apart reach 1163, against a yard
## half-width of 1100 - so Oyelle's pen had a rail and a bird hanging over
## the void. A number that is right for three seats and wrong for four.
const PEN_FIRST: Vector2i = Vector2i(12, 19)
const PEN_SIZE: Vector2 = Vector2(250.0, 180.0)
const PEN_GAP: float = 36.0

## How many cells apart the pens stand, so they are laid on the map rather
## than measured off each other in units the ground knows nothing about.
const PEN_STEP: int = 3

signal entered(station_id: String)
## The Warden walked somewhere. The session relays this; the yard does not.
signal walked(at: Vector2, facing: Vector2)

## The ground itself: the map, the height field, the banks and the flights.
## Everything above it measures the flat plane and asks this where to draw.
var _land: Elevation = null
var _ground: Texture2D = null
var _bank: Texture2D = null
var _steps: Texture2D = null
## What colour the Hold's earth is, so one authored bank belongs to this
## valley. Computed once from the ground the yard is painted with, exactly
## as the raid tints its ledges to the region they are cut out of - a bank
## left untinted is the road's orange soil laid across a green valley, which
## is what the first plate showed.
var _earth: Color = Color(0.62, 0.62, 0.62)
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

## The painted plants standing in the yard, kept so a re-scatter clears the
## last garden rather than growing a second one on top of it.
var _plants: Array[Node] = []

## The cloth and the fire, and the wind that moves both.
##
## A wind of the Hold's own rather than the road's: the road's belongs to a run
## and this is not one. Slow, never still, and read by the banners, the embers
## and the foliage so all three lean together - which is the whole difference
## between a place with air in it and a set.
var _banners: Array[HoldBanner] = []
var _bonfire: HoldBonfire = null
var _wind: Vector2 = Vector2.RIGHT
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
	# **The paths and the worn patches read the ground in world coordinates**,
	# so their UVs run well past one and the texture has to wrap. Left on the
	# default this node clamps to the edge texel, and a whole route comes out
	# as one flat smear of whatever colour happens to be on the right-hand
	# column of the terrain sheet - which is a hard-edged rectangle again,
	# arrived at from the other direction.
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_rng.seed = hash("hold-yard")
	if ResourceLoader.exists(GROUND_ART):
		_ground = load(GROUND_ART) as Texture2D
	if ResourceLoader.exists(BANK_ART):
		_bank = load(BANK_ART) as Texture2D
	if ResourceLoader.exists(STAIR_NORTH_ART):
		_steps = load(STAIR_NORTH_ART) as Texture2D
	var side: Texture2D = null
	if ResourceLoader.exists(STAIR_SIDE_ART):
		side = load(STAIR_SIDE_ART) as Texture2D
	_earth = _earth_tint()
	if ResourceLoader.exists(GRASS_ART):
		_grass = load(GRASS_ART) as Texture2D
	# **The ground goes in first and below everything.** It is a child rather
	# than this node's own `_draw` so that the height field, the banks and the
	# flights are one object a rift can stand up with its own kit - the owner's
	# own "the stair solution should also apply to dungeons".
	_land = Elevation.new()
	_land.name = "Ground"
	# Added so it is owned and freed with the yard, and hidden so its own `_draw`
	# never runs: the Hold paints it into its own canvas instead, which is what
	# puts the ground underneath everything drawn on it.
	_land.visible = false
	add_child(_land)
	_land.set_map(PackedStringArray(MAP), CELL, Balance.HOLD_TERRACE_RISE)
	_land.set_kit(_ground, _bank, _steps, side,
		Color(1.0, 1.02, 0.94), _earth)
	# The valley's own water, which is the jungle pond every Act I road digs:
	# one authored sheet used twice cannot disagree with itself.
	if ResourceLoader.exists(POND_ART):
		_land.set_water(load(POND_ART) as Texture2D)
	for level: int in TILE_ART.size():
		var sheet: String = TILE_ART[level]
		if sheet.is_empty() or not ResourceLoader.exists(sheet):
			continue
		_land.set_tiles(level, load(sheet) as Texture2D)
	_land.set_overscan(OVERSCAN)
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
	_build_bonfire()
	_build_banners()
	set_process(true)


# ------------------------------------------------------------- the terraces


## Which shelf a point stands on, counting up from the lower yard.
## Which shelf a point stands on. Rounded, because the ground between two of
## them is a flight and a flight is on both.
func level_at(point: Vector2) -> int:
	return int(round(_land.height_at(point))) if _land != null else 0


## How far above its own place a point is drawn.
##
## **A rise, never a height.** A Warden's position stays in the flat plane -
## the reach, the focus, the dash, the pens and the relay are all measured
## there and none of them learned that the Hold has shelves. What a shelf
## changes is where a thing is *drawn* and whether a step is allowed, which is
## two small rules instead of a second coordinate system.
func lift_at(point: Vector2) -> float:
	return _land.lift_at(point) if _land != null else 0.0


## Whether a step is one a person could take.
##
## **Slope, not stairs**, and that is the whole of what replaced the stair
## table: `Elevation` allows a climb that is gentle for the distance it covers,
## so a flight passes at two thirds and a cliff is refused at sixteen. Nothing
## in this file knows where a stair is any more.
func step_is_legal(from: Vector2, to: Vector2) -> bool:
	# **The fire is a hole in the yard, not a hazard.** Nothing here burns
	# anybody: the pit is simply ground the Hold refuses, which is the honest
	# answer to "so players cannot go into it to accidentally burn themselves"
	# and costs the run no rule at all.
	if _bonfire != null and is_instance_valid(_bonfire) \
			and _bonfire.refuses(to) and not _bonfire.refuses(from):
		return false
	return _land.step_is_legal(from, to) if _land != null else true


## A step that gives ground rather than sticking against a bank.
func _slide(from: Vector2, to: Vector2) -> Vector2:
	return _land.slide(from, to) if _land != null else to


## The nearest ground to a point, for putting something down. A station or a
## resident authored a cell into the hillside is invisible in a table.
func _on_ground(at: Vector2) -> Vector2:
	return _land.settle(at) if _land != null else at

# ---------------------------------------------------------------- the place


## **Foliage, scattered the way a place grows rather than the way dice fall.**
##
## Owner, 2026-09-17: *"ensure also procedural smart foliage scattering around
## the hold"*. The first cut was `HOLD_GRASS_TUFTS` tufts of one sprite thrown
## at a rectangle, which is a rectangle with confetti on it.
##
## Four rules, and each one is a thing about this place rather than a number:
##
## - **Nothing grows where people walk.** A candidate inside a route's own width
##   is dropped, and so is one standing at a door or in a pen - read from the
##   same tables the paths and the pens are drawn from, so the two can never
##   disagree about where the traffic is.
## - **It thickens toward the rim.** The middle of the square is kept and the
##   ground at the edge of the map is not, so the yard fades into the valley it
##   was cut out of rather than stopping at a line of grass.
## - **The plant suits the ground it is on.** Ferns and creepers in the shade at
##   the foot of a bank, tallgrass and shrubs out on the open floor, flowers
##   only where the Hold is kept - which is what makes the middle read as tended
##   and the outskirts as taken back.
## - **And the same seed grows the same garden**, from the yard's own stream, so
##   nothing shimmers between redraws and no run's dice are touched.
func _scatter_grass() -> void:
	_grass_at.clear()
	for plant: Node in _plants:
		if is_instance_valid(plant):
			plant.queue_free()
	_plants.clear()
	for _index: int in Balance.HOLD_GRASS_TUFTS * 3:
		var at := Vector2(_rng.randf_range(-YARD.x * 0.5, YARD.x * 0.5),
			_rng.randf_range(-YARD.y * 0.5, YARD.y * 0.5))
		if not _is_open_ground(at):
			continue
		# Thicker the further out it is: zero in the middle of the square and one
		# at the rim.
		var out: float = maxf(absf(at.x) / (YARD.x * 0.5),
			absf(at.y) / (YARD.y * 0.5))
		if _rng.randf() > lerpf(Balance.HOLD_FOLIAGE_INNER,
				Balance.HOLD_FOLIAGE_OUTER, out):
			continue
		if _rng.randf() < Balance.HOLD_FOLIAGE_PLANT_SHARE:
			_stand_plant(at, out)
		else:
			_grass_at.append(at)
	# **Sorted by the ground rather than by the draw**, so a tuft on the shelf
	# is drawn before the bank that falls in front of it.
	_grass_at.sort_custom(func(a: Vector2, c: Vector2) -> bool: return a.y < c.y)


## Whether a point is ground nothing else already has a claim on.
func _is_open_ground(at: Vector2) -> bool:
	if _land != null and not _land.is_ground(at):
		return false
	for route: Dictionary in ROUTES:
		var wide: float = float(route["wide"]) + 26.0
		var cells: Array = route["cells"] as Array
		for index: int in cells.size() - 1:
			var from: Vector2 = at_cell(cells[index] as Vector2i)
			var to: Vector2 = at_cell(cells[index + 1] as Vector2i)
			if _near_the_line(at, from, to) < wide:
				return false
	for station: Dictionary in STATIONS:
		if at.distance_to(at_cell(station["cell"] as Vector2i)) < 130.0:
			return false
	for person: Dictionary in RESIDENTS:
		if at.distance_to(at_cell(person["cell"] as Vector2i)) < 90.0:
			return false
	for index: int in Balance.HOLD_SEATS:
		var pen: Vector2 = at_cell(PEN_FIRST + Vector2i(index * PEN_STEP, 0))
		if absf(at.x - pen.x) < PEN_SIZE.x * 0.7 \
			and absf(at.y - pen.y) < PEN_SIZE.y * 0.8:
			return false
	var paddock: Vector2 = at_cell(PADDOCK_AT)
	if absf(at.x - paddock.x) < Balance.STABLE_PADDOCK.x * 0.7 \
		and absf(at.y - paddock.y) < Balance.STABLE_PADDOCK.y * 0.8:
		return false
	return true


## How far a point lies from a stretch of route.
func _near_the_line(at: Vector2, from: Vector2, to: Vector2) -> float:
	var way: Vector2 = to - from
	var span: float = way.length_squared()
	if span < 0.01:
		return at.distance_to(from)
	var along: float = clampf((at - from).dot(way) / span, 0.0, 1.0)
	return at.distance_to(from + way * along)


## One painted plant, chosen by the ground it is standing on.
##
## A plant with no art on disk is simply not stood up, which is the rule every
## sprite in this project lives under: a missing file is a duller Hold, never a
## hole and never an error.
func _stand_plant(at: Vector2, out: float) -> void:
	var shaded: bool = _land != null \
		and _land.height_at(at + Vector2(0.0, -CELL)) > _land.height_at(at) + 0.5
	var pool: Array[String] = Balance.HOLD_FOLIAGE_OPEN
	if shaded:
		pool = Balance.HOLD_FOLIAGE_SHADE
	elif out < 0.42:
		pool = Balance.HOLD_FOLIAGE_KEPT
	var art: String = FOLIAGE_FORMAT % pool[_rng.randi() % pool.size()]
	if not ResourceLoader.exists(art):
		return
	var texture: Texture2D = load(art) as Texture2D
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = true
	sprite.offset = Vector2(0.0, -float(texture.get_height()) * 0.5)
	# The road's own stature rule, so a fern in the Hold is the size of a fern on
	# the battlefield rather than whatever its canvas happens to be.
	sprite.scale = Vector2.ONE * Foliage.painted_scale(texture) \
		* _rng.randf_range(0.82, 1.14)
	sprite.flip_h = _rng.randf() < 0.5
	# It breathes, through the one material every plant in the game shares - so
	# the Hold's ferns lean in the same wind the road's do.
	sprite.material = Foliage.kind_material(Foliage.kind_of(art))
	sprite.position = at + Vector2(0.0, lift_at(at))
	_actors.add_child(sprite)
	_plants.append(sprite)


func _build_stations() -> void:
	for entry: Dictionary in STATIONS:
		var where: Vector2 = _on_ground(at_cell(entry["cell"] as Vector2i))
		var sprite: Sprite2D = _stand(String(entry["art"]), where)
		if sprite == null:
			continue
		var station: Dictionary = entry.duplicate(true)
		station["at"] = where
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
		var art: String = String(entry["art"])
		if not ResourceLoader.exists(art):
			art = String(entry.get("stall", ""))
		var where: Vector2 = _on_ground(at_cell(entry["cell"] as Vector2i))
		var sprite: Sprite2D = _stand(art, where)
		if sprite == null:
			continue
		var person: Dictionary = entry.duplicate(true)
		# **Sized against the Warden rather than against the canvas.**
		# Photographed on 2026-09-17: at their drawn size the four of them stood
		# a head over the players they serve, which reads as a yard of giants
		# with four small heroes in it. One scale for all four, chosen so the
		# tallest sits level with a Warden, so they still differ in height the
		# way people do.
		sprite.scale = Vector2.ONE * Balance.HOLD_RESIDENT_SCALE
		person["node"] = sprite
		# **A flat point of their own, separate from where they are drawn.** The
		# yard has shelves now, so a figure's node sits a terrace's rise above the
		# ground it is standing on - and everything that measures reach, focus or
		# a errand has to keep measuring the ground.
		person["at"] = where
		person["home"] = where
		person["to"] = where
		person["aside"] = _on_ground(at_cell(entry["aside"] as Vector2i))
		person["clock"] = _rng.randf() * 10.0
		person["left"] = _rng.randf_range(Balance.HOLD_NPC_PAUSE.x, Balance.HOLD_NPC_PAUSE.y)
		person["stood_aside"] = false
		# **The same convention every other animated thing in this project
		# uses**, so the art drops in by name and no manifest row or loader is
		# invented for the Hold: `_idle_01` beside the base, `_move_01` beside
		# it. A resident with no frames on disk is a stiller picture rather than
		# a hole - the rule `MountRig` lives under.
		person["idle_frames"] = GameData.load_idle_frames(art)
		person["walk_frames"] = GameData.load_move_frames(art)
		# **A resident at their post is doing their job**, which is the half of
		# "animate their states" that a walk and a breath cannot say: Orden
		# swings a hammer, Maela stacks a crate, Bryn carries feed and Halric
		# works a bridle. `load_state_frames` is the convention this project
		# already has for a named state, so this needed no loader.
		#
		# It deliberately does *not* prepend the base sprite the way an idle
		# does: the pinned last frame is the pose the loop closes on, exactly
		# as a walk keeps its contact pose, and alternating a standing figure
		# with a hammer swing reads as the sprite being swapped rather than
		# animated.
		person["work_frames"] = GameData.load_state_frames(art, "work")
		# Its own phase, so four residents on one clock are not four copies of
		# one loop - the argument `PenYard` and the paddock are both built under.
		person["frame"] = _rng.randf() * 8.0
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
	# Standing on its own shelf. The point handed in is the ground it occupies,
	# which is what everything else measures against; the node is where that
	# ground is drawn.
	sprite.position = at + Vector2(0.0, lift_at(at))
	_actors.add_child(sprite)
	return sprite


## One pen a seat, side by side down the path, each with its own gate and its
## own plate. A Warden sees their own animals in theirs and everybody else's in
## theirs, and may touch nobody's but their own (owner, 2026-09-17).
func _build_pens() -> void:
	for index: int in Balance.HOLD_SEATS:
		# Laid on the map a fixed number of cells apart, so the pens stand on
		# ground the ground agrees exists rather than at an offset measured in
		# units nobody checked against it.
		var at: Vector2 = _on_ground(at_cell(PEN_FIRST
			+ Vector2i(index * PEN_STEP, 0)))
		var pen := PenYard.new()
		pen.name = "Pen%d" % index
		pen.position = at
		_actors.add_child(pen)
		pen.set_stage(PEN_SIZE - Vector2(40.0, 52.0))
		# The yard it is standing in, so it lays that rather than its own
		# opaque floor: two nodes drawing one piece of ground is how the pens
		# went back to being panes after the Hold had already stopped drawing
		# them that way.
		pen.set_ground(_ground)

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
	_paddock.position = _on_ground(at_cell(PADDOCK_AT))
	_actors.add_child(_paddock)
	_paddock.set_stage(Balance.STABLE_PADDOCK)
	# Standing in a yard rather than on a screen: it wears this ground instead
	# of painting its own over it.
	_paddock.stand_in_a_yard(_ground)


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
	_seats[0]["at"] = _on_ground(at_cell(ENTRY))
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
		return _on_ground(at_cell(ENTRY))
	var pick: Dictionary = STATIONS[own.randi() % STATIONS.size()]
	# Settled onto real ground: the yard is a shape now, so a spot a hundred
	# units south of a door can easily be over a bank or off the map.
	return _on_ground(at_cell(pick["cell"] as Vector2i)
		+ Vector2(own.randf_range(-110.0, 110.0), own.randf_range(90.0, 170.0)))


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
## **The fire in the middle of the square, and the stones that keep people out
## of it** (owner, 2026-09-17). Its refusal is read by `step_is_legal`, so the
## wall a player sees and the wall that stops them are the same number.
func _build_bonfire() -> void:
	_bonfire = HoldBonfire.new()
	_bonfire.name = "Bonfire"
	var at: Vector2 = _on_ground(at_cell(FIRE_AT))
	_bonfire.position = at + Vector2(0.0, lift_at(at))
	_actors.add_child(_bonfire)


## Cloth on the wall, at the gate and over the market.
##
## Hung on the map rather than at authored points, so a banner cannot end up
## over a cliff: each names a cell and the colour of whoever hung it.
func _build_banners() -> void:
	for entry: Dictionary in BANNERS:
		var flag := HoldBanner.new()
		var at: Vector2 = at_cell(entry["cell"] as Vector2i)
		flag.position = at + Vector2(0.0, lift_at(at))
		flag.cloth = entry["cloth"] as Color
		flag.shade = (entry["cloth"] as Color).darkened(0.42)
		flag.length = float(entry.get("length", 96.0)) * Balance.HOLD_BANNER_SCALE
		flag.width = float(entry.get("width", 34.0)) * Balance.HOLD_BANNER_SCALE
		flag.exposure = float(entry.get("exposure", 1.0))
		# **No negative z.** A child drawn behind its parent is a child behind
		# the ground as well, which this project has now paid for three times -
		# a mount, a campfire and the Hold's own floor. The banners are actors
		# in a y-sorted layer like everybody else, so one hung further up the
		# yard is simply drawn first.
		_actors.add_child(flag)
		_banners.append(flag)


## The Hold's own weather, turned once a frame and handed to everything that
## answers it.
##
## **One wind, read by three things.** A banner with its own clock and embers
## with theirs would be a yard where the cloth leans east while the smoke goes
## west, which is worse than neither moving at all.
func _turn_the_wind(delta: float) -> void:
	_clock += 0.0
	var turn: float = _clock * Balance.HOLD_WIND_SPEED
	var gust: float = 1.0 + sin(_clock * 0.9) * Balance.HOLD_WIND_GUST
	_wind = Vector2(cos(turn), sin(turn * 0.7) * 0.4) \
		* Balance.HOLD_WIND_STRENGTH * gust
	for flag: HoldBanner in _banners:
		if is_instance_valid(flag):
			flag.set_wind(_wind)
	if _bonfire != null and is_instance_valid(_bonfire):
		_bonfire.set_wind(_wind)
	# The plants lean in it too, through the material every plant in the game
	# shares - so the Hold's ferns answer the same wind its banners do.
	RunState.wind = _wind


func _build_fires() -> void:
	_fires.clear()
	_lights.clear()
	# **Big enough to be the middle of the place.** Photographed at 1.35 it was a
	# torch standing in the open; a campfire is the thing people gather at, and
	# at this scale the yard has a centre after dark rather than merely a
	# midpoint.
	_stand_fire(at_cell(FIRE_AT), Balance.HOLD_FIRE_REACH,
		Balance.HOLD_FIRE_ENERGY, 2.4)
	for cell: Vector2i in TORCHES:
		var at: Vector2 = at_cell(cell)
		_stand_fire(at, Balance.HOLD_TORCH_REACH, Balance.HOLD_TORCH_ENERGY, 0.7)


func _stand_fire(at: Vector2, reach: float, energy: float, size: float) -> void:
	var flame := Flame.new()
	flame.position = at + Vector2(0.0, lift_at(at))
	flame.scale = Vector2(size, size)
	# **Left at zero, which is above the ground.** A node's children draw after
	# its own `_draw`, so the default already puts a fire on top of the yard's
	# painting; `z_index = -1` puts it *under* that painting and the fire is
	# simply not there. The first night plates showed a dark yard with no fire in
	# it - the same trap `mount_shot` records, where the same -1 photographed
	# four Wardens sitting on nothing.
	flame.z_index = 0
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
	return _seats[0]["at"] as Vector2 if not _seats.is_empty() \
		else _on_ground(at_cell(ENTRY))


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
	_turn_the_wind(delta)
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
	var was: Vector2 = seat["at"] as Vector2
	var at: Vector2 = was
	if way.length_squared() > 0.01:
		at += way.normalized() * speed * delta
		seat["facing"] = way.normalized()
	at.x = clampf(at.x, -YARD.x * 0.5 + 40.0, YARD.x * 0.5 - 40.0)
	at.y = clampf(at.y, -YARD.y * 0.5 + 40.0, YARD.y * 0.5 - 40.0)
	# The shelves. A step that would walk off a bank gives ground sideways
	# instead of sticking, and a dash goes through here too - so a Warden
	# cannot dash up an earth face, which is the one way a rule like this gets
	# quietly skipped.
	at = _slide(was, at)
	seat["at"] = at
	var node := seat["node"] as Node2D
	if node != null:
		node.position = at + Vector2(0.0, lift_at(at))
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
		sprite.flip_h = warden.x < (person["at"] as Vector2).x
	else:
		person["left"] = float(person["left"]) - delta
		if float(person["left"]) <= 0.0:
			person["left"] = _rng.randf_range(Balance.HOLD_NPC_PAUSE.x,
				Balance.HOLD_NPC_PAUSE.y)
			person["to"] = home + Vector2(_rng.randf_range(-70.0, 70.0),
				_rng.randf_range(-40.0, 40.0))
	var at: Vector2 = person["at"] as Vector2
	var step: Vector2 = (person["to"] as Vector2) - at
	var walking: bool = step.length() > 4.0
	if walking:
		# Through the same shelf rule the Warden walks under, so a resident on an
		# errand cannot stroll up a bank the player has to find the stair for.
		at = _slide(at, at
			+ step.normalized() * Balance.HOLD_WALK_SPEED * 0.35 * delta)
		sprite.flip_h = step.x < 0.0
	person["at"] = at
	# **What this person is doing, decided in one place.** A resident standing
	# still on their own patch works; one crossing the yard walks; one who
	# has been asked for the tools waits, and one the Warden has walked up
	# to looks up from the bench. It reads the same three facts the movement
	# above read, rather than a flag somebody else has to remember to set.
	#
	# **Standing still is the whole test, and there is deliberately no
	# distance to home in it.** A resident wanders a little way around their
	# own station between errands and never leaves it, so a radius here
	# would be a second, weaker statement of a bound the movement already
	# holds - and the first cut of it left Halric idle for ever at the far
	# end of his own paddock.
	var doing: StringName = &"idle"
	if walking:
		doing = &"walk"
	elif not yielding \
			and warden.distance_to(sprite.position) >= Balance.HOLD_REACH * 1.6:
		doing = &"work"
	person["doing"] = doing
	# Breathing, at the rate the stalls' own people work: a sprite that is
	# perfectly still beside a Warden that is animated reads as a cardboard cut
	# out, and a bob is the whole of the difference at this size.
	sprite.position = at + Vector2(0.0, lift_at(at)
		+ sin(float(person["clock"]) * float(person["beat"]) * 0.02) * 0.9)
	_play_resident(person, delta, doing)


## A resident's own frames, idle or walking.
##
## **The bob stays.** It is not a substitute for frames that have arrived - it is
## what keeps a figure alive on the frame a loop happens to rest on, and it is
## the only motion a resident whose art is still the old stall painting has.
##
## The work loop is the walk's convention rather than the idle's, for the same
## reason: it is a cycle of its own and the standing pose is not part of it. A
## resident with no work frames on disk falls back to breathing where they
## stand, which is what all four of them did before the art arrived.
##
## The walk sequence deliberately does *not* include the base sprite, which is
## the one place `load_move_frames` differs from `load_idle_frames`: the base is
## a person standing, and alternating it with a stride reads as the sprite being
## swapped rather than animated. That was reported once already, about a
## squirrel that "flashes, almost like it is not the same squirrel".
func _play_resident(person: Dictionary, delta: float, doing: StringName) -> void:
	var sprite := person["node"] as Sprite2D
	if sprite == null:
		return
	var frames: Array = person["idle_frames"] as Array
	var rate: float = Balance.HOLD_NPC_FRAME_HZ
	if doing == &"walk":
		frames = person["walk_frames"] as Array
		rate = Balance.HOLD_NPC_WALK_FRAME_HZ
	elif doing == &"work":
		frames = person["work_frames"] as Array
		rate = Balance.HOLD_NPC_WORK_FRAME_HZ
		if frames.is_empty():
			frames = person["idle_frames"] as Array
			rate = Balance.HOLD_NPC_FRAME_HZ
	if frames.is_empty():
		return
	person["frame"] = float(person["frame"]) + delta * rate
	var at: int = int(person["frame"]) % frames.size()
	var texture := frames[at] as Texture2D
	if texture != null and sprite.texture != texture:
		sprite.texture = texture


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


## What a resident is doing - `idle`, `walk` or `work`. For the gate.
##
## The state the yard *decided*, rather than one the gate recomputes from the
## same three facts: a second copy of that rule would agree with the first
## right up until somebody changed one of them.
func doing(id: String) -> StringName:
	for person: Dictionary in _residents:
		if String(person["id"]) == id:
			return person.get("doing", &"idle") as StringName
	return &""


## The frame a resident is drawing right now. For the gate.
##
## A state that is decided and drawn by nothing passes every walk of the art
## folder there is - the `DisciplineEffects` lie in a fourth place - so the
## gate reads the texture off the sprite rather than the flag off the record.
func resident_frame(id: String) -> Texture2D:
	for person: Dictionary in _residents:
		if String(person["id"]) == id:
			var sprite := person["node"] as Sprite2D
			return null if sprite == null else sprite.texture
	return null


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
	var warden: Vector2 = _seats[0]["at"] as Vector2 \
		if not _seats.is_empty() else _on_ground(at_cell(ENTRY))
	var best: String = ""
	var nearest: float = Balance.HOLD_REACH
	for person: Dictionary in _residents:
		var sprite := person["node"] as Sprite2D
		if sprite == null:
			continue
		# **The flat point, never the drawn one.** A resident on a different shelf
		# from the Warden is drawn up to a terrace's rise away from where it is
		# standing, and `HOLD_REACH` is only twice that - so measuring reach off
		# the sprite would make the market unusable from the square.
		var away: float = warden.distance_to(person["at"] as Vector2)
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
		var away: float = warden.distance_to((station["at"] as Vector2) + Vector2(0.0, 40.0))
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
	# **The ground is painted into this canvas rather than onto its own.**
	#
	# `Elevation` is a node so that a rift can stand one up with its own kit,
	# but a child draws *after* its parent - so laid out as a child here it
	# painted straight over the paths, the wall, the pens and every worn patch.
	# Sinking it with a negative `z_index` instead put it behind the screen's
	# own plate and the whole yard vanished, which is the second time a
	# negative z has cost this project a feature.
	#
	# Handing it a canvas to paint into settles the order by saying it, which
	# is also what a dungeon needs: the deep already has a tile layer and wants
	# its banks and flights drawn into that rather than beside it.
	if _land != null:
		_land.paint(self)
	# The ground is `_land`, a child, so it is under everything drawn here.
	_fall_away(half)

	# **The paths are routes now, not bands.** Photographed on 2026-09-17 the
	# widest of them was a 130-unit rectangle across the whole yard with a hard
	# edge down both sides, and at play zoom it read as a river of mud rather
	# than as ground people walk on. That is the same fault the pens and the
	# paddock each had, in the largest shape in the place.
	#
	# A route is a spine with a width, worn through to earth along the middle
	# and fading into the grass at both rims - which is what a path *is*, and
	# what a rectangle can never be, because one colour for the whole shape is
	# exactly what a hard edge is.
	for route: Dictionary in ROUTES:
		var spine: Array = []
		for cell: Variant in route["cells"] as Array:
			spine.append(at_cell(cell as Vector2i))
		_tread(spine, float(route["wide"]))

	# **And the ground is worn where people actually stand.** A yard whose
	# only bare earth is on its roads is a diagram of a yard: what says a
	# place is used is the patch in front of every door and under the boots
	# of somebody who has worked the same spot for years.
	#
	# Read off the stations and the residents rather than authored, so a
	# station moved or added brings its own worn ground with it - the same
	# argument the doors themselves are adopted under.
	for station: Dictionary in _stations:
		var door: Vector2 = station["at"] as Vector2
		_scuff(door + Vector2(0.0, lift_at(door) + 14.0), 62.0,
			Balance.HOLD_SOIL_TINT * Color(1.0, 1.0, 1.0, 0.62))
	for person: Dictionary in _residents:
		var post: Vector2 = person["home"] as Vector2
		_scuff(post + Vector2(0.0, lift_at(post)), 44.0,
			Balance.HOLD_SOIL_TINT * Color(1.0, 1.0, 1.0, 0.70))

	_draw_wall(half)

	_draw_pens()

	for flat: Vector2 in _grass_at:
		var at: Vector2 = flat + Vector2(0.0, lift_at(flat))
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
		# The ground under them, which on a shelf is the shelf's surface rather
		# than the yard's floor.
		var flat: Vector2 = seat["at"] as Vector2
		var stood: Vector2 = flat + Vector2(0.0, lift_at(flat))
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
		lit += Vector2(0.0, lift_at(lit))
		var pulse: float = 0.55 + 0.25 * sin(_clock * 3.4)
		draw_arc(lit, Balance.HOLD_REACH * 0.5, 0.0, TAU, 40,
			Color(0.91, 0.64, 0.24, pulse), 3.0)


## A fence a post at a time, with a gate on the path side: a rectangle of line
## reads as a diagram, and the gap is what says which side you walk in from.
## The shelves themselves: the ground of each, and the earth bank under its
## south edge.
##
## The Hold's own soil, normalised to its own brightness and then darkened -
## a face is the side the sun is not on. Normalising first is what stops a
## dark ground blacking the bank out and a bright one washing it white.
## **The stone the wall is built of, taken from the ground it stands on.**
##
## It was `Color(0.23, 0.22, 0.19)` with the walkway `lightened(0.16)` on top,
## and photographed on 2026-09-17 that walkway was the single brightest thing in
## the Hold - a pale grey band across the whole north edge of a yard painted in
## muted olive. A hand-picked grey cannot know what light a place is in, which
## is exactly why the bank has been tinted from the ground since it was built.
##
## So: the valley's own mean, pulled most of the way to grey because quarried
## stone is not soil, and set to a value a little above the ground's - a wall
## catches the sky and the ground does not. Every other shade in `_wall_length`
## is relative to this one, so the whole structure moves with it.
func _stone_tint() -> Color:
	var mean: Color = _ground_mean()
	var grey: float = (mean.r + mean.g + mean.b) / 3.0
	var stone: Color = mean.lerp(Color(grey, grey, grey),
		Balance.HOLD_WALL_GREY)
	var value: float = maxf(maxf(stone.r, maxf(stone.g, stone.b)), 0.02)
	return stone * (grey * Balance.HOLD_WALL_VALUE / value)


## The average colour of the ground the Hold is painted on, absolutely rather
## than normalised - the bank wants the hue and this wants the light as well.
func _ground_mean() -> Color:
	if _ground == null:
		return Color(0.20, 0.19, 0.15)
	var image: Image = _ground.get_image()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(8, 8, Image.INTERPOLATE_BILINEAR)
	var total := Color(0.0, 0.0, 0.0)
	for y: int in 8:
		for x: int in 8:
			total += image.get_pixel(x, y)
	return total / 64.0


func _earth_tint() -> Color:
	if _ground == null:
		return Color(Balance.HOLD_BANK_SHADE, Balance.HOLD_BANK_SHADE,
			Balance.HOLD_BANK_SHADE)
	var mean: Color = _ground_mean()
	var lift: float = maxf(maxf(mean.r, maxf(mean.g, mean.b)), 0.08)
	return Color(mean.r / lift, mean.g / lift, mean.b / lift) \
		* Balance.HOLD_BANK_SHADE


## **The valley falls into shadow past the rim.**
##
## The ground now runs `OVERSCAN` past the yard, which stops the picture having
## an edge; this is what stops it having a *seam* instead. Four feathered bands
## lie along the four sides, clear where the Warden may walk and near-black out
## at the overscan, so the Hold reads as a cut in a hillside with the light
## falling off rather than as a lit rectangle with more ground beside it.
##
## Drawn in `_draw`, so it is under every actor: this is shade on the earth,
## and a person standing in it is standing in it.
##
## A colour per vertex again, for the reason everything soft-edged here is: one
## colour for the whole shape *is* a hard edge.
func _fall_away(half: Vector2) -> void:
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	var dark := Color(0.02, 0.03, 0.02, 0.92)
	var out: float = OVERSCAN
	# **The crest, not the plan.** The yard is a flat plane that is *drawn*
	# lifted, so the top of the picture is a whole stack of rises above
	# `-half.y` - a band laid at the flat edge sat well inside the ground and
	# showed as a hard line across the sky end of the Hold.
	var crest: float = -half.y - float(Elevation.LEVEL.size() - 1) \
		* Balance.HOLD_TERRACE_RISE
	var points: PackedVector2Array = []
	var colours: PackedColorArray = []
	var indices: PackedInt32Array = []
	# Inside edge, outside edge - one band a side, sharing no vertices so the
	# corners simply overlap and go darker, which is what a corner does.
	var bands: Array[Array] = [
		[Vector2(-half.x, crest), Vector2(half.x, crest),
			Vector2(half.x, crest - out), Vector2(-half.x, crest - out)],
		[Vector2(-half.x, half.y), Vector2(half.x, half.y),
			Vector2(half.x, half.y + out), Vector2(-half.x, half.y + out)],
		[Vector2(-half.x, crest - out), Vector2(-half.x, half.y + out),
			Vector2(-half.x - out, half.y + out), Vector2(-half.x - out, crest - out)],
		[Vector2(half.x, crest - out), Vector2(half.x, half.y + out),
			Vector2(half.x + out, half.y + out), Vector2(half.x + out, crest - out)],
	]
	for band: Array in bands:
		var base: int = points.size()
		for corner: int in 4:
			points.append(band[corner] as Vector2)
			colours.append(clear if corner < 2 else dark)
		indices.append_array([base, base + 1, base + 2,
			base, base + 2, base + 3])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours)

## A trodden route, through the one definition three nodes here share.
##
## The spine is a plain `Array` of `Vector2` rather than a packed one because
## `PackedVector2Array([...])` is **not a constant expression** in GDScript -
## the same finding `PackedStringArray([...])` cost this project once already.
func _tread(spine: Array, wide: float) -> void:
	GroundWear.tread(get_canvas_item(), _ground, spine, wide,
		Balance.HOLD_SOIL_TINT, lift_at)


## A patch of ground worn bare - inside a pen, in front of a door, at the feet
## of somebody who stands in one place all day.
func _scuff(at: Vector2, wide: float, tint: Color) -> void:
	GroundWear.patch(get_canvas_item(), _ground, at, wide, tint)

## The wall that was never finished (see `world_first_cut`): it runs out
## halfway across, which is the one thing about this place a player should be
## able to read without being told.
##
## **Courses rather than a rectangle.** Photographed on 2026-09-17 it was a
## flat grey bar across the top of the yard and read as an interface element
## laid over the painting - the same fault the pens and the paddock each had,
## in the one place a player looks to find out what this camp is.
## **A wall has a top and a side, and it stands where the ground says.**
##
## Photographed twice as a flat band of one thickness across the top of the
## screen, which is why it has a lit walkway, a shadowed face under it and
## merlons breaking the top line - the three things that separate masonry from a
## ruled rectangle at this size.
##
## **And it is laid on the map rather than at an authored y.** The sanctum is a
## blob now, so the wall follows its northern lip: every cell whose north
## neighbour is hillside gets a course, which means a wall that can never sit in
## front of the shelf it is meant to be defending. It runs out partway along,
## because it was never finished (see `world_first_cut`).
func _draw_wall(_half: Vector2) -> void:
	var lip: Array[Vector2i] = []
	for x: int in MAP_W:
		for y: int in MAP_H:
			if _mark(Vector2i(x, y)) != "2":
				continue
			if _mark(Vector2i(x, y - 1)) == " ":
				lip.append(Vector2i(x, y))
			break
	if lip.is_empty():
		return
	var stone: Color = _stone_tint()
	var cap: float = 20.0
	var tall: float = 58.0
	var built: int = int(float(lip.size()) * 0.62)
	for index: int in lip.size():
		var middle: Vector2 = at_cell(lip[index])
		var top: float = middle.y - CELL * 0.5 + lift_at(middle)
		var west: float = middle.x - CELL * 0.5
		if index < built:
			_wall_length(west, top, CELL, cap, tall, stone)
			continue
		# The broken end: courses falling away, each with its own lit walkway, so
		# the wall runs out rather than stopping.
		var lost: float = minf(float(index - built) * 11.0, cap + tall - 6.0)
		var stub := Rect2(west + 8.0, top + lost, CELL - 16.0, cap + tall - lost)
		draw_rect(stub, stone.darkened(0.42), true)
		draw_rect(Rect2(stub.position.x, stub.position.y, stub.size.x,
			minf(cap, stub.size.y)), stone.lightened(0.10), true)
	var first: Vector2 = at_cell(lip[0])
	var last: Vector2 = at_cell(lip[mini(built, lip.size() - 1)])
	_wall_shadow(first.x - CELL * 0.5, last.x + CELL * 0.5,
		first.y - CELL * 0.5 + lift_at(first) + cap + tall)


## One cell of wall: merlons above, a lit walkway, and a shadowed face with its
## courses showing.
func _wall_length(west: float, top: float, span: float, cap: float,
		tall: float, stone: Color) -> void:
	var step: float = span * 0.5
	var at: float = west
	var tooth: int = int(absf(west) / step) % 3
	while at < west + span - 1.0:
		if tooth % 3 != 2:
			var high: float = 22.0 + sin(at * 0.03) * 3.0
			var merlon := Rect2(at + 4.0, top - high, step - 10.0, high + 4.0)
			draw_rect(merlon, stone.darkened(0.30), true)
			draw_rect(Rect2(merlon.position.x + 3.0, merlon.position.y + 3.0,
				merlon.size.x - 6.0, merlon.size.y - 8.0),
				stone.lightened(0.10), true)
		at += step
		tooth += 1
	draw_rect(Rect2(west, top, span, cap), stone.lightened(0.16), true)
	var face := Rect2(west, top + cap, span, tall)
	draw_rect(face, stone.darkened(0.42), true)
	var course: float = tall / 3.0
	for row: int in 3:
		var y: float = face.position.y + float(row) * course
		var along: float = west - (0.0 if row % 2 == 0 else 24.0)
		while along < face.end.x:
			var block := Rect2(along + 3.0, y + 3.0, 44.0, course - 5.0)
			var shade: float = 0.03 + 0.04 * float(int(absf(along) / 48.0) % 3)
			draw_rect(block.intersection(face), stone.darkened(0.30 - shade), true)
			along += 48.0


## What the map says is at a cell.
func _mark(cell: Vector2i) -> String:
	if cell.y < 0 or cell.y >= MAP.size():
		return " "
	var row: String = MAP[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return " "
	return row[cell.x]


## The line of shade the wall throws on the yard in front of it: strongest at
## the foot and gone a stride out, which is what puts a standing thing on the
## ground rather than on top of the picture.
func _wall_shadow(west: float, east: float, foot: float) -> void:
	var deep: float = 34.0
	var dark := Color(0.0, 0.0, 0.0, 0.42)
	var clear := Color(0.0, 0.0, 0.0, 0.0)
	var points := PackedVector2Array([Vector2(west, foot), Vector2(east, foot),
		Vector2(east, foot + deep), Vector2(west, foot + deep)])
	var colours := PackedColorArray([dark, dark, clear, clear])
	var indices := PackedInt32Array([0, 1, 2, 0, 2, 3])
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(),
		indices, points, colours)

func _draw_pens() -> void:
	var timber := Color(0.38, 0.29, 0.19)
	for pen: Dictionary in _pens:
		var at: Vector2 = pen["at"] as Vector2
		var box := Rect2(at - PEN_SIZE * 0.5, PEN_SIZE)
		# **Trodden ground rather than a flat fill.** Photographed on
		# 2026-09-17: four pens drawn as one translucent colour read as green
		# boxes laid on the yard, which is most of what the owner meant by the
		# Hold needing to be *"way more aesthetically appealing"*. The yard's own
		# ground texture, darkened and worn toward the middle where the animals
		# actually stand, is a *place* rather than a rectangle - and it costs one
		# more textured rect, because the texture is already loaded.
		if _ground != null:
			draw_texture_rect(_ground, box, true, Color(0.52, 0.55, 0.44))
		else:
			draw_rect(box, Color(0.20, 0.21, 0.15, 0.55), true)
		# The worn patch: earth the grass has gone from, softest at the rail and
		# bare in the middle.
		#
		# **It was three flat ellipses and they wiped the texture out.** The
		# widest was 0.58 of the pen's *width* against a half-height of 90, so
		# all three covered the whole box - a flat film at forty percent alpha
		# over ground that had just been drawn as earth, which photographed as
		# precisely the pane of glass the textured rect was added to stop.
		_scuff(box.get_center(), box.size.x * 0.40,
			Balance.HOLD_SOIL_TINT * Color(1.0, 1.0, 1.0, 0.94))
		# **A far rail as well as a near one, and that is a correction.**
		#
		# The first cut drew the near side only, reasoning that a closed
		# rectangle puts a fence between the player and the animals. Photographed,
		# that is wrong in the other direction: a pen fenced on one edge reads as
		# a rectangle of paint with a comb under it, and there is nothing to say
		# where the pen *ends*. The far rail is drawn first and low, so it sits
		# behind whatever is standing in the pen, and the near one in front.
		var far_posts: int = 9
		var far_span: float = box.size.x / float(far_posts)
		for index: int in far_posts + 1:
			var back := Vector2(box.position.x + far_span * float(index),
				box.position.y)
			_fence_post(back, 18.0, timber.darkened(0.25))
			if index > 0:
				_fence_rail(back - Vector2(far_span, 13.0),
					back - Vector2(0.0, 13.0), timber.darkened(0.25))
		# The gate is the two missing posts in the middle of the near rail,
		# which is the whole of "there is a way in".
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
			return person["at"] as Vector2
	for station: Dictionary in _stations:
		if String(station["id"]) == _focus:
			return station["at"] as Vector2
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
			return (station["at"] as Vector2) + Vector2(0.0, 70.0)
	return Vector2.INF


func station_ids() -> Array[String]:
	var out: Array[String] = []
	for station: Dictionary in _stations:
		out.append(String(station["id"]))
	return out


func pens() -> int:
	return _pens.size()
