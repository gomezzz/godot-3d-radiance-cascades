extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/scene_picker.tscn")
	await scene_changed
	await process_frame
	current_scene.buttons[4].pressed.emit()
	await scene_changed
	for frame in 180:
		await process_frame
	assert(current_scene.cascades.is_ready)
	print("PICKER_LAB_OK")
	quit()
