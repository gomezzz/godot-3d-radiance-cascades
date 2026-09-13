extends Node3D
## Offline commercial photography: real meshes, moving cameras and editorial cuts.

var camera := Camera3D.new()
var product := Node3D.new()
var door := Node3D.new()
var title := Label.new()
var subtitle := Label.new()
var elapsed := 0.0
var campaign := 0
var cut := -1


func _ready() -> void:
	campaign = 1 if "--rest" in OS.get_cmdline_user_args() else 0
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("142439") if campaign == 0 else Color("262034")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b7cce5")
	environment.ambient_light_energy = 0.6
	world.environment = environment
	add_child(world)
	add_child(camera)
	camera.fov = 55
	add_child(product)
	add_child(door)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-45, -30, 0)
	key.light_energy = 2.0
	add_child(key)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-3, 4, -2)
	rim.light_color = Color("7ecfff") if campaign == 0 else Color("e8a7f0")
	rim.light_energy = 5
	rim.omni_range = 20
	add_child(rim)
	if campaign == 0:
		_aer()
	else:
		_rest()
	var hud := CanvasLayer.new()
	add_child(hud)
	var brand := Label.new()
	brand.text = "aer / life services" if campaign == 0 else "RestAssured / human storage"
	brand.position = Vector2(90, 60)
	brand.add_theme_font_size_override("font_size", 36)
	hud.add_child(brand)
	title.position = Vector2(90, 790)
	title.add_theme_font_size_override("font_size", 78)
	hud.add_child(title)
	subtitle.position = Vector2(95, 905)
	subtitle.add_theme_font_size_override("font_size", 34)
	hud.add_child(subtitle)
	var terms := Label.new()
	terms.text = "Paid placement. Your continued existence constitutes acceptance of these terms."
	terms.position = Vector2(95, 1020)
	terms.add_theme_font_size_override("font_size", 22)
	hud.add_child(terms)
	_process(0.0)


func _process(delta: float) -> void:
	elapsed += delta
	var shot := mini(int(elapsed / 5.0), 2)
	var t := fposmod(elapsed, 5.0) / 5.0
	if shot != cut:
		cut = shot
		title.text = (
			["Breathe now.", "We own the atmosphere.", "Exhale later."]
			if campaign == 0
			else ["Dream bigger.", "Sleep smaller.", "Finance your next eight hours."]
		)[shot]
		subtitle.text = (
			[
				"Precision oxygen. Delivered by the breath.",
				"A better world. Metered for you.",
				"Start your free inhale. Only 9.99 / breath."
			]
			if campaign == 0
			else [
				"Your future has a room waiting.",
				"The 2 m² executive suite. Space to be grateful.",
				"Rest is an investment. You are the collateral."
			]
		)[shot]
	title.position.x = 90 + 80 * exp(-t * 15)
	title.modulate.a = minf(t * 8, 1.0)
	subtitle.modulate.a = clampf((t - 0.08) * 6, 0, 1)
	if campaign == 0:
		product.rotation.y = elapsed * 0.5
		product.position.y = sin(elapsed * 1.7) * 0.1
		if shot == 0:
			camera.position = Vector3(3.8 - t * 2, 2.7, 5.3 - t)
		elif shot == 1:
			camera.position = Vector3(-7 + t * 12, 3.8, -5.8)
		else:
			camera.position = Vector3(sin(t * 1.8) * 5.5, 2.2 + t, cos(t * 1.8) * 5.5)
		camera.look_at(Vector3(0, 1.8, 0))
	else:
		door.position.x = smoothstep(0.1, 0.8, t) * 1.55 if shot == 1 else 0.0
		if shot == 0:
			camera.position = Vector3(0.2 * sin(t * PI), 1.6, 15 - t * 13)
			camera.look_at(Vector3(0, 1.5, -5))
		elif shot == 1:
			camera.position = Vector3(1.3 - t * 0.7, 1.6, 2.4 - t * 1.4)
			camera.look_at(Vector3(3.2, 1.2, 0))
		else:
			camera.position = Vector3(-6 + t * 4, 5.5 - t, 7 - t * 5)
			camera.look_at(Vector3(1, 1.2, -2))
	if elapsed >= 15.0:
		get_tree().quit()


func _aer() -> void:
	_box(Vector3(0, -0.12, 0), Vector3(30, 0.2, 30), Color("477088"))
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.65
	capsule.height = 2.7
	_shape(capsule, Vector3(0, 1.95, 0), Color("c0e6ef"), product)
	for y in [0.8, 1.35, 2.6, 3.1]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.62
		ring.outer_radius = 0.71
		_shape(ring, Vector3(0, y, 0), Color("183c50"), product)
	var label := Label3D.new()
	label.text = "aer"
	label.position = Vector3(0, 2.0, 0.67)
	label.font_size = 130
	label.pixel_size = 0.004
	product.add_child(label)
	for i in 16:
		var angle := i * TAU / 16
		var p := Vector3(cos(angle) * 8, 1.2, sin(angle) * 8)
		_box(p, Vector3(0.5, 2.4 + (i % 3), 0.5), Color("80a9bc"))
		var bubble := SphereMesh.new()
		bubble.radius = 0.08 + (i % 4) * 0.035
		bubble.height = bubble.radius * 2
		_shape(
			bubble,
			Vector3(cos(angle) * 1.6, 1 + i * 0.16, sin(angle) * 1.6),
			Color("e4f9ff"),
			product
		)


func _rest() -> void:
	_box(Vector3(0, -0.1, 2), Vector3(12, 0.2, 38), Color("807086"))
	for side in [-1.0, 1.0]:
		for row in 7:
			var z := 12.0 - row * 4
			_box(Vector3(side * 3.7, 1.4, z), Vector3(3.2, 2.8, 3.4), Color("9b8aa5"))
			_box(Vector3(side * 2.05, 1.45, z), Vector3(0.03, 2.2, 2.7), Color("252037"))
			_box(Vector3(side * 1.98, 2.48, z), Vector3(0.06, 0.04, 2.5), Color("f2dfe9"))
	# One open viewing pod, with the animated shutter in front of its furnished recess.
	_box(Vector3(2.01, 1.42, 0), Vector3(0.06, 2.2, 2.7), Color("d0b8cd"), door)
	_box(Vector3(1.94, 0.62, 0), Vector3(0.15, 0.16, 2.25), Color("ded7e1"))
	_box(Vector3(1.91, 0.77, -0.8), Vector3(0.17, 0.12, 0.55), Color.WHITE)


func _box(p: Vector3, size: Vector3, color: Color, parent: Node3D = self) -> void:
	var box := BoxMesh.new()
	box.size = size
	_shape(box, p, color, parent)


func _shape(shape: Mesh, p: Vector3, color: Color, parent: Node3D) -> void:
	var instance := MeshInstance3D.new()
	instance.mesh = shape
	instance.position = p
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.25
	material.roughness = 0.32
	instance.material_override = material
	parent.add_child(instance)
