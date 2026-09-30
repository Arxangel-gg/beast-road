class_name ScopeCut
extends CanvasLayer

## **A change of view is a cut from dark, not a jump** (2026-09-30, owner:
## *"more aesthetic appeal and polish"*). The battlefield, the Town and Yuri were
## swapped on one frame - every node of one picture replaced by another with
## nothing between them, which reads as the renderer hiccuping rather than as
## the camera going somewhere. A short fade in from near-black is what every
## polished game puts on that seam.
##
## **Under the HUD, never over it**: the interface is the one thing that did not
## change, and darkening it with the world would say it had. So this is its own
## layer just below the HUD's, and it never takes a click. **A look and nothing
## else**: it reads the scope signal and changes no number. The first scope of a
## run is not cut, because the road already arrives under its own card.

const LAYER: int = 19

var _rect: ColorRect
var _left: float = 0.0
var _last_scope: int = -1


func _ready() -> void:
	layer = LAYER
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.color = Color(Balance.SCOPE_CUT_COLOUR, 0.0)
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.visible = false
	EventBus.scope_changed.connect(_on_scope_changed)
	set_process(false)


func _on_scope_changed(scope: int) -> void:
	var first: bool = _last_scope < 0
	var same: bool = scope == _last_scope
	_last_scope = scope
	if first or same or DisplayServer.get_name() == "headless":
		return
	_left = Balance.SCOPE_CUT_SECONDS
	_rect.visible = true
	_paint()
	set_process(true)


func _process(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)
	_paint()
	if _left <= 0.0:
		_rect.visible = false
		set_process(false)


func _paint() -> void:
	var t: float = _left / maxf(Balance.SCOPE_CUT_SECONDS, 0.001)
	_rect.color.a = Balance.SCOPE_CUT_ALPHA * t * t


## For the gate: how dark the cut stands now, 0 when it is not showing.
func darkness() -> float:
	return _rect.color.a if _rect.visible else 0.0
