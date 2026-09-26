class_name DiagnosticCopyData
extends GameData

## Support UI copy stays authored and localizable, separate from collection.
@export var heading: String = ""
@export var prepare_label: String = ""
@export var copy_label: String = ""
@export_multiline var ready_note: String = ""
@export_multiline var copy_requested_note: String = ""
@export_multiline var clipboard_unavailable_note: String = ""
## The main menu's one line when the last session ended without saying so.
@export var crash_notice: String = ""
## What leaves the machine, said where a player looking for it would look.
## `docs/PRIVACY.md` is the long form; `privacy_check` holds both to the code.
@export var privacy_heading: String = ""
@export_multiline var privacy_body: String = ""
