class_name TrailerMomentData
extends GameData

## **One kind of moment the trailer may show** (owner, 2026-10-07: "make the
## trailers procedurally generated in game at game launch instead of a
## pre-recorded video ... the moments shouldn't all be in the same act every
## time but to have random variations").
##
## The `id` names the recipe that stages it (`TrailerStage`): what is built,
## what is sent, where the Warden goes and what the camera does. Everything a
## player reads - the lines laid over it - lives here (working rule 9), and so
## does everything that decides where it may fall: which acts it suits, where in
## the cut it belongs, how long it holds, how far the camera stands and how
## light it is. Adding a moment of a kind that already has a recipe is adding a
## file.

## Where in the cut a moment belongs: the opening, the build-up, the body, the
## climax, the last word.
enum Place { OPEN, EARLY, MIDDLE, LATE, CLOSE }

@export var place: Place = Place.MIDDLE
## **Always in the cut** (owner, 2026-10-08: "Trailer dragons missing"): dealt
## in the first slot of its place on a road whose act it suits, before any
## moment is drawn for that slot.
@export var always: bool = false
## How often it is dealt among the moments that fit its place.
@export var weight: float = 1.0
## The acts it may be filmed in - a boss of the summit is not an Act I picture.
@export_range(1, 11) var first_act: int = 1
@export_range(1, 11) var last_act: int = 11
@export var seconds_min: float = 4.5
@export var seconds_max: float = 6.0
## How far the camera stands, as the battlefield camera's zoom.
@export var zoom_min: float = 0.8
@export var zoom_max: float = 1.1
## How light it is (`DayNight`'s darkness, 0 noon and 1 midnight).
@export var daylight_min: float = 0.18
@export var daylight_max: float = 0.42
## The lines one of which may be laid over it, and how often one is.
@export var lines: Array[String] = []
@export_range(0.0, 1.0) var line_chance: float = 0.6
