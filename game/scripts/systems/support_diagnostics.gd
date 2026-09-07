class_name SupportDiagnostics
extends RefCounted

## A user-requested, allowlisted snapshot, not telemetry or a save exporter.
## Keep the schema explicit: serializing settings, run dictionaries or logs can
## silently start sharing private fields when another system adds one.
const FORMAT: String = "beast-road-support-v1"
const MAX_METADATA_LENGTH: int = 128
const MAX_NUMBER: float = 1000000000000.0


static func capture(viewport_size: Vector2i) -> Dictionary:
	var engine: Dictionary = Engine.get_version_info()
	return {
		"format": FORMAT,
		"build": {
			"version": _metadata(BuildInfo.VERSION),
			"engine": "%d.%d.%d" % [int(engine.get("major", 0)),
				int(engine.get("minor", 0)), int(engine.get("patch", 0))],
		},
		"platform": {
			"os": _metadata(OS.get_name()),
			"display_backend": _metadata(DisplayServer.get_name()),
			"configured_renderer": _metadata(String(ProjectSettings.get_setting(
				"rendering/renderer/rendering_method", "unknown"))),
			"video_adapter": _metadata(RenderingServer.get_video_adapter_name()),
		},
		"viewport": {"width": clampi(viewport_size.x, 0, 32768),
			"height": clampi(viewport_size.y, 0, 32768)},
		"quality": _quality(),
		"run": _run(),
	}


static func report_text(viewport_size: Vector2i) -> String:
	return JSON.stringify(capture(viewport_size), "  ", true)


static func _quality() -> Dictionary:
	var preset: String = Graphics.preset()
	if not Graphics.PRESETS.has(preset) and preset != Graphics.PRESET_CUSTOM:
		preset = "unknown"
	return {
		"preset": preset,
		"cast_shadows": Graphics.cast_shadows(),
		"ground_shadows": Graphics.contact_shadows(),
		"cloud_shadows": Graphics.cloud_shadows(),
		"particles": _number(Graphics.particle_scale()),
		"foliage": _number(Graphics.foliage_scale()),
		"frame_cap": maxi(Graphics.fps_cap(), 0),
		"brightness_lift": _number(Graphics.brightness_lift()),
		"smooth_pixel_art": Graphics.canvas_filter() == CanvasItem.TEXTURE_FILTER_LINEAR,
		"colourblind_mode": Palette.mode(),
		"touch_controls_visible": TouchInput.is_showing(),
	}


static func _run() -> Dictionary:
	var context: String = "none"
	if GameDirector.run_active:
		context = "current"
	elif RunState.phase == RunState.Phase.ENDED:
		context = "last_finished"
	if context == "none":
		return {"context": context}
	return {
		"context": context,
		"seed": clampi(RunState.run_seed, 1, RunState.RNG_MAX_SEED),
		"phase": _enum_name(RunState.Phase, RunState.phase),
		"scope": _enum_name(GameDirector.Scope, GameDirector.current_scope),
		"act": maxi(RunState.act, 0),
		"segment": maxi(RunState.segment, 0),
		"wave": maxi(RunState.wave_number, 0),
		"tier": _content_id(RunState.tier_id, ContentDB.tiers),
		"terrain": _content_id(RunState.terrain_id, ContentDB.terrains),
		"weather": _content_id(RunState.weather_id, ContentDB.weathers),
		"totals": {
			"distance": _number(RunState.distance_travelled),
			"combat_seconds": _number(RunState.run_time_seconds),
			"planning_seconds": _number(RunState.planning_time_seconds),
			"enemies_defeated": maxi(RunState.enemies_killed, 0),
			"hero_deaths": maxi(RunState.hero_deaths, 0),
			"wounds_suffered": maxi(RunState.wounds_suffered, 0),
			"raids_completed": maxi(RunState.raids_completed, 0),
			"towers_built": maxi(RunState.towers_built, 0),
			"tower_upgrades": maxi(RunState.tower_upgrades, 0),
			"towers_lost": maxi(RunState.towers_lost, 0),
			"town_hits_taken": maxi(RunState.town_hits_taken, 0),
			"town_damage_taken": _number(RunState.town_damage_taken),
		},
	}


static func _content_id(id: String, registry: Dictionary) -> String:
	# A corrupted or edited save must not smuggle arbitrary text into the report.
	return id if registry.has(id) else "unknown"


static func _enum_name(values: Dictionary, value: int) -> String:
	var key: Variant = values.find_key(value)
	return String(key).to_lower() if key != null else "unknown"


static func _number(value: float) -> float:
	return snappedf(clampf(value, 0.0, MAX_NUMBER), 0.01) if is_finite(value) else 0.0


static func _metadata(value: String) -> String:
	var cleaned: String = ""
	for index: int in mini(value.length(), MAX_METADATA_LENGTH):
		var character: int = value.unicode_at(index)
		if character >= 32 and character != 127:
			cleaned += String.chr(character)
	return cleaned
