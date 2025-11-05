# Post Scene Manager: Interactables Unification Tasks

**Progress:** 69% (36 / 52 tasks complete)

Input: Current gameplay scenes and ECS components
Prerequisites: Scene Manager Phase 10 complete, checkpoint/door controllers validated in exterior/interior

Purpose
- Unify all interactables (doors, checkpoints, hazards, goals, and new signposts) under a single, clean authoring model: one `E_*` node per interactable with a thin controller. No authored component/Area3D children; all per‑instance tuning via exports and a small settings Resource.

Outcomes
- Faster authoring and duplication of interactables
- Consistent volume creation (shape/offset/mask) through a single settings Resource
- Uniform enable/disable, cooldown, player detection, and input behavior
- Clear separation between passive vs. triggered interactables

 

Architecture Overview
- BaseVolumeController (base class)
  - Responsibilities: manage `Area3D + CollisionShape3D`, apply `RS_SceneTriggerSettings`, expose `get_trigger_area()` and `set_enabled(bool)`; optional `visual_paths` for show/hide
  - Exports: `settings: RS_SceneTriggerSettings`, `area_path: NodePath`, `visual_paths: Array[NodePath]`
  - Behavior: auto‑create area/shape if `area_path` empty; normalize mask/offset
- BaseInteractableController (extends BaseVolumeController)
  - Adds: enter/exit detection, cooldown, lock
  - Signals: `player_entered`, `player_exited`, `activated`
  - Detection: ECS PlayerTag via `M_ECSManager` component lookup
- Triggered vs Passive split
  - TriggeredInteractableController (base): `trigger_mode` (AUTO/INTERACT), `interact_action` input handling
  - PassiveInteractableController (base): auto on enter or continuous (systems apply effects)

Naming & Key Decisions
- Reuse `RS_SceneTriggerSettings` for all volumes (doors/checkpoints/hazards/goals/signpost) to avoid resource proliferation
- Controllers ensure their required ECS component exists and is configured on `_ready()`; no nested authored component nodes required
- Systems remain the source of truth for effects (e.g., damage, victory routing); controllers only guarantee presence/configuration and handle player interaction
 - Prefixes:
   - Base classes: `Base*` (e.g., `BaseVolumeController`, `BaseInteractableController`)
   - Entity controllers: `E_*` (e.g., `E_DoorTriggerController`, `E_CheckpointZone`, `E_HazardZone`, `E_VictoryZone`, `E_Signpost`)
   - Resources: `RS_*` (e.g., `RS_SceneTriggerSettings`)

Phases & Tasks (TDD-first for base; tests-after for migrations)

Phase A: Foundations (TDD)
- [x] T-A01 Tests: `tests/unit/interactables/test_base_volume_controller.gd` (added)
- [x] T-A02 Impl: `scripts/gameplay/base_volume_controller.gd` (tabs only)
- [x] T-A03 Tests: `tests/unit/interactables/test_base_interactable_controller.gd` (added)
- [x] T-A04 Impl: `scripts/gameplay/base_interactable_controller.gd` (cooldown/lock + player detection)
- [x] T-A05 Tests: `tests/unit/interactables/test_triggered_interactable_controller.gd` (added)
- [x] T-A06 Impl: `scripts/gameplay/triggered_interactable_controller.gd` (AUTO/INTERACT + input)
- [x] T-A07 Validate `scripts/ecs/resources/rs_scene_trigger_settings.gd` covers all needs; extend conservatively and update default `.tres` as needed
  - Include cases: spawn-inside handling (initial overlap), arming after first physics frame, and enable/disable toggling visuals

Phase B: Controllers (Concrete; TDD)
- [x] T-B00 Align naming: rename existing controllers to E_*-prefixed filenames and update scenes (scripts + exterior/interior scenes now reference new controllers)
  - `scripts/gameplay/door_trigger.gd` → `scripts/gameplay/e_door_trigger_controller.gd`
  - `scripts/gameplay/checkpoint_zone.gd` → `scripts/gameplay/e_checkpoint_zone.gd`
  - Update references in `exterior.tscn`, `interior_house.tscn`, and any others
- [x] T-B01 Tests: `tests/unit/interactables/test_e_door_trigger_controller.gd` (covers component wiring + activation delegation)
- [x] T-B02 Impl: `scripts/gameplay/e_door_trigger_controller.gd` (extends BaseInteractable; AUTO default)
- [x] T-B03 Tests: `tests/unit/interactables/test_e_checkpoint_zone.gd` (verifies component reuse of controller area)
- [x] T-B04 Impl: `scripts/gameplay/e_checkpoint_zone.gd` (extends BaseVolume; passive on enter)
- [x] T-B05 Tests: `tests/unit/interactables/test_e_hazard_zone.gd` (validates damage config + shared area)
- [x] T-B06 Impl: `scripts/gameplay/e_hazard_zone.gd` (extends BaseVolume; passive continuous)
- [x] T-B07 Tests: `tests/unit/interactables/test_e_victory_zone.gd` (ensures objective + area wiring)
- [x] T-B08 Impl: `scripts/gameplay/e_victory_zone.gd` (extends BaseVolume; passive on enter, supports `victory_type`)
- [x] T-B09 Tests: `tests/unit/interactables/test_e_signpost.gd` (signal behaviour + locking)
- [x] T-B10 Impl: `scripts/gameplay/e_signpost.gd` (extends TriggeredInteractable; INTERACT)

Phase C: HUD/UI (Optional niceties; TDD optional)
- [x] T-C01 Add prompt UI for INTERACT mode (“Press [E] to …”) showing while inside and hiding on exit (interact prompt events + HUD label wired)
- [x] T-C02 Toast or popup for signpost message; reuse existing checkpoint toast for MVP (signpost publishes event, HUD reuses toast)

Phase D: Scene Migration (tests-after)
- [x] T-D01 Exterior: replace nested door component with controller; assign existing door settings `.tres` (door now uses E_DoorTriggerController with visual path)
- [x] T-D02 Interior: same as above (interior door migrated to controller + shared settings)
- [x] T-D03 Exterior: checkpoint uses controller + settings; remove authored Area3D/CollisionShape3D (safe zone relies on controller volume)
- [x] T-D04 Objectives: convert `checkpoint_safe_zone.tscn` to controller pattern (resource updated to use E_CheckpointZone)
- [x] T-D05 Hazards: convert `scenes/hazards/*.tscn` to hazard controller (remove nested component/areas where simple) (death zone & spike trap now controller-driven)
- [x] T-D06 Goals: ensure endgame goal enforces `GAME_COMPLETE` and routes to victory; convert to victory controller if appropriate (endgame goal extends E_VictoryZone)
- [x] T-D07 De‑nest audit: `scenes/gameplay/*` contains no PackedScene instances under Entities (allow Camera/Player templates only where required) (exterior/interior inline hazard & goal nodes)
- [x] T-D08 Remove exterior/interior as primary gameplay entries; mark as fixtures; update Scene Registry defaults to `gameplay_base` (hub scenes downgraded to fixture priority + flows now enter `gameplay_base`)
- [x] T-D09 Normalize gameplay scene root naming/markers (e.g., `GameplayRoot`) to match templates and docs (exterior root renamed to `GameplayRoot`)

Phase F: De‑nesting & Docs Cleanup
- [x] T-F01 Remove nested scenes from gameplay via interactables base/controller pattern (single `E_*` per interactable; no authored component/Area3D children) (gameplay scenes define controllers inline)
- [x] T-F02 Retire `exterior.tscn` and `interior_house.tscn` as fixtures; route post–Main Menu action to `gameplay_base.tscn` (main menu/victory/game over now point to hub scene)
- [ ] T-F03 Clean up Scene Manager documentation (reconcile phases, remove stale notes, link to this plan)
- [ ] T-F04 Clean up `DEV_PITFALLS.md`, `STYLE_GUIDE.md`, `SCENE_ORGANIZATION_GUIDE.md`, and `AGENTS.md` with new interactables/base patterns
- [ ] T-F05 Create base templates for PRD, Plan, Tasks, and Continuation Guide in `docs/_templates/` (if not already present), modeled on existing documents

Phase E: Validation (Tests)
- [x] T-E01 Unit tests for base controllers (enter/exit, cooldown, INTERACT) (interactable/unit suites executed via GUT)
- [x] T-E02 Integration tests: door transitions still work; checkpoints update state; hazards apply damage; victory routes correctly (scene manager integration suite exercised post-migration)

Phase G: Cross‑cutting Hardening & Migration Gaps
- [x] T-G01 Scene Registry sweep: update `U_SceneRegistry` scene IDs, defaults, door pairings, and preload priorities; add fallbacks for retired `exterior`/`interior_house` (hub entries downgraded, flows rerouted to gameplay_base)
- [ ] T-G02 Save/state migration: map legacy `current_scene_id`, `last_checkpoint`, and `completed_areas` to new IDs; warn + fallback when unknown; add unit tests
- [ ] T-G03 Spawn‑inside policy: decide (arm vs. detect initial overlap) and implement consistently across controllers; add tests
- [ ] T-G04 Transition gating: ensure controllers/trigger components suppress activation while `M_SceneManager.is_transitioning()` or store `scene.is_transitioning` is true; add tests
- [ ] T-G05 Physics layers: standardize player layer and default `player_mask` in `RS_SceneTriggerSettings`; audit scenes and update docs
- [ ] T-G06 Resource uniqueness: document and enforce per‑instance settings policy (Make Unique or `resource_local_to_scene`); audit for shared resource misuse
- [ ] T-G07 Visuals separation: define pattern for interactable visuals (e.g., `Visual` child under entity) now that logic is de‑nested; update examples/guides
- [ ] T-G08 Input scope: verify `interact` InputMap entry and prompt/HUD process modes are correct (e.g., PROCESS_MODE_ALWAYS when needed)
- [ ] T-G09 Signal lifecycle: all controllers disconnect on `_exit_tree()`; add a unit test covering subscribe/unsubscribe
- [x] T-G10 Prompt UI (optional): show/hide on enter/exit for INTERACT controllers; reuse HUD or add lightweight prompt label (HUD prompt label wired to new controller events)
- [ ] T-G11 Style enforcement: add/extend checks for tabs-only `.gd` and explicit `script = ExtResource(...)` in `.tres` where applicable
- [x] T-G12 Component integration: verify C_* components bind to controller-provided `Area3D` via `area_path` and do not duplicate geometry; add unit tests (controllers create components post-area; tests cover reuse)

Phase Z: Process Discipline (Required after each phase)
- [ ] T-Z01 Update continuation prompt and tasks checklist with current status (per AGENTS.md mandatory step)
- [ ] T-Z02 Update `AGENTS.md` with new patterns/architecture if applicable
- [ ] T-Z03 Update `DEV_PITFALLS.md` with new pitfalls discovered (tabs-only, `.tres` script refs, overlap/arming)
- [ ] T-Z04 Commit documentation updates separately from implementation; keep commits focused and validated

Acceptance Criteria
- A single `E_*` node can represent any interactable with no authored child components or areas
- Per‑instance configuration is exclusively via exported fields and a `RS_SceneTriggerSettings` resource
- AUTO and INTERACT both verified; input action is configurable and present in `InputMap`
- All existing gameplay flows (doors, checkpoints, hazards, victory) behave identically or better
 - No nested interactable scenes remain in gameplay scenes (excluding core templates like Player/Camera where explicitly intended)

Risks & Mitigations
- Mixed indentation in `.gd`: enforce tabs; add lint note in DEV_PITFALLS
- `.tres` class resolution errors: always include `script = ExtResource("...")` in settings files
- Multiple managers/stores: controllers rely on `U_ECSUtils.get_manager`/`U_StateUtils.get_store` which guard against nulls

Dependencies
- Input action for INTERACT (default `interact`) must exist; ensure via system or controller bootstrap
- `M_ECSManager` presence in gameplay scenes

Commit Strategy
- Separate commits per phase:
  - Foundations (base controllers + resource validation)
  - Controllers (door/checkpoint/hazard/victory/signpost)
  - Scene migrations (by scene)
  - Tests
  - Docs

Notes
- Keep changes minimal and localized; avoid unrelated refactors
- Update resources under `resources/` when adding new exported fields to settings scripts
- Maintain test green between commits; prefer small, verified steps
