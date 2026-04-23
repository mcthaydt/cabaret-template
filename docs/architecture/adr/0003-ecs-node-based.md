# ADR-002: Node-Based ECS (Components + Systems)

**Status**: Accepted  
**Date**: 2025-12-17  

## Context

Gameplay logic needs to be modular, composable, and editor-friendly:

- Entities are assembled from small reusable behaviors.
- Systems should operate over sets of entities, not tightly-coupled per-node scripts.
- Designers should be able to wire NodePaths and tweak settings resources in the editor.

Pure-data ECS patterns (arrays/SoA) can be performant, but are not a natural fit for Godot’s authoring workflow and scene composition.

## Decision

Adopt a lightweight ECS implemented with scene tree Nodes:

- Entities are scene nodes (commonly `CharacterBody3D` roots).
- Components are child nodes extending `BaseECSComponent`.
- Systems are nodes extending `BaseECSSystem` and run tick logic (`process_tick(delta)`).
- `M_ECSManager` registers components and provides type-based queries.
- Cross-cutting flows use `U_ECSEventBus` and Redux state where appropriate.

## Consequences

**Positive**

- Strong Godot editor integration (composition via scenes, NodePaths, resources)
- Easy to visualize and debug in the scene tree
- Systems can be unit-tested via dependency injection (`I_ECSManager`, `I_StateStore`)

**Negative**

- Less cache-friendly than pure-data ECS
- Requires conventions to avoid “component scripts containing gameplay logic”
- Scene structure and naming standards become critical (enforced by style tests)

## Alternatives Considered

- **Traditional OOP scripts on entities**: lower upfront cost, but harder to mix behaviors and reuse patterns at scale.
- **Pure-data ECS**: higher performance potential, but significantly worse authoring ergonomics for this project.

## References

- `docs/ecs/ecs_architecture.md`
- `scripts/managers/m_ecs_manager.gd`
- `scripts/ecs/base_ecs_component.gd`
- `scripts/ecs/base_ecs_system.gd`

