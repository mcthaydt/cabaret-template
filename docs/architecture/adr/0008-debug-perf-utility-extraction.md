# ADR 0008: Debug and Perf Utility Extraction

**Status**: Accepted  
**Date**: 2026-04-24  
**Context**: Cleanup V8 Phase 2

## Context

Managers and ECS systems accumulated inline `print()` calls, throttling dictionaries, debug probes, and perf timing blocks. These patterns made production paths noisy and inconsistent.

## Decision

Route debug logging and performance probes through shared utilities. Use `U_DebugLogThrottle` for throttled diagnostics and `U_PerfProbe` for scoped performance instrumentation. Bare `print()` calls are forbidden in managers and ECS systems by style enforcement.

## Alternatives Considered

- **Inline debug guards**: low ceremony, but duplicates state and policy.
- **Compile-time flags only**: useful for broad feature gates, but not enough for targeted runtime diagnostics.

## Consequences

**Positive**

- Debug/perf behavior is centralized and testable.
- Production code paths stay cleaner.
- Style enforcement catches regressions.

**Negative**

- New debug sites must pick a utility and tag instead of writing one-off prints.

## References

- `scripts/utils/debug/u_debug_log_throttle.gd`
- `scripts/utils/debug/u_perf_probe.gd`
- `tests/unit/style/test_style_enforcement.gd`

