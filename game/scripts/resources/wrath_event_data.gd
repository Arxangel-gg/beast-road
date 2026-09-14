class_name WrathEventData
extends GameData

## What the earth's wrath says and looks like when it answers.
##
## One resource per thing the earth does - a quake, a funnel, a blaze, a
## stone - and per patch of ground a disaster leaves charged: the line said
## before it lands, the line said when it does, and which element's towers
## the ground it leaves feeds. The strings live here and nowhere else
## (working rule 9); `WeatherSky` and `WrathZones` read them by id.
##
## Wrath itself has no readout, ever (owner brief, 2026-09-14). These lines
## are the *signs* of it - what the birds and the ground and the sky do - and
## none of them carries a number.

## Which towers a zone of this kind feeds: a `TowerData.Element`, or -1 for
## an event that leaves no charged ground behind it.
@export_range(-1, 3) var element: int = -1

## Said before it lands, for the events that are telegraphed. Empty for an
## event that gives no warning.
@export var warning: String = ""
@export var warning_title: String = ""

## Said when it lands - or, for charged ground, when the ground opens.
@export var announce: String = ""
@export var announce_title: String = ""

## The colour of the ground it leaves, and of the tell before it.
@export var colour: Color = Color(1.0, 1.0, 1.0, 1.0)


func get_sprite_path() -> String:
	return ""
