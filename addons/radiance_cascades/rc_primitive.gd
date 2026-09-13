@tool
class_name RCPrimitive
extends MeshInstance3D
## Geometry consumed by the analytic RC tracer and by Godot's mesh renderer.
## BoxMesh and SphereMesh support arbitrary nonsingular affine transforms.

@export var albedo := Color(0.7, 0.7, 0.7)
@export var radiance := Color.BLACK
## Delta light: radiance is RGB intensity, not finite-surface emission.
@export var point_source := false
@export var point_range := 14.0


func pack() -> PackedFloat32Array:
	assert(mesh is BoxMesh or mesh is SphereMesh, "RC supports BoxMesh and SphereMesh only")
	assert(absf(global_transform.basis.determinant()) > 0.000001, "Singular RC transform")
	var inverse := global_transform.affine_inverse()
	var data := PackedFloat32Array()
	for column in [inverse.basis.x, inverse.basis.y, inverse.basis.z]:
		data.append_array([column.x, column.y, column.z, 0.0])
	data.append_array([inverse.origin.x, inverse.origin.y, inverse.origin.z, 1.0])
	if mesh is BoxMesh:
		var size: Vector3 = mesh.size
		data.append_array([size.x, size.y, size.z, 0.0])
	else:
		assert(is_equal_approx(mesh.height, mesh.radius * 2.0), "RC SphereMesh must be spherical")
		data.append_array([mesh.radius, point_range if point_source else 0.0, 0.0, 1.0])
	var linear := albedo.srgb_to_linear()
	data.append_array([linear.r, linear.g, linear.b, 0.0])
	assert(
		not point_source or mesh is SphereMesh, "Point source requires spherical display geometry"
	)
	data.append_array([radiance.r, radiance.g, radiance.b, float(point_source)])
	return data
