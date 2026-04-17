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
		"hunger": 0.85,
		"sated_threshold": 0.75,
		"starving_threshold": 0.3,
		"is_player_in_range": false,
	})
	await get_tree().process_frame
	label.call("_process", 0.0)

	assert_eq(
		label.text,
		"forest_wolf_01\ngoal: hunt\ntask: move_to_detected_first\nhunger: 0.85\ndetect:false",
		"Label text should render entity/goal/task/detect with multiline formatting."
	)
	assert_almost_eq(label.modulate.g, 0.95, 0.001, "High hunger should render sated/green label color.")

func test_label_falls_back_to_entity_root_id_when_snapshot_id_missing() -> void:
	var fixture: Dictionary = _build_entity_with_brain("E_Fallback")
	if fixture.is_empty():
		return

	var brain: C_AIBrainComponent = fixture.get("brain") as C_AIBrainComponent
	var label: Label3D = fixture.get("label") as Label3D
	brain.update_debug_snapshot({
		"goal_id": &"wander",
		"task_id": &"wander",
		"hunger": 0.2,
		"sated_threshold": 0.75,
		"starving_threshold": 0.3,
		"is_player_in_range": true,
	})
	await get_tree().process_frame
	label.call("_process", 0.0)

	assert_eq(
		label.text,
		"fallback\ngoal: wander\ntask: wander\nhunger: 0.20\ndetect:true",
		"Label should derive entity_id from entity root when snapshot omits it."
	)
	assert_almost_eq(label.modulate.r, 1.0, 0.001, "Low hunger should render starving/red label color.")

func test_label_follows_character_body_position() -> void:
	var fixture: Dictionary = _build_entity_with_brain("E_Wolf_02")
	if fixture.is_empty():
		return

	var entity: BaseECSEntity = fixture.get("entity") as BaseECSEntity
	var label: Label3D = fixture.get("label") as Label3D

	var body := CharacterBody3D.new()
	body.name = "Player_Body"
	entity.add_child(body)
	autofree(body)

	body.global_position = Vector3(5.0, 0.0, 3.0)
	await get_tree().process_frame

	label.call("_process", 0.0)
	assert_almost_eq(label.global_position.x, 5.0, 0.01, "Label X should track body X.")
	assert_almost_eq(label.global_position.z, 3.0, 0.01, "Label Z should track body Z.")

	body.global_position = Vector3(-10.0, 2.0, 7.0)
	label.call("_process", 0.0)
	assert_almost_eq(label.global_position.x, -10.0, 0.01, "Label X should track body after move.")
	assert_almost_eq(label.global_position.z, 7.0, 0.01, "Label Z should track body after move.")
