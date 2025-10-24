# Jump & Landing VFX/SFX Responders Implementation Plan

**This is an ECS system, so please review the ecs_architecture.md document before beginning**
**Overall Progress:** `0%` (0/12 tasks complete)

---

## Phase 1: Jump Sound System

- [ ] 🟥 **Task 1.1: Implement S_JumpSoundSystem.process_tick()**
  - [ ] 🟥 Early return if `play_requests` is empty
  - [ ] 🟥 Get/create EffectsContainer (via `_get_or_create_effects_container()`)
  - [ ] 🟥 Iterate `play_requests`, spawn AudioStreamPlayer3D nodes
  - [ ] 🟥 Position nodes at request payload position
  - [ ] 🟥 Connect `finished` signal → `queue_free()`
  - [ ] 🟥 Clear `play_requests` queue after processing

- [ ] 🟥 **Task 1.2: Add helper method `_get_or_create_effects_container()`**
  - [ ] 🟥 Check scene tree group "effects_container"
  - [ ] 🟥 If missing, create Node3D, name it "EffectsContainer"
  - [ ] 🟥 Add to scene root and join group

---

## Phase 2: Jump Particles System

- [ ] 🟥 **Task 2.1: Implement S_JumpParticlesSystem.process_tick()**
  - [ ] 🟥 Early return if `spawn_requests` is empty
  - [ ] 🟥 Get/create EffectsContainer
  - [ ] 🟥 Iterate `spawn_requests`, spawn GPUParticles3D nodes
  - [ ] 🟥 Position nodes at request payload position
  - [ ] 🟥 Set `one_shot = true`, `emitting = true`
  - [ ] 🟥 Track spawned particles in `_active_particles` array
  - [ ] 🟥 Clear `spawn_requests` queue after processing

- [ ] 🟥 **Task 2.2: Add particle cleanup logic**
  - [ ] 🟥 Add `_active_particles: Array` variable
  - [ ] 🟥 Each tick, check `_active_particles` for finished emitters
  - [ ] 🟥 Remove and `queue_free()` particles where `emitting == false`

---

## Phase 3: Landing Sound System

- [ ] 🟥 **Task 3.1: Create S_LandingSoundSystem file**
  - [ ] 🟥 Copy structure from S_JumpSoundSystem
  - [ ] 🟥 Subscribe to "entity_landed" event instead of "entity_jumped"
  - [ ] 🟥 Extract landing-specific payload fields

- [ ] 🟥 **Task 3.2: Implement S_LandingSoundSystem.process_tick()**
  - [ ] 🟥 Same logic as jump sound (spawn AudioStreamPlayer3D)
  - [ ] 🟥 Use landing position from event payload

---

## Phase 4: Landing Particles System

- [ ] 🟥 **Task 4.1: Create S_LandingParticlesSystem file**
  - [ ] 🟥 Copy structure from S_JumpParticlesSystem
  - [ ] 🟥 Subscribe to "entity_landed" event
  - [ ] 🟥 Extract landing-specific payload fields

- [ ] 🟥 **Task 4.2: Implement S_LandingParticlesSystem.process_tick()**
  - [ ] 🟥 Same logic as jump particles (spawn GPUParticles3D)
  - [ ] 🟥 Use landing position from event payload
  - [ ] 🟥 Track and cleanup particles

---

## Phase 5: Testing & Validation

- [ ] 🟥 **Task 5.1: Manual integration test**
  - [ ] 🟥 Add all 4 systems to base scene template
  - [ ] 🟥 Run game, verify no errors when jumping/landing
  - [ ] 🟥 Verify EffectsContainer appears in scene tree
  - [ ] 🟥 Verify audio/particle nodes spawn and auto-cleanup

- [ ] 🟥 **Task 5.2: Unit tests (optional future enhancement)**
  - [ ] 🟥 Test queue draining behavior
  - [ ] 🟥 Test EffectsContainer creation
  - [ ] 🟥 Test node cleanup

---

## Implementation Notes

### Event Payloads
- **entity_jumped**: Contains `position`, `entity`, `velocity`, `jump_force`, etc.
- **entity_landed**: Contains `position`, `entity`, `velocity`, `landing_time`, etc.

### EffectsContainer Pattern
```gdscript
func _get_or_create_effects_container() -> Node:
    var containers = get_tree().get_nodes_in_group("effects_container")
    if containers.size() > 0:
        return containers[0]

    var container = Node3D.new()
    container.name = "EffectsContainer"
    get_tree().current_scene.add_child(container)
    container.add_to_group("effects_container")
    return container
```

### Audio Spawn Pattern
```gdscript
var audio = AudioStreamPlayer3D.new()
audio.global_position = request["position"]
# audio.stream = settings.jump_sound  # User provides later
audio.autoplay = true
audio.finished.connect(audio.queue_free)
container.add_child(audio)
```

### Particle Spawn Pattern
```gdscript
var particles = GPUParticles3D.new()
particles.global_position = request["position"]
particles.one_shot = true
particles.emitting = true
# particles.process_material = settings.jump_particles  # User provides later
container.add_child(particles)
_active_particles.append(particles)
```

### Particle Cleanup Pattern
```gdscript
# In process_tick(), before processing new requests:
var i = _active_particles.size() - 1
while i >= 0:
    var particle = _active_particles[i]
    if not particle.emitting:
        particle.queue_free()
        _active_particles.remove_at(i)
    i -= 1
```

---

## Files Modified/Created

### Modified:
- `scripts/ecs/systems/s_jump_sound_system.gd` (~40 lines added)
- `scripts/ecs/systems/s_jump_particles_system.gd` (~50 lines added)

### Created:
- `scripts/ecs/systems/s_landing_sound_system.gd` (~70 lines, mirrors jump sound)
- `scripts/ecs/systems/s_landing_particles_system.gd` (~80 lines, mirrors jump particles)

---

## Success Criteria

✅ All 4 systems drain their request queues each tick
✅ Audio/particle nodes spawn at correct positions
✅ One-shot effects auto-cleanup after playing
✅ EffectsContainer created on-demand
✅ No errors in console during jump/landing
✅ Existing tests remain passing
✅ Systems ready to accept audio/particle assets when provided
