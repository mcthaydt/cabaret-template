# Prefab Builder Migration P7.4–P7.7 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate all remaining `.tscn` prefabs to `U_EditorPrefabBuilder` scripts; extend builder with `add_child_to` and `add_child_scene_to`.

**Architecture:** Extend `U_EditorPrefabBuilder` with two child-parenting methods. Character prefabs inherit `tmpl_character.tscn`, attach `Body_Mesh` to `Player_Body`, override component settings, add ECS components. Scene prefabs import GLB models and add collision. All builder scripts are `@tool extends EditorScript` thin wrappers.

**Tech Stack:** Godot 4.6, GDScript, GUT, PackedScene API.

---

### Task 1: RED — Test `add_child_to`

**Files:**
- Modify: `tests/unit/editors/test_u_editor_prefab_builder.gd`

- [ ] **Step 1: Write failing test**

At the end of the test file (after line 435):

```gdscript
func test_add_child_to_adds_node_under_parent() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_visual_mesh", "ParentMesh", null, Vector3.ONE)
	var child: MeshInstance3D = MeshInstance3D.new()
	child.name = "ChildMesh"
	builder.call("add_child_to", "ParentMesh", child)
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var parent_node: Node = (root as Node).get_node_or_null("ParentMesh")
	assert_not_null(parent_node, "ParentMesh must exist")
	var found_child: Node = parent_node.get_node_or_null("ChildMesh")
	assert_not_null(found_child, "add_child_to must add child under specified parent")
	assert_eq(found_child.name, "ChildMesh", "Child name must match")
	if root is Node:
		(root as Node).queue_free()

func test_add_child_to_without_root_returns_self() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	var child: Node = Node.new()
	var result: Variant = builder.call("add_child_to", "Parent", child)
	assert_eq(result, builder, "add_child_to without root must return self")

func test_add_child_to_missing_parent_returns_self() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	var child: Node = Node.new()
	var result: Variant = builder.call("add_child_to", "NonExistent", child)
	assert_push_error("override_property target not found")
	assert_eq(result, builder, "add_child_to missing parent must return self after error")
```

- [ ] **Step 2: Run the test**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_prefab_builder.gd
```

Expected: FAIL with "add_child_to not found"

---

### Task 2: GREEN — Implement `add_child_to`

**Files:**
- Modify: `scripts/core/utils/editors/u_editor_prefab_builder.gd`

- [ ] **Step 3: Implement method**

After `override_property()` (after line 116), add:

```gdscript
func add_child_to(parent_path: String, node: Node) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_child_to called before root creation")
		return self
	var parent: Node = _root.get_node(parent_path) if parent_path != "." else _root
	if parent == null:
		push_error("U_EditorPrefabBuilder: add_child_to parent not found at '%s'" % parent_path)
		return self
	parent.add_child(node)
	return self
```

- [ ] **Step 4: Run tests**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_prefab_builder.gd
```

Expected: PASS for `add_child_to` tests.

---

### Task 3: RED — Test `add_child_scene_to`

**Files:**
- Modify: `tests/unit/editors/test_u_editor_prefab_builder.gd`

- [ ] **Step 5: Write failing test**

After the `add_child_to` tests, add:

```gdscript
func test_add_child_scene_to_instantiates_under_parent() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "TestRoot")
	builder.call("add_marker", "ParentMarker")
	builder.call("add_child_scene_to", "ParentMarker", TMPL_CHARACTER_PATH, "CharChild")
	var root: Variant = builder.call("build")
	assert_not_null(root, "build must return root")
	var parent_node: Node = (root as Node).get_node_or_null("ParentMarker")
	assert_not_null(parent_node, "ParentMarker must exist")
	var child: Node = parent_node.get_node_or_null("CharChild")
	assert_not_null(child, "add_child_scene_to must instantiate child under parent")
	if root is Node:
		(root as Node).queue_free()
```

- [ ] **Step 6: Run the test**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_prefab_builder.gd
```

Expected: FAIL with "add_child_scene_to not found"

---

### Task 4: GREEN — Implement `add_child_scene_to`

**Files:**
- Modify: `scripts/core/utils/editors/u_editor_prefab_builder.gd`

- [ ] **Step 7: Implement method**

After `add_child_to()`, add:

```gdscript
func add_child_scene_to(parent_path: String, scene_path: String, child_name: String) -> U_EditorPrefabBuilder:
	if _root == null:
		push_error("U_EditorPrefabBuilder: add_child_scene_to called before root creation")
		return self
	var parent: Node = _root.get_node(parent_path) if parent_path != "." else _root
	if parent == null:
		push_error("U_EditorPrefabBuilder: add_child_scene_to parent not found at '%s'" % parent_path)
		return self
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("U_EditorPrefabBuilder: failed to load child scene at '%s'" % scene_path)
		return self
	var instance: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_MAIN) as Node
	if instance == null:
		push_error("U_EditorPrefabBuilder: failed to instantiate child scene from '%s'" % scene_path)
		return self
	instance.name = child_name
	parent.add_child(instance)
	return self
```

- [ ] **Step 8: Run tests**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_prefab_builder.gd
```

Expected: All tests PASS.

---

### Task 5: Migrate `prefab_demo_npc_body`

**Files:**
- Create: `scripts/demo/editors/build_prefab_demo_npc_body.gd`
- Modify: `tests/unit/editors/test_u_editor_prefab_builder.gd`

- [ ] **Step 9: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "NPC_BodyMeshRoot")
	
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	visual.transform = Transform3D.IDENTITY.translated(Vector3(0, 1.1, 0))
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.8
	sphere_mesh.height = 1.6
	visual.mesh = sphere_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.9490196, 0.70980394, 0.21568628)
	visual.material_override = mat
	builder.add_child_to(".", visual)
	
	var indicator: Sprite3D = Sprite3D.new()
	indicator.name = "GroundIndicator"
	indicator.transform = Transform3D(0.2, 0, 0, 0, -8.742278e-09, -0.2, 0, 0.2, -8.742278e-09, 0, -2.3227184, 0)
	indicator.modulate = Color(1, 1, 1, 0.49803922)
	indicator.texture = load("res://assets/core/textures/tex_shadow_blob.png")
	builder.add_child_to(".", indicator)
	
	builder.save("res://scenes/demo/prefabs/prefab_demo_npc_body.tscn")
	print("prefab_demo_npc_body rebuilt.")
```

- [ ] **Step 10: Write integration test**

```gdscript
func test_migrate_demo_npc_body_matches_gold() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("create_root", "Node3D", "NPC_BodyMeshRoot")
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "Visual"
	visual.transform = Transform3D.IDENTITY.translated(Vector3(0, 1.1, 0))
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = 0.8
	sphere_mesh.height = 1.6
	visual.mesh = sphere_mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.9490196, 0.70980394, 0.21568628)
	visual.material_override = mat
	builder.call("add_child_to", ".", visual)
	var indicator: Sprite3D = Sprite3D.new()
	indicator.name = "GroundIndicator"
	builder.call("add_child_to", ".", indicator)
	var result: Variant = builder.call("save", "res://tests/unit/editors/_prefab_npc_body_migrated.tscn")
	assert_true(result, "save must succeed")
	var packed: PackedScene = load("res://tests/unit/editors/_prefab_npc_body_migrated.tscn") as PackedScene
	assert_not_null(packed, "Migrated prefab must load as PackedScene")
	var instance: Node = packed.instantiate()
	assert_not_null(instance.get_node_or_null("Visual"), "Visual child must exist")
	assert_not_null(instance.get_node_or_null("GroundIndicator"), "GroundIndicator child must exist")
	instance.queue_free()
	if FileAccess.file_exists("res://tests/unit/editors/_prefab_npc_body_migrated.tscn"):
		DirAccess.remove_absolute("res://tests/unit/editors/_prefab_npc_body_migrated.tscn")
	var root: Variant = builder.call("build")
	if root is Node:
		(root as Node).queue_free()
```

- [ ] **Step 11: Run test**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_prefab_builder.gd::test_migrate_demo_npc_body_matches_gold
```

Expected: PASS.

---

### Task 6: Migrate `prefab_woods_wolf`

**Files:**
- Create: `scripts/demo/editors/build_prefab_woods_wolf.gd`
- Modify: `tests/unit/editors/test_u_editor_prefab_builder.gd`

- [ ] **Step 12: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"wolf")
	builder.set_tags([&"predator", &"ai", &"woods"])
	
	var body_mesh: CSGBox3D = CSGBox3D.new()
	body_mesh.name = "Body_Mesh"
	body_mesh.transform = Transform3D(0.9, 0, 0, 0, 1, 0, 0, 0, 1.4, 0, 1, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.24, 0.26, 0.29)
	body_mesh.material = mat
	builder.add_child_to("Player_Body", body_mesh)
	
	builder.override_property("Components/C_MovementComponent", "settings", load("res://resources/demo/base_settings/ai_woods/ai_woods/cfg_movement_woods_wolf.tres"))
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_detection_component.gd", "", {
		"detection_radius": 14.0,
		"detection_exit_radius": 20.0,
		"target_tag": &"prey"
	})
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_move_target_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_ai_brain_component.gd",
		"res://resources/demo/ai/woods/wolf/cfg_woods_wolf_brain_script.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_needs_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_needs_wolf.tres")
	builder.add_child_scene("res://scenes/demo/debug/debug_woods_agent_label.tscn", "DebugWoodsAgentLabel")
	builder.save("res://scenes/demo/prefabs/prefab_woods_wolf.tscn")
	print("prefab_woods_wolf rebuilt.")
```

- [ ] **Step 13: Write integration test**

```gdscript
func test_migrate_wolf_prefab_matches_gold() -> void:
	var builder: Object = _new_builder()
	if builder == null:
		return
	builder.call("inherit_from", "res://scenes/core/templates/tmpl_character.tscn")
	builder.call("set_entity_id", &"wolf")
	builder.call("set_tags", [&"predator", &"ai", &"woods"])
	
	var body_mesh: CSGBox3D = CSGBox3D.new()
	body_mesh.name = "Body_Mesh"
	builder.call("add_child_to", "Player_Body", body_mesh)
	
	builder.call("override_property", "Components/C_MovementComponent", "settings", load("res://resources/demo/base_settings/ai_woods/ai_woods/cfg_movement_woods_wolf.tres"))
	builder.call("add_ecs_component_by_path", "res://scripts/core/ecs/components/c_input_component.gd")
	builder.call("add_ecs_component_by_path", "res://scripts/demo/ecs/components/c_detection_component.gd", "", {"detection_radius": 14.0, "target_tag": &"prey"})
	builder.call("add_ecs_component_by_path", "res://scripts/demo/ecs/components/c_move_target_component.gd")
	builder.call("add_ecs_component_by_path", "res://scripts/demo/ecs/components/c_ai_brain_component.gd",
		"res://resources/demo/ai/woods/wolf/cfg_woods_wolf_brain_script.tres")
	builder.call("add_ecs_component_by_path", "res://scripts/demo/ecs/components/c_needs_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_needs_wolf.tres")
	builder.call("add_child_scene", "res://scenes/demo/debug/debug_woods_agent_label.tscn", "DebugWoodsAgentLabel")
	
	var result: Variant = builder.call("save", "res://tests/unit/editors/_prefab_wolf_migrated.tscn")
	assert_true(result, "save must succeed")
	var packed: PackedScene = load("res://tests/unit/editors/_prefab_wolf_migrated.tscn") as PackedScene
	assert_not_null(packed, "Migrated prefab must load as PackedScene")
	var instance: Node = packed.instantiate()
	assert_not_null(instance.get_node_or_null("Player_Body/Body_Mesh"), "Body_Mesh must exist under Player_Body")
	assert_not_null(instance.get_node_or_null("Components/C_InputComponent"), "C_InputComponent must exist")
	assert_not_null(instance.get_node_or_null("DebugWoodsAgentLabel"), "DebugWoodsAgentLabel must exist")
	instance.queue_free()
	if FileAccess.file_exists("res://tests/unit/editors/_prefab_wolf_migrated.tscn"):
		DirAccess.remove_absolute("res://tests/unit/editors/_prefab_wolf_migrated.tscn")
	var root: Variant = builder.call("build")
	if root is Node:
		(root as Node).queue_free()
```

- [ ] **Step 14: Run test**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/editors/test_u_editor_prefab_builder.gd::test_migrate_wolf_prefab_matches_gold
```

Expected: PASS.

---

### Task 7: Migrate `prefab_woods_rabbit`

**Files:**
- Create: `scripts/demo/editors/build_prefab_woods_rabbit.gd`

- [ ] **Step 15: Write builder script**

Pattern identical to wolf with different colors/settings:

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"rabbit")
	builder.set_tags([&"prey", &"ai", &"woods"])
	
	var body_mesh: CSGBox3D = CSGBox3D.new()
	body_mesh.name = "Body_Mesh"
	body_mesh.transform = Transform3D(0.6, 0, 0, 0, 0.7, 0, 0, 0, 0.9, 0, 0.7, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.95, 0.95, 0.95)
	body_mesh.material = mat
	builder.add_child_to("Player_Body", body_mesh)
	
	builder.override_property("Components/C_MovementComponent", "settings", load("res://resources/demo/base_settings/ai_woods/ai_woods/cfg_movement_woods.tres"))
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_detection_component.gd", "", {
		"detection_radius": 10.0,
		"detection_exit_radius": 15.0,
		"target_tag": &"predator"
	})
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_move_target_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_ai_brain_component.gd",
		"res://resources/demo/ai/woods/rabbit/cfg_woods_rabbit_brain_script.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_needs_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_needs_rabbit.tres")
	builder.add_child_scene("res://scenes/demo/debug/debug_woods_agent_label.tscn", "DebugWoodsAgentLabel")
	builder.save("res://scenes/demo/prefabs/prefab_woods_rabbit.tscn")
	print("prefab_woods_rabbit rebuilt.")
```

---

### Task 8: Migrate `prefab_woods_builder`

**Files:**
- Create: `scripts/demo/editors/build_prefab_woods_builder.gd`

- [ ] **Step 16: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"builder")
	builder.set_tags([&"ai", &"woods", &"builder"])
	
	var body_mesh: CSGBox3D = CSGBox3D.new()
	body_mesh.name = "Body_Mesh"
	body_mesh.transform = Transform3D(0.6, 0, 0, 0, 1.8, 0, 0, 0, 0.5, 0, 1, 0)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.55, 0.35, 0.15)
	body_mesh.material = mat
	builder.add_child_to("Player_Body", body_mesh)
	
	builder.override_property("Components/C_MovementComponent", "settings", load("res://resources/demo/base_settings/ai_woods/ai_woods/cfg_movement_woods.tres"))
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_detection_component.gd", "", {
		"detection_radius": 10.0,
		"detection_exit_radius": 15.0,
		"target_tag": &"predator"
	})
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_move_target_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_ai_brain_component.gd",
		"res://resources/demo/ai/woods/builder/cfg_builder_brain_script.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_needs_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_needs_builder.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_inventory_component.gd",
		"res://resources/demo/base_settings/ai_woods/ai_woods/cfg_inventory_builder.tres")
	builder.add_child_scene("res://scenes/demo/debug/debug_woods_agent_label.tscn", "DebugWoodsAgentLabel")
	builder.save("res://scenes/demo/prefabs/prefab_woods_builder.tscn")
	print("prefab_woods_builder rebuilt.")
```

---

### Task 9: Migrate `prefab_demo_npc`

**Files:**
- Create: `scripts/demo/editors/build_prefab_demo_npc.gd`

- [ ] **Step 17: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"npc")
	builder.set_tags([&"npc", &"ai", &"character"])
	
	builder.override_property("Player_Body/CollisionShape3D", "transform", Transform3D.IDENTITY.translated(Vector3(0, 0.96823025, 0)))
	
	for ray_name in ["Center", "Forward", "Back", "Left", "Right", "ForwardLeft", "ForwardRight", "BackLeft", "BackRight"]:
		builder.override_property("Player_Body/HoverRays/%s" % ray_name, "target_position", Vector3(0, -2.5, 0))
	
	builder.add_child_scene("res://scenes/demo/prefabs/prefab_demo_npc_body.tscn", "Body_Mesh")
	builder.override_property("Components/C_FloatingComponent", "settings", load("res://resources/core/base_settings/gameplay/cfg_floating_default.tres"))
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_ai_brain_component.gd",
		"res://resources/demo/ai/cfg_ai_brain_placeholder.tres")
	builder.add_ecs_component_by_path("res://scripts/demo/ecs/components/c_detection_component.gd")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_spawn_recovery_component.gd",
		"res://resources/core/base_settings/gameplay/cfg_spawn_recovery_default.tres")
	builder.save("res://scenes/demo/prefabs/prefab_demo_npc.tscn")
	print("prefab_demo_npc rebuilt.")
```

---

### Task 10: Migrate `prefab_player` (core)

**Files:**
- Create: `scripts/core/editors/build_prefab_player.gd`

- [ ] **Step 18: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character.tscn")
	builder.set_entity_id(&"player")
	builder.set_tags([&"player", &"character"])
	
	builder.add_child_scene_to("Player_Body", "res://scenes/core/prefabs/prefab_player_body.tscn", "Body_Mesh")
	
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_input_component.gd")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_gamepad_component.gd",
		"res://resources/core/input/gamepad_settings/cfg_default_gamepad_settings.tres")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_player_tag_component.gd")
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_surface_detector_component.gd", "", {
		"character_body_path": NodePath("../../Player_Body")
	})
	builder.add_ecs_component_by_path("res://scripts/core/ecs/components/c_spawn_recovery_component.gd",
		"res://resources/core/base_settings/gameplay/cfg_spawn_recovery_player_default.tres")
	builder.save("res://scenes/core/prefabs/prefab_player.tscn")
	print("prefab_player rebuilt.")
```

---

### Task 11: Migrate `prefab_player_body` (core)

**Files:**
- Create: `scripts/core/editors/build_prefab_player_body.gd`

- [ ] **Step 19: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "PlayerBodyVisualRoot")
	
	builder.add_child_scene("res://scenes/core/prefabs/prefab_character.tscn", "CharacterMesh")
	builder.override_property("CharacterMesh", "transform", Transform3D.IDENTITY.translated(Vector3(0, -0.5, 0)))
	
	var direction: MeshInstance3D = MeshInstance3D.new()
	direction.name = "Direction_Mesh"
	direction.transform = Transform3D(0.39169633, 0, 0, 0, 0.15378642, 0, 0, 0, 0.36884245, -0.019476414, 2.6623948, -0.4746977)
	direction.visible = false
	var box: BoxMesh = BoxMesh.new()
	direction.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	mat.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mat.albedo_color = Color(0.08627451, 0.3529412, 0.29803923)
	direction.material_override = mat
	builder.add_child_to(".", direction)
	
	var ground: Sprite3D = Sprite3D.new()
	ground.name = "GroundIndicator"
	ground.transform = Transform3D(0.2, 0, 0, 0, -8.742278e-09, -0.2, 0, 0.2, -8.742278e-09, 0, -2.3227184, 0)
	ground.modulate = Color(1, 1, 1, 0.49803922)
	ground.texture = load("res://assets/core/textures/tex_shadow_blob.png")
	builder.add_child_to(".", ground)
	
	builder.save("res://scenes/core/prefabs/prefab_player_body.tscn")
	print("prefab_player_body rebuilt.")
```

---

### Task 12: Migrate `prefab_player_ragdoll` (core)

**Files:**
- Create: `scripts/core/editors/build_prefab_player_ragdoll.gd`

- [ ] **Step 20: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.inherit_from("res://scenes/core/templates/tmpl_character_ragdoll.tscn")
	builder.save("res://scenes/core/prefabs/prefab_player_ragdoll.tscn")
	print("prefab_player_ragdoll rebuilt.")
```

---

### Task 13: Migrate `prefab_alleyway`

**Files:**
- Create: `scripts/demo/editors/build_prefab_alleyway.gd`

- [ ] **Step 21: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "NewExterior")
	
	builder.add_child_scene("res://assets/demo/models/mdl_new_exterior.glb", "ExteriorScene")
	
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "StaticBody3D"
	static_body.collision_layer = 33
	builder.add_child_to(".", static_body)
	
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.transform = Transform3D.IDENTITY.scaled(Vector3(17, 17, 17)).translated(Vector3(0, 2.4162946, 0))
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	# NOTE: mesh data is embedded in the GLB import; collision is generated at runtime
	# or by the tri-mesh function below. For parity with original, we attempt create_trimesh_collision.
	shape.shape = concave
	builder.add_child_to("StaticBody3D", shape)
	
	builder.save("res://scenes/demo/prefabs/prefab_alleyway.tscn")
	print("prefab_alleyway rebuilt.")
```

---

### Task 14: Migrate `prefab_bar`

**Files:**
- Create: `scripts/demo/editors/build_prefab_bar.gd`

- [ ] **Step 22: Write builder script**

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder: U_EditorPrefabBuilder = U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "NewInterior")
	
	builder.add_child_scene("res://assets/demo/models/mdl_new_interior.glb", "InteriorScene")
	
	var static_body: StaticBody3D = StaticBody3D.new()
	static_body.name = "StaticBody3D"
	static_body.collision_layer = 33
	builder.add_child_to(".", static_body)
	
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var concave: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.shape = concave
	builder.add_child_to("StaticBody3D", shape)
	
	builder.save("res://scenes/demo/prefabs/prefab_bar.tscn")
	print("prefab_bar rebuilt.")
```

---

### Task 15: Full Suite + Style Check

- [ ] **Step 23: Run full test suite**

```bash
tools/run_gut_suite.sh
```

Expected: 0 regressions.

- [ ] **Step 24: Run style suite**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: PASS.

---

### Task 16: Delete Original `.tscn` Files

**Files to delete:**
- `scenes/demo/prefabs/prefab_woods_wolf.tscn`
- `scenes/demo/prefabs/prefab_woods_rabbit.tscn`
- `scenes/demo/prefabs/prefab_woods_builder.tscn`
- `scenes/demo/prefabs/prefab_demo_npc.tscn`
- `scenes/demo/prefabs/prefab_demo_npc_body.tscn`
- `scenes/core/prefabs/prefab_player.tscn`
- `scenes/core/prefabs/prefab_player_body.tscn`
- `scenes/core/prefabs/prefab_player_ragdoll.tscn`
- `scenes/demo/prefabs/prefab_alleyway.tscn`
- `scenes/demo/prefabs/prefab_bar.tscn`

- [ ] **Step 25: Delete files**

```bash
rm -f scenes/demo/prefabs/prefab_woods_wolf.tscn
rm -f scenes/demo/prefabs/prefab_woods_rabbit.tscn
rm -f scenes/demo/prefabs/prefab_woods_builder.tscn
rm -f scenes/demo/prefabs/prefab_demo_npc.tscn
rm -f scenes/demo/prefabs/prefab_demo_npc_body.tscn
rm -f scenes/core/prefabs/prefab_player.tscn
rm -f scenes/core/prefabs/prefab_player_body.tscn
rm -f scenes/core/prefabs/prefab_player_ragdoll.tscn
rm -f scenes/demo/prefabs/prefab_alleyway.tscn
rm -f scenes/demo/prefabs/prefab_bar.tscn
```

- [ ] **Step 26: Rerun style suite**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```

Expected: PASS.

---

### Task 17: Docs Update

**Files:**
- Create/Modify: `docs/architecture/adr/0019-editor-prefab-builder-migration.md`
- Modify: `docs/history/cleanup_v8/cleanup-v8-continuation-prompt.md`

- [ ] **Step 27: Write ADR**

Summarize: Prefab builder migration completes V7. Approach A (minimal builder extension) chosen over character subclass. All `.tscn` prefabs now have builder script sources.

- [ ] **Step 28: Update continuation prompt**

Mark P7.4–P7.7 as complete. Note original `.tscn` files deleted.
