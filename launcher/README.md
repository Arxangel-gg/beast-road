# Beast Road Launcher

A small Godot app that installs, updates and runs the game from GitHub Releases.

It updates the game, not its own running executable. When launcher code changes,
replace `BeastRoadLauncher.exe` once from the permanent latest-release link.

- Checks `releases/latest` on the repository named in `scripts/LauncherConfig.gd`
- Installs into `%LOCALAPPDATA%\\BeastRoad`
- Retries transient GitHub/CDN failures and verifies the downloaded byte count
  and SHA-256 before unpacking
- Writes `installed.json` **last**, so an interrupted install is reported as
  "not installed" rather than as a broken game

To point it at a different repository, edit `REPO_OWNER` and `REPO_NAME` in
`scripts/LauncherConfig.gd` and rebuild. It is deliberately not configurable at
runtime: a launcher that can be aimed anywhere can be aimed somewhere hostile.

## Uninstalling

**Uninstall** sits beside Releases and Quit. It removes the installed build from
`%LOCALAPPDATA%\BeastRoad`, along with any half-finished download beside it, and
puts the launcher back to offering **Install**.

Saved progress is a separate thing and is kept by default. It lives in
`%APPDATA%\Godotpp_userdata\Beast Road`, and the dialog offers a tickbox to
delete it as well - off unless asked for, because the build is a download and the
save is a campaign. That is also what makes a clean reinstall possible: uninstall,
install again, and the game comes back fresh with the hero intact.

Every delete is checked against the two directories the launcher owns before it
happens. Handed anything else - an empty path, a drive root, a home directory -
it removes nothing and says so. `tests/release_pipeline_test.tscn` covers both
the refusal and the removal; it never calls the save deletion, because the save
path is this machine's real one and no fixture redirects it.
