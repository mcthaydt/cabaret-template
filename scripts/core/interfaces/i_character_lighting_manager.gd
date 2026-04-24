extends Node
class_name I_CHARACTER_LIGHTING_MANAGER

## Runtime interface for character zone lighting coordination.
##
## Implementations:
## - M_CharacterLightingManager (production)

func set_scene_default_profile(_profile: Resource) -> void:
	push_error("I_CHARACTER_LIGHTING_MANAGER.set_scene_default_profile not implemented")

func register_zone(_zone: Node) -> void:
	push_error("I_CHARACTER_LIGHTING_MANAGER.register_zone not implemented")

func unregister_zone(_zone: Node) -> void:
	push_error("I_CHARACTER_LIGHTING_MANAGER.unregister_zone not implemented")

func refresh_scene_bindings() -> void:
	push_error("I_CHARACTER_LIGHTING_MANAGER.refresh_scene_bindings not implemented")

func set_character_lighting_enabled(_enabled: bool) -> void:
	push_error("I_CHARACTER_LIGHTING_MANAGER.set_character_lighting_enabled not implemented")
