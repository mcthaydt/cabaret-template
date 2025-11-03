# Scene Manager Implementation Guide

## Overview

This guide directs you to implement the Scene Manager feature by following the tasks outlined in the documentation in sequential order.

**Branch**: `SceneManager`
**Status**: ✅ Phase 9 COMPLETE | 🎯 Phase 10: Camera Blending & Polish

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

## Getting Started

**Current Phase**: 🎯 Phase 10 - Polish & Cross-Cutting Concerns (28 tasks, 2-3 days)

**Phase 9 COMPLETE**:

- ✅ All 177 Phase 9 tasks complete (100%)
- ✅ End-game UI scenes (game_over, victory, credits) implemented
- ✅ Two-stage victory progression working (LEVEL_COMPLETE → GAME_COMPLETE)
- ✅ Ragdoll death effect with delayed transition
- ✅ Retry/continue/credits navigation flows complete
- ✅ Manual in-editor validation complete (T177) - all endgame flows working
- ✅ Integration test coverage: test_endgame_flows.gd

**Phase 10 Preparation Complete**:

- ✅ T177 manual validation complete
- ✅ Camera blending architecture validated (scene-based pattern, prototype exists)
- ✅ Implementation approach confirmed: Transition camera + Tween interpolation
- ✅ Scene cameras identified: E_Camera entity with E_PlayerCamera node
- ✅ Current state: Cameras identical at (0, 1, 4.5), FOV 75°
- ✅ Optional variations planned: Different FOV/height for exterior vs interior

**Phase 9 Victory Progression Design**:

Phase 9 implements a **two-stage victory system** to provide progression:

1. **Stage 1: LEVEL_COMPLETE** (Interior House Goal)
   - Player enters goal zone in `interior_house.tscn`
   - `S_VictorySystem` adds "interior_house" to `state.gameplay.completed_areas`
   - Returns player to `exterior.tscn` to continue exploring
   - Always available from game start

2. **Stage 2: GAME_COMPLETE** (Exterior Final Goal)
   - New goal zone spawns in `exterior.tscn` after Stage 1 completion
   - Only activates if "interior_house" is in `completed_areas` array
   - Triggers transition to victory screen (`victory.tscn`)
   - Shows credits option and end-game stats

**Unlock Logic**: Goal zone or `S_VictorySystem` checks `state.gameplay.completed_areas` before allowing GAME_COMPLETE victory type to trigger.

**Phase 9 Death Effect Design**:

Phase 9 implements a **simple ragdoll death effect** for visual feedback:

- **Approach**: Spawn separate `RigidBody3D` ragdoll, hide `CharacterBody3D` player
- **Ragdoll**: Simple single-body physics (capsule mesh, tumble rotation)
- **Flow**:
  1. Player health reaches 0
  2. `S_HealthSystem` hides player entity
  3. Spawn ragdoll prefab at player position with impulse/angular velocity
  4. Ragdoll tumbles and falls for 2.5 seconds
  5. Fade transition to `game_over.tscn`
- **Prefab**: `templates/player_ragdoll.tscn` (RigidBody3D + CapsuleMesh + CollisionShape3D)

**Next Steps** (Phase 10 execution):

1. 🎯 Start with camera blending (T178-T182.6)
   - Reference: `scripts/prototypes/prototype_camera_blending.gd` for implementation pattern
   - Create transition camera in M_SceneManager
   - Implement Tween-based interpolation (position, rotation, FOV)
   - Integrate with FadeTransition (parallel blending)
   - Optional: Create scene-specific camera variations

2. 🎯 Edge case testing (T183-T191)
   - All 8 edge case scenarios from PRD
   - Scene loading failures, transition collisions, memory pressure
   - Physics frame safety, unsaved progress handling

3. 🎯 Documentation updates (T192-T194)
   - Create quickstart.md usage guide
   - Update AGENTS.md with Scene Manager patterns
   - Update DEV_PITFALLS.md with scene-specific pitfalls

4. 🎯 Final validation & code cleanup (T195-T205)
   - Full test suite validation
   - Manual game loop testing
   - Performance/memory validation
   - Code review and cleanup
   - Remove debug code, verify TODOs

**Phase 10 Scope (User Confirmed)**:

- ✅ All 28 tasks (skip T206 static analysis)
- ✅ Camera blending: Implement system + optional scene variations
- ✅ Edge case testing: All 8 scenarios from PRD
- ✅ Documentation: quickstart.md, AGENTS.md, DEV_PITFALLS.md updates
- ✅ Code cleanup: Remove debug code, verify TODOs

**Recommended Path**:

1. ✅ Phase 6 (Area Transitions) - COMPLETE
2. ✅ Phase 6.5 (Refactoring) - COMPLETE
3. ✅ Phase 7 (Transition Effects) - COMPLETE
4. ✅ Phase 8 (Preloading & Performance) - COMPLETE
5. ✅ Phase 8.5 (Gameplay Mechanics) - COMPLETE
6. ✅ Phase 9 (End-Game Flows) - COMPLETE
7. → Phase 10 (Polish) - 2-3 days

---
Now implement precisely as planned, in full.

Implementation Requirements:

- Write elegant, minimal, modular code.
- Adhere strictly to existing code patterns, conventions, and best practices.
- Include thorough, clear comments/documentation within the code.
- Ensure we have absolutely no orphans, and every test that's expected to fail is marked as such\
- Read every single required document before beginning\

Do you have any questions?

---
