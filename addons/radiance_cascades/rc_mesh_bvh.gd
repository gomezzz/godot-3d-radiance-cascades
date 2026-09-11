class_name RCMeshBVH
extends RefCounted
## World-space, stackless triangle BVH. Build before replacing source materials.
## Indexed and non-indexed triangle surfaces are both supported.

var node_data := PackedFloat32Array()
var triangle_data := PackedFloat32Array()
var triangle_count := 0
var build_ms := 0.0
var _triangles: Array[PackedFloat32Array] = []
var _bounds: Array[AABB] = []
var _centers: Array[Vector3] = []


func build(instances: Array[MeshInstance3D]) -> void:
	var start := Time.get_ticks_usec()
	node_data.clear()
	triangle_data.clear()
	_triangles.clear()
	_bounds.clear()
	_centers.clear()
	for instance in instances:
		_extract(instance)
	triangle_count = _triangles.size()
	if triangle_count > 0:
		var indices: Array[int] = []
		indices.assign(range(triangle_count))
		_build_node(indices)
	_triangles.clear()
	_bounds.clear()
	_centers.clear()
	build_ms = (Time.get_ticks_usec() - start) / 1000.0


static func colors(instance: MeshInstance3D, surface: int) -> Array[Color]:
	if instance is RCPrimitive:
		return [instance.albedo, instance.radiance]
	var material := instance.get_active_material(surface)
	if material == null:
		# An unassigned Godot material has a white diffuse response.
		return [Color.WHITE, Color.BLACK]
	assert(material is BaseMaterial3D, "Mesh RC requires BaseMaterial3D or RCPrimitive colors")
	var emission := Color.BLACK
	if material.emission_enabled:
		emission = material.emission.srgb_to_linear() * material.emission_energy_multiplier
	return [material.albedo_color, emission]


func _extract(instance: MeshInstance3D) -> void:
	assert(instance.mesh != null, "RC mesh must have geometry")
	assert(instance.skin == null, "Skinned meshes require a deformed triangle snapshot")
	assert(absf(instance.global_basis.determinant()) > 0.000001, "Singular mesh transform")
	for surface in instance.mesh.get_surface_count():
		if instance.mesh is ArrayMesh:
			assert(
				instance.mesh.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES,
				"RC accepts triangle surfaces only"
			)
		else:
			assert(
				instance.mesh is PrimitiveMesh and not instance.mesh is PointMesh,
				"RC requires readable triangle mesh geometry"
			)
		var arrays := instance.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices = PackedInt32Array(range(vertices.size()))
		assert(indices.size() % 3 == 0, "Incomplete triangle surface")
		var palette := colors(instance, surface)
		var albedo := palette[0].srgb_to_linear()
		var emission := palette[1]
		for offset in range(0, indices.size(), 3):
			var a := instance.global_transform * vertices[indices[offset]]
			var b := instance.global_transform * vertices[indices[offset + 1]]
			var c := instance.global_transform * vertices[indices[offset + 2]]
			# Sphere poles and export triangulators can legitimately contain zero-area faces.
			if (b - a).cross(c - a).length_squared() < 1e-14:
				continue
			var bounds := AABB(a, Vector3.ZERO).expand(b).expand(c).grow(0.0001)
			_bounds.append(bounds)
			_centers.append((a + b + c) / 3.0)
			_triangles.append(
				PackedFloat32Array(
					[
						a.x,
						a.y,
						a.z,
						0,
						b.x,
						b.y,
						b.z,
						0,
						c.x,
						c.y,
						c.z,
						0,
						albedo.r,
						albedo.g,
						albedo.b,
						0,
						emission.r,
						emission.g,
						emission.b,
						0
					]
				)
			)


func _build_node(indices: Array[int]) -> void:
	var index := node_data.size() / 12
	var bounds := _bounds[indices[0]]
	var centers := AABB(_centers[indices[0]], Vector3.ZERO)
	for triangle in indices:
		bounds = bounds.merge(_bounds[triangle])
		centers = centers.expand(_centers[triangle])
	node_data.append_array(
		[
			bounds.position.x,
			bounds.position.y,
			bounds.position.z,
			0,
			bounds.end.x,
			bounds.end.y,
			bounds.end.z,
			0,
			0,
			0,
			0,
			0
		]
	)
	if indices.size() <= 4:
		node_data[index * 12 + 8] = triangle_data.size() / 20
		node_data[index * 12 + 9] = indices.size()
		for triangle in indices:
			triangle_data.append_array(_triangles[triangle])
	else:
		var halves := _partition(indices, centers)
		_build_node(halves[0])
		_build_node(halves[1])
	# Escape links skip a complete subtree without a fixed-size GPU stack.
	node_data[index * 12 + 10] = node_data.size() / 12


func _partition(indices: Array[int], centers: AABB) -> Array:
	var best_cost := INF
	var best_axis := -1
	var best_threshold := 0.0
	# Surface-area splitting reduces overlap from long floors, rails, and curved ribs.
	for axis in 3:
		if centers.size[axis] < 0.00001:
			continue
		var counts := PackedInt32Array()
		counts.resize(8)
		var bins: Array[AABB] = []
		bins.resize(8)
		for triangle in indices:
			var bin := mini(
				7,
				int((_centers[triangle][axis] - centers.position[axis]) / centers.size[axis] * 8.0)
			)
			bins[bin] = (
				_bounds[triangle] if counts[bin] == 0 else bins[bin].merge(_bounds[triangle])
			)
			counts[bin] += 1
		var left_count := 0
		var left_bounds := AABB()
		for split in 7:
			if counts[split] > 0:
				left_bounds = bins[split] if left_count == 0 else left_bounds.merge(bins[split])
			left_count += counts[split]
			var right_count := 0
			var right_bounds := AABB()
			for bin in range(split + 1, 8):
				if counts[bin] > 0:
					right_bounds = bins[bin] if right_count == 0 else right_bounds.merge(bins[bin])
				right_count += counts[bin]
			if left_count == 0 or right_count == 0:
				continue
			var cost := _area(left_bounds) * left_count + _area(right_bounds) * right_count
			if cost < best_cost:
				best_cost = cost
				best_axis = axis
				best_threshold = centers.position[axis] + centers.size[axis] * (split + 1) / 8.0
	var left: Array[int] = []
	var right: Array[int] = []
	if best_axis >= 0:
		for triangle in indices:
			if _centers[triangle][best_axis] < best_threshold:
				left.append(triangle)
			else:
				right.append(triangle)
	if left.is_empty() or right.is_empty():
		# Coincident centroids cannot be separated spatially, but still need finite leaves.
		return [indices.slice(0, indices.size() / 2), indices.slice(indices.size() / 2)]
	return [left, right]


func _area(bounds: AABB) -> float:
	var size := bounds.size
	return 2.0 * (size.x * size.y + size.y * size.z + size.z * size.x)
