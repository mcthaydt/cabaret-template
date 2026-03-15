extends RefCounted
class_name U_ECSEventNames

## Centralized ECS event and service name constants.

# VFX Events
const EVENT_SCREEN_SHAKE_REQUEST := StringName("screen_shake_request")
const EVENT_DAMAGE_FLASH_REQUEST := StringName("damage_flash_request")
const EVENT_SILHOUETTE_UPDATE_REQUEST := StringName("silhouette_update_request")

# Gameplay Events
const EVENT_HEALTH_CHANGED := StringName("health_changed")
const EVENT_ENTITY_LANDED := StringName("entity_landed")
const EVENT_ENTITY_DEATH := StringName("entity_death")
const EVENT_ENTITY_DEATH_REQUESTED := StringName("entity_death_requested")
const EVENT_ENTITY_RESPAWN_REQUESTED := StringName("entity_respawn_requested")
const EVENT_CHECKPOINT_ZONE_ENTERED := StringName("checkpoint_zone_entered")
const EVENT_CHECKPOINT_ACTIVATED := StringName("checkpoint_activated")
const EVENT_CHECKPOINT_ACTIVATION_REQUESTED := StringName("checkpoint_activation_requested")
const EVENT_VICTORY_TRIGGERED := StringName("victory_triggered")
const EVENT_VICTORY_EXECUTION_REQUESTED := StringName("victory_execution_requested")
const EVENT_VICTORY_EXECUTED := StringName("victory_executed")
const EVENT_DAMAGE_ZONE_ENTERED := StringName("damage_zone_entered")
const EVENT_DAMAGE_ZONE_EXITED := StringName("damage_zone_exited")
const EVENT_OBJECTIVE_ACTIVATED := StringName("objective_activated")
const EVENT_OBJECTIVE_COMPLETED := StringName("objective_completed")
const EVENT_OBJECTIVE_FAILED := StringName("objective_failed")
const EVENT_OBJECTIVE_VICTORY_TRIGGERED := StringName("objective_victory_triggered")
const EVENT_DIRECTIVE_STARTED := StringName("directive_started")
const EVENT_DIRECTIVE_COMPLETED := StringName("directive_completed")
const EVENT_BEAT_ADVANCED := StringName("beat_advanced")
const EVENT_VCAM_ACTIVE_CHANGED := StringName("vcam_active_changed")
const EVENT_VCAM_BLEND_STARTED := StringName("vcam_blend_started")
const EVENT_VCAM_BLEND_COMPLETED := StringName("vcam_blend_completed")
const EVENT_VCAM_RECOVERY := StringName("vcam_recovery")

# Service Names
const SERVICE_VFX_MANAGER := StringName("vfx_manager")
const SERVICE_CAMERA_MANAGER := StringName("camera_manager")
const SERVICE_STATE_STORE := StringName("state_store")
