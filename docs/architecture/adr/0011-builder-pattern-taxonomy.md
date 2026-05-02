# ADR 0011: Builder Pattern Taxonomy

**Status**: Accepted  
**Date**: 2026-04-27  
**Context**: Cleanup V8 Phase 6 + Phase 8 prep

## Context

Cleanup V8 Phase 6 introduced GDScript builder scripts to replace `.tres` resource authoring. The motivation: an LLM co-pilot can generate a 20-line builder script in one turn, but `.tres` files require multi-turn back-and-forth with hallucinated ExtResource IDs. As more builders landed, three distinct patterns emerged with different contracts.

## Decision

Three pattern types are recognized:

**1. Static builder** — all-static methods, pure function, no instance lifecycle.  
Use when all parameters are always known up-front and the output is a single resource or node. Each call is self-contained.  
Examples: `U_BTBuilder`, `U_UIThemeBuilder`

**2. Declarative (fluent) builder** — instance-based, chainable methods, terminated by `.build()`.  
Use when a resource has many optional fields and callers need to accumulate configuration incrementally before materializing the object.  
Examples: `U_InputProfileBuilder`, `U_SceneRegistryBuilder`

**3. Helper** — static or instance, procedural, mutates external node trees or populates out-arrays. **Not a builder.**  
Named `U_*Helper`, lives in `helpers/` directories. Does not return a built object. Used when the construction target already exists and the work is orchestration or population.  
Examples: `U_RebindActionListHelper`, `U_TouchscreenPreviewHelper`, `U_VCamPipelineHelper`

## Alternatives Considered

- **Unify all three into one pattern**: Adding `.new()` + `.build()` scaffolding to static builders adds ceremony with no benefit when all args are always present. Forcing helpers into builder form requires awkward return types for what is fundamentally void, side-effecting work. No unification.

## Consequences

**Positive**

- Static vs. declarative split maps cleanly to problem shape: one-shot construction vs. accumulated optional config.
- Helpers are clearly distinct from builders; the naming contract is enforced by class suffix.
- Phase 8 UI builders can land without naming collision or pattern confusion.
- Mobile/browser safe: all three patterns are in-memory; none require `DirAccess`.

**Negative**

- Three patterns to learn instead of one. Mitigated by suffix clarity (`Builder` vs. `Helper`).

## References

- `scripts/core/utils/bt/u_bt_builder.gd` — static builder
- `scripts/core/ui/utils/u_ui_theme_builder.gd` — static builder
- `scripts/core/utils/input/u_input_profile_builder.gd` — declarative builder
- `scripts/core/utils/scene/u_scene_registry_builder.gd` — declarative builder
- `scripts/core/ui/helpers/u_rebind_action_list_helper.gd` — helper
- `scripts/core/ui/helpers/u_touchscreen_preview_helper.gd` — helper
- `scripts/core/ecs/systems/helpers/u_vcam_pipeline_helper.gd` — helper
