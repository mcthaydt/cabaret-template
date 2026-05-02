# Add Validated Resource

**Status**: Active

## When To Use This Recipe

Use this recipe when adding a designer-authored `Resource` class or a new `.tres` instance for:

- Manager configuration
- ECS component settings
- Scene registry or spawn metadata
- Input, display, localization, UI, VFX, lighting, QB, or scene director data
- Core/demo split resource placement

This recipe does **not** cover:

- QB condition/effect/rule behavior (see `conditions_effects_rules.md`)
- Scene authoring (see `scenes.md`)
- State slice structure (see `state.md`)

## Governing ADR(s)

- [ADR 0009: Template vs Demo Separation](../adr/0009-template-vs-demo-separation.md)
- [ADR 0010: Base Scene and Demo Entry Split](../adr/0010-base-scene-and-demo-entry-split.md)

## Canonical Example

- Scene registry resource type: `scripts/core/resources/scene_management/rs_scene_registry_entry.gd`
- Scene registry instance: `resources/core/scene_registry/cfg_gameplay_base_entry.tres`
- Spawn metadata resource type: `scripts/core/resources/scene_management/rs_spawn_metadata.gd`
- Spawn metadata instance: `resources/core/spawn_metadata/cfg_sp_base.tres`
- Input profile resource type: `scripts/core/resources/input/rs_input_profile.gd`
- Display preset resource type: `scripts/core/resources/display/rs_quality_preset.gd`
- Game config resource type: `scripts/core/resources/rs_game_config.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `RS_*` | Resource class prefix for `.gd` resource definitions. |
| `cfg_*` | Resource instance prefix for `.tres` files. |
| `cfg_*_default.tres` | Reusable core default instance. |
| `cfg_*_entry.tres` | Registry entry instance. |
| `cfg_sp_*.tres` | Spawn metadata instance. |
| Core resource | Template infrastructure data that must survive demo removal. |
| Demo resource | Example content data tied to forest/AI/demo scenes. |

Resource classes live under `scripts/core/resources/**`. Resource instances live under `resources/**`. Do not reuse `rs_` for `.tres` instances.

## Recipe

### Adding a new resource class

1. Pick the owning domain directory under `scripts/core/resources/**`.
2. Create `rs_<domain>_<name>.gd`; extend `Resource` or the established domain base class.
3. Add `class_name RS_<Domain><Name>` when the class is designer-facing or referenced by `.tres` files.
4. Use typed exported properties where Godot 4.6 supports them.
5. Validate local field shape in property setters when invalid values should fail loudly at load time.
6. Include `resource_path` in `push_error()` messages when reporting invalid authored data.
7. Add a focused unit test for validation and serialization helpers.
8. Run style enforcement.

### Adding a new resource instance

1. Pick the instance destination under `resources/**` based on ownership:
   - Core defaults and reusable framework config stay in the current core resource folders.
   - Demo-only scene/content resources move to the Phase 4 demo destination when that split lands.
2. Name the instance `cfg_<name>.tres`, `cfg_<name>_default.tres`, `cfg_<name>_entry.tres`, or the domain-specific pattern in `docs/guides/STYLE_GUIDE.md`.
3. Ensure the `.tres` contains `script = ExtResource(...)` for typed resources that need runtime validation.
4. Wire the instance through the owning registry, config, manager, or scene.
5. Add a test that loads the resource and verifies required fields.
6. Run style enforcement.

### Adding cross-reference validation

1. Keep per-field validation in resource setters.
2. Validate cross-resource references during boot or manager initialization, after registries/configs are loaded.
3. Prefer explicit registry APIs such as `has_*()` / `get_*()` over stringly typed path checks.
4. Push errors for invalid references; do not silently substitute unrelated defaults.

## Anti-patterns

- **Using `_init()` to validate exported `.tres` values**: exported properties are assigned after `_init()`, so this misses authored data.
- **Resource instances named with `rs_`**: `rs_` is for class definitions; use `cfg_` for `.tres`.
- **Runtime `DirAccess` discovery for exported presets**: mobile exports can omit or remap loose directories; use explicit preload arrays or registries where the codebase already does.
- **Core resources referencing demo paths**: breaks the template after demo removal.
- **Silent defaulting for invalid authored data**: push errors with the resource path so bad content is visible.
- **Duplicating shared `.tres` files by mutation at runtime**: duplicate before customizing per-scene data or rely on established controller auto-duplication.

## Out Of Scope

- QB conditions/effects/rules: see `conditions_effects_rules.md`
- Scene registry usage and transitions: see `scenes.md`
- Display preset behavior: see `display_post_process.md`
- Input profile behavior: see `input.md`

## References

- [Style Guide](../../guides/STYLE_GUIDE.md)
- [Godot Engine Pitfalls](../../guides/pitfalls/GODOT_ENGINE.md)
- [Target Structure](../../history/cleanup_v8/target_structure.md)
- [Template vs Demo Classification](../../history/cleanup_v8/template_vs_demo.md)
