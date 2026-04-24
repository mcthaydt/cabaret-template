@icon("res://assets/editor_icons/icn_resource.svg")
extends Node

## Scene marker for per-scene character lighting defaults consumed by M_CharacterLightingManager.
@export var default_profile: RS_CharacterLightingProfile = null

func get_default_profile() -> Resource:
	return default_profile
