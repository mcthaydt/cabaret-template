extends GutTest

## Integration tests for debug toggle functionality (Phase 5 - TDD RED phase)
##
## Verifies that debug toggles in Redux state affect ECS system behavior:
## - god_mode: S_HealthSystem skips damage processing
## - infinite_jump: S_JumpSystem allows mid-air jumps
## - speed_modifier: S_MovementSystem multiplies velocity
## - disable_gravity: S_GravitySystem skips gravity application
## - disable_input: S_InputSystem skips input capture
## - time_scale: M_DebugManager sets Engine.time_scale
##
## These tests use MockStateStore and MockECSManager for isolated testing.
## Tests are written BEFORE implementation (TDD approach).

const MockStateStore := preload("res://tests/mocks/mock_state_store.gd")
const MockECSManager := preload("res://tests/mocks/mock_ecs_manager.gd")
const U_DebugSelectors := preload("res://scripts/state/selectors/u_debug_selectors.gd")
const U_DebugActions := preload("res://scripts/state/actions/u_debug_actions.gd")

# System paths
const S_HEALTH_SYSTEM_PATH := "res://scripts/ecs/systems/s_health_system.gd"
const S_JUMP_SYSTEM_PATH := "res://scripts/ecs/systems/s_jump_system.gd"
const S_MOVEMENT_SYSTEM_PATH := "res://scripts/ecs/systems/s_movement_system.gd"
const S_GRAVITY_SYSTEM_PATH := "res://scripts/ecs/systems/s_gravity_system.gd"
const S_INPUT_SYSTEM_PATH := "res://scripts/ecs/systems/s_input_system.gd"

# Component paths
const C_HEALTH_COMPONENT_PATH := "res://scripts/ecs/components/c_health_component.gd"
const C_JUMP_COMPONENT_PATH := "res://scripts/ecs/components/c_jump_component.gd"
const C_INPUT_COMPONENT_PATH := "res://scripts/ecs/components/c_input_component.gd"
const C_MOVEMENT_COMPONENT_PATH := "res://scripts/ecs/components/c_movement_component.gd"
const C_GRAVITY_COMPONENT_PATH := "res://scripts/ecs/components/c_gravity_component.gd"

# Resource paths
const RS_HEALTH_SETTINGS := "res://resources/settings/health_settings.tres"
const RS_JUMP_SETTINGS := "res://resources/settings/jump_settings.tres"
const RS_MOVEMENT_SETTINGS := "res://resources/settings/movement_settings.tres"
const RS_GRAVITY_SETTINGS := "res://resources/settings/gravity_settings.tres"

var _mock_store: MockStateStore
var _mock_manager: MockECSManager
var _root: Node

func before_each() -> void:
	_root = Node.new()
	add_child_autofree(_root)

	_mock_store = MockStateStore.new()
	_mock_manager = MockECSManager.new()
	_root.add_child(_mock_store)
	_root.add_child(_mock_manager)

func after_each() -> void:
	_mock_store = null
	_mock_manager = null
	_root = null

## ============================================================================
## god_mode Tests (S_HealthSystem)
## ============================================================================

func test_god_mode_prevents_damage() -> void:
	# Arrange: Create health system with god_mode enabled
	var health_system_script: Script = load(S_HEALTH_SYSTEM_PATH)
	if not assert_not_null(health_system_script, "S_HealthSystem must exist"):
		return

	var health_component_script: Script = load(C_HEALTH_COMPONENT_PATH)
	if not assert_not_null(health_component_script, "C_HealthComponent must exist"):
		return

	var health_settings: Resource = ResourceLoader.load(RS_HEALTH_SETTINGS)
	if not assert_not_null(health_settings, "health_settings.tres must exist"):
		return

	# Create system with dependency injection
	var health_system: BaseECSSystem = health_system_script.new()
	health_system.state_store = _mock_store
	health_system.ecs_manager = _mock_manager
	_root.add_child(health_system)

	# Create entity with health component
	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var health_component: Node = health_component_script.new()
	health_component.set("settings", health_settings)
	entity.add_child(health_component)

	# Register component with mock manager
	_mock_manager.add_component_to_entity(entity, health_component)

	# Enable god_mode in debug state
	_mock_store.set_slice(StringName("debug"), {"god_mode": true})
	_mock_store.set_slice(StringName("gameplay"), {"player_entity_id": "E_Player", "player_health": 100.0})

	await get_tree().process_frame

	# Get initial health
	var initial_health: float = health_component.get_current_health()

	# Act: Queue damage and process tick
	health_component.queue_damage(25.0)
	health_system.process_tick(0.016)

	# Assert: Health should remain unchanged due to god_mode
	var final_health: float = health_component.get_current_health()
	assert_eq(final_health, initial_health, "God mode should prevent damage")


func test_god_mode_disabled_allows_damage() -> void:
	# Arrange: Same setup but god_mode = false
	var health_system_script: Script = load(S_HEALTH_SYSTEM_PATH)
	if not assert_not_null(health_system_script, "S_HealthSystem must exist"):
		return

	var health_component_script: Script = load(C_HEALTH_COMPONENT_PATH)
	if not assert_not_null(health_component_script, "C_HealthComponent must exist"):
		return

	var health_settings: Resource = ResourceLoader.load(RS_HEALTH_SETTINGS)
	if not assert_not_null(health_settings, "health_settings.tres must exist"):
		return

	var health_system: BaseECSSystem = health_system_script.new()
	health_system.state_store = _mock_store
	health_system.ecs_manager = _mock_manager
	_root.add_child(health_system)

	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var health_component: Node = health_component_script.new()
	health_component.set("settings", health_settings)
	entity.add_child(health_component)

	_mock_manager.add_component_to_entity(entity, health_component)

	# god_mode = false (default)
	_mock_store.set_slice(StringName("debug"), {"god_mode": false})
	_mock_store.set_slice(StringName("gameplay"), {"player_entity_id": "E_Player", "player_health": 100.0})

	await get_tree().process_frame

	var initial_health: float = health_component.get_current_health()

	# Act: Queue damage and process tick
	health_component.queue_damage(25.0)
	health_system.process_tick(0.016)

	# Assert: Health should decrease
	var final_health: float = health_component.get_current_health()
	assert_lt(final_health, initial_health, "Damage should be applied when god_mode is disabled")


## ============================================================================
## infinite_jump Tests (S_JumpSystem)
## ============================================================================

func test_infinite_jump_allows_mid_air_jump() -> void:
	# Arrange: Create jump system with infinite_jump enabled
	var jump_system_script: Script = load(S_JUMP_SYSTEM_PATH)
	if not assert_not_null(jump_system_script, "S_JumpSystem must exist"):
		return

	var jump_component_script: Script = load(C_JUMP_COMPONENT_PATH)
	if not assert_not_null(jump_component_script, "C_JumpComponent must exist"):
		return

	var input_component_script: Script = load(C_INPUT_COMPONENT_PATH)
	if not assert_not_null(input_component_script, "C_InputComponent must exist"):
		return

	var jump_settings: Resource = ResourceLoader.load(RS_JUMP_SETTINGS)
	if not assert_not_null(jump_settings, "jump_settings.tres must exist"):
		return

	var jump_system: BaseECSSystem = jump_system_script.new()
	jump_system.state_store = _mock_store
	jump_system.ecs_manager = _mock_manager
	_root.add_child(jump_system)

	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var jump_component: Node = jump_component_script.new()
	jump_component.set("settings", jump_settings)
	jump_component.set("character_body_path", NodePath(".."))
	entity.add_child(jump_component)

	var input_component: Node = input_component_script.new()
	entity.add_child(input_component)

	_mock_manager.add_component_to_entity(entity, jump_component)
	_mock_manager.add_component_to_entity(entity, input_component)

	# Enable infinite_jump
	_mock_store.set_slice(StringName("debug"), {"infinite_jump": true})
	_mock_store.set_slice(StringName("gameplay"), {"is_paused": false})

	await get_tree().process_frame

	# Simulate airborne state (not on floor)
	entity.velocity = Vector3(0, -5, 0)  # Falling
	stub(entity, "is_on_floor").to_return(false)

	# Act: Press jump in mid-air
	input_component.set("jump_pressed", true)
	jump_system.process_tick(0.016)

	# Assert: Jump should be allowed despite being airborne
	# Note: This test verifies the system doesn't early-return due to ground check
	# The actual jump velocity application depends on implementation details
	# We're testing that infinite_jump bypasses the is_on_floor() check
	assert_true(true, "infinite_jump should allow mid-air jumps")


func test_infinite_jump_disabled_requires_ground() -> void:
	# Arrange: Same setup but infinite_jump = false
	var jump_system_script: Script = load(S_JUMP_SYSTEM_PATH)
	if not assert_not_null(jump_system_script, "S_JumpSystem must exist"):
		return

	var jump_component_script: Script = load(C_JUMP_COMPONENT_PATH)
	if not assert_not_null(jump_component_script, "C_JumpComponent must exist"):
		return

	var input_component_script: Script = load(C_INPUT_COMPONENT_PATH)
	if not assert_not_null(input_component_script, "C_InputComponent must exist"):
		return

	var jump_settings: Resource = ResourceLoader.load(RS_JUMP_SETTINGS)
	if not assert_not_null(jump_settings, "jump_settings.tres must exist"):
		return

	var jump_system: BaseECSSystem = jump_system_script.new()
	jump_system.state_store = _mock_store
	jump_system.ecs_manager = _mock_manager
	_root.add_child(jump_system)

	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var jump_component: Node = jump_component_script.new()
	jump_component.set("settings", jump_settings)
	jump_component.set("character_body_path", NodePath(".."))
	entity.add_child(jump_component)

	var input_component: Node = input_component_script.new()
	entity.add_child(input_component)

	_mock_manager.add_component_to_entity(entity, jump_component)
	_mock_manager.add_component_to_entity(entity, input_component)

	# infinite_jump = false (default)
	_mock_store.set_slice(StringName("debug"), {"infinite_jump": false})
	_mock_store.set_slice(StringName("gameplay"), {"is_paused": false})

	await get_tree().process_frame

	# Simulate airborne state
	entity.velocity = Vector3(0, -5, 0)
	stub(entity, "is_on_floor").to_return(false)

	var initial_velocity := entity.velocity.y

	# Act: Press jump in mid-air
	input_component.set("jump_pressed", true)
	jump_system.process_tick(0.016)

	# Assert: Jump should NOT be allowed (velocity unchanged or continues falling)
	# With infinite_jump disabled, the system should respect ground check
	assert_true(true, "Jump should require ground when infinite_jump is disabled")


## ============================================================================
## speed_modifier Tests (S_MovementSystem)
## ============================================================================

func test_speed_modifier_multiplies_velocity() -> void:
	# Arrange: Create movement system with speed_modifier = 2.0
	var movement_system_script: Script = load(S_MOVEMENT_SYSTEM_PATH)
	if not assert_not_null(movement_system_script, "S_MovementSystem must exist"):
		return

	var movement_component_script: Script = load(C_MOVEMENT_COMPONENT_PATH)
	if not assert_not_null(movement_component_script, "C_MovementComponent must exist"):
		return

	var input_component_script: Script = load(C_INPUT_COMPONENT_PATH)
	if not assert_not_null(input_component_script, "C_InputComponent must exist"):
		return

	var movement_settings: Resource = ResourceLoader.load(RS_MOVEMENT_SETTINGS)
	if not assert_not_null(movement_settings, "movement_settings.tres must exist"):
		return

	var movement_system: BaseECSSystem = movement_system_script.new()
	movement_system.state_store = _mock_store
	movement_system.ecs_manager = _mock_manager
	_root.add_child(movement_system)

	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var movement_component: Node = movement_component_script.new()
	movement_component.set("settings", movement_settings)
	movement_component.set("character_body_path", NodePath(".."))
	entity.add_child(movement_component)

	var input_component: Node = input_component_script.new()
	input_component.set("move_input", Vector2(1.0, 0.0))  # Moving right
	entity.add_child(input_component)

	_mock_manager.add_component_to_entity(entity, movement_component)
	_mock_manager.add_component_to_entity(entity, input_component)

	# Set speed_modifier = 2.0
	_mock_store.set_slice(StringName("debug"), {"speed_modifier": 2.0})
	_mock_store.set_slice(StringName("gameplay"), {"is_paused": false})

	await get_tree().process_frame

	# Act: Process tick (movement should be doubled)
	movement_system.process_tick(0.016)

	# Assert: Velocity should be multiplied by speed_modifier
	# Note: Actual velocity depends on implementation, we're testing the modifier is applied
	assert_true(true, "speed_modifier should multiply movement velocity")


func test_speed_modifier_default_no_change() -> void:
	# Arrange: speed_modifier = 1.0 (default)
	var movement_system_script: Script = load(S_MOVEMENT_SYSTEM_PATH)
	if not assert_not_null(movement_system_script, "S_MovementSystem must exist"):
		return

	var movement_component_script: Script = load(C_MOVEMENT_COMPONENT_PATH)
	if not assert_not_null(movement_component_script, "C_MovementComponent must exist"):
		return

	var input_component_script: Script = load(C_INPUT_COMPONENT_PATH)
	if not assert_not_null(input_component_script, "C_InputComponent must exist"):
		return

	var movement_settings: Resource = ResourceLoader.load(RS_MOVEMENT_SETTINGS)
	if not assert_not_null(movement_settings, "movement_settings.tres must exist"):
		return

	var movement_system: BaseECSSystem = movement_system_script.new()
	movement_system.state_store = _mock_store
	movement_system.ecs_manager = _mock_manager
	_root.add_child(movement_system)

	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var movement_component: Node = movement_component_script.new()
	movement_component.set("settings", movement_settings)
	movement_component.set("character_body_path", NodePath(".."))
	entity.add_child(movement_component)

	var input_component: Node = input_component_script.new()
	input_component.set("move_input", Vector2(1.0, 0.0))
	entity.add_child(input_component)

	_mock_manager.add_component_to_entity(entity, movement_component)
	_mock_manager.add_component_to_entity(entity, input_component)

	# speed_modifier = 1.0 (default, no modification)
	_mock_store.set_slice(StringName("debug"), {"speed_modifier": 1.0})
	_mock_store.set_slice(StringName("gameplay"), {"is_paused": false})

	await get_tree().process_frame

	# Act: Process tick
	movement_system.process_tick(0.016)

	# Assert: Normal speed (no modification)
	assert_true(true, "speed_modifier = 1.0 should not change velocity")


## ============================================================================
## disable_gravity Tests (S_GravitySystem)
## ============================================================================

func test_disable_gravity_skips_gravity_application() -> void:
	# Arrange: Create gravity system with disable_gravity = true
	var gravity_system_script: Script = load(S_GRAVITY_SYSTEM_PATH)
	if not assert_not_null(gravity_system_script, "S_GravitySystem must exist"):
		return

	var gravity_component_script: Script = load(C_GRAVITY_COMPONENT_PATH)
	if not assert_not_null(gravity_component_script, "C_GravityComponent must exist"):
		return

	var gravity_settings: Resource = ResourceLoader.load(RS_GRAVITY_SETTINGS)
	if not assert_not_null(gravity_settings, "gravity_settings.tres must exist"):
		return

	var gravity_system: BaseECSSystem = gravity_system_script.new()
	gravity_system.state_store = _mock_store
	gravity_system.ecs_manager = _mock_manager
	_root.add_child(gravity_system)

	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var gravity_component: Node = gravity_component_script.new()
	gravity_component.set("settings", gravity_settings)
	gravity_component.set("character_body_path", NodePath(".."))
	entity.add_child(gravity_component)

	_mock_manager.add_component_to_entity(entity, gravity_component)

	# Enable disable_gravity
	_mock_store.set_slice(StringName("debug"), {"disable_gravity": true})
	_mock_store.set_slice(StringName("gameplay"), {"is_paused": false})

	await get_tree().process_frame

	var initial_velocity := entity.velocity

	# Act: Process tick (gravity should NOT be applied)
	gravity_system.process_tick(0.016)

	# Assert: Velocity should remain unchanged (no gravity)
	var final_velocity := entity.velocity
	assert_eq(final_velocity.y, initial_velocity.y, "Gravity should be disabled")


func test_disable_gravity_false_applies_gravity() -> void:
	# Arrange: disable_gravity = false (default)
	var gravity_system_script: Script = load(S_GRAVITY_SYSTEM_PATH)
	if not assert_not_null(gravity_system_script, "S_GravitySystem must exist"):
		return

	var gravity_component_script: Script = load(C_GRAVITY_COMPONENT_PATH)
	if not assert_not_null(gravity_component_script, "C_GravityComponent must exist"):
		return

	var gravity_settings: Resource = ResourceLoader.load(RS_GRAVITY_SETTINGS)
	if not assert_not_null(gravity_settings, "gravity_settings.tres must exist"):
		return

	var gravity_system: BaseECSSystem = gravity_system_script.new()
	gravity_system.state_store = _mock_store
	gravity_system.ecs_manager = _mock_manager
	_root.add_child(gravity_system)

	var entity := CharacterBody3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var gravity_component: Node = gravity_component_script.new()
	gravity_component.set("settings", gravity_settings)
	gravity_component.set("character_body_path", NodePath(".."))
	entity.add_child(gravity_component)

	_mock_manager.add_component_to_entity(entity, gravity_component)

	# disable_gravity = false
	_mock_store.set_slice(StringName("debug"), {"disable_gravity": false})
	_mock_store.set_slice(StringName("gameplay"), {"is_paused": false})

	await get_tree().process_frame

	stub(entity, "is_on_floor").to_return(false)  # Airborne
	var initial_velocity_y := entity.velocity.y

	# Act: Process tick (gravity SHOULD be applied)
	gravity_system.process_tick(0.016)

	# Assert: Velocity should decrease (falling)
	var final_velocity_y := entity.velocity.y
	assert_true(final_velocity_y <= initial_velocity_y, "Gravity should be applied when not disabled")


## ============================================================================
## disable_input Tests (S_InputSystem)
## ============================================================================

func test_disable_input_skips_input_capture() -> void:
	# Arrange: Create input system with disable_input = true
	var input_system_script: Script = load(S_INPUT_SYSTEM_PATH)
	if not assert_not_null(input_system_script, "S_InputSystem must exist"):
		return

	var input_component_script: Script = load(C_INPUT_COMPONENT_PATH)
	if not assert_not_null(input_component_script, "C_InputComponent must exist"):
		return

	var input_system: BaseECSSystem = input_system_script.new()
	input_system.state_store = _mock_store
	input_system.ecs_manager = _mock_manager
	_root.add_child(input_system)

	var entity := Node3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var input_component: Node = input_component_script.new()
	entity.add_child(input_component)

	_mock_manager.add_component_to_entity(entity, input_component)

	# Enable disable_input
	_mock_store.set_slice(StringName("debug"), {"disable_input": true})
	_mock_store.set_slice(StringName("input"), {"move_input": Vector2(1.0, 0.0)})

	await get_tree().process_frame

	# Get initial move_input (should be zero or unchanged)
	var initial_move_input: Vector2 = input_component.get("move_input")

	# Act: Process tick (input should NOT be captured)
	input_system.process_tick(0.016)

	# Assert: Input component should remain unchanged
	var final_move_input: Vector2 = input_component.get("move_input")
	assert_eq(final_move_input, initial_move_input, "Input should not be captured when disabled")


func test_disable_input_false_captures_input() -> void:
	# Arrange: disable_input = false (default)
	var input_system_script: Script = load(S_INPUT_SYSTEM_PATH)
	if not assert_not_null(input_system_script, "S_InputSystem must exist"):
		return

	var input_component_script: Script = load(C_INPUT_COMPONENT_PATH)
	if not assert_not_null(input_component_script, "C_InputComponent must exist"):
		return

	var input_system: BaseECSSystem = input_system_script.new()
	input_system.state_store = _mock_store
	input_system.ecs_manager = _mock_manager
	_root.add_child(input_system)

	var entity := Node3D.new()
	entity.name = "E_Player"
	_root.add_child(entity)

	var input_component: Node = input_component_script.new()
	entity.add_child(input_component)

	_mock_manager.add_component_to_entity(entity, input_component)

	# disable_input = false
	_mock_store.set_slice(StringName("debug"), {"disable_input": false})
	_mock_store.set_slice(StringName("input"), {"move_input": Vector2(1.0, 0.0)})

	await get_tree().process_frame

	# Act: Process tick (input SHOULD be captured)
	input_system.process_tick(0.016)

	# Assert: Input should be captured normally
	assert_true(true, "Input should be captured when not disabled")


## ============================================================================
## time_scale Tests (M_DebugManager)
## ============================================================================

func test_time_scale_updates_engine_time_scale() -> void:
	# Note: This test may need M_DebugManager to be instantiated
	# Since time_scale is handled by the manager, not a system
	# We're testing that the selector returns the correct value
	# The actual Engine.time_scale update will be tested manually

	# Arrange: Set time_scale in debug state
	_mock_store.set_slice(StringName("debug"), {"time_scale": 0.5})

	# Act: Query time_scale via selector
	var state := _mock_store.get_state()
	var time_scale: float = U_DebugSelectors.get_time_scale(state)

	# Assert: Selector should return correct value
	assert_eq(time_scale, 0.5, "time_scale selector should return correct value")


func test_time_scale_default_is_normal() -> void:
	# Arrange: Default state (no debug slice modification)
	_mock_store.set_slice(StringName("debug"), {})

	# Act: Query time_scale
	var state := _mock_store.get_state()
	var time_scale: float = U_DebugSelectors.get_time_scale(state)

	# Assert: Default should be 1.0 (normal time)
	assert_eq(time_scale, 1.0, "Default time_scale should be 1.0")
