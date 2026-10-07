class_name BarJuice
extends Control

## **The life of a bar** (owner, 2026-10-07: "UI Progressbars on the battlefield
## should have semitransparency and have game juicy vfx animations for idle and
## changes with the VFX affected by the amount of change").
##
## One child laid over a `ProgressBar`, drawn and read by nothing. Idle, a soft
## sheen walks the fill and its leading edge breathes. On a change the whole of
## it answers by how much moved: a gain flashes the edge and lifts motes out of
## the segment that filled, a loss leaves the lost segment as a bright chunk that
## falls away and throws splinters, and the bar swells for a beat - all of it
## sized by the share of the bar that moved, so a sliver of mana is a glint and
## half the wall is a blow.
##
## **Cheap by construction.** Plain rects on one canvas item, a few dozen motes at
## most, redrawn on `UI_BAR_JUICE_HZ` while idle and every frame only while
## something is moving - so fifteen bars on a HUD cost what one used to.

var bar: ProgressBar = null
var colour: Color = Color(1.0, 0.85, 0.5)

var _shown: float = -1.0
var _clock: float = 0.0
var _redraw_wait: float = 0.0
var _flash: float = 0.0
var _flash_gain: bool = true
var _bump: float = 0.0
## Motes: x, y, vx, vy, life, size - six floats a mote.
var _motes: PackedFloat32Array = PackedFloat32Array()
## Chunks: from, to (shares of the bar), life - three floats a chunk.
var _chunks: PackedFloat32Array = PackedFloat32Array()
var _dice := RandomNumberGenerator.new()


func _ready() -> void:
	name = "Juice"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_dice.seed = hash(get_path()) if is_inside_tree() else 1


func _ratio() -> float:
	if bar == null:
		return 0.0
	var span: float = bar.max_value - bar.min_value
	return clampf((bar.value - bar.min_value) / span, 0.0, 1.0) if span > 0.0 else 0.0


func _process(delta: float) -> void:
	if bar == null or not is_visible_in_tree():
		return
	_clock += delta
	var now: float = _ratio()
	if _shown < 0.0:
		_shown = now
	elif absf(now - _shown) > 0.0005:
		_answer(_shown, now)
		_shown = now
	var busy: bool = _flash > 0.0 or _bump > 0.0 or not _motes.is_empty() or not _chunks.is_empty()
	if busy:
		_age(delta)
	_ease_the_bump()
	_redraw_wait -= delta
	if busy or _redraw_wait <= 0.0:
		_redraw_wait = 1.0 / Balance.UI_BAR_JUICE_HZ
		queue_redraw()


## A change, answered by how much of the bar moved.
func _answer(before: float, after: float) -> void:
	var moved: float = absf(after - before)
	var weight: float = clampf(moved / Balance.UI_BAR_JUICE_FULL_CHANGE, 0.0, 1.0)
	_flash = maxf(_flash, 0.35 + 0.65 * weight)
	_flash_gain = after > before
	_bump = maxf(_bump, Balance.UI_BAR_JUICE_BUMP * (0.25 + 0.75 * weight))
	var lo: float = minf(before, after)
	var hi: float = maxf(before, after)
	if after < before:
		_chunks.append_array(PackedFloat32Array([lo, hi, 1.0]))
	var count: int = clampi(int(round(2.0 + weight * float(Balance.UI_BAR_JUICE_MOTES))), 2,
		Balance.UI_BAR_JUICE_MOTES)
	for _i: int in count:
		if _motes.size() >= Balance.UI_BAR_JUICE_MOTE_CAP * 6:
			break
		var x: float = lerpf(lo, hi, _dice.randf()) * size.x
		var y: float = _dice.randf_range(0.2, 0.8) * size.y
		var rise: float = -1.0 if after > before else 1.0
		_motes.append_array(PackedFloat32Array([x, y,
			_dice.randf_range(-24.0, 24.0), rise * _dice.randf_range(18.0, 46.0) * (0.6 + weight),
			1.0, _dice.randf_range(1.2, 2.4) * (1.0 + weight)]))


func _age(delta: float) -> void:
	_flash = maxf(_flash - delta / Balance.UI_BAR_JUICE_FLASH_SECONDS, 0.0)
	var kept := PackedFloat32Array()
	for index: int in range(0, _motes.size(), 6):
		var life: float = _motes[index + 4] - delta / Balance.UI_BAR_JUICE_MOTE_SECONDS
		if life <= 0.0:
			continue
		kept.append_array(PackedFloat32Array([
			_motes[index] + _motes[index + 2] * delta,
			_motes[index + 1] + _motes[index + 3] * delta,
			_motes[index + 2] * 0.96, _motes[index + 3] * 0.97, life, _motes[index + 5]]))
	_motes = kept
	var chunks := PackedFloat32Array()
	for index: int in range(0, _chunks.size(), 3):
		var life: float = _chunks[index + 2] - delta / Balance.UI_BAR_JUICE_CHUNK_SECONDS
		if life > 0.0:
			chunks.append_array(PackedFloat32Array([_chunks[index], _chunks[index + 1], life]))
	_chunks = chunks


## The swell, on the bar's own scale about its middle, eased back to one. A
## container lays out a child's position and size and never its scale, so this
## cannot fight the layout.
func _ease_the_bump() -> void:
	if bar == null:
		return
	if _bump <= 0.0001:
		if bar.scale != Vector2.ONE:
			bar.scale = Vector2.ONE
		_bump = 0.0
		return
	bar.pivot_offset = bar.size * 0.5
	bar.scale = Vector2.ONE * (1.0 + _bump)
	_bump *= 0.82


func _draw() -> void:
	if bar == null:
		return
	var ratio: float = _ratio()
	var width: float = size.x * ratio
	var lit: Color = colour.lightened(0.55)
	# **Idle: the sheen.** A soft band walking the fill every few seconds, and the
	# leading edge breathing. Only over what is filled - an empty pool is still.
	if width > 2.0:
		var sweep: float = fposmod(_clock / Balance.UI_BAR_JUICE_SHEEN_SECONDS, 1.0)
		var band: float = maxf(size.x * 0.12, 6.0)
		var at: float = lerpf(-band, width + band, sweep)
		for step: int in 4:
			var share: float = float(step) / 4.0
			var x0: float = clampf(at - band * (1.0 - share), 0.0, width)
			var x1: float = clampf(at + band * (1.0 - share) * 0.4, 0.0, width)
			if x1 > x0:
				draw_rect(Rect2(x0, 0.0, x1 - x0, size.y),
					Color(1.0, 1.0, 1.0, Balance.UI_BAR_JUICE_SHEEN * 0.25))
		var breath: float = 0.5 + 0.5 * sin(_clock * TAU / Balance.UI_BAR_JUICE_BREATH_SECONDS)
		draw_rect(Rect2(maxf(width - 2.0, 0.0), 0.0, 2.0, size.y),
			Color(lit.r, lit.g, lit.b, 0.25 + 0.35 * breath))
	# **A loss: the chunk.** What was taken stays a moment as a bright slab, then
	# drops and fades.
	for index: int in range(0, _chunks.size(), 3):
		var life: float = _chunks[index + 2]
		var x0: float = _chunks[index] * size.x
		var x1: float = _chunks[index + 1] * size.x
		var fall: float = (1.0 - life) * size.y * 0.9
		draw_rect(Rect2(x0, fall, maxf(x1 - x0, 1.0), size.y),
			Color(1.0, 0.92, 0.85, 0.85 * life * life))
	# **The edge flash**, green-gold for a gain and red-white for a loss.
	if _flash > 0.0:
		var hue: Color = Color(1.0, 0.97, 0.75) if _flash_gain else Color(1.0, 0.55, 0.45)
		var glow: float = maxf(size.y * 1.6, 8.0) * _flash
		draw_rect(Rect2(maxf(width - glow * 0.5, 0.0), -2.0 * _flash, glow, size.y + 4.0 * _flash),
			Color(hue.r, hue.g, hue.b, 0.55 * _flash))
		draw_rect(Rect2(0.0, 0.0, width, size.y), Color(hue.r, hue.g, hue.b, 0.16 * _flash))
	# **Motes**, out of the segment that moved.
	for index: int in range(0, _motes.size(), 6):
		var life: float = _motes[index + 4]
		var mote: float = _motes[index + 5]
		draw_rect(Rect2(_motes[index] - mote * 0.5, _motes[index + 1] - mote * 0.5, mote, mote),
			Color(lit.r, lit.g, lit.b, life))


## How many motes are in the air. For the gate.
func motes_alive() -> int:
	return _motes.size() / 6


## The flash's strength now. For the gate.
func flash_now() -> float:
	return _flash
