# Input Manager PRD

## Overview

- Feature name: Input Manager System
- Owner: Development Team
- Target release: Launch (P0)
- **Last Updated**: 2025-12-08
- **Status**: ✅ **PRODUCTION READY** - All planned features implemented

## Problem Statement

### What user problem are we solving?

Players need a flexible, responsive input system that:
1. **Supports multiple input devices** across platforms (keyboard/mouse, gamepad, touchscreen)
2. **Allows customization** through rebindable controls and input profiles
3. **Provides consistent behavior** across Desktop, Mobile, and Console platforms
4. **Integrates seamlessly** with the ECS architecture and state management system

Currently, the input system only supports basic keyboard/mouse input with hardcoded keybindings. Players cannot:
- Use gamepads or controllers
- Rebind keys to their preferences
- Switch between control schemes (e.g., accessibility profiles)
- Play on mobile devices with touch controls
- Experience platform-appropriate input (console controllers, mobile gestures)

### Why now?

The input system is foundational infrastructure that impacts every gameplay system. Implementing it now (after ECS, State Store, and Scene Manager are complete) ensures:
- All gameplay features can rely on robust input handling
- Cross-platform support is baked in from the start
- Player customization is available at launch (P0 requirement)
- No need to retrofit input handling across existing systems later

## Goals

### Primary Goals

1. **Multi-Device Support**: Support keyboard, mouse, gamepad, and touchscreen inputs with device-specific features
2. **Input Profiles**: Provide switchable control schemes (default, alternate, accessibility)
3. **Rebinding System**: Allow players to customize all input mappings with conflict detection
4. **Cross-Platform Compatibility**: Deliver appropriate input methods for Desktop, Mobile, and Console platforms
5. **ECS Integration**: Maintain clean component/system patterns with state store coordination
6. **Persistence**: Save and restore player input preferences across sessions

### Secondary Goals

7. **Input Buffering**: Support action buffering (jump buffering already implemented)
8. **Dead Zone Configuration**: Configurable analog stick dead zones for gamepad
9. **Haptic Feedback**: Gamepad rumble/vibration support
10. **Input Prompts**: Display context-appropriate button prompts (e.g., "Press [A]" vs "Press [Space]")
11. **Accessibility**: Support for alternative control schemes and assistive features

## Non-Goals

### Out of Scope

- **Touch Gestures Beyond Movement**: Advanced gestures (pinch-to-zoom, multi-touch) are not needed for core gameplay
- **Voice Input**: Voice commands or speech recognition
- **Motion Controls**: Accelerometer, gyroscope for motion-based input
- **Custom Hardware**: Support for specialized controllers (racing wheels, flight sticks)
- **Macro System**: Complex input macros or scripting
- **Input Recording/Replay**: Input demo recording for testing/speedruns
- **Network Input Prediction**: Client-side prediction for multiplayer (future feature)

### Deferred to Future Releases

- **Per-Action Sensitivity**: Individual sensitivity curves per action (global sensitivity is sufficient for P0)
- **Input Analytics**: Telemetry on input usage patterns
- **Input Hints System**: Contextual tutorial prompts (e.g., "Try pressing [Jump]")

## Current Implementation Status

### What Exists (Phase 16 - State Store Integration)

#### Core Components

1. **S_InputSystem** (`scripts/ecs/systems/s_input_system.gd`)
   - Captures keyboard/mouse input via Godot's Input singleton
   - Dispatches to both C_InputComponent and state store
   - Handles mouse delta for look input
   - Respects pause state and cursor capture mode
   - Auto-initializes InputMap actions if missing
   - Runs in `_physics_process` via ECS manager

2. **C_InputComponent** (`scripts/ecs/components/c_input_component.gd`)
   - Stores `move_vector` (Vector2), `jump_pressed` (bool), `sprint_pressed` (bool)
   - Jump buffering support with configurable buffer time
   - Consume jump request pattern to prevent double-jumps
   - Auto-registers with M_ECSManager

3. **State Store Integration**
   - `U_InputActions` (`scripts/state/actions/u_input_actions.gd`): Action creators for input state updates
   - `U_InputSelectors` (`scripts/state/selectors/u_input_selectors.gd`): Selectors to query input state
   - `U_GameplayReducer`: Handles input actions in gameplay slice
   - Input state persists across scene transitions via StateHandoff

4. **M_CursorManager** (`scripts/managers/m_cursor_manager.gd`)
   - Manages mouse visibility and capture mode
   - Toggle via "pause" input action
   - Emits `cursor_state_changed` signal
   - Added to "cursor_manager" group for discovery

5. **Rotation System**
   - **S_RotateToInputSystem**: Rotates entities based on input direction
   - **C_RotateToInputComponent**: Stores rotation state
   - **RS_RotateToInputSettings**: Configurable turn speed and second-order dynamics

#### InputMap Configuration

Defined in `project.godot` [input] section:
- `move_forward`, `move_backward`, `move_left`, `move_right` (WASD)
- `jump` (Space)
- `sprint` (Shift)
- `interact` (E)
- `pause` (ESC)
- `toggle_debug_overlay` (F3)

All actions have 0.2 deadzone (except `toggle_debug_overlay`: 0.5).
**Currently keyboard-only** - no gamepad or touchscreen bindings.

#### UI Navigation Actions

The following `ui_*` actions are reserved for UI navigation:

| Action | Keyboard | Gamepad | Purpose |
|--------|----------|---------|---------|
| `ui_accept` | Enter, Space | A (button 0) | Activate focused control |
| `ui_cancel` | ESC | B (button 1) | Context-dependent back |
| `ui_pause` | ESC | Start (button 6) | Identical to `ui_cancel` |
| `ui_up/down/left/right` | Arrows | D-pad / Left stick | Focus navigation |

**Design**: `ui_pause` and `ui_cancel` are identical (both ESC on keyboard)
- In gameplay: Opens pause
- In overlays: Closes overlay (CloseMode determines next state)
- In menu panels: Returns to previous panel

**Routing**: `UIInputHandler` maps `ui_*` events to navigation actions based on context

See: `docs/ui_manager/ui-manager-prd.md`

#### Test Coverage

10 passing tests:
- `test_input_system.gd`: Move vector, jump, sprint flag updates (3 tests)
- `test_s_rotate_to_input_system.gd`: Rotation logic and second-order dynamics (5 tests)
- `test_input_map.gd`: "interact" action existence (1 test)
- `test_input_during_transition.gd`: Input blocking during transitions (1 test)

### What's Missing (P0 for Launch)

1. **Input Profiles**: No profile system for switching control schemes
2. **Rebinding System**: No UI or persistence for custom keybindings
3. **Gamepad Support**: No controller input handling, analog sticks, or rumble
4. **Touchscreen Support**: No touch controls or virtual joystick for mobile
5. **Input Device Detection**: No device change events or automatic switching
6. **Platform-Specific Prompts**: No button glyph system (e.g., Xbox A vs PS Cross)
7. **Rebind Validation**: No conflict detection or reserved action protection

## User Experience Notes

### Primary Entry Points

1. **Gameplay Loop**
   - Player uses input devices to control character movement, jumping, sprinting
   - Input feels responsive and matches player expectations for the device type
   - Analog input (gamepad sticks) provides smooth directional control

2. **Settings Menu**
   - Player navigates to Input Settings screen
   - Can select from predefined profiles (Default, Alternate, Accessibility)
   - Can rebind individual actions by clicking and pressing new key/button
   - Sees conflict warnings if rebind duplicates another action
   - Changes persist across game sessions

3. **Device Switching**
   - Player unplugs gamepad and starts using keyboard - UI updates automatically
   - Input prompts change from controller buttons to keyboard keys
   - No manual device selection needed (auto-detection)

4. **Mobile Experience**
   - Touchscreen players see virtual joystick and action buttons on screen
   - Virtual controls are visually clear and positioned ergonomically
   - Optional gamepad support for mobile devices with Bluetooth controllers

### Critical Interactions

#### Input Profile Selection
```
[Settings] → [Input] → [Profile Dropdown]
  ├─ Default (WASD, Space, Shift)
  ├─ Alternate (Arrow keys, Right Ctrl, Right Shift)
  └─ Accessibility (Configurable, larger buffer windows)
```

#### Action Rebinding Flow
```
1. Player clicks "Rebind" button next to action (e.g., Jump)
2. UI shows "Press any key/button..."
3. Player presses new input (e.g., Right Mouse Button)
4. System validates:
   - Not a reserved action (ESC for pause must stay)
   - No conflict with existing bindings
5. If valid: Update binding and save to disk
6. If conflict: Show warning "Already bound to [Sprint]. Replace?"
```

#### Device Auto-Detection
```
1. Player connects gamepad mid-game
2. System detects InputEventJoypadButton event
3. Updates active device to "gamepad"
4. HUD changes prompts: "Press [Space]" → "Press [A]"
5. Input continues seamlessly with new device
```

#### Virtual Joystick (Mobile)
```
1. Player touches left side of screen
2. Virtual joystick appears at touch point
3. Dragging finger updates move_vector
4. Releasing resets joystick and move_vector to zero
5. Jump/Sprint buttons on right side respond to taps
```

## Technical Considerations

### Architecture

Architecture Overview: Input Manager is built from resource-based input profiles, in-scene managers (no autoloads), ECS components/systems, and a Redux-style state integration. It supports keyboard/mouse, gamepad, and touchscreen, with device detection and button prompts. Implementation details, file inventories, and code patterns have moved to the plan.

See: docs/input_manager/input-manager-plan.md (Architecture)

### ECS Integration

**Component Updates**:
- `C_InputComponent`: Add `device_type` field, `action_strength` (for analog)
- Keep existing `move_vector`, `jump_pressed`, `sprint_pressed` fields

**System Updates**:
- `S_InputSystem`: Expand to handle gamepad/touchscreen inputs
- Add device detection logic
- Apply deadzone filtering for analog sticks

**State Store Updates**:
- Add `input_device` field to gameplay slice
- Add `active_profile_id` field to settings slice (persistent)
- Dispatch device change actions

### Persistence

Input preferences persist across sessions. See plan for JSON schema and load/save flow.

See: docs/input_manager/input-manager-plan.md (Persistence)

### Dependencies

Built on Godot 4.5 Input/InputMap, ECS manager, state store, and UI. See plan for full dependency list.

See: docs/input_manager/input-manager-plan.md (Dependencies)

### Risks & Mitigations

Key risks include mobile latency, gamepad mapping differences, rebind conflicts, virtual control intrusion, profile switching mid-game, and cross-platform test coverage. See plan for full mitigations.

See: docs/input_manager/input-manager-plan.md (Risks & Mitigations)

### Platform-Specific Considerations

#### Desktop (Windows/Mac/Linux)
- **Primary Input**: Keyboard + Mouse
- **Secondary Input**: Gamepad (Xbox, PlayStation, Generic USB)
- **Unique Features**: Mouse look, high-precision input

#### Mobile (iOS/Android)
- **Primary Input**: Touchscreen (virtual joystick + buttons)
- **Secondary Input**: Bluetooth gamepad (optional)
- **Unique Features**: Touch gestures, screen size variance, performance constraints

#### Console (PlayStation/Xbox/Switch)
- **Primary Input**: Platform-specific gamepad (mandatory)
- **Secondary Input**: None (gamepad-only)
- **Unique Features**: Platform-specific button prompts, certification requirements, vibration

#### Web (HTML5)
- **Primary Input**: Keyboard + Mouse
- **Secondary Input**: Gamepad (via Gamepad API)
- **Unique Considerations**: Browser input restrictions; platform persistence constraints

## Success Criteria

### Measurable Outcomes

- **SC-001**: 100% of target input devices supported with zero P0 bugs
  - Keyboard: WASD movement, Space jump, Shift sprint, all keys mappable
  - Mouse: Delta tracking, button inputs, configurable sensitivity
  - Gamepad: Analog sticks, all buttons, triggers, vibration support
  - Touchscreen: Virtual joystick, virtual buttons, multi-touch handling
  - Measured by: Device compatibility matrix, zero critical input bug reports

- **SC-002**: Input latency < 16ms (one frame @ 60 FPS) measured from hardware event to C_InputComponent update
  - Keyboard: Hardware press → S_InputSystem._physics_process → component.move_vector update
  - Gamepad: Analog stick → deadzone filtering → component update
  - Touch: Screen touch → VirtualJoystick update → component update
  - Measured by: Profiling with Time.get_ticks_msec() timestamps, average across 1000 samples

- **SC-003**: Profile switching completes < 200ms including full InputMap update
  - Switch command → load profile resource → clear InputMap → apply mappings → emit signal
  - Measured by: Stopwatch timing in M_InputProfileManager.switch_profile()

- **SC-004**: Custom bindings save/load < 100ms on all platforms
  - Save: Serialize bindings → write JSON → close file
  - Load: Read JSON → parse → validate → apply to InputMap
  - Measured by: File I/O timing, tested on HDD and SSD

- **SC-005**: 90%+ code coverage for all input systems, components, managers, utilities
  - Unit tests: C_InputComponent, C_GamepadComponent, all systems, all managers
  - Integration tests: Profile switching, device handoff, rebinding flow, persistence
  - Measured by: GUT test coverage report

- **SC-006**: Zero input drop - 100% of physical inputs captured during stress test
  - Stress test: 100 rapid inputs per second for 60 seconds
  - Measure: Input event count vs component update count
  - Success: No missed inputs, all state changes registered

- **SC-007**: Rebind conflict detection 100% accurate (zero false positives, zero false negatives)
  - Test all input combinations across all actions
  - Measure: Conflict detection results vs expected conflicts
  - Success: Perfect match with expected behavior

- **SC-008**: Device auto-detection 100% accurate within one frame of device input
  - Test: Switch between keyboard, gamepad, touchscreen
  - Measure: Frame delay between input event and active_device update
  - Success: Detection within same frame (0ms delay)

- **SC-009**: Mobile virtual controls maintain 60 FPS on mid-range devices
  - Tested devices: iPhone 12, Galaxy S21, Pixel 5
  - Measured by: FPS counter during 5-minute gameplay session
  - Success: Average FPS ≥ 60, minimum FPS ≥ 55

- **SC-010**: Gamepad vibration latency < 50ms from trigger event to haptic feedback
  - Test: apply_rumble() call → Input.start_joy_vibration() → physical vibration
  - Measured by: High-speed camera recording timestamp comparison
  - Success: Vibration starts within 3 frames @ 60 FPS

### Development Success

- **SC-011**: All input components extend ECSComponent and follow component patterns
  - C_InputComponent has COMPONENT_TYPE constant
  - C_GamepadComponent has COMPONENT_TYPE constant
  - Auto-register with M_ECSManager on _ready()
  - Measured by: Code review, pattern compliance checklist

- **SC-012**: All input systems extend ECSSystem and follow system patterns
  - S_InputSystem implements process_tick(delta)
  - S_TouchscreenSystem implements process_tick(delta)
  - Auto-discover M_ECSManager via parent traversal
  - Measured by: Code review, pattern compliance checklist

- **SC-013**: All input state managed via Redux patterns (action creators, reducers, selectors)
  - U_InputActions provides 14 action creators
  - Reducers handle all input action types
  - U_InputSelectors provides query methods
  - Measured by: Code review, Redux pattern audit

- **SC-014**: Zero Godot autoloads added - all managers are in-scene nodes
  - M_InputProfileManager in root.tscn
  - M_InputDeviceManager in root.tscn
  - Managers use groups for discovery
  - Measured by: project.godot inspection, autoload section empty

- **SC-015**: API documentation 100% complete with GDScript doc comments
  - All public methods have ## doc comments
  - All @export fields have ## descriptions
  - All signals documented
  - Measured by: Documentation coverage script

- **SC-016**: 5+ complete implementation examples in PRD or developer guides
  - Profile switching example
  - Rebinding workflow example
  - Device detection example
  - Virtual joystick setup example
  - Gamepad vibration example
  - Measured by: Documentation review

- **SC-017**: Integration tests demonstrate full input flow from capture to state update
  - test_keyboard_to_component_flow.gd
  - test_gamepad_to_component_flow.gd
  - test_profile_persistence_roundtrip.gd
  - Measured by: Integration test suite execution

### User Experience Success

- **SC-018**: 95%+ rebind attempts succeed without errors or conflicts
  - Test: 100 rebind operations across all actions
  - Measure: Success rate, error frequency, conflict resolution rate
  - Success: ≤ 5 conflicts requiring user resolution

- **SC-019**: Device switching feels seamless - input continues without interruption
  - Test: Switch devices mid-gameplay (keyboard → gamepad, gamepad → touch)
  - Measure: Gameplay interruption, input lag during switch
  - Success: Zero gameplay interruption, button prompts update within 1 frame

- **SC-020**: Virtual controls on mobile feel responsive with perceived latency < 100ms
  - Test: User study with 10 mobile players
  - Measure: Subjective responsiveness rating (1-5 scale)
  - Success: Average rating ≥ 4.0, zero "unresponsive" reports

- **SC-021**: Accessibility profiles enable comfortable play for players with motor impairments
  - Test: User study with 5 players requiring accessibility features
  - Measure: Task completion rate, comfort rating, customization satisfaction
  - Success: 100% task completion, average comfort ≥ 4.0/5.0

- **SC-022**: Button prompts always show correct input for active device
  - Test: Switch devices and verify all HUD prompts update correctly
  - Measure: Prompt accuracy across 20 UI elements
  - Success: 100% accuracy, zero incorrect prompts displayed

## Architectural Decisions

### Confirmed Design Decisions

1. **Multi-Device Input: SIMULTANEOUS (CONFIRMED)**
   - **Decision**: YES, simultaneous input from keyboard + gamepad is fully supported
   - **Implementation**: Inputs blend together - both devices contribute to movement simultaneously
   - **Device Detection**: M_InputDeviceManager detects last-used device and updates button prompts only
   - **Active Device State**: ALL devices remain active; "active device" is only for prompt display
   - **Example**: Player uses WASD for movement and gamepad stick for camera simultaneously

2. **Profile Switching on Device Change: PROMPT UPDATE ONLY (CONFIRMED)**
   - **Decision**: Option B - Keep current profile, device detection updates prompts only
   - **Implementation**: Device detection does NOT auto-switch profiles, only updates which button icons display
   - **Rationale**: Players customize one profile and use it across all devices without interruption

3. **Reserved Actions Policy (CONFIRMED)**
   - **Decision**: Only `pause` (ESC) is reserved and non-rebindable
   - **Rebindable Actions**: ALL other actions can be rebound including:
     - `interact` - Players can customize interaction key
     - `toggle_debug_overlay` - Developers can rebind debug toggle
     - All movement, jump, sprint, etc.
   - **Rationale**: `pause` must remain ESC for emergency menu access. `interact` is gameplay, not system-critical.

4. **Profile Switching Timing: ANYTIME (CONFIRMED)**
   - **Decision**: Allow profile switching anytime, even during gameplay
   - **Implementation**: Changes apply immediately without requiring pause
   - **Rationale**: Players may want to experiment with profiles mid-session without interruption

5. **Input Processing Timing: ALL IN _physics_process (CONFIRMED)**
   - **Decision**: Process ALL input types (keyboard, mouse, gamepad, touch) in `_physics_process()`
   - **Rationale**: Consistent 60Hz timing across all devices, predictable integration with physics systems
   - **Note**: Touchscreen captures events in `_input()` but applies to state in `_physics_process()`

## Open Questions

### Design Questions

1. **Should virtual controls be mandatory or optional on mobile?** (OPEN)
   - Option A: Always show virtual controls on mobile
   - Option B: Hide if Bluetooth gamepad detected
   - Current thinking: Option B (auto-hide when gamepad connected)

2. **How granular should rebinding be?** (OPEN)
   - Option A: One binding per action (e.g., Jump = Space only)
   - Option B: Multiple bindings per action (e.g., Jump = Space OR Gamepad A)
   - Current thinking: Option B (Godot InputMap supports multiple events per action)

3. **Should we support input recording for accessibility?** (DEFERRED)
   - Example: Player records a sequence of inputs, replays with one button
   - Decision: Out of scope for P0, defer to post-launch

### Confirmed Technical Decisions

6. **Input Profiles Format: RESOURCES + JSON (CONFIRMED)**
   - **Decision**: Resources (.tres) for built-in profiles, JSON for persistence/custom profiles
   - **Implementation**:
     - `RS_InputProfile` Resource class for built-in profiles
     - JSON serialization for saved settings at `user://global_settings.json`
   - **Rationale**: Type-safe editor resources + human-readable persistence

7. **Manager Location: PERSISTENT IN root.tscn (CONFIRMED)**
   - **Decision**: Option A - M_InputProfileManager and M_InputDeviceManager in root.tscn
   - **Implementation**: Add to root scene alongside M_StateStore, M_SceneManager
   - **Rationale**: Follows existing manager patterns, no autoloads, discoverable via groups

8. **System Organization: UNIFIED + SEPARATE TOUCH (CONFIRMED)**
   - **Decision**: S_InputSystem handles keyboard+mouse+gamepad, S_TouchscreenSystem separate
   - **Rationale**: Desktop inputs processed together, touch requires UI layer (different concerns)

9. **File Organization: DISTRIBUTED PATTERN (CONFIRMED)**
   - **Decision**: Match existing repo patterns, NO new `scripts/input/` directory
   - **Implementation**:
     - Resources: `scripts/ecs/resources/rs_input_*.gd`
     - Utilities: `scripts/u_input_*.gd`
     - Systems: `scripts/ecs/systems/s_*_system.gd`
     - Managers: `scripts/managers/m_input_*.gd`
   - **Rationale**: Consistency with existing ECS architecture

10. **Persistence Format: JSON (CONFIRMED)**
    - **Decision**: JSON at `user://global_settings.json`
    - **Implementation**: `JSON.stringify()` / `JSON.parse_string()` for structured data
    - **Rationale**: Easier schema validation and version migration than ConfigFile

11. **Rebinding Conflict Resolution: CONFIRM DIALOG (CONFIRMED)**
    - **Decision**: Show confirm dialog listing conflicts when rebinding
    - **Implementation**: Player sees "Jump is already bound to Spacebar. Replace?" → Confirm/Cancel
    - **Rationale**: Prevents accidental binding loss, gives player control

12. **Unmapped Gamepad Handling: RAW INDICES (CONFIRMED)**
    - **Decision**: Use raw button indices (button_0, button_1, etc.) when SDL mapping unavailable
    - **Implementation**: Fall back to generic button names, players can rebind
    - **Rationale**: Graceful degradation without blocking gameplay

13. **Undo/Redo for Rebinding: RESET TO DEFAULTS ONLY (CONFIRMED)**
    - **Decision**: No undo/redo stack, provide "Reset to Defaults" button only
    - **Rationale**: Simpler implementation, players can rebind again if they make mistakes

14. **Button Prompt Assets: KENNEY.NL (CONFIRMED)**
    - **Decision**: Use Kenney.nl Input Prompts pack (free, 64x64 PNG, generic gamepad)
    - **Implementation**: Download and integrate Kenney's icons as project assets
    - **Rationale**: Free, high-quality, legally clear licensing

15. **Virtual Controls Layout: CONFIGURABLE (CONFIRMED)**
    - **Decision**: Players can drag and reposition virtual controls on screen
    - **Implementation**: Save positions per-profile in JSON persistence
    - **Rationale**: Mobile players have different hand sizes/preferences

### Persistence Schema (JSON)

Complete schema for `input_settings` inside `user://global_settings.json`:

```json
{
  "version": "1.0.0",
  "input_settings": {
    "active_profile_id": "default",
    "custom_bindings": {
      "move_forward": [
        {"type": "key", "keycode": 87},
        {"type": "joypad_button", "button_index": 12}
      ],
      "move_backward": [
        {"type": "key", "keycode": 83},
        {"type": "joypad_button", "button_index": 13}
      ],
      "move_left": [
        {"type": "key", "keycode": 65},
        {"type": "joypad_button", "button_index": 14}
      ],
      "move_right": [
        {"type": "key", "keycode": 68},
        {"type": "joypad_button", "button_index": 15}
      ],
      "jump": [
        {"type": "key", "keycode": 32},
        {"type": "joypad_button", "button_index": 0}
      ],
      "sprint": [
        {"type": "key", "keycode": 4194325},
        {"type": "joypad_button", "button_index": 1}
      ],
      "interact": [
        {"type": "key", "keycode": 69},
        {"type": "joypad_button", "button_index": 2}
      ],
      "toggle_debug_overlay": [
        {"type": "key", "keycode": 16777244}
      ]
    },
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
      "joystick_size": 100.0,
      "joystick_opacity": 0.7,
      "joystick_position": {"x": 100.0, "y": 500.0},
      "button_size": 80.0,
      "button_opacity": 0.7,
      "button_positions": {
        "jump": {"x": 900.0, "y": 500.0},
        "sprint": {"x": 820.0, "y": 450.0},
        "interact": {"x": 980.0, "y": 450.0}
      }
    },
    "accessibility": {
      "buffer_window_multiplier": 3.0,
      "toggle_sprint": false,
      "hold_to_interact_duration": 0.5
    }
  }
}
```

**Schema Notes**:
- `version`: Semantic version for schema migration (1.0.0 → 1.1.0 if fields added)
- `active_profile_id`: Currently active profile (default, alternate, accessibility, custom)
- `custom_bindings`: Per-action array of InputEvent configurations
  - `type`: "key", "joypad_button", "joypad_motion", "mouse_button"
  - `keycode`: For "key" type (KEY_* constants)
  - `button_index`: For "joypad_button" type (JOY_BUTTON_* indices)
- `gamepad_settings`: Device-specific configuration
- `mouse_settings`: Mouse-specific configuration
- `touchscreen_settings`: Touch-specific configuration with configurable positions
- `accessibility`: Assistive features

**Validation Rules**:
- Version must match expected format (major.minor.patch)
- active_profile_id must reference existing profile or default to "default"
- Sensitivity ranges: 0.1 - 5.0 (clamped on load)
- Deadzone ranges: 0.0 - 0.9 (clamped on load)
- Vibration intensity: 0.0 - 1.0 (clamped on load)
- Opacity values: 0.0 - 1.0 (clamped on load)
- If any field invalid/missing, use default value and log warning

**Migration Strategy**:
- Version 1.0.0 → 1.1.0: Add new fields with defaults, preserve existing fields
- If schema version newer than known version, attempt load with graceful degradation
- Backup corrupted files to `user://global_settings.json.backup`
- Always validate after parse, never trust loaded data

### Coverage Measurement Strategy

**SC-005 Target**: 90%+ code coverage (qualitative)

**Measurement Approach**:
- **Method**: Line-by-line qualitative review (no automated tooling)
- **Calculation**: `(Functions with unit tests) / (Total functions)` × 100%
- **Scope**: All input manager files (components, systems, managers, utilities, resources)
- **Exclusions**: Test files themselves, example/research files, third-party code

**Review Process**:
1. List all public methods/functions in input manager files
2. For each function, verify corresponding unit test exists in `tests/unit/input_manager/`
3. Mark function as "covered" if test exercises primary logic path
4. Calculate coverage percentage per-file and overall
5. Document untested functions with rationale (e.g., "trivial getter", "engine callback")

**Coverage Acceptance Criteria**:
- Core systems (S_InputSystem, M_InputProfileManager, etc.): 95%+
- Utilities (U_InputRebindUtils, etc.): 90%+
- Resources (RS_InputProfile, etc.): 80%+ (property getters/setters less critical)
- Overall project average: 90%+

**Documentation**: Maintain coverage report in `docs/input_manager/coverage-report.md` with:
- Per-file coverage percentage
- List of untested functions with rationale
- Update after each phase completion

### Open Technical Questions

16. **How should we handle input during scene transitions?** (OPEN)
    - Already implemented: Input blocked during transitions via `is_transitioning` check
    - Question: Should buffered inputs (jump buffer) persist across transitions?
    - Current thinking: No, flush buffers on transition start

17. **Should button prompts be part of Input Manager or separate UI system?** (OPEN)
    - Option A: Input Manager provides prompt registry, UI queries it
    - Option B: Separate Button Prompt system with its own manager
    - Current thinking: Option A (lightweight registry, no separate manager needed)

### Open Process Questions

18. **What's the testing strategy for console hardware?** (DEFERRED)
    - Desktop/Mobile can be tested in-house
    - Console requires dev kits or cloud testing services
    - Decision: Defer console-specific testing until dev kits acquired

19. **Should we implement all platforms in one phase or incrementally?** (OPEN)
    - Option A: Desktop → Mobile → Console (incremental)
    - Option B: All platforms simultaneously
    - Current thinking: Option A (Desktop first, validates architecture before expanding)

## Implementation Examples

Implementation examples have moved to the plan to keep this PRD focused on requirements and outcomes.

See: docs/input_manager/input-manager-plan.md (Examples)
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		new_device = DeviceType.GAMEPAD
		# Update active gamepad device_id
		if event is InputEventJoypadButton:
			gamepad_device_id = event.device
		elif event is InputEventJoypadMotion:
			gamepad_device_id = event.device
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		new_device = DeviceType.TOUCHSCREEN

	# Switch if changed
	if new_device != active_device:
		_switch_device(new_device)

func _switch_device(new_device: DeviceType) -> void:
	active_device = new_device
	last_input_time = U_ECSUtils.get_current_time()

	# Dispatch to state store
	var store := U_StateUtils.get_store(self)
	store.dispatch(U_InputActions.device_changed(new_device, gamepad_device_id))

	# Emit signal for UI updates
	device_changed.emit(new_device)

	print("Input device switched to: %s" % DeviceType.keys()[new_device])

func detect_gamepads() -> void:
	var joypads := Input.get_connected_joypads()
	if joypads.size() > 0:
		gamepad_device_id = joypads[0]
		gamepad_connected.emit(gamepad_device_id)
		print("Gamepad detected: device_id=%d" % gamepad_device_id)
```

### Example 4: Rebinding Workflow with U_InputRebindUtils

Moved to plan. See: docs/input_manager/input-manager-plan.md (Examples)

### Example 5: Virtual Joystick Setup in Mobile Scene

Moved to plan. See: docs/input_manager/input-manager-plan.md (Examples)

### Example 6: Gamepad Vibration Trigger

Moved to plan. See: docs/input_manager/input-manager-plan.md (Examples)

### Example 7: Button Prompt Registry Initialization

Moved to plan. See: docs/input_manager/input-manager-plan.md (Examples)

## Comprehensive Edge Cases

Moved to plan for validation/test planning.

See: docs/input_manager/input-manager-plan.md (Edge Cases & Validation)
2. Returns ValidationResult with `valid=false`, `conflict=StringName("jump")`
3. UI displays warning dialog: "Space is already bound to Jump. Replace?"
4. If player confirms:
   - Jump binding cleared from Space
   - Sprint binding set to Space
   - Both changes saved to custom_bindings
5. If player cancels:
   - No changes applied
   - Rebind mode exits
   - Original bindings preserved

**Edge Case**: What if conflict action is reserved (pause)?
- Validation fails immediately with error "Cannot reassign key from reserved action"
- No dialog shown, rebind rejected

### What happens when gamepad disconnects mid-game?

**Scenario**: Player using gamepad, USB cable unplugs during gameplay.

**System Behavior**:
1. Godot detects disconnection (Input.get_connected_joypads() changes)
2. M_InputDeviceManager._input() or polling detects missing device_id
3. Emits gamepad_disconnected(device_id) signal
4. Dispatches U_InputActions.gamepad_disconnected(device_id) to store
5. Auto-switches active_device to KEYBOARD_MOUSE
6. Emits device_changed(KEYBOARD_MOUSE) signal
7. HUD updates button prompts from gamepad icons to keyboard keys within 1 frame
8. C_GamepadComponent.is_connected = false
9. Input continues seamlessly with keyboard/mouse

**Edge Case**: What if player is mid-jump when disconnect occurs?
- C_InputComponent.jump_pressed remains true until player releases Space on keyboard
- Movement input resets to Vector2.ZERO (no stuck movement)
- Game continues without interruption

### What happens when player attempts to rebind a reserved action?

**Scenario**: Player clicks "Rebind" button next to Pause action.

**System Behavior**:
1. RS_RebindSettings.reserved_actions contains StringName("pause")
2. U_InputRebindUtils.is_reserved_action("pause", settings) returns true
3. Validation fails with error "Cannot rebind reserved action"
4. UI shows error toast: "Pause cannot be rebound (reserved for menu access)"
5. Rebind mode does not activate
6. Original Esc binding preserved

**Rationale**: Players must always have access to pause menu. If pause is rebound to obscure key and player forgets, they cannot access settings to fix it.

### What happens when save file contains invalid custom bindings?

**Scenario**: user://global_settings.json corrupted or manually edited with invalid data.

**System Behavior**:
1. M_InputProfileManager.load_custom_bindings() reads JSON
2. JSON.parse_string() returns null or malformed Dictionary
3. Validation detects issues:
   - Missing "version" field
   - Unknown action names
   - Invalid event type strings
   - Malformed event data (missing keycode, etc.)
4. System logs warnings for each invalid entry
5. Invalid entries skipped, valid entries applied
6. Falls back to default profile for skipped actions
7. User sees notification: "Some custom bindings could not be loaded. Defaults restored for affected actions."
8. Corrupted file backed up to user://global_settings.json.backup
9. New valid file saved on next successful rebind

**Edge Case**: Entire file unreadable
- Load defaults for all actions
- Notification: "Custom bindings file corrupted. All bindings reset to default profile."

### What happens when multiple gamepads are connected?

**Scenario**: Player has 2 Xbox controllers plugged in (device_id 0 and 1).

**System Behavior**:
1. Input.get_connected_joypads() returns [0, 1]
2. M_InputDeviceManager tracks all connected devices
3. First gamepad to send input becomes active device
4. Active device_id stored in M_InputDeviceManager.gamepad_device_id
5. S_InputSystem processes input only from active gamepad
6. Other gamepad inputs ignored (unless future multiplayer support)
7. If player wants to switch active gamepad:
   - Press any button on desired gamepad
   - System detects input from different device_id
   - Switches active_device_id to new gamepad
   - Continues seamlessly

**Future Enhancement**: Settings UI to manually select active gamepad by name

### What happens when touchscreen and gamepad both provide input on mobile?

**Scenario**: Mobile player has Bluetooth gamepad connected, touches screen accidentally.

**System Behavior**:
1. M_InputDeviceManager tracks last input source
2. If gamepad input detected:
   - active_device = GAMEPAD
   - S_TouchscreenSystem.hide_virtual_controls() called
   - Virtual joystick and buttons hidden
3. If touch input detected while gamepad active:
   - active_device = TOUCHSCREEN
   - S_TouchscreenSystem.show_virtual_controls() called
   - Virtual controls re-appear
4. Seamless switching without manual configuration
5. Input continues from whichever device was used last

**Edge Case**: Rapid alternating input (gamepad then touch then gamepad)
- Device switching debounced (minimum 0.5s between switches)
- Prevents flickering virtual controls

### What happens when player triggers rebind but presses ESC to cancel?

**Scenario**: Player clicks "Rebind" for Jump, then changes mind and presses ESC.

**System Behavior**:
1. Rebind UI listens for any InputEvent
2. ESC detected as special "cancel" signal (not bound as action)
3. Rebind mode exits immediately
4. Original Jump binding preserved (Space)
5. No validation performed
6. No save operation triggered
7. UI returns to normal settings view

**Implementation Note**: ESC handled separately from rebind input capture to always allow cancellation.

### What happens when input actions are missing from InputMap?

**Scenario**: New game version adds "crouch" action, but player's InputMap doesn't have it yet.

**System Behavior**:
1. S_InputSystem._ready() iterates all expected actions
2. InputMap.has_action("crouch") returns false
3. System logs warning: "Action 'crouch' not found in InputMap, initializing with default"
4. Loads default binding from active profile resource
5. InputMap.add_action("crouch")
6. InputMap.action_add_event("crouch", default_event)
7. Game continues without crash
8. Player can rebind "crouch" normally in settings

**Edge Case**: Profile also missing the action
- Fall back to hardcoded default (C key)
- Log error but continue

### What happens when analog stick input is below deadzone threshold?

**Scenario**: Gamepad left stick has slight drift, reporting 0.05 on X axis when centered.

**System Behavior**:
1. S_InputSystem receives InputEventJoypadMotion with axis_value = 0.05
2. RS_GamepadSettings.left_stick_deadzone = 0.2 (default)
3. C_GamepadComponent.apply_deadzone(Vector2(0.05, 0), 0.2) called
4. magnitude = 0.05 < 0.2 (below threshold)
5. Returns Vector2.ZERO
6. C_InputComponent.move_vector = Vector2.ZERO
7. Character does not move (drift eliminated)

**Above Deadzone**:
- Input 0.3: (0.3 - 0.2) / (1.0 - 0.2) = 0.125 normalized output
- Smooth ramp from deadzone to full input

### What happens when player rapidly switches profiles during gameplay?

**Scenario**: Player opens pause menu mid-gameplay, rapidly clicks between Default, Alternate, Accessibility profiles.

**System Behavior**:
1. M_InputProfileManager checks U_GameplaySelectors.get_is_paused()
2. If `paused = false`: Show error "Cannot switch profiles during gameplay. Pause first."
3. Profile switch blocked, no changes applied
4. If `paused = true`: Allow switch
5. Each switch:
   - Clears current input state (move_vector = Vector2.ZERO, all buttons = false)
   - Applies new profile's InputMap
   - Saves active_profile_id to settings
   - Emits profile_switched signal
6. Rapid switches (< 0.2s apart) debounced to prevent spam
7. Last selected profile wins
8. On unpause, gameplay resumes with new profile active

**Rationale**: Prevent mid-action profile switches that could cause unexpected behavior (e.g., changing sprint from hold to toggle while sprinting).

### What happens when virtual joystick positioned under player's finger obscures gameplay?

**Scenario**: Mobile player touches bottom-left of screen, virtual joystick appears but blocks view of character.

**System Behavior**:
1. VirtualJoystick.floating_joystick = true (default)
2. Touch detected at position P
3. Joystick center spawns at P
4. Player drags finger, joystick follows
5. If RS_TouchscreenSettings.virtual_joystick_opacity = 0.7:
   - Joystick renders semi-transparent
   - Character visible through joystick
6. If still problematic:
   - Player can adjust opacity in settings (0.3 - 1.0)
   - Player can switch to fixed joystick position (floating = false)
   - Fixed position: Always bottom-left corner, doesn't follow touch

**Accessibility Option**: Large button mode increases opacity to 0.9 for better visibility of controls themselves.

### What happens when input buffering carries over scene transition?

**Scenario**: Player presses Jump right before scene transition triggers.

**System Behavior**:
1. C_InputComponent.jump_pressed = true
2. _jump_buffer_timestamp set to current time
3. Scene transition starts (M_SceneManager.transition_to_scene())
4. S_InputSystem detects is_transitioning = true
5. Input capture blocked during transition
6. **FR-108**: Input buffers flushed on transition start
   - _jump_buffer_timestamp reset to 0.0
   - jump_pressed reset to false
7. New scene loads
8. Character spawns at target spawn point
9. No buffered jump executes (prevented by flush)

**Rationale**: Buffered inputs from previous scene could trigger unintended actions in new scene context.

### What happens when button prompt assets are missing for active device?

**Scenario**: Player switches to gamepad, but gamepad button icons not found in resources/button_prompts/gamepad/.

**System Behavior**:
1. M_InputDeviceManager emits device_changed(GAMEPAD)
2. HUD calls U_ButtonPromptRegistry.get_prompt("jump", GAMEPAD)
3. Registry attempts to load "res://assets/button_prompts/gamepad/south.png"
4. ResourceLoader.load() returns null (file not found)
5. U_ButtonPromptRegistry.get_prompt_text("jump", GAMEPAD) called as fallback
6. Returns text label: "Press [South]"
7. HUD displays text instead of icon
8. System logs warning: "Button prompt asset missing: gamepad/south.png, using text fallback"
9. Game continues without crash
10. No visual glitch (graceful degradation)

**Best Practice**: Ship with complete icon sets to avoid text fallbacks.

## User Stories

### User Story 1: Keyboard/Mouse Input (Priority: P1)

**Description**: Players can control character movement and actions using keyboard and mouse input with low latency and accurate response.

**Why this priority**: Foundation for all input functionality. Desktop is primary development platform and keyboard/mouse is the baseline input method for testing and validation.

**Independent Test**: Launch game → Use WASD to move character → Press Space to jump → Move mouse to look around → Verify responsive input without lag or missed inputs.

**Acceptance Scenarios**:

1. **Given** player presses W key, **When** input system processes in `_physics_process`, **Then** C_InputComponent.move_vector.y = -1.0
2. **Given** player presses A key, **When** input system processes, **Then** C_InputComponent.move_vector.x = -1.0
3. **Given** player presses Space, **When** jump action triggered, **Then** C_InputComponent.jump_pressed = true
4. **Given** player releases Space, **When** input system processes next frame, **Then** C_InputComponent.jump_pressed = false
5. **Given** player presses Shift, **When** sprint action triggered, **Then** C_InputComponent.sprint_pressed = true
6. **Given** player moves mouse while cursor captured, **When** input system processes mouse delta, **Then** look_input Vector2 updates in state store
7. **Given** game is paused, **When** player presses WASD, **Then** input is ignored (C_InputComponent.move_vector remains Vector2.ZERO)
8. **Given** player presses E near interactable, **When** interact action triggered, **Then** interactable responds to interaction

**Edge Cases**:
- Player rapidly taps Space (buffering prevents missed jumps)
- Player holds multiple movement keys simultaneously (diagonal movement via Input.get_vector)
- Cursor not captured (mouse delta not processed)
- Scene transition in progress (input blocked via is_transitioning check)

### User Story 2: Input Profile System (Priority: P1)

**Description**: Players can select from multiple predefined control schemes (Default, Alternate, Accessibility) and the game saves their preference across sessions.

**Why this priority**: Enables player customization and accessibility. Critical for players who prefer different keyboard layouts or need assistive controls.

**Independent Test**: Open Settings → Select "Alternate" profile from dropdown → Exit game → Restart game → Verify "Alternate" profile loads automatically with correct key bindings.

**Acceptance Scenarios**:

1. **Given** game launches, **When** M_InputProfileManager initializes, **Then** loads active_profile_id from user://global_settings.json
2. **Given** no saved profile exists, **When** M_InputProfileManager initializes, **Then** defaults to "default" profile
3. **Given** player opens Input Settings, **When** UI displays, **Then** shows list of available profiles (Default, Alternate, Accessibility)
4. **Given** player selects "Alternate" profile, **When** profile switched, **Then** M_InputProfileManager applies new action mappings to InputMap within 200ms
5. **Given** player selects "Alternate" profile, **When** profile switched, **Then** active_profile_id saved to user://global_settings.json
6. **Given** "Alternate" profile active, **When** game restarts, **Then** M_InputProfileManager loads "Alternate" profile automatically
7. **Given** profile switch occurs, **When** device_changed signal emits, **Then** HUD updates button prompts to match new profile bindings
8. **Given** player in gameplay, **When** attempts to switch profile, **Then** system shows error "Cannot switch profiles during gameplay. Pause first."

**Edge Cases**:
- Saved profile ID no longer exists (fall back to "default")
- Profile resource file corrupted (log error, load default profile)
- Profile switching during active input (input state cleared, new profile applied)
- Multiple rapid profile switches (debounce to prevent spam)

### User Story 3: Gamepad Support (Priority: P1)

**Description**: Players can use gamepad controllers (Xbox, PlayStation, Switch) with analog stick movement, button inputs, and haptic feedback.

**Why this priority**: Essential for console platforms and preferred input method for many players. Gamepad support is baseline requirement for cross-platform release.

**Independent Test**: Connect Xbox controller → Launch game → Use left stick to move → Press A to jump → Verify analog movement feels smooth with proper deadzone filtering and rumble triggers on impact.

**Acceptance Scenarios**:

1. **Given** gamepad connected, **When** player moves left stick, **Then** C_InputComponent.move_vector updates based on analog input (0.0-1.0 range)
2. **Given** left stick input below deadzone (< 0.2), **When** input system processes, **Then** C_InputComponent.move_vector = Vector2.ZERO (prevents stick drift)
3. **Given** left stick input above deadzone, **When** input system processes, **Then** analog value normalized to 0.0-1.0 range
4. **Given** player presses A button (Xbox), **When** jump action triggered, **Then** C_InputComponent.jump_pressed = true
5. **Given** player holds RT trigger (Xbox), **When** sprint action triggered, **Then** C_InputComponent.sprint_pressed = true
6. **Given** gamepad supports vibration, **When** apply_rumble(0.5, 0.3) called, **Then** Input.start_joy_vibration() triggers with intensity 0.5 for 0.3 seconds
7. **Given** gamepad disconnects mid-game, **When** connection lost detected, **Then** M_InputDeviceManager auto-switches to KEYBOARD_MOUSE and emits device_changed signal
8. **Given** multiple gamepads connected, **When** any gamepad provides input, **Then** first gamepad to send input becomes active device

**Edge Cases**:
- Gamepad disconnects during analog input (move_vector resets to zero)
- Gamepad reconnects with different device ID (system detects and updates device_id)
- Unsupported gamepad without SDL mapping (falls back to generic button indices)
- Vibration not supported on device (apply_rumble() fails gracefully, no crash)

### User Story 4: Input Rebinding System (Priority: P1)

**Description**: Players can customize keybindings by clicking a rebind button, pressing a new key/button, and the system validates for conflicts and saves preferences.

**Why this priority**: Player agency and accessibility. Different players have different preferences and physical needs. Rebinding is expected feature in modern games.

**Independent Test**: Open Settings → Click "Rebind" next to Jump → Press Right Mouse Button → See conflict warning if RMB already bound → Confirm replacement → Verify Jump now bound to RMB → Restart game → Verify custom binding persists.

**Acceptance Scenarios**:

1. **Given** player clicks "Rebind" button for Jump, **When** rebind mode activates, **Then** UI shows "Press any key/button..." and waits for input
2. **Given** rebind mode active, **When** player presses Right Mouse Button, **Then** U_InputRebindUtils.validate_rebind() checks for conflicts
3. **Given** RMB not bound to another action, **When** validation succeeds, **Then** InputMap.action_erase_events() clears old Jump binding and InputMap.action_add_event() adds RMB
4. **Given** RMB already bound to Sprint, **When** validation detects conflict, **Then** UI shows warning "Right Mouse Button already bound to [Sprint]. Replace?"
5. **Given** player confirms replacement, **When** rebind applied, **Then** Sprint binding cleared and Jump gets RMB binding
6. **Given** player cancels conflict dialog, **When** cancel pressed, **Then** original bindings preserved, rebind mode exits
7. **Given** player attempts to rebind Pause action, **When** RS_RebindSettings marks Pause as reserved, **Then** validation fails with error "Cannot rebind reserved action"
8. **Given** rebind succeeds, **When** U_InputRebindUtils.rebind_action() completes, **Then** M_InputProfileManager.save_custom_bindings() writes to user://global_settings.json within 100ms

**Edge Cases**:
- Player presses ESC during rebind (cancels rebind, returns to settings)
- Player presses mouse button during keyboard profile (allowed, creates multi-device binding)
- Custom bindings file corrupted (log error, fall back to default profile)
- Player clicks "Reset to Default" (clears custom_bindings, reloads active profile)

### User Story 5: Touchscreen Support for Mobile (Priority: P1)

**Description**: Mobile players can control character using on-screen virtual joystick and action buttons with responsive touch input.

**Why this priority**: Mobile platform support is P0 requirement. Touchscreen is only viable input method for mobile players without Bluetooth controllers.

**Independent Test**: Launch game on mobile device → Touch left side of screen to spawn virtual joystick → Drag finger to move character → Tap Jump button on right side → Verify responsive movement and actions without lag.

**Acceptance Scenarios**:

1. **Given** game runs on mobile (OS.has_feature("mobile") = true), **When** gameplay scene loads, **Then** VirtualJoystick and VirtualButton nodes instantiate
2. **Given** player touches left side of screen, **When** InputEventScreenTouch detected, **Then** VirtualJoystick appears at touch point
3. **Given** player drags finger on joystick, **When** InputEventScreenDrag processed, **Then** VirtualJoystick.get_vector() returns normalized Vector2 based on drag distance
4. **Given** joystick vector updates, **When** S_TouchscreenSystem.process_tick() runs, **Then** C_InputComponent.move_vector = virtual_joystick.get_vector()
5. **Given** player releases touch, **When** InputEventScreenTouch.pressed = false, **Then** VirtualJoystick resets to center, C_InputComponent.move_vector = Vector2.ZERO
6. **Given** player taps Jump button, **When** VirtualButton detects touch, **Then** C_InputComponent.jump_pressed = true for one frame
7. **Given** Bluetooth gamepad connected on mobile, **When** gamepad input detected, **Then** virtual controls auto-hide and M_InputDeviceManager switches to GAMEPAD
8. **Given** gamepad disconnects, **When** connection lost, **Then** virtual controls re-appear and M_InputDeviceManager switches to TOUCHSCREEN

**Edge Cases**:
- Player uses multiple fingers on joystick (tracks first touch, ignores others)
- Virtual joystick positioned under finger (visual feedback shows joystick offset)
- Screen rotates during gameplay (virtual controls reposition for new orientation)
- Low-end device with < 60 FPS (input still processed in _input() for low latency)

### User Story 6: Device Auto-Detection and Prompt Updates (Priority: P2)

**Description**: System automatically detects when player switches input devices (keyboard → gamepad) and updates button prompts in UI without manual configuration.

**Why this priority**: Quality of life feature that eliminates manual device selection. Creates seamless experience when players switch between keyboard and controller.

**Independent Test**: Launch game with keyboard → Use WASD to move → HUD shows "Press [E] to interact" → Plug in gamepad → Press A button → HUD updates to "Press [A] to interact" within one frame.

**Acceptance Scenarios**:

1. **Given** player using keyboard, **When** M_InputDeviceManager detects InputEventKey, **Then** active_device = KEYBOARD_MOUSE
2. **Given** player connects gamepad, **When** InputEventJoypadButton detected, **Then** M_InputDeviceManager.device_changed signal emits with GAMEPAD
3. **Given** device_changed signal emits, **When** HUD receives signal, **Then** U_ButtonPromptRegistry.get_prompt() called with new device type
4. **Given** U_ButtonPromptRegistry queried, **When** get_prompt("interact", GAMEPAD) called, **Then** returns generic gamepad South button icon Texture2D
5. **Given** new prompt texture returned, **When** HUD updates, **Then** interact prompt label changes from "Press [E]" to shows gamepad button icon within one frame
6. **Given** player switches back to keyboard, **When** InputEventKey detected, **Then** HUD updates back to "Press [E]" keyboard prompt
7. **Given** no input received for 10 seconds, **When** active_device unchanged, **Then** device detection remains stable (no false switches)
8. **Given** both keyboard and gamepad provide simultaneous input, **When** blended input processed, **Then** active_device = last input device used (for prompt purposes)

**Edge Cases**:
- Multiple gamepads connected (first to send input becomes active)
- Device unplugged during active input (input continues with fallback device)
- Button prompt assets missing for device (falls back to text labels)
- Rapid device switching (debounce device_changed signal to prevent spam)

### User Story 7: Accessibility Profiles (Priority: P2)

**Description**: Players with motor impairments or special needs can select accessibility-focused control schemes with larger input buffer windows, toggle vs hold options, and simplified controls.

**Why this priority**: Inclusivity and legal compliance (ADA, accessibility guidelines). Enables more players to enjoy the game regardless of physical abilities.

**Independent Test**: Open Settings → Select "Accessibility" profile → Notice jump buffer increased from 0.1s to 0.3s → Configure Sprint as toggle instead of hold → Verify controls accommodate players with limited dexterity.

**Acceptance Scenarios**:

1. **Given** player selects "Accessibility" profile, **When** profile loads, **Then** C_InputComponent.jump_buffer_time increases from 0.1s to 0.3s
2. **Given** "Accessibility" profile active, **When** Sprint configured as toggle, **Then** first press of Shift toggles sprint on, second press toggles off (no hold required)
3. **Given** accessibility profile active, **When** player presses Jump within 0.3s of landing, **Then** jump buffering triggers jump even with slower reaction time
4. **Given** larger deadzone configured (0.4 vs 0.2), **When** analog stick input below 0.4, **Then** move_vector = Vector2.ZERO (accommodates hand tremors)
5. **Given** player enables "hold to activate" for interact, **When** player holds E for 0.5s near door, **Then** door interaction triggers (prevents accidental activation)
6. **Given** accessibility profile saved, **When** game restarts, **Then** accessibility settings persist (buffer times, toggle modes, deadzones)
7. **Given** player switches from accessibility to default, **When** profile changed, **Then** buffer/toggle settings revert to standard values
8. **Given** accessibility documentation enabled, **When** player opens help, **Then** shows clear descriptions of each accessibility option

**Edge Cases**:
- Toggle mode conflicts with existing mechanics (document incompatibilities)
- Extreme buffer windows (> 1s) causing unintended inputs (cap at reasonable maximum)
- Accessibility profile on gamepad (larger deadzones accommodate physical limitations)

## Functional Requirements

### Core Input Handling

- **FR-001**: System MUST capture keyboard input via S_InputSystem using Godot's Input singleton
- **FR-002**: System MUST capture mouse input with delta tracking for look direction
- **FR-003**: System MUST capture gamepad input (analog sticks, buttons, triggers, bumpers)
- **FR-004**: System MUST capture touchscreen input on mobile platforms (touch, drag, release)
- **FR-005**: System MUST update C_InputComponent fields (move_vector, jump_pressed, sprint_pressed) every physics frame
- **FR-006**: System MUST dispatch input state to state store via U_InputActions every physics frame
- **FR-007**: System MUST respect pause state - input ignored when game paused (except pause action)
- **FR-008**: System MUST respect cursor capture mode - mouse delta only processed when cursor captured
- **FR-009**: System MUST block input during scene transitions (via M_SceneManager.is_transitioning check)
- **FR-010**: System MUST use Input.get_vector() for movement to handle diagonal input and deadzones correctly

### Input Profiles

- **FR-011**: System MUST support multiple input profiles stored as RS_InputProfile resources
- **FR-012**: System MUST include 3 built-in profiles: Default, Alternate, Accessibility
- **FR-013**: System MUST include generic gamepad profile that works across all controller types
- **FR-014**: System MUST allow runtime profile switching via M_InputProfileManager
- **FR-015**: System MUST apply profile changes to InputMap within 200ms
- **FR-016**: System MUST persist active profile selection in settings slice
- **FR-017**: System MUST load active profile on game initialization from saved settings
- **FR-018**: System MUST default to "default" profile if no saved profile exists
- **FR-019**: System MUST prevent profile switching during active gameplay (require pause first)
- **FR-020**: System MUST clear input state (move_vector, button presses) when switching profiles

### Rebinding System

- **FR-021**: System MUST allow players to rebind any non-reserved action
- **FR-022**: System MUST mark critical actions as reserved (pause, interact) via RS_RebindSettings
- **FR-023**: System MUST detect binding conflicts when player rebinds an action
- **FR-024**: System MUST show warning dialog when rebind conflicts with existing binding
- **FR-025**: System MUST allow player to confirm conflict and swap bindings
- **FR-026**: System MUST allow player to cancel rebind operation
- **FR-027**: System MUST validate rebind via U_InputRebindUtils.validate_rebind() before applying
- **FR-028**: System MUST save custom bindings to user://global_settings.json within 100ms
- **FR-029**: System MUST load custom bindings on initialization and apply to InputMap
- **FR-030**: System MUST provide "Reset to Default" function to clear all custom bindings
- **FR-031**: System MUST support multiple InputEvents per action (e.g., Jump = Space OR Gamepad A)
- **FR-032**: System MUST handle corrupted save files gracefully (log error, load defaults)

### Gamepad Support

- **FR-033**: System MUST detect gamepad connection via Input.get_connected_joypads()
- **FR-034**: System MUST handle InputEventJoypadButton for button presses
- **FR-035**: System MUST handle InputEventJoypadMotion for analog stick input
- **FR-036**: System MUST apply deadzone filtering to analog sticks (configurable, default 0.2)
- **FR-037**: System MUST normalize analog stick values above deadzone to 0.0-1.0 range
- **FR-038**: System MUST support gamepad vibration via Input.start_joy_vibration()
- **FR-039**: System MUST track gamepad device_id (0-7) in C_GamepadComponent
- **FR-040**: System MUST emit gamepad_connected signal when gamepad detected
- **FR-041**: System MUST emit gamepad_disconnected signal when gamepad removed
- **FR-042**: System MUST auto-switch to KEYBOARD_MOUSE when gamepad disconnects mid-game
- **FR-043**: System MUST use first gamepad to send input when multiple gamepads connected
- **FR-044**: System MUST use Godot's SDL gamepad mapping database for button mapping
- **FR-045**: System MUST handle vibration gracefully on devices that don't support it (no crash)

### Touchscreen Support

**Architecture Review (2025-11-13)**: See `docs/input_manager/phase-6-touchscreen-architecture.md` for detailed audit and user decisions.

**User Decisions:**
- Draggable control positioning (saved globally, not per-profile)
- Auto-hide when gamepad/keyboard detected on mobile
- Hide during pause menu, visible during scene transitions
- Landscape orientation only (no rotation support in Phase 6)
- Kenney.nl assets for virtual control visuals
- Physical mobile device available for QA; desktop `--emulate-mobile` flag kept as developer fallback
- Default touchscreen profile for reset capability

- **FR-046**: System MUST instantiate virtual controls when `OS.has_feature("mobile") = true` OR `_is_emulate_mode() = true` (developer fallback for desktop)
- **FR-046-A**: System MUST provide desktop emulation mode via `--emulate-mobile` command-line flag (fallback; primary QA uses physical device)
- **FR-046-B**: System MUST destroy MobileControls layer if not mobile and not emulation mode (NEW: `queue_free()` on `_ready()`)
- **FR-047**: System MUST provide VirtualJoystick for movement on left side of screen (default position: Vector2(120, 520))
- **FR-047-A**: System MUST save custom VirtualJoystick position to `settings.input_settings.touchscreen_settings.custom_joystick_position` (NEW: draggable positioning)
- **FR-047-B**: System MUST load saved VirtualJoystick position on startup, fall back to profile default if custom position = Vector2(-1, -1) (NEW)
- **FR-048**: System MUST provide VirtualButton nodes for actions (Jump, Sprint) on right side (default: Jump=Vector2(920, 520), Sprint=Vector2(820, 480)). **Status (2025-11-20):** ✅ Implemented via `scripts/ui/virtual_button.gd`, `scenes/ui/virtual_button.tscn`, and `tests/unit/ui/test_virtual_button.gd` (press/release, drag-out, tap vs hold, multi-touch, reposition save, visual feedback).
- **FR-048-A**: System MUST save custom VirtualButton positions to `touchscreen_settings.custom_button_positions` dictionary (NEW: draggable positioning)
- **FR-049**: System MUST track touch within VirtualJoystick area, NOT show joystick at arbitrary touch points (CLARIFIED: fixed joystick position, not floating)
- **FR-050**: System MUST update move_vector based on VirtualJoystick drag distance/direction, apply deadzone via `RS_TouchscreenSettings.apply_touch_deadzone()`
- **FR-051**: System MUST reset VirtualJoystick to center when touch released, emit `joystick_released()` signal
- **FR-052**: System MUST process touch input in `_input()` for low latency (not `_physics_process`), VirtualJoystick/VirtualButton handle input capture
- **FR-052-A**: System MUST update C_InputComponent from S_TouchscreenSystem in `process_tick()` (1 frame lag acceptable) (NEW: system integration pattern)
- **FR-053**: System MUST auto-hide virtual controls when Bluetooth gamepad OR keyboard detected on mobile (CLARIFIED: keyboard also triggers hide)
- **FR-053-A**: System MUST hide virtual controls when pause menu overlay active (NEW: user decision)
- **FR-053-B**: System MUST keep virtual controls visible during scene transitions (ignore `is_transitioning` flag) (NEW: user decision)
- **FR-054**: System MUST re-show virtual controls when gamepad/keyboard input stops and touchscreen input detected
- **FR-055**: System MUST track first touch for joystick via `_touch_id: int`, ignore touches with different IDs (multi-touch safe)
- **FR-055-A**: System MUST allow simultaneous joystick + button presses (different fingers, different touch IDs) (NEW: multi-touch clarification)
- **FR-056**: ~~System MUST handle screen rotation and reposition virtual controls appropriately~~ (REMOVED: Phase 6 locks to landscape orientation, defer rotation to Phase 7)
- **FR-056-A**: System MUST lock orientation to landscape via `project.godot` display settings (NEW: user decision)
- **FR-056-B**: System MUST reduce virtual control opacity to 50% during scene transitions (NEW: Gap Fill - visual feedback that input is blocked)
- **FR-056-C**: Touchscreen profile MUST define virtual button list via metadata array with actions and positions (NEW: Gap Fill - metadata-driven configuration)
- **FR-056-D**: System MUST provide Edit Touch Controls overlay with drag mode toggle, save/reset/cancel buttons (NEW: Gap Fill - layout customization)
- **FR-056-E**: System MUST provide Touchscreen Settings overlay with sliders for size, opacity, deadzone, and live preview (NEW: Gap Fill - settings UI)
- **FR-056-F**: HUD MUST calculate and apply safe area margins (bottom 150px, left/right 200px) on mobile to avoid virtual control overlap (NEW: Gap Fill)
- **FR-056-G**: System MUST log "Mobile emulation mode enabled" to console when emulation active (NEW: Gap Fill - developer fallback visibility)
- **FR-056-H**: System MUST validate save file migration from Phase 5 to Phase 6 touchscreen schema via integration test (NEW: Gap Fill)

### Device Detection

- **FR-057**: System MUST track active input device type (KEYBOARD_MOUSE, GAMEPAD, TOUCHSCREEN)
- **FR-058**: System MUST auto-detect device type based on last input received
- **FR-059**: System MUST emit device_changed signal when active device switches
- **FR-060**: System MUST update active_device within one frame of new device input
- **FR-061**: System MUST dispatch ACTION_DEVICE_CHANGED to state store on device switch
- **FR-062**: System MUST persist active_device in gameplay slice (transient, not saved)
- **FR-063**: System MUST allow simultaneous input from multiple devices (keyboard + mouse)
- **FR-064**: System MUST use last-used device for button prompt selection purposes
- **FR-065**: System MUST remain stable when no input received (no false device switches)

### Button Prompt System

- **FR-066**: System MUST provide U_ButtonPromptRegistry for mapping actions to device-specific icons
- **FR-067**: System MUST support button prompt assets for Generic Gamepad and Keyboard
- **FR-068**: System MUST return appropriate Texture2D icon via get_prompt(action, device)
- **FR-069**: System MUST update HUD button prompts when device_changed signal emits
- **FR-070**: System MUST update button prompts within one frame of device change
- **FR-071**: System MUST fall back to text labels if button prompt asset missing
- **FR-072**: System MUST handle custom rebindings in button prompt display (show custom key)

### State Integration

- **FR-073**: System MUST maintain input state in gameplay slice (runtime)
- **FR-074**: System MUST maintain input settings in settings slice (persistent)
- **FR-075**: System MUST dispatch input actions via U_InputActions action creators
- **FR-076**: System MUST handle input actions in reducer (U_GameplayReducer or U_InputReducer)
- **FR-077**: System MUST provide selectors via U_InputSelectors for querying input state
- **FR-078**: System MUST persist input settings across scene transitions via StateHandoff
- **FR-079**: System MUST save input settings to disk when changed
- **FR-080**: System MUST validate state schema on load (handle missing/invalid fields)

### ECS Integration

- **FR-081**: All input components MUST extend ECSComponent base class
- **FR-082**: All input systems MUST extend ECSSystem base class
- **FR-083**: C_InputComponent MUST define COMPONENT_TYPE constant
- **FR-084**: C_GamepadComponent MUST define COMPONENT_TYPE constant
- **FR-085**: Systems MUST query components via M_ECSManager.get_components(COMPONENT_TYPE)
- **FR-086**: Systems MUST auto-discover M_ECSManager via parent traversal or group
- **FR-087**: Components MUST auto-register with M_ECSManager on _ready()
- **FR-088**: Systems MUST run in _physics_process via process_tick(delta) pattern

### Manager Integration

- **FR-089**: M_InputProfileManager MUST be in-scene node (added to root.tscn, not autoload)
- **FR-090**: M_InputDeviceManager MUST be in-scene node (added to root.tscn, not autoload)
- **FR-091**: Managers MUST add themselves to groups for discovery ("input_profile_manager", "input_device_manager")
- **FR-092**: Managers MUST initialize on _ready() before gameplay systems run
- **FR-093**: Managers MUST emit signals for state changes (profile_switched, device_changed)

### Persistence & Save/Load

- **FR-094**: System MUST save input settings to user://global_settings.json in JSON format
- **FR-095**: System MUST load input settings from user://global_settings.json on game start
- **FR-096**: Save file MUST include version number for migration compatibility
- **FR-097**: Save file MUST include active_profile_id
- **FR-098**: Save file MUST include custom_bindings dictionary (action → events)
- **FR-099**: Save file MUST include gamepad_settings (deadzone, vibration preferences)
- **FR-100**: Save file MUST include mouse_settings (sensitivity, invert_y_axis)
- **FR-101**: Save file MUST include touchscreen_settings (joystick size, opacity, layout)
- **FR-102**: System MUST handle missing save file (create with defaults)
- **FR-103**: System MUST handle corrupted save file (log error, load defaults, backup corrupted file)

### Input Buffering

- **FR-104**: System MUST support jump buffering (already implemented in C_InputComponent)
- **FR-105**: Jump buffer window MUST be configurable (default 0.1s, accessibility 0.3s)
- **FR-106**: System MUST track buffer timestamp for each buffered action
- **FR-107**: System MUST consume buffered input when condition met (e.g., on landing)
- **FR-108**: System MUST clear input buffers on scene transition start
- **FR-109**: System MUST support buffer window configuration per profile

### Accessibility

- **FR-110**: Accessibility profile MUST support larger buffer windows (0.3s+ vs 0.1s)
- **FR-111**: Accessibility profile MUST support toggle mode for hold actions (Sprint)
- **FR-112**: Accessibility profile MUST support larger deadzones (0.4+ vs 0.2)
- **FR-113**: Accessibility profile MUST support "hold to activate" for interactions (0.5s hold)
- **FR-114**: Accessibility settings MUST persist across sessions
- **FR-115**: System MUST provide clear documentation for each accessibility option

### Performance

- **FR-116**: Input latency MUST be < 16ms (one frame) from hardware event to component update
- **FR-117**: Profile switching MUST complete < 200ms including InputMap updates
- **FR-118**: Custom bindings save MUST complete < 100ms
- **FR-119**: Virtual controls MUST maintain 60 FPS on mid-range mobile devices
- **FR-120**: Device detection MUST update active_device within one frame
- **FR-121**: Button prompt updates MUST complete within one frame of device change

### Error Handling

- **FR-122**: System MUST log warning if InputMap action missing, auto-initialize with defaults
- **FR-123**: System MUST handle gamepad disconnection without crash or freeze
- **FR-124**: System MUST handle missing button prompt assets without crash (fall back to text)
- **FR-125**: System MUST validate rebind input before applying (prevent invalid InputEvents)
- **FR-126**: System MUST handle profile resource load failure (log error, load default)
- **FR-127**: System MUST handle save file write failure (log error, show user notification)

### Testing

- **FR-128**: System MUST achieve 90%+ code coverage via GUT unit tests
- **FR-129**: System MUST include unit tests for all components (C_InputComponent, C_GamepadComponent)
- **FR-130**: System MUST include unit tests for all systems (S_InputSystem, S_TouchscreenSystem)
- **FR-131**: System MUST include unit tests for all managers (M_InputProfileManager, M_InputDeviceManager)
- **FR-132**: System MUST include unit tests for all utilities (U_InputRebindUtils, U_ButtonPromptRegistry)
- **FR-133**: System MUST include integration tests for profile switching
- **FR-134**: System MUST include integration tests for device detection and handoff
- **FR-135**: System MUST include integration tests for rebinding workflow
- **FR-136**: System MUST include integration tests for save/load persistence

## Technical Specifications

### Input State Slice Schema

The Input Manager maintains state in two slices of the Redux store:

#### Gameplay Slice (Runtime State - Transient)

```gdscript
# Part of existing gameplay slice - extends current structure
{
  # ... existing gameplay fields (entities, scene_id, spawn_point, etc.)
  "input": {
    "active_device": int,                  # DeviceType enum: 0=KEYBOARD_MOUSE, 1=GAMEPAD, 2=TOUCHSCREEN
    "last_input_time": float,              # Timestamp of last input (Time.get_ticks_msec() / 1000.0)
    "gamepad_connected": bool,             # Whether gamepad is currently connected
    "gamepad_device_id": int,              # Joypad device ID (0-7, -1 if none)
    "touchscreen_enabled": bool,           # Whether virtual controls are visible/active
    "move_input": Vector2,                 # Current move vector (duplicates C_InputComponent for state visibility)
    "look_input": Vector2,                 # Current look delta (mouse or right stick)
    "jump_pressed": bool,                  # Current jump state
    "jump_just_pressed": bool,             # Jump pressed this frame
    "sprint_pressed": bool                 # Current sprint state
  }
}
```

#### Settings Slice (Persistent State - Saved to Disk)

```gdscript
# New settings.input_settings field in settings slice
{
  # ... existing settings fields (audio, graphics, etc.)
  "input_settings": {
    "active_profile_id": String,           # e.g., "default", "alternate", "accessibility", "gamepad_xbox"
    "custom_bindings": {                   # Dictionary of custom rebindings
      # StringName action → Array of event dictionaries
      "jump": [
        {"type": "key", "keycode": 32},    # Space
        {"type": "joypad_button", "button_index": 0}  # A button (Xbox)
      ],
      "move_forward": [
        {"type": "key", "keycode": 87}     # W
      ]
    },
    "gamepad_settings": {
      "left_stick_deadzone": float,        # 0.0-1.0, default 0.2
      "right_stick_deadzone": float,       # 0.0-1.0, default 0.2
      "vibration_enabled": bool,           # default true
      "vibration_intensity": float,        # 0.0-1.0, default 1.0
      "invert_y_axis": bool                # default false
    },
    "mouse_settings": {
      "sensitivity": float,                # 0.1-5.0, default 1.0
      "invert_y_axis": bool                # default false
    },
    "touchscreen_settings": {
      "virtual_joystick_size": float,      # Scale factor 0.5-2.0, default 1.0
      "virtual_joystick_opacity": float,   # 0.0-1.0, default 0.7
      "button_layout": String,             # "default" or "left_handed"
      "button_size": float                 # Scale factor 0.5-2.0, default 1.0
    },
    "accessibility": {
      "jump_buffer_time": float,           # Seconds, default 0.1, accessibility 0.3
      "sprint_toggle_mode": bool,          # false = hold, true = toggle, default false
      "interact_hold_duration": float      # Seconds to hold E, default 0.0 (instant), accessibility 0.5
    }
  }
}
```

### Action Type Definitions

```gdscript
# scripts/state/actions/u_input_actions.gd

class_name U_InputActions extends RefCounted

# Action type constants
const ACTION_UPDATE_MOVE_INPUT := StringName("input/update_move_input")
const ACTION_UPDATE_LOOK_INPUT := StringName("input/update_look_input")
const ACTION_UPDATE_JUMP_STATE := StringName("input/update_jump_state")
const ACTION_UPDATE_SPRINT_STATE := StringName("input/update_sprint_state")
const ACTION_DEVICE_CHANGED := StringName("input/device_changed")
const ACTION_GAMEPAD_CONNECTED := StringName("input/gamepad_connected")
const ACTION_GAMEPAD_DISCONNECTED := StringName("input/gamepad_disconnected")
const ACTION_PROFILE_SWITCHED := StringName("input/profile_switched")
const ACTION_REBIND_ACTION := StringName("input/rebind_action")
const ACTION_RESET_BINDINGS := StringName("input/reset_bindings")
const ACTION_UPDATE_GAMEPAD_DEADZONE := StringName("input/update_gamepad_deadzone")
const ACTION_TOGGLE_VIBRATION := StringName("input/toggle_vibration")
const ACTION_UPDATE_MOUSE_SENSITIVITY := StringName("input/update_mouse_sensitivity")
const ACTION_UPDATE_ACCESSIBILITY := StringName("input/update_accessibility")

# Action creators (return action dictionaries)

static func update_move_input(move_vector: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_MOVE_INPUT,
		"payload": {"move_vector": move_vector}
	}

static func update_look_input(look_delta: Vector2) -> Dictionary:
	return {
		"type": ACTION_UPDATE_LOOK_INPUT,
		"payload": {"look_delta": look_delta}
	}

static func update_jump_state(pressed: bool, just_pressed: bool) -> Dictionary:
	return {
		"type": ACTION_UPDATE_JUMP_STATE,
		"payload": {"pressed": pressed, "just_pressed": just_pressed}
	}

static func update_sprint_state(pressed: bool) -> Dictionary:
	return {
		"type": ACTION_UPDATE_SPRINT_STATE,
		"payload": {"pressed": pressed}
	}

static func device_changed(device_type: int, device_id: int = -1) -> Dictionary:
	return {
		"type": ACTION_DEVICE_CHANGED,
		"payload": {"device_type": device_type, "device_id": device_id}
	}

static func gamepad_connected(device_id: int) -> Dictionary:
	return {
		"type": ACTION_GAMEPAD_CONNECTED,
		"payload": {"device_id": device_id}
	}

static func gamepad_disconnected(device_id: int) -> Dictionary:
	return {
		"type": ACTION_GAMEPAD_DISCONNECTED,
		"payload": {"device_id": device_id}
	}

static func profile_switched(profile_id: String) -> Dictionary:
	return {
		"type": ACTION_PROFILE_SWITCHED,
		"payload": {"profile_id": profile_id}
	}

static func rebind_action(action_name: StringName, event_data: Dictionary) -> Dictionary:
	return {
		"type": ACTION_REBIND_ACTION,
		"payload": {"action": action_name, "event": event_data}
	}

static func reset_bindings() -> Dictionary:
	return {"type": ACTION_RESET_BINDINGS, "payload": {}}

static func update_gamepad_deadzone(stick: String, deadzone: float) -> Dictionary:
	return {
		"type": ACTION_UPDATE_GAMEPAD_DEADZONE,
		"payload": {"stick": stick, "deadzone": deadzone}
	}

static func toggle_vibration(enabled: bool) -> Dictionary:
	return {
		"type": ACTION_TOGGLE_VIBRATION,
		"payload": {"enabled": enabled}
	}

static func update_mouse_sensitivity(sensitivity: float) -> Dictionary:
	return {
		"type": ACTION_UPDATE_MOUSE_SENSITIVITY,
		"payload": {"sensitivity": sensitivity}
	}

static func update_accessibility(field: String, value) -> Dictionary:
	return {
		"type": ACTION_UPDATE_ACCESSIBILITY,
		"payload": {"field": field, "value": value}
	}
```

### API Signatures

#### M_InputProfileManager

```gdscript
# scripts/managers/m_input_profile_manager.gd
class_name M_InputProfileManager extends Node

# Signals
signal profile_switched(profile_id: String)
signal bindings_reset()
signal custom_binding_added(action: StringName, event: InputEvent)

# Properties
var active_profile: RS_InputProfile
var custom_bindings: Dictionary = {}  # StringName → Array[InputEvent]
var available_profiles: Dictionary = {}  # String → RS_InputProfile

# Public Methods

## Loads a profile by ID and applies it to InputMap
## Returns true if successful, false if profile not found
func load_profile(profile_id: String) -> bool

## Returns the currently active profile resource
func get_active_profile() -> RS_InputProfile

## Switches to a different profile, clearing input state
## Validates game is paused before allowing switch
## Emits profile_switched signal on success
func switch_profile(profile_id: String) -> void

## Saves current custom bindings to user://global_settings.json
## Returns true if save successful
func save_custom_bindings() -> bool

## Loads custom bindings from user://global_settings.json
## Applies bindings on top of active profile
## Returns true if load successful (false if file missing/corrupted)
func load_custom_bindings() -> bool

## Resets all custom bindings, reverts to active profile defaults
## Emits bindings_reset signal
func reset_to_defaults() -> void

## Returns list of available profile IDs
func get_available_profile_ids() -> Array[String]

## Applies profile's action mappings to Godot's InputMap
## Clears existing events for each action before adding new ones
func _apply_profile_to_input_map(profile: RS_InputProfile) -> void

## Converts custom bindings to JSON-serializable format
func _bindings_to_dict() -> Dictionary

## Reconstructs InputEvents from JSON dictionary
func _dict_to_bindings(data: Dictionary) -> Dictionary
```

#### M_InputDeviceManager

```gdscript
# scripts/managers/m_input_device_manager.gd
class_name M_InputDeviceManager extends Node

# Device type enum (must match state store schema)
enum DeviceType {
	KEYBOARD_MOUSE = 0,
	GAMEPAD = 1,
	TOUCHSCREEN = 2
}

# Signals
signal device_changed(device_type: DeviceType)
signal gamepad_connected(device_id: int)
signal gamepad_disconnected(device_id: int)

# Properties
var active_device: DeviceType = DeviceType.KEYBOARD_MOUSE
var gamepad_device_id: int = -1
var last_input_time: float = 0.0

# Public Methods

## Returns the currently active device type
func get_active_device() -> DeviceType

## Returns the active gamepad device ID (0-7, or -1 if none)
func get_gamepad_device_id() -> int

## Checks for connected gamepads and updates state
## Called on _ready() and when gamepad events detected
func detect_gamepads() -> void

## Manually sets the active device (used for testing/overrides)
func set_active_device(device: DeviceType) -> void

## Internal: Handles input events to detect device switches
func _input(event: InputEvent) -> void

## Internal: Updates active_device and emits signals
func _switch_device(new_device: DeviceType) -> void
```

#### U_InputRebindUtils

```gdscript
# scripts/input/u_input_rebind_utils.gd
class_name U_InputRebindUtils extends RefCounted

# Validation result structure
class ValidationResult:
	var valid: bool
	var error: String
	var conflict: StringName  # Action that conflicts, or empty

## Validates a rebind attempt
## Checks for reserved actions and conflicts
## Returns ValidationResult with details
static func validate_rebind(
	action: StringName,
	event: InputEvent,
	settings: RS_RebindSettings
) -> ValidationResult

## Applies a rebind to InputMap
## Removes old events for the action, adds new event
## Returns true if successful
static func rebind_action(
	action: StringName,
	event: InputEvent
) -> bool

## Checks if an InputEvent conflicts with existing bindings
## Returns the conflicting action name, or empty StringName if no conflict
static func get_conflicting_action(event: InputEvent) -> StringName

## Checks if an action is marked as reserved (cannot be rebound)
static func is_reserved_action(action: StringName, settings: RS_RebindSettings) -> bool

## Converts InputEvent to JSON-serializable dictionary
static func event_to_dict(event: InputEvent) -> Dictionary

## Reconstructs InputEvent from dictionary
static func dict_to_event(data: Dictionary) -> InputEvent
```

#### U_ButtonPromptRegistry

```gdscript
# scripts/input/u_button_prompt_registry.gd
class_name U_ButtonPromptRegistry extends RefCounted

# Prompt maps (action → device → Texture2D path)
static var _prompt_registry: Dictionary = {}

## Initializes the registry with button prompt asset paths
## Called automatically on first use (lazy initialization)
static func _initialize_registry() -> void

## Returns the appropriate button prompt icon for an action and device
## Falls back to text label if asset missing
static func get_prompt(action: StringName, device: int) -> Texture2D

## Returns text label for action if no icon available
## Examples: "Press [E]", "Press [A]", "Tap Jump"
static func get_prompt_text(action: StringName, device: int) -> String

## Registers a custom prompt asset for an action/device combination
static func register_prompt(action: StringName, device: int, texture_path: String) -> void
```

#### C_GamepadComponent

```gdscript
# scripts/ecs/components/c_gamepadcomponent.gd
class_name C_GamepadComponent extends ECSComponent

const COMPONENT_TYPE := StringName("C_GamepadComponent")

# Gamepad state
@export var device_id: int = -1
@export var is_connected: bool = false

# Vibration settings
@export var vibration_enabled: bool = true
@export_range(0.0, 1.0) var vibration_intensity: float = 1.0

# Deadzone settings
@export_range(0.0, 1.0) var left_stick_deadzone: float = 0.2
@export_range(0.0, 1.0) var right_stick_deadzone: float = 0.2

# Analog stick values (after deadzone filtering)
var left_stick: Vector2 = Vector2.ZERO
var right_stick: Vector2 = Vector2.ZERO

# Button states (cached for frame-to-frame comparison)
var button_states: Dictionary = {}  # JoyButton → bool

## Applies rumble/vibration to the gamepad
## weak_magnitude: 0.0-1.0 for low-frequency motor
## strong_magnitude: 0.0-1.0 for high-frequency motor
## duration: seconds to vibrate
func apply_rumble(weak_magnitude: float, strong_magnitude: float, duration: float) -> void:
	if not vibration_enabled or device_id < 0:
		return
	var adjusted_weak := weak_magnitude * vibration_intensity
	var adjusted_strong := strong_magnitude * vibration_intensity
	Input.start_joy_vibration(device_id, adjusted_weak, adjusted_strong, duration)

## Stops all vibration immediately
func stop_rumble() -> void:
	if device_id >= 0:
		Input.stop_joy_vibration(device_id)

## Applies deadzone filtering to analog stick input
## Returns Vector2.ZERO if magnitude below deadzone
## Normalizes to 0.0-1.0 range if above deadzone
func apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
	var magnitude := input.length()
	if magnitude < deadzone:
		return Vector2.ZERO
	# Normalize to 0.0-1.0 range above deadzone
	var normalized_magnitude := (magnitude - deadzone) / (1.0 - deadzone)
	return input.normalized() * normalized_magnitude

## Component initialization
func _init() -> void:
	component_type = COMPONENT_TYPE
```

#### S_TouchscreenSystem

```gdscript
# scripts/ecs/systems/s_touchscreen_system.gd
class_name S_TouchscreenSystem extends ECSSystem

# References to virtual controls (set by scene)
@export var virtual_joystick_path: NodePath
@export var virtual_jump_button_path: NodePath
@export var virtual_sprint_button_path: NodePath

var virtual_joystick: VirtualJoystick
var virtual_jump_button: VirtualButton
var virtual_sprint_button: VirtualButton

## Called every physics frame to update input components from virtual controls
func process_tick(delta: float) -> void:
	if not virtual_joystick:
		return

	# Update all C_InputComponents with virtual control state
	for component in query_entities(C_InputComponent.COMPONENT_TYPE):
		if virtual_joystick.is_active():
			component.move_vector = virtual_joystick.get_vector()
		else:
			component.move_vector = Vector2.ZERO

		component.jump_pressed = virtual_jump_button.is_pressed() if virtual_jump_button else false
		component.sprint_pressed = virtual_sprint_button.is_pressed() if virtual_sprint_button else false

## Shows virtual controls (called when gamepad disconnects on mobile)
func show_virtual_controls() -> void:
	if virtual_joystick:
		virtual_joystick.show()
	if virtual_jump_button:
		virtual_jump_button.show()
	if virtual_sprint_button:
		virtual_sprint_button.show()

## Hides virtual controls (called when gamepad connects on mobile)
func hide_virtual_controls() -> void:
	if virtual_joystick:
		virtual_joystick.hide()
	if virtual_jump_button:
		virtual_jump_button.hide()
	if virtual_sprint_button:
		virtual_sprint_button.hide()

func _ready() -> void:
	super._ready()
	# Resolve NodePaths
	virtual_joystick = get_node_or_null(virtual_joystick_path) as VirtualJoystick
	virtual_jump_button = get_node_or_null(virtual_jump_button_path) as VirtualButton
	virtual_sprint_button = get_node_or_null(virtual_sprint_button_path) as VirtualButton
```

#### VirtualJoystick

```gdscript
# scripts/ui/virtual_joystick.gd
class_name VirtualJoystick extends Control

signal joystick_moved(vector: Vector2)

@export_range(50.0, 200.0) var radius: float = 100.0
@export_range(0.0, 1.0) var opacity: float = 0.7
@export var reset_on_release: bool = true

var touch_index: int = -1
var center_position: Vector2
var current_vector: Vector2 = Vector2.ZERO

## Returns the current joystick vector (-1.0 to 1.0 in both axes)
func get_vector() -> Vector2:
	return current_vector

## Returns true if joystick is currently being touched
func is_active() -> bool:
	return touch_index >= 0

## Handles touch input events
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed and touch_index < 0:
		# Start tracking this touch
		touch_index = event.index
		center_position = event.position
		show()  # Make joystick visible at touch point
	elif not event.pressed and event.index == touch_index:
		# Release touch
		touch_index = -1
		current_vector = Vector2.ZERO
		if reset_on_release:
			hide()
		joystick_moved.emit(current_vector)

func _handle_drag(event: InputEventScreenDrag) -> void:
	if event.index != touch_index:
		return

	var offset := event.position - center_position
	var distance := offset.length()

	if distance > radius:
		offset = offset.normalized() * radius

	current_vector = offset / radius  # Normalize to -1.0 to 1.0
	joystick_moved.emit(current_vector)
```

#### VirtualButton

```gdscript
# scripts/ui/virtual_button.gd
class_name VirtualButton extends Button

signal button_pressed()
signal button_released()

var _is_pressed: bool = false
var touch_index: int = -1

## Returns true if button is currently pressed
func is_pressed() -> bool:
	return _is_pressed

## Handles touch input for button
func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and touch_index < 0:
			touch_index = event.index
			_is_pressed = true
			button_pressed.emit()
		elif not event.pressed and event.index == touch_index:
			touch_index = -1
			_is_pressed = false
			button_released.emit()
```

### Resource Schemas

#### RS_InputProfile

```gdscript
# scripts/input/resources/rs_input_profile.gd
extends Resource
class_name RS_InputProfile

## Profile name displayed in UI
@export var profile_name: String = "Default"

## Device type this profile is designed for
@export_enum("Keyboard/Mouse:0", "Gamepad:1", "Touchscreen:2") var device_type: int = 0

## Action mappings: StringName action → Array[InputEvent]
## Each action can have multiple input events (e.g., Jump = Space OR Gamepad A)
@export var action_mappings: Dictionary = {}

## Human-readable description for settings menu
@export_multiline var description: String = "Standard WASD keyboard layout with Space to jump"

## Whether this is a built-in system profile (cannot be deleted by player)
@export var is_system_profile: bool = true

## Icon texture for profile selection UI (optional)
@export var profile_icon: Texture2D

## Accessibility settings for this profile (optional overrides)
@export_group("Accessibility")
@export_range(0.0, 1.0) var jump_buffer_time: float = 0.1
@export var sprint_toggle_mode: bool = false
@export_range(0.0, 2.0) var interact_hold_duration: float = 0.0

## Returns InputEvents for a specific action
func get_events_for_action(action: StringName) -> Array[InputEvent]:
	if not action_mappings.has(action):
		return []
	return action_mappings[action].duplicate()

## Sets InputEvents for a specific action
func set_events_for_action(action: StringName, events: Array[InputEvent]) -> void:
	action_mappings[action] = events.duplicate()

## Converts profile to JSON-serializable Dictionary
func to_dictionary() -> Dictionary:
	var result := {
		"profile_name": profile_name,
		"device_type": device_type,
		"description": description,
		"is_system_profile": is_system_profile,
		"action_mappings": {}
	}

	for action in action_mappings:
		var events_data := []
		for event in action_mappings[action]:
			events_data.append(_event_to_dict(event))
		result["action_mappings"][action] = events_data

	return result

## Loads profile from Dictionary
func from_dictionary(data: Dictionary) -> void:
	profile_name = data.get("profile_name", "Unnamed")
	device_type = data.get("device_type", 0)
	description = data.get("description", "")
	is_system_profile = data.get("is_system_profile", false)

	action_mappings.clear()
	var mappings: Dictionary = data.get("action_mappings", {})
	for action in mappings:
		var events := []
		for event_data in mappings[action]:
			var event := _dict_to_event(event_data)
			if event:
				events.append(event)
		if not events.is_empty():
			action_mappings[action] = events

## Internal: Converts InputEvent to Dictionary
func _event_to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {
			"type": "key",
			"keycode": event.keycode,
			"physical_keycode": event.physical_keycode,
			"unicode": event.unicode
		}
	elif event is InputEventMouseButton:
		return {
			"type": "mouse_button",
			"button_index": event.button_index
		}
	elif event is InputEventJoypadButton:
		return {
			"type": "joypad_button",
			"button_index": event.button_index
		}
	elif event is InputEventJoypadMotion:
		return {
			"type": "joypad_motion",
			"axis": event.axis,
			"axis_value": event.axis_value
		}
	else:
		push_warning("Unsupported InputEvent type: %s" % event.get_class())
		return {}

## Internal: Reconstructs InputEvent from Dictionary
func _dict_to_event(data: Dictionary) -> InputEvent:
	var event_type: String = data.get("type", "")

	match event_type:
		"key":
			var event := InputEventKey.new()
			event.keycode = data.get("keycode", 0)
			event.physical_keycode = data.get("physical_keycode", 0)
			event.unicode = data.get("unicode", 0)
			return event
		"mouse_button":
			var event := InputEventMouseButton.new()
			event.button_index = data.get("button_index", 0)
			return event
		"joypad_button":
			var event := InputEventJoypadButton.new()
			event.button_index = data.get("button_index", 0)
			return event
		"joypad_motion":
			var event := InputEventJoypadMotion.new()
			event.axis = data.get("axis", 0)
			event.axis_value = data.get("axis_value", 0.0)
			return event
		_:
			push_warning("Unknown event type: %s" % event_type)
			return null
```

#### RS_GamepadSettings

```gdscript
# scripts/input/resources/rs_gamepad_settings.gd
extends Resource
class_name RS_GamepadSettings

## Left analog stick deadzone (prevents drift)
@export_range(0.0, 1.0, 0.01) var left_stick_deadzone: float = 0.2

## Right analog stick deadzone (prevents drift)
@export_range(0.0, 1.0, 0.01) var right_stick_deadzone: float = 0.2

## Trigger deadzone (L2/R2, LT/RT)
@export_range(0.0, 1.0, 0.01) var trigger_deadzone: float = 0.1

## Enable/disable vibration globally
@export var vibration_enabled: bool = true

## Vibration intensity multiplier
@export_range(0.0, 1.0, 0.1) var vibration_intensity: float = 1.0

## Invert Y-axis for right stick (look/camera)
@export var invert_y_axis: bool = false

## Right stick sensitivity for camera/look
@export_range(0.1, 5.0, 0.1) var right_stick_sensitivity: float = 1.0

## Deadzone curve type
@export_enum("Linear:0", "Quadratic:1", "Cubic:2") var deadzone_curve: int = 0

## Apply deadzone with configured curve
func apply_deadzone(input: Vector2, deadzone: float) -> Vector2:
	var magnitude := input.length()
	if magnitude < deadzone:
		return Vector2.ZERO

	# Normalize above deadzone
	var normalized_magnitude := (magnitude - deadzone) / (1.0 - deadzone)

	# Apply curve
	match deadzone_curve:
		1:  # Quadratic
			normalized_magnitude = normalized_magnitude * normalized_magnitude
		2:  # Cubic
			normalized_magnitude = normalized_magnitude * normalized_magnitude * normalized_magnitude
		_:  # Linear (default)
			pass

	return input.normalized() * normalized_magnitude
```

#### RS_RebindSettings

```gdscript
# scripts/input/resources/rs_rebind_settings.gd
extends Resource
class_name RS_RebindSettings

## Actions that cannot be rebound (critical for gameplay)
@export var reserved_actions: Array[StringName] = [
	StringName("pause"),
	StringName("interact")
]

## Whether to allow multiple actions bound to same key (conflicts)
@export var allow_conflicts: bool = false

## Require confirmation dialog before applying rebind with conflict
@export var require_confirmation: bool = true

## Maximum number of InputEvents per action
@export_range(1, 10) var max_events_per_action: int = 3

## Whether to show warning for reserved action rebind attempts
@export var warn_on_reserved: bool = true

## Actions that trigger special warnings (not reserved but important)
@export var warning_actions: Array[StringName] = [
	StringName("toggle_debug_overlay")
]

## Checks if an action is reserved
func is_reserved(action: StringName) -> bool:
	return action in reserved_actions

## Checks if an action should show warning
func should_warn(action: StringName) -> bool:
	return action in warning_actions
```

#### RS_MouseSettings

```gdscript
# scripts/input/resources/rs_mouse_settings.gd
extends Resource
class_name RS_MouseSettings

## Mouse sensitivity multiplier
@export_range(0.1, 5.0, 0.1) var sensitivity: float = 1.0

## Invert Y-axis for mouse look
@export var invert_y_axis: bool = false

## Mouse smoothing (0 = no smoothing, higher = more smoothing)
@export_range(0.0, 1.0, 0.05) var smoothing: float = 0.0

## Mouse acceleration curve (0 = linear, higher = more acceleration)
@export_range(0.0, 2.0, 0.1) var acceleration: float = 0.0

## Apply sensitivity and transformations to mouse delta
func apply_settings(delta: Vector2) -> Vector2:
	var result := delta * sensitivity

	if invert_y_axis:
		result.y = -result.y

	# Apply acceleration if enabled
	if acceleration > 0.0:
		var magnitude := result.length()
		var accelerated := pow(magnitude, 1.0 + acceleration)
		if magnitude > 0.0:
			result = result.normalized() * accelerated

	return result
```

#### RS_TouchscreenSettings

```gdscript
# scripts/input/resources/rs_touchscreen_settings.gd
extends Resource
class_name RS_TouchscreenSettings

## Virtual joystick size multiplier
@export_range(0.5, 2.0, 0.1) var virtual_joystick_size: float = 1.0

## Virtual joystick opacity
@export_range(0.0, 1.0, 0.05) var virtual_joystick_opacity: float = 0.7

## Virtual button size multiplier
@export_range(0.5, 2.0, 0.1) var button_size: float = 1.0

## Virtual button opacity
@export_range(0.0, 1.0, 0.05) var button_opacity: float = 0.8

## Button layout preset
@export_enum("Default:0", "Left-Handed:1") var button_layout: int = 0

## Auto-hide virtual controls after inactivity (seconds, 0 = never hide)
@export_range(0.0, 10.0, 0.5) var auto_hide_delay: float = 0.0

## Joystick deadzone (same as gamepad deadzone concept)
@export_range(0.0, 0.5, 0.05) var joystick_deadzone: float = 0.15

## Enable haptic feedback on button press (if device supports)
@export var haptic_feedback: bool = true

## Joystick appears at touch point (true) or fixed position (false)
@export var floating_joystick: bool = true
```

## Test Organization & File Structure

### Test Structure

```
tests/
├── unit/
│   └── input/
│       ├── test_m_input_profile_manager.gd         # Profile loading, switching, persistence
│       ├── test_m_input_device_manager.gd          # Device detection, switching, signals
│       ├── test_u_input_rebind_utils.gd            # Rebind validation, conflict detection
│       ├── test_u_input_actions.gd                 # Action creator validation
│       ├── test_u_input_selectors.gd               # Selector query correctness
│       ├── test_input_reducer.gd                   # Input slice reducer tests
│       ├── test_s_input_system.gd                  # Input capture and processing (EXISTING - 3 tests)
│       ├── test_c_input_component.gd               # Component state management
│       ├── test_c_gamepad_component.gd             # Gamepad state, vibration, deadzone
│       ├── test_s_touchscreen_system.gd            # Touch input processing
│       ├── test_virtual_joystick.gd                # Virtual joystick vector calculation
│       ├── test_virtual_button.gd                  # Virtual button press/release
│       ├── test_u_button_prompt_registry.gd        # Prompt lookup, fallback logic
│       └── test_rs_input_profile.gd                # Profile serialization/deserialization
└── integration/
    └── input/
        ├── test_profile_switching_flow.gd          # End-to-end profile switch
        ├── test_rebinding_flow.gd                  # Full rebind workflow with UI
        ├── test_device_handoff.gd                  # Keyboard→gamepad→touch switching
        ├── test_input_persistence.gd               # Save/load round-trip
        ├── test_gamepad_disconnect.gd              # Gamepad removal during gameplay
        ├── test_input_during_transition.gd         # Input blocked during scenes (EXISTING - 1 test)
        ├── test_virtual_controls_visibility.gd     # Mobile virtual control show/hide
        └── test_keyboard_to_component_flow.gd      # Keyboard→S_InputSystem→C_InputComponent→State

```

### Test Commands

```bash
# Run all input unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input -gexit

# Run all input integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/input -gexit

# Run specific test suite
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gtest=test_m_input_profile_manager.gd -gexit

# Run all input tests (unit + integration)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/input,res://tests/integration/input -gexit
```

### Critical Test Scenarios

1. **Input Latency Test** (`test_s_input_system.gd`)
   - Dispatch 100 input events
   - Measure time from Input.is_action_pressed() to C_InputComponent update
   - Assert average latency < 16ms, max latency < 32ms

2. **Rebind Conflict Test** (`test_u_input_rebind_utils.gd`)
   - Bind Space to Jump
   - Attempt to bind Space to Sprint
   - Assert conflict detected with conflict=StringName("jump")
   - Confirm Space rebinding, assert Jump binding cleared

3. **Device Switch Test** (`test_m_input_device_manager.gd`)
   - Simulate InputEventKey
   - Assert active_device = KEYBOARD_MOUSE, device_changed signal emitted
   - Simulate InputEventJoypadButton
   - Assert active_device = GAMEPAD, device_changed signal emitted

4. **Profile Persistence Test** (`test_input_persistence.gd`)
   - Switch to "Alternate" profile
   - Save settings via M_InputProfileManager.save_custom_bindings()
   - Reload game (fresh M_InputProfileManager instance)
   - Assert active_profile_id = "alternate"

5. **Analog Deadzone Test** (`test_c_gamepad_component.gd`)
   - Send stick input Vector2(0.15, 0) (below 0.2 deadzone)
   - Assert apply_deadzone() returns Vector2.ZERO
   - Send stick input Vector2(0.3, 0) (above deadzone)
   - Assert apply_deadzone() returns normalized value > 0

6. **Vibration Test** (`test_c_gamepad_component.gd`)
   - Call apply_rumble(0.5, 0.8, 0.2)
   - Mock Input.start_joy_vibration()
   - Assert called with (device_id, 0.5, 0.8, 0.2)

7. **Virtual Joystick Test** (`test_virtual_joystick.gd`)
   - Simulate touch at center
   - Simulate drag 50 pixels right (radius=100)
   - Assert get_vector() returns Vector2(0.5, 0)

8. **State Handoff Test** (`test_input_persistence.gd`)
   - Set custom bindings
   - Trigger scene transition
   - Assert input settings slice preserved via StateHandoff
   - Assert input buffers flushed (jump_buffer_timestamp = 0)

9. **Reserved Action Test** (`test_u_input_rebind_utils.gd`)
   - Attempt to rebind "pause" action
   - Assert validation fails with "Cannot rebind reserved action"

10. **Button Prompt Fallback Test** (`test_u_button_prompt_registry.gd`)
    - Request prompt for missing asset
    - Assert get_prompt() returns null
    - Assert get_prompt_text() returns text fallback "Press [Space]"

### Complete File Structure

```
/scripts/
  /managers/
    m_input_profile_manager.gd          # NEW - Profile loading and switching
    m_input_device_manager.gd           # NEW - Device detection
    m_cursor_manager.gd                 # EXISTING - Cursor control
  /input/                               # NEW DIRECTORY
    /resources/
      rs_input_profile.gd               # NEW - Profile resource definition
      rs_gamepad_settings.gd            # NEW - Gamepad configuration
      rs_rebind_settings.gd             # NEW - Rebind rules
      rs_mouse_settings.gd              # NEW - Mouse configuration
      rs_touchscreen_settings.gd        # NEW - Touch configuration
    /utils/
      u_input_rebind_utils.gd           # NEW - Rebinding logic
      u_button_prompt_registry.gd       # NEW - Button prompt mapping
  /state/
    /actions/
      u_input_actions.gd                # NEW - Input action creators
    /reducers/
      u_input_reducer.gd                # NEW - Input state reducer
    /selectors/
      u_input_selectors.gd              # NEW - Input state selectors
  /ecs/
    /components/
      c_input_component.gd              # EXISTING - ENHANCE for multi-device
      c_gamepad_component.gd            # NEW - Gamepad-specific state
    /systems/
      s_input_system.gd                 # EXISTING - ENHANCE for gamepad/device detection
      s_touchscreen_system.gd           # NEW - Touch input processing
  /ui/
    rebind_button.gd                    # NEW - Rebind UI component
    virtual_joystick.gd                 # NEW - Mobile virtual joystick
    virtual_button.gd                   # NEW - Mobile virtual button

/resources/
  /input_profiles/                      # NEW DIRECTORY
    default.tres                        # NEW - Default keyboard/mouse profile
    alternate.tres                      # NEW - Alternate keyboard layout
    accessibility.tres                  # NEW - Accessibility-focused profile
    gamepad_generic.tres                # NEW - Generic gamepad profile
  /button_prompts/                      # NEW DIRECTORY
    /gamepad/                           # NEW - Generic gamepad icons
      south.png                         # A/Cross button
      east.png                          # B/Circle button
      west.png                          # X/Square button
      north.png                         # Y/Triangle button
      [... additional button icons]
    /keyboard/                          # NEW - Keyboard key icons
      space.png
      shift.png
      e.png
      w.png
      a.png
      s.png
      d.png
      [... additional key icons]

/tests/unit/input/                      # NEW DIRECTORY
  [14 test files listed above]

/tests/integration/input/               # NEW DIRECTORY
  [8 test files listed above]
```

### File Count Summary

- **New Managers**: 2 (M_InputProfileManager, M_InputDeviceManager)
- **New Resources**: 5 (RS_InputProfile, RS_GamepadSettings, RS_RebindSettings, RS_MouseSettings, RS_TouchscreenSettings)
- **New Utilities**: 2 (U_InputRebindUtils, U_ButtonPromptRegistry)
- **New State Files**: 3 (U_InputActions, U_InputReducer, U_InputSelectors)
- **New Components**: 1 (C_GamepadComponent)
- **Enhanced Components**: 1 (C_InputComponent)
- **New Systems**: 1 (S_TouchscreenSystem)
- **Enhanced Systems**: 1 (S_InputSystem)
- **New UI**: 3 (RebindButton, VirtualJoystick, VirtualButton)
- **New Profile Resources**: 4 (.tres files)
- **New Button Prompt Assets**: ~20-30 icons (keyboard + gamepad)
- **New Tests**: 22 (14 unit + 8 integration)

**Total New Files**: ~45-55 (including assets)
**Enhanced Existing Files**: 2

## Architecture Integration

### Integration with M_StateStore (Redux Coordination)

**How Input Manager Uses State Store:**

1. **Action Dispatch**: S_InputSystem dispatches input actions every physics frame
   ```gdscript
   func process_tick(delta: float) -> void:
       var store := U_StateUtils.get_store(self)
       store.dispatch(U_InputActions.update_move_input(move_vector))
       store.dispatch(U_InputActions.update_look_input(mouse_delta))
   ```

2. **State Persistence**: Input settings persist across scene transitions via StateHandoff
   - Settings slice contains `input_settings` field
   - Includes `active_profile_id`, `custom_bindings`, device preferences
   - StateHandoff mechanism preserves settings during transitions

3. **State Queries**: Systems and UI query input state via selectors
   ```gdscript
   var state := store.get_state()
   var active_device := U_InputSelectors.get_active_device(state)
   var move_input := U_InputSelectors.get_move_input(state)
   ```

4. **Input Slice Structure**:
   - **Gameplay Slice** (transient): `active_device`, `gamepad_connected`, current input values
   - **Settings Slice** (persistent): `active_profile_id`, `custom_bindings`, device settings

**No Conflicts**: Input Manager follows same Redux patterns as Scene Manager and Gameplay systems.

### Integration with M_ECSManager (Component/System Patterns)

**ECS Integration Points:**

1. **Component Registration**:
   - C_InputComponent auto-registers on `_ready()` via `ECSComponent._ready()`
   - C_GamepadComponent auto-registers similarly
   - Both define `COMPONENT_TYPE` constant for queries

2. **System Discovery**:
   - S_InputSystem extends `ECSSystem`, auto-discovers M_ECSManager via parent traversal
   - S_TouchscreenSystem follows same pattern
   - No manual manager wiring required

3. **Component Queries**:
   ```gdscript
   func process_tick(delta: float) -> void:
       for component in query_entities(C_InputComponent.COMPONENT_TYPE):
           # Update component with input data
   ```

4. **System Execution**:
   - Systems run in `_physics_process` via `process_tick(delta)` pattern
   - M_ECSManager orchestrates execution order
   - Input systems run early in frame (before movement, rotation systems)

**Pattern Consistency**: Input Manager uses identical ECS patterns as existing systems (S_GravitySystem, S_MovementSystem, etc.).

### Integration with M_SceneManager (Transition Handling)

**Scene Transition Integration:**

1. **Input Blocking During Transitions**:
   ```gdscript
   func process_tick(delta: float) -> void:
       # Check if transitioning
       if get_tree().get_first_node_in_group("scene_manager"):
           var scene_mgr := get_tree().get_first_node_in_group("scene_manager") as M_SceneManager
           if scene_mgr and scene_mgr.is_transitioning():
               return  # Block input capture
   ```

2. **Buffer Flushing on Transition Start**:
   - When `is_transitioning` becomes true, S_InputSystem clears all input buffers
   - `_jump_buffer_timestamp = 0.0`, `jump_pressed = false`
   - Prevents buffered inputs from carrying into new scene

3. **Settings Persistence**:
   - Input settings slice persists across transitions via StateHandoff
   - Profile selection and custom bindings survive scene changes
   - Transient input state (move_vector, device_id) resets per scene

4. **Virtual Controls Per Scene**:
   - Mobile virtual controls instantiate per-scene (not global)
   - Each gameplay scene optionally includes VirtualJoystick/VirtualButton nodes
   - S_TouchscreenSystem references them via NodePath exports

**No Scene Manager Modifications Required**: Input Manager consumes existing `is_transitioning` API without changes to M_SceneManager.

### Integration with M_CursorManager (Cursor Coordination)

**Cursor State Coordination:**

1. **Mouse Delta Processing**:
   ```gdscript
   func _input(event: InputEvent) -> void:
       if event is InputEventMouseMotion:
           # Only process if cursor captured
           var cursor_mgr := get_tree().get_first_node_in_group("cursor_manager") as M_CursorManager
           if cursor_mgr and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
               mouse_delta = event.relative
   ```

2. **Pause Toggle**:
   - M_CursorManager listens for "pause" action
   - Toggles between MOUSE_MODE_CAPTURED and MOUSE_MODE_VISIBLE
   - S_InputSystem respects cursor mode automatically

3. **Authority**:
   - M_CursorManager has authority over cursor visibility/capture
   - S_InputSystem reads cursor mode, does not set it
   - Clean separation of concerns

**No Conflicts**: Cursor and input managers coordinate via Input.mouse_mode property, no direct coupling.

### Integration with UI System (Prompts & Virtual Controls)

**UI Integration Points:**

1. **Button Prompts**:
   - HUD nodes call `U_ButtonPromptRegistry.get_prompt(action, device)`
   - Subscribe to `M_InputDeviceManager.device_changed` signal
   - Update prompt textures/labels when device switches
   - Example:
     ```gdscript
     func _ready() -> void:
         var device_mgr := get_tree().get_first_node_in_group("input_device_manager")
         device_mgr.device_changed.connect(_on_device_changed)
     
     func _on_device_changed(device: int) -> void:
         var prompt := U_ButtonPromptRegistry.get_prompt("interact", device)
         interact_label.texture = prompt
     ```

2. **Virtual Controls**:
   - VirtualJoystick and VirtualButton are UI nodes (Control/Button)
   - S_TouchscreenSystem reads their state via NodePath references
   - Clean UI→System communication via exported paths

3. **Settings UI**:
   - RebindButton component captures InputEvent for rebinding
   - Calls U_InputRebindUtils for validation
   - Calls M_InputProfileManager to save custom bindings
   - Profile dropdown calls M_InputProfileManager.switch_profile()

**UI as Thin Layer**: UI components call Input Manager APIs, contain minimal logic themselves.

### No Autoloads Pattern

**Manager Discovery**:
- M_InputProfileManager: Added to root.tscn, discovered via "input_profile_manager" group
- M_InputDeviceManager: Added to root.tscn, discovered via "input_device_manager" group
- No autoload singletons (maintains architectural consistency)

**Discovery Pattern**:
```gdscript
var profile_mgr := get_tree().get_first_node_in_group("input_profile_manager") as M_InputProfileManager
var device_mgr := get_tree().get_first_node_in_group("input_device_manager") as M_InputDeviceManager
```

**Root.tscn Structure**:
```
Root (Node)
├─ M_StateStore
├─ M_CursorManager
├─ M_SceneManager
├─ M_InputProfileManager       # NEW
├─ M_InputDeviceManager         # NEW
├─ ActiveSceneContainer
└─ [UI overlays...]
```

## Initialization Flow

### 6-Step Bootstrap Sequence

#### Step 1: Game Launch - Root Scene Loads

**File**: `scenes/root.tscn` loaded as main scene

**Managers Initialize** (in tree order):
1. M_StateStore._ready()
2. M_CursorManager._ready()
3. M_SceneManager._ready()
4. **M_InputProfileManager._ready()** ← NEW
5. **M_InputDeviceManager._ready()** ← NEW

**Order**: Godot calls _ready() bottom-up (children before parents)

#### Step 2: M_InputProfileManager Initialization

```gdscript
func _ready() -> void:
    add_to_group("input_profile_manager")
    
    # Load available profiles
    _load_available_profiles()
    
    # Load saved settings
    var success := load_custom_bindings()
    
    if not success:
        # No saved settings, load default profile
        load_profile("default")
    
    print("Input Profile Manager initialized. Active profile: %s" % active_profile.profile_name)

func _load_available_profiles() -> void:
    available_profiles["default"] = load("res://resources/input_profiles/default.tres")
    available_profiles["alternate"] = load("res://resources/input_profiles/alternate.tres")
    available_profiles["accessibility"] = load("res://resources/input_profiles/accessibility.tres")
    available_profiles["gamepad_generic"] = load("res://resources/input_profiles/gamepad_generic.tres")
```

**Outcome**:
- Available profiles loaded into memory
- Saved profile ID retrieved from `user://global_settings.json`
- Profile applied to InputMap
- Custom bindings overlaid on profile defaults

#### Step 3: M_InputDeviceManager Initialization

```gdscript
func _ready() -> void:
    add_to_group("input_device_manager")
    
    # Detect connected gamepads
    detect_gamepads()
    
    # Set initial device based on platform
    if OS.has_feature("mobile"):
        active_device = DeviceType.TOUCHSCREEN
        print("Platform: Mobile, initial device: TOUCHSCREEN")
    else:
        active_device = DeviceType.KEYBOARD_MOUSE
        print("Platform: Desktop, initial device: KEYBOARD_MOUSE")
    
    # Dispatch initial state to store
    await get_tree().process_frame  # Wait for M_StateStore to be ready
    var store := U_StateUtils.get_store(self)
    store.dispatch(U_InputActions.device_changed(active_device, gamepad_device_id))

func detect_gamepads() -> void:
    var joypads := Input.get_connected_joypads()
    if joypads.size() > 0:
        gamepad_device_id = joypads[0]
        gamepad_connected.emit(gamepad_device_id)
        print("Gamepad detected: device_id=%d, name=%s" % [gamepad_device_id, Input.get_joy_name(gamepad_device_id)])
```

**Outcome**:
- Gamepad detection complete
- Active device determined (platform-appropriate)
- Initial device state dispatched to state store

#### Step 4: State Store Registration

**M_StateStore receives input actions**:
- Reducer processes ACTION_DEVICE_CHANGED
- Input slice in gameplay state initialized:
  ```gdscript
  gameplay.input = {
      "active_device": 0,  # KEYBOARD_MOUSE (or TOUCHSCREEN on mobile)
      "gamepad_connected": true/false,
      "gamepad_device_id": 0 or -1,
      ...
  }
  ```

**Settings slice initialized**:
- Loaded from `user://global_settings.json` (if exists)
- Or defaults created:
  ```gdscript
  settings.input_settings = {
      "active_profile_id": "default",
      "custom_bindings": {},
      "gamepad_settings": { deadzone: 0.2, vibration_enabled: true, ... },
      ...
  }
  ```

#### Step 5: Gameplay Scene Loads

**Scene**: `scenes/gameplay/gameplay_base.tscn` loaded into ActiveSceneContainer

**Systems Initialize**:
1. S_InputSystem._ready()
   - Finds M_ECSManager via parent traversal
   - Validates InputMap actions (auto-initializes if missing)
   - Registers for _physics_process callbacks
2. S_TouchscreenSystem._ready() (if on mobile)
   - Resolves virtual control NodePaths
   - Conditionally shows/hides based on active device

**Components Initialize**:
1. C_InputComponent._ready() (on player entity)
   - Auto-registers with M_ECSManager
   - Initializes to default state (Vector2.ZERO, false, false)
2. C_GamepadComponent._ready() (if gamepad detected)
   - Auto-registers with M_ECSManager
   - Sets device_id from M_InputDeviceManager.gamepad_device_id

#### Step 6: First Frame - Input Capture Begins

**_physics_process starts**:

1. **S_InputSystem.process_tick(delta)** runs first (input systems run early)
   - Captures keyboard: `Input.get_vector()` for movement
   - Captures mouse: `mouse_delta` from _input()
   - Captures gamepad: Analog sticks, buttons
   - Updates all C_InputComponent instances
   - Dispatches input actions to state store

2. **S_TouchscreenSystem.process_tick(delta)** (mobile only)
   - Reads VirtualJoystick.get_vector()
   - Reads VirtualButton.is_pressed()
   - Updates C_InputComponent instances

3. **Other systems process**:
   - S_MovementSystem reads C_InputComponent.move_vector
   - S_JumpSystem reads C_InputComponent.jump_pressed
   - Systems execute gameplay logic using input data

**HUD Updates**:
- Button prompts display correct icons for active device
- Virtual controls visible/hidden based on device

**Initialization Complete**: Input Manager fully operational, processing input every frame.

### Initialization Timing Diagram

```
Time →

[0ms] Game launch, root.tscn loads
  ↓
[10ms] M_StateStore._ready()
  ↓
[12ms] M_InputProfileManager._ready()
       - Loads profiles from resources/
       - Loads user://global_settings.json
       - Applies profile to InputMap
  ↓
[15ms] M_InputDeviceManager._ready()
       - Detects gamepads (Input.get_connected_joypads())
       - Sets active_device (KEYBOARD_MOUSE or TOUCHSCREEN)
  ↓
[20ms] await process_frame
  ↓
[21ms] M_InputDeviceManager dispatches ACTION_DEVICE_CHANGED
  ↓
[22ms] M_StateStore processes action, input state initialized
  ↓
[100ms] Gameplay scene loads (gameplay_base.tscn)
  ↓
[110ms] S_InputSystem._ready()
        - Validates InputMap actions
        - Registers with M_ECSManager
  ↓
[112ms] C_InputComponent._ready() (player entity)
        - Auto-registers with M_ECSManager
  ↓
[120ms] First _physics_process frame
  ↓
[121ms] S_InputSystem.process_tick()
        - Input capture begins
        - move_vector, jump_pressed updated
        - Actions dispatched to store
  ↓
[Ongoing] Input processing every physics frame (60 FPS)
```

### Error Recovery

**Missing Profile File**:
- M_InputProfileManager logs error
- Falls back to "default" profile
- User notified: "Saved profile not found, using default"

**Corrupted Settings File**:
- JSON parse fails
- Invalid entries logged and skipped
- Corrupted file backed up to `.backup`
- Defaults loaded for missing/invalid data

**Gamepad Detection Failure**:
- No gamepads in Input.get_connected_joypads()
- gamepad_device_id remains -1
- Gamepad input ignored (gracefully degraded)
- If player connects gamepad later, _input() detects and switches device


## Implementation Phases

Detailed phase breakdown moved to the plan to keep this PRD product-focused.

See: docs/input_manager/input-manager-plan.md (Detailed Phases)

## Resolved Questions

### Design Decisions

**1. Should we support simultaneous input from multiple devices?**
   - **Resolution**: Yes, blend input from all active devices
   - **Rationale**: Players expect WASD + mouse to work simultaneously (movement + look). No exclusive device lock.
   

**2. How should we handle profile switching on device change?**
   - **Resolution**: Keep current profile, device detection updates prompts only
   - **Rationale**: Device switch shouldn't change player's chosen control scheme. Prompts update automatically to match active device.
   

**3. Should virtual controls be mandatory or optional on mobile?**
   - **Resolution**: Auto-hide when Bluetooth gamepad detected
   - **Rationale**: Mobile players with gamepad shouldn't see distracting on-screen controls. Seamless experience.
   

**4. How granular should rebinding be?**
   - **Resolution**: Multiple bindings per action (Godot InputMap supports this)
   - **Rationale**: Players expect "Jump = Space OR Gamepad A". Flexibility without complexity.
   

**5. Should we support input recording for accessibility?**
   - **Resolution**: Out of scope for P0, defer to post-launch
   - **Rationale**: Complex feature with limited audience. Focus on core rebinding and profiles first.
   

**6. Should we use Command pattern for input?**
   - **Resolution**: No, stick with Redux actions
   - **Rationale**: Redux actions already provide Command pattern benefits (encapsulation, logging). Adding explicit Command pattern creates unnecessary complexity and architectural inconsistency.
   - **Analysis**: See comprehensive Command pattern analysis document
   

### Technical Decisions

**7. Should input profiles be Resources (.tres) or JSON files?**
   - **Resolution**: Resources for built-in, JSON for custom
   - **Rationale**: .tres files are type-safe and editor-friendly for development. JSON for custom bindings enables modding and easy editing.
   

**8. Where should M_InputProfileManager live?**
   - **Resolution**: In-scene node in root.tscn (not autoload)
   - **Rationale**: Follows existing manager patterns (M_StateStore, M_SceneManager). Maintains architectural consistency.
   

**9. Should we create separate systems for each input type?**
   - **Resolution**: One S_InputSystem for keyboard/gamepad, separate S_TouchscreenSystem for touch
   - **Rationale**: Keyboard and gamepad use same Input API. Touch requires UI layer (different processing model).
   

**10. How should we handle input during scene transitions?**
    - **Resolution**: Block input capture, flush buffers on transition start
    - **Rationale**: Prevents buffered inputs from previous scene triggering in new scene. Clean state per scene.
    

**11. Should button prompts be part of Input Manager or separate UI system?**
    - **Resolution**: Lightweight registry in Input Manager, UI queries it
    - **Rationale**: Button prompts are input-related metadata. No need for separate manager, adds complexity.
    

**12. Should we support per-manufacturer gamepad profiles (Xbox, PS, Switch)?**
    - **Resolution**: No, use single generic gamepad profile
    - **Rationale**: Godot's SDL mapping handles manufacturer differences automatically. Generic approach reduces maintenance burden.
    

### Process Decisions

**13. What's the testing strategy for console hardware?**
    - **Resolution**: Defer console-specific testing until dev kits acquired
    - **Rationale**: Desktop/Mobile sufficient for validation. Console testing requires hardware investment.
    

**14. Should we implement all platforms in one phase or incrementally?**
    - **Resolution**: Incremental - Desktop → Mobile → Polish
    - **Rationale**: Validates architecture early, allows iterative feedback. Reduces risk.
    

**15. Who is responsible for creating button prompt assets?**
    - **Resolution**: Use open-source icons initially (Kenney.nl), replace with custom later
    - **Rationale**: Unblocks implementation, can polish art later. Generic icons sufficient for functionality.
    

**16. How do we handle state persistence across scene transitions?**
    - **Resolution**: Settings slice persists via StateHandoff, runtime state resets
    - **Rationale**: Player preferences (profile, bindings) should persist. Transient input state (move_vector, device_id) resets per scene.
    

**17. Should we support undo/redo for rebinding?**
    - **Resolution**: No undo/redo for P0, "Reset to Default" sufficient
    - **Rationale**: Rebinding is low-frequency operation. Players can rebind again if mistake. "Reset" provides safety net.
    

**18. How do we validate input system correctness?**
    - **Resolution**: Comprehensive test suite (60+ tests) + manual testing on physical devices
    - **Rationale**: Input is critical path. Automated tests catch regressions, manual tests validate feel/responsiveness.
    

**19. What input actions are required in project.godot?**
    - **Resolution**: "interact" and "pause" must remain in InputMap (reserved actions)
    - **Rationale**: HUD/process prompts run in PROCESS_MODE_ALWAYS, need guaranteed action availability.
    

**20. How do we handle input conflicts with existing codebase?**
    - **Resolution**: Enhance C_InputComponent, extend S_InputSystem (no breaking changes)
    - **Rationale**: Existing systems (S_MovementSystem, S_JumpSystem) already read C_InputComponent. Preserve compatibility.
    
