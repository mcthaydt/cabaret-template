# Sprite Zone Lighting Shader — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `sh_sprite_zone_lighting.gdshader` (spatial unshaded, identical math to character lighting) and extend the zone lighting pipeline so `Sprite3D` nodes on character entities receive zone tint/intensity updates.

**Architecture:** New shader file in `assets/core/shaders/`. Extend `U_CharacterLightingMaterialApplier` with parallel sprite methods sharing the same instance-id-keyed cache. Add one call site in `M_CharacterLightingManager._apply_lighting_to_characters()`. Wire up default shader material in `build_prefab_player_body.gd` so the prefab ships pre-configured.

**Tech Stack:** Godot 4.6, GDScript, spatial unshaded shaders, GUT test framework

---

### Task 1: Create `sh_sprite_zone_lighting.gdshader`

**Files:**
- Create: `assets/core/shaders/sh_sprite_zone_lighting.gdshader`

- [ ] **Step 1: Write the new shader file**

Write the file with content identical to `sh_character_zone_lighting.gdshader` (same uniforms and fragment math):

```glsl
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled;

uniform sampler2D albedo_texture : source_color;
uniform vec4 base_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 effective_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float effective_intensity : hint_range(0.0, 8.0, 0.01) = 1.0;
uniform float minimum_unlit_floor : hint_range(0.0, 1.0, 0.01) = 0.2;

void fragment() {
	vec4 albedo_sample = texture(albedo_texture, UV);
	vec3 zone_tinted_color = albedo_sample.rgb * base_tint.rgb * effective_tint.rgb;
	ALBEDO = zone_tinted_color * effective_intensity;
	EMISSION = zone_tinted_color * minimum_unlit_floor;
}
```

`cull_disabled` because Sprite3D quads should be visible from any angle (though billboarding means back-face is rarely seen, this avoids invisible-sprite bugs during transitions).

- [ ] **Step 2: Verify shader loads**

Run:
```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```
Expected: PASS (new file is under `assets/core/shaders/`, following `sh_*.gdshader` naming — should pass style checks).

- [ ] **Step 3: Commit**

```bash
git add assets/core/shaders/sh_sprite_zone_lighting.gdshader
git commit -m "feat: add sh_sprite_zone_lighting.gdshader for Sprite3D zone lighting (GREEN)"
```

---

### Task 2: Write failing applier tests for sprite methods (RED)

**Files:**
- Modify: `tests/unit/lighting/test_character_lighting_material_applier.gd`

- [ ] **Step 1: Add `_create_sprite_with_texture` test helper and four new tests**

Append to the end of `tests/unit/lighting/test_character_lighting_material_applier.gd` (before the last line):

```gdscript
func _create_sprite_with_texture(texture: Texture2D) -> Sprite3D:
	var sprite := Sprite3D.new()
	sprite.name = "DirectionalSprite"
	sprite.texture = texture
	sprite.pixel_size = 0.01
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	return sprite

func test_collect_sprite_targets_finds_sprite3d_children() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()
	var texture := _create_test_texture()

	var sprite := _create_sprite_with_texture(texture)
	character_root.add_child(sprite)
	autofree(sprite)

	var nested := Node3D.new()
	nested.name = "Nested"
	character_root.add_child(nested)
	autofree(nested)

	var nested_sprite := _create_sprite_with_texture(texture)
	nested_sprite.name = "NestedSprite"
	nested.add_child(nested_sprite)
	autofree(nested_sprite)

	var result: Array = applier.collect_sprite_targets(character_root)
	assert_eq(result.size(), 2)
	assert_true(result.has(sprite))
	assert_true(result.has(nested_sprite))

func test_collect_sprite_targets_skips_null_texture_sprites() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()

	var no_texture_sprite := Sprite3D.new()
	no_texture_sprite.name = "NoTexSprite"
	character_root.add_child(no_texture_sprite)
	autofree(no_texture_sprite)

	var result: Array = applier.collect_sprite_targets(character_root)
	assert_eq(result.size(), 0)

func test_apply_sprite_lighting_sets_shader_material_and_params() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()
	var texture := _create_test_texture()

	var sprite := _create_sprite_with_texture(texture)
	character_root.add_child(sprite)
	autofree(sprite)

	applier.apply_sprite_lighting(character_root, Color(1.0, 1.0, 1.0, 1.0), Color(0.5, 0.6, 0.7, 1.0), 1.75)

	var override_material := sprite.material_override as ShaderMaterial
	assert_not_null(override_material, "Sprite should receive a ShaderMaterial override.")
	var shader := override_material.shader
	assert_not_null(shader, "ShaderMaterial should have the sprite lighting shader assigned.")
	var shader_code: String = shader.code
	assert_true(shader_code.find("unshaded") >= 0, "Sprite shader must remain unshaded.")
	assert_eq(override_material.get_shader_parameter(PARAM_ALBEDO_TEXTURE), texture)
	assert_eq(override_material.get_shader_parameter(PARAM_EFFECTIVE_TINT), Color(0.5, 0.6, 0.7, 1.0))
	assert_almost_eq(float(override_material.get_shader_parameter(PARAM_EFFECTIVE_INTENSITY)), 1.75, 0.0001)

func test_restore_sprite_materials_clears_material_override() -> void:
	var script_obj := _applier_script()
	if script_obj == null:
		return
	var applier: Variant = script_obj.new()
	var character_root := _create_character_root()
	var texture := _create_test_texture()

	var original_override := StandardMaterial3D.new()
	var sprite := _create_sprite_with_texture(texture)
	sprite.material_override = original_override
	character_root.add_child(sprite)
	autofree(sprite)

	applier.apply_sprite_lighting(character_root, Color.WHITE, Color(0.8, 0.8, 0.8, 1.0), 2.0)
	assert_true(sprite.material_override is ShaderMaterial)

	applier.restore_sprite_materials(character_root)
	assert_eq(sprite.material_override, original_override)
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/lighting/test_character_lighting_material_applier.gd
```
Expected: 4 FAILING — `collect_sprite_targets`, `apply_sprite_lighting`, `restore_sprite_materials` methods not found on applier.

- [ ] **Step 3: Commit**

```bash
git add tests/unit/lighting/test_character_lighting_material_applier.gd
git commit -m "test: add failing sprite zone lighting applier tests (RED)"
```

---

### Task 3: Implement sprite methods in material applier (GREEN)

**Files:**
- Modify: `scripts/core/utils/lighting/u_character_lighting_material_applier.gd`

- [ ] **Step 1: Add sprite shader preload constant**

After line 4 (`SH_CHARACTER_ZONE_LIGHTING`), add:

```gdscript
const SH_SPRITE_ZONE_LIGHTING := preload("res://assets/core/shaders/sh_sprite_zone_lighting.gdshader")
```

- [ ] **Step 2: Add `_sprite_shader` field and generalize cache pruning**

In the field declarations (after `_shader: Shader = SH_CHARACTER_ZONE_LIGHTING` on line 14), add:

```gdscript
var _sprite_shader: Shader = SH_SPRITE_ZONE_LIGHTING
```

Replace `_get_cached_mesh` (lines 202-216) with a generalized version that returns `Node`:

```gdscript
func _get_cached_node(cache_key: int) -> Node:
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return null
	var entry := entry_variant as Dictionary
	var ref_key := "mesh_ref"
	var ref_variant: Variant = entry.get(ref_key, null)
	if not (ref_variant is WeakRef):
		return null
	var resolved_variant: Variant = (ref_variant as WeakRef).get_ref()
	if not (resolved_variant is Node):
		return null
	var node := resolved_variant as Node
	if not is_instance_valid(node):
		return null
	return node
```

Update `_prune_invalid_cache_entries` (line 197) to call `_get_cached_node` instead of `_get_cached_mesh`:

In `_prune_invalid_cache_entries` — the call on line 197:
```gdscript
if _get_cached_node(cache_key) == null:
```

Update `_restore_mesh` (line 184) to still work — it accesses `entry.get("original_material_override")` which works fine for both mesh and sprite entries.

- [ ] **Step 3: Add `collect_sprite_targets` and recursive helper**

After `_collect_mesh_targets_recursive` (around line 68), add:

```gdscript
func collect_sprite_targets(character_entity: Node) -> Array[Sprite3D]:
	var targets: Array[Sprite3D] = []
	if character_entity == null or not is_instance_valid(character_entity):
		return targets
	_collect_sprite_targets_recursive(character_entity, targets)
	return targets

func _collect_sprite_targets_recursive(node: Node, targets: Array[Sprite3D]) -> void:
	if node is Sprite3D:
		var sprite := node as Sprite3D
		if sprite.texture != null:
			targets.append(sprite)

	var children: Array = node.get_children()
	for child_variant in children:
		if child_variant is Node:
			_collect_sprite_targets_recursive(child_variant as Node, targets)
```

- [ ] **Step 4: Add `apply_sprite_lighting` and per-sprite override**

After the existing `apply_character_lighting` method (around line 29), add:

```gdscript
func apply_sprite_lighting(
	character_entity: Node,
	base_tint: Color,
	effective_tint: Color,
	effective_intensity: float
) -> void:
	_prune_invalid_cache_entries()
	var targets := collect_sprite_targets(character_entity)
	for sprite in targets:
		_apply_sprite_override(sprite, base_tint, effective_tint, effective_intensity)

func _apply_sprite_override(
	sprite: Sprite3D,
	base_tint: Color,
	effective_tint: Color,
	effective_intensity: float
) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	if sprite.texture == null:
		return

	var albedo_texture: Texture2D = sprite.texture

	var shader_material := _ensure_sprite_shader_material(sprite)
	if shader_material == null:
		return

	shader_material.set_shader_parameter(PARAM_ALBEDO_TEXTURE, albedo_texture)
	shader_material.set_shader_parameter(PARAM_BASE_TINT, base_tint)
	shader_material.set_shader_parameter(PARAM_EFFECTIVE_TINT, effective_tint)
	shader_material.set_shader_parameter(
		PARAM_EFFECTIVE_INTENSITY,
		clampf(effective_intensity, MIN_INTENSITY, MAX_INTENSITY)
	)
	sprite.material_override = shader_material

func _ensure_sprite_shader_material(sprite: Sprite3D) -> ShaderMaterial:
	var cache_key: int = sprite.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if entry_variant is Dictionary:
		var existing_entry := entry_variant as Dictionary
		var shader_material_variant: Variant = existing_entry.get("shader_material", null)
		if shader_material_variant is ShaderMaterial:
			return shader_material_variant as ShaderMaterial

	var shader_material := ShaderMaterial.new()
	shader_material.shader = _sprite_shader
	_material_cache[cache_key] = {
		"mesh_ref": weakref(sprite),
		"original_material_override": sprite.material_override,
		"shader_material": shader_material,
	}
	return shader_material
```

- [ ] **Step 5: Add `restore_sprite_materials` and per-sprite restore**

After the existing `restore_character_materials` method (around line 35), add:

```gdscript
func restore_sprite_materials(character_entity: Node) -> void:
	var targets := collect_sprite_targets(character_entity)
	for sprite in targets:
		_restore_sprite(sprite)
	_prune_invalid_cache_entries()

func _restore_sprite(sprite: Sprite3D) -> void:
	var cache_key: int = sprite.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	sprite.material_override = entry.get("original_material_override", null)
	_material_cache.erase(cache_key)
```

- [ ] **Step 6: Run applier tests to verify pass**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/lighting/test_character_lighting_material_applier.gd
```
Expected: ALL PASS (existing 8 + new 4 = 12 passing).

- [ ] **Step 7: Commit**

```bash
git add scripts/core/utils/lighting/u_character_lighting_material_applier.gd
git commit -m "feat: extend material applier with Sprite3D zone lighting support (GREEN)"
```

---

### Task 4: Integrate sprite applier into lighting manager (GREEN)

**Files:**
- Modify: `scripts/core/managers/m_character_lighting_manager.gd`

- [ ] **Step 1: Add sprite applier calls in `_apply_lighting_to_characters`**

In `_apply_lighting_to_characters()`, after the existing `_material_applier.apply_character_lighting(...)` block (around line 458-463), add:

```gdscript
		_material_applier.apply_sprite_lighting(
			character_node,
			Color(1.0, 1.0, 1.0, 1.0),
			effective_tint,
			effective_intensity
		)
```

- [ ] **Step 2: Add sprite restore calls in `_update_character_entities`**

In `_update_character_entities()`, in the loop where removed characters are cleaned up (around line 330), add after `_material_applier.restore_character_materials(previous)`:

```gdscript
		_material_applier.restore_sprite_materials(previous)
```

- [ ] **Step 3: Add sprite restore in `_physics_process` disabled/enabled transitions**

In `_physics_process()`, where the disabled path calls `_material_applier.restore_all_materials()` (line 115), we don't need changes — `restore_all_materials` already iterates all cache entries regardless of node type. But we need to make sure it works for both MeshInstance3D and Sprite3D. The current `_restore_mesh` on line 183 accesses `mesh_instance.material_override` on a specific typed method. `restore_all_materials` (line 41) calls `_get_cached_mesh` which now calls `_get_cached_node` — since we already changed `_get_cached_mesh` to `_get_cached_node` in Task 3, `restore_all_materials` should now handle both types.

But wait — `restore_all_materials` on line 45 casts the cache key to `int` and calls `_get_cached_mesh(cache_key)`. We need to update `_restore_mesh` to handle both types, OR make `restore_all_materials` generic. The simplest fix: update `_restore_mesh` to accept any `Node`, not just `MeshInstance3D`:

In `_restore_mesh` (line 183), change the parameter type from `MeshInstance3D` to `Node` and the internal call from casting as MeshInstance3D to just using `Node`:

Replace `_restore_mesh` (lines 183-190):
```gdscript
func _restore_mesh(node: Node) -> void:
	var cache_key: int = node.get_instance_id()
	var entry_variant: Variant = _material_cache.get(cache_key, null)
	if not (entry_variant is Dictionary):
		return
	var entry := entry_variant as Dictionary
	node.set("material_override", entry.get("original_material_override", null))
	_material_cache.erase(cache_key)
```

And update `restore_all_materials` (line 43) to return `Node` instead of `MeshInstance3D`:
```gdscript
func restore_all_materials() -> void:
	var keys: Array = _material_cache.keys()
	for key_variant in keys:
		var cache_key: int = int(key_variant)
		var node := _get_cached_node(cache_key)
		if node == null:
			continue
		var entry_variant: Variant = _material_cache.get(cache_key, null)
		if not (entry_variant is Dictionary):
			continue
		var entry := entry_variant as Dictionary
		node.set("material_override", entry.get("original_material_override", null))
	_material_cache.clear()
```

Also update the existing call sites. In `_restore_character_materials` (line 36):
```gdscript
	for mesh_instance in targets:
		_restore_mesh(mesh_instance)
```
This still works since `MeshInstance3D` extends `Node`.

- [ ] **Step 4: Run the full lighting suite**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/lighting/
```
Expected: ALL PASS.

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/lighting/
```
Expected: ALL PASS.

- [ ] **Step 5: Run the full suite**

```bash
tools/run_gut_suite.sh
```
Expected: ALL PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/managers/m_character_lighting_manager.gd scripts/core/utils/lighting/u_character_lighting_material_applier.gd
git commit -m "feat: integrate Sprite3D zone lighting into character lighting manager (GREEN)"
```

---

### Task 5: Wire up default sprite shader material in prefab builder

**Files:**
- Modify: `scripts/demo/editors/build_prefab_player_body.gd`

- [ ] **Step 1: Add shader preload and assign default material**

Replace the contents of `scripts/demo/editors/build_prefab_player_body.gd`:

```gdscript
@tool
extends EditorScript

const OUTPUT_PATH := "res://scenes/core/prefabs/prefab_player_body.tscn"
const PLAYER_SPRITE_PATH := "res://assets/core/textures/characters/tex_player_sprite_sheet.png"
const SH_SPRITE_ZONE_LIGHTING := preload("res://assets/core/shaders/sh_sprite_zone_lighting.gdshader")

const _SHADOW_BLOB := preload("res://assets/core/textures/tex_shadow_blob.png")

func _run() -> void:
	var sprite_texture: Texture2D = load(PLAYER_SPRITE_PATH) as Texture2D
	if sprite_texture == null:
		printerr("Sprite texture not found at %s" % PLAYER_SPRITE_PATH)
		return

	var builder := U_EditorPrefabBuilder.new()
	builder.create_root("Node3D", "PlayerBodyVisualRoot")

	var sprite := Sprite3D.new()
	sprite.name = "DirectionalSprite"
	sprite.pixel_size = 0.01
	sprite.hframes = 3
	sprite.vframes = 3
	sprite.texture = sprite_texture
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.position = Vector3(0, 0.64, 0)

	var sprite_shader_material := ShaderMaterial.new()
	sprite_shader_material.shader = SH_SPRITE_ZONE_LIGHTING
	sprite_shader_material.set_shader_parameter("albedo_texture", sprite_texture)
	sprite.material_override = sprite_shader_material

	builder.add_child_to(".", sprite)

	var ground_indicator := Sprite3D.new()
	ground_indicator.name = "GroundIndicator"
	ground_indicator.texture = _SHADOW_BLOB
	ground_indicator.modulate = Color(1, 1, 1, 0.49803922)
	ground_indicator.position = Vector3(0, -0.01, 0)
	ground_indicator.rotation_degrees = Vector3(-90, 0, 0)
	ground_indicator.scale = Vector3(0.08, 0.08, 0.08)
	builder.add_child_to(".", ground_indicator)

	if builder.save(OUTPUT_PATH):
		print("prefab_player_body built: %s" % OUTPUT_PATH)
	else:
		printerr("Failed to build prefab_player_body")
```

- [ ] **Step 2: Commit**

```bash
git add scripts/demo/editors/build_prefab_player_body.gd
git commit -m "feat: wire default sprite zone lighting material in prefab builder (GREEN)"
```

---

### Task 6: Rebuild prefab and update contract test

**Files:**
- Modify: `scenes/core/prefabs/prefab_player_body.tscn` (regenerated)
- Modify: `tests/integration/test_base_scene_contract.gd`

- [ ] **Step 1: Rebuild the player body prefab**

Open the Godot editor and run the `build_prefab_player_body.gd` EditorScript, OR run via headless:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script scripts/demo/editors/build_prefab_player_body.gd
```
Expected: Prints "prefab_player_body built: res://scenes/core/prefabs/prefab_player_body.tscn"

- [ ] **Step 2: Add contract test assertion for sprite shader material**

In `tests/integration/test_base_scene_contract.gd`, inside the `test_canonical_player_prefab_uses_sprite_body_visual` test method (after its last assertion at line 218, before the closing brace), add:

```gdscript
		var sprite_material := (sprite as Sprite3D).material_override
		assert_not_null(sprite_material, "DirectionalSprite must have a material_override for zone lighting")
		assert_true(sprite_material is ShaderMaterial, "DirectionalSprite material must be ShaderMaterial")
		if sprite_material is ShaderMaterial:
			var sprite_mat := sprite_material as ShaderMaterial
			var sprite_mat_shader := sprite_mat.shader
			assert_not_null(sprite_mat_shader, "Sprite ShaderMaterial must have a shader assigned")
			var sprite_shader_code: String = sprite_mat_shader.code
			assert_true(sprite_shader_code.find("zone_tinted_color") >= 0,
				"Sprite material shader must contain zone tinting math")
```

- [ ] **Step 3: Run contract tests**

```bash
tools/run_gut_suite.sh -gtest=res://tests/integration/test_base_scene_contract.gd
```
Expected: ALL PASS.

- [ ] **Step 4: Run style enforcement**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add scenes/core/prefabs/prefab_player_body.tscn tests/integration/test_base_scene_contract.gd
git commit -m "test: add contract assertion for sprite zone lighting material (GREEN)"
```

---

### Task 7: Final verification

- [ ] **Step 1: Run full test suite**

```bash
tools/run_gut_suite.sh
```
Expected: ALL PASS.

- [ ] **Step 2: Verify no lint/doc warnings**

```bash
tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
```
Expected: PASS.
