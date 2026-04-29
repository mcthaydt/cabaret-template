# Add Builder / Fluent Script

**Status**: Active

## When To Use This Recipe

Use this recipe when adding or modifying **builder-driven configuration** instead of hand-authoring `.tres` resource files. The builder pattern replaces inspector-authored resources with programmatic GDScript APIs, making authoring readable for LLM co-pilots and producing compact git diffs.

This recipe covers:

- Adding or evolving a builder utility (`U_*Builder`)
- Adding a new AI behavior using `U_BTBuilder` / `U_AIBTFactory`
- Migrating a `.tres` configuration to a builder script
- Script-backed brain settings (`RS_AIBrainScriptSettings`)
- Scene-registry, input-profile, and QB-rule builders
- Editor prefab / blockout builders (Phase 7)
- UI settings tab / menu screen builders (Phase 8)

This recipe does **not** cover:

- The runtime consumer system that *reads* built resources (see the per-system recipe: `ai.md`, `ecs.md`, `scenes.md`, etc.)
- Manual `.tres` inspector authoring (deprecated once a builder exists)
- Adding new AI actions, conditions, effects, or ECS components (see `ai.md` or `conditions_effects_rules.md`)

## Governing ADR(s)

- [ADR 0011: Builder Pattern Taxonomy](../../adr/0011-builder-pattern-taxonomy.md)

## Canonical Examples

| Domain | Builder | Example Usage |
|--------|---------|---------------|
| BT structural | `scripts/core/utils/bt/u_bt_builder.gd` | `U_BTBuilder.sequence([...])` |
| BT AI factory | `scripts/core/utils/ai/u_ai_bt_factory.gd` | `U_AIBTFactory.move_to(...)` |
| Scene registry | `scripts/core/utils/scene/u_scene_registry_builder.gd` | `U_SceneRegistryBuilder.register(...)` |
| Input profile | `scripts/core/utils/input/u_input_profile_builder.gd` | `U_InputProfileBuilder.bind_key(...)` |
| QB rules | `scripts/core/utils/qb/u_qb_rule_builder.gd` | `U_QBRuleBuilder.rule(...)` |
| BT behavior script | `scripts/demo/ai/trees/wolf_behavior.gd` | Script-backed brain: `build() -> RS_BTNode` |
| Editor prefab | `scripts/core/utils/editors/u_editor_prefab_builder.gd` (Phase 7) | `U_EditorPrefabBuilder.create_root(...)` |
| Editor blockout | `scripts/core/utils/editors/u_editor_blockout_builder.gd` (Phase 7) | `U_EditorBlockoutBuilder.create_root(...)` |
| Settings tab | `scripts/core/ui/helpers/u_settings_tab_builder.gd` (Phase 8) | `U_SettingsTabBuilder.new(tab).bind_heading(...)` |
| UI menu | `scripts/core/ui/helpers/u_ui_menu_builder.gd` (Phase 8) | `U_UIMenuBuilder.new(menu).bind_title(...)` |
| Settings catalog | `scripts/core/ui/helpers/u_ui_settings_catalog.gd` (Phase 8) | `U_UISettingsCatalog.get_quality_presets()` |

## Vocabulary

| Term | Meaning |
|------|---------|
| `Builder` (suffix) | Either static factory (`U_BTBuilder`) or fluent instance builder (`U_SceneRegistryBuilder`). |
| `Helper` (suffix) | Side-effecting procedural utility. **Not a builder.** |
| Static builder | All `static func`, no instance state. One-shot construction. |
| Declarative/fluent builder | Instance-based, chainable methods, returns `self`, terminated by `.build()`. |
| `br_*` | Builder script category name prefix. e.g. `br_harvest_rule.gd` for a QB rule builder. |
| `_sanitize_*` | Headless-safe typed-array/population setter. Bypasses Godot 4.x `Object.set()` coercion on typed `Array` exports. |
| `_children` bypass | Setting via `.set("_children", sanitized_array)` to preserve typed container population in headless GUT runs. |
| `RS_AIBrainScriptSettings` | Brain settings subclass where `root` is produced by calling a builder script at load time. |

## Recipe

### Adding a new builder utility

1. Choose the pattern category per ADR 0011:
   - **Static**: all args always known up-front → `static func` on a `class_name U_*Builder` extending `RefCounted`.
   - **Declarative/fluent**: optional accumulation → instance `class_name U_*Builder extends RefCounted`, chainable methods return `self`, `.build()` returns the constructed object.
2. Do **not** use `EditorScript` as the base — `RefCounted` is required for headless GUT testability.
3. If the builder constructs typed `Array` fields on Godot resources with `@export` typed-array setters (e.g. `children: Array[RS_BTNode]`), use the `_sanitize_` + `.set("_children", sanitized)` bypass pattern to avoid headless `Object.set()` silently coercing arrays to empty.
4. Keep the file under 200 lines. Extract helpers if needed.
5. Add unit tests in `tests/unit/<domain>/test_u_<name>_builder.gd`.
6. Update `docs/architecture/extensions/builders.md` vocabulary + canonical examples sections if a new builder is added.
7. Run style enforcement.

### Adding a new AI behavior using `U_BTBuilder` + `U_AIBTFactory`

1. Determine whether the behavior is static (all args known) or declarative (optional fields accumulate).
   - Most creature brains are static: one `build()` returns a complete tree.
   - One-off utility branches may use `U_AIBTFactory` convenience methods.
2. Create the builder script at `scripts/demo/ai/trees/<name>_behavior.gd`:
   - `extends RefCounted`
   - `func build() -> RS_BTNode`
   - Preload the `RS_*` resources you need, instantiate them inline, call `U_BTBuilder.*` or `U_AIBTFactory.*` helpers.
3. If the behavior uses composite conditions via `RS_ConditionComposite`:
   - Call `cond.call("_sanitize_children", [...])` then `cond.set("_children", sanitized)` for the headless-safe bypass.
4. Wrap the builder in `RS_AIBrainScriptSettings`:
   - Create `resources/demo/ai/<creature>/cfg_<creature>_brain_script.tres` typed `RS_AIBrainScriptSettings`.
   - Set `builder_script` to `load("res://scripts/demo/ai/trees/<name>_behavior.gd")`.
5. Write an integration test at `tests/unit/ai/integration/test_<name>_brain_bt.gd`:
   - Load the `.tres`, call `get_root()`.
   - Assert the result is non-null and is `RS_BTNode`.
   - Verify structure if applicable.
6. Wire the prefab scene to the new `.tres`.
7. Delete the old `.tres` brain / `.tres` subtrees **in an atomic commit** after visual parity is verified.
8. Run style enforcement.

### Using `RS_AIBrainScriptSettings` for a script-backed brain

1. For a creature already on the legacy `RS_AIBrainSettings` (`.tres` with `root` field), migrate in two steps:
   - Phase 1: author the builder script, create a new `RS_AIBrainScriptSettings` `.tres` pointing to it, and wire the scene to it.
   - Phase 2: after parity tests pass, delete the old `.tres`.
2. `RS_AIBrainScriptSettings.get_root()` caches the built root on first call.
   - If the builder script file changes, the cache survives until the resource is reloaded.
   - In tests, `get_root()` is idempotent across multiple calls.
3. The builder script does **not** need a class_name or UID. It only needs a public `build() -> RS_BTNode` method.

### Adding a scene-registry entry using `U_SceneRegistryBuilder`

1. Create or modify a manifest script (e.g. `scripts/demo/scene_management/u_scene_manifest.gd`):
   ```gdscript
   var builder := U_SceneRegistryBuilder.new()
   builder.register("my_scene", "res://scenes/demo/gameplay/my_scene.tscn")
          .with_type(1)
          .with_transition("fade")
          .with_preload(1)
   return builder.build()
   ```
2. The manifest returns a `Dictionary` keyed by scene_id; the consumer iterates and calls `_register_scene_from_dict()`.
3. Delete the old `resources/scene_registry/cfg_*.tres` entries after the manifest is wired.

### Adding an input profile using `U_InputProfileBuilder`

1. Create a builder script (e.g. `scripts/demo/input/keyboard_builder.gd`):
   ```gdscript
   var b := U_InputProfileBuilder.new()
   b.named("keyboard_default")
    .with_device_type(0)
    .bind_key("move_left", KEY_A)
    .bind_joypad_button("jump", JOY_BUTTON_A)
   return b.build()
   ```
2. Expose the builder in an `RS_InputProfile` wrapper or load it directly in test fixtures.
3. Replace `.tres`-authored profiles only after the builder output matches the original.

### Adding a QB rule using `U_QBRuleBuilder`

1. Create a script under `scripts/core/qb/rules/br_<name>_rule.gd`:
   - `extends RefCounted`
   - `static func build() -> Array[RS_Rule]`
2. Use `U_QBRuleBuilder.rule(rule_id, conditions, effects, config)` with:
   - Conditions from `U_QBRuleBuilder.event_name(...)`, `component_field(...)`, `composite_all([...])`, etc.
   - Effects from `U_QBRuleBuilder.publish_event(...)`, `set_field(...)`, etc.
3. For composite conditions, call the headless-safe bypass:
   ```gdscript
   var sanitized = comp.call("_sanitize_children", children)
   comp.set("_children", sanitized)
   ```
4. The ECS system that loads rules calls `_build_rules_from_scripts()`:
   ```gdscript
   var rules: Array[RS_Rule] = br_harvest_rule.build()
   for r in rules:
       _rule_registerer.register(r)
   ```
5. Add an integration test loading the builder and asserting rule count + rule_id coverage.
6. Delete the old `resources/core/qb/<domain>/cfg_*.tres` rules only after the builder is tested.
7. Run style enforcement.

### Using editor prefab / blockout builders (Phase 7)

1. Builder infrastructure lives in `scripts/core/utils/editors/`.
2. Thin `@tool extends EditorScript` adapters live in `scripts/demo/editors/` (~5 lines each):
   ```gdscript
   @tool
   extends EditorScript
   func _run():
       var builder := U_EditorPrefabBuilder.new()
       builder.create_root("StaticBody3D", "MyPrefab") \
              .add_ecs_component(...) \
              .save("res://scenes/demo/prefabs/prefab_my_thing.tscn")
   ```
3. `U_EditorPrefabBuilder` and `U_EditorBlockoutBuilder` are `RefCounted`; no `EditorScript` base. This lets GUT unit-test them headlessly.

### Using UI settings tab / menu builders (Phase 8)

1. Builder infrastructure lives in `scripts/core/ui/helpers/`.
2. In your settings overlay `_setup_builder()`:
   ```gdscript
   _builder = U_SettingsTabBuilder.new(self)
   _builder.bind_heading(heading_label, &"settings.audio.title") \
          .bind_field_label(master_label, &"settings.audio.label.master") \
          .bind_field_control(master_slider, _on_master_changed) \
          .bind_action_button(cancel_button, &"common.cancel", _on_cancel_pressed, "Cancel") \
          .build()
   ```
3. In your menu screen `_setup_menu_builder()`:
   ```gdscript
   _menu_builder = U_UIMenuBuilder.new(self)
   _menu_builder.bind_title(title_label, &"menu.main.title", "Main Menu") \
                 .bind_button_group([
                     {"button": play_button, "key": &"menu.main.play", "callback": _on_play_pressed, "fallback": "Play"},
                     {"button": settings_button, "key": &"menu.main.settings", "callback": _on_settings_pressed, "fallback": "Settings"},
                 ]) \
                 .build()
   ```
4. `bind_*` methods take existing `@onready` nodes and register them for theming, localization, and focus.
5. Always pass a `fallback` string to `bind_action_button`, `bind_button`, `bind_title`, and `bind_heading` for headless test localization.
6. `BaseSettingsSimpleOverlay` uses `bind_panel()` to delegate panel/content theming; subclasses call `super._on_panel_ready()`.
7. LOC caps: `U_SettingsTabBuilder` ≤300, `U_UIMenuBuilder` ≤200, `U_UISettingsCatalog` ≤150.

## Anti-patterns

- **Hand-authoring `.tres` after a builder exists**: Once a builder is wired and tested, the `.tres` is dead code. Keep it around only during the migration window.
- **Forcing static builders into fluent form**: If all args are always known, adding `.new() / .build()` scaffolding is noise. Use `static func`.
- **Using `EditorScript` as the builder base**: This breaks headless GUT. Builder logic goes in `RefCounted`; a thin `EditorScript` adapter calls it.
- **Skipping the `_children` bypass on typed arrays**: Without `.set("_children", sanitized)`, headless GUT runs may silently drop array contents on `Object.set()`.
- **Putting builder scripts in `scripts/core/`**: Builder scripts that author demo-specific configuration belong in `scripts/demo/`. Builder *utilities* (the factory class) belong in `scripts/core/`.

## Out Of Scope

- AI behavior runtime details: see `ai.md`
- Scene registry runtime loading: see `scenes.md`
- Input system runtime wiring: see `input.md`
- QB rule engine runtime evaluation: see `conditions_effects_rules.md`
- ECS component/system authoring: see `ecs.md`

## References

- [ADR 0011: Builder Pattern Taxonomy](../../adr/0011-builder-pattern-taxonomy.md)
- [ADR 0013: UI Menu/Settings Builder Pattern](../../adr/0013-ui-menu-settings-builder-pattern.md)
- `scripts/core/utils/bt/u_bt_builder.gd`
- `scripts/core/utils/ai/u_ai_bt_factory.gd`
- `scripts/core/utils/scene/u_scene_registry_builder.gd`
- `scripts/core/utils/input/u_input_profile_builder.gd`
- `scripts/core/utils/qb/u_qb_rule_builder.gd`
- `scripts/core/utils/editors/` (Phase 7: prefab + blockout builders)
- `scripts/core/ui/helpers/` (Phase 8: settings tab + menu builders)
