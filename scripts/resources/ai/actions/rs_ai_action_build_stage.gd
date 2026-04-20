@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionBuildStage

const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/ecs/components/c_detection_component.gd")
const RS_BUILD_STAGE := preload("res://scripts/resources/ai/world/rs_build_stage.gd")

func start(_context: Dictionary, task_state: Dictionary) -> void:
	task_state[U_AITaskStateKeys.BUILD_ELAPSED] = 0.0

func tick(_context: Dictionary, task_state: Dictionary, delta: float) -> void:
	var elapsed: float = task_state.get(U_AITaskStateKeys.BUILD_ELAPSED, 0.0)
	task_state[U_AITaskStateKeys.BUILD_ELAPSED] = elapsed + maxf(delta, 0.0)

func is_complete(context: Dictionary, task_state: Dictionary) -> bool:
	var build_site: Object = _resolve_build_site(context)
	if build_site == null:
		return true
	var current_stage_variant: Variant = build_site.call("current_stage")
	if current_stage_variant == null:
		return true
	var build_seconds: float = 3.0
	if current_stage_variant is RS_BuildStage:
		var stage: RS_BuildStage = current_stage_variant as RS_BuildStage
		build_seconds = stage.build_seconds
	var elapsed: float = task_state.get(U_AITaskStateKeys.BUILD_ELAPSED, 0.0)
	if elapsed < maxf(build_seconds, 0.0):
		return false
	build_site.call("advance_stage")
	return true

func _resolve_build_site(context: Dictionary) -> Object:
	var detection: Object = _resolve_detection_component(context)
	if detection != null:
		var scan_id: StringName = detection.get("last_scan_entity_id") as StringName
		if scan_id != StringName(""):
			var site: Object = _resolve_build_site_by_entity_id(context, scan_id)
			if site != null:
				return site
	return _resolve_build_site_by_component_query(context)

func _resolve_build_site_by_entity_id(context: Dictionary, target_id: StringName) -> Object:
	var manager_variant: Variant = context.get("ecs_manager", null)
	if manager_variant == null or not manager_variant.has_method("get_entity_by_id"):
		return null
	var target_entity: Node = manager_variant.call("get_entity_by_id", target_id)
	if target_entity == null or not is_instance_valid(target_entity):
		return null
	return _find_component_on_entity(target_entity, C_BUILD_SITE_COMPONENT.COMPONENT_TYPE)

func _resolve_build_site_by_component_query(context: Dictionary) -> Object:
	var manager_variant: Variant = context.get("ecs_manager", null)
	if manager_variant == null or not manager_variant.has_method("get_components"):
		return null
	var sites: Array = manager_variant.call("get_components", C_BUILD_SITE_COMPONENT.COMPONENT_TYPE)
	if sites.is_empty():
		return null
	for site_variant in sites:
		if site_variant is Object and is_instance_valid(site_variant as Object):
			return site_variant as Object
	return null

func _resolve_detection_component(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(C_DETECTION_COMPONENT.COMPONENT_TYPE, null)

func _find_component_on_entity(entity: Node, component_type: StringName) -> Object:
	for child in entity.get_children():
		if child.has_method("get_component_type") and child.get_component_type() == component_type:
			return child
	return null