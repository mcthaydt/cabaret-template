@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionBuildStage

const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
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
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	return components.get(C_BUILD_SITE_COMPONENT.COMPONENT_TYPE, null)