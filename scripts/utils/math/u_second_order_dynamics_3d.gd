extends RefCounted
class_name U_SecondOrderDynamics3D

const SECOND_ORDER_DYNAMICS := preload("res://scripts/utils/math/u_second_order_dynamics.gd")

var _x: Variant
var _y: Variant
var _z: Variant

func _init(f: float, zeta: float, r: float, initial_value: Vector3 = Vector3.ZERO) -> void:
	_x = SECOND_ORDER_DYNAMICS.new(f, zeta, r, initial_value.x)
	_y = SECOND_ORDER_DYNAMICS.new(f, zeta, r, initial_value.y)
	_z = SECOND_ORDER_DYNAMICS.new(f, zeta, r, initial_value.z)

func step(target: Vector3, dt: float) -> Vector3:
	return Vector3(
		float(_x.step(target.x, dt)),
		float(_y.step(target.y, dt)),
		float(_z.step(target.z, dt))
	)

func reset(value: Vector3) -> void:
	_x.reset(value.x)
	_y.reset(value.y)
	_z.reset(value.z)

func get_value() -> Vector3:
	return Vector3(
		float(_x.get_value()),
		float(_y.get_value()),
		float(_z.get_value())
	)

