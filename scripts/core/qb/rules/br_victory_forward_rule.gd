extends RefCounted

const U_QB_RULE_BUILDER := preload("res://scripts/core/utils/qb/u_qb_rule_builder.gd")

func build() -> RS_Rule:
	return U_QB_RULE_BUILDER.rule(
		&"victory_forward",
		[
			U_QB_RULE_BUILDER.event_name(&"victory_triggered"),
		],
		[
			U_QB_RULE_BUILDER.publish_event(&"victory_execution_requested"),
		],
		{"trigger_mode": "event"}
	)
