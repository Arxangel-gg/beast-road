extends CharacterBody2D

## A body that stands where it is put, for `fishing_check`.
##
## `Fishing` asks a hero four things - is it alive, how fast is it moving under
## its own power, where its hand is, and what its input source says - so a
## fixture only has to answer those. A real `Hero` would drag in an attack, a
## health pool, an animator and a spell caster, none of which the thing under
## test reads, and any one of which could fail the gate for reasons that have
## nothing to do with ponds.
##
## The input is a `RemoteHeroInput`, which is exactly what a guest's hero is
## driven by: a snapshot applied from outside. That makes the gate's "press" the
## same press a wire delivers, rather than a fake the fishing code might treat
## differently.

var input: HeroInput = RemoteHeroInput.new()


func is_alive() -> bool:
	return true


func own_speed() -> float:
	return velocity.length()


func combat_origin() -> Vector2:
	return global_position + Vector2(0.0, -40.0)


## A press of the interact button, as a snapshot.
func press_interact() -> void:
	(input as RemoteHeroInput).apply([Vector2.ZERO, Vector2.RIGHT, HeroInput.BUTTON_INTERACT, 0])


## Hold or release the interact button, as a snapshot.
func hold_interact(down: bool) -> void:
	(input as RemoteHeroInput).apply([Vector2.ZERO, Vector2.RIGHT, 0,
		HeroInput.HOLD_INTERACT if down else 0])
