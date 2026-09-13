class_name MetroPostFX
extends CanvasLayer
## Rotational camera reprojection only: no object velocities or temporal history.

var effect := ColorRect.new()
var material := ShaderMaterial.new()
var previous_basis := Basis.IDENTITY
var previous_position := Vector3.ZERO
var initialized := false


func _ready() -> void:
	# Below all HUD/debug/fade layers, after the rendered 3D scene.
	layer = 0
	add_child(effect)
	effect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	material.shader = preload("res://shaders/metro_postfx.gdshader")
	effect.material = material


func tick(camera: Camera3D, delta: float, enabled: bool, moving: bool, debug: bool) -> void:
	var basis := camera.global_basis.orthonormalized()
	var angle := previous_basis.get_rotation_quaternion().angle_to(basis.get_rotation_quaternion())
	var cut := (
		not initialized
		or delta <= 0.0
		or delta > .1
		or angle > .25
		or camera.global_position.distance_to(previous_position) > 2.0
	)
	var projection := camera.get_camera_projection()
	var rotation := Transform3D(previous_basis.inverse() * basis, Vector3.ZERO)
	var reprojection := projection * Projection(rotation) * projection.inverse()
	material.set_shader_parameter("reprojection", reprojection)
	material.set_shader_parameter("shutter", 0.0 if cut or not moving or debug else .35)
	effect.visible = enabled and not debug
	previous_basis = basis
	previous_position = camera.global_position
	initialized = true
