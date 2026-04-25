@icon("res://assets/core/editor_icons/icn_system.svg")
extends BaseECSSystem
class_name S_NeedsSystem

const C_NEEDS_COMPONENT := preload("res://scripts/demo/ecs/components/c_needs_component.gd")

func get_phase() -> BaseECSSystem.SystemPhase:
	return BaseECSSystem.SystemPhase.PRE_PHYSICS

func process_tick(delta: float) -> void:
	if delta <= 0.0:
		return

	var needs_components: Array = get_components(C_NEEDS_COMPONENT.COMPONENT_TYPE)
	for component_variant in needs_components:
		var needs: C_NeedsComponent = component_variant as C_NeedsComponent
		if needs == null:
			continue
		if needs.settings == null:
			continue
		var decay: float = maxf(needs.settings.decay_per_second, 0.0)
		if decay <= 0.0:
			continue
		needs.hunger = clampf(needs.hunger - (decay * delta), 0.0, 1.0)
