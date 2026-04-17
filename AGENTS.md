# Agents Notes

## Start Here

- Project type: Godot 4.6 (GDScript). Core area:
  - `scripts/ecs`: Lightweight ECS built on Nodes (components + systems + manager).
- Scenes and resources:
  - `scenes/templates/`: Base scene, character, and camera templates that wire components/systems together.
  - `resources/base_settings/`: Default `*Settings.tres` for component configs (domain subfolders); update defaults when adding new exported fields.
  - `assets/audio/`, `assets/button_prompts/`, `assets/editor_icons/`: Shared asset libraries for audio, input glyphs, and editor UI.
- Documentation to consult (do not duplicate here):
  - General pitfalls: `docs/general/DEV_PITFALLS.md`
  - AI entity behavior spec template (fill before implementing new AI entities): `docs/ai_system/ai-entity-authoring-template.md`
- Before adding or modifying code, re-read `docs/general/DEV_PITFALLS.md` and `docs/general/STYLE_GUIDE.md` to stay aligned with testing and formatting requirements.
- Keep project planning docs current: whenever a story advances, update the relevant plan and PRD documents immediately so written guidance matches the implementation state.
- **MANDATORY: Update continuation prompt and tasks checklist after EVERY phase**: When completing a phase (e.g., Phase 2 of Scene Manager), you MUST:
  1. Update the continuation prompt file (e.g., `docs/scene_manager/scene-manager-continuation-prompt.md`) with current status
  2. Update the tasks file (e.g., `docs/scene_manager/scene-manager-tasks.md`) to mark completed tasks with [x] and add completion notes
  3. Update AGENTS.md with new patterns/architecture (if applicable)
  4. Update DEV_PITFALLS.md with new pitfalls discovered (if applicable)
  5. Commit documentation updates separately from implementation
- Commit at the end of each completed story (or logical, test-green milestone) so every commit represents a verified state.
- Make a git commit whenever a feature, refactor, or documentation update moves the needle forward; keep commits focused and validated. Skipping required commits is a blocker—treat the guidance as non-optional.
- **MANDATORY: Run style and scene organization tests before merging**: After any changes to file naming, scene structure, or adding new scripts/scenes, run `tests/unit/style/test_style_enforcement.gd` to ensure prefix compliance and scene structure validity. Automated checks enforce the prefix rules documented in `STYLE_GUIDE.md`.

## Repo Map (essentials)

- `scripts/managers/m_ecs_manager.gd`: Registers components/systems; exposes `get_components(StringName)` and emits component signals.
- `scripts/managers/m_scene_manager.gd`: Scene transition coordinator (Phase 3+); manages ActiveSceneContainer.
- `scripts/managers/m_save_manager.gd`: Save/load coordinator; manages save slots, atomic writes, migrations, and autosave scheduling.
- `scripts/managers/m_objectives_manager.gd`: Objectives manager (Phase 2 core); loads objective sets, validates dependency DAGs, evaluates objective conditions on relevant events, and publishes objective lifecycle/victory events.
- `scripts/managers/m_run_coordinator_manager.gd`: Run reset coordinator; listens for `run/reset`, dispatches gameplay reset, force-unblocks interactions, resets objectives for a fresh run, and retries to `alleyway`.
- `scripts/interfaces/i_objectives_manager.gd`: Interface contract for objectives manager lookups (`load_objective_set`, `reset_for_new_run`, `get_objective_status`).
- `scripts/interfaces/i_scene_director.gd`: Interface contract for scene director lookups (`get_active_directive_id`).
- `scripts/interfaces/i_run_coordinator.gd`: Interface contract for run coordinator lookups (`is_reset_in_flight`).
- `scripts/state/m_state_store.gd`: Redux store; registers with ServiceLocator for discovery via `U_StateUtils.get_store()`.
- `scripts/ui/utils/u_ui_registry.gd` + `resources/ui_screens/`: UI registry definitions (`RS_UIScreenDefinition`) for base screens and overlays.
- UI controllers are grouped by screen type: `scripts/ui/menus/`, `scripts/ui/overlays/`, `scripts/ui/hud/` (utilities live in `scripts/ui/utils/`).
- UI scenes organized by type: `scenes/ui/menus/`, `scenes/ui/overlays/`, `scenes/ui/hud/`, `scenes/ui/widgets/` (cleanup v4.5).
- `scripts/ecs/base_ecs_component.gd`: Base for components. Auto-registers with manager; exposes `get_snapshot()` hook.
- `scripts/ecs/base_ecs_system.gd`: Base for systems. Implement `process_tick(delta)`; runs via `_physics_process`. Declares `SystemPhase` enum (`PRE_PHYSICS`, `INPUT`, `PHYSICS_SOLVE`, `POST_PHYSICS`, `CAMERA`, `VFX`) — override `get_phase()` in every `S_*` system. `M_ECSManager` sorts by phase (primary), `execution_priority` (secondary), instance ID (tertiary).
- `scripts/ecs/components/*`: Gameplay components with `@export` NodePaths and typed getters.
- `scripts/ecs/systems/*`: Systems that query components by `StringName` and operate per-physics tick.
- `scripts/resources/ecs/*`: `Resource` classes holding tunables consumed by components/systems.
- C9 config resources (gameplay feel tuning): `scripts/resources/ecs/rs_wall_visibility_config.gd`, `scripts/resources/ecs/rs_camera_state_config.gd`, `scripts/resources/managers/rs_spawn_config.gd`.
- Manager config resources (C9 follow-through): `scripts/resources/managers/rs_character_lighting_config.gd` and `scripts/resources/managers/rs_display_config.gd` provide default/fallback tuning consumed by `M_CharacterLightingManager` and `M_DisplayManager`.
- Canonical C9 default config instances live under `resources/base_settings/*/cfg_*_config_default.tres` and should be used as fallback baselines instead of runtime `Resource.new()` allocation in hot paths.
- `scripts/ecs/components/c_spawn_recovery_component.gd`: Shared unsupported-state recovery component; requires `RS_SpawnRecoverySettings`.
- `scripts/resources/ecs/rs_spawn_recovery_settings.gd`: Recovery tuning resource (`spawn_point_id`, `unsupported_delay_sec`, `recovery_cooldown_sec`, `startup_grace_period_sec`).
- `scripts/ecs/systems/s_spawn_recovery_system.gd`: Shared player/NPC recovery system; respawns unsupported entities via `I_SpawnManager` and clears movement/task runtime state after recovery.
- `scripts/utils/ecs/u_ecs_utils.gd`: ECS helpers (manager lookup, time, component mapping). Input helpers live in `scripts/utils/input/`.
- `scripts/utils/scene_director/u_objective_graph.gd`: Objective DAG helper (build, cycle/missing-dependency validation, ready-dependents, topological sort).
- `scripts/utils/scene_director/u_objective_event_log.gd`: Objective transition log helper (timestamped entries + readable formatting).
- `scripts/utils/scene_director/u_beat_graph.gd`: Beat-flow graph validator/helper (ID/reference checks, cycle detection, ID->index map).
- `scripts/events/ecs/`: ECS event bus + typed ECS events; `scripts/events/state/` holds `U_StateEventBus` (state-domain bus).
- `docs/adr/0001-channel-taxonomy.md`: Channel taxonomy ADR — managers dispatch to Redux only; ECS components/systems publish to `U_ECSEventBus`.
- `scenes/root.tscn`: Main scene (persistent managers + containers).
- `scenes/gameplay/*`: Gameplay scenes (dynamic loading, own M_ECSManager).
- `tests/unit/*`: GUT test suites for ECS and state management.

## Scene Director / Objectives (Phase 2 Core)

- `M_ObjectivesManager` is event-driven, not tick-driven:
  - Evaluates active objectives only when subscribed milestone events fire (`checkpoint_activated`, `victory_executed`, `gameplay/mark_area_complete` action dispatches).
  - Does not run per-physics polling for objective completion.
- Condition/effect execution contract:
  - Conditions evaluate directly via `condition.evaluate(context)` and pass when score > 0.0.
  - Effects execute directly via `effect.execute(context)` after objective completion.
  - Context contract is `{"state_store": _store, "redux_state": _store.get_state()}` with optional `"event_payload"` for event-driven checks.
- Objective completion flow:
  - Status transition dispatches via `U_ObjectivesActions` (`activate`, `complete`, `fail`).
  - Event log entries are dispatched through `U_ObjectiveEventLog.create_entry(...)`.
  - Dependents are activated only when `U_ObjectiveGraph.get_ready_dependents(...)` reports all prerequisites completed.
  - VICTORY objectives dispatch `U_GameplayActions.trigger_victory_routing(target_scene, completion_payload)` through Redux (per channel taxonomy, `docs/adr/0001-channel-taxonomy.md`).
  - `M_SceneManager` subscribes to `M_StateStore.action_dispatched` and reacts to `ACTION_TRIGGER_VICTORY_ROUTING` for endgame transitions; legacy ECS-bus victory routing is removed.
- Reset-run orchestration pattern (Phase 7):
  - `UI_Victory` Continue dispatches `U_RunActions.reset_run(&"retry")` (do not chain gameplay/navigation reset actions directly in UI code).
  - `M_RunCoordinatorManager` handles `run/reset` order: `gameplay/reset_progress` -> `U_InteractBlocker.force_unblock()` -> `objectives_manager.reset_for_new_run(&"default_progression")` -> `navigation/retry(game_config.retry_scene_id)` (currently `&"ai_showcase"` in `resources/cfg_game_config.tres`).
  - Service-locator lookups in the reset path are type-cast to `I_ObjectivesManager` (no `has_method("reset_for_new_run")` duck-typing guards).
  - `M_ObjectivesManager.reset_for_new_run()` is the fresh objective-reset path (no persisted-status reconciliation); `load_objective_set()` remains the save/load reconciliation path.
  - Re-entrant `run/reset` requests are ignored while a reset is in-flight.
- Player-facing beat messaging pattern:
  - Scene-director beats may publish `signpost_message` events with `{"message": "<localization_key>", "message_duration_sec": <float>}` payloads so existing HUD/mobile signpost consumers can render narrative/tutorial text without custom UI plumbing.
- Scene-director flow-control pattern (Phase 9):
  - `RS_BeatDefinition` supports `next_beat_id`, `next_beat_id_on_failure`, `parallel_beat_ids`, and `parallel_join_beat_id`.
  - Always validate beat arrays with `U_BeatGraph.validate(...)` before runner start; skip invalid directives at runtime.
  - Parallel support is single-hop fork/join only (lane beats must not define their own `parallel_beat_ids`).
  - Redux observability uses `scene_director.current_beat_id`, `active_beat_ids`, and `parallel_lane_ids` in addition to `current_beat_index`.

## ServiceLocator Registration & Test Isolation (F6)

- **`register()` fails on conflict**: `U_ServiceLocator.register(name, instance)` pushes an error and returns without overwriting if `name` is already registered with a different instance. Same-instance re-registration is idempotent.
- **Intentional replacement**: use `U_ServiceLocator.register_or_replace(name, instance)` when swapping out a service is the intended behavior (reconnection, test setup).
- **Test scope isolation**: `U_ServiceLocator.push_scope()` saves `_services` + `_dependencies` and installs a fresh empty registry; `pop_scope()` restores the previous state (no-op on empty stack). Production never calls these — the stack stays empty and default behavior is unchanged.
- **BaseTest contract**: tests extending `BaseTest` get automatic isolation — `before_each()` calls `push_scope()` + `U_StateHandoff.clear_all()`, `after_each()` calls `pop_scope()`. Overriding these without `super.before_each()` / `super.after_each()` bypasses isolation; if you override, call `super` first.
- **Avoid `U_ServiceLocator.clear()` in tests** — it wipes the scope stack as well as `_services`, which breaks nested scope isolation. Prefer `push_scope` / `pop_scope` (or inherit from `BaseTest`).

## Communication Channel Taxonomy (F5)

Per `docs/adr/0001-channel-taxonomy.md`, the project enforces a publisher-based channel rule:

- **ECS component/system → `U_ECSEventBus`**: subscribers can be anywhere (manager, UI, other systems).
- **Manager → Redux dispatch only**: managers must not call `U_ECSEventBus.publish`. State changes flow through `M_StateStore.dispatch()` for action history, validation, and subscriber batching.
- **Intra-manager / manager-UI wiring → Godot signals**: only allow-listed signal declarations permitted (enforced by `test_manager_signals_allow_list`).
- **Everything else → method calls**.

**Exception**: `m_ecs_manager.gd` may publish to `U_ECSEventBus` (entity_registered/unregistered) because it IS the ECS infrastructure.

## ECS Guidelines

- Components
  - Extend `BaseECSComponent`; define `const COMPONENT_TYPE := StringName("YourComponent")` and set `component_type = COMPONENT_TYPE` in `_init()`.
  - Enforce required settings/resources by overriding `_validate_required_settings()` (call `push_error(...)` and return `false` to abort registration); use `_on_required_settings_ready()` for post-validation setup.
  - Prefer `@export` NodePaths with typed getters that use `get_node_or_null(...) as Type` and return `null` on empty paths.
  - Keep null-safe call sites; systems assume absent paths disable behavior rather than error.
  - Shared recursive body lookup contract: use `U_NodeFind.find_character_body_recursive(...)` for generic `CharacterBody3D` discovery instead of duplicating `_find_character_body_recursive` helpers across components/systems.
  - If you expose debug state, copy via `snapshot.duplicate(true)` to avoid aliasing.
  - Spawn freeze/unfreeze state lives in `C_SpawnStateComponent` (`is_physics_frozen`, `unfreeze_at_frame`, `suppress_landing_until_frame`); systems gate movement/jump/floating via this component.
- Systems
  - Extend `BaseECSSystem`; implement `process_tick(delta)` (invoked from `_physics_process`).
  - Query with `get_components(StringName)`, dedupe per-body where needed, and clamp/guard values (see movement/rotation/floating examples).
  - Use `U_ECSUtils.map_components_by_body()` when multiple systems need shared body→component dictionaries (avoids duplicate loops).
  - Auto-discovers `M_ECSManager` via parent traversal or ServiceLocator (`ecs_manager`); no manual wiring needed.
  - Event-driven request systems should extend `BaseEventVFXSystem` / `BaseEventSFXSystem` and implement `get_event_name()` + `create_request_from_payload()` to enqueue `requests`.
- Game event system + handlers (Phase 3B, QB v2)
  - `S_GameEventSystem` hosts default game forwarding rules from `resources/qb/game/*.tres` and composes v2 rule utilities (`U_RuleScorer`, `U_RuleSelector`, `U_RuleStateTracker`, `U_RuleValidator`) directly.
  - `S_GameEventSystem` evaluates event/both rules on subscribed ECS events and supports optional global tick evaluation for tick/both rules.
  - Event-forwarding publish effects merge incoming event payload into the outgoing payload, then apply configured payload overrides and `entity_id` injection.
  - `S_CheckpointHandlerSystem` subscribes to `U_ECSEventNames.EVENT_CHECKPOINT_ACTIVATION_REQUESTED`, validates required payload (`checkpoint`, `spawn_point_id`), dispatches `set_last_checkpoint`, and publishes `Evn_CheckpointActivated`.
  - `S_VictoryHandlerSystem` subscribes to `U_ECSEventNames.EVENT_VICTORY_EXECUTION_REQUESTED` at subscription priority `10`, enforces `game_config.required_final_area` (from `RS_GameConfig`) for game-complete triggers, dispatches gameplay victory actions, calls `trigger.set_triggered()`, then publishes `U_ECSEventNames.EVENT_VICTORY_EXECUTED` for post-validation scene transitions.
  - Gameplay flows use `S_GameEventSystem` + handler systems end-to-end; legacy `S_CheckpointSystem` / `S_VictorySystem` are removed from the codebase, and active tests target QB-handler flow.
- QB Rule Engine v2 patterns (Phase 5 complete)
  - The rule engine is a stateless library: `U_RuleScorer.score_rules(...)` + `U_RuleSelector.select_winners(...)`; systems compose these utilities instead of inheriting a QB base class.
  - Rule consumers (`S_CharacterStateSystem`, `S_GameEventSystem`, `S_CameraStateSystem`) each own their own `U_RuleStateTracker` instance; never share trackers between systems.
  - Rule assets use `RS_Rule` + typed condition/effect resources (`RS_Condition*`, `RS_Effect*`). `conditions` and `effects` use typed arrays (`Array[I_Condition]`, `Array[I_Effect]`) with coerce setters matching `RS_AIGoal` pattern; `U_RuleValidator` validates semantic correctness (required fields, valid ranges) as a double-check layer.
  - Condition contract: all rules must declare at least one condition; unconditional rules are invalid (validator error, scorer returns 0.0).
  - Validation contract: use only `valid_rules` from the validation report; expose/report `{valid_rules, errors_by_index, errors_by_rule_id}` for tests and debugging.
  - Scoring contract: conditions return 0.0-1.0, optional `response_curve` remap applies before optional `invert`, and rule score is the multiplicative product across conditions.
  - Selection contract: rules with empty `decision_group` fire independently; grouped rules compete by score, then priority, then `rule_id` alphabetical tiebreak.
  - Trigger contract: `trigger_mode` supports `tick`, `event`, and `both`; event subscriptions are derived from `RS_ConditionEventName.expected_event_name` (not rule-level `trigger_event` metadata), and event consumers fan out contexts per relevant entity/payload with cooldown/rising-edge/one-shot gating via tracker state.
  - Context/path contract: conditions/effects resolve context paths through `U_PathResolver` and must not rely on method-call fallback behavior.
  - Camera baseline pattern: `S_CameraStateSystem` captures authored baseline FOV into `C_CameraStateComponent.base_fov` and restores it when `state.vcam.in_fov_zone` is false.
  - Pause gate pattern: character pause gate rules (`cfg_pause_gate_paused/shell/transitioning`) share `decision_group = &"pause_gate"` so exactly one winner applies the same gate effect each tick.
  - Composite condition pattern (Phase 9): use `RS_ConditionComposite` for nested logical grouping (`ALL` for AND/product, `ANY` for OR/max). Keep nesting <= 8 and validate through `U_RuleValidator` (empty composite children are invalid).
- AI goal-loop pattern (M7 complete)
  - `S_AIBehaviorSystem` (`scripts/ecs/systems/s_ai_behavior_system.gd`) is the canonical GOAP goal-evaluation + task-runner system. It must compose `U_RuleScorer`, `U_RuleSelector`, `U_RuleStateTracker`, and `U_HTNPlanner` (no QB base-class inheritance).
  - Collaborator split contract (R3 refactor): `S_AIBehaviorSystem` is orchestration-first and delegates to `U_AIGoalSelector`, `U_AITaskRunner`, `U_AIReplanner`, and `U_AIContextBuilder`. Keep goal selection/state gating, task execution, replanning/suspend-restore, and context assembly in those utilities; do not re-expand the behavior system with monolithic inline helpers.
  - Orchestration integration contract (R10 refactor): keep `S_AIBehaviorSystem` orchestration-only and under 200 lines; preserve no AI-local duck-typing helper family (`_read_object_property`, `_read_int_property`, `_read_bool_property`, `_read_float_property`, `_variant_to_string_name`) in this system.
  - Debug extraction contract (R4 refactor): AI debug throttle/probe behavior must compose shared utilities (`U_DebugLogThrottle`, `U_AIRenderProbe`) instead of per-system helper duplication. Do not reintroduce `_tick_debug_log_cooldowns` or local `_build_render_probe` stacks in AI systems.
  - Typed-contract pattern (R1 refactor): treat AI brain/goal/task/action fields as strongly typed runtime contracts, not duck-typed payloads. Canonical types are `C_AIBrainComponent.brain_settings: RS_AIBrainSettings`, `RS_AIBrainSettings.goals: Array[RS_AIGoal]`, `RS_AIGoal.root_task: RS_AITask`, `RS_AIGoal.conditions: Array[I_Condition]`, `RS_AIPrimitiveTask.action: I_AIAction`, `RS_AICompoundTask.subtasks: Array[RS_AITask]`, and `RS_AICompoundTask.method_conditions: Array[I_Condition]`. Do not reintroduce `_read_*_property` helpers into the AI hot path.
  - AI resource directory contract (R7 refactor): keep core AI resource scripts organized by concept under `scripts/resources/ai/brain/`, `scripts/resources/ai/goals/`, `scripts/resources/ai/tasks/`, and `scripts/resources/ai/actions/`. Do not add new top-level `scripts/resources/ai/rs_ai_*.gd` files.
  - Goal selection contract: evaluate `RS_AIGoal` entries from `C_AIBrainComponent.brain_settings.goals`, resolve winners via a single decision group (`ai_goal`), and fall back to `default_goal_id` when no goal scores above threshold.
  - Re-plan contract: on goal change, reset `current_task_queue`, `current_task_index`, and `task_state`, then populate a new primitive queue via `U_HTNPlanner.decompose(goal.root_task, context)`.
  - HTN planner context contract (R9 refactor): keep recursion/runtime decomposition state in `U_HTNPlannerContext` (`reusable_rule`, `recursion_stack`, `result`, `max_depth`, `depth`) and keep `U_HTNPlanner.decompose(...)` as the stable public entry point.
  - Evaluation-throttle contract: honor `RS_AIBrainSettings.evaluation_interval` using `C_AIBrainComponent.evaluation_timer`; first evaluation should run immediately for brains without an active goal.
  - Task-runner contract (M6): `_execute_current_task(brain, delta, context)` runs every tick, dispatches primitive task actions polymorphically via `I_AIAction.start/tick/is_complete`, advances one task at a time, and clears queue/index/task-state only when the queue completes.
  - Instant action contract (M6): `RS_AIActionWait` tracks `task_state["elapsed"]`; `RS_AIActionPublishEvent` publishes through `U_ECSEventBus`; `RS_AIActionSetField` resolves targets with `U_PathResolver`.
  - Movement/stub action contract (M7/M12/R6): `RS_AIActionMoveTo` resolves waypoint/node/position targets and writes `task_state["ai_move_target"]` plus `task_state["ai_arrival_threshold"]` (back-compat path used by the move-target follower); `RS_AIActionScan` tracks scan timing in task state; `RS_AIActionAnimate` is a stub that sets `task_state["animation_state"]` and completes immediately.
  - Move-target follower contract (R6): `S_MoveTargetFollowerSystem` (`scripts/ecs/systems/s_move_target_follower_system.gd`, `execution_priority = -5`) is the canonical world-space move-vector bridge. It queries `C_InputComponent` + `C_MovementComponent`, prefers active `C_MoveTargetComponent` targets (`target_position`, `arrival_threshold`, `is_active`), and falls back to AI task-state targets (`U_AITaskStateKeys.MOVE_TARGET`/`ARRIVAL_THRESHOLD`) for compatibility.
  - AI movement consumption contract (M12): `S_MovementSystem` detects `C_AIBrainComponent` and routes AI-authored move vectors through `_get_desired_velocity()` (world-space) while keeping player input camera-relative.
  - Player-input isolation contract (M7): `S_InputSystem` queries `C_InputComponent` with required `C_PlayerTagComponent` so player input updates only player-tagged entities and does not clobber AI-authored move vectors.
  - Demo scene authoring contract (M10): any NPC expected to execute `RS_AIActionMoveTo` in authored gameplay scenes must include a runtime movement stack (`CharacterBody3D`, `C_InputComponent`, and `C_MovementComponent` with valid movement settings). Brain-only placeholder entities without that stack will select goals but fail to progress movement tasks.
  - NPC prefab unification contract (M13): authored demo NPC entities should instance `scenes/prefabs/prefab_demo_npc.tscn` (inherits `tmpl_character.tscn`) and override only archetype-specific fields (`entity_id`, tags, brain settings, visuals). Runtime body path is `Player_Body` (not legacy `NPC_Body`), and custom CSG visuals under NPC bodies must keep `use_collision = false`.
  - Demo trigger gating contract (M10 audit follow-up): do not gate demo GOAP goals off transient one-frame input fields (for example `camera_center_just_pressed`). Use durable gameplay flags under `gameplay.ai_demo_flags.*` and drive them from authored trigger zones (`Inter_AIDemoFlagZone`) so evaluate-interval scheduling cannot miss triggers.
  - Shared spawn-recovery contract (R5 refactor): recovery settings now live on `C_SpawnRecoveryComponent.settings: RS_SpawnRecoverySettings` (not `RS_AIBrainSettings`). `S_SpawnRecoverySystem` is the canonical unsupported-recovery flow for both player and NPC entities; it tracks startup grace/unsupported delay/cooldown per entity, uses `I_SpawnManager.spawn_at_last_spawn(...)` for player entities when `spawn_point_id` is empty, uses `spawn_entity_at_point(...)` for authored spawn-point entities, clears move vector/body velocity (and AI `task_state` when present), and disables recovery for the session when a configured spawn point is missing.
  - Player-proximity detection contract (M15): `C_DetectionComponent` + `S_AIDetectionSystem` (`execution_priority = -12`) are the canonical range-detection path for AI demo NPCs. Enter/exit state is tracked on the component (`is_player_in_range`, `last_detected_player_entity_id`) and optional enter events publish through `U_ECSEventBus`.
  - Tag-detection self-exclusion contract (AI forest audit): when using `C_DetectionComponent.target_tag` flows, `S_AIDetectionSystem` must skip the detector's own entity during nearest-target resolution (match by entity instance ID with entity-ID fallback) to prevent self-locking at zero distance in same-tag scenarios (for example predator pack detection).
  - Predation consume-lock contract (AI forest audit): predator hunt loops that include `RS_AIActionFeed.consume_detected_target` must lock the prey entity id during move-to-detected (`U_AITaskStateKeys.DETECTED_ENTITY_ID` and `C_DetectionComponent.pending_feed_entity_id`) and consume that locked target first in feed. Hunt-loop completion is not valid unless prey removal occurs (entity unregistered/removed + node freed) alongside hunger refill.
  - Cascading alarm relay contract (M15/R8): `S_DemoAlarmRelaySystem` (`scripts/gameplay/s_demo_alarm_relay_system.gd`, `execution_priority = -11`) listens for `ai_alarm_triggered` and dispatches durable gameplay flags for cross-NPC reactions. Keep this system event-driven and use `U_GameplayActions.set_ai_demo_flag(...)` for flag updates (no navigation-action equivalents).
  - Showcase interaction authoring contract (M15): `gameplay_ai_showcase.tscn` owns interaction trigger nodes (`Inter_AlarmButton`, `Inter_DoorSwitch`, `Inter_GuideCollectible`) and `SO_GuardBarrier` listener wiring; demo NPC prefab instances should set detection component flag IDs per archetype rather than hardcoding trigger logic in systems.
- VFX Event Requests (Phase 1 refactor)
  - Publisher systems translate gameplay events into VFX request events.
  - `M_VFXManager` subscribes to VFX request events and processes queues in `_physics_process()`.
  - Player-only + transition gating: `M_VFXManager` filters requests via `_is_player_entity()` and `_is_transition_blocked()` using Redux `gameplay.player_entity_id`, `scene.is_transitioning`, `scene.scene_stack`, and `navigation.shell == "gameplay"`.
  - `U_DamageFlash` now takes `(flash_rect, owner_node)` and creates tweens through `U_TweenManager` (`TweenConfig.process_mode = TWEEN_PROCESS_IDLE` + explicit `TWEEN_PAUSE_PROCESS`).
  - Use `U_ECSEventNames` constants for subscriptions instead of string literals.
- VFX Tuning Resources (Phase 4)
  - `RS_ScreenShakeTuning` defines trauma decay + damage/landing/death curves; defaults in `resources/vfx/cfg_screen_shake_tuning.tres`.
  - `RS_ScreenShakeConfig` defines shake offset/rotation/noise; defaults in `resources/vfx/cfg_screen_shake_config.tres`.
  - `S_ScreenShakePublisherSystem` reads tuning (export injection optional), `M_VFXManager` uses tuning for decay and config for `U_ScreenShake`.
- VFX Settings Preview (Phase 8)
  - `M_VFXManager` supports temporary overrides via `set_vfx_settings_preview(...)` and `clear_vfx_settings_preview()`.
  - `UI_VFXSettingsOverlay` pushes preview updates on toggle/slider changes and calls `trigger_test_shake()` on intensity changes; preview is cleared on cancel or overlay exit.
- vCam Runtime Contracts (Documentation Sweep 2026-03)
  - Gameplay camera orchestration authority lives in `docs/vcam_manager/*`; keep camera-runtime behavior aligned to those docs.
  - Refactor architecture contract (Phase 2A-2H / 3A): `S_VCamSystem` is a coordinator and should delegate feature state/runtime to focused helpers instead of reintroducing a monolith. Canonical helper stack:
    - `U_VCamLookInput` (look-input activity filtering + lifecycle)
    - `U_VCamRotation` (runtime yaw/pitch continuity + look smoothing/release + recenter state)
    - `U_VCamOrbitEffects` (look-ahead, ground-relative anchoring, soft-zone, motion gating)
    - `U_VCamResponseSmoother` (response smoothing state/signatures + lifecycle)
    - `U_VCamLandingImpact` (landing event normalization + landing-offset recovery)
    - Coordinator support helpers: `U_VCamRuntimeContext`, `U_VCamRuntimeState`, `U_VCamRuntimeServices`, `U_VCamEffectPipeline`, `U_VCamDebug`
  - `M_CameraManager` integration for gameplay vCam flow is `apply_main_camera_transform(xform)` [new — Phase 9] with `is_blend_active()` [new — Phase 9] gating for transition blends. Both methods must be implemented before vCam can submit gameplay transforms.
  - Blend manager helper contract (Phase 3A): `U_VCamBlendManager` (`scripts/managers/helpers/u_vcam_blend_manager.gd`) is the canonical owner of live-blend/startup-blend state machines (configure/advance/recover/startup queue+resolve/clear). `M_VCamManager` must delegate blend runtime state transitions to this helper.
  - Live blend lifecycle contract (Phase 9 + 3A): `M_VCamManager` dispatches `U_VCamActions` blend lifecycle actions (start/update/complete) through Redux (per channel taxonomy, F5), and blends active/outgoing evaluated results via `U_VCamBlendManager` (which uses `U_VCamBlendEvaluator` for transform/FOV interpolation).
  - Blend observability ordering contract (Phase 12): `M_VCamManager` must dispatch `U_VCamActions.set_active_runtime(...)` before `U_VCamActions.start_blend(...)` during active-camera switches so reducer `blend_to_vcam_id` resolves to the incoming active camera.
  - Frame-handoff contract (Phase 9): `M_VCamManager` must consume frame-stamped submissions (`Engine.get_physics_frames`) and ignore stale previous-frame results; gameplay apply remains `camera_manager.apply_main_camera_transform(...)` only.
  - Reentrant/recovery contract (Phase 9): mid-blend `set_active_vcam()` snapshots the current blended pose as the new "from" source, and invalid blend endpoints must route to `U_VCamActions.record_recovery(...)` reasons (`blend_from_invalid`, `blend_to_invalid`, `blend_both_invalid`) without wedged blend state.
  - `in_fov_zone` now lives in `state.vcam.in_fov_zone`; do not reintroduce legacy `state.camera.in_fov_zone` reads in runtime or tests.
  - Occlusion silhouette preference persists in `vfx.occlusion_silhouette_enabled` and is surfaced in `UI_VFXSettingsOverlay` with localization keys.
  - Occlusion rollout is complete only when both physics-layer naming (`vcam_occludable`) and authored-scene blocker migration are done.
  - Occlusion detector contract (Phase 10A): `U_VCamCollisionDetector` (`scripts/managers/helpers/u_vcam_collision_detector.gd`) is the canonical helper for line-of-sight blocker discovery; it must iterate ray hits with exclusions to return all blockers on the segment, enforce the provided collision mask, resolve collision bodies to `GeometryInstance3D` descendants, and skip freed/invalid colliders safely.
  - Occlusion silhouette-helper contract (Phase 10B): `U_VCamSilhouetteHelper` (`scripts/managers/helpers/u_vcam_silhouette_helper.gd`) is the canonical silhouette lifecycle helper; runtime silhouettes are currently transparency-based (`GeometryInstance3D.transparency`). It must preserve original transparency/material state, apply deterministic silhouette visibility, restore via `remove_silhouette`/`remove_all_silhouettes`, and safely no-op on invalid/freed targets.
  - Occlusion anti-flicker contract (Phase 10C2): `U_VCamSilhouetteHelper.update_silhouettes(...)` is the canonical per-tick silhouette update API and must enforce two-frame apply debounce + one-frame grace removal, treat occluder sets as order-insensitive, and skip per-frame reapplication when the stable occluder set is unchanged.
  - Shared look-input contract is `gameplay.look_input`; `S_TouchscreenSystem` owns touchscreen look dispatch and `S_InputSystem` must not zero-clobber touchscreen-owned move/look payloads.
  - Second-order dynamics contract (Phase 1D): use `U_SecondOrderDynamics` (`scripts/utils/math/u_second_order_dynamics.gd`) for scalar camera response smoothing with `(f, zeta, r)` tuning, frequency clamp (`MIN_FREQUENCY_HZ`), and large-delta stability guard (`MAX_STEP_DELTA_SEC`).
  - Vector dynamics contract (Phase 1E): use `U_SecondOrderDynamics3D` (`scripts/utils/math/u_second_order_dynamics_3d.gd`) as the canonical Vector3 wrapper so x/y/z smoothing stays consistent with scalar dynamics behavior.
  - Response resource contract (Phase 1F): `RS_VCamResponse` (`scripts/resources/display/vcam/rs_vcam_response.gd`) is the canonical tuning source for follow/rotation frequency+damping+initial-response, and runtime consumers should use `get_resolved_values()` for clamped frequency/damping reads.
  - Orbit response-feel contract (Phase 2C1/2C2): `RS_VCamResponse` now also carries orbit look-ahead/auto-level tuning (`look_ahead_distance`, `look_ahead_smoothing`, `auto_level_speed`, `auto_level_delay`). `S_VCamSystem` applies look-ahead as a pre-smoothing position offset sourced from movement velocity (`state.gameplay.entities[*].velocity` first, then movement-component/body fallback) and applies delayed auto-level pitch recenter only for orbit mode; do not derive look-ahead direction from follow-target transform deltas. Look-ahead is only applied while filtered look input is inactive; active look input clears look-ahead state for that vCam.
  - Orbit soft-zone contract (Phase 2C3/2C4/2C5): `U_VCamSoftZone` (`scripts/managers/helpers/u_vcam_soft_zone.gd`) is the canonical projection helper and must run against the active gameplay camera viewport using `unproject_position`/`project_position` at tracked depth with near-plane guard. `S_VCamSystem` applies this correction only for orbit mode and tracks per-vCam hysteresis state in `_soft_zone_dead_zone_state`; do not clear that state from response-null smoothing paths.
  - Orbit ground-relative contract (Phase 2C6): `RS_VCamResponse` carries `ground_relative_enabled`, `ground_reanchor_min_height_delta`, `ground_probe_max_distance`, and `ground_anchor_blend_hz`. `S_VCamSystem` tracks per-vCam dual-anchor state in `_ground_relative_state`; grounded-state resolution is `state.gameplay.entities[*].is_on_floor` first, then character/body fallback; airborne ticks must not overwrite anchor reference, and re-anchor only occurs on landing transitions meeting the configured height delta threshold.
  - Orbit mode resource contract (Phase 2A): `RS_VCamModeOrbit` (`scripts/resources/display/vcam/rs_vcam_mode_orbit.gd`) is the authored baseline for third-person orbit (`distance`, `authored_pitch`, `authored_yaw`, `allow_player_rotation`, `lock_x_rotation`, `lock_y_rotation`, `rotation_speed`, `fov`) and now exposes `get_resolved_values()` as the canonical clamp/sanitation read path for evaluator/runtime consumers. `lock_y_rotation` defaults to `true` in the baseline preset. Keep `rotation_speed` consumption in `S_VCamSystem`, not in evaluator helpers.
  - Mode evaluator contract (Refactor Phase 1C/1I): `U_VCamModeEvaluator.evaluate(...)` supports orbit only and returns `{transform, fov, mode_name}` for valid inputs; null/invalid mode/target inputs must return `{}` without warning-channel noise.
  - vCam component contract (Phase 5A): `C_VCamComponent` (`scripts/ecs/components/c_vcam_component.gd`) is the authoring/runtime bridge. Keep exports for `vcam_id`, priority, mode, target/anchor/path NodePaths, entity-id/tag follow fallbacks, soft-zone/blend/response resources, and `is_active`; runtime yaw/pitch state lives on the component.
  - vCam manager core contract (Phase 5C): `M_VCamManager` (`scripts/managers/m_vcam_manager.gd`) is the single authority for registration and active-camera selection. Selection order is explicit override (`set_active_vcam`) first, then highest priority, then ascending `vcam_id` tie-break. Components with `is_active = false` are excluded and should trigger reselection.
  - vCam active-change observability contract (Phase 5C): on active-camera changes, `M_VCamManager` dispatches `U_VCamActions.set_active_runtime(...)` to the transient `vcam` slice and publishes `U_ECSEventNames.EVENT_VCAM_ACTIVE_CHANGED` through `U_ECSEventBus` with `{vcam_id, previous_vcam_id, mode}` payload, including active-clear transitions (`vcam_id = &""`) when the active camera is removed.
  - vCam invalid-target recovery contract (Phase 6B2): on active vCam target/anchor/evaluator failures (`target_freed`, `path_anchor_invalid`, `anchor_invalid`, `evaluation_failed`), `S_VCamSystem` must dispatch target-validity/recovery observability, publish `EVENT_VCAM_RECOVERY` with `{reason, vcam_id}`, and request manager reselection via `set_active_vcam(&"")` once per recovery transition while holding the last valid submitted camera pose.
  - vCam system core contract (Phase 6A): `S_VCamSystem` (`scripts/ecs/systems/s_vcam_system.gd`) owns per-tick evaluation/submission for active vCams. It reads shared look input from Redux via `U_InputSelectors.get_look_input(state)` and submits same-frame results through `I_VCamManager.submit_evaluated_camera(...)`. When `I_VCamManager.is_blending()` is true, evaluate and submit both active and previous vCam IDs each tick.
  - vCam baseline-FOV sync contract (Orbit UX follow-up 2026-03): `S_VCamSystem` writes active evaluated `result.fov` into the primary `C_CameraStateComponent.base_fov` each tick. Writes must clamp to `1..179`, and missing/non-finite `fov` values must be strict no-ops.
  - vCam target resolution contract (Phase 6A): follow-target resolution priority is NodePath (`follow_target_path`) -> entity ID (`follow_target_entity_id`) -> tag (`follow_target_tag`). Multiple valid tag matches use the first ECS-registration-order entity and emit a debug issue.
  - vCam response smoothing contract (Phase 6A2 + look-smoothing follow-up): `S_VCamSystem` applies `RS_VCamResponse` smoothing per vCam with `U_SecondOrderDynamics3D` position smoothing. Smoothing state is keyed by `vcam_id`, recreated on response tuning changes, reset on mode/follow-target changes, and bypassed entirely when `C_VCamComponent.response` is `null` (raw evaluator passthrough).
  - vCam look smoothing contract (Movement-style follow-up, March 2026): orbit evaluator rotation consumes per-vCam spring-damper look state (`smoothed_yaw`, `smoothed_pitch`, `yaw_velocity`, `pitch_velocity`) using response `rotation_frequency` + `rotation_damping`; `C_VCamComponent.runtime_yaw`/`runtime_pitch` remain raw target values for continuity/contracts, and look state resets on mode/target/response changes plus vCam prune/clear.
  - vCam look-activity filtering contract (Camera Look Smoothing Parity pass, March 2026): `S_VCamSystem` keeps per-vCam `_look_input_filter_state` driven by `RS_VCamResponse` (`look_input_deadzone`, `look_input_hold_sec`, `look_input_release_decay`) to smooth bursty look-input activity for gating/spring state decisions. Runtime yaw/pitch accumulation remains raw-input driven (no synthetic post-release rotation).
  - Orbit release-smoothing contract (Phase 2C7, March 2026): `RS_VCamResponse` carries `look_release_yaw_damping`, `look_release_pitch_damping`, and `look_release_stop_threshold`. `S_VCamSystem` applies these only for orbit no-input ticks by damping existing look-smoothing velocities and clamping near-zero residual velocity to prevent drift.
  - Orbit moving-look smoothing gate contract (Camera Look Smoothing Parity pass, March 2026): orbit follow-position bypass is speed-aware and hysteresis-driven via `RS_VCamResponse` (`orbit_look_bypass_enable_speed`, `orbit_look_bypass_disable_speed`) with per-vCam `_follow_target_motion_state`. Slow/stationary targets keep no-lag bypass; moving targets keep follow smoothing active while rotating.
  - Orbit button-recenter contract (Phase 2C8, March 2026): `camera_center` flows through the shared input slice (`input.camera_center_just_pressed`), and `S_VCamSystem` runs orbit-only short-window recenter interpolation using per-vCam `_orbit_centering_state` (~`0.3s` smoothstep) with manual look suppression while active. Recenter is button-only (no idle auto-center), centering-state lifecycle must remain independent of response-smoothing cleanup, and default gameplay gamepad intent is `camera_center = JOY_BUTTON_RIGHT_STICK (R3)` with `sprint = JOY_BUTTON_LEFT_STICK (L3)`.
  - Touchscreen recenter contract (Phase 2C8 follow-up, March 2026): `UI_MobileControls` detects `camera_center` via empty-space double-tap (`DOUBLE_TAP_MAX_INTERVAL_SEC = 0.30`, `DOUBLE_TAP_MAX_DISTANCE_PX = 72.0`) and exposes one-shot `consume_camera_center_just_pressed()`. `S_TouchscreenSystem` must dispatch `U_InputActions.update_camera_center_state(...)` from that consume API (never hardcode `false`).
  - Gameplay prompt binding contract (Phase 2C8 follow-up, March 2026): gameplay prompt icons are binding-aware (`InputMap` event texture first, registry fallback second) so rebinds update icon/label output at runtime.
  - Orbit room-fade data-layer contract (Phase 2C9, March 2026): `RS_RoomFadeSettings` (`fade_dot_threshold`, `fade_speed`, `min_alpha`) is the canonical room-fade tuning resource with clamped `get_resolved_values()`. `C_RoomFadeGroupComponent` (`RoomFadeGroup`) provides authoring/runtime data (`group_tag`, `fade_normal`, nullable `settings`, `current_alpha`), recursive mesh-target collection from entity hierarchy, and parent-basis world-normal resolution for downstream room-fade systems.
  - Orbit wall-visibility runtime contract (Phase 2C10, April 2026): `S_WallVisibilitySystem` (`scripts/ecs/systems/s_wall_visibility_system.gd`) is a standalone post-vCam system (`execution_priority = 110`) that consumes camera output and gates wall visibility to `state.vcam.active_mode == "orbit"` (non-orbit ticks restore all groups/materials immediately). Camera resolution order is `camera_manager.get_main_camera()` then `Viewport.get_camera_3d()` fallback. `U_WallVisibilityMaterialApplier` (`scripts/utils/lighting/u_wall_visibility_material_applier.gd`) owns shader-override lifecycle (`sh_wall_visibility.gdshader`) and must cache/restore original `material_override` cleanly. The system uses dithered dissolve + vertical clip plane instead of alpha-blending fade. Key features: occlusion corridor (walls between camera and player stay opaque), bucket continuity (adjacent wall segments with same normal fade together), room filtering (only player's room processed), roof handling (roofs inherit wall fade state), mobile tick throttling (every 4th frame on mobile), min_fade cap (walls never fully dissolve), and duplicate target ownership (first-component-wins with warning).
  - Orbit wall-visibility shared-wall ownership contract (Phase 2C11A, April 2026): `S_WallVisibilitySystem` must run a per-tick target-ownership pre-pass before fade/material writes so each target is owned by exactly one component (first component in filtered order wins). Duplicate owners must warn-and-skip (non-fatal), with warning de-duplication per target/component pair per tick. Authored room-fade groups in gameplay scenes should use explicit unique `group_tag` values and avoid multi-group target overlap.
  - Orbit region-visibility data-layer contract (Phase 2C11, March 2026): `RS_RegionVisibilitySettings` (`fade_speed`, `min_alpha`, `aabb_grow`, `aabb_vertical_shrink`) is the canonical region-visibility tuning resource with clamped `get_resolved_values()`. `C_RegionVisibilityComponent` (`RegionVisibility`) provides authoring/runtime data (`region_tag`, nullable `settings`, `current_alpha`, `is_active_region`), recursive mesh-target collection from entity hierarchy, and cached region AABB for player containment checks.
  - Orbit region-visibility runtime contract (Phase 2C11, March 2026): `S_RegionVisibilitySystem` (`scripts/ecs/systems/s_region_visibility_system.gd`) is a standalone pre-room-fade system (`execution_priority = 100`) that gates region visibility to `state.vcam.active_mode == "orbit"` (non-orbit ticks restore all regions to opaque). Player containment uses expanded region AABB. Each system owns its own `U_RoomFadeMaterialApplier` instance; region visibility and room fade operate on disjoint mesh sets (region system only fades non-active regions, room fade only processes the player's room). Public queries: `get_active_region_tags()`, `is_region_faded(tag)`.
  - vCam debug-authoring contract (Post-0f51 retune audit, March 2026): `debug_rotation_logging` is diagnostics-only and must stay disabled in authored gameplay/template scenes; do not commit `.tscn` overrides setting `debug_rotation_logging = true`. Keep regression guard coverage in `tests/unit/style/test_style_enforcement.gd`.
  - vCam rotation continuity contract (Phase 6A.3): `S_VCamSystem` applies runtime yaw/pitch carry/reset/reseed policy on active-vCam switches before evaluation. Same-mode (orbit) switches carry yaw/pitch only when follow targets resolve to the same node, otherwise reseed to incoming authored angles.
  - Camera-state feel scaffolding contract (Phase 6A3a): `C_CameraStateComponent` now exposes `landing_impact_offset`, `landing_impact_recovery_speed`, `speed_fov_bonus`, and `speed_fov_max_bonus` as runtime fields consumed by upcoming QB camera-feel phases. Keep these fields included in `reset_state()` and `get_snapshot()` so runtime resets and debugging snapshots stay consistent.
  - Camera-state speed-FOV contract (Phase 6A3b): `S_CameraStateSystem` composes final FOV as `base_target + clamp(speed_fov_bonus, 0.0, speed_fov_max_bonus)` and remains the sole writer of `camera.fov`. Default speed breathing is authored by `resources/qb/camera/cfg_camera_speed_fov_rule.tres`; keep that rule in `DEFAULT_RULE_DEFINITIONS`, feed movement speed through camera-rule context (`C_MovementComponent` snapshot), and preserve `RS_EffectSetField.scale_by_rule_score` winner-score scaling for proportional bonus output.
  - Camera-state landing-impact contract (Phase 6A3c): default landing dip is authored by `resources/qb/camera/cfg_camera_landing_impact_rule.tres` and must stay in `S_CameraStateSystem.DEFAULT_RULE_DEFINITIONS`. Event-mode evaluation must prefilter rules by subscribed event name before scoring/winner selection to avoid cross-event effects when thresholds allow zero-score winners. `RS_EffectSetField` now supports `vector3` score-scaled writes for `landing_impact_offset`, and `S_VCamSystem` applies/recover-writes that offset with `U_SecondOrderDynamics3D` at `landing_impact_recovery_speed`.
  - Keyboard-look contract (Phase 0A2): use dedicated `look_left/right/up/down` actions (not `ui_*`); settings live in `settings.input_settings.mouse_settings` (`keyboard_look_enabled`, `keyboard_look_speed`) and surface through `UI_KeyboardMouseSettingsOverlay`.
  - Touch look gating contract (Phase 7A/7B/7B2/7C): `UI_MobileControls` owns free-screen drag-look tracking and exposes `consume_look_delta()` + `is_touch_look_active()`. `S_TouchscreenSystem` dispatches touchscreen look deltas via `U_InputActions.update_look_input(...)` and toggles `U_GameplayActions.set_touch_look_active(...)` on gesture lifecycle changes. `S_InputSystem` must hard-skip touchscreen-active ticks so touch-owned move/look/button payloads are not zero-clobbered by `TouchscreenSource`.
  - Silhouette routing contract (Phase 10B2): `M_VCamManager` publishes `EVENT_SILHOUETTE_UPDATE_REQUEST` from active-camera submission using `U_VCamCollisionDetector` results and payload `{entity_id, occluders, enabled}`; `M_VFXManager` is the sole subscriber/applicator and must gate enabled updates with `_is_player_entity()` + `_is_transition_blocked()` before delegating to `U_VCamSilhouetteHelper`. Explicit disable/clear requests (`enabled = false`) must bypass transition blocking so stale silhouettes are always torn down.
  - Silhouette runtime apply contract (Phase 10C2): `M_VFXManager` must route silhouette payload processing through `U_VCamSilhouetteHelper.update_silhouettes(...)`; do not reintroduce per-frame `remove_all + apply` loops that churn stable occluders.
  - Per-tick occlusion integration contract (Phase 10C): `M_VCamManager` must consult `U_VFXSelectors.is_occlusion_silhouette_enabled(...)` before occluder detection and publish `enabled=false` clear requests when silhouettes are disabled or transition blend ownership blocks gameplay camera submission.
  - Editor preview contract (Phase 11): `U_VCamRuleOfThirdsPreview` (`scripts/utils/display/u_vcam_rule_of_thirds_preview.gd`) is the canonical editor-only thirds-grid helper for camera authoring. Keep it `@tool`, render through an internal `CanvasLayer` + draw control, and `queue_free()` outside editor so runtime has zero preview overhead.
  - Silhouette count observability contract (Phase 10C2): `silhouette_active_count` dispatch is renderer-owned in `M_VFXManager` and must be sourced from `U_VCamSilhouetteHelper.get_active_count()` after debounce/grace filtering (dispatch only on count changes, including clear-to-`0` on runtime teardown paths).
- **Testing with Dependency Injection (Phase 10B-8)**
  - Systems support `@export` dependency injection for isolated testing with mocks.
  - **Inject ECS manager**: All systems inherit `@export var ecs_manager: I_ECSManager` from BaseECSSystem.
  - **Inject state store**: 9 state-dependent systems have `@export var state_store: I_StateStore` (S_HealthSystem, S_VictorySystem, S_CheckpointSystem, S_InputSystem, S_GamepadVibrationSystem, S_GravitySystem, S_MovementSystem, S_JumpSystem, S_RotateToInputSystem).
  - **Injection priority chain**: U_StateUtils.get_store() and U_ECSUtils.get_manager() check @export injection first, then fall back to ServiceLocator. Production code unchanged (auto-discovery if not injected).
  - **Mock classes**: Use `MockStateStore` and `MockECSManager` from `tests/mocks/` for isolated testing.
  - **Example test pattern**:
    ```gdscript
    var mock_manager := MockECSManager.new()
    var mock_store := MockStateStore.new()
    var system := S_HealthSystem.new()
    system.ecs_manager = mock_manager  # Inject via @export
    system.state_store = mock_store    # Inject via @export
    # Test system in isolation without real managers
    ```
  - **Mock helpers**: `MockStateStore.get_dispatched_actions()` verifies actions; `MockStateStore.set_slice()` sets up test state; `MockECSManager.add_component_to_entity()` populates components.
- Manager
  - Ensure exactly one `M_ECSManager` in-scene. It registers with ServiceLocator on `_ready()`.
  - Emits `component_added`/`component_removed` and calls `component.on_registered(self)`.
  - `get_components()` strips out null entries automatically; only guard for missing components when logic truly requires it.
  - Entity root caching is dictionary-backed in `M_ECSManager`/`U_ECSUtils` (no metadata tags); `BaseECSEntity` registers itself with the manager for lookups.
- Entities (Phase 6 - Entity IDs & Tags)
  - All entities extend `BaseECSEntity` (Node3D with entity_id and tags exports).
  - **Entity IDs**: Auto-generated from node name (`E_Player` → `"player"`), or manually set via `entity_id` export. Cached after first access. Duplicate IDs automatically get `_{instance_id}` suffix.
  - **Tags**: Freeform `Array[StringName]` for categorization. Use `add_tag(tag)`, `remove_tag(tag)`, `has_tag(tag)` to modify. Tags auto-update manager's tag index.
  - **Manager queries**: `get_entity_by_id(id)`, `get_entities_by_tag(tag)`, `get_entities_by_tags(tags, match_all)`.
  - **Auto-registration**: Entities automatically register with `M_ECSManager` when their first component registers. Publishes `"entity_registered"` event to `U_ECSEventBus`.
  - **State integration**: `U_ECSUtils.build_entity_snapshot(entity)` includes entity_id and tags for Redux persistence.
  - Example: `player.entity_id = StringName("player"); player.tags = [StringName("player"), StringName("controllable")]`

## Scene Organization

- **Root scene pattern (NEW - Phase 2)**: `scenes/root.tscn` persists throughout session
  - Persistent managers: `M_StateStore`, `M_CursorManager`, `M_SceneManager`
  - Scene containers: `GameViewportContainer/GameViewport/ActiveSceneContainer`, `UIOverlayStack`, `TransitionOverlay`, `LoadingOverlay`
  - Gameplay scenes load/unload as children of `GameViewportContainer/GameViewport/ActiveSceneContainer`
  - Container service registration contract (Phase 4 UI/Layers refactor): `root.gd` registers `hud_layer`, `ui_overlay_stack`, `transition_overlay`, `loading_overlay`, `game_viewport`, `active_scene_container`, and `post_process_overlay` via `U_ServiceLocator`.
  - Test harness contract for strict container discovery: lightweight tests that instantiate scenes outside `root.tscn` must register required container services (at minimum `hud_layer` for HUD-bearing scenes, plus any container consumed by the path under test).
  - Scene/container discovery contract: `U_SceneManagerNodeFinder` and display post-process setup are ServiceLocator-only; do not add `find_child()` fallbacks for these container lookups.
  - HUD transition-decoupling contract (Phase 5): `UI_HudController` visibility is Redux-driven (`scene.is_transitioning` + `navigation.shell == "gameplay"`). Transition effects (including `Trans_LoadingScreen`) must not hide/show HUD directly, and `I_SceneManager` no longer exposes HUD registration/getter APIs.
  - HUD lifecycle contract (Phase 6): `M_SceneManager` instantiates `scenes/ui/hud/ui_hud_overlay.tscn` under `hud_layer`; gameplay templates/scenes must not embed HUD instances, and `UI_HudController` must not self-reparent.
- Mobile touch controls: `scenes/ui/mobile_controls.tscn` CanvasLayer lives in root; shows virtual joystick/buttons on mobile or `--emulate-mobile`, hides during transitions/pause/gamepad input
- CanvasLayer constants are centralized in `scripts/ui/u_canvas_layers.gd`; script-authored layer assignments should use these constants instead of raw numbers.
- **Gameplay scenes**: Each has own `M_ECSManager` instance
  - Example: `scenes/gameplay/gameplay_base.tscn`
  - Contains: Systems, Entities, SceneObjects, Environment
  - If a gameplay scene instances `tmpl_camera.tscn`, `Systems/Core` must include `S_VCamSystem` with `execution_priority = 100` (parity with `gameplay_base`, `gameplay_bar`, `gameplay_alleyway`, `gameplay_exterior`, and `gameplay_interior_house`).
  - HUD is root-managed under `HUDLayer` by `M_SceneManager`; gameplay scenes must not embed HUD nodes.
  - UI controllers (including HUD) use `U_StateUtils.get_store(self)` for `M_StateStore` lookup (or injected store).
- Node tree structure: See `docs/scene_organization/SCENE_ORGANIZATION_GUIDE.md`
- Templates: `scenes/templates/tmpl_base_scene.tscn`, `scenes/templates/tmpl_character.tscn`, `scenes/templates/tmpl_camera.tscn`
- Marker scripts: `scripts/scene_structure/*` (11 total) provide visual organization
- Systems organized by category: Core / Physics / Movement / Feedback
- Naming: Node names use prefixes matching their script types (E_, Inter_, S_, C_, M_, SO_, Env_)

### UI Theme Pipeline (UI Visual Overhaul Phase 0)

- `RS_UIThemeConfig` (`scripts/resources/ui/rs_ui_theme_config.gd`) is the canonical theme contract; default instance is `resources/ui/cfg_ui_theme_default.tres`.
- `U_UIThemeBuilder` (`scripts/ui/utils/u_ui_theme_builder.gd`) is the single composition point for UI themes:
  - Input: base font theme from `U_LocalizationFontApplier`, optional `RS_UIColorPalette`, required `RS_UIThemeConfig`.
  - Output: merged `Theme` containing fonts, text colors, spacing constants, and styleboxes.
  - Runtime-default contract: call `RS_UIThemeConfig.ensure_runtime_defaults()` inside `U_UIThemeBuilder` before stylebox application so loaded config resources hydrate missing styleboxes consistently on mobile/export builds.
- Root bootstrap contract: `scripts/root.gd` sets `U_UIThemeBuilder.active_config` on enter/ready; only the persistent app root (`Managers/M_StateStore` present) clears it on exit. Non-persistent gameplay roots must not clear global theme config.
- `U_DisplayUIThemeApplier` no longer owns a standalone applied theme in unified mode; it stores active palette state and rebuilds registered UI roots through `U_UIThemeBuilder`.
- Backward-compat contract: when `U_UIThemeBuilder.active_config` is `null`, localization and display theming keep legacy behavior (font-only localization theme + palette-only display theme).
- Palette bootstrapping contract: when unified mode is active and palette has not been applied yet, `U_UIThemeBuilder` should still apply config text colors for roots missing explicit font colors while preserving existing base-theme colors when present.
- Settings-tab tokenization contract (Phase 3 Screen 14): tabs embedded inside settings wrappers (for example `UI_LocalizationSettingsTab`) should remove inline `theme_override_*` constants and apply spacing/typography tokens in script via `U_UIThemeBuilder.active_config` + `RS_UIThemeConfig` (`separation_default`, `separation_compact`, `heading`, `section_header`, `body_small`, semantic text colors).
- HUD tokenization contract (Phase 4 Screen 17): `scenes/ui/hud/ui_hud_overlay.tscn` should not keep inline `theme_override_*` entries. Apply HUD margins/typography/surface tokens in `UI_HudController._apply_theme_tokens()`. Health bar background should come from themed `ProgressBar.background`; health fill stays palette-driven via `_update_health_bar_colors(...)`.
- Button-prompt tokenization contract (Phase 4 Screen 18): `scenes/ui/hud/ui_button_prompt.tscn` should not keep inline `theme_override_*` entries. Apply prompt spacing/panel/typography tokens in `UI_ButtonPrompt._apply_theme_tokens()` using `separation_default`, `panel_button_prompt`, `subheading`, `body`, and `caption_small`.
- Inline-override policy (Phase 5A): do not reintroduce non-semantic `theme_override_*` lines in `scenes/ui/**`. `tests/unit/style/test_style_enforcement.gd::test_no_inline_theme_overrides_except_semantic` enforces this. Current semantic exceptions are intentional (`ui_virtual_button.tscn`, signpost golden callout text, and danger/error emphasis labels).

### UI Motion Pipeline (UI Visual Overhaul Phase 0)

- Motion resources are data-driven and opt-in:
  - `RS_UIMotionPreset` (`scripts/resources/ui/rs_ui_motion_preset.gd`) defines one tween step (property, from/to, duration, delay, interval, transition/ease, parallel flag).
  - `RS_UIMotionSet` (`scripts/resources/ui/rs_ui_motion_set.gd`) groups motion sequences by interaction (`enter`, `exit`, `hover_in/out`, `press`, `focus_in/out`, `pulse`).
- `U_UIMotion` (`scripts/ui/utils/u_ui_motion.gd`) is the canonical playback helper:
  - `play(node, presets)` supports sequential steps by default, optional parallel steps, and interval-only hold steps.
  - `play_enter(...)` / `play_exit(...)` / `play_pulse(...)` delegate to `RS_UIMotionSet` lifecycle/interaction arrays.
  - `append_step(tween, node, preset)` is the public single-step API for custom tween composition (used by `UI_HudController` for interleaved toast/signpost sequences).
  - `bind_interactive(control, motion_set)` wires hover/focus/press signals without duplicating existing connections.
- Default authored presets live under `resources/ui/motions/` (`cfg_motion_fade_slide.tres`, `cfg_motion_button_default.tres`) and are intended as baseline feel, not hard requirements.
- HUD feedback motion contract (Phase 4 Screen 17): checkpoint/signpost timing is data-driven through `cfg_motion_hud_checkpoint_toast.tres`, `cfg_motion_hud_signpost_fade_in.tres`, and `cfg_motion_hud_signpost_fade_out.tres`; avoid reintroducing hardcoded HUD fade durations in `UI_HudController`.
- Base-class integration contract (Phase 0F):
  - `BasePanel.motion_set` is opt-in; when set, focusable child controls are bound via `U_UIMotion.bind_interactive(...)`.
  - `BaseMenuScreen.play_enter_animation()` / `play_exit_animation()` delegate to `U_UIMotion` using a resolved motion target:
    - explicit `motion_target_path` when exported/set,
    - otherwise auto-target `CenterContainer` when a backdrop (`Background` / `OverlayBackground` / `ColorRect`) and `PanelContainer` are present,
    - otherwise fallback to the screen root.
  - Prefer this default backdrop-fade + panel-slide behavior over per-screen motion overrides for centered panel screens.
  - `BaseOverlay` animates its dim `OverlayBackground` alpha in parallel with content enter/exit motion.
  - `BaseOverlay` background contract: prefer `background_color` + auto-created `OverlayBackground`; do not keep an extra full-screen `Background` `ColorRect` unless `auto_create_background = false`, or dim opacity will stack.
  - `UI_SettingsMenu` dual-mode dim contract (Phase 2 Screen 7): apply `bg_base` dim at alpha `0.7` only when `navigation.overlay_stack` top is `settings_menu_overlay`; keep dim alpha `0.0` when the same scene is embedded under main-menu settings.
- Backward-compat motion contract: `motion_set = null` must remain a strict no-op (no signal binding side effects, no tween playback). This preserves pre-overhaul behavior for screens/controllers that opt out of motion resources.

### Interactable Controllers

- Controllers live in `scripts/gameplay/` and replace ad-hoc `C_*` nodes; create a single `Inter_*` controller per interactable (node names may remain `E_*` in scenes):
  - Base stack: `base_volume_controller.gd`, `base_interactable_controller.gd`, `triggered_interactable_controller.gd`
  - Concrete controllers: `inter_door_trigger.gd`, `inter_checkpoint_zone.gd`, `inter_hazard_zone.gd`, `inter_victory_zone.gd`, `inter_signpost.gd`, `inter_endgame_goal_zone.gd`
- Controllers auto-create/adopt `Area3D` volumes using `RS_SceneTriggerSettings`—never author separate component or Area children manually.
- `triggered_interactable_controller.gd` publishes `interact_prompt_show` / `interact_prompt_hide` events; HUD renders the prompt label.
- `inter_signpost.gd` emits `signpost_message` events; HUD reuses the checkpoint toast UI for signpost text.
- Exterior/interior scenes are now fixtures built on controllers; core flow routes through `gameplay_base` instead of these fixtures.
- Controller `settings` are auto-duplicated (`resource_local_to_scene = true`). Assign shared `.tres` files freely—each controller keeps a unique copy.
- Interaction config schema resources live in `scripts/resources/interactions/` (`rs_*_interaction_config.gd`) with authored instances under `resources/interactions/**` (`cfg_*.tres`).
- Validate config resources with `scripts/gameplay/helpers/u_interaction_config_validator.gd` before binding them to controllers.
- Phase 5 config-binding pattern: interaction controllers are config-driven only. Legacy interaction export fallbacks (`door_id`, `checkpoint_id`, damage/victory/signpost literals, `required_area`) were removed; provide typed `config` resources in scenes/prefabs and treat those resources as the single source of truth.
- Phase 3 scene-authoring pattern: gameplay/prefab `Inter_*` nodes should bind `config = ExtResource("res://resources/interactions/.../cfg_*.tres")` and avoid duplicating door/checkpoint/hazard/victory/signpost literals directly in `.tscn` nodes.
- Passive volumes (`E_CheckpointZone`, `E_HazardZone`, `E_VictoryZone`) keep `ignore_initial_overlap = false` so respawns inside the volume re-register automatically. Triggered interactables (doors, signposts) leave it `true` to avoid instant re-activation.
- Use `visual_paths` to toggle meshes/lights/particles when controllers enable/disable; keep visuals as controller children instead of wiring extra logic nodes.
- Controllers run with `process_mode = PROCESS_MODE_ALWAYS` and will not activate while `scene.is_transitioning` or `M_SceneManager.is_transitioning()` is true.

### Character Lighting (Phase 1-5)

- Lighting resource scripts live under `scripts/resources/lighting/` with `rs_` prefixes.
- `RS_CharacterLightingProfile` is the base data contract; use `get_resolved_values()` for clamped runtime values (`tint`, `intensity`, `blend_smoothing`) instead of reading raw exports directly in blend code.
- `RS_CharacterLightZoneConfig` is the zone-side contract; use `get_resolved_values()` for clamped dimensions/weights and deep-copied `profile` snapshots.
- Blend calculations live in `scripts/utils/lighting/u_character_lighting_blend_math.gd` (`U_CharacterLightingBlendMath`):
  - Deterministic ordering: priority desc, weight desc, zone_id asc.
  - Weighted blending normalizes source weights.
  - Empty/invalid zone inputs fall back to a sanitized default profile.
- `Inter_CharacterLightZone` extends `BaseVolumeController` and remains config-driven:
  - Build runtime `RS_SceneTriggerSettings` from `RS_CharacterLightZoneConfig` in `_apply_config_to_volume_settings()`.
  - Use `resource_local_to_scene = true` for generated trigger settings.
  - Keep passive overlap behavior (`ignore_initial_overlap = false`) so spawn-inside zones still apply.
  - Auto-register/unregister with `character_lighting_manager` in `_ready()`/`_exit_tree()` so zones authored outside `Lighting` (goal/signpost/prefab hierarchies) are still consumed by the manager.
- Influence sampling contract for manager consumption:
  - `get_influence_weight(world_position)` returns shape-aware weight (box/cylinder) with falloff and transition gating.
  - `get_zone_metadata()` returns deterministic cache inputs (`zone_id`, `stable_key`, `priority`, `blend_weight`, deep-copied `profile` snapshot).
- Material application helper lives in `scripts/utils/lighting/u_character_lighting_material_applier.gd` (`U_CharacterLightingMaterialApplier`):
  - `collect_mesh_targets(entity)` recursively gathers `MeshInstance3D` nodes with valid mesh resources.
  - `apply_character_lighting(...)` swaps each target to `ShaderMaterial` using `assets/shaders/sh_character_zone_lighting.gdshader`, carries forward `albedo_texture`, and sets `base_tint`, `effective_tint`, `effective_intensity`.
  - Missing mesh/material/albedo texture is a deliberate no-op (skip target, do not cache).
  - Teardown contract: call `restore_character_materials(entity)` on entity cleanup and `restore_all_materials()` on broader scene teardown.
- `M_CharacterLightingManager` runtime pattern (Phase 4):
  - Discovers dependencies via injection-first + ServiceLocator fallback (`state_store`, `scene_manager`, `ecs_manager`).
  - Discovers active scene lighting data from `ActiveSceneContainer/<GameplayScene>/Lighting`.
  - Resolves scene defaults from `Lighting/CharacterLightingSettings.default_profile` when available, otherwise sanitized white/default fallback profile.
  - Listens for `scene/swapped` via `state_store.action_dispatched` and marks lighting caches dirty for next physics tick.
  - Discovers character targets from ECS tag query (`get_entities_by_tag("character")`) and restores materials for removed/non-3D entities.
  - Applies transition gating via Redux scene/navigation slices and `scene_manager.is_transitioning()`; blocked frames restore all character lighting overrides.
- Phase 8 stabilization pattern:
  - Boundary hysteresis is per character/per zone key with a deadband (`enter >= 0.02`, `exit < 0.01`) to reduce edge flicker.
  - Temporal smoothing uses blended `blend_smoothing` per character (`alpha = 1.0 - blend_smoothing`) for tint/intensity transitions.
  - Clear smoothing/hysteresis runtime state whenever lighting is blocked/disabled or scene bindings are refreshed so stale history does not bleed across transitions.
- Phase 5 scene-authoring pattern:
  - Every migrated gameplay scene should provide `Lighting/CharacterLightingSettings` with a `default_profile` (`RS_CharacterLightingProfile`) resource.
  - Author light zones as explicit `Inter_CharacterLightZone` nodes with scene/prefab `config = ExtResource("res://resources/lighting/zones/cfg_*.tres")`.
  - Keep authoring data split into reusable resources:
    - `resources/lighting/profiles/cfg_character_lighting_profile_*.tres`
    - `resources/lighting/zones/cfg_character_light_zone_*.tres`
  - Replace character-driving `OmniLight3D` nodes (mood/objective/signpost) only after equivalent zone config is present; preserve non-light visuals (`Visual`, `Sparkles`, meshes) for readability.

## Naming Conventions Quick Reference

**IMPORTANT**: All production scripts, scenes, and resources must follow documented prefix patterns. As of Phase 5 Complete (2025-12-08), 100% prefix compliance achieved - all files follow their respective prefix patterns. See `docs/general/STYLE_GUIDE.md` for the complete prefix matrix.

- **Base classes:** `base_*` prefix (e.g., `base_ecs_component.gd` → `BaseECSComponent`, `base_panel.gd` → `BasePanel`)
- **Utilities:** `u_*` prefix (e.g., `u_ecs_utils.gd` → `U_ECSUtils`, `u_entity_query.gd` → `U_EntityQuery`)
- **Managers:** `m_*` prefix (e.g., `m_ecs_manager.gd` → `M_ECSManager`, `m_state_store.gd` → `M_StateStore`)
- **Components:** `c_*` prefix (e.g., `c_movement_component.gd` → `C_MovementComponent`)
- **Systems:** `s_*` prefix (e.g., `s_gravity_system.gd` → `S_GravitySystem`)
- **Resources:** `rs_*` prefix (e.g., `rs_jump_settings.gd` → `RS_JumpSettings`)
- **QB Condition Resources:** `rs_condition_*` prefix under `scripts/resources/qb/conditions/` (e.g., `rs_condition_redux_field.gd` → `RS_ConditionReduxField`)
- **QB Effect Resources:** `rs_effect_*` prefix under `scripts/resources/qb/effects/` (e.g., `rs_effect_set_field.gd` → `RS_EffectSetField`)
- **Entities:** `e_*` prefix (e.g., `e_player.gd` → `E_Player`)
- **Interactable Controllers:** `inter_*` prefix (e.g., `inter_door_trigger.gd` → `Inter_DoorTrigger`)
- **UI Scripts:** `ui_*` prefix (e.g., `ui_main_menu.gd` → `UI_MainMenu`)
- **Marker Scripts:** `marker_*` prefix (e.g., `marker_entities_group.gd`, `marker_active_scene_container.gd`)
- **Transitions:** `trans_*` prefix (e.g., `trans_fade.gd` → `Trans_Fade`)
- **Interfaces:** `i_*` prefix (e.g., `i_scene_contract.gd` → `I_SCENE_CONTRACT`)
- **Prefabs:** `prefab_*` prefix for scenes (e.g., `prefab_death_zone.tscn`)

### Resource Instance and Asset Prefixes

Resource **instances** (`.tres` files) use `cfg_` prefix to distinguish from Resource **class definitions** (`.gd` files use `rs_`):
- `cfg_movement_default.tres` = instance of `RS_MovementSettings` class
- `cfg_jump_default.tres` = instance of `RS_JumpSettings` class
- `cfg_gameplay_base_entry.tres` = scene registry entry

Production asset files use type-specific prefixes:
- `tex_` = textures (e.g., `tex_shadow_blob.png`)
- `mus_` = music (e.g., `mus_main_menu.ogg`)
- `sfx_` = sound effects (e.g., `sfx_jump.wav`)
- `amb_` = ambient sounds (e.g., `amb_exterior.wav`)
- `fst_` = footsteps (e.g., `fst_grass_01.wav`)
- `icn_` = editor icons (e.g., `icn_component.svg`)
- `fnt_` = fonts (e.g., `fnt_ui_default.ttf`)

**Test assets:** Placeholder assets for testing live in `tests/assets/audio/` and `tests/assets/textures/` (moved from production `assets/` during cleanup v4.5).

### Helper Extraction Pattern (Large Files)

- When core scripts approach 400–500 lines, prefer extracting pure helpers instead of adding more responsibilities:
  - Scene management helpers: `scripts/scene_management/helpers/u_scene_registry_loader.gd`
  - Input helpers: `scripts/managers/helpers/u_input_profile_loader.gd`
  - ECS helpers: `scripts/utils/ecs/u_ecs_query_metrics.gd`
  - UI helpers/builders: `scripts/ui/helpers/u_rebind_action_list_builder.gd`, `scripts/ui/helpers/u_touchscreen_preview_builder.gd`
- Helper scripts:
  - Live under a `helpers/` subdirectory next to their parent domain.
  - Use existing prefixes (`u_` for utilities/loaders) plus a descriptive suffix (e.g., `_loader`, `_builder`, `_metrics`).
  - Expose small, focused APIs that keep managers/systems under ~400 lines while preserving behavior.

## Conventions and Gotchas

- **Groups are NOT used**
  - This codebase does NOT use Godot's groups feature for manager discovery or node organization
  - Use `U_ServiceLocator` for all manager lookups instead of `get_tree().get_first_node_in_group()`
  - Groups add hidden coupling that's hard to track; ServiceLocator provides explicit registration with O(1) lookup
- GDScript typing
  - Annotate locals receiving Variants (e.g., from `Callable.call()`, `JSON.parse_string`, `Time.get_ticks_msec()` calc). Prefer explicit `: float`, `: int`, `: Dictionary`, etc.
  - Use `StringName` for action/component identifiers; keep constants like `const MOVEMENT_TYPE := StringName("C_MovementComponent")`.
- Time helpers
  - For ECS timing, call `U_ECSUtils.get_current_time()` (seconds) instead of repeating `Time.get_ticks_msec() / 1000.0`.
- Copy semantics
  - Use `.duplicate(true)` for deep copies of `Dictionary`/`Array` before mutating; the codebase relies on immutability patterns both in ECS snapshots and state.
- Scenes and NodePaths
- Wire `@export` NodePaths in scenes; missing paths intentionally short-circuit behavior in systems. See `scenes/templates/tmpl_character.tscn` + `scenes/prefabs/prefab_player.tscn` for patterns.
- Resources
  - New exported fields in `*Settings.gd` require updating default `.tres` under `resources/base_settings/` and any scene using them.
  - Trigger settings automatically clamp `player_mask` to at least layer 1; configure the desired mask on the resource instead of zeroing it at runtime.
- Tabs and warnings
  - Keep tab indentation in `.gd` files; tests use native method stubs on engine classes—suppress with `@warning_ignore("native_method_override")` where applicable (details in `docs/general/developer_pitfalls.md`).
- State store batching and input persistence
  - `M_StateStore` emits `slice_updated` once per physics frame; do not also flush on idle frames.
  - Actions that need same-frame visibility (e.g., input rebinds) must set `"immediate": true` on the dispatched payload; the store now flushes batched slice updates immediately for these actions.
  - Gameplay input fields are transient across scene transitions (StateHandoff) but are persisted to disk on save/load.
  - Global settings persist via `user://global_settings.json` (display/audio/vfx/input + gameplay preferences). Controlled by `RS_StateStoreSettings.enable_global_settings_persistence`; legacy `audio_settings.json`/`input_settings.json` migrate on load.
  - In non-persistence tests, set `store.settings.enable_persistence = false` before adding `M_StateStore` to the tree to avoid ambient `user://savegame.json` autoload side effects.
- State load normalization
  - `M_StateStore.load_state()` sanitizes unknown `current_scene_id`, `target_spawn_point`, and `last_checkpoint` values, falling back to `gameplay_base` / `sp_default` and deduping `completed_areas`.
- Style enforcement
  - `tests/unit/style/test_style_enforcement.gd` fails on leading spaces in gameplay/state/ui scripts and verifies trigger resources include `script = ExtResource(...)`.
- InputMap
  - The `interact` action must remain in `project.godot`; HUD/process prompts run in `PROCESS_MODE_ALWAYS` to stay responsive when the tree is paused.
  - Device detection is centralized in `M_InputDeviceManager`; gameplay systems read `U_InputSelectors.get_active_device_type()` / `get_active_gamepad_id()` instead of dispatching their own `device_changed` actions.
  - Rebinding flows must dispatch via Redux (`U_InputActions.rebind_action`)—`M_InputProfileManager` now derives InputMap state from the store, so avoid mutating InputMap directly in UI code.
  - `S_InputSystem` only gates input on cursor capture for desktop platforms; on mobile (`OS.has_feature("mobile")`), do not depend on `Input.mouse_mode` for gamepad routing so Bluetooth controllers remain functional when MobileControls hides the touchscreen UI.
- Input Source Abstraction (Phase 10B-4 - Device Polymorphism)
  - **Centralized device types**: `U_DeviceTypeConstants.DeviceType` enum (KEYBOARD_MOUSE, GAMEPAD, TOUCHSCREEN) replaces local enums
  - **IInputSource interface**: All input devices implement `get_device_type()`, `get_priority()`, `is_active()`, `capture_input()`
  - **Source implementations**:
    - `KeyboardMouseSource`: Priority 1, captures keyboard vector + mouse delta
    - `GamepadSource`: Priority 2, handles stick deadzones + button states
    - `TouchscreenSource`: Priority 3, delegates to MobileControls virtual input
  - **M_InputDeviceManager**: Registers sources at startup, delegates input events to appropriate source
  - **S_InputSystem**: Queries active source from manager, delegates `capture_input()` call, writes to components
  - **Adding new devices (e.g., VR)**: Create new source class extending `I_InputSource`, register in `M_InputDeviceManager._register_input_sources()`
  - **Pattern**:
    ```gdscript
    # In M_InputDeviceManager
    var source := _input_device_manager.get_input_source_for_device(active_device_type)
    var input_data := source.capture_input(delta)  # {move_input, look_input, jump_pressed, etc.}
    ```
- Button Prompt Patterns (Phase 1 - Generic Glyphs)
  - **Registry handles texture loading**: `U_ButtonPromptRegistry.get_prompt(action, device_type)` returns cached Texture2D for registered actions
  - **Automatic fallback**: When texture unavailable, ButtonPrompt falls back to text label
  - **Texture priority**: Show texture if available, otherwise show text binding label
  - **Caching**: Textures loaded once and cached in registry for performance
  - **Device switching**: ButtonPrompt automatically updates texture when device changes
  - **Texture display**: TextureRect with 32x32 minimum size, aspect ratio preserved (STRETCH_KEEP_ASPECT_CENTERED)
  - **Usage**:
    ```gdscript
    button_prompt.show_prompt(StringName("interact"), "Open Door")
    # Shows texture for current device, falls back to text if unavailable
    ```
  - **Note**: Textures are mapped to actions, not specific key bindings. When user rebinds an action, the texture remains the same (shows action's registered glyph, not the new key).

## Localization Manager Patterns (Phase 6 Refactor)

- Catalog ownership moved to `scripts/managers/helpers/localization/u_localization_catalog.gd` (`U_LocalizationCatalog`):
  - uses const-preloaded `RS_LocaleTranslations` resources (mobile-safe, no runtime file IO)
  - merges by locale with deterministic last-wins behavior on duplicate keys
  - applies fallback chain `requested -> en` before key fallback
  - caches merged catalogs and exposes `clear_cache()` / `force_refresh` for invalidation
- `M_LocalizationManager` should consume `U_LocalizationCatalog` directly for locale loads.
- `scripts/managers/helpers/u_locale_file_loader.gd` is now a compatibility shim; avoid adding new production call sites to it.
- Font/theme ownership moved to `scripts/managers/helpers/localization/u_localization_font_applier.gd` (`U_LocalizationFontApplier`):
  - `build_theme(locale, dyslexia_enabled)` resolves active font with CJK priority (`zh_CN`, `ja`) over dyslexia toggle
  - `apply_theme_to_root(root, theme)` handles `Control` roots and `CanvasLayer` direct `Control` children
  - use `load()` for `.ttf`/`.otf` assets and treat missing fonts as no-op (null theme)
- Root lifecycle ownership moved to `scripts/managers/helpers/localization/u_localization_root_registry.gd` (`U_LocalizationRootRegistry`):
  - use registry APIs for `register_root`, `unregister_root`, and `notify_locale_changed`
  - registry prunes dead nodes before iteration; manager should not mutate root arrays directly
- Preview ownership moved to `scripts/managers/helpers/localization/u_localization_preview_controller.gd` (`U_LocalizationPreviewController`):
  - use helper APIs for `start_preview`, `clear_preview`, `is_preview_active`, and preview value resolution
  - while preview is active, localization managers must ignore Redux `slice_updated` events for the localization slice
- UI scale ownership moved to `M_DisplayManager`:
  - compute effective UI scale from display + localization slices (`display.ui_scale * localization.ui_scale_override`)
  - `M_LocalizationManager` must not dispatch `display/*` actions for locale changes
- Locale label localization pattern (Phase 7):
  - use shared `locale.name.*` keys for language names in both `UI_LocalizationSettingsTab` and `UI_LanguageSelector`
  - avoid hardcoded language labels in `.gd`/`.tscn`; populate labels at runtime with `U_LocalizationUtils.localize(...)`
  - use `hud.autosave_saving` for autosave spinner text instead of scene-authored literals
- Overlay static-label localization pattern (Phase 7):
  - define overlay copy keys under `overlay.<screen>.*` in `cfg_locale_*_ui.tres` (for example `overlay.input_profile_selector.*`)
  - implement `_localize_static_labels()` in overlay controllers and call it from both `_on_panel_ready()` and `_on_locale_changed()`
  - clear scene-authored static text defaults in `.tscn` for labels/buttons owned by runtime localization, so locale swaps cannot leave stale scene literals
  - keep non-localized overlay string literals limited to defensive fallback text and debug/developer logs
- Settings tab option-catalog localization pattern (Phase 7):
  - keep option entry metadata in catalogs (`U_DisplayOptionCatalog`) and expose `label_key` alongside `id`/`label`
  - localize option labels inside the catalog with `U_LocalizationUtils.localize(...)` + fallback, then repopulate tab `OptionButton` entries on `_on_locale_changed` while preserving selected ids
  - keep settings-tab section/row/button/dialog/tooltip labels in `settings.<domain>.*` keys and relocalize in-place on locale changes
- Localization test-hardening pattern (Phase 8):
  - prefer behavior assertions over private manager internals (`get("_field")`, private helper calls)
  - for localization manager font/root behavior, assert via registered root theme state and locale-change callbacks rather than internal arrays/counters/fonts

## Time Manager Patterns

### Overview

`M_TimeManager` replaces `M_PauseManager` as the central time authority. It owns layered pause channels, timescale, and world clock runtime state while synchronizing the Redux `time` slice for persistence and selectors.

### ServiceLocator Access

- Primary lookup: `U_ServiceLocator.get_service(StringName("time_manager"))`
- Backward-compatible lookup: `U_ServiceLocator.get_service(StringName("pause_manager"))` (same manager instance)

### Pause Channels

- Use `request_pause(channel)` / `release_pause(channel)` for reference-counted pause control.
- Standard channels live in `U_PauseSystem`: `CHANNEL_UI`, `CHANNEL_CUTSCENE`, `CHANNEL_DEBUG`, `CHANNEL_SYSTEM`.
- `CHANNEL_UI` is manager-derived from overlay stack state; do not manually request/release it.
- Gameplay time advances only when all channels are inactive.

### Timescale

- Use `set_timescale(scale)` (clamped to `[0.01, 10.0]`) and `get_scaled_delta(raw_delta)`.
- ECS physics consumes scaled delta via `M_ECSManager`; system code should not re-scale delta.
- `timescale` is transient in the `time` slice; save/load strips it, and runtime timescale stays manager-owned until `M_TimeManager` dispatches a replacement value.

### World Clock

- World clock advances in `M_TimeManager._physics_process` when unpaused and in gameplay scenes.
- Read current values via `get_world_time()` (`hour`, `minute`, `total_minutes`, `day_count`) and `is_daytime()`.
- Persisted fields: `world_hour`, `world_minute`, `world_total_minutes`, `world_day_count`, `world_time_speed`.
- Transient fields: `is_paused`, `active_channels`, `timescale`.

## Scene Manager Patterns (Phase 10 Complete)

### Scene Registration

- **Register all scenes**: Add scenes to `U_SceneRegistry._register_all_scenes()` before using them

  ```gdscript
  _register_scene(
    StringName("my_scene"),
    "res://scenes/gameplay/my_scene.tscn",
    SceneType.GAMEPLAY,
    "fade",  # default transition
    5        # preload priority (0-10)
  )
  ```

- **Preload priority guidelines**:
  - `10`: Critical UI (main_menu, pause_menu) - preloaded at startup
  - `5-7`: Frequently accessed scenes
  - `0-4`: Occasional access
  - `0`: No preload (loaded on-demand)

### Scene Transitions

- **Get scene manager**: `U_ServiceLocator.get_service(StringName("scene_manager")) as M_SceneManager`
- **Basic transition**: `scene_manager.transition_to_scene(StringName("scene_id"))`
- **Override transition type**: `scene_manager.transition_to_scene(StringName("scene_id"), "fade")`
- **Priority transitions**: `scene_manager.transition_to_scene(StringName("game_over"), "fade", M_SceneManager.Priority.CRITICAL)`
- **Transition types**:
  - `"instant"`: < 100ms, no visual effect (UI navigation)
  - `"fade"`: 0.2-0.5s, fade out → load → fade in (polished)
  - `"loading"`: 1.5s+, loading screen with progress bar (large scenes)
- **Transition callback state contract**: `M_SceneManager` transition callbacks use `U_TransitionState` (`scripts/scene_management/helpers/u_transition_state.gd`) for mutable shared state; do not reintroduce `Array` wrapper captures for progress/new-scene refs.
- **Camera blend handoff contract**: blend-finalization checks must use `I_CameraManager.is_blend_active()`; do not reflect private camera-manager members (for example `_camera_blend_tween`).
- **Priority levels**:
  - `NORMAL = 0`: Standard navigation
  - `HIGH = 1`: Important but not urgent
  - `CRITICAL = 2`: Death, game over (jumps to front of queue)

### Overlay Management (Pause/Menus)

- **Push overlay**: `scene_manager.push_overlay(StringName("pause_menu"))` - adds to stack, pauses tree
- **Pop overlay**: `scene_manager.pop_overlay()` - removes top overlay, resumes if empty
- **Return stack**: `push_overlay_with_return(StringName("settings_menu"))` - remember previous overlay
- **Auto-restore**: `pop_overlay_with_return()` - return to previous overlay automatically
- **Navigation**: `go_back()` - navigate back through UI history (UI scenes only, skips gameplay)

### Scene Triggers (Doors)

- **Component setup**: Add `C_SceneTriggerComponent` to door entities with Area3D collision
- **Required properties**:
  - `door_id`: Unique identifier (e.g., `"door_to_house"`)
  - `target_scene_id`: Destination scene (e.g., `"interior_house"`)
  - `target_spawn_point`: Spawn marker name (e.g., `"sp_entrance_from_exterior"`)
- **Trigger modes**:
  - `AUTO`: Triggers on collision (walk through)
  - `INTERACT`: Requires input action (press 'E')
- **Duplicate request protection**: Components check transition state and use cooldown/pending flags to prevent duplicate requests
- **Input blocking during transitions**: Transition effects temporarily block input to prevent accidental re-triggers; restore input on completion
- **Trigger shape configuration**: Use shape resources (Box or Cylinder). Avoid non-uniform scaling of nodes; adjust shape dimensions on the resource instead. Use `local_offset` to align triggers with visual geometry
- **Cooldown**: Set `cooldown_duration` (1-2 seconds) to prevent spam
- **Door pairings**: Register bidirectional doors in `U_SceneRegistry._register_door_pairings()`

  ```gdscript
  _register_door_pair(
    StringName("exterior"), StringName("door_to_house"),
    StringName("interior_house"), StringName("door_to_exterior")
  )
  ```

### Spawn Point Management

- **Naming convention**: `sp_` prefix + descriptive name (e.g., `sp_entrance_from_exterior`)
- **Container**: Place under `Entities/SpawnPoints` (Node3D) in gameplay scenes
- **Default spawn**: Name one marker `sp_default` for initial scene load
- **Position**: Place spawn markers 2-3 units OUTSIDE trigger zones (prevents ping-pong)
- **Automatic restoration**: M_SpawnManager applies spawn on scene load using:
  - Priority: `target_spawn_point` → `last_checkpoint` → `sp_default`
  - Fallback: If a `last_checkpoint` from a different scene is invalid, fall back to `sp_default` automatically

### State Persistence

- **Automatic persistence**: `gameplay` slice persists across transitions via `StateHandoff`
- **Use action creators**: Modify state via `U_GameplayActions` (never set fields directly)

  ```gdscript
  const U_GameplayActions = preload("res://scripts/state/actions/u_gameplay_actions.gd")
  store.dispatch(U_GameplayActions.take_damage(player_id, 25.0))
  store.dispatch(U_GameplayActions.mark_area_complete("interior_house"))
  ```

- **Read state safely**: Use `U_StateUtils.get_store(self)` with `await` in `_ready()`

  ```gdscript
  await get_tree().process_frame
  var store := U_StateUtils.get_store(self)
  var state: Dictionary = store.get_state()
  ```

- **Transient fields**: Excluded from saves (e.g., `is_transitioning`, `transition_type`)
- **Save/load**: `store.save_state("user://savegame.json")` / `store.load_state("user://savegame.json")`

### Camera Blending

- **Automatic blending**: Gameplay → Gameplay transitions blend camera position, rotation, FOV
- **Requirements**: Both scenes must have a Camera3D discoverable by `M_CameraManager` (or registered via `register_main_camera()`)
- **Transition type**: Only works with `"fade"` transitions (not instant/loading)
- **Scene-specific setup**: Configure camera per-scene (e.g., exterior: FOV 80°, interior: FOV 65°)
- **Implementation**: Uses transition camera + Tween (0.2s, TRANS_CUBIC, EASE_IN_OUT)

### Scene Preloading & Performance

- **Critical scene preload**: Scenes with `preload_priority >= 10` load at startup
- **Scene cache**: LRU cache with 5 scene limit + 100MB memory cap
- **Preload hints**: Call `hint_preload_scene(StringName("scene_id"))` when player approaches door
- **Automatic hints**: `C_SceneTriggerComponent` auto-hints target scene on player proximity
- **Async loading**: Gameplay scenes load asynchronously with real progress tracking
- **Performance targets**:
  - UI transitions: < 0.5s (cached scenes are instant)
  - Gameplay transitions: < 3s (async with loading screen)
  - Large scenes: < 5s (loading screen with progress bar)

## UI Manager Patterns

### Navigation State

- **Navigation slice**: Dedicated Redux slice managing UI location (`shell`, `overlay_stack`, `active_menu_panel`)
- **Shells**: `main_menu`, `gameplay`, `endgame`
- **Overlays**: Modal dialogs stacked on gameplay via `overlay_stack` array
- **Panels**: Embedded UI within shells (e.g., `menu/main`, `menu/settings`)

### Using Navigation Actions

```gdscript
const U_NavigationActions = preload("res://scripts/state/actions/u_navigation_actions.gd")

# Open pause overlay
store.dispatch(U_NavigationActions.open_pause())

# Open nested overlay
store.dispatch(U_NavigationActions.open_overlay(StringName("settings_menu_overlay")))

# Close top overlay (CloseMode determines behavior)
store.dispatch(U_NavigationActions.close_top_overlay())

# Switch menu panels
store.dispatch(U_NavigationActions.set_menu_panel(StringName("menu/settings")))
```

### UI Registry

- **Resource-based**: All screens defined in `resources/ui_screens/cfg_*.tres`
- **Screen definition**: `RS_UIScreenDefinition` with `screen_id`, `kind`, `scene_id`, `allowed_shells`, `close_mode`
- **Validation**: Registry validates parent-child relationships and scene references

### Base UI Classes

- **BasePanel**: Auto-store lookup, focus management, back button handling
- **BaseMenuScreen**: For full-screen UIs (main menu, endgame)
- **BaseOverlay**: For modal dialogs, sets `PROCESS_MODE_ALWAYS`, manages background dimming

### Common Patterns

- UI controllers extend base classes and dispatch actions (never call Scene Manager directly)
- Subscribe to `slice_updated` for reactive updates
- Use `U_NavigationSelectors.is_paused()` for pause state (single source of truth)
- Await store ready: `await get_tree().process_frame` before accessing store in `_ready()`

### Unified Settings Panel Patterns

**Architecture**:
- `SettingsPanel` extends `BaseMenuScreen` (gets analog stick repeater)
- Tab content panels extend plain `Control` (NO nested repeaters)
- Use `ButtonGroup` for tab radio behavior (automatic mutual exclusivity)
- Auto-save pattern: dispatch Redux actions immediately (no Apply/Cancel buttons)

**Base Class Hierarchy**:
```
BasePanel (store + focus helpers)
└─ BaseMenuScreen (+ U_AnalogStickRepeater)
    ├─ SettingsPanel ← extends this
    └─ BaseOverlay (+ PROCESS_MODE_ALWAYS)

Tab panels (gamepad_tab, touchscreen_tab, etc.)
└─ Control ← extends this (NOT BaseMenuScreen!)
```

**ButtonGroup Setup**:
```gdscript
# In settings_panel.gd:
var _tab_button_group := ButtonGroup.new()
func _ready():
    input_profiles_button.toggle_mode = true
    input_profiles_button.button_group = _tab_button_group
    gamepad_button.toggle_mode = true
    gamepad_button.button_group = _tab_button_group
    # ButtonGroup automatically handles button_pressed states
    _tab_button_group.pressed.connect(_on_tab_button_pressed)
```

**Focus Management Rules**:
1. **Tab switch**: Transfer focus to first control in new tab
   ```gdscript
   await get_tree().process_frame  # Let visibility settle
   var first_focusable := _get_first_focusable_in_active_tab()
   if first_focusable:
       first_focusable.grab_focus()
   ```

2. **Device switch**: If active tab becomes hidden, switch tab AND re-focus
   ```gdscript
   _update_tab_visibility()
   if not _is_active_tab_visible():
       _switch_to_first_visible_tab()
       await get_tree().process_frame
       _focus_first_control_in_active_tab()  # Critical!
   ```

3. **Tab content**: Use `U_FocusConfigurator` for focus chains, not custom `_navigate_focus()`
   ```gdscript
   # In gamepad_tab.gd:
   func _configure_focus_neighbors():
       var controls: Array[Control] = [left_slider, right_slider, checkbox]
       U_FocusConfigurator.configure_vertical_focus(controls, false)
   ```

**Auto-Save Pattern**:
```gdscript
# ✅ CORRECT - immediate dispatch
func _on_left_deadzone_changed(value: float):
    store.dispatch(U_InputActions.update_gamepad_setting("left_stick_deadzone", value))

# ❌ WRONG - batching with Apply button
var _pending_changes: Dictionary = {}
func _on_slider_changed(value: float):
    _pending_changes["deadzone"] = value
func _on_apply_pressed():
    store.dispatch(...)
```

**Input Actions for Tab Switching**:
- Add `ui_focus_prev` (L1/LB, Page Up) and `ui_focus_next` (R1/RB, Page Down) to `project.godot`
- Shoulder buttons cycle tabs, focus transfers automatically

**Anti-Patterns**:
- ❌ Tab panels extending `BaseMenuScreen` (creates nested repeater conflict)
- ❌ Manual button state management (use `ButtonGroup` instead)
- ❌ Apply/Cancel buttons (use auto-save pattern)
- ❌ Tab content overriding `_navigate_focus()` (conflicts with parent repeater)

## Save Manager Patterns (Phase 13 Complete)

### Overview

M_SaveManager orchestrates save/load operations with atomic writes, migrations, and autosave scheduling. It does NOT define gameplay data—M_StateStore remains the single source of truth for serializable state.

### Slot System

- **1 autosave slot**: `SLOT_AUTOSAVE` (overwritten by autosave events, cannot be deleted)
- **3 manual slots**: `SLOT_01`, `SLOT_02`, `SLOT_03` (user-created via pause menu)
- **File location**: `user://saves/` (configurable for testing via `set_save_directory()`)
- **File format**: `{header: {...}, state: {...}}` with version, timestamp, playtime, scene context

### Save Operations

```gdscript
const M_SAVE_MANAGER := preload("res://scripts/managers/m_save_manager.gd")

# Get manager (discoverable via ServiceLocator)
var save_manager := U_ServiceLocator.get_service(StringName("save_manager")) as M_SaveManager

# Manual save to slot
save_manager.save_to_slot(StringName("slot_01"))  # Returns Error code

# Check slot existence
if save_manager.slot_exists(StringName("slot_01")):
    # Slot has valid save file

# Get metadata for UI display
var metadata: Dictionary = save_manager.get_slot_metadata(StringName("slot_01"))
# Returns: {save_version, timestamp, build_id, playtime_seconds, current_scene_id,
#           last_checkpoint, target_spawn_point, area_name, slot_id, thumbnail_path}

# Get all slot metadata
var all_metadata: Array[Dictionary] = save_manager.get_all_slot_metadata()
```

### Load Operations

```gdscript
# Load from slot (applies state + transitions to saved scene)
save_manager.load_from_slot(StringName("slot_01"))  # Returns Error code

# Load workflow:
# 1. Reads save file with .bak fallback on corruption
# 2. Applies migrations (v0 → v1, etc.)
# 3. Validates structure (header, state, current_scene_id)
# 4. Applies loaded state to M_StateStore via apply_loaded_state()
# 5. Transitions to saved scene_id via M_SceneManager (loading screen)
# 6. Clears loading lock when transition completes
```

### Delete Operations

```gdscript
# Delete manual slot (autosave cannot be deleted)
save_manager.delete_slot(StringName("slot_01"))  # Returns ERR_UNAUTHORIZED for autosave
```

### Autosave Triggers

Autosaves trigger on **milestones** (low-frequency, meaningful events):

- **Checkpoint activated**: `checkpoint_activated` ECS event
- **Area completed**: `gameplay/mark_area_complete` Redux action
- **Scene transition completed**: `scene/transition_completed` Redux action

**Blocking conditions** (autosave suppressed):
- `gameplay.death_in_progress == true` (no autosave during death)
- `scene.is_transitioning == true` (no autosave during transitions)
- `navigation.shell != "gameplay"` (only autosave during gameplay, not in menus)
- Save/load operations in progress (`M_SaveManager.is_locked()`)

**Cooldown/Priority**:
- NORMAL priority: 5s cooldown (checkpoint, scene transition)
- HIGH priority: 2s cooldown (area completion)
- CRITICAL priority: always trigger (reserved for future use)

### Autosave Scheduler (Internal)

U_AutosaveScheduler (helper, child of M_SaveManager):
- Subscribes to ECS events (`checkpoint_activated`) via `U_ECSEventBus`
- Subscribes to Redux actions via `M_StateStore.action_dispatched` signal
- Coalesces multiple requests within same frame (dirty flag pattern)
- Enforces blocking conditions and cooldowns
- Calls `M_SaveManager.request_autosave(priority)` when allowed

### Playtime Tracking

S_PlaytimeSystem (ECS system):
- Tracks `gameplay.playtime_seconds` (increments every second during gameplay)
- Pauses when: `navigation.shell != "gameplay"`, paused, or transitioning
- Dispatches `U_GameplayActions.increment_playtime(seconds)` periodically
- Playtime persists across scene transitions and saves/loads

### File I/O Patterns

**Atomic writes** (crash-safe):
```
1. Write to {slot}.json.tmp
2. Backup existing {slot}.json to {slot}.json.bak
3. Rename {slot}.json.tmp to {slot}.json
```

**Corruption recovery**:
```
Load order: {slot}.json → {slot}.json.bak (if .json missing/corrupted) → empty dict
```

**Orphaned .tmp cleanup**: On startup, remove all `.tmp` files from save directory

### Migration System

U_SaveMigrationEngine (helper):
- Pure `Dictionary → Dictionary` transforms (no side effects)
- Version detection from `header.save_version` (missing header = v0)
- Sequential migration chain: `v0 → v1 → v2 → ...`
- **v0 → v1 migration**: Wraps headerless saves in `{header, state}` structure

**Legacy save import**:
- On first launch, imports `user://savegame.json` (old format) to autosave slot
- Applies v0 → v1 migration automatically
- Deletes original `user://savegame.json` after successful import

### Validation & Error Handling

U_SaveValidator (utility):
- Validates save file structure (header, state must be Dictionaries)
- Validates required fields (`current_scene_id` must exist and be non-empty)
- Returns detailed error messages with context (field name, expected/actual type)

**Error codes**:
- `OK`: Success
- `ERR_BUSY`: Save/load already in progress
- `ERR_INVALID_PARAMETER`: Invalid slot_id
- `ERR_FILE_NOT_FOUND`: Slot doesn't exist
- `ERR_FILE_CORRUPT`: Invalid/corrupted save file
- `ERR_UNAUTHORIZED`: Attempted to delete autosave slot
- `ERR_UNAVAILABLE`: Scene manager unavailable for load transition

### UI Integration

**Pause menu buttons** (`ui_pause_menu.gd`):
```gdscript
const U_NAVIGATION_ACTIONS := preload("res://scripts/state/actions/u_navigation_actions.gd")

# Save button pressed
func _on_save_pressed():
    store.dispatch(U_NavigationActions.set_save_load_mode(StringName("save")))
    store.dispatch(U_NavigationActions.open_overlay(StringName("save_load_menu_overlay")))

# Load button pressed
func _on_load_pressed():
    store.dispatch(U_NavigationActions.set_save_load_mode(StringName("load")))
    store.dispatch(U_NavigationActions.open_overlay(StringName("save_load_menu_overlay")))
```

**Save/Load overlay** (`ui_save_load_menu.gd`):
- Extends `BaseOverlay` (PROCESS_MODE_ALWAYS, background dimming)
- Reads mode from `navigation.save_load_mode` on `_ready()`
- Populates slot list from `M_SaveManager.get_all_slot_metadata()`
- Shows overwrite confirmation dialog before saving to occupied slot
- Shows inline spinner + disables buttons during load operation
- Subscribes to save events (`save_started`, `save_completed`, `save_failed`) for UI refresh

**Toast notifications** (`ui_hud_controller.gd`):
- Subscribes to `U_ECSEventBus` save events
- Shows toasts for autosaves ONLY (manual saves use inline UI feedback)
- Suppressed during pause (toasts only appear during gameplay)
- "Saving..." on `save_started`, "Game Saved" on `save_completed`, "Save Failed" on `save_failed`

### Testing Patterns

**Integration tests** (`tests/integration/save_manager/test_save_load_cycle.gd`):
- Use `M_SaveManager.set_save_directory("user://test_saves/")` BEFORE adding to tree
- Create real `M_StateStore` with initial state resources (not mock)
- Set `navigation.shell = "gameplay"` to allow autosave triggers
- Use empty string for player damage: `U_GameplayActions.take_damage("", amount)`
- Wait for physics frame after dispatching actions to flush state updates

**Unit tests** (Phase 0-8):
- 94 unit tests covering manager lifecycle, slot registry, file I/O, migrations, validation
- Use `MockStateStore` and `MockSceneManager` from `tests/mocks/`
- Test directory helpers in `u_save_test_utils.gd` (setup/teardown)

### Anti-Patterns

- ❌ Calling `M_StateStore.save_state(filepath)` directly (bypasses save manager, no header/migrations)
- ❌ Triggering autosave on high-frequency events (position updates, damage ticks)
- ❌ Autosaving during death (`death_in_progress == true`)
- ❌ Autosaving during scene transitions (`is_transitioning == true`)
- ❌ Modifying state during load (let StateHandoff handle restoration)
- ❌ Attempting to delete autosave slot (returns `ERR_UNAUTHORIZED`)

## Audio Manager Patterns (Phase 10 Complete)

### Registry & Data Architecture

- **Resource-driven definitions**: All audio assets defined as resources, not hard-coded dictionaries
  - `RS_MusicTrackDefinition`: Music tracks with fade duration, volume, loop, pause behavior
  - `RS_AmbientTrackDefinition`: Ambient tracks with fade duration, volume, loop
  - `RS_UISoundDefinition`: UI sounds with volume, pitch variation, throttle_ms
  - `RS_SceneAudioMapping`: Maps scenes to music/ambient tracks
- **Registry loader**: `U_AudioRegistryLoader.initialize()` populates O(1) lookup dictionaries
  - `get_music_track(track_id)` → RS_MusicTrackDefinition or null
  - `get_ambient_track(ambient_id)` → RS_AmbientTrackDefinition or null
  - `get_ui_sound(sound_id)` → RS_UISoundDefinition or null
  - `get_audio_for_scene(scene_id)` → RS_SceneAudioMapping or null
- **Registration pattern**:
  ```gdscript
  # In U_AudioRegistryLoader._register_music_tracks()
  var track := preload("res://resources/audio/tracks/music_main_menu.tres")
  _music_tracks[track.track_id] = track
  ```

### Crossfade Patterns

- **U_CrossfadePlayer**: Reusable dual-player crossfader for music and ambient
  - **Initialization**: `var crossfader := U_CrossfadePlayer.new(owner_node, &"Music")`
  - **Crossfade**: `crossfader.crossfade_to(stream, track_id, duration, start_position)`
    - Swaps active/inactive players
    - Starts new player at -80dB, fades to 0dB
    - Fades old player out to -80dB
    - Uses parallel Tween (TRANS_CUBIC, EASE_IN_OUT)
  - **Stop**: `crossfader.stop(duration)` - fades active player out
  - **Pause/Resume**: `crossfader.pause()` / `crossfader.resume()` - stores/restores playback position
  - **Query**: `crossfader.get_current_track_id()`, `crossfader.is_playing()`
  - **Cleanup**: `crossfader.cleanup()` - frees both players
- **Usage in M_AudioManager**:
  ```gdscript
  _music_crossfader = U_CrossfadePlayer.new(self, &"Music")
  _ambient_crossfader = U_CrossfadePlayer.new(self, &"Ambient")
  ```

### Bus Layout & Validation

- **Editor-defined buses**: Bus layout defined in `default_bus_layout.tres`, not created at runtime
  - Master (0) → Music (1), SFX (2) → UI (3), Footsteps (4), Ambient (5)
- **Constants**: `U_AudioBusConstants` defines bus names and validation
  - `BUS_MASTER`, `BUS_MUSIC`, `BUS_SFX`, `BUS_UI`, `BUS_FOOTSTEPS`, `BUS_AMBIENT`
  - `REQUIRED_BUSES` array for validation
- **Validation**: Non-destructive validation at startup
  ```gdscript
  if not U_AudioBusConstants.validate_bus_layout():
      push_error("Audio bus layout invalid - check default_bus_layout.tres")
  ```
- **Safe bus access**: `U_AudioBusConstants.get_bus_index_safe(bus_name)` returns Master (0) on failure

### SFX Spawner Patterns

- **Dictionary-based API**: `U_SFXSpawner.spawn_3d(config: Dictionary)` for flexible configuration
  ```gdscript
  U_SFXSpawner.spawn_3d({
      "stream": audio_stream,
      "position": global_position,
      "volume_db": -6.0,
      "pitch_scale": 1.2,
      "bus": "SFX",
      "max_distance": 100.0,
      "attenuation_model": AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
      "follow_target": entity_node  # Optional: player follows entity
  })
  ```
- **Voice stealing**: Automatically steals oldest playing sound when pool exhausted (>16 sounds)
  - Tracks play times in `_play_times` dictionary
  - `_steal_oldest_voice()` finds and stops oldest player
  - Stats tracking: `U_SFXSpawner.get_stats()` returns `{spawns, steals, drops, peak_usage}`
- **Bus fallback**: `_validate_bus(bus)` returns "SFX" if bus not found, warns on invalid bus
- **Per-sound spatialization**: Override max_distance and attenuation_model per-sound
  - Respects `_spatial_audio_enabled` flag (disables attenuation/panning when false)
- **Follow-emitter mode**: Sound follows moving entity via `follow_target` config
  - `update_follow_targets()` called each frame to sync positions
  - Automatic cleanup when entity freed or playback stops
- **Stats & metrics**: `reset_stats()` clears counters, `_update_peak_usage()` tracks max concurrent

### ECS Sound Systems Patterns

- **Request-driven architecture**: Systems extend `BaseEventSFXSystem`, subscribe to ECS events
  - Implement `get_event_name()` → StringName (e.g., `"entity_jumped"`)
  - Implement `create_request_from_payload(payload)` → Dictionary `{position: Vector3, entity_id: StringName}`
  - Implement `_get_audio_stream()` → AudioStream (from settings resource)
- **Standard request schema**:
  ```gdscript
  {
      "position": Vector3,  # Required - extracted via _extract_position()
      "entity_id": StringName  # Optional - for debugging
  }
  ```
- **Shared helpers in BaseEventSFXSystem**:
  - `_should_skip_processing()` → checks settings enabled, stream exists
  - `_is_audio_blocked()` → pause/transition/shell gating (returns true if audio should not play)
  - `_is_throttled(min_interval, now)` → enforces minimum time between plays
  - `_calculate_pitch(pitch_variation)` → clamps variation to 0.0-0.95, returns randomized pitch
  - `_extract_position(request)` → safely extracts position from request Dictionary
  - `_spawn_sfx(stream, position, volume_db, pitch_scale, bus)` → delegates to U_SFXSpawner.spawn_3d()
- **Pause/transition gating**: All sound systems check before playing
  ```gdscript
  func process_tick(delta: float) -> void:
      if _is_audio_blocked():  # Checks pause, transition, shell != "gameplay"
          requests.clear()
          return
  ```
- **State store injection**: Systems support `@export var state_store: I_StateStore` for testing
  - `_is_audio_blocked()` tries injected store first, falls back to `U_StateUtils.try_get_store()`
- **Position resolution**: Resolve entity positions at event **publish time**, not in sound systems
  - ✅ Include position in event payload: `U_ECSEventBus.publish("entity_jumped", {position: global_position})`
  - ❌ Avoid O(n) lookups in sound systems: `get_entity_by_id()`, `find_child()`

### UI Sound Patterns

- **U_UISoundPlayer**: Lightweight helper wrapping M_AudioManager UI sound playback
  ```gdscript
  U_UISoundPlayer.play_focus()    # UI navigation focus
  U_UISoundPlayer.play_confirm()  # UI confirm/select
  U_UISoundPlayer.play_cancel()   # UI cancel/back
  U_UISoundPlayer.play_slider_tick()  # Slider value change
  ```
- **Per-sound throttling**: `RS_UISoundDefinition.throttle_ms` prevents rapid repeated plays
  - `throttle_ms = 100` → blocks plays within 100ms window
  - `throttle_ms = 0` → no throttle, all plays allowed
  - Tracked per sound_id in `_last_play_times` dictionary
- **Polyphony**: M_AudioManager uses 4 round-robin players for overlapping UI sounds
  - `UI_SOUND_POLYPHONY = 4` → up to 4 simultaneous UI sounds
  - `_ui_sound_index` cycles through players (0-3)
- **Usage in UI controllers**:
  ```gdscript
  func _on_button_focus_entered() -> void:
      U_UISoundPlayer.play_focus()

  func _on_confirm_pressed() -> void:
      U_UISoundPlayer.play_confirm()
  ```

### State-Driven Audio Settings

- **Hash-based optimization**: M_AudioManager only applies settings when audio slice changes
  ```gdscript
  var audio_slice: Dictionary = state.get("audio", {})
  var audio_hash := audio_slice.hash()
  if audio_hash != _last_audio_hash:
      _apply_audio_settings(state)
      _last_audio_hash = audio_hash
  ```
- **Settings preview mode**: Temporary overrides via `set_audio_settings_preview(preview_dict)`
  - Used by UI_VFXSettingsOverlay for real-time previews
  - `clear_audio_settings_preview()` restores persisted settings
  - `_audio_settings_preview_active` flag prevents hash updates during preview
- **Audio persistence**: Audio settings auto-save to disk when changed
  - `_schedule_audio_save()` debounces writes (500ms delay)
  - Only actions with `action_type.begins_with("audio/")` trigger save

### Scene-Based Audio Transitions

- **Automatic music/ambient**: M_AudioManager subscribes to `scene/transition_completed` action
  ```gdscript
  func _change_audio_for_scene(scene_id: StringName) -> void:
      var mapping := U_AudioRegistryLoader.get_audio_for_scene(scene_id)
      if mapping.music_track_id != StringName(""):
          play_music(mapping.music_track_id, 2.0)  # 2s crossfade
      if mapping.ambient_track_id != StringName(""):
          play_ambient(mapping.ambient_track_id, 2.0)
  ```
- **Pause music handling**: ACTION_OPEN_PAUSE → play "pause" track, ACTION_CLOSE_PAUSE → restore pre-pause track
  - Stores `_pre_pause_music_id` and `_pre_pause_music_position` for restoration
- **Cross-scene persistence**: Music and ambient managed by M_AudioManager (persistent), not per-scene systems

### Common Patterns

- **Access audio manager**: `U_AudioUtils.get_audio_manager()` (ServiceLocator lookup)
- **Play music**: `audio_mgr.play_music(StringName("main_menu"), 1.5)` - 1.5s crossfade
- **Play ambient**: `audio_mgr.play_ambient(StringName("exterior"), 2.0)` - 2s crossfade
- **Play UI sound**: `audio_mgr.play_ui_sound(StringName("ui_confirm"))` - round-robin polyphony
- **Spawn 3D SFX**: `U_SFXSpawner.spawn_3d({stream: sfx, position: pos, bus: "SFX"})`

### Anti-Patterns

- ❌ Hard-coding audio streams in scripts (use resource definitions instead)
- ❌ Creating bus layout at runtime (define in default_bus_layout.tres)
- ❌ O(n) entity lookups in sound systems (include position in event payload)
- ❌ Playing audio during pause/transitions (use `_is_audio_blocked()` gating)
- ❌ Spawning >16 simultaneous SFX without voice stealing (pool will exhaust)
- ❌ Bypassing throttle_ms for rapid UI sounds (causes audio spam)

## Display Manager Patterns (Phase 11 Complete)

### Overview

M_DisplayManager handles window settings, post-processing effects, UI scaling, and accessibility features. It follows the same hash-based optimization and preview mode patterns as M_AudioManager.

### Hash-Based Change Detection

Same pattern as audio manager - only applies settings when display slice hash changes:

```gdscript
var _last_display_hash: int = 0
var _display_settings_preview_active: bool = false

func _on_slice_updated(slice_name: StringName, _slice_data: Dictionary) -> void:
    if slice_name != &"display" or _display_settings_preview_active:
        return
    var state := state_store.get_state()
    var display_slice: Dictionary = state.get("display", {})
    var display_hash := display_slice.hash()
    if display_hash != _last_display_hash:
        _apply_display_settings(state)
        _last_display_hash = display_hash
```

### Preview Mode

Temporary overrides for settings UI (real-time preview without persisting):

```gdscript
# Push preview
display_manager.set_display_settings_preview({
    "film_grain_enabled": true,
    "film_grain_intensity": 0.3
})

# Clear preview (restores persisted state)
display_manager.clear_display_settings_preview()
```

### ServiceLocator Registration

Access display manager via ServiceLocator:

```gdscript
var display_manager := U_ServiceLocator.get_service(StringName("display_manager")) as I_DisplayManager
# Or use helper
var display_manager := U_DisplayUtils.get_display_manager()
```

### Post-Process Overlay (Layer 100)

Post-processing effects render via `ui_post_process_overlay.tscn`:
- **CanvasLayer**: Layer 100 (above gameplay at 0, below UI overlays)
- **Effects**: FilmGrainRect, DitherRect, ColorBlindRect
- **Shaders**: Each rect has a ShaderMaterial with configurable uniforms
- **Time Updates**: Film grain shader receives `TIME` updates in `_process()`

### UI Scaling

UIScaleRoot registration for consistent UI size adjustment:

```gdscript
# UIScaleRoot helper registers parent UI roots
func _ready() -> void:
    U_DisplayUtils.register_ui_scale_root(get_parent())

# M_DisplayManager applies scale to registered roots
func set_ui_scale(scale: float) -> void:
    scale = clampf(scale, 0.5, 2.0)
    for node in _ui_scale_roots:
        if node is CanvasLayer:
            node.transform = Transform2D().scaled(Vector2(scale, scale))
        elif node is Control:
            node.scale = Vector2(scale, scale)
```

**Registration rules:**
- ✅ Add UIScaleRoot helper node to menu/overlay/HUD root nodes
- ❌ Do NOT add to post-process overlay (layer 100, not UI)
- ❌ Do NOT add to nested widgets (inherit scaling from parents)

### Display Slice State Shape

```gdscript
{
    "display": {
        # Graphics
        "window_size_preset": "1920x1080",  # Valid: 1280x720, 1600x900, 1920x1080, 2560x1440, 3840x2160
        "window_mode": "windowed",          # Valid: windowed, fullscreen, borderless
        "vsync_enabled": true,
        "quality_preset": "high",           # Valid: low, medium, high, ultra

        # Post-Processing
        "film_grain_enabled": false,
        "film_grain_intensity": 0.1,        # Clamped: 0.0-1.0
        "dither_enabled": false,
        "dither_intensity": 0.5,            # Clamped: 0.0-1.0
        "dither_pattern": "bayer",          # Valid: bayer, noise

        # UI
        "ui_scale": 1.0,                    # Clamped: 0.8-1.3

        # Accessibility
        "color_blind_mode": "normal",       # Valid: normal, deuteranopia, protanopia, tritanopia
        "high_contrast_enabled": false,
        "color_blind_shader_enabled": false,

        # Color Grading (transient — loaded per-scene, NOT persisted)
        "color_grading_filter_mode": 0,       # 0=none, 1-8=named filters
        "color_grading_filter_intensity": 1.0,
        "color_grading_exposure": 0.0,
        "color_grading_brightness": 0.0,
        "color_grading_contrast": 1.0,
        "color_grading_brilliance": 0.0,
        "color_grading_highlights": 0.0,
        "color_grading_shadows": 0.0,
        "color_grading_saturation": 1.0,
        "color_grading_vibrance": 0.0,
        "color_grading_warmth": 0.0,
        "color_grading_tint": 0.0,
        "color_grading_sharpness": 0.0,
    }
}
```

### Color Grading System (Phase 11)

Per-scene cinematic color grading applied as the bottom-most post-process layer. Artistic direction, not a user preference — always active regardless of `post_processing_enabled`.

**Layer Stack (bottom to top):**
- ColorGradingLayer = CanvasLayer 1
- GrainDitherLayer = CanvasLayer 2
- ColorBlindRect = CanvasLayer 5
- UIColorBlindLayer = CanvasLayer 11

**Scene Transition Flow:**
1. `action_dispatched` fires with `scene/transition_completed`
2. `U_DisplayColorGradingApplier` extracts `scene_id` from payload
3. Looks up `U_ColorGradingRegistry.get_color_grading_for_scene(scene_id)` (returns neutral fallback if unmapped)
4. Dispatches `U_ColorGradingActions.load_scene_grade(grade.to_dictionary())`
5. Display slice updates → hash change → `_apply_color_grading_settings()` sets shader uniforms

**Action Prefix (`color_grading/` NOT `display/`):**
- `color_grading/` prefix deliberately does NOT match `begins_with("display/")` in `U_GlobalSettingsSerialization.is_global_settings_action()`
- This ensures color grading state is NOT persisted to `user://global_settings.json`
- Per-scene grades are transient — loaded from `.tres` resources on each scene enter

**Registry (mobile-safe):**
```gdscript
# U_ColorGradingRegistry uses const preload arrays (no runtime DirAccess)
const _SCENE_GRADE_PRELOADS := [
    preload("res://resources/display/color_gradings/cfg_color_grading_gameplay_base.tres"),
    # ...
]
```

**Editor Preview (@tool node):**
- Drop `U_ColorGradingPreview` into any gameplay scene root
- Assign a `RS_SceneColorGrading` resource in the inspector
- Creates local CanvasLayer 100 + ColorRect with color grading shader
- `queue_free()` at runtime (M_DisplayManager handles everything in-game)

### Thread Safety

DisplayServer calls must be deferred for thread safety:

```gdscript
func set_window_mode(mode: String) -> void:
    call_deferred("_apply_window_mode", mode)

func _apply_window_mode(mode: String) -> void:
    match mode:
        "fullscreen":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
        "borderless":
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
            DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
        _:  # windowed
            DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
```

### Anti-Patterns

- ❌ Mutating DisplayServer from non-main thread (use `call_deferred()`)
- ❌ Applying settings without hash check (causes redundant DisplayServer calls)
- ❌ Adding UIScaleRoot to the post-process overlay (it's not UI)
- ❌ Adding UIScaleRoot to nested widgets (causes compounding scale)
- ❌ Using instant/sync applies during preview mode (blocks preview hash)
- ❌ Relying on display settings auto-save (unlike audio, display uses M_SaveManager)
- ❌ Using `display/` prefix for cinema grade actions (would persist to global_settings.json)
- ❌ Gating cinema grade behind `post_processing_enabled` (it's artistic direction, always active)
- ❌ Using runtime `DirAccess` in cinema grade registry (breaks on Android PCK)

## Behavior Tree Patterns (Phase 1)

### File Layout
- General BT framework (composites, decorators): `scripts/resources/bt/`
- AI-specific leaves + scorers: `scripts/resources/ai/bt/`
- BT runner (P1.6): `scripts/utils/bt/`

### RS_BTAction Context Contract
- `context["delta"]` must be injected by the **caller** before `tick()`. `RS_BTAction._resolve_delta()` reads `context["delta"]`; absent key silently returns `0.0`.
- **P1.8 risk**: `S_AIBehaviorSystem` currently passes `delta` as a separate arg to the task runner, not into context. When `U_BTRunner` is wired in P1.8, inject `context[&"delta"] = delta` before calling `runner.tick(root, context, state_bag)` or every action silently gets `delta = 0`.
- `U_AITaskStateKeys` (`scripts/utils/ai/u_ai_task_state_keys.gd`) is preloaded by `RS_BTAction` and is retained after P1.10.

### Scorer Architecture
- `RS_BTUtilitySelector` scores children via `child_scorers: Array[Resource]` — one scorer per child by index.
- All scorers extend `RS_AIScorer` and implement `score(context: Dictionary) -> float`.
- Score ≤ 0.0 means "not viable". Selector returns FAILURE when all children score ≤ 0.

## Test Commands

- Run ECS tests
  - `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ecs -gexit`
- Always include `-gexit` when running GUT via the command line so the runner terminates cleanly; without it the process hangs and triggers harness timeouts.
- Notes
  - Tests commonly `await get_tree().process_frame` after adding nodes to allow auto-registration with `M_ECSManager` before assertions.
  - When stubbing engine methods in tests (e.g., `is_on_floor`, `move_and_slide`), include `@warning_ignore("native_method_override")`.

## Quick How-Tos (non-duplicative)

- Add a new ECS Component
  - Create `scripts/ecs/components/c_your_component.gd` extending `BaseECSComponent` with `COMPONENT_TYPE` and exported NodePaths; add typed getters; update a scene to wire paths.
- Add a new ECS System
  - Create `scripts/ecs/systems/s_your_system.gd` extending `BaseECSSystem`; implement `process_tick(delta)`; query with your component's `StringName`; drop the node under a running scene—auto-configured.
- Find M_StateStore from any node
  - Use `U_StateUtils.get_store(self)` to find the store (internally uses U_ServiceLocator or injected store).
  - In `_ready()`: add `await get_tree().process_frame` BEFORE calling `get_store()` to avoid race conditions.
  - In `process_tick()`: no await needed (store already registered).
- Access managers via ServiceLocator (Phase 10B-7: T141)
  - Use `U_ServiceLocator.get_service(StringName("service_name"))` for fast, centralized manager access.
  - Available services: `"state_store"`, `"scene_manager"`, `"time_manager"`, `"pause_manager"` (backward-compat alias), `"spawn_manager"`, `"camera_manager"`, `"cursor_manager"`, `"vfx_manager"`, `"character_lighting_manager"`, `"input_device_manager"`, `"input_profile_manager"`, `"ui_input_handler"`, `"audio_manager"`, `"display_manager"`, `"localization_manager"`, `"save_manager"`, `"objectives_manager"`, `"run_coordinator"`, `"scene_director"`.
  - ServiceLocator provides O(1) Dictionary lookup vs O(n) scene-tree traversal.
  - All services are registered at startup in `root.tscn` via `root.gd`.
- Create a new gameplay scene
  - Duplicate `scenes/gameplay/gameplay_base.tscn` as starting point.
  - Keep M_ECSManager + Systems + Entities + Environment structure.
  - Do NOT add M_StateStore or M_CursorManager (they live in root.tscn).
