extends "res://scripts/reactor_hall.gd"
## Reuse the laboratory's flight controls and benchmark/capture harness.

const LAMP_ENERGY := 2.2
const SPECULAR_ENERGY := 0.65
const CUTSCENE_LENGTH := 24.0

@export var postfx_enabled := true

var postfx := MetroPostFX.new()
var station := MetroGeometry.new()
var train := MetroTrain.new()
var lamps: Array[RCPrimitive] = []
var highlights: Array[OmniLight3D] = []
var flicker_enabled := true
var atmosphere := MetroAtmosphere.new()
var train_audio := AudioStreamPlayer3D.new()
var soundscape := MetroSoundscape.new()
var barrel := MetroBarrel.new()
var security := MetroSecurity.new()
var walker := MetroWalker.new()
var flashlight := MetroFlashlight.new()
var lightning := MetroLightning.new()
var focus_overlay := ColorRect.new()
var focus_material := ShaderMaterial.new()
var cutscene := true
var audio_muted := false
var last_cycle := -1
var shortcut_hint := CanvasLayer.new()
var _quitting := false
var _previous_auto_quit := true


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	allow_free_flight = false
	_previous_auto_quit = get_tree().auto_accept_quit
	get_tree().auto_accept_quit = false
	get_window().content_scale_size = Vector2i(2560, 1440)
	get_window().mode = Window.MODE_WINDOWED
	get_window().current_screen = DisplayServer.get_primary_screen()
	get_window().mode = Window.MODE_FULLSCREEN
	_parse_args()
	var geometry := Node3D.new()
	geometry.name = "TransportGeometry"
	add_child(geometry)
	var architecture := station.build()
	geometry.add_child(architecture)
	architecture.create_trimesh_collision()
	# A walker-only smooth surface clears sleepers/rail fasteners while retaining
	# the detailed world collider for lightning, train and drone physics.
	var track_walk := StaticBody3D.new()
	track_walk.name = "TrackWalkingSurface"
	track_walk.collision_layer = 16
	track_walk.collision_mask = 0
	var track_shape := CollisionShape3D.new()
	var track_box := BoxShape3D.new()
	track_box.size = Vector3(6.0, .15, 34.5)
	track_shape.shape = track_box
	track_shape.position = Vector3(2.5, -.44, 0)
	track_walk.add_child(track_shape)
	add_child(track_walk)
	generator.piece_count = station.piece_count
	train.build()
	geometry.add_child(train.transport)
	add_child(train.visual)
	train.animate(0.0)
	add_child(barrel)
	barrel.build(geometry)
	var barrel_body := StaticBody3D.new()
	var barrel_collision := CollisionShape3D.new()
	var barrel_shape := CylinderShape3D.new()
	barrel_shape.radius = 0.34
	barrel_shape.height = 0.9
	barrel_collision.shape = barrel_shape
	barrel_collision.position.y = 0.45
	barrel_body.add_child(barrel_collision)
	barrel.add_child(barrel_body)
	for x in [-5.5, 7.0]:
		for z in range(-14, 15, 5):
			var lamp := RCPrimitive.new()
			var shape := BoxMesh.new()
			shape.size = Vector3(0.38, 0.08, 2.35)
			lamp.mesh = shape
			lamp.albedo = Color(0.24, 0.27, 0.25)
			var diffuser := MetroGeometry.scanned("blue_metal_plate", 0.7, Color(0.4, 0.43, 0.4))
			diffuser.metallic = 0.0
			diffuser.heightmap_enabled = false
			diffuser.normal_scale = 0.35
			lamp.material_override = diffuser
			lamp.position = Vector3(x, 4.14, z)
			lamp.radiance = Color(0.47, 0.68, 0.63) * LAMP_ENERGY
			geometry.add_child(lamp)
			lamps.append(lamp)
			var light := OmniLight3D.new()
			light.position = Vector3(x, 3.95, z)
			light.light_color = Color(0.47, 0.68, 0.63)
			light.light_energy = SPECULAR_ENERGY
			light.omni_range = 8.5
			light.light_volumetric_fog_energy = 0.0
			light.shadow_enabled = lamps.size() - 1 in [2, 9]
			add_child(light)
			highlights.append(light)
	add_child(lightning)
	lightning.build(geometry)
	cascades = RadianceCascades.new()
	cascades.geometry_root = geometry
	cascades.visual_geometry_root = train.visual
	cascades.pbr_surfaces = true
	cascades.volume_origin = Vector3(-18, -3, -18)
	cascades.probe_spacing = 1.5
	cascades.sky_radiance = Color(0.0002, 0.0004, 0.0006)
	cascades.bounce_feedback = 0.55
	cascades.temporal_blend = 0.5
	add_child(cascades)
	for material in cascades.materials:
		material.set_shader_parameter("metro_reflection_clip", true)
		if material.get_shader_parameter("albedo_map") == station.palette["tile"].albedo_texture:
			material.set_shader_parameter("metro_graffiti", true)
			material.set_shader_parameter(
				"graffiti_map", preload("res://assets/textures/graffiti/paint_atlas.png")
			)
	for lamp in lamps:
		lamp.material_override.set_shader_parameter("luminaire", true)
	add_child(atmosphere)
	atmosphere.build()
	_signage()
	atmosphere.build_adverts()
	atmosphere.build_escape_signs()
	add_child(security)
	security.build()
	add_child(walker)
	_setup_audio()
	_build_hud()
	add_child(postfx)
	$WorldEnvironment.environment.glow_enabled = postfx_enabled
	camera.add_child(flashlight)
	var focus_layer := CanvasLayer.new()
	focus_layer.layer = 2
	add_child(focus_layer)
	focus_layer.add_child(focus_overlay)
	focus_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	focus_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_material.shader = preload("res://shaders/metro_focus.gdshader")
	focus_overlay.material = focus_material
	cascades.failed.connect(
		func(message: String) -> void:
			push_error(message)
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
		"METRO_READY pillars=",
		station.pillar_count,
		" triangles=",
		cascades.mesh_bvh.triangle_count
	)


func _process(delta: float) -> void:
	if lightning.epilogue != null:
		lightning.tick(delta, self)
		postfx.tick(camera, delta, postfx_enabled, motion, true)
		return
	lightning.restore_lights()
	super._process(delta)
	train.animate(time)
	if cutscene and time >= CUTSCENE_LENGTH:
		_enter_walk()
	walker.muted = audio_muted
	walker.walking_enabled = motion
	atmosphere.update_views(camera, time)
	barrel.tick(time, motion)
	security.paused = not motion
	security.tick(time, delta if motion else 0.0)
	flashlight.tick(time)
	focus_overlay.visible = postfx_enabled and cutscene and time < 2.5
	focus_material.set_shader_parameter("blur", 1.0 - smoothstep(0.0, 2.5, time))
	_update_audio()
	for index in lamps.size():
		var intensity := lamp_intensity(time, index, flicker_enabled)
		var circuit := 1.0 if index in [0, 2, 5, 7, 9] else 0.002
		lamps[index].radiance = Color(0.47, 0.68, 0.63) * LAMP_ENERGY * intensity * circuit
		highlights[index].light_energy = SPECULAR_ENERGY * intensity * circuit
		highlights[index].visible = circuit > 0.1
	lightning.tick(delta, self)
	postfx.tick(camera, delta, postfx_enabled, motion, lightning.epilogue != null)
	status.visible = not cutscene
	if total_frames % 15 == 0 and cascades.is_ready:
		status.text = (
			"%d FPS / %s\n22 pillars / 8 cars / %d static triangles\nGPU cascades every %d frame(s)"
			% [
				Engine.get_frames_per_second(),
				str(get_viewport().get_texture().get_size()),
				cascades.mesh_bvh.triangle_count,
				cascades.update_every_frames
			]
		)


static func lamp_intensity(seconds: float, index: int, enabled: bool) -> float:
	# Only two failing ballasts; localized outages, not full-screen strobing.
	if not enabled or index not in [2, 9]:
		return 1.0
	var cell := int(floor(seconds * 11.0))
	var noise := MetroFlashlight.noise_at(cell + index * 719)
	var outage := MetroFlashlight.noise_at(int(seconds * 1.7) + index * 31)
	if outage < 0.3 and noise < 0.55:
		return 0.08 + noise * 0.3
	return 0.94 + noise * 0.06


# gdlint:disable=max-returns
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_O:
		postfx_enabled = not postfx_enabled
		$WorldEnvironment.environment.glow_enabled = postfx_enabled
		return
	if lightning.epilogue != null:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == KEY_P:
				motion = not motion
			elif event.keycode == KEY_M:
				audio_muted = not audio_muted
				soundscape.tick(time, motion, audio_muted)
			elif event.keycode == KEY_ESCAPE:
				_quit_cleanly()
		return
	if lightning.contact:
		if event is InputEventKey and event.pressed and not event.echo:
			match event.keycode:
				KEY_M:
					audio_muted = not audio_muted
				KEY_P:
					motion = not motion
				KEY_ESCAPE:
					_quit_cleanly()
		return
	if (
		lightning.elapsed >= 0
		and event is InputEventKey
		and event.keycode in [KEY_C, KEY_R, KEY_ENTER]
	):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_F1, KEY_H]:
			hud.visible = not hud.visible
			return
		if event.keycode in [KEY_F, KEY_B]:
			if event.keycode == KEY_F:
				flashlight.visible = not flashlight.visible
			else:
				cascades.paused = not cascades.paused
			return
		if event.keycode == KEY_ENTER:
			_enter_walk()
			return
		if event.keycode == KEY_SPACE:
			if walker.active and motion:
				walker.jump_requested = true
			return
		if event.keycode == KEY_P:
			motion = not motion
			return
		if event.keycode == KEY_ESCAPE:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			else:
				_quit_cleanly()
			return
		if event.keycode == KEY_M:
			audio_muted = not audio_muted
		if event.keycode == KEY_C or event.keycode == KEY_R:
			walker.stop()
			cutscene = true
			cinematic = true
			motion = true
			time = 0.0
			last_cycle = -1
			train_audio.stop()
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera.rotation.y -= event.relative.x * 0.002
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.002, -1.4, 1.4)
	elif event is InputEventKey:
		super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		flicker_enabled = not flicker_enabled


func _update_camera() -> void:
	camera.fov = 88.0
	if time < 5.0:
		camera.position = Vector3(-7.5, 3.5, 15.5)
		camera.look_at(Vector3(-2.0, 2.7, -5.0))
		return
	if time < 10.0:
		camera.position = Vector3(-7.5, 3.2, -16.0)
		camera.look_at(Vector3(-3.6, 1.1, 6.0))
		return
	if time < 15.0:
		camera.position = Vector3(-8.8, 0.35, 14.7)
		camera.look_at(Vector3(-3.2, 1.0, -4.0))
		return
	var progress := clampf((time - 15.0) / 9.0, 0.0, 1.0)
	var ease := progress * progress * (3.0 - 2.0 * progress)
	camera.position = Vector3(-5.6 + sin(progress * PI) * 1.0, 1.65, lerpf(-5.0, 14.0, ease))
	camera.look_at(Vector3(-4.2, 1.5, camera.position.z - 8.0))


func _enter_walk() -> void:
	if walker.active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		return
	cutscene = false
	cinematic = false
	motion = true
	walker.enter(camera)
	camera.fov = 78.0
	camera.rotation = Vector3.ZERO
	if capture_path.is_empty() and benchmark_path.is_empty():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _exit_tree() -> void:
	if has_meta("train_limiter"):
		for index in range(AudioServer.get_bus_effect_count(0) - 1, -1, -1):
			if AudioServer.get_bus_effect(0, index) == get_meta("train_limiter"):
				AudioServer.remove_bus_effect(0, index)
		remove_meta("train_limiter")
	soundscape.stop()
	train_audio.stop()
	train_audio.stream = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().auto_accept_quit = _previous_auto_quit


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_cleanly()


func _quit_cleanly() -> void:
	if _quitting:
		return
	_quitting = true
	await _stop_audio()
	get_tree().quit()


func _setup_audio() -> void:
	add_child(soundscape)
	soundscape.build()
	train_audio.stream = load("res://assets/audio/train_rush.wav")
	assert(train_audio.stream != null, "Train recording missing")
	train_audio.unit_size = 28.0
	train_audio.max_db = 0.0
	train_audio.max_distance = 90.0
	train_audio.volume_db = 2.0
	var limiter := AudioEffectLimiter.new()
	limiter.ceiling_db = -1.0
	AudioServer.add_bus_effect(0, limiter)
	set_meta("train_limiter", limiter)
	train_audio.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_IDLE_STEP
	add_child(train_audio)


func _update_audio() -> void:
	soundscape.tick(time, motion, audio_muted)
	var cycle := int(time / MetroTrain.CYCLE)
	var phase := fposmod(time, MetroTrain.CYCLE)
	if phase >= 7.7 and cycle != last_cycle:
		last_cycle = cycle
		train_audio.play()
	# A long train is not a point at its nose: anchor sound to its nearest carriage.
	train_audio.position = Vector3(
		2.5,
		1.2,
		clampf(camera.global_position.z, train.visual.position.z - 57.0, train.visual.position.z)
	)
	train_audio.stream_paused = not motion
	train_audio.volume_db = -80.0 if audio_muted else 2.0


func _benchmark_name() -> String:
	return "METRO_BENCHMARK"


func _finish_capture() -> void:
	await _stop_audio()
	await super._finish_capture()


func _stop_audio() -> void:
	# Let the audio mixer release its playback reference before engine shutdown.
	set_process(false)
	walker.stop()
	if is_instance_valid(security.reflection):
		security.reflection.queue_free()
	soundscape.stop()
	train_audio.stop()
	train_audio.stream = null
	for frame in 5:
		await get_tree().process_frame


func _benchmark_details() -> Dictionary:
	for index in atmosphere.cameras.size():
		atmosphere.cameras[index].get_viewport().get_texture().get_image().save_png(
			"res://artifacts/reflection-%d.png" % index
		)
	return {
		"window_size": str(get_window().size),
		"window_mode": get_window().mode,
		"screen": get_window().current_screen,
		"pillars": station.pillar_count,
		"analytic_proxies": cascades.primitives.size(),
		"train_z": train.visual.position.z,
		"flicker": flicker_enabled,
		"pbr": cascades.pbr_surfaces,
	}


func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.scale = Vector2.ONE * (4.0 / 3.0)
	add_child(hud)
	hud.visible = false
	shortcut_hint.scale = hud.scale
	add_child(shortcut_hint)
	var hint := _label("F1: shortcuts", Vector2(1760, 1030), 15, Color("b0c0c1"))
	hint.reparent(shortcut_hint)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label("N O R T H L I N E", Vector2(42, 28), 30, Color("759087"))
	_label("M2 / NO SERVICE / 02:13", Vector2(44, 76), 15, Color("668578"))
	status = _label("Building station lighting...", Vector2(44, 950), 16, Color("c8d5d6"))
	_label(
		(
			"WASD  Walk    Space  Jump    Enter  Skip / capture    C  Replay\n"
			+ "F  Flashlight    B  Freeze GI    P  Pause    L  Flicker    M  Mute    Esc  Release"
			+ "\nO  Post FX on / off"
		),
		Vector2(1260, 980),
		15,
		Color("b0c0c1")
	)


func _signage() -> void:
	for z in [-12, 6]:
		_sign("M2   NORTHLINE", Vector3(-5.4, 3.25, z), 0, Color("192a2b"), Color("eee9d1"))
		_sign(
			"EXIT  /  SALIDA  >", Vector3(-5.4, 3.00, z - 0.01), 0, Color("192a2b"), Color("c8dbac")
		)


func _sign(
	text: String, p: Vector3, angle: float, _background: Color, _ink: Color, scale_px := 0.005
) -> void:
	atmosphere.screen(text, p, angle, scale_px > 0.004)
