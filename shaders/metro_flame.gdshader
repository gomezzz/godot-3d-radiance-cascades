shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_never;
uniform sampler3D fuel_tex : filter_linear, repeat_enable;
uniform float scene_time = 0.0;
varying vec3 local_position;
varying vec3 local_eye;
void vertex() {
    local_position = VERTEX;
    local_eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}
void fragment() {
    vec3 ray = normalize(local_position - local_eye);
    vec3 safe_ray = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), ray)) * max(abs(ray), vec3(0.00001));
    vec3 a = (-vec3(0.38,0.55,0.38) - local_eye) / safe_ray;
    vec3 b = ( vec3(0.38,0.55,0.38) - local_eye) / safe_ray;
    vec3 lo = min(a,b), hi = max(a,b);
    float begin = max(max(lo.x,lo.y),max(lo.z,0.0));
    float end = min(min(hi.x,hi.y),hi.z);
    float step_size = max(end-begin,0.0) / 32.0;
    vec3 light = vec3(0.0);
    float transmission = 1.0;
    for (int i=0; i<32; i++) {
        vec3 p = local_eye + ray * (begin + (float(i)+0.5)*step_size);
        float h = (p.y+0.55)/1.1;
        vec2 bend = vec2(sin(h*7.0-scene_time*2.3),cos(h*9.0-scene_time*1.7))*h*0.055;
        vec3 q = vec3((p.xz+bend)*2.6,h*1.5-scene_time*0.65);
        float n = texture(fuel_tex,q).r;
        float detail = texture(fuel_tex,q*2.7+vec3(0.3,0.7,-scene_time*0.3)).r;
        float radius = length(p.xz+bend);
        float envelope = 1.0-smoothstep(0.05,0.3*(1.0-h)+0.06,radius);
        float density = smoothstep(0.30+h*0.25,0.63,n*0.78+detail*0.22);
        density *= envelope * (1.0-smoothstep(0.65,1.0,h));
        float opacity = 1.0-exp(-density*step_size*9.0);
        float hot = clamp(density*0.8+(1.0-h)*0.25,0.0,1.0);
        vec3 color = mix(vec3(1.15,0.08,0.008),vec3(2.4,1.25,0.28),hot);
        light += transmission * opacity * color;
        transmission *= 1.0-opacity;
    }
    ALPHA = 1.0-transmission;
    ALBEDO = light / max(ALPHA,0.001);
}
