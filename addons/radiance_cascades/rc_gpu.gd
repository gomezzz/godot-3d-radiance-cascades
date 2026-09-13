class_name RCGPU
extends RefCounted
## All methods run on the render thread, or on the owner of a local test RD.

const GRID := Vector3i(24, 16, 24)
const ORIGIN := Vector3(-6, 0, -6)
const LEVELS := 5
const MAX_OBJECTS := 64
const STRIDE := 112
const SHADER_ROOT := "res://addons/radiance_cascades/shaders/"

var rd: RenderingDevice
var output: RID
var history: RID
var scene_buffer: RID
var buffers: Array[RID] = []
var cascade_sets: Array[RID] = []
var resolve_set: RID
var cascade_pipeline: RID
var resolve_pipeline: RID
var resources: Array[RID] = []
var ready := false
var failure := ""
var volume_origin := ORIGIN
var base_spacing := 0.5
var mesh_node_count := 0
var mesh_nodes: RID
var mesh_triangles: RID
var linear_sampler: RID
var visibility_merge := false
var point_index := -1
var debug_output: RID
var debug_pipeline: RID
var debug_set: RID


static func grid_at(level: int) -> Vector3i:
	var divisor := 1 << level
	return Vector3i(
		ceili(float(GRID.x) / divisor),
		ceili(float(GRID.y) / divisor),
		ceili(float(GRID.z) / divisor)
	)


static func interval_at(level: int) -> Vector2:
	return Vector2(0.75 * ((1 << level) - 1), 0.75 * ((1 << (level + 1)) - 1))


func initialize(
	device: RenderingDevice,
	mesh_bvh: RCMeshBVH = null,
	origin: Vector3 = ORIGIN,
	spacing: float = 0.5
) -> void:
	rd = device
	volume_origin = origin
	base_spacing = spacing
	assert(spacing > 0.0, "Probe spacing must be positive")
	if rd == null:
		failure = "Radiance Cascades requires Forward+ or Mobile with a compute-capable GPU."
		return
	var cascade_shader := _compile("cascade.glslinc")
	var resolve_shader := _compile("resolve.glslinc")
	if not failure.is_empty():
		return
	cascade_pipeline = _keep(rd.compute_pipeline_create(cascade_shader))
	resolve_pipeline = _keep(rd.compute_pipeline_create(resolve_shader))
	scene_buffer = _keep(rd.storage_buffer_create(MAX_OBJECTS * STRIDE))
	var nodes := PackedByteArray()
	var triangles := PackedByteArray()
	if mesh_bvh != null:
		nodes = mesh_bvh.node_data.to_byte_array()
		triangles = mesh_bvh.triangle_data.to_byte_array()
	mesh_node_count = nodes.size() / 48
	if nodes.is_empty():
		nodes.resize(48)
		triangles.resize(80)
	mesh_nodes = _keep(rd.storage_buffer_create(nodes.size(), nodes))
	mesh_triangles = _keep(rd.storage_buffer_create(triangles.size(), triangles))
	output = _texture()
	history = _texture()
	var sampler_state := RDSamplerState.new()
	sampler_state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	sampler_state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	linear_sampler = _keep(rd.sampler_create(sampler_state))
	for level in LEVELS:
		var grid := grid_at(level)
		var rays := 32 * (1 << (2 * level))
		buffers.append(_keep(rd.storage_buffer_create(grid.x * grid.y * grid.z * rays * 16)))
	var dummy := _keep(rd.storage_buffer_create(16))
	for level in LEVELS:
		var upper: RID = buffers[level + 1] if level + 1 < LEVELS else dummy
		(
			cascade_sets
			. append(
				_keep(
					(
						rd
						. uniform_set_create(
							[
								_uniform(
									0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, scene_buffer
								),
								_uniform(1, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, upper),
								_uniform(
									2, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, buffers[level]
								),
								_uniform(3, RenderingDevice.UNIFORM_TYPE_IMAGE, history),
								_uniform(
									4, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, mesh_nodes
								),
								_uniform(
									5, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, mesh_triangles
								),
								_history_sampler(),
							],
							cascade_shader,
							0
						)
					)
				)
			)
		)
	resolve_set = _keep(
		(
			rd
			. uniform_set_create(
				[
					_uniform(0, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, scene_buffer),
					_uniform(1, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, buffers[0]),
					_uniform(2, RenderingDevice.UNIFORM_TYPE_IMAGE, output),
					_uniform(3, RenderingDevice.UNIFORM_TYPE_IMAGE, history),
					_uniform(4, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, mesh_nodes),
					_uniform(5, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, mesh_triangles),
					_history_sampler(),
				],
				resolve_shader,
				0
			)
		)
	)
	ready = true


func dispatch(
	scene: PackedByteArray, object_count: int, bounce: float, blend: float, sky: Color
) -> void:
	assert(ready, failure)
	assert(object_count <= MAX_OBJECTS and scene.size() == object_count * STRIDE)
	point_index = -1
	for index in object_count:
		if scene.decode_float(index * STRIDE + 108) > 0.5:
			assert(point_index == -1, "Only one explicit point source is supported")
			point_index = index
	if not scene.is_empty():
		rd.buffer_update(scene_buffer, 0, scene.size(), scene)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, cascade_pipeline)
	for level in range(LEVELS - 1, -1, -1):
		var grid := grid_at(level)
		var count := grid.x * grid.y * grid.z * 32 * (1 << (2 * level))
		var params := _params(level, object_count, bounce, blend, sky)
		rd.compute_list_bind_uniform_set(list, cascade_sets[level], 0)
		rd.compute_list_set_push_constant(list, params, params.size())
		rd.compute_list_dispatch(list, ceili(float(count) / 64.0), 1, 1)
		rd.compute_list_add_barrier(list)
	rd.compute_list_bind_compute_pipeline(list, resolve_pipeline)
	rd.compute_list_bind_uniform_set(list, resolve_set, 0)
	var params := _params(0, object_count, bounce, blend, sky)
	rd.compute_list_set_push_constant(list, params, params.size())
	rd.compute_list_dispatch(list, ceili(float(GRID.x * GRID.y * GRID.z * 6) / 64.0), 1, 1)
	rd.compute_list_end()
	rd.texture_copy(
		output,
		history,
		Vector3.ZERO,
		Vector3.ZERO,
		Vector3(GRID.x * 6, GRID.y * GRID.z, 1),
		0,
		0,
		0,
		0
	)


func release() -> void:
	if rd == null:
		return
	for index in range(resources.size() - 1, -1, -1):
		rd.free_rid(resources[index])
	resources.clear()
	ready = false


func update_debug(position: Vector3) -> void:
	# Lazy allocation: no extra atlas or dispatch in ordinary gameplay.
	if not debug_output.is_valid():
		var shader := _compile("debug.glslinc")
		assert(shader.is_valid(), failure)
		debug_pipeline = _keep(rd.compute_pipeline_create(shader))
		debug_output = _texture(256, 640)
		var uniforms: Array[RDUniform] = []
		for level in LEVELS:
			uniforms.append(
				_uniform(level, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, buffers[level])
			)
		uniforms.append(_uniform(5, RenderingDevice.UNIFORM_TYPE_IMAGE, debug_output))
		debug_set = _keep(rd.uniform_set_create(uniforms, shader, 0))
	var params := (
		PackedFloat32Array(
			[
				volume_origin.x,
				volume_origin.y,
				volume_origin.z,
				base_spacing,
				position.x,
				position.y,
				position.z,
				0.0
			]
		)
		. to_byte_array()
	)
	var list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(list, debug_pipeline)
	rd.compute_list_bind_uniform_set(list, debug_set, 0)
	rd.compute_list_set_push_constant(list, params, params.size())
	rd.compute_list_dispatch(list, 32, 80, 1)
	rd.compute_list_end()


func _compile(filename: String) -> RID:
	var source := RDShaderSource.new()
	var common := FileAccess.get_file_as_string(SHADER_ROOT + "common.glslinc")
	common = common.replace("// MESH", FileAccess.get_file_as_string(SHADER_ROOT + "mesh.glslinc"))
	source.source_compute = FileAccess.get_file_as_string(SHADER_ROOT + filename).replace(
		"// COMMON", common
	)
	var spirv := rd.shader_compile_spirv_from_source(source)
	var error := spirv.get_stage_compile_error(RenderingDevice.SHADER_STAGE_COMPUTE)
	if not error.is_empty():
		failure += filename + ": " + error
		push_error(failure)
		return RID()
	return _keep(rd.shader_create_from_spirv(spirv))


func _texture(width: int = GRID.x * 6, height: int = GRID.y * GRID.z) -> RID:
	var format := RDTextureFormat.new()
	format.width = width
	format.height = height
	format.format = RenderingDevice.DATA_FORMAT_R16G16B16A16_SFLOAT
	format.usage_bits = (
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
		| RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
		| RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
	)
	var texture := _keep(rd.texture_create(format, RDTextureView.new(), []))
	rd.texture_clear(texture, Color(0, 0, 0, 0), 0, 1, 0, 1)
	return texture


func _params(level: int, count: int, bounce: float, blend: float, sky: Color) -> PackedByteArray:
	var grid := grid_at(level)
	var upper := grid_at(level + 1) if level + 1 < LEVELS else Vector3i.ZERO
	var interval := interval_at(level) * base_spacing / 0.5
	var bytes := (
		PackedFloat32Array(
			[volume_origin.x, volume_origin.y, volume_origin.z, base_spacing * (1 << level)]
		)
		. to_byte_array()
	)
	bytes.append_array(PackedInt32Array([grid.x, grid.y, grid.z, level]).to_byte_array())
	bytes.append_array(PackedInt32Array([upper.x, upper.y, upper.z, count]).to_byte_array())
	bytes.append_array(PackedFloat32Array([interval.x, interval.y, bounce, blend]).to_byte_array())
	bytes.append_array(
		PackedInt32Array([GRID.x, GRID.y, GRID.z, int(visibility_merge)]).to_byte_array()
	)
	bytes.append_array(PackedFloat32Array([sky.r, sky.g, sky.b, mesh_node_count]).to_byte_array())
	bytes.append_array(
		PackedFloat32Array([base_spacing, base_spacing * 0.6, point_index, 0]).to_byte_array()
	)
	return bytes


func _uniform(binding: int, type: int, rid: RID) -> RDUniform:
	var uniform := RDUniform.new()
	uniform.binding = binding
	uniform.uniform_type = type
	uniform.add_id(rid)
	return uniform


func _history_sampler() -> RDUniform:
	var uniform := RDUniform.new()
	uniform.binding = 6
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
	uniform.add_id(linear_sampler)
	uniform.add_id(history)
	return uniform


func _keep(rid: RID) -> RID:
	assert(rid.is_valid(), "RenderingDevice resource creation failed")
	resources.append(rid)
	return rid
