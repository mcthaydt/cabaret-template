# ADR 0009: Template vs Demo Separation

**Status**: Accepted  
**Date**: 2026-04-24  
**Context**: Cleanup V8 Phase 4 target decision

## Context

The project is intended to ship as a reusable template, but demo content and template infrastructure currently share top-level script/resource folders. Consumers need to delete demo content without breaking the core template.

## Decision

Separate reusable template code/content from examples with `core` and `demo` ownership boundaries. `scripts/core/` already exists and remains the seed for template-owned code; Phase 4 extends the split through scripts/resources and enforces that core code does not import demo code.

## Alternatives Considered

- **Keep mixed folders**: least churn, but keeps deletion and review boundaries unclear.
- **Top-level `template/` and `game/` trees**: clearer conceptually, but larger path churn than extending existing `core` patterns.

## Consequences

**Positive**

- Template consumers get a clearer deletion boundary for demos.
- Import-boundary tests can enforce ownership.

**Negative**

- Phase 4 path moves must update scene/resource references atomically.

## References

- `docs/guides/cleanup_v8/cleanup-v8-tasks.md`

