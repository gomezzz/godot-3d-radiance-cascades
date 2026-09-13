shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform float phase = 0.0;
uniform float energy = 1.0;
varying vec3 plasma_position;
void vertex() {
    vec3 direction = normalize(VERTEX);
    float swell = 1.0 + 0.06 * sin(phase * 3.1) + 0.035 * sin(phase * 6.7);
    float lobes = sin(direction.x * 5.0 + phase * 2.3)
        * sin(direction.y * 4.0 - phase * 1.7)
        * cos(direction.z * 5.0 + phase * 2.0);
    VERTEX *= swell + lobes * 0.12;
    VERTEX += vec3(sin(direction.y * 7.0 + phase),
        sin(direction.z * 6.0 - phase * 1.3),
        cos(direction.x * 7.0 + phase * 1.5)) * 0.018;
    plasma_position = VERTEX;
}
void fragment() {
    vec3 warped_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
    float rim = pow(1.0 - abs(dot(warped_normal, normalize(VIEW))), 2.4);
    vec3 p = plasma_position * 65.0;
    float veins = pow(0.5 + 0.5 * sin(p.x + sin(p.y * 1.3 - phase * 3.0)
        * 3.0 + cos(p.z * 1.2 + phase * 2.0) * 3.0), 5.0);
    vec3 ink = mix(vec3(0.14, 0.025, 1.0), vec3(0.3, 0.85, 1.0), rim);
    ALBEDO = ink * (rim * 2.5 + veins * 3.0 + 0.12) * energy;
    ALPHA = clamp(rim + veins + 0.08, 0.0, 1.0);
}
