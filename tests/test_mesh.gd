extends SceneTree
## GPU traversal is compared with Godot's independent CPU triangle intersection.

var failures := 0
var checks := 0
var device: RenderingDevice
var mesh_gpu := RCGPU.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	device = RenderingServer.create_local_rendering_device()
	_check(device != null, "Compute device available")
	if device == null:
		quit(1)
		return
	var source := Node3D.new()
	root.add_child(source)
	var instances: Array[MeshInstance3D] = []
	for index in 4:
		var instance := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.radial_segments = 9 + index
		cylinder.height = 1.0 + index * 0.3
		cylinder.top_radius = 0.3
		cylinder.bottom_radius = 0.6
		var arrays := cylinder.surface_get_arrays(0)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		# A second, non-indexed triangle surface exercises the other extraction path.
		var triangle := []
		triangle.resize(Mesh.ARRAY_MAX)
		triangle[Mesh.ARRAY_VERTEX] = PackedVector3Array(
			[Vector3(-1, -1, 0), Vector3(1, -1, 0), Vector3(0, 1, 0)]
		)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, triangle)
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.6, 0.3, 0.2)
		material.emission_enabled = true
		material.emission = Color(0.2, 0.5, 1)
		material.emission_energy_multiplier = 2.0
		mesh.surface_set_material(0, material)
		instance.mesh = mesh
		source.add_child(instance)
		instance.position = Vector3(index - 1.5, 2.5, -index * 0.5)
		instance.rotation = Vector3(index * 0.2, index * 0.3, 0)
		instance.scale = Vector3(1.3, 0.7, 0.9)
		instances.append(instance)
	var bvh := RCMeshBVH.new()
	bvh.build(instances)
	_check(bvh.triangle_count > 100, "Indexed and non-indexed surfaces extracted")
	_check(bvh.node_data.size() > 12, "Nontrivial hierarchy built")
	_validate_links(bvh)
	mesh_gpu.initialize(device, bvh)
	_check(mesh_gpu.ready, "Triangle production shaders compile")
	_test_queries(bvh, instances)
	mesh_gpu.dispatch(PackedByteArray(), 0, 0, 1, Color.BLACK)
	device.submit()
	device.sync()
	var data := device.buffer_get_data(mesh_gpu.buffers[0]).to_float32_array()
	var maximum := 0.0
	for index in range(0, data.size(), 4):
		maximum = maxf(maximum, data[index + 2])
	_check(maximum > 0.1, "Mesh emission reaches cascade radiance")
	_test_gltf(source, bvh.triangle_count)
	_test_hall()
	mesh_gpu.release()
	device.free()
	source.free()
	await _test_controller()
	print("MESH_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _validate_links(bvh: RCMeshBVH) -> void:
	var counts := PackedInt32Array()
	counts.resize(bvh.triangle_count)
	var valid := true
	for node in bvh.node_data.size() / 12:
		var offset := node * 12
		var escape := int(bvh.node_data[offset + 10])
		valid = valid and escape > node and escape <= bvh.node_data.size() / 12
		var first := int(bvh.node_data[offset + 8])
		var count := int(bvh.node_data[offset + 9])
		for triangle in range(first, first + count):
			counts[triangle] += 1
	for count in counts:
		valid = valid and count == 1
	_check(valid, "Escape links terminate and leaves cover triangles exactly once")


func _test_queries(
	bvh: RCMeshBVH, instances: Array[MeshInstance3D], query_count: int = 512
) -> void:
	var queries := PackedFloat32Array()
	var origins: Array[Vector3] = []
	var directions: Array[Vector3] = []
	var random := RandomNumberGenerator.new()
	random.seed = 12873
	for index in query_count:
		var origin := Vector3(random.randf_range(-4, 4), random.randf_range(0, 6), 5)
		var direction := (Vector3(random.randf_range(-2, 2), 2.5, -1) - origin).normalized()
		if index < 3:
			direction = [Vector3.LEFT, Vector3.DOWN, Vector3.FORWARD][index]
		origins.append(origin)
		directions.append(direction)
		queries.append_array(
			[origin.x, origin.y, origin.z, 30, direction.x, direction.y, direction.z, 0]
		)
	var input := device.storage_buffer_create(queries.size() * 4, queries.to_byte_array())
	var output := device.storage_buffer_create(origins.size() * 16)
	var shader := mesh_gpu._compile("validate_mesh.glslinc")
	var pipeline := device.compute_pipeline_create(shader)
	var uniforms := [
		mesh_gpu._uniform(0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, mesh_gpu.scene_buffer),
		mesh_gpu._uniform(1, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, input),
		mesh_gpu._uniform(2, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, output),
		mesh_gpu._uniform(3, RenderingDevice.UNIFORM_TYPE_IMAGE, mesh_gpu.history),
		mesh_gpu._uniform(4, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, mesh_gpu.mesh_nodes),
		mesh_gpu._uniform(5, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, mesh_gpu.mesh_triangles),
		mesh_gpu._history_sampler(),
	]
	var uniform_set := device.uniform_set_create(uniforms, shader, 0)
	var list := device.compute_list_begin()
	device.compute_list_bind_compute_pipeline(list, pipeline)
	device.compute_list_bind_uniform_set(list, uniform_set, 0)
	var params := mesh_gpu._params(0, 0, 0, 1, Color.BLACK)
	params.encode_s32(76, origins.size())
	device.compute_list_set_push_constant(list, params, params.size())
	device.compute_list_dispatch(list, ceili(query_count / 64.0), 1, 1)
	device.compute_list_end()
	device.submit()
	device.sync()
	var results := device.buffer_get_data(output).to_float32_array()
	var vertices := PackedVector3Array()
	for instance in instances:
		for vertex in instance.mesh.get_faces():
			vertices.append(instance.global_transform * vertex)
	var mismatches := 0
	var hits := 0
	for index in origins.size():
		var nearest := 30.0
		for triangle in range(0, vertices.size(), 3):
			var hit = Geometry3D.ray_intersects_triangle(
				origins[index],
				directions[index],
				vertices[triangle],
				vertices[triangle + 1],
				vertices[triangle + 2]
			)
			if hit != null:
				nearest = minf(nearest, origins[index].distance_to(hit))
		if nearest < 30:
			hits += 1
		if absf(nearest - results[index * 4]) > 0.002:
			mismatches += 1
	_check(hits > query_count / 5, "Reference rays exercise geometry")
	_check(
		mismatches == 0, "%d GPU BVH rays agree with independent CPU triangle queries" % query_count
	)
	_check(bvh.triangle_count == vertices.size() / 3, "Triangle extraction preserves all faces")
	for rid in [uniform_set, pipeline, input, output]:
		device.free_rid(rid)


func _test_gltf(source: Node3D, triangle_count: int) -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	_check(document.append_from_scene(source, state) == OK, "Arbitrary scene exports to glTF")
	var buffer := document.generate_buffer(state)
	var imported_state := GLTFState.new()
	_check(document.append_from_buffer(buffer, "", imported_state) == OK, "Binary glTF imports")
	var imported := document.generate_scene(imported_state)
	root.add_child(imported)
	var instances: Array[MeshInstance3D] = []
	for node in imported.find_children("*", "MeshInstance3D", true, false):
		instances.append(node)
	var bvh := RCMeshBVH.new()
	bvh.build(instances)
	_check(bvh.triangle_count == triangle_count, "Imported glTF meshes enter the BVH intact")
	imported.free()


func _test_hall() -> void:
	var generator := ReactorGeometry.new()
	var hall := generator.build(2)
	root.add_child(hall)
	var bvh := RCMeshBVH.new()
	bvh.build([hall])
	_check(bvh.triangle_count == 72012, "Full hall geometry is included in the tracer")
	_validate_links(bvh)
	mesh_gpu.release()
	mesh_gpu = RCGPU.new()
	mesh_gpu.initialize(device, bvh, Vector3(-12, 0, -12), 1.0)
	_test_queries(bvh, [hall], 64)
	hall.free()


func _test_controller() -> void:
	var geometry := Node3D.new()
	root.add_child(geometry)
	var instance := MeshInstance3D.new()
	instance.mesh = BoxMesh.new()
	var original := StandardMaterial3D.new()
	original.albedo_color = Color(0.7, 0.2, 0.1)
	instance.material_override = original
	geometry.add_child(instance)
	var controller := RadianceCascades.new()
	controller.geometry_root = geometry
	root.add_child(controller)
	await controller.initialized
	_check(
		(
			instance.material_override == null
			and instance.get_surface_override_material(0) is ShaderMaterial
		),
		"Mesh material override is replaced by GPU RC shading"
	)
	for frame in 4:
		await process_frame
	_check(controller.frame_count > 0, "Mesh controller dispatches on the render thread")
	instance.position.x = 2.0
	controller.rebuild_geometry()
	await controller.initialized
	_check(
		controller.mesh_bvh.node_data[0] > 1.0, "Explicit rebuild updates moved triangle geometry"
	)
	controller.queue_free()
	for frame in 4:
		await process_frame
	_check(instance.material_override == original, "Controller removal restores original materials")
	geometry.free()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)
