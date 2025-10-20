# ECS Refactor – Quick Start for Humans

## Picking Up After Batch 2 Kickoff

Stories 1.1–2.6 are complete. Before you dive into the Event Bus work:

1. Re-read the quick guidance docs:
   - `AGENTS.md`
   - `docs/general/DEV_PITFALLS.md`
   - `docs/general/STYLE_GUIDE.md`
2. Review planning status:
   - `docs/ecs/ecs_refactor_plan.md` (next up: Story 3.1 – ECSEventBus)
   - `docs/ecs/ecs_refactor_prd.md` (progress summary now lists Stories 1.1–2.6)
   - `docs/ecs/ecs_architecture.md` and `docs/ecs/refactor recommendations/ecs_refactor_recommendations.md`
3. Familiarize yourself with the updated baseline:
   - `scripts/utils/u_ecs_utils.gd` (manager lookup, current time, body→component mapping)
   - `scripts/managers/m_ecs_manager.gd` (entity-component tracking, `query_entities()` caching, `get_components_for_entity()`)
   - Systems in `scripts/ecs/systems/` (movement/jump now consume multi-component queries; other systems expect components under `E_*` roots)
   - Tests: `tests/unit/ecs/test_ecs_manager.gd`, `tests/unit/ecs/test_ecs_system.gd`, `tests/unit/ecs/test_ecs_component.gd`, plus updated system suites under `tests/unit/ecs/systems/`
4. Continue with Story 3.1 using strict RED→GREEN→REFACTOR TDD. Run GUT with `-gexit`, update plan/PRD/docs after each story, and keep commits atomic per story.

## Friendly Resources

- `ecs_ELI5.md` – Intro to the architecture
- `ecs_tradeoffs.md` – Pros/cons overview
- `ecs_architecture.md` – Full technical reference
- `ecs_refactor_plan.md` – Detailed roadmap

Happy coding!
