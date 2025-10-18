# Resource-Driven ECS Component Settings PRD

## Summary
Move all tunable gameplay parameters from ECS components into dedicated Resource assets (Scriptable Object–like) to enable shared, swappable settings per entity. Components will expose a single `settings` export referencing a typed Resource. Systems and tests will read values exclusively through these Resources. No legacy per-field exports remain on components.

## Goals
- Centralize tuning in reusable Resources to swap behaviours quickly.
- Enforce a single source of truth; remove legacy fallbacks and duplicated fields.
- Preserve current behaviours and clamps with equivalent default values.

## Scope
- Components: Movement, Jump, Floating, RotateToInput, AlignWithSurface, LandingIndicator.
- Systems: Read from `settings` only; minimal logic changes.
- Tests: Update to set/assert via `component.settings`.

## Non-Goals
- No gameplay feature additions beyond resource-driven config.
- No editor tooling beyond adding default `.tres` assets.
- No networking/serialization work.

## Editor UX
- Each component exposes `@export var settings: XxxSettings` only.
- Defaults shipped as `.tres` under `resources/` for quick assignment and reuse.
- NodePaths for wiring (e.g., `character_body_path`) stay on components.

## Architecture
- Add typed Resource scripts under `scripts/ecs/resources/`:
  - `RS_MovementSettings`, `RS_JumpSettings`, `RS_FloatingSettings`, `RS_RotateToInputSettings`, `RS_AlignSettings`, `RS_LandingIndicatorSettings`.
- Replace component per-field exports with `settings` and keep ephemeral state (e.g., dynamics/rotation velocities, debug snapshots) in components.
- Strictness: Fail hard if `settings == null`. Each component validates in `_ready()` and will assert or error-out and disable processing when settings are missing. Scenes and tests must assign settings (either default `.tres` or `XxxSettings.new()`).

### Component Changes (field mapping → settings)
- C_MovementComponent
  - max_speed, sprint_speed_multiplier, acceleration, deceleration
  - use_second_order_dynamics, response_frequency, damping_ratio
  - grounded_damping_multiplier, air_damping_multiplier
  - grounded_friction, air_friction, strafe_friction_scale, forward_friction_scale
  - support_grace_time
  - Keep NodePaths: `character_body_path`, `input_component_path`, `support_component_path`.

- C_JumpComponent
  - jump_force, coyote_time, max_air_jumps, jump_buffer_time
  - apex_coyote_time, apex_velocity_threshold
  - Keep NodePaths: `character_body_path`, `input_component_path`.

- C_FloatingComponent
  - hover_height, hover_frequency, damping_ratio
  - max_up_speed, max_down_speed, fall_gravity
  - height_tolerance, settle_speed_tolerance, align_to_normal
  - Keep NodePaths: `character_body_path`, `raycast_root_path`.

- RotateToC_InputComponent
  - turn_speed_degrees, max_turn_speed_degrees
  - use_second_order, rotation_frequency, rotation_damping
  - Keep NodePaths: `target_node_path`, `input_component_path`.

- C_AlignWithSurfaceComponent
  - smoothing_speed, align_only_when_supported, recent_support_tolerance
  - fallback_up_direction
  - Keep NodePaths: `character_body_path`, `visual_alignment_path`, `floating_component_path`.

- C_LandingIndicatorComponent
  - indicator_height_offset, ground_plane_height, max_projection_distance
  - Keep NodePaths: `character_body_path`, `origin_marker_path`, `landing_marker_path`.

### Systems Adjustments
- S_MovementSystem
  - Read all tuning from `movement.settings`.
  - Support-aware damping/friction uses `C_FloatingComponent.has_recent_support(now, movement.settings.support_grace_time)`.
  - Remove `is_on_floor()` fallback entirely for support-aware tuning. If no `C_FloatingComponent` is linked, treat as unsupported (air coefficients apply) regardless of body floor state.

- S_JumpSystem
  - Read buffer/coyote/force/apex values from `jump.settings`.
  - After a jump, clear support timers: if a `C_FloatingComponent` is associated with the same body, mark it as not supported with a timestamp older than `coyote_time` to avoid unintended extra jumps.

- S_FloatingSystem, RotateToS_InputSystem, S_AlignWithSurfaceSystem, S_LandingIndicatorSystem
  - Replace all field reads with `component.settings.*`; preserve existing clamps and second‑order dynamics behaviour.

- S_GravitySystem, S_InputSystem
  - No changes required for this pass (optional future: move to resources).

## Resource Definitions
- RS_MovementSettings
  - max_speed, sprint_speed_multiplier, acceleration, deceleration
  - use_second_order_dynamics, response_frequency, damping_ratio
  - grounded_damping_multiplier, air_damping_multiplier
  - grounded_friction, air_friction, strafe_friction_scale, forward_friction_scale
  - support_grace_time

- RS_JumpSettings
  - jump_force, coyote_time, max_air_jumps, jump_buffer_time
  - apex_coyote_time, apex_velocity_threshold

- RS_FloatingSettings
  - hover_height, hover_frequency, damping_ratio
  - max_up_speed, max_down_speed, fall_gravity
  - height_tolerance, settle_speed_tolerance, align_to_normal

- RS_RotateToInputSettings
  - turn_speed_degrees, max_turn_speed_degrees
  - use_second_order, rotation_frequency, rotation_damping

- RS_AlignSettings
  - smoothing_speed, align_only_when_supported, recent_support_tolerance
  - fallback_up_direction

- RS_LandingIndicatorSettings
  - indicator_height_offset, ground_plane_height, max_projection_distance

## Behavioural Notes
- Movement support detection requires a `C_FloatingComponent` link; this ensures support-aware damping/friction are truly contact-driven.
- After jumping, support grace is cleared to prevent unintended buffered/coyote jumps.
- Keep existing max speed/turn clamps to avoid overshoot in movement/rotation tests.

## Files to Add/Change (implementation plan)
- New: `scripts/ecs/resources/*.gd` for all settings types.
- New defaults: `resources/*_default.tres` for each settings type (committed) and referenced by templates.
- Update: all components to export `settings` and remove legacy fields.
- Update: systems to use `settings`.
- Update: tests to configure/inspect via `component.settings`.
- Update: templates/scenes to assign default settings assets.

## Testing Plan
- Update unit tests under `tests/unit/ecs` to:
  - Instantiate and assign `component.settings = XxxSettings.new()` or load default `.tres`.
  - Use `settings` to configure scenarios (e.g., grounded friction, second‑order params, jump buffer/coyote).
  - Ensure no references remain to legacy per-field exports.
- Run:
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs`

## Migration
- Scenes: assign appropriate default settings `.tres` to each component instance.
- Code/tests: replace `component.foo` with `component.settings.foo`.
- Movement: link `support_component_path` to a `C_FloatingComponent` where grounded-specific tuning is desired.

## Risks & Mitigations
- Scene breakage due to removed fields: ship defaults and provide migration notes.
- Shared Resource mutation affects multiple entities: document and recommend duplicate-per-entity when needed.
- Missing settings at runtime: log clear errors; tests always assign settings explicitly.

## Rollout
1) Add Resources + defaults and wire components.
2) Update systems and tests; remove legacy fields.
3) Update templates and docs.

## Decisions
- Strictness: Fail hard if `settings == null`; components validate at `_ready()`.
- Grounded fallback: Remove any `is_on_floor()` fallback for support-aware tuning.
- Defaults delivery: Provide committed default `.tres` assets and reference them in templates.
- Scope stretch: Leave Gravity/Input as-is for this pass.
