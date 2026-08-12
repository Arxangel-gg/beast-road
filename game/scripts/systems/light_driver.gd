class_name LightDriver
extends Node

## Keeps one light in step with the day/night cycle, and optionally flickers it.
##
## Separate from LightKit because a light needs per-frame work and LightKit is a
## static factory. Every light gets one of these, so no caller has to remember
## to fade its lights at dawn — that is the class of bug that leaves torches
## blazing at midday.

var _light: PointLight2D
var _base_energy: float = 1.0
var _flicker: float = 0.0
var _seed: float = 0.0


func setup(light: PointLight2D, base_energy: float, flicker: float) -> void:
	_light = light
	_base_energy = base_energy
	_flicker = flicker
	# Offset per light so a row of torches does not pulse in unison.
	_seed = randf() * 100.0
	_apply()
	DayNight.phase_changed.connect(_on_phase)


func _process(delta: float) -> void:
	if _flicker <= 0.0 or _light == null:
		set_process(false)
		return
	_seed += delta
	_apply()


func _on_phase(_phase: float, _tint: Color, _darkness: float) -> void:
	_apply()


func _apply() -> void:
	if _light == null or not is_instance_valid(_light):
		return
	# Lights are pointless at midday and essential at midnight, so energy tracks
	# darkness rather than being constant.
	var day_scale: float = lerpf(Balance.LIGHT_DAY_ENERGY, 1.0, DayNight.darkness)
	var wobble: float = 1.0
	if _flicker > 0.0:
		# Two out-of-phase sines read as an unsteady flame; one reads as a pulse.
		wobble = 1.0 + _flicker * (sin(_seed * 7.3) * 0.6 + sin(_seed * 13.1) * 0.4) * 0.5
	_light.energy = _base_energy * day_scale * wobble
	_light.visible = _light.energy > 0.01
