shader_type spatial;
render_mode unshaded;
uniform sampler2D irradiance_tex : filter_nearest, repeat_disable;
uniform vec3 volume_origin = vec3(-6.0, 0.0, -6.0);
uniform ivec3 volume_grid = ivec3(24, 16, 24);
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
    vec3 q = clamp((position - volume_origin) / 0.5 - 0.5,
                   vec3(0.0), vec3(volume_grid - ivec3(1)));
    ivec3 p = ivec3(floor(q));
    vec3 f = fract(q), result = vec3(0.0);
    for (int corner = 0; corner < 8; corner++) {
        ivec3 offset = ivec3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1);
        ivec3 cell = min(p + offset, volume_grid - ivec3(1));
        vec3 w = mix(vec3(1.0) - f, f, vec3(offset));
        vec3 value = vec3(0.0);
        for (int axis = 0; axis < 3; axis++) {
            int face = axis * 2 + int(normal[axis] < 0.0);
            ivec2 pixel = ivec2(cell.x + face * volume_grid.x, cell.y + cell.z * volume_grid.y);
            value += texelFetch(irradiance_tex, pixel, 0).rgb * normal[axis] * normal[axis];
        }
        result += value * w.x * w.y * w.z;
    }
    return result;
}
void fragment() {
    vec3 normal = normalize(world_normal);
    vec3 light = sample_lighting(world_position + normal * 0.3, normal);
    vec3 color = emission_color + surface_color.rgb * light * gi_strength;
    if (view_mode == 1) { color = light; }
    if (view_mode == 2) { color = surface_color.rgb; }
    ALBEDO = color;
}
