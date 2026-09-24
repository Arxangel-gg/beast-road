class_name SunRelief
extends DirectionalLight2D

## The sun's direction on the towers, and nothing else (2026-09-23).
##
## A tower shades with the lights around it (`actor_polish.gdshader`, the
## `shade_strength` pilot). At night the torches, the town and the towers
## themselves are those lights; by day there were none, so a day-lit tower was
## the flat painting it has always been. This is the sun: it rises on the right,
## stands over the field at noon and sets on the left, following `DayNight`, so
## the same tower is lit on a different side at breakfast and at supper.
##
## **Relief only.** The shader's `light()` gives a directional light no flat
## surface at all - it brightens what faces it and darkens what faces away - so
## it cannot wash a tower out, and it reaches only what carries
## `Balance.SUN_RELIEF_LAYER`, which only a shaded tower does. Nothing else in the
## game is lit by it. It changes no number and nothing reads it.


func _ready() -> void:
	name = "SunRelief"
	blend_mode = Light2D.BLEND_MODE_ADD
	range_item_cull_mask = Balance.SUN_RELIEF_LAYER
	shadow_enabled = false
	height = 0.0
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	# Phase 0 is dawn and 0.5 dusk: rotation 90 lights from the right, 0 from
	# above and -90 from the left (measured on the renderer, `shade_probe`).
	var day: float = clampf(DayNight.phase / 0.5, 0.0, 1.0)
	rotation_degrees = 90.0 - 180.0 * day
	energy = Balance.SUN_RELIEF_ENERGY * clampf(1.0 - DayNight.darkness, 0.0, 1.0)
	visible = energy > 0.002
