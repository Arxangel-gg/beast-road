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
const TURF_SHADER: String = "res://scripts/shaders/hold_grass.gdshader"
const FOLIAGE_FORMAT: String = "res://art/foliage/plant_jungle_%s.png"
const PROP_FORMAT: String = "res://art/foliage/prop_%s.png"

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
	# **The pond, which is a place rather than a door.** Owner, 2026-09-17:
	# *"players can also only fish for up to 3 fish every 10 minutes at their
	# Hold's pond."* It has no button to press because there is no screen: the
	# Hold answers it itself, exactly as the Warden's Stone and the road out do.
	#
	# Standing on the shore rather than in the water: the pool is not walkable,
	# so the reeds mark the one edge of it a person can reach.
	{"id": "pond", "door": "", "art": "res://art/foliage/prop_reeds.png",
		"label": "The Pond", "cell": Vector2i(26, 14)},
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
const FIRE_AT: Vector2i = Balance.HOLD_FIRE_CELL
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

## The field itself. One node and one draw call for the lot - see
## `HoldGrass`, which is also where a blade learns to give way to a boot.
var _grass_field: HoldGrass = null

## The lawn: one quad over the whole yard with `hold_grass.gdshader` on it, laid
## between the ground and everything standing on it. See `Balance.HOLD_TURF_BLADE`.
var _turf: ColorRect = null

## What the hooves leave behind. One node for every mark in the yard - see
## `GroundMarks`, which also samples the colour off the ground it is laid on.
var _marks: GroundMarks = null
## Where everybody's feet were last frame, for `_tick_treads`.
var _treads: Dictionary = {}

## How far the Warden has ridden since the last hoof fall, so a trail is laid by
## distance rather than by a clock and is the same density at any speed.
var _hoof_left: float = 0.0

## The little hop a rider takes when they come off a moving horse, and how fast
## they were going when they did.
var _land_left: float = 0.0
var _land_hard: float = 0.0

## One reading per sheet. Measuring an image every hoof fall would be a resize
## and sixteen pixel reads forty times a second.

## The painted plants standing in the yard, kept so a re-scatter clears the
## last garden rather than growing a second one on top of it.
var _plants: Array[Node] = []

## The scattered things that carry idle frames of their own, ticked together so
## a yard of them is not a yard of `_process` callbacks.
var _breathers: Array[Sprite2D] = []

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

## The Hold's own fog. See `Balance.HOLD_FOG_WARDEN`.
var _fog: FogOfWar = null
var _fires: Array[Node2D] = []
var _lights: Array[PointLight2D] = []
## The shadows, the window light and the embers. See `HoldGlow`.
var _glow: HoldGlow = null
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
	# **The lawn goes down before anything stands on it.** A child draws after
	# its parent, so a quad added here is over the ground this node paints and
	# under everything in `_actors` - which is the order grass is actually in.
	_build_turf()
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
	_build_fog()
	_marks = GroundMarks.new()
	_marks.name = "Marks"
	_marks.ground = _ground_colour
	# Under the actors and over the ground: dust settles on the earth and people
	# walk through it.
	_actors.add_child(_marks)
	_actors.move_child(_marks, 0)
	# **The Hold's light and its air.** Built after the stations so it has
	# windows to light, and before the fires so it has something to throw
	# embers over.
	_glow = HoldGlow.new()
	_actors.add_child(_glow)
	_actors.move_child(_glow, 1)
	_glow.light_stations(_stations)
	_build_fires()
	_build_bonfire()
	_build_banners()
	_build_houses()
	if _glow != null:
		_glow.over_fires(_fires)
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
	_breathers.clear()
	for _index: int in Balance.HOLD_GRASS_BLADES:
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
		if _rng.randf() < Balance.HOLD_PROP_SHARE:
			_stand_prop(at, out)
		elif _rng.randf() < Balance.HOLD_FOLIAGE_PLANT_SHARE:
			_stand_plant(at, out)
		else:
			_grass_at.append(at)
	# **One node for the whole field.** It was a sprite drawn per tuft in this
	# node's own `_draw`, which is fine for a hundred and is the frame for a few
	# thousand - and a hundred tufts on a yard this size is what the owner meant
	# by bare. `HoldGrass` is one triangle array, and it is also where a blade
	# learns to give way to a boot.
	if _grass_field == null:
		_grass_field = HoldGrass.new()
		_grass_field.name = "Grass"
		_grass_field.sheet = _grass
		_grass_field.walkers = _who_is_walking
		_actors.add_child(_grass_field)
	var lifted: Array[Vector2] = []
	for flat: Vector2 in _grass_at:
		lifted.append(flat + Vector2(0.0, lift_at(flat)))
	_grass_field.set_field(lifted)


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


## One of the things a place accumulates, chosen by how far out it is.
##
## Close in is what a camp puts down - a cairn, a signpost, split wood; far out
## is what the valley left and nobody has cleared. That split is the whole of
## why this is not one list: a wreck in the middle of the square says nobody
## lives here and a signpost at the treeline says nothing at all.
func _stand_prop(at: Vector2, out: float) -> void:
	var pool: Array[String] = Balance.HOLD_PROPS_WILD if out > 0.52 \
		else Balance.HOLD_PROPS_KEPT
	var art: String = PROP_FORMAT % pool[_rng.randi() % pool.size()]
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
	sprite.scale = Vector2.ONE * _rng.randf_range(0.86, 1.18)
	sprite.flip_h = _rng.randf() < 0.5
	# A prop with idle frames of its own breathes; one without simply stands.
	# Mushrooms are the only shared prop that carries them, and a scatter that
	# refused to animate what it could would be leaving motion on the disk.
	var frames: Array[Texture2D] = GameData.load_idle_frames(art)
	if frames.size() > 1:
		sprite.set_meta("idle_frames", frames)
		sprite.set_meta("idle_clock", _rng.randf() * 9.0)
		_breathers.append(sprite)
	sprite.position = at + Vector2(0.0, lift_at(at))
	_actors.add_child(sprite)
	_plants.append(sprite)


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
		# **You can see through what you are standing behind.** Owner,
		# 2026-09-17: *"some buildings may have ceilings that fade when players
		# enter them"*. These are single paintings rather than a shell and a
		# roof, so what fades is the structure - which is what the town core has
		# done since it was built, and against a yard that sorts by Y it reads
		# as walking *into* a building rather than behind one.
		var fade := Occluder.new()
		fade.sprite = sprite
		fade.behind_margin = Balance.HOLD_OCCLUDE_MARGIN
		sprite.add_child(fade)
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


## **A different crowd every visit** (owner, 2026-09-22: the Wardens in the
## Hold *"need random procedural variations for each visit"*).
##
## Keyed on the play code alone, the same three strangers with the same three
## pens and the same two dyes stood in the same Hold for the life of the
## account. The salt is drawn once when the yard is built and every simulated
## thing hangs off it, so a visit is a crowd rather than a photograph.
##
## **One key, asked for rather than recomputed.** The name, the pen and the
## dye are all drawn from this string, and `HoldSession` asks the yard for it
## rather than building its own - two spellings of it is how the Warden called
## Marrow ends up standing over somebody else's animals, which the note on
## `_simulated_pen` already warns about.
func sim_key(index: int) -> String:
	# Built before `_build_seats` has run - a caller asking early gets a
	# stable key rather than an empty one.
	return "%s:%s:%d" % [MetaState.play_code, _visit, index]


func _build_seats() -> void:
	_seats.clear()
	# Not the run's stream: this is decoration, and a draw on a named stream
	# moves every roll after it. The clock is the salt, which is also what
	# makes it different on the next visit.
	_visit = str(Time.get_ticks_usec())
	for index: int in Balance.HOLD_SEATS:
		_seats.append(_stand_warden(index))
	_seats[0]["kind"] = HoldSession.Seat.LOCAL
	_seats[0]["name"] = MetaState.player_name if not MetaState.player_name.is_empty() else "Oathless"
	_seats[0]["at"] = _on_ground(at_cell(ENTRY))
	_place(_seats[0])
	for index: int in range(1, _seats.size()):
		_seats[index]["kind"] = HoldSession.Seat.SIMULATED
		_seats[index]["name"] = SIM_NAMES[
			absi(hash(sim_key(index))) % SIM_NAMES.size()]
		# Its own wandering is seeded from the visit too, so two visits are not
		# the same three people walking the same three errands.
		var own := _seats[index]["rng"] as RandomNumberGenerator
		if own != null:
			own.seed = absi(hash("hold-seat:" + sim_key(index)))
		_place(_seats[index])
	_relabel()


## What a simulated Warden is up to where it stopped. See `_errand`.
enum Errand {
	## Standing and looking at it: the fire, the paddock rail.
	WATCH,
	## Working: one swing of the heavy sheet, every few seconds.
	WORK,
	## Beside somebody: turned to face them, and they turn back.
	TALK,
}


## The salt every simulated thing in this visit is drawn from. See `sim_key`.
var _visit: String = "0"


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

	# **The Warden's own mount, if they have one saddled.** Owner, 2026-09-17.
	# Only the player's seat: the other three are presence rather than accounts,
	# and `MetaState.saddled_mount()` read for somebody else's Warden returns
	# this player's own - which is the same reason the road relays a mount's id
	# rather than working it out locally.
	var rig: MountRig = null
	if index == 0:
		var saddled: MountData = MetaState.saddled_mount()
		if saddled != null:
			rig = MountRig.new()
			rig.rider = sprite
			root.add_child(rig)
			rig.show_mount(saddled)
			rig.visible = false

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
		"rig": rig,
		"riding": false,
		"tag": tag,
		"at": home,
		"to": home,
		"facing": Vector2.DOWN,
		"rng": own,
		"left": own.randf_range(Balance.HOLD_NPC_PAUSE.x, Balance.HOLD_NPC_PAUSE.y),
		"doing": Errand.WATCH,
		"busy": 0.0,
	}


## What a simulated Warden does where it stopped.
##
## **Presentation, and read by nothing.** A swing at the forge deals no damage,
## makes nothing and presses no door - it is the same distinction `PenYard` is
## drawn under, and turning every one of these off would leave the Hold
## identical apart from three figures standing still.
func _busy(seat: Dictionary, delta: float) -> void:
	seat["busy"] = float(seat["busy"]) - delta
	if float(seat["busy"]) > 0.0:
		return
	var own := seat["rng"] as RandomNumberGenerator
	match int(seat["doing"]):
		Errand.WORK:
			var animator := seat["animator"] as HeroAnimator
			if animator != null:
				# The heavy sheet, which is what the Warden's own work swing
				# uses: at this size an axe into a trunk and a hammer onto an
				# anvil are the same body doing the same thing.
				animator.play("attack_3", true)
			seat["busy"] = own.randf_range(Balance.HOLD_NPC_WORK_GAP.x,
				Balance.HOLD_NPC_WORK_GAP.y)
		Errand.TALK:
			# **Both of them turn.** One figure facing another who is facing
			# away is somebody being ignored; the pair reads as a conversation
			# only when the other looks back, so the nearest other simulated
			# Warden is turned round too - never a real seat, whose facing is
			# its own machine's to say.
			var at: Vector2 = seat["at"] as Vector2
			var best: Dictionary = {}
			var near: float = 260.0
			for index: int in range(1, _seats.size()):
				var other: Dictionary = _seats[index]
				if other == seat or int(other["kind"]) != HoldSession.Seat.SIMULATED:
					continue
				var gap: float = ((other["at"] as Vector2) - at).length()
				if gap < near:
					near = gap
					best = other
			if not best.is_empty():
				best["facing"] = (at - (best["at"] as Vector2)).normalized()
			seat["busy"] = own.randf_range(Balance.HOLD_NPC_WORK_GAP.x,
				Balance.HOLD_NPC_WORK_GAP.y)
		_:
			seat["busy"] = 1.0


## Somewhere a Warden might plausibly be standing: in front of one of the
## buildings rather than anywhere in the rectangle. A figure standing in the
## middle of an empty yard reads as a bug.
## **Where a simulated Warden goes next, and it is an errand rather than a
## wander** (owner, 2026-09-22: *"the players should occasionally also try to
## do things like to certain interactables on the Hold's map or other NPCs and
## interact with them"*).
##
## Four kinds of destination, weighted: a station's door, the paddock rail,
## the fire, and somebody else - another seat or a resident. The old version
## drew a station every time and stood a hundred and thirty units south of it,
## which reads as milling about rather than as going to the forge.
##
## Still only a *place*: nothing here presses a button, opens a door or writes
## anything. A simulated Warden is presence, which is the bound the seats were
## built under, and standing at the anvil is the whole of what presence looks
## like.
func _somewhere(own: RandomNumberGenerator) -> Vector2:
	return _errand(own)["at"] as Vector2


## The same choice, saying what kind of thing was chosen.
##
## **What arriving means differs by errand** (owner, 2026-09-22: they should
## *"try to do things like to certain interactables ... or other NPCs and
## interact with them"*). At a station a Warden works - one swing of the heavy
## sheet, which is exactly what `Hero.play_work_swing` uses for an axe into a
## trunk. Beside somebody they turn to face them. At the fire and the rail they
## simply stand, because that is what standing at a fire looks like.
##
## Still only presence: nothing here presses a button, opens a door or writes
## anything, which is the bound the seats were built under.
func _errand(own: RandomNumberGenerator) -> Dictionary:
	var roll: float = own.randf()
	if roll < 0.26 and not _pens.is_empty():
		var pen: Dictionary = _pens[own.randi() % _pens.size()]
		return {"at": _on_ground((pen["at"] as Vector2)
			+ Vector2(own.randf_range(-70.0, 70.0), own.randf_range(70.0, 120.0))),
			"doing": Errand.WATCH}
	if roll < 0.40:
		return {"at": _on_ground(at_cell(FIRE_AT)
			+ Vector2(own.randf_range(-110.0, 110.0), own.randf_range(40.0, 110.0))),
			"doing": Errand.WATCH}
	if roll < 0.60:
		var people: Array[Vector2] = []
		for other: Dictionary in _residents:
			people.append(other["home"] as Vector2)
		for index: int in range(1, _seats.size()):
			if int(_seats[index]["kind"]) != HoldSession.Seat.EMPTY:
				people.append(_seats[index]["at"] as Vector2)
		if not people.is_empty():
			return {"at": _on_ground(people[own.randi() % people.size()]
				+ Vector2(own.randf_range(-90.0, 90.0), own.randf_range(30.0, 80.0))),
				"doing": Errand.TALK}
	if STATIONS.is_empty():
		return {"at": _on_ground(at_cell(ENTRY)), "doing": Errand.WATCH}
	var pick: Dictionary = STATIONS[own.randi() % STATIONS.size()]
	# Close enough to the door to read as *at* it. Settled onto real ground,
	# because the yard is a shape and a spot south of a door is easily over a
	# bank or off the map.
	return {"at": _on_ground(at_cell(pick["cell"] as Vector2i)
		+ Vector2(own.randf_range(-52.0, 52.0), own.randf_range(72.0, 104.0))),
		"doing": Errand.WORK}


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
## **The fog, and the things that hold it open.**
##
## The Warden carries a lantern's worth of it; every station and every fire
## holds its own doorway lit, which is the owner's "essentials lit up". What is
## left dim is the hillside between them, which is what gives a yard this size
## a middle and an edge.
##
## Most of it is already explored on arrival: this is home. A Hold that opened
## black would be a fog that punishes rather than one that lights.
## The lawn, and the mask that says where it grows.
##
## **One texel a cell.** Grass grows on the valley floor and on the plaza and
## nowhere else - not on the flagstone sanctum, not on water, not on the
## hillside - and sampling that mask linearly is what gives the lawn a soft
## boundary instead of the cell grid. The shader is told *where*, never *what*:
## it has no idea a sanctum exists.
func _build_turf() -> void:
	if not ResourceLoader.exists(TURF_SHADER):
		return
	var across: int = MAP_W
	var down: int = MAP_H
	var mask := Image.create(across, down, false, Image.FORMAT_L8)
	for y: int in down:
		for x: int in across:
			var ch: String = _mark(Vector2i(x, y))
			# Level 2 is cut stone and grows nothing; water and hillside grow
			# nothing either. A flight is earth and stone, so it gets a little.
			var grows: float = 0.0
			if ch == "1":
				grows = 1.0
			elif ch == ".":
				# The valley floor is mossy stone rather than lawn: it carries
				# grass, thinly, the way ground nobody tends does.
				grows = 0.55
			elif Elevation.WAY.has(ch):
				grows = 0.25
			# **Nothing grows where people walk.** Read off the same routes the
			# paths are drawn from, so the lawn and the trodden earth cannot
			# disagree about where the traffic is - grass over a path is the
			# single clearest way to say a place is not used.
			if grows > 0.0 and not _is_off_the_routes(at_cell(Vector2i(x, y))):
				grows *= 0.08
			mask.set_pixel(x, y, Color(grows, grows, grows))
	var material := ShaderMaterial.new()
	material.shader = load(TURF_SHADER) as Shader
	material.set_shader_parameter("cover", ImageTexture.create_from_image(mask))
	material.set_shader_parameter("world_origin",
		Vector2(-YARD.x * 0.5, -YARD.y * 0.5))
	material.set_shader_parameter("world_size", YARD)
	material.set_shader_parameter("blade", Balance.HOLD_TURF_BLADE)
	material.set_shader_parameter("sway", Balance.HOLD_TURF_SWAY)
	material.set_shader_parameter("ripple", Balance.HOLD_TURF_RIPPLE)
	material.set_shader_parameter("tip", Balance.HOLD_TURF_TIP)
	material.set_shader_parameter("root", Balance.HOLD_TURF_ROOT)
	material.set_shader_parameter("strength", Balance.HOLD_TURF_STRENGTH
		* Graphics.foliage_scale())
	_turf = ColorRect.new()
	_turf.name = "Turf"
	_turf.color = Color.WHITE
	_turf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# **The quad is the flat plane, not the drawn one.** The lawn is laid on the
	# ground and the ground is drawn lifted per shelf; laying the carpet at the
	# lift as well would slide it off the shelf it belongs to. Every shelf is
	# lifted from the same plane, so one quad over the plane is right for all of
	# them - which is also why this needs no knowledge of the terraces at all.
	_turf.position = Vector2(-YARD.x * 0.5, -YARD.y * 0.5
		- float(Elevation.LEVEL.size()) * Balance.HOLD_TERRACE_RISE)
	_turf.size = YARD + Vector2(0.0,
		float(Elevation.LEVEL.size()) * Balance.HOLD_TERRACE_RISE)
	_turf.material = material
	add_child(_turf)


## Whether a point is clear of every route. The paths' own widths, so the lawn
## and the trodden earth read the same table.
func _is_off_the_routes(at: Vector2) -> bool:
	for route: Dictionary in ROUTES:
		var wide: float = float(route["wide"]) + 18.0
		var cells: Array = route["cells"] as Array
		for index: int in cells.size() - 1:
			if _near_the_line(at, at_cell(cells[index] as Vector2i),
					at_cell(cells[index + 1] as Vector2i)) < wide:
				return false
	return true


func _build_fog() -> void:
	if not Graphics.fog_of_war():
		return
	_fog = FogOfWar.new()
	_fog.half_extent = maxf(YARD.x, YARD.y) * 0.5 + OVERSCAN
	_fog.cell = CELL
	_fog.sources = _fog_sources
	add_child(_fog)
	_fog.prime_explored(maxf(YARD.x, YARD.y) * 0.5 * Balance.HOLD_FOG_KNOWN)


## What can see, and how far. Read rather than registered, so a station added
## tomorrow lights its own door without anybody remembering this.
## Everybody standing in the yard, for the grass to lean away from.
##
## The seats rather than only the player: in a Hold with four Wardens in it,
## grass that parted for one of them and stood up through the other three would
## be worse than grass that never moved.
func _who_is_walking() -> Array:
	var feet: Array = []
	for seat: Dictionary in _seats:
		if int(seat.get("kind", 0)) == HoldSession.Seat.EMPTY:
			continue
		var at: Vector2 = seat["at"] as Vector2
		feet.append(at + Vector2(0.0, lift_at(at)))
	for person: Dictionary in _residents:
		var at: Vector2 = person["at"] as Vector2
		feet.append(at + Vector2(0.0, lift_at(at)))
	return feet


## What colour the ground is at a point, for anything that has to match it.
##
## Read off the sheet the shelf is actually laid with rather than a table: the
## plaza is turf, the sanctum is flagstone and the lower yard is the valley
## floor, and a dust colour that knew about only one of them would be wrong in
## two thirds of the Hold.
func _ground_colour(at: Vector2) -> Color:
	var level: int = level_at(at)
	var sheet: Texture2D = _ground
	if level >= 0 and level < TILE_ART.size():
		var named: String = TILE_ART[level]
		if not named.is_empty() and ResourceLoader.exists(named):
			sheet = load(named) as Texture2D
	# **The reading itself lives in one place now.** This function used to carry
	# its own four-by-four mean and its own cache, and when the battlefield and
	# the arenas needed the same answer on 2026-09-17 the obvious thing was to
	# write it again there - which would have been two answers to "what colour is
	# the earth somebody is standing on", drifting apart the first time either
	# was tuned. `GroundTone` is this code, moved rather than copied. What stays
	# here is the part that is genuinely the Hold's: *which sheet* is under this
	# point, which no other scope has shelves to ask about.
	return GroundTone.of(sheet)


func _fog_sources() -> Array:
	var seen: Array = []
	for seat: Dictionary in _seats:
		if int(seat.get("kind", 0)) == HoldSession.Seat.EMPTY:
			continue
		seen.append({"at": seat["at"] as Vector2,
			"radius": Balance.HOLD_FOG_WARDEN})
	for station: Dictionary in _stations:
		seen.append({"at": station["at"] as Vector2,
			"radius": Balance.HOLD_FOG_STATION})
	seen.append({"at": at_cell(FIRE_AT), "radius": Balance.HOLD_FOG_FIRE})
	for cell: Vector2i in TORCHES:
		seen.append({"at": at_cell(cell), "radius": Balance.HOLD_FOG_FIRE * 0.6})
	return seen


func _build_sky() -> void:
	_sky = CanvasModulate.new()
	_sky.name = "HoldSky"
	add_child(_sky)
	_follow_the_sun()


func _follow_the_sun() -> void:
	if _sky == null or not is_instance_valid(_sky):
		return
	# **The Hold's own grade on top of the sun's.** Owner, 2026-09-17: *"the
	# Hold needs more color grading and tint applied to assets"*. A hub cut
	# into a shaded valley reads warmer and deeper than the open road, and this
	# is the one place that can be said once for every asset in it - the
	# buildings, the cloth, the people and the props all hang under this node.
	var tint: Color = DayNight.tint * Balance.HOLD_GRADE
	tint = Color(tint.r, tint.g, tint.b).lerp(
		Color(tint.r, tint.g, tint.b) * Balance.HOLD_GRADE_DEPTH, 0.5)
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
## The scattered props that have frames, each on its own clock.
##
## One loop here rather than a `_process` on each: a yard holds dozens of these
## and a script per mushroom is dozens of callbacks for a thing nobody clicks.
## **The people in the Hold scuff the ground they walk on too.**
##
## Owner, 2026-09-17: the dust should be thrown by *"all characters"*. Everywhere
## else in the game that is `Footfalls`, which watches a node group - and the
## Hold has no nodes to watch. Its Wardens and its residents are **records**,
## drawn by this file's own `_draw`, which is what makes the place cheap enough
## to carry four seats, six houses, a lawn and a bonfire at once.
##
## So the measurement is the same and the enumeration is local: travel since the
## last frame, a stride's worth at a time, laid into the very array the hooves
## are already in. It walks the same two lists `_who_is_walking` walks - the
## seats and the residents - rather than calling it, because a scuff needs to
## know *which* walker it belongs to across frames and that function hands back
## anonymous points.
func _tick_treads(delta: float) -> void:
	if _marks == null or delta <= 0.0:
		return
	var weight: float = Graphics.particle_scale() 		* JuiceDirector.weight(JuiceDirector.Priority.COSMETIC)
	if weight <= 0.01:
		return
	var stride: float = Balance.HERO_BODY_RADIUS * Balance.FOOTFALL_STRIDE
	var top: float = Balance.HOLD_WALK_SPEED
	for index: int in _seats.size():
		var seat: Dictionary = _seats[index]
		if int(seat.get("kind", 0)) == HoldSession.Seat.EMPTY:
			continue
		# **A rider lays no boot marks.** The horse is already laying hoof marks
		# through `_tick_ride`, and both at once reads as somebody dragging their
		# feet beside a galloping animal.
		if bool(seat.get("riding", false)):
			_treads.erase("s%d" % index)
			continue
		_one_walker("s%d" % index, seat["at"] as Vector2, stride,
			top * Balance.HOLD_MOUNT_SPEED, delta, weight)
	for index: int in _residents.size():
		_one_walker("r%d" % index, _residents[index]["at"] as Vector2, stride,
			top, delta, weight)
	_marks.bound(Balance.FOOTFALL_MAX_MARKS)


## One walker's travel since the last frame, a stride's worth at a time.
##
## Keyed by a string rather than by position in a list, because a seat emptying
## renumbers everybody after it - and a walker that changes key arrives looking
## like somebody who has just teleported across the yard, which empties a whole
## journey into one scuff.
func _one_walker(key: String, at: Vector2, stride: float, top: float, delta: float,
		weight: float) -> void:
	var was: Variant = _treads.get(key)
	if not (was is Array):
		_treads[key] = [at, 0.0]
		return
	var last: Vector2 = (was as Array)[0] as Vector2
	var gone: float = last.distance_to(at)
	var effort: float = clampf(gone / delta / maxf(top, 1.0), 0.0, 1.0)
	if effort < Balance.FOOTFALL_MOVING:
		_treads[key] = [at, 0.0]
		return
	var carried: float = float((was as Array)[1]) + gone
	var way: Vector2 = (at - last).normalized()
	var floor_at: Vector2 = at + Vector2(0.0, lift_at(at))
	while carried >= stride:
		carried -= stride
		var puffs: int = maxi(int(round(lerpf(1.0,
			float(Balance.FOOTFALL_PUFFS), effort) * weight)), 1)
		for _puff: int in puffs:
			_marks.scuff(floor_at,
				-way * lerpf(Balance.FOOTFALL_THROW.x,
					Balance.FOOTFALL_THROW.y, effort),
				Balance.HERO_BODY_RADIUS * Balance.FOOTFALL_PUFF_SIZE
					* lerpf(0.7, 1.25, effort) * clampf(weight, 0.4, 1.0),
				Balance.FOOTFALL_LIFE,
				Balance.FOOTFALL_ALPHA * clampf(weight, 0.0, 1.0),
				Balance.FOOTFALL_DRAG)
	_treads[key] = [at, carried]


func _breathe_the_scatter(delta: float) -> void:
	for sprite: Sprite2D in _breathers:
		if not is_instance_valid(sprite):
			continue
		var frames: Array = sprite.get_meta("idle_frames", []) as Array
		if frames.is_empty():
			continue
		var clock: float = float(sprite.get_meta("idle_clock", 0.0)) \
			+ delta * Balance.HOLD_IDLE_FPS
		sprite.set_meta("idle_clock", clock)
		var step: int = int(clock) % frames.size()
		var texture := frames[step] as Texture2D
		if texture != null and sprite.texture != texture:
			sprite.texture = texture


func _build_bonfire() -> void:
	_bonfire = HoldBonfire.new()
	_bonfire.name = "Bonfire"
	var at: Vector2 = _on_ground(at_cell(FIRE_AT))
	_bonfire.position = at + Vector2(0.0, lift_at(at))
	_actors.add_child(_bonfire)


## **Where people in the Hold actually live**, assembled part by part.
##
## Each takes its seed from its own cell, so the same six houses come back every
## visit and no two of them are the same house - the rule the pens' animals and
## the paddock's horses are each given a clock under.
func _build_houses() -> void:
	for cell: Vector2i in Balance.HOLD_HOUSES:
		var house := HoldHouse.new()
		house.seed_value = absi(hash(cell))
		var at: Vector2 = _on_ground(at_cell(cell))
		house.position = at + Vector2(0.0, lift_at(at))
		_actors.add_child(house)


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
		# **The painting, and a weathering of its own.** Which cloth a banner
		# wears is decided by where it hangs rather than rolled, so the Hold
		# looks the same every visit; the weathering is drawn from the same
		# place, so two banners sharing a device are still two banners.
		var pick: int = absi(hash(entry["cell"])) % Balance.HOLD_BANNER_ART.size()
		var painted: String = Balance.HOLD_BANNER_ART[pick]
		if ResourceLoader.exists(painted):
			flag.art = load(painted) as Texture2D
		var worn: float = 1.0 - float(absi(hash(entry["cell"]) >> 8) % 100) \
			* 0.01 * Balance.HOLD_BANNER_WEATHER
		flag.weathering = Color(worn, worn * 0.99, worn * 0.96)
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
	if _grass_field != null and is_instance_valid(_grass_field):
		_grass_field.set_wind(_wind)
	if _turf != null and is_instance_valid(_turf) and _turf.material != null:
		(_turf.material as ShaderMaterial).set_shader_parameter("wind", _wind)
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
		_seats[index]["name"] = SIM_NAMES[absi(hash(sim_key(index))) % SIM_NAMES.size()]
	_relabel()


## How a seat's Warden is dyed: this machine's own off the save, a stranger's
## as the host said. A simulated seat is the painted Warden.
func set_look(index: int, row: Array) -> void:
	if index < 0 or index >= _seats.size():
		return
	var animator := _seats[index].get("animator") as HeroAnimator
	if animator != null and animator.sprite != null:
		WardenLook.dress(animator.sprite, WardenLook.unpack(row))


## A seat's own record, so a gate can drive one rather than assert a constant.
func seat_state(index: int) -> Dictionary:
	if index < 0 or index >= _seats.size():
		return {}
	return _seats[index]


## A seat's own sprite, for anything that needs to read what it is wearing.
func seat_sprite(index: int) -> Sprite2D:
	if index < 0 or index >= _seats.size():
		return null
	var animator := _seats[index].get("animator") as HeroAnimator
	return animator.sprite if animator != null else null


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
	_tick_treads(delta)
	_turn_the_wind(delta)
	_breathe_the_scatter(delta)
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
	# **Mounting, with the same press the road reads**, so nobody learns a
	# second one. There is nothing here to fight, so none of the road's reasons
	# to be put on your feet apply - what a mount buys in the Hold is the size
	# of the place, and the yard is three and a half thousand units across.
	if _driving and Input.is_action_just_pressed(&"mount"):
		_toggle_ride(seat, way)
	var riding: bool = bool(seat.get("riding", false))
	# **Sprinting here costs nothing.** Owner, 2026-09-18: *"Players should
	# also be able to sprint with shift etc without using sp in the Hold, same
	# with riding their mount in the hold and sprinting with it."* SP is the
	# road's resource and exists to make crossing a battlefield a decision;
	# there is nothing here to ration it against, and a hub three and a half
	# thousand units across that makes you walk is the size working against
	# the place. The Warden's own pool is never read and never spent.
	var running: float = 1.0
	if _driving and Input.is_action_pressed(&"sprint"):
		running = Balance.HOLD_SPRINT_SPEED
	var speed: float = Balance.HOLD_WALK_SPEED * running \
		* (Balance.HOLD_MOUNT_SPEED if riding else 1.0)
	_step(seat, way, delta, speed)
	_tick_ride(seat, way, delta, speed)
	_relay(delta)


## **On and off, and what the ground makes of it.**
##
## Coming off carries whatever was being carried: the dismount's dirt and its
## little hop are both scaled by how fast the horse was going, which is the
## owner's *"continued force to impact on the ground"*. Nothing is taken away
## from the player for it - no stun, no slow - because a dismount that cost
## control would be a price the road never agreed to either.
func _toggle_ride(seat: Dictionary, way: Vector2) -> void:
	var rig: MountRig = seat.get("rig", null) as MountRig
	if rig == null or not is_instance_valid(rig):
		return
	var riding: bool = bool(seat.get("riding", false))
	seat["riding"] = not riding
	rig.visible = not riding
	if riding:
		# Down, carrying the speed it was doing.
		var at: Vector2 = seat["at"] as Vector2
		_land_hard = clampf(float(seat.get("gait", 0.0)), 0.0, 1.0)
		_land_left = Balance.MOUNT_LAND_TIME
		if _marks != null and is_instance_valid(_marks):
			_marks.impact(at + Vector2(0.0, lift_at(at)),
				way.normalized() if way.length_squared() > 0.01
					else (seat["facing"] as Vector2), _land_hard)
		Sfx.play_group_at("sfx_hit_stone", at, -6.0)
	else:
		Sfx.play_group("sfx_ui_confirm")


## The trail, the gait and the landing hop, once a frame.
func _tick_ride(seat: Dictionary, way: Vector2, delta: float,
		speed: float) -> void:
	var moving: bool = way.length_squared() > 0.01
	# How hard it is going, 0 at a stand and 1 at the fastest the Hold allows -
	# the figure the trail and the dismount are both scaled by.
	var gait: float = 0.0
	if moving:
		gait = clampf(speed / (Balance.HOLD_WALK_SPEED
			* Balance.HOLD_MOUNT_SPEED), 0.0, 1.0)
	seat["gait"] = gait
	var rig: MountRig = seat.get("rig", null) as MountRig
	if rig != null and is_instance_valid(rig) and bool(seat.get("riding", false)):
		rig.set_facing(seat["facing"] as Vector2)
		rig.play("gallop" if moving else "idle")
	# **Laid by distance rather than by a clock**, so a trail is the same
	# density at any speed and a gallop simply lays more of it.
	if bool(seat.get("riding", false)) and moving and _marks != null \
			and is_instance_valid(_marks):
		_hoof_left -= speed * delta
		if _hoof_left <= 0.0:
			_hoof_left = Balance.MOUNT_MARK_EVERY
			var at: Vector2 = seat["at"] as Vector2
			_marks.hoof(at + Vector2(0.0, lift_at(at)),
				way.normalized(), gait)
	# The landing hop. A half-sine, so it returns exactly to rest rather than
	# leaving the Warden a pixel off the ground - the rule the tower's upgrade
	# swell is drawn under.
	if _land_left > 0.0:
		_land_left = maxf(_land_left - delta, 0.0)
		var node := seat["node"] as Node2D
		if node != null:
			var share: float = _land_left / maxf(Balance.MOUNT_LAND_TIME, 0.01)
			var hop: float = sin(share * PI) * Balance.MOUNT_LAND_HOP \
				* _land_hard
			var at: Vector2 = seat["at"] as Vector2
			node.position = at + Vector2(0.0, lift_at(at) - hop)


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
			var errand: Dictionary = _errand(own)
			seat["to"] = errand["at"]
			seat["doing"] = errand["doing"]
			seat["busy"] = 0.0
			seat["left"] = own.randf_range(Balance.HOLD_NPC_PAUSE.x,
				Balance.HOLD_NPC_PAUSE.y)
		# **Arrived, it looks at what it walked to.** A figure that stops
		# facing whichever way it happened to be walking reads as one that
		# lost interest; one that turns to the anvil reads as one using it.
		var gap: Vector2 = (seat["to"] as Vector2) - (seat["at"] as Vector2)
		if gap.length() <= 12.0:
			seat["facing"] = Vector2.UP if absf(gap.x) < 1.0 else gap.normalized()
			_busy(seat, delta)
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
	# **A one-shot is left to finish.** Standing still asks for "idle" every
	# frame, which over a gesture requested on the same tick is a swing that
	# never draws a frame of itself. Walking cancels it, which is right: a
	# figure that walks off mid-swing has changed its mind.
	if way.length_squared() <= 0.01 and animator.mid_gesture():
		return
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

	# The tufts are `HoldGrass`, a node of their own - see `_scatter_grass`.

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
