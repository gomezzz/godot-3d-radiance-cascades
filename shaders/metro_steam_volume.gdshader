shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, blend_mix, depth_draw_never, depth_test_disabled;
uniform sampler3D noise_tex : repeat_enable, filter_linear;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform float scene_time = 0.0;
varying vec3 local_point;
varying vec3 local_eye;
void vertex() {
    local_point = VERTEX;
    local_eye = (inverse(MODEL_MATRIX) * vec4(CAMERA_POSITION_WORLD, 1.0)).xyz;
}
void fragment() {
    vec3 ray = normalize(local_point - local_eye);
    vec3 safe_ray = mix(vec3(-1.0), vec3(1.0), step(vec3(0.0), ray)) * max(abs(ray), vec3(0.00001));
    vec3 a = (-vec3(1.0,1.75,1.2) - local_eye) / safe_ray;
    vec3 b = (vec3(1.0,1.75,1.2) - local_eye) / safe_ray;
    vec3 lo = min(a,b), hi = max(a,b);
    float start = max(max(lo.x,lo.y),max(lo.z,0.0));
    float finish = min(min(hi.x,hi.y),hi.z);
    vec4 depth_view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, texture(scene_depth, SCREEN_UV).r, 1.0);
    finish = min(finish, length(depth_view.xyz / depth_view.w));
    float step_length = max(finish - start, 0.0) / 40.0;
    float optical_depth = 0.0;
    for (int i = 0; i < 40; i++) {
        vec3 p = (local_eye + ray * (start + (float(i)+0.5)*step_length)) / vec3(2.0,3.5,2.4) + 0.5;
        vec2 drift = vec2(sin(p.y*4.0-scene_time*0.15),cos(p.y*3.0+scene_time*0.12))*p.y*0.1;
        float r = length(p.xz-0.5-drift);
        float edge = 1.0-smoothstep(0.10+p.y*0.12,0.26+p.y*0.19,r);
        float n = texture(noise_tex,p*0.9-vec3(0.0,scene_time*0.045,0.0)).r;
        // Continuous dilution avoids a dense column with an abrupt upper cap.
        float falloff = exp(-1.8*p.y) * (1.0-smoothstep(0.65,1.0,p.y));
        float density = edge * falloff * smoothstep(0.0,0.045,p.y) * (0.3+n*0.7);
        optical_depth += density * step_length * 0.72;
    }
    ALPHA = 1.0-exp(-optical_depth);
    ALBEDO = vec3(0.105,0.135,0.145);
}
