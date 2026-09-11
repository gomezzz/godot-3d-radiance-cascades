class_name RadianceCascades
extends Node
## Add RCPrimitive descendants under geometry_root and use their RC materials.

signal initialized
signal failed(message: String)

const SURFACE_SHADER := preload("res://addons/radiance_cascades/shaders/surface.gdshader")

@export var geometry_root: Node3D
@export_range(0.0, 1.0) var bounce_feedback := 0.65
@export_range(0.01, 1.0) var temporal_blend := 0.3
@export var sky_radiance := Color(0.015, 0.02, 0.03)
@export var paused := false
@export var volume_origin := RCGPU.ORIGIN
@export_range(0.1, 4.0) var probe_spacing := 0.5
@export_range(1, 8) var update_every_frames := 1

var gpu := RCGPU.new()
var texture := Texture2DRD.new()
var primitives: Array[RCPrimitive] = []
var materials: Array[ShaderMaterial] = []
var is_ready := false
var frame_count := 0
var mesh_instances: Array[MeshInstance3D] = []
var mesh_bvh := RCMeshBVH.new()
var _pending := false
var _tick := 0
var _original_overrides: Dictionary[MeshInstance3D, Material] = {}
var _original_surfaces: Dictionary[MeshInstance3D, Array] = {}


func _ready() -> void:
	assert(geometry_root != null, "Assign the RC geometry root")
	_collect(geometry_root)
	assert(primitives.size() <= RCGPU.MAX_OBJECTS, "Too many RC primitives")
	mesh_bvh.build(mesh_instances)
	for instance in mesh_instances:
		_apply_mesh_materials(instance)
	RenderingServer.call_on_render_thread(_initialize_gpu)


func _process(_delta: float) -> void:
	_tick += 1
	if not is_ready or paused or _pending:
		return
	var packed := PackedFloat32Array()
	for index in primitives.size():
		var primitive := primitives[index]
		packed.append_array(primitive.pack())
		materials[index].set_shader_parameter("surface_color", primitive.albedo)
		materials[index].set_shader_parameter(
			"emission_color",
			Vector3(primitive.radiance.r, primitive.radiance.g, primitive.radiance.b)
		)
	if _tick % update_every_frames != 0:
		return
	_pending = true
	RenderingServer.call_on_render_thread(
		_render.bind(
			packed.to_byte_array(), primitives.size(), bounce_feedback, temporal_blend, sky_radiance
		)
	)


func set_view(mode: int, strength: float) -> void:
	for material in materials:
		material.set_shader_parameter("view_mode", mode)
		material.set_shader_parameter("gi_strength", strength)


func rebuild_geometry() -> void:
	# Topology / static mesh edits are explicit because a CPU BVH rebuild can stall.
	is_ready = false
	while _pending:
		await get_tree().process_frame
	_restore_materials()
	primitives.clear()
	materials.clear()
	mesh_instances.clear()
	_collect(geometry_root)
	assert(primitives.size() <= RCGPU.MAX_OBJECTS, "Too many RC primitives")
	mesh_bvh.build(mesh_instances)
	for instance in mesh_instances:
		_apply_mesh_materials(instance)
	RenderingServer.call_on_render_thread(_reinitialize_gpu)


func _collect(node: Node) -> void:
	if node is MeshInstance3D and node.mesh != null:
		var instance := node as MeshInstance3D
		_original_overrides[instance] = node.material_override
		var surfaces: Array[Material] = []
		for surface in node.mesh.get_surface_count():
			surfaces.append(node.get_surface_override_material(surface))
		_original_surfaces[instance] = surfaces
	if node is RCPrimitive and (node.mesh is BoxMesh or node.mesh is SphereMesh):
		primitives.append(node)
		var material := ShaderMaterial.new()
		material.shader = SURFACE_SHADER
		material.set_shader_parameter("irradiance_tex", texture)
		material.set_shader_parameter("volume_origin", volume_origin)
		material.set_shader_parameter("probe_spacing", probe_spacing)
		node.material_override = material
		materials.append(material)
	elif node is MeshInstance3D and node.mesh != null:
		mesh_instances.append(node)
	for child in node.get_children():
		_collect(child)


func _apply_mesh_materials(instance: MeshInstance3D) -> void:
	for surface in instance.mesh.get_surface_count():
		var palette := RCMeshBVH.colors(instance, surface)
		var material := ShaderMaterial.new()
		material.shader = SURFACE_SHADER
		material.set_shader_parameter("irradiance_tex", texture)
		material.set_shader_parameter("volume_origin", volume_origin)
		material.set_shader_parameter("probe_spacing", probe_spacing)
		material.set_shader_parameter("surface_color", palette[0])
		material.set_shader_parameter(
			"emission_color", Vector3(palette[1].r, palette[1].g, palette[1].b)
		)
		instance.set_surface_override_material(surface, material)
		materials.append(material)
	instance.material_override = null


func _initialize_gpu() -> void:
	gpu.initialize(RenderingServer.get_rendering_device(), mesh_bvh, volume_origin, probe_spacing)
	if not gpu.ready:
		_report_failure.call_deferred(gpu.failure)
		return
	texture.texture_rd_rid = gpu.output
	_finish_initialize.call_deferred()


func _finish_initialize() -> void:
	is_ready = true
	initialized.emit()


func _report_failure(message: String) -> void:
	push_error(message)
	failed.emit(message)


func _render(data: PackedByteArray, count: int, bounce: float, blend: float, sky: Color) -> void:
	gpu.dispatch(data, count, bounce, blend, sky)
	_finish_frame.call_deferred()


func _finish_frame() -> void:
	_pending = false
	frame_count += 1


func _exit_tree() -> void:
	_restore_materials()
	RenderingServer.call_on_render_thread(_release_gpu)


func _restore_materials() -> void:
	for instance in _original_overrides:
		if not is_instance_valid(instance):
			continue
		instance.material_override = _original_overrides[instance]
		for surface in mini(
			instance.get_surface_override_material_count(), _original_surfaces[instance].size()
		):
			instance.set_surface_override_material(surface, _original_surfaces[instance][surface])
	_original_overrides.clear()
	_original_surfaces.clear()


func _reinitialize_gpu() -> void:
	_release_gpu()
	gpu = RCGPU.new()
	_initialize_gpu()


func _release_gpu() -> void:
	texture.texture_rd_rid = RID()
	gpu.release()
