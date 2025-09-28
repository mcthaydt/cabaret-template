# Current Progress

## Core Platform Work
- Established the ECS framework (`ECSManager`, `ECSComponent`, `ECSSystem`) with automatic registration so components and systems link themselves when added to the scene tree.
- Authored gameplay components for player control (movement, jump, input, rotate-to-input) with helper accessors to the underlying `CharacterBody3D`, input nodes, and orientation targets.
- Implemented the companion systems (input, movement, gravity, jump, rotate-to-input) that query registered components each physics frame and drive character behaviour.
- Built reusable scene templates: `templates/player_template.tscn` bundles the player body, collider, and component nodes, while `templates/base_scene_template.tscn` wires managers, systems, a floor, and a spawn point for rapid level setup.
- Configured project input actions (`move_left`, `move_right`, `move_forward`, `move_backward`, `jump`) and ensured `InputSystem` seeds default key bindings at runtime.

## Testing & Tooling
- Added GUT unit coverage for the ECS manager and each gameplay system, using lightweight fake nodes to validate velocity, rotation, gravity, and jump behaviour.
- Documented the architecture and workflow (`docs/implementation_details.md`) and surfaced key commands in `AGENTS.md` for quick onboarding.

## Recent Updates
- Converted movement, jump, and rotate-to-input components to typed `@export_node_path` hints so inspector assignments are validated.
- Corrected the player template’s component paths to reference the shared `Player_Body`, preventing null bodies at runtime.
- Adjusted the rotate-to-input system yaw calculation so horizontal input matches world-space directions and added a focused regression test.
- Stabilised the floating system with a second-order dynamics solver and tolerance window so hover bodies settle cleanly without bounce.
- Linked the floating and jump systems via recent-support tracking, restoring jump responsiveness for hovering characters while keeping coyote-time behaviour consistent.
- Extended the unit suite to cover the floating component/system upgrades and the new jump integration, ensuring upward launches aren’t cancelled by hover support.
- Captured a project architecture overview diagram (`docs/images/project_architecture_overview.mmd`) to document how templates, components, systems, and tooling fit together.
- Added a per-system flow reference (`docs/images/system_flows.mmd`) outlining the runtime relationships between each ECS system, its components, and supporting nodes.
- Recorded these changes and testing notes here; ran the ECS system GUT suite (`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs`) to confirm all tests pass—Godot logs the success summary before the headless process fails to exit cleanly.
