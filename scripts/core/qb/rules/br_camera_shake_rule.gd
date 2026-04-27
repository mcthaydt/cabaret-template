extends RefCounted

const U_QB_RULE_BUILDER := preload("res://scripts/core/utils/qb/u_qb_rule_builder.gd")

func build() -> RS_Rule:
	return U_QB_RULE_BUILDER.rule(
		&"camera_shake",
		[
			U_QB_RULE_BUILDER.event_name(&"entity_death"),
		],
		[
			U_QB_RULE_BUILDER.set_field(
				&"C_CameraStateComponent",
				&"shake_trauma",
				0.5,
				{"operation": "add", "use_clamp": true}
			),
		],
		{"trigger_mode": "event"}
	)
