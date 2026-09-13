class_name RCPBRMaterial
extends RefCounted
## Preserve supported BaseMaterial3D channels when installing the RC surface shader.

const SHADER := preload("res://addons/radiance_cascades/shaders/pbr_surface.gdshader")


static func configure(target: ShaderMaterial, source: Material) -> void:
	target.shader = SHADER
	if source == null:
		return
	assert(source is BaseMaterial3D, "PBR RC requires a BaseMaterial3D source")
	var base := source as BaseMaterial3D
	# Enclosed train interiors are finer than the exterior transport proxy.
	target.set_shader_parameter("local_diffuse", base.has_meta("rc_local_diffuse"))
	target.set_shader_parameter("roughness_factor", base.roughness)
	target.set_shader_parameter("metallic_factor", base.metallic)
	target.set_shader_parameter("normal_strength", base.normal_scale)
	target.set_shader_parameter(
		"use_height", base.heightmap_enabled and base.heightmap_texture != null
	)
	if base.heightmap_enabled and base.heightmap_texture != null:
		target.set_shader_parameter("height_map", base.heightmap_texture)
		target.set_shader_parameter("height_scale", base.heightmap_scale)
	target.set_shader_parameter("uv_scale", Vector2(base.uv1_scale.x, base.uv1_scale.y))
	target.set_shader_parameter("uv_offset", Vector2(base.uv1_offset.x, base.uv1_offset.y))
	for channel in ["albedo", "roughness", "metallic", "normal"]:
		var map: Texture2D = base.get(channel + "_texture")
		var enabled: bool = map != null and (channel != "normal" or base.normal_enabled)
		target.set_shader_parameter("use_" + channel, enabled)
		if enabled:
			target.set_shader_parameter(channel + "_map", map)
	target.set_shader_parameter("roughness_channel", _channel(base.roughness_texture_channel))
	target.set_shader_parameter("metallic_channel", _channel(base.metallic_texture_channel))


static func _channel(channel: int) -> Vector4:
	assert(channel >= 0 and channel <= 4, "Unsupported material texture channel")
	if channel == 4:
		return Vector4(0.333333, 0.333333, 0.333333, 0)
	var mask := Vector4.ZERO
	mask[channel] = 1.0
	return mask
