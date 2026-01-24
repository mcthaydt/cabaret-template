# UI Manager Data Model

**Date**: 2025-11-24  
**Status**: Draft – Architecture Definition

## Purpose

This document defines the data model for UI / Navigation in the project. It describes:

- The conceptual navigation model (shells, base scenes, overlays, panels).
- How this model maps onto Redux slices (`scene`, `menu`, and optional `navigation`).
- The schema for the UI screen/overlay/panel registry.
- Concrete semantics for existing UI screens and overlays.

It does **not** mandate a particular slice layout in code (separate `navigation` slice vs extended `scene`/`menu`), but it defines the **logical fields and invariants** that the implementation must satisfy.

---

## 1. Conceptual Navigation Model

### 1.1 Definitions

- **Shell**  
  High‑level UI context, independent of specific scenes:
  - `shell = "main_menu"` – Main menu UI.
  - `shell = "gameplay"` – Active gameplay (exterior/interior scenes).
  - `shell = "endgame"` – Game over, victory, credits flows.
  - `shell = "debug"` – Debug overlays / state inspectors (if applicable).

- **Base Scene**  
  The currently loaded primary scene under `ActiveSceneContainer`, identified by `scene.current_scene_id`.

- **Overlay**  
  A UI screen instantiated as a child of `UIOverlayStack` (CanvasLayer). Overlays map 1:1 to entries in the UI registry with `kind = OVERLAY`.

- **Panel**  
  A reusable UI component embedded inside a shell screen (e.g., Settings panel in main menu, or Character Select panel). Panels are not added to `UIOverlayStack` directly; they are internal to a base scene or overlay.

### 1.2 Logical Navigation State

Conceptually, navigation/UI state answers three questions:

1. **Which shell are we in?**
2. **Which base scene is active (if any)?**
3. **Which overlays and panels are active within that shell?**

The following logical fields capture this:

```gdscript
{
    "shell": StringName,                 # "main_menu", "gameplay", "endgame", "debug"

    # Base scene (maps to Scene Manager and scene slice)
    "base_scene_id": StringName,         # e.g., "main_menu", "exterior", "interior_house", "victory"

    # Overlay stack (logical IDs, top = last)
    "overlay_stack": Array[StringName],  # e.g., ["pause_menu"], ["pause_menu", "settings_menu"]

    # Active panel within current shell (uses {context}/{panel} format)
    "active_menu_panel": StringName,     # e.g., "menu/main", "menu/settings", "pause/root"

    # Optional: last non-gameplay shell for "go back" behaviors
    "last_shell": StringName             # used for future flows if needed
}
```

Default initial values (navigation slice is **transient** and re-initializes on load):
- `shell = "main_menu"`
- `base_scene_id = "main_menu"`
- `overlay_stack = []`
- `active_menu_panel = "menu/main"`

**Note on Panel IDs**: All panel IDs use the `{context}/{panel}` format:
- Main menu panels: `"menu/main"`, `"menu/settings"`, `"menu/character_select"`
- Pause panels: `"pause/root"`, `"pause/settings"`

This format makes the context explicit and prevents ID collisions between different shells.

### 1.3 Mapping to Redux Slices

Implementation MUST provide these logical fields but MAY choose one of two patterns in code:

- **Option A – Dedicated `navigation` slice**  
  - Add a `navigation` slice (`U_NavigationReducer`, `RS_NavigationInitialState`) holding the fields above.
  - `scene` slice continues to own `current_scene_id`, `scene_stack`, `is_transitioning`.  
  - Reducers keep `navigation.base_scene_id` in sync with `scene.current_scene_id`, and `navigation.overlay_stack` in sync with `scene.scene_stack`.

- **Option B – Extended `scene` + `menu` slices**  
  - Extend `scene` slice to hold `shell`, `overlay_stack` (and possibly `last_shell`).
  - Extend `menu` slice to hold `active_menu_panel` (and pause panel info if desired).
  - Navigation selectors (`U_NavigationSelectors`) compute the logical model from these slices.

**Decision: Option A – Dedicated `navigation` slice**

The implementation will use a dedicated `navigation` slice for clarity and separation of concerns:
- `U_NavigationReducer` handles all navigation logic
- `RS_NavigationInitialState` defines default state
- Navigation slice is **fully transient** (not saved/loaded)
- Selectors in `U_NavigationSelectors` are the single source of truth for UI location

**Relationship with Existing `menu` Slice**:

The existing `U_MenuReducer` has actions:
- `ACTION_NAVIGATE_TO_SCREEN` - Currently unused by actual menus
- `ACTION_SELECT_CHARACTER` - Character selection logic
- `ACTION_SELECT_DIFFICULTY` - Difficulty selection logic
- `ACTION_LOAD_SAVE_FILES` - Save file loading logic

These actions remain in `menu` slice and are NOT deprecated. The `navigation` slice handles UI flow/routing (which screen/overlay/panel is visible), while `menu` slice handles menu-specific data (selected character, difficulty, save files). The two slices complement each other:
- `navigation.active_menu_panel` = where we are (UI location)
- `menu.selected_character` = what we've selected (data)

**Invariants:**

1. `navigation.base_scene_id` == `scene.current_scene_id` for all stable states.
2. `navigation.overlay_stack` is a logical mirror of `scene.scene_stack`:
   - Same length and ordering.
   - Only `StringName` values representing overlay IDs.
3. `navigation.shell` must be derivable from `U_SceneRegistry.get_scene_type(base_scene_id)` plus overlay context:
   - `SceneType.MENU` → `shell = "main_menu"`.
   - `SceneType.GAMEPLAY` → `shell = "gameplay"`.
   - `SceneType.END_GAME` → `shell = "endgame"`.
4. UI selectors (`U_NavigationSelectors`) must be the **only** place other systems query “are we paused?”, “which overlay is on top?”, “which menu panel is active?”.
5. `M_SceneManager` reads navigation + scene slices and enforces them in the scene tree; it does not mutate navigation state directly.

---

## 2. UI Screen / Overlay / Panel Registry

### 2.1 Resource Schema: `RS_UIScreenDefinition`

Each UI screen/overlay/panel is described by a resource. Logical fields:

```gdscript
class_name RS_UIScreenDefinition
extends Resource

@export var screen_id: StringName          # Logical identifier ("pause_menu", "settings_menu", "input_rebinding")
@export var kind: int                      # Enum UIScreenKind: BASE_SCENE, OVERLAY, PANEL

# Scene / panel binding
@export var scene_id: StringName           # Scene ID from U_SceneRegistry for scene-based screens/overlays
@export var panel_id: StringName           # Panel ID for panel-only definitions (embedded in scenes)

# Context & navigation rules
@export var allowed_shells: Array[StringName]  # e.g., ["main_menu"], ["gameplay"]
@export var allowed_parents: Array[StringName] # Overlay IDs that may host this screen (for OVERLAY / PANEL)

@export var close_mode: int                # Enum CloseMode: RETURN_TO_PREVIOUS_OVERLAY, RESUME_TO_GAMEPLAY, RESUME_TO_MENU
```

**Enums (conceptual):**

- `UIScreenKind`:
  - `BASE_SCENE` – Full-screen scenes (main_menu, game_over, victory, credits).
  - `OVERLAY` – Scenes added under `UIOverlayStack` (pause_menu, settings_menu, overlays).
  - `PANEL` – Panels embedded inside screens/overlays (SettingsPanel, CharacterSelectPanel).

- `CloseMode`:
  - `RETURN_TO_PREVIOUS_OVERLAY` – Close and return to prior overlay (e.g., Pause → Settings → back to Pause).
  - `RESUME_TO_GAMEPLAY` – Close overlays and resume gameplay (e.g., Rebinding overlay).
  - `RESUME_TO_MENU` – Close overlays and return to main menu (for future flows).

### 2.2 UI Registry: `U_UIRegistry`

`U_UIRegistry` is a static helper that:

- Loads all `RS_UIScreenDefinition` resources from `res://resources/ui_screens/` (and optionally test directories).
- Provides lookup by `screen_id`, `scene_id`, and context (shell + parent overlay).
- Validates definitions on startup (similar to `U_SceneRegistry.validate_door_pairings()`).

Core responsibilities:

- `get_screen(screen_id: StringName) -> Dictionary`  
  Returns a deep copy of the registry entry or `{}` if missing.

- `get_overlays_for_shell(shell: StringName) -> Array[Dictionary]`  
  All overlays allowed in a given shell.

- `get_valid_targets(shell: StringName, parent_overlay: StringName) -> Array[StringName]`  
  Used by reducers to validate navigation targets before updating state.

Validation rules (non-exhaustive):
- Every `screen_id` must be unique.
- `scene_id` references must exist in `U_SceneRegistry` for `BASE_SCENE` and `OVERLAY` kinds.
- `allowed_shells` may not be empty.
- `close_mode` must map to a known CloseMode enum value.

---

## 3. Overlay Semantics for Existing UI

This table documents how existing screens/overlays should behave in the new architecture. It is the **single source of truth** for close behavior and allowed contexts.

### 3.1 Base UI Scenes

| screen_id    | kind       | scene_id        | SceneType        | shell       | Notes                                     |
|--------------|-----------|-----------------|------------------|------------|-------------------------------------------|
| `main_menu`  | BASE_SCENE| `main_menu`     | MENU             | main_menu  | Entry point, hosts panels (main/settings) |
| `game_over`  | BASE_SCENE| `game_over`     | END_GAME         | endgame    | Shown after death                         |
| `victory`    | BASE_SCENE| `victory`       | END_GAME         | endgame    | Shown after completing required area(s)   |
| `credits`    | BASE_SCENE| `credits`       | END_GAME         | endgame    | Auto-scroll, returns to main_menu         |

### 3.2 Overlays

| screen_id                 | kind    | scene_id                   | allowed_shells | allowed_parents        | close_mode                     | Notes                                           |
|---------------------------|---------|----------------------------|----------------|------------------------|--------------------------------|------------------------------------------------|
| `pause_menu`              | OVERLAY | `pause_menu`               | ["gameplay"]   | []                              | RESUME_TO_GAMEPLAY             | Top-level pause overlay                         |
| `settings_menu_overlay`   | OVERLAY | `settings_menu`            | ["gameplay"]   | ["pause_menu"]                  | RETURN_TO_PREVIOUS_OVERLAY     | Settings overlay opened from pause              |
| `input_profile_selector`  | OVERLAY | `input_profile_selector`   | ["gameplay"]   | ["pause_menu", "settings_menu_overlay"] | RETURN_TO_PREVIOUS_OVERLAY     | Returns to settings or pause overlay on close   |
| `gamepad_settings`        | OVERLAY | `gamepad_settings`         | ["gameplay"]   | ["pause_menu", "settings_menu_overlay"] | RETURN_TO_PREVIOUS_OVERLAY     | Returns to settings or pause overlay on close   |
| `touchscreen_settings`    | OVERLAY | `touchscreen_settings`     | ["gameplay"]   | ["pause_menu", "settings_menu_overlay"] | RETURN_TO_PREVIOUS_OVERLAY     | Returns to settings or pause overlay on close   |
| `input_rebinding`         | OVERLAY | `input_rebinding`          | ["gameplay"]   | ["pause_menu", "settings_menu_overlay"] | RETURN_TO_PREVIOUS_OVERLAY     | Returns to settings or pause overlay on close   |
| `edit_touch_controls`     | OVERLAY | `edit_touch_controls`      | ["gameplay"]   | ["pause_menu", "touchscreen_settings"]  | RETURN_TO_PREVIOUS_OVERLAY     | Returns to touchscreen or pause overlay on close|

**Close Mode Summary**: All sub-settings overlays (profiles, gamepad, touchscreen, rebinding, edit_touch_controls) now use `RETURN_TO_PREVIOUS_OVERLAY`, so closing them returns to their parent overlay (settings or pause) instead of resuming gameplay directly.

> ⚠️ **BEHAVIORAL CHANGE**: Earlier iterations resumed gameplay directly when closing sub-settings overlays. The current implementation routes all sub-settings overlays back to their parent (`settings_menu_overlay`, `touchscreen_settings`, or `pause_menu`), keeping the game paused until the user explicitly exits the pause/settings stack.

### 3.3 Panels (Conceptual)

Panels do not map to specific scenes; they are identified by panel IDs and embedded in base scenes or overlays.

Examples:

| panel_id           | Context        | Notes                                        |
|--------------------|----------------|----------------------------------------------|
| `menu/main`        | main_menu      | Default main menu panel (Play/Settings/Quit) |
| `menu/settings`    | main_menu      | Settings panel embedded in main menu         |
| `pause/root`       | pause_menu     | Default pause panel                          |
| `pause/settings`   | pause_menu     | Settings panel shown inside pause            |

Panel definitions live alongside screen definitions but do not have `scene_id`; instead they reference `screen_id` + `panel_id`.

### 3.4 Reusable Panels

In the current implementation, the only cross-context “settings” UI is the **Settings Hub** used for input configuration. It is shared between shells in a simple way:

| Panel / Screen   | Panel ID        | Contexts                     | Consumes Selectors                                  | Dispatches Actions                                         | Notes                                                                 |
|------------------|-----------------|------------------------------|-----------------------------------------------------|------------------------------------------------------------|-----------------------------------------------------------------------|
| Settings Hub     | `menu/settings` | main_menu (panel) / gameplay (overlay via `settings_menu_overlay`) | `U_InputSelectors` for device state, `U_NavigationSelectors.get_shell()` for context | `U_NavigationActions.set_menu_panel("menu/main")`, `U_NavigationActions.close_top_overlay()`, `U_NavigationActions.open_overlay(...)` | Single hub UI used both as embedded panel in main menu and as an overlay from pause; fans out to dedicated overlays/scenes for each settings area. |

The more ambitious tabbed `SettingsPanel` (with audio/graphics/accessibility categories) is intentionally deferred. New settings areas should be added as additional hub entries plus dedicated overlays/scenes rather than as new tabs until a future phase revisits that design.

#### Panel Architecture (Phase 4 target – adjusted)

- **BasePanel script** (new in Phase 4) provides:
  - Store discovery (`await get_tree().process_frame`, `U_StateUtils.get_store(self)`).
  - `get_navigation_state(): Dictionary` helper returning defensive copy.
  - `focus_first_control()` hook invoked after `_ready()` plus on `navigation.slice_updated` to ensure UI responsiveness when panels hot-swap.
  - `_on_back_pressed()` virtual for ESC/Start/back-button flows (BasePanel will emit a `panel_back_requested` signal that the parent screen/overlay must connect to).
- **Parent screen/overlay contract**:
  1. Look up active panel ID via `U_NavigationSelectors.get_active_menu_panel(state)`.
  2. Instance/attach requested panel scene under a `PanelHost` placeholder.
  3. Connect the panel's `panel_back_requested` to context-specific handler (e.g., `U_NavigationActions.set_menu_panel("menu/main")` or `U_NavigationActions.close_top_overlay()`).
  4. Destroy/queue_free old panel when ID changes to avoid stacking unused nodes.
- **State ownership**: Panels never mutate Scene Manager directly. They dispatch Redux actions (navigation, settings, gameplay, etc.) and rely on reconciliation/overlay logic to react.
- **Focus contract**: Parent overlay/screen ensures `process_mode = PROCESS_MODE_ALWAYS` so BasePanel focus helpers still run while the tree is paused.
- **Data flow reminder**:
  ```
  UI Input (ui_*) ──> UI Input Handler ──> Navigation/Settings actions ──> Redux Store ──> Navigation slice updates
                   └───────────────────────────────────────────────────────> Scene Manager reconciliation ──> Scene tree
  ```

This architecture keeps panels declarative and test-friendly while letting multiple shells share the same scene resource without branching logic inside Scene Manager.

### 3.5 Overlay Presentation

**Animation**: Quick fade (0.1-0.2 seconds) for overlay appear/disappear
- Consistent across all overlays
- No slide or complex animations

**Focus**: First focusable control in tab order
- No per-screen `default_focus_path` configuration needed
- Godot's built-in focus system handles directional navigation

---

## 4. Canonical UI Input Actions & Navigation Actions

### 4.1 Canonical `ui_*` Actions

For UI and menu flows, the following actions are considered canonical:

- `ui_accept` – Activate focused control (keyboard Enter / gamepad A / Cross).
- `ui_cancel` – Navigate backwards (ESC / gamepad B / Circle).
- `ui_up`, `ui_down`, `ui_left`, `ui_right` – Navigate focus between controls.
- `ui_focus_next`, `ui_focus_prev` – Optional additional focus navigation.

**Rules:**

- UI controllers and panels **must only** depend on these `ui_*` actions for navigation and confirmation.
- Input Manager is responsible for binding these actions appropriately per device; UI code must not hardcode physical keys or buttons.

### 4.2 Navigation Actions (Logical)

Navigation reducers will handle actions such as:

- `NAV/OPEN_PAUSE`
- `NAV/CLOSE_PAUSE`
- `NAV/OPEN_OVERLAY(screen_id, from_context)`
- `NAV/CLOSE_TOP_OVERLAY`
- `NAV/SET_MENU_PANEL(panel_id)`
- `NAV/START_NEW_RUN(payload)`
- `NAV/RETURN_TO_MAIN_MENU`

The thin UI input handler maps `ui_*` events to these actions based on context:

- In gameplay, `ui_back` → `NAV/OPEN_PAUSE`.
- In pause root panel, `ui_back` → `NAV/CLOSE_PAUSE`.
- In return overlays, `ui_back` → `NAV/CLOSE_TOP_OVERLAY` (CloseMode = RETURN_TO_PREVIOUS_OVERLAY).
- In main menu panels, `ui_back` → panel transitions (`NAV/SET_MENU_PANEL("main")`) rather than scene transitions.

Exact action names and payload shapes will be finalized in the navigation reducer implementation, but this section defines the **logical responsibilities**.

---

## 5. Invariants & Safety Checks

Implementations must ensure the following invariants:

1. **Single Source of Truth for UI Location**  
   - Navigation selectors are the only API other systems use to answer questions like “are we paused?”, “which overlay is on top?”, “which menu panel is active?”.

2. **Scene Manager as Executor, Not Decider**  
   - `M_SceneManager` reads navigation and scene slices (and UI registry) to determine which scenes/overlays should be active. It does not invent new overlays or scene transitions outside of actions + state.

3. **Registry & State Consistency**  
   - All `screen_id` and `panel_id` values in navigation state must exist in `U_UIRegistry`.
   - All `scene_id` values referenced by `RS_UIScreenDefinition` must exist in `U_SceneRegistry`.

4. **Pause Semantics**
   - `U_NavigationSelectors.is_paused()` is THE authoritative source of truth for pause state.
   - This selector returns `true` when `overlay_stack` is non-empty in gameplay shell.
   - All other systems must derive pause state from this selector:
     - `get_tree().paused` (SceneTree flag) is SET BY the reconciliation logic based on this selector.
     - `scene.scene_stack` mirrors `navigation.overlay_stack` and should not be queried directly for pause.
     - Any `gameplay.paused` field must be derived from or agree with this selector.
   - **Migration note**: Existing code that checks `scene.scene_stack.size() > 0` should migrate to `U_NavigationSelectors.is_paused(state)`.

5. **Backwards Compatibility**
   - During migration, existing APIs (`M_SceneManager.transition_to_scene`, `push_overlay`, etc.) may continue to be used directly, but they must be implemented in terms of navigation actions and state updates, not parallel logic.

---

## 6. Signal Flow & Integration

### 6.1 Navigation State → Scene Manager Reconciliation

The signal flow for navigation state changes:

```
User Input (ui_cancel)
    ↓
UI Input Handler
    ↓
store.dispatch(U_NavigationActions.close_top_overlay())
    ↓
M_StateStore processes action via U_NavigationReducer
    ↓
M_StateStore emits slice_updated("navigation")
    ↓
M_SceneManager._on_navigation_slice_updated()
    ↓
Reconciliation: compare navigation.overlay_stack with scene.scene_stack
    ↓
Apply changes: push_overlay() / pop_overlay() / transition_to_scene()
```

### 6.2 root.tscn Integration

The `ui_input_handler.gd` should be placed in `root.tscn` with the following requirements:

**Node Setup**:
- Add as child of root (sibling to M_SceneManager)
- Name: `UIInputHandler`
- ProcessMode: `PROCESS_MODE_ALWAYS` (must process during pause)

**Script Configuration**:
```gdscript
# ui_input_handler.gd
extends Node

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
    # Only handle ui_* actions, not gameplay actions
    if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause"):
        _handle_ui_cancel()
        get_viewport().set_input_as_handled()
```

**Order Dependencies**:
- Must initialize after M_StateStore (to dispatch actions)
- Must initialize after M_SceneManager (Scene Manager subscribes to navigation slice)
- No dependencies on specific scenes (operates at root level)

### 6.3 M_SceneManager Subscription

Scene Manager subscribes to navigation slice changes in `_ready()`:

```gdscript
func _ready() -> void:
    # ... existing setup ...
    var store := U_StateUtils.get_store(self)
    if store:
        store.slice_updated.connect(_on_slice_updated)

func _on_slice_updated(slice_name: StringName) -> void:
    if slice_name == "navigation":
        _reconcile_navigation_state()
```

---

## 8. Navigation → Scene Tree Reconciliation (Phase 3)

Phase 3 introduces a **reactive** Scene Manager that treats the navigation slice as the declarative source of truth. The reconciliation loop runs whenever the store emits `slice_updated` for `"navigation"` and keeps the actual scene tree synced with the desired state.

### 8.1 Responsibilities

1. **Base Scene Alignment**
   - Compare `navigation.base_scene_id` with `scene.current_scene_id`.
   - If they differ (and the desired ID is registered), request a transition via `transition_to_scene`.
   - Use the scene's default transition from `U_SceneRegistry` (typically `fade` for menus/endgame, `instant` for overlays).
   - De-dupe requests by tracking the currently loading scene and any scene IDs already in the transition queue.

2. **Overlay Stack Alignment**
   - Compare `navigation.overlay_stack` with the actual overlays installed under `UIOverlayStack`.
   - Pop any overlays that are not present (or out of order) in the desired stack.
   - Push missing overlays in stack order, using the existing `push_overlay()` helper (which dispatches `scene/push_overlay` for state parity).
   - Overlay transitions use a short (0.15 s) fade animation; the CanvasLayer already supports this, so reconciliation only needs to ensure overlays arrive/depart.

3. **CloseMode Semantics**
   - The reducer enforces CloseMode by mutating `overlay_stack` (e.g., RESUME_TO_GAMEPLAY clears the stack, RETURN_TO_PREVIOUS_OVERLAY pops one element). Reconciliation simply makes the tree match the desired stack; the semantic behavior remains centralized in navigation state.

### 8.2 Pseudocode

```gdscript
func _on_slice_updated(slice_name: StringName, slice_state: Dictionary) -> void:
    if slice_name != "navigation":
        return
    _reconcile_navigation_state(slice_state)

func _reconcile_navigation_state(nav: Dictionary) -> void:
    var desired_scene := nav.get("base_scene_id", StringName(""))
    _reconcile_base_scene(desired_scene)

    var desired_stack := _coerce_to_string_name_array(nav.get("overlay_stack", []))
    var current_stack := _get_overlay_scene_ids_from_ui()
    _reconcile_overlay_stack(desired_stack, current_stack)
```

`_reconcile_base_scene()`:
1. Return early if desired ID is empty or already active.
2. If a transition for that scene ID is already in-flight or queued, do nothing.
3. Otherwise call `transition_to_scene(desired_scene, U_SceneRegistry.get_default_transition(desired_scene), Priority.HIGH)` and record the pending ID so repeated signals do not requeue duplicates.

`_reconcile_overlay_stack()`:
1. Trim the current stack to match the desired prefix (pop until order matches).
2. If current stack is longer than desired, continue popping until sizes match.
3. Push remaining overlays (from current size → desired size), verifying each ID exists in the UI registry before instancing.

### 8.3 Edge Cases & Guards

- **Scene Manager startup**: Run reconciliation once after `_ready()` so the initial navigation state (default main menu) is enforced even when initial scene load is skipped for tests.
- **Transition spam**: Pending navigation transitions are tracked; reconciliation ignores requests targeting the same scene while `_is_processing_transition` is true or the queue already contains the requested ID.
- **Overlay safety**: Stack comparisons are limited to a small maximum (current overlays < 8) to prevent runaway loops. All `push_overlay` / `pop_overlay` calls continue to dispatch `scene/*` actions, keeping the legacy scene slice consistent for existing HUD consumers.

This algorithm allows Phase 4+ work to focus on dispatching `U_NavigationActions` from UI/input layers; Scene Manager simply reacts to navigation state and no longer needs bespoke overlay wiring for each screen.

---

## 7. Save/Load Behavior

### Navigation State Persistence

The `navigation` slice is **fully transient** (not persisted to save files):
- `shell`, `overlay_stack`, `active_menu_panel` reset on load
- Only `scene.current_scene_id` persists for gameplay position

### Load State Restoration

When `M_StateStore.load_state()` is called:
1. Gameplay state (health, checkpoints, completed areas) is restored
2. Navigation state initializes to default: `shell = "main_menu"`, `base_scene_id = "main_menu"`
3. Player sees main menu and clicks "Play" / "Continue" to enter gameplay
4. Scene Manager transitions to saved `current_scene_id` with spawn at `last_checkpoint`

This ensures a clean entry point after loading, avoiding edge cases where overlays or panels might be in inconsistent state.

---

## 7. Return Stack Standardization

All overlays use the return stack pattern for consistent back navigation:

### Pattern
```gdscript
# Opening overlay from pause
store.dispatch(U_NavigationActions.open_overlay("settings_menu_overlay"))

# Closing overlay - CloseMode determines behavior
store.dispatch(U_NavigationActions.close_top_overlay())
# If RETURN_TO_PREVIOUS_OVERLAY: pops to previous overlay
# If RESUME_TO_GAMEPLAY: clears all overlays, resumes game
```

### Close Mode Reference

| Overlay | CloseMode | Result |
|---------|-----------|--------|
| pause_menu | RESUME_TO_GAMEPLAY | Game resumes |
| settings_menu_overlay | RETURN_TO_PREVIOUS_OVERLAY | Back to pause |
| gamepad_settings | RESUME_TO_GAMEPLAY | Game resumes |
| touchscreen_settings | RESUME_TO_GAMEPLAY | Game resumes |
| input_rebinding | RESUME_TO_GAMEPLAY | Game resumes |
| input_profile_selector | RESUME_TO_GAMEPLAY | Game resumes |
| edit_touch_controls | RESUME_TO_GAMEPLAY | Game resumes |
