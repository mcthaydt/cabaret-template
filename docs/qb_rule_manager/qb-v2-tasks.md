# QB Rule Engine v2 — Task Checklist

**Progress:** 83% (198 / 240 tasks complete)

---

## Phase 1 — Core Library (Stateless Engine)

### 1A — Path Resolver (TDD)

**Tests first:**

- [x] T1. Create `tests/unit/qb/test_path_resolver.gd`
- [x] T2. Test: resolves single-key Dictionary path (`{"health": 100}`, path `"health"` → `100`)
- [x] T3. Test: resolves nested Dictionary path (`{"a": {"b": 5}}`, path `"a.b"` → `5`)
- [x] T4. Test: resolves StringName Dictionary key when path is String (and vice versa)
- [x] T5. Test: resolves Array index via string segment (`{"items": [10, 20]}`, path `"items.1"` → `20`)
- [x] T6. Test: resolves Object property (`node.name`, path `"name"` → node name)
- [x] T7. Test: resolves mixed nesting (Dict → Object → Dict)
- [x] T8. Test: returns null for missing Dictionary key
- [x] T9. Test: returns null for out-of-bounds Array index
- [x] T10. Test: returns null for missing Object property (no method-call fallback)
- [x] T11. Test: returns root value when path is empty string

**Implementation:**

- [x] T12. Create `scripts/utils/qb/u_path_resolver.gd` — static `resolve(root: Variant, path: String) -> Variant`
- [x] T13. All path resolver tests green

Completion note (2026-02-25): Added `U_PathResolver` + `test_path_resolver.gd`; ran `test_path_resolver.gd` (10/10 passing) and `tests/unit/style` (12/12 passing).

### 1B — Resource Definitions: Conditions (TDD)

**Tests first:**

- [x] T14. Create `tests/unit/qb/test_condition_component_field.gd`
- [x] T15. Test: numeric field normalized to 0-1 range (value=50, min=0, max=100 → 0.5)
- [x] T16. Test: value below range_min clamps to 0.0
- [x] T17. Test: value above range_max clamps to 1.0
- [x] T18. Test: bool field returns 1.0 for true, 0.0 for false
- [x] T19. Test: nested field_path resolves through component properties
- [x] T20. Test: missing component in context returns 0.0
- [x] T21. Test: missing field on component returns 0.0
- [x] T22. Test: division-by-zero guard when range_min == range_max (value >= min → 1.0, else 0.0)

- [x] T23. Create `tests/unit/qb/test_condition_redux_field.gd`
- [x] T24. Test: normalize mode — numeric value mapped to 0-1 range
- [x] T25. Test: equals mode — matching string returns 1.0, non-matching returns 0.0
- [x] T26. Test: equals mode — bool true matched against string "true" returns 1.0
- [x] T27. Test: not_equals mode — non-matching returns 1.0, matching returns 0.0
- [x] T28. Test: nested state path resolves (e.g. `gameplay.completed_areas`)
- [x] T29. Test: missing state path returns 0.0

- [x] T30. Create `tests/unit/qb/test_condition_entity_tag.gd`
- [x] T31. Test: tag present in entity_tags returns 1.0
- [x] T32. Test: tag absent returns 0.0
- [x] T33. Test: empty entity_tags array returns 0.0

- [x] T34. Create `tests/unit/qb/test_condition_event_payload.gd`
- [x] T35. Test: exists mode — non-null field returns 1.0, null/missing returns 0.0
- [x] T36. Test: normalize mode — numeric field mapped to 0-1 range
- [x] T37. Test: equals mode — string match returns 1.0
- [x] T38. Test: missing event_payload in context returns 0.0

- [x] T39. Create `tests/unit/qb/test_condition_constant.gd`
- [x] T40. Test: returns configured score value regardless of context
- [x] T41. Test: default score is 1.0

**Tests for base class behavior (response_curve + invert):**

- [x] T42. Create `tests/unit/qb/test_base_condition.gd`
- [x] T43. Test: response_curve remaps raw score (linear curve 0→0, 1→1 passthrough)
- [x] T44. Test: response_curve with sigmoid shape remaps mid-range values
- [x] T45. Test: invert flag flips score (0.7 → 0.3)
- [x] T46. Test: response_curve applied before invert
- [x] T47. Test: null response_curve passes score through unchanged

**Implementation:**

- [x] T48. Create `scripts/resources/qb/rs_base_condition.gd` — base class with response_curve, invert, virtual evaluate()
- [x] T49. Create `scripts/resources/qb/conditions/rs_condition_component_field.gd`
- [x] T50. Create `scripts/resources/qb/conditions/rs_condition_redux_field.gd`
- [x] T51. Create `scripts/resources/qb/conditions/rs_condition_entity_tag.gd`
- [x] T52. Create `scripts/resources/qb/conditions/rs_condition_event_payload.gd`
- [x] T53. Create `scripts/resources/qb/conditions/rs_condition_constant.gd`
- [x] T54. All condition tests green

Completion note (2026-02-25): Added 6 condition test suites (28 tests), implemented `RS_BaseCondition` + 5 condition subclasses, and verified:
- QB condition suites: 28/28 passing (`test_condition_*` + `test_base_condition`)
- Style suite: 12/12 passing (`tests/unit/style`)

### 1C — Resource Definitions: Effects (TDD)

**Tests first:**

- [x] T55. Create `tests/unit/qb/test_effect_dispatch_action.gd`
- [x] T56. Test: dispatches action with correct type and payload to MockStateStore
- [x] T57. Test: missing state_store in context is no-op (no crash)

- [x] T58. Create `tests/unit/qb/test_effect_publish_event.gd`
- [x] T59. Test: publishes event with correct name and payload
- [x] T60. Test: entity_id injected from context when inject_entity_id is true
- [x] T61. Test: entity_id NOT injected when inject_entity_id is false

- [x] T62. Create `tests/unit/qb/test_effect_set_field.gd`
- [x] T63. Test: set operation writes literal float value to component field
- [x] T64. Test: add operation adds to existing component field value
- [x] T65. Test: clamp applied when use_clamp is true
- [x] T66. Test: use_context_value reads value from context path instead of literal
- [x] T67. Test: missing component in context is no-op
- [x] T68. Test: all value types (float, int, bool, string, string_name) resolve correctly

- [x] T69. Create `tests/unit/qb/test_effect_set_context_value.gd`
- [x] T70. Test: writes typed value to context dictionary key
- [x] T71. Test: all value types write correctly

**Implementation:**

- [x] T72. Create `scripts/resources/qb/rs_base_effect.gd` — base class with virtual execute()
- [x] T73. Create `scripts/resources/qb/effects/rs_effect_dispatch_action.gd`
- [x] T74. Create `scripts/resources/qb/effects/rs_effect_publish_event.gd`
- [x] T75. Create `scripts/resources/qb/effects/rs_effect_set_field.gd`
- [x] T76. Create `scripts/resources/qb/effects/rs_effect_set_context_value.gd`
- [x] T77. All effect tests green

Completion note (2026-02-25): Added 4 effect test suites (13 tests), implemented `RS_BaseEffect` + 4 effect subclasses, and verified:
- QB effect suites: 13/13 passing (`test_effect_*`)
- Style suite: 12/12 passing (`tests/unit/style`)

### 1D — Rule Resource

- [x] T78. Create `scripts/resources/qb/rs_rule.gd` — typed-array target (`Array[RS_BaseCondition]`, `Array[RS_BaseEffect]`) with documented fallback path
- [x] T79. Validate fallback export metadata in headless (`conditions`/`effects` exported as `Array[Resource]`)
- [x] T80. Document typed-array inspector verification follow-up (deferred until typed arrays are re-enabled)

Completion note (2026-02-25): Added `RS_Rule` and validated export metadata in headless. Typed array annotations (`Array[RS_BaseCondition]`/`Array[RS_BaseEffect]`) failed to parse reliably in headless (`Could not find type ...`), so Phase 1D applied the documented fallback to `Array[Resource]` for parser stability; runtime type validation will be enforced in `U_RuleValidator` (Phase 1H).

### 1E — Scorer (TDD)

**Tests first:**

- [x] T81. Create `tests/unit/qb/test_rule_scorer.gd`
- [x] T82. Test: single condition rule — score equals condition evaluate() result
- [x] T83. Test: multi-condition rule — scores multiplied (0.8 * 0.5 = 0.4)
- [x] T84. Test: short-circuits on first 0.0 condition (second condition never called)
- [x] T85. Test: response_curve applied per condition before multiplication
- [x] T86. Test: invert applied per condition
- [x] T87. Test: score_threshold filters out rules below threshold
- [x] T88. Test: rule with empty conditions scores 1.0 (unconditional)
- [x] T89. Test: empty rules array returns empty results
- [x] T90. Test: returned results contain {rule: RS_Rule, score: float} dictionaries

**Implementation:**

- [x] T91. Create `scripts/utils/qb/u_rule_scorer.gd` — static `score_rules(rules, context) -> Array[Dictionary]`
- [x] T92. All scorer tests green

Completion note (2026-02-25): Added scorer test suite (9 tests), implemented `U_RuleScorer`, and verified:
- QB scorer suite: 9/9 passing (`test_rule_scorer`)
- Style suite: 12/12 passing (`tests/unit/style`)

### 1F — Selector (TDD)

**Tests first:**

- [x] T93. Create `tests/unit/qb/test_rule_selector.gd`
- [x] T94. Test: ungrouped rules all appear in winners
- [x] T95. Test: grouped rules — highest score wins
- [x] T96. Test: grouped rules — priority tiebreak when scores equal
- [x] T97. Test: grouped rules — alphabetical rule_id tiebreak when score and priority equal
- [x] T98. Test: mixed grouped + ungrouped — both types represented in winners
- [x] T99. Test: multiple decision groups — each group produces its own winner
- [x] T100. Test: empty input returns empty winners

**Implementation:**

- [x] T101. Create `scripts/utils/qb/u_rule_selector.gd` — static `select_winners(scored_results) -> Array[Dictionary]`
- [x] T102. All selector tests green

Completion note (2026-02-25): Added selector test suite (7 tests), implemented `U_RuleSelector`, and verified:
- QB selector suite: 7/7 passing (`test_rule_selector`)
- Style suite: 12/12 passing (`tests/unit/style`)

### 1G — State Tracker (TDD)

**Tests first:**

- [x] T103. Create `tests/unit/qb/test_rule_state_tracker.gd`
- [x] T104. Test: tick_cooldowns decrements active cooldowns
- [x] T105. Test: is_on_cooldown returns true during cooldown, false after expiry
- [x] T106. Test: mark_fired sets cooldown for rule+context pair
- [x] T107. Test: per-context cooldown isolation (rule on cooldown for context A, not for context B)
- [x] T108. Test: check_rising_edge returns true on false→true transition
- [x] T109. Test: check_rising_edge returns false on true→true (already true)
- [x] T110. Test: check_rising_edge returns false on false→false
- [x] T111. Test: rising edge resets after true→false→true cycle
- [x] T112. Test: mark_one_shot_spent prevents future firing
- [x] T113. Test: is_one_shot_spent returns false for unfired rules
- [x] T114. Test: cleanup_stale_contexts removes contexts not in active set
- [x] T115. Test: cleanup_stale_contexts preserves contexts with active cooldowns

**Implementation:**

- [x] T116. Create `scripts/utils/qb/u_rule_state_tracker.gd` — `class_name RuleStateTracker extends RefCounted`
- [x] T117. All state tracker tests green

Completion note (2026-02-25): Added state-tracker test suite (12 tests), implemented `RuleStateTracker`, and verified:
- QB state tracker suite: 12/12 passing (`test_rule_state_tracker`)
- Style suite: 12/12 passing (`tests/unit/style`)

### 1H — Validator (TDD)

**Tests first:**

- [x] T118. Create `tests/unit/qb/test_rule_validator.gd`
- [x] T119. Test: valid rule with conditions and effects passes
- [x] T120. Test: empty rule_id fails validation
- [x] T121. Test: event trigger mode without trigger_event fails
- [x] T122. Test: RS_ConditionComponentField with empty component_type fails
- [x] T123. Test: RS_ConditionReduxField with empty state_path fails
- [x] T124. Test: RS_ConditionReduxField without dot separator fails
- [x] T125. Test: RS_EffectSetField with empty component_type fails
- [x] T126. Test: RS_EffectSetField with empty field_name fails
- [x] T127. Test: range_min >= range_max on numeric condition fails (when both non-zero)
- [x] T128. Test: grouped unconditional rule without rising_edge emits warning
- [x] T129. Test: returns valid_rules, errors_by_index, errors_by_rule_id structure

**Implementation:**

- [x] T130. Create `scripts/utils/qb/u_rule_validator.gd` — static `validate_rules(rules) -> Dictionary`
- [x] T131. All validator tests green

Completion note (2026-02-25): Added validator test suite (11 tests), implemented `U_RuleValidator`, and verified:
- QB validator suite: 11/11 passing (`test_rule_validator`)
- Style suite: 12/12 passing (`tests/unit/style`)

**Phase 1 commit checkpoint.** All library code tested in isolation. No v1 code touched.

---

## Phase 2 — Delete v1, Migrate Character State

### 2A — Delete v1

- [x] T132. Delete `scripts/ecs/systems/base_qb_rule_manager.gd`
- [x] T133. Delete `scripts/resources/qb/rs_qb_condition.gd`
- [x] T134. Delete `scripts/resources/qb/rs_qb_effect.gd`
- [x] T135. Delete `scripts/resources/qb/rs_qb_rule_definition.gd`
- [x] T136. Delete `scripts/utils/qb/u_qb_rule_evaluator.gd`
- [x] T137. Delete `scripts/utils/qb/u_qb_quality_provider.gd`
- [x] T138. Delete `scripts/utils/qb/u_qb_effect_executor.gd`
- [x] T139. Delete `scripts/utils/qb/u_qb_variant_utils.gd`
- [x] T140. Delete `scripts/utils/qb/u_qb_rule_validator.gd`
- [x] T141. Delete all v1 test files in `tests/unit/qb/` (only v1 files — preserve v2 tests from Phase 1)
- [x] T142. Delete `tests/integration/qb/test_qb_brain_data_pipeline.gd`
- [x] T143. Delete all 9 v1 `.tres` files in `resources/qb/` subdirectories
- [x] T144. Grep codebase for references to deleted class names — fix any remaining imports

Completion note (2026-02-25): Deleted all targeted v1 QB engine scripts/resources/tests (`T132-T143`) and removed stale deleted-class references from active code (`T144`). Verification:
- Stale-reference grep across `scripts/`, `scenes/`, `tests/`, `resources/`, and `project.godot`: 0 matches for deleted v1 class/file symbols
- Style suite: 12/12 passing (`tests/unit/style`)
- QB unit suite: 101/101 passing (`tests/unit/qb`)

### 2B — Recreate Character Rule Resources

- [x] T145. Create `resources/qb/character/cfg_pause_gate_paused.tres` — RS_Rule + RS_ConditionReduxField (state_path=`time.is_paused`, equals, match=`true`) + RS_EffectSetContextValue (is_gameplay_active=false), decision_group=`pause_gate`
- [x] T146. Create `resources/qb/character/cfg_pause_gate_shell.tres` — RS_ConditionReduxField (state_path=`navigation.shell`, not_equals, match=`gameplay`), decision_group=`pause_gate`
- [x] T147. Create `resources/qb/character/cfg_pause_gate_transitioning.tres` — RS_ConditionReduxField (state_path=`scene.is_transitioning`, equals, match=`true`), decision_group=`pause_gate`
- [x] T148. Create `resources/qb/character/cfg_spawn_freeze_rule.tres` — RS_ConditionComponentField (C_SpawnStateComponent.is_physics_frozen, binary)
- [x] T149. Create `resources/qb/character/cfg_death_sync_rule.tres` — RS_ConditionComponentField (C_HealthComponent.is_dead, binary)
- [x] T150. All 5 resources pass U_RuleValidator.validate_rules()

Completion note (2026-02-25): Added all 5 character rule resources with v2 `RS_Rule` + typed condition/effect subresources and validated them with a headless generation/validation script (`/tmp/create_qb_v2_character_rules.gd` calling `U_RuleValidator.validate_rules`). Verification:
- Validator: 5/5 resources loaded, 0 validation errors
- Style suite: 12/12 passing (`tests/unit/style`)
- QB unit suite: 101/101 passing (`tests/unit/qb`)

### 2C — Migrate S_CharacterStateSystem (TDD)

**Tests first:**

- [x] T151. Create `tests/unit/qb/test_character_state_system.gd`
- [x] T152. Test: brain data defaults reset each tick (is_gameplay_active=true, is_dead=false, etc.)
- [x] T153. Test: pause gate paused — is_gameplay_active set to false when time.is_paused=true
- [x] T154. Test: pause gate shell — is_gameplay_active set to false when navigation.shell != gameplay
- [x] T155. Test: pause gate transitioning — is_gameplay_active set to false when scene.is_transitioning=true
- [x] T156. Test: pause gates compete in decision group — only one winner fires per tick
- [x] T157. Test: spawn freeze — is_spawn_frozen=true when C_SpawnStateComponent.is_physics_frozen=true
- [x] T158. Test: spawn freeze clears when component reports unfrozen
- [x] T159. Test: death sync — is_dead=true when C_HealthComponent.is_dead=true
- [x] T160. Test: death sync clears when health component reports alive
- [x] T161. Test: health_percent populated from health component
- [x] T162. Test: is_grounded populated from CharacterBody3D/floating state
- [x] T163. Test: is_moving populated from velocity threshold
- [x] T164. Test: designer rules via `@export var rules` evaluated alongside defaults

**Implementation:**

- [x] T165. Rename `s_character_rule_manager.gd` → `s_character_state_system.gd`, class → `S_CharacterStateSystem`
- [x] T166. Replace `extends BaseQBRuleManager` with `extends BaseECSSystem`
- [x] T167. Add `@export var rules: Array[RS_Rule] = []` for designer-added rules
- [x] T168. Add `var _tracker := RuleStateTracker.new()` instance
- [x] T169. Migrate context building: `_build_entity_contexts()` + decomposed helpers (populate entity, components, health, movement, input)
- [x] T170. Implement `process_tick()`: tick cooldowns → build contexts → score → select → execute → write brain data
- [x] T171. Implement `_execute_effects(winners, context)` — iterate winner effects, call effect.execute(context)
- [x] T172. Migrate `_write_brain_data()` — copy context values to C_CharacterStateComponent
- [x] T173. Implement event subscription for any rules with event/both trigger modes
- [x] T174. Update scene references (`.tscn` files) to new script path/class name
- [x] T175. All character state system tests green

Completion note (2026-02-25): Added `test_character_state_system.gd` (13 tests, `T151-T164`) and migrated `S_CharacterStateSystem` end-to-end (`T165-T175`) with v2 scoring/selection, designer rules export, cooldown/rising-edge/one-shot tracking, and event-trigger subscriptions. Scene references were updated across gameplay scenes to `s_character_state_system.gd` / `S_CharacterStateSystem`. Verification:
- `@export var rules` remains `Array[Resource]` in implementation as a headless parser-stability fallback while validating to `RS_Rule` via `U_RuleValidator`.
- Character system suite: 13/13 passing (`test_character_state_system.gd`)
- QB unit suite: 114/114 passing (`tests/unit/qb`)
- Style suite: 12/12 passing (`tests/unit/style`)

**Integration test:**

- [x] T176. Create `tests/integration/qb/test_character_movement_pipeline.gd`
- [x] T177. Test: paused → movement system reads is_gameplay_active=false → movement blocked
- [x] T178. Test: unpaused → movement proceeds

Completion note (2026-02-25): Added `tests/integration/qb/test_character_movement_pipeline.gd` to validate the end-to-end character gate → movement pipeline in v2. Verification:
- QB integration suite (`tests/integration/qb`): 2/2 passing
- QB unit suite (`tests/unit/qb`): 114/114 passing
- Style suite (`tests/unit/style`): 12/12 passing

**Phase 2 commit checkpoint.** v1 deleted. Character brain data works identically. Green tests.

---

## Phase 3 — Migrate Game Events

### 3A — Recreate Game Rule Resources

- [x] T179. Create `resources/qb/game/cfg_checkpoint_rule.tres` — RS_Rule (trigger_mode=event, trigger_event=checkpoint_zone_entered) + RS_EffectPublishEvent (checkpoint_activation_requested, inject_entity_id=true)
- [x] T180. Create `resources/qb/game/cfg_victory_rule.tres` — RS_Rule (trigger_mode=event, trigger_event=victory_triggered) + RS_EffectPublishEvent (victory_execution_requested, inject_entity_id=true)

Completion note (2026-02-25): Added both v2 game event-forwarding rule resources (`cfg_checkpoint_rule.tres`, `cfg_victory_rule.tres`) using `RS_Rule` + `RS_EffectPublishEvent` with event trigger modes and `inject_entity_id = true`. Verification:
- Resource validation: `U_RuleValidator.validate_rules(...)` (2/2 valid, 0 errors)
- QB unit suite: 114/114 passing (`tests/unit/qb`)
- Style suite: 12/12 passing (`tests/unit/style`)

### 3B — Migrate S_GameEventSystem (TDD)

**Tests first:**

- [x] T181. Create `tests/unit/qb/test_game_event_system.gd`
- [x] T182. Test: checkpoint event received → checkpoint_activation_requested published with full payload
- [x] T183. Test: victory event received → victory_execution_requested published with full payload
- [x] T184. Test: entity_id from event context injected into published payload
- [x] T185. Test: designer-added event rules via `@export var rules` are subscribed and evaluated
- [x] T186. Test: event subscription cleaned up on _exit_tree
- [x] T187. Test: no tick processing when all rules are event-only (process_tick is no-op)
- [x] T188. Test: global tick context built and evaluated when a tick-mode rule is added via export

**Implementation:**

- [x] T189. Rename `s_game_rule_manager.gd` → `s_game_event_system.gd`, class → `S_GameEventSystem`
- [x] T190. Replace `extends BaseQBRuleManager` with `extends BaseECSSystem`
- [x] T191. Add `@export var rules: Array[RS_Rule] = []`
- [x] T192. Add `var _tracker := RuleStateTracker.new()` instance
- [x] T193. Implement `on_configured()`: validate rules, subscribe to trigger events for event/both mode rules
- [x] T194. Implement `_on_event_received(event_name, event)`: build context from payload + Redux state → score → select → execute effects
- [x] T195. Implement `process_tick(delta)`: if any rules are tick/both mode, build global context (Redux state snapshot) → score → select → execute
- [x] T196. Clean up event subscriptions in `_exit_tree()`
- [x] T197. Update scene references to new script path/class name
- [x] T198. All game event system tests green

Completion note (2026-02-25): Added `test_game_event_system.gd` (7 tests, `T181-T188`) and migrated `S_GameEventSystem` end-to-end (`T189-T198`) with v2 scoring/selection, event/tick trigger evaluation, validator-backed rule loading, cooldown/rising-edge/one-shot gating, and explicit event subscription cleanup. Scene references were updated across gameplay and integration fixtures to `s_game_event_system.gd` / `S_GameEventSystem`, and stale script UID references were removed from gameplay scenes to keep headless scene parsing stable after the script rename. Verification:
- `test_game_event_system.gd`: 7/7 passing
- QB unit suite (`tests/unit/qb`): 121/121 passing
- Style suite (`tests/unit/style`): 12/12 passing

**Integration tests:**

- [ ] T199. Create `tests/integration/qb/test_checkpoint_pipeline.gd`
- [ ] T200. Test: checkpoint zone enter → game event system → handler system → state update + typed event published
- [ ] T201. Create `tests/integration/qb/test_victory_pipeline.gd`
- [ ] T202. Test: victory zone enter → game event system → handler system → state update + victory executed event

**Phase 3 commit checkpoint.** Game event routing works. Handler systems unchanged.

---

## Phase 4 — Migrate Camera State

### 4A — Recreate Camera Rule Resources

- [ ] T203. Create `resources/qb/camera/cfg_camera_shake_rule.tres` — RS_Rule (trigger_mode=event, trigger_event=entity_death) + RS_EffectSetField (C_CameraStateComponent.shake_trauma, add, 0.5, clamp 0-1)
- [ ] T204. Create `resources/qb/camera/cfg_camera_zone_fov_rule.tres` — RS_Rule (trigger_mode=tick) + RS_ConditionReduxField (camera.in_fov_zone, equals, true) + RS_EffectSetField (C_CameraStateComponent.target_fov, set, 60.0)

### 4B — Migrate S_CameraStateSystem (TDD)

**Tests first:**

- [ ] T205. Create `tests/unit/qb/test_camera_state_system.gd`
- [ ] T206. Test: default rules loaded and pass validation
- [ ] T207. Test: shake trauma added on entity_death event (0.0 → 0.5)
- [ ] T208. Test: shake trauma clamped to 1.0 max on repeated events
- [ ] T209. Test: FOV zone — target_fov set when camera.in_fov_zone=true in Redux state
- [ ] T210. Test: FOV blending lerps camera.fov toward target_fov over time
- [ ] T211. Test: baseline FOV captured from authored Camera3D fov on first tick
- [ ] T212. Test: baseline FOV restored when camera.in_fov_zone becomes false
- [ ] T213. Test: designer-added rules via export evaluated alongside defaults
- [ ] T214. Test: event fan-out — shake event evaluated across all camera entities
- [ ] T215. Test: primary camera selection by entity_id "camera" or tag "camera"

**Implementation:**

- [ ] T216. Rename `s_camera_rule_manager.gd` → `s_camera_state_system.gd`, class → `S_CameraStateSystem`
- [ ] T217. Replace `extends BaseQBRuleManager` with `extends BaseECSSystem`
- [ ] T218. Add `@export var rules: Array[RS_Rule] = []`
- [ ] T219. Add `var _tracker := RuleStateTracker.new()` instance
- [ ] T220. Migrate camera context building (`_build_camera_contexts`, `_attach_camera_context`)
- [ ] T221. Implement `process_tick(delta)`: tick cooldowns → build camera contexts → score tick rules → select → execute → apply camera state
- [ ] T222. Implement event subscription + `_on_event_received()` with fan-out across camera entities
- [ ] T223. Migrate `_apply_camera_state()` — FOV blending (baseline capture, lerp, restore) + trauma shake (sine/cosine, decay) — all constants preserved
- [ ] T224. Update scene references to new script path/class name
- [ ] T225. All camera state system tests green

**Integration test:**

- [ ] T226. Create `tests/integration/qb/test_camera_shake_pipeline.gd`
- [ ] T227. Test: entity death event → camera shake effect applied to camera manager

**Phase 4 commit checkpoint.** Camera state works identically to v1.

---

## Phase 5 — Cleanup, Docs, Verification

### 5A — Codebase Verification

- [ ] T228. Grep for all deleted v1 class names — zero references remain: `BaseQBRuleManager`, `RS_QBCondition`, `RS_QBEffect`, `RS_QBRuleDefinition`, `U_QBRuleEvaluator`, `U_QBQualityProvider`, `U_QBEffectExecutor`, `U_QBVariantUtils`, `U_QBRuleValidator`, `S_CharacterRuleManager`, `S_GameRuleManager`, `S_CameraRuleManager`
- [ ] T229. Grep for old script paths — zero `.tscn` or `.gd` files reference deleted paths
- [ ] T230. Run style enforcement tests — all new files follow prefix patterns
- [ ] T231. Run full QB v2 test suite — all green
- [ ] T232. Run full ECS test suite — all green (handler systems unchanged)
- [ ] T233. Run full integration test suite — all green

### 5B — Documentation Updates

- [ ] T234. Update `AGENTS.md` — replace all v1 QB sections with v2 architecture (library model, typed resources, consumer pattern, scoring algorithm, context contract, anti-patterns)
- [ ] T235. Update `AGENTS.md` — remove `base_qb_rule_manager.gd` naming exception, add condition/effect subclass file patterns
- [ ] T236. Update `docs/general/STYLE_GUIDE.md` — remove base_qb_rule_manager exception, add `rs_condition_*.gd` and `rs_effect_*.gd` patterns, add `conditions/` and `effects/` subdirectory convention
- [ ] T237. Update `docs/general/DEV_PITFALLS.md` — replace v1 QB pitfalls with v2 pitfalls (no method-call fallback, typed arrays, effect subclasses, context-driven values)
- [ ] T238. Update continuation prompt with final status

### 5C — Final Commit

- [ ] T239. Record final test counts per suite
- [ ] T240. Commit v2 complete

---

## Notes

- Handler systems (`S_CheckpointHandlerSystem`, `S_VictoryHandlerSystem`, `S_DeathHandlerSystem`) are NOT modified — they subscribe to ECS events and have zero coupling to rule engine internals
- All `.tres` rule resources are recreated fresh with v2 resource types — v1 `.tres` files are deleted, not migrated
- The `base_qb_rule_manager.gd` naming exception in STYLE_GUIDE is removed since the file no longer exists
- Each phase ends with a verified-green commit before proceeding

## Links

- [Overview](qb-v2-overview.md)
- [Plan](qb-v2-plan.md)
- [Continuation Prompt](qb-v2-continuation-prompt.md)
- [v1 Tasks (archived)](v1/qb-rule-manager-tasks.md)
