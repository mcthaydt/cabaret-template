# Base Scene Defaults Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the canonical `tmpl_base_scene.tscn` with a 5x5x5m grid-textured room, tuned camera defaults (FOV=39.6, 3m above/4m away, -36.87 pitch), working wall/ceiling fading, and solid black sky.

**Architecture:** Extend `U_EditorBlockoutBuilder` with geometry/material helpers (staying under 200-line cap). Create a `@tool` build script that regenerates `tmpl_base_scene.tscn`. Update camera resource configs directly. Copy one grid texture from demo to core.

**Tech Stack:** Godot 4.7, GDScript, GUT test framework, CSGBox3D geometry, VCam orbit mode

---

### Task 1: Copy grid texture to core assets

**Files:**
- Create: `assets/core/textures/prototype_grids/tex_texture_01.png`
- Create: `assets/core/textures/prototype_grids/tex_texture_01.png.import`

- [ ] **Step 1: Create destination directory and copy files**

```bash
mkdir -p assets/core/textures/prototype_grids
cp assets/demo/textures/prototype_grids_png/Dark/tex_texture_01.png assets/core/textures/prototype_grids/tex_texture_01.png
cp assets/demo/textures/prototype_grids_png/Dark/tex_texture_01.png.import assets/core/textures/prototype_grids/tex_texture_01.png.import
```

- [ ] **Step 2: Update .import file source path**

Edit `assets/core/textures/prototype_grids/tex_texture_01.png.import` — change the `source_file` in the `[deps]` section from:
```
source_file="res://assets/demo/textures/prototype_grids_png/Dark/tex_texture_01.png"
```
to:
```
source_file="res://assets/core/textures/prototype_grids/tex_texture_01.png"
```

- [ ] **Step 3: Remove UID from copied .import to avoid collision**

The copied file has `uid="uid://dy0x7tmqlyw0y"` from the demo source. Remove the uid line from `[remap]` so Godot assigns a new one on reimport:
```
importer="texture"
type="CompressedTexture2D"
path.s3tc="res://.godot/imported/tex_texture_01.png-1331a27bd472a0153ec915708103bf9c.s3tc.ctex"
path.etc2="res://.godot/imported/tex_texture_01.png-1331a27bd472a0153ec915708103bf9c.etc2.ctex"
```

- [ ] **Step 4: Verify files exist**

```bash
ls -la assets/core/textures/prototype_grids/tex_texture_01.png
```

- [ ] **Step 5: Commit**

```bash
git add assets/core/textures/prototype_grids/
git commit -m "feat: copy grid texture to core for base scene (GREEN)"
```

---

### Task 2: Extend U_EditorBlockoutBuilder with position/texture helpers

**Files:**
- Modify: `scripts/core/utils/editors/u_editor_blockout_builder.gd`
- Modify: `tests/unit/editors/test_u_editor_blockout_builder.gd`

Current LOC: 110. After additions: ~160. Under 200-line cap.

- [ ] **Step 1: Add failing tests for new builder methods**

Append to `tests/unit/editors/test_u_editor_blockout_builder.gd`:

```gdscript
func test_add_csg_box_at_adds_box_at_position() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box_at", "Wall", Vector3(0.2, 5, 5), Vector3(-2.5, 2.5, 0))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Wall")
	assert_not_null(box, "add_csg_box_at must add child named Wall")
	assert_true(box is CSGBox3D, "Added child must be CSGBox3D")
	assert_eq((box as CSGBox3D).size, Vector3(0.2, 5, 5), "add_csg_box_at must set size")
	assert_eq((box as CSGBox3D).position, Vector3(-2.5, 2.5, 0), "add_csg_box_at must set position")
	if root is Node:
		(root as Node).free()

func test_set_position_moves_node() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box", "Floor", Vector3(1, 1, 1))
	builder.call("set_position", "Floor", Vector3(0, 5, 0))
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Floor")
	assert_true(box is CSGBox3D, "Floor must be CSGBox3D")
	assert_eq((box as CSGBox3D).position, Vector3(0, 5, 0), "set_position must move node")
	if root is Node:
		(root as Node).free()

func test_set_material_unshaded_texture_applies_texture() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "TestBlockout")
	builder.call("add_csg_box", "Floor", Vector3(5, 1, 5))
	builder.call("set_material_unshaded_texture", "Floor", "res://tests/unit/editors/_test_grid.png")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var box: Node = (root as Node).get_node_or_null("Floor")
	assert_not_null(box, "Floor must exist")
	assert_true(box is CSGBox3D, "Floor must be CSGBox3D")
	var mat: Material = (box as CSGBox3D).material
	assert_not_null(mat, "set_material_unshaded_texture must assign a material")
	assert_true(mat is StandardMaterial3D, "Material must be StandardMaterial3D")
	assert_eq((mat as StandardMaterial3D).shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "Material must be unshaded")
	if root is Node:
		(root as Node).free()
```

- [ ] **Step 2: Create a small test texture (1-pixel PNG) for the texture test**

```bash
# Create a minimal 1x1 pixel PNG using Python
python3 -c "
import struct, zlib
def create_png(width, height, r, g, b):
    def chunk(chunk_type, data):
        c = chunk_type + data
        crc = struct.pack('>I', zlib.crc32(c) & 0xffffffff)
        return struct.pack('>I', len(data)) + c + crc
    raw = b''
    for y in range(height):
        raw += b'\x00'
        for x in range(width):
            raw += struct.pack('BBB', r, g, b)
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw)) +
            chunk(b'IEND', b''))
with open('tests/unit/editors/_test_grid.png', 'wb') as f:
    f.write(create_png(1, 1, 128, 128, 128))
"
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_blockout_builder.gd
```

Expected: FAIL with "Invalid call. Nonexistent function 'add_csg_box_at' in base 'RefCounted (U_EditorBlockoutBuilder)'"

- [ ] **Step 4: Add new methods to U_EditorBlockoutBuilder**

Add after line 20 (after `add_csg_box`) in `scripts/core/utils/editors/u_editor_blockout_builder.gd`:

```gdscript
func add_csg_box_at(node_name: String, size: Vector3, position: Vector3) -> U_EditorBlockoutBuilder:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: add_csg_box_at called before create_root")
		return self
	var box: CSGBox3D = CSGBox3D.new()
	box.name = node_name
	box.size = size
	box.position = position
	_root.add_child(box)
	return self
```

Add after `add_csg_box_at` (before `add_csg_sphere`):

```gdscript
func set_position(node_name: String, position: Vector3) -> U_EditorBlockoutBuilder:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: set_position called before create_root")
		return self
	var target: Node = _root.get_node_or_null(node_name)
	if target == null:
		push_error("U_EditorBlockoutBuilder: set_position target '%s' not found" % node_name)
		return self
	if target is Node3D:
		target.position = position
	return self
```

Add after `set_material` (after line 60):

```gdscript
func set_material_unshaded_texture(node_name: String, texture_path: String) -> U_EditorBlockoutBuilder:
	if _root == null:
		push_error("U_EditorBlockoutBuilder: set_material_unshaded_texture called before create_root")
		return self
	var target: Node = _root.get_node_or_null(node_name)
	if target == null:
		push_error("U_EditorBlockoutBuilder: set_material_unshaded_texture target '%s' not found" % node_name)
		return self
	var texture: CompressedTexture2D = load(texture_path)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = texture
	target.set("material", mat)
	return self
```

- [ ] **Step 5: Run tests to verify they pass**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_blockout_builder.gd
```

Expected: ALL PASS

- [ ] **Step 6: Clean up test texture**

```bash
rm tests/unit/editors/_test_grid.png
```

- [ ] **Step 7: Commit**

```bash
git add scripts/core/utils/editors/u_editor_blockout_builder.gd tests/unit/editors/test_u_editor_blockout_builder.gd
git commit -m "feat: add position/texture helpers to U_EditorBlockoutBuilder (GREEN)"
```

---

### Task 3: Create build script that regenerates tmpl_base_scene.tscn

**Files:**
- Create: `scripts/core/editors/build_base_scene.gd`

- [ ] **Step 1: Create the build script**

Write `scripts/core/editors/build_base_scene.gd`:

```gdscript
@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"
const GRID_TEXTURE_PATH := "res://assets/core/textures/prototype_grids/tex_texture_01.png"
const CAMERA_TEMPLATE_PATH := "res://scenes/core/templates/tmpl_camera.tscn"
const PLAYER_PREFAB_PATH := "res://scenes/core/prefabs/prefab_player.tscn"
const ROOM_SIZE: float = 5.0
const WALL_THICKNESS: float = 0.2
const CEILING_HEIGHT: float = 5.0
const HALF_ROOM: float = ROOM_SIZE / 2.0
const WALL_HALF: float = WALL_THICKNESS / 2.0

func _run() -> void:
	var BuilderKlass: Script = load("res://scripts/core/utils/editors/u_editor_blockout_builder.gd")
	var builder: U_EditorBlockoutBuilder = BuilderKlass.new()
	builder.create_root("GameplayRoot")

	# --- SceneObjects container ---
	var scene_objects: Node3D = Node3D.new()
	scene_objects.name = "SceneObjects"
	scene_objects.script = load("res://scripts/core/scene_structure/marker_scene_objects_group.gd")

	# Floor
	builder.create_root("_tmp")
	builder.add_csg_box_at("SO_Floor", Vector3(ROOM_SIZE, WALL_THICKNESS, ROOM_SIZE), Vector3(0, 0, 0))
	builder.set_material_unshaded_texture("SO_Floor", GRID_TEXTURE_PATH)
	var floor: Node = builder.build().get_node("SO_Floor")
	builder.build().remove_child(floor)
	scene_objects.add_child(floor)
	floor.set_meta("_ignore_style", true)

	# Ceiling
	builder.create_root("_tmp")
	builder.add_csg_box_at("SO_Ceiling", Vector3(ROOM_SIZE, WALL_THICKNESS, ROOM_SIZE), Vector3(0, CEILING_HEIGHT, 0))
	builder.set_material_unshaded_texture("SO_Ceiling", GRID_TEXTURE_PATH)
	var ceiling: Node = builder.build().get_node("SO_Ceiling")
	builder.build().remove_child(ceiling)
	scene_objects.add_child(ceiling)
	ceiling.set_meta("_ignore_style", true)

	# Walls with RoomFadeGroup components
	_add_wall(scene_objects, "SO_Wall_West",  Vector3(WALL_THICKNESS, CEILING_HEIGHT, ROOM_SIZE),  Vector3(-HALF_ROOM, CEILING_HEIGHT / 2.0, 0), StringName("wall_west"),  Vector3(-1, 0, 0))
	_add_wall(scene_objects, "SO_Wall_East",  Vector3(WALL_THICKNESS, CEILING_HEIGHT, ROOM_SIZE),  Vector3(HALF_ROOM, CEILING_HEIGHT / 2.0, 0),  StringName("wall_east"),  Vector3(1, 0, 0))
	_add_wall(scene_objects, "SO_Wall_North", Vector3(ROOM_SIZE, CEILING_HEIGHT, WALL_THICKNESS),  Vector3(0, CEILING_HEIGHT / 2.0, -HALF_ROOM), StringName("wall_north"), Vector3(0, 0, -1))
	_add_wall(scene_objects, "SO_Wall_South", Vector3(ROOM_SIZE, CEILING_HEIGHT, WALL_THICKNESS),  Vector3(0, CEILING_HEIGHT / 2.0, HALF_ROOM),  StringName("wall_south"), Vector3(0, 0, 1))

	var root: Node3D = Node3D.new()
	root.name = "GameplayRoot"
	var RootScript: Script = load("res://scripts/core/root.gd")
	root.script = RootScript
	root.add_child(scene_objects)

	# --- Environment ---
	_add_environment(root)

	# --- Systems ---
	_add_systems(root)

	# --- Managers ---
	_add_managers(root)

	# --- Entities ---
	_add_entities(root)

	_apply_collision_settings(root)

	var packed: PackedScene = PackedScene.new()
	var pack_result: int = packed.pack(root)
	if pack_result != OK:
		printerr("Failed to pack scene: %d" % pack_result)
		return

	var save_result: int = ResourceSaver.save(packed, OUTPUT_PATH)
	if save_result != OK:
		printerr("Failed to save scene: %d" % save_result)
	else:
		print("Base scene saved: %s" % OUTPUT_PATH)

func _add_wall(parent: Node3D, name_str: String, size: Vector3, pos: Vector3, entity_id: StringName, fade_normal: Vector3) -> void:
	var wall: CSGBox3D = CSGBox3D.new()
	wall.name = name_str
	wall.size = size
	wall.position = pos
	wall.use_collision = true

	var EntityScript: Script = load("res://scripts/core/ecs/base_ecs_entity.gd")
	wall.script = EntityScript
	wall.entity_id = entity_id
	wall.tags = [StringName("room_fade_group")]

	var fade_comp: Node = Node.new()
	fade_comp.name = "C_RoomFadeGroupComponent"
	var FadeScript: Script = load("res://scripts/core/ecs/components/c_room_fade_group_component.gd")
	fade_comp.script = FadeScript
	fade_comp.set("group_tag", entity_id)
	fade_comp.set("fade_normal", fade_normal)
	wall.add_child(fade_comp)

	var texture: CompressedTexture2D = load(GRID_TEXTURE_PATH)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = texture
	wall.material = mat

	parent.add_child(wall)

func _add_environment(root: Node3D) -> void:
	var env_container: Node = Node.new()
	env_container.name = "Environment"
	var EnvScript: Script = load("res://scripts/core/scene_structure/marker_environment_group.gd")
	env_container.script = EnvScript

	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.name = "Env_WorldEnvironment"
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 1)
	world_env.environment = env
	env_container.add_child(world_env)

	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.name = "Env_DirectionalLight3D"
	light.position = Vector3(0, 0, 0)
	light.light_color = Color(0.56078434, 0.827451, 1, 1)
	light.light_energy = 1.5
	light.light_indirect_energy = 0.0
	env_container.add_child(light)

	root.add_child(env_container)

func _add_systems(root: Node3D) -> void:
	var systems: Node = Node.new()
	systems.name = "Systems"
	var SysScript: Script = load("res://scripts/core/scene_structure/marker_systems_group.gd")
	systems.script = SysScript

	# Core
	var core: Node = Node.new()
	core.name = "Core"
	var CoreScript: Script = load("res://scripts/core/scene_structure/marker_systems_core_group.gd")
	core.script = CoreScript

	_add_system_node(core, "S_InputSystem", "res://scripts/core/ecs/systems/s_input_system.gd")

	var vcam: Node = Node.new()
	vcam.name = "S_VCamSystem"
	var VCamScript: Script = load("res://scripts/core/ecs/systems/s_vcam_system.gd")
	vcam.script = VCamScript
	vcam.set("execution_priority", 100)
	core.add_child(vcam)

	var wall_vis: Node = Node.new()
	wall_vis.name = "S_WallVisibilitySystem"
	var WallVisScript: Script = load("res://scripts/core/ecs/systems/s_wall_visibility_system.gd")
	wall_vis.script = WallVisScript
	wall_vis.set("wall_visibility_config", load("res://resources/core/base_settings/gameplay/cfg_wall_visibility_config_default.tres"))
	core.add_child(wall_vis)

	systems.add_child(core)

	# Physics
	var physics: Node = Node.new()
	physics.name = "Physics"
	var PhysScript: Script = load("res://scripts/core/scene_structure/marker_systems_physics_group.gd")
	physics.script = PhysScript

	_add_system_node_with_priority(physics, "S_GravitySystem", "res://scripts/core/ecs/systems/s_gravity_system.gd", 60)
	_add_system_node_with_priority(physics, "S_JumpSystem", "res://scripts/core/ecs/systems/s_jump_system.gd", 75)

	systems.add_child(physics)

	# Movement
	var movement: Node = Node.new()
	movement.name = "Movement"
	var MovScript: Script = load("res://scripts/core/scene_structure/marker_systems_movement_group.gd")
	movement.script = MovScript

	_add_system_node_with_priority(movement, "S_MovementSystem", "res://scripts/core/ecs/systems/s_movement_system.gd", 50)
	_add_system_node_with_priority(movement, "S_FloatingSystem", "res://scripts/core/ecs/systems/s_floating_system.gd", 70)
	_add_system_node_with_priority(movement, "S_SpawnRecoverySystem", "res://scripts/core/ecs/systems/s_spawn_recovery_system.gd", 75)
	_add_system_node_with_priority(movement, "S_RotateToInputSystem", "res://scripts/core/ecs/systems/s_rotate_to_input_system.gd", 80)
	_add_system_node_with_priority(movement, "S_AlignWithSurfaceSystem", "res://scripts/core/ecs/systems/s_align_with_surface_system.gd", 90)

	systems.add_child(movement)

	# Feedback
	var feedback: Node = Node.new()
	feedback.name = "Feedback"
	var FbScript: Script = load("res://scripts/core/scene_structure/marker_systems_feedback_group.gd")
	feedback.script = FbScript

	_add_system_node_with_priority(feedback, "S_LandingIndicatorSystem", "res://scripts/core/ecs/systems/s_landing_indicator_system.gd", 110)

	var jump_particles: Node = Node.new()
	jump_particles.name = "S_JumpParticlesSystem"
	var JPScript: Script = load("res://scripts/core/ecs/systems/s_jump_particles_system.gd")
	jump_particles.script = JPScript
	jump_particles.set("execution_priority", 120)
	jump_particles.set("settings", load("res://resources/core/base_settings/gameplay/cfg_jump_particles_default.tres"))
	feedback.add_child(jump_particles)

	_add_system_node_with_priority(feedback, "S_JumpSoundSystem", "res://scripts/core/ecs/systems/s_jump_sound_system.gd", 121)

	var landing_particles: Node = Node.new()
	landing_particles.name = "S_LandingParticlesSystem"
	var LPScript: Script = load("res://scripts/core/ecs/systems/s_landing_particles_system.gd")
	landing_particles.script = LPScript
	landing_particles.set("settings", load("res://resources/core/base_settings/gameplay/cfg_landing_particles_default.tres"))
	feedback.add_child(landing_particles)

	_add_system_node_with_priority(feedback, "S_GamepadVibrationSystem", "res://scripts/core/ecs/systems/s_gamepad_vibration_system.gd", 122)

	systems.add_child(feedback)

	root.add_child(systems)

func _add_system_node(parent: Node, name_str: String, script_path: String) -> void:
	var node: Node = Node.new()
	node.name = name_str
	node.script = load(script_path)
	parent.add_child(node)

func _add_system_node_with_priority(parent: Node, name_str: String, script_path: String, priority: int) -> void:
	var node: Node = Node.new()
	node.name = name_str
	node.script = load(script_path)
	node.set("execution_priority", priority)
	parent.add_child(node)

func _add_managers(root: Node3D) -> void:
	var managers: Node = Node.new()
	managers.name = "Managers"
	var MgrScript: Script = load("res://scripts/core/scene_structure/marker_managers_group.gd")
	managers.script = MgrScript

	var ecs_mgr: Node = Node.new()
	ecs_mgr.name = "M_ECSManager"
	ecs_mgr.script = load("res://scripts/core/managers/m_ecs_manager.gd")
	managers.add_child(ecs_mgr)

	root.add_child(managers)

func _add_entities(root: Node3D) -> void:
	var entities: Node = Node.new()
	entities.name = "Entities"
	var EntScript: Script = load("res://scripts/core/scene_structure/marker_entities_group.gd")
	entities.script = EntScript

	var player: Node3D = load(PLAYER_PREFAB_PATH).instantiate()
	player.name = "E_Player"
	player.position = Vector3(0, 0, 0)
	entities.add_child(player)

	var camera: Node3D = load(CAMERA_TEMPLATE_PATH).instantiate()
	camera.name = "E_CameraRoot"
	entities.add_child(camera)

	var spawn_points: Node3D = Node3D.new()
	spawn_points.name = "SpawnPoints"
	var SpawnScript: Script = load("res://scripts/core/scene_structure/marker_spawn_points_group.gd")
	spawn_points.script = SpawnScript
	entities.add_child(spawn_points)

	root.add_child(entities)

func _apply_collision_settings(root: Node3D) -> void:
	var i: int = 100
	for child in root.find_children("*", "CSGBox3D"):
		child.set("use_collision", true)
		child.set_meta("_ignore_style", true)
		i += 1
```

- [ ] **Step 2: Commit**

```bash
git add scripts/core/editors/build_base_scene.gd
git commit -m "feat: add base scene build script (GREEN)"
```

---

### Task 4: Update camera template (tmpl_camera.tscn) with base_fov

**Files:**
- Modify: `scenes/core/templates/tmpl_camera.tscn`

- [ ] **Step 1: Set base_fov on C_CameraStateComponent**

Edit `scenes/core/templates/tmpl_camera.tscn`. The `C_CameraStateComponent` node (line 25-26) needs `base_fov = 39.5978`. Change from:

```
[node name="C_CameraStateComponent" type="Node" parent="Components" unique_id=1323051184]
script = ExtResource("2_camera_state")
```

to:

```
[node name="C_CameraStateComponent" type="Node" parent="Components" unique_id=1323051184]
script = ExtResource("2_camera_state")
base_fov = 39.5978
```

- [ ] **Step 2: Commit**

```bash
git add scenes/core/templates/tmpl_camera.tscn
git commit -m "feat: set camera base_fov to 39.5978 in template (GREEN)"
```

---

### Task 5: Update camera orbit defaults (cfg_default_orbit.tres)

**Files:**
- Modify: `resources/core/display/vcam/cfg_default_orbit.tres`

- [ ] **Step 1: Update FOV, distance, and pitch**

Edit `resources/core/display/vcam/cfg_default_orbit.tres`. Change values:

```
distance = 12.5
authored_pitch = -30.0
rotation_speed = 1.2
fov = 28.8415
```

to:

```
distance = 5.0
authored_pitch = -36.87
rotation_speed = 1.2
fov = 39.5978
```

- [ ] **Step 2: Commit**

```bash
git add resources/core/display/vcam/cfg_default_orbit.tres
git commit -m "feat: update default orbit FOV/distance/pitch (GREEN)"
```

---

### Task 6: Update wall visibility config defaults

**Files:**
- Modify: `resources/core/base_settings/gameplay/cfg_wall_visibility_config_default.tres`

- [ ] **Step 1: Add fade_speed, min_alpha, corridor_occlusion_margin overrides**

Edit `resources/core/base_settings/gameplay/cfg_wall_visibility_config_default.tres`. Currently uses script defaults only (no explicit values). Override with:

```
[resource]
script = ExtResource("1_wall_visibility_config_script")
fade_speed = 6.0
min_alpha = 0.0
corridor_occlusion_margin = 3.0
```

- [ ] **Step 2: Commit**

```bash
git add resources/core/base_settings/gameplay/cfg_wall_visibility_config_default.tres
git commit -m "feat: tune wall fade defaults (speed=6, dissolve, margin=3) (GREEN)"
```

---

### Task 7: Run full test suite and style enforcement

- [ ] **Step 1: Run unit tests**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_blockout_builder.gd
```

Expected: ALL 11 tests PASS. (8 original + 3 new)

- [ ] **Step 2: Run base scene contract test**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd
```

Expected: ALL PASS. Base scene must meet contract after regeneration.

- [ ] **Step 3: Run style enforcement**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: PASS. No naming/style violations introduced.

- [ ] **Step 4: Run full suite**

```bash
tools/run_gut_suite.sh
```

Expected: ALL PASS with no regressions.

---

### Task 8: Regenerate base scene and verify

**Files:**
- Modify: `scenes/core/templates/tmpl_base_scene.tscn` (regenerated)

- [ ] **Step 1: Run the build script in Godot editor to regenerate tmpl_base_scene.tscn**

Open the project in Godot editor. In the Script editor, open `res://scripts/core/editors/build_base_scene.gd`. Click File > Run (or Ctrl+Shift+X) to execute the EditorScript. The console should print: "Base scene saved: res://scenes/core/templates/tmpl_base_scene.tscn"

Or run headless:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://scripts/core/editors/build_base_scene.gd
```

If headless execution doesn't support EditorScript, use the `godot_run_project` tool or open in editor manually.

- [ ] **Step 2: Verify generated scene loads**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd
```

Expected: ALL PASS. All containers present in regenerated scene.

- [ ] **Step 3: Visual verification**

Open `tmpl_base_scene.tscn` in Godot editor. Verify:
- Room is 5x5x5m grid-textured
- Solid black background
- Camera template has correct base_fov
- Walls have C_RoomFadeGroupComponent children with correct fade_normals
- All CSGBox3D nodes have unshaded grid texture material

- [ ] **Step 4: Commit**

```bash
git add scenes/core/templates/tmpl_base_scene.tscn
git commit -m "feat: regenerate base scene with 5x5x5m grid room (GREEN)"
```

---

### Task 9: Final verification

- [ ] **Step 1: Run full test suite one last time**

```bash
tools/run_gut_suite.sh
```

Expected: ALL PASS.

- [ ] **Step 2: Run style enforcement**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: PASS.

- [ ] **Step 3: Run base scene contract**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd
```

Expected: ALL PASS.

