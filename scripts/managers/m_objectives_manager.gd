@icon("res://assets/editor_icons/icn_manager.svg")
extends I_ObjectivesManager
class_name M_ObjectivesManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/events/ecs/u_ecs_event_bus.gd")
const U_ECS_EVENT_NAMES := preload("res://scripts/events/ecs/u_ecs_event_names.gd")
const U_OBJECTIVE_GRAPH := preload("res://scripts/utils/scene_director/u_objective_graph.gd")
const U_OBJECTIVE_EVENT_LOG := preload("res://scripts/utils/scene_director/u_objective_event_log.gd")
const U_OBJECTIVES_ACTIONS := preload("res://scripts/state/actions/u_objectives_actions.gd")
const U_OBJECTIVES_SELECTORS := preload("res://scripts/state/selectors/u_objectives_selectors.gd")
const U_GAMEPLAY_ACTIONS := preload("res://scripts/state/actions/u_gameplay_actions.gd")
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")
const RS_OBJECTIVE_DEFINITION := preload("res://scripts/resources/scene_director/rs_objective_definition.gd")
const U_OBJECTIVES_DEBUG_TRACER := preload("res://scripts/utils/scene_director/u_objectives_debug_tracer.gd")

const STORE_SERVICE_NAME := StringName("state_store")
const STATUS_INACTIVE := "inactive"
const STATUS_ACTIVE := "active"
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"

@export var state_store: I_StateStore = null
@export var objective_sets: Array[Resource] = []

var _store: I_StateStore = null
var _objective_sets_by_id: Dictionary = {}
var _objectives_by_id: Dictionary = {}
var _objective_graph: Dictionary = {}
var _event_unsubscribes: Array[Callable] = []
var _store_action_connected: bool = false

func _ready() -> void:
	U_OBJECTIVES_DEBUG_TRACER.emit_startup_signature(objective_sets, get_script().resource_path)
	U_OBJECTIVES_DEBUG_TRACER.log_config_snapshot(objective_sets)
	_resolve_store()
	_index_objective_sets()
	_subscribe_events()

	for objective_set in objective_sets:
		if objective_set == null:
			continue
		var set_id: StringName = U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(objective_set, "set_id", StringName("")))
		if set_id == StringName(""):
			continue
		load_objective_set(set_id)

func _exit_tree() -> void:
	_disconnect_store_action_signal()
	for unsubscribe in _event_unsubscribes:
		if unsubscribe.is_valid():
			unsubscribe.call()
	_event_unsubscribes.clear()

func load_objective_set(set_id: StringName) -> bool:
	return _load_objective_set_internal(set_id, true)

func reset_for_new_run(set_id: StringName = StringName("default_progression")) -> bool:
	return _load_objective_set_internal(set_id, false)

func _load_objective_set_internal(set_id: StringName, reconcile_persisted_statuses: bool) -> bool:
	if set_id == StringName(""):
		return false

	_resolve_store()
	_index_objective_sets()

	var objective_set: Resource = _objective_sets_by_id.get(set_id, null) as Resource
	if objective_set == null:
		U_OBJECTIVES_DEBUG_TRACER.debug_log("failed to load objective set: missing set_id=%s" % str(set_id))
		return false

	var objective_resources: Array[Resource] = U_ResourceAccessHelpers.to_resource_array(U_ResourceAccessHelpers.resource_get(objective_set, "objectives", []))
	var objective_map: Dictionary = {}
	var known_ids: Array[StringName] = []

	for objective in objective_resources:
		if objective == null:
			continue
		var objective_id: StringName = U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(objective, "objective_id", StringName("")))
		if objective_id == StringName(""):
			continue
		if objective_map.has(objective_id):
			push_warning("M_ObjectivesManager: Duplicate objective_id '%s' in set '%s'" % [
				String(objective_id),
				String(set_id),
			])
			continue
		objective_map[objective_id] = objective
		known_ids.append(objective_id)

	var graph: Dictionary = U_OBJECTIVE_GRAPH.build_graph(objective_resources)
	var errors: Array[String] = U_OBJECTIVE_GRAPH.validate_graph(graph, known_ids)
	if not errors.is_empty():
		U_OBJECTIVES_DEBUG_TRACER.debug_log("objective graph validation failed set_id=%s errors=%s" % [str(set_id), str(errors)])
		return false

	if set_id == StringName("default_progression"):
		var has_new_flow_ids: bool = known_ids.has(StringName("bar_complete")) and known_ids.has(StringName("final_complete"))
		if not has_new_flow_ids:
			U_OBJECTIVES_DEBUG_TRACER.debug_log(
				"WARNING stale default_progression objective IDs detected known_ids=%s (expected bar_complete + final_complete)"
				% str(known_ids)
			)

	_objectives_by_id = objective_map
	_objective_graph = graph

	if _store != null:
		if reconcile_persisted_statuses:
			var persisted_statuses: Dictionary = _get_statuses_snapshot()
			_store.dispatch(U_OBJECTIVES_ACTIONS.reset_all())
			U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives/reset_all", _store)
			_store.dispatch(U_OBJECTIVES_ACTIONS.set_active_set(set_id))
			U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives/set_active_set", _store)
			_reconcile_persisted_statuses(known_ids, persisted_statuses)
			U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives reconcile persisted statuses", _store)
		else:
			_store.dispatch(U_OBJECTIVES_ACTIONS.reset_for_new_run(set_id))
			U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives/reset_for_new_run", _store)

	var auto_activate_ids: Array[StringName] = []
	for objective_id in known_ids:
		var objective: Resource = _objectives_by_id.get(objective_id, null) as Resource
		if objective == null:
			continue
		if bool(U_ResourceAccessHelpers.resource_get(objective, "auto_activate", false)):
			auto_activate_ids.append(objective_id)
	auto_activate_ids.sort()

	if reconcile_persisted_statuses:
		for objective_id in auto_activate_ids:
			_activate_objective(objective_id, {"reason": "auto_activate"})
	else:
		_activate_objectives_for_reset(auto_activate_ids)

	U_OBJECTIVES_DEBUG_TRACER.debug_log(
		"loaded objective set set_id=%s objectives=%s auto_activate=%s"
		% [str(set_id), str(known_ids), str(auto_activate_ids)]
	)

	return true

func _check_conditions(conditions: Array[Resource], context: Dictionary) -> bool:
	var condition_index: int = 0
	for condition_resource in conditions:
		var condition: Variant = condition_resource
		if condition == null:
			U_OBJECTIVES_DEBUG_TRACER.debug_log("condition check failed index=%s reason=null_condition" % str(condition_index))
			return false
		if not condition.has_method("evaluate"):
			push_warning("M_ObjectivesManager: Condition missing evaluate(context): %s" % str(condition))
			U_OBJECTIVES_DEBUG_TRACER.debug_log(
				"condition check failed index=%s reason=missing_evaluate condition=%s"
				% [str(condition_index), str(condition)]
			)
			return false

		var score_variant: Variant = condition.evaluate(context)
		var score: float = U_ResourceAccessHelpers.to_float(score_variant, 0.0)
		U_OBJECTIVES_DEBUG_TRACER.debug_log(
			"condition evaluated index=%s condition=%s score=%s"
			% [str(condition_index), str(condition), str(score)]
		)
		if score <= 0.0:
			U_OBJECTIVES_DEBUG_TRACER.debug_log("condition check failed index=%s reason=score<=0" % str(condition_index))
			return false
		condition_index += 1

	return true

func _execute_effects(effects: Array[Resource], context: Dictionary) -> void:
	for effect_resource in effects:
		var effect: Variant = effect_resource
		if effect == null:
			continue
		if not effect.has_method("execute"):
			push_warning("M_ObjectivesManager: Effect missing execute(context): %s" % str(effect))
			continue
		effect.execute(context)

func _complete_objective(objective_id: StringName) -> void:
	_complete_objective_with_context(objective_id, {})

func _complete_objective_with_context(objective_id: StringName, context: Dictionary) -> void:
	if objective_id == StringName(""):
		return

	var objective: Resource = _objectives_by_id.get(objective_id, null) as Resource
	if objective == null:
		return

	var status: String = get_objective_status(objective_id)
	if status == STATUS_COMPLETED or status == STATUS_FAILED:
		U_OBJECTIVES_DEBUG_TRACER.debug_log("skipping objective completion objective_id=%s status=%s" % [str(objective_id), status])
		return

	U_OBJECTIVES_DEBUG_TRACER.debug_log("completing objective objective_id=%s previous_status=%s" % [str(objective_id), status])
	U_OBJECTIVES_DEBUG_TRACER.log_gameplay_slice("before objectives/complete %s" % str(objective_id), _store)

	if _store != null:
		_store.dispatch(U_OBJECTIVES_ACTIONS.complete(objective_id))
		U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives/complete %s" % str(objective_id), _store)

	_log_event(objective_id, U_OBJECTIVE_EVENT_LOG.EVENT_COMPLETED)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_OBJECTIVE_COMPLETED, {
		"objective_id": objective_id,
	})

	var completion_context: Dictionary = context.duplicate(true)
	if completion_context.is_empty():
		completion_context = _build_context()
	var completion_effects: Array[Resource] = U_ResourceAccessHelpers.to_resource_array(
		U_ResourceAccessHelpers.resource_get(objective, "completion_effects", [])
	)
	_execute_effects(completion_effects, completion_context)

	var objective_type: int = int(
		U_ResourceAccessHelpers.resource_get(objective, "objective_type", RS_OBJECTIVE_DEFINITION.ObjectiveType.STANDARD)
	)
	if objective_type == RS_OBJECTIVE_DEFINITION.ObjectiveType.VICTORY:
		var payload: Dictionary = {}
		var payload_variant: Variant = U_ResourceAccessHelpers.resource_get(objective, "completion_event_payload", {})
		if payload_variant is Dictionary:
			payload = (payload_variant as Dictionary).duplicate(true)
		U_OBJECTIVES_DEBUG_TRACER.log_gameplay_slice("before objective_victory_triggered publish objective_id=%s" % str(objective_id), _store)
		U_OBJECTIVES_DEBUG_TRACER.debug_log(
			"publishing objective_victory_triggered objective_id=%s payload=%s"
			% [str(objective_id), str(payload)]
		)
		U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_OBJECTIVE_VICTORY_TRIGGERED, payload)

	_activate_dependents(objective_id)

func _fail_objective(objective_id: StringName) -> void:
	if objective_id == StringName(""):
		return

	var objective: Resource = _objectives_by_id.get(objective_id, null) as Resource
	if objective == null:
		return

	var status: String = get_objective_status(objective_id)
	if status == STATUS_COMPLETED or status == STATUS_FAILED:
		return

	if _store != null:
		_store.dispatch(U_OBJECTIVES_ACTIONS.fail(objective_id))
		U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives/fail %s" % str(objective_id), _store)

	_log_event(objective_id, U_OBJECTIVE_EVENT_LOG.EVENT_FAILED)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_OBJECTIVE_FAILED, {
		"objective_id": objective_id,
	})

func _activate_dependents(objective_id: StringName) -> void:
	if objective_id == StringName(""):
		return
	if _objective_graph.is_empty():
		return

	var statuses: Dictionary = _get_statuses_snapshot()
	var ready_dependents: Array[StringName] = U_OBJECTIVE_GRAPH.get_ready_dependents(
		objective_id,
		_objective_graph,
		statuses
	)

	for dependent_id in ready_dependents:
		_log_event(dependent_id, U_OBJECTIVE_EVENT_LOG.EVENT_DEPENDENCY_MET, {
			"dependency_id": objective_id,
		})
		_activate_objective(dependent_id, {"dependency_id": objective_id})

func get_objective_status(objective_id: StringName) -> String:
	_resolve_store()
	if _store == null:
		return STATUS_INACTIVE
	var state: Dictionary = _store.get_state()
	return U_OBJECTIVES_SELECTORS.get_objective_status(state, objective_id)

func _build_context() -> Dictionary:
	_resolve_store()
	var redux_state: Dictionary = {}
	if _store != null:
		redux_state = _store.get_state()

	return {
		"state_store": _store,
		"redux_state": redux_state,
	}

func _build_event_context(event_payload: Dictionary) -> Dictionary:
	var context: Dictionary = _build_context()
	context["event_payload"] = event_payload.duplicate(true)
	return context

func _resolve_store() -> void:
	var resolved_store: I_StateStore = null

	if state_store != null and is_instance_valid(state_store):
		resolved_store = state_store
	elif _store != null and is_instance_valid(_store):
		resolved_store = _store
	else:
		resolved_store = U_STATE_UTILS.try_get_store(self)
		if resolved_store == null:
			resolved_store = U_SERVICE_LOCATOR.try_get_service(STORE_SERVICE_NAME) as I_StateStore

	_set_store_reference(resolved_store)

func _set_store_reference(next_store: I_StateStore) -> void:
	if _store != next_store:
		if _store != null and _store.has_signal("action_dispatched"):
			if _store.action_dispatched.is_connected(_on_action_dispatched):
				_store.action_dispatched.disconnect(_on_action_dispatched)
		_store_action_connected = false
		_store = next_store

	_ensure_store_action_signal_connection()

func _index_objective_sets() -> void:
	_objective_sets_by_id.clear()
	for objective_set in objective_sets:
		if objective_set == null:
			continue
		var set_id: StringName = U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(objective_set, "set_id", StringName("")))
		if set_id == StringName(""):
			continue
		if _objective_sets_by_id.has(set_id):
			push_warning("M_ObjectivesManager: Duplicate objective set_id '%s'" % String(set_id))
			continue
		_objective_sets_by_id[set_id] = objective_set

func _subscribe_events() -> void:
	_event_unsubscribes.append(
		U_ECS_EVENT_BUS.subscribe(U_ECS_EVENT_NAMES.EVENT_CHECKPOINT_ACTIVATED, _on_checkpoint_activated)
	)
	_event_unsubscribes.append(
		U_ECS_EVENT_BUS.subscribe(U_ECS_EVENT_NAMES.EVENT_VICTORY_EXECUTED, _on_victory_executed)
	)

	_ensure_store_action_signal_connection()

func _ensure_store_action_signal_connection() -> void:
	if _store == null:
		return
	if not _store.has_signal("action_dispatched"):
		return
	if _store.action_dispatched.is_connected(_on_action_dispatched):
		_store_action_connected = true
		return

	_store.action_dispatched.connect(_on_action_dispatched)
	_store_action_connected = true

func _disconnect_store_action_signal() -> void:
	if not _store_action_connected:
		return
	if _store != null and _store.has_signal("action_dispatched"):
		if _store.action_dispatched.is_connected(_on_action_dispatched):
			_store.action_dispatched.disconnect(_on_action_dispatched)
	_store_action_connected = false

func _on_checkpoint_activated(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	_ensure_objective_runtime_state()
	U_OBJECTIVES_DEBUG_TRACER.debug_log("received checkpoint_activated payload=%s" % str(payload))
	_evaluate_active_objectives(_build_event_context(payload))

func _on_victory_executed(event: Dictionary) -> void:
	var payload: Dictionary = event.get("payload", {})
	_ensure_objective_runtime_state()
	U_OBJECTIVES_DEBUG_TRACER.debug_log(
		"received victory_executed payload=%s statuses=%s"
		% [str(payload), str(_get_statuses_snapshot())]
	)
	_evaluate_active_objectives(_build_event_context(payload))

func _on_action_dispatched(action: Dictionary) -> void:
	var action_type: StringName = action.get("type", StringName(""))
	if action_type != U_GAMEPLAY_ACTIONS.ACTION_MARK_AREA_COMPLETE \
	and action_type != U_GAMEPLAY_ACTIONS.ACTION_RESET_PROGRESS \
	and action_type != U_GAMEPLAY_ACTIONS.ACTION_GAME_COMPLETE \
	and action_type != U_NAVIGATION_ACTIONS.ACTION_START_GAME:
		return

	_ensure_objective_runtime_state()
	if action_type == U_NAVIGATION_ACTIONS.ACTION_START_GAME:
		if _is_scene_transitioning():
			return
		var set_id: StringName = _resolve_set_id_for_new_run()
		if set_id == StringName(""):
			push_warning("M_ObjectivesManager: Ignoring navigation/start_game because no objective set is available for reset.")
			return
		var reset_ok: bool = reset_for_new_run(set_id)
		if not reset_ok:
			push_warning("M_ObjectivesManager: Failed to reset objective set '%s' on navigation/start_game." % str(set_id))
		return

	if action_type == U_GAMEPLAY_ACTIONS.ACTION_RESET_PROGRESS:
		U_OBJECTIVES_DEBUG_TRACER.debug_log("observed gameplay/reset_progress payload=%s" % str(action.get("payload", null)))
		U_OBJECTIVES_DEBUG_TRACER.log_gameplay_slice("after gameplay/reset_progress dispatch observed", _store)
		U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after gameplay/reset_progress dispatch observed", _store)
		U_OBJECTIVES_DEBUG_TRACER.debug_log(
			"post-reset objective snapshot active_ids=%s statuses=%s"
			% [str(U_OBJECTIVES_SELECTORS.get_active_objectives(_store.get_state())), str(_get_statuses_snapshot())]
		)
		return

	if action_type == U_GAMEPLAY_ACTIONS.ACTION_GAME_COMPLETE:
		U_OBJECTIVES_DEBUG_TRACER.debug_log("observed gameplay/game_complete")
		U_OBJECTIVES_DEBUG_TRACER.log_gameplay_slice("after gameplay/game_complete dispatch observed", _store)
		U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after gameplay/game_complete dispatch observed", _store)
		return

	U_OBJECTIVES_DEBUG_TRACER.debug_log("observed gameplay/mark_area_complete payload=%s" % str(action.get("payload", null)))
	U_OBJECTIVES_DEBUG_TRACER.log_gameplay_slice("after gameplay/mark_area_complete dispatch observed", _store)
	U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("before evaluating objectives from gameplay/mark_area_complete", _store)

	_evaluate_active_objectives(_build_event_context({
		"action_type": action_type,
		"action_payload": action.get("payload", null),
	}))

func _evaluate_active_objectives(context: Dictionary) -> void:
	if _store == null:
		return
	_ensure_objective_runtime_state()

	var event_payload: Dictionary = {}
	var payload_variant: Variant = context.get("event_payload", {})
	if payload_variant is Dictionary:
		event_payload = (payload_variant as Dictionary).duplicate(true)

	var max_iterations: int = max(_objectives_by_id.size() + 1, 1)
	for _iteration in range(max_iterations):
		var progressed: bool = false
		var evaluation_context: Dictionary = _build_context()
		if not event_payload.is_empty():
			evaluation_context["event_payload"] = event_payload.duplicate(true)
		var state: Dictionary = _store.get_state()
		var active_ids: Array[StringName] = U_OBJECTIVES_SELECTORS.get_active_objectives(state)
		U_OBJECTIVES_DEBUG_TRACER.debug_log("evaluating active objectives active_ids=%s event_payload=%s" % [str(active_ids), str(event_payload)])
		if active_ids.is_empty():
			U_OBJECTIVES_DEBUG_TRACER.debug_log("no active objectives to evaluate; statuses=%s" % str(_get_statuses_snapshot()))
			break

		for objective_id in active_ids:
			var objective: Resource = _objectives_by_id.get(objective_id, null) as Resource
			if objective == null:
				continue

			var conditions: Array[Resource] = U_ResourceAccessHelpers.to_resource_array(U_ResourceAccessHelpers.resource_get(objective, "conditions", []))
			var conditions_met: bool = _check_conditions(conditions, evaluation_context)
			_log_event(objective_id, U_OBJECTIVE_EVENT_LOG.EVENT_CONDITION_CHECKED, {
				"passed": conditions_met,
			})
			if conditions_met:
				_complete_objective_with_context(objective_id, evaluation_context)
				progressed = true

		if not progressed:
			break

func _ensure_objective_runtime_state() -> void:
	if _store == null:
		return
	if _objectives_by_id.is_empty():
		return

	var state: Dictionary = _store.get_state()
	var objectives_variant: Variant = state.get("objectives", {})
	if not (objectives_variant is Dictionary):
		_reload_objective_set_from_state()
		return

	var objectives_slice: Dictionary = objectives_variant as Dictionary
	var statuses_variant: Variant = objectives_slice.get("statuses", {})
	if statuses_variant is Dictionary:
		var statuses: Dictionary = statuses_variant as Dictionary
		if not statuses.is_empty():
			return

	_reload_objective_set_from_state()

func _reload_objective_set_from_state() -> void:
	var set_id: StringName = _resolve_active_set_id_from_store()
	if set_id == StringName(""):
		return
	if load_objective_set(set_id):
		U_OBJECTIVES_DEBUG_TRACER.debug_log("reloaded objective set after empty objectives state set_id=%s" % str(set_id))
	else:
		push_warning("M_ObjectivesManager: Failed to reload objective set '%s' for runtime recovery." % str(set_id))

func _resolve_active_set_id_from_store() -> StringName:
	if _store == null:
		return StringName("")

	var state: Dictionary = _store.get_state()
	var objectives_variant: Variant = state.get("objectives", {})
	if objectives_variant is Dictionary:
		var objectives_slice: Dictionary = objectives_variant as Dictionary
		var active_set_variant: Variant = objectives_slice.get("active_set_id", StringName(""))
		var active_set_id: StringName = U_ResourceAccessHelpers.to_string_name(active_set_variant)
		if active_set_id != StringName(""):
			return active_set_id

	var candidate_ids: Array[StringName] = []
	for set_id_variant in _objective_sets_by_id.keys():
		var candidate_id: StringName = U_ResourceAccessHelpers.to_string_name(set_id_variant)
		if candidate_id != StringName(""):
			candidate_ids.append(candidate_id)
	if candidate_ids.is_empty():
		return StringName("")

	candidate_ids.sort()
	return candidate_ids[0]

func _is_scene_transitioning() -> bool:
	if _store == null:
		return false

	var state: Dictionary = _store.get_state()
	var scene_variant: Variant = state.get("scene", {})
	if not (scene_variant is Dictionary):
		return false
	var scene_slice: Dictionary = scene_variant as Dictionary
	return bool(scene_slice.get("is_transitioning", false))

func _resolve_set_id_for_new_run() -> StringName:
	_index_objective_sets()
	if _objective_sets_by_id.is_empty():
		return StringName("")

	var active_set_id: StringName = _resolve_active_set_id_from_store()
	if active_set_id != StringName("") and _objective_sets_by_id.has(active_set_id):
		return active_set_id

	var default_set_id := StringName("default_progression")
	if _objective_sets_by_id.has(default_set_id):
		return default_set_id

	var candidate_ids: Array[StringName] = []
	for set_id_variant in _objective_sets_by_id.keys():
		var candidate_id: StringName = U_ResourceAccessHelpers.to_string_name(set_id_variant)
		if candidate_id != StringName(""):
			candidate_ids.append(candidate_id)
	if candidate_ids.is_empty():
		return StringName("")

	candidate_ids.sort()
	return candidate_ids[0]

func _activate_objective(objective_id: StringName, details: Dictionary = {}) -> void:
	if objective_id == StringName(""):
		return
	if get_objective_status(objective_id) != STATUS_INACTIVE:
		U_OBJECTIVES_DEBUG_TRACER.debug_log(
			"skipping objectives/activate objective_id=%s current_status=%s"
			% [str(objective_id), get_objective_status(objective_id)]
		)
		return

	if _store != null:
		_store.dispatch(U_OBJECTIVES_ACTIONS.activate(objective_id))
		U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives/activate %s" % str(objective_id), _store)

	_log_event(objective_id, U_OBJECTIVE_EVENT_LOG.EVENT_ACTIVATED, details)
	U_ECS_EVENT_BUS.publish(U_ECS_EVENT_NAMES.EVENT_OBJECTIVE_ACTIVATED, {
		"objective_id": objective_id,
	})

func _activate_objectives_for_reset(objective_ids: Array[StringName]) -> void:
	if objective_ids.is_empty():
		return
	if _store == null:
		for objective_id in objective_ids:
			_activate_objective(objective_id, {"reason": "reset_run"})
		return

	_store.dispatch(U_OBJECTIVES_ACTIONS.bulk_activate(objective_ids))
	U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("after objectives/bulk_activate reset_run", _store)

func _log_event(objective_id: StringName, event_type: String, details: Dictionary = {}) -> void:
	if _store == null:
		return
	var entry: Dictionary = U_OBJECTIVE_EVENT_LOG.create_entry(objective_id, event_type, details)
	_store.dispatch(U_OBJECTIVES_ACTIONS.log_event(entry))

func _reconcile_persisted_statuses(known_ids: Array[StringName], persisted_statuses: Dictionary) -> void:
	if _store == null:
		return

	for objective_id in known_ids:
		var status: String = str(persisted_statuses.get(objective_id, STATUS_INACTIVE))
		match status:
			STATUS_ACTIVE:
				_store.dispatch(U_OBJECTIVES_ACTIONS.activate(objective_id))
				U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("reconcile -> objectives/activate %s" % str(objective_id), _store)
			STATUS_COMPLETED:
				_store.dispatch(U_OBJECTIVES_ACTIONS.complete(objective_id))
				U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("reconcile -> objectives/complete %s" % str(objective_id), _store)
			STATUS_FAILED:
				_store.dispatch(U_OBJECTIVES_ACTIONS.fail(objective_id))
				U_OBJECTIVES_DEBUG_TRACER.log_objectives_slice("reconcile -> objectives/fail %s" % str(objective_id), _store)
			_:
				# Unknown/empty statuses are treated as inactive.
				pass

func _get_statuses_snapshot() -> Dictionary:
	if _store == null:
		return {}
	var state: Dictionary = _store.get_state()
	var objectives_slice_variant: Variant = state.get("objectives", {})
	if not (objectives_slice_variant is Dictionary):
		return {}
	var objectives_slice := objectives_slice_variant as Dictionary
	var statuses_variant: Variant = objectives_slice.get("statuses", {})
	if statuses_variant is Dictionary:
		return (statuses_variant as Dictionary).duplicate(true)
	return {}

