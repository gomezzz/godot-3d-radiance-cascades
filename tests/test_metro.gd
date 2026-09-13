extends SceneTree
## Exercise real rendered PBR channels, moving proxies and localized flicker.

var checks := 0
var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene = load("res://scenes/metro_station.tscn").instantiate()
	root.add_child(scene)
	await scene.cascades.initialized
	assert(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Metro intro hides the pointer")
	await _frames(90)
	assert(scene.postfx_enabled and scene.postfx.effect.visible, "Post FX default on")
	await _key(KEY_O)
	assert(not scene.postfx.effect.visible, "O disables vignette and camera blur")
	assert(not scene.get_node("WorldEnvironment").environment.glow_enabled, "O also disables glow")
	await _key(KEY_O)
	assert(scene.postfx.effect.visible, "O restores post FX")
	var camera_pose: Transform3D = scene.camera.global_transform
	scene.postfx.tick(scene.camera, .016, true, true, false)
	scene.camera.rotate_y(.03)
	scene.postfx.tick(scene.camera, .016, true, true, false)
	assert(scene.postfx.material.get_shader_parameter("shutter") > 0, "Camera turn enables blur")
	scene.postfx.tick(scene.camera, .016, true, false, false)
	assert(scene.postfx.material.get_shader_parameter("shutter") == 0, "Pause disables blur")
	scene.camera.position += Vector3(5, 0, 0)
	scene.postfx.tick(scene.camera, .016, true, true, false)
	assert(scene.postfx.material.get_shader_parameter("shutter") == 0, "Cuts reset blur")
	scene.camera.global_transform = camera_pose
	scene.postfx.initialized = false
	assert(not scene.hud.visible and scene.shortcut_hint.visible, "Only shortcut hint on entry")
	await _key(KEY_F1)
	assert(scene.hud.visible, "F1 reveals metro title and shortcuts")
	await _key(KEY_F1)
	assert(not scene.hud.visible and scene.shortcut_hint.visible, "F1 hides overlays again")
	root.get_texture().get_image().save_png("res://artifacts/metro-hud-hidden.png")
	await _key(KEY_F1)
	root.get_texture().get_image().save_png("res://artifacts/metro-hud-shortcuts.png")
	await _key(KEY_F1)
	_check(
		(
			root.get_texture().get_size() == Vector2(2560, 1440)
			and root.mode == Window.MODE_FULLSCREEN
		),
		"Native 2560x1440 fullscreen metro rendering"
	)
	_check(scene.station.pillar_count == 22, "Near-wall duplicate pillar row removed")
	_check(
		scene.cascades.primitives.size() == 38, "Train, lamp, fire and dormant lightning proxies"
	)
	var all_pbr := true
	var textured := 0
	for material: ShaderMaterial in scene.cascades.materials:
		all_pbr = all_pbr and material.shader == RCPBRMaterial.SHADER
		if material.get_shader_parameter("use_albedo"):
			textured += 1
	_check(all_pbr and textured > 7, "Scanned PBR installed on station and moving train")
	var maps_valid := true
	for key in ["floor", "tile", "concrete"]:
		var material: StandardMaterial3D = scene.station.palette[key]
		for map: Texture2D in [
			material.albedo_texture,
			material.normal_texture,
			material.roughness_texture,
			material.heightmap_texture
		]:
			var resolution := 2048 if key == "concrete" else 4096
			maps_valid = (
				maps_valid and map.get_width() == resolution and map.get_image().has_mipmaps()
			)
	_check(maps_valid, "4K floor/column maps and 2K concrete retain mip chains")
	var bvh_bytes: PackedFloat32Array = scene.cascades.mesh_bvh.node_data.duplicate()
	var first := scene.train.transport.get_child(0) as RCPrimitive
	var old_pack := first.pack()
	var old_z: float = scene.train.visual.position.z
	await _frames(12)
	_check(scene.train.visual.position.z != old_z, "Train actually moves between rendered frames")
	_check(first.pack() != old_pack, "Train transform reaches analytic GPU upload data")
	_check(
		scene.train.visual.position == scene.train.transport.position,
		"Raster and proxy roots stay aligned"
	)
	_check(
		scene.cascades.mesh_bvh.node_data == bvh_bytes, "Train motion does not rebuild static BVH"
	)
	var low := 1.0
	var high := 0.0
	var healthy := true
	for step in 800:
		low = minf(low, scene.lamp_intensity(step * 0.01, 2, true))
		high = maxf(high, scene.lamp_intensity(step * 0.01, 2, true))
		healthy = healthy and scene.lamp_intensity(step * 0.01, 1, true) == 1.0
	_check(low < 0.2 and high > 0.95 and healthy, "Faulty lamps flicker; healthy lamps stay steady")
	var changed_rhythm := 0
	for sample in 100:
		if not is_equal_approx(
			scene.lamp_intensity(sample * 0.1, 2, true),
			scene.lamp_intensity(sample * 0.1 + 7.5, 2, true)
		):
			changed_rhythm += 1
	_check(changed_rhythm > 80, "Lamp flicker no longer repeats the old 7.5-second rhythm")
	await _key(KEY_L)
	_check(
		(
			not scene.flicker_enabled
			and is_equal_approx(scene.highlights[2].light_energy, scene.SPECULAR_ENERGY)
		),
		"L disables flicker and restores lamp energy"
	)
	await _key(KEY_P)
	old_z = scene.train.visual.position.z
	await _frames(5)
	_check(not scene.motion and scene.train.visual.position.z == old_z, "P pauses train animation")
	await _key(KEY_ENTER)
	_check(
		not scene.cinematic and not scene.cutscene and scene.walker.active,
		"Enter skips intro into walking"
	)
	scene.walker.stop()
	scene.motion = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	scene.hud.visible = false
	scene.cascades.paused = true
	await _frames(8)
	var baseline := root.get_texture().get_image()
	for channel in ["albedo", "normal", "roughness", "height"]:
		var changed: Array[ShaderMaterial] = []
		for material: ShaderMaterial in scene.cascades.materials:
			if material.get_shader_parameter("use_" + channel):
				changed.append(material)
				material.set_shader_parameter("use_" + channel, false)
		await _frames(8)
		var difference := _difference(baseline, root.get_texture().get_image())
		_check(difference > 0.0001, "%s map visibly affects pixels: %.6f" % [channel, difference])
		for material in changed:
			material.set_shader_parameter("use_" + channel, true)
		await _frames(8)
	await _horror_checks(scene)
	await _detail_checks(scene)
	await _graffiti_checks(scene)
	await _key(KEY_G)
	var gi_off := true
	for material: ShaderMaterial in scene.cascades.materials:
		gi_off = gi_off and material.get_shader_parameter("gi_strength") == 0.0
	_check(gi_off, "GI toggle reaches train detail and station PBR materials")
	var visual_mesh: MeshInstance3D = scene.train.wheels[0]
	var source_material: Material = scene.cascades._original_overrides[visual_mesh]
	scene.cascades.queue_free()
	scene.set_process(false)
	await _frames(5)
	_check(
		visual_mesh.material_override == source_material,
		"Raster-only detail restores original materials"
	)
	await scene._stop_audio()
	scene.queue_free()
	await _frames(5)
	print("METRO_TESTS: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _horror_checks(scene: Node3D) -> void:
	_check(scene.LAMP_ENERGY < 3.0, "Ceiling emission reduced by over 75 percent")
	_check(
		scene.atmosphere.puddles.size() == 7 and scene.atmosphere.mirrors.size() == 3,
		"Seven puddles and three wall mirrors"
	)
	_check(
		scene.atmosphere.displays.size() == 4,
		"Only two paired ceiling signs remain; wall line signs removed"
	)
	_check(scene.train_audio.stream.get_length() > 7.9, "Eight-second train recording loads")
	await _key(KEY_M)
	_check(
		scene.audio_muted and scene.train_audio.volume_db == -80.0, "M mutes the train recording"
	)
	scene.train.animate(4.0)
	var start: float = scene.train.visual.position.z
	scene.train.animate(4.5)
	_check(
		is_equal_approx(scene.train.visual.position.z - start, 16.0),
		"Train travels at 32 metres per second"
	)
	scene.time = 9.0
	scene.motion = true
	scene.last_cycle = -1
	scene._update_audio()
	await _frames(3)
	var audio_started: bool = scene.train_audio.playing
	scene.motion = false
	scene._update_audio()
	_check(
		audio_started and scene.train_audio.stream_paused,
		"Audio triggers on timeline and respects pause"
	)
	scene.cascades.paused = false
	scene.camera.position = Vector3(-7.0, 1.8, -12.0)
	scene.camera.look_at(Vector3(-9.64, 2.0, -14.5))
	await _frames(12)
	var mirror_image: Image = scene.atmosphere.cameras[1].get_viewport().get_texture().get_image()
	mirror_image.save_png("res://artifacts/mirror-test.png")
	root.get_texture().get_image().save_png("res://artifacts/mirror-surface-test.png")
	_check(_brightness(mirror_image) > 0.003, "Wall reflection contains rendered station pixels")
	_check(
		scene.atmosphere.cameras[1].cull_mask == 1,
		"Reflection excludes mirrors and puddles to prevent recursion"
	)
	scene.time = 2.0
	scene._update_camera()
	var camera_start: Vector3 = scene.camera.position
	scene.time = 18.0
	scene._update_camera()
	_check(
		camera_start.distance_to(scene.camera.position) > 8.0,
		"Intro camera travels through station"
	)
	scene.cutscene = true
	scene.cinematic = true
	scene.time = 24.1
	await _frames(2)
	_check(
		not scene.cutscene and not scene.cinematic and scene.walker.active,
		"24-second intro hands off to walking"
	)
	var flight_start: Vector3 = scene.camera.position
	_check(
		scene.walker.position.z > 13.0 and scene.barrel.position.z < -14.0,
		"Walking begins opposite the barrel"
	)
	var forward := InputEventKey.new()
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	await create_timer(0.3).timeout
	forward.pressed = false
	Input.parse_input_event(forward)
	_check(
		scene.camera.position.distance_to(flight_start) > 0.01,
		"W walks forward after automatic handoff without RMB"
	)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _key(KEY_C)
	assert(Input.mouse_mode == Input.MOUSE_MODE_HIDDEN, "Replayed intro hides the pointer")
	_check(
		scene.cutscene and scene.cinematic and scene.motion and scene.time < 0.5,
		"C replays intro from beginning, including when paused"
	)
	scene._enter_walk()
	await _walking_checks(scene)
	scene.walker.stop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _walking_checks(scene: Node3D) -> void:
	scene.motion = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await create_timer(0.3).timeout
	_check(
		scene.walker.is_on_floor() and absf(scene.walker.position.y) < 0.1,
		"Walker settles on platform collision"
	)
	var step_start: int = scene.walker.step_count
	var forward := InputEventKey.new()
	forward.physical_keycode = KEY_W
	forward.pressed = true
	Input.parse_input_event(forward)
	await create_timer(0.6).timeout
	forward.pressed = false
	Input.parse_input_event(forward)
	_check(
		scene.walker.step_count > step_start and scene.walker.steps.stream.get_length() > 0.2,
		"Walking distance triggers shoe footsteps"
	)
	await _key(KEY_SPACE)
	await create_timer(0.16).timeout
	_check(scene.walker.position.y > 0.25, "Space jumps upward under gravity")
	await create_timer(1.1).timeout
	_check(
		scene.walker.is_on_floor() and absf(scene.walker.position.y) < 0.1,
		"Jump lands back on floor"
	)
	scene.walker.position = Vector3(-9.6, 0.05, 0)
	scene.camera.rotation = Vector3(0, PI * 0.5, 0)
	forward.pressed = true
	Input.parse_input_event(forward)
	await create_timer(0.6).timeout
	forward.pressed = false
	Input.parse_input_event(forward)
	_check(scene.walker.position.x > -10.0, "Physical wall blocks walking capsule")
	scene.walker.position = Vector3(-2.7, 0.05, -1.5)
	scene.camera.rotation = Vector3(0, PI, 0)
	forward = forward.duplicate()
	forward.pressed = true
	Input.parse_input_event(forward)
	await create_timer(0.6).timeout
	forward.pressed = false
	Input.parse_input_event(forward)
	_check(scene.walker.position.z < -0.5, "Remaining pillar blocks walking capsule")
	_check(
		(
			scene.soundscape.machinery.playing
			and scene.soundscape.machinery.stream.get_length() > 39.9
		),
		"Forty-second muffled metallic background plays"
	)
	_check(
		(
			scene.lamps[1].material_override.get_shader_parameter("luminaire")
			and scene.lamps[1].material_override.get_shader_parameter("use_normal")
		),
		"Dim ceiling diffusers retain PBR normal detail"
	)
	_check(
		(
			scene.atmosphere.tickers.size() == 4
			and scene.atmosphere.displays[0].get_shader_parameter("dot_matrix")
		),
		"Four remaining matrix displays carry service tickers"
	)
	scene.security.tick(0.05)
	var beacon_on: float = scene.security.beacon.emission_energy_multiplier
	scene.security.tick(1.0)
	_check(
		beacon_on > scene.security.beacon.emission_energy_multiplier * 10.0,
		"Drone status beacon blinks independently of searchlight"
	)
	_check(scene.barrel.position.z < -14.0, "Barrel moved beside far-end mirror")
	var route_clear := true
	for sample in 600:
		scene.security.tick(sample * 0.1)
		var drone_position: Vector3 = scene.security.drone.position
		route_clear = route_clear and drone_position.x + 0.6 < -6.8 and drone_position.y + 0.3 < 4.2
	_check(route_clear, "Drone patrol clears ceiling signs and beams over its full route")
	var grate_material: StandardMaterial3D = scene.security.grates[0].material_override
	_check(
		(
			grate_material.albedo_texture != null
			and grate_material.normal_enabled
			and grate_material.metallic > 0.8
		),
		"Grates use scanned PBR metal including their base"
	)
	_check(
		MetroWalker.SPEED == 4.3 and MetroWalker.JUMP_SPEED == 6.0,
		"Walking speed and jump impulse increased"
	)
	for moment in [0.5, 5.5, 10.5]:
		scene.time = moment
		scene._update_camera()
		var fixed_pose: Transform3D = scene.camera.transform
		scene.time = moment + 4.0
		scene._update_camera()
		_check(
			scene.camera.transform == fixed_pose,
			"Opening shot remains locked off at %.1f seconds" % moment
		)


func _detail_checks(scene: Node3D) -> void:
	scene.set_process(false)
	_check(
		scene.atmosphere.ad_panels.size() == 4 and scene.atmosphere.adverts.size() == 2,
		"Four large ad screens share two movie feeds"
	)
	var feed: SubViewport = scene.atmosphere.adverts[0].get_viewport()
	scene.atmosphere.adverts[0].advance(2.0)
	feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await create_timer(1.0).timeout
	await _frames(3)
	var first_image := feed.get_texture().get_image()
	first_image.save_png("res://artifacts/advert-a.png")
	scene.atmosphere.adverts[0].advance(11.0)
	await create_timer(1.0).timeout
	await _frames(3)
	var second_image := feed.get_texture().get_image()
	second_image.save_png("res://artifacts/advert-b.png")
	_check(
		feed.size == Vector2i(1920, 1080) and _difference(first_image, second_image) > 0.01,
		"1080p advert visibly changes its content over time"
	)
	var advert: MetroAdvert = scene.atmosphere.adverts[0]
	_check(
		advert.player.stream is VideoStreamTheora and advert.player.stream_position > 1.0,
		"Advertisement decodes real video frames"
	)
	advert.advance(11.0)
	_check(advert.player.paused, "Video pauses with scene timeline")
	_check(
		scene.atmosphere.cameras[1].get_viewport().size == Vector2i(2560, 1440),
		"Mirrors render at native QHD"
	)
	_check(
		(
			scene.security.steam.is_empty()
			and scene.get_node("WorldEnvironment").environment.volumetric_fog_enabled
		),
		"Unlit gutter plumes removed; native spotlight scattering retained"
	)
	scene.security.tick(0.0)
	var drone_start: Vector3 = scene.security.drone.position
	scene.security.tick(6.0)
	_check(
		(
			scene.security.drone.position.distance_to(drone_start) > 3.0
			and scene.security.spotlight.shadow_enabled
		),
		"Drone patrol moves with a shadowed searchlight"
	)
	_check(
		scene.train.seat_count == 160 and scene.train.interior_lights.size() == 16,
		"Eight empty carriages have 160 seats and sixteen clinical white lights"
	)
	_check(
		not scene.train.transport.get_child(0).visible,
		"Solid exterior transport proxy never occludes visible train interior"
	)
	_check(
		scene.atmosphere.escape_panels.size() == 10,
		"Four platform and six tunnel emergency escape signs"
	)
	_check(
		scene.soundscape.hum.stream.get_length() > 6.9 and scene.soundscape.hum.playing,
		"Downloaded seven-second transformer hum loops"
	)
	scene.soundscape.tick(0.0, true, false)
	scene.soundscape.tick(7.5, true, false)
	await _frames(2)
	_check(
		scene.soundscape.voice.playing and scene.soundscape.voice.stream.get_length() > 6.0,
		"VoiceForge station-closure announcement triggers"
	)
	scene.soundscape.tick(20.4, true, false)
	await _frames(2)
	_check(
		scene.soundscape.bang.playing and scene.soundscape.bang.position.z < -20.0,
		"Downloaded mysterious impact plays from tunnel"
	)
	scene.soundscape.tick(20.5, false, true)
	_check(
		(
			scene.soundscape.hum.stream_paused
			and scene.soundscape.voice.volume_db == -80.0
			and scene.soundscape.bang.volume_db == -80.0
		),
		"Pause and mute cover the whole soundscape"
	)
	var radiance: Color = scene.barrel.emitter.radiance
	scene.barrel.tick(1.1, false)
	_check(
		(
			scene.barrel.flames.size() == 1
			and scene.barrel.emitter.radiance != radiance
			and scene.barrel.sparks.speed_scale == 0.0
		),
		"GPU fire, RC emission and embers respect timeline"
	)
	# Capture inspectable detail views, without using mouse automation.
	scene.train.animate(9.1)
	scene.camera.position = Vector3(2.5, 1.55, 6.7)
	scene.camera.look_at(Vector3(2.5, 1.6, 0.0))
	await _frames(10)
	root.get_texture().get_image().save_png("res://artifacts/train-interior.png")
	_check(
		_brightness(root.get_texture().get_image()) > 0.03,
		"Clinical interior visibly lit in rendered pixels"
	)
	scene.cascades.paused = false
	scene.camera.position = Vector3(-7.0, 1.7, -12.0)
	scene.camera.look_at(Vector3(-8.9, 1.05, -14.4))
	scene.atmosphere.update_views(scene.camera, 1.1)
	await _frames(15)
	root.get_texture().get_image().save_png("res://artifacts/barrel-detail.png")
	scene.camera.position = Vector3(-6.6, 2.0, 7.5)
	scene.camera.look_at(Vector3(-10.08, 2.1, 7.5))
	scene.atmosphere.update_views(scene.camera, 11.0)
	await _frames(8)
	root.get_texture().get_image().save_png("res://artifacts/advert-in-station.png")
	scene.security.tick(0.0)
	scene.camera.position = Vector3(-6.8, 3.1, 11.5)
	scene.camera.look_at(Vector3(-8.0, 3.55, 10.0))
	scene.atmosphere.update_views(scene.camera, 12.0)
	await _frames(20)
	root.get_texture().get_image().save_png("res://artifacts/security-detail.png")
	scene.camera.position = Vector3(-6.0, 1.3, 11.0)
	scene.camera.look_at(Vector3(-4.3, 1.0, 8.0))
	await _frames(15)
	var unlit := root.get_texture().get_image()
	await _key(KEY_F)
	await _frames(20)
	_check(
		scene.flashlight.visible and scene.flashlight.shadow_enabled,
		"F enables shadowed flashlight"
	)
	root.get_texture().get_image().save_png("res://artifacts/flashlight.png")
	_check(
		_difference(unlit, root.get_texture().get_image()) > 0.001,
		"Flashlight changes rendered illumination"
	)
	await _key(KEY_F)
	for moment in [0.7, 5.7, 10.7, 19.4]:
		scene.time = moment
		scene._update_camera()
		scene.train.animate(moment)
		scene.security.tick(moment)
		scene.atmosphere.update_views(scene.camera, moment)
		await _frames(30)
		root.get_texture().get_image().save_png("res://artifacts/intro-%.1f.png" % moment)


func _graffiti_checks(scene: Node3D) -> void:
	scene.cutscene = true
	scene.time = 0.0
	scene._process(0.0)
	var starts_blurred: bool = scene.focus_overlay.visible
	await _frames(8)
	var blurred := root.get_texture().get_image()
	blurred.save_png("res://artifacts/metro-focus-start.png")
	scene.time = 2.5
	scene._process(0.0)
	await _frames(8)
	root.get_texture().get_image().save_png("res://artifacts/metro-focus-sharp.png")
	_check(
		(
			starts_blurred
			and not scene.focus_overlay.visible
			and _difference(blurred, root.get_texture().get_image()) > 0.0001
		),
		"Opening focus resolves after 2.5 seconds"
	)
	scene.cutscene = false
	var painted: Array[ShaderMaterial] = []
	for material: ShaderMaterial in scene.cascades.materials:
		if material.get_shader_parameter("metro_graffiti"):
			painted.append(material)
	for pillar in [false, true]:
		scene.camera.position = Vector3(-5.4, 1.8, -5.0) if pillar else Vector3(-8.5, 1.8, -2.2)
		scene.camera.look_at(Vector3(-2.7, 1.7, -6.0) if pillar else Vector3(-10.2, 1.8, -2.2))
		scene.atmosphere.update_views(scene.camera, 0.0)
		await _frames(10)
		var with_paint := root.get_texture().get_image()
		with_paint.save_png("res://artifacts/graffiti-%s.png" % ("pillar" if pillar else "wall"))
		for material in painted:
			material.set_shader_parameter("metro_graffiti", false)
		await _frames(8)
		_check(
			_difference(with_paint, root.get_texture().get_image()) > 0.0001,
			"Graffiti visibly affects %s pixels" % ("pillar" if pillar else "wall")
		)
		for material in painted:
			material.set_shader_parameter("metro_graffiti", true)


func _brightness(image: Image) -> float:
	var result := 0.0
	var count := 0
	for y in range(0, image.get_height(), 8):
		for x in range(0, image.get_width(), 8):
			var color := image.get_pixel(x, y)
			result += (color.r + color.g + color.b) / 3.0
			count += 1
	return result / count


func _difference(a: Image, b: Image) -> float:
	var difference := 0.0
	var count := 0
	for y in range(120, 920, 12):
		for x in range(40, 1880, 12):
			var delta := a.get_pixel(x, y) - b.get_pixel(x, y)
			difference += absf(delta.r) + absf(delta.g) + absf(delta.b)
			count += 3
	return difference / count


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(1)
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(2)


func _frames(count: int) -> void:
	for frame in count:
		await process_frame
	await RenderingServer.frame_post_draw


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)
