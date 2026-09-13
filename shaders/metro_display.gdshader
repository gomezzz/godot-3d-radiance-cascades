shader_type spatial;
uniform float station_power = 1.0;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D display_tex : source_color, filter_linear, repeat_disable;
uniform float scene_time = 0.0;
uniform float brightness = 0.85;
uniform bool dot_matrix = false;
uniform vec2 matrix_size = vec2(256.0, 32.0);
uniform sampler2D smudge_tex : filter_linear_mipmap_anisotropic, repeat_enable;
void fragment() {
    vec2 uv = UV;
    vec2 sample_uv = dot_matrix ? (floor(uv * matrix_size) + 0.5) / matrix_size : uv;
    float grime = texture(smudge_tex, uv * vec2(2.7, 1.8)).r;
    // Fade subpixel structure to prevent distant moire.
    float visible_pixels = 1.0 - smoothstep(0.2, 0.65, fwidth(uv.y) * 1080.0);
    float scan = 1.0 - visible_pixels * 0.035 * (0.5 + 0.5 * cos(uv.y * 6785.84));
    vec2 border = smoothstep(vec2(0.0), vec2(0.007), uv) * smoothstep(vec2(0.0), vec2(0.007), 1.0 - uv);
    float view_loss = mix(0.55, 1.0, pow(max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 0.3));
    ALBEDO = vec3(0.008, 0.012, 0.014);
    ROUGHNESS = 0.12 + grime * 0.16;
    SPECULAR = 0.65;
    float dots = 1.0;
    if (dot_matrix) {
        vec2 cell = fract(uv * matrix_size) - 0.5;
        float aa = max(length(fwidth(uv * matrix_size)), 0.03);
        float mask = 1.0 - smoothstep(0.30 - aa, 0.46 + aa, length(cell));
        dots = mix(mask, 0.68, smoothstep(0.5, 1.8, aa));
    }
    float noise = fract(sin(dot(floor(sample_uv * matrix_size), vec2(12.9898,78.233)) + floor(scene_time * 12.0)) * 43758.5453);
    EMISSION = texture(display_tex, sample_uv).rgb * brightness * station_power * scan * dots * border.x * border.y * view_loss * (1.0 - grime * 0.055) * (1.0 - noise * (dot_matrix ? 0.07 : 0.015));
}
