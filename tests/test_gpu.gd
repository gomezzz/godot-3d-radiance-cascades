extends SceneTree
## Integration tests execute the production GLSL on a real local RenderingDevice.

var checks := 0
var failures := 0
var device: RenderingDevice
var gpu: RCGPU


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	device = RenderingServer.create_local_rendering_device()
	if device == null:
		push_error("GPU tests require a compute-capable renderer; do not use --headless")
		quit(1)
		return
	gpu = RCGPU.new()
	gpu.initialize(device)
	_check(gpu.ready, "Production compute shaders compile")
	if not gpu.ready:
		quit(1)
		return
	_test_intervals()
	_test_empty_space()
	_test_opaque_scene()
	_test_emitter_and_occlusion()
	_test_transforms()
	_test_bounce()
	gpu.release()
	device.free()
	print("GPU_TESTS: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_intervals() -> void:
	_check(RCGPU.interval_at(0).x == 0.0, "First interval starts at zero")
	for level in range(1, RCGPU.LEVELS):
		_check(
			RCGPU.interval_at(level).x == RCGPU.interval_at(level - 1).y,
			"Cascade intervals are contiguous: %d" % level
		)


func _test_empty_space() -> void:
	var sky := Color(0.25, 0.5, 1.0)
	var result := _dispatch([], 0.0, sky)
	var maximum_error := 0.0
	for y in result.get_height():
		for x in result.get_width():
			var pixel := result.get_pixel(x, y)
			maximum_error = maxf(maximum_error, absf(pixel.r - sky.r))
			maximum_error = maxf(maximum_error, absf(pixel.g - sky.g))
			maximum_error = maxf(maximum_error, absf(pixel.b - sky.b))
	_check(maximum_error < 0.002, "Constant environment conserved across all probes / lobes")
	var data := device.buffer_get_data(gpu.buffers[0]).to_float32_array()
	var transparent := true
	for index in range(3, data.size(), 4):
		transparent = transparent and is_equal_approx(data[index], 1.0)
	_check(transparent, "Empty intervals preserve unit transmittance")
	result = _dispatch([], 0.0, Color.BLACK)
	_check(_energy(result) < 0.00001, "Removing all emission clears previous lighting")


func _test_opaque_scene() -> void:
	var solid := _box(Vector3(0, 4, 0), Vector3(100, 100, 100), Color.BLACK)
	var result := _dispatch([solid], 0.0, Color.WHITE)
	_check(_energy(result) < 0.00001, "Opaque solid blocks the environment")
	var data := device.buffer_get_data(gpu.buffers[0]).to_float32_array()
	var opaque := true
	for index in range(3, data.size(), 4):
		opaque = opaque and is_zero_approx(data[index])
	_check(opaque, "Opaque intervals have zero transmittance")
	solid.free()


func _test_emitter_and_occlusion() -> void:
	var emitter := _box(Vector3(0.8, 2.25, 0.25), Vector3(0.1, 2, 2), Color(2, 0.5, 0.1))
	var first := _dispatch([emitter], 0.0, Color.BLACK)
	var probe := Vector3i(12, 4, 12)
	var lit := _lobe(first, probe, 0).r
	_check(lit > 0.4, "Near emitter illuminates facing lobe")
	_check(_lobe(first, probe, 1).r < lit * 0.15, "Opposite lobe rejects behind-normal light")
	emitter.radiance *= 2.0
	var second := _dispatch([emitter], 0.0, Color.BLACK)
	_check(
		absf(_lobe(second, probe, 0).r / lit - 2.0) < 0.02,
		"Doubling emitter radiance doubles received irradiance"
	)
	var blocker := _box(Vector3(0.5, 2.25, 0.25), Vector3(0.1, 2.5, 2.5), Color.BLACK)
	var blocked := _dispatch([emitter, blocker], 0.0, Color.BLACK)
	_check(_lobe(blocked, probe, 0).r < lit * 0.1, "Near blocker occludes emissive geometry")
	blocker.position.x = -3.0
	var restored := _dispatch([emitter, blocker], 0.0, Color.BLACK)
	_check(_lobe(restored, probe, 0).r > lit * 1.8, "Moving blocker restores illumination")
	var finite := true
	for buffer in gpu.buffers:
		var values := device.buffer_get_data(buffer).to_float32_array()
		for index in values.size():
			finite = finite and is_finite(values[index]) and values[index] >= 0.0
			if index % 4 == 3:
				finite = finite and values[index] <= 1.00001
	_check(finite, "All cascade samples finite, nonnegative; transmittance bounded")
	emitter.free()
	blocker.free()


func _test_transforms() -> void:
	var emitter := _box(Vector3(0.8, 2.25, 0.25), Vector3(0.1, 2, 2), Color(2, 1, 0.5))
	var first := _dispatch([emitter], 0.0, Color.BLACK)
	emitter.position = Vector3(0.25, 2.25, -0.8)
	emitter.rotation.y = PI * 0.5
	var rotated := _dispatch([emitter], 0.0, Color.BLACK)
	_check(
		(
			absf(_lobe(first, Vector3i(12, 4, 12), 0).r - _lobe(rotated, Vector3i(12, 4, 11), 5).r)
			< 0.02
		),
		"Rotated boxes preserve world-space intersections"
	)
	var sphere := SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	emitter.mesh = sphere
	emitter.rotation = Vector3.ZERO
	emitter.position = Vector3(0.8, 2.25, 0.25)
	emitter.scale = Vector3(0.5, 2.0, 2.0)
	first = _dispatch([emitter], 0.0, Color.BLACK)
	_check(_lobe(first, Vector3i(12, 4, 12), 0).r > 0.1, "Nonuniformly scaled spheres emit light")
	emitter.position = Vector3(0.25, 2.25, -0.8)
	emitter.rotation.y = PI * 0.5
	rotated = _dispatch([emitter], 0.0, Color.BLACK)
	_check(
		(
			absf(_lobe(first, Vector3i(12, 4, 12), 0).r - _lobe(rotated, Vector3i(12, 4, 11), 5).r)
			< 0.02
		),
		"Rotated ellipsoids preserve world-space ray distance"
	)
	emitter.free()


func _test_bounce() -> void:
	var floor_object := _box(Vector3(0, -0.15, 0), Vector3(8, 0.3, 8), Color.BLACK)
	var wall := _box(Vector3(0, 2, -3), Vector3(8, 4, 0.3), Color.BLACK)
	var emitter := _box(Vector3(0, 3, 0), Vector3(2, 0.1, 2), Color(3, 2, 1))
	var objects: Array[RCPrimitive] = [floor_object, wall, emitter]
	var direct := _dispatch(objects, 0.0, Color.BLACK)
	var bounced: Image
	for iteration in 8:
		bounced = _dispatch(objects, 0.65, Color.BLACK)
	_check(_energy(bounced) > _energy(direct) * 1.03, "Diffuse feedback adds indirect energy")
	_check(_energy(bounced) < _energy(direct) * 3.0, "Diffuse feedback remains bounded")
	for object in objects:
		object.free()


func _dispatch(objects: Array[RCPrimitive], bounce: float, sky: Color) -> Image:
	var data := PackedFloat32Array()
	for object in objects:
		data.append_array(object.pack())
	gpu.dispatch(data.to_byte_array(), objects.size(), bounce, 1.0, sky)
	device.submit()
	device.sync()
	var raw := device.texture_get_data(gpu.output, 0)
	return Image.create_from_data(
		RCGPU.GRID.x * 6, RCGPU.GRID.y * RCGPU.GRID.z, false, Image.FORMAT_RGBAH, raw
	)


func _box(position: Vector3, size: Vector3, emission: Color) -> RCPrimitive:
	var object := RCPrimitive.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	object.mesh = mesh
	root.add_child(object)
	object.position = position
	object.radiance = emission
	return object


func _lobe(image: Image, probe: Vector3i, face: int) -> Color:
	return image.get_pixel(probe.x + face * RCGPU.GRID.x, probe.y + probe.z * RCGPU.GRID.y)


func _energy(image: Image) -> float:
	var sum := 0.0
	for y in range(0, image.get_height(), 4):
		for x in range(0, image.get_width(), 4):
			var color := image.get_pixel(x, y)
			sum += color.r + color.g + color.b
	return sum


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)
