extends RefCounted
class_name U_SceneBuilder

## Utility for programmatically building gameplay scene templates
##
## This utility helps create .tscn files with proper structure for area transitions.
## Builds scenes with ECS architecture (M_ECSManager, Systems, Entities, Environment).
##
## Usage:
## ```
## var builder := U_SceneBuilder.new()
## builder.create_area_scene("exterior", "door_to_house", "interior_house", "entrance_from_exterior", "exit_from_house")
## ```

const M_ECS_MANAGER := preload("res://scripts/managers/m_ecs_manager.gd")
const C_SCENE_TRIGGER_COMPONENT := preload("res://scripts/ecs/components/c_scene_trigger_component.gd")

# Scene structure scripts
const SCENE_OBJECTS_GROUP := preload("res://scripts/scene_structure/scene_objects_group.gd")
const ENVIRONMENT_GROUP := preload("res://scripts/scene_structure/environment_group.gd")
const SYSTEMS_GROUP := preload("res://scripts/scene_structure/systems_group.gd")
const SYSTEMS_CORE_GROUP := preload("res://scripts/scene_structure/systems_core_group.gd")
const SYSTEMS_PHYSICS_GROUP := preload("res://scripts/scene_structure/systems_physics_group.gd")
const SYSTEMS_MOVEMENT_GROUP := preload("res://scripts/scene_structure/systems_movement_group.gd")
const SYSTEMS_FEEDBACK_GROUP := preload("res://scripts/scene_structure/systems_feedback_group.gd")
const MANAGERS_GROUP := preload("res://scripts/scene_structure/managers_group.gd")
const ENTITIES_GROUP := preload("res://scripts/scene_structure/entities_group.gd")
const MAIN_ROOT_NODE := preload("res://scripts/scene_structure/main_root_node.gd")

# System scripts
const S_INPUT_SYSTEM := preload("res://scripts/ecs/systems/s_input_system.gd")
const S_PAUSE_SYSTEM := preload("res://scripts/ecs/systems/s_pause_system.gd")
const S_GRAVITY_SYSTEM := preload("res://scripts/ecs/systems/s_gravity_system.gd")
const S_JUMP_SYSTEM := preload("res://scripts/ecs/systems/s_jump_system.gd")
const S_MOVEMENT_SYSTEM := preload("res://scripts/ecs/systems/s_movement_system.gd")
const S_FLOATING_SYSTEM := preload("res://scripts/ecs/systems/s_floating_system.gd")
const S_ROTATE_TO_INPUT_SYSTEM := preload("res://scripts/ecs/systems/s_rotate_to_input_system.gd")
const S_ALIGN_WITH_SURFACE_SYSTEM := preload("res://scripts/ecs/systems/s_align_with_surface_system.gd")
const S_LANDING_INDICATOR_SYSTEM := preload("res://scripts/ecs/systems/s_landing_indicator_system.gd")
const S_JUMP_PARTICLES_SYSTEM := preload("res://scripts/ecs/systems/s_jump_particles_system.gd")
const S_JUMP_SOUND_SYSTEM := preload("res://scripts/ecs/systems/s_jump_sound_system.gd")
const S_LANDING_PARTICLES_SYSTEM := preload("res://scripts/ecs/systems/s_landing_particles_system.gd")

# Templates
const PLAYER_TEMPLATE := preload("res://templates/player_template.tscn")
const CAMERA_TEMPLATE := preload("res://templates/camera_template.tscn")

# Resources
const JUMP_PARTICLES_SETTINGS := preload("res://resources/settings/jump_particles_default.tres")
const LANDING_PARTICLES_SETTINGS := preload("res://resources/settings/landing_particles_default.tres")

## Create a gameplay area scene with door trigger and spawn marker
##
## Returns true if scene was saved successfully, false otherwise.
static func create_area_scene(
	scene_name: String,
	door_id: StringName,
	target_scene_id: StringName,
	target_spawn_point: StringName,
	this_scene_spawn_marker: StringName,
	output_path: String
) -> bool:
	# Create root node
	var root := Node3D.new()
	root.name = "Main"
	root.set_script(MAIN_ROOT_NODE)

	# Add SceneObjects
	var scene_objects := _create_scene_objects()
	root.add_child(scene_objects)
	scene_objects.owner = root
	_set_children_owner(scene_objects, root)

	# Add Environment
	var environment := _create_environment()
	root.add_child(environment)
	environment.owner = root
	_set_children_owner(environment, root)

	# Add Systems
	var systems := _create_systems()
	root.add_child(systems)
	systems.owner = root
	_set_children_owner(systems, root)

	# Add Managers
	var managers := _create_managers()
	root.add_child(managers)
	managers.owner = root
	_set_children_owner(managers, root)

	# Add Entities (with door trigger and spawn marker)
	var entities := _create_entities(door_id, target_scene_id, target_spawn_point, this_scene_spawn_marker)
	root.add_child(entities)
	entities.owner = root
	_set_children_owner(entities, root)

	# Add HUD
	var hud_scene: PackedScene = load("res://scenes/ui/hud_overlay.tscn")
	if hud_scene != null:
		var hud := hud_scene.instantiate()
		root.add_child(hud)
		hud.owner = root

	# Pack scene
	var packed_scene := PackedScene.new()
	var pack_result: Error = packed_scene.pack(root)
	if pack_result != OK:
		push_error("U_SceneBuilder: Failed to pack scene '%s' (Error: %d)" % [scene_name, pack_result])
		root.queue_free()
		return false

	# Save scene
	var save_result: Error = ResourceSaver.save(packed_scene, output_path)
	if save_result != OK:
		push_error("U_SceneBuilder: Failed to save scene '%s' to '%s' (Error: %d)" % [scene_name, output_path, save_result])
		root.queue_free()
		return false

	# Clean up
	root.queue_free()

	print("U_SceneBuilder: Created scene '%s' at '%s'" % [scene_name, output_path])
	return true

## Create SceneObjects group with floor
static func _create_scene_objects() -> Node3D:
	var scene_objects := Node3D.new()
	scene_objects.name = "SceneObjects"
	scene_objects.set_script(SCENE_OBJECTS_GROUP)

	# Create floor
	var floor := CSGBox3D.new()
	floor.name = "SO_Floor"
	floor.transform = Transform3D(Basis.IDENTITY, Vector3(0, -2, 0))
	floor.use_collision = true
	floor.size = Vector3(25, 1, 25)

	# Create red material for floor
	var floor_material := StandardMaterial3D.new()
	floor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	floor_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	floor_material.albedo_color = Color(0.43137255, 0.15294118, 0.15294118, 1)
	floor.material_override = floor_material

	scene_objects.add_child(floor)

	return scene_objects

## Create Environment group
static func _create_environment() -> Node:
	var environment_node := Node.new()
	environment_node.name = "Enviroment"  # Keep original typo from gameplay_base.tscn
	environment_node.set_script(ENVIRONMENT_GROUP)

	# Create WorldEnvironment
	var world_env := WorldEnvironment.new()
	world_env.name = "Env_WorldEnvironment"

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.3019608, 0.60784316, 0.9019608, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world_env.environment = env

	environment_node.add_child(world_env)

	# Create DirectionalLight3D
	var light := DirectionalLight3D.new()
	light.name = "Env_DirectionalLight3D"
	light.transform = Transform3D(Basis(Vector3(1, 0, 0), Vector3(0, 0.9385653, 0.34510165), Vector3(0, -0.34510165, 0.9385653)), Vector3.ZERO)
	light.light_color = Color(0.56078434, 0.827451, 1, 1)
	light.light_energy = 12.026
	light.light_indirect_energy = 4.482

	environment_node.add_child(light)

	return environment_node

## Create Systems group with all subsystems
static func _create_systems() -> Node:
	var systems := Node.new()
	systems.name = "Systems"
	systems.set_script(SYSTEMS_GROUP)

	# Core systems
	var core := Node.new()
	core.name = "Core"
	core.set_script(SYSTEMS_CORE_GROUP)
	systems.add_child(core)

	var input_system := Node.new()
	input_system.name = "S_InputSystem"
	input_system.set_script(S_INPUT_SYSTEM)
	core.add_child(input_system)

	var pause_system := Node.new()
	pause_system.name = "S_PauseSystem"
	pause_system.set_script(S_PAUSE_SYSTEM)
	pause_system.set(&"execution_priority", 5)
	core.add_child(pause_system)

	# Physics systems
	var physics := Node.new()
	physics.name = "Physics"
	physics.set_script(SYSTEMS_PHYSICS_GROUP)
	systems.add_child(physics)

	var gravity_system := Node.new()
	gravity_system.name = "S_GravitySystem"
	gravity_system.set_script(S_GRAVITY_SYSTEM)
	gravity_system.set(&"execution_priority", 60)
	physics.add_child(gravity_system)

	var jump_system := Node.new()
	jump_system.name = "S_JumpSystem"
	jump_system.set_script(S_JUMP_SYSTEM)
	jump_system.set(&"execution_priority", 75)
	physics.add_child(jump_system)

	# Movement systems
	var movement := Node.new()
	movement.name = "Movement"
	movement.set_script(SYSTEMS_MOVEMENT_GROUP)
	systems.add_child(movement)

	var movement_system := Node.new()
	movement_system.name = "S_MovementSystem"
	movement_system.set_script(S_MOVEMENT_SYSTEM)
	movement_system.set(&"execution_priority", 50)
	movement.add_child(movement_system)

	var floating_system := Node.new()
	floating_system.name = "S_FloatingSystem"
	floating_system.set_script(S_FLOATING_SYSTEM)
	floating_system.set(&"execution_priority", 70)
	movement.add_child(floating_system)

	var rotate_system := Node.new()
	rotate_system.name = "S_RotateToInputSystem"
	rotate_system.set_script(S_ROTATE_TO_INPUT_SYSTEM)
	rotate_system.set(&"execution_priority", 80)
	movement.add_child(rotate_system)

	var align_system := Node.new()
	align_system.name = "S_AlignWithSurfaceSystem"
	align_system.set_script(S_ALIGN_WITH_SURFACE_SYSTEM)
	align_system.set(&"execution_priority", 90)
	movement.add_child(align_system)

	# Feedback systems
	var feedback := Node.new()
	feedback.name = "Feedback"
	feedback.set_script(SYSTEMS_FEEDBACK_GROUP)
	systems.add_child(feedback)

	var landing_indicator_system := Node.new()
	landing_indicator_system.name = "S_LandingIndicatorSystem"
	landing_indicator_system.set_script(S_LANDING_INDICATOR_SYSTEM)
	landing_indicator_system.set(&"execution_priority", 110)
	feedback.add_child(landing_indicator_system)

	var jump_particles_system := Node.new()
	jump_particles_system.name = "S_JumpParticlesSystem"
	jump_particles_system.set_script(S_JUMP_PARTICLES_SYSTEM)
	jump_particles_system.set(&"settings", JUMP_PARTICLES_SETTINGS)
	jump_particles_system.set(&"execution_priority", 120)
	feedback.add_child(jump_particles_system)

	var jump_sound_system := Node.new()
	jump_sound_system.name = "S_JumpSoundSystem"
	jump_sound_system.set_script(S_JUMP_SOUND_SYSTEM)
	jump_sound_system.set(&"execution_priority", 121)
	feedback.add_child(jump_sound_system)

	var landing_particles_system := Node.new()
	landing_particles_system.name = "S_LandingParticlesSystem"
	landing_particles_system.set_script(S_LANDING_PARTICLES_SYSTEM)
	landing_particles_system.set(&"settings", LANDING_PARTICLES_SETTINGS)
	landing_particles_system.set(&"execution_priority", 122)
	feedback.add_child(landing_particles_system)

	return systems

## Create Managers group with ECS manager
static func _create_managers() -> Node:
	var managers := Node.new()
	managers.name = "Managers"
	managers.set_script(MANAGERS_GROUP)

	var ecs_manager := Node.new()
	ecs_manager.name = "M_ECSManager"
	ecs_manager.set_script(M_ECS_MANAGER)
	managers.add_child(ecs_manager)

	return managers

## Create Entities group with player, camera, spawn points, and door trigger
static func _create_entities(
	door_id: StringName,
	target_scene_id: StringName,
	target_spawn_point: StringName,
	this_scene_spawn_marker: StringName
) -> Node:
	var entities := Node.new()
	entities.name = "Entities"
	entities.set_script(ENTITIES_GROUP)

	# Create spawn points group
	var spawn_points := Node3D.new()
	spawn_points.name = "E_SpawnPoints"
	spawn_points.set_script(ENTITIES_GROUP)
	entities.add_child(spawn_points)

	# Player spawn
	var player_spawn := Node3D.new()
	player_spawn.name = "E_PlayerSpawn"
	spawn_points.add_child(player_spawn)

	# Camera spawn
	var camera_spawn := Node3D.new()
	camera_spawn.name = "E_CameraSpawn"
	camera_spawn.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1, 4.5))
	spawn_points.add_child(camera_spawn)

	# This scene's spawn marker (for incoming transitions)
	var spawn_marker := Node3D.new()
	spawn_marker.name = String(this_scene_spawn_marker)
	spawn_marker.transform = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0))
	spawn_points.add_child(spawn_marker)

	# Add player
	var player := PLAYER_TEMPLATE.instantiate()
	player.transform = Transform3D(Basis.IDENTITY, Vector3(-0.15322971, 1.9733102, 0))
	entities.add_child(player)

	# Add camera
	var camera := CAMERA_TEMPLATE.instantiate()
	camera.transform = Transform3D(Basis.IDENTITY, Vector3(0, 1, 4.5))
	entities.add_child(camera)

	# Add door trigger
	var door_trigger := Node3D.new()
	door_trigger.name = "E_DoorTrigger"
	door_trigger.transform = Transform3D(Basis.IDENTITY, Vector3(5, 0, 0))  # Position to the side
	entities.add_child(door_trigger)

	# Add C_SceneTriggerComponent to door trigger
	var trigger_component := C_SCENE_TRIGGER_COMPONENT.new()
	trigger_component.name = "C_SceneTriggerComponent"
	trigger_component.door_id = door_id
	trigger_component.target_scene_id = target_scene_id
	trigger_component.target_spawn_point = target_spawn_point
	trigger_component.trigger_mode = C_SCENE_TRIGGER_COMPONENT.TriggerMode.AUTO
	trigger_component.cooldown_duration = 1.0
	door_trigger.add_child(trigger_component)

	return entities

## Recursively set owner for all children
static func _set_children_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		_set_children_owner(child, owner_node)
