# Animation System Overview

**Project**: Cabaret Template (Godot 4.6)
**Created**: 2026-03-31
**Last Updated**: 2026-03-31
**Status**: PRE-IMPLEMENTATION (design phase)
**Scope**: Quality-based animation state selection per entity, powered by QB Rule Manager v2

## Summary

The animation system selects and applies animation states per entity each tick using QB v2 rule scoring. An ECS system (`S_AnimationStateSystem`) evaluates animation rules for each entity with a `C_AnimationComponent`, and the winning rule determines the active animation state. For the greybox demo, "animation" means **procedural transform manipulation** on CSG shapes (bob, rotate, pulse, scale). The architecture also supports `AnimationTree`/`AnimationPlayer` backends for future skeletal animation use. Animation states are authored as `.tres` resources with QB conditions controlling when each state applies.

## Repo Reality Checks

- QB v2 consumers follow direct-composition: `S_CharacterStateSystem`, `S_GameEventSystem`, `S_CameraStateSystem` each instantiate `U_RuleScorer` + `U_RuleSelector` + `U_RuleStateTracker` directly
- Components extend `BaseECSComponent` with `const COMPONENT_TYPE := StringName("...")`; validated via `_validate_required_settings()`
- Systems extend `BaseECSSystem`; implement `process_tick(delta)` from `_physics_process`
- `U_PathResolver` enables conditions to read component fields (e.g., `c_ai_brain.active_goal_id`)
- Existing movement/rotation systems manipulate entity root transforms — animation must layer on a child node to avoid conflict
- No existing animation infrastructure in the template (no AnimationPlayer, no AnimationTree)

## Goals

- Per-entity animation state selection driven by QB v2 rule scoring each tick
- Procedural animation backend for greybox/CSG shapes (position offset, rotation, scale pulsing)
- Skeletal animation backend architecture for future use (AnimationTree travel, blend parameters)
- Animation states authored as `.tres` resources with QB conditions
- Smooth transitions: blend between outgoing and incoming states over configurable duration
- Override support: AI primitive tasks and cutscene effects can force animation states
- Entity-specific animation sets (different NPCs have different available animations)

## Non-Goals

- No visual animation editor or timeline tool
- No inverse kinematics (IK)
- No ragdoll physics
- No animation retargeting
- No procedural walk cycle generation
- No facial animation or blend shapes
- No animation events/notifies (use ECS events for gameplay timing)

## Architecture

```
S_AnimationStateSystem (scripts/ecs/systems/s_animation_state_system.gd)  [extends BaseECSSystem]
  Composes:
  ├── U_RuleScorer         (existing)
  ├── U_RuleSelector       (existing)
  └── U_RuleStateTracker   (existing)

C_AnimationComponent (scripts/ecs/components/c_animation_component.gd)  [extends BaseECSComponent]
  @export var animation_settings: RS_AnimationSettings
  @export var visual_root: NodePath      (child node whose transform gets animated)
  Runtime state:
  ├── active_state_id: StringName
  ├── previous_state_id: StringName
  ├── blend_progress: float              (0.0-1.0 transition progress)
  ├── state_elapsed: float               (time in current state)
  ├── override_state_id: StringName      (forced by AI/cutscene)
  └── override_priority: int             (prevents QB from overriding)

Resources:
  RS_AnimationSettings (scripts/resources/animation/rs_animation_settings.gd)
    ├── animation_rules: Array[RS_AnimationRule]
    ├── default_state_id: StringName
    └── evaluation_interval: float       (default 0.0 = every tick)

  RS_AnimationRule (scripts/resources/animation/rs_animation_rule.gd)
    ├── state_id: StringName
    ├── conditions: Array[Resource]      (QB v2 typed conditions)
    ├── priority: int
    └── transition_duration: float       (blend time entering this state)

  RS_ProceduralAnimationState (scripts/resources/animation/rs_procedural_animation_state.gd)
    ├── state_id: StringName
    ├── position_offset_curve: Curve     (Y-axis bob, null = no bob)
    ├── rotation_speed: Vector3          (degrees/sec per axis)
    ├── scale_pulse_curve: Curve         (uniform scale, null = no pulse)
    ├── scale_base: Vector3              (default 1,1,1)
    ├── loop: bool                       (default true)
    └── duration: float                  (cycle duration in seconds)

  RS_SkeletalAnimationState (scripts/resources/animation/rs_skeletal_animation_state.gd)  [DEFERRED]
    ├── animation_name: StringName
    ├── blend_parameters: Dictionary
    └── playback_speed: float

Animation Backend:
  U_ProceduralAnimator (scripts/utils/animation/u_procedural_animator.gd)  [extends RefCounted]
    Applies position/rotation/scale to Node3D based on state + elapsed time
    Handles blending between outgoing and incoming states
```

## Key Design: visual_root Separation

Animation manipulates a **child node** (`visual_root`), not the entity root. This prevents conflict with movement/physics systems:

```
NPCEntity (BaseECSEntity)  ← movement system controls this
  └── VisualRoot (Node3D)  ← animation system controls this
        ├── CSGSphere3D
        └── CSGCylinder3D
```

## Responsibilities & Boundaries

### Animation System owns

- Per-entity animation state evaluation via QB v2 scoring
- Animation state transitions with blend duration
- Procedural animation application (transform offsets on visual_root)
- Override handling (AI/cutscene forces state, QB doesn't override)
- State lifecycle (enter → tick → exit → transition)

### Animation System depends on

- `M_ECSManager`: Component queries
- QB v2 utilities: scoring, selection, state tracking
- `U_PathResolver`: Condition evaluation

### Animation System does NOT own

- Entity movement/positioning (movement systems own root transforms)
- AI behavior decisions (AI requests overrides; animation applies them)
- Cutscene choreography (cutscene triggers overrides via effects)
- Sound effects (ECS event bus; audio systems listen)

## Demo Integration (Signal Lost)

### Patrol Drone (Power Core)
| State | Conditions | Procedural |
|-------|-----------|------------|
| `idle_bob` | Default | Y sine bob (0.1m, 2s), slow Y rotation (30deg/s) |
| `patrol_move` | `active_goal_id == "patrol"` | Fast Y rotation (90deg/s), forward tilt 15deg |
| `investigate_pause` | `active_goal_id == "investigate"` | No bob, spotlight Z rotation sweep |

### Sentry (Comms Array)
| State | Conditions | Procedural |
|-------|-----------|------------|
| `idle_scan` | Default | Slow eye Y sweep (+-45deg, 3s) |
| `alert_pulse` | `active_goal_id == "investigate"` | Scale pulse (1.0→1.2, 0.5s), fast eye |
| `patrol_slide` | `active_goal_id == "guard"` AND velocity > 0 | Slight lean, steady eye |

### Guide Prism (Nav Nexus)
| State | Conditions | Procedural |
|-------|-----------|------------|
| `float_idle` | Default | Y rotation 60deg/s, gentle bob (0.05m, 1.5s) |
| `lead_ahead` | `active_goal_id == "show_path"` | Fast rotation 180deg/s, larger bob, scale 1.1 |
| `encourage_pulse` | `active_goal_id == "encourage"` | Scale pulse (1.0→1.5, 0.8s), doubled bob |
| `celebrate_spin` | `active_goal_id == "celebrate"` | Rapid 360deg/s, scale pulse + bounce |

## Implementation Phases

### Phase 1: Core Resources & Component
- Create `RS_AnimationSettings`, `RS_AnimationRule`, `RS_ProceduralAnimationState`
- Create `C_AnimationComponent` with `@export animation_settings`, `@export visual_root`
- Unit tests for resource creation and component registration

### Phase 2: Procedural Animator
- Create `U_ProceduralAnimator` (RefCounted)
- Apply position offset (curve), rotation (continuous), scale (curve) to Node3D
- Blend between two states (lerp transforms over transition duration)
- Unit tests with mock Node3D

### Phase 3: Animation State System
- Create `S_AnimationStateSystem` extending `BaseECSSystem`
- QB v2 composition for rule scoring per-entity per-tick
- State transition management: detect change → blend → complete
- Override support: AI/cutscene force state with priority
- Integration tests

### Phase 4: Demo NPC Animations
- Author `RS_ProceduralAnimationState` for all 10 NPC animation states
- Author `RS_AnimationRule` with QB conditions
- Author `RS_AnimationSettings` per NPC type
- Wire into entity scenes, playtest, tune

## Verification Checklist

1. Procedural animation applies correct offsets to visual_root
2. State transitions blend smoothly
3. QB scoring selects correct state based on entity conditions
4. Override states prevent QB switching
5. Override clears and QB resumes when expired
6. No conflict with movement system (visual_root vs entity root)
7. Multiple entities animate independently
8. All demo NPCs display correct animations per behavior
9. Style enforcement passes
10. No jitter during transitions

## Resolved Questions

| Question | Decision |
|----------|----------|
| Skeletal vs procedural? | Both architected; only procedural built for greybox demo |
| Transform conflict? | Solved via `visual_root` child node pattern |
| Per-tick vs interval? | Configurable; default every tick |
| Animation events? | Not in scope; use ECS event bus |

## Links

- Animation system plan/tasks/continuation docs are not present yet.
- [AI System Overview](../ai_system/ai-system-overview.md)
- [QB Rule Manager v2 Overview](../qb_rule_manager/qb-v2-overview.md)
