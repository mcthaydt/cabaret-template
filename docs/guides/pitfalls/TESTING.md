# Testing Pitfalls

Common GUT, headless Godot, and test-isolation pitfalls for this project.

---

## Test Commands

- Prefer the project wrapper:
  ```sh
  tools/run_gut_suite.sh
  ```
- Run a focused test:
  ```sh
  tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd
  ```
- Run a focused directory recursively:
  ```sh
  tools/run_gut_suite.sh -gdir=res://tests/unit/ecs -ginclude_subdirs=true
  ```
- Always include `-gexit` when invoking GUT directly through Godot, or the process can hang.
- Tests commonly need `await get_tree().process_frame` after adding nodes so auto-registration with `M_ECSManager` or `U_ServiceLocator` has completed before assertions.

## Dependency Injection

- Systems support exported dependency injection for isolated tests.
- `BaseECSSystem` exposes `@export var ecs_manager: I_ECSManager`.
- State-dependent systems expose `@export var state_store: I_StateStore` where needed.
- `U_StateUtils.get_store()` and `U_ECSUtils.get_manager()` check explicit injection first, then fall back to `U_ServiceLocator`.
- Use `MockStateStore` and `MockECSManager` from `tests/mocks/` for isolated tests.
- `MockStateStore.get_dispatched_actions()` verifies actions; `MockStateStore.set_slice()` seeds test state; `MockECSManager.add_component_to_entity()` populates components.

Example:

```gdscript
var mock_manager := MockECSManager.new()
var mock_store := MockStateStore.new()
var system := S_HealthSystem.new()
system.ecs_manager = mock_manager
system.state_store = mock_store
```

## Asset Import

- **New assets used with `preload()` can fail until `.import` files exist**: If you add a new `*.ogg`, `*.png`, or similar asset and immediately reference it via `preload("res://...")`, headless GUT runs can fail because Godot has not generated the sidecar `*.import` file yet.
  - **Fix**: Run a one-time import pass before tests:
    ```sh
    HOME="$PWD/.godot_user" /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
    ```
  - Commit generated `*.import` files next to the asset. Do not commit `.godot/imported`.

## Test Execution

- **GUT needs recursive dirs**: `-gdir` is not recursive by default. Use explicit leaf directories or pass `-ginclude_subdirs=true`.
- **Godot 4.6 CLI compatibility renderer flag is `gl_compatibility`, not `compatibility`**: Use `--rendering-method mobile` or `--rendering-method gl_compatibility` when validating shader/runtime behavior outside Forward+.
- **Viewport capture fails in headless**: `Viewport.get_texture().get_image()` can error under the headless renderer. Mark screenshot-capture tests `pending` when `OS.has_feature("headless")` or `DisplayServer.get_name() == "headless"`.
- **Detached `Node3D.global_position` access produces engine errors in GUT**: Add nodes to the tree before touching global transforms, or use local `position` while detached.
- **Detached `Node.get_path()` can throw in unit tests**: Guard with `is_inside_tree()`; for detached nodes, emit a synthetic marker such as `<detached:NodeName>`.
- **`M_StateStore` persistence can leak ambient user state into tests**: For tests not explicitly validating persistence, set `store.settings.enable_persistence = false` before adding the store node.
- **`M_StateStore` does not expose `set_slice(...)` like `MockStateStore`**: Seed real-store tests through reducer actions (`store.dispatch(...)`) and reserve direct `set_slice(...)` usage for `MockStateStore`.
- **Do not assert raw `push_warning` output directly**: Engine warnings are hard to capture reliably in headless runs. Expose a warning hook in test doubles or assert deterministic return/state instead.
- **Expected warnings can be treated as unexpected test errors**: For validation-failure branches expected in tests, prefer deterministic non-warning observability over warning-channel assertions.
- **Tween pause mode is not reliably introspectable**: Prefer behavior-focused assertions over inspecting tween pause internals.
- **ServiceLocator-only discovery requires explicit test registrations**: Register services such as `hud_layer`, `active_scene_container`, `ui_overlay_stack`, `transition_overlay`, `loading_overlay`, `post_process_overlay`, and `game_viewport` in lightweight scene scaffolds.
- **Use ServiceLocator registration keys, not class-like names**: Root service keys are canonical names like `scene_manager`, `state_store`, and `camera_manager`, not `M_SceneManager` or `M_StateStore`.
- **Standalone touchscreen-settings overlay tests can leave gameplay shell**: Seed/push overlay-stack state before Apply, or explicitly dispatch gameplay shell and touchscreen device actions before sampling touch look input.

## GUT Patterns

- **Expected errors must use `assert_push_error()` after the action**: Call `assert_push_error("error pattern")` immediately after the action that causes the error.
- **Prefer `print()` for temporary diagnostics**: `gut.p()` output can be buffered or discarded by the CLI harness. Remove or guard noisy prints before merging.
- **Default diagnostic debug flags to `true` during active investigation**: For temporary diagnostics, enabled-by-default ensures the run actually produces signal.
- **State handoff persists across tests**: Call `U_StateHandoff.clear_all()` in `before_each()` and `after_each()` when tests instantiate `M_StateStore`.
- **Avoid private-manager assertions**: Prefer public API and observable behavior over checking private fields/methods that are likely to change during helper extraction.
- **Mock overrides need warning suppression**: When stubbing engine methods such as `is_on_floor()` or `move_and_slide()`, add `@warning_ignore("native_method_override")`.
- **Always register fixtures with GUT autofree**: Use `add_child_autofree(node)` for nodes created in tests.
- **Clear static state between tests**: Reset event buses, state handoff, and other static registries in `before_each()` and `after_each()`.
- **Systems requiring `M_StateStore` need it in setup**: Add and initialize a store before ticking systems that read state.
- **Integration tests need extra initialization frames**: Full-scene tests often need process and physics frame waits after scene instantiation before querying systems/managers.
- **`wait_frames()` is deprecated**: Use `wait_physics_frames()` for ECS/physics behavior and `wait_process_frames()` for process-frame behavior.

## Headless Tests

- **Headless GUT runs crash if `user://` resolves outside the sandbox**: Always launch through `tools/run_gut_suite.sh`, or manually set `HOME="$PWD/.godot_user"` when invoking Godot directly.
- The wrapper also enables recursive suite discovery so nested tests do not get skipped silently.

## Coverage Status

- Display Manager has focused unit coverage for display reducers/selectors and manager behavior, but headless limitations prevent direct fullscreen/window-mode verification.
- Tests cannot verify OS-level `DisplayServer.window_set_mode()` side effects, physical monitor resolution changes, fullscreen toggles, viewport texture capture, or thread behavior around DisplayServer calls.
- Manual QA remains required for real display-mode switching, fullscreen/windowed transitions, vsync behavior, UI scaling on varied resolutions, post-process rendering, and persistence across app restarts.
