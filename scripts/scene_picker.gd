extends Control
## A compact keyboard-accessible launcher; no demo loads before selection.

const SCENES := [
	["Northline", "Abandoned metro / walk, jump, flashlight", "metro_station"],
	["Cornell box", "Red and green colour bleed / diffuse bounce", "cornell_box"],
	["Occlusion study", "Point-light shadows / textured walls / RC indirect", "occlusion_study"],
	["Helios", "Complex triangle-mesh reactor hall", "reactor_hall"],
	["Light laboratory", "Interactive probes and transport controls", "laboratory"],
]
static var reduced_flashes := false
var buttons: Array[Button] = []


func _ready() -> void:
	get_window().content_scale_size = Vector2i(1280, 720)
	var background := ColorRect.new()
	background.color = Color("192b3b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 180)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 55)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "Radiance Cascades"
	heading.add_theme_font_size_override("font_size", 40)
	heading.add_theme_color_override("font_color", Color("edf3f7"))
	column.add_child(heading)
	var intro := Label.new()
	intro.text = "Choose a scene. Explore how light travels."
	intro.add_theme_font_size_override("font_size", 19)
	column.add_child(intro)
	for entry in SCENES:
		var button := Button.new()
		button.text = entry[0] + "   /   " + entry[1]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 68
		button.add_theme_font_size_override("font_size", 19)
		var panel := StyleBoxFlat.new()
		panel.bg_color = Color("2c4659")
		panel.content_margin_left = 22
		button.add_theme_stylebox_override("normal", panel)
		var active := panel.duplicate() as StyleBoxFlat
		active.bg_color = Color("46697e")
		active.set_border_width_all(2)
		active.border_color = Color("9bcad9")
		button.add_theme_stylebox_override("focus", active)
		button.add_theme_stylebox_override("hover", active)
		button.pressed.connect(_launch.bind(entry[2]))
		column.add_child(button)
		buttons.append(button)
	var flashes := CheckButton.new()
	flashes.text = "Reduce flashes (Northline contains intense flashing lightning)"
	flashes.button_pressed = reduced_flashes
	flashes.toggled.connect(func(on: bool) -> void: reduced_flashes = on)
	column.add_child(flashes)
	buttons[0].grab_focus()


func _launch(scene_name: String) -> void:
	# A button signal must finish before its scene is removed.
	_open_scene.call_deferred(scene_name)


func _open_scene(scene_name: String) -> void:
	var error := get_tree().change_scene_to_file("res://scenes/" + scene_name + ".tscn")
	assert(error == OK, "Could not load selected scene")
