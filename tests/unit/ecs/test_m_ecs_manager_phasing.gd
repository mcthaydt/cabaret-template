extends BaseTest

## Tests for SystemPhase enum and phase-aware system ordering in M_ECSManager.
##
## Commit 1 (RED): These tests verify the SystemPhase behavior that does
## not yet exist. They will fail until Commit 2 adds the enum and Commit 3
## refactors the sort.

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const BASE_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")

## Inner class: a test system that logs its label on process_tick
## and declares a configurable phase and priority.
class PhasedSystem extends BaseECSSystem:
	var label: String = ""
	var log: Array = []

	func configure_for_test(name: String, priority: int, phase: int, target_log: Array) -> void:
		label = name
		execution_priority = priority
		_phase = phase
		log = target_log

	func process_tick(_delta: float) -> void:
		if log == null:
			return
		log.append(label)

	## Stores the phase for testing. Will be replaced by get_phase() override
	## once SystemPhase is added to BaseECSSystem.
	var _phase: int = 0

	func get_phase() -> int:
		return _phase

## Test 1: Systems registered in random order execute in strict phase order.
## A PRE_PHYSICS system runs before INPUT, which runs before PHYSICS_SOLVE,
## regardless of registration order.
func test_systems_execute_in_strict_phase_order() -> void:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var execution_log: Array = []

	var camera_system := PhasedSystem.new()
	autofree(camera_system)
	camera_system.configure_for_test("camera", 0, 4, execution_log)  # CAMERA

	var physics_system := PhasedSystem.new()
	autofree(physics_system)
	physics_system.configure_for_test("physics", 0, 2, execution_log)  # PHYSICS_SOLVE

	var pre_physics_system := PhasedSystem.new()
	autofree(pre_physics_system)
	pre_physics_system.configure_for_test("pre_physics", 0, 0, execution_log)  # PRE_PHYSICS

	# Register in non-phase order: camera first, then physics, then pre_physics
	manager.register_system(camera_system)
	manager.register_system(physics_system)
	manager.register_system(pre_physics_system)

	manager._physics_process(0.016)

	assert_eq(execution_log, ["pre_physics", "physics", "camera"],
		"Systems should execute in phase order regardless of registration order")

## Test 2: Within the same phase, systems execute by execution_priority.
func test_within_phase_systems_sort_by_execution_priority() -> void:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var execution_log: Array = []

	var low_system := PhasedSystem.new()
	autofree(low_system)
	low_system.configure_for_test("low", -10, 2, execution_log)  # PHYSICS_SOLVE, priority -10

	var mid_system := PhasedSystem.new()
	autofree(mid_system)
	mid_system.configure_for_test("mid", 0, 2, execution_log)  # PHYSICS_SOLVE, priority 0

	var high_system := PhasedSystem.new()
	autofree(high_system)
	high_system.configure_for_test("high", 50, 2, execution_log)  # PHYSICS_SOLVE, priority 50

	# Register in reverse priority order
	manager.register_system(high_system)
	manager.register_system(low_system)
	manager.register_system(mid_system)

	manager._physics_process(0.016)

	assert_eq(execution_log, ["low", "mid", "high"],
		"Within the same phase, systems should execute in execution_priority order")

## Test 3: A CAMERA system always runs after PHYSICS_SOLVE regardless of
## execution_priority values. This verifies phase takes precedence over priority.
func test_camera_always_runs_after_physics_solve() -> void:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var execution_log: Array = []

	# CAMERA system with very low priority (-100)
	var camera_system := PhasedSystem.new()
	autofree(camera_system)
	camera_system.configure_for_test("camera", -100, 4, execution_log)  # CAMERA

	# PHYSICS_SOLVE system with very high priority (1000)
	var physics_system := PhasedSystem.new()
	autofree(physics_system)
	physics_system.configure_for_test("physics", 1000, 2, execution_log)  # PHYSICS_SOLVE

	manager.register_system(camera_system)
	manager.register_system(physics_system)

	manager._physics_process(0.016)

	assert_eq(execution_log, ["physics", "camera"],
		"CAMERA phase must always execute after PHYSICS_SOLVE, regardless of priority")

## Test 4: Phase ordering preserves the production priority hierarchy.
## Simulates production system ordering: AI detection (-12), AI behavior (-10),
## move target (-5) in PRE_PHYSICS; input (0) in INPUT; movement (0) and
# jump (0) in PHYSICS_SOLVE; character state (0) in POST_PHYSICS;
## camera (0) in CAMERA; health (200) in VFX.
func test_phase_order_preserves_production_priority_ordering() -> void:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var execution_log: Array = []

	# PRE_PHYSICS systems (currently negative priorities)
	var ai_detection := PhasedSystem.new()
	autofree(ai_detection)
	ai_detection.configure_for_test("ai_detection", -12, 0, execution_log)  # PRE_PHYSICS

	var ai_behavior := PhasedSystem.new()
	autofree(ai_behavior)
	ai_behavior.configure_for_test("ai_behavior", -10, 0, execution_log)  # PRE_PHYSICS

	# INPUT system
	var input_sys := PhasedSystem.new()
	autofree(input_sys)
	input_sys.configure_for_test("input", 0, 1, execution_log)  # INPUT

	# PHYSICS_SOLVE system
	var movement := PhasedSystem.new()
	autofree(movement)
	movement.configure_for_test("movement", 0, 2, execution_log)  # PHYSICS_SOLVE

	# POST_PHYSICS system
	var char_state := PhasedSystem.new()
	autofree(char_state)
	char_state.configure_for_test("char_state", 0, 3, execution_log)  # POST_PHYSICS

	# CAMERA system
	var vcam := PhasedSystem.new()
	autofree(vcam)
	vcam.configure_for_test("vcam", 0, 4, execution_log)  # CAMERA

	# VFX system
	var health := PhasedSystem.new()
	autofree(health)
	health.configure_for_test("health", 200, 5, execution_log)  # VFX

	# Register in shuffled order
	manager.register_system(health)
	manager.register_system(ai_detection)
	manager.register_system(vcam)
	manager.register_system(input_sys)
	manager.register_system(movement)
	manager.register_system(ai_behavior)
	manager.register_system(char_state)

	manager._physics_process(0.016)

	assert_eq(execution_log, [
		"ai_detection", "ai_behavior",
		"input",
		"movement",
		"char_state",
		"vcam",
		"health"
	], "Phase ordering should preserve production priority hierarchy")