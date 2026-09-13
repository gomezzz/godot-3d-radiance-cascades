class_name MetroSecurity
extends Node3D
## Textured drains and a surveillance drone with native spotlight scattering.

var drone := CharacterBody3D.new()
var gimbal := Node3D.new()
var spotlight := SpotLight3D.new()
var rotors: Array[MeshInstance3D] = []
var steam: Array[MeshInstance3D] = []
var grates: Array[MeshInstance3D] = []
var beacon := StandardMaterial3D.new()
var reflection := ReflectionProbe.new()
var navigation_lights: Array[Light3D] = []
var navigation_materials: Array[StandardMaterial3D] = []
var crashed := false
var investigating := false
var paused := false
var fall_age := 0.0


func build() -> void:
	var metal := MetroGeometry.scanned("metal_plate", 0.5, Color(0.55, 0.62, 0.68))
	metal.metallic = 0.95
	metal.roughness = 0.24
	metal.normal_scale = 0.45
	metal.heightmap_enabled = false
	var grate_metal := MetroGeometry.scanned("metal_plate", 0.35, Color(0.6, 0.65, 0.68))
	grate_metal.metallic = 0.85
	grate_metal.roughness = 0.5
	grate_metal.heightmap_enabled = false
	reflection.position = Vector3(-5, 2.5, 0)
	reflection.size = Vector3(12, 5, 35)
	reflection.interior = true
	reflection.box_projection = true
	add_child(reflection)
	for index in 4:
		var p := Vector3(-4.3 if index < 2 else 6.5, 0.06, -7.0 + (index % 2) * 15.0)
		grates.append(_box(self, p, Vector3(0.7, 0.05, 1.3), grate_metal))
		for bar in 12:
			_box(
				self,
				p + Vector3(0, 0.03, -0.58 + bar * 0.105),
				Vector3(0.7, 0.025, 0.025),
				grate_metal
			)
		# Keep the physical drains; the unlit smoke impostors are intentionally removed.
	add_child(drone)
	drone.collision_layer = 8
	drone.collision_mask = 1
	var collision := CollisionShape3D.new()
	# Rotation-invariant hull prevents visual tumbling from pushing a box corner
	# through the floor between kinematic sweeps.
	var collision_box := SphereShape3D.new()
	collision_box.radius = .38
	collision.shape = collision_box
	drone.add_child(collision)
	for side in [-1.0, 1.0]:
		var navigation := StandardMaterial3D.new()
		navigation.emission_enabled = true
		navigation.emission = Color(.1, .65, 1) if side > 0 else Color(1, .08, .015)
		navigation.albedo_color = navigation.emission
		_box(drone, Vector3(side * .35, .05, .2), Vector3(.08, .045, .18), navigation)
		navigation_materials.append(navigation)
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(side * .35, .1, .2)
		lamp.light_color = navigation.emission
		lamp.omni_range = 1.8
		lamp.light_volumetric_fog_energy = 0
		drone.add_child(lamp)
		navigation_lights.append(lamp)
	var body := PrismMesh.new()
	body.size = Vector3(0.65, 0.22, 0.9)
	var shell := _mesh(drone, body, Vector3.ZERO, metal)
	shell.rotation.z = PI
	var visor := MetroGeometry.plain(Color(0.12, 0.003, 0.001), 0.5, 0.16)
	visor.emission_enabled = true
	visor.emission = Color(0.9, 0.018, 0.004)
	_box(drone, Vector3(0, -0.01, -0.46), Vector3(0.38, 0.028, 0.03), visor)
	for side in [-1.0, 1.0]:
		var fin := PrismMesh.new()
		fin.size = Vector3(0.15, 0.25, 0.7)
		_mesh(drone, fin, Vector3(side * 0.3, 0.1, 0.12), metal)
	var glow := MetroGeometry.plain(Color(0.08, 0.15, 0.18))
	glow.emission_enabled = true
	glow.emission = Color(0.85, 0.94, 1.0)
	glow.emission_energy_multiplier = 0.6
	for x in [-0.29, 0.29]:
		for z in [-0.3, 0.3]:
			_box(drone, Vector3(x * 0.5, 0, z * 0.5), Vector3(0.4, 0.035, 0.06), metal)
			var ring := TorusMesh.new()
			ring.inner_radius = 0.105
			ring.outer_radius = 0.135
			_mesh(drone, ring, Vector3(x, 0, z), metal)
			rotors.append(_box(drone, Vector3(x, 0, z), Vector3(0.24, 0.015, 0.035), metal))
			_box(drone, Vector3(x, 0.025, z), Vector3(0.045, 0.008, 0.012), glow)
	beacon.albedo_color = Color(0.25, 0.008, 0.004)
	beacon.emission_enabled = true
	beacon.emission = Color(1.0, 0.04, 0.01)
	_box(drone, Vector3(0, 0.078, 0.18), Vector3(0.055, 0.015, 0.035), beacon)
	drone.add_child(gimbal)
	gimbal.position = Vector3(0, -0.045, -0.24)
	var lens := BoxMesh.new()
	lens.size = Vector3(0.14, 0.035, 0.025)
	var glass := _mesh(gimbal, lens, Vector3(0, 0, -0.06), glow)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	spotlight.position.z = -0.16
	spotlight.light_color = Color(0.68, 0.82, 1.0)
	spotlight.light_energy = 7.0
	spotlight.spot_range = 8.0
	spotlight.spot_angle = 22.0
	spotlight.spot_angle_attenuation = 1.5
	spotlight.shadow_enabled = true
	spotlight.light_volumetric_fog_energy = 3.0
	gimbal.add_child(spotlight)
	# A thin local aerosol volume makes the real spotlight visible between vents.
	var beam := FogVolume.new()
	beam.size = Vector3(5, 5, 8)
	beam.position.z = -4.0
	var haze := FogMaterial.new()
	haze.density = 0.018
	haze.albedo = Color(0.65, 0.72, 0.8)
	haze.edge_fade = 0.25
	beam.material = haze
	gimbal.add_child(beam)
	tick(0.0)


func tick(seconds: float, delta := 1.0 / 60.0) -> void:
	if crashed:
		return
	for index in navigation_lights.size():
		var flash := fposmod(seconds + index * .43, 1.37) < .12
		navigation_lights[index].light_energy = 2.0 if flash else .08
		navigation_materials[index].emission_energy_multiplier = 9.0 if flash else .3
	beacon.emission_energy_multiplier = 2.0 if fposmod(seconds, 2.4) < 0.16 else 0.02
	if investigating:
		drone.position = drone.position.move_toward(Vector3(-7.7, 3.25, 0), delta * 2.3)
	else:
		drone.position = Vector3(
			-8.0 + sin(seconds * .71) * .22 + sin(seconds * 2.31) * .18,
			3.45 + sin(seconds * 1.7) * .12 + sin(seconds * 3.1) * .07,
			10.0 * cos(seconds * .16) + sin(seconds * 1.13) * .65
		)
	drone.rotation.y = sin(seconds * .83) * .5 + sin(seconds * 2.11) * .15
	drone.rotation.z = sin(seconds * 1.31) * .15
	drone.rotation.x = sin(seconds * 1.91) * .09
	gimbal.rotation = Vector3(-0.95, sin(seconds * 0.6) * 0.65, 0)
	for rotor in rotors:
		rotor.rotation.y = seconds * 65.0


func crash() -> void:
	if crashed:
		return
	crashed = true
	drone.velocity = Vector3(4.0, -.4, 1.1)
	spotlight.visible = false
	for lamp in navigation_lights:
		lamp.visible = false
	for material in navigation_materials:
		material.emission_enabled = false


func _physics_process(delta: float) -> void:
	if not crashed or paused or fall_age > 4.0:
		return
	fall_age += delta
	drone.velocity.y -= 9.8 * delta
	var collision := drone.move_and_collide(drone.velocity * delta)
	if collision:
		drone.velocity = drone.velocity.bounce(collision.get_normal()) * .22
	else:
		drone.rotation += Vector3(3.7, 1.9, 4.5) * delta


func _box(parent: Node3D, p: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var shape := BoxMesh.new()
	shape.size = size
	return _mesh(parent, shape, p, material)


func _mesh(parent: Node3D, shape: Mesh, p: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.position = p
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh
