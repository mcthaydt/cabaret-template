# ADR 0010: Base Scene and Demo Entry Split

**Status**: Accepted  
**Date**: 2026-04-24  
**Context**: Cleanup V8 Phase 5 target decision

## Context

The project has accumulated temporary and demo scenes. A reusable template needs one canonical base scene contract plus separate demo entry content.

## Decision

Use the existing `scenes/templates/tmpl_base_scene.tscn` as the canonical base scene and keep demo entry content separate. Phase 5 refactors real demo scenes onto the base contract and deletes temporary/fake scenes last.

## Alternatives Considered

- **Single scene with embedded demo menu**: simple for demos, but weak as a reusable template.
- **Minimal-only scene with no demo entry**: clean template, but less useful for validating systems in context.

## Consequences

**Positive**

- New gameplay scenes inherit a stable manager/system/entity layout.
- Demo content remains inspectable without becoming template infrastructure.

**Negative**

- Scene migration must preserve references, registry entries, and authored resources in the same commit.

## References

- `docs/guides/cleanup_v8/cleanup-v8-tasks.md`
- `docs/guides/SCENE_ORGANIZATION_GUIDE.md`

