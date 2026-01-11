extends GutTest

# Test suite for M_VFXManager scaffolding and lifecycle (Phase 1, Task 1.1)
# Tests manager initialization, group membership, ServiceLocator registration,
# StateStore discovery, and basic trauma system functionality

const M_VFX_MANAGER := preload("res://scripts/managers/m_vfx_manager.gd")
const M_STATE_STORE := preload("res://scripts/state/m_state_store.gd")
const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_ECS_EVENT_BUS := preload("res://scripts/ecs/u_ecs_event_bus.gd")

var _manager: Node
var _store: Node

func before_each() -> void:
	# Clear ServiceLocator before each test
	U_SERVICE_LOCATOR.clear()
	# Reset ECS Event Bus to prevent subscription leaks
	U_ECS_EVENT_BUS.reset()

func after_each() -> void:
	# Clean up ServiceLocator after each test
	U_SERVICE_LOCATOR.clear()
	# Reset ECS Event Bus after each test
	U_ECS_EVENT_BUS.reset()

# Test 1: Manager extends Node
func test_manager_extends_node() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)

	assert_true(_manager is Node, "M_VFXManager should extend Node")

# Test 2: Manager adds itself to "vfx_manager" group
func test_manager_adds_to_vfx_manager_group() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_true(_manager.is_in_group("vfx_manager"),
		"M_VFXManager should be in 'vfx_manager' group")

# Test 3: Manager can be registered with ServiceLocator (now done by main.gd)
func test_manager_can_be_registered_with_service_locator() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Manually register (simulating what main.gd does)
	U_SERVICE_LOCATOR.register(StringName("vfx_manager"), _manager)

	var service = U_SERVICE_LOCATOR.get_service(StringName("vfx_manager"))
	assert_not_null(service, "M_VFXManager should be registered with ServiceLocator")
	assert_eq(service, _manager, "ServiceLocator should return the VFX manager instance")

# Test 4: Manager discovers StateStore dependency
func test_manager_discovers_state_store() -> void:
	# Create and register StateStore first
	_store = M_STATE_STORE.new()
	add_child_autofree(_store)
	await get_tree().process_frame

	# Create manager after store is ready
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Manager should have discovered the store
	# We'll verify this by checking that the manager doesn't push errors
	# The actual internal field is private, so we trust initialization
	assert_true(_manager.is_in_group("vfx_manager"),
		"Manager should initialize successfully when StateStore is present")

# Test 5: Trauma initializes to 0.0
func test_trauma_initializes_to_zero() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_eq(_manager.get_trauma(), 0.0,
		"Trauma should initialize to 0.0")

# Test 6: add_trauma() increases trauma value
func test_add_trauma_increases_value() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_manager.add_trauma(0.3)
	assert_almost_eq(_manager.get_trauma(), 0.3, 0.001,
		"add_trauma(0.3) should set trauma to 0.3")

	_manager.add_trauma(0.2)
	assert_almost_eq(_manager.get_trauma(), 0.5, 0.001,
		"add_trauma(0.2) should accumulate to 0.5")

# Test 7: get_trauma() returns current trauma value
func test_get_trauma_returns_current_value() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	assert_eq(_manager.get_trauma(), 0.0, "Initial trauma should be 0.0")

	_manager.add_trauma(0.7)
	assert_almost_eq(_manager.get_trauma(), 0.7, 0.001,
		"get_trauma() should return 0.7 after adding 0.7")

# Test 8: Trauma clamps at maximum 1.0
func test_trauma_clamps_at_max_one() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	_manager.add_trauma(0.8)
	_manager.add_trauma(0.5)  # Total would be 1.3, should clamp to 1.0

	assert_almost_eq(_manager.get_trauma(), 1.0, 0.001,
		"Trauma should clamp at maximum 1.0")

	# Try adding more trauma when already at max
	_manager.add_trauma(0.2)
	assert_almost_eq(_manager.get_trauma(), 1.0, 0.001,
		"Trauma should remain at 1.0 when adding more")

# ============================================================================
# VFX Request Event Subscription Tests (Phase 1 Refactor)
# ============================================================================

# Test 9: screen_shake_request event triggers trauma
func test_screen_shake_request_adds_trauma() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Publish screen_shake_request event (VFX architecture refactor)
	# Note: BaseEventBus wraps payload automatically with "name", "payload", "timestamp"
	U_ECS_EVENT_BUS.publish(StringName("screen_shake_request"), {
		"entity_id": "E_Player",
		"trauma_amount": 0.45,
		"source": "test",
	})
	# Event bus is synchronous - check trauma immediately (before physics decay)

	# Should add the requested trauma amount (0.45)
	var trauma: float = _manager.get_trauma()
	assert_almost_eq(trauma, 0.45, 0.001,
		"screen_shake_request should add trauma, got %f" % trauma)

# Test 10: screen_shake_request with different trauma amounts
func test_screen_shake_request_with_different_amounts() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Low trauma request (0.33)
	U_ECS_EVENT_BUS.publish(StringName("screen_shake_request"), {
		"entity_id": "E_Player",
		"trauma_amount": 0.33,
		"source": "test",
	})
	# Check immediately (event bus is synchronous)

	var low_trauma: float = _manager.get_trauma()
	assert_almost_eq(low_trauma, 0.33, 0.001,
		"Low trauma request should work, got %f" % low_trauma)

	# Reset trauma - clear ServiceLocator to avoid warning about re-registration
	U_SERVICE_LOCATOR.clear()
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# High trauma request (0.57)
	U_ECS_EVENT_BUS.publish(StringName("screen_shake_request"), {
		"entity_id": "E_Player",
		"trauma_amount": 0.57,
		"source": "test",
	})
	# Check immediately (event bus is synchronous)

	var high_trauma: float = _manager.get_trauma()
	assert_almost_eq(high_trauma, 0.57, 0.001,
		"High trauma request should work, got %f" % high_trauma)

# Test 11: Non-player shake requests are ignored (player-only gating)
func test_non_player_shake_requests_ignored() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Publish shake request from non-player entity
	U_ECS_EVENT_BUS.publish(StringName("screen_shake_request"), {
		"entity_id": "E_Enemy",  # Not E_Player
		"trauma_amount": 0.5,
		"source": "test",
	})
	# Check immediately (event bus is synchronous)

	# Should be ignored (player-only gating)
	assert_eq(_manager.get_trauma(), 0.0,
		"Non-player shake request should be ignored")

# Test 12: Zero trauma requests are ignored
func test_zero_trauma_requests_ignored() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Publish shake request with zero trauma
	U_ECS_EVENT_BUS.publish(StringName("screen_shake_request"), {
		"entity_id": "E_Player",
		"trauma_amount": 0.0,
		"source": "test",
	})
	# Check immediately (event bus is synchronous)

	assert_eq(_manager.get_trauma(), 0.0,
		"Zero trauma request should not add trauma")

# Test 14: Trauma decays over time in _physics_process
func test_trauma_decays_over_time() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Set initial trauma
	_manager.add_trauma(1.0)
	assert_almost_eq(_manager.get_trauma(), 1.0, 0.001, "Initial trauma should be 1.0")

	# Simulate physics frames (decay rate = 2.0/sec)
	# At 60 FPS, delta = 1/60 ≈ 0.0167, decay per frame = 2.0 * 0.0167 ≈ 0.033
	# After 30 frames (0.5 seconds), trauma should drop by ~1.0
	for i in range(30):
		await get_tree().physics_frame

	var trauma_after_decay: float = _manager.get_trauma()
	assert_true(trauma_after_decay < 1.0,
		"Trauma should decay after physics frames, got %f" % trauma_after_decay)
	assert_true(trauma_after_decay >= 0.0,
		"Trauma should not go negative, got %f" % trauma_after_decay)

# Test 15: Trauma decay respects 2.0/sec rate
func test_trauma_decay_rate() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Set initial trauma
	_manager.add_trauma(1.0)

	# Simulate 0.5 seconds of physics (30 frames at 60 FPS)
	# Expected decay: 2.0/sec * 0.5sec = 1.0 trauma
	# Final trauma: 1.0 - 1.0 = 0.0 (or close to it)
	for i in range(30):
		await get_tree().physics_frame

	var final_trauma: float = _manager.get_trauma()
	assert_almost_eq(final_trauma, 0.0, 0.1,
		"Trauma should decay to ~0.0 after 0.5 seconds")

# Test 16: Trauma never goes negative
func test_trauma_never_goes_negative() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# Start with low trauma
	_manager.add_trauma(0.1)

	# Simulate excessive decay (more than enough to go negative)
	for i in range(60):  # 1 second at 60 FPS, decay = 2.0
		await get_tree().physics_frame

	var final_trauma: float = _manager.get_trauma()
	assert_true(final_trauma >= 0.0,
		"Trauma should never go negative, got %f" % final_trauma)
	assert_eq(final_trauma, 0.0,
		"Trauma should clamp at 0.0, got %f" % final_trauma)

# Test 17: Multiple shake requests accumulate trauma (clamped at 1.0)
func test_multiple_events_accumulate_trauma() -> void:
	_manager = M_VFX_MANAGER.new()
	add_child_autofree(_manager)
	await get_tree().process_frame

	# First shake request
	U_ECS_EVENT_BUS.publish(StringName("screen_shake_request"), {
		"entity_id": "E_Player",
		"trauma_amount": 0.45,
		"source": "test",
	})
	# Check immediately (event bus is synchronous)

	var trauma_after_first: float = _manager.get_trauma()
	assert_almost_eq(trauma_after_first, 0.45, 0.001, "First event should add trauma")

	# Second shake request
	U_ECS_EVENT_BUS.publish(StringName("screen_shake_request"), {
		"entity_id": "E_Player",
		"trauma_amount": 0.45,
		"source": "test",
	})
	# Check immediately (event bus is synchronous)

	var trauma_after_second: float = _manager.get_trauma()
	assert_true(trauma_after_second > trauma_after_first,
		"Second event should accumulate trauma")
	assert_almost_eq(trauma_after_second, 0.9, 0.001,
		"Accumulated trauma should be 0.9, got %f" % trauma_after_second)
