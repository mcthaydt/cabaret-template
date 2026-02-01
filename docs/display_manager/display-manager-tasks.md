# Display Manager Implementation Tasks

**Progress:** 25% (19 / 76 tasks complete)

**Estimated Test Count:** ~120 tests (90 unit + 30 integration)

**Prerequisite:** Audio Manager Phase 0 must be complete before starting Display Manager implementation. The `display_initial_state` parameter must be added as the **12th parameter** (AFTER `audio_initial_state`) in the `u_state_slice_manager.initialize_slices()` function signature.

---

## Pre-Implementation Checklist

Before starting Phase 0, verify:

- [ ] **PRE-1**: Audio Manager Phase 0 complete
  - Verify `audio_initial_state: RS_AudioInitialState` exists in `u_state_slice_manager.initialize_slices()` signature
  - Verify audio slice is registered (run existing audio tests)

- [ ] **PRE-2**: Understand existing patterns by reading:
  - `scripts/state/utils/u_state_slice_manager.gd` (slice registration)
  - `scripts/managers/m_audio_manager.gd` (hash-based optimization, preview mode)
  - `scripts/state/m_state_store.gd` (export pattern, initialize_slices call)

---

## Phase 0: Redux Foundation

**Exit Criteria:** All 77 Redux tests pass (11+19+28+19), display slice registered in M_StateStore, no console errors

### Phase 0A: Display Initial State Resource

- [x] **Task 0A.1 (Red)**: Write tests for RS_DisplayInitialState resource
  - Create `tests/unit/state/test_display_initial_state.gd`
  - Test `window_size_preset` field exists with default `"1920x1080"`
  - Test `window_mode` field exists with default `"windowed"`
  - Test `vsync_enabled` field exists with default `true`
  - Test `quality_preset` field exists with default `"high"`
  - Test film grain fields (`film_grain_enabled`, `film_grain_intensity`)
  - Test outline fields (`outline_enabled`, `outline_thickness`, `outline_color`)
  - Test dither fields (`dither_enabled`, `dither_intensity`, `dither_pattern`)
  - Test LUT fields (`lut_enabled`, `lut_resource`, `lut_intensity`)
  - Test `ui_scale` field exists with default `1.0`
  - Test accessibility fields (`color_blind_mode`, `high_contrast_enabled`, `color_blind_shader_enabled`)
  - Test `to_dictionary()` returns all fields
  - **Target: 11 tests**
  - Notes: Completed 2026-02-01 (added 11 tests in `tests/unit/state/test_display_initial_state.gd`)

- [x] **Task 0A.2 (Green)**: Implement RS_DisplayInitialState resource
  - Create `scripts/resources/state/rs_display_initial_state.gd`
  - Add all @export fields with correct types and defaults
  - Implement `to_dictionary()` method
  - All tests should pass
  - Notes: Completed 2026-02-01 (created `scripts/resources/state/rs_display_initial_state.gd`)

- [x] **Task 0A.3**: Create default resource instance
  - Create `resources/base_settings/state/cfg_display_initial_state.tres`
  - Set all fields to sensible defaults
  - Notes: Completed 2026-02-01 (created `resources/base_settings/state/cfg_display_initial_state.tres`)

---

### Phase 0B: Display Actions

- [x] **Task 0B.1 (Red)**: Write tests for U_DisplayActions
  - Create `tests/unit/state/test_display_actions.gd`
  - Test `set_window_size_preset(preset)` action structure
  - Test `set_window_mode(mode)` action structure
  - Test `set_vsync_enabled(enabled)` action structure
  - Test `set_quality_preset(preset)` action structure
  - Test `set_film_grain_enabled(enabled)` action structure
  - Test `set_film_grain_intensity(intensity)` action structure
  - Test `set_outline_enabled(enabled)` action structure
  - Test `set_outline_thickness(thickness)` action structure
  - Test `set_outline_color(color)` action structure
  - Test `set_dither_enabled(enabled)` action structure
  - Test `set_dither_intensity(intensity)` action structure
  - Test `set_dither_pattern(pattern)` action structure
  - Test `set_lut_enabled(enabled)` action structure
  - Test `set_lut_resource(resource)` action structure
  - Test `set_lut_intensity(intensity)` action structure
  - Test `set_ui_scale(scale)` action structure
  - Test `set_color_blind_mode(mode)` action structure
  - Test `set_high_contrast_enabled(enabled)` action structure
  - Test `set_color_blind_shader_enabled(enabled)` action structure
  - **Target: 19 tests**
  - Notes: Completed 2026-02-01 (added 19 tests in `tests/unit/state/test_display_actions.gd`)

- [x] **Task 0B.2 (Green)**: Implement U_DisplayActions
  - Create `scripts/state/actions/u_display_actions.gd`
  - Add all action type constants (StringName)
  - Implement all static action creator functions
  - All tests should pass
  - Notes: Completed 2026-02-01 (created `scripts/state/actions/u_display_actions.gd`)

---

### Phase 0C: Display Reducer

- [x] **Task 0C.1 (Red)**: Write tests for U_DisplayReducer
  - Create `tests/unit/state/test_display_reducer.gd`
  - Test each action type updates correct field
  - Test `film_grain_intensity` clamping (0.0-1.0)
  - Test `dither_intensity` clamping (0.0-1.0)
  - Test `lut_intensity` clamping (0.0-1.0)
  - Test `outline_thickness` clamping (1-5)
  - Test `ui_scale` clamping (0.5-2.0)
  - Test invalid `window_size_preset` ignored
  - Test invalid `window_mode` ignored
  - Test invalid `quality_preset` ignored
  - Test invalid `color_blind_mode` ignored
  - Test invalid `dither_pattern` ignored
  - Test reducer returns same state for unknown action
  - Test reducer immutability (old_state !== new_state)
  - **Target: 28 tests**
  - Notes: Completed 2026-02-01 (added 28 tests in `tests/unit/state/test_display_reducer.gd`)

- [x] **Task 0C.2 (Green)**: Implement U_DisplayReducer
  - Create `scripts/state/reducers/u_display_reducer.gd`
  - Add validation constants (VALID_WINDOW_PRESETS, VALID_WINDOW_MODES, etc.)
  - Implement `reduce(state, action)` with match statement
  - Implement `_with_values()` helper for immutable updates
  - All tests should pass
  - Notes: Completed 2026-02-01 (created `scripts/state/reducers/u_display_reducer.gd`)

- [ ] **Task 0C.3 (Refactor)**: Extract helper methods if needed
  - Ensure all validation logic is clean and consistent
  - No new functionality, only code quality

---

### Phase 0D: Display Selectors & Store Integration

- [x] **Task 0D.1 (Red)**: Write tests for U_DisplaySelectors
  - Create `tests/unit/state/test_display_selectors.gd`
  - Test each selector returns correct value from state
  - Test each selector returns default when slice missing
  - Test each selector returns default when field missing
  - **Target: 19 tests**
  - Notes: Completed 2026-02-01 (added 19 tests in `tests/unit/state/test_display_selectors.gd`)

- [x] **Task 0D.2 (Green)**: Implement U_DisplaySelectors
  - Create `scripts/state/selectors/u_display_selectors.gd`
  - Implement all selector functions with safe defaults
  - All tests should pass
  - Notes: Completed 2026-02-01 (created `scripts/state/selectors/u_display_selectors.gd`)

- [x] **Task 0D.3**: Integrate display slice with M_StateStore
  - Modify `scripts/state/m_state_store.gd`:
    - Line ~41: Add `const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")`
    - Line ~65: Add `@export var display_initial_state: Resource`
    - Lines 217-229: Add `display_initial_state` as 12th parameter to `initialize_slices()` call
  - Modify `scripts/state/utils/u_state_slice_manager.gd`:
    - Line ~11: Add `const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")`
    - Lines 16-28: Add `display_initial_state: Resource` as 12th parameter
    - After line 120: Add display slice registration block (copy audio pattern)
  - Modify `scenes/root.tscn`:
    - Assign `resources/base_settings/state/cfg_display_initial_state.tres` to M_StateStore.display_initial_state export
  - Notes: Completed 2026-02-01 (export uses `Resource` to avoid headless class cache issues)

- [x] **Task 0D.4**: Register display actions with U_ActionRegistry
  - Notes: Completed 2026-02-01 (registration handled in `U_DisplayActions._static_init()`)

- [x] **Task 0D.5**: Verify integration
  - Run existing state tests (no regressions)
  - Verify display slice appears in `get_state()` output
  - Verify actions dispatch correctly
  - Verify display slice has correct default values
  - Notes: Completed 2026-02-01 (ran full state suite + display unit tests)

**Transient Fields Decision:**
- Display slice has **no transient fields** (all settings persist to save files)
- `transient_fields = []` in slice config

**Notes:**
- Phase 0 follows existing patterns from audio/gameplay slices
- All 77 Redux tests should pass before moving to Phase 1

---

## Phase 1: Interface & Core Manager

**Exit Criteria:** Manager registered with ServiceLocator, settings applied on state change, preview mode works

### Phase 1A: Interface Definition

- [x] **Task 1A.1**: Create I_DisplayManager interface
  - Create `scripts/interfaces/i_display_manager.gd`
  - Define `set_display_settings_preview(settings: Dictionary) -> void`
  - Define `clear_display_settings_preview() -> void`
  - Define `get_active_palette() -> Resource`
  - All methods push_error for unimplemented
  - Notes: Completed 2026-02-01 (created `scripts/interfaces/i_display_manager.gd`, palette returns Resource to avoid headless class cache issues)

---

### Phase 1B: Manager Scaffolding

- [x] **Task 1B.1 (Red)**: Write tests for M_DisplayManager lifecycle
  - Create `tests/unit/managers/test_display_manager.gd`
  - Test extends I_DisplayManager
  - Test adds to "display_manager" group
  - Test registers with ServiceLocator
  - Test discovers state store dependency via `U_StateUtils.try_get_store()`
  - Test subscribes to `slice_updated` signal
  - Test settings applied on `_ready()` (initial apply)
  - Test settings applied on slice change (reactive apply)
  - Test hash prevents redundant applies (`_last_display_hash` pattern)
  - Test preview mode sets `_display_settings_preview_active` flag
  - Test preview mode overrides state
  - Test `clear_display_settings_preview()` restores state and clears flag
  - **Target: 11 tests**
  - Notes: Completed 2026-02-01 (added 11 tests in `tests/unit/managers/test_display_manager.gd`)

- [x] **Task 1B.2 (Green)**: Implement M_DisplayManager scaffold
  - Create `scripts/managers/m_display_manager.gd` extending I_DisplayManager
  - Add `@export var state_store: I_StateStore` for DI
  - Add `var _last_display_hash: int = 0` for change detection
  - Add `var _display_settings_preview_active: bool = false` for preview mode
  - Add `var _preview_settings: Dictionary = {}` for preview values
  - Implement ServiceLocator registration in `_ready()`
  - Implement state store discovery via `U_StateUtils.try_get_store(self)` with soft timeout
  - Implement `slice_updated` subscription with hash comparison:
    ```gdscript
    func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
        if slice_name != &"display" or _display_settings_preview_active:
            return
        var state := state_store.get_state()
        var display_slice: Dictionary = state.get("display", {})
        var display_hash := display_slice.hash()
        if display_hash != _last_display_hash:
            _apply_display_settings(state)
            _last_display_hash = display_hash
    ```
  - Implement preview mode methods
  - All tests should pass
  - Notes: Completed 2026-02-01 (created `scripts/managers/m_display_manager.gd`)

- [x] **Task 1B.3**: Add manager to main scene
  - Add M_DisplayManager node to `scenes/root.tscn` under Managers/
  - Position after M_AudioManager
  - Update `scripts/root.gd`:
    - Add: `_register_if_exists(managers_node, "M_DisplayManager", StringName("display_manager"))`
    - Display manager depends on state_store (register after state_store is ready)
  - Notes: Completed 2026-02-01 (added M_DisplayManager node + root registration)

- [x] **Task 1B.4**: Create U_DisplayUtils helper
  - Create `scripts/utils/display/u_display_utils.gd`
  - Implement `static func get_display_manager() -> M_DisplayManager`
  - Pattern: `return U_ServiceLocator.get_service(StringName("display_manager")) as M_DisplayManager`
  - Notes: Completed 2026-02-01 (helper returns I_DisplayManager via ServiceLocator)

---

## Phase 2: Display/Graphics Settings

**Exit Criteria:** Window size/mode changes work, VSync toggle works, quality presets apply rendering settings

### Phase 2A: Window Size & Mode

- [x] **Task 2A.1 (Red)**: Write tests for window operations
  - Add tests to `test_display_manager.gd`
  - Test `apply_window_size_preset()` with valid preset
  - Test `apply_window_size_preset()` with invalid preset (no-op)
  - Test `set_window_mode("fullscreen")` calls DisplayServer
  - Test `set_window_mode("windowed")` calls DisplayServer
  - Test `set_window_mode("borderless")` calls DisplayServer
  - Test `set_vsync_enabled(true/false)` calls DisplayServer
  - **Target: 6 tests** (may require mocking DisplayServer in tests)
  - Notes: Completed 2026-02-01 (6 tests added; pending in headless DisplayServer)

- [x] **Task 2A.2 (Green)**: Implement window operations
  - Add `WINDOW_PRESETS` dictionary (preset string -> Vector2i)
  - Implement `apply_window_size_preset(preset)`
  - Implement `set_window_mode(mode)`
  - Implement `set_vsync_enabled(enabled)`
  - Call deferred for thread safety
  - Notes: Completed 2026-02-01 (implemented in `scripts/managers/m_display_manager.gd`)

---

### Phase 2B: Quality Presets

- [x] **Task 2B.1**: Create RS_QualityPreset resource
  - Create `scripts/resources/display/rs_quality_preset.gd`
  - Add fields: `preset_name`, `shadow_quality`, `anti_aliasing`, `post_processing_enabled`
  - Notes: Completed 2026-02-01 (created resource with shadow/AA/post-processing fields)

- [x] **Task 2B.2**: Create quality preset instances
  - Create `resources/display/cfg_quality_presets/cfg_quality_low.tres`
  - Create `resources/display/cfg_quality_presets/cfg_quality_medium.tres`
  - Create `resources/display/cfg_quality_presets/cfg_quality_high.tres`
  - Create `resources/display/cfg_quality_presets/cfg_quality_ultra.tres`
  - Notes: Completed 2026-02-01 (added low/medium/high/ultra preset configs)

- [x] **Task 2B.3**: Implement quality preset application
  - Add `apply_quality_preset(preset)` to M_DisplayManager
  - Apply shadow quality via RenderingServer
  - Apply anti-aliasing via viewport settings
  - Wire to `_apply_display_settings()`
  - Notes: Completed 2026-02-01 (apply_quality_preset + cache + RenderingServer/viewport wiring)

---

## Phase 3: Post-Processing System

**Exit Criteria:** Film Grain, Outline, Dither, LUT effects work via CanvasLayer + shaders

### Phase 3A: Post-Process Overlay & Helper

- [ ] **Task 3A.1 (Red)**: Write tests for U_PostProcessLayer helper
  - Create `tests/unit/managers/helpers/test_post_process_layer.gd`
  - Test `initialize(canvas_layer)` caches effect rects
  - Test `set_effect_enabled()` toggles visibility
  - Test `set_effect_parameter()` sets shader uniform
  - Test handles null rect gracefully
  - Test handles null material gracefully
  - **Target: 8 tests**

- [ ] **Task 3A.2 (Green)**: Implement U_PostProcessLayer helper
  - Create `scripts/managers/helpers/u_post_process_layer.gd`
  - Implement `initialize()` to cache ColorRect references
  - Implement `set_effect_enabled(effect_name, enabled)`
  - Implement `set_effect_parameter(effect_name, param, value)`
  - All tests should pass

- [ ] **Task 3A.3**: Create post-process overlay scene
  - Create `scenes/ui/overlays/ui_post_process_overlay.tscn`
  - CanvasLayer (layer 100, mouse_filter IGNORE)
  - Add FilmGrainRect, OutlineRect, DitherRect, LUTRect ColorRects
  - Each covers full screen, starts hidden

---

### Phase 3B: Shaders

- [ ] **Task 3B.1**: Create Film Grain shader
  - Create `assets/shaders/sh_film_grain.gdshader`
  - Uniforms: `intensity` (0.0-1.0), `time`
  - Noise-based grain effect

- [ ] **Task 3B.2**: Create Outline shader
  - Create `assets/shaders/sh_outline.gdshader`
  - Uniforms: `thickness` (1-5), `outline_color`
  - Sobel edge detection

- [ ] **Task 3B.3**: Create Dither shader
  - Create `assets/shaders/sh_dither.gdshader`
  - Uniforms: `intensity` (0.0-1.0), `pattern` (0=bayer, 1=noise)
  - Create `resources/textures/tex_bayer_8x8.png`

- [ ] **Task 3B.4**: Create LUT shader
  - Create `assets/shaders/sh_lut.gdshader`
  - Uniforms: `lut_texture`, `intensity` (0.0-1.0)
  - Create default LUT resources in `resources/luts/`

- [ ] **Task 3B.5**: Wire shaders to overlay scene
  - Assign shader materials to each ColorRect
  - Add shader materials to each effect rect

---

### Phase 3C: Manager Integration

- [ ] **Task 3C.1**: Integrate post-process overlay with manager
  - M_DisplayManager instantiates/discovers overlay
  - Create U_PostProcessLayer instance
  - Wire `_apply_display_settings()` to effect toggles/parameters

- [ ] **Task 3C.2**: Add time update for film grain
  - Pass engine time to film grain shader in `_process()`

---

## Phase 4: UI Scaling

**Exit Criteria:** UI scale slider affects all UI elements proportionally (0.5x-2.0x)

- [ ] **Task 4.1 (Red)**: Write tests for UI scale application
  - Test `set_ui_scale()` clamps to valid range
  - Test `set_ui_scale()` applies to CanvasLayers in group
  - **Target: 3 tests**

- [ ] **Task 4.2 (Green)**: Implement UI scale application
  - Implement `set_ui_scale(scale)` in M_DisplayManager
  - Query nodes in "ui_scalable" group
  - Apply transform scale to CanvasLayers

- [ ] **Task 4.3**: Add UI layers to scalable group
  - Add "ui_scalable" group to menu CanvasLayers
  - Add "ui_scalable" group to overlay CanvasLayers
  - Add "ui_scalable" group to HUD CanvasLayers

---

## Phase 5: Color Blind Accessibility

**Exit Criteria:** All 5 color palettes load correctly, palette switching works, optional shader filter works

### Phase 5A: Color Palette Resource

- [ ] **Task 5A.1 (Red)**: Write tests for RS_UIColorPalette
  - Create `tests/unit/resources/test_ui_color_palette.gd`
  - Test all fields exist with correct types
  - Test palette_id is StringName
  - Test color fields are Color type
  - **Target: 5 tests**

- [ ] **Task 5A.2 (Green)**: Implement RS_UIColorPalette resource
  - Create `scripts/resources/ui/rs_ui_color_palette.gd`
  - Add fields: palette_id, primary, secondary, success, warning, danger, info, background, text

- [ ] **Task 5A.3**: Create palette resource instances
  - Create `resources/ui_themes/cfg_palette_normal.tres`
  - Create `resources/ui_themes/cfg_palette_deuteranopia.tres`
  - Create `resources/ui_themes/cfg_palette_protanopia.tres`
  - Create `resources/ui_themes/cfg_palette_tritanopia.tres`
  - Create `resources/ui_themes/cfg_palette_high_contrast.tres`

---

### Phase 5B: Palette Manager Helper

- [ ] **Task 5B.1 (Red)**: Write tests for U_PaletteManager
  - Create `tests/unit/managers/helpers/test_palette_manager.gd`
  - Test `set_color_blind_mode()` loads correct palette
  - Test `set_color_blind_mode()` emits `active_palette_changed` signal
  - Test invalid mode falls back to "normal"
  - Test `get_active_palette()` returns current palette
  - Test palettes are cached after first load
  - **Target: 8 tests**

- [ ] **Task 5B.2 (Green)**: Implement U_PaletteManager helper
  - Create `scripts/managers/helpers/u_palette_manager.gd`
  - Add `active_palette_changed` signal
  - Implement palette loading with cache
  - Implement fallback to "normal" on invalid mode

- [ ] **Task 5B.3**: Integrate with M_DisplayManager
  - M_DisplayManager creates/owns U_PaletteManager instance
  - Wire `set_color_blind_mode()` to state changes
  - Expose `get_active_palette()` via manager

---

### Phase 5C: Color Blind Shader (Optional)

- [ ] **Task 5C.1**: Create daltonization shader
  - Create `assets/shaders/sh_colorblind_daltonize.gdshader`
  - Uniforms: `mode` (0=off, 1=deuteranopia, 2=protanopia, 3=tritanopia)
  - Color transformation matrices for simulation

- [ ] **Task 5C.2**: Add to post-process overlay
  - Add ColorBlindRect to overlay scene
  - Wire `color_blind_shader_enabled` and `color_blind_mode` to shader

---

## Phase 6: Settings UI Integration

**Exit Criteria:** Display settings tab works, accessibility section works, auto-save pattern followed

**Note:** Settings UI uses the **overlay pattern** (like `ui_audio_settings_tab.tscn` in `scenes/ui/overlays/`), not a separate `scenes/ui/settings/` directory.

### Phase 6A: Display Settings Tab

- [ ] **Task 6A.1**: Create display settings tab scene
  - Create `scenes/ui/overlays/ui_display_settings_tab.tscn` (matches audio pattern)
  - Layout: Window Size, Window Mode, VSync, Quality, Post-Processing, UI Scale sections
  - Use OptionButton for dropdowns, CheckBox for toggles, HSlider for intensities
  - Extend Control (NOT BaseMenuScreen) to avoid nested repeater conflicts

- [ ] **Task 6A.2**: Implement display settings tab controller
  - Create `scripts/ui/settings/ui_display_settings_tab.gd`
  - Subscribe to store for initial values via `U_StateUtils.get_store(self)`
  - Dispatch Redux actions on control changes (auto-save pattern - immediate dispatch, no Apply button)
  - Wire all controls to corresponding U_DisplayActions
  - Use `U_FocusConfigurator` for focus chains

- [ ] **Task 6A.3**: Integrate with settings panel
  - Add Display tab button to existing settings panel (SettingsPanel)
  - Add to ButtonGroup for tab radio behavior
  - Configure focus navigation between tabs
  - Add to "ui_scalable" group for UI scaling support

---

### Phase 6B: Accessibility Settings Section

- [ ] **Task 6B.1**: Add color blind options to accessibility tab
  - Add Color Mode dropdown (normal, deuteranopia, protanopia, tritanopia)
  - Add High Contrast checkbox
  - Add Color Blind Shader Filter checkbox

- [ ] **Task 6B.2**: Wire accessibility controls
  - Dispatch `set_color_blind_mode()` action on dropdown change
  - Dispatch `set_high_contrast_enabled()` action on checkbox change
  - Dispatch `set_color_blind_shader_enabled()` action on checkbox change

---

## Phase 7: Integration Testing

**Exit Criteria:** All ~30 integration tests pass, settings persist correctly

### Integration Tests

- [ ] **Task 7.1**: Create display settings integration tests
  - Create `tests/integration/display/test_display_settings.gd`
  - Test window mode changes apply to DisplayServer
  - Test quality presets update rendering settings
  - Test settings persist across scene transitions
  - Test settings persist in save files
  - **Target: 15 tests**

- [ ] **Task 7.2**: Create post-processing integration tests
  - Create `tests/integration/display/test_post_processing.gd`
  - Test each effect enables/disables correctly
  - Test effect parameters update shader uniforms
  - Test preview mode overrides persisted settings
  - Test clear preview restores persisted settings
  - **Target: 10 tests**

- [ ] **Task 7.3**: Create color blind palette integration tests
  - Create `tests/integration/display/test_color_blind_palettes.gd`
  - Test all 5 palettes load correctly
  - Test palette switching emits signal
  - Test high contrast mode applies correctly
  - **Target: 5 tests**

---

## Phase 8: Manual Testing

**Exit Criteria:** All visual verification tests pass on target platforms

### Visual Verification Checklist

- [ ] **MT-01**: Window size presets resize window correctly
- [ ] **MT-02**: Fullscreen toggle works
- [ ] **MT-03**: Borderless windowed mode works
- [ ] **MT-04**: VSync toggle affects frame timing
- [ ] **MT-05**: Quality preset changes are visually noticeable
- [ ] **MT-06**: Film Grain effect visible when enabled
- [ ] **MT-07**: Outline effect draws edges correctly
- [ ] **MT-08**: Dither patterns (bayer/noise) distinguishable
- [ ] **MT-09**: LUT color grading applies correctly
- [ ] **MT-10**: UI scale slider affects all UI elements proportionally
- [ ] **MT-11**: UI remains usable at 0.5x scale
- [ ] **MT-12**: UI remains usable at 2.0x scale
- [ ] **MT-13**: Each color blind palette provides distinct colors
- [ ] **MT-14**: High contrast mode increases visibility
- [ ] **MT-15**: Color blind shader filter simulates correctly
- [ ] **MT-16**: Settings persist after quit and relaunch
- [ ] **MT-17**: Post-process overlay renders above gameplay but below UI

---

## Phase 9: Documentation Updates

**Exit Criteria:** All documentation updated to reflect implementation

- [ ] **Task 9.1**: Create continuation prompt
  - Create `docs/display_manager/display-manager-continuation-prompt.md`
  - Document current phase, completed tasks, next steps
  - Update after each phase completion

- [ ] **Task 9.2**: Update AGENTS.md
  - Add "Display Manager Patterns" section (after Audio Manager section)
  - Document hash-based optimization pattern
  - Document preview mode pattern
  - Document ServiceLocator registration
  - Add anti-patterns section

- [ ] **Task 9.3**: Update DEV_PITFALLS.md if applicable
  - Add Display-specific pitfalls discovered during implementation
  - Document DisplayServer thread safety requirements
  - Document UI scale transform origin issue

---

## Notes

- Record decisions, follow-ups, or blockers here as implementation progresses
- Document any deviations from the plan and rationale

**Key Decisions:**
- Display slice has **no transient fields** - all settings persist to save files
- Settings UI uses **overlay pattern** in `scenes/ui/overlays/` (not separate settings directory)
- Post-process overlay uses **layer 100** (above gameplay layer 0, below UI overlays)
- Display settings **do NOT auto-save to disk** on change (unlike audio) - rely on M_SaveManager

**Prerequisite check:**
- [ ] Audio Manager Phase 0 complete (audio_initial_state exists in u_state_slice_manager)

**Test commands:**
```bash
# Run display unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gselect=test_display -ginclude_subdirs=true -gexit

# Run display manager tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_display -ginclude_subdirs=true -gexit

# Run display integration tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration/display -ginclude_subdirs=true -gexit
```

---

## Links

- **Plan**: `docs/display_manager/display-manager-plan.md`
- **Overview**: `docs/display_manager/display-manager-overview.md`
- **Continuation prompt**: `docs/display_manager/display-manager-continuation-prompt.md`

---

## File Reference

### Files to Create

| File | Type | Description |
|------|------|-------------|
| `scripts/resources/state/rs_display_initial_state.gd` | Resource | Initial state for display slice |
| `resources/base_settings/state/cfg_display_initial_state.tres` | Instance | Default display settings instance |
| `scripts/state/actions/u_display_actions.gd` | Actions | Display action creators (19 actions) |
| `scripts/state/reducers/u_display_reducer.gd` | Reducer | Display state reducer |
| `scripts/state/selectors/u_display_selectors.gd` | Selectors | Display state selectors (19 selectors) |
| `scripts/interfaces/i_display_manager.gd` | Interface | Display manager interface |
| `scripts/managers/m_display_manager.gd` | Manager | Main display manager |
| `scripts/managers/helpers/u_post_process_layer.gd` | Helper | Post-process effect management |
| `scripts/managers/helpers/u_palette_manager.gd` | Helper | Color blind palette management |
| `scripts/utils/display/u_display_utils.gd` | Utility | Display manager lookup helper |
| `scripts/resources/display/rs_quality_preset.gd` | Resource | Quality preset definition |
| `scripts/resources/ui/rs_ui_color_palette.gd` | Resource | Color palette definition |
| `resources/display/cfg_quality_presets/cfg_quality_low.tres` | Instance | Low quality preset |
| `resources/display/cfg_quality_presets/cfg_quality_medium.tres` | Instance | Medium quality preset |
| `resources/display/cfg_quality_presets/cfg_quality_high.tres` | Instance | High quality preset |
| `resources/display/cfg_quality_presets/cfg_quality_ultra.tres` | Instance | Ultra quality preset |
| `resources/ui_themes/cfg_palette_normal.tres` | Instance | Normal color palette |
| `resources/ui_themes/cfg_palette_deuteranopia.tres` | Instance | Deuteranopia palette |
| `resources/ui_themes/cfg_palette_protanopia.tres` | Instance | Protanopia palette |
| `resources/ui_themes/cfg_palette_tritanopia.tres` | Instance | Tritanopia palette |
| `resources/ui_themes/cfg_palette_high_contrast.tres` | Instance | High contrast palette |
| `assets/shaders/sh_film_grain.gdshader` | Shader | Film grain effect |
| `assets/shaders/sh_outline.gdshader` | Shader | Outline effect |
| `assets/shaders/sh_dither.gdshader` | Shader | Dither effect |
| `assets/shaders/sh_lut.gdshader` | Shader | LUT color grading |
| `assets/shaders/sh_colorblind_daltonize.gdshader` | Shader | Color blind simulation |
| `resources/textures/tex_bayer_8x8.png` | Texture | Bayer dither pattern |
| `scenes/ui/overlays/ui_post_process_overlay.tscn` | Scene | Post-process overlay (layer 100) |
| `scenes/ui/overlays/ui_display_settings_tab.tscn` | Scene | Display settings UI tab |
| `scripts/ui/settings/ui_display_settings_tab.gd` | UI | Display settings controller |
| `docs/display_manager/display-manager-continuation-prompt.md` | Doc | Implementation continuation prompt |
| `tests/unit/state/test_display_initial_state.gd` | Test | Initial state tests (11) |
| `tests/unit/state/test_display_actions.gd` | Test | Actions tests (19) |
| `tests/unit/state/test_display_reducer.gd` | Test | Reducer tests (28) |
| `tests/unit/state/test_display_selectors.gd` | Test | Selectors tests (19) |
| `tests/unit/managers/test_display_manager.gd` | Test | Manager tests (11+) |
| `tests/unit/managers/helpers/test_post_process_layer.gd` | Test | Post-process helper tests (8) |
| `tests/unit/managers/helpers/test_palette_manager.gd` | Test | Palette manager tests (8) |
| `tests/unit/resources/test_ui_color_palette.gd` | Test | Color palette tests (5) |
| `tests/integration/display/test_display_settings.gd` | Test | Display settings integration (15) |
| `tests/integration/display/test_post_processing.gd` | Test | Post-processing integration (10) |
| `tests/integration/display/test_color_blind_palettes.gd` | Test | Color blind integration (5) |

### Files to Modify

| File | Changes |
|------|---------|
| `scripts/state/m_state_store.gd` | Add RS_DISPLAY_INITIAL_STATE const, display_initial_state export, pass as 12th param to initialize_slices() |
| `scripts/state/utils/u_state_slice_manager.gd` | Add U_DISPLAY_REDUCER const, display_initial_state as 12th param, register display slice after audio |
| `scripts/state/u_action_registry.gd` | Register all 19 U_DisplayActions action types |
| `scenes/root.tscn` | Add M_DisplayManager node under Managers/, assign cfg_display_initial_state.tres |
| `scripts/root.gd` | Register M_DisplayManager with ServiceLocator via `_register_if_exists()` |
| `scenes/ui/menus/*.tscn` | Add "ui_scalable" group to CanvasLayers |
| `scenes/ui/overlays/*.tscn` | Add "ui_scalable" group to CanvasLayers |
| `scenes/ui/hud/*.tscn` | Add "ui_scalable" group to CanvasLayers |
| `AGENTS.md` | Add Display Manager Patterns section (after Audio Manager) |
| `docs/general/DEV_PITFALLS.md` | Add Display-specific pitfalls if discovered |
