shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform mat4 reprojection;
uniform float shutter = 0.0;
uniform float vignette_strength : hint_range(0.0, 0.5) = 0.16;

void fragment() {
    // Reproject the current camera ray into the previous camera orientation.
    // This intentionally excludes translation, moving-object blur and history trails.
    vec4 previous = reprojection * vec4(SCREEN_UV * 2.0 - 1.0, 1.0, 1.0);
    vec2 velocity = vec2(0.0);
    if (previous.w > 0.0001) {
        velocity = ((previous.xy / previous.w) * 0.5 + 0.5 - SCREEN_UV) * shutter;
    }
    vec2 pixels = velocity / SCREEN_PIXEL_SIZE;
    velocity *= min(1.0, 10.0 / max(length(pixels), 0.0001));
    vec3 color = vec3(0.0);
    for (int i = 0; i < 7; i++) {
        vec2 uv = clamp(SCREEN_UV + velocity * (float(i) / 6.0 - 0.5),
                        SCREEN_PIXEL_SIZE * 0.5, vec2(1.0) - SCREEN_PIXEL_SIZE * 0.5);
        color += texture(screen_tex, uv).rgb / 7.0;
    }
    vec2 edge = (SCREEN_UV - 0.5) * 2.0;
    float vignette = smoothstep(0.35, 1.35, length(edge));
    COLOR = vec4(color * (1.0 - vignette * vignette_strength), 1.0);
}
