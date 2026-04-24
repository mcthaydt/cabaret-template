extends RefCounted
class_name U_BTPlannerSearch

const FLOAT_EPSILON: float = 0.00001

func find_plan(initial_state: Dictionary, goal: I_Condition, pool: Array, max_depth: int) -> Array:
	if goal == null:
		push_error("U_BTPlannerSearch.find_plan: goal is null")
		return []
	var safe_state: Dictionary = initial_state.duplicate(true)
	var safe_depth: int = maxi(max_depth, 0)
	if goal.evaluate(safe_state) > 0.0:
		return []
	var actions: Array[Object] = _coerce_pool(pool)
	if actions.is_empty():
		_push_no_plan_context(safe_state, goal, pool.size(), safe_depth)
		return []
	var frontier: Array[Dictionary] = [_node(safe_state, [], 0.0, 0)]
	var best: Dictionary = {_sig(safe_state): 0.0}
	while not frontier.is_empty():
		var node: Dictionary = _pop_best(frontier)
		var node_state: Dictionary = node.get(&"state", {})
		if goal.evaluate(node_state) > 0.0:
			var pv: Variant = node.get(&"plan", [])
			return pv as Array if pv is Array else []
		var depth: int = int(node.get(&"depth", 0))
		if depth >= safe_depth:
			continue
		var sig: String = _sig(node_state)
		var cost: float = float(node.get(&"cost", 0.0))
		for action: Object in actions:
			if action == null:
				continue
			var ok: Variant = action.call("is_applicable", node_state)
			if not (ok is bool and bool(ok)):
				continue
			var ev: Variant = action.call("get_effect_sequence") if action.has_method("get_effect_sequence") else action.get("effects")
			if not (ev is Array):
				continue
			var next_state: Dictionary = _apply_effects(node_state, ev as Array)
			var next_sig: String = _sig(next_state)
			if next_sig == sig:
				continue
			var cv: Variant = action.get("cost")
			var next_cost: float = cost + maxf(float(cv) if cv is float or cv is int else FLOAT_EPSILON, FLOAT_EPSILON)
			if next_cost >= (float(best.get(next_sig, INF)) - FLOAT_EPSILON):
				continue
			best[next_sig] = next_cost
			var np: Array = (node.get(&"plan", []) as Array).duplicate()
			np.append(action)
			frontier.append(_node(next_state, np, next_cost, depth + 1))
	_push_no_plan_context(safe_state, goal, pool.size(), safe_depth)
	return []

func _node(state: Dictionary, plan: Array, cost: float, depth: int) -> Dictionary:
	return {&"state": state.duplicate(true), &"plan": plan.duplicate(), &"cost": cost, &"depth": depth}

func _coerce_pool(pool: Array) -> Array[Object]:
	var out: Array[Object] = []
	for v in pool:
		if not (v is Object):
			continue
		var o: Object = v as Object
		if o == null:
			continue
		if o.has_method("is_applicable") and o.has_method("tick") and _has_prop(o, "effects") and _has_prop(o, "cost"):
			out.append(o)
	return out

func _has_prop(o: Object, name: String) -> bool:
	for p: Dictionary in o.get_property_list():
		if str(p.get("name", "")) == name:
			return true
	return false

func _pop_best(frontier: Array[Dictionary]) -> Dictionary:
	var bi: int = 0
	for i in range(1, frontier.size()):
		var a: Dictionary = frontier[bi]
		var b: Dictionary = frontier[i]
		var ac: float = float(a.get(&"cost", 0.0))
		var bc: float = float(b.get(&"cost", 0.0))
		if bc < (ac - FLOAT_EPSILON) or (absf(bc - ac) <= FLOAT_EPSILON and int(b.get(&"depth", 0)) < int(a.get(&"depth", 0))):
			bi = i
	var sel: Dictionary = frontier[bi]
	frontier.remove_at(bi)
	return sel

func _sig(state: Dictionary) -> String:
	var keys: Array = state.keys()
	keys.sort()
	var parts: Array[String] = []
	for k in keys:
		parts.append("%s=%s" % [str(k), var_to_str(state[k])])
	return "|".join(parts)

func _apply_effects(state: Dictionary, effects: Array) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	for v in effects:
		if not (v is Object):
			continue
		var e: Object = v as Object
		if e != null and e.has_method("apply_to"):
			var r: Variant = e.call("apply_to", s)
			if r is Dictionary:
				s = (r as Dictionary).duplicate(true)
	return s

func _push_no_plan_context(state: Dictionary, goal: I_Condition, pool_size: int, depth: int) -> void:
	push_error("U_BTPlannerSearch.find_plan: no plan found, pool size=%d" % pool_size)
	push_error("U_BTPlannerSearch.find_plan: no plan found, depth=%d" % depth)
	push_error("U_BTPlannerSearch.find_plan: no plan found, goal=%s" % str(goal))
	push_error("U_BTPlannerSearch.find_plan: no plan found, initial state=%s" % var_to_str(state))
