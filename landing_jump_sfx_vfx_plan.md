# Jump & Landing VFX/SFX Responders Implementation Plan (Strict TDD)

**Overall Progress:** `0%` (0/20 tasks complete)

---

## Phase 1: Jump Sound System (TDD Cycle)

- [ ] 🟥 **Task 1.1: RED - Write test for queue draining**
  - [ ] 🟥 Create `test_jump_sound_system_drains_queue.gd`
  - [ ] 🟥 Test: populate `play_requests`, call `process_tick()`, assert queue is empty
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 1.2: GREEN - Implement minimal queue draining**
  - [ ] 🟥 Implement `process_tick()` that clears `play_requests`
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 1.3: RED - Write test for AudioStreamPlayer3D spawning**
  - [ ] 🟥 Test: verify AudioStreamPlayer3D nodes created and added to scene
  - [ ] 🟥 Test: verify nodes positioned at request payload position
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 1.4: GREEN - Implement audio node spawning**
  - [ ] 🟥 Create `_get_or_create_effects_container()` helper
  - [ ] 🟥 Spawn AudioStreamPlayer3D for each request
  - [ ] 🟥 Set position from payload, add to container
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 1.5: RED - Write test for auto-cleanup**
  - [ ] 🟥 Test: verify `finished` signal connected to `queue_free()`
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 1.6: GREEN - Implement auto-cleanup**
  - [ ] 🟥 Connect `finished` signal on each spawned audio node
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 1.7: REFACTOR - Clean up and optimize**
  - [ ] 🟥 Extract common patterns, improve readability
  - [ ] 🟥 Run all tests → expect PASS

---

## Phase 2: Jump Particles System (TDD Cycle)

- [ ] 🟥 **Task 2.1: RED - Write test for queue draining**
  - [ ] 🟥 Extend `test_jump_event_subscribers.gd` or create new test
  - [ ] 🟥 Test: populate `spawn_requests`, call `process_tick()`, assert queue is empty
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 2.2: GREEN - Implement minimal queue draining**
  - [ ] 🟥 Implement `process_tick()` that clears `spawn_requests`
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 2.3: RED - Write test for GPUParticles3D spawning**
  - [ ] 🟥 Test: verify GPUParticles3D nodes created and configured
  - [ ] 🟥 Test: verify `one_shot = true`, `emitting = true`
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 2.4: GREEN - Implement particle spawning**
  - [ ] 🟥 Spawn GPUParticles3D for each request
  - [ ] 🟥 Set position, one_shot, emitting properties
  - [ ] 🟥 Add `_active_particles: Array` tracking
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 2.5: RED - Write test for particle cleanup**
  - [ ] 🟥 Test: verify finished particles removed from `_active_particles`
  - [ ] 🟥 Test: verify finished particles are queue_free'd
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 2.6: GREEN - Implement particle cleanup**
  - [ ] 🟥 Add cleanup logic in `process_tick()` before processing requests
  - [ ] 🟥 Remove finished particles from array and scene
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 2.7: REFACTOR - Clean up and optimize**
  - [ ] 🟥 Extract common patterns, improve readability
  - [ ] 🟥 Run all tests → expect PASS

---

## Phase 3: Landing Sound System (TDD Cycle)

- [ ] 🟥 **Task 3.1: RED - Write tests for landing sound system**
  - [ ] 🟥 Create `test_landing_event_subscribers.gd`
  - [ ] 🟥 Test: verify subscription to "entity_landed" event
  - [ ] 🟥 Test: verify request recording from event payload
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 3.2: GREEN - Create S_LandingSoundSystem**
  - [ ] 🟥 Copy structure from S_JumpSoundSystem
  - [ ] 🟥 Change event name to "entity_landed"
  - [ ] 🟥 Implement `_on_entity_landed()` handler
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 3.3: RED - Write test for landing audio queue draining**
  - [ ] 🟥 Test: same as jump sound (queue draining + spawning)
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 3.4: GREEN - Implement landing audio spawning**
  - [ ] 🟥 Copy implementation from S_JumpSoundSystem
  - [ ] 🟥 Adapt for landing payload structure
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 3.5: REFACTOR - Extract common audio logic**
  - [ ] 🟥 Consider shared helper for both jump/landing audio
  - [ ] 🟥 Run all tests → expect PASS

---

## Phase 4: Landing Particles System (TDD Cycle)

- [ ] 🟥 **Task 4.1: RED - Write tests for landing particles**
  - [ ] 🟥 Test: verify subscription to "entity_landed" event
  - [ ] 🟥 Test: verify request recording from event payload
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 4.2: GREEN - Create S_LandingParticlesSystem**
  - [ ] 🟥 Copy structure from S_JumpParticlesSystem
  - [ ] 🟥 Change event name to "entity_landed"
  - [ ] 🟥 Implement `_on_entity_landed()` handler
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 4.3: RED - Write test for landing particles queue draining**
  - [ ] 🟥 Test: same as jump particles (spawning + cleanup)
  - [ ] 🟥 Run test → expect FAIL

- [ ] 🟥 **Task 4.4: GREEN - Implement landing particles spawning**
  - [ ] 🟥 Copy implementation from S_JumpParticlesSystem
  - [ ] 🟥 Adapt for landing payload structure
  - [ ] 🟥 Run test → expect PASS

- [ ] 🟥 **Task 4.5: REFACTOR - Extract common particle logic**
  - [ ] 🟥 Consider shared helper for both jump/landing particles
  - [ ] 🟥 Run all tests → expect PASS

---

## Phase 5: Integration & Final Validation

- [ ] 🟥 **Task 5.1: Run full test suite**
  - [ ] 🟥 Run all ECS unit tests
  - [ ] 🟥 Run all integration tests
  - [ ] 🟥 Verify 100% pass rate

- [ ] 🟥 **Task 5.2: Manual integration test**
  - [ ] 🟥 Add all 4 systems to base scene template
  - [ ] 🟥 Run game, jump/land multiple times
  - [ ] 🟥 Verify EffectsContainer appears and populates
  - [ ] 🟥 Verify no errors or warnings in console
  - [ ] 🟥 Verify audio/particle nodes auto-cleanup

---

## TDD Principles Applied

### Red-Green-Refactor Cycle
1. **RED**: Write a failing test that defines desired behavior
2. **GREEN**: Write minimal code to make the test pass
3. **REFACTOR**: Clean up code while keeping tests green

### Test Structure
```gdscript
# tests/unit/ecs/systems/test_jump_sound_system.gd
extends BaseTest

func test_process_tick_drains_play_requests() -> void:
    var system = S_JumpSoundSystem.new()
    add_child(system)

    # Populate queue
    system.play_requests.append({"position": Vector3.ZERO})

    # Process tick
    system.process_tick(0.016)

    # Assert queue empty
    assert_eq(system.play_requests.size(), 0)
```

### Implementation Patterns

**Audio Spawn Pattern**:
```gdscript
func process_tick(_delta: float) -> void:
    if play_requests.is_empty():
        return

    var container = _get_or_create_effects_container()

    for request in play_requests:
        var audio = AudioStreamPlayer3D.new()
        audio.global_position = request.get("position", Vector3.ZERO)
        audio.autoplay = true
        audio.finished.connect(audio.queue_free)
        container.add_child(audio)

    play_requests.clear()
```

**Particle Spawn Pattern**:
```gdscript
func process_tick(_delta: float) -> void:
    # Cleanup finished particles first
    _cleanup_finished_particles()

    if spawn_requests.is_empty():
        return

    var container = _get_or_create_effects_container()

    for request in spawn_requests:
        var particles = GPUParticles3D.new()
        particles.global_position = request.get("position", Vector3.ZERO)
        particles.one_shot = true
        particles.emitting = true
        container.add_child(particles)
        _active_particles.append(particles)

    spawn_requests.clear()

func _cleanup_finished_particles() -> void:
    var i = _active_particles.size() - 1
    while i >= 0:
        var particle = _active_particles[i]
        if particle == null or not particle.emitting:
            if particle != null:
                particle.queue_free()
            _active_particles.remove_at(i)
        i -= 1
```

---

## Files Created/Modified

### Test Files (Created):
- `tests/unit/ecs/systems/test_jump_sound_system.gd`
- `tests/unit/ecs/systems/test_jump_particles_system.gd` (extend existing)
- `tests/unit/ecs/systems/test_landing_sound_system.gd`
- `tests/unit/ecs/systems/test_landing_particles_system.gd`

### Implementation Files (Modified):
- `scripts/ecs/systems/s_jump_sound_system.gd`
- `scripts/ecs/systems/s_jump_particles_system.gd`

### Implementation Files (Created):
- `scripts/ecs/systems/s_landing_sound_system.gd`
- `scripts/ecs/systems/s_landing_particles_system.gd`

---

## Success Criteria

✅ All tests written before implementation
✅ Every test initially fails (RED)
✅ Implementation makes tests pass (GREEN)
✅ Code refactored for clarity (REFACTOR)
✅ 100% test pass rate maintained throughout
✅ No implementation without corresponding test
✅ Manual validation confirms visual/audio behavior
