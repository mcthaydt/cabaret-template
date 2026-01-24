@icon("res://assets/editor_icons/spawn_points.svg")
extends Node3D
class_name SP_SpawnPoint

## SP_SpawnPoint
##
## Data-bearing spawn point node that owns an RS_SpawnMetadata
## resource. This replaces the previous pattern where spawn points
## reused marker scripts intended for containers only.
##
## Usage:
## - Attach this script to `sp_*` nodes under `SpawnPoints`
## - Drag an RS_SpawnMetadata resource onto `spawn_metadata` in the editor

@export var spawn_metadata: RS_SpawnMetadata

func get_spawn_metadata() -> RS_SpawnMetadata:
	return spawn_metadata
