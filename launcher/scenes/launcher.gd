class_name Launcher
extends Control

## The launcher window.
##
## One button that always says the single most useful thing it can: Install,
## Update, or Play. Everything else on screen exists to justify that word —
## what version, how big, what changed.

enum State {
	CHECKING,
	NOT_INSTALLED,
	UPDATE_AVAILABLE,
	UP_TO_DATE,
	WORKING,
	OFFLINE,
	ERROR,
	## A newer launcher exists. Offered before a game update, because installing
	## the game with a launcher that is about to replace itself means doing the
	## long download and then immediately restarting on top of it.
	LAUNCHER_UPDATE,
}

@export var title_label: Label
@export var version_label: Label
@export var status_label: Label
@export var notes_label: RichTextLabel
@export var notes_panel: Control
@export var primary_button: Button
@export var secondary_button: Button
@export var releases_button: Button
@export var quit_button: Button
@export var progress_bar: ProgressBar
@export var spinner: Label
@export var installer: Installer
@export var self_update: SelfUpdate

var _http: HTTPRequest
var _state: State = State.CHECKING
var _installed: InstallState
var _uninstall_button: Button
var _uninstall_dialog: ConfirmationDialog
var _uninstall_label: Label
var _wipe_saves: CheckBox
var _latest: ReleaseInfo = null
var _spin_time: float = 0.0
var _stage_time: float = 0.0
@onready var _backdrop: TextureRect = get_node("Backdrop") as TextureRect
@onready var _logo: TextureRect = get_node("Logo") as TextureRect

## Set once the player declines a launcher update, so it is offered once per
## session and not re-offered every time the launcher re-checks.
var _skip_launcher_update: bool = false

const SPINNER_FRAMES: Array[String] = ["·  ", "·· ", "···", " ··", "  ·", "   "]


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.use_threads = true
	add_child(_http)
	_http.request_completed.connect(_on_release_fetched)

	primary_button.pressed.connect(_on_primary)
	secondary_button.pressed.connect(_on_secondary)
	releases_button.pressed.connect(func() -> void: OS.shell_open(LauncherConfig.releases_page_url()))
	quit_button.pressed.connect(func() -> void: get_tree().quit())
	_build_uninstall()

	installer.progress.connect(_on_install_progress)
	installer.finished.connect(_on_install_finished)

	if self_update != null:
		self_update.progress.connect(func(ratio: float, detail: String) -> void:
			_on_install_progress("Launcher", ratio, detail))
		self_update.finished.connect(_on_self_update_finished)

	title_label.text = "One hero, four roads, and a town that cannot be defended everywhere at once."
	notes_panel.visible = false
	progress_bar.visible = false

	_refresh_installed()
	_check_for_updates()


func _process(delta: float) -> void:
	# The main menu is a living pixel-art road rather than a poster. The launcher
	# uses the same art and the same restrained motion language so the hand-off
	# feels like one product: long backdrop drift, barely perceptible logo breath.
	_stage_time += delta
	if _backdrop != null:
		var drift: float = sin(_stage_time * 0.075) * 10.0
		_backdrop.offset_left = -18.0 + drift
		_backdrop.offset_right = 18.0 + drift
	if _logo != null:
		var bob: float = sin(_stage_time * 0.52) * 2.0
		_logo.offset_top = 46.0 + bob
		_logo.offset_bottom = 330.0 + bob

	if _state != State.CHECKING and _state != State.WORKING:
		spinner.text = ""
		return
	_spin_time += delta
	spinner.text = SPINNER_FRAMES[int(_spin_time * 6.0) % SPINNER_FRAMES.size()]


# --- Uninstalling -----------------------------------------------------------

## The button and its confirmation, built here rather than in the scene.
##
## A player who no longer wants the game should not have to go looking through
## AppData for it, and one who wants a clean reinstall should be able to get one
## without knowing where anything lives.
func _build_uninstall() -> void:
	_uninstall_button = Button.new()
	_uninstall_button.text = "Uninstall"
	_uninstall_button.tooltip_text = "Remove the installed game from this computer."
	_uninstall_button.pressed.connect(_on_uninstall)
	if releases_button.get_parent() != null:
		releases_button.get_parent().add_child(_uninstall_button)
		releases_button.get_parent().move_child(_uninstall_button, 0)

	_uninstall_dialog = ConfirmationDialog.new()
	_uninstall_dialog.title = "Uninstall Beast Road"
	_uninstall_dialog.ok_button_text = "Uninstall"
	_uninstall_dialog.confirmed.connect(_do_uninstall)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_uninstall_label = Label.new()
	_uninstall_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_uninstall_label.custom_minimum_size = Vector2(420.0, 0.0)
	column.add_child(_uninstall_label)
	# **Off by default, and named plainly.** The build is a download; the save is
	# a campaign. A dialog that treats them as one thing will eventually delete
	# somebody's hero because they wanted a clean reinstall.
	_wipe_saves = CheckBox.new()
	_wipe_saves.text = "Also delete my saved progress (cannot be undone)"
	column.add_child(_wipe_saves)
	_uninstall_dialog.add_child(column)
	add_child(_uninstall_dialog)


func _on_uninstall() -> void:
	_refresh_installed()
	if not _installed.installed:
		status_label.text = "There is no installed build to remove."
		return
	_wipe_saves.button_pressed = false
	_wipe_saves.disabled = not Uninstaller.save_exists()
	_uninstall_label.text = ("This removes the installed game from %s.

"
		+ "Your saved progress is kept unless you tick the box below, so "
		+ "reinstalling from here gives you a clean copy of the game with your "
		+ "campaign intact.") % LauncherConfig.install_dir_static()
	if not Uninstaller.save_exists():
		_uninstall_label.text += "

No saved progress was found on this computer."
	_uninstall_dialog.popup_centered()


func _do_uninstall() -> void:
	var report: Dictionary = Uninstaller.remove_build()
	var said: String = Uninstaller.describe(report)
	if _wipe_saves.button_pressed:
		var saves: Dictionary = Uninstaller.remove_saves()
		said += "  " + ("Saved progress deleted."
			if bool(saves.get("ok", false)) else Uninstaller.describe(saves))
	InstallState.clear()
	_refresh_installed()
	# Back to whatever the release check already knows, which after this is
	# "not installed" - so the primary button becomes Install again rather than
	# offering Play for something that is no longer there.
	_evaluate_release()
	status_label.text = said


# --- Checking ---------------------------------------------------------------

func _refresh_installed() -> void:
	_installed = InstallState.read()


func _check_for_updates() -> void:
	_set_state(State.CHECKING)
	var err: int = _http.request(LauncherConfig.latest_release_url(), LauncherConfig.api_headers())
	if err != OK:
		_offline("Could not reach GitHub.")


func _on_release_fetched(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		_offline("No connection.")
		return
	if code == 404:
		# A 404 here almost always means the repo is private or has no releases,
		# not that the launcher is broken — say so rather than "unknown error".
		_offline("No published release found. Is the repository public?")
		return
	if code == 403:
		_offline("GitHub rate-limited this machine. Try again in a few minutes.")
		return
	if code < 200 or code >= 300:
		_offline("GitHub returned HTTP %d." % code)
		return

	_latest = ReleaseInfo.from_json(body.get_string_from_utf8())
	if _latest == null or not _latest.is_usable():
		_offline("The latest release has no Windows build attached.")
		return

	if not _latest.notes.is_empty():
		notes_label.text = _latest.notes
		notes_panel.visible = true

	_refresh_mirrors()
	_evaluate_release()


## Fetches the release's mirror list and keeps a copy.
##
## **The list in the release body is used first, and it is the one that works.**
## The `mirrors.json` asset is served from
## `release-assets.githubusercontent.com` - the very host the mirror list exists
## to route around - so fetching it was a request that could only succeed for
## players who did not need it. A friend of the owner's behind a national filter
## sat on "Retrying... no data from GitHub for 20 seconds" indefinitely: their
## launcher had read the API perfectly, knew the latest tag, rendered the
## changelog, and still had an empty mirror list, because the only copy it knew
## how to reach was behind the block.
##
## The body arrives in the same `api.github.com` response as the tag. If the
## launcher knows an update exists, it already has this.
##
## **Nothing waits for the fallback.** It is a few hundred bytes and the download
## it informs is minutes away; blocking the interface on it would trade a certain
## delay for an uncertain benefit. If it never arrives, the cached copy from last
## time is used, and if there is no cache the launcher simply has GitHub - which
## is where it was before mirrors existed.
func _refresh_mirrors() -> void:
	if _latest == null:
		return
	# In the release notes: already in hand, nothing to fetch, nothing to block.
	if not _latest.mirrors_inline.is_empty():
		if LauncherConfig.remember_mirrors(_latest.mirrors_inline):
			return
	# Older releases carried the list only as an asset. Still worth trying: a
	# player who can reach the CDN is not harmed by one small request, and a
	# player who cannot is no worse off than before.
	if _latest.mirrors_url.is_empty():
		return
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(
		func(result: int, code: int, _h: PackedStringArray,
				payload: PackedByteArray) -> void:
			if result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300:
				LauncherConfig.remember_mirrors(payload.get_string_from_utf8())
			request.queue_free())
	if request.request(_latest.mirrors_url, LauncherConfig.download_headers()) != OK:
		request.queue_free()


## Which state this release puts the launcher in.
##
## Separated out because "Not now" on a launcher update has to re-run exactly
## this decision without re-fetching, and duplicating the ladder is how the two
## copies end up disagreeing.
func _evaluate_release() -> void:
	if _latest == null:
		return
	if _latest.has_launcher_update() and not _skip_launcher_update:
		_set_state(State.LAUNCHER_UPDATE)
	elif not _installed.installed:
		_set_state(State.NOT_INSTALLED)
	elif _latest.differs_from(_installed.tag):
		_set_state(State.UPDATE_AVAILABLE)
	else:
		_set_state(State.UP_TO_DATE)


func _launcher_size_text() -> String:
	if _latest == null or _latest.launcher_size <= 0:
		return "unknown size"
	return "%.1f MB" % (float(_latest.launcher_size) / 1048576.0)


## The helper script restarts the launcher, so there is nothing left to do here
## but get out of its way and release the file it is waiting to overwrite.
func _on_self_update_finished(success: bool, message: String) -> void:
	if success:
		status_label.text = message
		get_tree().quit()
		return
	progress_bar.visible = false
	_skip_launcher_update = true
	_set_state(State.ERROR)
	status_label.text = message


## Offline is not an error state when the game is already installed — you should
## still be able to play a game you own without GitHub being reachable.
func _offline(reason: String) -> void:
	_latest = null
	_set_state(State.OFFLINE)
	status_label.text = reason + ("  Playing the installed build." if _installed.installed else "")


# --- Actions ----------------------------------------------------------------

func _on_primary() -> void:
	match _state:
		State.LAUNCHER_UPDATE:
			self_update.run(_latest)
			_set_state(State.WORKING)
		State.NOT_INSTALLED, State.UPDATE_AVAILABLE:
			installer.install(_latest)
			_set_state(State.WORKING)
		State.UP_TO_DATE, State.OFFLINE:
			_play()
		State.ERROR:
			_check_for_updates()
		_:
			pass


func _on_secondary() -> void:
	match _state:
		State.WORKING:
			installer.cancel()
		State.LAUNCHER_UPDATE:
			# Skippable. A launcher update is never allowed to stand between a
			# player and a game they already have installed.
			_skip_launcher_update = true
			_evaluate_release()
		State.UPDATE_AVAILABLE:
			_play()
		_:
			_check_for_updates()


func _play() -> void:
	if not _installed.installed:
		status_label.text = "Nothing installed yet."
		return
	var pid: int = OS.create_process(_installed.exe_path, PackedStringArray())
	if pid <= 0:
		status_label.text = "Could not start %s." % LauncherConfig.GAME_EXECUTABLE
		return
	# The launcher's job is done the moment the game is running.
	get_tree().quit()


func _on_install_progress(stage: String, ratio: float, detail: String) -> void:
	progress_bar.visible = true
	progress_bar.value = ratio
	status_label.text = "%s   %s" % [stage, detail]


func _on_install_finished(success: bool, message: String) -> void:
	progress_bar.visible = false
	_refresh_installed()
	if success:
		_set_state(State.UP_TO_DATE)
		status_label.text = message + "  Ready."
	else:
		_set_state(State.ERROR)
		status_label.text = message


# --- Presentation -----------------------------------------------------------

func _set_state(state: State) -> void:
	_state = state

	var installed_text: String = _installed.tag if _installed.installed else "not installed"
	var latest_text: String = _latest.tag if _latest != null else "—"
	version_label.text = "Installed  %s      Latest  %s" % [installed_text, latest_text]

	primary_button.disabled = false
	secondary_button.visible = false
	secondary_button.disabled = false

	match state:
		State.CHECKING:
			primary_button.text = "Checking…"
			primary_button.disabled = true
			status_label.text = "Looking for the latest build."
		State.NOT_INSTALLED:
			primary_button.text = "Install"
			status_label.text = "%s  ·  %s" % [_latest.tag, _latest.size_text()]
		State.UPDATE_AVAILABLE:
			primary_button.text = "Update"
			secondary_button.visible = true
			secondary_button.text = "Play anyway"
			status_label.text = "%s is available  ·  %s" % [_latest.tag, _latest.size_text()]
		State.UP_TO_DATE:
			primary_button.text = "Play"
			secondary_button.visible = true
			secondary_button.text = "Check again"
			status_label.text = "Up to date."
		State.WORKING:
			primary_button.text = "Working…"
			primary_button.disabled = true
			secondary_button.visible = true
			secondary_button.text = "Cancel"
		State.OFFLINE:
			# With nothing installed the only useful move is to try again, so
			# there is no second button offering the same thing.
			primary_button.text = "Play" if _installed.installed else "Retry"
			secondary_button.visible = _installed.installed
			secondary_button.text = "Retry"
		State.LAUNCHER_UPDATE:
			primary_button.text = "Update launcher"
			secondary_button.visible = true
			secondary_button.text = "Not now"
			status_label.text = "A newer launcher (%s) is available  ·  %s" % [
				_latest.tag, _launcher_size_text()]
		State.ERROR:
			primary_button.text = "Retry"
