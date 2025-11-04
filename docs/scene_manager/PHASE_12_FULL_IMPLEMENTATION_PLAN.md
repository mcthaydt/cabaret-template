# Phase 12 - Full Implementation Plan

**Decision**: Implementing ALL of Phase 12 (no deferrals)

**Rationale**: Complete spawn system with checkpoints, effects, and validation for production-ready gameplay.

---

## Overview

**Status**: Sub-Phases 12.1 & 12.2 complete, 12.3a-12.5 remaining

**Total Remaining**: 61 tasks, 26-38 hours

**Current Baseline**: 548/552 tests passing (4 pending health system tests)

---

## Completed Sub-Phases

### ✅ Sub-Phase 12.1: M_SpawnManager Extraction (T215-T231)
- **Time**: 8 hours actual
- **Result**: 106 lines extracted, M_SpawnManager created (~150 lines)
- **Tests**: 524/528 passing after completion
- **Commit**: 51e3066

### ✅ Sub-Phase 12.2: M_CameraManager Extraction (T232-T251)
- **Time**: 6 hours actual
- **Result**: 135 lines extracted, M_CameraManager created (~192 lines)
- **Tests**: 548/552 passing after completion
- **Commit**: 0704347

---

## Remaining Implementation

### 🎯 Sub-Phase 12.3a: Death Respawn (T252-T261) - 6-8 hours

**Goal**: Player death → respawn at last spawn point used

**Dependencies**: M_SpawnManager (complete), S_HealthSystem (exists), game_over scene (exists)

**Tasks** (9 tasks):
- T252: Write `tests/integration/spawn_system/test_death_respawn.gd` - TDD RED
- T253: Write tests for death → game_over → respawn flow
- T254: Write tests for `spawn_at_last_spawn()` method
- T255: Implement `M_SpawnManager.spawn_at_last_spawn()` → bool
  - Read `target_spawn_point` from gameplay state
  - Call existing `spawn_player_at_point()` with last spawn point
  - Fallback to `sp_default` if no last spawn set
- T256: Integrate with S_HealthSystem death sequence
  - When health ≤ 0: transition to game_over scene
  - Game over "Retry" button: restore to last scene + spawn
- T257: Update `game_over.tscn` to wire Retry button
- T258: Run death respawn tests - expect all PASS
- T259: Run full test suite - expect 552+/556 passing
- T260: Manual test: exterior → interior → die → respawn at last door
- T261: Commit: "Phase 12.3a: Death respawn using last spawn point"

**Success Criteria**:
- Death → game over → respawn working
- Player spawns at last door used
- All tests passing

---

### 🆕 Sub-Phase 12.3b: Checkpoint Markers (T262-T266) - 4-6 hours

**Goal**: Mid-scene checkpoint system for saving spawn points independent of doors

**Dependencies**: Sub-Phase 12.3a (death respawn)

**Rationale**: Enables checkpoints in dungeons/difficult areas without requiring doors

**Tasks** (10 tasks - newly designed):
- T262: Write `tests/unit/spawn_system/test_checkpoint_component.gd` - TDD RED
- T263: Write tests for checkpoint activation (player enters Area3D)
- T264: Write tests for checkpoint persistence in save files
- T265: Create `scripts/ecs/components/c_checkpoint_component.gd`
  - Extends `ECSComponent`
  - Properties: `checkpoint_id: StringName`, `spawn_point_id: StringName`
  - Requires: Area3D child node for collision detection
  - On player collision: update `last_checkpoint` in gameplay state
- T266: Create `scripts/ecs/systems/s_checkpoint_system.gd`
  - Extends `ECSSystem`
  - Query: `C_CheckpointComponent`
  - Connect Area3D `body_entered` signals
  - On player enter: dispatch action to set last checkpoint
  - Visual feedback: particle effect or shader pulse (optional)
- T267: Add `last_checkpoint: StringName` to gameplay state
- T268: Update `M_SpawnManager.spawn_at_last_spawn()` to check checkpoints first
  - Priority: last_checkpoint > target_spawn_point > sp_default
- T269: Create test scene `scenes/test/checkpoint_test.tscn`
  - Multiple checkpoints in sequence
  - Test checkpoint → die → respawn at checkpoint
- T270: Run checkpoint tests - expect all PASS
- T271: Commit: "Phase 12.3b: Checkpoint marker system"

**Success Criteria**:
- Player touching checkpoint sets spawn point
- Death respawns at last checkpoint
- Checkpoints persist in save files

---

### 🆕 Sub-Phase 12.4: Advanced Features (T272-T298) - 12-14 hours

**Goal**: Spawn effects, conditional spawning, spawn metadata/registry

**Dependencies**: Sub-Phases 12.3a & 12.3b

#### Part A: Spawn Effects (4 hours)

**Tasks** (8 tasks):
- T272: Write `tests/unit/spawn_system/test_spawn_effects.gd` - TDD RED
- T273: Write tests for fade-in effects on player spawn
- T274: Write tests for particle effects on spawn
- T275: Create `scripts/spawn_system/base_spawn_effect.gd`
  - Virtual `execute(player: Node3D)` method
  - `duration: float` property
  - `completion_callback: Callable`
- T276: Create `scripts/spawn_system/spawn_fade_effect.gd`
  - Fade player MeshInstance3D from transparent → opaque
  - Tween duration: 0.3s, TRANS_CUBIC, EASE_OUT
- T277: Create `scripts/spawn_system/spawn_particle_effect.gd`
  - Instantiate particle burst at spawn point
  - Auto-cleanup after duration
- T278: Integrate effects with `M_SpawnManager.spawn_player_at_point()`
  - Optional `effect: BaseSpawnEffect` parameter
  - Play effect after positioning, await completion
- T279: Run spawn effect tests - expect all PASS

#### Part B: Conditional Spawning (4 hours)

**Tasks** (8 tasks):
- T280: Write `tests/unit/spawn_system/test_spawn_conditions.gd` - TDD RED
- T281: Write tests for locked spawns (condition not met)
- T282: Write tests for unlock state integration
- T283: Create `scripts/spawn_system/rs_spawn_condition.gd` resource
  - Enum: `ConditionType` (ALWAYS, QUEST_COMPLETE, ITEM_OWNED, FLAG_SET)
  - Properties: `condition_type`, `required_quest/item/flag`
- T284: Add `conditions: Array[RS_SpawnCondition]` to spawn metadata
- T285: Implement `M_SpawnManager._check_spawn_conditions(spawn_id: StringName)` → bool
  - Query gameplay state for quest/item/flag
  - Return true if all conditions met
- T286: Integrate condition checks into `spawn_player_at_point()`
  - Call `_check_spawn_conditions()` before spawning
  - Log warning if locked, return false
- T287: Run conditional spawn tests - expect all PASS

#### Part C: Spawn Metadata & Registry (4-6 hours)

**Tasks** (12 tasks):
- T288: Write `tests/unit/scene_management/test_spawn_registry.gd` - TDD RED
- T289: Write tests for spawn point metadata lookup
- T290: Write tests for spawn priority (multiple spawns, pick best)
- T291: Write tests for spawn tags (outdoor, indoor, safe, dangerous)
- T292: Create `scripts/scene_management/u_spawn_registry.gd` static class
  - `register_spawn_point(scene_id, spawn_id, metadata)`
  - `get_spawn_metadata(scene_id, spawn_id)` → Dictionary
  - `find_spawn_by_tag(scene_id, tag)` → StringName
- T293: Define spawn metadata structure
  - `priority: int` (higher = preferred)
  - `tags: Array[String]` (outdoor, indoor, safe, dangerous, default)
  - `conditions: Array[RS_SpawnCondition]`
  - `effect: String` (fade, particle, none)
- T294: Integrate U_SpawnRegistry with M_SpawnManager
  - Look up metadata during spawn operations
  - Apply conditions and effects based on metadata
- T295: Add `spawn_by_tag(scene_id: StringName, tag: String)` method
  - Use case: "spawn at safe outdoor spawn" after death
- T296: Update scene templates to register spawn points in `_ready()`
- T297: Create example: exterior.tscn registers spawn metadata
- T298: Run spawn registry tests - expect all PASS
- T299: Commit: "Phase 12.4: Advanced spawn features (effects, conditions, registry)"

**Success Criteria**:
- Spawn effects working (fade, particles)
- Conditional spawning validates requirements
- Spawn registry enables metadata lookup and tag-based spawning

---

### 🆕 Sub-Phase 12.5: Scene Contract Validation (T300-T310) - 4-6 hours

**Goal**: Catch scene configuration errors at load time with clear error messages

**Dependencies**: All spawn system work (12.3a-12.4)

**Tasks** (11 tasks):
- T300: Write `tests/unit/scene_validation/test_scene_contract.gd` - TDD RED
- T301: Write tests for gameplay scene validation
- T302: Write tests for UI scene validation
- T303: Create `scripts/scene_management/i_scene_contract.gd` class
  - `validate_scene(scene: Node, scene_type: SceneType)` → ValidationResult
  - ValidationResult: `{ valid: bool, errors: Array[String], warnings: Array[String] }`
- T304: Implement gameplay scene validation rules
  - REQUIRED: One player entity (E_Player*)
  - REQUIRED: One camera in "main_camera" group
  - REQUIRED: At least one spawn point (sp_*)
  - REQUIRED: Default spawn point (sp_default)
  - WARNING: Multiple players (ambiguous)
  - WARNING: Multiple default spawn points
- T305: Implement UI scene validation rules
  - FORBIDDEN: Player entities
  - FORBIDDEN: Spawn points
  - OPTIONAL: Camera
- T306: Integrate validation into `M_SceneManager._perform_transition()`
  - After loading scene, before spawning
  - Call `ISceneContract.validate_scene()`
  - If validation fails: log errors, abort transition, show error screen
  - If warnings only: log warnings, continue
- T307: Run scene validation tests - expect all PASS
- T308: Manual test: Load scene with missing player → clear error at load time
- T309: Manual test: Load scene with missing spawn → clear error
- T310: Run full test suite - expect 570+/574 passing
- T311: Commit: "Phase 12.5: Scene contract validation"

**Success Criteria**:
- Configuration errors caught at scene load (not spawn time)
- Clear, structured error messages
- Validation prevents broken scene transitions

---

## Final Phase 12 Deliverables

**Code Changes**:
- **Lines Extracted**: 241 (106 spawn + 135 camera)
- **M_SceneManager**: ~1,171 lines (down from 1,412)
- **New Managers**: M_SpawnManager (~200 lines), M_CameraManager (~192 lines)
- **New Components**: C_CheckpointComponent (~80 lines)
- **New Systems**: S_CheckpointSystem (~100 lines)
- **New Classes**: BaseSpawnEffect, SpawnFadeEffect, SpawnParticleEffect, RS_SpawnCondition, U_SpawnRegistry, ISceneContract (~500 lines)

**Test Coverage**:
- **New Tests**: ~80-100 test methods
- **Expected Final**: 570+/574 passing
- **Assertions**: ~400+ new assertions

**Documentation**:
- Update scene-manager-tasks.md with T262-T299 definitions
- Update scene-manager-continuation-prompt.md (Phase 12 complete)
- Update AGENTS.md with checkpoint/spawn patterns
- Create spawn-system-quickstart.md

**Time Investment**:
- Sub-Phase 12.3a: 6-8 hours
- Sub-Phase 12.3b: 4-6 hours
- Sub-Phase 12.4: 12-14 hours
- Sub-Phase 12.5: 4-6 hours
- **Total**: 26-34 hours

---

## Implementation Order

1. **First**: Sub-Phase 12.3a (Death Respawn) - Core functionality
2. **Second**: Sub-Phase 12.3b (Checkpoint Markers) - Extends respawn
3. **Third**: Sub-Phase 12.4 (Advanced Features) - Polish and metadata
4. **Finally**: Sub-Phase 12.5 (Scene Validation) - Quality safeguard

**Rationale**: Build from core → extensions → polish → validation

---

## Ready to Start?

**Next Task**: T252 - Write death respawn tests (TDD RED)

**Estimated Completion**: 26-34 hours (3-4 days of focused work)

**Question**: Proceed with Sub-Phase 12.3a implementation?
