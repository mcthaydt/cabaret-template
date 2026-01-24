# UI Manager Flows & Input Routing

**Date**: 2025-11-24  
**Status**: Draft – Flow & Input Design

This document describes how key UI flows map onto navigation state, the UI registry, and the `ui_*` input actions. It complements `data-model.md` and is meant to guide reducer, selector, and input handler implementation.

---

## 1. Key Flows

### 1.1 Gameplay → Pause → Settings → Back → Gameplay

**Initial State (Gameplay):**

- `shell = "gameplay"`
- `base_scene_id = "exterior"` (or another gameplay scene)
- `overlay_stack = []`
- `get_tree().paused = false`

**Step 1 – Open Pause**

- Player presses `ui_back` (ESC / gamepad Start) in gameplay.
- UI input handler:
  - Context: shell = gameplay, overlay_stack empty.
  - Dispatches `NAV/OPEN_PAUSE`.
- Navigation reducer:
  - Validates `pause_menu` is allowed in shell `gameplay` via `U_UIRegistry`.
  - Appends `"pause_menu"` to `overlay_stack`.
  - Marks pause state for selectors.
- Scene Manager reconciliation:
  - Sees desired overlay_stack = ["pause_menu"].
  - Calls `push_overlay("pause_menu")`.
  - Sets `get_tree().paused = true`.

**Step 2 – From Pause → Open Settings Overlay**

- In pause root panel, player activates “Settings” button (via `ui_confirm` or click).
- Panel:
  - Emits intent or dispatches `NAV/OPEN_OVERLAY("settings_menu_overlay", from="pause")`.
- Navigation reducer:
  - Uses `U_UIRegistry` to verify:
    - `"settings_menu_overlay"` has `kind = OVERLAY`.
    - Allowed in shell `gameplay` with parent `"pause_menu"`.
  - Updates `overlay_stack = ["pause_menu", "settings_menu_overlay"]`.
- Scene Manager reconciliation:
  - Calls `push_overlay("settings_menu")` (Scene ID from registry).

**Step 3 – Back from Settings to Pause**

- Player presses `ui_back` in settings overlay.
- UI input handler:
  - Context: shell = gameplay, overlay_stack top = `"settings_menu_overlay"`, CloseMode = RETURN_TO_PREVIOUS_OVERLAY.
  - Dispatches `NAV/CLOSE_TOP_OVERLAY`.
- Navigation reducer:
  - Pops top overlay from `overlay_stack` (back to ["pause_menu"]).
- Scene Manager reconciliation:
  - Calls `pop_overlay()` to remove settings overlay scene.
  - Pause remains active (`get_tree().paused` stays true).

**Step 4 – Resume Gameplay**

- From pause, player presses “Resume” or `ui_back`.
- UI input handler:
  - Context: shell = gameplay, overlay_stack top = `"pause_menu"`, CloseMode = RESUME_TO_GAMEPLAY.
  - Dispatches `NAV/CLOSE_TOP_OVERLAY`.
- Navigation reducer:
  - Pops overlay stack back to empty.
  - Clears pause state.
- Scene Manager reconciliation:
  - Calls `pop_overlay()` to remove pause overlay.
  - Sets `get_tree().paused = false`.

Result: the entire flow is expressed via navigation actions + state updates; Scene Manager simply applies the desired overlay stack to the tree.

---

### 1.2 Main Menu → Settings Panel → Back → Main Menu

**Initial State (Main Menu):**

- `shell = "main_menu"`
- `base_scene_id = "main_menu"`
- `overlay_stack = []`
- `active_menu_panel = "menu/main"`

**Step 1 – Open Settings Panel**

- Player activates “Settings” in main menu.
- Panel dispatches `NAV/SET_MENU_PANEL("menu/settings")`.
- Navigation reducer:
  - Validates panel exists (via registry).
  - Sets `active_menu_panel = "menu/settings"`.
- Main menu controller:
  - Reads `active_menu_panel` via selectors.
  - Shows Settings panel, hides Main panel.

**Step 2 – Back to Main Panel**

- In Settings panel, player presses `ui_back`.
- Panel:
  - Dispatches `NAV/SET_MENU_PANEL("menu/main")`.
- Reducer updates `active_menu_panel`.
- Controller switches visible panel accordingly.

No scene or overlay transitions occur here; the flow is entirely panel‑based within the main menu shell.

---

### 1.3 Death → Game Over → Retry / Menu

**Step 0 – Death in Gameplay**

- ECS system (`S_VictorySystem` / death system) currently calls `M_SceneManager.transition_to_scene("game_over", "fade", Priority.HIGH)`.
- In the target architecture, there are two possible strategies:
  - **Strategy A (Incremental)**: Keep calling Scene Manager directly and have it dispatch navigation actions internally.
  - **Strategy B (Target)**: Systems dispatch `NAV/OPEN_ENDGAME("game_over")` and let navigation reducers + Scene Manager handle it.

**Assuming Strategy B:**

- System dispatches `NAV/OPEN_ENDGAME("game_over")`.
- Navigation reducer:
  - Sets `shell = "endgame"`.
  - Sets `base_scene_id = "game_over"`.
  - Clears `overlay_stack`.
- Scene Manager reconciliation:
  - Calls `transition_to_scene("game_over", "fade", Priority.HIGH)`.
  - Ensures ActiveSceneContainer contains only the `game_over` scene.

**Game Over Scene Buttons:**

- "Retry" dispatches `NAV/RETRY`.
  - Reducer sets `shell = "gameplay"`, `base_scene_id` to last checkpoint scene, `overlay_stack = []`.
  - Scene Manager transitions to gameplay (restores from last checkpoint).
- “Menu” dispatches `NAV/RETURN_TO_MAIN_MENU`.
  - Reducer sets `shell = "main_menu"`, `base_scene_id = "main_menu"`, `overlay_stack = []`.
  - Scene Manager transitions to `"main_menu"`.

Implementation uses Strategy B: ECS systems dispatch navigation actions.

### 1.4 Endgame `ui_back` Behavior

**Game Over Screen:**
- `ui_back` → Dispatches `NAV/RETRY` (equivalent to clicking Retry button)
- Reducer sets `shell = "gameplay"`, `base_scene_id` to last checkpoint scene
- Scene Manager transitions back to gameplay

**Victory Screen:**
- `ui_back` → Dispatches `NAV/SKIP_TO_CREDITS`
- Reducer sets `base_scene_id = "credits"`
- Scene Manager transitions to credits

**Credits Screen:**
- `ui_back` → Dispatches `NAV/SKIP_TO_MENU`
- Reducer sets `shell = "main_menu"`, `base_scene_id = "main_menu"`
- Scene Manager transitions to main menu

---

## 2. Canonical UI Actions & Input Mapping

### 2.1 Canonical Actions

The UI Manager relies on the following `ui_*` actions defined in `project.godot`. These actions follow Godot's built-in conventions with custom extensions for pause handling:

| Action | Keyboard | Gamepad | Left Stick | Purpose |
|--------|----------|---------|------------|---------|
| `ui_accept` | Enter, Space | A (button 0) | - | Activate focused control |
| `ui_cancel` | ESC | B (button 1) | - | Context-dependent back/cancel |
| `ui_pause` | ESC | Start (button 6) | - | Identical to `ui_cancel` |
| `ui_up` | Up Arrow | D-pad Up | Left Y- | Navigate focus up |
| `ui_down` | Down Arrow | D-pad Down | Left Y+ | Navigate focus down |
| `ui_left` | Left Arrow | D-pad Left | Left X- | Navigate focus left |
| `ui_right` | Right Arrow | D-pad Right | Left X+ | Navigate focus right |

**Key Details:**
- **Deadzone**: All `ui_*` actions use a 0.2 deadzone for stick/trigger inputs
- **Device Independence**: Actions work across keyboard, gamepad, and analog stick inputs
- **Button Indices** (Godot standard):
  - 0 = A (Xbox) / Cross (PS)
  - 1 = B (Xbox) / Circle (PS)
  - 6 = Start (Xbox/PS)
  - 11/12/13/14 = D-pad Up/Down/Left/Right

### 2.2 ESC and Start Mapping Rules

**Critical Design Decision: `ui_pause` and `ui_cancel` are identical**

Both actions map to the same physical inputs:
- Keyboard: ESC
- Gamepad: Start button (button 6) for `ui_pause`, B button (button 1) for `ui_cancel`

**Behavior by Context:**

| Shell | Overlay State | `ui_pause` / `ui_cancel` Behavior |
|-------|---------------|-----------------------------------|
| Gameplay | No overlays | Opens pause menu (`NAV/OPEN_PAUSE`) |
| Gameplay | Pause overlay | Closes pause, resumes gameplay (`NAV/CLOSE_TOP_OVERLAY`) |
| Gameplay | Other overlay | Closes top overlay, CloseMode determines behavior |
| Main Menu | Root panel | No-op (back does nothing) |
| Main Menu | Settings panel | Returns to main panel (`NAV/SET_MENU_PANEL("menu/main")`) |
| Endgame | game_over | Retry from checkpoint (`NAV/RETRY`) |
| Endgame | victory | Skip to credits (`NAV/SKIP_TO_CREDITS`) |
| Endgame | credits | Return to main menu (`NAV/SKIP_TO_MENU`) |

**Why This Design:**
- Consistent "back" semantics across keyboard and gamepad
- ESC and Start feel natural for pause in gameplay context
- Both inputs work identically in all UI contexts
- Simplifies input handler logic (one code path for both)

### 2.3 Focus & Directional Navigation

- Directional navigation (`ui_up/down/left/right`) uses Godot's built-in focus mechanics
- UI Manager does NOT replace or override Godot's focus system
- Base UI classes (`BaseMenuScreen`, `BaseOverlay`) auto-focus first focusable control on `_ready()`
- Tab order and focus neighbors are configured per-scene as usual

---

## 3. UI Input Routing

### 3.1 Responsibilities

The UI input handler is a thin layer whose sole job is to:

- Listen for `ui_*` actions (`ui_accept`, `ui_cancel`, `ui_up/down/left/right`).
- Determine the current context from navigation selectors:
  - Shell (`main_menu`, `gameplay`, `endgame`).
  - Whether overlays are active and their CloseMode.
  - Which panel is active (in main menu, pause, etc.).
- Dispatch appropriate navigation actions, not call Scene Manager directly.

It **must not**:

- Hardcode physical keys or gamepad buttons.
- Maintain its own notion of overlays or panels separate from navigation state.

### 3.2 Context Matrix for `ui_cancel` / `ui_pause`

**Context → Action mapping:**

- **Gameplay, no overlays:**
  - `ui_cancel` / `ui_pause` → `NAV/OPEN_PAUSE`.

- **Gameplay, top overlay is `pause_menu`:**
  - If pause root panel active: `ui_cancel` / `ui_pause` → `NAV/CLOSE_TOP_OVERLAY` (RESUME_TO_GAMEPLAY).
  - If pause settings panel active: map to panel nav (`NAV/SET_PAUSE_PANEL("pause/root")`).

- **Gameplay, top overlay is a "return" overlay (CloseMode = RETURN_TO_PREVIOUS_OVERLAY):**
  - `ui_cancel` / `ui_pause` → `NAV/CLOSE_TOP_OVERLAY` (return to previous overlay, usually pause).

- **Main menu (no overlays):**
  - If `active_menu_panel != "menu/main"`: `ui_cancel` / `ui_pause` → `NAV/SET_MENU_PANEL("menu/main")`.
  - If at root panel (`menu/main`): **No-op** (back does nothing).

- **Endgame screens:**
  - `game_over`: `ui_cancel` / `ui_pause` → `NAV/RETRY`
  - `victory`: `ui_cancel` / `ui_pause` → `NAV/SKIP_TO_CREDITS`
  - `credits`: `ui_cancel` / `ui_pause` → `NAV/SKIP_TO_MENU`

**Implementation Note:**
The input handler treats `ui_cancel` and `ui_pause` identically, using a single code path for both actions. This matrix is encoded as conditional branches keyed by shell + top overlay CloseMode + active panel.

---

## 4. Implementation Notes & Open Questions

- **ECS integration path (Strategy A vs B)**  
  Decide whether ECS systems continue to call Scene Manager directly or dispatch nav actions. The architecture prefers Strategy B, but a transitional Strategy A can be supported if Scene Manager updates navigation state when called imperatively.

- **Panel vs Overlay boundaries**  
  For some current overlays (e.g., settings), there is a choice:
  - Keep as overlay for pause context but also host as panel in main menu.
  - Or unify usage through a single panel and let shells decide how to host it.

- **Back button semantics in endgame / credits**  
  UX decisions for `ui_back` in victory/game_over/credits must be written down and reflected in registry CloseMode and input matrix.

These questions should be resolved in the UI Manager continuation prompt and tasks notes before implementation progresses into M4–M6.

---

## 5. Additional Flows

### 5.1 Virtual Button Pause Flow (Mobile)

The virtual pause button on mobile controls dispatches navigation actions, not direct Scene Manager calls:

**Pause Toggle:**
```gdscript
# In virtual_button.gd
func _on_pause_button_pressed():
    var state := store.get_state()
    var is_paused := U_NavigationSelectors.is_paused(state)

    if is_paused:
        store.dispatch(U_NavigationActions.close_pause())
    else:
        store.dispatch(U_NavigationActions.open_pause())
```

This ensures mobile pause behavior is identical to keyboard ESC and gamepad Start.

### 5.2 Credits Auto-Scroll Timeout Flow

Credits screen has dual exit paths that both dispatch navigation actions:

**Manual Skip (ui_back or Skip button):**
```gdscript
store.dispatch(U_NavigationActions.skip_to_menu())
```

**Auto-scroll Timeout:**
```gdscript
func _on_scroll_complete():
    store.dispatch(U_NavigationActions.skip_to_menu())
```

Both paths result in identical state changes and Scene Manager behavior.

### 5.3 Main Menu Panel Switching Flow

Main menu uses embedded panels instead of scene transitions:

**Initial State:**
- `shell = "main_menu"`
- `active_menu_panel = "menu/main"`

**Open Settings Panel:**
```gdscript
# Settings button pressed
store.dispatch(U_NavigationActions.set_menu_panel("menu/settings"))
```

**Controller Response:**
```gdscript
func _on_slice_updated(slice_name: StringName) -> void:
    if slice_name == "navigation":
        var state := _store.get_state()
        var panel := U_NavigationSelectors.get_active_menu_panel(state)
        _show_panel(panel)  # Shows/hides panel containers
```

**Back to Main Panel:**
- `ui_back` in settings panel → `store.dispatch(U_NavigationActions.set_menu_panel("menu/main"))`
- `ui_back` at main panel → no-op

