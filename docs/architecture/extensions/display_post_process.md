# Add Display / Post-Process Preset

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new post-processing preset (e.g., "extreme", "retro")
- A new quality preset (e.g., "ultra_plus")
- A new window size preset
- A new color grading preset for a scene
- A new display setting field

This recipe does **not** cover:

- State slice creation (see `state.md`)
- Manager registration (see `managers.md`)
- vCam effects (see `vcam.md`)

## Governing ADR(s)

- [ADR 0001: Channel Taxonomy](../adr/0001-channel-taxonomy.md)

## Canonical Example

- Post-processing: `resources/display/cfg_post_processing_presets/cfg_post_processing_medium.tres` (`RS_PostProcessingPreset`)
- Quality: `resources/display/cfg_quality_presets/cfg_quality_high.tres` (`RS_QualityPreset`)
- Window size: `resources/display/cfg_window_size_presets/cfg_window_size_1920x1080.tres` (`RS_WindowSizePreset`)
- Color grading: `resources/display/color_gradings/cfg_color_grading_bar.tres` (`RS_SceneColorGrading`)
- Catalog: `scripts/utils/display/u_display_option_catalog.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `M_DisplayManager` | Singleton. Orchestrates all display settings through applier helpers. |
| `U_DisplayOptionCatalog` | Static catalog with `const` preload arrays for presets. |
| `U_PostProcessingPresetValues` | Static preset values with `const` preload arrays. |
| `U_ColorGradingRegistry` | Scene grading registry. `_register_scene_grades()` maps `scene_id` to `RS_SceneColorGrading`. |
| `RS_PostProcessingPreset` | Resource: `film_grain_intensity`, `dither_intensity`, `line_mask_intensity`, `scanline_count`. |
| `RS_QualityPreset` | Resource: `shadow_quality`, `anti_aliasing`, `post_processing_enabled`. |
| `RS_WindowSizePreset` | Resource: `preset_id`, `size`, `label`, `sort_order`. |
| `RS_SceneColorGrading` | Resource: 13 artistic parameters + `filter_preset` (8 named filters) + `to_dictionary()`. |

Resource instances: `cfg_` prefix. Script classes: `RS_` prefix. Actions: `display/` prefix (persisted). Color grading actions: `color_grading/` prefix (NOT persisted).

## Recipe

### Adding a new post-processing preset

1. Create `RS_PostProcessingPreset` `.tres` under `resources/display/cfg_post_processing_presets/cfg_post_processing_<name>.tres`. Set `preset_name`, `display_name`, `sort_order`, intensity fields.
2. Add `preload()` to `U_PostProcessingPresetValues._PRESET_RESOURCES`.

### Adding a new quality preset

1. Create `RS_QualityPreset` `.tres` under `resources/display/cfg_quality_presets/cfg_quality_<name>.tres`. Set fields.
2. Add `preload()` to `U_DisplayOptionCatalog.QUALITY_PRESETS`.

### Adding a new window size preset

1. Create `RS_WindowSizePreset` `.tres` under `resources/display/cfg_window_size_presets/cfg_window_size_<W>x<H>.tres`. Set `preset_id`, `size`, `label`, `sort_order`.
2. Add `preload()` to `U_DisplayOptionCatalog.WINDOW_SIZE_PRESETS`.

### Adding a new color grading preset

1. Create `RS_SceneColorGrading` `.tres` under `resources/display/color_gradings/cfg_color_grading_<scene_id>.tres`. Set `scene_id`, `filter_preset`, artistic parameters.
2. Add `preload()` + `_scene_grades[StringName("scene_id")] = resource` to `U_ColorGradingRegistry._register_scene_grades()`.
3. Scene transition flow (`scene/swapped`) automatically picks up the new grading.

### Adding a new display setting field

1. Add `@export` to `RS_DisplayInitialState` + `to_dictionary()`.
2. Add action constant + creator to `U_DisplayActions` (register in `_static_init`). Use `display/` prefix for persisted, other prefixes for non-persisted.
3. Handle in `U_DisplayReducer.reduce()`.
4. Add selector to `U_DisplaySelectors`.
5. If new prefix, update `u_global_settings_serialization.gd` in 4 places.

## Anti-patterns

- **Calling `DisplayServer` methods without Redux dispatch**: Breaks state sync.
- **Applying settings without checking hash**: Redundant GPU/CPU work.
- **Modifying display state during preview mode**: Preview state is temporary.
- **Window operations off main thread**: Not thread-safe.
- **Creating post-process overlay per scene**: Must be singleton in `root.tscn`.
- **Layer 100+ for UI overlays**: Conflicts with post-process layer.
- **`ColorRect.new()` outside `U_PostProcessPipeline`**: Delegate to the pipeline.

## Out Of Scope

- vCam effects: see `vcam.md`
- State slice: see `state.md`
- Manager registration: see `managers.md`

## References

- [Display Manager Overview](../../systems/display_manager/display-manager-overview.md)