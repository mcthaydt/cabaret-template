extends RefCounted

const U_QB_RULE_BUILDER := preload("res://scripts/core/utils/qb/u_qb_rule_builder.gd")

func build() -> RS_Rule:
	return U_QB_RULE_BUILDER.rule(
		&"pause_gate_shell",
		[
			U_QB_RULE_BUILDER.redux_field("navigation.shell", RS_ConditionReduxField.MATCH_NOT_EQUALS, "gameplay"),
		],
		[
			U_QB_RULE_BUILDER.set_context(&"is_gameplay_active", false, {}),
		],
		{
			"decision_group": &"pause_gate",
		}
	)
