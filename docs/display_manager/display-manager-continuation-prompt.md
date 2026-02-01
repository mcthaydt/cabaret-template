# Display Manager - Continuation Prompt

**Last Updated:** 2026-02-01
**Current Phase:** Phase 0B Complete (Redux Foundation)
**Branch:** `display-manager`

---

## Current Status

Phase 0A and 0B complete (Display Initial State Resource + Display Actions). Actions and tests created.

**Ready to begin Phase 0C: Display Reducer**

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

---

## Next Steps

### Immediate: Phase 0C - Display Reducer

1. **Task 0C.1 (Red)**: Write tests for U_DisplayReducer
   - Create `tests/unit/state/test_display_reducer.gd`
   - 28 tests covering reducer behavior + validation

2. **Task 0C.2 (Green)**: Implement U_DisplayReducer
   - Create `scripts/state/reducers/u_display_reducer.gd`
   - Add validation constants and reducer logic

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

### Files to Modify (Phase 0D)
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
- [ ] 0C: Display Reducer (28 tests)
- [ ] 0D: Display Selectors & Store Integration (19 tests)

### Phase 1: Interface & Core Manager
- [ ] 1A: Interface Definition
- [ ] 1B: Manager Scaffolding (11 tests)

### Phase 2: Display/Graphics Settings
- [ ] 2A: Window Size & Mode
- [ ] 2B: Quality Presets

### Phase 3: Post-Processing System
- [ ] 3A: Post-Process Overlay & Helper (8 tests)
- [ ] 3B: Shaders (4 shaders)
- [ ] 3C: Manager Integration

### Phase 4: UI Scaling
- [ ] UI scale application (3 tests)

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
