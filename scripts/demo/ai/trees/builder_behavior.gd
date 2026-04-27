extends RefCounted

const RS_CONDITION_COMPONENT_FIELD := preload("res://scripts/core/resources/qb/conditions/rs_condition_component_field.gd")
const RS_CONDITION_COMPOSITE := preload("res://scripts/core/resources/qb/conditions/rs_condition_composite.gd")
const RS_AI_ACTION_WANDER := preload("res://scripts/core/resources/ai/actions/rs_ai_action_wander.gd")
const RS_AI_ACTION_MOVE_TO_NEAREST := preload("res://scripts/core/resources/ai/actions/rs_ai_action_move_to_nearest.gd")
const RS_AI_ACTION_DRINK := preload("res://scripts/demo/resources/ai/actions/rs_ai_action_drink.gd")
const RS_AI_ACTION_HARVEST := preload("res://scripts/demo/resources/ai/actions/rs_ai_action_harvest.gd")
const RS_AI_ACTION_HAUL_DEPOSIT := preload("res://scripts/demo/resources/ai/actions/rs_ai_action_haul_deposit.gd")
const RS_AI_ACTION_BUILD_STAGE := preload("res://scripts/demo/resources/ai/actions/rs_ai_action_build_stage.gd")
const RS_AI_ACTION_RESERVE := preload("res://scripts/demo/resources/ai/actions/rs_ai_action_reserve.gd")

func build() -> RS_BTNode:
	var cond_thirst_low := RS_CONDITION_COMPONENT_FIELD.new()
	cond_thirst_low.component_type = &"C_NeedsComponent"
	cond_thirst_low.field_path = "thirst"
	cond_thirst_low.range_max = 0.25
	cond_thirst_low.invert = true

	var cond_inventory_not_full := RS_CONDITION_COMPONENT_FIELD.new()
	cond_inventory_not_full.component_type = &"C_InventoryComponent"
	cond_inventory_not_full.field_path = "fill_ratio"
	cond_inventory_not_full.invert = true

	var cond_build_not_completed := RS_CONDITION_COMPONENT_FIELD.new()
	cond_build_not_completed.component_type = &"C_BuildSiteComponent"
	cond_build_not_completed.field_path = "completed"
	cond_build_not_completed.invert = true

	var cond_inventory_has_items := RS_CONDITION_COMPONENT_FIELD.new()
	cond_inventory_has_items.component_type = &"C_InventoryComponent"
	cond_inventory_has_items.field_path = "fill_ratio"

	var cond_materials_ready := RS_CONDITION_COMPONENT_FIELD.new()
	cond_materials_ready.component_type = &"C_BuildSiteComponent"
	cond_materials_ready.field_path = "materials_ready"

	var cond_gather_gate := _composite_all([cond_inventory_not_full, cond_build_not_completed])
	var cond_haul_gate := _composite_all([cond_inventory_has_items, cond_build_not_completed])

	var scorer_drink := U_BTBuilder.score_condition(cond_thirst_low, 12.0)
	var scorer_gather := U_BTBuilder.score_condition(cond_gather_gate, 3.0)
	var scorer_haul := U_BTBuilder.score_condition(cond_haul_gate, 4.0)
	var scorer_build := U_BTBuilder.score_condition(cond_materials_ready, 5.0)
	var scorer_wander := U_BTBuilder.score_const(1.0)

	var drink_seq := U_BTBuilder.sequence([
		_move_to_water(),
		_drink(),
	])

	var gather_seq := U_BTBuilder.sequence([
		_move_to_resource(),
		_reserve(),
		_harvest(),
	])

	var haul_seq := U_BTBuilder.sequence([
		_move_to_build_site(),
		_haul_deposit(),
	])

	var build_seq := U_BTBuilder.sequence([
		_move_to_build_site(),
		_build_stage(),
	])

	var wander := _wander(12.0)

	var root := U_BTBuilder.utility_selector([drink_seq, gather_seq, haul_seq, build_seq, wander])
	root.child_scorers = [scorer_drink, scorer_gather, scorer_haul, scorer_build, scorer_wander]
	return root

func _composite_all(conditions: Array) -> RS_ConditionComposite:
	var c := RS_CONDITION_COMPOSITE.new()
	c.set("mode", 0)
	var sanitized: Variant = c.call("_sanitize_children", conditions)
	c.set("_children", sanitized)
	return c

func _move_to_water() -> RS_BTAction:
	var a := RS_AI_ACTION_MOVE_TO_NEAREST.new()
	a.scan_component_type = &"C_ResourceNodeComponent"
	a.scan_filter = &"is_available"
	a.scan_required_resource_type = &"water"
	return U_BTBuilder.action(a)

func _move_to_resource() -> RS_BTAction:
	var a := RS_AI_ACTION_MOVE_TO_NEAREST.new()
	a.scan_component_type = &"C_ResourceNodeComponent"
	a.scan_filter = &"is_available"
	a.scan_required_resource_type = &"wood"
	a.use_build_site_missing_material = true
	return U_BTBuilder.action(a)

func _move_to_build_site() -> RS_BTAction:
	var a := RS_AI_ACTION_MOVE_TO_NEAREST.new()
	a.scan_component_type = &"C_BuildSiteComponent"
	return U_BTBuilder.action(a)

func _drink() -> RS_BTAction:
	return U_BTBuilder.action(RS_AI_ACTION_DRINK.new())

func _harvest() -> RS_BTAction:
	return U_BTBuilder.action(RS_AI_ACTION_HARVEST.new())

func _haul_deposit() -> RS_BTAction:
	return U_BTBuilder.action(RS_AI_ACTION_HAUL_DEPOSIT.new())

func _build_stage() -> RS_BTAction:
	return U_BTBuilder.action(RS_AI_ACTION_BUILD_STAGE.new())

func _reserve() -> RS_BTAction:
	return U_BTBuilder.action(RS_AI_ACTION_RESERVE.new())

func _wander(home_radius: float) -> RS_BTAction:
	var a := RS_AI_ACTION_WANDER.new()
	a.home_radius = home_radius
	return U_BTBuilder.action(a)
