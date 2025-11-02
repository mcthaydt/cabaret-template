extends GutTest

## Integration tests for damage system gameplay mechanics (Phase 8.5)
##
## Covers C_DamageZoneComponent + S_DamageSystem interactions with player health:
## - Spike trap damage application and cooldown enforcement
## - Instant-death fall zones triggering game_over
## - Damage zones ignoring non-player bodies via ECS tagging
## - Fall-off-map scenario using death zone prefab

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
const DAMAGE_COMPONENT_PATH := "res://scripts/ecs/components/c_damage_zone_component.gd"
const DAMAGE_SYSTEM_PATH := "res://scripts/ecs/systems/s_damage_system.gd"

var _root: Node
var _state_store: M_StateStore
var _ecs_manager: M_ECSManager
var _scene_manager_stub: TestSceneManager

func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)

	_state_store = M_STATE_STORE.new()
	_state_store.settings = RS_STATE_STORE_SETTINGS.new()
	_state_store.gameplay_initial_state = RS_GAMEPLAY_INITIAL_STATE.new()
	_state_store.scene_initial_state = RS_SCENE_INITIAL_STATE.new()
	_root.add_child(_state_store)

	_scene_manager_stub = TestSceneManager.new()
	_root.add_child(_scene_manager_stub)

	_ecs_manager = M_ECS_MANAGER.new()
	_root.add_child(_ecs_manager)

	await get_tree().process_frame

func after_each() -> void:
	_root = null
	_state_store = null
	_ecs_manager = null
	_scene_manager_stub = null

## Create player entity with health and required systems
func _prepare_damage_fixture() -> Dictionary:
	var health_component_script: Script = load(HEALTH_COMPONENT_PATH)
	if not assert_not_null(health_component_script, "C_HealthComponent script must exist"):
		return {}

	var health_system_script: Script = load(HEALTH_SYSTEM_PATH)
	if not assert_not_null(health_system_script, "S_HealthSystem script must exist"):
		return {}

	var health_settings_script: Script = load(HEALTH_SETTINGS_PATH)
	if not assert_not_null(health_settings_script, "RS_HealthSettings script must exist"):
		return {}

	var damage_component_script: Script = load(DAMAGE_COMPONENT_PATH)
	if not assert_not_null(damage_component_script, "C_DamageZoneComponent script must exist"):
		return {}

	var damage_system_script: Script = load(DAMAGE_SYSTEM_PATH)
	if not assert_not_null(damage_system_script, "S_DamageSystem script must exist"):
		return {}

	var player_tag_script: Script = load(PLAYER_TAG_COMPONENT_PATH)
	if not assert_not_null(player_tag_script, "C_PlayerTagComponent script must exist"):
		return {}

	var health_settings: Resource = ResourceLoader.load(HEALTH_SETTINGS_RESOURCE)
	if not assert_not_null(health_settings, "health_settings.tres must exist"):
		return {}

	var entities := Node3D.new()
	entities.name = "Entities"
	_root.add_child(entities)

	var player_entity := Node3D.new()
	player_entity.name = "E_PlayerTest"
	entities.add_child(player_entity)

	var body := CharacterBody3D.new()
	body.name = "Body"
	body.set_meta("entity_id", "E_Player")
	player_entity.add_child(body)

	var player_tag_component: Node = player_tag_script.new()
	player_entity.add_child(player_tag_component)

	var health_component: Node = health_component_script.new()
	health_component.set("settings", health_settings)
	if health_component.has_method("set_character_body_path"):
		health_component.set_character_body_path(NodePath("Body"))
	else:
		health_component.set("character_body_path", NodePath("Body"))
	player_entity.add_child(health_component)

	var systems := Node.new()
	systems.name = "Systems"
	_root.add_child(systems)

	var core := Node.new()
	core.name = "Core"
	systems.add_child(core)

	var health_system: Node = health_system_script.new()
	health_system.name = "S_HealthSystem"
	core.add_child(health_system)

	var damage_system: Node = damage_system_script.new()
	damage_system.name = "S_DamageSystem"
	core.add_child(damage_system)

	var hazards_root := Node3D.new()
	hazards_root.name = "Hazards"
	_root.add_child(hazards_root)

	await wait_physics_frames(2)

	return {
		"player_body": body,
		"player_entity": player_entity,
		"health_component": health_component,
		"damage_system": damage_system,
		"damage_component_script": damage_component_script,
		"hazards_root": hazards_root
	}

func _instantiate_damage_zone(script: Script, parent: Node, name: String, damage_amount: float, is_instant_death: bool, cooldown: float = 1.0) -> Node:
	var zone_entity := Node3D.new()
	zone_entity.name = name
	parent.add_child(zone_entity)

	var zone_component: Node = script.new()
	zone_component.set("damage_amount", damage_amount)
	zone_component.set("is_instant_death", is_instant_death)
	zone_component.set("damage_cooldown", cooldown)
	zone_entity.add_child(zone_component)
	return zone_component

func _emit_body_entered(zone_component: Node, body: Node3D) -> void:
	if zone_component == null:
		return
	if not zone_component.has_method("get_damage_area"):
		fail_test("C_DamageZoneComponent should expose get_damage_area() for tests")
		return
	var area: Area3D = zone_component.get_damage_area()
	if area == null:
		fail_test("Damage zone missing Area3D child")
		return
	area.emit_signal("body_entered", body)

func test_spike_trap_applies_damage() -> void:
	var fixture := await _prepare_damage_fixture()
	if fixture.is_empty():
		return

	var zone_component: Node = _instantiate_damage_zone(
		fixture["damage_component_script"],
		fixture["hazards_root"],
		"E_SpikeTrap",
		25.0,
		false,
		1.0
	)

	await wait_physics_frames(2)

	var health_component = fixture["health_component"]
	var initial_health: float = health_component.get_current_health()

	_emit_body_entered(zone_component, fixture["player_body"])
	await wait_physics_frames(2)

	var after_damage: float = health_component.get_current_health()
	assert_almost_eq(after_damage, initial_health - 25.0, 0.05, "Spike trap should subtract damage amount from health")

func test_damage_cooldown_prevents_repeated_hits() -> void:
	var fixture := await _prepare_damage_fixture()
	if fixture.is_empty():
		return

	var zone_component: Node = _instantiate_damage_zone(
		fixture["damage_component_script"],
		fixture["hazards_root"],
		"E_SpikeTrap",
		25.0,
		false,
		1.0
	)

	await wait_physics_frames(2)

	var health_component = fixture["health_component"]
	_emit_body_entered(zone_component, fixture["player_body"])
	await wait_physics_frames(2)
	var after_first_hit: float = health_component.get_current_health()

	# Immediate second hit should be ignored due to cooldown
	_emit_body_entered(zone_component, fixture["player_body"])
	await wait_physics_frames(2)
	var after_second_hit: float = health_component.get_current_health()
	assert_almost_eq(after_second_hit, after_first_hit, 0.01, "Cooldown should prevent rapid damage")

	await wait_seconds(1.2)
	_emit_body_entered(zone_component, fixture["player_body"])
	await wait_physics_frames(2)
	var after_cooldown: float = health_component.get_current_health()
	assert_almost_eq(after_cooldown, after_first_hit - 25.0, 0.05, "Damage should apply after cooldown elapses")

func test_fall_death_zone_triggers_game_over() -> void:
	var fixture := await _prepare_damage_fixture()
	if fixture.is_empty():
		return

	var zone_component: Node = _instantiate_damage_zone(
		fixture["damage_component_script"],
		fixture["hazards_root"],
		"E_DeathZone",
		0.0,
		true,
		0.0
	)

	await wait_physics_frames(2)

	var health_component = fixture["health_component"]
	var transitions_before := _scene_manager_stub.transition_calls.size()

	_emit_body_entered(zone_component, fixture["player_body"])
	await wait_physics_frames(2)

	assert_true(health_component.is_dead(), "Fall death zone should mark player dead immediately")
	await wait_seconds(2.7)

	assert_eq(_scene_manager_stub.transition_calls.size(), transitions_before + 1, "Death zone should trigger scene transition")
	var call: Dictionary = _scene_manager_stub.transition_calls[-1]
	assert_eq(call.get("scene_id"), StringName("game_over"), "Fall death should transition to game_over")

func test_damage_zone_ignores_non_player_bodies() -> void:
	var fixture := await _prepare_damage_fixture()
	if fixture.is_empty():
		return

	var zone_component: Node = _instantiate_damage_zone(
		fixture["damage_component_script"],
		fixture["hazards_root"],
		"E_SpikeTrap",
		25.0,
		false,
		1.0
	)

	await wait_physics_frames(2)

	var dummy_body := CharacterBody3D.new()
	dummy_body.name = "NonPlayer"
	fixture["hazards_root"].add_child(dummy_body)

	var health_component = fixture["health_component"]
	var initial_health: float = health_component.get_current_health()

	_emit_body_entered(zone_component, dummy_body)
	await wait_physics_frames(2)

	var after_dummy_enter: float = health_component.get_current_health()
	assert_almost_eq(after_dummy_enter, initial_health, 0.001, "Non-player bodies should not take player damage")

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
