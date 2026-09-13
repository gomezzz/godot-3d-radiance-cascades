extends SceneTree

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var picker = load("res://scenes/scene_picker.tscn").instantiate()
	root.add_child(picker)
	await process_frame
	_check(
		picker.buttons.size() == 5 and picker.buttons[0].has_focus(),
		"Picker exposes five focused scene choices"
	)
	await _frames(3)
	root.get_texture().get_image().save_png("res://artifacts/scene-picker.png")
	picker.queue_free()
	await process_frame
	for name in ["cornell_box", "occlusion_study"]:
		var scene = load("res://scenes/" + name + ".tscn").instantiate()
		root.add_child(scene)
		await scene.cascades.initialized
		scene.animate = false
		await _frames(100)
		var lit := root.get_texture().get_image()
		await _frames(80)
		_check(
			_difference(lit, root.get_texture().get_image()) < 0.0005,
			name + " stationary field does not flicker after convergence"
		)
		lit.save_png("res://artifacts/" + name + ".png")
		_check(
			scene.cascades.is_ready and scene.cascades.primitives.size() > 4,
			name + " runs real GPU cascades"
		)
		scene.cascades.set_view(0, 0.0)
		await _frames(8)
		var no_gi := root.get_texture().get_image()
		no_gi.save_png("res://artifacts/" + name + "-no-gi.png")
		_check(
			_difference(lit, no_gi) > (0.01 if scene.cornell else 0.001),
			name + " visibly depends on RC illumination"
		)
		if not scene.cornell:
			_check(
				scene.emitter.point_source and scene.point_light.shadow_enabled,
				"Occlusion uses a true point source with native direct shadows"
			)
			scene.point_light.visible = false
			await _frames(8)
			_check(
				_difference(no_gi, root.get_texture().get_image()) > 0.01,
				"G disables only RC indirect, leaving independent point direct lighting"
			)
			scene.point_light.visible = true
		scene.cascades.set_view(0, 1.0)
		var key := InputEventKey.new()
		key.keycode = KEY_B
		key.pressed = true
		Input.parse_input_event(key)
		await process_frame
		_check(scene.cascades.bounce_feedback == 0.0, name + " B key disables bounce")
		await _frames(100)
		_check(
			_difference(lit, root.get_texture().get_image()) > 0.0001,
			name + " bounce feedback visibly changes lighting"
		)
		scene.queue_free()
		await _frames(5)
	print("EXAMPLE_TESTS: ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _frames(count: int) -> void:
	for frame in count:
		await process_frame
	await RenderingServer.frame_post_draw


func _difference(a: Image, b: Image) -> float:
	var difference := 0.0
	var count := 0
	for y in range(150, a.get_height(), 16):
		for x in range(0, a.get_width(), 16):
			var delta := a.get_pixel(x, y) - b.get_pixel(x, y)
			difference += absf(delta.r) + absf(delta.g) + absf(delta.b)
			count += 3
	return difference / count


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
