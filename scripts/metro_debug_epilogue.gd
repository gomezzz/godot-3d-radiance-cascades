class_name MetroDebugEpilogue
extends CanvasLayer
## Three locked-off views with actual merged cascade buffers, not illustrative art.

const EYES := [Vector3(-7.5, 3.5, 15.5), Vector3(-7.5, 3.2, -16), Vector3(-8.8, .35, 14.7)]
const TARGETS := [Vector3(-2, 2.7, -5), Vector3(-3.6, 1.1, 6), Vector3(-3.2, 1, -4)]
const INSPECT := [Vector3(-5, 2, 8), Vector3(-5, 2, -8), Vector3(-5, .8, 4)]
const TITLES := ["Shaded station", "Resolved diffuse irradiance", "Surface albedo input"]
const SHOT_DURATIONS := [15.0, 8.0, 8.0]
const SHOT_STARTS := [0.0, 15.0, 23.0]
const SHOTS_LENGTH := 31.0
const THANKS_LENGTH := 8.0
const TOTAL_LENGTH := SHOTS_LENGTH + THANKS_LENGTH
const REPO_URL := "https://github.com/gomezzz/godot-3d-radiance-cascades"
const STEPS := [
	"1. Sample space: the amber marker selects nearby probes in all five grids.",
	"2. Trace directions: C0 has dense probes; farther levels trade space for more directions.",
	"3. Merge far to near: farther radiance passes where near transmission is open.",
	"4. Resolve light: the GPU integrates directions into diffuse irradiance used by surfaces."
]
const LEVEL_COLORS := [
	Color("79c2ed"), Color("98cbd8"), Color("c6d4c1"), Color("edbf78"), Color("aa9edf")
]
var stage := -1
var heading: Label
var explanation: Label
var labels: Array[Label] = []
var marker := MeshInstance3D.new()
var steps: Array[Label] = []
var thanks: ColorRect
var repo_link: Label


func build(station: Node3D) -> void:
	layer = 24
	var backdrop := ColorRect.new()
	backdrop.position = Vector2(1820, 0)
	backdrop.size = Vector2(740, 1440)
	backdrop.color = Color("142432")
	add_child(backdrop)
	_text("Merged radiance     /     Transmittance", Vector2(1852, 28), 26)
	_text("Same inspection point, nearest probe in each level", Vector2(1852, 68), 20)
	for level in RCGPU.LEVELS:
		labels.append(_text("", Vector2(1852, 116 + level * 238), 22))
		labels[level].add_theme_color_override("font_color", LEVEL_COLORS[level])
		for mode in 2:
			var map := TextureRect.new()
			var atlas := AtlasTexture.new()
			atlas.atlas = station.cascades.debug_texture
			atlas.region = Rect2(0, level * 128, 256, 128)
			map.texture = atlas
			map.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			map.position = Vector2(1852 + mode * 340, 190 + level * 238)
			map.size = Vector2(320, 160)
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/cascade_debug.gdshader")
			material.set_shader_parameter("transmittance", mode == 1)
			map.material = material
			add_child(map)
	_text(
		(
			"X: azimuth  /  Y: cos(polar angle)\nRadiance: x4 exposure + tone map\n"
			+ "Transmission: black = blocked, white = open"
		),
		Vector2(1852, 1330),
		20
	)
	var footer := ColorRect.new()
	footer.position = Vector2(0, 1170)
	footer.size = Vector2(1820, 270)
	footer.color = Color(0.078, 0.141, 0.196, .94)
	add_child(footer)
	heading = _text("", Vector2(48, 1198), 36)
	for index in STEPS.size():
		var step := _text(STEPS[index], Vector2(48, 1250 + index * 34), 23)
		step.modulate.a = 0
		steps.append(step)
	explanation = _text("", Vector2(48, 1400), 18)
	_build_thanks()
	var mesh := SphereMesh.new()
	mesh.radius = .09
	mesh.height = .18
	marker.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("edbf78")
	marker.material_override = material
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	station.add_child(marker)
	station.walker.stop()
	station.cinematic = false
	station.cutscene = false
	station.cascades.paused = false
	station.cascades.debug_enabled = true
	# Reuse the registered analytic sphere: no BVH rebuild or native direct light.
	station.lightning.proxy.visible = true
	station.lightning.proxy.scale = Vector3.ONE * .8
	station.lightning.light.light_energy = 0.0
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func tick(age: float, station: Node3D) -> void:
	station.cascades.paused = not station.motion
	station.soundscape.tick(station.time, station.motion, station.audio_muted)
	if age >= SHOTS_LENGTH:
		thanks.visible = true
		thanks.modulate.a = smoothstep(0.0, 0.8, age - SHOTS_LENGTH)
		marker.visible = false
		station.lightning.proxy.visible = false
		station.lightning.proxy.radiance = Color.BLACK
		station.cascades.paused = true
		return
	var phase := age * TAU / 12.0
	station.lightning.proxy.position = Vector3(
		-5.0 + sin(phase) * .7, 1.9 + sin(phase * 2) * .4, cos(phase) * 12.0
	)
	station.lightning.proxy.radiance = Color(.15, .55, 1.0) * 28.0
	for index in steps.size():
		steps[index].modulate.a = smoothstep(index * 2.5, index * 2.5 + .8, age)
	var next := 0 if age < SHOT_STARTS[1] else (1 if age < SHOT_STARTS[2] else 2)
	if next != stage:
		stage = next
		station.camera.position = EYES[stage]
		station.camera.look_at(TARGETS[stage])
		station.camera.fov = 88
		station.cascades.set_view(stage, 1.0)
		station.cascades.debug_position = INSPECT[stage]
		marker.position = INSPECT[stage]
		for level in RCGPU.LEVELS:
			var spacing: float = station.cascades.probe_spacing * (1 << level)
			var interval: Vector2 = RCGPU.interval_at(level) * station.cascades.probe_spacing / .5
			labels[level].text = (
				"C%d   %s probes   /   %d directions\n%.1f m spacing   /   traced interval %.1f-%.1f m"
				% [
					level,
					RCGPU.grid_at(level),
					32 * (1 << (2 * level)),
					spacing,
					interval.x,
					interval.y
				]
			)
	heading.text = "%d / 3   %s" % [stage + 1, TITLES[stage]]
	explanation.text = (
		"Blue ball: live RC emitter. Amber marker: fixed probe sample. "
		+ (
			"%d GPU updates / %d triangles.  P: pause  M: mute  O: post FX"
			% [station.cascades.frame_count, station.cascades.mesh_bvh.triangle_count]
		)
	)
	station.atmosphere.update_views(station.camera, station.time)


func _build_thanks() -> void:
	thanks = ColorRect.new()
	thanks.size = Vector2(2560, 1440)
	thanks.color = Color("101920")
	thanks.visible = false
	add_child(thanks)
	_credit("Thank you for visiting Northline", 310, 54)
	_credit(
		(
			"This project uses independently created assets, tools and research.\n"
			+ "Credits acknowledge reuse, not collaboration or endorsement."
		),
		410,
		28
	)
	_credit("Textures used / Poly Haven", 515, 28)
	_credit(
		(
			"Rob Tuytel  /  Sergej Majboroda  /  Jenelle van Heerden\n"
			+ "Charlotte Baglioni  /  Dario Barresi  /  Amal Kumar"
		),
		563,
		26
	)
	_credit("Recordings used / Freesound", 675, 28)
	_credit(
		"craigsmith  /  videog  /  FOSSarts  /  SamsterBirdies  /  kev_durr  /  InspectorJ", 725, 26
	)
	_credit(
		(
			"Research: Alexander Sannikov   /   Engine: Godot contributors\n"
			+ "Announcements: VoiceForge + Qwen3-TTS   /   Footsteps: InspectorJ, CC BY 4.0 (edited)"
		),
		820,
		24
	)
	repo_link = Label.new()
	repo_link.text = REPO_URL.trim_prefix("https://")
	repo_link.position = Vector2(480, 970)
	repo_link.size = Vector2(1600, 60)
	repo_link.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	repo_link.add_theme_font_size_override("font_size", 44)
	repo_link.add_theme_color_override("font_color", Color("79c2ed"))
	thanks.add_child(repo_link)
	_credit("Source, full asset credits and licence details on GitHub.", 1070, 22)


func _credit(value: String, y: float, size: int) -> void:
	var label := Label.new()
	label.text = value
	label.position = Vector2(240, y)
	label.size.x = 2080
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("eaf0f4"))
	thanks.add_child(label)


func _text(value: String, position: Vector2, size: int) -> Label:
	var label := Label.new()
	label.text = value
	label.position = position
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("eaf0f4"))
	add_child(label)
	return label
