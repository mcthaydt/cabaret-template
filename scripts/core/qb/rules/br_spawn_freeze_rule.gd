extends RefCounted

const U_QB_RULE_BUILDER := preload("res://scripts/core/utils/qb/u_qb_rule_builder.gd")

func build() -> RS_Rule:
	return U_QB_RULE_BUILDER.rule(
		&"spawn_freeze",
		[
			U_QB_RULE_BUILDER.component_field(&"C_SpawnStateComponent", "is_physics_frozen"),
		],
		[
			U_QB_RULE_BUILDER.set_context(&"is_spawn_frozen", true, {}),
		],
		{}
	)
