# Feature Specification: Scene Manager System

**Feature Branch**: `scene-manager`
**Created**: 2025-10-27
**Last Updated**: 2025-12-08
**Status**: ✅ **PRODUCTION READY** - All Phases Complete, Post-Hardening Complete
**Input**: User description: "Scene Manager (menu → gameplay (exterior -> interior) → pause → end) — FLOW CONTROL"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Scene Transitions (Priority: P1)

The player can navigate from the main menu to gameplay and back. The system loads and unloads scenes cleanly, maintaining performance and preventing memory leaks.

**Why this priority**: Core flow control foundation. Without basic scene transitions, no other gameplay flow is possible. This is the MVP that enables all other features.

**Independent Test**: Launch game → Main Menu appears → Click "Play" → Gameplay scene loads → ESC to pause → "Return to Menu" → Main Menu reappears. Memory usage returns to baseline after transition.

**Acceptance Scenarios**:

1. **Given** game is launched, **When** the application starts, **Then** the Main Menu scene loads and displays menu options
2. **Given** player is on Main Menu, **When** player selects "Play", **Then** gameplay scene loads and player can move/interact
3. **Given** player is in gameplay, **When** player opens pause menu and selects "Return to Menu", **Then** Main Menu loads and gameplay scene is unloaded from memory
4. **Given** scene transition is requested, **When** the new scene loads, **Then** the previous scene is properly cleaned up (no orphaned nodes, components unregister from ECS)

---

### User Story 2 - Persistent Game State (Priority: P1)

Player state, progress, and settings persist across scene transitions. The player doesn't lose progress when moving between areas or returning to menu.

**Why this priority**: Critical for player experience. Without state persistence, players lose progress on every transition, making the game unplayable.

**Independent Test**: Start new game → Modify player state (e.g., collect item, change health) → Transition to interior scene → Verify player state persists → Return to menu → Load game → Verify all state restored correctly.

**Acceptance Scenarios**:

1. **Given** player has collected items in gameplay, **When** player transitions to a different area, **Then** inventory persists in the new scene
2. **Given** player has modified settings (volume, controls), **When** player quits and relaunches game, **Then** settings are loaded from disk
3. **Given** player is in middle of gameplay, **When** player returns to menu then resumes, **Then** player state (health, position, inventory) is preserved
4. **Given** player reaches a checkpoint, **When** auto-save triggers, **Then** progress is written to disk and can be loaded after game restart

---

### User Story 3 - Area Transitions (Exterior ↔ Interior) (Priority: P2)

Players can seamlessly transition between different gameplay areas (exterior overworld, interior buildings, dungeons) using doors, entrances, and zone triggers.

**Why this priority**: Essential for Zelda OoT-style semi-open world design. Enables exploration and dungeon gameplay. Depends on P1 scene transitions but adds gameplay-specific triggers.

**Independent Test**: Load gameplay → Walk to door trigger → Door transition plays → Interior scene loads with player at correct spawn point → Exit door → Return to exterior at correct location. Player state persists throughout.

**Acceptance Scenarios**:

1. **Given** player approaches a door trigger in exterior scene, **When** player presses interact or enters collision zone, **Then** transition effect plays and interior scene loads
2. **Given** player is entering an interior from specific door, **When** interior loads, **Then** player spawns at the correct entrance position
3. **Given** player exits interior through a door, **When** returning to exterior, **Then** player appears at the correct exit location in exterior scene
4. **Given** player transitions between areas, **When** transition occurs, **Then** appropriate transition effect plays (fade, loading screen, or instant based on scene configuration)

---

### User Story 4 - Pause System (Priority: P2)

Players can pause gameplay at any time, access pause menu options (resume, settings, quit), and resume exactly where they left off.

**Why this priority**: Core quality-of-life feature. Players expect to pause games. Enables access to settings and safe exit. Depends on scene stack functionality from P1.

**Independent Test**: Start gameplay → Press ESC → Pause menu scene loads over gameplay → Gameplay is frozen → Select "Resume" → Gameplay resumes exactly where it stopped. Verify all game state unchanged.

**Acceptance Scenarios**:

1. **Given** player is in gameplay, **When** player presses pause button (ESC), **Then** pause menu scene loads and gameplay is frozen
2. **Given** pause menu is open, **When** player selects "Resume", **Then** pause menu closes and gameplay continues from exact state
3. **Given** pause menu is open, **When** player selects "Settings", **Then** settings menu loads while maintaining pause state
4. **Given** player is in pause menu, **When** player changes settings and returns to game, **Then** settings apply immediately and persist to disk

---

### User Story 5 - Scene Transition Effects (Priority: P3)

Scene transitions use appropriate visual effects (instant, fade, loading screen, custom) based on transition type, providing polish and hiding loading times.

**Why this priority**: Polish and user experience enhancement. Prevents jarring cuts and provides feedback during loading. Builds on P1 transitions but is not critical for core functionality.

**Independent Test**: Configure different scene pairs with different transition types → Trigger each transition → Verify correct effect plays → Verify effect duration and smoothness → Confirm scene fully loads before effect completes.

**Acceptance Scenarios**:

1. **Given** scene transition is configured with fade effect, **When** transition triggers, **Then** screen fades to black, new scene loads, then fades back in
2. **Given** large scene is loading, **When** transition exceeds threshold duration, **Then** loading screen appears with progress indicator
3. **Given** quick transition (UI menu to UI menu), **When** transition occurs, **Then** instant transition is used (no unnecessary delay)
4. **Given** custom transition effect is configured, **When** specific transition triggers, **Then** custom animation plays (wipe, zoom, etc.)

---

### User Story 6 - Scene Preloading & Performance (Priority: P3)

The system intelligently preloads scenes to minimize wait times while managing memory efficiently, using mixed strategy (UI preloaded, gameplay on-demand).

**Why this priority**: Performance optimization. Improves perceived responsiveness but not critical for core functionality. Can be implemented after basic transitions work.

**Independent Test**: Monitor memory usage → Launch game → Verify UI scenes are preloaded at startup → Transition to gameplay → Verify gameplay scene loads on-demand → Monitor memory usage stays within acceptable bounds → Verify transition times are acceptable.

**Acceptance Scenarios**:

1. **Given** game starts up, **When** initialization completes, **Then** Main Menu, Settings Menu, and Pause Menu are preloaded into memory
2. **Given** player selects "Play" from menu, **When** gameplay scene loads, **Then** scene loads on-demand (not preloaded at startup)
3. **Given** player is in exterior scene near interior entrance, **When** preload hint is triggered, **Then** interior scene begins loading in background
4. **Given** multiple scenes are in memory, **When** memory pressure is detected, **Then** unused scenes are unloaded to free memory

---

### User Story 7 - Win/Lose End-Game Flow (Priority: P3)

Game properly handles end-game scenarios (player death, level victory, game completion) with appropriate screens and navigation options.

**Why this priority**: Completes the game flow loop but not needed for core development. Can be implemented once core gameplay is functional.

**Independent Test**: Trigger death condition → Game Over screen appears → Select "Retry" → Gameplay restarts from checkpoint. Trigger victory condition → Victory screen shows stats → "Continue" proceeds to next area. Complete game → Credits roll → Return to Main Menu.

**Acceptance Scenarios**:

1. **Given** player health reaches zero, **When** death condition triggers, **Then** Game Over screen loads with options to retry or return to menu
2. **Given** player completes level objective, **When** victory condition triggers, **Then** Victory screen displays stats and provides continue/menu options
3. **Given** player completes final objective, **When** game completion triggers, **Then** Credits scene plays, then returns to Main Menu
4. **Given** player is on Game Over screen, **When** player selects "Retry", **Then** gameplay scene reloads from last checkpoint with restored state

---

### Edge Cases

- What happens when scene loading fails (missing file, corrupted data)?
  - System should display error message and fallback to Main Menu gracefully

- What happens when player triggers transition while another transition is in progress?
  - System should queue transitions or ignore duplicate requests to prevent race conditions

- What happens when save file is corrupted or missing?
  - System should detect corruption, warn player, and offer to start new game or load backup

- What happens when player pauses during a scene transition?
  - Transition should complete before pause is allowed, or pause request should queue

- What happens when memory is low and scene cannot load?
  - System should unload non-essential scenes first, display loading screen, retry, or fallback to lighter scene

- What happens when player uses door trigger while in air or moving?
  - System should validate player state (grounded, not in animation) before allowing transition, or queue transition

- What happens when scene transition is triggered from within ECS system during physics frame?
  - Transitions should be deferred to end of frame or next frame to avoid mid-frame state corruption

- What happens when player has unsaved progress and quits?
  - System should trigger auto-save before quit, or warn player of unsaved progress

## Requirements *(mandatory)*

### Functional Requirements

#### Core Scene Management

- **FR-001**: System MUST support hybrid scene transition modes (stack for UI overlays, replace for major scene changes)
- **FR-002**: System MUST maintain a scene stack for pause/overlay scenarios (gameplay → pause → settings → back to gameplay)
- **FR-003**: System MUST support scene replacement for major transitions (menu → gameplay, exterior → interior)
- **FR-004**: System MUST properly cleanup previous scenes (unregister components from ECS, free nodes, clear references)
- **FR-005**: System MUST integrate with existing per-scene M_ECSManager pattern without requiring autoload configuration
- **FR-006**: System MUST work within Godot's scene tree structure (no autoloads, scene-based architecture)

#### Scene Types & Registry

- **FR-007**: System MUST support categorized scene types: Menu, Gameplay, UI, EndGame
- **FR-008**: System MUST maintain a scene registry mapping scene names/paths to metadata (type, preload priority, default transition)
- **FR-009**: System MUST support the following scene templates:
  - Main Menu (initial entry point)
  - Settings Menu (audio, graphics, controls configuration)
  - Pause Menu (in-game pause overlay)
  - Loading Screen (transition loading indicator)
  - Gameplay Areas (exterior, interior, dungeon variations)
  - Game Over Screen (death/failure state)
  - Victory Screen (level/objective completion)
  - Credits Scene (game completion)

#### State Persistence

- **FR-010**: System MUST persist player state across scene transitions (health, inventory, equipped items, abilities)
- **FR-011**: System MUST persist game progress data (checkpoints, unlocked areas, quest flags, level completion)
- **FR-012**: System MUST persist settings across game sessions (audio volume, control bindings, graphics quality)
- **FR-013**: System MUST persist session statistics (playtime, score, collectibles found)
- **FR-014**: System MUST support both auto-save (at checkpoints, scene transitions) and manual save (save points, menu option)
- **FR-015**: System MUST serialize state to disk in structured format (JSON or Godot resource format)
- **FR-016**: System MUST support multiple save slots (minimum 3 slots)
- **FR-017**: System MUST validate save data integrity on load (detect corruption, version mismatches)

#### Scene Transitions & Effects

- **FR-018**: System MUST support multiple transition effect types:
  - Instant (no visual effect)
  - Fade (fade to black/color, configurable duration)
  - Loading Screen (for long loads, with progress indicator)
  - Custom (pluggable transition animations via resources/scripts)

- **FR-019**: System MUST support async scene loading (non-blocking background loading)
- **FR-020**: System MUST support transition progress callbacks (for loading bars, progress indicators)
- **FR-021**: System MUST allow per-transition configuration (override default transition for specific scene pairs)
- **FR-022**: System MUST ensure new scene is fully loaded before completing transition effect

#### Scene Preloading Strategy

- **FR-023**: System MUST implement mixed preloading strategy:
  - Preload UI/menu scenes at game startup (Main Menu, Settings, Pause, Loading)
  - Load gameplay scenes on-demand when transitioning

- **FR-024**: System MUST support manual preload hints (begin loading likely next scene in background)
- **FR-025**: System MUST unload unused scenes when memory pressure detected
- **FR-026**: System MUST cache scene metadata without loading full scene (for registry lookups)

#### Transition Triggers

- **FR-027**: System MUST support player input triggers (ESC for pause, menu button)
- **FR-028**: System MUST support collision-based triggers via Area3D nodes (doors, zone boundaries)
- **FR-029**: System MUST support event-based triggers (win/lose conditions, scripted sequences)
- **FR-030**: System MUST support timer/delay triggers (auto-transition after duration)
- **FR-031**: System MUST integrate with ECS via C_SceneTriggerComponent and S_SceneTriggerSystem
- **FR-032**: System MUST allow configuration of trigger behavior (require interaction key vs auto-enter, transition delay)

#### Area Transitions (Zelda OoT-style)

- **FR-033**: System MUST support separate scenes for different gameplay areas (exterior overworld, interiors, dungeons)
- **FR-034**: System MUST track entrance/exit pairings (entering door A in exterior loads interior at spawn point B)
- **FR-035**: System MUST restore player to correct location when returning to previous area
- **FR-036**: System MUST persist area state when transitioning away (enemy positions, collected items, puzzle state)
- **FR-037**: System MUST support bidirectional transitions (exterior ↔ interior with correct spawn points)

#### Pause System

- **FR-038**: System MUST freeze gameplay when pause scene is stacked (stop physics, animations, timers)
- **FR-039**: System MUST allow pause from any gameplay state (mid-air, during animation, in combat)
- **FR-040**: System MUST maintain exact game state when unpausing (no time advancement, no position changes)
- **FR-041**: System MUST support nested pause menus (gameplay → pause → settings → back through stack)
- **FR-042**: System MUST lock mouse cursor when paused, unlock when resumed (via existing M_ECSManager utility)

#### End-Game Scenarios

- **FR-043**: System MUST trigger Game Over scene when player death condition occurs
- **FR-044**: System MUST trigger Victory scene when level/objective completion occurs
- **FR-045**: System MUST trigger Credits scene when game completion condition occurs
- **FR-046**: System MUST provide navigation options from end screens (retry, continue, return to menu)
- **FR-047**: System MUST restore appropriate game state when retrying (reload from checkpoint, reset session stats)

#### Integration & Architecture

- **FR-048**: System MUST work with existing singleton M_ECSManager (not replace or duplicate it)
- **FR-049**: System MUST allow ECS components and systems to persist across scene transitions when appropriate
- **FR-050**: System MUST provide lifecycle hooks for components/systems during transitions (on_scene_exiting, on_scene_entered)
- **FR-051**: System MUST use U_ECSEventBus for transition events (scene_transition_started, scene_loaded, etc.)
- **FR-052**: System MUST not require Godot autoload/singleton configuration (pure scene-tree-based)
- **FR-053**: System MUST be discoverable via scene tree groups (similar to ECS Manager's "ecs_manager" group)

#### Error Handling & Safety

- **FR-054**: System MUST detect and handle missing scene files gracefully (fallback to menu, error message)
- **FR-055**: System MUST prevent transition race conditions (queue or ignore duplicate transition requests)
- **FR-056**: System MUST validate scene transitions (prevent invalid transitions, check prerequisites)
- **FR-057**: System MUST defer frame-sensitive transitions (triggered during physics frame) to safe timing
- **FR-058**: System MUST provide emergency fallback (return to main menu on critical error)

### Key Entities

- **M_SceneManager** (NEW): Coordinator for scene transitions
  - Dispatches actions to M_StateStore (U_SceneActions.transition_to, etc.)
  - Subscribes to scene slice updates to react to state changes
  - Manages Godot scene tree operations (load, unload, add_child)
  - Executes transition effects (fade, loading screen, camera blend)
  - Does NOT store state directly (delegates to M_StateStore)

- **M_StateStore** (EXISTING): Redux-style state management
  - Manages all game state via slices (boot, menu, gameplay, scene)
  - Implements save_state() / load_state() for JSON persistence
  - StateHandoff preserves slices across scene transitions automatically
  - Provides action/reducer pattern for state updates
  - Already implements transient field exclusion, serialization
  - MUST be modified to add scene slice registration (see FR-112)

- **Scene State Slice** (NEW): State slice for scene management
  - Managed by M_StateStore, updated via SceneReducer
  - Tracks: current_scene_id, scene_stack, is_transitioning
  - Persisted via StateHandoff like all other slices
  - Modified via U_SceneActions (transition_to, push_overlay, pop_overlay)

- **U_SceneActions** (NEW): Action creators for scene operations
  - transition_to(scene_id, transition_type): Start scene transition
  - transition_complete(scene_id): Mark transition finished
  - push_overlay(scene_id): Add overlay scene to stack
  - pop_overlay(): Remove top overlay scene
  - Returns action dictionaries with type and payload
  - Follows existing pattern (U_BootActions, U_MenuActions, U_GameplayActions)

- **RS_SceneInitialState** (NEW): Initial state resource for scene slice
  - Extends Resource, used by M_StateStore to initialize scene slice
  - Exports: current_scene_id (String), scene_stack (Array), is_transitioning (bool)
  - Implements to_dictionary() method
  - Follows existing pattern (RS_BootInitialState, RS_MenuInitialState)

- **SceneReducer** (NEW): Reducer for scene slice
  - Handles scene-related actions
  - Returns new state (immutable updates)
  - Updates current_scene_id, scene_stack, is_transitioning
  - Follows existing pattern (BootReducer, MenuReducer, GameplayReducer)

- **U_SceneRegistry** (NEW): Configuration data for all game scenes
  - Maps scene identifiers to scene paths
  - Stores scene metadata (type, default transition, preload priority)
  - Defines entrance/exit pairings for area transitions
  - Static GDScript class or Resource

- **BaseTransitionEffect** (NEW): Visual transition animations
  - Base interface for all transition types
  - Implementations: Trans_Instant, Trans_Fade, Trans_LoadingScreen, CustomTransition
  - Provides async transition lifecycle (start, update progress, complete)

- **SceneTrigger** (NEW): Entity-based trigger component
  - C_SceneTriggerComponent: Data (door_id, target scene, spawn point)
  - S_SceneTriggerSystem: Logic (collision detection, dispatches SceneActions)
  - Integrated with ECS Manager query system

- **StateHandoff** (EXISTING): Static utility for state preservation
  - preserve_slice(): Stores slice state before scene unload
  - restore_slice(): Retrieves slice state after scene load
  - Used automatically by M_StateStore._exit_tree() and _ready()

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Players can complete full gameplay loop (menu → gameplay → pause → resume → end screen → menu) without crashes or memory leaks
- **SC-002**: Scene transitions complete within acceptable time (UI transitions < 0.5s, gameplay transitions < 3s, large area loads < 5s with loading screen)
- **SC-003**: Memory usage remains stable across 20+ scene transitions (no memory leaks, proper cleanup verified)
- **SC-004**: Player state persists accurately across 100% of scene transitions (no data loss, no state corruption)
- **SC-005**: Save/load operations complete successfully in < 1 second for typical save data size
- **SC-006**: System handles 100% of edge cases gracefully (missing scenes, corrupt saves, mid-transition interrupts)
- **SC-007**: Pause/unpause maintains exact game state with < 1 frame timing error (no physics simulation advancement)
- **SC-008**: Area transitions (exterior ↔ interior) spawn player at correct location 100% of the time
- **SC-009**: ECS components properly unregister during scene cleanup (0 orphaned components in manager after transition)
- **SC-010**: Transition effects play smoothly at target framerate (60 FPS minimum during transitions)
- **SC-011**: Scene preloading reduces perceived load times by 50% for preloaded scenes compared to on-demand
- **SC-012**: System integrates with existing ECS architecture without requiring refactoring of existing components/systems

### Development Success

- **SC-013**: All 7 user stories have passing acceptance tests (manual or automated via GUT framework)
- **SC-014**: System architecture documentation is complete and up-to-date
- **SC-015**: Example scenes demonstrate all scene types and transition types
- **SC-016**: Zero Godot autoloads added to project (maintains scene-tree-based architecture)
- **SC-017**: Code follows existing project patterns (auto-discovery, type-based queries, settings resources)

### User Experience Success

- **SC-018**: Testers can navigate full game flow without confusion (menu structure is intuitive)
- **SC-019**: Transitions feel responsive (no perceived input lag after triggering transition)
- **SC-020**: Loading screens appear only when necessary (quick transitions don't show loading unnecessarily)
- **SC-021**: Game state persistence is invisible to player (no manual "save complete" popups unless player manually saves)
- **SC-022**: End-game flows provide clear next action (buttons are clearly labeled, purpose is obvious)

### Core Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **State Management** | Use existing M_StateStore (Redux) | Already implements save/load, StateHandoff, transient fields. Add "scene" slice for scene management |
| **Player Persistence** | State store serialization (all transitions) | M_ECSManager is per-scene, player recreated from "gameplay" slice via StateHandoff |
| **ECS Manager** | Per-scene (existing pattern) | Current architecture uses StateHandoff to preserve state across transitions |
| **Bootstrap Pattern** | Root scene with M_StateStore | M_StateStore persists via StateHandoff, M_SceneManager coordinates transitions |
| **Pause Mechanism** | Hybrid (SceneTree.paused + ECS aware) | Godot-native with ECS control, flexible system behavior |
| **Camera Transitions** | Blend between scene cameras | Smooth transitions, hides spawn pop, cinematic feel |
| **Area State Persistence** | Use M_StateStore transient fields | Leverage existing state store mechanism for selective persistence |
| **Save Format** | M_StateStore.save_state() (JSON) | Reuse existing implementation, already handles serialization correctly |
| **Transition Queuing** | Priority-based (pause > gameplay) | Responsive to critical inputs, prevents spam |
| **Door Configuration** | Central registry resource | Single source of truth, easy to overview all connections |
| **Input Blocking** | Block after transition effect starts | Responsive feel, prevents mid-transition issues |
| **Migration Strategy** | Build new, migrate later | Safe, allows testing before affecting existing scenes |
| **Scene History** | Separate for UI vs gameplay | Menu breadcrumbs useful, gameplay transitions explicit |

### Additional Functional Requirements (Based on Architectural Decisions)

#### Redux Integration with M_StateStore

- **FR-059**: System MUST add "scene" state slice to M_StateStore for scene management state
- **FR-060**: Scene slice MUST track: current_scene_id (String), scene_stack (Array), is_transitioning (bool)
- **FR-061**: System MUST implement SceneReducer to handle scene-related actions
- **FR-062**: System MUST implement U_SceneActions module for creating scene transition actions
- **FR-063**: M_SceneManager MUST dispatch actions to M_StateStore (not manage state directly)
- **FR-064**: M_SceneManager MUST subscribe to scene slice updates to react to state changes
- **FR-065**: Scene transitions MUST be triggered by dispatching actions (e.g., U_SceneActions.transition_to())

#### Player State Management

- **FR-066**: Player state MUST be stored in M_StateStore's "gameplay" slice
- **FR-067**: ECS systems MUST dispatch GameplayActions to update player state in store
- **FR-068**: Player entity MUST be recreated from gameplay slice state on each scene load
- **FR-069**: Player components MUST read initial state from M_StateStore during _ready()
- **FR-070**: StateHandoff MUST preserve gameplay slice across scene transitions (existing mechanism)

#### Camera Management

- **FR-071**: System MUST blend camera smoothly between old and new scene cameras during transitions
- **FR-072**: System MUST use a dedicated transition camera for blending (separate from scene cameras)
- **FR-073**: System MUST blend camera position, rotation, and FOV properties
- **FR-074**: Camera blend MUST occur in parallel with fade-in effect to hide transition
- **FR-075**: Each scene MUST define its own scene camera node for consistent camera setup

#### History & Navigation

- **FR-076**: System MUST maintain separate history stacks for UI scenes vs gameplay scenes
- **FR-077**: UI scenes (Menu, Settings) MUST track navigation history for "Back" button functionality
- **FR-078**: Gameplay scenes MUST use explicit transitions (no automatic history)
- **FR-079**: System MUST provide `go_back()` function for UI navigation

#### Bootstrap & Initialization

- **FR-080**: System MUST use root scene pattern with M_StateStore (existing) and M_SceneManager (new)
- **FR-081**: Root scene MUST be set as project main scene in project.godot
- **FR-082**: M_StateStore MUST persist via StateHandoff across scene transitions (existing mechanism)
- **FR-083**: Each scene MUST have its own M_ECSManager (per-scene pattern, existing)
- **FR-084**: Active gameplay scenes MUST load as children of ActiveSceneContainer node
- **FR-085**: M_SceneManager MUST persist in root.tscn and survive scene transitions
- **FR-086**: M_StateStore MUST be in root.tscn but recreated per scene instance via StateHandoff

#### State Synchronization

- **FR-087**: Components MUST keep local state for runtime operations (not query store every frame)
- **FR-088**: Systems MUST dispatch to store on significant changes (health lost, item collected, position threshold crossed)
- **FR-089**: Systems MUST NOT dispatch to store every frame (performance requirement)
- **FR-090**: Systems MUST sync all component state to store before scene transitions
- **FR-091**: Systems MUST sync component state to store when checkpoint reached

#### Scene Slice Management

- **FR-092**: Scene slice MUST have persistent fields (current_scene_id, scene_stack) for save files
- **FR-093**: Scene slice MUST have transient fields (is_transitioning) marked in slice config
- **FR-094**: Scene slice MUST be updated when transition completes (set is_transitioning to false)
- **FR-095**: M_SceneManager MUST dispatch transition_complete action after scene fully loaded

#### Player Spawning

- **FR-096**: M_SceneManager MUST spawn player after gameplay scene loads
- **FR-097**: M_SceneManager MUST check scene type before spawning (only GAMEPLAY scenes get player)
- **FR-098**: Player spawn MUST read position and state from gameplay slice
- **FR-099**: If gameplay slice missing or corrupted, MUST load from last checkpoint file

#### Error Handling Enhancement

- **FR-100**: System MUST fallback to main menu if scene load fails critically
- **FR-101**: System MUST fallback to last checkpoint if player state corrupted
- **FR-102**: System MUST validate scene slice state after StateHandoff restore
- **FR-103**: U_SceneRegistry MUST provide validate_door_pairings() to check configuration integrity

#### Transition Effects Implementation

- **FR-104**: Root scene MUST have TransitionOverlay CanvasLayer for fade effects
- **FR-105**: Root scene MUST have LoadingOverlay CanvasLayer for loading screens
- **FR-106**: Fade effects MUST use ColorRect overlay (not scene visibility)
- **FR-107**: Old scene MUST remain visible during fade-out effect

#### Pause Implementation Details

- **FR-108**: UIOverlayStack in scene tree MUST be source of truth for overlay scenes
- **FR-109**: scene_slice.scene_stack MUST be metadata only (for save/debug)
- **FR-110**: M_SceneManager MUST keep UIOverlayStack and scene_stack in sync
- **FR-111**: Systems MUST check get_tree().paused before processing gameplay logic
- **FR-112**: M_StateStore MUST be modified to add `@export var scene_initial_state: RS_SceneInitialState` and register scene slice in `_initialize_slices()` method following existing boot/menu/gameplay slice pattern

## Architecture Constraints

### No Autoloads

The Scene Manager system must NOT use Godot autoload/singleton configuration. Instead, it follows the existing ECS pattern:

- **Scene Tree Discovery**: Managers join groups (e.g., `scene_manager` group) and are discovered via tree traversal
- **Parent Hierarchy Search**: Components/systems walk parent chain to find managers
- **Root Scene Pattern**: Managers live in root.tscn which serves as persistent container

### Bootstrap Pattern: Root Scene Architecture

**Critical Clarification**: The bootstrap pattern defines how the game initializes and how scenes transition throughout the session.

**Root Scene Lifecycle**:
- `root.tscn` is set as the project's main scene in `project.godot`
- `root.tscn` remains loaded throughout the entire game session (never unloaded)
- Contains persistent managers: M_StateStore, M_SceneManager
- Contains an `ActiveSceneContainer` node (Node or Control) where gameplay/menu scenes are added as children

**Scene Transition Mechanism**:
- Scene transitions DO NOT replace root.tscn
- Transitions work by: unload old child from ActiveSceneContainer → load new child into ActiveSceneContainer
- M_StateStore persists because root.tscn persists (never exits scene tree)
- M_SceneManager persists because root.tscn persists (never exits scene tree)

**StateHandoff Usage**:
- StateHandoff is a **compatibility/safety mechanism**, not the primary persistence strategy
- M_StateStore automatically calls `_preserve_to_handoff()` in `_exit_tree()` and `_restore_from_handoff()` in `_ready()`
- In normal operation, root.tscn never exits, so StateHandoff is dormant
- StateHandoff activates IF root.tscn is somehow reloaded (edge case, development/debug scenario)
- This dual-mechanism design ensures state survival even in unexpected reload scenarios

**Per-Scene M_ECSManager Pattern**:
- Each gameplay/menu scene loaded into ActiveSceneContainer has its own M_ECSManager instance
- When scene is removed from ActiveSceneContainer, its M_ECSManager is destroyed
- When new scene is added, its M_ECSManager initializes
- ECS state is preserved via M_StateStore's "gameplay" slice (player state, entity snapshots)
- Components read from store on `_ready()`, systems dispatch updates to store on significant changes

**Initial Bootstrap Flow**:
1. Godot launches, loads root.tscn as main scene
2. M_StateStore initializes, registers all slices (boot, menu, gameplay, scene)
3. M_SceneManager initializes, subscribes to scene slice updates
4. M_SceneManager dispatches U_SceneActions.transition_to("main_menu") to load first scene
5. Main menu scene loads as child of ActiveSceneContainer
6. Game loop begins

### Integration with Existing Systems

- **M_StateStore** (existing Redux store) manages all game state including new "scene" slice
- **StateHandoff** (existing utility) preserves state slices across scene transitions
- **M_ECSManager** remains per-scene (existing pattern), each scene has its own instance
- **M_SceneManager** (new coordinator) dispatches actions to M_StateStore, manages scene tree
- **ECS Systems** dispatch actions to update state (e.g., GameplayActions.update_player_position())
- **Player Persistence**: State stored in "gameplay" slice, player recreated each scene from state
- **Scene Transitions**: M_SceneManager coordinates, StateHandoff preserves state automatically
- **Hybrid Pause**: SceneTree.paused = true + ECS systems check pause state manually
- **Save/Load**: Use M_StateStore.save_state() / load_state() (existing implementation)

#### UI Manager Integration

Scene Manager acts as a reactive enforcer of navigation state:
- Reads `navigation` slice via `U_NavigationSelectors`
- Reconciles desired overlay stack with actual `UIOverlayStack` children
- Does not own navigation logic (delegated to `U_NavigationReducer`)

See: `docs/ui_manager/ui-manager-prd.md`

### Godot Version

- Target: **Godot 4.5** (current project version)
- Use modern Godot 4.x patterns (signals, typed GDScript, resources, async loading, process_mode)

## Resolved Questions

These questions were answered during architectural planning and integration with existing systems:

1. **State Management**: ✅ **Use existing M_StateStore** - Add "scene" slice to existing Redux store. Reuse save/load, StateHandoff, transient fields

2. **Player Persistence**: ✅ **State store serialization (all transitions)** - Player state stored in "gameplay" slice, recreated from state each scene. M_ECSManager is per-scene so entity cannot persist

3. **ECS Manager Pattern**: ✅ **Per-scene (existing)** - Keep current architecture where each scene has own M_ECSManager. StateHandoff preserves state across transitions

4. **Bootstrap Strategy**: ✅ **Root scene with persistent managers** - root.tscn set as main scene, remains loaded entire session. M_StateStore and M_SceneManager persist in root. Scenes load/unload as children of ActiveSceneContainer. StateHandoff is safety mechanism for edge cases, not primary persistence

5. **Pause Implementation**: ✅ **Hybrid** - Use `get_tree().paused = true` with process_mode configuration, ECS systems manually check pause state

6. **Camera Handling**: ✅ **Blend between scene cameras** - Each scene has its own camera, smooth blend during transitions hides spawn pop

7. **Area State Persistence**: ✅ **Use M_StateStore transient fields** - Leverage existing mechanism. Mark non-persistent data as transient in slice configs

8. **Save Format**: ✅ **M_StateStore.save_state() (JSON)** - Reuse existing implementation with proper Godot type serialization

9. **Transition Queuing**: ✅ **Priority-based** - High-priority transitions (pause, death) interrupt/queue over low-priority (doors). Prevents spam while being responsive

10. **Door Configuration**: ✅ **Central registry (static class)** - U_SceneRegistry static class defines all scene metadata and door pairings as single source of truth

11. **Input Blocking**: ✅ **Block after transition effect starts** - Input remains active until fade-out begins, provides responsive feel while preventing mid-transition issues

12. **Migration Approach**: ✅ **Build new, migrate later** - Develop Scene Manager with new test scenes, keep existing debug scenes working, migrate production scenes when system proven stable

13. **Scene History**: ✅ **Separate for UI vs gameplay** - UI scenes maintain history stack for breadcrumb navigation, gameplay uses explicit transitions only

14. **Player Spawning**: ✅ **M_SceneManager spawns after load** - M_SceneManager spawns player after scene loads, centralizes logic, scenes stay clean

15. **Component State Sync**: ✅ **On significant changes** - Systems dispatch to store when state changes significantly (health lost, item collected, position changes). Balance between sync and performance

16. **Scene Slice Pattern**: ✅ **Hybrid (save data + transition tracking)** - scene_slice has persistent data (current_scene_id) AND transient data (is_transitioning). Mark transient fields in slice config

17. **M_StateStore Lifecycle**: ✅ **Root persistence (primary)** - M_StateStore lives in root.tscn which never unloads. StateHandoff is automatic safety mechanism (calls in _exit_tree/_ready) but dormant in normal operation since root never exits. Both managers persist via root persistence

18. **Missing State Handling**: ✅ **Fallback to last checkpoint** - If gameplay state corrupted or missing, load from last checkpoint save file to prevent total loss

19. **M_SceneManager Pattern**: ✅ **Controller (not view)** - M_SceneManager performs scene operations, THEN dispatches completion to store. Avoids circular loops

20. **Scene Registry**: ✅ **Static GDScript class** - Fast, no file loading, easy validation, matches existing static utility pattern

21. **Transition Effects**: ✅ **CanvasLayer overlay** - ColorRect in root.tscn for fades, keeps old scene visible during transition

22. **Pause Stack**: ✅ **UIOverlayStack is source of truth** - Scene tree reality, scene_slice.scene_stack is just metadata for save/debug

23. **Loading Screen**: ✅ **Preloaded overlay in root** - Simple CanvasLayer with ProgressBar, always available

24. **Error Recovery**: ✅ **Fallback to main menu** - On scene load failure, transition to main menu gracefully

## Open Questions

These questions remain open for future iteration:

1. **Checkpoint System**: How should checkpoints be defined and triggered? (Specific component, trigger zones, manual save points?)
2. **Scene Transition Audio**: Should transition effects support audio cues (whoosh sounds, musical stingers)?
3. **Loading Screen Content**: Should loading screens display tips, lore, controls hints? Static or dynamic content?
4. **Save Slot UI**: Should save slots show thumbnails/screenshots, playtime, level name? Metadata requirements?
5. **Multiplayer Considerations**: Is multiplayer/co-op planned? Scene transitions would need synchronization.

## Implementation Notes

### Recommended Phases

**Phase 1 (P1 Foundation)**:
- Basic scene transition (replace mode)
- State Manager with simple serialization
- Main Menu → Gameplay → Main Menu flow
- Basic fade transition effect

**Phase 2 (P2 Gameplay)**:
- Scene stack (pause system)
- Area transitions with spawn points
- Scene trigger component/system
- State persistence for player/progress

**Phase 3 (P3 Polish)**:
- All transition effects
- Scene preloading system
- End-game flows
- Advanced save system (multiple slots, validation)

### File Structure Recommendation

```
/scripts/
  /managers/
    m_scene_manager.gd          # Scene coordinator (dispatches to M_StateStore)
    m_state_store.gd            # EXISTING - Redux state store

  /state/
    utils/u_state_handoff.gd    # EXISTING - State preservation utility
    /actions/
      u_scene_actions.gd        # NEW - Scene action creators (slice-level)
    /reducers/
      u_scene_reducer.gd        # NEW - Scene slice reducer
    /resources/
      rs_scene_initial_state.gd # NEW - Scene slice initial state

  /scene_management/
    u_scene_registry.gd           # Scene metadata configuration
    /transitions/
      base_transition_effect.gd      # Base transition interface
      trans_instant.gd     # Instant effect implementation
      trans_fade.gd        # Fade effect implementation
      trans_loading_screen.gd # Loading screen implementation

  /ecs/
    c_scene_trigger_component.gd # Trigger component
    s_scene_trigger_system.gd    # Trigger system

/scenes/
  root.tscn                     # Root with M_StateStore + M_SceneManager
  /ui/
    main_menu.tscn
    settings_menu.tscn
    pause_menu.tscn
    loading_screen.tscn
    game_over.tscn
    victory.tscn
    credits.tscn
  /gameplay/
    exterior_template.tscn      # With M_ECSManager (per-scene)
    interior_template.tscn      # With M_ECSManager (per-scene)
    dungeon_template.tscn       # With M_ECSManager (per-scene)

/docs/
  /scene_manager/
    scene-manager-prd.md        # This document
    INTEGRATION_SUMMARY.md      # Integration with existing systems

/tests/
  /integration/
    /scene_manager/
      test_basic_transitions.gd
      test_state_persistence.gd
      test_pause_system.gd
      test_scene_slice.gd       # Test Redux scene slice
```

## Implementation Examples

### Example 1: RS_SceneInitialState Resource

```gdscript
extends Resource
class_name RS_SceneInitialState

## Initial state for scene slice
##
## Defines default values for scene management state fields.
## Used by M_StateStore to initialize scene slice on _ready().

@export var current_scene_id: String = ""
@export var scene_stack: Array[String] = []
@export var is_transitioning: bool = false

## Convert resource to Dictionary for state store
func to_dictionary() -> Dictionary:
    return {
        "current_scene_id": current_scene_id,
        "scene_stack": scene_stack.duplicate(),
        "is_transitioning": is_transitioning
    }
```

### Example 2: U_SceneActions Action Creators

```gdscript
extends RefCounted
class_name U_SceneActions

## Action creators for scene state slice
##
## Provides type-safe action creators using StringName constants.
## All actions are automatically registered on static initialization.

const ACTION_TRANSITION_TO := StringName("scene/transition_to")
const ACTION_TRANSITION_COMPLETE := StringName("scene/transition_complete")
const ACTION_PUSH_OVERLAY := StringName("scene/push_overlay")
const ACTION_POP_OVERLAY := StringName("scene/pop_overlay")

## Static initializer - automatically registers actions
static func _static_init() -> void:
    ActionRegistry.register_action(ACTION_TRANSITION_TO)
    ActionRegistry.register_action(ACTION_TRANSITION_COMPLETE)
    ActionRegistry.register_action(ACTION_PUSH_OVERLAY)
    ActionRegistry.register_action(ACTION_POP_OVERLAY)

## Create a transition_to action
static func transition_to(scene_id: String, transition_type: String = "fade") -> Dictionary:
    return {
        "type": ACTION_TRANSITION_TO,
        "payload": {
            "scene_id": scene_id,
            "transition_type": transition_type
        }
    }

## Create a transition_complete action
static func transition_complete(scene_id: String) -> Dictionary:
    return {
        "type": ACTION_TRANSITION_COMPLETE,
        "payload": {"scene_id": scene_id}
    }

## Create a push_overlay action
static func push_overlay(scene_id: String) -> Dictionary:
    return {
        "type": ACTION_PUSH_OVERLAY,
        "payload": {"scene_id": scene_id}
    }

## Create a pop_overlay action
static func pop_overlay() -> Dictionary:
    return {
        "type": ACTION_POP_OVERLAY,
        "payload": null
    }
```

### Example 3: SceneReducer

```gdscript
extends RefCounted
class_name SceneReducer

## Reducer for scene state slice
##
## Pure function that takes current state and action, returns new state.
## NEVER mutates state directly - always uses .duplicate(true) for immutability.

const U_SceneActions := preload("res://scripts/state/actions/u_scene_actions.gd")

static func reduce(state: Dictionary, action: Dictionary) -> Dictionary:
    var action_type: StringName = action.get("type", StringName())

    match action_type:
        U_SceneActions.ACTION_TRANSITION_TO:
            var new_state: Dictionary = state.duplicate(true)
            var payload: Dictionary = action.get("payload", {})
            new_state["is_transitioning"] = true
            # Don't update current_scene_id yet - wait for transition_complete
            return new_state

        U_SceneActions.ACTION_TRANSITION_COMPLETE:
            var new_state: Dictionary = state.duplicate(true)
            var payload: Dictionary = action.get("payload", {})
            new_state["current_scene_id"] = payload.get("scene_id", "")
            new_state["is_transitioning"] = false
            return new_state

        U_SceneActions.ACTION_PUSH_OVERLAY:
            var new_state: Dictionary = state.duplicate(true)
            var payload: Dictionary = action.get("payload", {})
            var scene_id: String = payload.get("scene_id", "")
            if not scene_id.is_empty():
                var stack: Array = new_state.get("scene_stack", []).duplicate()
                stack.append(scene_id)
                new_state["scene_stack"] = stack
            return new_state

        U_SceneActions.ACTION_POP_OVERLAY:
            var new_state: Dictionary = state.duplicate(true)
            var stack: Array = new_state.get("scene_stack", []).duplicate()
            if not stack.is_empty():
                stack.pop_back()
            new_state["scene_stack"] = stack
            return new_state

        _:
            # Unknown action - return state unchanged
            return state
```

### Example 4: M_StateStore Modification

Add scene slice registration to `m_state_store.gd`:

```gdscript
# In M_StateStore class definition:

@export var boot_initial_state: RS_BootInitialState
@export var menu_initial_state: RS_MenuInitialState
@export var gameplay_initial_state: RS_GameplayInitialState
@export var scene_initial_state: RS_SceneInitialState  # NEW

const BootReducer = preload("res://scripts/state/reducers/u_boot_reducer.gd")
const MenuReducer = preload("res://scripts/state/reducers/u_menu_reducer.gd")
const GameplayReducer = preload("res://scripts/state/reducers/u_gameplay_reducer.gd")
const SceneReducer = preload("res://scripts/state/reducers/u_scene_reducer.gd")  # NEW

func _initialize_slices() -> void:
    # ... existing boot, menu, gameplay registrations ...

    # Register scene slice if initial state provided
    if scene_initial_state != null:
        var scene_config := RS_StateSliceConfig.new(StringName("scene"))
        scene_config.reducer = Callable(SceneReducer, "reduce")
        scene_config.initial_state = scene_initial_state.to_dictionary()
        scene_config.dependencies = []
        scene_config.transient_fields = [StringName("is_transitioning")]
        register_slice(scene_config)
```

### Example 5: M_SceneManager Basic Structure

```gdscript
extends Node
class_name M_SceneManager

## Scene transition coordinator
##
## Dispatches actions to M_StateStore, manages Godot scene tree operations.
## Does NOT store state directly - delegates to M_StateStore.

var _state_store: M_StateStore = null
var _active_scene_container: Node = null
var _current_scene: Node = null

func _ready() -> void:
    add_to_group("scene_manager")

    # Find M_StateStore in parent hierarchy
    _state_store = U_StateUtils.get_store(self)
    if _state_store == null:
        push_error("M_SceneManager: Could not find M_StateStore")
        return

    # Find ActiveSceneContainer
    _active_scene_container = get_node_or_null("../ActiveSceneContainer")
    if _active_scene_container == null:
        push_error("M_SceneManager: Could not find ActiveSceneContainer")
        return

    # Subscribe to scene slice updates
    _state_store.subscribe(_on_state_changed)

    # Initial scene load
    _state_store.dispatch(U_SceneActions.transition_to("main_menu"))

func _on_state_changed(action: Dictionary, new_state: Dictionary) -> void:
    # React to scene slice changes
    var scene_slice: Dictionary = new_state.get("scene", {})
    # Handle state changes if needed

func transition_to_scene(scene_id: String, transition_type: String = "fade") -> void:
    # Dispatch action to state store
    _state_store.dispatch(U_SceneActions.transition_to(scene_id, transition_type))

    # Perform actual scene loading
    await _perform_transition(scene_id, transition_type)

    # Dispatch completion action
    _state_store.dispatch(U_SceneActions.transition_complete(scene_id))

func _perform_transition(scene_id: String, transition_type: String) -> void:
    # 1. Play transition effect (fade out)
    # 2. Unload old scene
    # 3. Load new scene
    # 4. Add to ActiveSceneContainer
    # 5. Play transition effect (fade in)
    pass
```

### Example 6: root.tscn Structure

```
root (Node)
├── M_StateStore
│   └── Properties:
│       ├── boot_initial_state: (Resource: RS_BootInitialState)
│       ├── menu_initial_state: (Resource: RS_MenuInitialState)
│       ├── gameplay_initial_state: (Resource: RS_GameplayInitialState)
│       └── scene_initial_state: (Resource: RS_SceneInitialState)
├── M_SceneManager
├── ActiveSceneContainer (Node)
│   └── [Active scene loaded here dynamically]
├── UIOverlayStack (CanvasLayer)
│   └── [Pause/settings overlays added here]
├── TransitionOverlay (CanvasLayer)
│   └── ColorRect (for fade effects)
└── LoadingOverlay (CanvasLayer)
    └── [Loading screen UI]
```

### Example 7: U_SceneRegistry Static Class

```gdscript
extends RefCounted
class_name U_SceneRegistry

## Static registry for scene metadata and door pairings
##
## Single source of truth for all scene configuration.
## No file loading needed - fast lookups at runtime.

enum SceneType {
	MENU,
	GAMEPLAY,
	UI,
	ENDGAME
}

## All scene metadata
static var _scenes: Dictionary = {
	"main_menu": {
		"path": "res://scenes/ui/main_menu.tscn",
		"type": SceneType.MENU,
		"default_transition": "instant",
		"preload_priority": 10
	},
	"settings_menu": {
		"path": "res://scenes/ui/settings_menu.tscn",
		"type": SceneType.UI,
		"default_transition": "instant",
		"preload_priority": 10
	},
	"pause_menu": {
		"path": "res://scenes/ui/pause_menu.tscn",
		"type": SceneType.UI,
		"default_transition": "instant",
		"preload_priority": 10
	},
	"exterior": {
		"path": "res://scenes/gameplay/exterior_template.tscn",
		"type": SceneType.GAMEPLAY,
		"default_transition": "fade",
		"preload_priority": 0
	},
	"interior_house": {
		"path": "res://scenes/gameplay/interior_house.tscn",
		"type": SceneType.GAMEPLAY,
		"default_transition": "fade",
		"preload_priority": 0
	},
	"game_over": {
		"path": "res://scenes/ui/game_over.tscn",
		"type": SceneType.ENDGAME,
		"default_transition": "fade",
		"preload_priority": 0
	}
}

## Door pairing structure - bidirectional relationships
static var _door_pairings: Dictionary = {
	# Exterior -> Interior
	"exterior_house_door": {
		"target_scene": "interior_house",
		"spawn_point": "entrance_main",
		"reverse_door": "interior_exit_main"
	},
	# Interior -> Exterior (reverse)
	"interior_exit_main": {
		"target_scene": "exterior",
		"spawn_point": "house_exterior_spawn",
		"reverse_door": "exterior_house_door"
	}
}

## Get scene metadata by scene_id
static func get_scene(scene_id: String) -> Dictionary:
	if not _scenes.has(scene_id):
		push_error("U_SceneRegistry: Unknown scene_id: ", scene_id)
		return {}
	return _scenes[scene_id].duplicate(true)

## Get scene path by scene_id
static func get_scene_path(scene_id: String) -> String:
	var scene_data: Dictionary = get_scene(scene_id)
	return scene_data.get("path", "")

## Get scene type by scene_id
static func get_scene_type(scene_id: String) -> SceneType:
	var scene_data: Dictionary = get_scene(scene_id)
	return scene_data.get("type", SceneType.MENU)

## Get default transition for scene
static func get_default_transition(scene_id: String) -> String:
	var scene_data: Dictionary = get_scene(scene_id)
	return scene_data.get("default_transition", "fade")

## Get door pairing by door_id
static func get_door_pairing(door_id: String) -> Dictionary:
	if not _door_pairings.has(door_id):
		push_error("U_SceneRegistry: Unknown door_id: ", door_id)
		return {}
	return _door_pairings[door_id].duplicate(true)

## Validate all door pairings (bidirectional consistency check)
static func validate_door_pairings() -> bool:
	var all_valid := true

	for door_id in _door_pairings:
		var pairing: Dictionary = _door_pairings[door_id]
		var reverse_door: String = pairing.get("reverse_door", "")

		# Check reverse door exists
		if not _door_pairings.has(reverse_door):
			push_error("U_SceneRegistry: door '", door_id, "' reverse_door '", reverse_door, "' not found")
			all_valid = false
			continue

		# Check reverse door points back
		var reverse_pairing: Dictionary = _door_pairings[reverse_door]
		var reverse_reverse: String = reverse_pairing.get("reverse_door", "")
		if reverse_reverse != door_id:
			push_error("U_SceneRegistry: door '", door_id, "' reverse pairing mismatch")
			all_valid = false

		# Check target scene exists
		var target_scene: String = pairing.get("target_scene", "")
		if not _scenes.has(target_scene):
			push_error("U_SceneRegistry: door '", door_id, "' target_scene '", target_scene, "' not found")
			all_valid = false

	return all_valid

## Get all scenes with preload_priority >= threshold
static func get_preloadable_scenes(min_priority: int = 5) -> Array[String]:
	var result: Array[String] = []
	for scene_id in _scenes:
		var priority: int = _scenes[scene_id].get("preload_priority", 0)
		if priority >= min_priority:
			result.append(scene_id)
	return result
```

### Example 8: BaseTransitionEffect Base Class

```gdscript
extends RefCounted
class_name BaseTransitionEffect

## Base class for scene transition effects
##
## Defines interface for all transition types (fade, instant, loading screen, custom).
## M_SceneManager uses this interface to execute transitions.

signal transition_started
signal transition_completed

var _overlay_node: CanvasLayer = null
var _is_active: bool = false

## Initialize with overlay node from root.tscn
func initialize(overlay_node: CanvasLayer) -> void:
	_overlay_node = overlay_node

## Start the transition effect (fade out, etc.)
func start_transition() -> void:
	_is_active = true
	transition_started.emit()

## Update transition progress during async loading (0.0 to 1.0)
func update_progress(progress: float) -> void:
	pass

## Complete the transition effect (fade in, etc.)
func complete_transition() -> void:
	_is_active = false
	transition_completed.emit()

## Check if transition is currently active
func is_active() -> bool:
	return _is_active

## Get expected duration in seconds
func get_duration() -> float:
	return 0.0
```

### Example 9: Trans_Fade Implementation

```gdscript
extends BaseTransitionEffect
class_name Trans_Fade

## Fade to black transition effect

@export var fade_duration: float = 0.3
@export var fade_color: Color = Color.BLACK

var _color_rect: ColorRect = null
var _tween: Tween = null

func initialize(overlay_node: CanvasLayer) -> void:
	super.initialize(overlay_node)

	# Find or create ColorRect for fade effect
	if _overlay_node != null:
		_color_rect = _overlay_node.get_node_or_null("ColorRect")
		if _color_rect == null:
			_color_rect = ColorRect.new()
			_color_rect.name = "ColorRect"
			_color_rect.color = fade_color
			_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			_overlay_node.add_child(_color_rect)

	if _color_rect != null:
		_color_rect.modulate.a = 0.0
		_color_rect.visible = true

func start_transition() -> void:
	super.start_transition()

	if _color_rect == null:
		push_error("Trans_Fade: No ColorRect available")
		return

	# Fade to opaque
	_color_rect.visible = true
	_color_rect.modulate.a = 0.0

	if _tween != null:
		_tween.kill()

	_tween = _overlay_node.create_tween()
	_tween.tween_property(_color_rect, "modulate:a", 1.0, fade_duration)
	await _tween.finished

func complete_transition() -> void:
	if _color_rect == null:
		super.complete_transition()
		return

	# Fade from opaque to transparent
	_color_rect.modulate.a = 1.0

	if _tween != null:
		_tween.kill()

	_tween = _overlay_node.create_tween()
	_tween.tween_property(_color_rect, "modulate:a", 0.0, fade_duration)
	await _tween.finished

	_color_rect.visible = false
	super.complete_transition()

func get_duration() -> float:
	return fade_duration * 2.0
```

### Example 10: Scene Trigger Component

```gdscript
extends BaseECSComponent
class_name C_SceneTriggerComponent

## Component for entities that trigger scene transitions
##
## Attach to Area3D nodes (doors, zone boundaries).

## Unique identifier (matches U_SceneRegistry door_id)
@export var door_id: String = ""

## Target scene override (if empty, uses U_SceneRegistry)
@export var target_scene_id: String = ""

## Spawn point override (if empty, uses U_SceneRegistry)
@export var spawn_point_id: String = ""

## Interaction mode: Auto or Interact
@export_enum("Auto:0", "Interact:1") var trigger_mode: int = 1

## Interaction prompt text
@export var interaction_prompt: String = "Press E to enter"

## Transition effect override
@export var transition_override: String = ""

## Cooldown to prevent rapid re-triggering
@export var trigger_cooldown: float = 1.0

var _last_trigger_time: float = 0.0
var _player_in_area: bool = false
var _area_node: Area3D = null

func get_component_type() -> StringName:
	return StringName("SceneTrigger")

func _ready() -> void:
	super._ready()

	# Find Area3D node
	if get_parent() is Area3D:
		_area_node = get_parent() as Area3D
	elif self is Area3D:
		_area_node = self as Area3D

	if _area_node != null:
		_area_node.body_entered.connect(_on_body_entered)
		_area_node.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node3D) -> void:
	if not U_ECSUtils.is_entity(body):
		return

	_player_in_area = true

	# Auto mode - trigger immediately
	if trigger_mode == 0:
		trigger_transition()

func _on_body_exited(body: Node3D) -> void:
	if U_ECSUtils.is_entity(body):
		_player_in_area = false

func is_player_in_area() -> bool:
	return _player_in_area

func can_trigger() -> bool:
	if not _player_in_area:
		return false

	# Check cooldown
	var current_time: float = Time.get_ticks_msec() / 1000.0
	if current_time - _last_trigger_time < trigger_cooldown:
		return false

	return true

func trigger_transition() -> void:
	if not can_trigger():
		return

	_last_trigger_time = Time.get_ticks_msec() / 1000.0

	# Resolve target scene and spawn point
	var target: String = target_scene_id
	var spawn: String = spawn_point_id
	var transition: String = transition_override

	# Use U_SceneRegistry pairing if door_id is set
	if not door_id.is_empty():
		var pairing: Dictionary = U_SceneRegistry.get_door_pairing(door_id)
		if not pairing.is_empty():
			target = pairing.get("target_scene", target)
			spawn = pairing.get("spawn_point", spawn)

	# Use default transition if not overridden
	if transition.is_empty():
		transition = U_SceneRegistry.get_default_transition(target)

	# Dispatch actions via state store
	var store: M_StateStore = U_StateUtils.get_store(self)
	if store != null:
		# Store spawn point for M_SceneManager
		store.dispatch(U_GameplayActions.set_target_spawn_point(spawn))
		store.dispatch(U_SceneActions.transition_to(target, transition))
```

### Example 11: Scene Trigger System

```gdscript
extends BaseECSSystem
class_name S_SceneTriggerSystem

## System that processes scene trigger components
##
## Handles interaction input for Interact-mode triggers.

const COMPONENT_SCENE_TRIGGER := StringName("SceneTrigger")

func get_system_name() -> StringName:
	return StringName("SceneTriggerSystem")

func process_tick(delta: float) -> void:
	if _ecs_manager == null:
		return

	# Query entities with scene trigger components
	var entities: Array = _ecs_manager.query_entities([COMPONENT_SCENE_TRIGGER])

	for query in entities:
		var trigger: C_SceneTriggerComponent = query.components.get(COMPONENT_SCENE_TRIGGER)
		if trigger == null:
			continue

		# Handle Interact mode triggers
		if trigger.trigger_mode == 1:  # Interact
			if trigger.is_player_in_area():
				# Check for interaction input
				if Input.is_action_just_pressed("interact"):
					trigger.trigger_transition()
```

## Related Documentation

- `/docs/ecs/ecs_architecture.md` - Existing ECS system design
- `/scripts/state/m_state_store.gd` - Existing Redux state store implementation
- `/scripts/state/utils/u_state_handoff.gd` - Existing state preservation utility
- `/docs/scene_manager/INTEGRATION_SUMMARY.md` - Integration details with existing systems
- `/AGENTS.md` - Project quick reference

## Version History

- **v1.0** (2025-10-27): Initial PRD based on user requirements and architecture exploration
- **v1.1** (2025-10-27): Added architectural decisions section, resolved 12 critical design questions, added additional FRs (FR-059 through FR-072) for camera, history, and bootstrap requirements
- **v2.0** (2025-10-27): **MAJOR REVISION** - Integrated with existing M_StateStore (Redux) and per-scene ECS architecture. Removed M_StateManager (use M_StateStore), removed singleton ECS (keep per-scene), removed hybrid player persistence (use state store only). Added FRs for Redux integration (scene slice, SceneActions, SceneReducer). Updated all architectural decisions to reflect existing systems.
- **v2.1** (2025-10-27): Added 24 resolved questions covering all critical implementation details. Added 32 new FRs (FR-080 through FR-111) for state synchronization, scene slice management, player spawning, error handling, transition effects, and pause implementation. Clarified M_SceneManager controller pattern, component state sync frequency, scene slice transient fields, StateHandoff lifecycle, and error recovery strategies.
- **v2.2** (2025-10-27): **AUDIT FIXES** - Corrected critical errors found in comprehensive audit: Fixed FR-005 (singleton → per-scene ECS), removed transition_state field ambiguity, standardized U_SceneActions naming, corrected file structure (u_scene_actions.gd location, removed .tres registry), added FR-112 for M_StateStore modification requirement, added RS_SceneInitialState to Key Entities. **MAJOR CLARIFICATION**: Added comprehensive Bootstrap Pattern section explaining root.tscn lifecycle, ActiveSceneContainer pattern, StateHandoff as safety mechanism vs primary persistence. Updated Resolved Questions #4 and #17 to reflect clarified architecture. Added 6 implementation examples with complete code patterns.
- **v2.3** (2025-10-27): **COMPLETENESS UPDATE** - Filled remaining 5% gaps identified in audit. Added 5 new implementation examples (Examples 7-11): U_SceneRegistry static class with scene metadata and door pairing structure, BaseTransitionEffect base class interface, Trans_Fade implementation, C_SceneTriggerComponent with Area3D integration, S_SceneTriggerSystem for interaction handling. All examples include complete working code, validation methods, and integration patterns. PRD now 100% complete and implementation-ready for all phases.
