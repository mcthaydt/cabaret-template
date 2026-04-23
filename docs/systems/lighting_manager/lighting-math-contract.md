# Character Lighting Math Contract

## Scope

This contract defines the runtime math and stability rules for character-zone lighting in Phase 8.
It is the authoritative reference for blending behavior used by:

- `res://scripts/utils/lighting/u_character_lighting_blend_math.gd`
- `res://scripts/managers/m_character_lighting_manager.gd`
- `res://scripts/gameplay/inter_character_light_zone.gd`

## Value Ranges and Clamp Rules

### Profile values (`RS_CharacterLightingProfile`)

- `tint`: `Color` value, preserved as authored.
- `intensity`: clamped to `[0.0, 8.0]`.
- `blend_smoothing`: clamped to `[0.0, 1.0]`.

### Zone values (`RS_CharacterLightZoneConfig`)

- `blend_weight`: clamped to `[0.0, 1.0]`.
- `falloff`: clamped to `[0.0, 1.0]`.
- `box_size` components: clamped to `>= 0.01`.
- `cylinder_radius`: clamped to `>= 0.01`.
- `cylinder_height`: clamped to `>= 0.01`.

### Runtime influence values

- Raw zone influence is clamped to `[0.0, 1.0]` before blending.
- Zone enter threshold (hysteresis): `0.02`.
- Zone exit threshold (hysteresis): `0.01`.

## Deterministic Blending Order

Zone sources are sorted with this stable ordering:

1. `priority` descending
2. `weight` descending
3. `zone_id` ascending (string compare)

This order is deterministic for identical inputs across frames and independent of zone discovery order.

## Blend Equations

Given validated zone sources `S` and fallback profile `D`:

- `zone_weight_total = sum(source.weight for source in S)`
- `default_weight = clamp(1.0 - zone_weight_total, 0.0, 1.0)`
- `total_weight = zone_weight_total + default_weight`

If `S` is empty or `total_weight <= 0.0`, return sanitized fallback profile.

Otherwise, normalized weights are:

- `w_default = default_weight / total_weight`
- `w_i = source_i.weight / total_weight`

Outputs:

- `tint = D.tint * w_default + sum(source_i.tint * w_i)`
- `intensity = clamp(D.intensity * w_default + sum(source_i.intensity * w_i), 0.0, 8.0)`
- `blend_smoothing = clamp(D.blend_smoothing * w_default + sum(source_i.blend_smoothing * w_i), 0.0, 1.0)`

## Boundary Stability Rules (Phase 8)

### 1) Per-zone hysteresis

For each `(character, zone_key)` pair:

- If previously inactive, zone becomes active only when `influence >= 0.02`.
- If previously active, zone remains active until `influence < 0.01`.

This deadband reduces edge flicker from tiny boundary oscillations.

### 2) Per-character temporal smoothing

After blend output is computed, each character applies temporal smoothing:

- `alpha = clamp(1.0 - blend_smoothing, 0.0, 1.0)`
- `smoothed_tint = lerp(previous_tint, target_tint, alpha)`
- `smoothed_intensity = lerp(previous_intensity, target_intensity, alpha)`

Special cases:

- First frame for a character uses target values directly (no history penalty).
- Runtime smoothing history and hysteresis state are cleared when:
  - lighting is disabled,
  - transition gating blocks lighting,
  - scene bindings are explicitly refreshed.

## Fallback and Safety Rules

- Missing/invalid zone metadata or profile data is skipped safely.
- Missing scene defaults fall back to sanitized white profile:
  - `tint = (1,1,1,1)`
  - `intensity = 1.0`
  - `blend_smoothing = 0.15`
- Invalid/non-3D character targets restore original materials and are excluded from active lighting.

## Validation Coverage

Contract coverage is enforced by:

- Unit: `res://tests/unit/lighting/test_character_lighting_blend_math.gd`
- Unit: `res://tests/unit/managers/test_character_lighting_manager.gd`
- Integration: `res://tests/integration/lighting/test_character_zone_lighting_flow.gd`
