class_name CairnText
extends GameData

## The Cairn's words (working rule 9): its title and note, the two headings,
## what each side says when it has nothing, how a fallen road and a record are
## written, and the names of the records.

@export var title: String = "The Cairn"
@export var note: String = ""
@export var fallen_heading: String = "The fallen"
@export var records_heading: String = "Records"
@export var walked_heading: String = "Roads walked"
@export var no_fallen: String = ""
@export var no_records: String = ""
## A fallen road: act, region, wave, road, level, and when.
@export var fallen_line: String = "Act %s · %s · wave %d"
@export var fallen_detail: String = "%s · level %d · %s"
@export var cause_unknown: String = ""
## How long ago, by size.
@export var ago_minutes: String = "%d minutes ago"
@export var ago_hours: String = "%d hours ago"
@export var ago_days: String = "%d days ago"
@export var ago_now: String = "just now"
## The record names, by `MetaState.RUN_RECORD_KEYS`, and the totals line.
@export var record_names: Dictionary = {}
@export var walked_line: String = "%d roads · %d came home · %d reached the summit · %d fell"
@export var hardcore_mark: String = "Hardcore"
## How the furthest act is written among the records.
@export var record_act: String = "Act %s"
## How a time on one road is written, over an hour and under one.
@export var record_hours: String = "%dh %02dm"
@export var record_minutes: String = "%dm %02ds"
@export var close: String = "Close"
