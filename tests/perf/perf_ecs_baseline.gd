extends SceneTree

const ENTITY_COUNT := 100
const FRAMES_TO_SIMULATE := 120

const ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const ECS_SYSTEM := preload("res://scripts/ecs/ecs_system.gd")
const ECS_COMPONENT := preload("res://scripts/ecs/ecs_component.gd")

const S_INPUT := preload("res://scripts/ecs/systems/s_input_system.gd")
const S_MOVEMENT := preload("res://scripts/ecs/systems/s_movement_system.gd")
const S_JUMP := preload("res://scripts/ecs/systems/s_jump_system.gd")
const S_GRAVITY := preload("res://scripts/ecs/systems/s_gravity_system.gd")
const S_FLOATING := preload("res://scripts/ecs/systems/s_floating_system.gd")
const S_ROTATE := preload("res://scripts/ecs/systems/s_rotate_to_input_system.gd")
const S_ALIGN := preload("res://scripts/ecs/systems/s_align_with_surface_system.gd")
const S_LANDING := preload("res://scripts/ecs/systems/s_landing_indicator_system.gd")

const C_INPUT := preload("res://scripts/ecs/components/c_input_component.gd")
const C_MOVEMENT := preload("res://scripts/ecs/components/c_movement_component.gd")
const C_JUMP := preload("res://scripts/ecs/components/c_jump_component.gd")
const C_FLOATING := preload("res://scripts/ecs/components/c_floating_component.gd")
const C_ROTATE := preload("res://scripts/ecs/components/c_rotate_to_input_component.gd")
const C_ALIGN := preload("res://scripts/ecs/components/c_align_with_surface_component.gd")
const C_LANDING := preload("res://scripts/ecs/components/c_landing_indicator_component.gd")

const RS_MOVEMENT := preload("res://scripts/ecs/resources/rs_movement_settings.gd")
const RS_JUMP := preload("res://scripts/ecs/resources/rs_jump_settings.gd")
const RS_FLOATING := preload("res://scripts/ecs/resources/rs_floating_settings.gd")
const RS_ROTATE := preload("res://scripts/ecs/resources/rs_rotate_to_input_settings.gd")
const RS_ALIGN := preload("res://scripts/ecs/resources/rs_align_settings.gd")
const RS_LANDING := preload("res://scripts/ecs/resources/rs_landing_indicator_settings.gd")

var _origin: Node
var _manager: M_ECSManager
var _systems: Array[ECSSystem] = []

func _initialize() -> void:
	call_deferred("_run_baseline")

func _run_baseline() -> void:
	_origin = Node.new()
	_origin.name = "PerfRoot"
	get_root().add_child(_origin)

	var setup_start_ms := Time.get_ticks_msec()

	_setup_camera()
	_setup_manager_and_systems()
	_setup_entities()

	await process_frame
	await process_frame

	var setup_duration_ms := Time.get_ticks_msec() - setup_start_ms

	var measurements := _simulate_frames()
	_report_results(setup_duration_ms, measurements)
	quit()

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.name = "PerfCamera"
	camera.current = true
	camera.add_to_group("main_camera")
	_origin.add_child(camera)

func _setup_manager_and_systems() -> void:
	_manager = ECS_MANAGER.new()
	_manager.name = "M_ECSManager"
	_origin.add_child(_manager)

	var system_specs := [
		{"name": "S_InputSystem", "instance": S_INPUT.new()},
		{"name": "S_MovementSystem", "instance": S_MOVEMENT.new()},
		{"name": "S_JumpSystem", "instance": S_JUMP.new()},
		{"name": "S_GravitySystem", "instance": S_GRAVITY.new()},
		{"name": "S_FloatingSystem", "instance": S_FLOATING.new()},
		{"name": "S_RotateToInputSystem", "instance": S_ROTATE.new()},
		{"name": "S_AlignWithSurfaceSystem", "instance": S_ALIGN.new()},
		{"name": "S_LandingIndicatorSystem", "instance": S_LANDING.new()},
	]

	for spec in system_specs:
		var system: ECSSystem = spec["instance"]
		system.name = spec["name"]
		_systems.append(system)
		_manager.add_child(system)

func _setup_entities() -> void:
	var entities_root := Node.new()
	entities_root.name = "Entities"
	_origin.add_child(entities_root)

	for index in range(ENTITY_COUNT):
		var entity := Node3D.new()
		entity.name = "E_Perf_%03d" % index
		entities_root.add_child(entity)

		var body := CharacterBody3D.new()
		body.name = "Body"
		entity.add_child(body)

		var visual := Node3D.new()
		visual.name = "Visual"
		entity.add_child(visual)

		var ray_root := Node3D.new()
		ray_root.name = "Raycasts"
		entity.add_child(ray_root)

		var origin_marker := Node3D.new()
		origin_marker.name = "OriginMarker"
		entity.add_child(origin_marker)

		var landing_marker := Node3D.new()
		landing_marker.name = "LandingMarker"
		entity.add_child(landing_marker)

		var components_root := Node.new()
		components_root.name = "Components"
		entity.add_child(components_root)

		var input_component: C_InputComponent = C_INPUT.new()
		input_component.name = "C_InputComponent"
		components_root.add_child(input_component)

		var movement_component: C_MovementComponent = C_MOVEMENT.new()
		movement_component.name = "C_MovementComponent"
		movement_component.settings = RS_MOVEMENT.new()
		components_root.add_child(movement_component)

		var jump_component: C_JumpComponent = C_JUMP.new()
		jump_component.name = "C_JumpComponent"
		jump_component.settings = RS_JUMP.new()
		components_root.add_child(jump_component)

		var floating_component: C_FloatingComponent = C_FLOATING.new()
		floating_component.name = "C_FloatingComponent"
		floating_component.settings = RS_FLOATING.new()
		components_root.add_child(floating_component)

		var rotate_component: C_RotateToInputComponent = C_ROTATE.new()
		rotate_component.name = "C_RotateToInputComponent"
		rotate_component.settings = RS_ROTATE.new()
		components_root.add_child(rotate_component)

		var align_component: C_AlignWithSurfaceComponent = C_ALIGN.new()
		align_component.name = "C_AlignWithSurfaceComponent"
		align_component.settings = RS_ALIGN.new()
		components_root.add_child(align_component)

		var landing_component: C_LandingIndicatorComponent = C_LANDING.new()
		landing_component.name = "C_LandingIndicatorComponent"
		landing_component.settings = RS_LANDING.new()
		components_root.add_child(landing_component)

		jump_component.character_body_path = jump_component.get_path_to(body)

		floating_component.character_body_path = floating_component.get_path_to(body)
		floating_component.raycast_root_path = floating_component.get_path_to(ray_root)

		rotate_component.target_node_path = rotate_component.get_path_to(visual)

		align_component.character_body_path = align_component.get_path_to(body)
		align_component.visual_alignment_path = align_component.get_path_to(visual)

		landing_component.character_body_path = landing_component.get_path_to(body)
		landing_component.origin_marker_path = landing_component.get_path_to(origin_marker)
		landing_component.landing_marker_path = landing_component.get_path_to(landing_marker)

func _simulate_frames() -> Dictionary:
	var total_time_usec: int = 0
	var system_time_totals: Dictionary = {}

	for system in _systems:
		system_time_totals[system.name] = 0

	for _i in range(FRAMES_TO_SIMULATE):
		var frame_start := Time.get_ticks_usec()
		for system in _systems:
			var system_start := Time.get_ticks_usec()
			system._physics_process(0.016)
			system_time_totals[system.name] += Time.get_ticks_usec() - system_start
		total_time_usec += Time.get_ticks_usec() - frame_start

	return {
		"total_time_usec": total_time_usec,
		"system_time_totals": system_time_totals,
	}

func _report_results(setup_duration_ms: int, measurements: Dictionary) -> void:
	var total_time_usec: int = measurements["total_time_usec"]
	var system_time_totals: Dictionary = measurements["system_time_totals"]

	var avg_frame_time_ms: float = float(total_time_usec) / float(FRAMES_TO_SIMULATE) / 1000.0

	print("--- ECS Baseline Performance ---")
	print("Entities: %d | Components per entity: 7" % ENTITY_COUNT)
	print("Setup time (ms): %d" % setup_duration_ms)
	print("Simulated frames: %d" % FRAMES_TO_SIMULATE)
	print("Average frame time (ms): %.4f" % avg_frame_time_ms)

	print("Average system time per frame (ms):")
	for system_name in system_time_totals.keys():
		var avg_ms := float(system_time_totals[system_name]) / float(FRAMES_TO_SIMULATE) / 1000.0
		print("  %s: %.4f" % [system_name, avg_ms])
