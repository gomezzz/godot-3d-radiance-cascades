extends Node3D
## Cornell uses RC-only light; occlusion isolates native point direct from RC bounce.

@export var cornell := true
var cascades := RadianceCascades.new()
var geometry := Node3D.new()
var camera := Camera3D.new()
var emitter: RCPrimitive
var point_light: OmniLight3D
var previous_shadow_atlas := 0
var seconds := 0.0
var animate := true
var gi := true
var label := Label.new()


func _ready() -> void:
	previous_shadow_atlas = get_viewport().positional_shadow_atlas_size
	get_window().content_scale_size = Vector2i(1280, 720)
	add_child(geometry)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.018, 0.023, 0.03)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(world)
	add_child(camera)
	camera.position = Vector3(0, 3.5, 9.5)
	camera.look_at(Vector3(0, 2.5, -0.5))
	camera.fov = 52
	camera.make_current()
	_box(Vector3(0, -0.15, 0), Vector3(8, 0.3, 8), Color(0.75, 0.75, 0.75))
	_box(Vector3(0, 2.8, -4), Vector3(8, 5.6, 0.25), Color(0.75, 0.75, 0.75))
	if cornell:
		_box(Vector3(-4, 2.8, 0), Vector3(0.25, 5.6, 8), Color(0.65, 0.06, 0.035))
		_box(Vector3(4, 2.8, 0), Vector3(0.25, 5.6, 8), Color(0.08, 0.5, 0.13))
		_box(Vector3(0, 5.6, 0), Vector3(8, 0.25, 8), Color(0.75, 0.75, 0.75))
		emitter = _box(Vector3(0, 5.35, -0.5), Vector3(2.8, 0.15, 2.0), Color.WHITE)
		emitter.radiance = Color(6, 5.7, 5.2)
		var tall := _box(Vector3(1.25, 1.5, -1.4), Vector3(1.7, 3, 1.7), Color(0.8, 0.8, 0.8))
		tall.rotation.y = -0.3
		var short_box := _box(
			Vector3(-1.25, 0.75, 0.9), Vector3(1.7, 1.5, 1.7), Color(0.8, 0.8, 0.8)
		)
		short_box.rotation.y = 0.3
	else:
		for x in [-2.5, 0.0, 2.5]:
			_box(Vector3(x, 1.0, -0.7), Vector3(0.55, 2.0, 1.3), Color(0.65, 0.68, 0.73))
		var sphere := RCPrimitive.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.9
		mesh.height = 1.8
		mesh.radial_segments = 96
		mesh.rings = 48
		sphere.mesh = mesh
		sphere.position = Vector3(-1.2, 0.9, 1.8)
		sphere.albedo = Color(0.65, 0.67, 0.72)
		geometry.add_child(sphere)
		emitter = RCPrimitive.new()
		var bulb := SphereMesh.new()
		bulb.radius = 0.07
		bulb.height = 0.14
		emitter.mesh = bulb
		emitter.position = Vector3(0, 3.8, 1)
		emitter.point_source = true
		emitter.radiance = Color(5, 8, 12)
		geometry.add_child(emitter)
		point_light = OmniLight3D.new()
		point_light.light_color = Color(5.0 / 12.0, 8.0 / 12.0, 1.0).linear_to_srgb()
		point_light.light_energy = 12.0
		point_light.omni_range = emitter.point_range
		point_light.omni_attenuation = 2.0
		point_light.shadow_enabled = true
		point_light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
		point_light.shadow_bias = 0.1
		point_light.shadow_normal_bias = 1.0
		point_light.light_size = 0.0
		add_child(point_light)
		point_light.position = emitter.position
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_materials()
		cascades.pbr_surfaces = true
		get_viewport().positional_shadow_atlas_size = 4096
	cascades.geometry_root = geometry
	cascades.volume_origin = Vector3(-6, -1, -6)
	cascades.probe_spacing = 0.5
	cascades.sky_radiance = Color.BLACK
	cascades.bounce_feedback = 0.65
	cascades.visibility_merge = true
	cascades.temporal_blend = 0.15
	add_child(cascades)
	var layer := CanvasLayer.new()
	add_child(layer)
	label.position = Vector2(24, 20)
	label.text = (
		("Cornell box" if cornell else "Occlusion study")
		+ "\nG: GI on/off   B: bounce on/off   Space: pause   Esc: scenes"
	)
	label.add_theme_font_size_override("font_size", 20)
	layer.add_child(label)


func _box(p: Vector3, size: Vector3, color: Color) -> RCPrimitive:
	var primitive := RCPrimitive.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	primitive.mesh = mesh
	primitive.position = p
	primitive.albedo = color
	geometry.add_child(primitive)
	return primitive


func _process(delta: float) -> void:
	label.text = (
		("Cornell box" if cornell else "Occlusion study")
		+ (
			"\nG: GI %s   B: diffuse bounce %s   Space: %s   Esc: scenes"
			% [
				"ON" if gi else "OFF",
				"ON" if cascades.bounce_feedback > 0 else "OFF",
				"pause" if animate else "resume"
			]
		)
	)
	if not cornell:
		label.text += "\nPoint direct shadows + GPU RC indirect (G/B)"
	if animate and not cornell:
		seconds += delta
		emitter.position.x = sin(seconds * 0.7) * 2.8
		point_light.position = emitter.position


func _exit_tree() -> void:
	get_viewport().positional_shadow_atlas_size = previous_shadow_atlas


func _materials() -> void:
	for primitive in geometry.get_children():
		var material := StandardMaterial3D.new()
		material.set_meta("rc_local_diffuse", true)
		material.roughness = 0.65
		if primitive.mesh is BoxMesh and primitive.mesh.size.x > 4.0:
			material.albedo_texture = preload("res://assets/textures/concrete_wall_006/Diffuse.jpg")
			material.normal_texture = preload("res://assets/textures/concrete_wall_006/nor_gl.jpg")
			material.roughness_texture = preload(
				"res://assets/textures/concrete_wall_006/Rough.jpg"
			)
			material.normal_enabled = true
			material.normal_scale = 0.6
			# BoxMesh UVs use a 3 by 2 face atlas; keep the scanned grain fine.
			material.uv1_scale = Vector3(6, 4, 1)
		primitive.material_override = material


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_G:
				gi = not gi
				cascades.set_view(0, 1.0 if gi else 0.0)
			KEY_B:
				cascades.bounce_feedback = 0.0 if cascades.bounce_feedback > 0 else 0.65
			KEY_SPACE:
				animate = not animate
			KEY_ESCAPE:
				get_tree().change_scene_to_file("res://scenes/scene_picker.tscn")
