@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionHaulDeposit

const C_INVENTORY_COMPONENT := preload("res://scripts/demo/ecs/components/c_inventory_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/demo/ecs/components/c_build_site_component.gd")
const C_DETECTION_COMPONENT := preload("res://scripts/demo/ecs/components/c_detection_component.gd")
const U_ECS_UTILS := preload("res://scripts/core/utils/ecs/u_ecs_utils.gd")

@export var deposit_target_tag: StringName = &"build_site"

func start(context: Dictionary, task_state: Dictionary) -> void:
	print("[ACTION] %s HaulDeposit started" % _resolve_entity_label(context))
	_do_deposit(context, task_state)
	task_state[U_AITaskStateKeys.COMPLETED] = true
	print("[ACTION] %s HaulDeposit complete" % _resolve_entity_label(context))

func tick(_context: Dictionary, _task_state: Dictionary, _delta: float) -> void:
	pass

func is_complete(_context: Dictionary, task_state: Dictionary) -> bool:
	return bool(task_state.get(U_AITaskStateKeys.COMPLETED, false))

func _do_deposit(context: Dictionary, task_state: Dictionary) -> void:
	var inventory: Object = _resolve_inventory(context)
	if inventory == null:
		return
	var build_site: Object = _resolve_build_site(context, task_state)
	if build_site != null:
		_deposit_to_build_site(inventory, build_site, context)

func _resolve_inventory(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	return components_variant.get(C_INVENTORY_COMPONENT.COMPONENT_TYPE, null)

func _resolve_build_site(context: Dictionary, task_state: Dictionary) -> Object:
	var build_site_from_context: Object = _resolve_build_site_from_components(context)
	if build_site_from_context != null:
		return build_site_from_context
	var target_id_variant: Variant = task_state.get(U_AITaskStateKeys.DETECTED_ENTITY_ID, StringName(""))
	var target_id: StringName = target_id_variant as StringName if target_id_variant is StringName else StringName("")
	if target_id == StringName(""):
		var detection: Object = _resolve_detection_component(context)
		if detection != null:
			target_id = detection.get("last_scan_entity_id") as StringName
	if target_id != StringName(""):
		var site: Object = _resolve_build_site_by_entity_id(context, target_id)
		if site != null:
			return site
	return _resolve_build_site_by_component_query(context)

func _resolve_build_site_from_components(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	var components: Dictionary = components_variant as Dictionary
	var build_site_variant: Variant = components.get(C_BUILD_SITE_COMPONENT.COMPONENT_TYPE, null)
	if not (build_site_variant is Object):
		return null
	return build_site_variant as Object

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

func _deposit_to_build_site(inventory: Object, build_site: Object, context: Dictionary) -> void:
	var items_variant: Variant = inventory.get("items")
	if not (items_variant is Dictionary):
		return
	var items: Dictionary = items_variant as Dictionary
	var placed_variant: Variant = build_site.get("placed_materials")
	if not (placed_variant is Dictionary):
		return
	var placed: Dictionary = placed_variant as Dictionary
	var missing: Dictionary = _resolve_missing_materials(build_site)
	var moved_total: int = 0
	for mat_type in items:
		var qty: int = int(items.get(mat_type, 0))
		if qty <= 0:
			continue
		var move_qty: int = qty
		if not missing.is_empty():
			var remaining: int = int(missing.get(mat_type, 0))
			if remaining <= 0:
				continue
			move_qty = mini(move_qty, remaining)
			missing[mat_type] = maxi(remaining - move_qty, 0)
		placed[mat_type] = int(placed.get(mat_type, 0)) + move_qty
		inventory.call("remove", mat_type, move_qty)
		moved_total += move_qty
	if build_site.has_method("refresh_materials_ready"):
		build_site.call("refresh_materials_ready")
	print("[ACTION] %s HaulDeposit moved=%d placed=%s stage_index=%d materials_ready=%s" % [
		_resolve_entity_label(context),
		moved_total,
		str(placed),
		int(build_site.get("current_stage_index")),
		str(bool(build_site.get("materials_ready"))),
	])

func _resolve_missing_materials(build_site: Object) -> Dictionary:
	if build_site != null and build_site.has_method("get_current_stage_missing_materials"):
		var missing_variant: Variant = build_site.call("get_current_stage_missing_materials")
		if missing_variant is Dictionary:
			return (missing_variant as Dictionary).duplicate(true)
	return {}

func _find_component_on_entity(entity: Node, component_type: StringName) -> Object:
	for child in entity.get_children():
		if child.has_method("get_component_type") and child.get_component_type() == component_type:
			return child
	return null

func _resolve_entity_label(context: Dictionary) -> String:
	var entity: Node = context.get("entity", null) as Node
	if entity != null and is_instance_valid(entity):
		return str(entity.name)
	return "?"
