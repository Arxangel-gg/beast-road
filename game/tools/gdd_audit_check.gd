extends Node

## A manual acceptance note must not change the progress denominator, and a
## misspelled probe must not be hidden by forgiving parsing.

const FIXTURE: String = """## Fixture
| Item | Target | Probe |
|------|--------|-------|
| Manual plain | Human review | `manual` |
| Manual note | Hardware review | `manual` — measured on target hardware |
| Declared symbol | Exists | `const:AUDIT_FIXTURE` |
| Missing symbol | Missing | `const:AUDIT_MISSING` |
| Unknown probe | Typo | `manualish` |
| Empty manual note | Typo | `manual` — |
"""

var _failures: PackedStringArray = []


func _ready() -> void:
	_test_manual_and_report()
	_test_count_syntax()
	_test_real_checklist()
	for problem: String in _failures:
		push_error("[gdd audit] " + problem)
	print("[gdd audit] %s — manual classification, report counts and invalid probes" % (
		"PASS" if _failures.is_empty() else "FAIL"))
	get_tree().quit(0 if _failures.is_empty() else 1)


func _test_manual_and_report() -> void:
	var rows: Array = GddAudit._parse_text(FIXTURE.replace("\n", "\r\n"))
	_check(rows.size() == 6, "Markdown headers/separators must not become checklist rows")
	if rows.size() != 6:
		return
	var index: Dictionary = {"balance": "const AUDIT_FIXTURE: int = 1"}
	for row: GddAudit.Row in rows:
		GddAudit._evaluate(row, index)
	_check(rows[0].manual and not rows[0].passed, "plain manual must remain unpassed human work")
	_check(rows[1].manual and not rows[1].passed, "annotated manual must remain human work")
	_check(rows[1].detail.contains("measured on target hardware"),
		"a manual requirement's explanation must survive parsing")
	for at: int in [4, 5]:
		_check(not rows[at].manual and not rows[at].passed
			and rows[at].detail.begins_with("unknown probe"),
			"invalid manual-like probes must stay visible: %s" % rows[at].probe)
	var report: Dictionary = GddAudit._report(rows, false)
	_check(report["done"] == 1 and report["total"] == 4 and report["manual"] == 2,
		"manual requirements must be excluded from both completed and total automatic counts")
	var todo: String = String(GddAudit._report(rows, true)["text"])
	_check(todo.contains("Unknown probe") and todo.contains("Empty manual note")
		and todo.contains("Missing symbol") and not todo.contains("Declared symbol"),
		"todo mode must retain unknown, invalid and failed probes")
	_check(GddAudit._parse_text("").is_empty(), "an empty checklist must have no rows")
	# Re-evaluation should not retain an earlier manual/passed state.
	var edited: GddAudit.Row = rows[0]
	edited.probe = "typo"
	GddAudit._evaluate(edited, index)
	_check(not edited.manual and not edited.passed,
		"editing a manual row to an invalid probe must not retain its old classification")


func _test_count_syntax() -> void:
	for expression: String in ["enemies >=", "missing => 0", "missing == typo",
			"enemies >= -1", "missing != 0"]:
		var row := GddAudit.Row.new()
		row.probe = "count:" + expression
		GddAudit._evaluate(row, {})
		_check(not row.manual and not row.passed and row.detail == "malformed count probe",
			"malformed count must not become a passing probe: %s" % expression)
	var count: int = GddAudit._count_resources("res://data/enemies/")
	_check(count > 0, "the count regression needs the real enemy data directory")
	for operator: String in [">=", "=="]:
		var row := GddAudit.Row.new()
		row.probe = "count:enemies %s %d" % [operator, count]
		GddAudit._evaluate(row, {})
		_check(row.passed, "supported count operators must retain their behaviour: %s" % operator)


func _test_real_checklist() -> void:
	var rows: Array = GddAudit._parse()
	var found_performance: bool = false
	for row: GddAudit.Row in rows:
		if row.item != "60 FPS at 1920x1080":
			continue
		found_performance = true
		GddAudit._evaluate(row, {})
		_check(row.manual and not row.passed,
			"the actual minimum-spec FPS row must remain a manual acceptance requirement")
	_check(found_performance, "the production checklist must include minimum-spec FPS acceptance")
	var report: Dictionary = GddAudit.run()
	var body: String = String(report.get("text", ""))
	_check(bool(report.get("ok", false)), "the real checklist must remain readable")
	_check(not body.contains("unknown probe") and not body.contains("malformed count probe"),
		"the real checklist must not contain unknown or malformed probes")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
