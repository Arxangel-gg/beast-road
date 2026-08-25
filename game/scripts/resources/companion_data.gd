class_name CompanionData
extends GameData

## One summonable companion: Wolf, Crow or Bear.
##
## **It expires, and that is the design decision rather than a tuning value.**
## GDD §54 cuts "multiple heroes, party roster" for 1.0, and a permanent second
## body on the field is near enough that line to be the same thing wearing a
## different word. A summon with a duration is a *spell effect* - it is Beast's
## Breath with legs, and it ends. One that persists is a party member.
##
## So there is no health here and nothing can kill one. Enemies never target a
## companion, because a companion is not a unit competing for their attention -
## it is damage the hero placed somewhere for a while. That also keeps the whole
## system out of the targeting, threat and death-payout code, none of which
## should have to learn a new kind of thing exists.
##
## Data like everything else: a fourth companion is a `.tres` and a sprite.

## How long it stays, in seconds.
@export_range(2.0, 60.0) var duration: float = 14.0

## Damage per strike, before the hero's own damage modifiers.
@export_range(0.0, 400.0) var damage: float = 26.0

## Seconds between strikes.
@export_range(0.15, 6.0) var attack_interval: float = 0.9

## How close it has to be to strike, in world units.
@export_range(20.0, 600.0) var attack_range: float = 92.0

## How far out it will look for something to attack.
@export_range(60.0, 1200.0) var hunt_range: float = 460.0

## World units per second.
@export_range(20.0, 700.0) var speed: float = 300.0

## How far behind the hero it settles when there is nothing to fight.
@export_range(20.0, 400.0) var follow_distance: float = 96.0

## Knockback dealt per strike.
@export_range(0.0, 600.0) var knockback: float = 60.0

## True for anything that ignores the ground and drifts over it.
@export var flies: bool = false

## Drawn size, as a multiple of the sprite's own pixels.
@export_range(0.2, 3.0) var scale: float = 1.0

## Tint of the summon and dismiss rings, and of the strike sparks.
@export var colour: Color = Color(0.62, 0.82, 1.0)


func get_sprite_path() -> String:
	return GameData.derive_path("companions", "companion_", id)
