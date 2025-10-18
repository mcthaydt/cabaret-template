# Resource-Driven Settings Migration Plan (Phased)

This plan describes step‑by‑step phases to migrate ECS components to resource‑driven settings with strict failure on missing settings, no grounded fallback in Movement, default `.tres` delivery, and unchanged scope beyond specified components/systems. It also details how we keep tests passing at each phase.

Guiding constraints
- Tabs for Godot scripts; avoid space tabs.
- Add explicit types for Variant returns to avoid warnings treated as errors.
- Movement requires `support_component_path` → `FloatingComponent` for support‑aware tuning.
- After a jump, clear/reset support timers to prevent unintended extra jumps.
- Keep max turn/velocity clamps to prevent overshoot.

## Phase 0 — Baseline and Safety Nets

Objectives
- Understand current usage and tests; set baseline for expected behaviour.
- Prepare helpers to speed up test updates.

Actions
- Scan for all tunable fields: use ripgrep on `scripts/ecs/components` to map current exports to settings fields.
- Confirm current test expectations (bounds, near‑equals) that depend on default values.
- Prepare a tiny per‑test helper snippet (not a global util) to assign default settings within each test file to avoid cross‑test pollution.

Validation
- Run unit tests to establish a baseline green suite:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs`

## Phase 1 — Scaffolding Settings Resources + Defaults

Objectives
- Introduce settings Resource classes with defaults matching current component exports.
- Create default `.tres` assets that mirror these defaults.

Actions
- Add `scripts/ecs/resources/` with the following Resource scripts (class_name provided for inspector convenience):
  - `movement_settings.gd` → `class_name MovementSettings`
  - `jump_settings.gd` → `class_name JumpSettings`
  - `floating_settings.gd` → `class_name FloatingSettings`
  - `rotate_to_input_settings.gd` → `class_name RotateToInputSettings`
  - `align_settings.gd` → `class_name AlignSettings`
  - `landing_indicator_settings.gd` → `class_name LandingIndicatorSettings`
- Ensure explicit types and default values exactly match current component exports.
- Create default assets under `resources/`:
  - `movement_default.tres`, `jump_default.tres`, `floating_default.tres`, `rotate_default.tres`, `align_default.tres`, `landing_indicator_default.tres`.
- Do not reference settings from components yet (no breaking change in this phase).

Validation
- No functional changes; run tests to ensure still green.

## Phase 2 — Components: Introduce `settings` (strict) + Keep NodePaths

Objectives
- Switch components to use a single `@export var settings: XxxSettings`.
- Fail hard when settings are missing.

Actions
- For each component under `scripts/ecs/components/`:
  - Add `@export var settings: XxxSettings`.
  - Remove legacy per‑field exports completely (no dual‑path/legacy access).
  - Keep NodePaths and ephemeral runtime state (dynamics/rotation velocities, debug snapshots).
  - Add `_ready()` guard:
    - If `settings == null`, log an error and `set_process(false); set_physics_process(false)` to fail hard and be obvious during tests.
- Do not yet change systems; components compile and register, but systems still read legacy fields (next phase will change systems).

Validation
- Update all tests in the same change set to assign settings before systems tick. See Phase 4 for specifics.
- Run tests; fix any missing type hints flagged by Godot.

## Phase 3 — Systems: Read From `settings` Only

Objectives
- Migrate all system logic to use `component.settings.*` exclusively.
- Enforce design decisions (no grounded fallback; jump clears support timers).

Actions
- `scripts/ecs/systems/movement_system.gd`
  - Replace all reads to component fields with `component.settings.*`.
  - Compute `support_active` only via `FloatingComponent` link:
    - `var support_active := false`
    - If `support_component != null`: `support_active = support_component.has_recent_support(now, settings.support_grace_time)`
    - Remove any fallback to `body.is_on_floor()` when calculating support‑aware damping/friction.
  - Keep speed clamps and second‑order dynamics logic as‑is, using settings values.
- `scripts/ecs/systems/jump_system.gd`
  - Replace uses of `jump_force`, `coyote_time`, `max_air_jumps`, `jump_buffer_time`, `apex_*` with `jump.settings.*`.
  - After a successful jump:
    - If there’s a `FloatingComponent` for the same body, clear support timers: set `update_support_state(false, now - jump.settings.coyote_time - 0.01)` to ensure `has_recent_support` returns false immediately.
- `scripts/ecs/systems/floating_system.gd`
  - Replace reads with `component.settings.*`; keep clamps and normal alignment logic.
- `scripts/ecs/systems/rotate_to_input_system.gd`
  - Replace reads with `component.settings.*`; preserve max turn speed clamp to avoid overshoot.
- `scripts/ecs/systems/align_with_surface_system.gd`
  - Replace reads with `component.settings.*`.
- `scripts/ecs/systems/landing_indicator_system.gd`
  - Replace reads with `component.settings.*`.

Validation
- Compile and run tests; expect compile‑time/type issues first, then behavioural.
- Adjust any missed type hints (e.g., explicit `as` casts for Variant returns) until green.

## Phase 4 — Tests: Update to Resource‑Driven API

Objectives
- Ensure all tests use the new `settings` interface and keep behaviourally equivalent assertions.

Actions (by suite)
- Common pattern per test:
  - Immediately after creating a component instance, assign settings: `component.settings = XxxSettings.new()`.
  - Set NodePaths after adding nodes; set `movement.support_component_path` when a test needs grounded behaviour.
  - Keep assertions identical by matching default values.

- `tests/unit/ecs/components/test_player_components.gd`
  - Replace `component.foo` expectations with `component.settings.foo`.
  - Verify `get_component_type()` unchanged.

- `tests/unit/ecs/systems/test_movement_system.gd`
  - For tests requiring grounded damping/friction or grounded multiplier, include a `FloatingComponent` and link it via `movement.support_component_path`.
  - Use `movement.settings.*` to configure: `max_speed`, `sprint_speed_multiplier`, `acceleration`, `deceleration`, second‑order params, and friction scales.
  - Remove reliance on `body.is_on_floor()` for support: explicitly call `floating.update_support_state(true/false, now)` depending on scenario.
  - Keep numeric expectations (e.g., second‑order step values and clamp tests) as they were; defaults are identical.

- `tests/unit/ecs/systems/test_jump_system.gd`
  - Assign `jump.settings = JumpSettings.new()` and configure buffer/coyote/apex as needed via settings.
  - Where needed, set a `FloatingComponent` and link to the same body for support tests.
  - Validate jump applies `settings.jump_force` and that support timers are cleared post‑jump (no unintended follow‑up jumps).

- `tests/unit/ecs/systems/test_rotate_to_input_system.gd` and `test_rotate_system.gd`
  - Assign `component.settings = RotateToInputSettings.new()`; configure second‑order/turn‑speed via settings.
  - Keep overshoot clamps expectations unchanged.

- `tests/unit/ecs/systems/test_floating_system.gd`
  - Assign `component.settings = FloatingSettings.new()` and set hover/ratio/speeds if the test changes them.

- `tests/unit/ecs/systems/test_align_with_surface_system.gd`
  - Assign `component.settings = AlignSettings.new()`; use settings to configure `align_only_when_supported`, `recent_support_tolerance`, `smoothing_speed`.

- `tests/unit/ecs/systems/test_landing_indicator_system.gd`
  - Assign `component.settings = LandingIndicatorSettings.new()` and configure `max_projection_distance`, `ground_plane_height`, etc.

- `tests/unit/ecs/systems/test_gravity_system.gd`
  - Ensure `MovementComponent` has `movement.settings = MovementSettings.new()` even if gravity doesn’t use settings directly (to satisfy strictness).

Validation gates (per test file update)
- After updating each test file, run only that suite to keep feedback tight, then run the full suite:
  - Single suite (example): `-gdir=res://tests/unit/ecs/systems -ginclude=test_movement_system.gd`
  - Full suite: default command from Phase 0.

## Phase 5 — Templates and Scenes

Objectives
- Make it easy in editor to use resource‑driven settings.

Actions
- Update `templates/player_template.tscn` and `templates/base_scene_template.tscn` to assign default `.tres` to each component `settings` export.
- Document use:
  - Duplicate a default `.tres` to create variants.
  - Assign per entity to swap behaviours.

Validation
- Open templates in editor; verify settings appear and defaults load without errors.

## Phase 6 — Documentation and Housekeeping

Objectives
- Ensure team clarity and consistency after migration.

Actions
- Keep `docs/resource_driven_settings_prd.md` as the authoritative design.
- Add a brief migration note to `README.md` (link to the PRD and this plan).
- Verify no lingering legacy fields via ripgrep (`rg "@export var .*: .* =" scripts/ecs/components | rg -v settings`).

## Phase 7 — Final QA and Stabilization

Objectives
- Confirm stability and behaviour parity with strict rules enforced.

Actions
- Run the full test suite and address any remaining failures.
- Manual smoke test in editor with templates:
  - Sprinting speed change by swapping Movement `.tres`.
  - Rotation smoothing toggled via Rotate `.tres`.
  - Floating hover height change via Floating `.tres`.

Exit criteria
- All unit tests green.
- No reads from legacy fields; only `settings`.
- Movement support detection uses `FloatingComponent` only (no `is_on_floor()` fallback).
- Components fail hard if `settings == null`.
- Templates reference committed default `.tres`.

## Risk Management

- Missing settings causing runtime errors
  - Mitigation: `_ready()` guard fails early; tests assign settings explicitly.
- Shared Resource side effects
  - Mitigation: educate via docs; duplicate `.tres` for per‑entity overrides.
- Overshoot/regression in second‑order tuning
  - Mitigation: keep clamps intact; tests assert post‑step values and clamp behaviour.

## Backout Plan

If critical regressions occur:
- Revert systems to the last green commit while keeping Resource classes to minimize churn.
- Re‑enable tests against legacy behaviour temporarily on a feature branch only if absolutely necessary (not expected, given concurrent test refactors).

---

Quick command references
- Full tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs`
- Ripgrep helpers:
  - Find legacy exports: `rg "@export var (?!settings:)" scripts/ecs/components`
  - Find direct field reads: `rg "\.(max_speed|acceleration|deceleration|jump_force|hover_height)\b" scripts/ecs/systems`
