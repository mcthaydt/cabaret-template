# Scene Manager Implementation Guide

## Overview

This guide directs you to implement the Scene Manager feature by following the tasks outlined in the documentation in sequential order.

**Branch**: `SceneManager` (continuing on existing branch)
**Status**: ✅ Phase 12.1 COMPLETE | 🎯 Phase 12.2 READY TO START

---

## 🎯 CURRENT PHASE: Phase 12.2 - Camera Manager Extraction

**Quick Start Checklist** (Do in order):
1. ⬜ Read this entire document first
2. ⬜ Read all the documentation required below - Project patterns
3. ⬜ Read `scene-manager-tasks.md` Phase 12.2 section
4. ⬜ Run baseline tests: `524/528 passing` (confirm no regressions)
5. ⬜ Start with Task **T232** (write camera manager tests)

**Remaining Approved Scope**: 39 tasks, 16-24 hours
- ✅ **Sub-Phase 12.1**: M_SpawnManager extraction (T215-T231) - **COMPLETE**
- **Sub-Phase 12.2**: M_CameraManager extraction (T232-T251) - **NEXT** (6-8 hours)
- **Sub-Phase 12.3a**: Death respawn (T252-T260) - Pending (6-8 hours)
- **Sub-Phase 12.5**: Scene contract validation (T299-T308) - Pending (4-6 hours)

**Deferred**: Sub-Phases 12.3b, 12.4 (checkpoint markers, spawn effects, advanced features)

**Jump to**: [Phase 12 Details](#next-phase-phase-12---spawn-system-extraction-3-manager-architecture) | [Phase 12 Tasks](./scene-manager-tasks.md#phase-12-spawn-system-extraction-separation-of-concerns)

---

## Instructions  **YOU MUST DO THIS - NON-NEGOTIABLE**

### 1. Review Project Foundations

- `AGENTS.md` - Project conventions and patterns
- `docs/general/DEV_PITFALLS.md` - Common mistakes to avoid
- `docs/general/SCENE_ORGANIZATION_GUIDE.md` - Code style requirements
- `docs/general/STYLE_GUIDE.md` - Code style requirements

### 2. Review Scene Manager Documentation

- `docs/scene_manager/scene-manager-prd.md` - Full specification
- `docs/scene_manager/scene-manager-plan.md` - Implementation plan with phase breakdown
- `docs/scene_manager/scene-manager-tasks.md` - Task list

### 3. Understand Existing Architecture

- `scripts/managers/m_state_store.gd` - Redux store
- `scripts/managers/m_ecs_manager.gd` - Per-scene ECS manager pattern

### 4. Execute Tasks in Order

Work through the tasks in `scene-manager-tasks.md` sequentially:

1. **Phase 0** (R001-R031): Research & Architecture Validation
2. **Phase 1** (T001-T002): Setup - Baseline Tests
3. **Phase 2** (T003-T024): Foundational - Scene Restructuring
4. **Phase 3** (T025-T067): User Story 1 - Basic Scene Transitions
5. **Phase 4** (T068-T079): User Story 2 - State Persistence
6. **Phase 5** (T101-T128): User Story 4 - Pause System
7. **Phase 6** (T080-T100): User Story 3 - Area Transitions
8. **Phase 7** (T129-T144): User Story 5 - Transition Effects
9. **Phase 8** (T145-T161): User Story 6 - Scene Preloading
10. **Phase 8.5** (T145.1-T145.24): Gameplay Mechanics Foundation
11. **Phase 9** (T162-T177): User Story 7 - End-Game Flows
12. **Phase 10** (T178-T206): Polish & Cross-Cutting Concerns

### 5. Follow TDD Discipline

For each task:

1. Write the test first
2. Run the test and verify it fails
3. Implement the minimal code to make it pass
4. Run the test and verify it passes
5. Commit with a clear message

### 6. Track Progress **YOU MUST DO THIS - NON-NEGOTIABLE**

As you complete tasks in `scene-manager-tasks.md`:

**ONLY mark tasks [x] complete when:**

- You have completed EVERY requirement in the task description
- You have not substituted research for actual implementation
- You have not made "close enough" compromises
- You have not skipped any specified components or steps

**If you deviate from the spec:**

- Mark task [ ] incomplete
- Document the deviation clearly in the task notes
- Get explicit user approval before proceeding to next phase

**Never assume "close enough" is acceptable. Every task requirement matters.**

Additional tracking requirements:

- Update task checkboxes in `scene-manager-tasks.md` after each task
- Ensure all tests remain passing after each change
- Update any relevant documentation
- Commit regularly with descriptive messages that accurately describe what was done

---

## Critical Notes

- **No autoloads**: Use scene-tree-based discovery patterns
- **TDD is mandatory**: Write tests before implementation
- **Immutable state**: Always use `.duplicate(true)` in reducers

---

## Previously Completed Phases

**Status**: Phases 1-11 complete, Phase 12.1 complete (524/528 tests passing)
- ✅ Scene restructuring, transitions, state persistence, pause, area transitions, effects, preloading, endgame flows, camera blending, polish complete
- ✅ Phase 12.1: M_SpawnManager extraction complete (106 lines extracted)
- ✅ Production ready - Comprehensive test coverage with 1390 assertions

---

## Current Phase: Phase 12 - Spawn System Extraction (3-Manager Architecture)

**Status**: ✅ Phase 12.1 COMPLETE | 🎯 Phase 12.2 IN PROGRESS
**Remaining Scope**: Sub-Phases 12.2, 12.3a, 12.5 (deferred: 12.3b, 12.4)
**Remaining Time**: 16-24 hours

**Architecture Decision**: ✅ **3-Manager Approach**
- **M_SceneManager** (~1,171 lines) → Scene transitions only
- **M_SpawnManager** (~150 lines) → Player spawning only
- **M_CameraManager** (~200 lines) → Camera blending only

**Why 3 Managers?**
- Maximum separation of concerns (each has single responsibility)
- Camera usable independently (cinematics, shake, cutscenes)
- Better testability (mock one without the others)

**Current Architecture Issues**:
- M_SceneManager handles both scene transitions AND player/camera spawning
- 241 lines of spawn/camera logic coupled to transition logic (106 spawn + 135 camera)
- Makes it harder to add spawn features or camera features independently

---

### **APPROVED IMPLEMENTATION SCOPE**

**Sub-Phase 12.1: Spawn Extraction** (T215-T231) - ✅ **COMPLETE** (8 hours actual)
- ✅ Extracted M_SpawnManager from M_SceneManager (~150 lines)
- ✅ Moved spawn point discovery, player positioning, validation
- ✅ 106 lines extracted from M_SceneManager (lines 970-1066 removed)
- ✅ Added 23 new comprehensive tests (18 integration + 15 unit)
- ✅ All 524/528 tests passing (up from 508 before Phase 12)

**Sub-Phase 12.2: Camera Extraction** (T232-T251) - 6-8 hours ⭐ APPROVED
- Extract M_CameraManager (separate from spawn manager)
- Move camera blending, CameraState class, transition camera
- Additional 135 lines extracted, M_SceneManager down to ~1,171 lines

**Sub-Phase 12.3a: Death Respawn** (T252-T260) - 6-8 hours ⭐ APPROVED
- Implement spawn_at_last_spawn() using existing spawn system
- Integrate with S_HealthSystem death sequence
- Death → respawn working (NO checkpoint markers yet)

**Sub-Phase 12.5: Scene Contract Validation** (T299-T308) - 4-6 hours ⭐ APPROVED
- Create ISceneContract validation class
- Validate gameplay scenes at load time (not spawn time)
- Catch missing player/camera/spawn points EARLY
- Clear, structured error messages

**Total Approved**: 24-32 hours, 45-50 tasks

---

### **DEFERRED TO PHASE 13** (Not Needed Yet)

**Sub-Phase 12.3b: Checkpoint Markers** - DEFERRED
- C_CheckpointComponent + S_CheckpointSystem
- Checkpoint persistence in save files
- Reason: Death respawn using last spawn point is sufficient

**Sub-Phase 12.4: Advanced Features** - DEFERRED
- Spawn effects (fade, particles) - polish, not functionality
- Conditional spawning - requires quest/item systems (don't exist yet)
- Spawn registry - overkill for current scale (< 50 spawn points)
- Reason: Not needed for core gameplay

---

### **IMPLEMENTATION ORDER**

1. ✅ **COMPLETE**: Sub-Phase 12.1 (M_SpawnManager extraction)
   - 17 tasks, 8 hours actual
   - All 524/528 tests passing
   - 106 lines extracted, M_SpawnManager created

2. 🎯 **CURRENT**: Sub-Phase 12.2 (M_CameraManager extraction)
   - 20 tasks, 6-8 hours
   - Camera independence achieved
   - M_SceneManager clean, focused on transitions

3. **Then**: Sub-Phase 12.3a (Death respawn)
   - 9 tasks, 6-8 hours
   - Death → respawn loop working
   - Core gameplay complete

4. **Finally**: Sub-Phase 12.5 (Scene contract validation)
   - 10 tasks, 4-6 hours
   - Configuration errors caught early
   - Quality improvement

**STOP after 12.5** - Ship it, move to other features

---

### **KEY BENEFITS**

**3-Manager Architecture**:
- ✅ M_SceneManager: Pure scene transitions (~1,171 lines, focused)
- ✅ M_SpawnManager: Pure player spawning (~150 lines, testable)
- ✅ M_CameraManager: Pure camera blending (~200 lines, reusable for cinematics)

**Scope Management**:
- ✅ Core features only (spawn, camera, death respawn, validation)
- ✅ No premature features (checkpoints, effects, conditional spawning)
- ✅ Faster time-to-value (24-32 hours vs 42-54 hours)

**Quality**:
- ✅ Scene contract validation catches config errors EARLY
- ✅ Comprehensive test coverage (TDD approach)
- ✅ Clean separation enables future extensions

---

### **QUICK START FOR PHASE 12.2**

**Before Starting Sub-Phase 12.2**:
1. Read: `docs/scene_manager/scene-manager-tasks.md` Phase 12.2 section (T232-T251)
2. Confirm baseline: Run tests, expect 524/528 passing
3. Review M_SceneManager camera code (lines 48-57, 71-74, 1087-1208)

**During Implementation**:
- Follow TDD: Tests first, watch fail, implement, watch pass
- Commit after each green test (include task number)
- Run full test suite every 3-5 tasks
- STOP if tests fail - fix immediately before proceeding

**Phase 12.1 Success Criteria** ✅ ACHIEVED:
- ✅ M_SpawnManager created and tested (23 new tests)
- ✅ All tests passing (524/528, up from 508)
- ✅ 106 lines extracted from M_SceneManager
- ✅ Spawn restoration working via M_SpawnManager

**Phase 12 Final Success Criteria** (after 12.2, 12.3a, 12.5):
- ✅ All approved sub-phases complete (12.1, 12.2, 12.3a, 12.5)
- ✅ All tests passing (524+/528)
- ✅ Manual validation: door transitions, camera blending, death respawn
- ✅ M_SceneManager ~1,171 lines (down from 1,412)
- ✅ M_SpawnManager ~150 lines, M_CameraManager ~200 lines

**See**: `docs/scene_manager/scene-manager-tasks.md` Phase 12 for detailed task breakdown

---

---

## Phase 12 - Implementation Requirements

**Phase 12.1 Completed** ✅:
- ✅ All prerequisites read and followed
- ✅ Baseline established: 508/512 tests passing → 524/528 after 12.1
- ✅ M_SpawnManager created and integrated
- ✅ 106 lines extracted, 23 new tests added
- ✅ Branch: `SceneManager` (continuing existing branch)

**Phase 12.2 Requirements**:
- Write elegant, minimal, modular code
- Adhere strictly to existing code patterns, conventions, and best practices
- Include thorough, clear comments/documentation within the code
- Ensure we have absolutely no orphans
- Follow TDD religiously: Tests FIRST, watch fail, implement, watch pass
- Commit after each green test with task number in message
- Run full test suite every 3-5 tasks
- **STOP if tests fail** - fix immediately before proceeding

**Next Task**: **T232** - Write camera manager tests (TDD RED)

**Remaining Implementation Path**:
1. ✅ **Phase 12.1** (T215-T231): M_SpawnManager extraction - COMPLETE (8 hours)
2. 🎯 **Phase 12.2** (T232-T251): M_CameraManager extraction - NEXT (6-8 hours)
3. → **Phase 12.3a** (T252-T260): Death respawn - 6-8 hours
4. → **Phase 12.5** (T299-T308): Scene contract validation - 4-6 hours

**Remaining**: 16-24 hours, 39 tasks

---
