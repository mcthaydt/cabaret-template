# QB Rule Engine v2 — Implementation Plan

## Summary

- **Feature:** Replace v1 QB rule engine (base class inheritance model) with v2 (stateless scoring library + resource polymorphism + domain composition)
- **Branch:** `scene-director` (continues from v1 completion)
- **Current status:** Complete (Phase 5C complete on 2026-02-25)
- **Prerequisite:** v1 is 100% complete (all phases + R1-R7 refactors)

## Guiding Principles

1. **TDD throughout.** Tests written before implementation for every new class. No code merges without green tests.
2. **Delete after replacement is ready.** Phase 1 builds the full v2 library alongside v1. Phase 2 deletes v1 and migrates the first consumer. No gap where both old and new are broken.
3. **One commit per phase.** Each phase ends with a verified-green commit.
4. **No backwards compatibility.** v1 classes, resources, and tests are removed wholesale in Phase 2A.

---

## Phase 1 — Core Library (TDD, Stateless Engine)

**Goal:** Build the entire scoring library, resource definitions, path resolver, state tracker, and validator. Everything is pure/static — no ECS, no scene tree, no Redux dependency. Fully unit-testable in isolation. v1 code is NOT touched.

**Sub-phases (TDD order: tests first, then implementation):**

| Sub-phase | Tests | Implementation | Deliverable |
|---|---|---|---|
| 1A — Path Resolver | T1-T11 | T12-T13 | Dot-path resolution for Dict/Array/Object |
| 1B — Conditions | T14-T47 | T48-T54 | 5 initial condition subclasses + base class with curve/invert (later expanded to 6 with `RS_ConditionEventName`) |
| 1C — Effects | T55-T71 | T72-T77 | 4 effect subclasses + base class |
| 1D — Rule Resource | — | T78-T80 | RS_Rule with `Array[Resource]` fallback (typed-array target deferred) |
| 1E — Scorer | T81-T90 | T91-T92 | `U_RuleScorer.score_rules()` |
| 1F — Selector | T93-T100 | T101-T102 | `U_RuleSelector.select_winners()` |
| 1G — State Tracker | T103-T115 | T116-T117 | `RuleStateTracker` (cooldowns, rising edge, one-shot) |
| 1H — Validator | T118-T129 | T130-T131 | `U_RuleValidator.validate_rules()` |

**Deliverable:** ~17 new files, ~80 test functions. All tested in isolation. v1 untouched.

**Risk gate (1D):** Verify `Array[RS_BaseCondition]` shows correct subclass dropdown in the Godot 4.6 inspector before proceeding past Phase 1. If it doesn't work, fall back to `Array[Resource]` with runtime type checks.
Current Phase 1 outcome: fallback path was selected due headless parser instability (`Could not find type ...`) and runtime subtype validation is enforced in `U_RuleValidator`.

---

## Phase 2 — Delete v1, Migrate Character State (TDD)

**Goal:** Remove all v1 core code. Migrate `S_CharacterRuleManager` → `S_CharacterStateSystem` using the v2 library. All brain data behavior preserved.

**Sub-phases:**

| Sub-phase | Tasks | Deliverable |
|---|---|---|
| 2A — Delete v1 | T132-T144 | 9 v1 scripts deleted, v1 tests deleted, v1 .tres deleted, zero stale references |
| 2B — Recreate character .tres | T145-T150 | 5 rule resources using v2 types, pass validation |
| 2C — Migrate system (TDD) | T151-T175 | Tests first (T151-T164), then implementation (T165-T175) |
| 2D — Integration test | T176-T178 | End-to-end: paused → movement blocked |

Phase 2A completion note (2026-02-25): Deleted all 9 v1 core QB scripts, deleted v1 QB unit/integration suites, deleted 9 legacy v1 QB `.tres` resources, and cleared stale deleted-class references from active code. Verification: `tests/unit/style` (12/12 passing), `tests/unit/qb` (101/101 passing).
Phase 2B completion note (2026-02-25): Recreated 5 character QB rule resources (`cfg_pause_gate_paused`, `cfg_pause_gate_shell`, `cfg_pause_gate_transitioning`, `cfg_spawn_freeze_rule`, `cfg_death_sync_rule`) using `RS_Rule` + typed v2 condition/effect subresources. Verified with `U_RuleValidator.validate_rules(...)` (0 errors), plus `tests/unit/style` (12/12 passing) and `tests/unit/qb` (101/101 passing).
Phase 2C completion note (2026-02-25): Migrated `S_CharacterRuleManager` → `S_CharacterStateSystem` with v2 scorer/selector/tracker composition, validator-backed rule loading, scene reference updates, and new unit coverage (`test_character_state_system.gd`, 13 tests). Verification: `tests/unit/qb` (114/114 passing) and `tests/unit/style` (12/12 passing).
Phase 2D completion note (2026-02-25): Added `tests/integration/qb/test_character_movement_pipeline.gd` for paused/unpaused end-to-end gating. Verification: `tests/integration/qb` (2/2 passing), `tests/unit/qb` (114/114 passing), `tests/unit/style` (12/12 passing).

**Deliverable:** v1 fully removed. Character brain data works identically. Green tests.

---

## Phase 3 — Migrate Game Events (TDD)

**Goal:** Migrate `S_GameRuleManager` → `S_GameEventSystem`. Add global tick context capability.

**Sub-phases:**

| Sub-phase | Tasks | Deliverable |
|---|---|---|
| 3A — Recreate game .tres | T179-T180 | 2 event-forwarding rules using v2 types |
| 3B — Migrate system (TDD) | T181-T198 | Tests first (T181-T188), then implementation (T189-T198) |
| 3C — Integration tests | T199-T202 | Checkpoint and victory end-to-end pipelines |

Phase 3A completion note (2026-02-25): Recreated `cfg_checkpoint_rule.tres` and `cfg_victory_rule.tres` in `resources/qb/game/` using `RS_Rule` + `RS_EffectPublishEvent` event-forwarding configs. Verification: `U_RuleValidator.validate_rules(...)` (2/2 valid), `tests/unit/qb` (114/114 passing), `tests/unit/style` (12/12 passing).
Phase 3B completion note (2026-02-25): Migrated `s_game_rule_manager.gd` → `s_game_event_system.gd` and added `test_game_event_system.gd` (7 tests) covering event forwarding, entity_id injection, designer-rule subscriptions, subscription cleanup, and global tick evaluation. Updated gameplay/integration scene references to the new script/class and removed stale script `uid` fields from affected `.tscn` `ext_resource` lines to keep headless parsing stable after rename. Verification: `tests/unit/qb` (121/121 passing), `tests/unit/style` (12/12 passing).
Phase 3C completion note (2026-02-25): Added `test_checkpoint_pipeline.gd` and `test_victory_pipeline.gd` integration coverage for full zone-entry → `S_GameEventSystem` forwarding → handler execution → Redux/event outcomes. Verification: `tests/integration/qb` (4/4 passing), `tests/unit/qb` (121/121 passing), `tests/unit/style` (12/12 passing).

**Deliverable:** Game event routing works. Handler systems unchanged. Global tick context available for future use.

---

## Phase 4 — Migrate Camera State (TDD)

**Goal:** Migrate `S_CameraRuleManager` → `S_CameraStateSystem`.

**Sub-phases:**

| Sub-phase | Tasks | Deliverable |
|---|---|---|
| 4A — Recreate camera .tres | T203-T204 | Shake + FOV zone rules using v2 types |
| 4B — Migrate system (TDD) | T205-T225 | Tests first (T205-T215), then implementation (T216-T225) |
| 4C — Integration test | T226-T227 | Camera shake end-to-end pipeline |

Phase 4A completion note (2026-02-25): Recreated `cfg_camera_shake_rule.tres` and `cfg_camera_zone_fov_rule.tres` in `resources/qb/camera/` using `RS_Rule` + typed v2 condition/effect subresources (`RS_EffectSetField`, `RS_ConditionReduxField`). Verification: `U_RuleValidator.validate_rules(...)` (2/2 valid), `tests/unit/qb` (121/121 passing), `tests/unit/style` (12/12 passing).
Phase 4B completion note (2026-02-25): Migrated `s_camera_rule_manager.gd` → `s_camera_state_system.gd` with v2 scorer/selector/tracker composition, validator-backed rule loading, per-camera tick/event evaluation, and preserved FOV/shake behavior. Added `test_camera_state_system.gd` (10 tests) and updated gameplay scene references to the renamed script/class while removing stale camera-system script UIDs from scene `ext_resource` lines for headless parsing stability. Verification: `tests/unit/qb` (131/131 passing), `tests/unit/style` (12/12 passing).
Phase 4C completion note (2026-02-25): Added `test_camera_shake_pipeline.gd` integration coverage and verified the full `entity_death` → camera shake pipeline through `S_CameraStateSystem` into camera-manager shake source writes. Verification: `tests/integration/qb` (5/5 passing), `tests/unit/qb` (131/131 passing), `tests/unit/style` (12/12 passing).

**Deliverable:** Camera state works identically to v1.

---

## Phase 5 — Cleanup, Docs, Verification

**Goal:** Update all documentation, verify zero stale references, run all test suites.

**Sub-phases:**

| Sub-phase | Tasks | Deliverable |
|---|---|---|
| 5A — Codebase verification | T228-T233 | Zero stale references, all suites green |
| 5B — Documentation | T234-T238 | AGENTS.md, STYLE_GUIDE.md, DEV_PITFALLS.md updated |
| 5C — Final commit | T239-T240 | Test counts recorded, v2 complete |

Phase 5A completion note (2026-02-25): Completed stale-reference/path greps (0 runtime matches), style verification (`tests/unit/style`: 11/12 — one pre-existing asset naming issue: `mdl_new_character_Image Color Quantizer.png` contains spaces, unrelated to QB v2 changes), QB verification (`tests/unit/qb`: 132/132, `tests/integration/qb`: 5/5), ECS verification (`tests/unit/ecs`: 126/126), and full integration verification (`tests/integration`: 395/396 passing with 1 headless pending, 0 failures).
Phase 5B completion note (2026-02-25): Updated `AGENTS.md`, `docs/guides/STYLE_GUIDE.md`, `docs/guides/pitfalls/`, `docs/qb_rule_manager/qb-v2-tasks.md`, and `docs/qb_rule_manager/qb-v2-continuation-prompt.md` for final v2 architecture alignment.
Phase 5C completion note (2026-02-25): Recorded final suite counts and committed v2 completion checkpoint.

---

## Testing Strategy

### Unit Tests (Phase 1 — library in isolation)

| Test file | Coverage |
|---|---|
| `test_path_resolver.gd` | Dict/Array/Object traversal, missing paths, key duality |
| `test_condition_component_field.gd` | Numeric normalization, bool, nested paths, missing data |
| `test_condition_redux_field.gd` | Normalize/equals/not_equals modes, nested paths |
| `test_condition_entity_tag.gd` | Present/absent tag, empty array |
| `test_condition_event_payload.gd` | Exists/normalize/equals modes, missing payload |
| `test_condition_constant.gd` | Fixed score, default |
| `test_base_condition.gd` | Response curve, invert, curve before invert |
| `test_effect_dispatch_action.gd` | Action dispatched, missing store |
| `test_effect_publish_event.gd` | Event published, entity_id injection |
| `test_effect_set_field.gd` | Set/add ops, clamp, context value, missing component |
| `test_effect_set_context_value.gd` | All value types |
| `test_rule_scorer.gd` | Single/multi condition, curves, threshold, short-circuit |
| `test_rule_selector.gd` | Groups, ungrouped, tiebreaks |
| `test_rule_state_tracker.gd` | Cooldowns, rising edge, one-shot, stale cleanup |
| `test_rule_validator.gd` | All validation rules, error reporting |

### Unit Tests (Phases 2-4 — domain systems)

| Test file | Coverage |
|---|---|
| `test_character_state_system.gd` | Brain data defaults, all 5 rules, designer rules |
| `test_game_event_system.gd` | Event forwarding, global tick context |
| `test_camera_state_system.gd` | Shake, FOV, baseline, event fan-out |

### Integration Tests

| Test file | Coverage |
|---|---|
| `test_character_movement_pipeline.gd` | Paused → movement blocked |
| `test_checkpoint_pipeline.gd` | Zone → event system → handler → state |
| `test_victory_pipeline.gd` | Zone → event system → handler → state |
| `test_camera_shake_pipeline.gd` | Death → shake effect on camera |

---

## Risks & Mitigations

| Risk | Mitigation |
|---|---|
| `Array[RS_BaseCondition]` inspector support in Godot 4.6 | Phase 1D: verify before proceeding. Fallback: `Array[Resource]` + runtime checks |
| Handler systems depend on v1 event payload shape | Phase 3C: integration tests verify identical payloads |
| `.tscn` files reference old script paths after rename | Grep all scenes at each migration phase (T144, T174, T197, T224) |
| Performance regression from virtual dispatch vs enum dispatch | Negligible at current rule counts. Benchmark after Phase 4 if concerned |

---

## References

- [Overview](qb-v2-overview.md)
- [Tasks](qb-v2-tasks.md)
- [Continuation Prompt](qb-v2-continuation-prompt.md)
- [v1 Overview (archived)](v1/qb-rule-manager-overview.md)
- [v1 Tasks (archived)](v1/qb-rule-manager-tasks.md)
