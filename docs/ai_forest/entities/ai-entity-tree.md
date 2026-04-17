# AI Entity Spec - Forest Tree (Static Decor)

Concrete Phase 1 spec for non-brain environmental tree instances in the forest scene.

Source template baseline: `docs/ai_system/ai-entity-authoring-template.md` (adapted for non-AI/static entity).

## 1) Identity

- Entity name: Forest Tree
- Entity ID (`StringName`): none (intentionally no `BaseECSEntity` root / no AI identity)
- Role/archetype summary: Static obstacle/decorative prop used to shape movement and visual layout.
- Scene/prefab path: `scenes/prefabs/prefab_forest_tree.tscn`
- Owner scene(s): `scenes/gameplay/gameplay_ai_forest.tscn`

## 2) Runtime Contract (Must Be True)

- [x] Root is `StaticBody3D` (`ForestTree`), not a brain-bearing entity.
- [x] Has explicit `CollisionShape3D` for obstacle behavior.
- [x] No ECS AI components (`C_AIBrainComponent`, `C_DetectionComponent`, `C_MoveTargetComponent`, etc.).
- [x] No `entity_id` and no species tags.
- [x] Visual CSG mesh uses `use_collision = false` to avoid duplicate collision bodies.

## 3) Collision/Scene Design

- Collision shape: `CylinderShape3D` (`radius = 0.6`, `height = 3.0`)
- Visual mesh: `CSGCylinder3D` with dark-green material
- Phase 1 scene count: 30 tree instances in `Environment/Trees`

## 4) Behavior Contract

- Expected Phase 1 behavior: trees are decoration + static blockers only.
- Current authored behavior: matches expected contract (no AI, no runtime logic, static physics obstacle).

## 5) Authoring Assets Checklist

- [x] Prefab: `scenes/prefabs/prefab_forest_tree.tscn`
- [x] Scene instances: `scenes/gameplay/gameplay_ai_forest.tscn` (`Tree_01` ... `Tree_30`)
- [x] No AI resources required for this prefab

## 6) Verification Notes

- Structural verification source: scene/prefab files only.
- Runtime visual/manual verification status for current patch: pending.
- Automated AI behavior tests do not directly assert tree contract; tree behavior is validated indirectly via forest scene navigation/obstacle context.

## 7) Post-Implementation Notes

- This document mirrors current tree prefab behavior as implemented on 2026-04-16.
- If trees become interactive or brain-bearing in later phases, replace this with a full AI spec.
