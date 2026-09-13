extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://scenes/metro_station.tscn")
	await scene_changed
	var station = current_scene
	await station.cascades.initialized
	station.set_process(false)
	station._enter_walk()
	station.walker.set_physics_process(false)
	var event: MetroLightning = station.lightning
	assert(
		absf(event.audio.stream.get_length() - 53.0) < .05,
		"Requested electrical excerpt imported in full"
	)
	assert(
		event.audio.unit_size == 32 and event.audio.max_db == 0,
		"Arc gain is not quietly attenuated nearby"
	)
	event.tick(0.1, station)
	assert(event.elapsed < 0, "Starting platform must not trigger event")
	station.walker.position = Vector3(6.8, 0, 10)
	event.tick(0.1, station)
	assert(event.elapsed >= 0, "Other platform triggers event")
	event.restore_lights()
	event.elapsed = 2.2
	event.tick(0, station)
	assert(event.overlay.color.a == 1)
	for lamp in station.highlights:
		assert(lamp.light_energy == 0, "Blackout switches light energy off")
	event.restore_lights()
	event.elapsed = 7
	event.tick(0, station)
	assert(event.orb.visible and event.proxy.radiance.b > 1)
	assert(event.orb.position.x < -4, "Ball travels on the puddled platform")
	for node in station.find_children("*", "Light3D", true, false):
		if (
			node != event.light
			and node != station.barrel.light
			and node not in station.security.navigation_lights
		):
			assert(node.light_energy == 0, "Other native lights stay off after reveal")
	for material in station.cascades.materials:
		assert(material.get_shader_parameter("station_power") == 0)
	for panel in station.atmosphere.ad_panels + station.atmosphere.escape_panels:
		assert(panel.material_override.get_shader_parameter("station_power") == 0)
	var particles: ParticleProcessMaterial = station.barrel.sparks.process_material
	assert(particles.damping_min > 0 and particles.gravity.y < 0)
	assert(particles.angle_min == -180 and particles.angle_max == 180)
	assert(station.barrel.sparks.draw_pass_1 is ArrayMesh)
	assert(
		station.barrel.sparks.draw_pass_1.surface_get_array_len(0) == 162,
		"Ash has 54 folded triangles, not a two-triangle shard"
	)
	assert(
		station.barrel.sparks.draw_pass_1.get_aabb().size.z > .15,
		"Ash geometry has real depth and folds"
	)
	assert(particles.color_ramp.gradient.colors[3].r < .1)
	particles = null
	station.camera.global_position = Vector3(-6.5, 1.8, 5.0)
	station.camera.look_at(event.orb.global_position)
	station.focus_overlay.visible = false
	station.hud.visible = false
	for frame in 60:
		station.atmosphere.update_views(station.camera, 7)
		await process_frame
	await RenderingServer.frame_post_draw
	assert(event.contact_points.size() >= 8, "Arcs terminate on nearby physics geometry")
	await physics_frame
	for point in event.contact_points:
		var direction: Vector3 = (point - event.orb.global_position).normalized()
		var ray := PhysicsRayQueryParameters3D.create(
			point - direction * .05, point + direction * .05, 1
		)
		assert(not event.get_world_3d().direct_space_state.intersect_ray(ray).is_empty())
	root.get_texture().get_image().save_png("res://artifacts/lightning-platform.png")
	await _heat_pixels(event)
	assert(event.core_material.get_shader_parameter("power") > 20)
	assert(event.heat_material.get_shader_parameter("strength") > 0)
	assert(station.walker.collision_mask == 17)
	assert(station.get_node("TrackWalkingSurface").collision_layer == 16)
	await physics_frame
	var track_ray := PhysicsRayQueryParameters3D.create(Vector3(1.7, 1, 4), Vector3(1.7, -1, 4), 17)
	var track_hit := event.get_world_3d().direct_space_state.intersect_ray(track_ray)
	assert(track_hit["collider"] == station.get_node("TrackWalkingSurface"))
	station.walker.position = Vector3(.3, -.36, 4)
	assert(
		station.walker.move_and_collide(Vector3(4.5, 0, 0)) == null,
		"Capsule crosses both rail heads without snagging"
	)
	track_hit.clear()
	track_ray = null
	assert(station.train_audio.unit_size == 28 and station.train_audio.max_db == 0)
	station.security.drone.position = Vector3(-7.7, 3.25, 0)
	event.elapsed = 12
	event.tick(0, station)
	assert(absf(event.orb.position.z) < .01 and event.orb.position.x == -5)
	assert(station.security.crashed, "Approaching lightning disables the drone")
	station.camera.global_position = Vector3(-8.0, 1.5, -11.5)
	station.camera.look_at(Vector3(-8.9, 1.1, -14.4))
	for frame in 90:
		station.barrel.tick(frame / 60.0, true)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/barrel-ash.png")
	for step in 120:
		await physics_frame
	assert(
		station.security.drone.position.y > .05 and station.security.drone.position.y < 1.0,
		"Drone settles above the platform, not through it"
	)
	assert(station.security.drone.rotation.length() > .5, "Drone tumbles while falling")
	station.camera.global_position = station.security.drone.global_position + Vector3(.5, 2.5, .1)
	station.camera.look_at(station.security.drone.global_position)
	for frame in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/drone-crash.png")
	event.elapsed = 21
	event.tick(0, station)
	assert(
		event.orb.position.x == -5 and event.orb.position.z == -16,
		"Full platform traversed before crossing rails"
	)
	event.elapsed = 25
	event.tick(0, station)
	station.train.animate(8.40625)
	for frame in 8:
		await physics_frame
	assert(event.contact, "Godot collision detects the train")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_P
	station._unhandled_input(key)
	event.tick(1, station)
	assert(event.collision_age == 0, "Pause also freezes the final fade")
	station._unhandled_input(key)
	key.keycode = KEY_M
	station._unhandled_input(key)
	event.tick(0, station)
	assert(event.impact.volume_db == -80, "Mute remains available after impact")
	event.tick(1.5, station)
	assert(event.overlay.color.a == 1 and not event.finished)
	event.tick(4.9, station)
	assert(not event.finished and event.epilogue == null, "Black hold must last five full seconds")
	event.tick(.1, station)
	assert(event.epilogue != null and not event.finished)
	assert(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "No cursor in the cinematic epilogue")
	key.keycode = KEY_P
	station._unhandled_input(key)
	var held_age := event.collision_age
	event.tick(1, station)
	assert(
		event.collision_age == held_age and station.cascades.paused,
		"Epilogue pause freezes its timeline and GPU updates"
	)
	station._unhandled_input(key)
	event.tick(0, station)
	assert(event.epilogue.steps[0].modulate.a == 0)
	event.tick(1, station)
	assert(event.epilogue.steps[0].modulate.a == 1)
	assert(event.epilogue.steps[1].modulate.a == 0)
	event.tick(9, station)
	for step in event.epilogue.steps:
		assert(step.modulate.a == 1, "All four explanations fade in within ten seconds")
	assert(event.epilogue.stage == 0)
	for stage in 3:
		if stage > 0:
			event.tick(5 if stage == 1 else 8, station)
		for frame in 40:
			await process_frame
		await RenderingServer.frame_post_draw
		assert(event.epilogue.stage == stage)
		assert(station.camera.position == MetroDebugEpilogue.EYES[stage])
		assert(station.cascades.debug_texture.texture_rd_rid.is_valid())
		root.get_texture().get_image().save_png("res://artifacts/metro-debug-%d.png" % stage)
		event.tick(0, station)
		assert(not event.finished)
	event.tick(7.9, station)
	assert(not event.epilogue.thanks.visible, "Last shot holds for its full eight seconds")
	assert(not event.finished)
	event.tick(.1, station)
	assert(event.epilogue.thanks.visible and not event.finished)
	event.tick(1, station)
	assert(event.epilogue.thanks.modulate.a == 1)
	assert(event.epilogue.repo_link.text == "github.com/gomezzz/godot-3d-radiance-cascades")
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/metro-thanks.png")
	event.tick(6.9, station)
	assert(not event.finished)
	event.tick(.1, station)
	assert(event.finished)
	await scene_changed
	assert(current_scene is Control)
	for frame in 8:
		await process_frame
	await create_timer(.25).timeout
	print("LIGHTNING_TESTS_OK")
	quit()


func _heat_pixels(event: MetroLightning) -> void:
	event.heat_material.set_shader_parameter("strength", 0.0)
	for frame in 8:
		await process_frame
	# The uncapped picker can render eight frames before one audio mix block ends.
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	var cold := root.get_texture().get_image()
	event.heat_material.set_shader_parameter("strength", 1.0)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var hot := root.get_texture().get_image()
	var difference := 0.0
	var middle := hot.get_size() / 2
	for y in range(middle.y - 100, middle.y + 100, 4):
		for x in range(middle.x - 100, middle.x + 100, 4):
			var change := hot.get_pixel(x, y) - cold.get_pixel(x, y)
			difference += absf(change.r) + absf(change.g) + absf(change.b)
	assert(difference > 1.0, "Heat refraction must visibly change pixels around the core")
