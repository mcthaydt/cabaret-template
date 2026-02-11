# Display Manager Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-01-02
**Updated**: 2026-02-06
**Status**: IMPLEMENTATION (Phase 11 Complete)
**Scope**: Stacking Post-Processing, Display/Graphics Settings, UI Scaling, Color Blind Accessibility, Cinema Grading

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

- Provide stacking post-processing effects (Film Grain, Dither, CRT) via CanvasLayer + shader.
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
- Screen shake or damage flash (owned by VFX Manager).

## Responsibilities & Boundaries

**Display Manager owns**

- Post-processing effect overlay (CanvasLayer + ColorRect + shader).
- Post-processing effect stack (Film Grain, Dither, CRT, optional color blind filter).
- Per-scene cinema grading (CinemaGradeLayer at layer 1, below post-process effects).
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
U_DisplaySelectors.is_crt_enabled(state: Dictionary) -> bool
U_DisplaySelectors.get_crt_scanline_intensity(state: Dictionary) -> float
U_DisplaySelectors.get_crt_curvature(state: Dictionary) -> float
U_DisplaySelectors.get_crt_chromatic_aberration(state: Dictionary) -> float
U_DisplaySelectors.is_dither_enabled(state: Dictionary) -> bool
U_DisplaySelectors.get_dither_intensity(state: Dictionary) -> float
U_DisplaySelectors.get_dither_pattern(state: Dictionary) -> String
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
        "crt_enabled": false,
        "crt_scanline_intensity": 0.3,
        "crt_curvature": 2.0,
        "crt_chromatic_aberration": 0.002,
        "dither_enabled": false,
        "dither_intensity": 0.5,
        "dither_pattern": "bayer",  # "bayer" or "noise"

        # UI
        "ui_scale": 1.0,

        # Accessibility
        "color_blind_mode": "normal",  # normal, deuteranopia, protanopia, tritanopia
        "high_contrast_enabled": false,
        "color_blind_shader_enabled": false,

        # Cinema Grade (transient — loaded per-scene via cinema_grade/ actions, NOT persisted)
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

**Note**: Display settings (with `display/` prefix) persist to `user://global_settings.json` (not save slots). Cinema grade settings (with `cinema_grade/` prefix) are transient and NOT persisted.

## Cinema Grading System (Phase 11)

### Overview

Per-scene artistic color grading as an additional post-process layer, separate from user-facing display settings. Each gameplay scene defines its look via a `RS_SceneCinemaGrade` resource, loaded automatically on scene transitions.

### Architecture

- **Shader**: `sh_cinema_grade_shader.gdshader` — single GLSL shader with 13 adjustment uniforms + 8 named filters
- **Resource**: `RS_SceneCinemaGrade` — @export properties for each parameter + `to_dictionary()`
- **Registry**: `U_CinemaGradeRegistry` — maps scene_id → resource using const preload arrays (mobile-safe)
- **Applier**: `U_DisplayCinemaGradeApplier` — creates CinemaGradeLayer (CanvasLayer 1) inside PostProcessOverlay
- **Redux**: `cinema_grade/` action prefix stored in display slice but NOT persisted (not a user setting)
- **Preview**: `U_CinemaGradePreview` — @tool node for editor viewport preview, auto-removes at runtime

### Layer Stack

| Layer | Effect | Description |
|-------|--------|-------------|
| 1 | CinemaGradeLayer | Per-scene artistic grading (always active) |
| 2 | FilmGrainLayer | User-toggled film grain |
| 3 | DitherLayer | User-toggled dither |
| 4 | CRTLayer | User-toggled CRT filter |
| 5 | ColorBlindLayer | Color blind simulation |
| 11 | UIColorBlindLayer | UI-only color blind filter |

### Scene Transition Flow

1. `action_dispatched` fires with `scene/transition_completed`
2. Applier extracts `scene_id` from payload
3. Looks up `U_CinemaGradeRegistry.get_cinema_grade_for_scene(scene_id)`
4. Dispatches `U_CinemaGradeActions.load_scene_grade(grade.to_dictionary())`
5. Display slice updates → `_on_slice_updated` → `_apply_display_settings` → `_apply_cinema_grade_settings`

### Adjustments

| Parameter | Range | Description |
|-----------|-------|-------------|
| exposure | -3.0 to 3.0 | EV stops |
| brightness | -1.0 to 1.0 | Linear brightness shift |
| contrast | 0.0 to 3.0 | Midpoint contrast |
| highlights | -1.0 to 1.0 | Bright region adjustment |
| shadows | -1.0 to 1.0 | Dark region adjustment |
| saturation | 0.0 to 3.0 | Global saturation |
| vibrance | -1.0 to 1.0 | Selective saturation |
| brilliance | -1.0 to 1.0 | Inverse-luminance adaptive lift |
| warmth | -1.0 to 1.0 | White balance warm/cool |
| tint | -1.0 to 1.0 | Green/magenta tint |
| sharpness | 0.0 to 2.0 | Unsharp mask |

### Named Filters

| Filter | filter_mode | Description |
|--------|-------------|-------------|
| None | 0 | No filter |
| Dramatic | 1 | High contrast, pulled highlights, lifted shadows, slight desaturation |
| Dramatic Warm | 2 | Dramatic + warm tones |
| Dramatic Cold | 3 | Dramatic + cool tones |
| Vivid | 4 | Boosted saturation + contrast |
| Vivid Warm | 5 | Vivid + warm tones |
| Vivid Cold | 6 | Vivid + cool tones |
| Black & White | 7 | Full desaturation + contrast boost |
| Sepia | 8 | Desaturated with sepia toning |

### Key Design Decisions

- Cinema grading is **independent of `post_processing_enabled`** — always active as artistic direction
- `cinema_grade/` prefix does NOT match `begins_with("display/")` — **not persisted** to global_settings.json
- Per-scene grades are transient (loaded from resource on each scene enter)
- CinemaGradeLayer at layer 1 (below user post-process effects) — grading applied first, stylistic effects on top

---

## Post-Processing System (CanvasLayer + Shader)

### Architecture

The Display Manager uses a CanvasLayer + ColorRect + shader approach for layered post-processing effects (similar to damage flash). Each effect is a ColorRect child of the post-process overlay with its own shader material. The overlay is managed by `U_PostProcessLayer` helper.

### Effect Stack

Effects execute in a fixed internal order (Film Grain → Dither → CRT → Color Blind). The order is not user-configurable:

| Effect | Toggle | Parameters | Description |
|--------|--------|------------|-------------|
| Film Grain | `film_grain_enabled` | `intensity` (0.0-1.0) | Noise overlay for cinematic look |
| Dither | `dither_enabled` | `intensity` (0.0-1.0), `pattern` (bayer/noise) | Ordered or noise dithering |
| CRT | `crt_enabled` | `scanline_intensity` (0.0-1.0), `curvature` (0.0-10.0), `chromatic_aberration` (0.0-0.01) | Scanlines, curvature, and chromatic aberration |

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

- Global scale factor: 0.8x - 1.3x (step 0.1, font-only)
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
- Applied via additional ColorRect in post-process overlay (after CRT in stack)
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

scripts/managers/helpers/display/
  u_cinema_grade_registry.gd        # Scene→grade mapping (mobile-safe)
  u_display_cinema_grade_applier.gd # Cinema grade applier (CanvasLayer 1)

scripts/resources/state/
  rs_display_initial_state.gd       # Initial state resource

scripts/resources/display/
  rs_quality_preset.gd              # Quality preset resource class
  rs_scene_cinema_grade.gd          # Per-scene cinema grade config (Phase 11)

scripts/resources/ui/
  rs_ui_color_palette.gd            # Color palette resource class

scripts/state/actions/
  u_display_actions.gd
  u_cinema_grade_actions.gd         # cinema_grade/ prefix (not persisted) (Phase 11)

scripts/state/reducers/
  u_display_reducer.gd              # Also handles cinema_grade/ actions (Phase 11)

scripts/state/selectors/
  u_display_selectors.gd
  u_cinema_grade_selectors.gd       # Cinema grade parameter selectors (Phase 11)

assets/shaders/
  sh_cinema_grade_shader.gdshader   # Per-scene cinema grading (Phase 11)
  sh_film_grain_shader.gdshader
  sh_crt_shader.gdshader
  sh_dither_shader.gdshader
  sh_colorblind_daltonize.gdshader

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

resources/display/cinema_grades/
  cfg_cinema_grade_gameplay_base.tres  # Per-scene configs (Phase 11)
  cfg_cinema_grade_alleyway.tres
  cfg_cinema_grade_exterior.tres
  cfg_cinema_grade_bar.tres
  cfg_cinema_grade_interior_house.tres

resources/textures/
  tex_bayer_8x8.png

scripts/utils/display/
  u_cinema_grade_preview.gd         # @tool editor preview (Phase 11)

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
│ [✓] Dither                          │
│     Pattern    [▼ Bayer          ]  │
│ [✓] CRT                             │
│     Scanlines  [█████░░░░] 30%      │
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
store.dispatch(U_DisplayActions.set_dither_enabled(true))
store.dispatch(U_DisplayActions.set_dither_pattern("bayer"))
store.dispatch(U_DisplayActions.set_crt_enabled(true))
store.dispatch(U_DisplayActions.set_crt_scanline_intensity(0.3))
store.dispatch(U_DisplayActions.set_crt_curvature(2.0))
store.dispatch(U_DisplayActions.set_crt_chromatic_aberration(0.002))
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
  - Dither: ~0.1ms
  - CRT: ~0.5ms (scanlines + curvature)
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
- No transient fields - display settings persist to `user://global_settings.json` (not save slots)
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
- UI scale slider affects font sizes only (layout is unchanged).
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
| UI scale range | 0.8x - 1.3x with 0.1 step |
| Quality preset levels | Low, Medium, High, Ultra |
| Settings persistence | Included in display slice, persisted to `user://global_settings.json` |
| Dither patterns | "bayer" (ordered) and "noise" (random) options |
