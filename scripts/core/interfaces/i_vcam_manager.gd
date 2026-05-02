extends Node
class_name I_VCamManager

func register_vcam(_vcam: Node) -> void:
	push_error("I_VCamManager.register_vcam not implemented")

func unregister_vcam(_vcam: Node) -> void:
	push_error("I_VCamManager.unregister_vcam not implemented")

func set_active_vcam(_vcam_id: StringName, _blend_duration: float = -1.0) -> void:
	push_error("I_VCamManager.set_active_vcam not implemented")

func get_active_vcam_id() -> StringName:
	push_error("I_VCamManager.get_active_vcam_id not implemented")
	return StringName("")

func get_previous_vcam_id() -> StringName:
	push_error("I_VCamManager.get_previous_vcam_id not implemented")
	return StringName("")

func submit_evaluated_camera(_vcam_id: StringName, _result: Dictionary) -> void:
	push_error("I_VCamManager.submit_evaluated_camera not implemented")

func get_blend_progress() -> float:
	push_error("I_VCamManager.get_blend_progress not implemented")
	return 1.0

func is_blending() -> bool:
	push_error("I_VCamManager.is_blending not implemented")
	return false
