@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_Rule

const BASE_CONDITION_SCRIPT := preload("res://scripts/resources/qb/rs_base_condition.gd")
const BASE_EFFECT_SCRIPT := preload("res://scripts/resources/qb/rs_base_effect.gd")

@export_group("Identity")
@export var rule_id: StringName
@export_multiline var description: String = ""

@export_group("Trigger")
@export_enum("tick", "event", "both") var trigger_mode: String = "tick"

@export_group("Evaluation")
# Fallback for headless parser stability: use Resource arrays when new class_name
# symbols are not yet resolvable in typed Array annotations.
@export var conditions: Array[Resource] = []
@export var effects: Array[Resource] = []
@export var score_threshold: float = 0.0

@export_group("Selection")
@export var decision_group: StringName
@export var priority: int = 0

@export_group("Behavior")
@export var cooldown: float = 0.0
@export var one_shot: bool = false
@export var requires_rising_edge: bool = false
