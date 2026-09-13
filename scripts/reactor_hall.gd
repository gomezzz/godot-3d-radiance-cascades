extends Node3D

var cascades: RadianceCascades
var generator := ReactorGeometry.new()
var satellites: Array[RCPrimitive] = []
var time := 0.0
var cinematic := true
var motion := true
var allow_free_flight := true
var gi_enabled := true
var orbit := Vector2(0.4, 0.15)
var distance := 22.0
var hud: CanvasLayer
var status: Label
var capture_path := ""
var benchmark_path := ""
var benchmark_frames := 600
var samples: Array[float] = []
var previous_tick := 0
var total_frames := 0
var detail := 2
var _finished := false

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	get_window().content_scale_size = Vector2i(2560, 1440)
	get_window().mode = Window.MODE_WINDOWED
	get_window().current_screen = DisplayServer.get_primary_screen()
	get_window().mode = Window.MODE_FULLSCREEN
	_parse_args()
	var geometry := Node3D.new()
	geometry.name = "Geometry"
	add_child(geometry)
	geometry.add_child(generator.build(detail))
	for index in 3:
		var light := RCPrimitive.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.25
		sphere.height = 0.5
		light.mesh = sphere
		light.radiance = Color(1.0, 0.25, 0.035) * 16.0
		geometry.add_child(light)
		satellites.append(light)
	cascades = RadianceCascades.new()
	cascades.geometry_root = geometry
	cascades.volume_origin = Vector3(-12, 0, -12)
	cascades.probe_spacing = 1.0
	cascades.sky_radiance = Color(0.035, 0.05, 0.075)
	cascades.bounce_feedback = 0.55
	cascades.temporal_blend = 0.45
	add_child(cascades)
	_build_hud()
	cascades.failed.connect(
		func(message: String) -> void:
			status.text = message
			if not capture_path.is_empty():
				get_tree().quit(1)
	)
	for argument in OS.get_cmdline_user_args():
		if argument == "--no-gi":
			gi_enabled = false
			cascades.set_view(0, 0.0)
		if argument == "--no-bounce":
			cascades.bounce_feedback = 0.0
		if argument.begins_with("--update-every="):
			cascades.update_every_frames = int(argument.trim_prefix("--update-every="))
	_update_camera()
	previous_tick = Time.get_ticks_usec()
	print(
		"HALL_READY pieces=",
		generator.piece_count,
		" triangles=",
		cascades.mesh_bvh.triangle_count,
		" bvh_nodes=",
		cascades.mesh_bvh.node_data.size() / 12,
		" build_ms=",
		cascades.mesh_bvh.build_ms
	)


func _parse_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")
		if argument.begins_with("--benchmark="):
			benchmark_path = argument.trim_prefix("--benchmark=")
		if argument.begins_with("--frames="):
			benchmark_frames = int(argument.trim_prefix("--frames="))
		if argument == "--high-detail":
			detail = 2
		if argument == "--low-detail":
			detail = 1
		if argument == "--static-camera":
			cinematic = false


func _process(delta: float) -> void:
	if motion:
		time += delta
	for index in satellites.size():
		var angle := time * 0.3 + index * TAU / 3
		satellites[index].position = Vector3(
			cos(angle) * 3.1, 4.7 + sin(angle * 2) * 1.2, -1 + sin(angle) * 3.1
		)
	if cinematic:
		orbit = Vector2(0.4 + sin(time * 0.08) * 0.22, 0.15 + sin(time * 0.12) * 0.04)
		_update_camera()
	if allow_free_flight and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		var direction := Vector3(
			(
				float(Input.is_physical_key_pressed(KEY_D))
				- float(Input.is_physical_key_pressed(KEY_A))
			),
			(
				float(Input.is_physical_key_pressed(KEY_E))
				- float(Input.is_physical_key_pressed(KEY_Q))
			),
			(
				float(Input.is_physical_key_pressed(KEY_S))
				- float(Input.is_physical_key_pressed(KEY_W))
			)
		)
		camera.position += camera.basis * direction * delta * 8.0
	total_frames += 1
	var tick := Time.get_ticks_usec()
	if total_frames > 120 and cascades.is_ready:
		samples.append((tick - previous_tick) / 1000.0)
	previous_tick = tick
	if total_frames % 15 == 0 and cascades.is_ready:
		status.text = (
			"%d FPS   /   %s\n%d triangles   ·   %d assemblies   ·   5 cascades\nGI update / %d frames"
			% [
				Engine.get_frames_per_second(),
				str(get_viewport().get_visible_rect().size),
				cascades.mesh_bvh.triangle_count,
				generator.piece_count,
				cascades.update_every_frames
			]
		)
	if (
		samples.size() >= benchmark_frames
		and not _finished
		and (not capture_path.is_empty() or not benchmark_path.is_empty())
	):
		_finished = true
		_finish_capture.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		cinematic = false
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x -= event.relative.y * 0.003
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			distance = clampf(
				distance + (-1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1), 9, 32
			)
			cinematic = false
			_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE:
				motion = not motion
			KEY_C:
				cinematic = not cinematic
			KEY_H:
				hud.visible = not hud.visible
			KEY_F:
				cascades.paused = not cascades.paused
			KEY_G:
				gi_enabled = not gi_enabled
				cascades.set_view(0, float(gi_enabled))
			KEY_1:
				cascades.set_view(0, float(gi_enabled))
			KEY_2:
				cascades.set_view(1, 1.0)
			KEY_3:
				cascades.set_view(2, 1.0)
			KEY_R:
				time = 0.0
				orbit = Vector2(0.4, 0.15)
				distance = 22.0
				_update_camera()
			KEY_ESCAPE:
				get_tree().quit()


func _update_camera() -> void:
	var target := Vector3(0, 5.0, -1)
	camera.position = (
		target
		+ Vector3(sin(orbit.x) * cos(orbit.y), sin(orbit.y), cos(orbit.x) * cos(orbit.y)) * distance
	)
	camera.look_at(target)


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.scale = Vector2.ONE * (4.0 / 3.0)
	add_child(hud)
	_label("H E L I O S", Vector2(44, 28), 38, Color.WHITE)
	_label(
		"THE ENGINE CHOIR    /    WORLD-SPACE RADIANCE CASCADES",
		Vector2(47, 80),
		14,
		Color("8ebbc5")
	)
	status = _label("Building radiance field…", Vector2(46, 944), 17, Color("b9d3da"))
	_label(
		(
			"RMB + WASD / QE  Fly     C  Camera tour     Space  Motion     G  GI on/off\n"
			+ "1 / 2 / 3  Lit / Irradiance / Albedo     F  Freeze GI     H  Hide HUD     R  Reset"
		),
		Vector2(1120, 970),
		15,
		Color("94afb9")
	)


func _label(text: String, position: Vector2, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	hud.add_child(label)
	return label


func _finish_capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	if not capture_path.is_empty():
		DirAccess.make_dir_recursive_absolute(
			ProjectSettings.globalize_path(capture_path.get_base_dir())
		)
		var result := get_viewport().get_texture().get_image().save_png(capture_path)
		assert(result == OK, "Capture failed")
	var sorted := samples.duplicate()
	sorted.sort()
	var total := 0.0
	for sample in samples:
		total += sample
	var stats := {
		"render_size": str(get_viewport().get_texture().get_size()),
		"gpu": RenderingServer.get_video_adapter_name(),
		"viewport": str(get_viewport().get_visible_rect().size),
		"triangles": cascades.mesh_bvh.triangle_count,
		"assemblies": generator.piece_count,
		"bvh_nodes": cascades.mesh_bvh.node_data.size() / 12,
		"bvh_build_ms": cascades.mesh_bvh.build_ms,
		"frame_count": samples.size(),
		"mean_fps": samples.size() * 1000.0 / total,
		"median_frame_ms": sorted[sorted.size() / 2],
		"p95_frame_ms": sorted[int(sorted.size() * 0.95)],
		"update_every_frames": cascades.update_every_frames,
		"gi_updates": cascades.frame_count,
		"cinematic": cinematic,
	}
	stats.merge(_benchmark_details())
	if not benchmark_path.is_empty():
		var file := FileAccess.open(benchmark_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(stats, "\t"))
	print(_benchmark_name(), " ", JSON.stringify(stats))
	get_tree().quit()


func _benchmark_name() -> String:
	return "HALL_BENCHMARK"


func _benchmark_details() -> Dictionary:
	return {}
