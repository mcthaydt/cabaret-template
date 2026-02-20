@icon("res://assets/editor_icons/icn_resource.svg")
extends Resource
class_name RS_QBRuleDefinition

enum TriggerMode {
	TICK,
	EVENT,
	BOTH,
}

@export_group("Identity")
@export var rule_id: StringName = &""
@export_multiline var description: String = ""

@export_group("Trigger")
@export var trigger_mode: TriggerMode = TriggerMode.TICK
@export var trigger_event: StringName = &""

@export_group("Evaluation")
@export var conditions: Array = []
@export var effects: Array = []
@export var priority: int = 0
@export var is_one_shot: bool = false
@export var requires_salience: bool = true

@export_group("Cooldown")
@export var cooldown: float = 0.0
## Empty = global cooldown bucket for this rule.
## Provide context keys (for example, entity_id) to scope cooldowns per context.
@export var cooldown_key_fields: Array[String] = []
## Optional context field that overrides `cooldown` at runtime when present.
@export var cooldown_from_context_field: String = ""

func uses_event_trigger() -> bool:
	return trigger_mode == TriggerMode.EVENT or trigger_mode == TriggerMode.BOTH

func get_effective_requires_salience() -> bool:
	if trigger_mode == TriggerMode.EVENT:
		return false
	return requires_salience
