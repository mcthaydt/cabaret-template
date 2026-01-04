# VFX Manager Overview

**Project**: Cabaret Template (Godot 4.5)
**Created**: 2026-01-01
**Last Updated**: 2026-01-04
**Status**: IMPLEMENTED (Phases 0-5); Phase 6 pending
**Scope**: Screen shake, damage flash, gameplay visual effects (particle systems retained)

## Summary

The VFX Manager is a persistent orchestration layer for screen-level visual effects. It coordinates screen shake (camera trauma), damage flash overlays, and future gameplay screen effects. The manager works alongside existing ECS particle systems (`S_JumpParticlesSystem`, `S_LandingParticlesSystem`, etc.) which remain unchanged. Post-processing effects (film grain, CRT, Lomo) are explicitly out of scope and will be handled by a future Display Manager.

## Repo Reality Checks

- Main scene is `scenes/root.tscn` (there is no `scenes/main.tscn` in this repo).
- Service registration is bootstrapped by `scripts/scene_structure/main.gd` using `U_ServiceLocator` (`res://scripts/core/u_service_locator.gd`).
- `M_CameraManager` supports both camera blending and screen shake via `apply_shake_offset(offset: Vector2, rotation: float)` (active scene camera, or TransitionCamera during blends).
- Tests should use real `U_ECSEventBus` and call `U_ECSEventBus.reset()` in `before_each()` to prevent subscription leaks.
- `LoadingOverlay` in `scenes/root.tscn` uses `layer = 100`; if adding a damage flash overlay scene, pick an explicit layer below it (docs recommend `layer = 50`).

## Goals

- Provide screen shake on damage, heavy landings, and impact events.
- Display damage flash (red vignette) when player takes damage.
- Orchestrate screen-level effects via a central manager.
- Expose VFX toggles and intensity controls via Redux state for settings UI.
- Integrate with existing `M_CameraManager` for camera manipulation.

## Non-Goals

- No post-processing effects (film grain, CRT, Lomo, color grading) - deferred to Display Manager.
- No graphics quality settings (resolution, shadows, AA) - deferred to Display Manager.
- No particle system changes (existing systems work correctly).
- No complex shader effects (distortion, heat haze) for initial implementation.
- No directional damage indicators (future enhancement).

## Responsibilities & Boundaries

**VFX Manager owns**

- Screen shake coordination (trauma accumulation, decay, camera offset).
- Damage flash overlay (vignette fade-in/fade-out).
- VFX-related Redux slice subscription for settings changes.
- Effect layers (CanvasLayer for 2D overlays).

**VFX Manager depends on**

- `M_StateStore`: VFX settings stored in `vfx` Redux slice; manager subscribes for changes.
- `M_CameraManager`: Camera offset application for screen shake.
- `U_ECSEventBus`: Damage/landing events trigger screen effects.
- `U_ServiceLocator`: Registration for discovery by other systems.

**Existing systems (unchanged)**

- `U_ParticleSpawner`: GPU particle spawning utility.
- `BaseEventVFXSystem`: Base class for particle systems.
- `S_JumpParticlesSystem`, `S_LandingParticlesSystem`, `S_SpawnParticlesSystem`: Particle effects.
- `C_LandingIndicatorComponent` + `S_LandingIndicatorSystem`: Landing preview visual.

**Display Manager will own (future)**

- Post-processing: Film grain, Lomo, CRT, bloom, vignette (persistent).
- Graphics settings: Resolution, fullscreen, vsync, quality presets.
- WorldEnvironment configuration.

## Public API

```gdscript
# Screen shake
M_VFXManager.add_trauma(amount: float) -> void  # Adds trauma (0.0-1.0), clamped to max
M_VFXManager.get_trauma() -> float              # Current trauma value

# VFX selectors (query from Redux state)
U_VFXSelectors.is_screen_shake_enabled(state: Dictionary) -> bool
U_VFXSelectors.get_screen_shake_intensity(state: Dictionary) -> float
U_VFXSelectors.is_damage_flash_enabled(state: Dictionary) -> bool
```

## VFX State Model

### Redux Slice: `vfx`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `screen_shake_enabled` | bool | true | Global screen shake toggle |
| `screen_shake_intensity` | float | 1.0 | Shake intensity multiplier (0.0-2.0) |
| `damage_flash_enabled` | bool | true | Damage flash effect toggle |

**Note**: VFX settings persist to save files (included in settings slice).

## Screen Shake System

### Trauma-Based Shake Model

Screen shake uses a "trauma" system inspired by Vlambeer's game feel techniques:

```gdscript
# Trauma accumulates from multiple sources, decays over time
var trauma: float = 0.0  # 0.0 = no shake, 1.0 = maximum shake

func _physics_process(delta: float) -> void:
    if trauma > 0.0:
        trauma = max(trauma - decay_rate * delta, 0.0)
        _apply_shake()
```

### Shake Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `max_offset` | Vector2(10, 8) | Maximum camera offset in pixels |
| `max_rotation` | 0.05 | Maximum rotation in radians |
| `decay_rate` | 2.0 | Trauma decay per second |
| `noise_speed` | 50.0 | FastNoiseLite sample speed |

### Shake Calculation

```gdscript
func _apply_shake() -> void:
    var shake_amount := trauma * trauma  # Quadratic for smooth feel
    var settings_multiplier := U_VFXSelectors.get_screen_shake_intensity(store.get_state())

    if not U_VFXSelectors.is_screen_shake_enabled(store.get_state()):
        return

    var offset := Vector2(
        max_offset.x * shake_amount * _noise.get_noise_1d(time * noise_speed),
        max_offset.y * shake_amount * _noise.get_noise_1d(time * noise_speed + 100.0)
    ) * settings_multiplier

    var rotation := max_rotation * shake_amount * _noise.get_noise_1d(time * noise_speed + 200.0) * settings_multiplier

    _camera_manager.apply_shake_offset(offset, rotation)
```

### Shake Triggers

| Event | Trauma Amount | Description |
|-------|---------------|-------------|
| `health_changed` | 0.3 - 0.6 | Based on damage amount (`previous_health - new_health`) |
| `entity_landed` (heavy) | 0.2 - 0.4 | Based on fall velocity (`abs(vertical_velocity)`) |
| `entity_death` | 0.5 | Death impact |
| Explosion (future) | 0.6 - 0.8 | Area effect |

### Camera Manager Integration

`M_CameraManager` exposes:

```gdscript
func apply_shake_offset(offset: Vector2, rotation: float) -> void
```

Shake is applied to a ShakeParent Node3D above the active camera (or above the TransitionCamera during blends) so shake does not fight camera blending and does not introduce gimbal lock.

## Damage Flash System

### Flash Overlay

A `CanvasLayer` with `ColorRect` that flashes red on damage:

```
CanvasLayer (recommend layer 50 - above gameplay, below `LoadingOverlay.layer = 100` in `scenes/root.tscn`)
└── ColorRect (full screen, red with alpha)
    └── AnimationPlayer or Tween for fade
```

### Flash Behavior

1. Damage event triggers `trigger_damage_flash(intensity)`.
2. Overlay alpha jumps to `0.3 * intensity` (immediate).
3. Overlay fades to 0 over 0.4 seconds.
4. Multiple damage events restart the flash (no stacking).

### Flash Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `flash_color` | Color(1, 0, 0, 0.3) | Red with 30% alpha |
| `fade_duration` | 0.4 | Seconds to fade out |
| `max_alpha` | 0.4 | Maximum overlay alpha |

### Flash Implementation

```gdscript
class_name M_DamageFlash
extends CanvasLayer

@onready var _overlay: ColorRect = $ColorRect
var _tween: Tween

func trigger(intensity: float = 1.0) -> void:
    if not U_VFXSelectors.is_damage_flash_enabled(_get_state()):
        return

    if _tween:
        _tween.kill()

    var target_alpha := clamp(max_alpha * intensity, 0.0, max_alpha)
    _overlay.modulate.a = target_alpha

    _tween = create_tween()
    _tween.tween_property(_overlay, "modulate:a", 0.0, fade_duration)
```

## Event Integration

### ECS Event Subscriptions

```gdscript
# In M_VFXManager._ready():
func _ready() -> void:
    # Subscribe to ECS events (static methods)
    _event_unsubscribes.append(
        U_ECSEventBus.subscribe(StringName("health_changed"), _on_health_changed)
    )
    _event_unsubscribes.append(
        U_ECSEventBus.subscribe(StringName("entity_landed"), _on_landed)
    )
    _event_unsubscribes.append(
        U_ECSEventBus.subscribe(StringName("entity_death"), _on_death)
    )

    # Redux subscription for settings
    if _state_store != null:
        _state_store.slice_updated.connect(_on_slice_updated)

func _on_health_changed(event: Dictionary) -> void:
    var payload: Dictionary = event.get("payload", {})
    var previous_health: float = payload.get("previous_health", 0.0)
    var new_health: float = payload.get("new_health", 0.0)
    var damage_amount: float = previous_health - new_health

    if damage_amount > 0.0:  # Only trigger on damage, not healing
        var trauma := remap(damage_amount, 0.0, 100.0, 0.3, 0.6)
        add_trauma(trauma)
        trigger_damage_flash(clamp(damage_amount / 50.0, 0.5, 1.0))

func _on_landed(event: Dictionary) -> void:
    var payload: Dictionary = event.get("payload", {})
    var fall_speed: float = abs(payload.get("vertical_velocity", 0.0))
    if fall_speed > 15.0:  # Heavy landing threshold
        var trauma := remap(fall_speed, 15.0, 40.0, 0.2, 0.4)
        add_trauma(trauma)

func _on_death(_event: Dictionary) -> void:
    add_trauma(0.5)
    trigger_damage_flash(1.0)
```

## File Structure

```
scripts/managers/
  m_vfx_manager.gd

scripts/managers/helpers/
  u_screen_shake.gd
  u_damage_flash.gd

scripts/state/
  resources/rs_vfx_initial_state.gd
  actions/u_vfx_actions.gd
  reducers/u_vfx_reducer.gd
  selectors/u_vfx_selectors.gd

scenes/ui/
  ui_damage_flash_overlay.tscn
```

## Settings UI Integration

### VFX Section in Settings Panel

VFX settings are placed in the "Accessibility" tab (along with Audio settings):

```
┌─────────────────────────────────────┐
│ VISUAL EFFECTS                      │
├─────────────────────────────────────┤
│ [✓] Screen Shake                    │
│     Intensity  [████████░░] 80%     │
├─────────────────────────────────────┤
│ [✓] Damage Flash                    │
└─────────────────────────────────────┘
```

### Redux Actions for Settings

```gdscript
const U_VFXActions = preload("res://scripts/state/actions/u_vfx_actions.gd")

# Toggle screen shake
store.dispatch(U_VFXActions.set_screen_shake_enabled(true))
store.dispatch(U_VFXActions.set_screen_shake_intensity(0.8))

# Toggle damage flash
store.dispatch(U_VFXActions.set_damage_flash_enabled(true))
```

## Accessibility Considerations

### Screen Shake

- Toggle allows complete disable for motion sensitivity.
- Intensity slider allows reducing shake without fully disabling.
- Default intensity is 1.0 (100%).

### Damage Flash

- Toggle allows complete disable for photosensitivity.
- Flash is brief (0.4s) and semi-transparent (30% alpha).
- No rapid flashing (new damage resets, doesn't stack).

## Performance Budget

### VFX Manager

- **CPU**: < 0.1ms per frame for shake + flash (measured on target hardware)
- **Memory**: ~10KB total (manager + helpers)
- **Trauma decay**: Runs only when trauma > 0.0 (idle = zero overhead)
- **Flash overlay**: CanvasModulate modulates entire scene (minimal cost)

### Profiling

Use Godot Profiler (Debugger > Profiler) to measure actual overhead:
- Monitor "Script Functions" category for M_VFXManager processing
- Check frame time doesn't spike > 0.1ms during shake
- Verify trauma decay doesn't trigger every frame when trauma = 0.0

### Optimization Guidelines

- Trauma decay early-exits when `trauma <= 0.0` (no wasted CPU)
- Shake offset applied directly to camera parent (no scene tree traversal)
- Flash uses single CanvasModulate node (hardware-accelerated)
- All calculations use cached noise values (no per-frame random generation)

## Testing Strategy

### Unit Tests

- `U_VFXReducer`: Action handling, intensity clamping, toggle state.
- `U_VFXSelectors`: Selector return values for all settings.
- `U_ScreenShake`: Trauma accumulation, decay, noise sampling.
- `M_DamageFlash`: Trigger, fade animation, settings respect.

### Integration Tests

- Screen shake: Dispatch damage action -> verify camera offset applied.
- Damage flash: Dispatch damage action -> verify overlay visible then fades.
- Settings toggle: Disable shake -> dispatch damage -> verify no camera movement.
- Multiple trauma: Add multiple trauma sources -> verify clamped to 1.0.

### Manual Testing

- Screen shake intensity slider visibly affects shake magnitude.
- Disabling screen shake completely stops all camera shake.
- Damage flash appears on hit and fades smoothly.
- Heavy landings trigger appropriate shake.
- Death triggers both shake and flash.

## Asset Requirements

### Camera Shake

No external assets required - shake is purely code-driven using trauma-based noise and spring physics.

### Damage Flash

No external assets required - flash uses `CanvasModulate` node with color interpolation (red tint).

### Future Placeholder Needs

If implementing additional VFX features (particles, textures, shaders):
- Particle textures: Use Godot's built-in white circle particle
- Custom shaders: Start with simple color multiplication
- Test assets: Keep under 10KB each, commit to `resources/vfx/`

## Resolved Questions

| Question | Decision |
|----------|----------|
| Shake vs post-processing scope | VFX = gameplay effects (shake, flash); Display = post-processing |
| Trauma model | Quadratic falloff (trauma^2) for smooth feel |
| Shake noise type | Perlin noise for organic feel (not random jitter) |
| Flash stacking | No stack - new damage restarts flash animation |
| Heavy landing threshold | 15 units/sec fall velocity triggers shake |
| Intensity slider range | 0.0-2.0 (can amplify beyond default) |
| Camera offset application | Via M_CameraManager helper method (use a parent node to prevent gimbal lock) |
| Flash layer order | Explicit CanvasLayer layer (docs recommend 50; keep below `LoadingOverlay.layer = 100` in `scenes/root.tscn`) |
| Settings persistence | Included in settings slice, persisted to save files |
| Accessibility defaults | Both effects enabled by default, easy to disable |
