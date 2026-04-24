extends Label3D
class_name DebugWoodsBuildSiteLabel

const C_BUILD_SITE_COMPONENT := preload("res://scripts/demo/ecs/components/c_build_site_component.gd")
const U_ECS_UTILS := preload("res://scripts/core/utils/ecs/u_ecs_utils.gd")

@export var build_site_component_path: NodePath = NodePath("../C_BuildSiteComponent")

var _build_site: C_BuildSiteComponent = null

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fixed_size = true
	no_depth_test = true
	pixel_size = 0.002
	font_size = 16
	_resolve_build_site_component()
	_update_label_text()

func _process(_delta: float) -> void:
	if _build_site == null or not is_instance_valid(_build_site):
		_resolve_build_site_component()
	_update_label_text()

func _resolve_build_site_component() -> void:
	if not build_site_component_path.is_empty():
		_build_site = get_node_or_null(build_site_component_path) as C_BuildSiteComponent
		if _build_site != null:
			return
	var entity_root: Node = U_ECS_UTILS.find_entity_root(self)
	if entity_root == null:
		_build_site = null
		return
	_build_site = entity_root.get_node_or_null("C_BuildSiteComponent") as C_BuildSiteComponent

func _update_label_text() -> void:
	if _build_site == null:
		text = "<no_build_site>"
		return

	var total_stages: int = 0
	if _build_site.settings != null:
		total_stages = _build_site.settings.stages.size()
	var stage_index: int = int(_build_site.current_stage_index)
	if bool(_build_site.completed):
		text = "house: completed\nstage: %d/%d\nmissing: none" % [total_stages, total_stages]
		return

	var stage_display_index: int = mini(stage_index + 1, total_stages) if total_stages > 0 else 0
	var stage_id_text: String = _resolve_stage_id_text()
	var missing_materials: Dictionary = _build_site.get_current_stage_missing_materials()
	var missing_text: String = _format_missing_materials(missing_materials)
	text = "house: building\nstage: %d/%d (%s)\nmissing: %s" % [
		stage_display_index,
		total_stages,
		stage_id_text,
		missing_text,
	]

func _resolve_stage_id_text() -> String:
	var stage_variant: Variant = _build_site.current_stage()
	if stage_variant == null:
		return "<none>"
	return str(stage_variant.get("stage_id"))

func _format_missing_materials(missing: Dictionary) -> String:
	if missing.is_empty():
		return "none"
	var keys: Array[String] = []
	for material_type_variant in missing.keys():
		keys.append(str(material_type_variant))
	keys.sort()
	var parts: Array[String] = []
	for key in keys:
		var qty: int = int(missing.get(StringName(key), missing.get(key, 0)))
		parts.append("%s:%d" % [key, qty])
	return ", ".join(parts)
