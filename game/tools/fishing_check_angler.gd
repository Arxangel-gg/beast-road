extends CharacterBody2D

## A body that stands where it is put, for `fishing_check`.
##
## `Fishing` asks a hero exactly two things - is it alive, and how fast is it
## moving - so a fixture only has to answer those. A real `Hero` would drag in
## an attack, a health pool, an animator and a spell caster, none of which the
## thing under test reads, and any one of which could fail the gate for reasons
## that have nothing to do with ponds.


func is_alive() -> bool:
	return true
