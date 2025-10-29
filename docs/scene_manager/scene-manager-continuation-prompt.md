# Scene Manager Implementation Guide

## Overview

This guide directs you to implement the Scene Manager feature by following the tasks outlined in the documentation in sequential order.

**Branch**: `SceneManager`
**Status**: ✅ Phase 0 & Phase 1 Complete - Ready for Phase 2

---

## ✅ Phase 0: Research & Architecture Validation - COMPLETE (31/31 tasks)

**Status**: All Phase 0 tasks completed successfully
**Decision**: Approved to proceed to Phase 1

**Completed (31/31 tasks) - 100%**:
- ✅ Research documented (`research.md`) - Godot 4.5 patterns, lifecycle, performance
- ✅ Data model specified (`data-model.md`) - Complete Scene Manager contracts
- ✅ Scene restructuring validated - ECS/Redux functional, 98ms load time
- ✅ Safety analysis complete - M_StateStore modification **LOW RISK**
- ✅ R011: root_prototype.tscn created with M_StateStore AND M_CursorManager - retested successfully
- ✅ R018-R021: Camera blending prototype complete with working test scene and full documentation
- ✅ R029: Memory measurements complete with quantitative data (baseline: 22.61 MB, per-scene: ~6.91 MB, peak: 30.21 MB)

**Key Findings**:
- Performance: 98ms load time (well under 500ms UI target)
- Memory: ~6.91 MB per gameplay scene, no leaks detected
- Camera blending: Smooth Tween-based interpolation validated (0.5s duration)
- M_StateStore modification: LOW RISK (additive changes only)

---

## ✅ Phase 1: Setup - COMPLETE (2/2 tasks)

**Status**: Baseline tests established successfully

**Completed (2/2 tasks) - 100%**:
- ✅ T001: All existing tests run successfully - 212 automated GUT tests passing
- ✅ T002: Test baseline documented in commit 6f7107f

**Next Phase**: Begin Phase 2 (Foundational Scene Restructuring) - T003-T024

See `docs/scene_manager/general/research.md` for detailed findings.

---

## Instructions

### 1. Review Project Foundations
- `AGENTS.md` - Project conventions and patterns
- `docs/general/DEV_PITFALLS.md` - Common mistakes to avoid
- `docs/general/SCENE_ORGANIZATION_GUIDE.md` - Code style requirements
- `docs/general/STYLE_GUIDE.md` - Code style requirements

### 2. Review Scene Manager Documentation
- `docs/scene_manager/scene-manager-prd.md` - Full specification (7 user stories, 112 FRs)
- `docs/scene_manager/scene-manager-plan.md` - Implementation plan with phase breakdown
- `docs/scene_manager/scene-manager-tasks.md` - Task list (237 tasks: R001-R031, T001-T206)

### 3. Understand Existing Architecture
- `scripts/managers/m_state_store.gd` - Redux store (will be modified to add scene slice)
- `scripts/state/state_handoff.gd` - State preservation utility
- `scripts/managers/m_ecs_manager.gd` - Per-scene ECS manager pattern
- `templates/base_scene_template.tscn` - Current main scene (will be restructured)

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
10. **Phase 9** (T162-T177): User Story 7 - End-Game Flows
11. **Phase 10** (T178-T206): Polish & Cross-Cutting Concerns

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

- **Phase 0 & Phase 1 complete**: Research validated, baseline tests established (212 GUT tests passing)
- **Phase 2 is high risk**: Scene restructuring affects the entire project - all ~212 existing tests must continue passing
- **No autoloads**: Use scene-tree-based discovery patterns
- **TDD is mandatory**: Write tests before implementation
- **Immutable state**: Always use `.duplicate(true)` in reducers

---

## Task Execution Order Note

Due to risk management reordering, Phase 5 (T101-T128) comes before Phase 6 (T080-T100). Follow the phase order listed above, not the task numbering.

---

## Getting Started

**Current Phase**: Phase 2 (Foundational Scene Restructuring)

Begin with Phase 2 by reading the detailed requirements in:

- `scene-manager-plan.md` (Phase 2 section)
- `scene-manager-tasks.md` (T003-T024)

**⚠️ CRITICAL**: Phase 2 restructures the entire project architecture. All existing tests must pass after each major change.
