# Mock Data Removal Plan - Phase 16.5

## Purpose
Remove test-only mock data from state store and refactor tests to use real entity coordination data.

## Audit Results

### Mock vs Production Fields

**RS_GameplayInitialState:**

Mock fields (TO REMOVE):
- `health: int = 100` - Test-only health tracking
- `score: int = 0` - Test-only score tracking  
- `level: int = 1` - Test-only level tracking

Production fields (TO KEEP):
- `paused: bool` - Used by S_PauseSystem and all gameplay systems
- `move_input: Vector2` - Used by S_InputSystem/S_MovementSystem
- `look_input: Vector2` - Used by S_InputSystem/S_RotateToInputSystem
- `jump_pressed: bool` - Used by S_InputSystem/S_JumpSystem
- `jump_just_pressed: bool` - Used by S_InputSystem/S_JumpSystem
- `gravity_scale: float` - Used by S_GravitySystem
- `show_landing_indicator: bool` - Used by S_LandingIndicatorSystem
- `particle_settings: Dictionary` - Used for particle configuration
- `audio_settings: Dictionary` - Used for audio configuration
- `entities: Dictionary` - **Entity Coordination Pattern** (production)

**RS_MenuInitialState:**

All fields are production (no mock data to remove):
- `active_screen: String` - Used for menu navigation
- `pending_character: String` - Character selection (if game has character system)
- `pending_difficulty: String` - Difficulty selection (if game has difficulty system)
- `available_saves: Array` - Save file list (if game has save system)

Note: `pending_character` and `pending_difficulty` may not be implemented yet, but they're not test-only mocks - they're planned production features.

### Mock Actions (TO REMOVE)

**U_GameplayActions:**

Mock actions:
- `ACTION_UPDATE_HEALTH` / `update_health(health: int)`
- `ACTION_UPDATE_SCORE` / `update_score(score: int)`
- `ACTION_SET_LEVEL` / `set_level(level: int)`
- `ACTION_TAKE_DAMAGE` / `take_damage(amount: int)`
- `ACTION_ADD_SCORE` / `add_score(points: int)`

Production actions (KEEP):
- `ACTION_PAUSE_GAME` / `pause_game()`
- `ACTION_UNPAUSE_GAME` / `unpause_game()`

### Mock Reducer Cases (TO REMOVE)

**GameplayReducer:**

Mock cases:
- `U_GameplayActions.ACTION_UPDATE_HEALTH`
- `U_GameplayActions.ACTION_UPDATE_SCORE`
- `U_GameplayActions.ACTION_SET_LEVEL`
- `U_GameplayActions.ACTION_TAKE_DAMAGE`
- `U_GameplayActions.ACTION_ADD_SCORE`

Also check transition action handling:
- `U_TransitionActions.ACTION_TRANSITION_TO_GAMEPLAY` - Applies character/difficulty from menu config (may need to keep if those are real features, or remove if mock)

Production cases (KEEP):
- `U_GameplayActions.ACTION_PAUSE_GAME`
- `U_GameplayActions.ACTION_UNPAUSE_GAME`
- All Phase 16 input/entity/settings actions

### Mock Selectors (TO REMOVE)

**GameplaySelectors:**

Mock selectors:
- `get_is_player_alive(gameplay_state)` - Uses health field
- `get_is_game_over(gameplay_state)` - Uses health field
- `get_completion_percentage(gameplay_state)` - Uses level field
- `get_current_health(gameplay_state)` - Returns health field
- `get_current_score(gameplay_state)` - Returns score field

Production selectors (KEEP):
- `get_is_paused(gameplay_state)` - Used by systems

### Tests Using Mock Data

Files that need refactoring:
1. `tests/unit/state/test_gameplay_slice_reducers.gd` - Tests mock action reducers
2. `tests/unit/state/test_u_gameplay_actions.gd` - Tests mock action creators
3. `tests/unit/state/test_state_selectors.gd` - Tests mock selectors
4. `tests/unit/state/test_state_persistence.gd` - Saves/loads mock fields
5. `tests/unit/state/test_m_state_store.gd` - May use mock fields
6. `tests/unit/integration/test_poc_health_system.gd` - Uses mock health actions
7. `tests/unit/state/integration/test_slice_transitions.gd` - Tests character/difficulty handoff
8. `tests/unit/state/test_sc_state_debug_overlay.gd` - May display mock data
9. `tests/unit/state/test_state_performance.gd` - May benchmark mock actions

### Files to Modify

**State Structure:**
- `scripts/state/resources/rs_gameplay_initial_state.gd` - Remove health, score, level fields
- `resources/state/default_gameplay_initial_state.tres` - Update to match

**Actions:**
- `scripts/state/actions/u_gameplay_actions.gd` - Remove 5 mock actions

**Reducers:**
- `scripts/state/reducers/gameplay_reducer.gd` - Remove 5 mock cases

**Selectors:**
- `scripts/state/selectors/u_gameplay_selectors.gd` - Remove 5 mock selectors

**Systems:**
- `scripts/ecs/systems/s_health_system.gd` - Currently uses mock actions (may need to remove or refactor)
- `scenes/ui/hud_overlay.gd` - Currently displays mock health/score (needs refactor or removal)

**Tests:**
- 9 test files listed above

## Migration Strategy

### Phase 1: Test Refactoring (Safe)
1. Update tests to use entity coordination data instead of mock fields
2. Tests for pause/input/entity snapshots already exist and work
3. Remove tests that validate mock-only behaviors (health/score/level)

### Phase 2: Remove Mock Data (Breaking)
1. Remove mock fields from RS_GameplayInitialState
2. Remove mock actions from U_GameplayActions
3. Remove mock cases from GameplayReducer
4. Remove mock selectors from GameplaySelectors

### Phase 3: System Updates (If Needed)
1. Remove or refactor S_HealthSystem (if it only exists for testing)
2. Remove or refactor HUD overlay (if it only displays mock data)

### Phase 4: Validation
1. Run all tests - verify no mock dependencies remain
2. In-game test - verify state store works with real entity data
3. Debug overlay - verify displays real entity snapshots, not mock fields

## Expected Test Changes

**Tests to Remove Entirely:**
- Tests specifically for mock health/score/level actions and reducers
- Tests for mock selectors (get_current_health, etc.)

**Tests to Refactor:**
- Persistence tests: Save/load entity snapshots instead of health/score
- Transition tests: Remove character/difficulty handoff if those aren't real features
- Integration tests: Use entity coordination pattern instead of mock health

**Tests to Keep As-Is:**
- Pause/unpause tests
- Input action tests
- Entity coordination tests
- Core store tests (dispatch, subscribe, batching, history)

## Success Criteria

1. ✅ All mock fields removed from state structure
2. ✅ All mock actions/reducers/selectors removed
3. ✅ All tests refactored or removed
4. ✅ All remaining tests pass (expect ~160-180 tests remaining)
5. ✅ In-game validation: Entity snapshots work, no mock data visible
6. ✅ Debug overlay shows real entity data only
7. ✅ No breaking changes to production systems (pause, input, entity coordination)

## Timeline

Estimated: 2-3 hours
- Test audit & refactoring: 1 hour
- Mock data removal: 30 minutes
- System updates: 30 minutes
- Validation & testing: 30 minutes
- Documentation updates: 30 minutes
