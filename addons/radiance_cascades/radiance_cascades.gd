class_name RadianceCascades
extends Node
## Add RCPrimitive descendants under geometry_root and use their RC materials.

signal initialized
signal failed(message: String)

@export var geometry_root: Node3D
@export_range(0.0, 1.0) var bounce_feedback := 0.65
@export_range(0.01, 1.0) var temporal_blend := 0.3
@export var sky_radiance := Color(0.015, 0.02, 0.03)
@export var paused := false

var gpu := RCGPU.new()
var texture := Texture2DRD.new()
var primitives: Array[RCPrimitive] = []
var materials: Array[ShaderMaterial] = []
var is_ready := false
var frame_count := 0
var _pending := false


func _ready() -> void:
	assert(geometry_root != null, "Assign the RC geometry root")
	_collect(geometry_root)
	assert(primitives.size() <= RCGPU.MAX_OBJECTS, "Too many RC primitives")
	RenderingServer.call_on_render_thread(_initialize_gpu)


func _process(_delta: float) -> void:
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


func _collect(node: Node) -> void:
	if node is RCPrimitive:
		primitives.append(node)
		var material := ShaderMaterial.new()
		material.shader = preload("res://addons/radiance_cascades/shaders/surface.gdshader")
		material.set_shader_parameter("irradiance_tex", texture)
		node.material_override = material
		materials.append(material)
	for child in node.get_children():
		_collect(child)


func _initialize_gpu() -> void:
	gpu.initialize(RenderingServer.get_rendering_device())
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
	RenderingServer.call_on_render_thread(_release_gpu)


func _release_gpu() -> void:
	texture.texture_rd_rid = RID()
	gpu.release()
