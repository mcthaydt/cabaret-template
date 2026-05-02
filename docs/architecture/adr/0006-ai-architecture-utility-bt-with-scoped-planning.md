# ADR 0006: AI Architecture — Utility BT with Scoped Planning

**Status**: Accepted  
**Date**: 2026-04-24  
**Context**: Cleanup V8 Phase 1

## Context

The previous AI stack combined GOAP goal selection with HTN task decomposition. In practice, shipped behaviors were priority-ordered condition checks followed by short fixed action sequences, while the architecture required authors to touch goals, tasks, planners, selectors, and runners for each behavior.

## Decision

Use utility-scored behavior trees as the primary AI architecture. Each brain owns one readable `RS_BTNode` root. Utility selectors score branches, decorators model cooldown/one-shot/rising-edge behavior, and existing `I_AIAction` resources run through `RS_BTAction`. Planning remains opt-in and scoped to a single `RS_BTPlanner` node backed by `U_BTPlannerSearch`.

## Alternatives Considered

- **Keep GOAP + HTN**: expressive, but overbuilt for current behaviors and hard to author.
- **Full GOAP/MBT rewrite**: powerful, but larger than needed and riskier for template users.
- **Plain BT without scoring**: simpler, but loses quality-based branch selection already useful in authored AI.

## Consequences

**Positive**

- AI brains are readable top-to-bottom as `.tres` behavior trees.
- Existing actions remain reusable through `I_AIAction`.
- Planning complexity is isolated to branches that need it.

**Negative**

- Highly dynamic planning problems require explicit planner nodes rather than being global behavior defaults.
- Utility scores and decorators need strong integration tests to avoid silent authoring mistakes.

## References

- `docs/history/cleanup_v8/cleanup-v8-tasks.md`
- `docs/systems/ai_system/ai-system-overview.md`
- Cleanup V8 Phase 1 commits
