@icon("res://assets/editor_icons/icn_component.svg")
extends BaseECSComponent
class_name C_BuildSiteComponent

const COMPONENT_TYPE := StringName("C_BuildSiteComponent")

@export var settings: RS_BuildSiteSettings = null

var current_stage_index: int = 0
var placed_materials: Dictionary = {}
var current_build_elapsed: float = 0.0
var completed: bool = false
var reserved_by_entity_id: StringName = StringName("")
var materials_ready: bool = false

func _init() -> void:
	component_type = COMPONENT_TYPE

func _validate_required_settings() -> bool:
	if settings == null:
		push_error("C_BuildSiteComponent missing settings; assign an RS_BuildSiteSettings resource.")
		return false
	if settings.stages.is_empty():
		push_error("C_BuildSiteComponent settings has no stages defined.")
		return false
	return true

func current_stage() -> RS_BuildStage:
	if settings == null or current_stage_index >= settings.stages.size():
		return null
	return settings.stages[current_stage_index]

func required_materials_met() -> bool:
	var stage := current_stage()
	if stage == null:
		return false
	for mat_type in stage.required_materials:
		var required: int = stage.required_materials[mat_type]
		var placed: int = placed_materials.get(mat_type, 0)
		if placed < required:
			return false
	return true

func refresh_materials_ready() -> void:
	materials_ready = required_materials_met()

func get_current_stage_missing_materials() -> Dictionary:
	var missing: Dictionary = {}
	var stage := current_stage()
	if stage == null:
		return missing
	for material_type_variant in stage.required_materials.keys():
		var material_type: StringName = StringName(material_type_variant)
		var required: int = int(stage.required_materials.get(material_type, 0))
		var placed: int = int(placed_materials.get(material_type, 0))
		var deficit: int = maxi(required - placed, 0)
		if deficit > 0:
			missing[material_type] = deficit
	return missing

func get_next_missing_material_type() -> StringName:
	var missing: Dictionary = get_current_stage_missing_materials()
	if missing.is_empty():
		return StringName("")
	var best_type: StringName = StringName("")
	var best_deficit: int = -1
	for material_type_variant in missing.keys():
		var material_type: StringName = StringName(material_type_variant)
		var deficit: int = int(missing.get(material_type, 0))
		if deficit > best_deficit:
			best_deficit = deficit
			best_type = material_type
			continue
		if deficit == best_deficit and String(material_type) < String(best_type):
			best_type = material_type
	return best_type

func advance_stage() -> bool:
	if settings == null or completed:
		return false
	var stage := current_stage()
	if stage == null:
		return false
	_toggle_stage_visual(stage, true)
	current_stage_index += 1
	current_build_elapsed = 0.0
	materials_ready = false
	if current_stage_index >= settings.stages.size():
		completed = true
	return true

func _toggle_stage_visual(stage: RS_BuildStage, visible: bool) -> void:
	if stage.visual_node_path.is_empty():
		return
	var entity := ECS_UTILS.find_entity_root(self)
	if entity == null:
		return
	var node := entity.get_node_or_null(stage.visual_node_path)
	if node != null:
		node.visible = visible
