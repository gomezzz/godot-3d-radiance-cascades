class_name MetroEscape
extends Node2D
## Physical backlit exit pictogram, not an animated advertising surface.


func _draw() -> void:
	var white := Color("e9f9ec")
	draw_rect(Rect2(0, 0, 1024, 320), Color("087746"))
	draw_rect(Rect2(15, 15, 994, 290), white, false, 7)
	# Doorway and running-person silhouette remain readable without language.
	draw_rect(Rect2(64, 68, 115, 190), white, false, 12)
	draw_circle(Vector2(239, 77), 20, white)
	draw_polyline(
		PackedVector2Array(
			[Vector2(219, 110), Vector2(194, 171), Vector2(261, 194), Vector2(284, 260)]
		),
		white,
		19,
		true
	)
	draw_polyline(
		PackedVector2Array([Vector2(203, 158), Vector2(158, 223), Vector2(113, 223)]),
		white,
		19,
		true
	)
	draw_polyline(
		PackedVector2Array([Vector2(268, 151), Vector2(229, 114), Vector2(180, 130)]),
		white,
		16,
		true
	)
	draw_line(Vector2(332, 160), Vector2(435, 160), white, 15)
	draw_polyline(
		PackedVector2Array([Vector2(399, 119), Vector2(442, 160), Vector2(399, 201)]),
		white,
		15,
		true
	)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Arial"])
	draw_string(font, Vector2(490, 177), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 96, white)
	draw_string(
		font, Vector2(495, 232), "Emergency escape", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, white
	)
