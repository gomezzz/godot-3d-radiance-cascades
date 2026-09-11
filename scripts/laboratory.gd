extends Node3D

var motion := true
var elapsed := 0.0
var yaw := 0.64
var pitch := 0.43
var distance := 17.0
var energy := 10.0
var gi_enabled := true
var view_mode := 0
var status: Label
var probe_mesh: MultiMeshInstance3D
var capture_frame := -1
var capture_path := "res://artifacts/laboratory.png"
var measured_frames := 0
var measured_seconds := 0.0
var toggles: Dictionary[String, CheckButton] = {}
var sliders: Dictionary[String, HSlider] = {}

@onready var cascades: RadianceCascades = $RadianceCascades
@onready var camera: Camera3D = $Camera3D
@onready var emitter: RCPrimitive = $Geometry/MovingEmitter
@onready var blocker: RCPrimitive = $Geometry/Blocker


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1440, 900)
	_build_ui()
	_build_probes()
	_update_camera()
	cascades.failed.connect(func(message: String) -> void: status.text = message)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			capture_frame = 300
			capture_path = argument.trim_prefix("--capture=")
			motion = false
		if argument == "--no-gi":
			gi_enabled = false
			_apply_view()
		if argument == "--no-bounce":
			cascades.bounce_feedback = 0.0
	toggles["Animate cyan emitter"].button_pressed = motion
	toggles["Radiance lighting"].button_pressed = gi_enabled
	sliders["Diffuse bounce feedback"].value = cascades.bounce_feedback


func _process(delta: float) -> void:
	if cascades.frame_count > 30:
		measured_frames += 1
		measured_seconds += delta
	if motion:
		elapsed += delta
	emitter.position = Vector3(sin(elapsed * 0.7) * 2.5, 2.5 + sin(elapsed) * 0.6, 1.0)
	emitter.radiance = Color(0.16, 0.68, 1.0) * energy
	if cascades.is_ready:
		status.text = (
			"%d FPS   /   %d updates\n5 cascades · 3D world space\n%s"
			% [
				Engine.get_frames_per_second(),
				cascades.frame_count,
				"Field frozen" if cascades.paused else "Live diffuse transport"
			]
		)
	if capture_frame > 0 and cascades.frame_count >= capture_frame:
		capture_frame = -1
		_capture.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.006, -0.1, 1.3)
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(7.0, distance - 0.8)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(28.0, distance + 0.8)
		_update_camera()
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			motion = not motion
		if event.keycode == KEY_R:
			yaw = 0.64
			pitch = 0.43
			distance = 17.0
			_update_camera()
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _update_camera() -> void:
	var target := Vector3(0, 2, 0)
	camera.position = (
		target + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	)
	camera.look_at(target)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var title := Label.new()
	title.text = "RADIANCE / LAB"
	title.position = Vector2(36, 28)
	title.add_theme_font_size_override("font_size", 32)
	root.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "01     A study in light transport"
	subtitle.position = Vector2(38, 73)
	subtitle.modulate = Color("91a8b9")
	root.add_child(subtitle)
	var panel := PanelContainer.new()
	panel.position = Vector2(30, 136)
	panel.custom_minimum_size = Vector2(268, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.047, 0.06, 0.94)
	style.border_color = Color("2b424e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 13)
	panel.add_child(stack)
	_label(stack, "TRANSPORT", 16, Color("7ce3df"))
	_toggle(
		stack,
		"Radiance lighting",
		true,
		func(on: bool) -> void:
			gi_enabled = on
			_apply_view()
	)
	_toggle(stack, "Animate cyan emitter", true, func(on: bool) -> void: motion = on)
	_toggle(stack, "Freeze radiance field", false, func(on: bool) -> void: cascades.paused = on)
	_slider(stack, "Emitter power", 0.0, 24.0, energy, func(value: float) -> void: energy = value)
	_slider(
		stack,
		"Diffuse bounce feedback",
		0.0,
		0.9,
		cascades.bounce_feedback,
		func(value: float) -> void: cascades.bounce_feedback = value
	)
	_slider(
		stack,
		"Occluder position",
		-2.5,
		2.5,
		blocker.position.x,
		func(value: float) -> void: blocker.position.x = value
	)
	stack.add_child(HSeparator.new())
	_label(stack, "INSPECT", 16, Color("7ce3df"))
	var views := OptionButton.new()
	views.add_item("Lit materials")
	views.add_item("Irradiance only")
	views.add_item("Surface albedo")
	views.item_selected.connect(
		func(index: int) -> void:
			view_mode = index
			_apply_view()
	)
	stack.add_child(views)
	_toggle(stack, "Show probe grid", false, func(on: bool) -> void: probe_mesh.visible = on)
	status = _label(stack, "Compiling compute shaders…", 14, Color("91a8b9"))
	var help := Label.new()
	help.text = "RMB drag  Orbit     /     Wheel  Zoom     /     Space  Motion     /     R  Reset"
	help.position = Vector2(38, 852)
	help.add_theme_font_size_override("font_size", 16)
	help.modulate = Color("91a8b9")
	root.add_child(help)
	var note := Label.new()
	note.text = "EMISSIVE GEOMETRY ONLY\nNo baked lightmaps · No Godot lights"
	note.position = Vector2(1090, 38)
	note.add_theme_font_size_override("font_size", 14)
	note.modulate = Color("91a8b9")
	root.add_child(note)


func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.modulate = color
	parent.add_child(label)
	return label


func _toggle(parent: Node, text: String, checked: bool, action: Callable) -> void:
	var button := CheckButton.new()
	button.text = text
	button.button_pressed = checked
	button.toggled.connect(action)
	parent.add_child(button)
	toggles[text] = button


func _slider(
	parent: Node, text: String, low: float, high: float, value: float, action: Callable
) -> void:
	var label := _label(parent, "%s  %.2f" % [text, value], 14, Color("d0dbe1"))
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = 0.01
	slider.value = value
	slider.value_changed.connect(
		func(current: float) -> void:
			label.text = "%s  %.2f" % [text, current]
			action.call(current)
	)
	parent.add_child(slider)
	sliders[text] = slider


func _apply_view() -> void:
	cascades.set_view(view_mode, 1.0 if gi_enabled else 0.0)


func _build_probes() -> void:
	probe_mesh = MultiMeshInstance3D.new()
	probe_mesh.visible = false
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var sphere := SphereMesh.new()
	sphere.radius = 0.025
	sphere.height = 0.05
	sphere.radial_segments = 6
	sphere.rings = 3
	multimesh.mesh = sphere
	multimesh.instance_count = 16 * 10 * 16
	var index := 0
	for z in 16:
		for y in 10:
			for x in 16:
				multimesh.set_instance_transform(
					index,
					Transform3D(
						Basis.IDENTITY, Vector3(-3.75 + x * 0.5, 0.25 + y * 0.5, -3.75 + z * 0.5)
					)
				)
				index += 1
	probe_mesh.multimesh = multimesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("6df4d0")
	probe_mesh.material_override = material
	add_child(probe_mesh)


func _capture() -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts"))
	var result := get_viewport().get_texture().get_image().save_png(capture_path)
	assert(result == OK, "Screenshot save failed")
	print(
		"CAPTURE_OK ",
		capture_path,
		" updates=",
		cascades.frame_count,
		" average_fps_after_warmup=",
		measured_frames / measured_seconds
	)
	get_tree().quit()
