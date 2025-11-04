extends GutTest

## Integration tests for health system gameplay mechanics (Phase 8.5)
##
## Verifies C_HealthComponent + S_HealthSystem behavior:
## - Initialization to max health with state store synchronization
## - Damage application with invincibility frames
## - Delayed death transition to game_over scene
## - Auto-regeneration after delay
## - Healing clamped to max health
##
## Tests are authored before implementation (TDD); they rely on script paths
## existing and will fail until components/systems are added.

const M_SCENE_MANAGER := preload("res://scripts/managers/m_scene_manager.gd")
const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const RS_STATE_STORE_SETTINGS := preload("res://scripts/state/resources/rs_state_store_settings.gd")
const RS_GAMEPLAY_INITIAL_STATE := preload("res://scripts/state/resources/rs_gameplay_initial_state.gd")
const RS_SCENE_INITIAL_STATE := preload("res://scripts/state/resources/rs_scene_initial_state.gd")
const PLAYER_TAG_COMPONENT_PATH := "res://scripts/ecs/components/c_player_tag_component.gd"
const HEALTH_COMPONENT_PATH := "res://scripts/ecs/components/c_health_component.gd"
const HEALTH_SYSTEM_PATH := "res://scripts/ecs/systems/s_health_system.gd"
const HEALTH_SETTINGS_PATH := "res://scripts/ecs/resources/rs_health_settings.gd"
const HEALTH_SETTINGS_RESOURCE := "res://resources/settings/health_settings.tres"

var _root: Node
var _state_store: M_StateStore
var _ecs_manager: M_ECSManager
var _scene_manager_stub: TestSceneManager

func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)

	# State store with gameplay + scene slices for health integration
	_state_store = M_STATE_STORE.new()
	_state_store.settings = RS_STATE_STORE_SETTINGS.new()
	_state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_root.add_child(_state_store)

	_scene_manager_stub = TestSceneManager.new()
	_root.add_child(_scene_manager_stub)

	_ecs_manager = M_ECS_MANAGER.new()
	_root.add_child(_ecs_manager)

	# Allow nodes to enter tree and register with groups
	await get_tree().process_frame

func after_each() -> void:
	_root = null
	_state_store = null
	_ecs_manager = null
	_scene_manager_stub = null

## Test helper: Prepare player entity with health component/system
func _prepare_health_fixture() -> Dictionary:
	var health_component_script: Script = load(HEALTH_COMPONENT_PATH)
	if not assert_not_null(health_component_script, "C_HealthComponent script must exist"):
		return {}

	var health_system_script: Script = load(HEALTH_SYSTEM_PATH)
	if not assert_not_null(health_system_script, "S_HealthSystem script must exist"):
		return {}

	var health_settings_script: Script = load(HEALTH_SETTINGS_PATH)
	if not assert_not_null(health_settings_script, "RS_HealthSettings script must exist"):
		return {}

	var health_settings_resource: Resource = ResourceLoader.load(HEALTH_SETTINGS_RESOURCE)
	if not assert_not_null(health_settings_resource, "health_settings.tres must exist"):
		return {}

	var player_tag_script: Script = load(PLAYER_TAG_COMPONENT_PATH)
	if not assert_not_null(player_tag_script, "C_PlayerTagComponent script must exist"):
		return {}

	# Build entity hierarchy (E_Player -> CharacterBody + Components)
	var entities_root := Node3D.new()
	entities_root.name = "Entities"
	_root.add_child(entities_root)

	var player_entity := Node3D.new()
	player_entity.name = "E_PlayerTest"
	entities_root.add_child(player_entity)

	var character_body := CharacterBody3D.new()
	character_body.name = "Body"
	character_body.set_meta("entity_id", "E_Player")
	player_entity.add_child(character_body)

	var player_tag_component: Node = player_tag_script.new()
	player_entity.add_child(player_tag_component)

	var health_component: Node = health_component_script.new()
	health_component.name = "C_HealthComponent"
	if health_component.has_method("set"):
		health_component.set("settings", health_settings_resource)
		if health_component.has_method("set_character_body_path"):
			health_component.set_character_body_path(NodePath("Body"))
		elif health_component.has_method("set"):
			health_component.set("character_body_path", NodePath("Body"))
	player_entity.add_child(health_component)

	var systems_root := Node.new()
	systems_root.name = "Systems"
	_root.add_child(systems_root)

	var core_systems := Node.new()
	core_systems.name = "Core"
	systems_root.add_child(core_systems)

	var health_system: Node = health_system_script.new()
	health_system.name = "S_HealthSystem"
	core_systems.add_child(health_system)

	# Wait for auto-registration (components + systems)
	await wait_physics_frames(2)

	return {
		"health_component": health_component,
		"health_system": health_system,
		"character_body": character_body,
		"player_entity": player_entity
	}

func test_health_initializes_to_max() -> void:
	var fixture := await _prepare_health_fixture()
	if fixture.is_empty():
		return

	var health_component = fixture["health_component"]
	assert_true(health_component.has_method("get_current_health"), "C_HealthComponent should expose get_current_health()")
	assert_true(health_component.has_method("get_max_health"), "C_HealthComponent should expose get_max_health()")

	var current_health: float = health_component.get_current_health()
	var max_health: float = health_component.get_max_health()

	assert_almost_eq(current_health, max_health, 0.001, "Health should initialize to max health")

	var gameplay_state: Dictionary = _state_store.get_state().get("gameplay", {})
	assert_true(gameplay_state.has("player_health"), "Gameplay state should track player health")
	assert_almost_eq(float(gameplay_state.get("player_health", -1)), max_health, 0.001, "State store should mirror current health")

func test_damage_reduces_health_and_updates_state() -> void:
	var fixture := await _prepare_health_fixture()
	if fixture.is_empty():
		return

	var health_component = fixture["health_component"]
	assert_true(health_component.has_method("queue_damage"), "C_HealthComponent must support queue_damage()")

	var initial_health: float = health_component.get_current_health()
	health_component.queue_damage(25.0)

	await wait_physics_frames(2)

	var damaged_health: float = health_component.get_current_health()
	assert_almost_eq(damaged_health, initial_health - 25.0, 0.01, "Damage should subtract from health respecting invincibility")

	var gameplay_state: Dictionary = _state_store.get_state().get("gameplay", {})
	assert_almost_eq(float(gameplay_state.get("player_health", initial_health)), damaged_health, 0.01, "Gameplay slice should update player_health on damage")

func test_invincibility_frames_prevent_rapid_damage() -> void:
	var fixture := await _prepare_health_fixture()
	if fixture.is_empty():
		return

	var health_component = fixture["health_component"]
	health_component.queue_damage(25.0)
	await wait_physics_frames(2)

	var after_first_hit: float = health_component.get_current_health()
	health_component.queue_damage(25.0)
	await wait_physics_frames(2)

	var after_second_hit: float = health_component.get_current_health()
	assert_almost_eq(after_second_hit, after_first_hit, 0.001, "Invincibility window should block immediate second hit")

	await wait_seconds(1.2)
	health_component.queue_damage(25.0)
	await wait_physics_frames(2)

	var after_cooldown: float = health_component.get_current_health()
	assert_almost_eq(after_cooldown, after_first_hit - 25.0, 0.05, "Damage should apply once invincibility expires")

func test_auto_regeneration_recovers_health_over_time() -> void:
	var fixture := await _prepare_health_fixture()
	if fixture.is_empty():
		return

	var health_component = fixture["health_component"]
	health_component.queue_damage(40.0)
	await wait_physics_frames(2)

	var post_damage: float = health_component.get_current_health()
	await wait_seconds(3.2)  # regen_delay before regen kicks in

	var before_regen: float = health_component.get_current_health()
	await wait_seconds(1.0)

	var after_regen: float = health_component.get_current_health()
	assert_almost_eq(before_regen, post_damage, 0.2, "Health should remain flat during regen delay")
	assert_gt(after_regen, before_regen, "Health should increase once regen starts")
	assert_almost_eq(after_regen, min(post_damage + 10.0, health_component.get_max_health()), 1.0, "Regen rate should be ~10 hp/s clamped to max")

func test_healing_restores_health_without_exceeding_max() -> void:
	var fixture := await _prepare_health_fixture()
	if fixture.is_empty():
		return

	var health_component = fixture["health_component"]
	health_component.queue_damage(30.0)
	await wait_physics_frames(2)

	var damaged_health: float = health_component.get_current_health()
	assert_true(health_component.has_method("queue_heal"), "C_HealthComponent must support queue_heal()")
	health_component.queue_heal(20.0)
	await wait_physics_frames(2)

	var healed_health: float = health_component.get_current_health()
	assert_almost_eq(healed_health, damaged_health + 20.0, 0.01, "Healing should restore requested amount")

	health_component.queue_heal(500.0)
	await wait_physics_frames(2)

	var capped_health: float = health_component.get_current_health()
	assert_almost_eq(capped_health, health_component.get_max_health(), 0.001, "Healing should not exceed max health")

func test_death_triggers_delayed_game_over_transition() -> void:
	var fixture := await _prepare_health_fixture()
	if fixture.is_empty():
		return

	var health_component = fixture["health_component"]
	var transition_calls_before: int = _scene_manager_stub.transition_calls.size()

	# Apply lethal damage and ensure immediate state reflects death but transition waits
	health_component.queue_damage(999.0)
	await wait_physics_frames(2)

	assert_true(health_component.has_method("is_dead"), "C_HealthComponent must expose is_dead()")
	assert_true(health_component.is_dead(), "Health component should mark entity dead after lethal damage")
	assert_eq(_scene_manager_stub.transition_calls.size(), transition_calls_before, "Death transition should be delayed by animation timer")

	await wait_seconds(2.7)  # death_animation_duration + buffer

	assert_eq(_scene_manager_stub.transition_calls.size(), transition_calls_before + 1, "SceneManager should receive transition after death delay")
	var call: Dictionary = _scene_manager_stub.transition_calls[-1]
	assert_eq(call.get("scene_id"), StringName("game_over"), "Death should transition to game_over scene")
	assert_eq(call.get("transition_type"), "fade", "Death transition should use fade effect")
	assert_eq(int(call.get("priority", -1)), M_SCENE_MANAGER.Priority.CRITICAL, "Death transition should be critical priority")

	var gameplay_state: Dictionary = _state_store.get_state().get("gameplay", {})
	assert_eq(int(gameplay_state.get("death_count", 0)), 1, "Gameplay state should increment death_count")

class TestSceneManager:
	extends Node

	var transition_calls: Array = []
	var _is_transitioning: bool = false

	func _ready() -> void:
		add_to_group("scene_manager")

	func transition_to_scene(scene_id: StringName, transition_type: String, priority: int = M_SCENE_MANAGER.Priority.NORMAL) -> void:
		transition_calls.append({
			"scene_id": scene_id,
			"transition_type": transition_type,
			"priority": priority
		})
		_is_transitioning = true

	func is_transitioning() -> bool:
		return _is_transitioning

	func reset_transition_state() -> void:
		_is_transitioning = false
