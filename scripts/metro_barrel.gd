class_name MetroBarrel
extends Node3D
## A tiny procedural fire with one RC emitter, local specular light and GPU embers.

var emitter := RCPrimitive.new()
var light := OmniLight3D.new()
var flames: Array[ShaderMaterial] = []
var sparks := GPUParticles3D.new()


func build(transport: Node3D) -> void:
	position = Vector3(-8.9, 0, -14.4)
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	emitter.mesh = sphere
	emitter.position = position + Vector3(0, 0.95, 0)
	emitter.visible = false
	emitter.radiance = Color(1.0, 0.18, 0.025) * 12.0
	transport.add_child(emitter)
	var metal := MetroGeometry.scanned("rusty_painted_metal", 1.0, Color(0.36, 0.3, 0.26))
	metal.metallic = 0.55
	metal.heightmap_enabled = false
	metal.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shell := CylinderMesh.new()
	shell.top_radius = 0.32
	shell.bottom_radius = 0.3
	shell.height = 0.86
	shell.cap_top = false
	shell.radial_segments = 48
	_mesh(shell, Vector3(0, 0.43, 0), metal)
	for y in [0.06, 0.25, 0.65, 0.85]:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.305
		ring.outer_radius = 0.33
		_mesh(ring, Vector3(0, y, 0), metal)
	var coal := MetroGeometry.plain(Color(0.04, 0.012, 0.005))
	coal.emission_enabled = true
	coal.emission = Color(1.0, 0.1, 0.005)
	coal.emission_energy_multiplier = 1.3
	for index in 7:
		var chunk := SphereMesh.new()
		chunk.radius = 0.09
		chunk.height = 0.12
		_mesh(chunk, Vector3(sin(index * 2.4) * 0.2, 0.77, cos(index * 2.4) * 0.2), coal)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.065
	noise.fractal_octaves = 3
	var fuel := NoiseTexture3D.new()
	fuel.width = 64
	fuel.height = 64
	fuel.depth = 64
	fuel.seamless = true
	fuel.noise = noise
	for index in 1:
		var quad := BoxMesh.new()
		quad.size = Vector3(0.76, 1.1, 0.76)
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/metro_flame.gdshader")
		material.set_shader_parameter("fuel_tex", fuel)
		var flame := _mesh(quad, Vector3(0, 1.07, 0), material)
		flame.scale = Vector3(0.75, 0.55, 0.75)
		flames.append(material)
	light.position.y = 1.15
	light.light_color = Color(1.0, 0.28, 0.055)
	light.omni_range = 5.0
	light.shadow_enabled = true
	add_child(light)
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 18.0
	process.initial_velocity_min = 0.8
	process.initial_velocity_max = 1.5
	process.gravity = Vector3(0.045, -0.08, 0.02)
	process.damping_min = 0.35
	process.damping_max = 0.65
	process.angular_velocity_min = -150
	process.angular_velocity_max = 150
	process.angle_min = -180
	process.angle_max = 180
	process.scale_min = 0.012
	process.scale_max = 0.035
	var cooling := Gradient.new()
	cooling.offsets = PackedFloat32Array([0, 0.18, 0.45, 0.72, 1])
	cooling.colors = PackedColorArray(
		[
			Color(1, .55, .12),
			Color(.85, .17, .025),
			Color(.24, .20, .17),
			Color(.075, .075, .075),
			Color(.015, .015, .015, 0)
		]
	)
	var ramp := GradientTexture1D.new()
	ramp.gradient = cooling
	process.color_ramp = ramp
	sparks.process_material = process
	sparks.amount = 20
	sparks.lifetime = 3.5
	sparks.position.y = 0.9
	var ash := ShaderMaterial.new()
	ash.shader = preload("res://shaders/metro_ember.gdshader")
	sparks.draw_pass_1 = _ash_mesh(ash)
	add_child(sparks)


func _ash_mesh(material: Material) -> ArrayMesh:
	# A torn perimeter and interior crease ring create folded paper-like ash.
	# The shader further deforms each particle independently, without topology churn.
	var rng := RandomNumberGenerator.new()
	rng.seed = 91277
	var outer := PackedVector3Array()
	var inner := PackedVector3Array()
	const EDGES := 18
	for index in EDGES:
		var angle := TAU * index / EDGES
		var radius := rng.randf_range(.30, .62)
		outer.append(
			Vector3(
				cos(angle) * radius,
				sin(angle) * radius,
				.12 * sin(angle * 3) + rng.randf_range(-.07, .07)
			)
		)
		inner.append(Vector3(cos(angle) * .19, sin(angle) * .19, .10 * cos(angle * 2) + .04))
	var flakes := SurfaceTool.new()
	flakes.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in EDGES:
		var next := (index + 1) % EDGES
		for vertex in [
			Vector3(0, 0, -.06),
			inner[index],
			inner[next],
			inner[index],
			outer[index],
			outer[next],
			inner[index],
			outer[next],
			inner[next]
		]:
			flakes.set_uv(Vector2(vertex.x, vertex.y))
			flakes.add_vertex(vertex)
	flakes.generate_normals()
	flakes.set_material(material)
	return flakes.commit()


func tick(seconds: float, moving: bool) -> void:
	var energy := 0.62 + 0.24 * sin(seconds * 11.7) + 0.13 * sin(seconds * 23.3)
	emitter.radiance = Color(1.0, 0.18, 0.025) * 12.0 * energy
	light.light_energy = energy * 1.4
	for material in flames:
		material.set_shader_parameter("scene_time", seconds * 1.8)
	sparks.speed_scale = 1.0 if moving else 0.0


func _mesh(shape: Mesh, p: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = p
	mesh.material_override = material
	add_child(mesh)
	return mesh
