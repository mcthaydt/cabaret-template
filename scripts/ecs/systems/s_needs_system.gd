@icon("res://assets/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_NeedsSystem

const C_NEEDS_COMPONENT := preload("res://scripts/ecs/components/c_needs_component.gd")

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.PRE_PHYSICS

func process_tick(delta: float) -> void:
	if delta <= 0.0:
		return

	var needs_components: Array = get_components(C_NEEDS_COMPONENT.COMPONENT_TYPE)
	for component_variant in needs_components:
		if component_variant == null or not (component_variant is Node):
			continue
		var needs: Node = component_variant as Node
		var settings_variant: Variant = needs.get("settings")
		if settings_variant == null:
			continue
		var settings: Resource = settings_variant as Resource
		if settings == null:
			continue
		var decay: float = maxf(float(settings.get("decay_per_second")), 0.0)
		if decay <= 0.0:
			continue
		var current_hunger: float = float(needs.get("hunger"))
		needs.set("hunger", clampf(current_hunger - (decay * delta), 0.0, 1.0))
