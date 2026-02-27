class_name U_ObjectivesDebugTracer

## Debug tracing infrastructure for M_ObjectivesManager.
##
## All methods are no-ops when DEBUG_VICTORY_TRACE is false, so this class
## adds zero runtime cost in production builds.

const RS_OBJECTIVE_DEFINITION := preload("res://scripts/resources/scene_director/rs_objective_definition.gd")

const DEBUG_VICTORY_TRACE := false
const DEBUG_SIGNATURE := "objmgr-2026-02-25T2"


static func debug_log(message: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	print("[VictoryDebug][M_ObjectivesManager] %s" % message)


static func log_gameplay_slice(label: String, store: Node) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	if store == null:
		debug_log("%s gameplay=<no_store>" % label)
		return
	var state: Dictionary = store.get_state()
	var gameplay_variant: Variant = state.get("gameplay", {})
	if gameplay_variant is Dictionary:
		var gameplay: Dictionary = gameplay_variant as Dictionary
		debug_log(
			"%s gameplay.completed_areas=%s gameplay.game_completed=%s gameplay.last_victory_objective=%s"
			% [
				label,
				str(gameplay.get("completed_areas", [])),
				str(gameplay.get("game_completed", false)),
				str(gameplay.get("last_victory_objective", StringName(""))),
			]
		)
		return
	debug_log("%s gameplay=<missing_or_invalid> type=%s" % [label, str(gameplay_variant)])


static func log_objectives_slice(label: String, store: Node) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	if store == null:
		debug_log("%s objectives_slice=<no_store>" % label)
		return
	var state: Dictionary = store.get_state()
	var objectives_variant: Variant = state.get("objectives", {})
	if objectives_variant is Dictionary:
		var objectives_slice: Dictionary = objectives_variant as Dictionary
		var statuses_variant: Variant = objectives_slice.get("statuses", {})
		var active_set_id: Variant = objectives_slice.get("active_set_id", StringName(""))
		debug_log(
			"%s objectives.statuses=%s objectives.active_set_id=%s"
			% [label, str(statuses_variant), str(active_set_id)]
		)
		return
	debug_log("%s objectives_slice=<missing_or_invalid> type=%s" % [label, str(objectives_variant)])


static func emit_startup_signature(objective_sets: Array[Resource], script_path: String) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	var objective_set_ids: Array[String] = []
	for objective_set_resource in objective_sets:
		var objective_set := objective_set_resource as Resource
		if objective_set == null:
			objective_set_ids.append("<null>")
			continue
		var set_id: StringName = U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(objective_set, "set_id", StringName("")))
		objective_set_ids.append(str(set_id))
	print(
		"[VictoryDebugSignature][M_ObjectivesManager] build=%s script=%s objective_sets=%s"
		% [DEBUG_SIGNATURE, script_path, str(objective_set_ids)]
	)


static func log_config_snapshot(objective_sets: Array[Resource]) -> void:
	if not DEBUG_VICTORY_TRACE:
		return
	for objective_set_resource in objective_sets:
		var objective_set := objective_set_resource as Resource
		if objective_set == null:
			debug_log("configured objective_set=<null>")
			continue
		var set_id: StringName = U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(objective_set, "set_id", StringName("")))
		var objective_resources: Array[Resource] = U_ResourceAccessHelpers.to_resource_array(U_ResourceAccessHelpers.resource_get(objective_set, "objectives", []))
		debug_log(
			"configured objective_set set_id=%s path=%s instance_id=%s objectives_count=%s"
			% [
				str(set_id),
				objective_set.resource_path,
				str(objective_set.get_instance_id()),
				str(objective_resources.size()),
			]
		)
		for objective_resource in objective_resources:
			var objective := objective_resource as Resource
			if objective == null:
				debug_log("configured objective=<null>")
				continue
			var objective_id: StringName = U_ResourceAccessHelpers.to_string_name(U_ResourceAccessHelpers.resource_get(objective, "objective_id", StringName("")))
			var objective_type: int = int(
				U_ResourceAccessHelpers.resource_get(objective, "objective_type", RS_OBJECTIVE_DEFINITION.ObjectiveType.STANDARD)
			)
			var conditions: Array[Resource] = U_ResourceAccessHelpers.to_resource_array(U_ResourceAccessHelpers.resource_get(objective, "conditions", []))
			var condition_descriptions: Array[String] = []
			for condition_resource in conditions:
				condition_descriptions.append(_describe_condition(condition_resource))
			debug_log(
				"configured objective objective_id=%s type=%s path=%s instance_id=%s conditions=%s"
				% [
					str(objective_id),
					str(objective_type),
					objective.resource_path,
					str(objective.get_instance_id()),
					str(condition_descriptions),
				]
			)


static func _describe_condition(condition_resource: Resource) -> String:
	if condition_resource == null:
		return "<null>"
	var script_path: String = _resource_script_path(condition_resource)
	var field_path: String = String(U_ResourceAccessHelpers.resource_get(condition_resource, "field_path", ""))
	var state_path: String = String(U_ResourceAccessHelpers.resource_get(condition_resource, "state_path", ""))
	var match_mode: String = String(U_ResourceAccessHelpers.resource_get(condition_resource, "match_mode", ""))
	var match_value_string: String = String(U_ResourceAccessHelpers.resource_get(condition_resource, "match_value_string", ""))
	return "%s field_path=%s state_path=%s match_mode=%s match_value=%s" % [
		script_path,
		field_path,
		state_path,
		match_mode,
		match_value_string,
	]


static func _resource_script_path(resource: Resource) -> String:
	if resource == null:
		return ""
	var script := resource.get_script() as Script
	if script == null:
		return "<no_script>"
	return script.resource_path


