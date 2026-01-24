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

# Service Names
const SERVICE_VFX_MANAGER := StringName("vfx_manager")
const SERVICE_CAMERA_MANAGER := StringName("camera_manager")
const SERVICE_STATE_STORE := StringName("state_store")
