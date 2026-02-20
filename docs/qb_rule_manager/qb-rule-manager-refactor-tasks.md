# QB Rule Manager Refactor - Tasks Checklist

**Progress:** 87% (34 / 39 tasks complete)

## Verification (all phases)

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/qb -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs/systems -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/qb -gexit
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/style -gexit
```

---

## Phase R1: Extract Variant Utils

**Goal:** Eliminate ~150-200 lines of duplicated helpers across 7 files into one shared `U_QBVariantUtils`.

### R1A: Create shared utility

- [x] TR1.1: Create `scripts/utils/qb/u_qb_variant_utils.gd` (`U_QBVariantUtils extends RefCounted`, all `static func`):
  - `get_int_property(object_value: Variant, property_name: String, fallback: int) -> int`
  - `get_bool_property(object_value: Variant, property_name: String, fallback: bool) -> bool`
  - `get_float_property(object_value: Variant, property_name: String, fallback: float) -> float`
  - `get_string_property(object_value: Variant, property_name: String, fallback: String) -> String`
  - `get_array_property(object_value: Variant, property_name: String) -> Array`
  - `object_has_property(object_value: Variant, property_name: String) -> bool`
  - `get_dict(source: Dictionary, key: String) -> Dictionary`
  - `dict_get_string_or_name(dictionary: Dictionary, key: String) -> Variant`

### R1B-R1H: Migrate all consumers

- [x] TR1.2: `u_qb_rule_evaluator.gd` -- replace `_get_int_property`, `_get_bool_property`, `_get_string_property` with `U_QBVariantUtils` calls
- [x] TR1.3: `u_qb_quality_provider.gd` -- replace `_get_int_property`, `_get_string_property`, `_object_has_property`, `_get_dict`, `_dict_get_string_or_name` with `U_QBVariantUtils` calls
- [x] TR1.4: `u_qb_effect_executor.gd` -- replace `_get_int_property`, `_get_string_property`, `_object_has_property`, `_get_dict`, `_dict_get_string_or_name` with `U_QBVariantUtils` calls
- [x] TR1.5: `u_qb_rule_validator.gd` -- replace `_get_int_property`, `_get_string_property`, `_get_array_property` with `U_QBVariantUtils` calls
- [x] TR1.6: `base_qb_rule_manager.gd` -- replace all 5 `_get_*_property` helpers (lines 482-528) with `U_QBVariantUtils` calls
- [x] TR1.7: `s_character_rule_manager.gd` -- replace `_object_has_property` (lines 265-277) with `U_QBVariantUtils.object_has_property` call
- [x] TR1.8: `s_camera_rule_manager.gd` -- replace `_object_has_property` (lines 291-300) with `U_QBVariantUtils.object_has_property` call. Rewrite `_get_camera_state_float` (lines 280-289) to use `U_QBVariantUtils.object_has_property` + `U_QBVariantUtils.get_float_property` — preserve the property-list guard that distinguishes this method from the base's `_get_float_property`

### R1I: Verification

- [x] TR1.9: Run full test suite -- zero regressions

Completion notes (2026-02-20):
- Added `scripts/utils/qb/u_qb_variant_utils.gd` and migrated all R1 consumers.
- Removed duplicated local helper implementations from evaluator/quality/effect/validator and object-property helpers from character/camera managers.
- Verification passed: `tests/unit/qb` (71/71), `tests/unit/ecs` (126/126), `tests/unit/ecs/systems` (200/200), `tests/integration/qb` (1/1), `tests/unit/style` (12/12).

**Commit:** `Extract shared variant helpers into U_QBVariantUtils`

---

## Phase R2: Promote `_resolve_store()` to Base Class

**Goal:** Eliminate identical `_resolve_store()` duplicated in both concrete managers. The base already has `@export var state_store` and `U_STATE_UTILS`.

- [x] TR2.1: Add `_resolve_store() -> I_StateStore` to `base_qb_rule_manager.gd` (body: return injected `state_store` if non-null, else `U_STATE_UTILS.try_get_store(self)`)
- [x] TR2.2: Update `_ensure_context_dependencies()` in base to call `_resolve_store()` instead of inlining the same pattern
- [x] TR2.3: Remove `_resolve_store()` from `s_character_rule_manager.gd` (lines 208-211)
- [x] TR2.4: Remove `_resolve_store()` from `s_camera_rule_manager.gd` (lines 123-126)
- [x] TR2.5: Run full test suite -- verify base is now under 500 lines

Completion notes (2026-02-20):
- Promoted `_resolve_store()` to `BaseQBRuleManager` and routed `_ensure_context_dependencies()` through the shared helper.
- Removed duplicated `_resolve_store()` methods from `S_CharacterRuleManager` and `S_CameraRuleManager`.
- Verified `scripts/ecs/systems/base_qb_rule_manager.gd` is now 499 lines.
- Verification passed: `tests/unit/qb` (71/71), `tests/unit/ecs` (126/126), `tests/unit/ecs/systems` (200/200), `tests/integration/qb` (1/1), `tests/unit/style` (12/12).

**Commit:** `Promote _resolve_store() to base, remove duplicates`

---

## Phase R3: Fix `process_tick()` Override Fragility

**Goal:** Both concrete managers re-implement the base's 5-step tick sequence instead of calling `super`. Add virtual hooks so subclasses extend rather than replace.

**Design note on `_on_event_received`:** The camera manager's `_on_event_received()` override fundamentally changes the evaluation flow from single-context to multi-context (one per camera entity), so it cannot be reduced to a simple hook + `super` call. R3 focuses on fixing `process_tick()` fragility only. The camera's `_on_event_received` override remains as-is — it shares 3 lines of payload extraction with the base, but its multi-context evaluation + camera state application is genuinely different behavior, not duplication.

### R3A: Add hook to BaseQBRuleManager

- [x] TR3.1: Add `_post_tick_evaluation(_contexts: Array, _delta: float) -> void` virtual (empty body) called inside `process_tick()` after `_evaluate_contexts` and before `_cleanup_stale_context_state`

### R3B: Refactor concrete managers

- [x] TR3.2: `S_CharacterRuleManager` -- delete `process_tick()` override entirely, override `_post_tick_evaluation()` for `_write_brain_data()` loop
- [x] TR3.3: `S_CameraRuleManager` -- delete `process_tick()` override entirely, override `_post_tick_evaluation()` for `_apply_camera_state()`. Keep `_on_event_received()` override as-is (multi-context evaluation is genuinely different, not duplicated)
- [x] TR3.4: Run full test suite -- zero regressions

Completion notes (2026-02-20):
- Added `_post_tick_evaluation(contexts, delta)` to `BaseQBRuleManager.process_tick()` between `_evaluate_contexts(...)` and `_cleanup_stale_context_state()`.
- Removed `process_tick()` overrides from `S_CharacterRuleManager` and `S_CameraRuleManager`; each now extends via `_post_tick_evaluation(...)` only.
- Kept `S_CameraRuleManager._on_event_received()` override unchanged for multi-context event evaluation.
- Verification passed: `tests/unit/qb` (71/71), `tests/unit/ecs` (126/126), `tests/unit/ecs/systems` (200/200), `tests/integration/qb` (1/1), `tests/unit/style` (12/12).

**Commit:** `Fix process_tick() override fragility with virtual hooks`

---

## Phase R4: Decompose `_build_quality_context()`

**Goal:** Break the 107-line monolith (lines 79-185) in `S_CharacterRuleManager` into focused private helpers. No file extraction -- same class.

- [x] TR4.1: Extract `_populate_entity_metadata(context: Dictionary, entity_query: Variant) -> void`
- [x] TR4.2: Extract `_populate_component_map(context: Dictionary, entity_query: Variant) -> Dictionary` (returns components dict)
- [x] TR4.3: Extract `_populate_health_state(context: Dictionary, health_component: Variant) -> void`
- [x] TR4.4: Extract `_populate_movement_state(context: Dictionary, body: CharacterBody3D, floating_component: Variant) -> void`
- [x] TR4.5: Extract `_populate_input_state(context: Dictionary, input_component: Variant) -> void`
- [x] TR4.6: Rewrite `_build_quality_context()` to: initialize context defaults (lines 86-101), call entity metadata + component map helpers, extract individual components + resolve body (lines 126-136 stay in orchestrator as wiring), then call health/movement/input helpers in sequence
- [x] TR4.7: Run full test suite -- zero regressions

Completion notes (2026-02-20):
- Decomposed `S_CharacterRuleManager._build_quality_context()` into focused private helpers for entity metadata, component map setup, health state, movement state, and input state.
- Kept the orchestrator responsible for context defaults + dependency wiring while preserving existing rule evaluation behavior.
- Verification passed: `tests/unit/qb` (71/71), `tests/unit/ecs` (126/126), `tests/unit/ecs/systems` (200/200), `tests/integration/qb` (1/1), `tests/unit/style` (12/12).

**Commit:** `Decompose _build_quality_context() into focused private helpers`

---

## Phase R5: Name Camera Shake Constants + Small Fixes

**Goal:** Name the magic numbers in `_apply_trauma_shake()`, make `REQUIRED_FINAL_AREA` designer-configurable, fix `execution_priority` placement, remove dead guard code, document entity ID normalization.

Note: The camera shake values (offset 10.0, rotation 0.03) are intentionally different from `RS_ScreenShakeConfig` (offset 18/14, rotation 0.12) -- the camera-source shake is gentler than the VFX overlay shake. Name the constants, don't reuse the VFX resource.

### R5A: Camera shake constants

- [x] TR5.1: Name the sine/cosine frequency literals in `_apply_trauma_shake()`:
  ```gdscript
  const SHAKE_FREQ_OFFSET_X: float = 17.0
  const SHAKE_FREQ_OFFSET_Y: float = 21.0
  const SHAKE_FREQ_ROTATION: float = 13.0
  const SHAKE_PHASE_OFFSET_X: float = 1.1
  const SHAKE_PHASE_OFFSET_Y: float = 2.3
  const SHAKE_PHASE_ROTATION: float = 0.7
  ```

### R5B: Victory handler configurability

- [x] TR5.2: Replace `const REQUIRED_FINAL_AREA := "bar"` with `@export var required_final_area: String = "bar"` in `s_victory_handler_system.gd`
- [x] TR5.3: Update `_can_trigger_victory()` call site to use `required_final_area` instead of `REQUIRED_FINAL_AREA`
- [x] TR5.4: Add test case verifying the export is configurable (set `required_final_area` to a different value, verify behavior changes)

### R5C: Checkpoint handler consistency

- [x] TR5.5: Move `execution_priority = 100` from `_ready()` to `_init()` in `s_checkpoint_handler_system.gd` (matches convention used by all other systems)

### R5D: Redundant guard code

- [x] TR5.6: Remove redundant `if not components.has(...)` guard in `s_camera_rule_manager.gd` `_attach_camera_context()` (lines 96-98). A fresh dict has the StringName key added at line 95, then checks for the String key at line 97 — the guard is either always-true or always-false depending on Godot's StringName/String dict key equivalence, but either way it's dead logic. Replace with unconditional dual-key add matching the character manager's `_add_component_from_query` pattern

### R5E: Document entity ID normalization

- [x] TR5.7: Add comment to `s_death_handler_system.gd` `get_ragdoll_for_entity()` explaining `E_` prefix stripping (entity IDs auto-generated from node names strip this prefix; callers may pass either form)

### R5F: Verification

- [x] TR5.8: Run full test suite -- zero regressions
- [x] TR5.9: Update `AGENTS.md` line referencing `REQUIRED_FINAL_AREA` to reflect `@export var required_final_area`

Completion notes (2026-02-20):
- Named camera shake frequency/phase literals in `S_CameraRuleManager` (`SHAKE_FREQ_*`, `SHAKE_PHASE_*`) while preserving existing shake behavior.
- Made `S_VictoryHandlerSystem` game-complete area gating designer-configurable via `@export var required_final_area: String = "bar"` and updated `_can_trigger_victory(...)` to use it.
- Added `test_required_final_area_export_is_configurable` to `tests/unit/qb/test_victory_handler_system.gd`.
- Moved `S_CheckpointHandlerSystem` priority assignment from `_ready()` to `_init()` for consistency with other systems.
- Added a normalization comment in `S_DeathHandlerSystem.get_ragdoll_for_entity()` documenting acceptance of both `player` and `E_Player` ids.
- Verification passed: `tests/unit/qb` (72/72), `tests/unit/ecs` (126/126), `tests/unit/ecs/systems` (200/200), `tests/integration/qb` (1/1), `tests/unit/style` (12/12).

**Commit:** `Name shake constants, designer-configurable victory area, small fixes`

---

## Phase R6: Inspector Hints + Doc Comments

**Goal:** Add `@export_group` organization and doc comments to QB resources for designer clarity. Document `evaluate_all_conditions` as test-only.

- [ ] TR6.1: Add `@export_group` separators to `rs_qb_condition.gd` (Source, Comparison, Value)
- [ ] TR6.2: Add doc comments to `rs_qb_effect.gd` `target` and `payload` exports
- [ ] TR6.3: Add `@export_group` separators to `rs_qb_rule_definition.gd` (Identity, Trigger, Evaluation, Cooldown) with doc hints on `cooldown_key_fields` and `cooldown_from_context_field`
- [ ] TR6.4: Add doc comment to `u_qb_rule_evaluator.gd` `evaluate_all_conditions()` marking it as test-only convenience method
- [ ] TR6.5: Run full test suite -- zero regressions

**Commit:** `Add inspector groups and doc hints to QB resources`

---

## Critical Files

| File | Phases |
|---|---|
| `scripts/utils/qb/u_qb_variant_utils.gd` | R1 (new) |
| `scripts/ecs/systems/base_qb_rule_manager.gd` | R1, R2, R3 |
| `scripts/utils/qb/u_qb_rule_evaluator.gd` | R1, R6 |
| `scripts/utils/qb/u_qb_quality_provider.gd` | R1 |
| `scripts/utils/qb/u_qb_effect_executor.gd` | R1 |
| `scripts/utils/qb/u_qb_rule_validator.gd` | R1 |
| `scripts/ecs/systems/s_character_rule_manager.gd` | R1, R2, R3, R4 |
| `scripts/ecs/systems/s_camera_rule_manager.gd` | R1, R2, R3, R5 |
| `scripts/ecs/systems/s_victory_handler_system.gd` | R5 |
| `scripts/ecs/systems/s_checkpoint_handler_system.gd` | R5 |
| `scripts/ecs/systems/s_death_handler_system.gd` | R5 |
| `scripts/resources/qb/rs_qb_condition.gd` | R6 |
| `scripts/resources/qb/rs_qb_effect.gd` | R6 |
| `scripts/resources/qb/rs_qb_rule_definition.gd` | R6 |

## Notes

- Zero behavioral changes across all phases -- existing tests are the definitive spec
- Each phase ends with a commit at test-green state
- R1-R5 touch the most files and carry the most regression risk; R6 is localized

## Links

- Plan: `docs/qb_rule_manager/qb-rule-manager-plan.md`
- Continuation prompt: `docs/qb_rule_manager/qb-rule-manager-continuation-prompt.md`
- Original tasks: `docs/qb_rule_manager/qb-rule-manager-tasks.md`
