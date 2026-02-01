# Display Manager - Implementation Plan

**Project**: Cabaret Template (Godot 4.6)
**Status**: Planning
**Estimated Duration**: 18 days
**Test Count**: ~120 tests (90 unit + 30 integration)
**Methodology**: Test-Driven Development (Red-Green-Refactor)

---

## Overview

The Display Manager handles visual post-processing effects (Film Grain, Outline, Dither, LUT), graphics settings (window size, fullscreen, VSync, quality presets), UI scaling, and color blind accessibility. Implementation follows established codebase patterns for Redux slices, managers, and settings UI integration.

## Key Patterns to Follow

Before implementation, study these reference files:
- `scripts/managers/m_audio_manager.gd` - Hash-based optimization, preview mode, store discovery
- `scripts/state/utils/u_state_slice_manager.gd` - Slice registration pattern
- `scripts/state/m_state_store.gd` - Export pattern, initialize_slices call
- `scripts/root.gd` - ServiceLocator registration

---

## Phase 0: Redux Foundation (Days 1-3)

**PREREQUISITE**: Audio Manager Phase 0 must be complete before starting Display Manager implementation. The `display_initial_state` parameter must be added as the **12th parameter** (AFTER `audio_initial_state`) in the `u_state_slice_manager.initialize_slices()` function signature.

**Exit Criteria**: 77 Redux tests pass (11+19+28+19), display slice registered in M_StateStore, no console errors

### Commit 1: Display Initial State Resource

**Files to create**:
- `scripts/resources/state/rs_display_initial_state.gd`
- `tests/unit/state/test_display_initial_state.gd` (8 tests)

**Implementation**:
```gdscript
@icon("res://assets/editor_icons/resource.svg")
extends Resource
class_name RS_DisplayInitialState

@export_group("Graphics")
@export var window_size_preset: String = "1920x1080"
@export_enum("windowed", "fullscreen", "borderless") var window_mode: String = "windowed"
@export var vsync_enabled: bool = true
@export_enum("low", "medium", "high", "ultra") var quality_preset: String = "high"

@export_group("Post-Processing")
# Note: Effect order is fixed internally (Film Grain → Outline → Dither → LUT), not user-configurable
@export var film_grain_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var film_grain_intensity: float = 0.1
@export var outline_enabled: bool = false
@export_range(1, 5, 1) var outline_thickness: int = 2
@export var outline_color: String = "000000"
@export var dither_enabled: bool = false
@export_range(0.0, 1.0, 0.05) var dither_intensity: float = 0.5
@export_enum("bayer", "noise") var dither_pattern: String = "bayer"
@export var lut_enabled: bool = false
@export var lut_resource: String = ""
@export_range(0.0, 1.0, 0.05) var lut_intensity: float = 1.0

@export_group("UI")
@export_range(0.5, 2.0, 0.1) var ui_scale: float = 1.0

@export_group("Accessibility")
@export_enum("normal", "deuteranopia", "protanopia", "tritanopia") var color_blind_mode: String = "normal"
@export var high_contrast_enabled: bool = false
@export var color_blind_shader_enabled: bool = false

func to_dictionary() -> Dictionary:
    return {
        "window_size_preset": window_size_preset,
        "window_mode": window_mode,
        "vsync_enabled": vsync_enabled,
        "quality_preset": quality_preset,
        "film_grain_enabled": film_grain_enabled,
        "film_grain_intensity": film_grain_intensity,
        "outline_enabled": outline_enabled,
        "outline_thickness": outline_thickness,
        "outline_color": outline_color,
        "dither_enabled": dither_enabled,
        "dither_intensity": dither_intensity,
        "dither_pattern": dither_pattern,
        "lut_enabled": lut_enabled,
        "lut_resource": lut_resource,
        "lut_intensity": lut_intensity,
        "ui_scale": ui_scale,
        "color_blind_mode": color_blind_mode,
        "high_contrast_enabled": high_contrast_enabled,
        "color_blind_shader_enabled": color_blind_shader_enabled,
    }
```

**Tests**:
- test_has_window_size_preset_field
- test_has_window_mode_field
- test_has_vsync_enabled_field
- test_has_film_grain_fields
- test_has_outline_fields
- test_has_dither_fields
- test_has_lut_fields
- test_has_ui_scale_field
- test_has_accessibility_fields
- test_to_dictionary_returns_all_fields
- test_defaults_match_reducer

---

### Commit 2: Display Actions

**Files to create**:
- `scripts/state/actions/u_display_actions.gd`
- `tests/unit/state/test_display_actions.gd` (19 tests)

**Action Creators** (19 total):
```gdscript
class_name U_DisplayActions
extends RefCounted

# Graphics
const ACTION_SET_WINDOW_SIZE_PRESET := StringName("display/set_window_size_preset")
const ACTION_SET_WINDOW_MODE := StringName("display/set_window_mode")
const ACTION_SET_VSYNC_ENABLED := StringName("display/set_vsync_enabled")
const ACTION_SET_QUALITY_PRESET := StringName("display/set_quality_preset")

# Post-Processing (effect order is fixed internally, not user-configurable)
const ACTION_SET_FILM_GRAIN_ENABLED := StringName("display/set_film_grain_enabled")
const ACTION_SET_FILM_GRAIN_INTENSITY := StringName("display/set_film_grain_intensity")
const ACTION_SET_OUTLINE_ENABLED := StringName("display/set_outline_enabled")
const ACTION_SET_OUTLINE_THICKNESS := StringName("display/set_outline_thickness")
const ACTION_SET_OUTLINE_COLOR := StringName("display/set_outline_color")
const ACTION_SET_DITHER_ENABLED := StringName("display/set_dither_enabled")
const ACTION_SET_DITHER_INTENSITY := StringName("display/set_dither_intensity")
const ACTION_SET_DITHER_PATTERN := StringName("display/set_dither_pattern")
const ACTION_SET_LUT_ENABLED := StringName("display/set_lut_enabled")
const ACTION_SET_LUT_RESOURCE := StringName("display/set_lut_resource")
const ACTION_SET_LUT_INTENSITY := StringName("display/set_lut_intensity")

# UI
const ACTION_SET_UI_SCALE := StringName("display/set_ui_scale")

# Accessibility
const ACTION_SET_COLOR_BLIND_MODE := StringName("display/set_color_blind_mode")
const ACTION_SET_HIGH_CONTRAST_ENABLED := StringName("display/set_high_contrast_enabled")
const ACTION_SET_COLOR_BLIND_SHADER_ENABLED := StringName("display/set_color_blind_shader_enabled")

static func set_window_size_preset(preset: String) -> Dictionary:
    return {"type": ACTION_SET_WINDOW_SIZE_PRESET, "payload": {"preset": preset}}

static func set_window_mode(mode: String) -> Dictionary:
    return {"type": ACTION_SET_WINDOW_MODE, "payload": {"mode": mode}}

# ... (similar pattern for all action creators)
```

**Tests**:
- test_set_window_size_preset_action
- test_set_window_mode_action
- test_set_vsync_enabled_action
- test_set_quality_preset_action
- test_set_film_grain_enabled_action
- test_set_film_grain_intensity_action
- test_set_outline_enabled_action
- test_set_outline_thickness_action
- test_set_outline_color_action
- test_set_dither_enabled_action
- test_set_dither_intensity_action
- test_set_dither_pattern_action
- test_set_lut_enabled_action
- test_set_lut_resource_action
- test_set_lut_intensity_action
- test_set_ui_scale_action
- test_set_color_blind_mode_action
- test_set_high_contrast_enabled_action
- test_set_color_blind_shader_enabled_action

---

### Commit 3: Display Reducer

**Files to create**:
- `scripts/state/reducers/u_display_reducer.gd`
- `tests/unit/state/test_display_reducer.gd` (28 tests)

**Key Features**:
- Intensity clamping (0.0-1.0 for film_grain, dither, lut)
- Thickness clamping (1-5 for outline)
- UI scale clamping (0.5-2.0)
- Immutability helpers (_merge_with_defaults, _with_values, _deep_copy)
- Valid window presets: ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
- Valid window modes: ["windowed", "fullscreen", "borderless"]
- Valid quality presets: ["low", "medium", "high", "ultra"]
- Valid color blind modes: ["normal", "deuteranopia", "protanopia", "tritanopia"]
- Valid dither patterns: ["bayer", "noise"]

**Implementation**:
```gdscript
class_name U_DisplayReducer
extends RefCounted

const VALID_WINDOW_PRESETS := ["1280x720", "1600x900", "1920x1080", "2560x1440", "3840x2160"]
const VALID_WINDOW_MODES := ["windowed", "fullscreen", "borderless"]
const VALID_QUALITY_PRESETS := ["low", "medium", "high", "ultra"]
const VALID_COLOR_BLIND_MODES := ["normal", "deuteranopia", "protanopia", "tritanopia"]
const VALID_DITHER_PATTERNS := ["bayer", "noise"]

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var action_type: StringName = action.get("type", StringName(""))
    var payload: Dictionary = action.get("payload", {})

    match action_type:
        U_DisplayActions.ACTION_SET_WINDOW_SIZE_PRESET:
            var preset: String = payload.get("preset", "1920x1080")
            if preset in VALID_WINDOW_PRESETS:
                return _with_values(state, {"window_size_preset": preset})
        U_DisplayActions.ACTION_SET_FILM_GRAIN_INTENSITY:
            var intensity: float = clampf(payload.get("intensity", 0.1), 0.0, 1.0)
            return _with_values(state, {"film_grain_intensity": intensity})
        U_DisplayActions.ACTION_SET_OUTLINE_THICKNESS:
            var thickness: int = clampi(payload.get("thickness", 2), 1, 5)
            return _with_values(state, {"outline_thickness": thickness})
        U_DisplayActions.ACTION_SET_UI_SCALE:
            var scale: float = clampf(payload.get("scale", 1.0), 0.5, 2.0)
            return _with_values(state, {"ui_scale": scale})
        # ... handle all other actions

    return state

static func _with_values(state: Dictionary, values: Dictionary) -> Dictionary:
    var new_state := state.duplicate(true)
    for key in values:
        new_state[key] = values[key]
    return new_state
```

**Critical Tests**:
- test_set_film_grain_intensity_clamp_lower (-0.5 → 0.0)
- test_set_film_grain_intensity_clamp_upper (1.5 → 1.0)
- test_set_outline_thickness_clamp_lower (0 → 1)
- test_set_outline_thickness_clamp_upper (10 → 5)
- test_set_ui_scale_clamp_lower (0.2 → 0.5)
- test_set_ui_scale_clamp_upper (3.0 → 2.0)
- test_invalid_window_preset_ignored
- test_invalid_window_mode_ignored
- test_invalid_quality_preset_ignored
- test_invalid_color_blind_mode_ignored
- test_invalid_dither_pattern_ignored
- test_reducer_immutability (old_state is not new_state)

---

### Commit 4: Display Selectors & M_StateStore Integration

**Files to create**:
- `scripts/state/selectors/u_display_selectors.gd`
- `tests/unit/state/test_display_selectors.gd` (19 tests)

**Files to modify**:

**1. `scripts/state/m_state_store.gd`**:
```gdscript
# Line ~41, add const:
const RS_DISPLAY_INITIAL_STATE := preload("res://scripts/resources/state/rs_display_initial_state.gd")

# Line ~65, add export:
@export var display_initial_state: Resource

# Lines 217-229, add as 12th param to initialize_slices() call:
U_STATE_SLICE_MANAGER.initialize_slices(
    _slice_configs,
    _state,
    boot_initial_state,
    menu_initial_state,
    navigation_initial_state,
    settings_initial_state,
    gameplay_initial_state,
    scene_initial_state,
    debug_initial_state,
    vfx_initial_state,
    audio_initial_state,
    display_initial_state  # ADD THIS AS 12TH PARAM
)
```

**2. `scripts/state/utils/u_state_slice_manager.gd`**:
```gdscript
# Line ~11, add const:
const U_DISPLAY_REDUCER := preload("res://scripts/state/reducers/u_display_reducer.gd")

# Lines 16-28, add 12th parameter:
static func initialize_slices(
    slice_configs: Dictionary,
    state: Dictionary,
    boot_initial_state: RS_BootInitialState,
    menu_initial_state: RS_MenuInitialState,
    navigation_initial_state: Resource,
    settings_initial_state: RS_SettingsInitialState,
    gameplay_initial_state: RS_GameplayInitialState,
    scene_initial_state: RS_SceneInitialState,
    debug_initial_state: RS_DebugInitialState,
    vfx_initial_state: RS_VFXInitialState,
    audio_initial_state: RS_AudioInitialState,
    display_initial_state: Resource  # ADD THIS (Resource to avoid headless class cache issues)
) -> void:

# After line 120 (after audio slice block), add:
# Display slice
if display_initial_state != null:
    var display_config := RS_StateSliceConfig.new(StringName("display"))
    display_config.reducer = Callable(U_DISPLAY_REDUCER, "reduce")
    display_config.initial_state = display_initial_state.to_dictionary()
    display_config.dependencies = []
    display_config.transient_fields = []  # All settings persist
    register_slice(slice_configs, state, display_config)
```

**3. `scripts/state/u_action_registry.gd`**:
- Register all 19 U_DisplayActions action types in the registered actions array

**4. `scenes/root.tscn`**:
- Assign `resources/base_settings/state/cfg_display_initial_state.tres` to M_StateStore.display_initial_state export

**Selectors**:
```gdscript
class_name U_DisplaySelectors
extends RefCounted

static func get_window_size_preset(state: Dictionary) -> String:
    return state.get("display", {}).get("window_size_preset", "1920x1080")

static func get_window_mode(state: Dictionary) -> String:
    return state.get("display", {}).get("window_mode", "windowed")

static func is_vsync_enabled(state: Dictionary) -> bool:
    return state.get("display", {}).get("vsync_enabled", true)

static func get_quality_preset(state: Dictionary) -> String:
    return state.get("display", {}).get("quality_preset", "high")

static func is_film_grain_enabled(state: Dictionary) -> bool:
    return state.get("display", {}).get("film_grain_enabled", false)

static func get_film_grain_intensity(state: Dictionary) -> float:
    return state.get("display", {}).get("film_grain_intensity", 0.1)

static func is_outline_enabled(state: Dictionary) -> bool:
    return state.get("display", {}).get("outline_enabled", false)

static func get_outline_thickness(state: Dictionary) -> int:
    return state.get("display", {}).get("outline_thickness", 2)

static func get_outline_color(state: Dictionary) -> String:
    return state.get("display", {}).get("outline_color", "000000")

static func is_dither_enabled(state: Dictionary) -> bool:
    return state.get("display", {}).get("dither_enabled", false)

static func get_dither_intensity(state: Dictionary) -> float:
    return state.get("display", {}).get("dither_intensity", 0.5)

static func get_dither_pattern(state: Dictionary) -> String:
    return state.get("display", {}).get("dither_pattern", "bayer")

static func is_lut_enabled(state: Dictionary) -> bool:
    return state.get("display", {}).get("lut_enabled", false)

static func get_lut_resource(state: Dictionary) -> String:
    return state.get("display", {}).get("lut_resource", "")

static func get_lut_intensity(state: Dictionary) -> float:
    return state.get("display", {}).get("lut_intensity", 1.0)

static func get_ui_scale(state: Dictionary) -> float:
    return state.get("display", {}).get("ui_scale", 1.0)

static func get_color_blind_mode(state: Dictionary) -> String:
    return state.get("display", {}).get("color_blind_mode", "normal")

static func is_high_contrast_enabled(state: Dictionary) -> bool:
    return state.get("display", {}).get("high_contrast_enabled", false)

static func is_color_blind_shader_enabled(state: Dictionary) -> bool:
    return state.get("display", {}).get("color_blind_shader_enabled", false)
```

---

## Phase 1: Interface & Core Manager (Days 4-5)

### Commit 1: I_DisplayManager Interface

**Files to create**:
- `scripts/interfaces/i_display_manager.gd`

**Implementation**:
```gdscript
extends Node
class_name I_DisplayManager

func set_display_settings_preview(_settings: Dictionary) -> void:
    push_error("I_DisplayManager.set_display_settings_preview not implemented")

func clear_display_settings_preview() -> void:
    push_error("I_DisplayManager.clear_display_settings_preview not implemented")

func get_active_palette() -> Resource:
    push_error("I_DisplayManager.get_active_palette not implemented")
    return null
```

---

### Commit 2: Manager Scaffolding & Lifecycle

**Files to create**:
- `scripts/managers/m_display_manager.gd`
- `scripts/utils/display/u_display_utils.gd`
- `tests/unit/managers/test_display_manager.gd` (11 tests)

**Manager Structure**:
```gdscript
@icon("res://assets/editor_icons/icn_manager.svg")
class_name M_DisplayManager
extends I_DisplayManager

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")
const U_STATE_UTILS := preload("res://scripts/state/utils/u_state_utils.gd")
const U_DISPLAY_SELECTORS := preload("res://scripts/state/selectors/u_display_selectors.gd")

# Dependency injection for testability
@export var state_store: I_StateStore = null

var _last_display_hash: int = 0
var _display_settings_preview_active: bool = false
var _preview_settings: Dictionary = {}

func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    add_to_group("display_manager")
    U_SERVICE_LOCATOR.register(StringName("display_manager"), self)
    _initialize_store_async()

func _initialize_store_async() -> void:
    # Use injected store if provided (for testing)
    if state_store != null:
        _on_store_ready()
        return

    # Discover via U_StateUtils with soft timeout (pattern from M_AudioManager)
    state_store = await U_STATE_UTILS.try_get_store(self, 2.0)
    if state_store != null:
        _on_store_ready()
    else:
        push_warning("M_DisplayManager: Could not discover state store")

func _on_store_ready() -> void:
    state_store.slice_updated.connect(_on_slice_updated)
    _apply_display_settings(state_store.get_state())

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
    # Skip if not display slice or if preview mode is active
    if slice_name != &"display" or _display_settings_preview_active:
        return

    var state := state_store.get_state()
    var display_slice: Dictionary = state.get("display", {})
    var display_hash := display_slice.hash()

    # Only apply if display slice actually changed (hash-based optimization)
    if display_hash != _last_display_hash:
        _apply_display_settings(state)
        _last_display_hash = display_hash

func set_display_settings_preview(preview: Dictionary) -> void:
    _display_settings_preview_active = true  # Blocks hash-based updates
    _preview_settings = preview.duplicate(true)
    _apply_preview_settings()

func clear_display_settings_preview() -> void:
    _display_settings_preview_active = false
    _preview_settings.clear()
    if state_store != null:
        _apply_display_settings(state_store.get_state())

func get_active_palette() -> RS_UIColorPalette:
    return _palette_manager.get_active_palette()
```

**U_DisplayUtils Helper** (`scripts/utils/display/u_display_utils.gd`):
```gdscript
class_name U_DisplayUtils
extends RefCounted

const U_SERVICE_LOCATOR := preload("res://scripts/core/u_service_locator.gd")

static func get_display_manager() -> M_DisplayManager:
    return U_SERVICE_LOCATOR.get_service(StringName("display_manager")) as M_DisplayManager
```

**Tests**:
- test_manager_extends_i_display_manager
- test_manager_registers_with_service_locator
- test_manager_adds_to_group
- test_manager_discovers_state_store
- test_manager_subscribes_to_slice_updates
- test_settings_applied_on_ready
- test_settings_applied_on_slice_change
- test_hash_prevents_redundant_applies
- test_preview_mode_sets_active_flag
- test_preview_mode_overrides_state
- test_clear_preview_restores_state

---

### Commit 3: Add to Main Scene

**Files to modify**:

**1. `scenes/root.tscn`**:
- Add M_DisplayManager node under Managers/
- Position after M_AudioManager, before UI managers

**2. `scripts/root.gd`**:
```gdscript
# Add to _register_managers() or equivalent:
_register_if_exists(managers_node, "M_DisplayManager", StringName("display_manager"))
```

**Node Position**: After M_AudioManager, before UI managers

---

## Phase 2: Display/Graphics Settings (Days 6-8)

### Commit 1: Window Size & Mode Application

**Files to modify**:
- `scripts/managers/m_display_manager.gd`

**Implementation**:
```gdscript
const WINDOW_PRESETS := {
    "1280x720": Vector2i(1280, 720),
    "1600x900": Vector2i(1600, 900),
    "1920x1080": Vector2i(1920, 1080),
    "2560x1440": Vector2i(2560, 1440),
    "3840x2160": Vector2i(3840, 2160),
}

func apply_window_size_preset(preset: String) -> void:
    if preset not in WINDOW_PRESETS:
        push_warning("Invalid window preset: %s" % preset)
        return
    var size: Vector2i = WINDOW_PRESETS[preset]
    DisplayServer.window_set_size(size)
    # Center window on screen
    var screen_size := DisplayServer.screen_get_size()
    var window_pos := (screen_size - size) / 2
    DisplayServer.window_set_position(window_pos)

func set_window_mode(mode: String) -> void:
    match mode:
        "fullscreen":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        "borderless":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
        "windowed":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)

func set_vsync_enabled(enabled: bool) -> void:
    if enabled:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
    else:
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
```

---

### Commit 2: Quality Presets

**Files to create**:
- `scripts/resources/display/rs_quality_preset.gd`
- `resources/display/cfg_quality_presets/cfg_quality_low.tres`
- `resources/display/cfg_quality_presets/cfg_quality_medium.tres`
- `resources/display/cfg_quality_presets/cfg_quality_high.tres`
- `resources/display/cfg_quality_presets/cfg_quality_ultra.tres`

**Quality Settings Resource** (`scripts/resources/display/rs_quality_preset.gd`):
```gdscript
class_name RS_QualityPreset
extends Resource

@export var preset_name: String
@export_enum("off", "low", "medium", "high") var shadow_quality: String = "medium"
@export_enum("none", "fxaa", "msaa_2x", "msaa_4x", "msaa_8x") var anti_aliasing: String = "fxaa"
@export var post_processing_enabled: bool = true
```

**Application**:
```gdscript
func apply_quality_preset(preset: String) -> void:
    var config := _load_quality_preset(preset)
    if config == null:
        return

    # Shadow quality
    match config.shadow_quality:
        "off":
            RenderingServer.directional_shadow_atlas_set_size(0, false)
        "low":
            RenderingServer.directional_shadow_atlas_set_size(1024, false)
        "medium":
            RenderingServer.directional_shadow_atlas_set_size(2048, true)
        "high":
            RenderingServer.directional_shadow_atlas_set_size(4096, true)

    # Anti-aliasing
    var viewport := get_viewport()
    match config.anti_aliasing:
        "none":
            viewport.msaa_3d = Viewport.MSAA_DISABLED
            viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
        "fxaa":
            viewport.msaa_3d = Viewport.MSAA_DISABLED
            viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
        "msaa_2x":
            viewport.msaa_3d = Viewport.MSAA_2X
            viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
        "msaa_4x":
            viewport.msaa_3d = Viewport.MSAA_4X
            viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
        "msaa_8x":
            viewport.msaa_3d = Viewport.MSAA_8X
            viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
```

---

## Phase 3: Post-Processing System (Days 9-12)

### Commit 1: Post-Process Overlay Scene & Helper

**Files to create**:
- `scenes/ui/overlays/ui_post_process_overlay.tscn`
- `scripts/managers/helpers/u_post_process_layer.gd`
- `tests/unit/managers/helpers/test_post_process_layer.gd` (15 tests)

**Scene Structure** (`ui_post_process_overlay.tscn`):
```
CanvasLayer (layer 100, mouse_filter IGNORE)
├── FilmGrainRect (ColorRect, full screen, sh_film_grain_shader.gdshader)
├── OutlineRect (ColorRect, full screen, sh_outline_shader.gdshader)
├── DitherRect (ColorRect, full screen, sh_dither_shader.gdshader)
└── LUTRect (ColorRect, full screen, sh_lut_shader.gdshader)
```

**Effect Stack Management**:
```gdscript
class_name U_PostProcessLayer
extends RefCounted

var _canvas_layer: CanvasLayer
var _effect_rects: Dictionary = {}  # effect_name -> ColorRect

func initialize(canvas_layer: CanvasLayer) -> void:
    _canvas_layer = canvas_layer
    _cache_effect_rects()

func _cache_effect_rects() -> void:
    # Cache references to effect ColorRects (created in scene)
    _effect_rects["film_grain"] = _canvas_layer.get_node_or_null("FilmGrainRect")
    _effect_rects["outline"] = _canvas_layer.get_node_or_null("OutlineRect")
    _effect_rects["dither"] = _canvas_layer.get_node_or_null("DitherRect")
    _effect_rects["lut"] = _canvas_layer.get_node_or_null("LUTRect")

func set_effect_enabled(effect_name: String, enabled: bool) -> void:
    var rect: ColorRect = _effect_rects.get(effect_name)
    if rect != null:
        rect.visible = enabled

func set_effect_parameter(effect_name: String, param: String, value: Variant) -> void:
    var rect: ColorRect = _effect_rects.get(effect_name)
    if rect == null or rect.material == null:
        return
    var shader_material := rect.material as ShaderMaterial
    if shader_material != null:
        shader_material.set_shader_parameter(param, value)
```

**Note**: Effect order is fixed by the scene structure (Film Grain → Outline → Dither → LUT). This is not user-configurable.

---

### Commit 2: Film Grain Shader

**Files to create**:
- `assets/shaders/sh_film_grain_shader.gdshader`

**Shader** (simplified):
```glsl
shader_type canvas_item;

uniform float intensity : hint_range(0.0, 1.0) = 0.1;
uniform float time;

float random(vec2 uv) {
    return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    vec4 color = texture(TEXTURE, UV);
    float noise = random(UV + vec2(time)) * 2.0 - 1.0;
    color.rgb += noise * intensity * 0.1;
    COLOR = color;
}
```

---

### Commit 3: Outline Shader

**Files to create**:
- `assets/shaders/sh_outline_shader.gdshader`

**Sobel Edge Detection**:
```glsl
shader_type canvas_item;

uniform int thickness : hint_range(1, 5) = 2;
uniform vec3 outline_color : source_color = vec3(0.0);
uniform sampler2D screen_texture : hint_screen_texture;

void fragment() {
    vec2 pixel_size = 1.0 / vec2(textureSize(screen_texture, 0));
    // Sobel edge detection implementation
    // ...
}
```

---

### Commit 4: Dither Shader

**Files to create**:
- `assets/shaders/sh_dither_shader.gdshader`
- `resources/textures/tex_bayer_8x8.png`

---

### Commit 5: LUT Color Grading Shader

**Files to create**:
- `assets/shaders/sh_lut_shader.gdshader`
- `scripts/resources/display/rs_lut_definition.gd`
- `resources/luts/cfg_lut_neutral.tres` (identity LUT)
- `resources/luts/cfg_lut_warm.tres`
- `resources/luts/cfg_lut_cool.tres`
- `resources/luts/tex_lut_neutral.png`
- `resources/luts/tex_lut_warm.png`
- `resources/luts/tex_lut_cool.png`

---

## Phase 4: UI Scaling (Days 13-14)

### Commit 1: UI Scale Application

**Files to modify**:
- `scripts/managers/m_display_manager.gd`

**Implementation**:
```gdscript
func set_ui_scale(scale: float) -> void:
    scale = clampf(scale, 0.5, 2.0)
    var ui_layers := get_tree().get_nodes_in_group("ui_scalable")
    for layer in ui_layers:
        if layer is CanvasLayer:
            # Scale transform
            layer.transform = Transform2D().scaled(Vector2(scale, scale))

func _apply_ui_scale(state: Dictionary) -> void:
    var scale := U_DisplaySelectors.get_ui_scale(state)
    set_ui_scale(scale)
```

**Files to modify** (add to "ui_scalable" group):
- `scenes/ui/menus/*.tscn`
- `scenes/ui/overlays/*.tscn`
- `scenes/ui/hud/*.tscn`

---

## Phase 5: Color Blind Accessibility (Days 15-16)

### Commit 1: RS_UIColorPalette Resource

**Files to create**:
- `scripts/resources/ui/rs_ui_color_palette.gd`
- `resources/ui_themes/cfg_palette_normal.tres`
- `resources/ui_themes/cfg_palette_deuteranopia.tres`
- `resources/ui_themes/cfg_palette_protanopia.tres`
- `resources/ui_themes/cfg_palette_tritanopia.tres`
- `resources/ui_themes/cfg_palette_high_contrast.tres`
- `tests/unit/resources/test_ui_color_palette.gd` (10 tests)

**Resource Definition** (`scripts/resources/ui/rs_ui_color_palette.gd`):
```gdscript
@icon("res://assets/editor_icons/resource.svg")
class_name RS_UIColorPalette
extends Resource

@export var palette_id: StringName
@export var primary: Color = Color.WHITE
@export var secondary: Color = Color.GRAY
@export var success: Color = Color.GREEN
@export var warning: Color = Color.YELLOW
@export var danger: Color = Color.RED
@export var info: Color = Color.CYAN
@export var background: Color = Color.BLACK
@export var text: Color = Color.WHITE
```

**Palette Values** (example: deuteranopia):
```gdscript
# cfg_palette_deuteranopia.tres
palette_id = &"deuteranopia"
primary = Color(0.0, 0.45, 0.7)     # Blue (replaces green)
secondary = Color(0.8, 0.6, 0.7)    # Pink (replaces red)
success = Color(0.0, 0.6, 0.5)      # Teal
warning = Color(0.95, 0.9, 0.25)    # Yellow (preserved)
danger = Color(0.8, 0.4, 0.0)       # Orange (replaces red)
info = Color(0.35, 0.7, 0.9)        # Light blue
background = Color(0.1, 0.1, 0.1)
text = Color(1.0, 1.0, 1.0)
```

---

### Commit 2: U_PaletteManager Helper

**Files to create**:
- `scripts/managers/helpers/u_palette_manager.gd`
- `tests/unit/managers/helpers/test_palette_manager.gd` (10 tests)

**Implementation**:
```gdscript
class_name U_PaletteManager
extends RefCounted

signal active_palette_changed(palette: RS_UIColorPalette)

# Palette instances live in resources/, class definition in scripts/resources/ui/
const PALETTE_PATHS := {
    "normal": "res://resources/ui_themes/cfg_palette_normal.tres",
    "deuteranopia": "res://resources/ui_themes/cfg_palette_deuteranopia.tres",
    "protanopia": "res://resources/ui_themes/cfg_palette_protanopia.tres",
    "tritanopia": "res://resources/ui_themes/cfg_palette_tritanopia.tres",
    "high_contrast": "res://resources/ui_themes/cfg_palette_high_contrast.tres",
}

var _cached_palettes: Dictionary = {}
var _active_palette: RS_UIColorPalette

func set_color_blind_mode(mode: String) -> void:
    var palette := _load_palette(mode)
    if palette == null:
        push_warning("Unknown color blind mode: %s, falling back to normal" % mode)
        palette = _load_palette("normal")
    _active_palette = palette
    active_palette_changed.emit(palette)

func get_active_palette() -> RS_UIColorPalette:
    return _active_palette

func _load_palette(mode: String) -> RS_UIColorPalette:
    if mode in _cached_palettes:
        return _cached_palettes[mode]
    if mode not in PALETTE_PATHS:
        return null
    var palette := load(PALETTE_PATHS[mode]) as RS_UIColorPalette
    _cached_palettes[mode] = palette
    return palette
```

---

### Commit 3: Color Blind Shader Filter (Optional)

**Files to create**:
- `assets/shaders/sh_colorblind_daltonize.gdshader`

**Daltonization Shader** (simulates and corrects color blindness):
```glsl
shader_type canvas_item;

uniform int mode : hint_range(0, 3) = 0;  // 0=off, 1=deuteranopia, 2=protanopia, 3=tritanopia

// Color transformation matrices for simulation
// ...
```

**Note**: This shader is applied via an additional ColorRect in the post-process overlay when `color_blind_shader_enabled` is true.

---

## Phase 6: Settings UI Integration (Days 17-18)

### Commit 1: Display Settings Tab

**Files to create**:
- `scenes/ui/settings/ui_display_settings_tab.tscn`
- `scripts/ui/settings/ui_display_settings_tab.gd`

**Scene Structure**:
```
ScrollContainer
└── VBoxContainer
    ├── Label ("DISPLAY")
    ├── HBoxContainer (Window Size)
    │   ├── Label
    │   └── OptionButton (presets)
    ├── HBoxContainer (Window Mode)
    │   ├── Label
    │   └── OptionButton (fullscreen/windowed/borderless)
    ├── CheckBox (VSync)
    ├── HSeparator
    ├── Label ("QUALITY")
    ├── HBoxContainer (Quality Preset)
    │   ├── Label
    │   └── OptionButton
    ├── HSeparator
    ├── Label ("POST-PROCESSING")
    ├── CheckBox (Film Grain)
    ├── HBoxContainer (Film Grain Intensity)
    │   ├── Label
    │   ├── HSlider
    │   └── Label (percentage)
    ├── CheckBox (Outline)
    ├── HBoxContainer (Outline Thickness)
    │   ├── Label
    │   └── OptionButton (1-5px)
    ├── CheckBox (Dither)
    ├── HBoxContainer (Dither Pattern)
    │   ├── Label
    │   └── OptionButton (bayer/noise)
    ├── CheckBox (LUT)
    ├── HBoxContainer (LUT File)
    │   ├── Label
    │   └── OptionButton
    ├── HSeparator
    ├── Label ("UI SCALE")
    ├── HBoxContainer
    │   ├── Label
    │   ├── HSlider (0.5-2.0)
    │   └── Label (scale value)
```

**Auto-Save Pattern**: Immediate Redux dispatch on change (no Apply button)

---

### Commit 2: Accessibility Settings Section

**Files to modify**:
- Existing accessibility settings tab (add color blind options)

**Scene Additions**:
```
├── Label ("COLOR VISION")
├── HBoxContainer (Color Mode)
│   ├── Label
│   └── OptionButton (normal/deuteranopia/protanopia/tritanopia)
├── CheckBox (High Contrast)
├── CheckBox (Color Blind Shader Filter)
```

---

## Phase 7: Integration Testing (Day 18+)

### Integration Tests

**Files to create**:
- `tests/integration/display/test_display_settings.gd` (15 tests)
- `tests/integration/display/test_post_processing.gd` (10 tests)
- `tests/integration/display/test_color_blind_palettes.gd` (5 tests)

**Test Categories**:
- Window mode changes apply to DisplayServer
- Quality presets update rendering settings
- Post-processing effects enable/disable correctly
- UI scale affects CanvasLayer transforms
- Color blind palettes load and emit signals
- Settings persist across save/load

---

## Success Criteria

### Phase 0 Complete:
- [ ] All 77 Redux tests pass (11 initial state + 19 actions + 28 reducer + 19 selectors)
- [ ] Display slice registered in M_StateStore as 12th slice
- [ ] Actions registered with U_ActionRegistry
- [ ] No console errors

### Phase 1 Complete:
- [ ] Manager registered with ServiceLocator
- [ ] Settings applied on state change (hash-based optimization working)
- [ ] Preview mode works correctly (flag blocks hash updates)
- [ ] U_DisplayUtils.get_display_manager() works

### Phase 2 Complete:
- [ ] Window size presets resize window correctly
- [ ] Fullscreen/windowed/borderless modes work
- [ ] VSync toggle affects frame timing
- [ ] Quality presets adjust shadow/AA settings

### Phase 3 Complete:
- [ ] Film Grain effect visible when enabled
- [ ] Outline effect draws edges correctly
- [ ] Dither patterns (bayer/noise) distinguishable
- [ ] LUT color grading applies correctly
- [ ] Post-process overlay renders above gameplay (layer 100)

### Phase 4 Complete:
- [ ] UI scale slider affects all UI elements
- [ ] Scale range 0.5x-2.0x works correctly
- [ ] UI remains usable at extreme scales

### Phase 5 Complete:
- [ ] All 5 color blind palettes load correctly
- [ ] Palette switching emits signal
- [ ] U_PaletteManager caches palettes
- [ ] High contrast mode increases visibility

### Phase 6-7 Complete:
- [ ] All ~120 tests pass (90 unit + 30 integration)
- [ ] Settings persist to save files (no transient fields)
- [ ] Settings UI controls work correctly
- [ ] Manual playtest: all effects visually correct

### Phase 8 Complete (Documentation):
- [ ] Continuation prompt created
- [ ] AGENTS.md updated with Display Manager patterns
- [ ] DEV_PITFALLS.md updated if applicable

---

## Common Pitfalls

1. **DisplayServer Thread Safety**: Window operations must run on main thread
   ```gdscript
   call_deferred("apply_window_size_preset", preset)
   ```

2. **Post-Process Layer Order**: CanvasLayer must be above gameplay but below UI overlays
   - Solution: Use layer 100 for post-process, higher for UI overlays

3. **UI Scale Transform Origin**: Scaling from wrong origin causes offset
   - Solution: Set transform origin to top-left before scaling

4. **Color Hex Parsing**: Invalid hex strings crash
   - Solution: Validate hex format before Color.html()

5. **Quality Preset Missing**: Loading nonexistent .tres returns null
   - Solution: Always validate resource exists before use

6. **VSync Mode Persistence**: DisplayServer.VSYNC_ADAPTIVE not available on all platforms
   - Solution: Only use VSYNC_ENABLED/VSYNC_DISABLED

---

## Testing Commands

```bash
# Run display unit tests
tools/run_gut_suite.sh -gdir=res://tests/unit/state -gselect=test_display -ginclude_subdirs=true

# Run display manager tests
tools/run_gut_suite.sh -gdir=res://tests/unit/managers -gselect=test_display -ginclude_subdirs=true

# Run display integration tests
tools/run_gut_suite.sh -gdir=res://tests/integration/display -ginclude_subdirs=true

# Run all tests
tools/run_gut_suite.sh -gdir=res://tests -ginclude_subdirs=true
```

---

## File Structure

```
scripts/interfaces/
  i_display_manager.gd              # Interface for testability

scripts/managers/
  m_display_manager.gd              # Extends I_DisplayManager

scripts/managers/helpers/
  u_post_process_layer.gd           # CanvasLayer effect manager
  u_palette_manager.gd              # Color blind palette loading

scripts/utils/display/
  u_display_utils.gd                # Display manager lookup helper

scripts/resources/state/
  rs_display_initial_state.gd       # Initial state resource

scripts/resources/display/
  rs_quality_preset.gd              # Quality preset resource class
  rs_lut_definition.gd              # LUT definition resource class

scripts/resources/ui/
  rs_ui_color_palette.gd            # Color palette resource class

scripts/state/actions/
  u_display_actions.gd              # 19 action creators

scripts/state/reducers/
  u_display_reducer.gd              # Reducer with validation

scripts/state/selectors/
  u_display_selectors.gd            # 19 selectors

scripts/ui/settings/
  ui_display_settings_tab.gd        # Settings UI controller

assets/shaders/
  sh_film_grain_shader.gdshader
  sh_outline_shader.gdshader
  sh_dither_shader.gdshader
  sh_lut_shader.gdshader
  sh_colorblind_daltonize.gdshader

resources/base_settings/state/
  cfg_display_initial_state.tres    # Default display settings instance

resources/display/cfg_quality_presets/
  cfg_quality_low.tres
  cfg_quality_medium.tres
  cfg_quality_high.tres
  cfg_quality_ultra.tres

resources/ui_themes/
  cfg_palette_normal.tres           # Instances only (class in scripts/)
  cfg_palette_deuteranopia.tres
  cfg_palette_protanopia.tres
  cfg_palette_tritanopia.tres
  cfg_palette_high_contrast.tres

resources/luts/
  cfg_lut_neutral.tres
  cfg_lut_warm.tres
  cfg_lut_cool.tres
  tex_lut_neutral.png
  tex_lut_warm.png
  tex_lut_cool.png

resources/textures/
  tex_bayer_8x8.png                  # Bayer dither pattern

scenes/ui/overlays/
  ui_post_process_overlay.tscn      # CanvasLayer with effect ColorRects (layer 100)
  ui_display_settings_tab.tscn      # Display settings tab (matches audio pattern)

docs/display_manager/
  display-manager-overview.md
  display-manager-plan.md
  display-manager-tasks.md
  display-manager-continuation-prompt.md  # Created during implementation

tests/unit/
  state/
    test_display_initial_state.gd   # 11 tests
    test_display_actions.gd         # 19 tests
    test_display_reducer.gd         # 28 tests
    test_display_selectors.gd       # 19 tests
  managers/
    test_display_manager.gd         # 11 tests
    helpers/
      test_post_process_layer.gd    # 8 tests
      test_palette_manager.gd       # 8 tests
  resources/
    test_ui_color_palette.gd        # 5 tests

tests/integration/display/
  test_display_settings.gd          # 15 tests
  test_post_processing.gd           # 10 tests
  test_color_blind_palettes.gd      # 5 tests
```

---

**END OF DISPLAY MANAGER PLAN**
