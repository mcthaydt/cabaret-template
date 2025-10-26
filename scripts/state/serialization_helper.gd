extends RefCounted
class_name SerializationHelper

## Helper for serializing Godot types to/from JSON
##
## Handles conversion of Godot-specific types (Vector2, Vector3, Color, etc.)
## to JSON-compatible dictionaries with type markers.

## Convert Godot types to JSON-compatible format
##
## Recursively processes dictionaries and arrays, converting Godot types
## to dictionaries with "_type" markers for reconstruction.
static func godot_to_json(value: Variant) -> Variant:
	# Handle null
	if value == null:
		return null
	
	# Handle Dictionary - recursively convert all values
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			result[key] = godot_to_json(value[key])
		return result
	
	# Handle Array - recursively convert all elements
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(godot_to_json(item))
		return result
	
	# Handle Vector2
	if value is Vector2:
		var v: Vector2 = value as Vector2
		return {"_type": "Vector2", "x": v.x, "y": v.y}
	
	# Handle Vector3
	if value is Vector3:
		var v: Vector3 = value as Vector3
		return {"_type": "Vector3", "x": v.x, "y": v.y, "z": v.z}
	
	# Handle Vector4
	if value is Vector4:
		var v: Vector4 = value as Vector4
		return {"_type": "Vector4", "x": v.x, "y": v.y, "z": v.z, "w": v.w}
	
	# Handle Color
	if value is Color:
		var c: Color = value as Color
		return {"_type": "Color", "r": c.r, "g": c.g, "b": c.b, "a": c.a}
	
	# Handle Quaternion
	if value is Quaternion:
		var q: Quaternion = value as Quaternion
		return {"_type": "Quaternion", "x": q.x, "y": q.y, "z": q.z, "w": q.w}
	
	# Handle Rect2
	if value is Rect2:
		var r: Rect2 = value as Rect2
		return {
			"_type": "Rect2",
			"position": godot_to_json(r.position),
			"size": godot_to_json(r.size)
		}
	
	# Handle AABB
	if value is AABB:
		var a: AABB = value as AABB
		return {
			"_type": "AABB",
			"position": godot_to_json(a.position),
			"size": godot_to_json(a.size)
		}
	
	# Handle Plane
	if value is Plane:
		var p: Plane = value as Plane
		return {
			"_type": "Plane",
			"normal": godot_to_json(p.normal),
			"d": p.d
		}
	
	# Handle Basis
	if value is Basis:
		var b: Basis = value as Basis
		return {
			"_type": "Basis",
			"x": godot_to_json(b.x),
			"y": godot_to_json(b.y),
			"z": godot_to_json(b.z)
		}
	
	# Handle Transform2D
	if value is Transform2D:
		var t: Transform2D = value as Transform2D
		return {
			"_type": "Transform2D",
			"origin": godot_to_json(t.origin),
			"x": godot_to_json(t.x),
			"y": godot_to_json(t.y)
		}
	
	# Handle Transform3D
	if value is Transform3D:
		var t: Transform3D = value as Transform3D
		return {
			"_type": "Transform3D",
			"origin": godot_to_json(t.origin),
			"basis": godot_to_json(t.basis)
		}
	
	# Primitive types and StringName pass through
	if value is String or value is StringName or value is int or value is float or value is bool:
		return value
	
	# Unknown type - warn and pass through
	push_warning("SerializationHelper: Unknown type %s, passing through" % typeof(value))
	return value

## Convert JSON data back to Godot types
##
## Reconstructs Godot types from dictionaries with "_type" markers.
## Recursively processes dictionaries and arrays.
static func json_to_godot(value: Variant) -> Variant:
	# Handle null
	if value == null:
		return null
	
	# Handle Dictionary
	if value is Dictionary:
		var dict: Dictionary = value as Dictionary
		
		# Check for type marker
		if dict.has("_type"):
			var type_name: String = dict.get("_type", "")
			
			match type_name:
				"Vector2":
					return Vector2(
						dict.get("x", 0.0),
						dict.get("y", 0.0)
					)
				
				"Vector3":
					return Vector3(
						dict.get("x", 0.0),
						dict.get("y", 0.0),
						dict.get("z", 0.0)
					)
				
				"Vector4":
					return Vector4(
						dict.get("x", 0.0),
						dict.get("y", 0.0),
						dict.get("z", 0.0),
						dict.get("w", 0.0)
					)
				
				"Color":
					return Color(
						dict.get("r", 0.0),
						dict.get("g", 0.0),
						dict.get("b", 0.0),
						dict.get("a", 1.0)
					)
				
				"Quaternion":
					return Quaternion(
						dict.get("x", 0.0),
						dict.get("y", 0.0),
						dict.get("z", 0.0),
						dict.get("w", 1.0)
					)
				
				"Rect2":
					return Rect2(
						json_to_godot(dict.get("position", Vector2.ZERO)),
						json_to_godot(dict.get("size", Vector2.ZERO))
					)
				
				"AABB":
					return AABB(
						json_to_godot(dict.get("position", Vector3.ZERO)),
						json_to_godot(dict.get("size", Vector3.ZERO))
					)
				
				"Plane":
					return Plane(
						json_to_godot(dict.get("normal", Vector3.UP)),
						dict.get("d", 0.0)
					)
				
				"Basis":
					return Basis(
						json_to_godot(dict.get("x", Vector3.RIGHT)),
						json_to_godot(dict.get("y", Vector3.UP)),
						json_to_godot(dict.get("z", Vector3.BACK))
					)
				
				"Transform2D":
					var t := Transform2D()
					t.origin = json_to_godot(dict.get("origin", Vector2.ZERO))
					t.x = json_to_godot(dict.get("x", Vector2.RIGHT))
					t.y = json_to_godot(dict.get("y", Vector2.DOWN))
					return t
				
				"Transform3D":
					var t := Transform3D()
					t.origin = json_to_godot(dict.get("origin", Vector3.ZERO))
					t.basis = json_to_godot(dict.get("basis", Basis()))
					return t
				
				_:
					push_warning("SerializationHelper: Unknown type marker '%s'" % type_name)
					return dict
		
		# Regular dictionary - recursively convert values
		var result: Dictionary = {}
		for key in dict:
			result[key] = json_to_godot(dict[key])
		return result
	
	# Handle Array - recursively convert elements
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(json_to_godot(item))
		return result
	
	# Primitive types pass through
	return value
