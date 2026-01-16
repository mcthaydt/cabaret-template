# VFX Manager - Continuation Prompt

## Current Status (2026-01-17)

- **Refactor status**: Phase 3 complete (Player-only & transition gating).
- **Phase 3 commit**: `4ec288a`.
- **Next phase**: Phase 4 (Resource-Driven Configuration).
- **Gating helpers**: `_is_player_entity()` and `_is_transition_blocked()` enforce player-only + transition/menu blocking.
- **Scene selectors**: `U_SceneSelectors` added for transition + scene stack checks.
- **Tests run**: unit managers, VFX integration, style enforcement (all passing).
- **Manual QA**: Pending Phase 1 (T1.13), Phase 2 (T2.6), Phase 3 (T3.11).

## Before You Start

- Re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md`.
- Follow `docs/vfx manager/vfx-manager-refactor-tasks.md` in TDD order.
- If you add/rename scripts/scenes/resources, run `tests/unit/style/test_style_enforcement.gd`.

## Repo Reality Checks (Do Not Skip)

- There is **no** `MockECSEventBus`; use `U_ECSEventBus.reset()` in `before_each()`.
- `U_ECSEventNames` centralizes ECS event/service names; use constants for subscriptions.
- Publisher systems publish typed requests via `U_ECSEventBus.publish_typed()`.
- `M_VFXManager` processes request queues inside `_physics_process()`; event handlers only enqueue.
- `M_VFXManager` no longer self-registers; `main.gd` handles ServiceLocator bootstrap.

## Next Step

- Phase 4: move tuning to resources (screen shake tuning/config).
