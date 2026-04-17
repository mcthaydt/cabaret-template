# AI Forest Phase 1 - Expected vs Current

Snapshot date: 2026-04-17  
Purpose: compare Phase 1 expected behavior to currently authored runtime contracts/resources.

## 0) Runtime Evidence (Latest Manual Run)

Source: in-thread Godot runtime log captured on 2026-04-17 (OpenGL Compatibility renderer on Apple M1).

Observed highlights from that run:
- Wolves switched from `wander` to `hunt` on prey detection (for example `forest_wolf_02`, `forest_wolf_01`).
- Rabbits switched from `graze`/`wander` to `flee` on predator detection (for example `forest_rabbit_03`, `forest_rabbit_05`, `forest_rabbit_08`).
- Deer switched from `graze`/`wander` to `startle` on predator detection (multiple deer IDs observed).
- Detection hysteresis events were observed with explicit lost logs using exit radius checks.

Notable behavior concern from the same run:
- Deer showed high-frequency `startle <-> graze/wander` cycling across multiple entities. This still satisfies the Phase 1 "switch to startle" requirement, but indicates likely tuning churn under sustained predator proximity (cooldown/priority interplay).

Post-log tuning applied in repo:
- `RS_AIActionMoveToDetected` now refreshes move target every tick from live detected entity position (continuous chase repath).
- `cfg_goal_startle.tres` now sets `requires_rising_edge = true` to reduce repeated retrigger churn while threat remains continuously true.
- 2026-04-17 tuning pass: rabbit `detection_exit_radius` increased to `16.0` (from `14.0`), deer `detection_exit_radius` increased to `18.0` (from `16.0`), rabbit flee distance increased to `12.0` (from `9.0`), and deer `startle` cooldown increased to `3.0` (from `2.0`) to reduce edge-flapping and repeated startle loops.

## 1) Species Behavior Comparison

| Species | Phase 1 expected behavior | Current authored behavior | Comparison |
|---|---|---|---|
| Wolf | Chase nearest rabbit/prey when detected; otherwise roam | `target_tag = &"prey"`, `detection_radius = 12`, goals `[hunt(10), wander(0)]`, hunt task sequence `move_to_detected -> wait(0.4) -> move_to_detected`, with move-to-detected target refreshed each tick | Aligned by authored contract and runtime logs; chase continuity improved by repath tuning |
| Rabbit | Flee from nearby wolves/predators | `target_tag = &"predator"`, `detection_radius = 8`, `detection_exit_radius = 16`, goals `[flee(10), graze(2), wander(0)]`, flee uses computed away-vector target with `flee_distance = 12` | Aligned by authored contract; widened hysteresis + longer flee displacement to reduce rapid flee/wander toggles near boundary |
| Deer | Switch from graze to startle when predator nearby | `target_tag = &"predator"`, `detection_radius = 10`, `detection_exit_radius = 18`, goals `[startle(8,cooldown=3,requires_rising_edge=true), graze(2), wander(0)]`, startle sequence `scan(1.0,1.5) -> wait(0.35)` | Functionally aligned; wider hysteresis + longer cooldown reduce repeated startle retriggers under sustained proximity |
| Tree | Static decoration/obstacle only | `StaticBody3D` + collision shape + visual CSG mesh, no brain/components | Aligned |

Detailed entity specs:
- `docs/ai_forest/entities/ai-entity-wolf.md`
- `docs/ai_forest/entities/ai-entity-rabbit.md`
- `docs/ai_forest/entities/ai-entity-deer.md`
- `docs/ai_forest/entities/ai-entity-tree.md`

## 2) Scene Wiring Comparison

| Phase 1 scene expectation | Current scene wiring | Comparison |
|---|---|---|
| AI-essential systems only | `S_AIDetectionSystem`, `S_AIBehaviorSystem`, `S_MoveTargetFollowerSystem`, `S_GravitySystem`, `S_MovementSystem`, `S_FloatingSystem` present in `gameplay_ai_forest.tscn` | Aligned |
| Population counts | 4 wolves, 8 rabbits, 6 deer, about 30 trees | 4 wolves, 8 rabbits, 6 deer, 30 trees authored | Aligned |
| Debug observability | Per-agent label + aggregate debug panel | `DebugForestAgentLabel` inherited on agent prefab; `DebugAIBrainPanel` instanced in scene | Aligned |

## 3) Acceptance Criteria Comparison (From `ai-forest-overview.md`)

| Acceptance criterion | Current evidence | Status |
|---|---|---|
| Scene boots and brain agents produce non-empty task queues | Startup logs show goal selection/action start across wolves/rabbits/deer; smoke suite re-run passed | Confirmed |
| Wolves converge on rabbits visually | Logs show wolf detection + `wander -> hunt` + `MoveToDetected` target assignments | Behavior transition confirmed via logs; full movement convergence still visual/manual |
| Rabbits flee predators visibly | Logs show rabbit detection + `graze/wander -> flee` + `FleeFromDetected` target assignments | Behavior transition confirmed via logs; full movement feel still visual/manual |
| Deer switch graze->startle near wolves | Logs show repeated deer `graze/wander -> startle` transitions on predator detection | Confirmed, with churn concern under sustained proximity |
| Agent Label3D shows entity/goal/task | Label script consumes brain debug snapshot each frame; logs alone do not prove on-screen rendering | Pending explicit UI visual confirmation |
| Debug panel lists all brain entities | Panel script refreshes rows from `C_AIBrainComponent` list; logs alone do not prove panel rendering | Pending explicit UI visual confirmation |
| Detection exit hysteresis behavior is active | Logs include multiple `lost ... (dist > exit_radius)` events for rabbits/deer | Confirmed by runtime log sample |
| Phase 1 test suites green | Re-ran `test_ai_actions_forest`, `test_s_ai_detection_system_tag_target`, and `test_forest_ecosystem_smoke` (all passed) | Partially re-verified |
| Style suite green | Re-ran `test_style_enforcement` and observed 1 failure unrelated to this tuning scope (`S_AIBehaviorSystem` line-count guard: 200 > 199) | Not green in current workspace |

## 4) Gaps To Verify Now

- Manual visual pass remains needed for UI/debug overlays and movement quality assessment.
- Re-run a visual pass after the 2026-04-17 tuning update to verify reduced rabbit flee/wander edge flapping and reduced deer startle churn.
- Re-run suites before locking comparison as current for a new code patch:
- `tests/integration/gameplay/test_forest_ecosystem_smoke.gd`
- `tests/unit/ecs/systems/test_s_ai_detection_system_tag_target.gd`
- `tests/unit/ai/actions/test_ai_actions_forest.gd`
- `tests/unit/style/test_style_enforcement.gd`
