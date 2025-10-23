# ECS Debugger Plugin – Quick Start for Humans

## Picking Up After Planning

Planning is complete. Before you dive into implementation:

1. Re-read the quick guidance docs:
   - `AGENTS.md`
   - `docs/general/DEV_PITFALLS.md`
   - `docs/general/STYLE_GUIDE.md`

2. Review planning status:
   - `docs/ecs plugin tool/ecs_plugin_tool_plan.md` (70 steps, TDD-first, 0% → 100%)
   - `docs/ecs plugin tool/ecs_plugin_tool_prd.md` (user stories, acceptance criteria)
   - `docs/ecs plugin tool/ecs_plugin_tool_architecture.md` (technical deep-dive)

3. Familiarize yourself with the dependencies:
   - `scripts/managers/m_ecs_manager.gd` (get_query_metrics:109, get_systems:86)
   - `scripts/ecs/ecs_event_bus.gd` (get_event_history:81, clear_history:73)
   - `scripts/ecs/ecs_system.gd` (set_debug_disabled:50, execution_priority)
   - `scripts/utils/u_ecs_utils.gd` (manager discovery pattern, static methods)
   - `addons/gut/gut_plugin.gd` (EditorPlugin bottom panel example)
   - `tests/unit/ecs/test_ecs_manager.gd` (test pattern reference)

4. **Implementation Requirements**:
   - Write elegant, minimal, modular code
   - Adhere strictly to existing patterns and conventions
   - Include thorough comments/documentation
   - **Update `ecs_plugin_tool_plan.md` as you go**: Change 🟥 → 🟩, update progress %
   - Follow TDD discipline: RED → GREEN → REFACTOR
   - Run tests: `Godot --headless --path . -s addons/gut/gut_cmdln.gd -gselect=test_ecs_debugger_plugin -gexit`

5. Start with **Phase 1** (Data Layer). Build `U_ECSDebugDataSource` TDD-first, keep GUT runs green, and update plan/progress at each milestone.

## Friendly Resources

- `ecs_plugin_tool_ELI5.md` – User guide (beginner-friendly)
- `ecs_plugin_tool_architecture.md` – Technical reference
- `ecs_plugin_tool_plan.md` – Implementation roadmap
- `ecs_plugin_tool_prd.md` – Requirements & stories

Happy coding!
