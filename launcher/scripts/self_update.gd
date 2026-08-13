class_name SelfUpdate
extends Node

## Replaces the launcher with a newer launcher.
##
## Without this, every launcher change is a message asking players to go and
## download the launcher again by hand — which is exactly the job the launcher
## exists to do, and the one thing it could not do for itself.
##
## **Windows will not let a running executable overwrite itself.** The file is
## locked for writing for as long as the process is alive, so there is no way to
## do this from inside the program that is being replaced. The standard dance,
## and the one used here:
##
##   1. download the new launcher beside the old one, under a temporary name;
##   2. write a small batch script that waits for this process to exit, swaps
##      the files, deletes the temporary, and starts the new launcher;
##   3. launch that script detached, then quit.
##
## The order matters. The swap only happens once the download has completely
## finished and been size-checked, so a dropped connection leaves a stray
## temporary file and a launcher that still works. The batch script keeps the old
## executable until the copy succeeds, so a failed swap is also survivable — the
## worst case is an unchanged launcher and a file to clean up, never a machine
## with no launcher on it at all.

signal progress(ratio: float, detail: String)
signal finished(success: bool, message: String)

## Below this, the download is not a launcher; GitHub serves HTML error pages
## with a 200 and they would otherwise be written straight over the executable.
const MIN_PLAUSIBLE_BYTES: int = 2 * 1024 * 1024

var _http: HTTPRequest
var _release: ReleaseInfo = null
var _busy: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	_http.max_redirects = 8
	add_child(_http)
	_http.request_completed.connect(_on_downloaded)


func is_busy() -> bool:
	return _busy


## Where the running launcher lives. `OS.get_executable_path()` is the launcher
## itself in an export, and the Godot binary when run from the editor — which is
## why `run()` refuses unless the build carries a CI version stamp.
static func current_exe() -> String:
	return OS.get_executable_path().replace("\\", "/")


static func _staged_exe() -> String:
	return current_exe() + ".new"


func run(release: ReleaseInfo) -> void:
	if _busy:
		return
	if release == null or not release.has_launcher_update():
		finished.emit(false, "No launcher update is attached to that release.")
		return

	_busy = true
	_release = release
	progress.emit(0.0, "Downloading %s" % release.launcher_name)

	var staged: String = _staged_exe()
	DirAccess.remove_absolute(staged)
	_http.download_file = staged
	var error: Error = _http.request(
		release.launcher_url, LauncherConfig.download_headers(), HTTPClient.METHOD_GET)
	if error != OK:
		_fail("Could not start the launcher download (%d)." % error)


func _process(_delta: float) -> void:
	if not _busy:
		return
	var total: int = _http.get_body_size()
	var got: int = _http.get_downloaded_bytes()
	if total > 0:
		progress.emit(float(got) / float(total),
			"Downloading launcher  %s / %s" % [_megabytes(got), _megabytes(total)])


func _on_downloaded(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not _busy:
		return
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_fail("The launcher download failed (HTTP %d)." % code)
		return

	var staged: String = _staged_exe()
	if not FileAccess.file_exists(staged):
		_fail("The launcher download produced no file.")
		return

	# Size-checked before anything is swapped. A truncated download and an error
	# page are both "a file that exists", and neither is a launcher.
	var size: int = _file_size(staged)
	if size < MIN_PLAUSIBLE_BYTES:
		DirAccess.remove_absolute(staged)
		_fail("The downloaded launcher was only %s and cannot be real." % _megabytes(size))
		return
	if _release.launcher_size > 0 and size != _release.launcher_size:
		DirAccess.remove_absolute(staged)
		_fail("The launcher download was incomplete (%s of %s)."
			% [_megabytes(size), _megabytes(_release.launcher_size)])
		return

	progress.emit(1.0, "Restarting into the new launcher…")
	if not _hand_over(staged):
		DirAccess.remove_absolute(staged)
		_fail("Could not start the update helper.")
		return

	_busy = false
	finished.emit(true, "Restarting…")


## Writes and starts the script that does the swap after this process exits.
##
## Batch rather than PowerShell: execution policy can block a .ps1 on a locked-
## down machine, and this has to work on someone else's computer without them
## configuring anything.
func _hand_over(staged: String) -> bool:
	var current: String = current_exe()
	var helper: String = current.get_base_dir().path_join("beast_road_update.cmd")

	var script: String = "\r\n".join([
		"@echo off",
		"setlocal",
		# Wait for this process to release the file. `tasklist` polling is
		# tedious but universal; timeout /t needs a console it may not have.
		":wait",
		'tasklist /fi "PID eq %d" 2>nul | find "%d" >nul' % [OS.get_process_id(), OS.get_process_id()],
		"if not errorlevel 1 (",
		'  ping -n 2 127.0.0.1 >nul',
		"  goto wait",
		")",
		# Copy, not move: if this fails the original is still there and still runs.
		'copy /y "%s" "%s" >nul' % [staged.replace("/", "\\"), current.replace("/", "\\")],
		"if errorlevel 1 goto done",
		'del /q "%s" >nul 2>&1' % staged.replace("/", "\\"),
		'start "" "%s"' % current.replace("/", "\\"),
		":done",
		# The helper deletes itself last. Nothing else would ever clean it up.
		'del /q "%~f0" >nul 2>&1',
		"",
	])

	var file: FileAccess = FileAccess.open(helper, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(script)
	file.close()

	# Detached: it has to outlive the process it is waiting for.
	var pid: int = OS.create_process("cmd.exe", ["/c", helper.replace("/", "\\")], false)
	return pid > 0


func _fail(message: String) -> void:
	_busy = false
	finished.emit(false, message)


static func _file_size(path: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return 0
	var size: int = file.get_length()
	file.close()
	return size


static func _megabytes(bytes: int) -> String:
	return "%.1f MB" % (float(bytes) / 1048576.0)
