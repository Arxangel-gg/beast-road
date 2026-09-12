class_name LoreEntryData
extends GameData

## One page of the world: a people, a place, a thing that happened, or the
## story so far (owner brief, 2026-09-12: story polish and world building,
## and a guide that holds the lore and the story as it has been unlocked).
##
## Data, like every string the player reads (working rule 9). A page unlocks
## on an act rather than on an event, so the story the guide tells is the
## story of how far this account has walked: an act reached is a chapter
## read, and nothing has to be relayed, replayed or remembered to say so.

enum Category { WORLD, STORY, REGION }

@export var title: String = ""
@export var category: Category = Category.WORLD
## The act this account must have reached for the page to be readable. Zero
## is always readable.
@export var unlock_act: int = 0
@export var order: int = 0
## Optional art beside the text.
@export var art: String = ""
@export_multiline var body: String = ""


func is_unlocked() -> bool:
	return unlock_act <= 0 or MetaState.highest_act >= unlock_act
