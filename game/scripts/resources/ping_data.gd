class_name PingData
extends GameData

## **A ping** (triage of 2026-10-07, item 63): a word put on the field for the
## party - here, attack this, fall back. Eight of them, one a spoke of the
## wheel, relayed as facts.
##
## Working rule 9: what a ping says lives here. A ping is presentation and a
## request, never a fact about the fight: it moves no number, and the only thing
## that answers it is the pinging Warden's own company, through the orders the
## mercenary AI already has.

## What a pinging Warden's own mercenaries do about it. Appended only: a file
## names one by number.
enum Heed { NONE, GO, ATTACK, COME }
## What a quick press over this kind of thing pings. Appended only.
enum Context { NONE, GROUND, BODY, TOWER, LOOT }

## Which spoke of the wheel, clockwise from the top: 0 to 7, each once.
@export_range(0, 7) var slot: int = 0
## What the party's feed says. `{who}` is the pinging Warden's name.
@export var line: String = "{who}: here."
## The mark's colour, on the field, the map and the edge of the screen.
@export var colour: Color = Color.WHITE
## The glyph, by `IconKit.ui` id.
@export var icon: String = ""
## A warning: a sharper mark and a sharper sound.
@export var alert: bool = false
@export var heed: Heed = Heed.NONE
@export var context: Context = Context.NONE
