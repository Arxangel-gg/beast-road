extends Node

## The wheel belongs to whatever is under the pointer.
##
##   godot --headless --path game res://tools/scroll_zoom_check.tscn
##
## **A menu that has run out of scroll still owns the wheel.** Godot hands a
## wheel event to `_unhandled_input` only when the GUI did not use it, and a
## ScrollContainer stops using it the moment it reaches the end of its travel.
## The run layer then read that event as a zoom - and the zoom ladder does not
## stop at the end of its own range either, it *changes scope*. So reading to
## the bottom of a list and scrolling once more threw the player into another
## view. Reported from play, 2026-09-13.
##
## The rule is `Run.scrolls_under`, and what is worth testing is the walk: the
## thing the pointer is actually over is a button or a label deep inside the
## panel, not the scroller, so an answer that only looked at the hovered node
## itself would let the wheel escape through every child.

var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	MetaState.hold_saves()
	_test_a_scroller_claims_the_wheel()
	_test_ordinary_ui_does_not()
	_test_the_wheel_path_asks()
	MetaState.resume_saves()
	if _failures.is_empty():
		print("[scroll-zoom] PASS - %d checks: scrollers keep the wheel, plain panels do not"
			% _checks)
	else:
		for failure: String in _failures:
			push_error("[scroll-zoom] " + failure)
	get_tree().quit(1 if not _failures.is_empty() else 0)


func _check(condition: bool, why: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(why)


## Anything inside a scroller answers yes, however deep.
func _test_a_scroller_claims_the_wheel() -> void:
	var scroller := ScrollContainer.new()
	var column := VBoxContainer.new()
	var row := PanelContainer.new()
	var button := Button.new()
	scroller.add_child(column)
	column.add_child(row)
	row.add_child(button)
	add_child(scroller)
	_check(Run.scrolls_under(scroller), "a scroller itself must keep the wheel")
	_check(Run.scrolls_under(column),
		"a column inside a scroller must keep the wheel")
	_check(Run.scrolls_under(row),
		"a panel inside a scroller must keep the wheel")
	_check(Run.scrolls_under(button),
		("a button inside a scroller must keep the wheel - this is the one that "
			+ "matters, because the pointer is never over the scroller itself"))
	scroller.queue_free()


## And ordinary furniture does not, or the wheel would stop zooming anywhere a
## panel happens to be.
func _test_ordinary_ui_does_not() -> void:
	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	var button := Button.new()
	panel.add_child(column)
	column.add_child(button)
	add_child(panel)
	_check(not Run.scrolls_under(panel), "a plain panel must not swallow the wheel")
	_check(not Run.scrolls_under(button),
		"a button that is not inside a scroller must not swallow the wheel")
	_check(not Run.scrolls_under(null),
		"nothing hovered means nothing to swallow the wheel")
	panel.queue_free()


## And the wheel path has to actually ask.
##
## A grep, the way `discipline_check` proves an effect is wired: weak proof of
## behaviour, strong proof that the question is still being asked before the
## ladder is touched. Without it the rule above could be perfect and unused.
func _test_the_wheel_path_asks() -> void:
	var file := FileAccess.open("res://scenes/run/run.gd", FileAccess.READ)
	_check(file != null, "run.gd is missing")
	if file == null:
		return
	var code: String = file.get_as_text()
	var at: int = code.find("MOUSE_BUTTON_WHEEL_UP")
	_check(at >= 0, "run.gd no longer reads the wheel at all")
	if at < 0:
		return
	var ladder: int = code.find("_zoom_wheel(", at)
	var asks: int = code.find("_pointer_is_over_a_scroller()", at)
	_check(asks >= 0 and (ladder < 0 or asks < ladder),
		("the wheel reaches _zoom_wheel without asking whether the pointer is "
			+ "over a scroller, so overscrolling a menu changes the view again"))
