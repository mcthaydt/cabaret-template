@icon("res://resources/editor_icons/resource.svg")
extends Resource
class_name RS_SaveManagerSettings

## Configuration for M_SaveManager slot layout and legacy import behavior.

@export_group("Slots")
@export var manual_slot_count: int = 3
@export var manual_slot_pattern: String = "user://savegame_slot_%d.json"
@export var auto_slot_path: String = "user://savegame_auto.json"

@export_group("Legacy")
@export var legacy_path: String = "user://savegame.json"
@export var legacy_backup_path: String = "user://savegame_legacy_backup.json"
