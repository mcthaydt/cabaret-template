extends BaseTest

const PANEL_SCRIPT_PATH := "res://scripts/debug/debug_ai_brain_panel.gd"
const C_AI_BRAIN_COMPONENT := preload("res://scripts/ecs/components/c_ai_brain_component.gd")
const MOCK_ECS_MANAGER := preload("res://tests/mocks/mock_ecs_manager.gd")
const RS_AI_BRAIN_PLACEHOLDER := preload("res://resources/ai/cfg_ai_brain_placeholder.tres")

func _instantiate_panel() -> Control:
	var panel_script_variant: Variant = load(PANEL_SCRIPT_PATH)
	assert_not_null(panel_script_variant, "Expected debug AI brain panel script to exist: %s" % PANEL_SCRIPT_PATH)
	if not (panel_script_variant is Script):
		return null

	var panel_variant: Variant = (panel_script_variant as Script).new()
	assert_true(panel_variant is Control, "Debug AI brain panel should extend Control.")
	if not (panel_variant is Control):
		return null

	var panel: Control = panel_variant as Control
	add_child_autofree(panel)
	await get_tree().process_frame
	return panel

func _register_brain(mock_manager: MockECSManager, snapshot: Dictionary, parent: Node) -> C_AIBrainComponent:
	var entity := Node3D.new()
	var entity_id_text: String = str(snapshot.get("entity_id", "test_entity"))
	entity.name = "E_%s" % entity_id_text
	parent.add_child(entity)
	autofree(entity)

	var brain: C_AIBrainComponent = C_AI_BRAIN_COMPONENT.new()
	brain.brain_settings = RS_AI_BRAIN_PLACEHOLDER
	entity.add_child(brain)
	autofree(brain)
	brain.update_debug_snapshot(snapshot)
	mock_manager.register_component(brain)
	return brain

func _get_row_labels(panel: Control) -> Array[Label]:
	var rows_node: Node = panel.get_node_or_null("Rows")
	assert_not_null(rows_node, "Panel should contain a node named 'Rows' for row labels.")
	if rows_node == null:
		return []

	var labels: Array[Label] = []
	for child in rows_node.get_children():
		if child is Label:
			labels.append(child as Label)
	return labels

func test_panel_renders_one_row_per_brain_component() -> void:
	var panel: Control = await _instantiate_panel()
	if panel == null:
		return

	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	add_child_autofree(ecs_manager)
	panel.set("ecs_manager", ecs_manager)

	_register_brain(ecs_manager, {
		"entity_id": &"E_Wolf_01",
		"goal_id": &"hunt",
		"task_id": &"move_to_detected",
	}, panel)
	_register_brain(ecs_manager, {
		"entity_id": &"E_Rabbit_01",
		"goal_id": &"flee",
		"task_id": &"flee_from_detected",
	}, panel)

	assert_true(panel.has_method("refresh_rows"), "Panel should expose refresh_rows() for deterministic testing.")
	if not panel.has_method("refresh_rows"):
		return
	panel.call("refresh_rows")

	var row_labels: Array[Label] = _get_row_labels(panel)
	assert_eq(row_labels.size(), 2, "Panel should render exactly one row per brain component.")

func test_panel_row_text_contains_entity_goal_and_task() -> void:
	var panel: Control = await _instantiate_panel()
	if panel == null:
		return

	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	add_child_autofree(ecs_manager)
	panel.set("ecs_manager", ecs_manager)

	_register_brain(ecs_manager, {
		"entity_id": &"E_Deer_01",
		"goal_id": &"startle",
		"task_id": &"scan_alert",
	}, panel)

	assert_true(panel.has_method("refresh_rows"), "Panel should expose refresh_rows() for deterministic testing.")
	if not panel.has_method("refresh_rows"):
		return
	panel.call("refresh_rows")

	var row_labels: Array[Label] = _get_row_labels(panel)
	assert_eq(row_labels.size(), 1, "Expected a single row for one brain component.")
	if row_labels.size() != 1:
		return

	var row_text: String = row_labels[0].text
	assert_string_contains(row_text, "E_Deer_01", "Row text should include entity_id.")
	assert_string_contains(row_text, "startle", "Row text should include goal_id.")
	assert_string_contains(row_text, "scan_alert", "Row text should include task_id.")

func test_panel_handles_empty_brain_list_without_crashing() -> void:
	var panel: Control = await _instantiate_panel()
	if panel == null:
		return

	var ecs_manager: MockECSManager = MOCK_ECS_MANAGER.new()
	add_child_autofree(ecs_manager)
	panel.set("ecs_manager", ecs_manager)

	assert_true(panel.has_method("refresh_rows"), "Panel should expose refresh_rows() for deterministic testing.")
	if not panel.has_method("refresh_rows"):
		return
	panel.call("refresh_rows")

	var row_labels: Array[Label] = _get_row_labels(panel)
	assert_eq(row_labels.size(), 0, "Panel should render zero rows when no brain components are present.")
