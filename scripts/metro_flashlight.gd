class_name MetroFlashlight
extends SpotLight3D
## Native shadowed direct light, not an RC emitter or a translucent cone mesh.

var haze := FogVolume.new()


func _ready() -> void:
	position = Vector3(0.28, -0.18, -0.18)
	spot_range = 17.0
	spot_angle = 16.0
	spot_angle_attenuation = 0.65
	spot_attenuation = 1.1
	light_color = Color(0.83, 0.9, 1.0)
	light_energy = 5.0
	light_volumetric_fog_energy = 5.0
	# Zero specular marks this non-RC light for the metro material's diffuse path.
	light_specular = 0.0
	shadow_enabled = true
	shadow_bias = 0.02
	shadow_normal_bias = 0.2
	haze.size = Vector3(10, 8, 18)
	haze.position.z = -8.0
	var material := FogMaterial.new()
	material.density = 0.009
	material.albedo = Color(0.8, 0.85, 0.9)
	material.edge_fade = 0.4
	haze.material = material
	add_child(haze)
	visible = false


func tick(seconds: float) -> void:
	var cell := int(floor(seconds * 13.0))
	var hashed := noise_at(cell)
	light_energy = 5.0 * (0.32 if hashed < 0.04 else 0.93 + hashed * 0.07)


static func noise_at(value: int) -> float:
	var mixed := (value ^ (value >> 16)) * 73244475 & 0x7fffffff
	mixed = (mixed ^ (mixed >> 16)) * 73244475 & 0x7fffffff
	return float(mixed ^ (mixed >> 16)) / 2147483647.0
