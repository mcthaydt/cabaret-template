# Display Manager - Continuation Prompt

**Last Updated:** 2026-02-06
**Current Phase:** Phase 11 Complete (Cinema Grading Post-Process System)
**Branch:** `display-manager`

---

## Current Status

Phase 0A–0D complete (Initial State, Actions, Reducer, Selectors + Store Integration). Display slice is registered and wired in root. Phase 1A interface stub added. Phase 1B scaffolding complete and manager registered in root. Phase 2A window size/mode operations implemented with DisplayServer tests (pending in headless). Phase 2B quality presets applied in M_DisplayManager (resource + configs + RenderingServer/viewport wiring). Phase 3A post-process helper + overlay scene implemented. Phase 3B shaders authored (film grain, CRT, dither, LUT), LUT resources added, and overlay wired with shader materials. Phase 3C manager integration complete (overlay discovery/instantiation + shader parameter wiring + film grain time updates). Phase 4 UI scaling implemented (set_ui_scale + UIScaleRoot registration; applies to CanvasLayer/Control roots and updates newly registered UI nodes). Phase 5 color blind accessibility complete (palette resource + instances, palette manager helper + tests, color blind shader + overlay wiring, manager integration). Minimal UI theme binding now applies palette text colors to common UI controls and is covered by display manager unit tests. Phase 6 settings UI integration complete (display settings overlay + tab, accessibility section wiring, settings menu integration, registry entries). Display settings UI now uses Apply/Cancel + preview, with persistence handled via global settings auto-save on dispatch. Phase 7 integration tests added for display settings UI, post-processing overlay wiring, and color blind palette switching/persistence. Cleanup v5 Phase 10A complete: data-driven option catalogs added (window size presets, quality preset metadata, option lists) and UI/reducer/manager now pull from catalog. Cleanup v5 Phase 10B complete: extracted display appliers (window/quality/post-process/ui scale/theme) and refactored M_DisplayManager to delegate. Cleanup v5 Phase 10C complete: confirm/revert flow added for window changes (countdown + keep/revert). Cleanup v5 Phase 10D complete: UI polish with dependent control gating and microcopy tooltips. Cleanup v5 Phase 10E complete: removed unused hex/safe-area helpers and safe-area padding helper with unit test cleanup.

**Phase 11 complete (2026-02-06):** Cinema grading post-process system implemented. Per-scene artistic color grading via GLSL shader (13 uniforms + 8 named filters). RS_SceneCinemaGrade resource class with @export groups. U_CinemaGradeRegistry with mobile-safe const preload arrays. U_DisplayCinemaGradeApplier creates CinemaGradeLayer (CanvasLayer 1) inside PostProcessOverlay, listens for `scene/transition_completed` via `action_dispatched`. Redux integration uses `cinema_grade/` prefix (NOT persisted to global_settings.json). U_CinemaGradePreview @tool node for editor viewport preview. 5 neutral .tres configs for gameplay scenes. U_DisplayReducer modified with 3 new match cases. M_DisplayManager integrated with cinema grade applier lifecycle. Style tests: 11/11 pass.

Tests (2026-02-06): `tools/run_gut_suite.sh -gdir=res://tests/unit/style -ginclude_subdirs=true` (11/11 pass).

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
- [x] Task 3B.2: CRT shader created (Outline shader exists but is not currently wired)
- [x] Task 3B.3: Dither shader + Bayer texture created
- [x] Task 3B.4: LUT shader + LUT resources created
- [x] Task 3B.5: Overlay wired with shader materials
- [x] Task 3C.1: Post-process overlay integration in M_DisplayManager
- [x] Task 3C.2: Film grain time update wired in _process()
- [x] Task 4.1: UI scale application tests created
- [x] Task 4.2: UI scale application implemented in M_DisplayManager
- [x] Task 4.3: UI scenes register UIScaleRoot helper nodes (no scene tree groups)
- [x] Task 5A: UI color palette resource + palette instances created
- [x] Task 5B: U_PaletteManager helper + tests + manager integration
- [x] Task 5C: Color blind daltonization shader + overlay wiring
- [x] Task 5D: Minimal UI theme binding (palette text colors + tests)
- [x] Task 6A: Display settings tab + overlay + settings menu integration
- [x] Task 6B: Accessibility section wiring (color blind mode, high contrast, shader toggle)
- [x] Task 7.1: Display settings integration tests
- [x] Task 7.2: Post-processing integration tests
- [x] Task 7.3: Color blind palette integration tests
- [x] Task 7.4: UI scale/theme integration tests (CI-safe)
- [x] Task 10A: Data-driven option catalogs (U_DisplayOptionCatalog + RS_WindowSizePreset + catalog-backed UI/reducer/manager)
- [x] Task 10B: Extracted display appliers (window/quality/post-process/ui scale/theme)
- [x] Task 10C: Confirm/revert flow for window changes (Apply/Cancel + preview remains)
- [x] Task 10D: Settings UI polish (contextual enable/disable + focus clarity)
- [x] Task 10E: Remove dead code after tests prove unused
- [x] Task 11A.1: Cinema grade GLSL shader (13 uniforms + 8 filters)
- [x] Task 11B.1: RS_SceneCinemaGrade resource class
- [x] Task 11B.2: U_CinemaGradeRegistry (mobile-safe const preload)
- [x] Task 11B.3: Per-scene .tres configs (5 neutral configs)
- [x] Task 11C.1: U_CinemaGradeActions (cinema_grade/ prefix, not persisted)
- [x] Task 11C.2: U_CinemaGradeSelectors
- [x] Task 11C.3: U_DisplayReducer modified (3 cinema_grade/ match cases)
- [x] Task 11D.1: U_DisplayCinemaGradeApplier (CinemaGradeLayer at layer 1)
- [x] Task 11D.2: M_DisplayManager integration (applier lifecycle)
- [x] Task 11E.1: U_CinemaGradePreview @tool editor preview
- [x] Task 11F.1: Style enforcement tests pass (11/11)

---

## Next Steps

### Immediate: Next Phase

1. **Task 11F.2**: Manual visual verification of cinema grading
   - Temp scene shader test (all uniforms)
   - Scene transition grade swap
   - Editor preview
   - Overlay visibility (pause menu hide/show)
   - Stacking with existing effects (film grain + CRT + dither)
2. **Task 8**: Run manual verification checklist (MT-01 → MT-17)

### Later: Phase 8 - Manual Testing

1. **Task 8**: Run manual verification checklist (MT-01 → MT-17)
2. **Task 9**: Documentation updates (AGENTS.md, DEV_PITFALLS.md if applicable)
3. **Phase 6 (Tuning)**: Tune each scene's .tres for desired artistic look

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
| Transient fields | None | Display settings persist to `user://global_settings.json` (not save slots) |
| Settings UI location | `scenes/ui/overlays/` | Matches audio pattern |
| Post-process layer | 100 | Above gameplay (0), below UI overlays |
| Auto-save to disk | Yes | Persist via M_StateStore → `user://global_settings.json` (SaveManager excludes display slice) |
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
        "crt_enabled": false,
        "crt_scanline_intensity": 0.3,
        "crt_curvature": 2.0,
        "crt_chromatic_aberration": 0.002,
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

        # Cinema Grade (transient — loaded per-scene, NOT persisted)
        "cinema_grade_filter_mode": 0,       # 0=none, 1-8=named filters
        "cinema_grade_filter_intensity": 1.0,
        "cinema_grade_exposure": 0.0,
        "cinema_grade_brightness": 0.0,
        "cinema_grade_contrast": 1.0,
        "cinema_grade_brilliance": 0.0,
        "cinema_grade_highlights": 0.0,
        "cinema_grade_shadows": 0.0,
        "cinema_grade_saturation": 1.0,
        "cinema_grade_vibrance": 0.0,
        "cinema_grade_warmth": 0.0,
        "cinema_grade_tint": 0.0,
        "cinema_grade_sharpness": 0.0,
    }
}
```

---

## Validation Sources

Validation for window modes, dither patterns, color blind modes, and preset IDs now comes from `U_DisplayOptionCatalog` (data-driven presets + static option lists). Defaults currently include:

- Window presets: 1280x720, 1600x900, 1920x1080, 2560x1440, 3840x2160
- Window modes: windowed, fullscreen, borderless
- Quality presets: low, medium, high, ultra
- Color blind modes: normal, deuteranopia, protanopia, tritanopia
- Dither patterns: bayer, noise

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
- [x] 5A: Color Palette Resource (5 tests)
- [x] 5B: Palette Manager Helper (8 tests)
- [x] 5C: Color Blind Shader

### Phase 6: Settings UI Integration
- [x] 6A: Display Settings Tab
- [x] 6B: Accessibility Settings Section

### Phase 7: Integration Testing
- [x] Integration tests (30 tests)

### Phase 8: Manual Testing
- [ ] Visual verification (17 items)

### Phase 9: Documentation Updates
- [ ] Update AGENTS.md
- [ ] Update DEV_PITFALLS.md if needed

### Phase 11: Cinema Grading Post-Process System
- [x] 11A: Cinema grade GLSL shader
- [x] 11B: Resource class + registry + 5 .tres configs
- [x] 11C: Redux integration (actions, selectors, reducer)
- [x] 11D: Applier + manager integration
- [x] 11E: @tool editor preview
- [x] 11F.1: Style tests pass
- [ ] 11F.2: Manual visual verification

---

## Notes

- Update this file after completing each phase
- Mark tasks complete in `display-manager-tasks.md` as you go
- Commit documentation updates separately from implementation
