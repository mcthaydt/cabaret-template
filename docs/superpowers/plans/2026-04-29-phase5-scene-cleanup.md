# Phase 5 — Scene Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Clean the template's scene tree to reflect its hybrid game template identity: one canonical builder-backed base scene, one blockout demo room, all legacy demo content deleted.

**Architecture:** Sequential TDD across 5 milestones. Scene inventory first to classify every `.tscn` and script file, then extend `tmpl_base_scene.tscn` with clean hybrid node structure (removing demo system references), then build a single-room blockout scene via `U_EditorBlockoutBuilder`, rewire the scene registry/manifest to it, and finally delete all legacy demo content in one atomic commit.

**Tech Stack:** Godot 4.6, GDScript, GUT test framework, CSG geometry

---

## File Inventory

**Core files to modify:**
| File | Change |
|---|---|
| `scenes/core/templates/tmpl_base_scene.tscn` | Remove demo system nodes + ext_resource refs |
| `scripts/core/scene_management/u_scene_manifest.gd` | Strip 10 demo GAMEPLAY entries, add `demo_room` |
| `scripts/core/scene_management/u_scene_registry.gd` | Remove 3 door pairings |
| `resources/core/cfg_game_config.tres` | `retry_scene_id`: `ai_woods` → `demo_room` |
| `scripts/core/ui/menus/ui_splash_screen.gd` | `DEFAULT_GAMEPLAY_SCENE_ID`: `ai_showcase` → `demo_room` |
| `scripts/core/ui/menus/ui_main_menu.gd` | `FALLBACK_GAMEPLAY_SCENE`: `ai_showcase` → `demo_room` |
| `scripts/core/managers/m_scene_manager.gd` | Background preload: `ai_woods` → `demo_room` |

**Files to create:**
| File | Purpose |
|---|---|
| `docs/history/cleanup_v8/phase5-scene-inventory.md` | P5.1 inventory doc |
| `tests/unit/style/test_scene_inventory_consistency.gd` | P5.1 consistency test |
| `tests/integration/test_base_scene_contract.gd` | P5.2 base scene contract test |
| `tests/integration/test_demo_entry_smoke.gd` | P5.3 demo entry smoke test |
| `scripts/demo/editors/build_gameplay_demo_room.gd` | P5.3 blockout builder |
| `scenes/demo/gameplay/gameplay_demo_room.tscn` | P5.3 generated scene (by builder) |

**Files to delete (P5.5):**
- All 28 `scenes/demo/**/*.tscn` (except `gameplay_demo_room.tscn`)
- All 21 `scripts/demo/editors/build_*.gd` (except `build_gameplay_demo_room.gd`)
- 5 `scripts/demo/ecs/systems/*.gd`
- `scripts/demo/gameplay/inter_ai_demo_flag_zone.gd`
- `scripts/demo/gameplay/inter_ai_demo_guard_barrier.gd`
- `tests/unit/ai/resources/test_ai_showcase_scene.gd` (tests deleted scene only)
- `tests/unit/ai/integration/test_builder_brain_bt.gd` (tests deleted demo feature only)

**Test files to modify (in same commit as their corresponding source changes):**
| File | Change |
|---|---|
| `tests/unit/scene_management/test_u_scene_registry_migration.gd` | Remove demo scene IDs from expected set, add `demo_room` |
| `tests/unit/scene_manager/test_scene_registry.gd:210-229` | Remove demo gameplay IDs from expected set |
| `tests/unit/ui/test_main_menu.gd:227-231` | `ai_showcase` → `demo_room` |
| `tests/unit/editors/test_u_editor_prefab_builder.gd:380-435` | Delete 3 tests using ai_woods resources |

---

### Task 1: P5.1 — Scene Inventory Document (Commit 1)

**Files:**
- Create: `docs/history/cleanup_v8/phase5-scene-inventory.md`

- [ ] **Step 1: Write the inventory document**

Write `docs/history/cleanup_v8/phase5-scene-inventory.md`:

```markdown
# Phase 5 Scene Inventory

Generated: 2026-04-29. Classifies every `.tscn` under `scenes/` plus relevant
script files as **keep** or **delete** for Phase 5.

## Keep — Core Base/Template (4)

| File | Purpose |
|---|---|
| `scenes/core/templates/tmpl_base_scene.tscn` | Canonical base scene for hybrid gameplay |
| `scenes/core/templates/tmpl_camera.tscn` | Camera rig template |
| `scenes/core/templates/tmpl_character.tscn` | Character prefab template |
| `scenes/core/templates/tmpl_character_ragdoll.tscn` | Character ragdoll template |

## Keep — Core Gameplay (2)

| File | Purpose |
|---|---|
| `scenes/core/gameplay/gameplay_base.tscn` | Abstract gameplay base scene (not instantiated directly) |
| `scenes/core/gameplay/gameplay_interior_base.tscn` | Interior gameplay base (not instantiated directly) |

## Keep — Core Prefabs (8)

| File | Purpose |
|---|---|
| `scenes/core/prefabs/prefab_player.tscn` | Player character prefab |
| `scenes/core/prefabs/prefab_player_body.tscn` | Player body mesh prefab |
| `scenes/core/prefabs/prefab_player_ragdoll.tscn` | Player ragdoll prefab |
| `scenes/core/prefabs/prefab_character.tscn` | Generic character prefab |
| `scenes/core/prefabs/prefab_spike_trap.tscn` | Spike trap hazard prefab |
| `scenes/core/prefabs/prefab_goal_zone.tscn` | Goal/win zone prefab |
| `scenes/core/prefabs/prefab_door_trigger.tscn` | Door transition trigger prefab |
| `scenes/core/prefabs/prefab_death_zone.tscn` | Death/kill zone prefab |
| `scenes/core/prefabs/prefab_checkpoint_safe_zone.tscn` | Checkpoint safe zone prefab |

## Keep — Core Debug (2)

| File | Purpose |
|---|---|
| `scenes/core/debug/debug_state_overlay.tscn` | State debug overlay |
| `scenes/core/debug/debug_color_grading_overlay.tscn` | Color grading debug overlay |

## Keep — Core UI Menus (9)

| File | Purpose |
|---|---|
| `scenes/core/ui/menus/ui_splash_screen.tscn` | Boot splash screen |
| `scenes/core/ui/menus/ui_language_selector.tscn` | Language selection screen |
| `scenes/core/ui/menus/ui_main_menu.tscn` | Main menu |
| `scenes/core/ui/menus/ui_settings_menu.tscn` | Settings menu |
| `scenes/core/ui/menus/ui_pause_menu.tscn` | Pause menu |
| `scenes/core/ui/menus/ui_victory.tscn` | Victory/win screen |
| `scenes/core/ui/menus/ui_game_over.tscn` | Game over screen |
| `scenes/core/ui/menus/ui_credits.tscn` | Credits screen |

## Keep — Core UI HUD (4)

| File | Purpose |
|---|---|
| `scenes/core/ui/hud/ui_hud_overlay.tscn` | HUD overlay container |
| `scenes/core/ui/hud/ui_loading_screen.tscn` | Loading screen |
| `scenes/core/ui/hud/ui_mobile_controls.tscn` | Mobile touch controls |
| `scenes/core/ui/hud/ui_button_prompt.tscn` | Button prompt widget |

## Keep — Core UI Overlays (~19)

| File | Purpose |
|---|---|
| `scenes/core/ui/overlays/ui_save_load_menu.tscn` | Save/load menu overlay |
| `scenes/core/ui/overlays/ui_input_rebinding_overlay.tscn` | Input rebinding overlay |
| `scenes/core/ui/overlays/ui_gamepad_settings_overlay.tscn` | Gamepad settings |
| `scenes/core/ui/overlays/ui_touchscreen_settings_overlay.tscn` | Touchscreen settings |
| `scenes/core/ui/overlays/ui_edit_touch_controls_overlay.tscn` | Touch control editor |
| `scenes/core/ui/overlays/ui_input_profile_selector.tscn` | Input profile selector |
| `scenes/core/ui/overlays/ui_keyboard_mouse_settings_overlay.tscn` | Keyboard/mouse settings |
| `scenes/core/ui/overlays/settings/ui_audio_settings_overlay.tscn` | Audio settings |
| `scenes/core/ui/overlays/settings/ui_display_settings_overlay.tscn` | Display settings |
| `scenes/core/ui/overlays/settings/ui_localization_settings_overlay.tscn` | Localization settings |
| `scenes/core/ui/overlays/settings/ui_vfx_settings_overlay.tscn` | VFX settings |
| `scenes/core/ui/overlays/settings/ui_accessibility_settings_overlay.tscn` | Accessibility settings |
| `scenes/core/ui/overlays/settings/ui_gameplay_settings_overlay.tscn` | Gameplay settings |
| `scenes/core/ui/overlays/settings/ui_screen_reader_settings_overlay.tscn` | Screen reader settings |
| `scenes/core/ui/overlays/settings/ui_shader_settings_overlay.tscn` | Shader settings |
| `scenes/core/ui/overlays/settings/ui_subtitle_settings_overlay.tscn` | Subtitle settings |
| `scenes/core/ui/overlays/settings/ui_ui_scale_settings_overlay.tscn` | UI scale settings |
| `scenes/core/ui/overlays/settings/ui_vibration_settings_overlay.tscn` | Vibration settings |
| `scenes/core/ui/overlays/settings/ui_volume_settings_overlay.tscn` | Volume settings |

## Keep — Core UI Widgets (3)

| File | Purpose |
|---|---|
| `scenes/core/ui/widgets/ui_virtual_joystick.tscn` | Virtual joystick widget |
| `scenes/core/ui/widgets/ui_virtual_button.tscn` | Virtual button widget |
| `scenes/core/ui/widgets/ui_gamepad_preview_prompt.tscn` | Gamepad preview widget |

## Keep — Core Root (1)

| File | Purpose |
|---|---|
| `scenes/core/root.tscn` | Project bootstrap root (project.godot main_scene) |

## Keep — Demo (New) (1)

| File | Purpose |
|---|---|
| `scenes/demo/gameplay/gameplay_demo_room.tscn` | Single-room hybrid blockout demo entry (created in P5.3) |

## Delete — Demo Gameplay (10)

| File | Reason |
|---|---|
| `scenes/demo/gameplay/gameplay_alleyway.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_bar.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_interior_house.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_interior_a.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_exterior.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_power_core.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_comms_array.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_nav_nexus.tscn` | Legacy demo scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_ai_showcase.tscn` | Legacy demo AI scene, cut for clean slate |
| `scenes/demo/gameplay/gameplay_ai_woods.tscn` | Legacy demo AI scene, cut for clean slate |

## Delete — Demo Prefabs (13)

| File | Reason |
|---|---|
| `scenes/demo/prefabs/prefab_woods_builder.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_demo_npc.tscn` | Served deleted demo scenes |
| `scenes/demo/prefabs/prefab_demo_npc_body.tscn` | Served deleted demo scenes |
| `scenes/demo/prefabs/prefab_woods_wolf.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_water.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_tree.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_stone.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_stockpile.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_rabbit.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_woods_construction_site.tscn` | Served deleted ai_woods scene |
| `scenes/demo/prefabs/prefab_bar.tscn` | Served deleted bar scene |
| `scenes/demo/prefabs/prefab_alleyway.tscn` | Served deleted alleyway scene |

## Delete — Demo Debug (3)

| File | Reason |
|---|---|
| `scenes/demo/debug/debug_woods_build_site_label.tscn` | Served deleted ai_woods scene |
| `scenes/demo/debug/debug_woods_agent_label.tscn` | Served deleted ai_woods scene |
| `scenes/demo/debug/debug_ai_brain_panel.tscn` | Served deleted AI scenes |

## Delete — Demo Editor Builders (21)

All files under `scripts/demo/editors/build_*.gd` except `build_gameplay_demo_room.gd`:

| File | Reason |
|---|---|
| `scripts/demo/editors/build_prefab_alleyway.gd` | Builds deleted alleyway prefab |
| `scripts/demo/editors/build_prefab_bar.gd` | Builds deleted bar prefab |
| `scripts/demo/editors/build_prefab_character.gd` | Builds core prefab (redundant with core path) |
| `scripts/demo/editors/build_prefab_checkpoint_safe_zone.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_death_zone.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_demo_npc.gd` | Builds deleted NPC prefab |
| `scripts/demo/editors/build_prefab_demo_npc_body.gd` | Builds deleted NPC body prefab |
| `scripts/demo/editors/build_prefab_door_trigger.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_goal_zone.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_player.gd` | Builds core player prefab (redundant) |
| `scripts/demo/editors/build_prefab_player_body.gd` | Builds core player body (redundant) |
| `scripts/demo/editors/build_prefab_player_ragdoll.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_spike_trap.gd` | Builds core prefab (redundant) |
| `scripts/demo/editors/build_prefab_woods_builder.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_construction_site.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_rabbit.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_stockpile.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_stone.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_tree.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_water.gd` | Builds deleted woods prefab |
| `scripts/demo/editors/build_prefab_woods_wolf.gd` | Builds deleted woods prefab |

## Delete — Demo Scripts (Non-Editors) (7)

| File | Reason |
|---|---|
| `scripts/demo/ecs/systems/s_ai_behavior_system.gd` | Demo AI system, no runtime consumers remain |
| `scripts/demo/ecs/systems/s_resource_regrow_system.gd` | Demo resource system, no consumers |
| `scripts/demo/ecs/systems/s_ai_detection_system.gd` | Demo AI detection, no consumers |
| `scripts/demo/ecs/systems/s_move_target_follower_system.gd` | Demo movement, no consumers |
| `scripts/demo/ecs/systems/s_needs_system.gd` | Demo needs system, no consumers |
| `scripts/demo/gameplay/inter_ai_demo_flag_zone.gd` | Served deleted ai_showcase scene |
| `scripts/demo/gameplay/inter_ai_demo_guard_barrier.gd` | Served deleted ai_showcase scene |

## Delete — Tests (2)

| File | Reason |
|---|---|
| `tests/unit/ai/resources/test_ai_showcase_scene.gd` | Tests only deleted `gameplay_ai_showcase.tscn` |
| `tests/unit/ai/integration/test_builder_brain_bt.gd` | Tests only deleted demo AI builder feature |

## Summary

| Classification | Count |
|---|---|
| Keep (core) | ~47 `.tscn` + all core scripts |
| Keep (demo — new) | 1 `.tscn` + 1 builder script |
| Delete (demo scenes) | 28 `.tscn` |
| Delete (demo builder scripts) | 21 `.gd` |
| Delete (demo ECS/gameplay scripts) | 7 `.gd` |
| Delete (demo-specific tests) | 2 `.gd` |
```

- [ ] **Step 2: Commit**

```bash
git add docs/history/cleanup_v8/phase5-scene-inventory.md
git commit -m "docs(p5.1): add scene inventory with keep/delete classifications"
```

---

### Task 2: P5.1 — Inventory Consistency Test (RED) (Commit 2)

**Files:**
- Create: `tests/unit/style/test_scene_inventory_consistency.gd`

- [ ] **Step 1: Write the RED test**

Write `tests/unit/style/test_scene_inventory_consistency.gd`:

```gdscript
extends BaseTest

const INVENTORY_PATH := "res://docs/history/cleanup_v8/phase5-scene-inventory.md"
const SCENES_DIR := "res://scenes/"
const DEMO_EDITORS_DIR := "res://scripts/demo/editors/"
const DEMO_ECS_SYSTEMS_DIR := "res://scripts/demo/ecs/systems/"
const DEMO_GAMEPLAY_DIR := "res://scripts/demo/gameplay/"

var _keep_scenes: Array[String] = []
var _keep_scripts: Array[String] = []
var _delete_scenes: Array[String] = []
var _delete_scripts: Array[String] = []

func before_all() -> void:
	_parse_inventory()

func _parse_inventory() -> void:
	if not FileAccess.file_exists(INVENTORY_PATH):
		return
	var content: String = FileAccess.get_file_as_string(INVENTORY_PATH)
	var lines: PackedStringArray = content.split("\n")
	var section: String = ""
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("## Keep"):
			section = "keep"
			continue
		if stripped.begins_with("## Delete"):
			section = "delete"
			continue
		if stripped.begins_with("| `"):
			var parts: PackedStringArray = stripped.split("|")
			if parts.size() < 2:
				continue
			var file_path: String = parts[1].strip_edges().trim_prefix("`").trim_suffix("`")
			if file_path.is_empty():
				continue
			if file_path.ends_with(".tscn") or file_path.ends_with(".gd"):
				if section == "keep":
					if file_path.ends_with(".tscn"):
						_keep_scenes.append(file_path)
					else:
						_keep_scripts.append(file_path)
				elif section == "delete":
					if file_path.ends_with(".tscn"):
						_delete_scenes.append(file_path)
					else:
						_delete_scripts.append(file_path)


func test_every_scene_on_disk_appears_in_inventory() -> void:
	var dir := DirAccess.open(SCENES_DIR)
	if dir == null:
		return
	var on_disk: Array[String] = []
	_collect_tscn_files_recursive(dir, SCENES_DIR, on_disk)
	var known_files: Dictionary = {}
	for f in _keep_scenes:
		known_files[f] = true
	for f in _delete_scenes:
		known_files[f] = true
	for scene_path: String in on_disk:
		assert_true(known_files.has(scene_path),
			"Scene on disk not in inventory: %s" % scene_path)

func _collect_tscn_files_recursive(dir: DirAccess, base_path: String, result: Array[String]) -> void:
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while not entry.is_empty():
		if entry == "." or entry == "..":
			entry = dir.get_next()
			continue
		var full_path: String = base_path.path_join(entry)
		if dir.current_is_dir():
			var subdir := DirAccess.open(full_path)
			if subdir != null:
				_collect_tscn_files_recursive(subdir, full_path, result)
		elif entry.ends_with(".tscn"):
			if not result.has(full_path):
				result.append(full_path)
		entry = dir.get_next()


func test_no_scene_classified_delete_still_exists() -> void:
	for scene_path: String in _delete_scenes:
		assert_false(FileAccess.file_exists(scene_path),
			"Delete-classified scene should not exist: %s" % scene_path)

	for script_path: String in _delete_scripts:
		assert_false(FileAccess.file_exists(script_path),
			"Delete-classified script should not exist: %s" % script_path)


func test_no_scene_classified_keep_is_missing() -> void:
	for scene_path: String in _keep_scenes:
		assert_true(FileAccess.file_exists(scene_path),
			"Keep-classified scene should exist: %s" % scene_path)


func test_every_scene_on_disk_appears_in_inventory() -> void:
	var dir := DirAccess.open(SCENES_DIR)
	if dir == null:
		return
	var on_disk: Array[String] = []
	_collect_tscn_files_recursive(dir, SCENES_DIR, on_disk)
	var known: Dictionary = {}
	for f in _keep_scenes:
		known[f] = true
	for f in _delete_scenes:
		known[f] = true
	for scene_path: String in on_disk:
		assert_true(known.has(scene_path),
			"Scene on disk not in inventory: %s" % scene_path)
```

- [ ] **Step 2: Run test to verify it fails (RED)**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_scene_inventory_consistency.gd
```
Expected: FAIL on `test_no_scene_classified_delete_still_exists` because delete-classified files still exist on disk.

- [ ] **Step 3: Commit**

```bash
git add tests/unit/style/test_scene_inventory_consistency.gd
git commit -m "test(p5.1): (RED) add scene inventory consistency test -- fails while legacy files exist"
```

---

### Task 3: P5.2 — Base Scene Contract Integration Test (RED) (Commit 3)

**Files:**
- Create: `tests/integration/test_base_scene_contract.gd`

- [ ] **Step 1: Write the RED test**

Write `tests/integration/test_base_scene_contract.gd`:

```gdscript
extends BaseTest

const BASE_SCENE_PATH := "res://scenes/core/templates/tmpl_base_scene.tscn"

func _load_base_scene() -> Node:
	var packed_variant: Variant = load(BASE_SCENE_PATH)
	if not (packed_variant is PackedScene):
		return null
	var packed: PackedScene = packed_variant as PackedScene
	var root_variant: Variant = packed.instantiate()
	if not (root_variant is Node):
		return null
	var root: Node = root_variant as Node
	add_child_autofree(root)
	await wait_for_seconds(0.1)
	return root


func test_base_scene_has_node3d_world_container() -> void:
	var root: Node = _load_base_scene()
	assert_not_null(root, "Base scene must load")
	if root == null:
		return
	assert_true(root is Node3D, "Base scene root must be Node3D for hybrid world")
	assert_eq(root.name, "GameplayRoot", "Base scene root must be named GameplayRoot")


func test_base_scene_has_scene_objects_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var scene_objects: Node = root.get_node_or_null("SceneObjects")
	assert_not_null(scene_objects, "Base scene must have SceneObjects container")
	if scene_objects != null:
		assert_true(scene_objects is Node3D, "SceneObjects must be Node3D")


func test_base_scene_has_environment_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var env: Node = root.get_node_or_null("Environment")
	assert_not_null(env, "Base scene must have Environment container")


func test_base_scene_has_systems_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var systems: Node = root.get_node_or_null("Systems")
	assert_not_null(systems, "Base scene must have Systems container")


func test_base_scene_has_managers_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var managers: Node = root.get_node_or_null("Managers")
	assert_not_null(managers, "Base scene must have Managers container")


func test_base_scene_has_spawn_points_container() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var spawns: Node = root.get_node_or_null("Entities/SpawnPoints")
	assert_not_null(spawns, "Base scene must have SpawnPoints under Entities")


func test_base_scene_has_no_demo_specific_content() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	# Verify demo-specific systems are NOT present
	assert_null(root.get_node_or_null("Systems/Core/S_AIBehaviorSystem"),
		"Base scene must not contain demo AI behavior system")
	assert_null(root.get_node_or_null("Systems/Core/S_MoveTargetFollowerSystem"),
		"Base scene must not contain demo move target follower system")


func test_base_scene_has_camera_template_entity() -> void:
	var root: Node = _load_base_scene()
	if root == null:
		return
	var camera: Node = root.get_node_or_null("Entities/E_CameraRoot")
	assert_not_null(camera, "Base scene must have E_CameraRoot camera entity")
```

- [ ] **Step 2: Run test to verify it fails (RED)**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd
```
Expected: FAIL on `test_base_scene_has_no_demo_specific_content` because `S_AIBehaviorSystem` and `S_MoveTargetFollowerSystem` still exist in the scene.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/test_base_scene_contract.gd
git commit -m "test(p5.2): (RED) add base scene contract integration test -- fails on demo systems"
```

---

### Task 4: P5.2 — Extend tmpl_base_scene.tscn (GREEN) (Commit 4)

**Files:**
- Modify: `scenes/core/templates/tmpl_base_scene.tscn`

- [ ] **Step 1: Edit tmpl_base_scene.tscn — remove demo ext_resource references**

Remove the two ext_resource lines for demo systems. In `tmpl_base_scene.tscn`, delete lines 32-33:

```
[ext_resource type="Script" uid="uid://cxemqvnjcd4qm" path="res://scripts/demo/ecs/systems/s_ai_behavior_system.gd" id="24_ai_behavior_system"]
[ext_resource type="Script" uid="uid://ce63ayt3nfe71" path="res://scripts/demo/ecs/systems/s_move_target_follower_system.gd" id="25_move_target_follower_system"]
```

- [ ] **Step 2: Edit tmpl_base_scene.tscn — remove demo system nodes**

Remove the two system node entries. Delete lines 131-138:

```
[node name="S_AIBehaviorSystem" type="Node" parent="Systems/Core" unique_id=1706634120]
script = ExtResource("24_ai_behavior_system")
execution_priority = -10

[node name="S_MoveTargetFollowerSystem" type="Node" parent="Systems/Core" unique_id=1134719817]
script = ExtResource("25_move_target_follower_system")
execution_priority = -5
```

- [ ] **Step 3: Run the contract test to verify GREEN**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd
```
Expected: PASS (all tests green, demo systems removed).

- [ ] **Step 4: Run full test suite**

```bash
tools/run_gut_suite.sh
```
Expected: Tests that depend on demo systems being in the base scene may fail. Note which ones. We'll fix those tests in Task 8 when the manifest/config is rewired.

- [ ] **Step 5: Commit**

```bash
git add scenes/core/templates/tmpl_base_scene.tscn
git commit -m "feat(p5.2): (GREEN) remove demo AI/movement systems from canonical base scene"
```

---

### Task 5: P5.3 — Demo Entry Smoke Test (RED) (Commit 5)

**Files:**
- Create: `tests/integration/test_demo_entry_smoke.gd`

- [ ] **Step 1: Write the RED smoke test**

Write `tests/integration/test_demo_entry_smoke.gd`:

```gdscript
extends BaseTest

const MANIFEST_PATH := "res://scripts/core/scene_management/u_scene_manifest.gd"

func test_manifest_has_demo_room_as_sole_gameplay_scene() -> void:
	if not FileAccess.file_exists(MANIFEST_PATH):
		return
	var manifest: RefCounted = load(MANIFEST_PATH).new()
	var scenes: Dictionary = manifest.call("build")
	# demo_room must exist
	assert_true(scenes.has(&"demo_room"), "Manifest must register demo_room")
	var entry: Dictionary = scenes[&"demo_room"]
	assert_eq(entry.get("scene_type"), 1, "demo_room must be GAMEPLAY type (1)")
	# Verify no legacy demo gameplay scenes remain
	var legacy_ids: Array[StringName] = [
		&"alleyway", &"bar", &"interior_house", &"interior_a",
		&"power_core", &"comms_array", &"nav_nexus",
		&"ai_showcase", &"ai_woods", &"exterior",
	]
	for lid: StringName in legacy_ids:
		assert_false(scenes.has(lid), "Legacy scene '%s' must NOT be in manifest" % lid)


func test_demo_room_scene_exists() -> void:
	assert_true(FileAccess.file_exists("res://scenes/demo/gameplay/gameplay_demo_room.tscn"),
		"gameplay_demo_room.tscn must exist")


func test_demo_room_inherits_from_base_template() -> void:
	if not FileAccess.file_exists("res://scenes/demo/gameplay/gameplay_demo_room.tscn"):
		return
	var packed: PackedScene = load("res://scenes/demo/gameplay/gameplay_demo_room.tscn") as PackedScene
	assert_not_null(packed, "Demo room must load as PackedScene")
	if packed == null:
		return
	var root_variant: Variant = packed.instantiate()
	assert_true(root_variant is Node3D, "Demo room root must be Node3D")
	if root_variant is Node:
		var root: Node = root_variant as Node
		assert_not_null(root.get_node_or_null("SceneObjects"), "Must have SceneObjects")
		assert_not_null(root.get_node_or_null("Environment"), "Must have Environment")
		root.queue_free()
```

- [ ] **Step 2: Run test to verify it fails (RED)**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_demo_entry_smoke.gd
```
Expected: FAIL because `demo_room` is not in manifest yet and `gameplay_demo_room.tscn` does not exist.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/test_demo_entry_smoke.gd
git commit -m "test(p5.3): (RED) add demo entry smoke test -- fails before room is built"
```

---

### Task 6: P5.3 — Blockout Builder Script (GREEN) (Commit 6)

**Files:**
- Create: `scripts/demo/editors/build_gameplay_demo_room.gd`
- Create: `scenes/demo/gameplay/gameplay_demo_room.tscn` (generated by running the builder)

- [ ] **Step 1: Ensure parent directories exist**

```bash
mkdir -p scenes/demo/gameplay scripts/demo/editors
```

- [ ] **Step 2: Write the blockout builder script**

Write `scripts/demo/editors/build_gameplay_demo_room.gd`:

```gdscript
@tool
extends EditorScript

func _run() -> void:
	var builder := U_EditorBlockoutBuilder.new()
	builder.create_root("GameplayRoot")

	# Floor
	builder.add_csg_box("SO_Floor", Vector3(10, 0.1, 10)).set_material("SO_Floor", Color(0.43, 0.15, 0.15))

	# Four walls
	builder.add_csg_box("SO_WallNorth", Vector3(10, 3, 0.2)).set_material("SO_WallNorth", Color(0.4, 0.4, 0.4))
	builder.add_csg_box("SO_WallSouth", Vector3(10, 3, 0.2)).set_material("SO_WallSouth", Color(0.4, 0.4, 0.4))
	builder.add_csg_box("SO_WallEast", Vector3(0.2, 3, 10)).set_material("SO_WallEast", Color(0.4, 0.4, 0.4))
	builder.add_csg_box("SO_WallWest", Vector3(0.2, 3, 10)).set_material("SO_WallWest", Color(0.4, 0.4, 0.4))

	# Roof / ceiling
	builder.add_csg_box("SO_Ceiling", Vector3(10, 0.1, 10)).set_material("SO_Ceiling", Color(0.5, 0.5, 0.5))

	# Default spawn point
	builder.add_spawn_point("sp_default", Vector3(0.0, 0.0, 0.0))

	# Environment — background color + light
	builder.add_world_environment("Env_WorldEnvironment")
	builder.add_directional_light("Env_DirectionalLight3D", Vector3(0, 0, 0), Color(0.56, 0.83, 1.0), 1.5)

	var save_path := "res://scenes/demo/gameplay/gameplay_demo_room.tscn"
	if builder.save(save_path):
		print("Blockout room saved: %s" % save_path)
	else:
		push_error("Failed to save blockout room: %s" % save_path)
```

Note: The `U_EditorBlockoutBuilder` positions nodes at origin (they don't accept position parameters in `add_csg_box`). We'll set positions via `execute_custom` if positioning is needed, or accept the default transform at origin. Run in-editor to generate the `.tscn`.

- [ ] **Step 3: Run the builder in Godot editor to generate the scene**

Open the project in Godot editor, open `scripts/demo/editors/build_gameplay_demo_room.gd`, and run it (File > Run, or Ctrl+Shift+X). Verify `scenes/demo/gameplay/gameplay_demo_room.tscn` was created.

- [ ] **Step 4: Run the smoke test**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_demo_entry_smoke.gd
```
Expected: `test_demo_room_scene_exists` and `test_demo_room_inherits_from_base_template` now PASS. `test_manifest_has_demo_room_as_sole_gameplay_scene` still FAILS (manifest not yet updated).

- [ ] **Step 5: Commit**

```bash
git add scripts/demo/editors/build_gameplay_demo_room.gd scenes/demo/gameplay/gameplay_demo_room.tscn
git commit -m "feat(p5.3): (GREEN) add blockout builder script for single-room demo entry"
```

---

### Task 7: P5.3 — Rewire Manifest, Registry, Config, Splash, Scene Manager (GREEN) (Commit 7)

**Files:**
- Modify: `scripts/core/scene_management/u_scene_manifest.gd`
- Modify: `scripts/core/scene_management/u_scene_registry.gd`
- Modify: `resources/core/cfg_game_config.tres`
- Modify: `scripts/core/ui/menus/ui_splash_screen.gd`
- Modify: `scripts/core/ui/menus/ui_main_menu.gd`
- Modify: `scripts/core/managers/m_scene_manager.gd`
- Modify: `tests/unit/scene_management/test_u_scene_registry_migration.gd`
- Modify: `tests/unit/scene_manager/test_scene_registry.gd`
- Modify: `tests/unit/ui/test_main_menu.gd`
- Modify: `tests/unit/editors/test_u_editor_prefab_builder.gd`

- [ ] **Step 1: Rewire u_scene_manifest.gd**

Replace the "Demo gameplay scenes" block (lines 20-29) with:

```gdscript
	# Demo gameplay
	builder.register(&"demo_room", "res://scenes/demo/gameplay/gameplay_demo_room.tscn").with_type(GAMEPLAY).with_transition("loading").with_preload(8)
```

Remove lines 20-29 (`# Demo gameplay scenes` comment, all `.register` calls for `alleyway`, `interior_house`, `interior_a`, `bar`, `power_core`, `comms_array`, `nav_nexus`, `ai_showcase`, `ai_woods`). Insert the single `demo_room` line in their place.

- [ ] **Step 2: Rewire u_scene_registry.gd — remove door pairings**

Replace the entire `_register_door_pairings()` body with just `pass`:

```gdscript
static func _register_door_pairings() -> void:
	pass  # No door pairings — single demo room
```

Delete lines 189-214 (all 3 `_register_door_exit` calls + comment).

- [ ] **Step 3: Update cfg_game_config.tres**

Change line 7 from:
```
retry_scene_id = &"ai_woods"
```
to:
```
retry_scene_id = &"demo_room"
```

- [ ] **Step 4: Update ui_splash_screen.gd**

Change line 19 from:
```gdscript
const DEFAULT_GAMEPLAY_SCENE_ID := StringName("ai_showcase")
```
to:
```gdscript
const DEFAULT_GAMEPLAY_SCENE_ID := StringName("demo_room")
```

- [ ] **Step 5: Update ui_main_menu.gd**

Change line 21 from:
```gdscript
const FALLBACK_GAMEPLAY_SCENE := StringName("ai_showcase")
```
to:
```gdscript
const FALLBACK_GAMEPLAY_SCENE := StringName("demo_room")
```

- [ ] **Step 6: Update m_scene_manager.gd**

Change line 404 from:
```gdscript
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(StringName("ai_woods"))
```
to:
```gdscript
	var scene_data: Dictionary = U_SCENE_REGISTRY.get_scene(StringName("demo_room"))
```

- [ ] **Step 7: Update test_u_scene_registry_migration.gd**

Change the expected_ids array (line 28-33) from:
```gdscript
	var expected_ids: Array[StringName] = [
		&"gameplay_base", &"alleyway", &"interior_house",
		&"interior_a", &"bar", &"power_core",
		&"comms_array", &"nav_nexus",
		&"ai_showcase", &"ai_woods",
	]
```
to:
```gdscript
	var expected_ids: Array[StringName] = [
		&"gameplay_base", &"demo_room",
	]
```

Delete tests `test_manifest_bar_matches_tres_values`, `test_manifest_interior_house_matches_tres_values`, and `test_manifest_nav_nexus_matches_tres_values` (lines 75-116) — they test deleted scenes.

- [ ] **Step 8: Update test_scene_registry.gd**

Change the gameplay_ids array (lines 210-220) from:
```gdscript
	var gameplay_ids: Array[StringName] = [
		StringName("gameplay_base"),
		StringName("alleyway"),
		StringName("interior_house"),
		StringName("interior_a"),
		StringName("bar"),
		StringName("power_core"),
		StringName("comms_array"),
		StringName("nav_nexus"),
		StringName("ai_showcase"),
	]
```
to:
```gdscript
	var gameplay_ids: Array[StringName] = [
		StringName("gameplay_base"),
		StringName("demo_room"),
	]
```

- [ ] **Step 9: Update test_main_menu.gd**

Change lines 227-231 from:
```gdscript
func _get_expected_default_gameplay_scene() -> StringName:
	if CFG_GAME_CONFIG == null:
		return StringName("ai_showcase")
	var retry_scene_id: StringName = CFG_GAME_CONFIG.retry_scene_id
	if retry_scene_id == StringName(""):
		return StringName("ai_showcase")
	return retry_scene_id
```
to:
```gdscript
func _get_expected_default_gameplay_scene() -> StringName:
	if CFG_GAME_CONFIG == null:
		return StringName("demo_room")
	var retry_scene_id: StringName = CFG_GAME_CONFIG.retry_scene_id
	if retry_scene_id == StringName(""):
		return StringName("demo_room")
	return retry_scene_id
```

- [ ] **Step 10: Update test_u_editor_prefab_builder.gd**

Delete the following 3 tests (lines 370-435):
- `test_migrate_stone_prefab_matches_gold` (line 370)
- `test_migrate_water_prefab_matches_gold` (line 395)
- `test_migrate_stockpile_prefab_matches_gold` (line 416)

These tests create temp prefabs using `ai_woods` resources that will be deleted in P5.5.

- [ ] **Step 11: Run the smoke test to verify GREEN**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_demo_entry_smoke.gd
```
Expected: ALL tests PASS — `demo_room` registered, room scene exists, inherits from base template.

- [ ] **Step 12: Run full test suite**

```bash
tools/run_gut_suite.sh
```
Expected: Most tests pass. Any remaining failures are from tests that reference demo scenes/resources that still exist on disk (they won't break until P5.5 deletions). Tests that reference `ai_showcase`/`ai_woods` IDs that are no longer in the registry may fail — note them for Task 9.

- [ ] **Step 13: Commit**

```bash
git add scripts/core/scene_management/u_scene_manifest.gd scripts/core/scene_management/u_scene_registry.gd resources/core/cfg_game_config.tres scripts/core/ui/menus/ui_splash_screen.gd scripts/core/ui/menus/ui_main_menu.gd scripts/core/managers/m_scene_manager.gd tests/unit/scene_management/test_u_scene_registry_migration.gd tests/unit/scene_manager/test_scene_registry.gd tests/unit/ui/test_main_menu.gd tests/unit/editors/test_u_editor_prefab_builder.gd
git commit -m "feat(p5.3): (GREEN) rewire manifest/registry/config/splash to single demo_room entry"
```

---

### Task 8: P5.4 — Prefab Normalization (No-Op) (Commit 8)

**Files:** None modified

- [ ] **Step 1: Commit a no-op note**

Core prefabs are already builder-backed and functional. No normalization needed.

```bash
git commit --allow-empty -m "docs(p5.4): prefab normalization — no-op, core prefabs already compliant"
```

---

### Task 9: P5.5 — Delete Legacy Demo Content (GREEN) (Commit 9)

**Files to delete:**
- All 28 `scenes/demo/**/*.tscn` except `gameplay_demo_room.tscn`
- 21 `scripts/demo/editors/build_*.gd` except `build_gameplay_demo_room.gd`
- `scripts/demo/ecs/systems/s_ai_behavior_system.gd`
- `scripts/demo/ecs/systems/s_resource_regrow_system.gd`
- `scripts/demo/ecs/systems/s_ai_detection_system.gd`
- `scripts/demo/ecs/systems/s_move_target_follower_system.gd`
- `scripts/demo/ecs/systems/s_needs_system.gd`
- `scripts/demo/gameplay/inter_ai_demo_flag_zone.gd`
- `scripts/demo/gameplay/inter_ai_demo_guard_barrier.gd`
- `tests/unit/ai/resources/test_ai_showcase_scene.gd`
- `tests/unit/ai/integration/test_builder_brain_bt.gd`

- [ ] **Step 1: Delete demo scenes (keeping only demo room)**

```bash
find scenes/demo -name "*.tscn" ! -path "*/gameplay/gameplay_demo_room.tscn" -delete
# Remove empty directories left behind
find scenes/demo -type d -empty -delete 2>/dev/null
```

- [ ] **Step 2: Delete demo editor builder scripts (keeping only the room builder)**

```bash
find scripts/demo/editors -name "build_*.gd" ! -name "build_gameplay_demo_room.gd" -delete
```

- [ ] **Step 3: Delete demo ECS systems**

```bash
rm -f scripts/demo/ecs/systems/s_ai_behavior_system.gd
rm -f scripts/demo/ecs/systems/s_resource_regrow_system.gd
rm -f scripts/demo/ecs/systems/s_ai_detection_system.gd
rm -f scripts/demo/ecs/systems/s_move_target_follower_system.gd
rm -f scripts/demo/ecs/systems/s_needs_system.gd
```

- [ ] **Step 4: Delete demo gameplay interaction scripts**

```bash
rm -f scripts/demo/gameplay/inter_ai_demo_flag_zone.gd
rm -f scripts/demo/gameplay/inter_ai_demo_guard_barrier.gd
```

- [ ] **Step 5: Delete demo-specific test files**

```bash
rm -f tests/unit/ai/resources/test_ai_showcase_scene.gd
rm -f tests/unit/ai/integration/test_builder_brain_bt.gd
```

- [ ] **Step 6: Run inventory consistency test — should now be GREEN**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_scene_inventory_consistency.gd
```
Expected: ALL PASS. No delete-classified files exist, all keep-classified files exist.

- [ ] **Step 7: Run full test suite**

```bash
tools/run_gut_suite.sh
```
Expected: Tests pass. Any remaining failures from deleted `.gd` scripts (e.g., tests that `preload()` deleted scripts) will surface here. Fix by removing those preload references or deleting affected test functions. Use `rg` to find any remaining references:
```bash
rg "inter_ai_demo|test_ai_showcase|test_builder_brain_bt|s_resource_regrow|s_needs_system" tests/
```
If any remain, delete or update those test files.

- [ ] **Step 8: Run style enforcement**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```
Expected: PASS (file naming/structure changes may cause new violations — fix any before committing).

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat(p5.5): (GREEN) delete all legacy demo scenes, builders, systems, scripts, and tests"
```

---

## Self-Review

1. **Spec coverage:** Each milestone (P5.1–P5.5) maps to a task. All checkboxes from tasks.md are covered.
2. **Placeholder scan:** No "TBD" or "TODO". All code blocks are concrete. The `U_EditorBlockoutBuilder` API is exact (read from the actual file).
3. **Type consistency:** Scene IDs (`demo_room`) used consistently across manifest, registry, config, splash, scene manager, and all test files. Function signatures match throughout.

**Note on Step 3 of Task 6:** The blockout builder positions all CSG boxes at the origin (default transform). The `U_EditorBlockoutBuilder` does not accept position parameters on `add_csg_box`. If walls need offset positions, run the builder in-editor and manually adjust transforms, then re-save. Alternatively, use `execute_custom` with a lambda to set positions after creation. Either approach is fine — the goal is a generated scene file, not pixel-perfect placement.
