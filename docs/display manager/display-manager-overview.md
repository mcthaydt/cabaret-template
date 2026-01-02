# Display Manager Overview

**Project**: Cabaret Template (Godot 4.5)
**Created**: 2026-01-02
**Status**: DEFERRED (Future Enhancement)
**Scope**: Post-processing effects, graphics quality settings, WorldEnvironment

## Summary

The Display Manager is a **future enhancement** that will handle visual post-processing effects and graphics quality settings. This scope has been explicitly deferred from the VFX Manager and Audio Manager implementations.

## Deferred from VFX Manager

The following features were originally considered for VFX Manager but deferred to Display Manager:

- **Post-processing effects**:
  - Film grain
  - CRT scanline effect
  - Lomo vignette (persistent, not damage flash)
  - Bloom / glow
  - Color grading / LUT application

- **Graphics quality settings**:
  - Resolution scaling
  - Fullscreen / windowed mode
  - VSync toggle
  - Quality presets (Low, Medium, High, Ultra)
  - Shadow quality
  - Anti-aliasing (MSAA, FXAA, TAA)

## Responsibilities (When Implemented)

**Display Manager will own**:
- WorldEnvironment configuration
- Post-processing effect toggles and parameters
- Graphics quality presets
- Resolution and display mode settings
- Shader-based visual effects (persistent, not gameplay-triggered)

**Display Manager will depend on**:
- Redux state (`display` slice) for settings
- M_StateStore for persistence
- Godot's rendering pipeline (Environment, CameraAttributes)

## Redux State Model (Proposed)

```gdscript
{
    "display": {
        "resolution_scale": 1.0,        // 0.5-2.0
        "fullscreen": false,
        "vsync_enabled": true,
        "quality_preset": "high",       // "low", "medium", "high", "ultra"

        // Post-processing toggles
        "film_grain_enabled": false,
        "crt_effect_enabled": false,
        "bloom_enabled": true,

        // Effect parameters
        "film_grain_intensity": 0.1,
        "bloom_intensity": 0.3,
    }
}
```

## Non-Goals (Still Out of Scope)

- Dynamic time-of-day lighting
- Weather effects (rain, snow, fog)
- Advanced rendering techniques (ray tracing, GI)
- Custom shader authoring UI

## Implementation Priority

**Status**: Low priority - implement after VFX Manager, Audio Manager, and core gameplay features are complete.

**Estimated effort**: 10-12 days (similar scope to VFX Manager)

## Notes

This document serves as a placeholder to capture scope that has been explicitly deferred. When Display Manager implementation begins, create full PRD/Plan/Tasks documents following the established pattern.
