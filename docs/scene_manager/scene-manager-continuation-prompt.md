# Scene Manager Implementation Guide

## Overview

This guide directs you to implement the Scene Manager feature by following the tasks outlined in the documentation in sequential order.

**Branch**: `SceneManager`
**Status**: ✅ Phase 0, 1, 2, 3, 4, 5, 6, 6.5, 7, 8, 8.5 Complete | 🎯 Ready for Phase 9

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

**Current Phase**: 🎯 Phase 9 - End-Game Flows (NEXT)

**Phase 8.5 Complete**:

- ✅ ECS health loop (components + systems + HUD wiring)
- ✅ Damage zones (spikes, death plane) with cooldown protection
- ✅ Victory triggers (goal zone, state updates, scene handoff)
- ✅ Player template owns health metadata + state integration
- ✅ New integration tests (health/damage/victory) + full suite passing

**Known Gaps from Phase 8.5**:

⚠️ Phase 8.5 implemented the *trigger systems* for victory and death, but the *destination scenes* don't exist yet. **The game will crash** if these triggers fire:

- ❌ **Victory scene missing**: `s_victory_system.gd:47` references `"victory"` scene (doesn't exist)
- ❌ **Game over scene missing**: `s_health_system.gd:151` references `"game_over"` scene (doesn't exist)
- ❌ **Credits scene missing**: Not yet referenced by any system
- ❌ **Scene registry incomplete**: None of the above scenes registered in `u_scene_registry.gd`
- ❌ **No death visual**: Death has 2.5s delay (`RS_HealthSettings.death_animation_duration`) but only waits passively, no visual effect
- ❌ **Exterior missing GAME_COMPLETE goal**: Only interior has victory trigger, no final goal zone unlocked after completion

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

**Next Steps** (Phase 9 - End-Game Flows):

- **Tasks**: 21 tasks (T162-T177 + T165.1-T165.5)
- **Goal**: Wire full win/lose flows: game over, victory, credits navigation, ragdoll death effect, progressive victory system
- **Why**: Unlock final story beats, allow retry/continue UX backed by real gameplay triggers, add visual death feedback
- **Read**: `scene-manager-tasks.md` Phase 9 section (lines ~883-965)
- **Estimated**: 10-12 hours

**Phase 9 Workstreams**:

1. Build UI scenes (game_over, victory, credits) with expected controls
2. Register scenes + transitions in U_SceneRegistry and Scene Manager flows
3. Implement retry/continue plumbing with state + Scene Manager
4. Author endgame integration tests (test_endgame_flows.gd) and run full suite

**After Phase 9**:

- Phase 10: Polish & Cross-Cutting (29 tasks, 2-3 days)

**Recommended Path**:

1. ✅ Phase 6 (Area Transitions) - COMPLETE
2. ✅ Phase 6.5 (Refactoring) - COMPLETE
3. ✅ Phase 7 (Transition Effects) - COMPLETE
4. ✅ Phase 8 (Preloading & Performance) - COMPLETE
5. ✅ Phase 8.5 (Gameplay Mechanics) - COMPLETE
6. → Phase 9 (End-Game Flows) - 8-10 hours
7. → Phase 10 (Polish) - 2-3 days
