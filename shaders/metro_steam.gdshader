shader_type fog;
uniform sampler3D noise_tex : repeat_enable, filter_linear;
uniform float scene_time = 0.0;
void fog() {
	vec3 p = UVW;
	vec2 drift = vec2(sin(p.y * 4.0 + scene_time * 0.15), cos(p.y * 3.0 + scene_time * 0.12)) * p.y * 0.1;
	float radius = length(p.xz - vec2(0.5) - drift);
	float edge = 1.0 - smoothstep(0.12 + p.y * 0.15, 0.26 + p.y * 0.22, radius);
	float noise = texture(noise_tex, p * vec3(0.8, 0.6, 0.8) - vec3(0.0, scene_time * 0.025, 0.0)).r;
	// A persistent low-frequency body avoids threshold popping in the froxel grid.
	DENSITY = edge * (1.0 - smoothstep(0.35, 1.0, p.y)) * smoothstep(0.0, 0.1, p.y) * (0.35 + noise * 0.65) * 0.85;
	ALBEDO = vec3(0.65, 0.75, 0.79);
	EMISSION = vec3(0.055, 0.07, 0.075) * DENSITY;
}
