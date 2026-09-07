class_name DiagnosticCopyData
extends GameData

## Support UI copy stays authored and localizable, separate from collection.
@export var heading: String = ""
@export var prepare_label: String = ""
@export var copy_label: String = ""
@export_multiline var ready_note: String = ""
@export_multiline var copy_requested_note: String = ""
@export_multiline var clipboard_unavailable_note: String = ""
