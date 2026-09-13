shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never;
uniform sampler2D scene_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float phase = 0.0;
uniform float strength = 1.0;
void fragment() {
    float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
    float envelope = smoothstep(.08, .65, facing);
    vec2 flow = vec2(sin(UV.y * 47.0 - phase * 5.0 + sin(UV.x * 31.0)),
        cos(UV.x * 39.0 + phase * 3.0 + cos(UV.y * 27.0)));
    vec2 displacement = flow * .0035 * envelope * strength;
    ALBEDO = texture(scene_tex, clamp(SCREEN_UV + displacement, vec2(.001), vec2(.999))).rgb;
    ALPHA = envelope * .4 * strength;
}
