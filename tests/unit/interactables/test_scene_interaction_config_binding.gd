extends BaseTest

const U_INTERACTION_CONFIG_RESOLVER := preload("res://scripts/gameplay/helpers/u_interaction_config_resolver.gd")
const RS_DOOR_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_door_interaction_config.gd")
const RS_CHECKPOINT_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_checkpoint_interaction_config.gd")
const RS_HAZARD_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_hazard_interaction_config.gd")
const RS_VICTORY_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_victory_interaction_config.gd")
const RS_SIGNPOST_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_signpost_interaction_config.gd")
const RS_ENDGAME_GOAL_INTERACTION_CONFIG := preload("res://scripts/resources/interactions/rs_endgame_goal_interaction_config.gd")

const SCENE_PATHS := [
	"res://scenes/gameplay/gameplay_exterior.tscn",
	"res://scenes/gameplay/gameplay_alleyway.tscn",
	"res://scenes/gameplay/gameplay_bar.tscn",
	"res://scenes/gameplay/gameplay_interior_house.tscn",
	"res://scenes/prefabs/prefab_door_trigger.tscn",
	"res://scenes/prefabs/prefab_checkpoint_safe_zone.tscn",
	"res://scenes/prefabs/prefab_spike_trap.tscn",
	"res://scenes/prefabs/prefab_death_zone.tscn",
	"res://scenes/prefabs/prefab_goal_zone.tscn",
]

const CONTROLLER_TO_CONFIG_SCRIPT := {
	"res://scripts/gameplay/inter_door_trigger.gd": RS_DOOR_INTERACTION_CONFIG,
	"res://scripts/gameplay/inter_checkpoint_zone.gd": RS_CHECKPOINT_INTERACTION_CONFIG,
	"res://scripts/gameplay/inter_hazard_zone.gd": RS_HAZARD_INTERACTION_CONFIG,
	"res://scripts/gameplay/inter_victory_zone.gd": RS_VICTORY_INTERACTION_CONFIG,
	"res://scripts/gameplay/inter_signpost.gd": RS_SIGNPOST_INTERACTION_CONFIG,
	"res://scripts/gameplay/inter_endgame_goal_zone.gd": RS_ENDGAME_GOAL_INTERACTION_CONFIG,
}

func test_interaction_controllers_have_typed_config_assignments_in_scenes() -> void:
	for scene_path_variant in SCENE_PATHS:
		var scene_path := String(scene_path_variant)
		var packed := load(scene_path) as PackedScene
		assert_not_null(packed, "Scene should load: %s" % scene_path)
		if packed == null:
			continue

		var instance := packed.instantiate()

		var controllers: Array[Node] = []
		_collect_interaction_controllers(instance, controllers)
		assert_true(controllers.size() > 0, "Expected interactable controllers in scene: %s" % scene_path)

		for controller in controllers:
			assert_true(
				_is_config_assignment_valid(controller),
				"Controller config must be assigned and typed (%s :: %s)" % [scene_path, controller.name]
			)
		instance.free()

func test_scene_config_validation_fails_when_config_missing_or_wrong_type() -> void:
	var packed := load("res://scenes/prefabs/prefab_door_trigger.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return

	var instance := packed.instantiate()

	var controllers: Array[Node] = []
	_collect_interaction_controllers(instance, controllers)
	assert_true(controllers.size() > 0, "Expected at least one interaction controller in prefab.")
	if controllers.is_empty():
		return

	var controller := controllers[0]
	assert_true(_is_config_assignment_valid(controller), "Fixture should start with a valid config assignment.")

	controller.set("config", null)
	assert_false(_is_config_assignment_valid(controller), "Validation should fail when config is missing.")

	controller.set("config", RS_HAZARD_INTERACTION_CONFIG.new())
	assert_false(_is_config_assignment_valid(controller), "Validation should fail for wrong config resource subtype.")
	instance.free()

func _collect_interaction_controllers(node: Node, controllers: Array[Node]) -> void:
	if node == null:
		return

	var script_obj := node.get_script() as Script
	if script_obj != null:
		var script_path := script_obj.resource_path
		if CONTROLLER_TO_CONFIG_SCRIPT.has(script_path):
			controllers.append(node)

	for child in node.get_children():
		_collect_interaction_controllers(child, controllers)

func _is_config_assignment_valid(controller: Node) -> bool:
	if controller == null:
		return false
	if not ("config" in controller):
		return false

	var script_obj := controller.get_script() as Script
	if script_obj == null:
		return false

	var script_path := script_obj.resource_path
	var expected_variant: Variant = CONTROLLER_TO_CONFIG_SCRIPT.get(script_path, null)
	if not (expected_variant is Script):
		return false
	var expected_script := expected_variant as Script

	var config_variant: Variant = controller.get("config")
	if not (config_variant is Resource):
		return false
	var config_resource := config_variant as Resource

	return U_INTERACTION_CONFIG_RESOLVER.script_matches(config_resource, expected_script)
