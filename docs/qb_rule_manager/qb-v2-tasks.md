# QB Rule Engine v2 — Task Checklist

**Progress:** 0% (0 / 120 tasks complete)

---

## Phase 1 — Core Library (Stateless Engine)

### 1A — Path Resolver (TDD)

**Tests first:**

- [ ] T1. Create `tests/unit/qb/test_path_resolver.gd`
- [ ] T2. Test: resolves single-key Dictionary path (`{"health": 100}`, path `"health"` → `100`)
- [ ] T3. Test: resolves nested Dictionary path (`{"a": {"b": 5}}`, path `"a.b"` → `5`)
- [ ] T4. Test: resolves StringName Dictionary key when path is String (and vice versa)
- [ ] T5. Test: resolves Array index via string segment (`{"items": [10, 20]}`, path `"items.1"` → `20`)
- [ ] T6. Test: resolves Object property (`node.name`, path `"name"` → node name)
- [ ] T7. Test: resolves mixed nesting (Dict → Object → Dict)
- [ ] T8. Test: returns null for missing Dictionary key
- [ ] T9. Test: returns null for out-of-bounds Array index
- [ ] T10. Test: returns null for missing Object property (no method-call fallback)
- [ ] T11. Test: returns root value when path is empty string

**Implementation:**

- [ ] T12. Create `scripts/utils/qb/u_path_resolver.gd` — static `resolve(root: Variant, path: String) -> Variant`
- [ ] T13. All path resolver tests green

### 1B — Resource Definitions: Conditions (TDD)

**Tests first:**

- [ ] T14. Create `tests/unit/qb/test_condition_component_field.gd`
- [ ] T15. Test: numeric field normalized to 0-1 range (value=50, min=0, max=100 → 0.5)
- [ ] T16. Test: value below range_min clamps to 0.0
- [ ] T17. Test: value above range_max clamps to 1.0
- [ ] T18. Test: bool field returns 1.0 for true, 0.0 for false
- [ ] T19. Test: nested field_path resolves through component properties
- [ ] T20. Test: missing component in context returns 0.0
- [ ] T21. Test: missing field on component returns 0.0
- [ ] T22. Test: division-by-zero guard when range_min == range_max (value >= min → 1.0, else 0.0)

- [ ] T23. Create `tests/unit/qb/test_condition_redux_field.gd`
- [ ] T24. Test: normalize mode — numeric value mapped to 0-1 range
- [ ] T25. Test: equals mode — matching string returns 1.0, non-matching returns 0.0
- [ ] T26. Test: equals mode — bool true matched against string "true" returns 1.0
- [ ] T27. Test: not_equals mode — non-matching returns 1.0, matching returns 0.0
- [ ] T28. Test: nested state path resolves (e.g. `gameplay.completed_areas`)
- [ ] T29. Test: missing state path returns 0.0

- [ ] T30. Create `tests/unit/qb/test_condition_entity_tag.gd`
- [ ] T31. Test: tag present in entity_tags returns 1.0
- [ ] T32. Test: tag absent returns 0.0
- [ ] T33. Test: empty entity_tags array returns 0.0

- [ ] T34. Create `tests/unit/qb/test_condition_event_payload.gd`
- [ ] T35. Test: exists mode — non-null field returns 1.0, null/missing returns 0.0
- [ ] T36. Test: normalize mode — numeric field mapped to 0-1 range
- [ ] T37. Test: equals mode — string match returns 1.0
- [ ] T38. Test: missing event_payload in context returns 0.0

- [ ] T39. Create `tests/unit/qb/test_condition_constant.gd`
- [ ] T40. Test: returns configured score value regardless of context
- [ ] T41. Test: default score is 1.0

**Tests for base class behavior (response_curve + invert):**

- [ ] T42. Create `tests/unit/qb/test_base_condition.gd`
- [ ] T43. Test: response_curve remaps raw score (linear curve 0→0, 1→1 passthrough)
- [ ] T44. Test: response_curve with sigmoid shape remaps mid-range values
- [ ] T45. Test: invert flag flips score (0.7 → 0.3)
- [ ] T46. Test: response_curve applied before invert
- [ ] T47. Test: null response_curve passes score through unchanged

**Implementation:**

- [ ] T48. Create `scripts/resources/qb/rs_base_condition.gd` — base class with response_curve, invert, virtual evaluate()
- [ ] T49. Create `scripts/resources/qb/conditions/rs_condition_component_field.gd`
- [ ] T50. Create `scripts/resources/qb/conditions/rs_condition_redux_field.gd`
- [ ] T51. Create `scripts/resources/qb/conditions/rs_condition_entity_tag.gd`
- [ ] T52. Create `scripts/resources/qb/conditions/rs_condition_event_payload.gd`
- [ ] T53. Create `scripts/resources/qb/conditions/rs_condition_constant.gd`
- [ ] T54. All condition tests green

### 1C — Resource Definitions: Effects (TDD)

**Tests first:**

- [ ] T55. Create `tests/unit/qb/test_effect_dispatch_action.gd`
- [ ] T56. Test: dispatches action with correct type and payload to MockStateStore
- [ ] T57. Test: missing state_store in context is no-op (no crash)

- [ ] T58. Create `tests/unit/qb/test_effect_publish_event.gd`
- [ ] T59. Test: publishes event with correct name and payload
- [ ] T60. Test: entity_id injected from context when inject_entity_id is true
- [ ] T61. Test: entity_id NOT injected when inject_entity_id is false

- [ ] T62. Create `tests/unit/qb/test_effect_set_field.gd`
- [ ] T63. Test: set operation writes literal float value to component field
- [ ] T64. Test: add operation adds to existing component field value
- [ ] T65. Test: clamp applied when use_clamp is true
- [ ] T66. Test: use_context_value reads value from context path instead of literal
- [ ] T67. Test: missing component in context is no-op
- [ ] T68. Test: all value types (float, int, bool, string, string_name) resolve correctly

- [ ] T69. Create `tests/unit/qb/test_effect_set_context_value.gd`
- [ ] T70. Test: writes typed value to context dictionary key
- [ ] T71. Test: all value types write correctly

**Implementation:**

- [ ] T72. Create `scripts/resources/qb/rs_base_effect.gd` — base class with virtual execute()
- [ ] T73. Create `scripts/resources/qb/effects/rs_effect_dispatch_action.gd`
- [ ] T74. Create `scripts/resources/qb/effects/rs_effect_publish_event.gd`
- [ ] T75. Create `scripts/resources/qb/effects/rs_effect_set_field.gd`
- [ ] T76. Create `scripts/resources/qb/effects/rs_effect_set_context_value.gd`
- [ ] T77. All effect tests green

### 1D — Rule Resource

- [ ] T78. Create `scripts/resources/qb/rs_rule.gd` — typed arrays `Array[RS_BaseCondition]`, `Array[RS_BaseEffect]`
- [ ] T79. Verify in Godot editor: inspector shows condition subclass dropdown for conditions array
- [ ] T80. Verify in Godot editor: inspector shows effect subclass dropdown for effects array

### 1E — Scorer (TDD)

**Tests first:**

- [ ] T81. Create `tests/unit/qb/test_rule_scorer.gd`
- [ ] T82. Test: single condition rule — score equals condition evaluate() result
- [ ] T83. Test: multi-condition rule — scores multiplied (0.8 * 0.5 = 0.4)
- [ ] T84. Test: short-circuits on first 0.0 condition (second condition never called)
- [ ] T85. Test: response_curve applied per condition before multiplication
- [ ] T86. Test: invert applied per condition
- [ ] T87. Test: score_threshold filters out rules below threshold
- [ ] T88. Test: rule with empty conditions scores 1.0 (unconditional)
- [ ] T89. Test: empty rules array returns empty results
- [ ] T90. Test: returned results contain {rule: RS_Rule, score: float} dictionaries

**Implementation:**

- [ ] T91. Create `scripts/utils/qb/u_rule_scorer.gd` — static `score_rules(rules, context) -> Array[Dictionary]`
- [ ] T92. All scorer tests green

### 1F — Selector (TDD)

**Tests first:**

- [ ] T93. Create `tests/unit/qb/test_rule_selector.gd`
- [ ] T94. Test: ungrouped rules all appear in winners
- [ ] T95. Test: grouped rules — highest score wins
- [ ] T96. Test: grouped rules — priority tiebreak when scores equal
- [ ] T97. Test: grouped rules — alphabetical rule_id tiebreak when score and priority equal
- [ ] T98. Test: mixed grouped + ungrouped — both types represented in winners
- [ ] T99. Test: multiple decision groups — each group produces its own winner
- [ ] T100. Test: empty input returns empty winners

**Implementation:**

- [ ] T101. Create `scripts/utils/qb/u_rule_selector.gd` — static `select_winners(scored_results) -> Array[Dictionary]`
- [ ] T102. All selector tests green

### 1G — State Tracker (TDD)

**Tests first:**

- [ ] T103. Create `tests/unit/qb/test_rule_state_tracker.gd`
- [ ] T104. Test: tick_cooldowns decrements active cooldowns
- [ ] T105. Test: is_on_cooldown returns true during cooldown, false after expiry
- [ ] T106. Test: mark_fired sets cooldown for rule+context pair
- [ ] T107. Test: per-context cooldown isolation (rule on cooldown for context A, not for context B)
- [ ] T108. Test: check_rising_edge returns true on false→true transition
- [ ] T109. Test: check_rising_edge returns false on true→true (already true)
- [ ] T110. Test: check_rising_edge returns false on false→false
- [ ] T111. Test: rising edge resets after true→false→true cycle
- [ ] T112. Test: mark_one_shot_spent prevents future firing
- [ ] T113. Test: is_one_shot_spent returns false for unfired rules
- [ ] T114. Test: cleanup_stale_contexts removes contexts not in active set
- [ ] T115. Test: cleanup_stale_contexts preserves contexts with active cooldowns

**Implementation:**

- [ ] T116. Create `scripts/utils/qb/u_rule_state_tracker.gd` — `class_name RuleStateTracker extends RefCounted`
- [ ] T117. All state tracker tests green

### 1H — Validator (TDD)

**Tests first:**

- [ ] T118. Create `tests/unit/qb/test_rule_validator.gd`
- [ ] T119. Test: valid rule with conditions and effects passes
- [ ] T120. Test: empty rule_id fails validation
- [ ] T121. Test: event trigger mode without trigger_event fails
- [ ] T122. Test: RS_ConditionComponentField with empty component_type fails
- [ ] T123. Test: RS_ConditionReduxField with empty state_path fails
- [ ] T124. Test: RS_ConditionReduxField without dot separator fails
- [ ] T125. Test: RS_EffectSetField with empty component_type fails
- [ ] T126. Test: RS_EffectSetField with empty field_name fails
- [ ] T127. Test: range_min >= range_max on numeric condition fails (when both non-zero)
- [ ] T128. Test: grouped unconditional rule without rising_edge emits warning
- [ ] T129. Test: returns valid_rules, errors_by_index, errors_by_rule_id structure

**Implementation:**

- [ ] T130. Create `scripts/utils/qb/u_rule_validator.gd` — static `validate_rules(rules) -> Dictionary`
- [ ] T131. All validator tests green

**Phase 1 commit checkpoint.** All library code tested in isolation. No v1 code touched.

---

## Phase 2 — Delete v1, Migrate Character State

### 2A — Delete v1

- [ ] T132. Delete `scripts/ecs/systems/base_qb_rule_manager.gd`
- [ ] T133. Delete `scripts/resources/qb/rs_qb_condition.gd`
- [ ] T134. Delete `scripts/resources/qb/rs_qb_effect.gd`
- [ ] T135. Delete `scripts/resources/qb/rs_qb_rule_definition.gd`
- [ ] T136. Delete `scripts/utils/qb/u_qb_rule_evaluator.gd`
- [ ] T137. Delete `scripts/utils/qb/u_qb_quality_provider.gd`
- [ ] T138. Delete `scripts/utils/qb/u_qb_effect_executor.gd`
- [ ] T139. Delete `scripts/utils/qb/u_qb_variant_utils.gd`
- [ ] T140. Delete `scripts/utils/qb/u_qb_rule_validator.gd`
- [ ] T141. Delete all v1 test files in `tests/unit/qb/` (only v1 files — preserve v2 tests from Phase 1)
- [ ] T142. Delete `tests/integration/qb/test_qb_brain_data_pipeline.gd`
- [ ] T143. Delete all 9 v1 `.tres` files in `resources/qb/` subdirectories
- [ ] T144. Grep codebase for references to deleted class names — fix any remaining imports

### 2B — Recreate Character Rule Resources

- [ ] T145. Create `resources/qb/character/cfg_pause_gate_paused.tres` — RS_Rule + RS_ConditionReduxField (state_path=`time.is_paused`, equals, match=`true`) + RS_EffectSetContextValue (is_gameplay_active=false), decision_group=`pause_gate`
- [ ] T146. Create `resources/qb/character/cfg_pause_gate_shell.tres` — RS_ConditionReduxField (state_path=`navigation.shell`, not_equals, match=`gameplay`), decision_group=`pause_gate`
- [ ] T147. Create `resources/qb/character/cfg_pause_gate_transitioning.tres` — RS_ConditionReduxField (state_path=`scene.is_transitioning`, equals, match=`true`), decision_group=`pause_gate`
- [ ] T148. Create `resources/qb/character/cfg_spawn_freeze_rule.tres` — RS_ConditionComponentField (C_SpawnStateComponent.is_physics_frozen, binary)
- [ ] T149. Create `resources/qb/character/cfg_death_sync_rule.tres` — RS_ConditionComponentField (C_HealthComponent.is_dead, binary)
- [ ] T150. All 5 resources pass U_RuleValidator.validate_rules()

### 2C — Migrate S_CharacterStateSystem (TDD)

**Tests first:**

- [ ] T151. Create `tests/unit/qb/test_character_state_system.gd`
- [ ] T152. Test: brain data defaults reset each tick (is_gameplay_active=true, is_dead=false, etc.)
- [ ] T153. Test: pause gate paused — is_gameplay_active set to false when time.is_paused=true
- [ ] T154. Test: pause gate shell — is_gameplay_active set to false when navigation.shell != gameplay
- [ ] T155. Test: pause gate transitioning — is_gameplay_active set to false when scene.is_transitioning=true
- [ ] T156. Test: pause gates compete in decision group — only one winner fires per tick
- [ ] T157. Test: spawn freeze — is_spawn_frozen=true when C_SpawnStateComponent.is_physics_frozen=true
- [ ] T158. Test: spawn freeze clears when component reports unfrozen
- [ ] T159. Test: death sync — is_dead=true when C_HealthComponent.is_dead=true
- [ ] T160. Test: death sync clears when health component reports alive
- [ ] T161. Test: health_percent populated from health component
- [ ] T162. Test: is_grounded populated from CharacterBody3D/floating state
- [ ] T163. Test: is_moving populated from velocity threshold
- [ ] T164. Test: designer rules via `@export var rules` evaluated alongside defaults

**Implementation:**

- [ ] T165. Rename `s_character_rule_manager.gd` → `s_character_state_system.gd`, class → `S_CharacterStateSystem`
- [ ] T166. Replace `extends BaseQBRuleManager` with `extends BaseECSSystem`
- [ ] T167. Add `@export var rules: Array[RS_Rule] = []` for designer-added rules
- [ ] T168. Add `var _tracker := RuleStateTracker.new()` instance
- [ ] T169. Migrate context building: `_build_entity_contexts()` + decomposed helpers (populate entity, components, health, movement, input)
- [ ] T170. Implement `process_tick()`: tick cooldowns → build contexts → score → select → execute → write brain data
- [ ] T171. Implement `_execute_effects(winners, context)` — iterate winner effects, call effect.execute(context)
- [ ] T172. Migrate `_write_brain_data()` — copy context values to C_CharacterStateComponent
- [ ] T173. Implement event subscription for any rules with event/both trigger modes
- [ ] T174. Update scene references (`.tscn` files) to new script path/class name
- [ ] T175. All character state system tests green

**Integration test:**

- [ ] T176. Create `tests/integration/qb/test_character_movement_pipeline.gd`
- [ ] T177. Test: paused → movement system reads is_gameplay_active=false → movement blocked
- [ ] T178. Test: unpaused → movement proceeds

**Phase 2 commit checkpoint.** v1 deleted. Character brain data works identically. Green tests.

---

## Phase 3 — Migrate Game Events

### 3A — Recreate Game Rule Resources

- [ ] T179. Create `resources/qb/game/cfg_checkpoint_rule.tres` — RS_Rule (trigger_mode=event, trigger_event=checkpoint_zone_entered) + RS_EffectPublishEvent (checkpoint_activation_requested, inject_entity_id=true)
- [ ] T180. Create `resources/qb/game/cfg_victory_rule.tres` — RS_Rule (trigger_mode=event, trigger_event=victory_triggered) + RS_EffectPublishEvent (victory_execution_requested, inject_entity_id=true)

### 3B — Migrate S_GameEventSystem (TDD)

**Tests first:**

- [ ] T181. Create `tests/unit/qb/test_game_event_system.gd`
- [ ] T182. Test: checkpoint event received → checkpoint_activation_requested published with full payload
- [ ] T183. Test: victory event received → victory_execution_requested published with full payload
- [ ] T184. Test: entity_id from event context injected into published payload
- [ ] T185. Test: designer-added event rules via `@export var rules` are subscribed and evaluated
- [ ] T186. Test: event subscription cleaned up on _exit_tree
- [ ] T187. Test: no tick processing when all rules are event-only (process_tick is no-op)
- [ ] T188. Test: global tick context built and evaluated when a tick-mode rule is added via export

**Implementation:**

- [ ] T189. Rename `s_game_rule_manager.gd` → `s_game_event_system.gd`, class → `S_GameEventSystem`
- [ ] T190. Replace `extends BaseQBRuleManager` with `extends BaseECSSystem`
- [ ] T191. Add `@export var rules: Array[RS_Rule] = []`
- [ ] T192. Add `var _tracker := RuleStateTracker.new()` instance
- [ ] T193. Implement `on_configured()`: validate rules, subscribe to trigger events for event/both mode rules
- [ ] T194. Implement `_on_event_received(event_name, event)`: build context from payload + Redux state → score → select → execute effects
- [ ] T195. Implement `process_tick(delta)`: if any rules are tick/both mode, build global context (Redux state snapshot) → score → select → execute
- [ ] T196. Clean up event subscriptions in `_exit_tree()`
- [ ] T197. Update scene references to new script path/class name
- [ ] T198. All game event system tests green

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
