# Scene Manager Implementation Guide

## Overview

This guide directs you to implement the Scene Manager feature by following the tasks outlined in the documentation in sequential order.

**Branch**: `SceneManager`
**Status**: ✅ Phase 0, 1, 2, 3, 4, 5, 6, 6.5, 7, 8 Complete | 🎯 Ready for Phase 8.5

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

**Current Phase**: 🎯 Phase 8.5 - Gameplay Mechanics Foundation (NEXT)

**Phase 7 & 8 Complete**:

- ✅ All transition effects working beautifully (instant, fade, loading)
- ✅ Async loading with real progress tracking
- ✅ Scene cache management (LRU + memory limits)
- ✅ Critical scene preloading at startup
- ✅ Automatic preload hints near doors
- ✅ All 74 tests passing (100%)
- ✅ Clean code (no warnings, no orphans)

**Next Steps** (Phase 8.5 - Gameplay Mechanics Foundation):

**Phase 8.5: Gameplay Mechanics Foundation (NEXT)**

- **Tasks**: 24 tasks (T145.1-T145.24)
- **Goal**: Implement minimal health, damage, death, and victory systems
- **Why**: Enable proper testing of Phase 9 end-game flows with real gameplay triggers
- **Read**: `scene-manager-tasks.md` (Phase 8.5, lines 537-773)
- **Estimated**: 6-8 hours

**Key Features**:

- Health system with ECS components (C_HealthComponent, S_HealthSystem)
- Damage zones (instant death + damage-over-time)
- Victory trigger zones (goal zones)
- State management integration (health, deaths, completed areas)
- HUD health display
- Death → game_over transition
- Victory → victory scene transition

**Implementation Parts**:

1. → Part 1: Health System (6 tasks, 2-3 hours)
2. → Part 2: Damage System (5 tasks, 1-2 hours)
3. → Part 3: Victory System (5 tasks, 1-2 hours)
4. → Part 4: Integration & Testing (8 tasks, 1-2 hours)

**After Phase 8.5**:

- Phase 9: End-Game Flows (16 tasks, 8-10 hours) - Can now test with real gameplay!
- Phase 10: Polish & Cross-Cutting (29 tasks, 2-3 days)

**Recommended Path**:

1. ✅ Phase 6 (Area Transitions) - COMPLETE
2. ✅ Phase 6.5 (Refactoring) - COMPLETE
3. ✅ Phase 7 (Transition Effects) - COMPLETE
4. ✅ Phase 8 (Preloading & Performance) - COMPLETE
5. → Phase 8.5 (Gameplay Mechanics) - 6-8 hours (NEXT)
6. → Phase 9 (End-Game Flows) - 8-10 hours
7. → Phase 10 (Polish) - 2-3 days
