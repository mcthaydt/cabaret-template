@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionFeed

const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")

func start(context: Dictionary, task_state: Dictionary) -> void:
	var needs_component: Object = _resolve_needs_component(context)
	if needs_component == null:
		push_error("RS_AIActionFeed.start: missing C_NeedsComponent in context.")
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return

	var settings_variant: Variant = needs_component.get("settings")
	if not (settings_variant is Resource):
		push_error("RS_AIActionFeed.start: C_NeedsComponent settings are missing.")
		task_state[U_AITaskStateKeys.COMPLETED] = true
		return

	var settings: Resource = settings_variant as Resource
	var gain_on_feed: float = maxf(float(settings.get("gain_on_feed")), 0.0)
	var current_hunger: float = float(needs_component.get("hunger"))
	needs_component.set("hunger", clampf(current_hunger + gain_on_feed, 0.0, 1.0))
	task_state[U_AITaskStateKeys.COMPLETED] = true

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AITaskStateKeys.COMPLETED, false))

func _resolve_needs_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var needs_variant: Variant = components.get(C_NEEDS_COMPONENT.COMPONENT_TYPE, null)
	if not (needs_variant is Object):
		return null
	return needs_variant as Object
