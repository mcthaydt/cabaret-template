# Lighting Manager - Task Checklist

**Progress:** 51 / 70 tasks complete
**Unit Tests:** 26 / 26 passing
**Integration Tests:** 0 / 0 passing
**Manual QA:** 0 / 0 complete

---

## Locked Decisions (from planning)

- Character shading is **full unlit** (ignores `Light3D` for character look).
- Zone authoring uses **dedicated controllers** (`Inter_CharacterLightZone`).
- Runtime source of truth is **scene/resources only** for phase 1 (no Redux slice yet).
- Target entities are **all gameplay actors tagged `character`** (player + NPCs + enemies/companions).
- Non-character proxies/dummies should not use the `character` tag.
- Overlap resolution is **weighted blend** with priority.
- Overlap blend must be **deterministic** (stable ordering/tie-break rules).
- Outside zones uses **scene default profile**.
- Existing physical mood/objective/signpost lights are **replaced with zones**, using current light values as migration references.

---

## Planned Public API / Types

- `scripts/interfaces/i_character_lighting_manager.gd` (runtime lighting behavior only; no debug methods)
- `scripts/managers/m_character_lighting_manager.gd`
- `scripts/gameplay/inter_character_light_zone.gd`
- `scripts/resources/lighting/rs_character_lighting_profile.gd`
- `scripts/resources/lighting/rs_character_light_zone_config.gd`
- `assets/shaders/sh_character_zone_lighting.gdshader`

---

## Phase 0: Documentation + Scaffolding

**Exit Criteria:** task list, continuation prompt, and implementation skeleton are in place with naming/style compliance.

- [x] LM001 Create interface stub `scripts/interfaces/i_character_lighting_manager.gd`
- [x] LM002 Create manager stub `scripts/managers/m_character_lighting_manager.gd`
- [x] LM003 Create zone controller stub `scripts/gameplay/inter_character_light_zone.gd`
- [x] LM004 Create resource stubs:
  - `scripts/resources/lighting/rs_character_lighting_profile.gd`
  - `scripts/resources/lighting/rs_character_light_zone_config.gd`
- [x] LM005 Create shader stub `assets/shaders/sh_character_zone_lighting.gdshader`
- [x] LM006 Add manager node `M_CharacterLightingManager` under root `Managers` in `scenes/root.tscn`
- [x] LM007 Register ServiceLocator key in `scripts/root.gd` (`character_lighting_manager`)
- [x] LM064 Update `docs/general/STYLE_GUIDE.md` with lighting category naming conventions and locked shader filename guidance
- [x] LM065 Update `tests/unit/style/test_style_enforcement.gd` prefix rules to include `scripts/resources/lighting` and enforce `rs_` pattern
- [x] LM008 Run style enforcement: `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
  - 2026-02-12: PASS after removing duplicate workspace directories (`resources/interactions/* 2`).

---

## Phase 1: Resource + Blend Math (TDD)

**Exit Criteria:** profile/config resources and blend math utility are implemented with unit coverage.

- [x] LM009 (Red) Create `tests/unit/lighting/test_character_lighting_profile.gd`
- [x] LM010 (Green) Implement `RS_CharacterLightingProfile` (tint, intensity, smoothing, validation/clamp)
- [x] LM011 (Red) Create `tests/unit/lighting/test_character_light_zone_config.gd`
- [x] LM012 (Green) Implement `RS_CharacterLightZoneConfig` (shape, dimensions, offset, falloff, priority, profile ref)
- [x] LM013 (Red) Create `tests/unit/lighting/test_character_lighting_blend_math.gd`
- [x] LM014 (Green) Implement blend helper utility (weights + normalization + default blend path)
- [x] LM015 Verify deep-copy semantics where mutable dictionaries/arrays are exposed
- [x] LM016 Re-run phase test suites + style test
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/lighting` (11 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/style` (12 tests)

---

## Phase 2: Zone Controller Authoring Pattern (TDD)

**Exit Criteria:** zones are authorable like interactable controllers and produce stable influence weights.

- [x] LM017 (Red) Create `tests/unit/interactables/test_inter_character_light_zone.gd`
- [x] LM018 (Green) Implement `Inter_CharacterLightZone` using volume-controller pattern
- [x] LM019 Implement area auto-create/adopt behavior and settings duplication (`resource_local_to_scene = true`)
- [x] LM020 Implement influence query API from controller (position -> weight)
- [x] LM021 Implement priority output and profile reference output for manager consumption
- [x] LM022 Add transition gating behavior parity with other interactable controllers where applicable
- [x] LM023 Add zone metadata needed by manager cache (stable id/name/profile snapshot)
- [x] LM024 Re-run unit + style tests
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables -gselect=test_inter_character_light_zone` (4 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables` (52 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/style` (12 tests)

---

## Phase 3: Shader + Material Application Pipeline (TDD)

**Exit Criteria:** tagged character meshes use unlit zone shader and can receive tint/intensity parameters.

- [x] LM025 (Red) Create `tests/unit/lighting/test_character_lighting_material_applier.gd`
  - 2026-02-12: RED confirmed (`tools/run_gut_suite.sh -gdir=res://tests/unit/lighting -gselect=test_character_lighting_material_applier`) with 5 expected failures while helper was missing.
- [x] LM026 (Green) Implement helper to collect relevant `MeshInstance3D` targets per character entity
- [x] LM027 (Green) Implement material swap to `ShaderMaterial` with restore-cache of original material
- [x] LM028 (Green) Implement shader params (base tint, effective tint, effective intensity)
- [x] LM029 Ensure shader ignores physical lights and still preserves texture/albedo read path
- [x] LM030 Add no-op fallback when target mesh/material is missing
- [x] LM031 Add teardown/restore logic for scene unloads
- [x] LM032 Re-run unit + style tests
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/lighting -gselect=test_character_lighting_material_applier` (5 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/lighting` (16 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/style` (12 tests)

---

## Phase 4: Character Lighting Manager Core (TDD)

**Exit Criteria:** manager discovers tagged characters + zones, computes weighted blend, and applies results every physics tick.

- [x] LM033 (Red) Create `tests/unit/managers/test_character_lighting_manager.gd`
  - 2026-02-12: RED confirmed (`tools/run_gut_suite.sh -gdir=res://tests/unit/managers -gselect=test_character_lighting_manager`) with 5 expected failures against stub manager behavior.
- [x] LM034 (Green) Implement manager lifecycle (`PROCESS_MODE_ALWAYS`, dependency discovery, cache init)
- [x] LM035 Implement entity discovery via ECS manager (`get_entities_by_tag("character")`) for player + NPC parity
- [x] LM036 Implement zone discovery from active gameplay scene `Lighting` subtree
- [x] LM037 Implement scene default profile lookup (`Lighting/CharacterLightingSettings`)
- [x] LM038 Implement weighted blend algorithm with priority, falloff, and deterministic tie-break rules
- [x] LM039 Implement transition gating using scene manager/state checks
- [x] LM040 Implement scene swap cache invalidation on `scene/swapped`
- [x] LM041 Implement support for dynamically added/removed tagged entities
- [x] LM042 Re-run unit + style tests
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/managers -gselect=test_character_lighting_manager` (8 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/managers` (149 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/lighting` (16 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/style` (12 tests)

---

## Phase 5: Gameplay Scene Migration (Reference Existing Lights)

**Exit Criteria:** gameplay scenes/prefabs use zone-based character lighting data; physical mood/objective/signpost light nodes removed.

- [x] LM043 Audit existing light nodes in:
  - `scenes/gameplay/gameplay_alleyway.tscn`
  - `scenes/gameplay/gameplay_bar.tscn`
  - `scenes/gameplay/gameplay_exterior.tscn`
  - `scenes/gameplay/gameplay_interior_house.tscn`
  - related prefabs with objective/signpost lights
  - 2026-02-12 inventory:
    - Character mood lights under `Lighting`: `MoonLight` + `StreetLight_Warm` (`gameplay_alleyway`), `BarLight_Warm` + `EntranceLight_Cool` (`gameplay_bar`).
    - Objective/signpost glow lights: `GlowLight` under objective goals in all four scenes, plus tutorial sign `GlowLight` in `gameplay_interior_house`.
    - Prefab reference: `scenes/prefabs/prefab_goal_zone.tscn` includes `GlowLight` (objective visual cue baseline).
    - `Lighting` root exists in alleyway/bar but not exterior/interior; no `Inter_CharacterLightZone` or `CharacterLightingSettings` nodes are authored yet in audited scenes.
    - `Env_DirectionalLight3D` nodes in exterior/interior are environment/global lighting and tracked separately from zone migration targets.
- [x] LM044 Author scene default profiles from current scene lighting intent
  - 2026-02-12 authored defaults:
    - `resources/lighting/cfg_character_lighting_profile_alleyway.tres`
    - `resources/lighting/cfg_character_lighting_profile_bar.tres`
    - `resources/lighting/cfg_character_lighting_profile_exterior.tres`
    - `resources/lighting/cfg_character_lighting_profile_interior_house.tres`
  - Added `Lighting/CharacterLightingSettings` scene node bindings in:
    - `scenes/gameplay/gameplay_alleyway.tscn`
    - `scenes/gameplay/gameplay_bar.tscn`
    - `scenes/gameplay/gameplay_exterior.tscn`
    - `scenes/gameplay/gameplay_interior_house.tscn`
- [x] LM045 Add `Inter_CharacterLightZone` nodes to mirror current light placement/range/color/energy
  - 2026-02-12 added zone controllers + configs for mood lights in alleyway/bar and glow-light replacements in goal/signpost targets:
    - `scenes/gameplay/gameplay_alleyway.tscn`
    - `scenes/gameplay/gameplay_bar.tscn`
    - `scenes/gameplay/gameplay_exterior.tscn`
    - `scenes/gameplay/gameplay_interior_house.tscn`
    - `scenes/prefabs/prefab_goal_zone.tscn`
    - `resources/lighting/zones/cfg_character_light_zone_*.tres`
    - `resources/lighting/profiles/cfg_character_lighting_profile_*.tres`
- [x] LM046 Remove migrated `OmniLight3D` nodes used for character lighting mood
  - 2026-02-12 removed `MoonLight` + `StreetLight_Warm` (alleyway) and `BarLight_Warm` + `EntranceLight_Cool` (bar) after equivalent zone authoring.
- [x] LM047 Remove objective/signpost glow lights and replace with equivalent zones
  - 2026-02-12 replaced `GlowLight` objective/signpost nodes with `Inter_CharacterLightZone_*` nodes in all migrated gameplay scenes and `prefab_goal_zone`.
- [x] LM048 Preserve non-light visual readability cues (materials/particles/meshes) as needed
  - 2026-02-12 preserved objective visuals/particles (`Visual`, `Sparkles`) and signpost geometry while removing physical light nodes.
- [x] LM049 Validate each migrated scene loads without warnings
  - 2026-02-12 PASS via `tests/unit/interactables/test_scene_interaction_config_binding.gd` (loads migrated scenes/prefab without unexpected warnings/errors).
- [x] LM050 Run style enforcement + targeted scene manager and interactable tests
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/style` (12 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/unit/interactables` (52 tests)
  - 2026-02-12: PASS `tools/run_gut_suite.sh -gdir=res://tests/integration/scene_manager -gselect=test_basic_transitions` (13 tests)

---

## Phase 6: Integration + Hardening

**Exit Criteria:** integration tests pass and system is stable across transitions and respawns.

- [ ] LM051 (Red) Create `tests/integration/lighting/test_character_zone_lighting_flow.gd`
- [ ] LM052 (Green) Validate overlap blending, scene default fallback, transition behavior, and respawn behavior
- [ ] LM053 [REMOVED] Debug API scope removed by product decision
- [ ] LM054 [REMOVED] Debug logging scope removed by product decision
- [ ] LM055 Run full relevant suites (unit/integration/style)
- [ ] LM056 Manual QA pass across alleyway, bar, exterior, interior transitions

---

## Phase 7: Documentation and Handoff

**Exit Criteria:** docs are current and phase-complete with continuation context.

- [ ] LM057 Update `docs/lighting_manager/lighting-manager-tasks.md` progress counts + completion notes
- [ ] LM058 Update `docs/lighting_manager/lighting-manager-continuation-prompt.md` next-step + test status
- [ ] LM059 Update `AGENTS.md` with finalized character-zone-lighting architecture patterns (if new stable patterns emerged)
- [ ] LM060 Update `docs/general/DEV_PITFALLS.md` with new pitfalls discovered during implementation
- [ ] LM061 Run style enforcement one final time
- [ ] LM062 Commit implementation changes
- [ ] LM063 Commit documentation updates separately

---

## Phase 8: Coverage + Determinism Gap Closure

**Exit Criteria:** inclusion scope, deterministic behavior, and runtime scalability are explicitly validated.

- [ ] LM066 Define lighting math contract doc (tint/intensity ranges, clamp rules, blend order, tie-break behavior)
- [ ] LM067 (Red) Add unit tests for deterministic overlap ordering and boundary jitter resistance
- [ ] LM068 (Green) Implement boundary hysteresis/smoothing safeguards to prevent zone-edge flicker
- [ ] LM069 Add integration coverage that validates player and NPC parity through identical zone paths
- [ ] LM070 Add performance smoke test + baseline notes for multi-character multi-zone scenes

---

## Required Validation Matrix

- [x] Unit: resources/config/blend math
- [x] Unit: zone controller behavior
- [x] Unit: manager lifecycle/discovery/cache invalidation
- [ ] Integration: scene transition + respawn + overlap blending
- [ ] Integration: player + NPC parity in shared lighting zones
- [x] Style: `tests/unit/style/test_style_enforcement.gd`
- [ ] Performance smoke: multi-character/multi-zone update remains stable
- [ ] Manual QA: 4 gameplay scenes and cross-scene transitions
