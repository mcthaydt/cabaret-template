extends RefCounted

const U_QB_RULE_BUILDER := preload("res://scripts/core/utils/qb/u_qb_rule_builder.gd")

func build() -> RS_Rule:
	return U_QB_RULE_BUILDER.rule(
		&"camera_landing_impact",
		[
			U_QB_RULE_BUILDER.event_name(&"entity_landed"),
			U_QB_RULE_BUILDER.event_payload("fall_speed", "normalize", 5.0, 30.0),
		],
		[
			U_QB_RULE_BUILDER.set_field(
				&"C_CameraStateComponent",
				&"landing_impact_offset",
				Vector3(0, -0.3, 0),
				{"scale_by_rule_score": true}
			),
		],
		{"trigger_mode": "event", "score_threshold": -1.0}
	)
