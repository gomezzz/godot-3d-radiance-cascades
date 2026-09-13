shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 1.0;
void fragment() {
    COLOR = vec4(textureLod(screen_tex, SCREEN_UV, blur * 4.5).rgb, 1.0);
}
