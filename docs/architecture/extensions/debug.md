# Add Debug / Perf Surface

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new perf probe (`U_PerfProbe`)
- A new debug log throttle (`U_DebugLogThrottle`)
- A new debug overlay panel or 3D label
- A new compile-time gated tracer
- A new debug state field in the Redux `debug` slice

This recipe does **not** cover:

- State slice creation (see `state.md`)
- ECS system authoring (see `ecs.md`)
- Manager registration (see `managers.md`)

## Governing ADR(s)

- [ADR 0008: Debug/Perf Utility Extraction](../adr/0008-debug-perf-utility-extraction.md)

## Canonical Example

- Perf probe: Any system using `U_PerfProbe.create("system_name")`
- Log throttle: `scripts/utils/debug/u_debug_log_throttle.gd`
- Debug panel: `scripts/demo/debug/debug_ai_brain_panel.gd` (extends `Control`)
- 3D label: `scripts/demo/debug/debug_woods_agent_label.gd` (extends `Label3D`)
- State overlay: `scripts/debug/debug_state_overlay.gd` (extends `CanvasLayer`)
- Tracer: `scripts/utils/scene_director/u_objectives_debug_tracer.gd`
- Debug Redux slice: `scripts/state/actions/u_debug_actions.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `U_PerfProbe` | Block profiler: `create(name, enabled, flush_interval)`, `start()`, `stop()`. Auto-enables on mobile. Zero-cost when disabled. |
| `U_DebugLogThrottle` | Rate-limited logging: `consume_budget(key, interval_sec) -> bool`, `tick(delta)`. |
| `U_PerfMonitor` | Frame-level FPS/render reporter. Auto-enables on mobile. |
| `U_PerfShaderBypass` | Mobile shader bypass cycler (5 rapid taps). |
| `U_PerfFadeBypass` | Static fade bypass toggle. |

Debug panels use `Debug<Name>` prefix. CanvasLayer overlays use `SC_<Name>` prefix. Log prefix: `[PERF]` for perf, `[VictoryDebug]` for objectives.

## Recipe

### Adding a new perf probe

1. Create at system initialization: `var _probe: RefCounted = U_PerfProbe.create("my_system")`.
2. Wrap hot code: `_probe.start()` / `_probe.stop()`.
3. Output is automatic: `[PERF] my_system samples=N avg=Xms` every flush interval.

### Adding a new debug log throttle

1. Create: `var _throttle := U_DebugLogThrottle.new()`.
2. Tick each frame: `_throttle.tick(delta)`.
3. Use: `if _throttle.consume_budget(&"my_key", 2.0): _throttle.log_message(...)`.

### Adding a new debug overlay panel

1. Create under `scripts/debug/debug_<name>.gd`. Extend `Control` (inspector panels) or `CanvasLayer` (screen overlays) or `Label3D` (3D world labels).
2. CanvasLayer overlays: set `process_mode = PROCESS_MODE_ALWAYS`, `layer = U_CANVAS_LAYERS.DEBUG_OVERLAY`.
3. Use `_ready()` with `await get_tree().process_frame` before accessing store/tree.
4. Connect to `M_StateStore` signals (`slice_updated`, `action_dispatched`). Disconnect in `_exit_tree()`.
5. Throttle expensive updates (JSON.stringify) to ~4Hz.

### Adding a new compile-time gated tracer

1. Create utility class with `const DEBUG_TRACE := false`.
2. All methods check `if not DEBUG_TRACE: return` as first line.
3. Use consistent log prefix. All methods static. Zero runtime cost when disabled.

### Adding a new debug state field

1. Add action constant to `U_DebugActions`: `const ACTION_SET_X := StringName("debug/set_x")`.
2. Register in `_static_init()` via `U_ActionRegistry.register_action()`.
3. Add to `U_DebugReducer.DEFAULT_DEBUG_STATE`.
4. Add match case in `U_DebugReducer.reduce()`.
5. Add selector to `U_DebugSelectors`.

## Anti-patterns

- **Bare `print()` in hot paths**: Use `U_DebugLogThrottle`.
- **Leaving `U_PerfProbe` enabled in production**: Auto-enables on mobile; explicitly disable on desktop if not needed.
- **Overlays without `PROCESS_MODE_ALWAYS`**: Won't work when paused.
- **Forgetting to disconnect store signals in `_exit_tree()`**: Orphan callbacks.
- **Skipping `await get_tree().process_frame` in `_ready()`**: Scene may not be ready.
- **Compile-time tracers with `true` as default**: Keep `const DEBUG_* := false` in production.
- **`JSON.stringify()` in `_process()` without throttling**: Expensive.

## Out Of Scope

- State slice creation: see `state.md`
- ECS system: see `ecs.md`
- Manager registration: see `managers.md`

## References

- [ADR 0008: Debug/Perf Utility Extraction](../adr/0008-debug-perf-utility-extraction.md)