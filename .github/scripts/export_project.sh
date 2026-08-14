#!/usr/bin/env bash
#
# Exports one Godot project and, if it fails, says why somewhere a person can
# read it.
#
# The reason this exists: when the export broke, the run page showed a red step
# named "Export the game" and an annotation that said "Process completed with
# exit code 1". The actual message was in the log, and GitHub requires a signed
# in session to read Actions logs even on a public repository. So the failure
# was visible to anyone and legible to nobody, and diagnosing it meant
# reproducing the whole runner locally.
#
# Annotations and job summaries are public. Everything this script learns goes
# into those two channels, so the next export failure is diagnosable from the
# run page alone.
#
#   bash .github/scripts/export_project.sh <name> <project-dir> <out-path> <preset>
#
# <out-path> is relative to the project directory, matching how Godot itself
# resolves an export path.

set -uo pipefail

NAME="$1"
PROJECT="$2"
OUT="$3"
PRESET="$4"

# Godot resolves the export path from inside the project, so the same string
# has to be resolved from here to know which directory to create.
ABS_OUT="$(cd "$PROJECT" && printf '%s/%s' "$PWD" "$OUT")"
mkdir -p "$(dirname "$ABS_OUT")"

LOG="$(mktemp)"

# Bounded, because this project's failure mode is hanging rather than failing:
# an export that stalls with no deadline turns a red build into a silent wait
# nobody is watching.
timeout 900 godot --headless --path "$PROJECT" --export-release "$PRESET" "$OUT" 2>&1 | tee "$LOG"
status=${PIPESTATUS[0]}

fail() {
	local reason="$1"
	echo "::error title=Export failed: ${NAME}::${reason}"

	{
		echo "### Export failed: ${NAME}"
		echo ""
		echo "\`\`\`"
		tail -n 40 "$LOG"
		echo "\`\`\`"
		echo ""
		echo "Reproduce locally (needs export templates for this Godot version):"
		echo ""
		echo "\`\`\`"
		echo "godot --headless --path ${PROJECT} --export-release \"${PRESET}\" ${OUT}"
		echo "\`\`\`"
	} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

	exit 1
}

if [ "$status" -eq 124 ]; then
	fail "Timed out after 15 minutes. Something is hanging, not failing."
fi

if [ "$status" -ne 0 ]; then
	# The first real error line, not the cascade. Godot reports a failed export
	# as a configuration error followed by every consequence of it, and only the
	# opening lines say what was actually wrong.
	reason="$(grep -E '^ERROR:|^SCRIPT ERROR:|No export template' "$LOG" \
		| head -3 | tr '\n' ' ' | cut -c1-400)"
	fail "${reason:-Exited ${status} with no error line. See the summary for the log tail.}"
fi

# Exit status alone is not proof: an export can report success and write
# nothing, and the first person to find out would otherwise be a player with an
# empty folder.
if [ ! -s "$ABS_OUT" ]; then
	fail "Reported success but wrote no executable to ${OUT}."
fi

echo "Exported ${NAME}: $(du -h "$ABS_OUT" | cut -f1)"
