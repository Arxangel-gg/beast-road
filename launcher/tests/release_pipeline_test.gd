extends Node

var _failures: int = 0


func _ready() -> void:
	_test_release_parsing()
	_test_download_failure_policy()
	if _failures == 0:
		print("[launcher test] release pipeline checks passed")
	get_tree().quit(_failures)


func _test_release_parsing() -> void:
	var payload: String = JSON.stringify({
		"tag_name": "v9.9.9",
		"name": "Test release",
		"assets": [
			{
				"name": "notes.txt",
				"browser_download_url": "https://example.invalid/notes.txt",
				"size": 4,
			},
			{
				"name": "BeastRoad-windows.zip",
				"browser_download_url": "https://example.invalid/game.zip",
				"size": 123456,
				"digest": "sha256:ABCDEF",
			},
		],
	})
	var release: ReleaseInfo = ReleaseInfo.from_json(payload)
	_check(release != null, "valid release JSON should parse")
	if release == null:
		return
	_check(release.is_usable(), "release with a Windows zip should be usable")
	_check(release.tag == "v9.9.9", "tag should be preserved")
	_check(release.asset_name == "BeastRoad-windows.zip", "Windows archive should be selected")
	_check(release.asset_size == 123456, "asset size should be preserved")
	_check(release.asset_sha256 == "abcdef", "GitHub SHA-256 should be normalized")
	_check(ReleaseInfo.from_json("[]") == null, "non-object JSON should be rejected")
	_check(ReleaseInfo.from_json("{}") == null, "objects without a tag should be rejected")


func _test_download_failure_policy() -> void:
	var installer := Installer.new()
	_check(
		installer._is_retryable_result(HTTPRequest.RESULT_CONNECTION_ERROR),
		"connection interruptions should retry"
	)
	_check(
		installer._is_retryable_result(HTTPRequest.RESULT_TIMEOUT),
		"timeouts should retry"
	)
	_check(
		not installer._is_retryable_result(HTTPRequest.RESULT_DOWNLOAD_FILE_WRITE_ERROR),
		"disk write errors should not retry"
	)
	_check(
		installer._result_text(HTTPRequest.RESULT_DOWNLOAD_FILE_CANT_OPEN).contains("temporary"),
		"file-open failures should identify the local temporary file"
	)
	_check(installer._safe_archive_path("game/BeastRoad.exe") == "game/BeastRoad.exe",
		"normal archive paths should be accepted")
	_check(installer._safe_archive_path("game\\BeastRoad.pck") == "game/BeastRoad.pck",
		"Windows separators should be normalized")
	_check(installer._safe_archive_path("../escape.exe").is_empty(),
		"parent traversal should be rejected")
	_check(installer._safe_archive_path("C:/escape.exe").is_empty(),
		"absolute Windows paths should be rejected")
	installer.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error("[launcher test] " + message)
