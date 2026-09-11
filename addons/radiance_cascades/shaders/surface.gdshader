shader_type spatial;
render_mode unshaded;
uniform sampler2D irradiance_tex : filter_linear, repeat_disable;
uniform vec3 volume_origin = vec3(-6.0, 0.0, -6.0);
uniform ivec3 volume_grid = ivec3(24, 16, 24);
uniform float probe_spacing = 0.5;
uniform vec4 surface_color : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec3 emission_color = vec3(0.0);
uniform float gi_strength = 1.0;
uniform int view_mode = 0;
varying vec3 world_position;
varying vec3 world_normal;
void vertex() {
    world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    world_normal = MODEL_NORMAL_MATRIX * NORMAL;
}
vec3 sample_lighting(vec3 position, vec3 normal) {
    vec3 q = clamp((position - volume_origin) / probe_spacing - 0.5,
                   vec3(0.0), vec3(volume_grid - ivec3(1)));
    vec3 result = vec3(0.0);
    float z0 = floor(q.z), z1 = min(z0 + 1.0, float(volume_grid.z - 1));
    vec2 size = vec2(float(volume_grid.x * 6), float(volume_grid.y * volume_grid.z));
    for (int axis = 0; axis < 3; axis++) {
        int face = axis * 2 + int(normal[axis] < 0.0);
        float x = q.x + float(face * volume_grid.x) + 0.5;
        vec3 a = textureLod(irradiance_tex,
            vec2(x, q.y + z0 * float(volume_grid.y) + 0.5) / size, 0.0).rgb;
        vec3 b = textureLod(irradiance_tex,
            vec2(x, q.y + z1 * float(volume_grid.y) + 0.5) / size, 0.0).rgb;
        result += mix(a, b, fract(q.z)) * normal[axis] * normal[axis];
    }
    return result;
}
void fragment() {
    vec3 normal = normalize(world_normal);
    vec3 light = sample_lighting(world_position + normal * probe_spacing * 0.6, normal);
    vec3 color = emission_color + surface_color.rgb * light * gi_strength;
    if (view_mode == 1) { color = light; }
    if (view_mode == 2) { color = surface_color.rgb; }
    ALBEDO = color;
}
