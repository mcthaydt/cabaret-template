# Display Manager - Continuation Prompt

**Last Updated:** 2026-02-01
**Current Phase:** Phase 4 Complete (UI Scaling)
**Branch:** `display-manager`

---

## Current Status

Phase 0A–0D complete (Initial State, Actions, Reducer, Selectors + Store Integration). Display slice is registered and wired in root. Phase 1A interface stub added. Phase 1B scaffolding complete and manager registered in root. Phase 2A window size/mode operations implemented with DisplayServer tests (pending in headless). Phase 2B quality presets applied in M_DisplayManager (resource + configs + RenderingServer/viewport wiring). Phase 3A post-process helper + overlay scene implemented. Phase 3B shaders authored (film grain, outline, dither, LUT), LUT resources added, and overlay wired with shader materials. Phase 3C manager integration complete (overlay discovery/instantiation + shader parameter wiring + film grain time updates). Phase 4 UI scaling implemented (set_ui_scale + UIScaleRoot registration; applies to CanvasLayer/Control roots and updates newly registered UI nodes).

**Ready to begin Phase 5: Color Blind Accessibility**

---

## Completed Work

- [x] Display Manager overview document created
- [x] Display Manager implementation plan created
- [x] Display Manager task checklist created
- [x] Documentation audit completed (test counts aligned, patterns documented)
- [x] Verified Audio Manager Phase 0 is complete (prerequisite satisfied)
- [x] Task 0A.1: Display initial state tests created
- [x] Task 0A.2: RS_DisplayInitialState resource implemented
- [x] Task 0A.3: Default display initial state resource created
- [x] Task 0B.1: Display actions tests created
- [x] Task 0B.2: U_DisplayActions implemented
- [x] Task 0C.1: Display reducer tests created
- [x] Task 0C.2: U_DisplayReducer implemented
- [x] Task 0D.1: Display selectors tests created
- [x] Task 0D.2: U_DisplaySelectors implemented
- [x] Task 0D.3: Display slice integrated with M_StateStore + root
- [x] Task 0D.4: Display actions registered with U_ActionRegistry
- [x] Task 0D.5: Integration verified via state + display test suite
- [x] Task 1A.1: I_DisplayManager interface created
- [x] Task 1B.1: M_DisplayManager lifecycle tests created
- [x] Task 1B.2: M_DisplayManager scaffold implemented
- [x] Task 1B.3: M_DisplayManager added to root + ServiceLocator registration
- [x] Task 1B.4: U_DisplayUtils helper created
- [x] Task 2A.1: Window operation tests added (DisplayServer calls, headless pending)
- [x] Task 2A.2: Window operations implemented (presets, mode, vsync)
- [x] Task 2B.1: RS_QualityPreset resource created
- [x] Task 2B.2: Quality preset configs created (low/medium/high/ultra)
- [x] Task 2B.3: Quality preset application wired in M_DisplayManager
- [x] Task 3A.1: Post-process helper tests created
- [x] Task 3A.2: U_PostProcessLayer helper implemented
- [x] Task 3A.3: Post-process overlay scene created
- [x] Task 3B.1: Film Grain shader created
- [x] Task 3B.2: Outline shader created
- [x] Task 3B.3: Dither shader + Bayer texture created
- [x] Task 3B.4: LUT shader + LUT resources created
- [x] Task 3B.5: Overlay wired with shader materials
- [x] Task 3C.1: Post-process overlay integration in M_DisplayManager
- [x] Task 3C.2: Film grain time update wired in _process()
- [x] Task 4.1: UI scale application tests created
- [x] Task 4.2: UI scale application implemented in M_DisplayManager
- [x] Task 4.3: UI scenes register UIScaleRoot helper nodes (no scene tree groups)

---

## Next Steps

### Immediate: Phase 5 - Color Blind Accessibility

1. **Task 5A**: Color palette resource + tests
2. **Task 5B**: Palette manager helper + tests
3. **Task 5C**: Color blind shader (optional)

---

## Key Context

### Test Count Target
- **Total:** ~120 tests (90 unit + 30 integration)
- **Phase 0:** 77 Redux tests (11 + 19 + 28 + 19)

### Critical Patterns to Follow

**Hash-Based Optimization** (from M_AudioManager):
```gdscript
var _last_display_hash: int = 0
var _display_settings_preview_active: bool = false

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

**Slice Registration** (12th parameter):
```gdscript
# In u_state_slice_manager.gd, after audio slice block:
if display_initial_state != null:
    var display_config := RS_StateSliceConfig.new(StringName("display"))
    display_config.reducer = Callable(U_DISPLAY_REDUCER, "reduce")
    display_config.initial_state = display_initial_state.to_dictionary()
    display_config.dependencies = []
    display_config.transient_fields = []  # All settings persist
    register_slice(slice_configs, state, display_config)
```

### Key Decisions Made

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Transient fields | None | All display settings persist to save files |
| Settings UI location | `scenes/ui/overlays/` | Matches audio pattern |
| Post-process layer | 100 | Above gameplay (0), below UI overlays |
| Auto-save to disk | No | Rely on M_SaveManager for persistence |
| Display slice position | 12th parameter | After audio_initial_state |

---

## Reference Files

### Patterns to Study
- `scripts/managers/m_audio_manager.gd` - Hash optimization, preview mode, store discovery
- `scripts/state/utils/u_state_slice_manager.gd` - Slice registration (lines 113-120 for audio)
- `scripts/state/m_state_store.gd` - Export pattern (line 65), initialize_slices call (lines 217-229)
- `scripts/resources/state/rs_audio_initial_state.gd` - Initial state resource pattern

### Files Modified (Phase 0D)
- `scripts/state/m_state_store.gd` - Add display_initial_state export
- `scripts/state/utils/u_state_slice_manager.gd` - Add 12th parameter, register slice
- `scripts/state/u_action_registry.gd` - Register 19 display actions
- `scenes/root.tscn` - Assign cfg_display_initial_state.tres

---

## Display Slice State Shape

```gdscript
{
    "display": {
        # Graphics
        "window_size_preset": "1920x1080",
        "window_mode": "windowed",
        "vsync_enabled": true,
        "quality_preset": "high",

        # Post-Processing
        "film_grain_enabled": false,
        "film_grain_intensity": 0.1,
        "outline_enabled": false,
        "outline_thickness": 2,
        "outline_color": "000000",
        "dither_enabled": false,
        "dither_intensity": 0.5,
        "dither_pattern": "bayer",
        "lut_enabled": false,
        "lut_resource": "",
        "lut_intensity": 1.0,

        # UI
        "ui_scale": 1.0,

        # Accessibility
        "color_blind_mode": "normal",
        "high_contrast_enabled": false,
        "color_blind_shader_enabled": false,
    }
}
```

---

## Validation Constants

```gdscript
const VALID_WINDOW_PRESETS := ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const VALID_WINDOW_MODES := ["windowed", "fullscreen", "borderless"]
const VALID_QUALITY_PRESETS := ["low", "medium", "high", "ultra"]
const VALID_COLOR_BLIND_MODES := ["normal", "deuteranopia", "protanopia", "tritanopia"]
const VALID_DITHER_PATTERNS := ["bayer", "noise"]
```

---

## Test Commands

```bash
# Run display unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -gselect=test_display -ginclude_subdirs=true -gexit

# Run display manager tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/managers -gselect=test_display -ginclude_subdirs=true -gexit

# Run all state tests (regression check)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/state -ginclude_subdirs=true -gexit
```

---

## Phase Checklist

### Phase 0: Redux Foundation
- [x] 0A: Display Initial State Resource (11 tests)
- [x] 0B: Display Actions (19 tests)
- [x] 0C: Display Reducer (28 tests)
- [x] 0D: Display Selectors & Store Integration (19 tests)

### Phase 1: Interface & Core Manager
- [x] 1A: Interface Definition
- [x] 1B: Manager Scaffolding (Tasks 1B.1-1B.4 complete)

### Phase 2: Display/Graphics Settings
- [x] 2A: Window Size & Mode
- [x] 2B: Quality Presets (2B.1-2B.3 complete)

### Phase 3: Post-Processing System
- [x] 3A: Post-Process Overlay & Helper (8 tests)
- [x] 3B: Shaders (4 shaders)
- [x] 3C: Manager Integration

### Phase 4: UI Scaling
- [x] UI scale application (3 tests)

### Phase 5: Color Blind Accessibility
- [ ] 5A: Color Palette Resource (5 tests)
- [ ] 5B: Palette Manager Helper (8 tests)
- [ ] 5C: Color Blind Shader

### Phase 6: Settings UI Integration
- [ ] 6A: Display Settings Tab
- [ ] 6B: Accessibility Settings Section

### Phase 7: Integration Testing
- [ ] Integration tests (30 tests)

### Phase 8: Manual Testing
- [ ] Visual verification (17 items)

### Phase 9: Documentation Updates
- [ ] Update AGENTS.md
- [ ] Update DEV_PITFALLS.md if needed

---

## Notes

- Update this file after completing each phase
- Mark tasks complete in `display-manager-tasks.md` as you go
- Commit documentation updates separately from implementation
