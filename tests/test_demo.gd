extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene = load("res://scenes/laboratory.tscn").instantiate()
	root.add_child(scene)
	await _frames(45)
	_check(scene.cascades.is_ready and scene.cascades.frame_count > 0, "Live renderer updates")
	var toggle: CheckButton = _find_control(scene, "Animate cyan emitter")
	# Exercise real pointer routing at the control's transformed window location.
	await _click(toggle)
	_check(not scene.motion, "Pointer click toggles emitter motion")
	var freeze: CheckButton = _find_control(scene, "Freeze radiance field")
	await _click(freeze)
	await _frames(3)
	var frames: int = scene.cascades.frame_count
	await _frames(5)
	_check(frames == scene.cascades.frame_count, "Freeze stops GPU field updates")
	await _click(freeze)
	await _frames(5)
	_check(scene.cascades.frame_count > frames, "Unfreeze resumes field updates")
	var probes: CheckButton = _find_control(scene, "Show probe grid")
	await _click(probes)
	_check(scene.probe_mesh.visible, "Probe visualization is connected")
	var lighting: CheckButton = _find_control(scene, "Radiance lighting")
	await _click(lighting)
	_check(
		scene.cascades.materials[0].get_shader_parameter("gi_strength") == 0.0,
		"Lighting toggle reaches rendered materials"
	)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(2)
	key.pressed = false
	Input.parse_input_event(key)
	_check(scene.motion, "Space key toggles motion")
	var old_position: float = scene.blocker.position.x
	await _drag(scene.sliders["Occluder position"])
	_check(
		absf(scene.blocker.position.x - old_position) > 0.2, "Slider drag moves the traced occluder"
	)
	var original: Vector3 = scene.camera.position
	var button := InputEventMouseButton.new()
	button.position = root.get_final_transform() * Vector2(800, 500)
	button.button_index = MOUSE_BUTTON_RIGHT
	button.pressed = true
	Input.parse_input_event(button)
	await _frames(1)
	var motion_event := InputEventMouseMotion.new()
	motion_event.position = root.get_final_transform() * Vector2(850, 500)
	motion_event.relative = Vector2(50, 0)
	motion_event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	Input.parse_input_event(motion_event)
	await _frames(1)
	button.pressed = false
	Input.parse_input_event(button)
	_check(scene.camera.position.distance_to(original) > 1.0, "Orbit changes camera pose")
	scene.queue_free()
	await _frames(5)
	await _test_hall()
	print("UI_TESTS: ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_hall() -> void:
	var hall = load("res://scenes/reactor_hall.tscn").instantiate()
	root.add_child(hall)
	await hall.cascades.initialized
	await _frames(5)
	_check(root.get_texture().get_size() == Vector2(2560, 1440), "Hall renders at native QHD")
	await _key(KEY_C)
	await _key(KEY_SPACE)
	_check(not hall.cinematic and not hall.motion, "Hall camera and emitter motion toggles work")
	await _key(KEY_G)
	var all_off := true
	for material: ShaderMaterial in hall.cascades.materials:
		all_off = all_off and material.get_shader_parameter("gi_strength") == 0.0
	_check(all_off, "Hall GI toggle updates analytic and mesh materials")
	await _key(KEY_F)
	await _frames(3)
	var updates: int = hall.cascades.frame_count
	await _frames(3)
	_check(hall.cascades.frame_count == updates, "Hall freeze halts field updates")
	await _key(KEY_H)
	_check(not hall.hud.visible, "Hall HUD can be hidden")
	hall.queue_free()
	await _frames(5)


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _click(control: Control) -> void:
	# Route one atomic pointer gesture through the real viewport GUI, in local
	# coordinates. OS cursor motion between frames must not steal synthetic clicks.
	var position := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)
	await _frames(2)


func _drag(slider: HSlider) -> void:
	var rect := slider.get_global_rect()
	var start := rect.position + Vector2(rect.size.x * 0.2, rect.size.y * 0.5)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = root.get_final_transform() * start
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	for step in range(1, 6):
		var movement := InputEventMouseMotion.new()
		movement.position = (
			root.get_final_transform() * (start + Vector2(rect.size.x * 0.12 * step, 0))
		)
		movement.relative = Vector2(rect.size.x * 0.12, 0)
		movement.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(movement)
		await _frames(1)
	event.position = root.get_final_transform() * (start + Vector2(rect.size.x * 0.6, 0))
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _find_control(node: Node, text: String) -> Control:
	if node is CheckButton and node.text == text:
		return node
	for child in node.get_children():
		var found := _find_control(child, text)
		if found != null:
			return found
	return null


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
