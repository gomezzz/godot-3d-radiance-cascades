shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D reflection_tex : filter_linear, repeat_disable;
uniform mat4 reflection_projection;
uniform bool water = false;
uniform float scene_time = 0.0;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float grime = sin(UV.x * 197.0) * sin(UV.y * 233.0);
    if (water) {
        float edge = length(p) + 0.09 * sin(p.x * 13.0 + sin(p.y * 9.0)) + 0.05 * cos(p.y * 21.0);
        if (edge > 0.92) { discard; }
    }
    vec4 clip = reflection_projection * vec4(world_position, 1.0);
    vec2 uv = clip.xy / clip.w * 0.5 + 0.5;
    uv.y = 1.0 - uv.y;
    if (water) { uv += vec2(sin(world_position.z * 16.0 + scene_time), cos(world_position.x * 19.0 - scene_time)) * 0.0009; }
    vec3 reflected = texture(reflection_tex, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
    float edge_stain = smoothstep(0.68, 1.0, max(abs(p.x), abs(p.y)));
    float grazing = pow(1.0 - max(dot(normalize(NORMAL), VIEW), 0.0), 5.0);
    float reflectance = water ? mix(0.08, 0.8, grazing) : 0.78;
    ALBEDO = reflected * reflectance * (1.0 - edge_stain * 0.25);
}
