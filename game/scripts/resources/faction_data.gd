class_name FactionData
extends GameData

## Narrative and combat identity for one authored region. Keeping the launch
## copy in data lets codex, previews and localization consume the same source.
@export_range(1, 3) var act: int = 1
@export var terrain_id: String = ""
@export var regular_enemy_ids: Array[String] = []
@export var elite_enemy_ids: Array[String] = []
@export_multiline var visual_identity: String = ""
@export_multiline var mechanical_identity: String = ""
