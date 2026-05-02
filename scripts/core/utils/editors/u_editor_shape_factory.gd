class_name U_EditorShapeFactory
extends RefCounted

static func create_visual_mesh(node_name: String, material: Material = null, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = scale
	mesh_instance.mesh = box_mesh
	if material != null:
		mesh_instance.material_override = material
	return mesh_instance

static func create_collision_capsule(radius: float, height: float, shape_name: String = "CollisionShape3D") -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = shape_name
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	shape.shape = capsule
	return shape

static func create_csg_box(name: String, size: Vector3, color: Color) -> CSGBox3D:
	var box: CSGBox3D = CSGBox3D.new()
	box.name = name
	box.size = size
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	box.material = mat
	return box

static func create_csg_sphere(name: String, radius: float, color: Color) -> CSGSphere3D:
	var sphere: CSGSphere3D = CSGSphere3D.new()
	sphere.name = name
	sphere.radius = radius
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	sphere.material = mat
	return sphere

static func create_csg_cylinder(name: String, radius: float, height: float, color: Color) -> CSGCylinder3D:
	var cylinder: CSGCylinder3D = CSGCylinder3D.new()
	cylinder.name = name
	cylinder.radius = radius
	cylinder.height = height
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	cylinder.material = mat
	return cylinder

static func create_collision_box(shape_name: String, size: Vector3) -> CollisionShape3D:
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = shape_name
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	return shape
