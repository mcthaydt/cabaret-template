extends BaseTest

## Tests for SystemPhase enum and phase-aware system ordering in M_ECSManager.

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const BASE_SYSTEM := preload("res://scripts/ecs/base_ecs_system.gd")

## Inner class: a test system that logs its label on process_tick
## and declares a configurable phase and priority.
class PhasedSystem extends BaseECSSystem:
	var label: String = ""
	var log: Array = []
	var _test_phase: int = BaseECSSystem.SystemPhase.PHYSICS_SOLVE

	func configure_for_test(name: String, priority: int, phase: int, target_log: Array) -> void:
		label = name
		execution_priority = priority
		_test_phase = phase
		log = target_log

	func process_tick(_delta: float) -> void:
		if log == null:
			return
		log.append(label)

	func get_phase() -> int:
		return _test_phase

## Test 0: BaseECSSystem.get_phase() defaults to PHYSICS_SOLVE.
func test_get_phase_defaults_to_physics_solve() -> void:
	var system := BASE_SYSTEM.new()
	autofree(system)
	assert_eq(system.get_phase(), BASE_SYSTEM.SystemPhase.PHYSICS_SOLVE,
		"Default phase should be PHYSICS_SOLVE")

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
	camera_system.configure_for_test("camera", 0, BASE_SYSTEM.SystemPhase.CAMERA, execution_log)

	var physics_system := PhasedSystem.new()
	autofree(physics_system)
	physics_system.configure_for_test("physics", 0, BASE_SYSTEM.SystemPhase.PHYSICS_SOLVE, execution_log)

	var pre_physics_system := PhasedSystem.new()
	autofree(pre_physics_system)
	pre_physics_system.configure_for_test("pre_physics", 0, BASE_SYSTEM.SystemPhase.PRE_PHYSICS, execution_log)

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
	low_system.configure_for_test("low", -10, BASE_SYSTEM.SystemPhase.PHYSICS_SOLVE, execution_log)

	var mid_system := PhasedSystem.new()
	autofree(mid_system)
	mid_system.configure_for_test("mid", 0, BASE_SYSTEM.SystemPhase.PHYSICS_SOLVE, execution_log)

	var high_system := PhasedSystem.new()
	autofree(high_system)
	high_system.configure_for_test("high", 50, BASE_SYSTEM.SystemPhase.PHYSICS_SOLVE, execution_log)

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
	camera_system.configure_for_test("camera", -100, BASE_SYSTEM.SystemPhase.CAMERA, execution_log)

	# PHYSICS_SOLVE system with very high priority (1000)
	var physics_system := PhasedSystem.new()
	autofree(physics_system)
	physics_system.configure_for_test("physics", 1000, BASE_SYSTEM.SystemPhase.PHYSICS_SOLVE, execution_log)

	manager.register_system(camera_system)
	manager.register_system(physics_system)

	manager._physics_process(0.016)

	assert_eq(execution_log, ["physics", "camera"],
		"CAMERA phase must always execute after PHYSICS_SOLVE, regardless of priority")

## Test 4: Phase ordering preserves the production priority hierarchy.
## Simulates production system ordering: AI detection (-12), AI behavior (-10),
## move target (-5) in PRE_PHYSICS; input (0) in INPUT; movement (0) and
## jump (0) in PHYSICS_SOLVE; character state (0) in POST_PHYSICS;
## camera (0) in CAMERA; health (200) in VFX.
func test_phase_order_preserves_production_priority_ordering() -> void:
	var manager := ECS_MANAGER.new()
	add_child(manager)
	autofree(manager)

	var execution_log: Array = []

	# PRE_PHYSICS systems (currently negative priorities)
	var ai_detection := PhasedSystem.new()
	autofree(ai_detection)
	ai_detection.configure_for_test("ai_detection", -12, BASE_SYSTEM.SystemPhase.PRE_PHYSICS, execution_log)

	var ai_behavior := PhasedSystem.new()
	autofree(ai_behavior)
	ai_behavior.configure_for_test("ai_behavior", -10, BASE_SYSTEM.SystemPhase.PRE_PHYSICS, execution_log)

	# INPUT system
	var input_sys := PhasedSystem.new()
	autofree(input_sys)
	input_sys.configure_for_test("input", 0, BASE_SYSTEM.SystemPhase.INPUT, execution_log)

	# PHYSICS_SOLVE system
	var movement := PhasedSystem.new()
	autofree(movement)
	movement.configure_for_test("movement", 0, BASE_SYSTEM.SystemPhase.PHYSICS_SOLVE, execution_log)

	# POST_PHYSICS system
	var char_state := PhasedSystem.new()
	autofree(char_state)
	char_state.configure_for_test("char_state", 0, BASE_SYSTEM.SystemPhase.POST_PHYSICS, execution_log)

	# CAMERA system
	var vcam := PhasedSystem.new()
	autofree(vcam)
	vcam.configure_for_test("vcam", 0, BASE_SYSTEM.SystemPhase.CAMERA, execution_log)

	# VFX system
	var health := PhasedSystem.new()
	autofree(health)
	health.configure_for_test("health", 200, BASE_SYSTEM.SystemPhase.VFX, execution_log)

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