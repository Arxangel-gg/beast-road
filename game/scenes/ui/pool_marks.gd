class_name PoolMarks
extends Control

## **The ward and the notches on the HUD's health bar** (owner, 2026-09-30:
## "Player shield inspired by LoL, also HP bar segments on players").
##
## A child of the bar, laid over the fill and under the sheen and the frame, so
## the ward reads as part of the pool rather than a sticker on it. The bar's
## own value is rescaled by the HUD when health and ward together pass the pool
## (League's rule), and this draws what follows the fill: the ward as a bright
## segment, and a notch every `HealthBar.segment_step` of the whole.
##
## A readout. It reads what it is handed and nothing reads it.

## Where the health ends, as a share of the bar's width.
var fill: float = 0.0
## The ward's width after it, as a share of the bar's width.
var ward: float = 0.0
## The health the whole bar stands for, so a notch lands on a real hundred.
var pool: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_pool(fill_share: float, ward_share: float, pool_hp: float) -> void:
	if is_equal_approx(fill_share, fill) and is_equal_approx(ward_share, ward) \
			and is_equal_approx(pool_hp, pool):
		return
	fill = clampf(fill_share, 0.0, 1.0)
	ward = clampf(ward_share, 0.0, 1.0 - fill)
	pool = maxf(pool_hp, 0.0)
	queue_redraw()


func _draw() -> void:
	var inset: float = Balance.UI_POOL_MARKS_INSET
	var body := Rect2(Vector2(0.0, inset), Vector2(size.x, maxf(size.y - inset * 2.0, 1.0)))
	if ward > 0.0:
		var from: float = size.x * fill
		var wide: float = size.x * ward
		draw_rect(Rect2(from, body.position.y, wide, body.size.y), Balance.HEALTH_BAR_SHIELD_COLOUR)
		draw_rect(Rect2(from, body.position.y, minf(2.0, wide), body.size.y), Balance.HEALTH_BAR_SHIELD_EDGE)
	if pool <= 0.0:
		return
	var step: float = HealthBar.segment_step(pool, Balance.UI_HERO_BAR_SEGMENT_MOST)
	var hp: float = step
	while hp < pool - 0.5:
		var x: float = floorf(size.x * hp / pool)
		var heavy: bool = step >= Balance.HEALTH_BAR_SEGMENT_MAJOR \
			or is_zero_approx(fmod(hp, Balance.HEALTH_BAR_SEGMENT_MAJOR))
		var tall: float = body.size.y if heavy else ceilf(body.size.y * 0.5)
		draw_rect(Rect2(x, body.position.y, 2.0 if heavy else 1.0, tall), Balance.HEALTH_BAR_SEGMENT_COLOUR)
		hp += step
