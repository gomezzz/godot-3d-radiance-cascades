class_name MetroLightning
extends Node3D
## One-shot crossing event. Train contact is queried against Godot physics shapes.

const Picker = preload("res://scripts/scene_picker.gd")
const PLATFORM_END := 16.0
const BLACK_HOLD := 5.0
const FADE_TIME := 1.5
var epilogue: MetroDebugEpilogue
var proxy := RCPrimitive.new()
var orb := Node3D.new()
var light := OmniLight3D.new()
var arcs := MeshInstance3D.new()
var plasma := ShaderMaterial.new()
var arc_material := StandardMaterial3D.new()
var overlay := ColorRect.new()
var audio := AudioStreamPlayer3D.new()
var impact := AudioStreamPlayer3D.new()
var elapsed := -1.0
var collision_age := -1.0
var contact := false
var finished := false
var start_z := 0.0
var reduced := false
var saved_lights: Dictionary[Light3D, float] = {}
var saved_emitters: Dictionary[RCPrimitive, Color] = {}
var last_arc := -1
var query := PhysicsShapeQueryParameters3D.new()
var arc_frame := 0
var arc_growth := 0.0
var contact_points: Array[Vector3] = []
var core_material := ShaderMaterial.new()
var heat_material := ShaderMaterial.new()


func build(geometry: Node3D) -> void:
	reduced = Picker.reduced_flashes
	var sphere := SphereMesh.new()
	sphere.radius = 0.58
	sphere.height = 1.16
	proxy.mesh = sphere
	proxy.visible = false
	proxy.position = Vector3(0, -1000, 0)
	proxy.radiance = Color.BLACK
	geometry.add_child(proxy)
	add_child(orb)
	orb.visible = false
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = .18
	core_mesh.height = .36
	core.mesh = core_mesh
	core_material.shader = preload("res://shaders/lightning_core.gdshader")
	core.material_override = core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(core)
	var heat := MeshInstance3D.new()
	var heat_mesh := SphereMesh.new()
	heat_mesh.radius = 0.52
	heat_mesh.height = 1.04
	heat.mesh = heat_mesh
	heat_material.shader = preload("res://shaders/lightning_heat.gdshader")
	heat_material.render_priority = -10
	heat.material_override = heat_material
	heat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	orb.add_child(heat)
	plasma.shader = preload("res://shaders/ball_lightning.gdshader")
	for size in [0.38, 0.48, 0.60]:
		var shell := MeshInstance3D.new()
		shell.mesh = sphere
		shell.scale = Vector3.ONE * size
		shell.material_override = plasma
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.add_child(shell)
	arcs.mesh = ImmediateMesh.new()
	arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	arc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	arc_material.albedo_color = Color(0.6, 0.85, 1.0)
	arc_material.emission_enabled = true
	arc_material.emission = Color(0.28, 0.42, 1.0)
	arc_material.emission_energy_multiplier = 10
	arc_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	arcs.material_override = arc_material
	orb.add_child(arcs)
	light.light_color = Color(0.3, 0.5, 1.0)
	light.omni_range = 22
	light.shadow_enabled = true
	light.omni_shadow_mode = OmniLight3D.SHADOW_CUBE
	light.light_volumetric_fog_energy = 0
	orb.add_child(light)
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.color = Color(0, 0, 0, 0)
	audio.stream = preload("res://assets/audio/lightning_arc.wav")
	audio.finished.connect(_loop_audio)
	audio.unit_size = 32
	audio.max_db = 0.0
	audio.attenuation_filter_cutoff_hz = 12000
	audio.max_distance = 80
	orb.add_child(audio)
	impact.stream = preload("res://assets/audio/lightning_impact.wav")
	impact.unit_size = 18
	impact.max_distance = 100
	add_child(impact)
	var shape := SphereShape3D.new()
	shape.radius = 0.65
	query.shape = shape
	query.collision_mask = 4
	query.collide_with_areas = false


func restore_lights() -> void:
	for lamp in saved_lights:
		lamp.light_energy = saved_lights[lamp]
	for emitter in saved_emitters:
		emitter.radiance = saved_emitters[emitter]
	saved_lights.clear()
	saved_emitters.clear()


func _loop_audio() -> void:
	if orb.visible:
		audio.play()


func tick(delta: float, station: Node3D) -> void:
	if finished:
		return
	if elapsed < 0:
		if (
			station.walker.active
			and station.walker.position.x > 5.8
			and station.walker.position.y > -0.1
		):
			elapsed = 0
			start_z = PLATFORM_END
		else:
			return
	var dt: float = delta if station.motion else 0.0
	elapsed += dt
	audio.stream_paused = not station.motion
	impact.stream_paused = not station.motion
	audio.volume_db = -80 if station.audio_muted else 0
	impact.volume_db = -80 if station.audio_muted else -5
	if elapsed >= 2 and epilogue == null:
		_power_station(station, 0.0)
	if contact:
		collision_age += dt
		overlay.color.a = smoothstep(0.0, FADE_TIME, collision_age)
		station.walker.walking_enabled = false
		station.hud.visible = false
		station.shortcut_hint.visible = false
		if collision_age >= FADE_TIME + BLACK_HOLD:
			if epilogue == null:
				_power_station(station, 1.0)
				restore_lights()
				epilogue = MetroDebugEpilogue.new()
				station.add_child(epilogue)
				epilogue.build(station)
				station.train_audio.stop()
				impact.stop()
				station.focus_overlay.visible = false
			overlay.color.a = 0
			epilogue.tick(collision_age - FADE_TIME - BLACK_HOLD, station)
		if collision_age >= FADE_TIME + BLACK_HOLD + MetroDebugEpilogue.TOTAL_LENGTH:
			finished = true
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			get_tree().change_scene_to_file.call_deferred("res://scenes/scene_picker.tscn")
		return
	if elapsed < 3:
		var factor := 0.0
		if elapsed < 2:
			factor = (
				1.0 - elapsed / 2
				if reduced
				else (0.12 if MetroFlashlight.noise_at(int(elapsed * 19)) < .55 else 1.0)
			)
		if elapsed < 2:
			_power_station(station, factor)
		# Emissive screens are not native lights; the blackout covers their raster output too.
		overlay.color.a = 1.0 - factor
		return
	overlay.color.a = 0
	if not orb.visible:
		orb.visible = true
		audio.play()
	var age := elapsed - 3
	var travel := smoothstep(0.0, 18.0, age)
	var cross := smoothstep(18.0, 22.0, age)
	orb.position = Vector3(
		lerpf(-5.0, 2.5, cross), 1.65 + sin(age * 1.8) * .18, lerpf(start_z, -PLATFORM_END, travel)
	)
	proxy.position = orb.global_position
	var pulse := 1.0 + sin(age * 2.5) * .18
	if not reduced:
		pulse += pow(MetroFlashlight.noise_at(int(age * 23)), 6) * 2.0
	light.light_energy = pulse * (3.0 if reduced else 7.0)
	proxy.radiance = Color(.16, .36, 1.0) * pulse * 35
	plasma.set_shader_parameter("phase", age)
	plasma.set_shader_parameter("energy", pulse)
	core_material.set_shader_parameter("phase", age)
	core_material.set_shader_parameter("power", (12.0 if reduced else 35.0) * pulse)
	heat_material.set_shader_parameter("phase", age)
	heat_material.set_shader_parameter("strength", .4 if reduced else 1.0)
	station.security.investigating = true
	if station.security.drone.global_position.distance_to(orb.global_position) < 4.2:
		station.security.crash()
	arc_frame = int(age * (8 if reduced else 24))
	arc_growth = minf(age / 9, 1)


func _power_station(station: Node3D, factor: float) -> void:
	# Keep the barrel as the only independent light source. Raster emission and
	# native lamps must go dark too, not just their RC transport proxies.
	for node in station.find_children("*", "Light3D", true, false):
		var lamp := node as Light3D
		if (
			lamp == light
			or lamp == station.barrel.light
			or lamp in station.security.navigation_lights
		):
			continue
		if not saved_lights.has(lamp):
			saved_lights[lamp] = lamp.light_energy
		lamp.light_energy = saved_lights[lamp] * factor
	for emitter in station.cascades.primitives:
		if emitter == proxy or emitter == station.barrel.emitter:
			continue
		if not saved_emitters.has(emitter):
			saved_emitters[emitter] = emitter.radiance
		emitter.radiance = saved_emitters[emitter] * factor
	for material in station.cascades.materials:
		material.set_shader_parameter("station_power", factor)
	for material in station.atmosphere.displays:
		material.set_shader_parameter("station_power", factor)
	for panel in station.atmosphere.ad_panels + station.atmosphere.escape_panels:
		panel.material_override.set_shader_parameter("station_power", factor)
	for node in station.security.find_children("*", "MeshInstance3D", true, false):
		var material: Material = node.material_override
		if material is BaseMaterial3D and material not in station.security.navigation_materials:
			material.emission_enabled = factor > 0.0


func _physics_process(_delta: float) -> void:
	if contact or not orb.visible or audio.stream_paused:
		return
	if arc_frame != last_arc:
		last_arc = arc_frame
		_rebuild_arcs(arc_frame, arc_growth)
	if elapsed < 21:
		return
	query.transform = Transform3D(Basis.IDENTITY, orb.global_position)
	for hit in get_world_3d().direct_space_state.intersect_shape(query, 8):
		if hit["collider"].is_in_group("metro_train"):
			contact = true
			collision_age = 0
			impact.position = orb.position
			impact.play()
			audio.stop()
			orb.visible = false
			proxy.radiance = Color.BLACK
			proxy.position.y = -1000
			print("LIGHTNING_TRAIN_CONTACT")
			break


func _rebuild_arcs(frame: int, growth: float) -> void:
	var mesh := arcs.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = frame * 719 + 43
	contact_points.clear()
	for strand in 20:
		var direction := (
			Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
			. normalized()
		)
		var ray := PhysicsRayQueryParameters3D.create(
			orb.global_position,
			orb.global_position + direction * (3.0 + growth * 2.0),
			1,
			[get_parent().walker.get_rid()]
		)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			continue
		var endpoint: Vector3 = hit["position"] - orb.global_position
		contact_points.append(hit["position"])
		direction = endpoint.normalized()
		var previous := direction * .25
		for segment in range(1, 25):
			var fraction := segment / 24.0
			var jitter := (
				Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1))
				* .32
				* sin(fraction * PI)
			)
			var point := endpoint * fraction + jitter
			_ribbon(
				mesh,
				previous,
				point,
				.025 * pow(1.0 - (segment - 1) / 24.0, 1.5),
				.025 * pow(1.0 - fraction, 1.5)
			)
			if segment in [8, 16]:
				# Jagged returning branches, not the old straight chords to the tip.
				var branch := point + jitter * 1.7
				_ribbon(mesh, point, branch, .006, .003)
				_ribbon(mesh, branch, endpoint * minf(fraction + .1, 1.0), .003, 0.0)
			previous = point
	mesh.surface_end()


func _ribbon(mesh: ImmediateMesh, a: Vector3, b: Vector3, width: float, tip_width: float) -> void:
	var axis := Vector3.RIGHT if absf((b - a).normalized().y) > .95 else Vector3.UP
	var side := (b - a).cross(axis).normalized()
	for vertex in [
		a - side * width,
		b - side * tip_width,
		b + side * tip_width,
		a - side * width,
		b + side * tip_width,
		a + side * width
	]:
		mesh.surface_add_vertex(vertex)
	# Crossed ribbons stay legible from the puddle and mirror cameras too.
	side = (b - a).cross(side).normalized()
	for vertex in [
		a - side * width,
		b - side * tip_width,
		b + side * tip_width,
		a - side * width,
		b + side * tip_width,
		a + side * width
	]:
		mesh.surface_add_vertex(vertex)
