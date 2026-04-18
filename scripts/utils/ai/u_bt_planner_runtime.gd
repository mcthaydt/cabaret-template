extends RefCounted
class_name U_BTPlannerRuntime

func coerce_action_pool(value: Variant) -> Array[Object]:
	var coerced: Array[Object] = []
	if not (value is Array):
		return coerced
	for action_variant in value as Array:
		if not (action_variant is Object):
			continue
		var action: Object = action_variant as Object
		if action == null:
			continue
		if action.has_method("tick") and action.has_method("is_applicable"):
			coerced.append(action)
	return coerced

func build_world_state(world_state_builder: Object, context: Dictionary, entity_query_key: StringName) -> Dictionary:
	if world_state_builder == null:
		return {}
	var entity_query: Variant = context.get(entity_query_key, null)
	var world_state_variant: Variant = world_state_builder.call("build", entity_query)
	if world_state_variant is Dictionary:
		return (world_state_variant as Dictionary).duplicate(true)
	return {}

func goal_satisfied(goal: I_Condition, world_state: Dictionary) -> bool:
	var score_variant: Variant = goal.evaluate(world_state)
	return (score_variant is float or score_variant is int) and float(score_variant) > 0.0

func apply_action_effects(world_state: Dictionary, action: Object) -> Dictionary:
	if action == null:
		return world_state
	var effects_variant: Variant = action.call("get_effect_sequence") if action.has_method("get_effect_sequence") else action.get("effects")
	if not (effects_variant is Array):
		return world_state
	var next_state: Dictionary = world_state.duplicate(true)
	for effect_variant in effects_variant as Array:
		if not (effect_variant is Object):
			continue
		var effect: Object = effect_variant as Object
		if effect != null and effect.has_method("apply_to"):
			var result_variant: Variant = effect.call("apply_to", next_state)
			if result_variant is Dictionary:
				next_state = (result_variant as Dictionary).duplicate(true)
	return next_state

func build_plan_debug_snapshot(plan: Array[Object]) -> Dictionary:
	var plan_names: Array[StringName] = []
	var total_cost: float = 0.0
	for action: Object in plan:
		if action == null:
			continue
		plan_names.append(StringName(action.resource_name))
		var cost_variant: Variant = action.get("cost")
		if cost_variant is float or cost_variant is int:
			total_cost += float(cost_variant)
	return {
		&"last_plan": plan_names,
		&"last_plan_cost": total_cost,
	}
