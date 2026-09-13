class_name MetroGeometry
extends RefCounted
## World-metre UVs and generated tangents preserve scanned material scale.

var palette: Dictionary[String, StandardMaterial3D] = {}
var batches: Dictionary[String, SurfaceTool] = {}
var piece_count := 0
var pillar_count := 0


func build() -> MeshInstance3D:
	_materials()
	for key in palette:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(palette[key])
		batches[key] = surface
	_architecture()
	_furniture()
	var mesh := ArrayMesh.new()
	for key in batches:
		batches[key].generate_tangents()
		batches[key].index()
		batches[key].commit(mesh)
	var instance := MeshInstance3D.new()
	instance.name = "StationArchitecture"
	instance.mesh = mesh
	return instance


func _materials() -> void:
	palette["floor"] = scanned("large_floor_tiles_02", 3.0, Color(0.72, 0.76, 0.77))
	palette["tile"] = scanned("long_white_tiles", 1.3, Color(0.82, 0.85, 0.8))
	palette["concrete"] = scanned("concrete_wall_006", 2.0, Color(0.65, 0.69, 0.7))
	palette["concrete"].roughness = 0.95
	palette["steel"] = scanned("metal_plate", 1.0, Color(0.5, 0.57, 0.6))
	palette["steel"].metallic = 0.8
	palette["steel"].roughness = 0.48
	palette["dark"] = scanned("rubber_tiles", 1.0, Color(0.12, 0.15, 0.16))
	palette["red"] = scanned("rusty_painted_metal", 1.5, Color(0.55, 0.14, 0.1))
	palette["yellow"] = plain(Color(0.85, 0.57, 0.08), 0.0, 0.62)
	palette["seat"] = scanned("metal_plate", 0.6, Color(0.16, 0.35, 0.32))
	palette["seat"].metallic = 0.4
	# Parallax is useful in grout/concrete; thin metal/rubber needs only normal detail.
	for key in ["steel", "dark", "red", "seat"]:
		palette[key].heightmap_enabled = false
		palette[key].normal_scale = 0.6


static func plain(color: Color, metal := 0.0, rough := 0.6) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metal
	material.roughness = rough
	return material


static func scanned(asset: String, metres: float, tint: Color) -> StandardMaterial3D:
	var material := plain(tint)
	var folder := "res://assets/textures/" + asset + "/"
	material.albedo_texture = load(folder + "Diffuse.jpg")
	material.normal_texture = load(folder + "nor_gl.jpg")
	material.roughness_texture = load(folder + "Rough.jpg")
	material.heightmap_texture = load(folder + "Displacement.jpg")
	material.heightmap_enabled = true
	material.heightmap_scale = 0.025
	assert(material.albedo_texture != null and material.normal_texture != null)
	assert(material.roughness_texture != null)
	material.roughness = 0.65
	material.normal_enabled = true
	material.normal_scale = 1.15
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.uv1_scale = Vector3.ONE / metres
	return material


func _architecture() -> void:
	box(Vector3(-5.5, -0.35, 0), Vector3(10, 0.7, 35), "floor")
	box(Vector3(8, -0.35, 0), Vector3(5, 0.7, 35), "floor")
	box(Vector3(2.5, -1.0, 0), Vector3(6, 0.35, 35), "concrete")
	box(Vector3(0, 5.05, 0), Vector3(21, 0.5, 35), "concrete")
	for x in [-10.4, 10.4]:
		box(Vector3(x, 2.25, 0), Vector3(0.35, 4.5, 35), "tile")
		box(Vector3(x * 0.98, 0.3, 0), Vector3(0.08, 0.6, 35), "dark")
		box(Vector3(x * 0.98, 2.7, 0), Vector3(0.08, 0.22, 35), "red")
	for z in range(-15, 16, 3):
		box(Vector3(0, 4.55, z), Vector3(21, 0.6, 0.42), "concrete")
		for x in [-2.7, 8.3]:
			pillar_count += 1
			box(Vector3(x, 2.15, z), Vector3(0.65, 4.3, 0.65), "tile")
			box(Vector3(x, 0.3, z), Vector3(0.75, 0.6, 0.75), "dark")
			box(Vector3(x, 3.65, z), Vector3(0.69, 0.35, 0.69), "red")
			box(Vector3(x, 4.25, z), Vector3(1.2, 0.3, 1.1), "concrete")
	# Tactile strips, sleepers, rails and fastening plates are actual geometry.
	for x in [-0.85, 5.85]:
		box(Vector3(x, 0.014, 0), Vector3(0.48, 0.028, 35), "yellow")
		for z in range(-34, 35):
			for dx in [-0.12, 0.0, 0.12]:
				box(Vector3(x + dx, 0.04, z * 0.5), Vector3(0.035, 0.045, 0.27), "yellow")
	for x in [1.7, 3.3]:
		box(Vector3(x, -0.53, 0), Vector3(0.075, 0.2, 35), "steel")
		box(Vector3(x, -0.42, 0), Vector3(0.14, 0.045, 35), "steel")
	for z in range(-24, 25):
		box(Vector3(2.5, -0.72, z * 0.7), Vector3(3.4, 0.16, 0.22), "dark")
		for x in [1.7, 3.3]:
			box(Vector3(x, -0.61, z * 0.7), Vector3(0.35, 0.06, 0.3), "steel")
	for x in [-9.5, -9.2, 9.7]:
		box(Vector3(x, 4.2, 0), Vector3(0.09, 0.09, 35), "steel")
	for x in [-5.5, 7.0]:
		for z in range(-14, 15, 5):
			box(Vector3(x, 4.25, z), Vector3(0.6, 0.14, 2.6), "steel")
			for side in [-0.26, 0.26]:
				box(Vector3(x + side, 4.13, z), Vector3(0.045, 0.16, 2.58), "steel")
			for rib in 9:
				box(Vector3(x, 4.085, z - 1.1 + rib * 0.275), Vector3(0.5, 0.025, 0.025), "steel")
			for dz in [-0.9, 0.9]:
				box(Vector3(x, 4.6, z + dz), Vector3(0.04, 0.7, 0.04), "steel")
	# Dark portal surrounds leave the rail corridor open at both ends.
	for z in [-17.3, 17.3]:
		box(Vector3(-5.5, 2.3, z), Vector3(10, 4.6, 0.45), "concrete")
		box(Vector3(8.4, 2.3, z), Vector3(4.4, 4.6, 0.45), "concrete")
		box(Vector3(2.5, 4.35, z), Vector3(6, 1.3, 0.45), "dark")
	# Real tunnel shells and maintenance walkways carry the escape signage.
	for direction in [-1.0, 1.0]:
		var z: float = direction * 28.0
		for x in [-0.45, 5.45]:
			box(Vector3(x, 1.65, z), Vector3(0.3, 5.5, 22), "concrete")
		box(Vector3(2.5, 4.35, z), Vector3(6.2, 0.3, 22), "concrete")
		box(Vector3(2.5, -1.0, z), Vector3(6.2, 0.3, 22), "concrete")
		box(Vector3(-0.02, -0.3, z), Vector3(0.6, 0.3, 22), "concrete")
		for x in [1.7, 3.3]:
			box(Vector3(x, -0.42, z), Vector3(0.14, 0.08, 22), "steel")


func _furniture() -> void:
	for z in [-11, -2, 7]:
		for x in [-7.0, 8.6]:
			for seat in 4:
				var p := Vector3(x, 0.5, z + seat * 0.56)
				box(p, Vector3(0.55, 0.09, 0.5), "seat")
				box(p + Vector3(-0.26, 0.25, 0), Vector3(0.08, 0.55, 0.5), "seat")
				box(p + Vector3(0, -0.25, 0), Vector3(0.06, 0.5, 0.06), "steel")
			box(Vector3(x, 0.25, z + 0.84), Vector3(0.1, 0.1, 2.5), "steel")
	# Service cabinets, bins, poster frames and wall-mounted route boards.
	for z in [-8, 9]:
		box(Vector3(-9.3, 0.55, z), Vector3(0.6, 1.1, 0.7), "steel")
		box(Vector3(-8.98, 0.87, z), Vector3(0.03, 0.15, 0.46), "dark")
	box(Vector3(-9.7, 1.2, -15.8), Vector3(0.8, 2.4, 1.2), "red")
	box(Vector3(-9.26, 1.55, -15.8), Vector3(0.04, 0.55, 0.65), "dark")


func box(p: Vector3, size: Vector3, material: String) -> void:
	piece_count += 1
	var mesh := BoxMesh.new()
	mesh.size = size
	var source := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var surface := batches[material]
	for index: int in source[Mesh.ARRAY_INDEX]:
		var vertex := vertices[index] + p
		var normal := normals[index]
		var uv: Vector2
		if absf(normal.x) > 0.5:
			uv = Vector2(-vertex.z * signf(normal.x), -vertex.y)
		elif absf(normal.y) > 0.5:
			uv = Vector2(vertex.x, vertex.z * signf(normal.y))
		else:
			uv = Vector2(vertex.x * signf(normal.z), -vertex.y)
		surface.set_normal(normal)
		surface.set_uv(uv)
		surface.add_vertex(vertex)
