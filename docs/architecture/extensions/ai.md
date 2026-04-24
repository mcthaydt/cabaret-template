# Add AI Behavior / Creature / Action

**Status**: Active

## When To Use This Recipe

Use this recipe when adding:

- A new NPC creature with its own behavior tree
- A new branch or subtree to an existing creature's BT
- A new `I_AIAction` resource type
- A new scorer resource for utility selection

This recipe does **not** cover:

- QB rule conditions/effects (see `conditions_effects_rules.md`)
- ECS component/system authoring (see `ecs.md`)
- Movement system changes (owned by `S_MoveTargetFollowerSystem` / `S_MovementSystem`)

## Governing ADR(s)

- [ADR 0006: AI Architecture — Utility BT with Scoped Planning](../adr/0006-ai-architecture-utility-bt-with-scoped-planning.md)
- [ADR 0007: BT Framework Scope — General vs AI-Specific](../adr/0007-bt-framework-scope-general-vs-ai-specific.md)

## Canonical Example

- Wolf brain: `resources/ai/woods/wolf/cfg_woods_wolf_brain.tres`
- Wolf BT resources: `resources/ai/woods/wolf/bt/`
- Wolf integration test: `tests/unit/ai/integration/test_woods_wolf_brain_bt.gd`
- Action resource: `scripts/resources/ai/actions/rs_ai_action_move_to.gd`
- Scorer resource: `scripts/resources/ai/bt/scorers/rs_ai_scorer_condition.gd`

## Vocabulary

| Term | Meaning |
|------|---------|
| `RS_BTNode` | Base BT resource. Three statuses: `RUNNING`, `SUCCESS`, `FAILURE`. |
| `RS_BTComposite` | Branch node with typed `children: Array[RS_BTNode]`. Subtypes: `RS_BTSequence`, `RS_BTSelector`, `RS_BTUtilitySelector`. |
| `RS_BTDecorator` | Wraps one `child: RS_BTNode`. Subtypes: `RS_BTCooldown`, `RS_BTOnce`, `RS_BTRisingEdge`, `RS_BTInverter`. |
| `RS_BTAction` | AI-specific leaf wrapping `I_AIAction`. Lives under `scripts/resources/ai/bt/`. |
| `RS_BTCondition` | AI-specific leaf wrapping `I_Condition`. Lives under `scripts/resources/ai/bt/`. |
| `RS_AIScorer*` | Scorer resources for `RS_BTUtilitySelector`. Subtypes: `Constant`, `Condition`, `ContextField`. |
| `RS_BTPlanner` | Opt-in planner node backed by `U_BTPlannerSearch` (A\*). |
| `RS_AIBrainSettings` | Brain config resource. Exports `root: RS_BTNode` and `evaluation_interval: float`. |
| `C_AIBrainComponent` | ECS component holding `brain_settings`, `bt_state_bag: Dictionary`, `evaluation_timer`. |
| `U_BTRunner` | Runtime tick executor: `tick(root, context, state_bag) -> int`. |
| `bt_state_bag` | Per-entity mutable dictionary keyed by `node.get_instance_id()`. Holds cooldown timestamps, action state, planner snapshots. |
| `context` | Per-tick read-only dictionary assembled by `U_AIContextAssembler`. Contains `delta`, `time`, `entity`, `ecs_manager`, etc. |

**Directory split** (per ADR 0007):

- General BT framework: `scripts/resources/bt/`, `scripts/utils/bt/`
- AI-specific BT nodes: `scripts/resources/ai/bt/`, `scripts/utils/ai/`

A node that imports AI-specific types (`I_AIAction`, `I_Condition`, task-state keys) belongs under `ai/bt/`. A node with no AI imports belongs under `bt/`.

## Recipe

### Adding a new creature

1. Create a brain settings `.tres` under `resources/ai/<creature>/cfg_<creature>_brain.tres` with type `RS_AIBrainSettings`.
2. Author the BT resource tree as `.tres` files under `resources/ai/<creature>/bt/`. Start with an `RS_BTUtilitySelector` root, add scored branches for each behavior.
3. Wire the root node into `cfg_<creature>_brain.tres` via the `root` property. Set `evaluation_interval` (0.0 = every frame, 0.5 = default).
4. Add a `C_AIBrainComponent` to the creature's entity scene with `brain_settings` pointing to the new `.tres`.
5. Write an integration test under `tests/unit/ai/integration/test_<creature>_brain_bt.gd` that:
   - Verifies the brain settings resource loads and has a non-null `root`.
   - Verifies the BT tree structure (expected branch count, scorer presence).
   - Verifies key behaviors via `U_BTRunner.tick()` with a fabricated context.
6. Run `tools/run_gut_suite.sh -gtest=res://tests/unit/ai/integration/test_<creature>_brain_bt.gd` and verify red-then-green.
7. Run `tools/run_gut_suite.sh -gtest=res://tests/unit/style/test_style_enforcement.gd`.

### Adding a new BT branch to an existing creature

1. Create the new subtree resources (composite + leaves + scorers) under the creature's `bt/` directory.
2. Add the subtree as a child of the appropriate composite in the brain `.tres`.
3. Add a scorer entry to the parent `RS_BTUtilitySelector` if the branch is score-selected.
4. Add a test assertion in the creature's integration test for the new branch.
5. Run the creature's integration test and the style enforcement test.

### Adding a new I_AIAction resource

1. Create the action script under `scripts/resources/ai/actions/rs_ai_action_<name>.gd` extending `Resource` and implementing `I_AIAction` (`start`, `tick`, `is_complete`).
2. Add `@export` fields for inspector authoring.
3. Use `U_AIActionPositionResolver` for movement-sensitive targets; use `U_AIContextAssembler` context keys for entity/scene resolution.
4. Write a unit test under `tests/unit/ai/actions/test_rs_ai_action_<name>.gd`.
5. The action is now usable in any `RS_BTAction` leaf — no system code changes needed.
6. Run style enforcement.

### Adding a new scorer type

1. Create the scorer script under `scripts/resources/ai/bt/scorers/rs_ai_scorer_<name>.gd` extending `RS_AIScorer`.
2. Implement `_get_score(context: Dictionary) -> float`.
3. Write a unit test under `tests/unit/ai/bt/test_rs_ai_scorer_<name>.gd`.
4. The scorer is now usable in any `RS_BTUtilitySelector` entry.
5. Run style enforcement.

## Anti-patterns

- **Hardcoded behavior in system scripts**: Behavior lives in `.tres` resource trees. `S_AIBehaviorSystem` is orchestration-only. If you're writing `if` branches in the system, put them in a BT condition instead.
- **GOAP/HTN re-introduction**: Goals, tasks, compound tasks, goal selectors, replanners, and task runners were deleted in P1.10. Do not recreate them. Use `RS_BTUtilitySelector` + decorators + `RS_BTPlanner` instead.
- **Inline goal-selector/planner stacks**: `S_AIBehaviorSystem` runs one `U_BTRunner.tick()` per brain. No nested evaluation loops.
- **Per-resource instance state**: BT resources are shared. Per-node runtime state must live in `bt_state_bag`, keyed by `node.get_instance_id()`. Never store tick-dependent state in the resource itself.
- **Bare `print()` for debug output**: Use `U_DebugLogThrottle` for throttled logging and `U_AIRenderProbe` for debug draws.
- **AI imports in general BT nodes**: `scripts/resources/bt/` must not import `I_AIAction`, `I_Condition`, or AI-specific utilities. Use `scripts/resources/ai/bt/` instead. Style boundary tests enforce this.

## Out Of Scope

- QB rule conditions/effects: see `conditions_effects_rules.md`
- ECS component/system authoring: see `ecs.md`
- Manager registration: see `managers.md`
- Scene authoring: see `scenes.md`
- Debug/probe surfaces: see `debug.md`

## References

- [AI System Overview](../../systems/ai_system/ai-system-overview.md)
- [ADR 0006: Utility BT with Scoped Planning](../adr/0006-ai-architecture-utility-bt-with-scoped-planning.md)
- [ADR 0007: BT Framework Scope](../adr/0007-bt-framework-scope-general-vs-ai-specific.md)
- [QB Rule Manager v2 Overview](../../systems/qb_rule_manager/qb-v2-overview.md)
