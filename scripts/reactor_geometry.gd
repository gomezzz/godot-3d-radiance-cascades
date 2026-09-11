class_name ReactorGeometry
extends RefCounted
## Deterministic, batched triangle geometry. Every visible structural face is traced.

const COLORS := {
	"alloy": Color(0.52, 0.61, 0.65),
	"dark": Color(0.2, 0.27, 0.32),
	"copper": Color(0.62, 0.31, 0.13),
	"floor": Color(0.39, 0.46, 0.49),
	"cyan": Color(0.1, 0.7, 0.9),
	"amber": Color(1.0, 0.55, 0.12),
}
var batches: Dictionary[String, Array] = {}
var piece_count := 0
var detail := 1


func build(detail_level: int = 1) -> MeshInstance3D:
	detail = detail_level
	batches.clear()
	piece_count = 0
	for key: String in COLORS:
		batches[key] = [PackedVector3Array(), PackedVector3Array(), PackedInt32Array()]
	_architecture()
	_reactor()
	_machinery()
	var mesh := ArrayMesh.new()
	for key: String in batches:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = batches[key][0]
		arrays[Mesh.ARRAY_NORMAL] = batches[key][1]
		arrays[Mesh.ARRAY_INDEX] = batches[key][2]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var material := StandardMaterial3D.new()
		material.albedo_color = COLORS[key]
		material.roughness = 0.8
		if key == "cyan" or key == "amber":
			material.emission_enabled = true
			material.emission = COLORS[key]
			material.emission_energy_multiplier = 12.0 if key == "cyan" else 9.0
		mesh.surface_set_material(mesh.get_surface_count() - 1, material)
	var instance := MeshInstance3D.new()
	instance.name = "ReactorHallMesh"
	instance.mesh = mesh
	return instance


func _architecture() -> void:
	_box(Vector3(0, -0.3, 0), Vector3(19, 0.6, 22), "floor")
	_box(Vector3(0, 6.5, -10.7), Vector3(19, 13, 0.6), "dark")
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 9.3, 2.0, 0), Vector3(0.45, 4, 22), "dark")
		for y in [4.0, 8.0]:
			_box(Vector3(side * 7.8, y, 0), Vector3(2.3, 0.25, 21), "alloy")
			_box(Vector3(side * 6.7, y + 0.9, 0), Vector3(0.08, 0.09, 21), "copper")
			_box(Vector3(side * 6.7, y + 0.45, 0), Vector3(0.06, 0.07, 21), "alloy")
			for z in range(-10, 11):
				_box(Vector3(side * 6.7, y + 0.45, z), Vector3(0.09, 0.9, 0.09), "alloy")
		for z in range(-9, 10, 3):
			_box(Vector3(side * 8.8, 6, z), Vector3(0.45, 12, 0.7), "alloy")
			_box(Vector3(side * 8.5, 6.2, z), Vector3(0.12, 2.2, 0.35), "amber")
	for z in range(-9, 10, 3):
		var arch := _arc(8.8, 0.19, 0.0, PI, 36 * detail, 6)
		_add(arch, Vector3(0, 4.0, z), Vector3.ONE, Vector3(-PI * 0.5, 0, 0), "alloy")
		for x in [-4.5, 4.5]:
			_box(Vector3(x, 11.5, z), Vector3(0.14, 2.4, 0.14), "copper")
	# Roof strips and floor inlays lead the eye through the full depth of the hall.
	for x in [-2.8, 2.8]:
		_box(Vector3(x, 12.1, -1), Vector3(0.25, 0.15, 18), "amber")
		_box(Vector3(x, 0.012, 1), Vector3(0.12, 0.025, 19), "cyan")
	for z in range(-10, 11):
		_box(Vector3(0, 0.02, z), Vector3(18, 0.015, 0.025), "dark")
	for x in range(-9, 10):
		_box(Vector3(x, 0.02, 0), Vector3(0.025, 0.015, 22), "dark")
	for step in 12:
		_box(Vector3(0, 0.12 * step, 7.5 - step * 0.3), Vector3(4.7, 0.24, 0.34), "alloy")
	# Rear cooling organ: unequal heights make an architectural silhouette.
	for index in 19:
		var x := (index - 9) * 0.85
		var height := 5.5 + 5.0 * (1.0 - absf(x) / 8.0)
		_cylinder(Vector3(x, height * 0.5, -9.9), 0.23, height, "copper")
		_box(Vector3(x, 2.8, -9.55), Vector3(0.35, 2.1, 0.1), "amber")


func _reactor() -> void:
	_cylinder(Vector3(0, 1.2, -1), 3.1, 1.0, "dark", 64)
	_cylinder(Vector3(0, 1.85, -1), 2.6, 0.3, "alloy", 64)
	_cylinder(Vector3(0, 5.1, -1), 0.72, 6.8, "cyan", 48)
	for y in [2.1, 4.0, 6.0, 8.1]:
		_add(
			_arc(2.2, 0.24, 0, TAU, 64 * detail, 8),
			Vector3(0, y, -1),
			Vector3.ONE,
			Vector3.ZERO,
			"alloy"
		)
		_add(
			_arc(1.7, 0.07, 0, TAU, 64 * detail, 6),
			Vector3(0, y + 0.3, -1),
			Vector3.ONE,
			Vector3.ZERO,
			"amber"
		)
	for index in 12:
		var angle := index * TAU / 12
		var point := Vector3(cos(angle) * 2.2, 5.1, -1 + sin(angle) * 2.2)
		_box(point, Vector3(0.16, 6.0, 0.16), "copper")
		for y in [2.6, 7.6]:
			var panel := Vector3(cos(angle) * 2.4, y, -1 + sin(angle) * 2.4)
			_box(panel, Vector3(0.6, 0.65, 0.12), "dark", Vector3(0, -angle + PI * 0.5, 0))
	for y in [3.1, 5.2, 7.2]:
		_add(
			_arc(3.5, 0.14, -PI * 0.85, PI * 1.7, 60 * detail, 8),
			Vector3(0, y, -1),
			Vector3.ONE,
			Vector3(0.15, y * 0.7, 0.1),
			"copper"
		)
	# Four support legs and diagonal conduits give the core structural weight.
	for index in 4:
		var angle := PI * 0.25 + index * PI * 0.5
		var p := Vector3(cos(angle) * 3.8, 1.5, sin(angle) * 3.8 - 1)
		_cylinder(p, 0.5, 3.0, "dark")
		_add(
			_arc(1.6, 0.18, 0, PI * 0.5, 20 * detail, 8),
			p + Vector3(0, 1.5, 0),
			Vector3.ONE,
			Vector3(-PI * 0.5, angle, 0),
			"alloy"
		)


func _machinery() -> void:
	for side in [-1.0, 1.0]:
		for z in [-7.5, -3.5, 1.0, 5.2, 8.5]:
			var x: float = side * 5.8
			_box(Vector3(x, 0.2, z), Vector3(1.8, 0.4, 2.2), "alloy")
			_cylinder(Vector3(x, 1.65, z), 0.62, 2.5, "dark", 24 * detail)
			for y in [0.6, 1.3, 2.1, 2.8]:
				_add(
					_arc(0.65, 0.075, 0, TAU, 24 * detail, 6),
					Vector3(x, y, z),
					Vector3.ONE,
					Vector3.ZERO,
					"copper"
				)
			_box(Vector3(x - side * 0.62, 1.7, z), Vector3(0.08, 1.1, 0.6), "amber")
			for rib in 8 * detail:
				var angle := rib * TAU / (8 * detail)
				_box(
					Vector3(x + cos(angle) * 0.65, 1.7, z + sin(angle) * 0.65),
					Vector3(0.045, 2.0, 0.045),
					"alloy"
				)
		# Two long bent supply pipes along each gallery.
		for y in [4.7, 8.7]:
			_cylinder(Vector3(side * 8.5, y, 0), 0.13, 20, "copper", 12, Vector3(PI * 0.5, 0, 0))


func _box(p: Vector3, size: Vector3, material: String, rotation := Vector3.ZERO) -> void:
	var box := BoxMesh.new()
	box.size = size
	_add(box, p, Vector3.ONE, rotation, material)


func _cylinder(
	p: Vector3,
	radius: float,
	height: float,
	material: String,
	segments: int = 24,
	rotation := Vector3.ZERO
) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius
	cylinder.bottom_radius = radius
	cylinder.height = height
	cylinder.radial_segments = segments
	_add(cylinder, p, Vector3.ONE, rotation, material)


func _add(mesh: Mesh, p: Vector3, size: Vector3, rotation: Vector3, material: String) -> void:
	piece_count += 1
	var transform := Transform3D(Basis.from_euler(rotation).scaled(size), p)
	var normals := transform.basis.inverse().transposed()
	var source := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var vertex_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var offset: int = batches[material][0].size()
	for index in vertices.size():
		batches[material][0].append(transform * vertices[index])
		batches[material][1].append((normals * vertex_normals[index]).normalized())
	for index: int in source[Mesh.ARRAY_INDEX]:
		batches[material][2].append(index + offset)


func _arc(
	radius: float, thickness: float, start: float, sweep: float, segments: int, sides: int
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for ring in segments + 1:
		var angle := start + sweep * ring / segments
		for side in sides:
			var phi := TAU * side / sides
			var normal := Vector3(cos(angle) * cos(phi), sin(phi), sin(angle) * cos(phi))
			vertices.append(
				Vector3(cos(angle) * radius, 0, sin(angle) * radius) + normal * thickness
			)
			normals.append(normal)
	for ring in segments:
		for side in sides:
			var a := ring * sides + side
			var b := ring * sides + (side + 1) % sides
			indices.append_array([a, b, a + sides, b, b + sides, a + sides])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
