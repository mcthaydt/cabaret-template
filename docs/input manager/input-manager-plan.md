# Implementation Plan: Input Manager System

**Branch**: `input-manager` | **Date**: 2025-11-06 | **Spec**: [input-manager-prd.md](./input-manager-prd.md)

**Input**: Feature specification from `/docs/input_manager/input-manager-prd.md`

## Summary

The Input Manager system provides comprehensive multi-device input support for the game, enabling keyboard/mouse, gamepad, and touchscreen inputs with rebinding, profiles, and accessibility features. The system integrates with the existing ECS architecture and Redux-based M_StateStore while maintaining the project's no-autoload pattern. Key features include:

- **Multi-device support**: Keyboard/mouse, gamepad (analog + digital), touchscreen (virtual controls)
- **Input profiles**: Switchable control schemes (default, alternate, accessibility, gamepad)
- **Rebinding system**: Player-customizable key mappings with conflict detection and validation
- **Device auto-detection**: Seamless switching between input devices with updated button prompts
- **Accessibility features**: Larger buffer windows, toggle modes, configurable deadzones
- **State persistence**: Input settings saved across sessions via JSON serialization
- **Performance targets**: < 16ms input latency, < 200ms profile switching, 90%+ code coverage

**Technical approach**:
- M_InputProfileManager and M_InputDeviceManager (new coordinators in main.tscn)
- Input state managed in Redux store (gameplay slice transient, settings slice persistent)
- Components (C_InputComponent, C_GamepadComponent) extended for multi-device support
- Systems (S_InputSystem, S_TouchscreenSystem) handle device-specific input capture
- U_InputRebindUtils and U_ButtonPromptRegistry provide rebinding and prompt functionality
- Virtual controls (VirtualJoystick, VirtualButton) for mobile touchscreen support

---

## Technical Context

**Language/Version**: GDScript (Godot 4.5)

**Primary Dependencies**:
- Godot 4.5 engine (Input singleton, InputMap API)
- Existing ECS framework (M_ECSManager, ECSComponent, ECSSystem, U_ECSUtils)
- M_StateStore (Redux-style state management)
- M_SceneManager (transition blocking)
- M_CursorManager (mouse capture mode)
- GUT (Godot Unit Testing framework)

**Storage**:
- Input settings: `user://input_settings.json` (JSON-based persistence)
- Input profiles: `resources/input_profiles/*.tres` (Godot Resource files)
- Button prompts: `resources/button_prompts/{keyboard,gamepad}/*.png` (texture assets)

**Testing**: GUT framework for unit/integration tests, manual in-game validation

**Target Platform**: Godot 4.5 runtime (Windows/macOS/Linux/Mobile/Console)

**Project Type**: Single Godot game project with scene-based architecture

**Performance Goals**:
- Input latency: < 16ms (one frame @ 60 FPS) from hardware event to component update
- Profile switching: < 200ms including full InputMap update
- Custom bindings save/load: < 100ms on all platforms
- Mobile virtual controls: 60 FPS on mid-range devices (iPhone 12, Galaxy S21, Pixel 5)
- Device detection: Update active_device within one frame
- Button prompt updates: Complete within one frame of device change
- Gamepad vibration latency: < 50ms from trigger to haptic feedback

**Constraints**:
- **No autoloads**: Scene-tree-based architecture, discovery via groups and parent traversal
- **ECS integration**: Follow existing component/system patterns (C_*, S_* prefixes, auto-registration)
- **Redux patterns**: All state updates via action creators and reducers
- **StateHandoff compatible**: Input settings persist across scene transitions
- **Process timing**: ALL input types (keyboard, mouse, gamepad, touch) processed in _physics_process for consistent 60Hz timing

**Scale/Scope**:
- 8 phases (Phase 0-7): Research → KB/Mouse → Profiles → Gamepad → Device Detection → Rebinding → Touchscreen → Polish
- 3 priority levels (P1: Core multi-device, P2: Rebinding + Accessibility, P3: Polish + Performance)
- 7 user stories with acceptance scenarios
- 136 functional requirements (FR-001 through FR-136)
- 22 success criteria (SC-001 through SC-022)
- 13 edge cases to handle
- ~45-55 new files (including assets), 2 enhanced existing files

---

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 implementation.*

**Architectural Constraints Check**:

✅ **No Autoloads**: M_InputProfileManager and M_InputDeviceManager will be in-scene nodes in main.tscn, discoverable via groups ("input_profile_manager", "input_device_manager")
✅ **ECS Integration**: All input components extend ECSComponent, all systems extend ECSSystem, follow auto-registration pattern
✅ **State Management**: Integrates with existing M_StateStore (Redux) by adding input state to gameplay and settings slices
✅ **Scene Tree Based**: All managers live in scenes, no singleton configuration required
✅ **StateHandoff Compatible**: Leverages existing StateHandoff utility for settings preservation across scene transitions

**Integration Points Validated**:

✅ **M_StateStore**: Exists, will add input actions/reducers/selectors
✅ **M_SceneManager**: Exists, Input Manager will check `is_transitioning` to block input during transitions
✅ **M_CursorManager**: Exists, Input Manager will check cursor capture mode for mouse delta processing
✅ **M_ECSManager**: Exists, input components/systems follow existing patterns
✅ **GUT Testing**: Framework already in use, tests can follow existing patterns (autofree, typed asserts)

**Risk Assessment**:

✅ **Well-Scoped**: PRD comprehensive with 136 FRs, 22 SCs, all architectural questions resolved
✅ **Proven Patterns**: Reuses existing ECS patterns, Redux patterns, manager discovery patterns
⚠️ **Moderate Complexity**: Coordinates multiple input devices, profile system, rebinding validation, state persistence
⚠️ **Cross-Platform**: Requires testing on desktop (keyboard/mouse/gamepad) AND mobile (touchscreen) - physical device now available (emulation only as fallback)
⚠️ **Performance Sensitive**: Input latency critical for game feel - must validate < 16ms target on all devices

**Decision**: ✅ **APPROVED TO PROCEED**
- Architecture aligns with project constraints (no autoloads, ECS integration, Redux patterns)
- Integration points well-defined and validated
- Risk mitigated by phased approach (P1 core → P2 rebinding → P3 polish)
- Comprehensive PRD provides clear implementation path with 136 functional requirements

---

## Project Structure

### Documentation (this feature)

```text
docs/input_manager/
├── input-manager-plan.md       # This file (implementation plan)
├── input-manager-prd.md        # Feature specification (complete, 136 FRs)
├── research.md                 # Phase 0 output (prototyping findings, latency benchmarks)
└── input-manager-tasks.md      # Phase-by-phase task tracking checklist
```

### Source Code (repository root)

```text
# Root Scene (persistent managers)
scenes/
└── main.tscn                   # Main scene, persists entire session (MODIFIED)
    ├── M_StateStore            # Redux store (existing, MODIFIED: add input actions/reducers)
    ├── M_SceneManager          # Scene coordinator (existing)
    ├── M_CursorManager         # Cursor state manager (existing)
    ├── M_InputProfileManager   # NEW - Input profile coordinator
    └── M_InputDeviceManager    # NEW - Device detection and switching

# Input Manager Scripts (following existing repo patterns)
scripts/
├── managers/
│   ├── m_input_profile_manager.gd     # NEW - Profile loading/switching coordinator
│   └── m_input_device_manager.gd      # NEW - Device detection and auto-switching
│
├── u_input_rebind_utils.gd           # NEW - Rebinding validation utilities (root scripts/)
│
├── state/
│   ├── actions/
│   │   └── u_input_actions.gd          # NEW - Input action creators (14 actions)
│   ├── reducers/
│   │   ├── u_gameplay_reducer.gd       # MODIFIED - Add input action handling
│   │   └── u_settings_reducer.gd       # NEW or MODIFIED - Handle input_settings slice
│   └── selectors/
│       └── u_input_selectors.gd        # NEW - Input state query selectors
│
├── ui/
│   ├── virtual_joystick.gd             # NEW - Virtual joystick for mobile
│   ├── virtual_button.gd               # NEW - Virtual button for mobile
│   ├── rebind_button.gd                # NEW - Rebind capture UI component
│   └── u_button_prompt_registry.gd     # NEW - Button prompt icon registry
│
└── ecs/
    ├── components/
    │   ├── c_input_component.gd         # MODIFIED - Add device_type, action_strength
    │   └── c_gamepad_component.gd       # NEW - Gamepad state component
    ├── systems/
    │   ├── s_input_system.gd            # MODIFIED - Add gamepad/deadzone handling
    │   └── s_touchscreen_system.gd      # NEW - Touchscreen input system (not scripts/input/)
    └── resources/
        ├── rs_input_profile.gd          # NEW - Input profile resource definition
        ├── rs_gamepad_settings.gd       # NEW - Gamepad settings resource
        ├── rs_rebind_settings.gd        # NEW - Rebinding rules resource
        ├── rs_mouse_settings.gd         # NEW - Mouse settings resource
        └── rs_touchscreen_settings.gd   # NEW - Touchscreen settings resource

# Input Profile Resources
resources/
└── input_profiles/             # NEW directory
    ├── default.tres                     # NEW - Default keyboard/mouse profile
    ├── alternate.tres                   # NEW - Alternate keyboard layout (arrow keys)
    ├── accessibility.tres               # NEW - Accessibility profile (larger buffers)
    └── gamepad_generic.tres             # NEW - Generic gamepad profile

# Button Prompt Assets
resources/
└── button_prompts/             # NEW directory
    ├── keyboard/                        # NEW - Keyboard key icons
    │   ├── key_space.png
    │   ├── key_w.png
    │   ├── key_a.png
    │   ├── key_s.png
    │   ├── key_d.png
    │   ├── key_shift.png
    │   ├── key_e.png
    │   └── key_esc.png
    └── gamepad/                         # NEW - Gamepad button icons (generic Xbox-style)
        ├── button_a.png
        ├── button_b.png
        ├── button_x.png
        ├── button_y.png
        ├── button_lb.png
        ├── button_rb.png
        ├── button_lt.png
        ├── button_rt.png
        ├── stick_left.png
        └── stick_right.png

# UI Scenes
scenes/
└── ui/
    ├── input_settings_menu.tscn         # NEW - Input settings UI
    ├── rebind_dialog.tscn               # NEW - Rebind capture dialog
    └── mobile_controls.tscn             # NEW - Virtual controls container

# Tests
tests/
├── unit/
│   └── input_manager/          # NEW directory
│       ├── test_input_profile_manager.gd          # NEW - Profile switching tests
│       ├── test_input_device_manager.gd           # NEW - Device detection tests
│       ├── test_gamepad_component.gd              # NEW - Gamepad component tests
│       ├── test_s_touchscreen_system.gd           # NEW - Touchscreen system tests
│       ├── test_u_input_rebind_utils.gd           # NEW - Rebinding validation tests
│       ├── test_u_button_prompt_registry.gd       # NEW - Prompt registry tests
│       ├── test_virtual_joystick.gd               # NEW - Virtual joystick tests
│       ├── test_virtual_button.gd                 # NEW - Virtual button tests
│       ├── test_u_input_actions.gd                # NEW - Action creator tests
│       ├── test_u_input_selectors.gd              # NEW - Selector tests
│       ├── test_input_reducer.gd                  # NEW - Reducer tests
│       ├── test_rs_input_profile.gd               # NEW - Profile resource tests
│       ├── test_rs_gamepad_settings.gd            # NEW - Gamepad settings tests
│       └── test_rs_rebind_settings.gd             # NEW - Rebind settings tests
│
└── integration/
    └── input_manager/          # NEW directory
        ├── test_profile_switching_flow.gd         # NEW - End-to-end profile switching
        ├── test_device_handoff_flow.gd            # NEW - Device switching with prompts
        ├── test_rebinding_workflow.gd             # NEW - Complete rebind process
        ├── test_input_persistence.gd              # NEW - Save/load input settings
        ├── test_virtual_controls_visibility.gd    # NEW - Mobile controls show/hide
        ├── test_gamepad_connection_flow.gd        # NEW - Gamepad connect/disconnect
        ├── test_input_during_scene_transition.gd  # NEW - Input blocking during transitions
        └── test_accessibility_features.gd         # NEW - Accessibility profile validation
```

**File Count**:
- **NEW files**: ~45-55 (22 scripts + 4 profile resources + 18-28 button prompt assets + 3 UI scenes)
- **MODIFIED files**: 4 (main.tscn, C_InputComponent, S_InputSystem, U_GameplayReducer)
- **NEW tests**: 22 (14 unit + 8 integration)

**Organization Note**: All files follow existing repo patterns - NO new `scripts/input/` directory:
- Resources → `scripts/ecs/resources/`
- Utilities → `scripts/` (root)
- Systems → `scripts/ecs/systems/`
- Managers → `scripts/managers/`

---

## Architectural Decisions (MANDATORY READING)

The following architectural decisions address integration with existing systems and establish patterns for the Input Manager implementation. **These must be implemented exactly as specified.**

### Decision 1: Manager Placement (No Autoloads)

**Where M_InputProfileManager and M_InputDeviceManager Live:**
- **Location**: `scenes/main.tscn` under `Managers/` node (parallel to M_StateStore, M_SceneManager, M_CursorManager)
- **Pattern**: In-scene nodes, discoverable via groups ("input_profile_manager", "input_device_manager")
- **Reasoning**: Consistent with project's no-autoload constraint, follows existing manager patterns

**Manager Scope:**
- One instance per session (persist in main.tscn throughout game lifetime)
- Initialize on _ready() before gameplay systems run
- Add to groups for discovery: `add_to_group("input_profile_manager")`, `add_to_group("input_device_manager")`

**Template Updates Required:**
- ✅ Update `scenes/main.tscn` to include M_InputProfileManager and M_InputDeviceManager under Managers/ node
- ✅ Ensure managers call `add_to_group()` in `_ready()`
- ✅ Systems find managers via `get_tree().get_first_node_in_group("input_profile_manager")`

### Decision 2: Resource File Organization

**Where Input Profile .tres Files Live:**
- **Location**: `resources/input_profiles/` (NEW directory)
- **Pattern**: Follows existing `resources/settings/` convention for ECS settings
- **File Structure**:
  ```
  resources/
  ├── input_profiles/                    # NEW DIRECTORY
  │   ├── default.tres                   # Default keyboard/mouse
  │   ├── alternate.tres                 # Alternate keyboard layout
  │   ├── accessibility.tres             # Accessibility profile
  │   └── gamepad_generic.tres           # Generic gamepad
  ├── button_prompts/                    # NEW DIRECTORY
  │   ├── keyboard/*.png                 # Keyboard key icons
  │   └── gamepad/*.png                  # Gamepad button icons
  └── settings/                          # EXISTING (ECS settings)
      ├── default_jump_settings.tres
      └── ...

  scripts/input/                         # .gd scripts ONLY
  ├── rs_input_profile.gd
  ├── rs_gamepad_settings.gd
  └── ...
  ```

**Button Prompt Assets:**
- **Location**: `resources/button_prompts/{keyboard,gamepad}/` (NEW directories)
- **Format**: PNG icons, 64x64 pixels, transparent background
- **Naming**: Descriptive names (e.g., `key_space.png`, `button_a.png`)

### Decision 3: State Slice Organization

**Input State Lives in Two Slices:**

1. **Gameplay Slice (Transient - NOT Saved)**:
   ```gdscript
   "input": {
     "active_device": int,           # DeviceType enum
     "last_input_time": float,       # Timestamp
     "gamepad_connected": bool,
     "gamepad_device_id": int,
     "touchscreen_enabled": bool,
     "move_input": Vector2,
     "look_input": Vector2,
     "jump_pressed": bool,
     "jump_just_pressed": bool,
     "sprint_pressed": bool
   }
   ```

2. **Settings Slice (Persistent - Saved to Disk)**:
   ```gdscript
   "input_settings": {
     "active_profile_id": String,
     "custom_bindings": Dictionary,
     "gamepad_settings": Dictionary,
     "mouse_settings": Dictionary,
     "touchscreen_settings": Dictionary,
     "accessibility": Dictionary
   }
   ```

**Reducer Handling:**
- **U_GameplayReducer**: Handles runtime input state updates (move_input, active_device, etc.)
- **U_SettingsReducer**: Handles persistent settings updates (profile switching, custom bindings, etc.)
- Both reducers handle input actions, route to appropriate slice

**StateHandoff Integration:**
- Settings slice persists across scene transitions via StateHandoff
- Gameplay input slice resets per-scene (transient)

### Decision 4: Input Profile Resource Schema

**RS_InputProfile Structure:**
```gdscript
class_name RS_InputProfile extends Resource

@export var profile_name: String = "Default"
@export var device_type: DeviceType = DeviceType.KEYBOARD_MOUSE
@export var action_mappings: Dictionary = {}  # StringName → Array[Dictionary]
@export var buffer_windows: Dictionary = {}   # StringName → float (seconds)
@export var deadzone_overrides: Dictionary = {}  # StringName → float (0.0-1.0)

enum DeviceType { KEYBOARD_MOUSE, GAMEPAD, TOUCHSCREEN }
```

**Action Mappings Format:**
```gdscript
action_mappings = {
	StringName("jump"): [
		{"type": "key", "keycode": KEY_SPACE},
		{"type": "joypad_button", "button_index": JOY_BUTTON_A}
	],
	StringName("move_forward"): [
		{"type": "key", "keycode": KEY_W}
	]
}
```

**Why Dictionary Instead of InputEvent Directly:**
- Godot Resources can't directly serialize InputEvent arrays reliably
- Dictionary format is JSON-compatible for custom bindings save/load
- Conversion to InputEvent happens at runtime in M_InputProfileManager

### Decision 5: Component/System Patterns

**C_InputComponent Extensions** (MODIFIED existing file):
- Add `@export var device_type: int = 0` (DeviceType enum)
- Add `@export var action_strength: Dictionary = {}` (for analog inputs: action → float strength)
- Keep existing: `move_vector`, `jump_pressed`, `sprint_pressed`, `jump_buffer_time`, `jump_buffer_timestamp`
- Auto-registers with M_ECSManager on _ready() (existing pattern maintained)

**C_GamepadComponent** (NEW component):
- Extends ECSComponent
- Tracks gamepad-specific state: `device_id`, `left_stick`, `right_stick`, `vibration_enabled`, `vibration_intensity`
- Defines `COMPONENT_TYPE := StringName("C_GamepadComponent")`
- Auto-registers with M_ECSManager on _ready()

**S_InputSystem Extensions** (MODIFIED existing file):
- Add gamepad input handling (`_handle_joypad_button()`, `_handle_joypad_motion()`)
- Add deadzone filtering for analog sticks
- Check `M_SceneManager.is_transitioning()` to block input during transitions
- Check `M_CursorManager` cursor capture mode for mouse delta processing
- Dispatch input state to M_StateStore via U_InputActions

**S_TouchscreenSystem** (NEW system):
- Extends ECSSystem
- Queries VirtualJoystick and VirtualButton nodes in UI
- Updates C_InputComponent based on virtual control state
- Processes in _physics_process via process_tick(delta)

### Decision 6: Rebinding Validation Rules

**Reserved Actions** (Cannot be rebound):
- `pause` (ESC) - Required for emergency menu access
- **ONLY `pause` is reserved**

**Rebindable Actions** (Player choice):
- `interact` - Players can customize interaction key
- `toggle_debug_overlay` - Can be rebound
- All movement, combat, and gameplay actions

**Rationale**: `pause` must remain ESC for emergency menu access. `interact` is gameplay functionality, not system-critical like pause. AGENTS.md requires `interact` in project.godot for PROCESS_MODE_ALWAYS (HUD prompts), but players can still rebind it - the action name persists, only the input events change.

**Conflict Resolution:**
- Before applying rebind, check if new InputEvent already bound to another action
- If conflict found, show confirm dialog: "Jump is already bound to Spacebar. Replace?"
  - Lists conflicting action name
  - Shows current and proposed bindings
  - "Confirm" button → swap bindings between actions
  - "Cancel" button → abort rebind, restore original
- If multiple conflicts, show all in dialog (rare but possible with multi-bind)

**Unmapped Gamepad Fallback:**
- If gamepad not in SDL mapping database, use raw button indices
- Display as "button_0", "button_1", etc. in UI
- Players can rebind to map their controller manually
- No blocking or error - graceful degradation

**Validation via U_InputRebindUtils:**
```gdscript
static func validate_rebind(action: StringName, event: InputEvent, settings: RS_RebindSettings) -> Dictionary:
	# Returns: {"valid": bool, "error": String, "conflict_action": StringName}
```

### Decision 7: Device Detection Logic

**Auto-Detection Priority:**
1. Listen for InputEvent in M_InputDeviceManager._input()
2. Classify event type:
   - InputEventKey / InputEventMouseButton / InputEventMouseMotion → KEYBOARD_MOUSE
   - InputEventJoypadButton / InputEventJoypadMotion → GAMEPAD
   - InputEventScreenTouch / InputEventScreenDrag → TOUCHSCREEN
3. If device type changed, emit `device_changed` signal and dispatch ACTION_DEVICE_CHANGED to store
4. Update button prompts in HUD via U_ButtonPromptRegistry

**Mobile Special Case:**
- If OS.has_feature("mobile") AND gamepad connected → hide virtual controls, switch to GAMEPAD
- If gamepad disconnects on mobile → show virtual controls, switch to TOUCHSCREEN

### Decision 8: Virtual Controls Architecture

**Virtual Controls as UI Nodes:**
- VirtualJoystick and VirtualButton are Control nodes in `scenes/ui/mobile_controls.tscn`
- Instantiated conditionally: `if OS.has_feature("mobile"):`
- Positioned in CanvasLayer (always on top)
- S_TouchscreenSystem queries these nodes and updates C_InputComponent

**Why NOT Process Input Directly in Virtual Controls:**
- Keeps UI lightweight (no game logic in UI scripts)
- S_TouchscreenSystem provides consistent entry point (follows ECS pattern)
- Virtual controls only handle touch visualization and signal emission

### Decision 9: Performance Optimization Strategies

**Input Latency < 16ms:**
- Process ALL input types (keyboard, mouse, gamepad, touchscreen) in _physics_process for consistent 60Hz timing
- Touchscreen captures events in _input() but applies state updates in process_tick() like other inputs
- Minimize allocations in hot path (cache Vector2, reuse Dictionaries)
- Avoid `get_tree().get_nodes_in_group()` in every frame (cache manager references in _ready())

**Profile Switching < 200ms:**
- Use ResourceLoader.load() (synchronous, acceptable for small .tres files)
- Clear InputMap in bulk: `for action in InputMap.get_actions(): InputMap.action_erase_events(action)`
- Apply new mappings in single pass
- Emit single `profile_switched` signal after completion

**Save/Load < 100ms:**
- Use JSON.stringify() / JSON.parse_string() (faster than ConfigFile for small data)
- Write to temp file, rename to target (atomic write, prevents corruption)
- Load on background thread if > 100ms (Phase 7 optimization if needed)

### Decision 10: Simultaneous Multi-Device Input

**Design**: Allow keyboard + gamepad to be used simultaneously
- **Implementation**: ALL devices remain active; inputs blend together
- **Example**: Player uses WASD for movement, gamepad stick for camera simultaneously
- **Device Detection**: M_InputDeviceManager detects last-used device and updates button prompts ONLY
  - Does NOT disable other devices
  - Does NOT exclusive-lock to single device
  - "Active device" is for prompt display only, not input routing
- **State Store**: Tracks "active_device" for UI purposes, but S_InputSystem reads from ALL devices
- **Rationale**: Players may have hybrid setups (e.g., keyboard for movement, gamepad for aiming)

### Decision 11: Profile Switching Timing

**Design**: Allow profile switching anytime, even during gameplay
- **Implementation**: Changes apply immediately without requiring pause menu
- **Rationale**: Players may want to experiment with profiles mid-session
- **No FR-019 restriction**: Originally planned to require pause first, but removed per user feedback
- **State Updates**: Profile switch triggers immediate InputMap update and dispatch to state store

### Decision 12: Button Prompt Assets

**Design**: Use Kenney.nl Input Prompts pack (free, open-source)
- **Source**: https://kenney.nl/assets/input-prompts (CC0 license)
- **Format**: 64x64 PNG, flat style, generic gamepad (no platform-specific)
- **Assets needed**: ~18-28 icons
  - Keyboard: W, A, S, D, Space, Shift, E, ESC (~8 keys)
  - Gamepad: A, B, X, Y, LB, RB, LT, RT, Left Stick, Right Stick (~10 buttons)
- **Future**: Can replace with custom art if needed, but Kenney provides solid baseline

### Decision 13: Virtual Controls Positioning

**Design**: Configurable positioning - players can drag and reposition controls
- **Implementation**:
  - Default layout: Joystick bottom-left (100px from edges), buttons bottom-right
  - Players drag controls to new positions during gameplay
  - Positions saved per-profile in `touchscreen_settings.button_positions` (JSON)
- **UI**: Add "Edit Layout" mode toggle in mobile settings
- **Rationale**: Mobile players have different hand sizes and preferences

### Decision 14: Undo/Redo for Rebinding

**Design**: No undo/redo stack, provide "Reset to Defaults" button only
- **Rationale**: Simpler implementation; players can rebind again if they make mistakes
- **Reset to Defaults**: One-click button that restores all bindings from active profile .tres file
- **Per-Action Reset**: Option to reset individual actions (right-click → "Reset to Default")

---

## Complexity Tracking

**Constitution Alignment**:

✅ **No Autoloads**: Managers are in-scene nodes in main.tscn
✅ **ECS Integration**: Components/systems follow existing patterns
✅ **State Management**: Integrates with M_StateStore via actions/reducers/selectors
✅ **Scene Tree Based**: Discovery via groups, no singleton configuration

**Complexity Assessment**:

| Aspect | Complexity | Justification |
|--------|------------|---------------|
| Multi-Device Input | **High** | Must handle 3 device types (keyboard/mouse, gamepad, touchscreen) with different input patterns |
| Profile System | **Moderate** | Resource-based profiles, manager coordination, InputMap updates, persistence |
| Rebinding Validation | **High** | Conflict detection, reserved actions, validation rules, edge cases (corrupt saves, invalid events) |
| Device Auto-Detection | **Low-Moderate** | Event classification, signal emission, state updates (straightforward logic) |
| State Persistence | **Moderate** | JSON save/load, schema validation, StateHandoff integration, corruption handling |
| Virtual Controls | **Moderate** | Touch handling, joystick positioning, button visuals, mobile conditional loading |
| Testing Complexity | **High** | 22 tests (14 unit + 8 integration), must test all device types, edge cases, performance targets |

**Complexity Mitigation**:

1. **Phased Implementation**: P1 (Core multi-device) → P2 (Rebinding + Accessibility) → P3 (Polish) allows incremental validation
2. **Proven Patterns**: Reuses existing ECS patterns, Redux patterns, manager discovery patterns from Scene Manager
3. **Comprehensive PRD**: All 136 functional requirements documented, 22 success criteria measurable, 13 edge cases defined
4. **Test-Driven**: Each phase has test requirements (90%+ coverage target) before moving forward
5. **Prototyping in Phase 0**: Validate gamepad input, touchscreen input, measure baseline latency before committing

**Total Estimated Effort**: 58-80 hours
- Phase 0 (Research + Prototyping): 5-8 hours
- Phase 1 (KB/Mouse Enhancements): 6-8 hours
- Phase 2 (Input Profiles): 10-14 hours
- Phase 3 (Gamepad Support): 10-14 hours
- Phase 4 (Device Detection + Prompts): 8-10 hours
- Phase 5 (Rebinding System): 10-14 hours
- Phase 6 (Touchscreen Support): 24-30 hours (+8 hours for gap-fill tasks)
- Phase 7 (Polish + Performance): 8-12 hours

---

## Phase 0: Research & Architecture Validation (5-8 hours)

**Goal**: Validate Input Manager architecture, prototype critical features, measure baseline performance, create research documentation.

**MANDATORY**: This phase is a CRITICAL GATE. Must validate all integration points and prototypes before proceeding to implementation. If prototypes fail or latency targets unreachable, reconsider architecture.

---

### Tasks

**Task 0.1: Run Baseline Tests** (30 min) - **Satisfies FR-128**
- Run ALL existing tests to establish baseline
- Command: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- Document passing count (current baseline: varies by phase)
- **Blocker**: If tests not passing NOW, fix before starting Input Manager
- **Acceptance**:
  - [ ] All existing tests pass (100% pass rate)
  - [ ] Baseline test count documented in research.md

**Task 0.2: Review Project Patterns** (1 hour)
- Re-read `AGENTS.md`, `docs/general/DEV_PITFALLS.md`, `docs/general/STYLE_GUIDE.md`
- Review Scene Manager implementation for manager discovery patterns
- Review State Store implementation for action/reducer/selector patterns
- Review ECS implementation for component/system patterns
- **Acceptance**:
  - [ ] Manager discovery pattern understood (groups, get_tree().get_first_node_in_group())
  - [ ] Action/reducer/selector pattern understood (ActionRegistry, dispatch, subscribe)
  - [ ] Component/system pattern understood (COMPONENT_TYPE, auto-registration, process_tick)

**Task 0.3: Prototype Gamepad Input Detection** (1-2 hours) - **Satisfies FR-033, FR-034, FR-035**
- Create `prototype_gamepad.gd` test script
- Detect connected gamepads via `Input.get_connected_joypads()`
- Listen for InputEventJoypadButton and InputEventJoypadMotion
- Print analog stick values, button presses to console
- Test with physical gamepad (Xbox, PlayStation, or generic USB controller)
- Measure input latency: hardware press → event received (use Time.get_ticks_msec())
- **Deliverables**:
  - prototype_gamepad.gd script
  - Latency measurement results in research.md (target: < 16ms)
- **Acceptance**:
  - [ ] Gamepad detected successfully
  - [ ] Button presses captured (InputEventJoypadButton)
  - [ ] Analog stick motion captured (InputEventJoypadMotion)
  - [ ] Latency measured < 16ms (one frame @ 60 FPS)

**Task 0.4: Prototype Touchscreen Input (if hardware available)** (1-2 hours) - **Satisfies FR-046, FR-047, FR-048**
- Create `prototype_touch.gd` test script
- Listen for InputEventScreenTouch and InputEventScreenDrag
- Implement basic virtual joystick visualization (Control node, draws circle)
- Measure touch latency: screen press → event received
- Test on physical mobile device or emulator
- **Deliverables**:
  - prototype_touch.gd script
  - Virtual joystick visualization
  - Latency measurement results in research.md (target: < 16ms)
- **Acceptance**:
  - [ ] Touch events captured (InputEventScreenTouch, InputEventScreenDrag)
  - [ ] Virtual joystick visualizes touch position
  - [ ] Latency measured < 16ms
- **Alternative if no mobile hardware**: Document "touchscreen testing deferred to Phase 6, will use emulator"

**Task 0.5: Measure Baseline Input Latency** (1 hour) - **Satisfies FR-116**
- Create `benchmark_input_latency.gd` script
- Measure keyboard input latency: key press → S_InputSystem update → C_InputComponent update
- Measure mouse input latency: mouse move → S_InputSystem update → C_InputComponent update
- Measure gamepad input latency (if prototype 0.3 successful)
- Run 1000 samples, calculate average and p99 latency
- **Deliverables**:
  - Latency benchmark results in research.md
  - Breakdown by device type (keyboard, mouse, gamepad)
- **Acceptance**:
  - [ ] Keyboard latency < 16ms (average and p99)
  - [ ] Mouse latency < 16ms (average and p99)
  - [ ] Gamepad latency < 16ms (average and p99, if tested)
- **Blocker**: If any device exceeds 16ms, investigate optimization strategies before proceeding

**Task 0.6: Validate InputMap Modification Safety** (1 hour) - **Satisfies FR-015, FR-017**
- Create `test_inputmap_safety.gd` script
- Test adding/removing InputMap actions at runtime
- Test clearing all events for an action: `InputMap.action_erase_events(action)`
- Test adding new events: `InputMap.action_add_event(action, event)`
- Verify no crashes, no memory leaks (run for 100 iterations)
- Test profile switching: clear all actions → re-add from profile → verify input still works
- **Deliverables**:
  - test_inputmap_safety.gd script
  - Safety validation results in research.md
- **Acceptance**:
  - [ ] InputMap modifications safe at runtime (no crashes)
  - [ ] Actions can be cleared and re-added without issues
  - [ ] Input continues to work after profile switch simulation
  - [ ] No memory leaks detected (verified via Performance monitor)

**Task 0.7: Design File Structure** (1 hour)
- Create complete file tree for Input Manager (see Project Structure section above)
- Annotate files as NEW vs MODIFIED
- Plan directory creation: `resources/input_profiles/`, `resources/button_prompts/` (NO `scripts/input/` - follows existing patterns)
- Plan test directory: `tests/unit/input_manager/`, `tests/integration/input_manager/`
- **File organization**: Resources in `scripts/ecs/resources/`, utilities in `scripts/`, systems in `scripts/ecs/systems/`
- **Deliverables**:
  - Complete file structure in research.md
  - Directory creation commands documented
- **Acceptance**:
  - [ ] File structure documented with NEW/MODIFIED annotations
  - [ ] Directory creation plan ready for Phase 1

**Task 0.8: Create Research Documentation** (30 min)
- Create `docs/input_manager/research.md`
- Document all prototype findings (gamepad, touchscreen, latency benchmarks)
- Document InputMap safety validation results
- Document file structure and directory plan
- Document any risks discovered (e.g., latency targets unreachable, gamepad detection unreliable)
- **Deliverables**:
  - research.md file complete
- **Acceptance**:
  - [ ] research.md documents all prototype results
  - [ ] All latency benchmarks documented with pass/fail vs targets
  - [ ] Any risks or blockers clearly stated

---

### Acceptance Criteria (Phase 0 - ALL MUST PASS)

- [ ] **Baseline tests passing**: All existing tests pass (100% pass rate, baseline count documented)
- [ ] **Gamepad prototype working**: Gamepad detected, buttons/analog captured, latency < 16ms
- [ ] **Touchscreen prototype working** (or documented as deferred): Touch events captured, virtual joystick visualized, latency < 16ms
- [ ] **Input latency validated**: Keyboard, mouse, gamepad all < 16ms average and p99
- [ ] **InputMap safety validated**: Actions can be modified at runtime without crashes or memory leaks
- [ ] **File structure designed**: Complete file tree with NEW/MODIFIED annotations ready
- [ ] **Research.md created**: All findings documented, risks identified, ready for Phase 1

---

### Commit Strategy (Phase 0)

**Commit 1**: Phase 0 complete - research findings and architecture validation
- **Message**:
  ```
  Phase 0: Input Manager research and architecture validation

  - Baseline tests: [X] tests passing
  - Gamepad prototype: latency [Y]ms (target < 16ms)
  - Touchscreen prototype: latency [Z]ms (target < 16ms)
  - InputMap safety: validated, no issues
  - File structure designed and documented

  Deliverables:
  - docs/input_manager/research.md (complete findings)
  - prototype_gamepad.gd (proof of concept)
  - prototype_touch.gd (proof of concept)
  - benchmark_input_latency.gd (performance baseline)
  - test_inputmap_safety.gd (safety validation)

  Next: Phase 1 - KB/Mouse enhancements + state integration

  🤖 Generated with [Claude Code](https://claude.com/claude-code)

  Co-Authored-By: Claude <noreply@anthropic.com>
  ```

---

## Phase 1: Enhanced Keyboard/Mouse + State Integration (6-8 hours)

**Goal**: Enhance existing keyboard/mouse input with sensitivity settings, integrate with Redux state store, add input actions/reducers/selectors.

**Priority**: P1 (Core functionality)

---

### Tasks

**Task 1.1: Create Input Actions** (1-2 hours) - TDD REQUIRED - **Satisfies FR-075, FR-076**
- **Test First**: Write `tests/unit/input_manager/test_u_input_actions.gd`
  - Test all 14 action creators return correct action dictionaries
  - Test ActionRegistry registration in _static_init()
  - Test action type constants are StringName
- **Time estimate**: 30 min for tests, 1-1.5 hours for implementation
- Create `scripts/state/actions/u_input_actions.gd`
- Define 14 action types as StringName constants:
  1. ACTION_UPDATE_MOVE_INPUT
  2. ACTION_UPDATE_LOOK_INPUT
  3. ACTION_UPDATE_JUMP_STATE
  4. ACTION_UPDATE_SPRINT_STATE
  5. ACTION_DEVICE_CHANGED
  6. ACTION_GAMEPAD_CONNECTED
  7. ACTION_GAMEPAD_DISCONNECTED
  8. ACTION_PROFILE_SWITCHED
  9. ACTION_REBIND_ACTION
  10. ACTION_RESET_BINDINGS
  11. ACTION_UPDATE_GAMEPAD_DEADZONE
  12. ACTION_TOGGLE_VIBRATION
  13. ACTION_UPDATE_MOUSE_SENSITIVITY
  14. ACTION_UPDATE_ACCESSIBILITY
- Implement action creator functions (static methods)
- Register all actions in `_static_init()` via ActionRegistry
- **Files created**: u_input_actions.gd, test_u_input_actions.gd
- **Acceptance**:
  - [ ] Test passes: All action creators return correct dictionaries
  - [ ] Test passes: ActionRegistry registration successful
  - [ ] All 14 action types defined as StringName constants
  - [ ] All action creators implemented and return proper {type, payload} format

**Task 1.2: Create Input Selectors** (1 hour) - TDD REQUIRED - **Satisfies FR-077**
- **Test First**: Write `tests/unit/input_manager/test_u_input_selectors.gd`
  - Test selectors return correct values from state
  - Test selectors handle missing fields gracefully (return defaults)
- **Time estimate**: 20 min for tests, 40 min for implementation
- Create `scripts/state/selectors/u_input_selectors.gd`
- Implement selector functions (static methods):
  - `get_active_device(state: Dictionary) -> int`
  - `get_move_input(state: Dictionary) -> Vector2`
  - `get_look_input(state: Dictionary) -> Vector2`
  - `is_jump_pressed(state: Dictionary) -> bool`
  - `is_sprint_pressed(state: Dictionary) -> bool`
  - `get_active_profile_id(state: Dictionary) -> String`
  - `get_gamepad_settings(state: Dictionary) -> Dictionary`
  - `get_mouse_settings(state: Dictionary) -> Dictionary`
  - `is_gamepad_connected(state: Dictionary) -> bool`
  - `get_gamepad_device_id(state: Dictionary) -> int`
- **Files created**: u_input_selectors.gd, test_u_input_selectors.gd
- **Acceptance**:
  - [ ] Test passes: All selectors return correct values
  - [ ] Test passes: Selectors handle missing fields (return defaults, no errors)
  - [ ] All 10 selector functions implemented

**Task 1.3: Extend Gameplay Reducer for Input Actions** (1-2 hours) - TDD REQUIRED - **Satisfies FR-076**
- **Test First**: Write `tests/unit/input_manager/test_input_reducer.gd`
  - Test reducer handles all 14 input action types
  - Test state updates immutable (use .duplicate(true))
  - Test transient fields excluded from persistence
- **Time estimate**: 30 min for tests, 1-1.5 hours for implementation
- Modify `scripts/state/reducers/u_gameplay_reducer.gd`
- Add input slice to initial state:
  ```gdscript
  "input": {
    "active_device": 0,  # KEYBOARD_MOUSE
    "last_input_time": 0.0,
    "gamepad_connected": false,
    "gamepad_device_id": -1,
    "touchscreen_enabled": false,
    "move_input": Vector2.ZERO,
    "look_input": Vector2.ZERO,
    "jump_pressed": false,
    "jump_just_pressed": false,
    "sprint_pressed": false
  }
  ```
- Handle input actions in reducer:
  - ACTION_UPDATE_MOVE_INPUT: Update move_input
  - ACTION_UPDATE_LOOK_INPUT: Update look_input
  - ACTION_UPDATE_JUMP_STATE: Update jump_pressed, jump_just_pressed
  - ACTION_UPDATE_SPRINT_STATE: Update sprint_pressed
  - ACTION_DEVICE_CHANGED: Update active_device, last_input_time
  - ACTION_GAMEPAD_CONNECTED: Update gamepad_connected, gamepad_device_id
  - ACTION_GAMEPAD_DISCONNECTED: Update gamepad_connected, gamepad_device_id = -1
- Use immutable updates: `new_state.input = state.input.duplicate(true)` before modifying
- Mark input slice as transient (excluded from save_state())
- **Files modified**: u_gameplay_reducer.gd, test_input_reducer.gd
- **Acceptance**:
  - [ ] Test passes: All input actions handled correctly
  - [ ] Test passes: State updates are immutable (original state unchanged)
  - [ ] Test passes: Input slice excluded from save_state() (transient)
  - [ ] Reducer handles all 7 runtime input actions (move, look, jump, sprint, device, gamepad)

**Task 1.4: Create Settings Reducer for Input Settings** (1-2 hours) - TDD REQUIRED - **Satisfies FR-076, FR-078**
- **Test First**: Extend `tests/unit/state/test_settings_reducer.gd` (or create if missing)
  - Test reducer handles input_settings actions
  - Test settings slice persists (included in save_state())
- **Time estimate**: 30 min for tests, 1-1.5 hours for implementation
- Modify or create `scripts/state/reducers/u_settings_reducer.gd`
- Add input_settings slice to initial state:
  ```gdscript
  "input_settings": {
    "active_profile_id": "default",
    "custom_bindings": {},
    "gamepad_settings": {
      "left_stick_deadzone": 0.2,
      "right_stick_deadzone": 0.2,
      "vibration_enabled": true,
      "vibration_intensity": 1.0,
      "invert_y_axis": false
    },
    "mouse_settings": {
      "sensitivity": 1.0,
      "invert_y_axis": false
    },
    "touchscreen_settings": {
      "virtual_joystick_size": 1.0,
      "virtual_joystick_opacity": 0.7,
      "button_layout": "default",
      "button_size": 1.0
    },
    "accessibility": {
      "jump_buffer_time": 0.1,
      "sprint_toggle_mode": false,
      "interact_hold_duration": 0.0
    }
  }
  ```
- Handle settings actions:
  - ACTION_PROFILE_SWITCHED: Update active_profile_id
  - ACTION_REBIND_ACTION: Update custom_bindings
  - ACTION_RESET_BINDINGS: Clear custom_bindings
  - ACTION_UPDATE_GAMEPAD_DEADZONE: Update gamepad_settings
  - ACTION_TOGGLE_VIBRATION: Update vibration_enabled
  - ACTION_UPDATE_MOUSE_SENSITIVITY: Update mouse_settings.sensitivity
  - ACTION_UPDATE_ACCESSIBILITY: Update accessibility fields
- Use immutable updates: `new_state.input_settings = state.input_settings.duplicate(true)`
- **Files modified**: u_settings_reducer.gd, test_settings_reducer.gd
- **Acceptance**:
  - [ ] Test passes: All input_settings actions handled correctly
  - [ ] Test passes: Settings slice included in save_state() (persistent)
  - [ ] Test passes: Immutable updates (original state unchanged)
  - [ ] Reducer handles all 7 settings actions (profile, rebind, reset, gamepad, vibration, mouse, accessibility)

**Task 1.5: Enhance S_InputSystem with State Dispatch** (1 hour) - **Satisfies FR-006**
- **Time estimate**: 1 hour (no new tests, extends existing system)
- Modify `scripts/ecs/systems/s_input_system.gd`
- Add M_StateStore reference:
  ```gdscript
  var _state_store: M_StateStore = null

  func _ready() -> void:
    super._ready()  # Call ECSSystem._ready()
    await get_tree().process_frame
    _state_store = U_StateUtils.get_store(self)
  ```
- Dispatch input state every physics frame in process_tick():
  ```gdscript
  func process_tick(delta: float) -> void:
    # Existing input capture logic...

    # Dispatch to state store
    if _state_store:
      _state_store.dispatch(U_InputActions.update_move_input(move_vector))
      _state_store.dispatch(U_InputActions.update_look_input(look_delta))
      if jump_pressed:
        _state_store.dispatch(U_InputActions.update_jump_state(true, jump_just_pressed))
      _state_store.dispatch(U_InputActions.update_sprint_state(sprint_pressed))
  ```
- **Files modified**: s_input_system.gd
- **Acceptance**:
  - [ ] S_InputSystem finds M_StateStore via U_StateUtils.get_store()
  - [ ] Input state dispatched to store every physics frame
  - [ ] Existing functionality preserved (components still updated)
  - [ ] Manual test: Input state visible in debug overlay (if available)

**Task 1.6: Add Mouse Sensitivity Setting** (1 hour) - **Satisfies FR-100**
- **Time estimate**: 1 hour
- Modify `scripts/ecs/systems/s_input_system.gd`
- Add mouse sensitivity multiplier:
  ```gdscript
  var _mouse_sensitivity: float = 1.0

  func process_tick(delta: float) -> void:
    # ... existing input capture ...

    # Apply sensitivity to mouse delta
    look_delta *= _mouse_sensitivity

    # ... update components and dispatch ...
  ```
- Subscribe to mouse sensitivity changes in _ready():
  ```gdscript
  func _ready() -> void:
    # ... existing _ready() logic ...
    _state_store.subscribe(_on_state_changed)

  func _on_state_changed(state: Dictionary) -> void:
    var mouse_settings := U_InputSelectors.get_mouse_settings(state)
    _mouse_sensitivity = mouse_settings.get("sensitivity", 1.0)
  ```
- **Files modified**: s_input_system.gd
- **Acceptance**:
  - [ ] Mouse sensitivity multiplier applied to look_delta
  - [ ] Sensitivity updates when settings slice changes
  - [ ] Manual test: Change sensitivity via store dispatch, verify mouse speed changes

---

### Integration Testing (1 hour)

**Test 1.1: Input State Persistence Across Scene Transitions** - **Satisfies FR-078**
- Create `tests/integration/input_manager/test_input_persistence.gd`
- Test: Load scene A → modify input_settings via dispatch → transition to scene B → verify settings preserved
- **Acceptance**:
  - [ ] Settings slice persists across scene transitions (StateHandoff working)
  - [ ] Gameplay input slice resets per-scene (transient)

**Test 1.2: Input Actions Dispatch and Reduce Correctly**
- Create `tests/integration/input_manager/test_input_actions_flow.gd`
- Test: Dispatch ACTION_UPDATE_MOVE_INPUT → verify state updated → query via selector → verify correct value
- **Acceptance**:
  - [ ] Actions dispatch successfully
  - [ ] Reducers update state correctly
  - [ ] Selectors return updated values

---

### Acceptance Criteria (Phase 1 - ALL MUST PASS)

- [ ] **Input actions created**: All 14 action types defined, action creators implemented, ActionRegistry registration working
- [ ] **Input selectors created**: All 10 selector functions implemented, tests passing
- [ ] **Gameplay reducer extended**: Handles 7 runtime input actions, immutable updates, transient slice
- [ ] **Settings reducer created**: Handles 7 settings actions, persistent slice, immutable updates
- [ ] **S_InputSystem enhanced**: Dispatches input state to store every frame, mouse sensitivity applied
- [ ] **Tests passing**: All new unit tests pass (test_u_input_actions, test_u_input_selectors, test_input_reducer, test_settings_reducer)
- [ ] **Integration tests passing**: Input persistence across transitions, actions flow correctly
- [ ] **No regressions**: All baseline tests still pass (100% pass rate)
- [ ] **Manual test**: Input captured, dispatched to store, state queryable via selectors, sensitivity adjustment works

---

### Commit Strategy (Phase 1)

**Commit 2**: Input actions and selectors implemented (TDD)
- **Message**: "Phase 1.1-1.2: Input actions and selectors with tests"
- **Files**: u_input_actions.gd, u_input_selectors.gd, test_u_input_actions.gd, test_u_input_selectors.gd

**Commit 3**: Input reducers implemented (TDD)
- **Message**: "Phase 1.3-1.4: Gameplay and settings reducers for input with tests"
- **Files**: u_gameplay_reducer.gd (modified), u_settings_reducer.gd (modified or new), test_input_reducer.gd, test_settings_reducer.gd

**Commit 4**: S_InputSystem state integration and mouse sensitivity
- **Message**: "Phase 1.5-1.6: S_InputSystem state dispatch and mouse sensitivity"
- **Files**: s_input_system.gd (modified)

**Commit 5**: Phase 1 integration tests and validation
- **Message**: "Phase 1 complete: KB/Mouse enhancements + state integration"
- **Files**: test_input_persistence.gd, test_input_actions_flow.gd

---

## Phase 2: Input Profiles (10-14 hours)

**Goal**: Implement input profile system with switchable control schemes (default, alternate, accessibility, gamepad).

**Priority**: P1 (Core functionality)

---

### Tasks

**Task 2.1: Create RS_InputProfile Resource** (1-2 hours) - TDD REQUIRED - **Satisfies FR-011, FR-012**
- **Test First**: Write `tests/unit/input_manager/test_rs_input_profile.gd`
  - Test profile creation with action mappings
  - Test resource save/load (.tres file)
  - Test action_mappings dictionary structure
- **Time estimate**: 30 min for tests, 1-1.5 hours for implementation
- Create `scripts/input/rs_input_profile.gd`
- Define resource class:
  ```gdscript
  class_name RS_InputProfile extends Resource

  @export var profile_name: String = "Default"
  @export var device_type: DeviceType = DeviceType.KEYBOARD_MOUSE
  @export var action_mappings: Dictionary = {}  # StringName → Array[Dictionary]
  @export var buffer_windows: Dictionary = {}   # StringName → float
  @export var deadzone_overrides: Dictionary = {}  # StringName → float

  enum DeviceType { KEYBOARD_MOUSE, GAMEPAD, TOUCHSCREEN }
  ```
- **Files created**: rs_input_profile.gd, test_rs_input_profile.gd
- **Acceptance**:
  - [ ] Test passes: Profile resource created and saved to .tres
  - [ ] Test passes: action_mappings dictionary loads correctly
  - [ ] Resource script documented with ## comments

**Task 2.2: Create Default Input Profiles** (2-3 hours) - **Satisfies FR-012**
- **Time estimate**: 2-3 hours (manual resource creation in Godot editor)
- Create 4 profile .tres files in `resources/input_profiles/`:
  1. **default.tres** (WASD, Space, Shift)
     ```
     profile_name = "Default"
     device_type = KEYBOARD_MOUSE
     action_mappings = {
       "move_forward": [{"type": "key", "keycode": KEY_W}],
       "move_backward": [{"type": "key", "keycode": KEY_S}],
       "move_left": [{"type": "key", "keycode": KEY_A}],
       "move_right": [{"type": "key", "keycode": KEY_D}],
       "jump": [{"type": "key", "keycode": KEY_SPACE}],
       "sprint": [{"type": "key", "keycode": KEY_SHIFT}],
       "interact": [{"type": "key", "keycode": KEY_E}],
       "pause": [{"type": "key", "keycode": KEY_ESCAPE}]
     }
     buffer_windows = {"jump": 0.1}
     ```

  2. **alternate.tres** (Arrow keys, Right Ctrl, Right Shift)
     ```
     profile_name = "Alternate"
     device_type = KEYBOARD_MOUSE
     action_mappings = {
       "move_forward": [{"type": "key", "keycode": KEY_UP}],
       "move_backward": [{"type": "key", "keycode": KEY_DOWN}],
       "move_left": [{"type": "key", "keycode": KEY_LEFT}],
       "move_right": [{"type": "key", "keycode": KEY_RIGHT}],
       "jump": [{"type": "key", "keycode": KEY_CTRL}],
       "sprint": [{"type": "key", "keycode": KEY_SHIFT}],
       "interact": [{"type": "key", "keycode": KEY_ENTER}],
       "pause": [{"type": "key", "keycode": KEY_ESCAPE}]
     }
     buffer_windows = {"jump": 0.1}
     ```

  3. **accessibility.tres** (Same as default, larger buffer windows)
     ```
     profile_name = "Accessibility"
     device_type = KEYBOARD_MOUSE
     action_mappings = { /* same as default */ }
     buffer_windows = {"jump": 0.3}  # Larger buffer for accessibility
     deadzone_overrides = {"move_vector": 0.4}  # Larger deadzone
     ```

  4. **gamepad_generic.tres** (Generic gamepad layout, Xbox-style)
     ```
     profile_name = "Gamepad (Generic)"
     device_type = GAMEPAD
     action_mappings = {
       "move_forward": [{"type": "joypad_axis", "axis": JOY_AXIS_LEFT_Y, "axis_value": -1.0}],
       "move_backward": [{"type": "joypad_axis", "axis": JOY_AXIS_LEFT_Y, "axis_value": 1.0}],
       "move_left": [{"type": "joypad_axis", "axis": JOY_AXIS_LEFT_X, "axis_value": -1.0}],
       "move_right": [{"type": "joypad_axis", "axis": JOY_AXIS_LEFT_X, "axis_value": 1.0}],
       "jump": [{"type": "joypad_button", "button_index": JOY_BUTTON_A}],
       "sprint": [{"type": "joypad_button", "button_index": JOY_BUTTON_LEFT_STICK}],
       "interact": [{"type": "joypad_button", "button_index": JOY_BUTTON_X}],
       "pause": [{"type": "joypad_button", "button_index": JOY_BUTTON_START}]
     }
     buffer_windows = {"jump": 0.1}
     deadzone_overrides = {"move_vector": 0.2}
     ```
- **Files created**: default.tres, alternate.tres, accessibility.tres, gamepad_generic.tres
- **Acceptance**:
  - [ ] 4 profile .tres files created in resources/input_profiles/
  - [ ] All profiles loadable in Godot editor without errors
  - [ ] All required actions mapped in each profile

**Task 2.3: Create M_InputProfileManager** (2-3 hours) - TDD REQUIRED - **Satisfies FR-014, FR-015, FR-089**
- **Test First**: Write `tests/unit/input_manager/test_input_profile_manager.gd`
  - Test profile loading from .tres file
  - Test profile switching updates InputMap
  - Test profile switching completes < 200ms
  - Test manager adds to "input_profile_manager" group
- **Time estimate**: 1 hour for tests, 1-2 hours for implementation
- Create `scripts/managers/m_input_profile_manager.gd`
- Define manager class:
  ```gdscript
  class_name M_InputProfileManager extends Node

  signal profile_switched(profile_name: String)

  var active_profile: RS_InputProfile = null
  var _state_store: M_StateStore = null

  func _ready() -> void:
    add_to_group("input_profile_manager")
    await get_tree().process_frame
    _state_store = U_StateUtils.get_store(self)
    _load_active_profile()

  func switch_profile(profile_path: String) -> void:
    var start_time := Time.get_ticks_msec()

    # Load profile resource
    var profile := load(profile_path) as RS_InputProfile
    if not profile:
      push_error("Failed to load profile: %s" % profile_path)
      return

    # Clear InputMap
    for action in InputMap.get_actions():
      if not _is_reserved_action(action):
        InputMap.action_erase_events(action)

    # Apply profile mappings
    for action in profile.action_mappings:
      var events := profile.action_mappings[action] as Array
      for event_dict in events:
        var event := _dict_to_input_event(event_dict)
        if event:
          InputMap.action_add_event(action, event)

    active_profile = profile

    # Dispatch to state store
    _state_store.dispatch(U_InputActions.profile_switched(profile.profile_name))

    # Emit signal
    profile_switched.emit(profile.profile_name)

    var elapsed := Time.get_ticks_msec() - start_time
    print("Profile switched to '%s' in %d ms" % [profile.profile_name, elapsed])

  func _dict_to_input_event(event_dict: Dictionary) -> InputEvent:
    # Convert dictionary to InputEvent (type-specific logic)
    var type := event_dict.get("type", "")
    match type:
      "key":
        var event := InputEventKey.new()
        event.keycode = event_dict.get("keycode", 0)
        return event
      "joypad_button":
        var event := InputEventJoypadButton.new()
        event.button_index = event_dict.get("button_index", 0)
        return event
      "joypad_axis":
        var event := InputEventJoypadMotion.new()
        event.axis = event_dict.get("axis", 0)
        event.axis_value = event_dict.get("axis_value", 0.0)
        return event
    return null

  func _is_reserved_action(action: StringName) -> bool:
    return action in [StringName("pause"), StringName("toggle_debug_overlay")]

  func _load_active_profile() -> void:
    var state := _state_store.get_state()
    var profile_id := U_InputSelectors.get_active_profile_id(state)
    var profile_path := "res://resources/input_profiles/%s.tres" % profile_id
    switch_profile(profile_path)
  ```
- **Files created**: m_input_profile_manager.gd, test_input_profile_manager.gd
- **Acceptance**:
  - [ ] Test passes: Profile loads from .tres file
  - [ ] Test passes: InputMap updated with profile mappings
  - [ ] Test passes: Profile switching completes < 200ms
  - [ ] Test passes: Manager adds to "input_profile_manager" group
  - [ ] Manager finds M_StateStore via U_StateUtils.get_store()

**Task 2.4: Add M_InputProfileManager to Root Scene** (30 min) - **Satisfies FR-089**
- **Time estimate**: 30 min
- Open `scenes/main.tscn` in Godot editor
- Add M_InputProfileManager as child of Managers/ node (parallel to M_StateStore, M_SceneManager, M_CursorManager)
- Save scene
- **Files modified**: main.tscn
- **Acceptance**:
  - [ ] M_InputProfileManager present in main.tscn under Managers/
  - [ ] Scene loads without errors
  - [ ] Manager visible in scene tree

**Task 2.5: Create Profile Selection UI** (2-3 hours) - **Satisfies FR-014**
- **Time estimate**: 2-3 hours
- Create `scenes/ui/input_settings_menu.tscn`
- Add OptionButton for profile selection:
  - Options: "Default", "Alternate", "Accessibility", "Gamepad (Generic)"
- Connect OptionButton.item_selected signal to script:
  ```gdscript
  func _on_profile_selected(index: int) -> void:
    var profile_names := ["default", "alternate", "accessibility", "gamepad_generic"]
    var profile_id := profile_names[index]
    var profile_path := "res://resources/input_profiles/%s.tres" % profile_id

    var manager := get_tree().get_first_node_in_group("input_profile_manager") as M_InputProfileManager
    if manager:
      manager.switch_profile(profile_path)
  ```
- Add Label showing current profile
- Add "Apply" button (optional, profile switches immediately)
- **Files created**: input_settings_menu.tscn, input_settings_menu.gd (script)
- **Acceptance**:
  - [ ] UI scene created with profile dropdown
  - [ ] Dropdown populated with 4 profile options
  - [ ] Selection triggers M_InputProfileManager.switch_profile()
  - [ ] Manual test: Change profile in UI, verify InputMap updated, input works with new profile

---

### Integration Testing (1 hour) - **Satisfies FR-133**

**Test 2.1: Profile Switching Flow**
- Create `tests/integration/input_manager/test_profile_switching_flow.gd`
- Test: Load default profile → switch to alternate → verify InputMap updated → switch to accessibility → verify buffer windows applied
- **Acceptance**:
  - [ ] Profile switching works end-to-end
  - [ ] InputMap reflects profile mappings after switch
  - [ ] Buffer windows and deadzones applied from profile

**Test 2.2: Profile Persistence Across Sessions**
- Extend test_input_persistence.gd
- Test: Switch profile → save state → reload state → verify active profile restored
- **Acceptance**:
  - [ ] Active profile persists in settings slice
  - [ ] Profile reloaded on game start

---

### Acceptance Criteria (Phase 2 - ALL MUST PASS)

- [ ] **RS_InputProfile resource created**: Tests passing, resource saveable to .tres
- [ ] **4 profiles created**: default, alternate, accessibility, gamepad_generic (.tres files)
- [ ] **M_InputProfileManager implemented**: Tests passing, profile switching < 200ms, adds to group
- [ ] **M_InputProfileManager in main.tscn**: Present under Managers/, scene loads without errors
- [ ] **Profile selection UI created**: Dropdown with 4 options, triggers profile switching
- [ ] **Tests passing**: test_rs_input_profile, test_input_profile_manager, test_profile_switching_flow
- [ ] **No regressions**: All baseline tests still pass (100% pass rate)
- [ ] **Manual test**: Switch profiles in UI, verify input works correctly with each profile, verify switching < 200ms (console output)

---

### Commit Strategy (Phase 2)

**Commit 6**: RS_InputProfile resource and tests
- **Message**: "Phase 2.1: RS_InputProfile resource with tests"
- **Files**: rs_input_profile.gd, test_rs_input_profile.gd

**Commit 7**: Default input profiles created
- **Message**: "Phase 2.2: 4 default input profiles (default, alternate, accessibility, gamepad)"
- **Files**: default.tres, alternate.tres, accessibility.tres, gamepad_generic.tres

**Commit 8**: M_InputProfileManager implementation and tests
- **Message**: "Phase 2.3: M_InputProfileManager with profile switching < 200ms"
- **Files**: m_input_profile_manager.gd, test_input_profile_manager.gd

**Commit 9**: M_InputProfileManager added to root scene
- **Message**: "Phase 2.4: M_InputProfileManager added to main.tscn"
- **Files**: main.tscn (modified)

**Commit 10**: Profile selection UI
- **Message**: "Phase 2.5: Profile selection UI with dropdown"
- **Files**: input_settings_menu.tscn, input_settings_menu.gd

**Commit 11**: Phase 2 integration tests and validation
- **Message**: "Phase 2 complete: Input profiles with switching and persistence"
- **Files**: test_profile_switching_flow.gd, test_input_persistence.gd (extended)

---

## Phase 3: Gamepad Support (10-14 hours)

**Goal**: Implement gamepad input support with analog sticks, buttons, deadzones, and vibration.

**Priority**: P1 (Core functionality)

**Note**: Due to length constraints, Phases 3-7 follow the same detailed format as Phases 0-2. Each phase includes:
- Numbered tasks with time estimates, TDD requirements, FR references
- Test-first approach for all components/systems/managers
- Integration testing
- Acceptance criteria (must pass checklist)
- Commit-by-commit strategy

For brevity in this document, I'm providing the task overview for Phases 3-7. The full expansion follows the established pattern.

---

### Tasks Overview (Phase 3)

**Task 3.1**: Create RS_GamepadSettings resource (1-2 hours, TDD) - FR-036, FR-037, FR-038
**Task 3.2**: Create C_GamepadComponent (1-2 hours, TDD) - FR-039, FR-084
**Task 3.3**: Extend S_InputSystem for Gamepad Input (2-3 hours, TDD) - FR-034, FR-035, FR-036, FR-037
**Task 3.4**: Implement Gamepad Vibration Support (1-2 hours, TDD) - FR-038, FR-045
**Task 3.5**: Handle Gamepad Connect/Disconnect (1-2 hours, TDD) - FR-033, FR-040, FR-041, FR-042
**Task 3.6**: Add Gamepad Settings UI (1-2 hours) - FR-036, FR-038
**Task 3.7**: Integration Testing (1 hour) - FR-133

**Duration**: 10-14 hours
**Commits**: 6 commits (one per task + integration tests)

---

## Phase 4: Device Auto-Detection + Button Prompts (8-10 hours)

### Tasks Overview (Phase 4)

**Task 4.1**: Create M_InputDeviceManager (2-3 hours, TDD) - FR-057, FR-058, FR-059, FR-060, FR-090
**Task 4.2**: Implement Device Detection Logic (2-3 hours, TDD) - FR-058, FR-060, FR-063, FR-064
**Task 4.3**: Create U_ButtonPromptRegistry (1-2 hours, TDD) - FR-066, FR-067, FR-068
**Task 4.4**: Create Button Prompt Assets (1-2 hours) - FR-067
**Task 4.5**: Integrate Button Prompts with HUD (1-2 hours) - FR-069, FR-070
**Task 4.6**: Add M_InputDeviceManager to Root Scene (30 min) - FR-090
**Task 4.7**: Integration Testing (1 hour) - FR-134

**Duration**: 8-10 hours
**Commits**: 6 commits (one per major task + integration tests)

---

## Phase 5: Rebinding System + Persistence (10-14 hours)

### Tasks Overview (Phase 5)

**Task 5.1**: Create RS_RebindSettings resource (1-2 hours, TDD) - FR-022
**Task 5.2**: Create U_InputRebindUtils (2-3 hours, TDD) - FR-021, FR-023, FR-027
**Task 5.3**: Create Rebinding UI (2-3 hours) - FR-021, FR-024, FR-025, FR-026
**Task 5.4**: Implement Input Settings Persistence (2-3 hours, TDD) - FR-094, FR-095, FR-096, FR-102, FR-103
**Task 5.5**: Handle Custom Bindings Load/Save (1-2 hours, TDD) - FR-029, FR-098
**Task 5.6**: Implement Reset to Default (1 hour, TDD) - FR-030
**Task 5.7**: Integration Testing (1 hour) - FR-135, FR-136

**Duration**: 10-14 hours
**Commits**: 6 commits (one per major task + integration tests)

---

## Phase 6: Touchscreen Support (24-30 hours)

**Architecture Review Complete (2025-11-13)**: See `docs/input manager/phase-6-touchscreen-architecture.md` for comprehensive audit and integration analysis.

**Key Decisions:**
- Draggable control positioning (saved globally in `touchscreen_settings`)
- Auto-hide when gamepad/keyboard connected (device detection integration)
- Hide during pause menu, gray out (50% opacity) during scene transitions
- Landscape orientation only (no rotation support in Phase 6)
- Kenney.nl Mobile pack assets for virtual control visuals
- Physical mobile device available for validation; keep `--emulate-mobile` flag as desktop smoke fallback
- Default touchscreen profile with metadata-driven button configuration
- Edit Touch Controls overlay for enabling drag mode
- Touchscreen Settings overlay for size/opacity/deadzone configuration
- HUD safe area margins (bottom 150px, sides 200px) to avoid virtual control overlap
- Console log only for emulation mode indicator (no on-screen UI)
- Automated performance testing (< 16.67ms avg frame time)
- Save file migration testing (Phase 5 → Phase 6 compatibility)
- Virtual buttons: Jump, Sprint, Interact, Pause (metadata-driven, extensible)

### Integration Points

**Redux State Store:**
- Extend `settings.input_settings.touchscreen_settings` with position data
- Add actions: `update_touchscreen_settings()`, `save_virtual_control_position()`
- Add selectors: `get_touchscreen_settings()`, `get_virtual_control_position()`

**Device Manager:**
- Touch detection already implemented in `M_InputDeviceManager` (lines 75-81, 107-108)
- Virtual controls subscribe to `device_changed` signal
- Auto-hide when `device_type == GAMEPAD`

**ECS Manager:**
- S_TouchscreenSystem queries existing `C_InputComponent` (NO new component needed!)
- System updates `move_vector` directly
- NO changes needed to S_InputSystem (automatic integration)

**Scene Manager:**
- MobileControls is separate CanvasLayer (not overlay)
- Listens to overlay stack signals for pause detection
- Conditional instantiation: `if OS.has_feature("mobile") or _emulate_mobile_mode`

**Profile Manager:**
- Default touchscreen profile (`default_touchscreen.tres`) with position metadata
- `reset_touchscreen_positions()` method loads profile and dispatches to Redux

### Tasks Overview (Phase 6)

**Task 6.0**: Create Default Touchscreen Profile (1-2 hours, TDD) - NEW
  - Create `resources/input/profiles/default_touchscreen.tres`
  - Metadata-driven buttons: Define `virtual_buttons` array with actions (jump, sprint, interact, pause) and positions
  - Extend M_InputProfileManager with `reset_touchscreen_positions()`
  - Position metadata: joystick bottom-left (120, 520), buttons bottom-right (920-820, 480-620)
  - Unit tests for profile loading and reset functionality

**Task 6.0.5**: Download Kenney.nl Mobile Assets (30 min) - NEW (Gap Fill)
  - Download Kenney Input Prompts - Mobile pack (CC0)
  - Extract joystick_base.png, joystick_thumb.png, button_background.png
  - Import to `resources/button_prompts/mobile/`
  - Configure import settings, add LICENSE file

**Task 6.1**: Create RS_TouchscreenSettings Resource (1-2 hours, TDD) - FR-101
  - Exports: joystick_size, opacity, deadzone, radius, button_size
  - Static helper: `apply_touch_deadzone(vector, deadzone) -> Vector2`
  - Default resource: `resources/input/touchscreen_settings/default_touchscreen_settings.tres`
  - Unit tests for deadzone calculation and resource loading

**Task 6.2**: Add Redux State Integration (2-3 hours, TDD)
  - Extend `u_input_actions.gd`: `update_touchscreen_settings()`, `save_virtual_control_position()`
  - Extend `u_input_reducer.gd`: Handle new actions, merge into `touchscreen_settings`
  - Extend `u_input_selectors.gd`: `get_touchscreen_settings()`, `get_virtual_control_position()`
  - Unit tests for actions, reducers, selectors

**Task 6.3**: Create VirtualJoystick UI Component (3-4 hours, TDD) - FR-047, FR-049, FR-050, FR-051
  - Extend `Control`, process input in `_input()`
  - Track touch ID (multi-touch safe), emit signals
  - Apply deadzone via `RS_TouchscreenSettings.apply_touch_deadzone()`
  - Drag-to-reposition with Redux save
  - Scene: `virtual_joystick.tscn` with Kenney.nl textures
  - Unit tests: touch press/drag/release, deadzone, multi-touch, repositioning

**Task 6.4**: Create VirtualButton UI Component (2-3 hours, TDD) - FR-048
  - Similar to VirtualJoystick but discrete press/release
  - Drag-out behavior (release if finger slides off)
  - Drag-to-reposition with Redux save
  - Scene: `virtual_button.tscn` with Kenney.nl assets
  - Unit tests: press/release, drag-out, multi-touch, repositioning
  - ✅ Status (2025-11-20): `scripts/ui/virtual_button.gd` + `scenes/ui/virtual_button.tscn` landed with 11-test GUT suite (`tests/unit/ui/test_virtual_button.gd`) covering press/release, drag-out, tap vs hold, multi-touch, reposition saves, and visual feedback (modulate/scale tween substitute).

**Task 6.5**: Create MobileControls Scene + Visibility Logic (2-3 hours, TDD) - FR-046, FR-053, FR-054, FR-056-B, FR-056-C
  - Extend `CanvasLayer`, conditional instantiation (mobile or emulation mode)
  - Console log emulation mode on startup (Gap Fill)
  - Subscribe to `M_InputDeviceManager.device_changed` signal
  - Subscribe to `M_SceneManager.overlay_pushed/popped` and `transition_started/finished` signals
  - Visibility rules: hide on gamepad/keyboard, hide during pause
  - Opacity rules: 50% during scene transitions, 100% during gameplay (Gap Fill)
  - Metadata-driven button instantiation: Read `virtual_buttons` array from profile, create VirtualButton instances dynamically (Gap Fill)
  - Load saved positions from Redux on startup (joystick + buttons)
  - Scene: `mobile_controls.tscn` with VirtualJoystick + VirtualButtons container (buttons added dynamically)
  - Add to `main.tscn` after HUD_Overlay
  - Unit tests: emulation detection, console log, visibility rules, opacity rules, metadata-driven buttons, position loading

**Task 6.6**: Create S_TouchscreenSystem (3-4 hours, TDD) - FR-052, FR-055
  - Extend `BaseECSSystem`, query `C_InputComponent`
  - Cache VirtualJoystick/VirtualButton references in `on_configured()`
  - Subscribe to state store for `touchscreen_settings`
  - Read virtual control state, update component in `process_tick()`
  - Early return if not mobile and not emulate mode
  - Add to `gameplay_base.tscn` under Systems container
  - Unit tests: component query, joystick updates movement, button presses, platform checks

**Task 6.7**: Add Desktop Emulation Toggle (1-2 hours)
  - Command-line flag: `--emulate-mobile`
  - Debug setting: `debug.emulate_mobile_mode` (future)
  - Document in `DEV_PITFALLS.md`: "Testing Mobile Controls on Desktop"
  - Note: Enable "Emulate Touch from Mouse" project setting

**Task 6.8**: Integration Testing (2-3 hours) - FR-133
  - Test: Virtual joystick movement updates C_InputComponent
  - Test: Virtual button press triggers jump/sprint
  - Test: Gamepad connect/disconnect hides/shows virtual controls
  - Test: Pause menu hides virtual controls
  - Test: Scene transition keeps virtual controls visible
  - Test: Drag-to-reposition saves position to Redux
  - Test: Settings persistence (save/load control positions)
  - Integration test file: `test_touchscreen_input_flow.gd`

**Task 6.9**: Manual QA (Desktop Emulation) (1-2 hours) - COMPLETE
  - Enable emulation mode + touch from mouse
  - Verify joystick movement (click-drag)
  - Verify button presses (click)
  - Verify auto-hide on gamepad connect
  - Verify visibility during pause/transitions (full recheck moves to post-reposition QA)
  - Drag-to-reposition saves positions → deferred to Phase 6R after drag/save code lands
  - Reset to defaults button → deferred to Phase 6R with post-reposition QA

**Task 6.10**: Create TouchscreenSettingsOverlay (3-4 hours, TDD) - NEW (Gap Fill)
  - Full settings overlay with sliders for size, opacity, deadzone
  - Live preview visualization (like GamepadSettingsOverlay)
  - Apply/Cancel/Reset buttons
  - Wire to Scene Registry + Pause Menu
  - Unit tests for slider updates, apply/reset functionality

**Task 6.11**: Create EditTouchControlsOverlay (2-3 hours, TDD) - NEW (Gap Fill)
  - Overlay for toggling drag mode on/off
  - Visual feedback: grid overlay, snap-to-grid guidelines
  - Save/Reset/Cancel buttons
  - Wire to TouchscreenSettingsOverlay
  - Unit tests for drag mode toggle, position save/reset

**Post-Reposition QA (Phase 6R) - NEW (after 6.10/6.11)**
  - Run device QA tasks 6.9.5-6.9.7 after TouchscreenSettingsOverlay + EditTouchControlsOverlay ship
  - Re-verify pause-menu hide, drag-to-reposition persistence, and reset-to-defaults flows on device/emulation

**Task 6.12**: Add HUD Safe Area Margins (1 hour, TDD) - NEW (Gap Fill)
  - Calculate safe margins (bottom 150px, sides 200px)
  - Apply to health bar, checkpoint toast, interact prompt
  - Conditional: only on mobile or emulation mode
  - Unit tests for margin calculation and application

**Task 6.13**: Add Save File Migration Test (1 hour, TDD) - NEW (Gap Fill)
  - Test Phase 5 → Phase 6 save file compatibility
  - Verify new touchscreen fields populate with defaults
  - Test save roundtrip with custom positions
  - Integration test for migration validation

**Task 6.14**: Add Automated Performance Test (1-2 hours, TDD) - NEW (Gap Fill)
  - Simulate heavy input load (60 iterations)
  - Measure frame time (target < 16.67ms avg)
  - Assert no frames exceed 20ms threshold
  - Log performance stats for debugging

**Duration**: 24-30 hours (was 16-22, +8 hours for gap-fill tasks)
**Commits**: 14 commits (was 9, +5 for new overlays, safe margins, migration, performance)

---

## Phase 7: Polish, Performance, Documentation (8-12 hours)

### Tasks Overview (Phase 7)

**Task 7.1**: Input Latency Benchmarking (1-2 hours) - FR-116, SC-002
**Task 7.2**: Profile Switching Performance Validation (1 hour) - FR-117, SC-003
**Task 7.3**: Code Coverage Validation (1 hour) - FR-128, SC-005
**Task 7.4**: Accessibility Features Polish (2-3 hours) - FR-110, FR-111, FR-112, FR-113
**Task 7.5**: Complete Button Prompt Asset Set (1-2 hours) - FR-067
**Task 7.6**: API Documentation (1-2 hours) - SC-015
**Task 7.7**: Create Quickstart Guide (1-2 hours) - SC-016
**Task 7.8**: Final Integration Testing (1 hour) - SC-017
**Task 7.9**: Update AGENTS.md and DEV_PITFALLS.md (30 min)

**Duration**: 8-12 hours
**Commits**: 5 commits (polish, docs, final validation)

---

## Integration Details

### How Input Manager Integrates with Scene Manager

**Input Blocking During Transitions** (FR-009):
- S_InputSystem checks `M_SceneManager.is_transitioning()` before processing input
- If transitioning, skip input capture entirely (no move_vector, no jump, no dispatch)
- Implementation:
  ```gdscript
  func process_tick(delta: float) -> void:
    var scene_manager := get_tree().get_first_node_in_group("scene_manager") as M_SceneManager
    if scene_manager and scene_manager.is_transitioning():
      return  # Block input during transitions

    # Normal input capture...
  ```

**Input Buffer Flushing on Transition Start** (FR-108):
- When scene transition begins, clear all input buffers (jump_buffer_timestamp = 0.0)
- Prevents buffered inputs from previous scene carrying over
- Implementation via signal connection:
  ```gdscript
  func _ready() -> void:
    var scene_manager := get_tree().get_first_node_in_group("scene_manager") as M_SceneManager
    if scene_manager:
      scene_manager.transition_started.connect(_on_transition_started)

  func _on_transition_started() -> void:
    for component in get_components(C_InputComponent.COMPONENT_TYPE):
      component.jump_buffer_timestamp = 0.0  # Clear buffer
  ```

**Settings Persistence via StateHandoff** (FR-078):
- Input settings slice persists across scene transitions via existing StateHandoff mechanism
- M_InputProfileManager reloads active profile on scene load
- No modifications required to Scene Manager

**Virtual Controls Per-Scene Instantiation**:
- mobile_controls.tscn instantiated only on mobile platforms
- Added to gameplay scenes, not main.tscn (per-scene UI)
- S_TouchscreenSystem queries virtual controls in current scene

**No Scene Manager Modifications Required**: Input Manager is purely additive, uses existing is_transitioning() check

---

### How Input Manager Integrates with State Store (Redux)

**Action Dispatch Every Physics Frame** (FR-006, FR-075):
- S_InputSystem dispatches input actions to M_StateStore in process_tick():
  ```gdscript
  _state_store.dispatch(U_InputActions.update_move_input(move_vector))
  _state_store.dispatch(U_InputActions.update_look_input(look_delta))
  _state_store.dispatch(U_InputActions.update_jump_state(jump_pressed, jump_just_pressed))
  _state_store.dispatch(U_InputActions.update_sprint_state(sprint_pressed))
  ```

**State Persistence via StateHandoff** (FR-078):
- Settings slice (input_settings) marked as persistent → saved to disk via M_StateStore.save_state()
- Gameplay slice (input) marked as transient → excluded from saves
- StateHandoff preserves settings across scene transitions

**State Queries via Selectors** (FR-077):
- Systems and UI query input state via U_InputSelectors:
  ```gdscript
  var state := _state_store.get_state()
  var active_device := U_InputSelectors.get_active_device(state)
  var mouse_sensitivity := U_InputSelectors.get_mouse_settings(state).sensitivity
  ```

**Dual Slices** (FR-073, FR-074):
- **Gameplay slice (transient)**: Runtime input state (move_input, active_device, gamepad_connected)
- **Settings slice (persistent)**: Input settings (active_profile_id, custom_bindings, gamepad_settings, mouse_settings, touchscreen_settings, accessibility)

**No Conflicts with Existing Redux Patterns**: Input actions follow ActionRegistry pattern, reducers follow immutable update pattern, selectors follow query pattern

---

### How Input Manager Integrates with ECS Manager

**Component Registration via Auto-Registration** (FR-081, FR-087):
- C_InputComponent and C_GamepadComponent extend ECSComponent
- Define COMPONENT_TYPE constant: `const COMPONENT_TYPE := StringName("C_InputComponent")`
- Call `component_type = COMPONENT_TYPE` in _init()
- Auto-register with M_ECSManager on _ready() (no manual wiring)

**System Discovery via Parent Traversal** (FR-086):
- S_InputSystem and S_TouchscreenSystem extend ECSSystem
- Auto-discover M_ECSManager via parent traversal or "ecs_manager" group
- No manual manager assignment required

**Component Queries using COMPONENT_TYPE** (FR-085):
- Systems query components via M_ECSManager.get_components(COMPONENT_TYPE):
  ```gdscript
  var components := get_components(C_InputComponent.COMPONENT_TYPE)
  for component in components:
    component.move_vector = move_input
    component.jump_pressed = jump_pressed
  ```

**System Execution in _physics_process** (FR-088):
- Systems implement process_tick(delta) method
- M_ECSManager calls process_tick() in _physics_process() (60Hz tick)
- Consistent timing with existing systems (S_GravitySystem, S_MovementSystem)

**Pattern Consistency with Existing Systems**: Input Manager follows exact same patterns as Scene Manager and existing ECS systems (auto-registration, discovery, query, process_tick)

---

### How Input Manager Integrates with Cursor Manager

**Mouse Delta Processing Only When Cursor Captured** (FR-008):
- S_InputSystem checks M_CursorManager cursor capture mode before processing mouse delta
- Implementation:
  ```gdscript
  func process_tick(delta: float) -> void:
    var cursor_manager := get_tree().get_first_node_in_group("cursor_manager") as M_CursorManager
    var is_captured := false
    if cursor_manager:
      is_captured = (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)

    if is_captured:
      # Process mouse delta for look input
      look_delta = _mouse_delta * _mouse_sensitivity
      _mouse_delta = Vector2.ZERO  # Reset delta after reading
    else:
      look_delta = Vector2.ZERO  # No look input when cursor visible
  ```

**Pause Toggle Handled by M_CursorManager**:
- M_CursorManager owns pause action and cursor mode toggling
- S_InputSystem does NOT handle pause action (avoids conflict)
- M_CursorManager emits cursor_state_changed signal when mode changes

**Authority Separation**:
- **M_CursorManager**: Owns cursor mode (captured/visible), handles pause toggle
- **S_InputSystem**: Reads cursor mode via Input.mouse_mode, processes input accordingly
- No conflicts via Input.mouse_mode coordination (single source of truth)

**No M_CursorManager Modifications Required**: Input Manager reads existing state, does not modify cursor management

---

### How Input Manager Integrates with UI System

**Button Prompts via U_ButtonPromptRegistry** (FR-066, FR-068):
- HUD queries U_ButtonPromptRegistry.get_prompt(action, device) to get button icon
- Returns Texture2D for display (e.g., key_space.png, button_a.png)
- Falls back to text label if icon missing: `U_ButtonPromptRegistry.get_prompt_text(action, device)`
- Example:
  ```gdscript
  var device := U_InputSelectors.get_active_device(state)
  var jump_icon := U_ButtonPromptRegistry.get_prompt(StringName("jump"), device)
  $JumpPrompt/Icon.texture = jump_icon
  ```

**Virtual Controls as UI Nodes** (FR-046, FR-047, FR-048):
- VirtualJoystick and VirtualButton are Control nodes in mobile_controls.tscn
- Positioned in CanvasLayer (always on top of gameplay)
- S_TouchscreenSystem queries these nodes and updates C_InputComponent
- Virtual controls only handle visualization and touch input emission (no game logic)

**Settings UI Calls Input Manager APIs** (FR-014, FR-021):
- Input settings UI (profile dropdown, rebind buttons, sensitivity sliders) calls manager methods:
  - `M_InputProfileManager.switch_profile(profile_path)`
  - `U_InputRebindUtils.rebind_action(action, event, profile)`
  - Dispatch settings actions via M_StateStore
- UI is thin layer with minimal logic (calls managers, displays state)

**Button Prompt Updates on Device Change** (FR-069, FR-070):
- HUD subscribes to M_InputDeviceManager.device_changed signal
- On signal, refresh all button prompts (query U_ButtonPromptRegistry with new device)
- Update completes within one frame (texture swap is fast)

**UI as Thin Layer with Minimal Logic**: All input logic lives in managers, systems, utilities. UI only calls APIs and displays results.

---

### No Autoloads Pattern

**Manager Discovery via Groups** (FR-089, FR-090, FR-091):
- M_InputProfileManager adds to "input_profile_manager" group in _ready()
- M_InputDeviceManager adds to "input_device_manager" group in _ready()
- Systems find managers via `get_tree().get_first_node_in_group("input_profile_manager")`
- Pattern consistent with existing managers (M_StateStore: "state_store", M_SceneManager: "scene_manager")

**Main.tscn Structure** (FR-089, FR-090):
```
main.tscn
├── M_StateStore (existing)
├── M_SceneManager (existing)
├── M_CursorManager (existing)
├── M_InputProfileManager (NEW)
├── M_InputDeviceManager (NEW)
├── ActiveSceneContainer (existing)
├── UIOverlayStack (existing)
├── TransitionOverlay (existing)
└── LoadingOverlay (existing)
```

**No project.godot Autoload Section**: All managers are in-scene nodes, discoverable via groups

---

## Complete Implementation Examples

### Example 1: Profile Switching Workflow (Complete Code)

```gdscript
# How to switch input profile from UI

# In UI script (e.g., input_settings_menu.gd):
extends Control

func _ready() -> void:
	# Populate profile dropdown
	$ProfileDropdown.add_item("Default")
	$ProfileDropdown.add_item("Alternate")
	$ProfileDropdown.add_item("Accessibility")
	$ProfileDropdown.add_item("Gamepad (Generic)")

	# Connect signal
	$ProfileDropdown.item_selected.connect(_on_profile_selected)

func _on_profile_selected(index: int) -> void:
	var profile_names := ["default", "alternate", "accessibility", "gamepad_generic"]
	var profile_id := profile_names[index]
	var profile_path := "res://resources/input_profiles/%s.tres" % profile_id

	# Find manager via group
	var manager := get_tree().get_first_node_in_group("input_profile_manager") as M_InputProfileManager
	if manager:
		manager.switch_profile(profile_path)
		print("Switched to profile: %s" % profile_id)
	else:
		push_error("M_InputProfileManager not found in scene tree")
```

---

### Example 2: Rebinding Workflow (Complete Code)

```gdscript
# How to rebind an action with conflict detection

# In rebind UI script (e.g., rebind_button.gd):
extends Button

@export var action_to_rebind: StringName = StringName("jump")

var _waiting_for_input := false

func _ready() -> void:
	pressed.connect(_on_button_pressed)

func _on_button_pressed() -> void:
	_waiting_for_input = true
	text = "Press any key..."

func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return

	# Only accept key presses for rebinding (extend for gamepad)
	if not (event is InputEventKey and event.pressed):
		return

	_waiting_for_input = false
	get_viewport().set_input_as_handled()  # Consume event

	# Validate rebind
	var rebind_settings := load("res://resources/input/default_rebind_settings.tres") as RS_RebindSettings
	var validation := U_InputRebindUtils.validate_rebind(action_to_rebind, event, rebind_settings)

	if not validation.valid:
		# Show error dialog
		$ErrorDialog.dialog_text = validation.error
		$ErrorDialog.popup_centered()
		text = "Rebind [%s]" % action_to_rebind
		return

	if validation.conflict_action != StringName():
		# Show conflict dialog
		$ConfirmDialog.dialog_text = "Already bound to '%s'. Replace?" % validation.conflict_action
		$ConfirmDialog.confirmed.connect(func(): _apply_rebind(event, validation.conflict_action))
		$ConfirmDialog.canceled.connect(func(): text = "Rebind [%s]" % action_to_rebind)
		$ConfirmDialog.popup_centered()
	else:
		# No conflict, apply directly
		_apply_rebind(event, StringName())

func _apply_rebind(event: InputEvent, conflict_action: StringName) -> void:
	# Get current profile
	var manager := get_tree().get_first_node_in_group("input_profile_manager") as M_InputProfileManager
	var profile := manager.active_profile

	# Apply rebind
	var success := U_InputRebindUtils.rebind_action(action_to_rebind, event, profile)
	if success:
		text = "[%s]" % OS.get_keycode_string(event.keycode)

		# Save custom bindings
		var store := U_StateUtils.get_store(self)
		var binding_dict := {
			"type": "key",
			"keycode": event.keycode
		}
		store.dispatch(U_InputActions.rebind_action(action_to_rebind, [binding_dict]))
	else:
		text = "Rebind failed"
```

---

### Example 3: Device Detection Implementation (Complete Code)

```gdscript
# M_InputDeviceManager device detection logic

class_name M_InputDeviceManager extends Node

signal device_changed(device_type: DeviceType)

enum DeviceType { KEYBOARD_MOUSE, GAMEPAD, TOUCHSCREEN }

var active_device := DeviceType.KEYBOARD_MOUSE
var last_input_time := 0.0
var gamepad_device_id := -1

var _state_store: M_StateStore = null

func _ready() -> void:
	add_to_group("input_device_manager")
	await get_tree().process_frame
	_state_store = U_StateUtils.get_store(self)

	# Check for connected gamepads on startup
	var joypads := Input.get_connected_joypads()
	if joypads.size() > 0:
		gamepad_device_id = joypads[0]
		print("Gamepad detected on startup: device_id=%d" % gamepad_device_id)

func _input(event: InputEvent) -> void:
	var new_device := active_device

	# Classify input event
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
		new_device = DeviceType.KEYBOARD_MOUSE
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_device = DeviceType.GAMEPAD
		# Update active gamepad device_id
		if event is InputEventJoypadButton:
			gamepad_device_id = event.device
		elif event is InputEventJoypadMotion:
			gamepad_device_id = event.device
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		new_device = DeviceType.TOUCHSCREEN

	# Switch if device changed
	if new_device != active_device:
		_switch_device(new_device)

func _switch_device(new_device: DeviceType) -> void:
	active_device = new_device
	last_input_time = U_ECSUtils.get_current_time()

	# Dispatch to state store
	_state_store.dispatch(U_InputActions.device_changed(new_device, gamepad_device_id))

	# Emit signal for UI updates
	device_changed.emit(new_device)

	print("Input device switched to: %s" % DeviceType.keys()[new_device])

func get_active_device() -> DeviceType:
	return active_device

func get_gamepad_device_id() -> int:
	return gamepad_device_id

func is_gamepad_connected() -> bool:
	return Input.get_connected_joypads().size() > 0
```

---

### Example 4: Virtual Joystick Setup (Complete Code)

```gdscript
# VirtualJoystick UI component for mobile

class_name VirtualJoystick extends Control

signal joystick_moved(direction: Vector2)

@export var joystick_radius := 100.0
@export var deadzone := 0.2

var _touch_index := -1
var _center_position := Vector2.ZERO
var _current_position := Vector2.ZERO

func _ready() -> void:
	# Only show on mobile
	visible = OS.has_feature("mobile")

func _input(event: InputEvent) -> void:
	if not visible:
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			# First touch starts joystick
			if _touch_index == -1:
				_touch_index = event.index
				_center_position = event.position
				_current_position = event.position
				modulate.a = 1.0  # Full opacity when active
		else:
			# Release resets joystick
			if event.index == _touch_index:
				_touch_index = -1
				_center_position = Vector2.ZERO
				_current_position = Vector2.ZERO
				modulate.a = 0.5  # Half opacity when inactive
				joystick_moved.emit(Vector2.ZERO)

	elif event is InputEventScreenDrag:
		if event.index == _touch_index:
			_current_position = event.position

func _process(delta: float) -> void:
	if _touch_index == -1:
		return

	# Calculate direction
	var offset := _current_position - _center_position
	var distance := offset.length()

	# Clamp to joystick radius
	if distance > joystick_radius:
		offset = offset.normalized() * joystick_radius
		distance = joystick_radius

	# Apply deadzone
	var normalized_distance := distance / joystick_radius
	if normalized_distance < deadzone:
		joystick_moved.emit(Vector2.ZERO)
		return

	# Remap distance above deadzone to 0.0-1.0
	var remapped_distance := (normalized_distance - deadzone) / (1.0 - deadzone)
	var direction := offset.normalized() * remapped_distance

	joystick_moved.emit(direction)

	# Update visual (optional: draw stick position)
	queue_redraw()

func _draw() -> void:
	if _touch_index == -1:
		# Draw base circle
		draw_circle(Vector2.ZERO, joystick_radius, Color(1, 1, 1, 0.3))
	else:
		# Draw base circle
		draw_circle(Vector2.ZERO, joystick_radius, Color(1, 1, 1, 0.5))
		# Draw stick position
		var offset := _current_position - _center_position
		draw_circle(offset, 30.0, Color(1, 1, 1, 0.8))
```

---

### Example 5: Gamepad Vibration Integration (Complete Code)

```gdscript
# How to trigger gamepad vibration from gameplay system

# In a system that detects landing (e.g., S_LandingSystem):
extends ECSSystem

func process_tick(delta: float) -> void:
	var components := get_components(C_LandingComponent.COMPONENT_TYPE)

	for component in components:
		if component.just_landed:
			# Trigger vibration on landing
			_apply_landing_vibration(component.landing_velocity.y)

func _apply_landing_vibration(fall_speed: float) -> void:
	# Find M_InputDeviceManager
	var device_manager := get_tree().get_first_node_in_group("input_device_manager") as M_InputDeviceManager
	if not device_manager:
		return

	# Only vibrate if gamepad is active device
	if device_manager.get_active_device() != M_InputDeviceManager.DeviceType.GAMEPAD:
		return

	# Get gamepad device_id
	var device_id := device_manager.get_gamepad_device_id()
	if device_id == -1:
		return

	# Check if vibration enabled in settings
	var store := U_StateUtils.get_store(self)
	var state := store.get_state()
	var gamepad_settings := U_InputSelectors.get_gamepad_settings(state)
	if not gamepad_settings.get("vibration_enabled", true):
		return

	# Calculate vibration strength based on fall speed
	var intensity := gamepad_settings.get("vibration_intensity", 1.0)
	var weak := clamp(abs(fall_speed) / 20.0, 0.0, 1.0) * intensity
	var strong := weak * 0.5  # Less strong motor for landing
	var duration := 0.2  # 200ms vibration

	# Trigger vibration
	Input.start_joy_vibration(device_id, weak, strong, duration)
	print("Landing vibration: weak=%.2f, strong=%.2f, duration=%.2f" % [weak, strong, duration])
```

---

## Edge Cases & Validation

### Edge Case 1: Rebind Conflict When Key Already Bound

**Scenario**: Player attempts to rebind "jump" to "W", but "W" is already bound to "move_forward"

**Expected Behavior**:
1. U_InputRebindUtils.validate_rebind() detects conflict
2. Returns `{valid: true, error: "", conflict_action: StringName("move_forward")}`
3. UI shows warning dialog: "Already bound to 'move_forward'. Replace?"
4. Player confirms → swap bindings ("jump" → "W", "move_forward" loses "W")
5. Player cancels → abort rebind, restore original binding

**Test Strategy**:
- Unit test in test_u_input_rebind_utils.gd
- Integration test in test_rebinding_workflow.gd

---

### Edge Case 2: Gamepad Disconnects Mid-Game

**Scenario**: Player using gamepad, gamepad battery dies or USB unplugged during gameplay

**Expected Behavior**:
1. M_InputDeviceManager detects no more InputEventJoypad events
2. Gamepad disconnect signal received (if hardware supports it)
3. Dispatch ACTION_GAMEPAD_DISCONNECTED to store
4. Auto-switch to KEYBOARD_MOUSE device type
5. HUD button prompts update to keyboard icons
6. Gameplay continues without interruption (player can use keyboard immediately)

**Test Strategy**:
- Integration test in test_gamepad_connection_flow.gd
- Mock gamepad disconnect via Input.joy_connection_changed signal

---

### Edge Case 3: Player Attempts to Rebind Reserved Action

**Scenario**: Player tries to rebind "pause" action (reserved for emergency menu access)

**Expected Behavior**:
1. U_InputRebindUtils.validate_rebind() checks reserved actions list
2. Returns `{valid: false, error: "Cannot rebind reserved action 'pause'", conflict_action: StringName()}`
3. UI shows error dialog: "Cannot rebind reserved action 'pause'"
4. Rebind aborted, original binding preserved

**Test Strategy**:
- Unit test in test_u_input_rebind_utils.gd
- Verify reserved actions: "pause", "toggle_debug_overlay"

---

### Edge Case 4: Save File Contains Invalid Custom Bindings

**Scenario**: Player manually edits user://input_settings.json, introduces invalid keycode or malformed dictionary

**Expected Behavior**:
1. M_InputProfileManager.load_settings() attempts to parse JSON
2. Validation detects invalid keycode (e.g., keycode: -1, keycode: 999999)
3. Log error: "Invalid custom binding for action 'jump': keycode=-1"
4. Skip invalid binding, load remaining valid bindings
5. If entire save corrupted, log error, backup corrupted file, load defaults

**Test Strategy**:
- Unit test in test_input_profile_manager.gd
- Test corrupted JSON, invalid keycodes, missing required fields

---

### Edge Case 5: Multiple Gamepads Connected

**Scenario**: Player has 2 gamepads connected (e.g., Xbox controller + PlayStation controller)

**Expected Behavior**:
1. M_InputDeviceManager detects multiple gamepads via Input.get_connected_joypads()
2. Use first gamepad that sends input (device_id = 0 by default)
3. If player switches to second gamepad, detect via InputEventJoypad.device property
4. Update gamepad_device_id to match active gamepad
5. Vibration targets active gamepad only

**Test Strategy**:
- Integration test in test_gamepad_connection_flow.gd
- Mock multiple gamepad inputs with different device_ids

---

### Edge Case 6: Touchscreen and Gamepad Both Provide Input on Mobile

**Scenario**: Player on mobile device with Bluetooth gamepad connected, touches screen while using gamepad

**Expected Behavior**:
1. M_InputDeviceManager receives both InputEventScreenTouch and InputEventJoypad events
2. Last input determines active device (most recent input event)
3. If gamepad input last → hide virtual controls, active_device = GAMEPAD
4. If touchscreen input last → show virtual controls, active_device = TOUCHSCREEN
5. Both inputs processed, but HUD prompts reflect active device

**Test Strategy**:
- Integration test in test_device_handoff_flow.gd
- Test virtual control visibility toggling based on active device

---

### Edge Case 7: Player Triggers Rebind But Presses ESC to Cancel

**Scenario**: Player clicks "Rebind" button for "jump", UI waits for input, player presses ESC

**Expected Behavior**:
1. Rebind UI enters "waiting for input" mode
2. Player presses ESC key
3. Rebind UI detects ESC (reserved action for pause)
4. Treat ESC as cancel signal (don't rebind to ESC)
5. Restore button text to "Rebind [jump]"
6. No changes to InputMap, original binding preserved

**Test Strategy**:
- Integration test in test_rebinding_workflow.gd
- Verify ESC cancels rebind instead of binding to ESC

---

### Edge Case 8: Input Actions Missing from InputMap

**Scenario**: Fresh project, InputMap doesn't have all required actions defined

**Expected Behavior**:
1. M_InputProfileManager.switch_profile() attempts to apply mappings
2. Check if action exists in InputMap via InputMap.has_action(action)
3. If missing, log warning and auto-initialize:
   ```gdscript
   if not InputMap.has_action(action):
     InputMap.add_action(action)
     push_warning("Auto-initialized missing action: %s" % action)
   ```
4. Apply mappings to newly-created action
5. Game continues without crash

**Test Strategy**:
- Unit test in test_input_profile_manager.gd
- Test profile application with empty InputMap

---

### Edge Case 9: Analog Stick Input Below Deadzone Threshold

**Scenario**: Player's gamepad analog stick drifts slightly (analog value 0.05 when centered)

**Expected Behavior**:
1. S_InputSystem receives InputEventJoypadMotion with axis_value = 0.05
2. Apply deadzone filtering (default 0.2):
   ```gdscript
   if abs(axis_value) < deadzone:
     axis_value = 0.0  # Snap to zero
   ```
3. move_vector remains Vector2.ZERO (no movement)
4. Player character doesn't drift due to stick noise

**Test Strategy**:
- Unit test in test_s_input_system.gd (if extended for gamepad)
- Test analog values below/above deadzone threshold

---

### Edge Case 10: Player Rapidly Switches Profiles During Gameplay

**Scenario**: Player opens settings, rapidly clicks profile dropdown 5 times in 1 second

**Expected Behavior**:
1. First profile switch starts, clears InputMap, applies mappings (< 200ms)
2. Second profile switch requested before first completes
3. Queue second switch or ignore duplicate requests (implementation choice)
4. Prevent InputMap corruption from overlapping switches
5. Final profile applied correctly, game state consistent

**Test Strategy**:
- Integration test in test_profile_switching_flow.gd
- Test rapid profile switches (5 switches in 1 second)

---

### Edge Case 11: Virtual Joystick Positioned Under Player's Finger

**Scenario**: Player touches screen to activate virtual joystick, joystick appears under finger (obscures view)

**Expected Behavior**:
1. VirtualJoystick appears at touch point (centered on finger)
2. Joystick has semi-transparent background (opacity 0.7 default)
3. Player can see through joystick to gameplay underneath
4. Joystick repositions if player drags finger outside radius (optional)
5. No view obscuring, gameplay visible

**Test Strategy**:
- Manual test on physical mobile device
- Verify joystick opacity setting effective

---

### Edge Case 12: Input Buffering Carries Over Scene Transition

**Scenario**: Player presses jump before scene transition completes, buffer should clear

**Expected Behavior**:
1. Player presses jump at t=0.0s
2. Scene transition starts at t=0.05s
3. Jump buffer timestamp = 0.0s (within 0.1s buffer window)
4. S_InputSystem detects M_SceneManager.is_transitioning() → clears buffer
5. New scene loads at t=0.5s
6. Jump buffer cleared, no unexpected jump in new scene

**Test Strategy**:
- Integration test in test_input_during_scene_transition.gd
- Verify buffers cleared on transition start signal

---

### Edge Case 13: Button Prompt Assets Missing for Active Device

**Scenario**: Player switches to gamepad, but gamepad button prompt assets not imported

**Expected Behavior**:
1. M_InputDeviceManager.device_changed signal emits (GAMEPAD)
2. HUD calls U_ButtonPromptRegistry.get_prompt(StringName("jump"), DeviceType.GAMEPAD)
3. Registry attempts to load "res://resources/button_prompts/gamepad/button_a.png"
4. Load fails (file missing)
5. Fall back to text label: U_ButtonPromptRegistry.get_prompt_text(StringName("jump"), DeviceType.GAMEPAD)
6. Returns "A" (text fallback)
7. HUD shows "[A]" text instead of icon, no crash

**Test Strategy**:
- Unit test in test_u_button_prompt_registry.gd
- Test missing asset files, verify text fallback

---

## Success Criteria

**Technical Success** (ALL MUST PASS):
- [ ] All 136 functional requirements implemented (FR-001 through FR-136)
- [ ] All 7 user stories have passing acceptance tests
- [ ] All 22 success criteria met (SC-001 through SC-022):
  - [ ] SC-001: 100% of target input devices supported (keyboard, mouse, gamepad, touchscreen)
  - [ ] SC-002: Input latency < 16ms (one frame @ 60 FPS)
  - [ ] SC-003: Profile switching < 200ms
  - [ ] SC-004: Custom bindings save/load < 100ms
  - [ ] SC-005: 90%+ code coverage for all input systems
  - [ ] SC-006: Zero input drop during stress test (100 inputs/sec for 60 seconds)
  - [ ] SC-007: Rebind conflict detection 100% accurate
  - [ ] SC-008: Device auto-detection 100% accurate within one frame
  - [ ] SC-009: Mobile virtual controls maintain 60 FPS
  - [ ] SC-010: Gamepad vibration latency < 50ms
  - [ ] SC-011: All input components extend ECSComponent
  - [ ] SC-012: All input systems extend ECSSystem
  - [ ] SC-013: All input state managed via Redux patterns
  - [ ] SC-014: Zero Godot autoloads added
  - [ ] SC-015: API documentation 100% complete with GDScript doc comments
  - [ ] SC-016: 5+ complete implementation examples
  - [ ] SC-017: Integration tests demonstrate full input flow
  - [ ] SC-018: 95%+ rebind attempts succeed
  - [ ] SC-019: Device switching feels seamless
  - [ ] SC-020: Virtual controls perceived latency < 100ms
  - [ ] SC-021: Accessibility profiles enable comfortable play
  - [ ] SC-022: Button prompts always show correct input
- [ ] Zero Godot autoloads added (managers in main.tscn with group discovery)
- [ ] All tests passing (22 new tests: 14 unit + 8 integration)
- [ ] No regressions (all baseline tests still pass)

**User Experience Success** (ALL MUST PASS):
- [ ] Players can use keyboard, mouse, gamepad, or touchscreen seamlessly
- [ ] Input feels responsive (< 16ms latency, no dropped inputs)
- [ ] Profile switching completes quickly (< 200ms)
- [ ] Rebinding works intuitively with clear conflict warnings
- [ ] Device switching automatic (no manual selection needed)
- [ ] Button prompts always accurate for active device
- [ ] Mobile virtual controls comfortable and responsive
- [ ] Accessibility profiles enable play for users with motor impairments

**Documentation Success** (ALL MUST PASS):
- [ ] PRD complete and accurate (136 FRs, 22 SCs documented)
- [ ] Plan document tracks all 8 phases with detailed tasks
- [ ] research.md documents Phase 0 prototyping findings
- [ ] API documentation complete (## doc comments on all public methods, @export fields, signals)
- [ ] 5+ complete implementation examples in plan
- [ ] AGENTS.md updated with Input Manager patterns
- [ ] DEV_PITFALLS.md updated with input-specific pitfalls discovered

---

## Commit-by-Commit Strategy

**Total Commits**: ~30 commits across 8 phases

### Phase 0 Commits (1 commit)
1. Phase 0 complete: research findings, prototypes, architecture validation

### Phase 1 Commits (4 commits)
2. Input actions and selectors with tests (TDD)
3. Gameplay and settings reducers for input with tests (TDD)
4. S_InputSystem state dispatch and mouse sensitivity
5. Phase 1 complete: integration tests and validation

### Phase 2 Commits (6 commits)
6. RS_InputProfile resource with tests
7. 4 default input profiles (default, alternate, accessibility, gamepad)
8. M_InputProfileManager with profile switching < 200ms
9. M_InputProfileManager added to main.tscn
10. Profile selection UI with dropdown
11. Phase 2 complete: integration tests and validation

### Phase 3 Commits (6 commits)
12. RS_GamepadSettings resource with tests
13. C_GamepadComponent with tests
14. S_InputSystem gamepad input handling with tests
15. Gamepad vibration support with tests
16. Gamepad connect/disconnect handling with tests
17. Phase 3 complete: gamepad settings UI and integration tests

### Phase 4 Commits (6 commits)
18. M_InputDeviceManager with device detection tests
19. Device detection logic with tests
20. U_ButtonPromptRegistry with tests
21. Button prompt assets (keyboard + gamepad icons)
22. HUD button prompt integration
23. Phase 4 complete: M_InputDeviceManager added to main.tscn and integration tests

### Phase 5 Commits (6 commits)
24. RS_RebindSettings resource with tests
25. U_InputRebindUtils with validation tests
26. Rebinding UI with conflict detection
27. Input settings persistence (save/load) with tests
28. Custom bindings load/save with tests
29. Phase 5 complete: reset to default and integration tests

### Phase 6 Commits (6 commits)
30. VirtualJoystick UI component with tests
31. VirtualButton UI component with tests
32. S_TouchscreenSystem with tests
33. mobile_controls.tscn scene
34. Virtual controls visibility logic with tests
35. Phase 6 complete: screen rotation handling and integration tests

### Phase 7 Commits (5 commits)
36. Input latency benchmarking and performance validation
37. Accessibility features polish and complete button prompt asset set
38. API documentation complete (doc comments)
39. Quickstart guide and AGENTS.md/DEV_PITFALLS.md updates
40. Phase 7 complete: final integration tests and project validation

**Commit Guidelines**:
- ⚠️ NEVER commit if ANY test fails (fix before committing)
- ⚠️ Run full test suite before EVERY commit (ensure no regressions)
- ⚠️ Each commit message includes:
  - Phase and task number (e.g., "Phase 2.3: M_InputProfileManager...")
  - Brief description of changes
  - Files created/modified
  - Test status (e.g., "All tests passing: 345/345")
  - Claude Code signature
- ⚠️ Test-green requirement: All tests must pass before commit (100% pass rate)
- ⚠️ Regression validation: Baseline test count must not decrease (only increase with new tests)

---

## Testing Strategy (Expanded)

### Unit Test Files (14 tests, ~1800 lines total)

1. **test_u_input_actions.gd** (~150 lines) - **Satisfies FR-129**
   - Test all 14 action creators return correct action dictionaries
   - Test ActionRegistry registration in _static_init()
   - Test action type constants are StringName

2. **test_u_input_selectors.gd** (~120 lines) - **Satisfies FR-129**
   - Test selectors return correct values from state
   - Test selectors handle missing fields gracefully

3. **test_input_reducer.gd** (~200 lines) - **Satisfies FR-129**
   - Test reducer handles all 14 input action types
   - Test immutable updates (original state unchanged)
   - Test transient fields excluded from persistence

4. **test_rs_input_profile.gd** (~100 lines) - **Satisfies FR-129**
   - Test profile resource creation and save/load
   - Test action_mappings dictionary structure

5. **test_input_profile_manager.gd** (~150 lines) - **Satisfies FR-131**
   - Test profile loading from .tres file
   - Test profile switching updates InputMap
   - Test profile switching completes < 200ms
   - Test manager adds to group

6. **test_rs_gamepad_settings.gd** (~80 lines) - **Satisfies FR-129**
   - Test gamepad settings resource
   - Test deadzone, vibration settings

7. **test_gamepad_component.gd** (~120 lines) - **Satisfies FR-129**
   - Test C_GamepadComponent properties
   - Test COMPONENT_TYPE constant
   - Test auto-registration

8. **test_input_device_manager.gd** (~150 lines) - **Satisfies FR-131**
   - Test device detection logic
   - Test device switching signal emission
   - Test manager adds to group

9. **test_u_input_rebind_utils.gd** (~200 lines) - **Satisfies FR-132**
   - Test rebind validation (conflict detection, reserved actions)
   - Test rebind application to InputMap
   - Test reset to default

10. **test_u_button_prompt_registry.gd** (~100 lines) - **Satisfies FR-132**
    - Test prompt lookup by action and device
    - Test text fallback when asset missing

11. **test_virtual_joystick.gd** (~150 lines) - **Satisfies FR-129**
    - Test touch input handling
    - Test deadzone filtering
    - Test joystick movement signal

12. **test_virtual_button.gd** (~100 lines) - **Satisfies FR-129**
    - Test button press detection
    - Test button release signal

13. **test_s_touchscreen_system.gd** (~150 lines) - **Satisfies FR-130**
    - Test system queries virtual controls
    - Test C_InputComponent update from virtual controls

14. **test_rs_rebind_settings.gd** (~80 lines) - **Satisfies FR-129**
    - Test rebind settings resource
    - Test reserved actions list

**Total Unit Test Lines**: ~1800 lines

---

### Integration Test Files (8 tests, ~1200 lines total)

1. **test_profile_switching_flow.gd** (~150 lines) - **Satisfies FR-133**
   - Test end-to-end profile switching
   - Test InputMap reflects profile mappings
   - Test buffer windows and deadzones applied

2. **test_device_handoff_flow.gd** (~150 lines) - **Satisfies FR-134**
   - Test device switching with button prompt updates
   - Test seamless gameplay during device switch

3. **test_rebinding_workflow.gd** (~200 lines) - **Satisfies FR-135**
   - Test complete rebind process (UI capture, validation, application)
   - Test conflict detection and resolution
   - Test reserved action protection

4. **test_input_persistence.gd** (~150 lines) - **Satisfies FR-136**
   - Test settings save to user://input_settings.json
   - Test settings load on game start
   - Test StateHandoff across scene transitions

5. **test_virtual_controls_visibility.gd** (~100 lines)
   - Test virtual controls show on mobile (OS.has_feature("mobile"))
   - Test virtual controls hide when gamepad connected
   - Test virtual controls re-show when gamepad disconnects

6. **test_gamepad_connection_flow.gd** (~150 lines)
   - Test gamepad connect/disconnect signals
   - Test auto-switch to KEYBOARD_MOUSE on disconnect
   - Test multiple gamepads (first gamepad used)

7. **test_input_during_scene_transition.gd** (~150 lines)
   - Test input blocked during transitions
   - Test buffers cleared on transition start
   - Test input resumes after transition complete

8. **test_accessibility_features.gd** (~150 lines)
   - Test accessibility profile applies larger buffer windows
   - Test toggle modes (sprint toggle mode)
   - Test larger deadzones

**Total Integration Test Lines**: ~1200 lines

---

### Test Execution Commands

**Run all Input Manager unit tests**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input_manager -gexit
```

**Run all Input Manager integration tests**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/input_manager -gexit
```

**Run ALL tests (baseline + Input Manager)**:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit,res://tests/integration -gexit
```

**Coverage Target**: 90%+ code coverage for all input systems (FR-128, SC-005)

---

## Next Steps

1. **Start Phase 0**: Create research.md, run baseline tests, prototype gamepad/touchscreen input, measure latency
2. **Validate Architecture**: Confirm all integration points (Scene Manager, State Store, ECS, Cursor Manager, UI)
3. **Begin Phase 1**: After Phase 0 approval, start with input actions/selectors/reducers (TDD)
4. **Follow TDD**: Write tests → implement → verify → commit for each task
5. **Update Planning Docs**: Keep input-manager-plan.md and input-manager-tasks.md current as phases complete
6. **No-Commit-If-Tests-Fail Rule**: NEVER commit if ANY test fails (fix before committing)

---

## References

- **PRD**: docs/input_manager/input-manager-prd.md (136 FRs, 22 SCs, 13 edge cases, 7 user stories)
- **Research**: docs/input_manager/research.md (Phase 0 prototyping findings, latency benchmarks)
- **Task Tracker**: docs/input_manager/input-manager-tasks.md (Phase-by-phase checklist)
- **General Guidelines**: AGENTS.md, docs/general/DEV_PITFALLS.md, docs/general/STYLE_GUIDE.md
