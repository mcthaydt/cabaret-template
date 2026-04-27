extends RefCounted

const U_QB_RULE_BUILDER := preload("res://scripts/core/utils/qb/u_qb_rule_builder.gd")

func build() -> RS_Rule:
	return U_QB_RULE_BUILDER.rule(
		&"camera_zone_fov",
		[
			U_QB_RULE_BUILDER.redux_field("vcam.in_fov_zone", "equals", "true"),
		],
		[
			U_QB_RULE_BUILDER.set_field(&"C_CameraStateComponent", &"target_fov", 60.0),
		],
		{}
	)
