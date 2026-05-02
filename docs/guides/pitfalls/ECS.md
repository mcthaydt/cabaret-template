# ECS System Pitfalls

---

## ECS System Pitfalls

- **All ECS systems need @icon annotation**: Every system extending ECSSystem should have `@icon("res://assets/editor_icons/system.svg")` at the top of the file. This provides visual consistency in the Godot editor and makes systems easy to identify in the scene tree. Without this annotation, systems appear with the default script icon.

- **Event-driven state updates can invalidate cached checks**: When systems fire events (like landing events), other systems may respond by modifying entity state (position resets, velocity changes). If your system caches state BEFORE firing the event, subsequent checks may use stale data. **Solution**: Update cached state AFTER events fire, not before. Example: S_JumpSystem marks the player as "on floor" AFTER publishing `EVENT_ENTITY_LANDED` to ensure jump permission checks see post-reset floor state. This prevents race conditions where landing position resets temporarily invalidate `is_on_floor()` checks, blocking immediate jump attempts.
