# Beast Road Launcher

A small Godot app that installs, updates and runs the game from GitHub Releases.

- Checks `releases/latest` on the repository named in `scripts/LauncherConfig.gd`
- Installs into `%LOCALAPPDATA%\\BeastRoad`
- Writes `installed.json` **last**, so an interrupted install is reported as
  "not installed" rather than as a broken game

To point it at a different repository, edit `REPO_OWNER` and `REPO_NAME` in
`scripts/LauncherConfig.gd` and rebuild. It is deliberately not configurable at
runtime: a launcher that can be aimed anywhere can be aimed somewhere hostile.
