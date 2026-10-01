class_name EarthGrief
extends RefCounted

## **Where the earth was wronged** (owner, 2026-10-01: *"Death of any wildlife
## from any means besides from other wildlife naturally should affect the
## earth's wrath in the area"*).
##
## The wrath has always been one number for the whole road, and that number
## still governs how often the earth answers. What it could not say is
## *where*: a clearing emptied of deer and a meadow nobody touched were the
## same ground to it. Grief is that missing half - a coarse sheet over the
## field that every death the earth minds is laid on, at the place it
## happened, fading on its own clock - and the sky reads it to decide where
## its blows fall (`Sky._pick_strike_point`) and how hard the ground under a
## Warden presses (`Sky.hazard_boost`). Natural wisdom: the earth answers where
## it was wronged.
##
## **A look and a lean, never a second wrath.** Grief adds no anger of its own
## and nothing pays out of it; the wrath number is fed exactly as it always
## was. What grief moves is the place of a blow already rolled, and the share
## of the global hazard a Warden standing there feels - bounded by
## `WRATH_GRIEF_PULL_MAX` and `WRATH_GRIEF_HAZARD`.
##
## Cells of `WRATH_GRIEF_CELL` units: a death is a place the size of a
## clearing, not of a tile, and a sheet of a hundred cells costs nothing to
## fade every frame.

var _across: int = 0
var _half: float = 0.0
var _cells: PackedFloat32Array = PackedFloat32Array()
var _total: float = 0.0


func _init(half_extent: float = 0.0) -> void:
	_half = half_extent if half_extent > 0.0 else BattleGrid.HALF_EXTENT
	_across = maxi(int(ceil(_half * 2.0 / Balance.WRATH_GRIEF_CELL)), 1)
	_cells.resize(_across * _across)
	_cells.fill(0.0)


## Lays `amount` of grief at `at`, most where it happened and falling to
## nothing at `WRATH_GRIEF_RADIUS`.
func add(at: Vector2, amount: float) -> void:
	if amount <= 0.0 or not at.is_finite():
		return
	var reach: float = Balance.WRATH_GRIEF_RADIUS
	var cell: float = Balance.WRATH_GRIEF_CELL
	var low: Vector2i = _cell_of(at - Vector2(reach, reach))
	var high: Vector2i = _cell_of(at + Vector2(reach, reach))
	var weights: Array[float] = []
	var indices: PackedInt32Array = PackedInt32Array()
	var weight_sum: float = 0.0
	for y: int in range(low.y, high.y + 1):
		for x: int in range(low.x, high.x + 1):
			var centre: Vector2 = Vector2((float(x) + 0.5) * cell - _half, (float(y) + 0.5) * cell - _half)
			var falloff: float = 1.0 - centre.distance_to(at) / reach
			if falloff <= 0.0:
				continue
			weights.append(falloff)
			indices.append(y * _across + x)
			weight_sum += falloff
	if indices.is_empty():
		indices.append(_index_of(at))
		weights.append(1.0)
		weight_sum = 1.0
	# The amount is shared out rather than laid whole in every cell, so a death
	# is worth the same grief wherever on the sheet it fell.
	for i: int in indices.size():
		var added: float = amount * weights[i] / weight_sum
		_cells[indices[i]] = minf(_cells[indices[i]] + added, Balance.WRATH_GRIEF_CELL_CAP)
	_recount()


## How much grief lies at `at`, read across the four nearest cells so nothing
## shows the square.
func at(point: Vector2) -> float:
	var cell: float = Balance.WRATH_GRIEF_CELL
	var fx: float = (point.x + _half) / cell - 0.5
	var fy: float = (point.y + _half) / cell - 0.5
	var x0: int = clampi(int(floor(fx)), 0, _across - 1)
	var y0: int = clampi(int(floor(fy)), 0, _across - 1)
	var x1: int = mini(x0 + 1, _across - 1)
	var y1: int = mini(y0 + 1, _across - 1)
	var tx: float = clampf(fx - float(x0), 0.0, 1.0)
	var ty: float = clampf(fy - float(y0), 0.0, 1.0)
	var top: float = lerpf(_cells[y0 * _across + x0], _cells[y0 * _across + x1], tx)
	var bottom: float = lerpf(_cells[y1 * _across + x0], _cells[y1 * _across + x1], tx)
	return lerpf(top, bottom, ty)


func total() -> float:
	return _total


## Fades the whole sheet on `WRATH_GRIEF_HALF_LIFE`.
func tick(delta: float) -> void:
	if _total <= 0.0:
		return
	var keep: float = pow(0.5, delta / maxf(Balance.WRATH_GRIEF_HALF_LIFE, 1.0))
	_total = 0.0
	for i: int in _cells.size():
		var value: float = _cells[i] * keep
		if value < 0.001:
			value = 0.0
		_cells[i] = value
		_total += value


## **A place on the sheet chosen by its grief**: the cell by its share of the
## whole, the point anywhere inside it. INF when nothing is grieved.
func weighted_point(dice: RandomNumberGenerator) -> Vector2:
	if _total <= 0.0:
		return Vector2.INF
	var roll: float = dice.randf() * _total
	var cell: float = Balance.WRATH_GRIEF_CELL
	for i: int in _cells.size():
		roll -= _cells[i]
		if roll <= 0.0:
			var x: int = i % _across
			var y: int = i / _across
			return Vector2((float(x) + dice.randf()) * cell - _half,
				(float(y) + dice.randf()) * cell - _half)
	return Vector2.INF


## The grieved cells, strongest first, as `{at, grief}` - for the picture.
func strongest(count: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if _total <= 0.0:
		return out
	var cell: float = Balance.WRATH_GRIEF_CELL
	for i: int in _cells.size():
		if _cells[i] < Balance.WRATH_GRIEF_SHOWN_FROM:
			continue
		var x: int = i % _across
		var y: int = i / _across
		out.append({"at": Vector2((float(x) + 0.5) * cell - _half, (float(y) + 0.5) * cell - _half),
			"grief": _cells[i]})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["grief"]) > float(b["grief"]))
	if out.size() > count:
		out.resize(count)
	return out


func clear() -> void:
	_cells.fill(0.0)
	_total = 0.0


func _cell_of(point: Vector2) -> Vector2i:
	var cell: float = Balance.WRATH_GRIEF_CELL
	return Vector2i(clampi(int(floor((point.x + _half) / cell)), 0, _across - 1),
		clampi(int(floor((point.y + _half) / cell)), 0, _across - 1))


func _index_of(point: Vector2) -> int:
	var at_cell: Vector2i = _cell_of(point)
	return at_cell.y * _across + at_cell.x


func _recount() -> void:
	_total = 0.0
	for value: float in _cells:
		_total += value
