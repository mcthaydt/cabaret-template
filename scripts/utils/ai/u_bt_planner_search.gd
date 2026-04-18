extends RefCounted
class_name U_BTPlannerSearch

const FLOAT_EPSILON: float = 0.00001

func find_plan(initial_state: Dictionary, goal: I_Condition, pool: Array, max_depth: int) -> Array:
	var safe_initial_state: Dictionary = initial_state.duplicate(true)
	if goal == null:
		push_error("U_BTPlannerSearch.find_plan: goal is null")
		return []

	var safe_depth: int = maxi(max_depth, 0)
	if _goal_passes(goal, safe_initial_state):
		return []

	var planner_actions: Array[Object] = _coerce_pool(pool)
	if planner_actions.is_empty():
		_push_no_plan_context(safe_initial_state, goal, pool.size(), safe_depth)
		return []

	var frontier: Array[Dictionary] = []
	frontier.append(_build_node(safe_initial_state, [], 0.0, 0))

	var best_cost_by_state: Dictionary = {}
	best_cost_by_state[_state_signature(safe_initial_state)] = 0.0

	var hit_depth_cap: bool = false
	while not frontier.is_empty():
		var current_node: Dictionary = _pop_lowest_cost_node(frontier)
		if _goal_passes(goal, current_node.get(&"state", {})):
			var plan_variant: Variant = current_node.get(&"plan", [])
			if plan_variant is Array:
				return plan_variant as Array
			return []

		var current_depth: int = int(current_node.get(&"depth", 0))
		if current_depth >= safe_depth:
			hit_depth_cap = true
			continue

		var current_state_variant: Variant = current_node.get(&"state", {})
		if not (current_state_variant is Dictionary):
			continue
		var current_state: Dictionary = current_state_variant as Dictionary
		var current_signature: String = _state_signature(current_state)
		var current_cost: float = float(current_node.get(&"cost", 0.0))

		for action: Object in planner_actions:
			if action == null:
				continue
			var applicable_variant: Variant = action.call("is_applicable", current_state)
			if not (applicable_variant is bool and bool(applicable_variant)):
				continue

			var effects_variant: Variant = []
			if action.has_method("get_effect_sequence"):
				effects_variant = action.call("get_effect_sequence")
			else:
				effects_variant = action.get("effects")
			if not (effects_variant is Array):
				continue
			var next_effects: Array = effects_variant as Array
			var next_state: Dictionary = _apply_effects(current_state, next_effects)
			var next_signature: String = _state_signature(next_state)
			if next_signature == current_signature:
				continue

			var next_depth: int = current_depth + 1
			var action_cost: float = _coerce_positive_cost(action.get("cost"))
			var next_cost: float = current_cost + maxf(action_cost, FLOAT_EPSILON)
			var best_known_cost: float = _get_best_known_cost(best_cost_by_state, next_signature)
			if next_cost >= (best_known_cost - FLOAT_EPSILON):
				continue

			best_cost_by_state[next_signature] = next_cost
			var current_plan: Array = current_node.get(&"plan", [])
			var next_plan: Array = current_plan.duplicate()
			next_plan.append(action)
			frontier.append(_build_node(next_state, next_plan, next_cost, next_depth))

	if hit_depth_cap:
		push_error("U_BTPlannerSearch.find_plan: no plan found within depth %d" % safe_depth)
	return []

func _build_node(state: Dictionary, plan: Array, cost: float, depth: int) -> Dictionary:
	return {
		&"state": state.duplicate(true),
		&"plan": plan.duplicate(),
		&"cost": cost,
		&"depth": depth,
	}

func _coerce_pool(pool: Array) -> Array[Object]:
	var coerced: Array[Object] = []
	for action_variant in pool:
		if not (action_variant is Object):
			continue
		var candidate: Object = action_variant as Object
		if candidate == null:
			continue
		if not candidate.has_method("is_applicable"):
			continue
		if not candidate.has_method("tick"):
			continue
		if not _has_property(candidate, "effects"):
			continue
		if not _has_property(candidate, "cost"):
			continue
		coerced.append(candidate)
	return coerced

func _goal_passes(goal: I_Condition, state: Dictionary) -> bool:
	return goal.evaluate(state) > 0.0

func _pop_lowest_cost_node(frontier: Array[Dictionary]) -> Dictionary:
	var best_index: int = 0
	var best_cost: float = float(frontier[0].get(&"cost", 0.0))
	var best_depth: int = int(frontier[0].get(&"depth", 0))
	for index in range(1, frontier.size()):
		var candidate: Dictionary = frontier[index]
		var candidate_cost: float = float(candidate.get(&"cost", 0.0))
		if candidate_cost < (best_cost - FLOAT_EPSILON):
			best_index = index
			best_cost = candidate_cost
			best_depth = int(candidate.get(&"depth", 0))
			continue
		if absf(candidate_cost - best_cost) <= FLOAT_EPSILON:
			var candidate_depth: int = int(candidate.get(&"depth", 0))
			if candidate_depth < best_depth:
				best_index = index
				best_depth = candidate_depth

	var selected: Dictionary = frontier[best_index]
	frontier.remove_at(best_index)
	return selected

func _state_signature(state: Dictionary) -> String:
	var keys: Array[StringName] = []
	for key_variant in state.keys():
		if key_variant is StringName:
			keys.append(key_variant as StringName)
		else:
			keys.append(StringName(str(key_variant)))
	keys.sort()

	var parts: Array[String] = []
	for key: StringName in keys:
		var value: Variant = null
		if state.has(key):
			value = state[key]
		elif state.has(String(key)):
			value = state[String(key)]
		parts.append("%s=%s" % [String(key), var_to_str(value)])
	return "|".join(parts)

func _get_best_known_cost(best_cost_by_state: Dictionary, signature: String) -> float:
	var known_cost_variant: Variant = best_cost_by_state.get(signature, INF)
	if known_cost_variant is float or known_cost_variant is int:
		return float(known_cost_variant)
	return INF

func _has_property(candidate: Object, property_name: String) -> bool:
	for property_variant in candidate.get_property_list():
		if not (property_variant is Dictionary):
			continue
		var property_definition: Dictionary = property_variant as Dictionary
		var name_variant: Variant = property_definition.get("name", "")
		if str(name_variant) == property_name:
			return true
	return false

func _coerce_positive_cost(cost_variant: Variant) -> float:
	if cost_variant is float or cost_variant is int:
		return maxf(float(cost_variant), FLOAT_EPSILON)
	return FLOAT_EPSILON

func _apply_effects(state: Dictionary, effects: Array) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	for effect_variant in effects:
		if not (effect_variant is Object):
			continue
		var effect: Object = effect_variant as Object
		if effect == null or not effect.has_method("apply_to"):
			continue
		var next_state_variant: Variant = effect.call("apply_to", next_state)
		if next_state_variant is Dictionary:
			next_state = (next_state_variant as Dictionary).duplicate(true)
	return next_state

func _push_no_plan_context(initial_state: Dictionary, goal: I_Condition, pool_size: int, depth: int) -> void:
	push_error("U_BTPlannerSearch.find_plan: no plan found, pool size=%d" % pool_size)
	push_error("U_BTPlannerSearch.find_plan: no plan found, depth=%d" % depth)
	push_error("U_BTPlannerSearch.find_plan: no plan found, goal=%s" % str(goal))
	push_error("U_BTPlannerSearch.find_plan: no plan found, initial state=%s" % var_to_str(initial_state))
