@icon("res://assets/core/editor_icons/icn_resource.svg")
extends Resource
class_name RSRuleContext

## Typed context resource for rule evaluation. Replaces flat Dictionary-with-magic-string-keys
## context pattern across rule systems, AI context building, and objectives/scene-director evaluation.
##
## Key constants follow the U_AITaskStateKeys pattern: StringName constants for all context
## field names, eliminating bare string literals and String/String dual-keying.
##
## to_dictionary() produces a Dictionary with StringName keys, compatible with QB conditions
## and effects that use _get_dict_value_string_or_name() for reads.

# ============================================================================
# Key constants — common fields
# ============================================================================

const KEY_REDUX_STATE := &"redux_state"
const KEY_STATE := &"state"
const KEY_STATE_STORE := &"state_store"
const KEY_ENTITY_ID := &"entity_id"
const KEY_ENTITY_TAGS := &"entity_tags"
const KEY_ENTITY := &"entity"
const KEY_COMPONENTS := &"components"
const KEY_COMPONENT_DATA := &"component_data"
const KEY_EVENT_NAME := &"event_name"
const KEY_EVENT_PAYLOAD := &"event_payload"
const KEY_RULE_SCORE := &"rule_score"

# ============================================================================
# Key constants — camera-specific fields
# ============================================================================

const KEY_CAMERA_STATE_COMPONENT := &"camera_state_component"
const KEY_CAMERA_ENTITY_ID := &"camera_entity_id"
const KEY_CAMERA_ENTITY_TAGS := &"camera_entity_tags"
const KEY_CAMERA_ENTITY := &"camera_entity"
const KEY_MOVEMENT_COMPONENT := &"movement_component"
const KEY_VCAM_ACTIVE_MODE := &"vcam_active_mode"
const KEY_VCAM_IS_BLENDING := &"vcam_is_blending"
const KEY_VCAM_ACTIVE_VCAM_ID := &"vcam_active_vcam_id"

# ============================================================================
# Key constants — character-specific fields
# ============================================================================

const KEY_CHARACTER_STATE_COMPONENT := &"character_state_component"
const KEY_IS_GAMEPLAY_ACTIVE := &"is_gameplay_active"
const KEY_IS_GROUNDED := &"is_grounded"
const KEY_IS_MOVING := &"is_moving"
const KEY_IS_SPAWN_FROZEN := &"is_spawn_frozen"
const KEY_IS_DEAD := &"is_dead"
const KEY_IS_INVINCIBLE := &"is_invincible"
const KEY_HEALTH_PERCENT := &"health_percent"
const KEY_VERTICAL_STATE := &"vertical_state"
const KEY_HAS_INPUT := &"has_input"

# ============================================================================
# Key constants — AI-specific fields
# ============================================================================

const KEY_BRAIN_COMPONENT := &"brain_component"

# ============================================================================
# Typed properties — common fields
# ============================================================================

var redux_state: Dictionary = {}
var state_store: Variant = null
var entity_id: StringName = &""
var entity_tags: Array = []
var entity: Variant = null
var components: Dictionary = {}
var event_name: StringName = &""
var event_payload: Dictionary = {}

# ============================================================================
# Typed properties — camera-specific fields
# ============================================================================

var camera_state_component: Variant = null
var camera_entity_id: StringName = &""
var camera_entity_tags: Array = []
var camera_entity: Variant = null
var movement_component: Variant = null
var vcam_active_mode: StringName = &""
var vcam_is_blending: bool = false
var vcam_active_vcam_id: StringName = &""

# ============================================================================
# Typed properties — character-specific fields
# ============================================================================

var character_state_component: Variant = null
var is_gameplay_active: bool = true
var is_grounded: bool = false
var is_moving: bool = false
var is_spawn_frozen: bool = false
var is_dead: bool = false
var is_invincible: bool = false
var health_percent: float = 1.0
var vertical_state: int = 0
var has_input: bool = false

# ============================================================================
# Typed properties — AI-specific fields
# ============================================================================

var brain_component: Variant = null

# ============================================================================
# Extra keys — for runtime additions by effects or system-specific extensions
# ============================================================================

var _extra: Dictionary = {}


func set_extra(key: StringName, value: Variant) -> void:
	_extra[key] = value


func get_extra(key: StringName, default: Variant = null) -> Variant:
	if _extra.has(key):
		return _extra[key]
	return default


## Converts typed context to a Dictionary with StringName keys, compatible with
## QB conditions and effects. Null and empty-default fields are omitted to match
## the behavior of the original per-system dictionary construction.
func to_dictionary() -> Dictionary:
	var context: Dictionary = {}

	# Common fields
	if not redux_state.is_empty():
		context[KEY_REDUX_STATE] = redux_state
		context[KEY_STATE] = redux_state  # alias

	if state_store != null:
		context[KEY_STATE_STORE] = state_store

	if entity_id != &"":
		context[KEY_ENTITY_ID] = entity_id

	if not entity_tags.is_empty():
		context[KEY_ENTITY_TAGS] = entity_tags

	if entity != null:
		context[KEY_ENTITY] = entity

	if not components.is_empty():
		context[KEY_COMPONENTS] = components
		context[KEY_COMPONENT_DATA] = components  # alias

	if event_name != &"":
		context[KEY_EVENT_NAME] = event_name

	if not event_payload.is_empty():
		context[KEY_EVENT_PAYLOAD] = event_payload

	# Camera-specific fields
	if camera_state_component != null:
		context[KEY_CAMERA_STATE_COMPONENT] = camera_state_component

	if camera_entity_id != &"":
		context[KEY_CAMERA_ENTITY_ID] = camera_entity_id

	if not camera_entity_tags.is_empty():
		context[KEY_CAMERA_ENTITY_TAGS] = camera_entity_tags

	if camera_entity != null:
		context[KEY_CAMERA_ENTITY] = camera_entity

	if movement_component != null:
		context[KEY_MOVEMENT_COMPONENT] = movement_component

	if vcam_active_mode != &"":
		context[KEY_VCAM_ACTIVE_MODE] = vcam_active_mode

	if vcam_is_blending:
		context[KEY_VCAM_IS_BLENDING] = vcam_is_blending

	if vcam_active_vcam_id != &"":
		context[KEY_VCAM_ACTIVE_VCAM_ID] = vcam_active_vcam_id

	# Character-specific fields
	if character_state_component != null:
		context[KEY_CHARACTER_STATE_COMPONENT] = character_state_component
	# Boolean/numeric fields always included (conditions may check defaults)
	context[KEY_IS_GAMEPLAY_ACTIVE] = is_gameplay_active
	context[KEY_IS_GROUNDED] = is_grounded
	context[KEY_IS_MOVING] = is_moving
	context[KEY_IS_SPAWN_FROZEN] = is_spawn_frozen
	context[KEY_IS_DEAD] = is_dead
	context[KEY_IS_INVINCIBLE] = is_invincible
	context[KEY_HEALTH_PERCENT] = health_percent
	context[KEY_VERTICAL_STATE] = vertical_state
	context[KEY_HAS_INPUT] = has_input

	# AI-specific fields
	if brain_component != null:
		context[KEY_BRAIN_COMPONENT] = brain_component

	# Extra keys from effects or system-specific extensions
	for key in _extra:
		context[key] = _extra[key]

	return context