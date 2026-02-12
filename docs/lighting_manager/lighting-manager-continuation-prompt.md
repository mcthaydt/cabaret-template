# Lighting Manager - Continuation Prompt

## Current Status (2026-02-12)

- **Status:** Phase 1 complete (resource + blend math foundations implemented and tested).
- **Task Checklist:** `docs/lighting_manager/lighting-manager-tasks.md`
- **Next Phase:** Phase 2 (Zone Controller Authoring Pattern)
- **Tests Run This Phase:**
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/lighting` (PASS, 10 tests)
  - `tools/run_gut_suite.sh -gdir=res://tests/unit/style` (PASS, 12 tests)
- **Manual QA:** Not started

## Locked Implementation Decisions

- Full unlit character shading (character does not respond to physical `Light3D`).
- Dedicated zone authoring via `Inter_CharacterLightZone`.
- Runtime source of truth is scene resources (no Redux slice in phase 1).
- Manager targets all gameplay actors tagged `character` (player + NPCs + enemies/companions).
- Non-character proxies/dummies should not use the `character` tag.
- Zone overlap uses weighted blend with priority.
- Zone overlap behavior must be deterministic (stable ordering/tie-break rules) and resistant to boundary jitter.
- Outside zones uses scene default profile.
- Existing mood/objective/signpost physical lights are replaced with zones, using those light values as migration references.

## Planned Public API / Types

- `scripts/interfaces/i_character_lighting_manager.gd` (runtime behavior only; no debug methods)
- `scripts/managers/m_character_lighting_manager.gd`
- `scripts/gameplay/inter_character_light_zone.gd`
- `scripts/resources/lighting/rs_character_lighting_profile.gd`
- `scripts/resources/lighting/rs_character_light_zone_config.gd`
- `assets/shaders/sh_character_zone_lighting.gdshader`

## Required Readings Before Coding

- `AGENTS.md`
- `docs/general/DEV_PITFALLS.md`
- `docs/general/STYLE_GUIDE.md`
- `docs/lighting_manager/lighting-manager-tasks.md`

## Execution Rules (Non-Negotiable)

1. Work from the next unchecked task in `lighting-manager-tasks.md`.
2. Follow TDD order: write failing test -> implement minimum fix -> verify pass.
3. Keep manager/service lookup patterns aligned with existing ServiceLocator usage.
4. Keep zone authoring aligned with existing volume controller patterns.
5. Replace physical light nodes only after equivalent zone data is authored.
6. Keep entity-tag semantics explicit:
   - `character` tag means any actor that should receive zone-driven character lighting (player and NPCs).
   - Do not assign `character` to proxy/helper/test-only entities that should not render as lit actors.
7. After each completed phase:
   - Update `lighting-manager-tasks.md` checkboxes and progress totals.
   - Update this continuation prompt with current status and next phase.
   - Update `AGENTS.md` / `DEV_PITFALLS.md` if new stable patterns or pitfalls emerge.
8. Run style enforcement after script/scene/resource changes:
   - `tools/run_gut_suite.sh -gdir=res://tests/unit/style`
9. Commit documentation updates separately from implementation.
10. Keep style docs/tests aligned with new script categories before first phase style run:
   - Update `docs/general/STYLE_GUIDE.md` when introducing new production path categories.
   - Update `tests/unit/style/test_style_enforcement.gd` prefix rules accordingly.
   - Document locked shader filename `sh_character_zone_lighting.gdshader` in style guidance (or explicit exception) to avoid naming-rule drift.
11. Capture and maintain a lighting math contract before core manager hardening:
   - Explicit tint/intensity ranges and clamp behavior.
   - Deterministic blend ordering/tie-break behavior.
   - Boundary smoothing/hysteresis rules.

## Minimum Test Expectations per Phase

- Resource phases: unit tests for profile/config validation and blend math.
- Controller phases: unit tests for area/weight behavior.
- Manager phases: unit tests for discovery, caching, blending, transition gating.
- Migration phases: integration tests for cross-scene behavior and zone correctness.
- Coverage phases: integration tests validating player and NPC lighting parity.
- Hardening phases: deterministic overlap + boundary jitter tests and performance smoke checks.
- Final phase: style enforcement + regression checks + manual QA.
- Ensure style-guide and style-enforcement rules include `scripts/resources/lighting` before LM008 and again at final handoff.

## Definition of Done

- All checklist items in `lighting-manager-tasks.md` are checked complete.
- Unit/integration/style tests pass for touched areas.
- Gameplay scenes use zone-driven character lighting data.
- Physical character-driving light nodes are removed and replaced by zone equivalents.
- Documentation is updated and current.

## Scope Note

- Debug API/logging work is intentionally out of scope for this plan.
- If needed later, schedule a separate follow-up phase/story.
