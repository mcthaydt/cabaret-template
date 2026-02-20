extends RefCounted
class_name U_ECSEventNames

## Centralized ECS event and service name constants.

# VFX Events
const EVENT_SCREEN_SHAKE_REQUEST := StringName("screen_shake_request")
const EVENT_DAMAGE_FLASH_REQUEST := StringName("damage_flash_request")

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

# Service Names
const SERVICE_VFX_MANAGER := StringName("vfx_manager")
const SERVICE_CAMERA_MANAGER := StringName("camera_manager")
const SERVICE_STATE_STORE := StringName("state_store")
