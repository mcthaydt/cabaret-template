extends BaseTest

const LABEL_SCRIPT_PATH := "res://scripts/debug/debug_forest_agent_label.gd"
const BASE_ECS_ENTITY := preload("res://scripts/ecs/base_ecs_entity.gd")
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const RS_AI_BRAIN_PLACEHOLDER := preload("res://resources/ai/cfg_ai_brain_placeholder.tres")

func _instantiate_label() -> Label3D:
	var label_script_variant: Variant = load(LABEL_SCRIPT_PATH)
	assert_not_null(label_script_variant, "Expected debug forest label script to exist: %s" % LABEL_SCRIPT_PATH)
	if not (label_script_variant is Script):
		return null

	var label_variant: Variant = (label_script_variant as Script).new()
	assert_true(label_variant is Label3D, "Debug forest label should extend Label3D.")
	if not (label_variant is Label3D):
		return null
	return label_variant as Label3D

func _build_entity_with_brain(entity_name: String) -> Dictionary:
	var root := Node3D.new()
	add_child_autofree(root)

	var entity: BaseECSEntity = BASE_ECS_ENTITY.new()
	entity.name = entity_name
	root.add_child(entity)
	autofree(entity)

	var components := Node.new()
	components.name = "Components"
	entity.add_child(components)
	autofree(components)

	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	brain.name = "C_AIBrainComponent"
	brain.brain_settings = RS_AI_BRAIN_PLACEHOLDER
	components.add_child(brain)
	autofree(brain)

	var label: Label3D = _instantiate_label()
	if label == null:
		return {}
	entity.add_child(label)
	autofree(label)

	return {
		"entity": entity,
		"brain": brain,
		"label": label,
	}

func test_label_formats_entity_goal_and_task_as_multiline_text() -> void:
	var fixture: Dictionary = _build_entity_with_brain("E_Wolf_01")
	if fixture.is_empty():
		return

	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var label: Label3D = fixture.get("label") as Label3D
	brain.update_debug_snapshot({
		"entity_id": &"forest_wolf_01",
		"goal_id": &"hunt",
		"task_id": &"move_to_detected_first",
	})
	await get_tree().process_frame
	label.call("_process", 0.0)

	assert_eq(
		label.text,
		"forest_wolf_01\ngoal: hunt\ntask: move_to_detected_first",
		"Label text should render entity/goal/task with multiline formatting."
	)

func test_label_falls_back_to_entity_root_id_when_snapshot_id_missing() -> void:
	var fixture: Dictionary = _build_entity_with_brain("E_Fallback")
	if fixture.is_empty():
		return

	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var label: Label3D = fixture.get("label") as Label3D
	brain.update_debug_snapshot({
		"goal_id": &"wander",
		"task_id": &"wander",
	})
	await get_tree().process_frame
	label.call("_process", 0.0)

	assert_eq(
		label.text,
		"fallback\ngoal: wander\ntask: wander",
		"Label should derive entity_id from entity root when snapshot omits it."
	)
