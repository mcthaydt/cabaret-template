@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_SpawnRecoverySettings

@export var spawn_point_id: StringName = StringName("")
@export var unsupported_delay_sec: float = 0.6
@export var recovery_cooldown_sec: float = 1.0
@export var startup_grace_period_sec: float = 1.0
