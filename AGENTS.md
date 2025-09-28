# Agents Notes

## Documentation
- Current progress snapshot: `docs/current_progress.md`
- ECS architecture & workflow: `docs/implementation_details.md`

## Test Commands
- GUT unit tests: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs`

## Things To Remember
- Godot scripts in this repo expect tab indentation; mixing spaces triggers parse errors.
- Add explicit type annotations (`: bool`, `: Vector3`, etc.) whenever values come from Variant-returning helpers to avoid warnings treated as errors.
- `MovementComponent.support_component_path` should point at a `FloatingComponent` so support-aware damping/friction works; missing links quietly disable the new tuning.
- After a jump, clear or reset support timers (see `JumpComponent.on_jump_performed`) to prevent unintended extra jumps—tests rely on this behaviour.
- When tweaking second-order parameters, keep max turn/velocity clamps in mind so you don’t reintroduce overshoot in rotation or movement tests.
