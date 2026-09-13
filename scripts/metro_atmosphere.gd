class_name MetroAtmosphere
extends Node3D
## Two shared planar views: floor water and coplanar wall mirrors, without recursion.

const REFLECTION := preload("res://shaders/metro_reflection.gdshader")
const DISPLAY := preload("res://shaders/metro_display.gdshader")
const SMUDGE := preload("res://assets/textures/blue_metal_plate/Rough.jpg")
var cameras: Array[Camera3D] = []
var reflection_materials: Array[Array] = [[], []]
var displays: Array[ShaderMaterial] = []
var puddles: Array[MeshInstance3D] = []
var mirrors: Array[MeshInstance3D] = []
var adverts: Array[MetroAdvert] = []
var ad_panels: Array[MeshInstance3D] = []
var escape_panels: Array[MeshInstance3D] = []
var tickers: Array[Label] = []


func build() -> void:
	for index in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(768, 432) if index == 0 else Vector2i(2560, 1440)
		viewport.world_3d = get_world_3d()
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.use_hdr_2d = true
		add_child(viewport)
		var camera := Camera3D.new()
		camera.cull_mask = 1
		camera.far = 100
		viewport.add_child(camera)
		camera.make_current()
		cameras.append(camera)
	for index in 7:
		var p := Vector3(-5.0 + sin(index * 2.4) * 1.6, 0.035, 12.7 - index * 3.8)
		var puddle := _reflector(p, Vector2(3.3, 2.8), true)
		puddle.rotation.x = -PI * 0.5
		puddles.append(puddle)
	for z in [-14.5, 0.0, 14.5]:
		var mirror := _reflector(Vector3(-9.64, 2.0, z), Vector2(2.0, 1.7), false)
		mirror.rotation.y = PI * 0.5
		mirrors.append(mirror)
		for dy in [-0.9, 0.9]:
			_box(Vector3(-9.7, 2.0 + dy, z), Vector3(0.12, 0.08, 2.16))
		for dz in [-1.04, 1.04]:
			_box(Vector3(-9.7, 2.0, z + dz), Vector3(0.12, 1.8, 0.08))


func update_views(source: Camera3D, seconds: float) -> void:
	for ticker in tickers:
		ticker.position.x = 512.0 - fposmod(seconds * 34.0, 1450.0)
		ticker.get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
	for advert in adverts:
		if advert.advance(seconds):
			advert.get_viewport().render_target_update_mode = SubViewport.UPDATE_ONCE
	for index in cameras.size():
		var normal := Vector3.UP if index == 0 else Vector3.RIGHT
		var plane_point := Vector3(0, 0.035, 0) if index == 0 else Vector3(-9.64, 0, 0)
		var camera := cameras[index]
		camera.global_position = (
			source.global_position - 2.0 * normal * normal.dot(source.global_position - plane_point)
		)
		var forward := -source.global_basis.z
		var up := source.global_basis.y
		forward -= 2.0 * normal * normal.dot(forward)
		up -= 2.0 * normal * normal.dot(up)
		camera.look_at(camera.global_position + forward, up)
		camera.fov = source.fov
		camera.near = source.near
		var projection := (
			camera.get_camera_projection() * Projection(camera.global_transform.affine_inverse())
		)
		for material: ShaderMaterial in reflection_materials[index]:
			material.set_shader_parameter("reflection_projection", projection)
			material.set_shader_parameter("scene_time", seconds)
	for material in displays:
		material.set_shader_parameter("scene_time", seconds)


func screen(text: String, p: Vector3, angle: float, wide: bool) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 64 if wide else 320)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var background := ColorRect.new()
	background.color = Color("070d12")
	background.size = viewport.size
	viewport.add_child(background)
	var label := Label.new()
	label.text = text
	label.position = Vector2(12, 4 if wide else 20)
	label.size = Vector2(viewport.size) - label.position * 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 30 if wide else 25)
	label.add_theme_font_override("font", _font())
	label.modulate = Color("e5aa55")
	label.size.y -= 16 if wide else 40
	viewport.add_child(label)
	var ticker := Label.new()
	ticker.text = "NO SERVICE   /   KINDLY VACATE THE STATION   /   NO SERVICE"
	ticker.position.y = 47 if wide else 284
	ticker.add_theme_font_size_override("font_size", 14 if wide else 20)
	ticker.add_theme_font_override("font", _font())
	ticker.modulate = Color("c58d46")
	viewport.add_child(ticker)
	tickers.append(ticker)
	var material := ShaderMaterial.new()
	material.shader = DISPLAY
	material.set_shader_parameter("dot_matrix", true)
	material.set_shader_parameter("matrix_size", Vector2(256, 32 if wide else 160))
	material.set_shader_parameter("display_tex", viewport.get_texture())
	material.set_shader_parameter("smudge_tex", SMUDGE)
	displays.append(material)
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(2.6, 0.29) if wide else Vector2(1.4, 0.9)
	panel.mesh = quad
	panel.material_override = material
	panel.position = p
	panel.rotation.y = angle
	add_child(panel)
	_housing(panel, quad.size)


func build_adverts() -> void:
	for campaign in 2:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1920, 1080)
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		add_child(viewport)
		var advert := MetroAdvert.new()
		advert.campaign = campaign
		viewport.add_child(advert)
		adverts.append(advert)
		for side in [-1.0, 1.0]:
			var panel := _panel(viewport.get_texture(), Vector2(4.6, 2.59))
			panel.position = Vector3(side * 10.08, 2.1, -7.5 + campaign * 15.0)
			panel.rotation.y = -side * PI * 0.5
			ad_panels.append(panel)


func build_escape_signs() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1024, 320)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var artwork := MetroEscape.new()
	viewport.add_child(artwork)
	for side in [-1.0, 1.0]:
		for z in [-14.2, 14.2]:
			var panel := _panel(viewport.get_texture(), Vector2(1.35, 0.42))
			panel.position = Vector3(side * 10.08, 3.3, z)
			panel.rotation.y = -side * PI * 0.5
			escape_panels.append(panel)
	for z in [-35, -27, -20, 20, 27, 35]:
		var panel := _panel(viewport.get_texture(), Vector2(1.1, 0.344))
		panel.position = Vector3(-0.27, 1.8, z)
		panel.rotation.y = PI * 0.5
		escape_panels.append(panel)


func _panel(texture: Texture2D, size: Vector2) -> MeshInstance3D:
	var panel := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	panel.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = DISPLAY
	material.set_shader_parameter("display_tex", texture)
	material.set_shader_parameter("smudge_tex", SMUDGE)
	material.set_shader_parameter("brightness", 0.65)
	panel.material_override = material
	add_child(panel)
	_housing(panel, size)
	return panel


func _housing(panel: MeshInstance3D, size: Vector2) -> void:
	var housing := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(size.x + 0.1, size.y + 0.1, 0.1)
	housing.mesh = box
	housing.position.z = -0.065
	var metal := MetroGeometry.scanned("metal_plate", 1.0, Color(0.12, 0.14, 0.16))
	metal.metallic = 0.7
	metal.heightmap_enabled = false
	housing.material_override = metal
	panel.add_child(housing)
	for side in [-1.0, 1.0]:
		var mount := MeshInstance3D.new()
		var shape := BoxMesh.new()
		shape.size = Vector3(0.04, size.y * 0.5, 0.1)
		mount.mesh = shape
		mount.material_override = metal
		mount.position = Vector3(side * size.x * 0.35, 0, -0.13)
		panel.add_child(mount)


func _font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "Courier New"])
	return font


func _reflector(p: Vector3, size: Vector2, water: bool) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = size
	mesh.mesh = quad
	mesh.layers = 2
	mesh.position = p
	var material := ShaderMaterial.new()
	material.shader = REFLECTION
	material.set_shader_parameter("water", water)
	var index := 0 if water else 1
	material.set_shader_parameter("reflection_tex", cameras[index].get_viewport().get_texture())
	reflection_materials[index].append(material)
	mesh.material_override = material
	add_child(mesh)
	return mesh


func _box(p: Vector3, size: Vector3) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = p
	mesh.material_override = MetroGeometry.plain(Color(0.07, 0.085, 0.08), 0.6, 0.35)
	add_child(mesh)
