class_name Installer
extends Node

## Downloads a release zip and unpacks it into the install directory.
##
## Installs go through a staging directory and the manifest is written last, so
## the only two outcomes visible to the next launch are "the previous install"
## and "the new one". A download that dies halfway leaves neither.

signal progress(stage: String, ratio: float, detail: String)
signal finished(success: bool, message: String)

## Extraction reports progress every N files rather than every file; at a few
## thousand small files the signal itself becomes the bottleneck.
const PROGRESS_EVERY: int = 24

var _http: HTTPRequest
var _release: ReleaseInfo = null
var _busy: bool = false
var _cancelled: bool = false


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	# GitHub serves release assets from a redirect to its CDN.
	_http.max_redirects = 8
	add_child(_http)
	_http.request_completed.connect(_on_download_completed)


func is_busy() -> bool:
	return _busy


func install(release: ReleaseInfo) -> void:
	if _busy:
		return
	if release == null or not release.is_usable():
		finished.emit(false, "That release has no Windows build attached.")
		return

	_busy = true
	_cancelled = false
	_release = release

	var download: String = LauncherConfig.download_path()
	DirAccess.remove_absolute(download)
	if DirAccess.make_dir_recursive_absolute(download.get_base_dir()) != OK:
		_fail("Could not create %s" % download.get_base_dir())
		return

	_http.download_file = download
	var err: int = _http.request(_release.asset_url, LauncherConfig.download_headers())
	if err != OK:
		_fail("Could not start the download (error %d)." % err)
		return
	progress.emit("Downloading", 0.0, _release.asset_name)
	set_process(true)


func cancel() -> void:
	if not _busy:
		return
	_cancelled = true
	_http.cancel_request()
	set_process(false)
	DirAccess.remove_absolute(LauncherConfig.download_path())
	_busy = false
	finished.emit(false, "Cancelled.")


func _process(_delta: float) -> void:
	if not _busy:
		return
	var total: int = _http.get_body_size()
	var got: int = _http.get_downloaded_bytes()
	# Servers may omit Content-Length; fall back to the size the API reported.
	if total <= 0:
		total = _release.asset_size
	if total <= 0:
		progress.emit("Downloading", 0.0, "%.1f MB" % (float(got) / 1048576.0))
		return
	progress.emit("Downloading", clampf(float(got) / float(total), 0.0, 1.0),
		"%.1f of %.1f MB" % [float(got) / 1048576.0, float(total) / 1048576.0])


func _on_download_completed(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	set_process(false)
	if _cancelled:
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		_fail("Download failed (result %d). Check your connection." % result)
		return
	if code < 200 or code >= 300:
		_fail("Download failed (HTTP %d)." % code)
		return
	_unpack()


func _unpack() -> void:
	progress.emit("Installing", 0.0, "unpacking")

	var staging: String = LauncherConfig.staging_dir()
	_remove_tree(staging)
	if DirAccess.make_dir_recursive_absolute(staging) != OK:
		_fail("Could not create the staging folder.")
		return

	var reader := ZIPReader.new()
	if reader.open(LauncherConfig.download_path()) != OK:
		_fail("The downloaded file is not a readable zip.")
		return

	var files: PackedStringArray = reader.get_files()
	var prefix: String = _common_prefix(files)
	var written: int = 0

	for i: int in files.size():
		var entry: String = files[i]
		if entry.ends_with("/"):
			continue
		var relative: String = entry.substr(prefix.length()) if not prefix.is_empty() else entry
		if relative.is_empty():
			continue

		var target: String = staging.path_join(relative)
		if DirAccess.make_dir_recursive_absolute(target.get_base_dir()) != OK:
			reader.close()
			_fail("Could not create %s" % target.get_base_dir())
			return
		var out: FileAccess = FileAccess.open(target, FileAccess.WRITE)
		if out == null:
			reader.close()
			_fail("Could not write %s" % target)
			return
		out.store_buffer(reader.read_file(entry))
		out.close()
		written += 1

		if i % PROGRESS_EVERY == 0:
			progress.emit("Installing", float(i) / float(maxi(files.size(), 1)), relative)

	reader.close()

	if written == 0:
		_fail("The archive was empty.")
		return

	progress.emit("Installing", 0.98, "finishing")
	if not _swap_in(staging):
		return

	DirAccess.remove_absolute(LauncherConfig.download_path())

	if not FileAccess.file_exists(LauncherConfig.game_exe_path()):
		_fail("Installed, but %s is not in the archive." % LauncherConfig.GAME_EXECUTABLE)
		return

	# Written last: this is what makes the install count as finished.
	if InstallState.write(_release.tag) != OK:
		_fail("Installed, but the version file could not be written.")
		return

	_busy = false
	finished.emit(true, "Installed %s." % _release.tag)


## Replaces the live install with the staged one. The old directory goes first;
## there is no way to make this atomic on Windows without a second copy, and a
## brief window with nothing installed is better than a merged half-old build.
func _swap_in(staging: String) -> bool:
	var install: String = LauncherConfig.install_dir()
	InstallState.clear()
	_remove_tree(install)

	var dir: DirAccess = DirAccess.open(install.get_base_dir())
	if dir == null:
		_fail("Could not open %s" % install.get_base_dir())
		return false
	if dir.rename(staging, install) != OK:
		_fail("Could not move the new build into place. Is the game running?")
		return false
	return true


## Zips built from a folder carry that folder as a prefix on every entry; zips
## built from its contents do not. Detect rather than assume, or the game ends
## up one directory deeper than the launcher looks.
func _common_prefix(files: PackedStringArray) -> String:
	var candidate: String = ""
	for entry: String in files:
		var slash: int = entry.find("/")
		if slash < 0:
			return ""  # a file at the root means there is no single wrapper
		var head: String = entry.substr(0, slash + 1)
		if candidate.is_empty():
			candidate = head
		elif candidate != head:
			return ""
	return candidate


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	var dir: DirAccess = DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var child: String = path.path_join(name)
		if dir.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(path)


func _fail(message: String) -> void:
	_busy = false
	set_process(false)
	DirAccess.remove_absolute(LauncherConfig.download_path())
	_remove_tree(LauncherConfig.staging_dir())
	finished.emit(false, message)
