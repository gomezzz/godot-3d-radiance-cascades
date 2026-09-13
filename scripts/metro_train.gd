class_name MetroTrain
extends RefCounted
## Detailed moving raster geometry follows nine cheap analytic transport proxies.

const SPEED := 32.0
const CAR_COUNT := 8
const CYCLE := 16.0

var visual := Node3D.new()
var transport := Node3D.new()
var wheels: Array[MeshInstance3D] = []
var headlights: Array[SpotLight3D] = []
var interior_lights: Array[OmniLight3D] = []
var seat_count := 0
var batches: Dictionary[Material, SurfaceTool] = {}


func build() -> void:
	visual.name = "TrainDetail"
	transport.name = "TrainLightingProxies"
	var silver := MetroGeometry.scanned("blue_metal_plate", 2.5, Color(0.67, 0.72, 0.75))
	silver.metallic = 0.75
	silver.heightmap_enabled = false
	var red := MetroGeometry.scanned("rusty_painted_metal", 1.2, Color(0.55, 0.08, 0.04))
	var black := MetroGeometry.plain(Color(0.025, 0.045, 0.06), 0.15, 0.25)
	var rubber := MetroGeometry.scanned("rubber_tiles", 1.0, Color(0.16, 0.17, 0.18))
	var collision_body := AnimatableBody3D.new()
	collision_body.add_to_group("metro_train")
	collision_body.collision_layer = 5
	collision_body.sync_to_physics = false
	visual.add_child(collision_body)
	for car in CAR_COUNT:
		var z := -car * 8.1
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.8, 3.2, 7.7)
		collider.shape = shape
		collider.position = Vector3(2.5, 1.35, z)
		collision_body.add_child(collider)
		var hull := _proxy(Vector3(2.5, 1.35, z), Vector3(2.8, 2.9, 7.7), silver.albedo_color)
		hull.material_override = silver
		hull.visible = false
		_interior(z, silver, rubber)
		for side in [-1.0, 1.0]:
			# Coarse exterior transport stays cheap; raster has real window openings.
			var strip := _proxy(
				Vector3(2.5 + side * 1.415, 1.9, z), Vector3(0.025, 0.75, 6.9), Color.WHITE
			)
			strip.radiance = Color(0.85, 0.93, 1.0) * 1.5
			strip.visible = false
			_box(Vector3(2.5 + side * 1.4, 0.58, z), Vector3(0.09, 1.1, 7.7), silver)
			_box(Vector3(2.5 + side * 1.4, 2.63, z), Vector3(0.09, 0.4, 7.7), silver)
			for window in 6:
				var wz := z - 2.95 + window * 1.16
				_box(Vector3(2.5 + side * 1.4, 1.78, wz - 0.55), Vector3(0.12, 1.3, 0.16), silver)
				for y in [1.16, 2.4]:
					_box(Vector3(2.5 + side * 1.46, y, wz), Vector3(0.06, 0.055, 1.07), black)
			for dz in [-1.75, 1.75]:
				_box(Vector3(2.5 + side * 1.43, 1.1, z + dz), Vector3(0.03, 2.05, 0.95), silver)
				_box(Vector3(2.5 + side * 1.46, 1.1, z + dz), Vector3(0.025, 2.04, 0.022), black)
			_box(Vector3(2.5 + side * 1.43, 0.85, z), Vector3(0.04, 0.3, 7.65), red)
			for rib in 4:
				_box(
					Vector3(2.5 + side * 1.43, 0.12 + rib * 0.1, z),
					Vector3(0.025, 0.025, 7.6),
					silver
				)
		_roof(z, silver)
		for end in [-3.82, 3.82]:
			_box(Vector3(2.5, 1.35, z + end), Vector3(2.8, 2.9, 0.07), silver)
		_box(Vector3(2.5, 3.05, z - 0.5), Vector3(1.1, 0.28, 2.3), rubber)
		for vent in 12:
			_box(Vector3(2.5, 3.2, z - 1.45 + vent * 0.17), Vector3(0.95, 0.025, 0.045), silver)
		_box(Vector3(2.5, -0.15, z), Vector3(2.3, 0.35, 7.5), rubber)
		for dz in [-2.4, 2.4]:
			_box(Vector3(2.5, -0.25, z + dz), Vector3(2.2, 0.35, 1.2), black)
			for side in [-1.0, 1.0]:
				var wheel := MeshInstance3D.new()
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.34
				cylinder.bottom_radius = 0.34
				cylinder.height = 0.17
				cylinder.radial_segments = 20
				wheel.mesh = cylinder
				wheel.material_override = rubber
				wheel.rotation.z = PI * 0.5
				wheel.position = Vector3(2.5 + side * 0.9, -0.15, z + dz)
				visual.add_child(wheel)
				wheels.append(wheel)
		if car < CAR_COUNT - 1:
			_box(Vector3(2.5, 1.3, z - 4.05), Vector3(2.2, 2.3, 0.4), rubber)
	_box(Vector3(2.5, 2.0, 3.87), Vector3(2.35, 1.0, 0.04), black)
	_box(Vector3(2.5, 0.75, 3.88), Vector3(2.8, 0.32, 0.045), red)
	for side in [-1.0, 1.0]:
		var lamp := MetroGeometry.plain(Color.WHITE)
		lamp.emission_enabled = true
		lamp.emission = Color(1.0, 0.8, 0.5)
		lamp.emission_energy_multiplier = 7.0
		_box(Vector3(2.5 + side * 0.9, 0.6, 3.93), Vector3(0.28, 0.18, 0.06), lamp)
		var light := SpotLight3D.new()
		light.position = Vector3(2.5 + side * 0.9, 0.6, 4.0)
		light.rotation.y = PI
		light.light_color = Color(1.0, 0.8, 0.5)
		light.light_energy = 4.0
		light.spot_range = 18
		light.spot_angle = 38
		visual.add_child(light)
		headlights.append(light)
	var destination := Label3D.new()
	destination.text = "M2  /  NORTHBOUND"
	destination.position = Vector3(2.5, 2.65, 3.91)
	destination.font_size = 42
	destination.pixel_size = 0.005
	destination.modulate = Color(1.0, 0.62, 0.18)
	visual.add_child(destination)
	_commit_batches()


func animate(seconds: float) -> void:
	# Eight cars at 115 km/h. The trailing car clears the far tunnel before reset.
	var offset := -285.0 + fposmod(seconds, CYCLE) * SPEED
	visual.position.z = offset
	transport.position.z = offset
	for wheel in wheels:
		wheel.rotation.x = seconds * SPEED / 0.34


func _roof(z: float, material: Material) -> void:
	# An enclosing cylinder would put its lower half inside the ceiling lights.
	_box(Vector3(2.5, 2.86, z), Vector3(2.8, 0.2, 7.65), material)


func _interior(z: float, metal: Material, floor_material: Material) -> void:
	var lining := MetroGeometry.plain(Color(0.72, 0.77, 0.79), 0.05, 0.55)
	lining.set_meta("rc_local_diffuse", true)
	var seating := MetroGeometry.scanned("rubber_tiles", 0.6, Color(0.18, 0.24, 0.3))
	seating.heightmap_enabled = false
	seating.set_meta("rc_local_diffuse", true)
	var rail := metal.duplicate() as StandardMaterial3D
	rail.set_meta("rc_local_diffuse", true)
	var floor_mat := floor_material.duplicate() as StandardMaterial3D
	floor_mat.set_meta("rc_local_diffuse", true)
	_box(Vector3(2.5, 0.16, z), Vector3(2.65, 0.1, 7.55), floor_mat)
	_box(Vector3(2.5, 2.73, z), Vector3(2.65, 0.08, 7.5), lining)
	for end in [-3.74, 3.74]:
		_box(Vector3(2.5, 1.42, z + end), Vector3(2.65, 2.45, 0.045), lining)
		_box(Vector3(2.5, 1.38, z + end * 0.996), Vector3(0.78, 2.25, 0.035), rail)
	for side in [-1.0, 1.0]:
		_box(Vector3(2.5 + side * 1.33, 0.71, z), Vector3(0.045, 1.0, 7.5), lining)
		_box(Vector3(2.5 + side * 0.65, 2.45, z), Vector3(0.025, 0.025, 7.3), rail)
		for index in 10:
			var p := Vector3(2.5 + side * 0.97, 0.64, z - 3.15 + index * 0.7)
			_box(p, Vector3(0.57, 0.11, 0.58), seating)
			_box(p + Vector3(side * 0.25, 0.28, 0), Vector3(0.09, 0.58, 0.58), seating)
			seat_count += 1
		for dz in [-2.4, 0.0, 2.4]:
			_box(Vector3(2.5 + side * 0.62, 1.35, z + dz), Vector3(0.035, 2.2, 0.035), rail)
	var tube := MetroGeometry.plain(Color.WHITE)
	tube.emission_enabled = true
	tube.emission = Color(0.86, 0.93, 1.0)
	tube.emission_energy_multiplier = 2.5
	for dz in [-2.1, 2.1]:
		_box(Vector3(2.5, 2.65, z + dz), Vector3(0.2, 0.04, 2.7), tube)
		var light := OmniLight3D.new()
		light.position = Vector3(2.5, 2.3, z + dz)
		light.light_color = Color(0.86, 0.93, 1.0)
		light.light_energy = 3.5
		light.omni_range = 3.4
		light.light_cull_mask = 4
		visual.add_child(light)
		interior_lights.append(light)


func _proxy(p: Vector3, size: Vector3, color: Color) -> RCPrimitive:
	var primitive := RCPrimitive.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	primitive.mesh = mesh
	primitive.position = p
	primitive.albedo = color
	transport.add_child(primitive)
	return primitive


func _box(p: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	if not batches.has(material):
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		batches[material] = builder
	var surface := batches[material]
	var arrays := mesh.surface_get_arrays(0)
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		var v: Vector3 = arrays[Mesh.ARRAY_VERTEX][index]
		var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][index]
		var uv := Vector2(v.x, v.y)
		if absf(n.x) > 0.5:
			uv = Vector2(v.z, v.y)
		elif absf(n.y) > 0.5:
			uv = Vector2(v.x, v.z)
		surface.set_normal(n)
		surface.set_uv(uv)
		surface.add_vertex(v + p)


func _commit_batches() -> void:
	# The entire train moves rigidly; hundreds of individual draw calls buy nothing.
	for material in batches:
		var surface := batches[material]
		surface.generate_tangents()
		surface.index()
		var instance := MeshInstance3D.new()
		instance.mesh = surface.commit()
		instance.material_override = material
		if material.has_meta("rc_local_diffuse"):
			instance.layers = 5
		visual.add_child(instance)
		visual.move_child(instance, 0)
	batches.clear()
