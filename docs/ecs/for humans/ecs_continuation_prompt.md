# ECS Refactor – Quick Start for Humans

## Picking Up After Priority Documentation

Stories 1.1–5.3 are complete. Before you dive into the Testing & Documentation batch:

1. Re-read the quick guidance docs:
   - `AGENTS.md`
   - `docs/general/DEV_PITFALLS.md`
   - `docs/general/STYLE_GUIDE.md`
2. Review planning status:
   - `docs/ecs/ecs_refactor_plan.md` (next up: Batch 4 Step 2 – debug the ECS debugger tooling | it's not detecting any systems and the queries tab is stuck on locating ECS manager, and no events captured;)
   - `docs/ecs/ecs_refactor_prd.md` (progress summary now includes Stories 1.1–5.3)
   - `docs/ecs/ecs_architecture.md` (§6.8 priority scheduling, §8 status recap) and `docs/ecs/refactor recommendations/ecs_refactor_recommendations.md`
3. Familiarize yourself with the updated baseline:
   - `scripts/utils/u_ecs_utils.gd` and `scripts/managers/m_ecs_manager.gd` (shared manager helpers, entity query caching, priority-sorted system execution inside `_physics_process`)
   - `scripts/ecs/ecs_system.gd` (exported, clamped `execution_priority` with manager notifications; systems only self-tick when unmanaged)
   - `scripts/ecs/components/c_movement_component.gd` & `c_jump_component.gd` (auto-discovery, no peer NodePaths)
   - `scripts/ecs/components/c_rotate_to_input_component.gd` & `c_align_with_surface_component.gd` (no component cross-links; scene-only NodePaths remain)
   - `scripts/ecs/systems/` gravity, floating, rotate-to-input, align-with-surface, and landing indicator systems (all rely on `query_entities()` with optional components)
   - `templates/player_template.tscn` & `tests/perf/perf_ecs_baseline.gd` (query-driven wiring, no manual Component NodePaths)
   - Tests: updated suites under `tests/unit/ecs/components/` and `tests/unit/ecs/systems/` (movement, gravity, floating, rotate, align, landing, jump) now drive behaviour via `manager._physics_process(...)`
4. Continue with Batch 4 Step 2 (ECS debugger tooling). Prototype the editor plugin with RED→GREEN→REFACTOR discipline, keep GUT runs (`-gexit`) green, and update plan/PRD/docs at each milestone.

## Friendly Resources

- `ecs_ELI5.md` – Intro to the architecture
- `ecs_tradeoffs.md` – Pros/cons overview
- `ecs_architecture.md` – Full technical reference
- `ecs_refactor_plan.md` – Detailed roadmap

Happy coding!
