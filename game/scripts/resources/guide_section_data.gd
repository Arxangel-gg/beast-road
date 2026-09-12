class_name GuideSectionData
extends GameData

## One section of the guide: how to do a thing, what a thing is, what a word
## means (owner brief, 2026-09-12: every guide section in one place, with
## screenshots, resources, items, a glossary, progress and achievements).
##
## Data, like every player-facing string (working rule 9). A section names a
## category the guide screen groups by, a body, and optionally a picture of
## the thing being explained - captured from the game itself by
## `tools/guide_shots`, so the picture and the game cannot drift apart.

@export var title: String = ""
## The tab this section sits under. The guide orders tabs by first
## appearance in `CATEGORY_ORDER`.
@export var category: String = "Basics"
@export var order: int = 0
## Optional picture: `res://art/guide/<id>.png`, or any path.
@export var image: String = ""
@export_multiline var body: String = ""
