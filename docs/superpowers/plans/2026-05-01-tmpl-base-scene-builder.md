# tmpl_base_scene Builder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a `U_TemplateBaseSceneBuilder` that programmatically generates `tmpl_base_scene.tscn`, replacing the hand-authored scene file.

**Architecture:** A `RefCounted` fluent builder following the `U_EditorBlockoutBuilder` pattern. A thin `@tool extends EditorScript` adapter calls it. The generated `.tscn` becomes the source of truth.

**Tech Stack:** Godot 4.6 GDScript, GUT test framework

---

### Task 1: Create the builder utility class

**Files:**
- Create: `scripts/core/utils/editors/u_template_base_scene_builder.gd`
- Create: `scripts/core/utils/editors/u_template_base_scene_builder.gd.uid` (empty placeholder for Godot UID)

- [ ] **Step 1: Write the builder class**

Create `scripts/core/utils/editors/u_template_base_scene_builder.gd`:

```gdscript
class_name U_TemplateBaseSceneBuilder
extends RefCounted

const ROOM_SIZE := 30.0
const THIN := 0.01

const PREFAB_PLAYER := preload("res://scenes/core/prefabs/prefab_player.tscn")
const PREFAB_CAMERA := preload("res://scenes/core/templates/tmpl_camera.tscn")
const GRID_TEXTURE := preload("res://assets/core/textures/prototype_grids/tex_texture_01.png")
const WALL_MATERIAL := preload("res://assets/core/materials/mat_wall_cutout.tres")
const WALL_CUTOUT_CONFIG := preload("res://resources/core/base_settings/gameplay/cfg_wall_cutout_config_default.tres")
const JUMP_PARTICLES_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_jump_particles_default.tres")
const LANDING_PARTICLES_SETTINGS := preload("res://resources/core/base_settings/gameplay/cfg_landing_particles_default.tres")
const WALL_VISIBILITY_CONFIG := preload("res://resources/core/base_settings/gameplay/cfg_wall_visibility_config_default.tres")

const MARKER_SCENE_OBJECTS := preload("res://scripts/core/scene_structure/marker_scene_objects_group.gd")
const MARKER_ENVIRONMENT := preload("res://scripts/core/scene_structure/marker_environment_group.gd")
const MARKER_SYSTEMS := preload("res://scripts/core/scene_structure/marker_systems_group.gd")
const MARKER_SYSTEMS_CORE := preload("res://scripts/core/scene_structure/marker_systems_core_group.gd")
const MARKER_SYSTEMS_PHYSICS := preload("res://scripts/core/scene_structure/marker_systems_physics_group.gd")
const MARKER_SYSTEMS_MOVEMENT := preload("res://scripts/core/scene_structure/marker_systems_movement_group.gd")
const MARKER_SYSTEMS_FEEDBACK := preload("res://scripts/core/scene_structure/marker_systems_feedback_group.gd")
const MARKER_MANAGERS := preload("res://scripts/core/scene_structure/marker_managers_group.gd")
const MARKER_ENTITIES := preload("res://scripts/core/scene_structure/marker_entities_group.gd")
const MARKER_SPAWN_POINTS := preload("res://scripts/core/scene_structure/marker_spawn_points_group.gd")

const BASE_ECS_ENTITY_SCRIPT := preload("res://scripts/core/ecs/base_ecs_entity.gd")
const ROOM_FADE_COMPONENT_SCRIPT := preload("res://scripts/core/ecs/components/c_room_fade_group_component.gd")

const ROOT_GAME_SCRIPT := preload("res://scripts/core/root.gd")

var _root: Node3D = null

func create_root() -> U_TemplateBaseSceneBuilder:
	var node := Node3D.new()
	node.name = "GameplayRoot"
	node.set_script(ROOT_GAME_SCRIPT)
	_root = node
	return self

func build_scene_objects() -> U_TemplateBaseSceneBuilder:
	var group := Node3D.new()
	group.name = "SceneObjects"
	group.set_script(MARKER_SCENE_OBJECTS)
	_root.add_child(group)

	_add_floor(group)
	_add_ceiling(group)
	_add_wall(group, "SO_Wall_West", Vector3(-15, 15, 0), Vector3(THIN, ROOM_SIZE, ROOM_SIZE), &"wall_west", Vector3(-1, 0, 0))
	_add_wall(group, "SO_Wall_East", Vector3(15, 15, 0), Vector3(THIN, ROOM_SIZE, ROOM_SIZE), &"wall_east", Vector3(1, 0, 0))
	_add_wall(group, "SO_Wall_North", Vector3(0, 15, -15), Vector3(ROOM_SIZE, ROOM_SIZE, THIN), &"wall_north")
	_add_wall(group, "SO_Wall_South", Vector3(0, 15, 15), Vector3(ROOM_SIZE, ROOM_SIZE, THIN), &"wall_south", Vector3(0, 0, 1))
	return self

func build_environment() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Environment"
	group.set_script(MARKER_ENVIRONMENT)
	_root.add_child(group)

	var world_env := WorldEnvironment.new()
	world_env.name = "Env_WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	world_env.environment = env
	group.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.name = "Env_DirectionalLight3D"
	light.light_color = Color(0.56078434, 0.827451, 1, 1)
	light.light_energy = 1.5
	light.light_indirect_energy = 0.0
	group.add_child(light)
	return self

func build_systems() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Systems"
	group.set_script(MARKER_SYSTEMS)
	_root.add_child(group)

	_add_core_systems(group)
	_add_physics_systems(group)
	_add_movement_systems(group)
	_add_feedback_systems(group)
	return self

func build_managers() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Managers"
	group.set_script(MARKER_MANAGERS)
	_root.add_child(group)

	var ecs_manager := Node.new()
	ecs_manager.name = "M_ECSManager"
	const ECS_MANAGER_SCRIPT := preload("res://scripts/core/managers/m_ecs_manager.gd")
	ecs_manager.set_script(ECS_MANAGER_SCRIPT)
	group.add_child(ecs_manager)
	return self

func build_entities() -> U_TemplateBaseSceneBuilder:
	var group := Node.new()
	group.name = "Entities"
	group.set_script(MARKER_ENTITIES)
	_root.add_child(group)

	var player := PREFAB_PLAYER.instantiate()
	player.name = "E_Player"
	group.add_child(player)

	var camera := PREFAB_CAMERA.instantiate()
	camera.name = "E_CameraRoot"
	group.add_child(camera)

	var spawn_points := Node3D.new()
	spawn_points.name = "SpawnPoints"
	spawn_points.set_script(MARKER_SPAWN_POINTS)
	group.add_child(spawn_points)
	return self

func save(path: String) -> bool:
	if _root == null:
		push_error("U_TemplateBaseSceneBuilder: save() called before create_root()")
		return false
	_set_owner_recursive(_root, _root)
	var packed := PackedScene.new()
	var pack_result := packed.pack(_root)
	if pack_result != OK:
		push_error("U_TemplateBaseSceneBuilder: pack() failed with code %d" % pack_result)
		return false
	var save_result := ResourceSaver.save(packed, path)
	if save_result != OK:
		push_error("U_TemplateBaseSceneBuilder: ResourceSaver.save() failed with code %d" % save_result)
		return false
	return true

func build() -> Node3D:
	if _root == null:
		push_error("U_TemplateBaseSceneBuilder: build() called before create_root()")
		return null
	return _root

func _add_floor(parent: Node3D) -> void:
	var box := CSGBox3D.new()
	box.name = "SO_Floor"
	box.use_collision = true
	box.size = Vector3(ROOM_SIZE, THIN, ROOM_SIZE)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = GRID_TEXTURE
	box.material = mat
	parent.add_child(box)

func _add_ceiling(parent: Node3D) -> void:
	var box := CSGBox3D.new()
	box.name = "SO_Ceiling"
	box.position = Vector3(0, ROOM_SIZE, 0)
	box.use_collision = true
	box.size = Vector3(ROOM_SIZE, THIN, ROOM_SIZE)
	box.material = WALL_MATERIAL
	parent.add_child(box)

func _add_wall(parent: Node3D, name_: String, position: Vector3, size: Vector3, entity_id: StringName, fade_normal: Vector3 = Vector3()) -> void:
	var box := CSGBox3D.new()
	box.name = name_
	box.position = position
	box.use_collision = true
	box.size = size
	box.material = WALL_MATERIAL
	box.set_script(BASE_ECS_ENTITY_SCRIPT)
	box.entity_id = entity_id
	box.tags = [&"room_fade_group"]
	parent.add_child(box)

	var component := Node.new()
	component.name = "C_RoomFadeGroupComponent"
	component.set_script(ROOM_FADE_COMPONENT_SCRIPT)
	component.group_tag = entity_id
	if fade_normal != Vector3():
		component.fade_normal = fade_normal
	box.add_child(component)

func _add_core_systems(parent: Node) -> void:
	var core := Node.new()
	core.name = "Core"
	core.set_script(MARKER_SYSTEMS_CORE)
	parent.add_child(core)

	var input_sys := Node.new()
	input_sys.name = "S_InputSystem"
	const INPUT_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_input_system.gd")
	input_sys.set_script(INPUT_SYSTEM_SCRIPT)
	core.add_child(input_sys)

	var vcam_sys := Node.new()
	vcam_sys.name = "S_VCamSystem"
	const VCAM_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_vcam_system.gd")
	vcam_sys.set_script(VCAM_SYSTEM_SCRIPT)
	vcam_sys.execution_priority = 100
	core.add_child(vcam_sys)

	var wall_sys := Node.new()
	wall_sys.name = "S_WallCutoutSystem"
	const WALL_CUTOUT_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_wall_cutout_system.gd")
	wall_sys.set_script(WALL_CUTOUT_SYSTEM_SCRIPT)
	wall_sys.wall_cutout_config = WALL_CUTOUT_CONFIG
	core.add_child(wall_sys)

func _add_physics_systems(parent: Node) -> void:
	var physics := Node.new()
	physics.name = "Physics"
	physics.set_script(MARKER_SYSTEMS_PHYSICS)
	parent.add_child(physics)

	var grav := Node.new()
	grav.name = "S_GravitySystem"
	const GRAVITY_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_gravity_system.gd")
	grav.set_script(GRAVITY_SYSTEM_SCRIPT)
	grav.execution_priority = 60
	physics.add_child(grav)

	var jump := Node.new()
	jump.name = "S_JumpSystem"
	const JUMP_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_jump_system.gd")
	jump.set_script(JUMP_SYSTEM_SCRIPT)
	jump.execution_priority = 75
	physics.add_child(jump)

func _add_movement_systems(parent: Node) -> void:
	var movement := Node.new()
	movement.name = "Movement"
	movement.set_script(MARKER_SYSTEMS_MOVEMENT)
	parent.add_child(movement)

	_add_movement_node(movement, "S_MovementSystem", preload("res://scripts/core/ecs/systems/s_movement_system.gd"), 50)
	_add_movement_node(movement, "S_FloatingSystem", preload("res://scripts/core/ecs/systems/s_floating_system.gd"), 70)
	_add_movement_node(movement, "S_SpawnRecoverySystem", preload("res://scripts/core/ecs/systems/s_spawn_recovery_system.gd"), 75)
	_add_movement_node(movement, "S_RotateToInputSystem", preload("res://scripts/core/ecs/systems/s_rotate_to_input_system.gd"), 80)
	_add_movement_node(movement, "S_AlignWithSurfaceSystem", preload("res://scripts/core/ecs/systems/s_align_with_surface_system.gd"), 90)

func _add_feedback_systems(parent: Node) -> void:
	var feedback := Node.new()
	feedback.name = "Feedback"
	feedback.set_script(MARKER_SYSTEMS_FEEDBACK)
	parent.add_child(feedback)

	_add_feedback_node(feedback, "S_LandingIndicatorSystem", preload("res://scripts/core/ecs/systems/s_landing_indicator_system.gd"), 110)

	var jump_parts := Node.new()
	jump_parts.name = "S_JumpParticlesSystem"
	const JUMP_PARTICLES_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_jump_particles_system.gd")
	jump_parts.set_script(JUMP_PARTICLES_SYSTEM_SCRIPT)
	jump_parts.settings = JUMP_PARTICLES_SETTINGS
	jump_parts.execution_priority = 120
	feedback.add_child(jump_parts)

	_add_feedback_node(feedback, "S_JumpSoundSystem", preload("res://scripts/core/ecs/systems/s_jump_sound_system.gd"), 121)

	var land_parts := Node.new()
	land_parts.name = "S_LandingParticlesSystem"
	const LANDING_PARTICLES_SYSTEM_SCRIPT := preload("res://scripts/core/ecs/systems/s_landing_particles_system.gd")
	land_parts.set_script(LANDING_PARTICLES_SYSTEM_SCRIPT)
	land_parts.settings = LANDING_PARTICLES_SETTINGS
	feedback.add_child(land_parts)

	_add_feedback_node(feedback, "S_GamepadVibrationSystem", preload("res://scripts/core/ecs/systems/s_gamepad_vibration_system.gd"), 122)

func _add_movement_node(parent: Node, name_: String, script: Script, priority: int) -> void:
	var node := Node.new()
	node.name = name_
	node.set_script(script)
	node.execution_priority = priority
	parent.add_child(node)

func _add_feedback_node(parent: Node, name_: String, script: Script, priority: int = -1) -> void:
	var node := Node.new()
	node.name = name_
	node.set_script(script)
	if priority >= 0:
		node.execution_priority = priority
	parent.add_child(node)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.set_owner(owner)
	for child in node.get_children():
		_set_owner_recursive(child, owner)
```

Create `scripts/core/utils/editors/u_template_base_scene_builder.gd.uid`:

```
uid://dtemplate000000
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/utils/editors/u_template_base_scene_builder.gd scripts/core/utils/editors/u_template_base_scene_builder.gd.uid
git commit -m "feat: add U_TemplateBaseSceneBuilder utility class"
```

---

### Task 2: Create the EditorScript adapter

**Files:**
- Create: `scripts/demo/editors/build_tmpl_base_scene.gd`
- Create: `scripts/demo/editors/build_tmpl_base_scene.gd.uid` (empty placeholder)

- [ ] **Step 1: Write the adapter**

Create `scripts/demo/editors/build_tmpl_base_scene.gd`:

```gdscript
@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"

func _run() -> void:
	var builder := U_TemplateBaseSceneBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	builder.build_entities()
	if builder.save(OUTPUT_PATH):
		print("tmpl_base_scene built: %s" % OUTPUT_PATH)
	else:
		printerr("Failed to build tmpl_base_scene")
```

Create `scripts/demo/editors/build_tmpl_base_scene.gd.uid`:

```
uid://demptytemplate0
```

- [ ] **Step 2: Run GUT to verify no compilation errors**

```bash
tools/run_gut_suite.sh
```

Expected: No new compilation errors. (Tests that reference `tmpl_base_scene` may fail if they depend on specific UIDs — that's expected until Task 4.)

- [ ] **Step 3: Commit**

```bash
git add scripts/demo/editors/build_tmpl_base_scene.gd scripts/demo/editors/build_tmpl_base_scene.gd.uid
git commit -m "feat: add build_tmpl_base_scene EditorScript adapter"
```

---

### Task 3: Write the builder unit test

**Files:**
- Create: `tests/unit/editors/test_u_template_base_scene_builder.gd`
- Create: `tests/unit/editors/test_u_template_base_scene_builder.gd.uid` (empty placeholder)

- [ ] **Step 1: Write the test**

Create `tests/unit/editors/test_u_template_base_scene_builder.gd`:

```gdscript
extends GutTest

const BUILDER_PATH := "res://scripts/core/utils/editors/u_template_base_scene_builder.gd"

func _new_builder() -> Object:
	assert_true(FileAccess.file_exists(BUILDER_PATH), "Builder script must exist: %s" % BUILDER_PATH)
	if not FileAccess.file_exists(BUILDER_PATH):
		return null
	var script: Variant = load(BUILDER_PATH)
	assert_not_null(script, "Builder script must load")
	if script == null or not (script is Script):
		return null
	var v: Variant = (script as Script).new()
	if v == null or not (v is Object):
		return null
	return v as Object

func test_builder_script_exists_and_loads() -> void:
	var builder: Object = _new_builder()
	assert_not_null(builder, "U_TemplateBaseSceneBuilder must instantiate")

func test_create_root_produces_gameplay_root() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build() must return root")
	assert_true(root is Node3D, "Root must be Node3D")
	assert_eq((root as Node).name, "GameplayRoot", "Root must be named GameplayRoot")
	assert_not_null((root as Node).script, "Root must have script attached")

func test_scene_objects_contains_walls_floor_ceiling() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	var so: Node = root.get_node_or_null("SceneObjects")
	assert_not_null(so, "SceneObjects group must exist")
	assert_not_null(so.get_node_or_null("SO_Floor"), "Floor must exist")
	assert_not_null(so.get_node_or_null("SO_Ceiling"), "Ceiling must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_West"), "West wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_East"), "East wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_North"), "North wall must exist")
	assert_not_null(so.get_node_or_null("SO_Wall_South"), "South wall must exist")

func test_walls_are_ecs_entities_with_room_fade_component() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	var root: Node = builder.call("build") as Node
	var so: Node = root.get_node_or_null("SceneObjects")
	var wall_west: Node = so.get_node_or_null("SO_Wall_West")
	assert_not_null(wall_west, "West wall must exist")
	assert_not_null(wall_west.get_script(), "Wall must have script")
	assert_eq(wall_west.get("entity_id"), &"wall_west", "entity_id must be set")
	var tags: Array = wall_west.get("tags")
	assert_true(tags.has(&"room_fade_group"), "Wall must have room_fade_group tag")
	var component: Node = wall_west.get_node_or_null("C_RoomFadeGroupComponent")
	assert_not_null(component, "RoomFadeGroupComponent must exist on wall")
	assert_eq(component.get("group_tag"), &"wall_west", "group_tag must match entity_id")

func test_environment_has_world_environment_and_light() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_environment")
	var root: Node = builder.call("build") as Node
	var env: Node = root.get_node_or_null("Environment")
	assert_not_null(env, "Environment group must exist")
	var we: Node = env.get_node_or_null("Env_WorldEnvironment")
	assert_not_null(we, "WorldEnvironment must exist")
	assert_true(we is WorldEnvironment, "Must be WorldEnvironment type")
	assert_not_null((we as WorldEnvironment).environment, "Environment resource must be set")
	var light: Node = env.get_node_or_null("Env_DirectionalLight3D")
	assert_not_null(light, "DirectionalLight3D must exist")
	assert_true(light is DirectionalLight3D, "Must be DirectionalLight3D type")

func test_systems_have_all_four_groups() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	var systems: Node = root.get_node_or_null("Systems")
	assert_not_null(systems, "Systems group must exist")
	assert_not_null(systems.get_node_or_null("Core"), "Core systems must exist")
	assert_not_null(systems.get_node_or_null("Physics"), "Physics systems must exist")
	assert_not_null(systems.get_node_or_null("Movement"), "Movement systems must exist")
	assert_not_null(systems.get_node_or_null("Feedback"), "Feedback systems must exist")

func test_core_systems_contain_input_vcam_wallcutout() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	var core: Node = root.get_node_or_null("Systems/Core")
	assert_not_null(core, "Core systems must exist")
	assert_not_null(core.get_node_or_null("S_InputSystem"), "InputSystem must exist")
	assert_not_null(core.get_node_or_null("S_VCamSystem"), "VCamSystem must exist")
	assert_not_null(core.get_node_or_null("S_WallCutoutSystem"), "WallCutoutSystem must exist")

func test_movement_systems_contain_all_five() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_systems")
	var root: Node = builder.call("build") as Node
	var movement: Node = root.get_node_or_null("Systems/Movement")
	assert_not_null(movement, "Movement systems must exist")
	assert_not_null(movement.get_node_or_null("S_MovementSystem"), "MovementSystem must exist")
	assert_not_null(movement.get_node_or_null("S_FloatingSystem"), "FloatingSystem must exist")
	assert_not_null(movement.get_node_or_null("S_SpawnRecoverySystem"), "SpawnRecoverySystem must exist")
	assert_not_null(movement.get_node_or_null("S_RotateToInputSystem"), "RotateToInputSystem must exist")
	assert_not_null(movement.get_node_or_null("S_AlignWithSurfaceSystem"), "AlignWithSurfaceSystem must exist")

func test_managers_contain_ecs_manager() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_managers")
	var root: Node = builder.call("build") as Node
	var managers: Node = root.get_node_or_null("Managers")
	assert_not_null(managers, "Managers group must exist")
	assert_not_null(managers.get_node_or_null("M_ECSManager"), "ECSManager must exist")

func test_entities_contain_player_camera_and_spawn_points() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_entities")
	var root: Node = builder.call("build") as Node
	var entities: Node = root.get_node_or_null("Entities")
	assert_not_null(entities, "Entities group must exist")
	assert_not_null(entities.get_node_or_null("E_Player"), "Player entity must exist")
	assert_not_null(entities.get_node_or_null("E_CameraRoot"), "Camera entity must exist")
	var spawn_points: Node = entities.get_node_or_null("SpawnPoints")
	assert_not_null(spawn_points, "SpawnPoints must exist")

func test_save_writes_tscn_file() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root")
	builder.call("build_scene_objects")
	builder.call("build_environment")
	builder.call("build_systems")
	builder.call("build_managers")
	builder.call("build_entities")
	var save_path: String = "res://tests/unit/editors/_test_tmpl_base_scene.tscn"
	var result: Variant = builder.call("save", save_path)
	assert_true(result, "save() must return true")
	assert_true(FileAccess.file_exists(save_path), "save() must write .tscn file")
	var packed: PackedScene = load(save_path) as PackedScene
	assert_not_null(packed, "Saved file must load as PackedScene")
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)
```

**After_each cleanup:**

```gdscript
func after_each() -> void:
	var cleanup_paths := [
		"res://tests/unit/editors/_test_tmpl_base_scene.tscn",
	]
	for path in cleanup_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
```

- [ ] **Step 2: Commit**

```bash
git add tests/unit/editors/test_u_template_base_scene_builder.gd tests/unit/editors/test_u_template_base_scene_builder.gd.uid
git commit -m "test(RED): add U_TemplateBaseSceneBuilder unit tests"
```

---

### Task 4: Run builder test suite and fix any issues

- [ ] **Step 1: Run the builder test**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_template_base_scene_builder.gd
```

Expected: All 10 tests pass (RED → GREEN confirmation).

- [ ] **Step 2: Fix any test failures**

If `save()` test fails due to missing directory, ensure the test directory exists:

```bash
mkdir -p tests/unit/editors
```

- [ ] **Step 3: Run full test suite**

```bash
tools/run_gut_suite.sh
```

Expected: Existing tests that reference `tmpl_base_scene.tscn` still pass (they load the hand-authored file, not yet replaced).

- [ ] **Step 4: Run style enforcement**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: PASS — new `.gd` files follow naming conventions.

- [ ] **Step 5: Commit**

```bash
git add tests/unit/editors/test_u_template_base_scene_builder.gd
git commit -m "test(GREEN): U_TemplateBaseSceneBuilder tests pass"
```

---

### Task 5: Generate and replace tmpl_base_scene.tscn

- [ ] **Step 1: Run the EditorScript adapter via GUT**

Use GUT's `execute_editor_script` functionality to run the adapter headlessly:

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_template_base_scene_builder.gd
```

Verify `test_save_writes_tscn_file` passes (already confirmed in Task 4).

- [ ] **Step 2: Manually verify the generated scene loads**

Confirm via GUT the generated output scene loads without errors:

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd
```

Expected: PASS — the contract test validates the scene structure.

- [ ] **Step 3: Commit the generated template**

The hand-authored `tmpl_base_scene.tscn` will be regenerated. Commit the new version:

```bash
git add scenes/core/templates/tmpl_base_scene.tscn
git commit -m "feat: replace hand-authored tmpl_base_scene.tscn with builder-generated version"
```

---

### Task 6: Update build_gameplay_demo_room to use builder

**Files:**
- Modify: `scripts/demo/editors/build_gameplay_demo_room.gd`

- [ ] **Step 1: Update build_gameplay_demo_room.gd**

Replace the contents of `scripts/demo/editors/build_gameplay_demo_room.gd`:

```gdscript
@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/demo/gameplay/gameplay_demo_room.tscn"

func _run() -> void:
	var builder := U_TemplateBaseSceneBuilder.new()
	builder.create_root()
	builder.build_scene_objects()
	builder.build_environment()
	builder.build_systems()
	builder.build_managers()
	builder.build_entities()

	var root: Node3D = builder.build()
	var spawn_points: Node = root.get_node_or_null("Entities/SpawnPoints")
	if spawn_points != null:
		var spawn := Marker3D.new()
		spawn.name = "sp_default"
		spawn.position = Vector3(0, 1.0, 0)
		spawn_points.add_child(spawn)
		spawn.set_owner(root)

	var packed := PackedScene.new()
	var pack_result := packed.pack(root)
	if pack_result != OK:
		printerr("Failed to pack scene: %d" % pack_result)
		return

	var save_result := ResourceSaver.save(packed, OUTPUT_PATH)
	if save_result != OK:
		printerr("Failed to save scene: %d" % save_result)
	else:
		print("Scene saved: %s" % OUTPUT_PATH)
```

- [ ] **Step 2: Run full test suite**

```bash
tools/run_gut_suite.sh
```

Expected: All tests pass.

- [ ] **Step 3: Commit**

```bash
git add scripts/demo/editors/build_gameplay_demo_room.gd
git commit -m "refactor: update build_gameplay_demo_room to use U_TemplateBaseSceneBuilder"
```

---

### Task 7: Update docs

**Files:**
- Modify: `docs/architecture/extensions/builders.md`

- [ ] **Step 1: Add builder to canonical examples table**

Add this row to the table in `docs/architecture/extensions/builders.md`:

```
| Template scene | `scripts/core/utils/editors/u_template_base_scene_builder.gd` | `U_TemplateBaseSceneBuilder.new().create_root()...` |
```

- [ ] **Step 2: Commit**

```bash
git add docs/architecture/extensions/builders.md
git commit -m "docs: document U_TemplateBaseSceneBuilder in builders recipe"
```
