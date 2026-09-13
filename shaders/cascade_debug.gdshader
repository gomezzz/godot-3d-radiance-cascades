shader_type canvas_item;
uniform bool transmittance = false;
uniform float exposure = 4.0;
void fragment() {
    vec4 data = texture(TEXTURE, UV);
    vec3 radiance = data.rgb * exposure;
    COLOR = vec4(transmittance ? vec3(data.a) : pow(radiance/(1.0+radiance),vec3(1.0/2.2)),1.0);
}
