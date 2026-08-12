extends CanvasLayer

## On-screen audio readout, toggled with F9.
##
## This exists because "the sound effects are not audible" was reported three
## times while every measurement I could take said signal was reaching the
## speakers. A number on screen settles that argument in one keypress instead of
## another round of guessing: if `starts` climbs and `master peak` moves, the
## engine is producing audio and the problem is downstream (device, mixer, mute).
## If they stay flat, it is not.

var _label: Label
var _shown: bool = false


func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.offset_left = 18.0
	panel.offset_top = 150.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 15)
	_label.add_theme_color_override("font_color", Color("9fe8b0"))
	panel.add_child(_label)

	visible = false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_F9:
		_shown = not _shown
		visible = _shown


func _process(_delta: float) -> void:
	if not _shown:
		return
	var d: Dictionary = Sfx.debug_state()
	var lines: PackedStringArray = ["AUDIO  (F9 to hide)"]
	lines.append("sfx files loaded  %d" % int(d["streams"]))
	lines.append("play attempts     %d" % int(d["attempts"]))
	lines.append("voices started    %d" % int(d["starts"]))
	lines.append("voices sounding   %d / %d" % [int(d["voices_busy"]), Sfx.VOICES])
	lines.append("blocked: gap %d  limit %d  novoice %d  missing %d" % [
		int(d["blocked_gap"]), int(d["blocked_limit"]),
		int(d["blocked_voices"]), int(d["blocked_missing"])])
	lines.append("")
	for i: int in AudioServer.bus_count:
		lines.append("%-7s %6.1f dB  peak %6.1f  %s" % [
			AudioServer.get_bus_name(i),
			AudioServer.get_bus_volume_db(i),
			AudioServer.get_bus_peak_volume_left_db(i, 0),
			"MUTED" if AudioServer.is_bus_mute(i) else ""])
	lines.append("")
	lines.append("music  %s%s" % [MusicPlayer.current_track(),
		"  (crossfading)" if MusicPlayer.is_crossfading() else ""])
	lines.append("master=%.2f  music=%.2f  sfx=%.2f" % [
		float(MetaState.settings.get("master_volume", 1.0)),
		float(MetaState.settings.get("music_volume", 0.8)),
		float(MetaState.settings.get("sfx_volume", 1.0))])
	_label.text = "\n".join(lines)
