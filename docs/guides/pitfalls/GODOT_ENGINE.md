# Godot Engine Pitfalls

Engine-level quirks and platform-specific gotchas for Godot 4.6.

---

## Godot Scene UIDs

- **Never manually specify UIDs in .tscn files**: When creating scene files programmatically or via text editing, do NOT include `uid://` lines in the scene file. Godot automatically generates and manages UIDs when you save scenes in the editor. Manually-specified UIDs will cause "Unrecognized UID" errors because Godot's UID registry doesn't know about them. **Solution**: Let Godot generate UIDs by either:
  - Creating scenes in the Godot editor and saving normally
  - Creating scene files without the `uid=` parameter in the header line
  - Opening manually-created scenes in the editor and re-saving to generate proper UIDs

  Example of WRONG approach:
  ```
  [gd_scene load_steps=3 format=3 uid="uid://cjxbw8u5jn7nn"]  # DON'T DO THIS
  ```

  Example of CORRECT approach:
  ```
  [gd_scene load_steps=3 format=3]  # Let Godot add UID when you save in editor
  ```

- **Refresh UID cache after moving scenes**: Moving `.tscn` files can leave `.godot/uid_cache.bin` pointing at old paths, which triggers instance warnings like "node ... has been removed or moved" and causes missing nodes in headless tests. **Fix**: refresh the UID cache by opening the project once in the editor or running:
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
  ```

- **Do not copy `ext_resource` UID strings blindly between scenes**: If an `ext_resource` line references a UID that does not match the target script/resource (`invalid UID ... using text path instead`), headless tests can fail with unexpected warnings. When hand-editing `.tscn` files, either:
  - omit the `uid="uid://..."` field on new `ext_resource` entries, or
  - verify the exact UID from the source `.uid` file before pasting it.

- **Script renames can leave stale `ext_resource` UIDs in scenes**: After renaming/moving a script referenced by `.tscn` files, scene `ext_resource` lines may keep a UID that still resolves to the old path (for example, trying to load `res://.../old_name.gd` even when `path="res://.../new_name.gd"` is present). This can fail headless style/scene tests with parse errors.
  - **Fix**: remove the stale `uid="uid://..."` on affected `ext_resource` lines (let Godot regenerate it), or refresh UID/cache via headless import.

---

## Godot Physics Pitfalls

- **CSG visuals under `CharacterBody3D` can self-collide and cause jitter**: If an NPC/player body has a child `CSG*` visual with `use_collision = true` on the same layer/mask as the body's collider, the internal CSG `StaticBody3D` can collide with its own parent during `move_and_slide()`. Symptoms include frame-to-frame jitter, micro-stalls, and unstable patrol motion.
  - **Fix pattern**: keep visual CSG collision disabled (`use_collision = false`) for body-child visuals, and use dedicated `CollisionShape3D`/physics bodies for gameplay collisions.

---

## Godot Script Class Cache

- **Refresh global class cache after moving `class_name` scripts**: Moving scripts that declare `class_name` can leave the global class cache pointing at old paths, causing scenes to instantiate with base `Control` nodes and missing methods in headless tests. **Fix**: run a headless import pass to rebuild the class cache:
  ```
  /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
  ```

---

## Godot UI Pitfalls

- **Use `RS_UIThemeConfig` + `U_UIThemeBuilder` tokens for shared UI styling, not inline `theme_override_*` scene edits**: Reintroducing scene-local overrides in polished UI screens bypasses the unified theme pipeline and causes style drift across menus/overlays.
  - **Fix pattern**: apply spacing/typography/panel tokens in controller scripts (`_apply_theme_tokens()` style methods) and keep scene files free of non-semantic inline overrides.

- **Store subscriptions can mutate bound controls between sequential dispatches in the same UI handler**: In settings overlays, calling `store.dispatch(...)` for one field can synchronously trigger `_on_state_changed(...)`, which may repopulate UI controls before the next dispatch reads its value.
  - **Fix pattern**: snapshot all UI control values to local variables first, then dispatch actions using those snapshots.

- **Motion resources are opt-in and must preserve no-op behavior when unset**: Assigning motion logic unconditionally can change legacy navigation/animation behavior on screens that intentionally do not opt in.
  - **Fix pattern**: keep `motion_set` nullable and treat `null` as a strict no-op (no automatic signal binding and no tween playback).

- **A small set of semantic per-node overrides are intentional and should not be "cleaned up"**: Some overrides are design semantics, not theme debt (for example signpost golden emphasis, danger/error emphasis labels, and mobile virtual-button exceptions).
  - **Fix pattern**: keep semantic overrides explicit and enforce global cleanup through `tests/unit/style/test_style_enforcement.gd::test_no_inline_theme_overrides_except_semantic`.

- **Snapping transition overlay + instant navigation can leave the screen black**: Endgame flows may call `U_TransitionOverlaySnap.hide_screen_and_snap_transition_overlay(...)` before dispatching navigation. If the next transition uses `instant`, there is no fade-in step to clear `TransitionColorRect.modulate.a`, so the new scene can remain fully obscured.
  - **Fix pattern**: instant transitions must explicitly clear `TransitionColorRect` alpha after scene swap (or use a fade transition that performs fade-in).

- **Always use `U_CanvasLayers` constants for script-authored layer assignments**: Do not introduce raw layer integers in GDScript for HUD/overlay/debug/post-process layering. Use `scripts/ui/u_canvas_layers.gd` constants so layer intent stays centralized and testable. Keep `.tscn` literals aligned with the same canonical map.

- **Unified UI theme bootstrapping needs a no-palette fallback**: In the merged font+theme pipeline, a root can receive a composed theme before `U_DisplayUIThemeApplier` has published an active palette. If the builder simply preserves base colors when palette is missing, roots with no pre-existing colors can remain unstyled until the next palette-triggered rebuild.
  - **Fix pattern**: when palette is `null`, preserve existing base-theme colors where they exist, but still apply `RS_UIThemeConfig.text_primary` to missing text color slots so first paint is deterministic.

- **`U_UIThemeBuilder.active_config` is global and can leak between tests**: UI/integration tests that set `active_config` can unintentionally affect later suites (for example, health-bar palette assertions reading themed defaults instead of runtime palette output) when they do not reset static state.
  - **Fix pattern**: explicitly set `U_UIThemeBuilder.active_config = null` in both `before_each` and `after_each` for tests that mutate the global config.

- **Loaded `RS_UIThemeConfig` resources can miss runtime stylebox defaults on mobile/export**: `cfg_ui_theme_default.tres` stores primitive tokens, but stylebox fields (`button_normal`, `panel_section`, etc.) may still be `null` at runtime on some export paths if hydration relies only on `_init()`.
  - **Fix pattern**: expose an explicit `ensure_runtime_defaults()` on `RS_UIThemeConfig` and call it from `U_UIThemeBuilder.build_theme(...)` before applying styleboxes.

- **Shared `root.gd` teardown can clear global UI theme config unexpectedly**: Gameplay scenes also attach `scripts/core/root.gd`, so unconditional cleanup in `_exit_tree()` can clear `U_UIThemeBuilder.active_config` while the persistent app root is still alive. This causes subsequent menus/overlays to render fallback/default (gray) styling instead of unified theme tokens.
  - **Fix pattern**: only clear `U_UIThemeBuilder.active_config` when the exiting root is the persistent app root (for example, it has `Managers/M_StateStore`). Keep non-persistent gameplay roots from mutating global theme config.

- **Shared overlay scenes can be mounted in non-overlay contexts**: Some UI scenes (for example `UI_SettingsMenu`) run both as gameplay overlays and as embedded panels in main-menu flows. If dim alpha is applied unconditionally in `BaseOverlay` subclasses, embedded usage can become unintentionally darkened.
  - **Fix pattern**: gate dim alpha by navigation context (`navigation.overlay_stack` top or shell checks). Use normal dim (`0.7`) only when running as an active overlay; use `0.0` when embedded.

- **`BaseOverlay` auto-background + manual full-screen background can double-stack dimming**: `BaseOverlay` auto-creates `OverlayBackground` when `auto_create_background` is enabled. If a scene also keeps a custom full-screen `Background` `ColorRect`, effective dim can be much darker than intended and drift from tokenized alpha targets.
  - **Fix pattern**: prefer setting `background_color` and style `OverlayBackground`; only keep a manual full-screen background when `auto_create_background = false`.

- **HUD is manager-instantiated under `HUDLayer`**: Do not add HUD instances to gameplay scenes or templates. `M_SceneManager` owns HUD instantiation in root, and `UI_HudController` visibility is Redux-driven. Embedding HUD in gameplay scenes reintroduces duplicate instances and lifecycle drift.

- **HUD health fill is palette-driven; do not bake it into themed scene overrides**: `UI_HudController` intentionally updates health fill color at runtime from the active display palette (`success`/`warning`/`danger`) for color-blind accessibility. Reintroducing inline `ProgressBar.fill` overrides or static hardcoded colors can break integration behavior.
  - **Fix pattern**: keep health background/theme chrome in `RS_UIThemeConfig` (`progress_bar_bg`), but leave fill updates to `_update_health_bar_colors(...)` using the active palette service.

- **Protect HUD ownership with style checks**: `tests/unit/style/test_style_enforcement.gd` includes a guard that fails when any `scenes/gameplay/*.tscn` references `ui_hud_overlay.tscn` or defines a `HUD` root node. Keep this test green when authoring or migrating gameplay scenes.

- **Full-screen overlay containers block input by default**: When creating HUD overlays or full-screen UI containers (using `anchors_preset = 15`), the container will block ALL mouse input to UI elements below it, even if the container's children only occupy a small portion of the screen. This happens because Control nodes use `mouse_filter = MOUSE_FILTER_STOP` (value 0) by default, which intercepts and stops mouse events from propagating.

  **Problem**: A MarginContainer covering the entire screen for a HUD overlay will prevent clicks from reaching buttons or UI elements below it, even though the HUD content (health/score labels) only appears in the corner.

  **Solution**: Set `mouse_filter = 2` (MOUSE_FILTER_IGNORE) on full-screen containers that should display information without blocking interaction:
  ```gdscript
  # In .tscn file:
  [node name="MarginContainer" type="MarginContainer" parent="."]
  anchors_preset = 15
  anchor_right = 1.0
  anchor_bottom = 1.0
  mouse_filter = 2  # MOUSE_FILTER_IGNORE - lets clicks pass through
  ```

  **When to use each mouse_filter mode:**
  - `MOUSE_FILTER_STOP` (0 - default): Block mouse events (use for clickable buttons, interactive panels)
  - `MOUSE_FILTER_PASS` (1): Receive mouse events but let them continue to nodes below
  - `MOUSE_FILTER_IGNORE` (2): Completely ignore mouse events (use for non-interactive overlays, info displays)

  **Real example**: `scenes/ui/hud_overlay.tscn` uses a full-screen MarginContainer to provide consistent margins for HUD elements. Without `mouse_filter = 2`, it blocked all clicks to test scene buttons below it, even though the HUD labels only occupied the top-left corner.

---

## Godot Audio Pitfalls

- **3D audio is disabled by default in SubViewports**: If gameplay is rendered in a `SubViewport` (e.g. `scenes/root.tscn` → `GameViewport`), `AudioStreamPlayer3D` can appear to "play" (logs show `playing=true`) but produce **no audible sound** because the SubViewport is not mixing 3D audio.

  **Symptom**:
  - 3D SFX never audible in gameplay scenes
  - Debug/logs show the sound is spawned and `playing=true`
  - Viewport reports `audio_listener_enable_3d=false`

  **Fix**: enable 3D audio on the gameplay viewport:
  ```gdscript
  # In scenes/root.tscn:
  [node name="GameViewport" type="SubViewport" parent="GameViewportContainer"]
  audio_listener_enable_3d = true
  ```

- **3D audio is viewport/world scoped**: `AudioStreamPlayer3D` must exist in the same `Viewport`/`World3D` as the active listener (the viewport's current `Camera3D`). If you parent your SFX pool under `/root` while gameplay runs in `GameViewport`, 3D SFX can be silent even though they are "playing".
