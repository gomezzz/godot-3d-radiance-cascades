shader_type spatial;
render_mode unshaded;
uniform float phase = 0.0;
uniform float power = 35.0;
void vertex() {
    VERTEX *= 1.0 + .13 * sin(phase * 4.1);
}
void fragment() {
    ALBEDO = vec3(1.0, .96, .88) * power;
}
