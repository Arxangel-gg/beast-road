class_name BuildInfo
extends RefCounted

## Which build this is (GDD §46).
##
## > "The game displays its semantic version in Settings and the debrief
## > diagnostics panel."
##
## It appeared nowhere. That is a small thing right up until somebody reports a
## bug: without it neither the player nor the person reading the report can say
## which build it came from, and half of "I can't reproduce that" is really "we
## were not running the same thing".
##
## Stamped by CI into `VERSION` just before export, exactly like the launcher,
## and never committed — so the repository copy stays "dev" and a build made on
## somebody's machine says so instead of impersonating a release.

## Replaced by the release workflow with the tag being built.
const VERSION: String = "dev"


## True for a build CI produced from a tag.
static func is_release() -> bool:
	return VERSION != "dev" and not VERSION.is_empty()


## What to show a player. A development build says so rather than showing
## nothing, because "no version" and "a version I forgot to read" look identical
## in a screenshot.
static func display() -> String:
	return VERSION if is_release() else "development build"


## The line that belongs in a bug report: version, platform and renderer.
##
## The renderer matters more than it looks. Most "the game looks wrong" reports
## are a driver or a backend, and it is the one fact a player cannot easily find
## and will never think to include.
static func diagnostics() -> String:
	return "%s  ·  %s  ·  %s" % [
		display(),
		OS.get_name(),
		RenderingServer.get_video_adapter_name(),
	]
