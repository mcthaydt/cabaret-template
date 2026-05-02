extends RefCounted

const U_QB_RULE_BUILDER := preload("res://scripts/core/utils/qb/u_qb_rule_builder.gd")

func build() -> RS_Rule:
	return U_QB_RULE_BUILDER.rule(
		&"camera_speed_fov",
		[
			U_QB_RULE_BUILDER.component_field(&"C_MovementComponent", "speed_magnitude", 0.0, 9.0),
		],
		[
			U_QB_RULE_BUILDER.set_field(
				&"C_CameraStateComponent",
				&"speed_fov_bonus",
				5.0,
				{"scale_by_rule_score": true, "use_clamp": true, "clamp_max": 15.0}
			),
		],
		{"score_threshold": -1.0}
	)
