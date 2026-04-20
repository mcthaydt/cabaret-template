@icon("res://assets/editor_icons/icn_resource.svg")
extends I_AIAction
class_name RS_AIActionHaulDeposit

const C_INVENTORY_COMPONENT := preload("res://scripts/ecs/components/c_inventory_component.gd")
const C_BUILD_SITE_COMPONENT := preload("res://scripts/ecs/components/c_build_site_component.gd")
const U_ECS_UTILS := preload("res://scripts/utils/ecs/u_ecs_utils.gd")

@export var deposit_target_tag: StringName = &"build_site"

func start(context: Dictionary, task_state: Dictionary) -> void:
	_do_deposit(context, task_state)
	task_state[U_AITaskStateKeys.COMPLETED] = true

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
		_deposit_to_build_site(inventory, build_site)

func _resolve_inventory(context: Dictionary) -> Object:
	var components_variant: Variant = context.get("components", null)
	if not (components_variant is Dictionary):
		return null
	return components_variant.get(C_INVENTORY_COMPONENT.COMPONENT_TYPE, null)

func _resolve_build_site(context: Dictionary, task_state: Dictionary) -> Object:
	var target_id_variant: Variant = task_state.get(U_AITaskStateKeys.DETECTED_ENTITY_ID, StringName(""))
	var target_id: StringName = target_id_variant as StringName if target_id_variant is StringName else StringName("")
	if target_id != StringName(""):
		var manager_variant: Variant = context.get("ecs_manager", null)
		if manager_variant != null and manager_variant.has_method("get_entity_by_id"):
			var target_entity: Node = manager_variant.call("get_entity_by_id", target_id)
			if target_entity != null and is_instance_valid(target_entity):
				return _find_component_on_entity(target_entity, C_BUILD_SITE_COMPONENT.COMPONENT_TYPE)
	return null

func _deposit_to_build_site(inventory: Object, build_site: Object) -> void:
	var items_variant: Variant = inventory.get("items")
	if not (items_variant is Dictionary):
		return
	var items: Dictionary = items_variant as Dictionary
	var placed_variant: Variant = build_site.get("placed_materials")
	if not (placed_variant is Dictionary):
		return
	var placed: Dictionary = placed_variant as Dictionary
	for mat_type in items:
		var qty: int = items.get(mat_type, 0)
		if qty > 0:
			placed[mat_type] = placed.get(mat_type, 0) + qty
			inventory.call("remove", mat_type, qty)
	if build_site.has_method("refresh_materials_ready"):
		build_site.call("refresh_materials_ready")

func _find_component_on_entity(entity: Node, component_type: StringName) -> Object:
	for child in entity.get_children():
		if child.has_method("get_component_type") and child.get_component_type() == component_type:
			return child
	return null