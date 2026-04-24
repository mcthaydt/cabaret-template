# ADR 0007: BT Framework Scope — General vs AI-Specific

**Status**: Accepted  
**Date**: 2026-04-24  
**Context**: Cleanup V8 Phase 1

## Context

Behavior tree nodes are useful beyond AI, but several leaf/scorer/planner concepts depend on AI-specific interfaces such as `I_AIAction`, `I_Condition`, and task-state keys.

## Decision

Keep the general BT framework under `scripts/resources/bt/` and `scripts/utils/bt/`. AI-specific leaves, scorers, and planner resources live under `scripts/resources/ai/bt/`, with planner search under `scripts/utils/ai/`.

## Alternatives Considered

- **AI-only framework**: simpler directory layout, but blocks reuse for non-AI tree workflows.
- **Fully general framework with AI imports**: fewer folders, but contaminates core BT resources with AI dependencies.

## Consequences

**Positive**

- General BT nodes remain reusable and protected by style boundary tests.
- AI behavior can still compose condition/action wrappers and scoped planning without leaking into the base framework.

**Negative**

- Authors must choose the correct folder based on whether a node imports AI-specific types.

## References

- `docs/systems/ai_system/ai-system-overview.md`
- `tests/unit/style/test_style_enforcement.gd`

