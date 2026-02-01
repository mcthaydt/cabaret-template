# Display Manager Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-01-02
**Updated**: 2026-01-31
**Status**: PLANNING
**Scope**: Stacking Post-Processing, Display/Graphics Settings, UI Scaling, Color Blind Accessibility

## Summary

The Display Manager handles visual post-processing effects, graphics quality settings, UI scaling, and color blind accessibility features. It owns the post-processing overlay (CanvasLayer + shader) and provides preview APIs for settings UI.

## Repo Reality Checks

- Main scene is `scenes/root.tscn` (there is no `scenes/main.tscn` in this repo).
- Service registration is bootstrapped by `scripts/root.gd` using `U_ServiceLocator` (`res://scripts/core/u_service_locator.gd`).
- WorldEnvironment node exists in gameplay scenes; Display Manager uses separate post-processing overlay.
- Viewport is fixed 960x600 internal resolution; window size presets scale output only.
- Color blind palettes use Theme Resources (`RS_UIColorPalette`), not runtime shader-based recoloring.
- Post-processing uses CanvasLayer + ColorRect + shader approach (like damage flash), not Compositor.

## Goals

- Provide stacking post-processing effects (Film Grain, Outline, Dither, LUT) via CanvasLayer + shader.
- Manage display/graphics settings (window size, fullscreen, VSync, quality presets).
- Apply global UI scaling to CanvasLayer roots.
- Support color blind accessibility via UI palette modes and optional full-screen shader filters.
- Expose display toggles and parameters via Redux state for settings UI.
- Provide preview APIs for settings UI (`set_display_settings_preview()` / `clear_display_settings_preview()`).

## Non-Goals

- Dynamic time-of-day lighting.
- Weather effects.
- Ray tracing / advanced GI.
- Custom shader authoring UI.
- Per-scene post-processing overrides (all scenes use global settings).
- Screen shake or damage flash (owned by VFX Manager).

## Responsibilities & Boundaries

**Display Manager owns**

- Post-processing effect overlay (CanvasLayer + ColorRect + shader).
- Post-processing effect stack (Film Grain, Outline, Dither, LUT).
- Graphics settings application (window mode, VSync, quality presets).
- UI scaling factor application to CanvasLayer roots.
- Color blind palette loading and application.
- Display-related Redux slice subscription for settings changes.

**Display Manager depends on**

- `M_StateStore`: Display settings stored in `display` Redux slice; manager subscribes for changes.
- `U_ServiceLocator`: Registration for discovery by other systems.
- Theme Resources: `RS_UIColorPalette` for color blind palettes.

**Display Manager does NOT own**

- Screen shake, damage flash (VFX Manager).
- Particle effects (ECS particle systems).
- Audio settings (Audio Manager).
- Camera blending (Camera Manager).

## Public API

```gdscript
# Post-processing
M_DisplayManager.set_effect_enabled(effect_name: StringName, enabled: bool) -> void
M_DisplayManager.set_effect_parameter(effect_name: StringName, param: StringName, value: Variant) -> void
M_DisplayManager.get_effect_enabled(effect_name: StringName) -> bool
M_DisplayManager.get_effect_parameter(effect_name: StringName, param: StringName) -> Variant

# Graphics
M_DisplayManager.apply_window_size_preset(preset: String) -> void
M_DisplayManager.set_window_mode(mode: String) -> void  # "fullscreen", "windowed", "borderless"
M_DisplayManager.set_vsync_enabled(enabled: bool) -> void
M_DisplayManager.apply_quality_preset(preset: String) -> void

# UI Scaling
M_DisplayManager.set_ui_scale(scale: float) -> void
M_DisplayManager.get_ui_scale() -> float

# Accessibility
M_DisplayManager.set_color_blind_mode(mode: String) -> void
M_DisplayManager.get_active_palette() -> RS_UIColorPalette

# Settings Preview
M_DisplayManager.set_display_settings_preview(preview: Dictionary) -> void
M_DisplayManager.clear_display_settings_preview() -> void

# Display selectors (query from Redux state)
U_DisplaySelectors.get_window_size_preset(state: Dictionary) -> String
U_DisplaySelectors.get_window_mode(state: Dictionary) -> String
U_DisplaySelectors.is_vsync_enabled(state: Dictionary) -> bool
U_DisplaySelectors.get_quality_preset(state: Dictionary) -> String
U_DisplaySelectors.get_ui_scale(state: Dictionary) -> float
U_DisplaySelectors.get_color_blind_mode(state: Dictionary) -> String
U_DisplaySelectors.is_film_grain_enabled(state: Dictionary) -> bool
U_DisplaySelectors.get_film_grain_intensity(state: Dictionary) -> float
U_DisplaySelectors.is_outline_enabled(state: Dictionary) -> bool
U_DisplaySelectors.get_outline_thickness(state: Dictionary) -> int
U_DisplaySelectors.get_outline_color(state: Dictionary) -> String
U_DisplaySelectors.is_dither_enabled(state: Dictionary) -> bool
U_DisplaySelectors.get_dither_intensity(state: Dictionary) -> float
U_DisplaySelectors.get_dither_pattern(state: Dictionary) -> String
U_DisplaySelectors.is_lut_enabled(state: Dictionary) -> bool
U_DisplaySelectors.get_lut_resource(state: Dictionary) -> String
U_DisplaySelectors.get_lut_intensity(state: Dictionary) -> float
```

## Redux State Model (`display` slice)

```gdscript
{
    "display": {
        # Graphics (viewport always 960x600)
        "window_size_preset": "1920x1080",  # 16:9 presets: 1280x720, 1600x900, 1920x1080, 2560x1440, 3840x2160
        "window_mode": "windowed",  # fullscreen, windowed, borderless
        "vsync_enabled": true,
        "quality_preset": "high",

        # Post-Processing (effect order is fixed internally, not user-configurable)
        "film_grain_enabled": false,
        "film_grain_intensity": 0.1,
        "outline_enabled": false,
        "outline_thickness": 2,
        "outline_color": "000000",  # Hex color string
        "dither_enabled": false,
        "dither_intensity": 0.5,
        "dither_pattern": "bayer",  # "bayer" or "noise"
        "lut_enabled": false,
        "lut_resource": "",
        "lut_intensity": 1.0,

        # UI
        "ui_scale": 1.0,

        # Accessibility
        "color_blind_mode": "normal",  # normal, deuteranopia, protanopia, tritanopia
        "high_contrast_enabled": false,
        "color_blind_shader_enabled": false,
    }
}
```

**Note**: Display settings persist to save files (included in display slice).

## Post-Processing System (CanvasLayer + Shader)

### Architecture

The Display Manager uses a CanvasLayer + ColorRect + shader approach for layered post-processing effects (similar to damage flash). Each effect is a ColorRect child of the post-process overlay with its own shader material. The overlay is managed by `U_PostProcessLayer` helper.

### Effect Stack

Effects execute in a fixed internal order (Film Grain → Outline → Dither → LUT). The order is not user-configurable:

| Effect | Toggle | Parameters | Description |
|--------|--------|------------|-------------|
| Film Grain | `film_grain_enabled` | `intensity` (0.0-1.0) | Noise overlay for cinematic look |
| Outline | `outline_enabled` | `thickness` (1-5px), `color` (hex) | Edge detection sobel filter |
| Dither | `dither_enabled` | `intensity` (0.0-1.0), `pattern` (bayer/noise) | Ordered or noise dithering |
| LUT | `lut_enabled` | `lut_resource` (path), `intensity` (0.0-1.0) | Color grading via lookup table |

## Display/Graphics Settings

### Viewport

Fixed 960x600 internal resolution (always). Window size presets scale the output.

### Desktop Window Size Presets (16:9)

| Preset | Resolution | Notes |
|--------|------------|-------|
| 1280x720 | 720p | Minimum recommended |
| 1600x900 | HD+ | Good balance |
| 1920x1080 | 1080p | Default |
| 2560x1440 | 1440p | High-res displays |
| 3840x2160 | 4K | Maximum |

### Window Mode

| Mode | Description |
|------|-------------|
| `fullscreen` | Exclusive fullscreen |
| `windowed` | Resizable window |
| `borderless` | Borderless windowed |

### Quality Presets

| Preset | Shadows | AA | Post-Processing |
|--------|---------|----|-----------------|
| Low | Off | None | Minimal |
| Medium | Low | FXAA | Standard |
| High | Medium | MSAA 2x | Full |
| Ultra | High | MSAA 4x | Full + enhanced |

## UI Scaling

- Global scale factor: 0.5x - 2.0x (step 0.1)
- Applied to CanvasLayer root nodes via `Control.scale`
- Default: 1.0
- Persisted in display slice
- UI root scenes register via `U_UIScaleRoot` helper node

### Application

```gdscript
func register_ui_scale_root(root: Node) -> void:
    _ui_scale_roots.append(root)
    _apply_ui_scale_to_node(root, _current_ui_scale)

func _apply_ui_scale(scale: float) -> void:
    for root in _ui_scale_roots:
        _apply_ui_scale_to_node(root, scale)
```

## Color Blind Accessibility

### UI Palette Modes (Theme Resources)

Color blind accessibility uses pre-authored Theme Resource palettes rather than runtime shader-based recoloring. This provides precise control over color combinations and ensures accessibility compliance.

**Available Modes**:
- `normal` - Default palette
- `deuteranopia` - Red-green color blindness (most common)
- `protanopia` - Red-green variant
- `tritanopia` - Blue-yellow color blindness
- `high_contrast` - Maximum contrast for low vision

### Theme Resources Architecture

```
scripts/resources/ui/
  rs_ui_color_palette.gd        # Resource class definition

resources/ui_themes/
  cfg_palette_normal.tres       # Default palette
  cfg_palette_deuteranopia.tres
  cfg_palette_protanopia.tres
  cfg_palette_tritanopia.tres
  cfg_palette_high_contrast.tres

scripts/managers/helpers/
  u_palette_manager.gd          # Loads/applies palettes based on Redux state
```

### RS_UIColorPalette Fields

```gdscript
class_name RS_UIColorPalette
extends Resource

@export var palette_id: StringName  # "normal", "deuteranopia", etc.
@export var primary: Color          # Primary UI elements, buttons
@export var secondary: Color        # Secondary elements, borders
@export var success: Color          # Positive states (health, checkpoints)
@export var warning: Color          # Warning states (low health)
@export var danger: Color           # Danger states (hazards, damage)
@export var info: Color             # Informational elements
@export var background: Color       # Panel backgrounds
@export var text: Color             # Text color
```

### Palette Application

```gdscript
# U_PaletteManager loads palette based on Redux state
func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
    if slice_name == &"display":
        var state := _store.get_state()
        var mode: String = U_DisplaySelectors.get_color_blind_mode(state)
        _apply_palette(mode)

func _apply_palette(mode: String) -> void:
    var palette := _load_palette(mode)
    if palette == null:
        push_warning("Unknown color blind mode: %s, falling back to normal" % mode)
        palette = _load_palette("normal")

    # Apply to Theme overrides or emit signal for UI to consume
    active_palette_changed.emit(palette)
```

### Full-Screen Shader Filters

Optional simulation shaders for testing accessibility or user preference:

- `color_blind_shader_enabled`: Toggle for full-screen color filter
- Applied via additional ColorRect in post-process overlay (after LUT in stack)
- Uses daltonization algorithms to simulate color blindness

## File Structure

```
scripts/interfaces/
  i_display_manager.gd              # Interface for testability

scripts/managers/
  m_display_manager.gd              # Extends I_DisplayManager

scripts/managers/helpers/
  u_post_process_layer.gd           # CanvasLayer effect manager
  u_palette_manager.gd              # Color blind palette loading

scripts/resources/state/
  rs_display_initial_state.gd       # Initial state resource

scripts/resources/display/
  rs_quality_preset.gd              # Quality preset resource class
  rs_lut_definition.gd              # LUT definition resource class

scripts/resources/ui/
  rs_ui_color_palette.gd            # Color palette resource class

scripts/state/actions/
  u_display_actions.gd

scripts/state/reducers/
  u_display_reducer.gd

scripts/state/selectors/
  u_display_selectors.gd

assets/shaders/
  sh_film_grain_shader.gdshader
  sh_outline_shader.gdshader
  sh_dither_shader.gdshader
  sh_lut_shader.gdshader

resources/base_settings/state/
  cfg_display_initial_state.tres    # Default display settings instance

resources/display/
  cfg_quality_presets/              # Quality preset configurations
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
  tex_bayer_8x8.png

scenes/ui/overlays/
  ui_post_process_overlay.tscn      # CanvasLayer with effect ColorRects
```

## Settings UI Integration

### Display Section in Settings Panel

Display settings are placed in the "Video" tab:

```
┌─────────────────────────────────────┐
│ DISPLAY                             │
├─────────────────────────────────────┤
│ Window Size    [▼ 1920x1080      ]  │
│ Window Mode    [▼ Windowed       ]  │
│ [✓] VSync                           │
├─────────────────────────────────────┤
│ QUALITY                             │
├─────────────────────────────────────┤
│ Quality Preset [▼ High           ]  │
├─────────────────────────────────────┤
│ POST-PROCESSING                     │
├─────────────────────────────────────┤
│ [✓] Film Grain                      │
│     Intensity  [████████░░] 50%     │
│ [✓] Outline                         │
│     Thickness  [▼ 2px            ]  │
│ [✓] Dither                          │
│     Pattern    [▼ Bayer          ]  │
│ [✓] LUT Color Grading               │
│     LUT File   [▼ Default        ]  │
├─────────────────────────────────────┤
│ UI SCALE                            │
├─────────────────────────────────────┤
│ Scale Factor   [████████░░] 1.0x    │
└─────────────────────────────────────┘
```

### Accessibility Section

Color blind options in "Accessibility" tab:

```
┌─────────────────────────────────────┐
│ COLOR VISION                        │
├─────────────────────────────────────┤
│ Color Mode     [▼ Normal         ]  │
│ [✓] High Contrast                   │
│ [ ] Color Blind Shader Filter       │
└─────────────────────────────────────┘
```

### Redux Actions for Settings

```gdscript
const U_DisplayActions = preload("res://scripts/state/actions/u_display_actions.gd")

# Graphics
store.dispatch(U_DisplayActions.set_window_size_preset("1920x1080"))
store.dispatch(U_DisplayActions.set_window_mode("fullscreen"))
store.dispatch(U_DisplayActions.set_vsync_enabled(true))
store.dispatch(U_DisplayActions.set_quality_preset("high"))

# Post-Processing
store.dispatch(U_DisplayActions.set_film_grain_enabled(true))
store.dispatch(U_DisplayActions.set_film_grain_intensity(0.5))
store.dispatch(U_DisplayActions.set_outline_enabled(true))
store.dispatch(U_DisplayActions.set_outline_thickness(2))
store.dispatch(U_DisplayActions.set_outline_color("000000"))
store.dispatch(U_DisplayActions.set_dither_enabled(true))
store.dispatch(U_DisplayActions.set_dither_pattern("bayer"))
store.dispatch(U_DisplayActions.set_lut_enabled(true))
store.dispatch(U_DisplayActions.set_lut_resource("res://resources/luts/cfg_lut_warm.tres"))
store.dispatch(U_DisplayActions.set_lut_intensity(0.8))
# UI
store.dispatch(U_DisplayActions.set_ui_scale(1.2))

# Accessibility
store.dispatch(U_DisplayActions.set_color_blind_mode("deuteranopia"))
store.dispatch(U_DisplayActions.set_high_contrast_enabled(true))
store.dispatch(U_DisplayActions.set_color_blind_shader_enabled(true))
```

## Performance Budget

### Display Manager

- **CPU**: < 0.05ms per frame for settings application (only on state change)
- **GPU**: Post-processing budget dependent on enabled effects
  - Film Grain: ~0.2ms
  - Outline: ~0.5ms (sobel filter)
  - Dither: ~0.1ms
  - LUT: ~0.1ms
- **Memory**: ~50KB (manager + palettes + effect resources)

### Optimization Guidelines

- Settings only applied on Redux state change (hash-based comparison)
- Post-processing ColorRects hidden (not destroyed) when effects toggled off
- Quality presets batch multiple settings changes into single apply
- Palette switching uses cached resources (no runtime loading)

## Hash-Based Optimization Pattern

M_DisplayManager uses hash comparison to prevent redundant settings application when unrelated slices change:

```gdscript
var _last_display_hash: int = 0
var _display_settings_preview_active: bool = false

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
    # Skip if not display slice or if preview mode is active
    if slice_name != &"display" or _display_settings_preview_active:
        return

    var state := state_store.get_state()
    var display_slice: Dictionary = state.get("display", {})
    var display_hash := display_slice.hash()

    # Only apply if display slice actually changed
    if display_hash != _last_display_hash:
        _apply_display_settings(state)
        _last_display_hash = display_hash
```

## Settings Preview Pattern

M_DisplayManager supports temporary settings overrides for UI preview:

```gdscript
func set_display_settings_preview(preview: Dictionary) -> void:
    _display_settings_preview_active = true  # Blocks hash-based updates
    _preview_settings = preview.duplicate(true)
    _apply_preview_settings()

func clear_display_settings_preview() -> void:
    _display_settings_preview_active = false
    _preview_settings.clear()
    if state_store != null:
        _apply_display_settings(state_store.get_state())
```

**Note:** While preview is active, Redux state changes are ignored. This allows real-time preview in settings UI without persisting changes until confirmed.

## ServiceLocator Integration

M_DisplayManager registers with ServiceLocator on `_ready()`:

```gdscript
func _ready() -> void:
    process_mode = PROCESS_MODE_ALWAYS
    U_ServiceLocator.register(StringName("display_manager"), self)
    _discover_state_store()
```

**Discovery:**
```gdscript
# Get display manager from anywhere
var display_manager := U_DisplayUtils.get_display_manager()
# or
var display_manager := U_ServiceLocator.get_service(StringName("display_manager")) as M_DisplayManager
```

## State Slice Configuration

Display slice in `u_state_slice_manager.gd`:

```gdscript
# Display slice (12th parameter, after audio)
if display_initial_state != null:
    var display_config := RS_StateSliceConfig.new(StringName("display"))
    display_config.reducer = Callable(U_DISPLAY_REDUCER, "reduce")
    display_config.initial_state = display_initial_state.to_dictionary()
    display_config.dependencies = []
    display_config.transient_fields = []  # All settings persist
    register_slice(slice_configs, state, display_config)
```

**Key Points:**
- No transient fields - all display settings persist to save files
- No dependencies on other slices
- Registered as 12th slice (after audio)

## Testing Strategy

### Unit Tests (~90 tests)

- `RS_DisplayInitialState`: Field existence, defaults, to_dictionary() (11 tests)
- `U_DisplayActions`: Action structure for all 19 action types (19 tests)
- `U_DisplayReducer`: Action handling, value clamping, validation, immutability (28 tests)
- `U_DisplaySelectors`: Selector return values, defaults when missing (19 tests)
- `M_DisplayManager`: Lifecycle, hash optimization, preview mode (11 tests)
- `U_PostProcessLayer`: Effect toggling, parameter setting (8 tests)
- `U_PaletteManager`: Mode switching, caching, fallback (8 tests)
- `RS_UIColorPalette`: Resource loading and field validation (5 tests)

### Integration Tests (~30 tests)

- Window mode: Dispatch action -> verify `DisplayServer` state matches (15 tests)
- Post-processing: Enable effect -> verify ColorRect visibility updated (10 tests)
- Color blind mode: Switch mode -> verify palette loaded and applied (5 tests)

### Manual Testing

- Window size presets correctly resize window.
- Fullscreen toggle works on all target platforms.
- VSync toggle affects actual frame timing.
- Each post-processing effect visually distinguishable when enabled.
- UI scale slider affects all UI elements proportionally.
- Each color blind palette provides distinct, accessible colors.
- High contrast mode increases visibility of all UI elements.

## Anti-Patterns

Common mistakes to avoid:

- ❌ Directly calling `DisplayServer` methods without Redux dispatch (breaks state sync)
- ❌ Applying settings without checking hash (causes redundant GPU/CPU work)
- ❌ Modifying display state during preview mode (preview should be temporary)
- ❌ Calling window operations off main thread (use `call_deferred()`)
- ❌ Scaling CanvasLayers without setting transform origin (causes offset issues)
- ❌ Creating post-process overlay per scene (should be singleton in root.tscn)
- ❌ Using layer 100+ for UI overlays (conflicts with post-process layer)

## Resolved Questions

| Question | Decision |
|----------|----------|
| VFX vs Display scope | VFX = gameplay effects (shake, flash); Display = post-processing + settings |
| Color blind implementation | Theme Resources (RS_UIColorPalette) for precise control |
| Post-process architecture | CanvasLayer + ColorRect + shader (not Compositor) |
| Post-process order | Fixed internally (not user-configurable) |
| Shader location | `assets/shaders/` with `sh_` prefix + `_shader` suffix |
| Viewport resolution | Fixed 960x600 internal, window presets scale output |
| UI scale range | 0.5x - 2.0x with 0.1 step |
| Quality preset levels | Low, Medium, High, Ultra |
| Settings persistence | Included in display slice, persisted to save files |
| Outline color format | Hex string (e.g., "000000") for easy serialization |
| Dither patterns | "bayer" (ordered) and "noise" (random) options |
| LUT intensity | 0.0-1.0 for blend between original and graded |
