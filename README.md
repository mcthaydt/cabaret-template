# project-musical-parakeet

Resource-Driven Settings (Migration Notes)
- All ECS components now expose a single `settings` export referencing a typed Resource (e.g., `MovementSettings`, `JumpSettings`). Per‑field tunables were removed from components; systems and tests must read and set values via `component.settings.*`.
- Components fail fast in `_ready()` if `settings == null`. Scenes and tests must assign a Resource (use the defaults in `resources/*.tres` or `XxxSettings.new()`).
- Movement grounded behaviour depends on `FloatingComponent`: wire `MovementComponent.support_component_path` to a `FloatingComponent` so support‑aware damping/friction engage; there is no `is_on_floor()` fallback.
- Jump clears/ages support after a jump to prevent unintended extra jumps.
- Defaults live under `resources/`: `movement_default.tres`, `jump_default.tres`, `floating_default.tres`, `rotate_default.tres`, `align_default.tres`, `landing_indicator_default.tres`. Templates are pre‑wired to these.

Docs
- Design PRD: `docs/resource_driven_settings_prd.md`
- Migration plan: `docs/resource_settings_migration_plan.md`

Run Tests
- Headless GUT unit tests:
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs`

Dev Tips
- Godot scripts here use tab indentation; do not mix spaces.
- Add explicit type annotations for values coming from Variant‑returning helpers.
- After switching settings in tests, assign before adding a node to the tree to avoid `_ready()` strictness errors.
