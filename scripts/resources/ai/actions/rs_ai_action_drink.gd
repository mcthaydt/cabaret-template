@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionDrink

const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")
const RS_NEEDS_SETTINGS := preload("res://scripts/resources/ecs/rs_needs_settings.gd")

@export var drink_seconds: float = 1.5

func start(context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.ELAPSED] = 0.0
	print("[ACTION] %s Drink started (duration=%.2fs)" % [_resolve_entity_label(context), maxf(drink_seconds, 0.0)])

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = task_state.get(U_AITaskStateKeys.ELAPSED, 0.0)
	task_state[U_AITaskStateKeys.ELAPSED] = elapsed + maxf(delta, 0.0)

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	var elapsed: float = task_state.get(U_AITaskStateKeys.ELAPSED, 0.0)
	if elapsed < maxf(drink_seconds, 0.0):
		return false
	_apply_drink(context)
	print("[ACTION] %s Drink complete after %.2fs" % [_resolve_entity_label(context), elapsed])
	return true

func _apply_drink(context: Dictionary) -> void:
	var needs: Object = _resolve_needs(context)
	if needs == null:
		return
	var settings_variant: Variant = needs.get("settings")
	if not (settings_variant is RS_NeedsSettings):
		return
	var settings: RS_NeedsSettings = settings_variant as RS_NeedsSettings
	var gain: float = maxf(settings.gain_on_drink, 0.0)
	var current_thirst: float = 1.0
	var thirst_variant: Variant = needs.get("thirst")
	if thirst_variant is float:
		current_thirst = thirst_variant
	needs.set("thirst", clampf(current_thirst + gain, 0.0, 1.0))

func _resolve_needs(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(C_NEEDS_COMPONENT.COMPONENT_TYPE, null)

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
