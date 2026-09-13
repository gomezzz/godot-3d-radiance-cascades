shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, ambient_light_disabled;
uniform sampler2D irradiance_tex : filter_linear, repeat_disable;
uniform vec3 volume_origin = vec3(-6.0, 0.0, -6.0);
uniform ivec3 volume_grid = ivec3(24, 16, 24);
uniform float probe_spacing = 0.5;
uniform vec4 surface_color : source_color = vec4(0.7, 0.7, 0.7, 1.0);
uniform vec3 emission_color = vec3(0.0);
uniform float station_power = 1.0;
uniform float gi_strength = 1.0;
uniform bool luminaire = false;
uniform bool metro_graffiti = false;
uniform sampler2D graffiti_map : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int view_mode = 0;
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metallic_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo = false;
uniform bool use_normal = false;
uniform bool use_roughness = false;
uniform bool use_metallic = false;
uniform bool use_height = false;
uniform bool metro_reflection_clip = false;
uniform bool local_diffuse = false;
uniform sampler2D height_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float height_scale = 0.025;
uniform float roughness_factor = 0.7;
uniform float metallic_factor = 0.0;
uniform float normal_strength = 1.0;
uniform vec4 roughness_channel = vec4(1,0,0,0);
uniform vec4 metallic_channel = vec4(1,0,0,0);
uniform vec2 uv_scale = vec2(1.0);
uniform vec2 uv_offset = vec2(0.0);
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec3 sample_lighting(vec3 position, vec3 normal) {
    vec3 q = clamp((position - volume_origin) / probe_spacing - 0.5,
                   vec3(0.0), vec3(volume_grid - ivec3(1)));
    vec3 result = vec3(0.0);
    float z0 = floor(q.z), z1 = min(z0 + 1.0, float(volume_grid.z - 1));
    vec2 size = vec2(float(volume_grid.x * 6), float(volume_grid.y * volume_grid.z));
    for (int axis = 0; axis < 3; axis++) {
        int face = axis * 2 + int(normal[axis] < 0.0);
        float x = q.x + float(face * volume_grid.x) + 0.5;
        vec3 a = textureLod(irradiance_tex,
            vec2(x, q.y + z0 * float(volume_grid.y) + 0.5) / size, 0.0).rgb;
        vec3 b = textureLod(irradiance_tex,
            vec2(x, q.y + z1 * float(volume_grid.y) + 0.5) / size, 0.0).rgb;
        result += mix(a, b, fract(q.z)) * normal[axis] * normal[axis];
    }
    return result;
}
vec4 paint_tag(vec2 uv, int tag) {
    if (any(lessThan(uv,vec2(0.0))) || any(greaterThan(uv,vec2(1.0)))) { return vec4(0.0); }
    float top = tag == 0 ? 0.0 : (tag == 1 ? 0.30 : (tag == 2 ? 0.55 : 0.79));
    float bottom = tag == 0 ? 0.30 : (tag == 1 ? 0.55 : (tag == 2 ? 0.79 : 1.0));
    vec4 paint = texture(graffiti_map,vec2(uv.x,mix(top+0.006,bottom-0.006,uv.y)));
    paint.a *= smoothstep(0.0,0.04,uv.y) * (1.0-smoothstep(0.94,1.0,uv.y));
    return paint;
}
void fragment() {
    // Reflected cameras lie behind the mirror plane. Clip the enclosing shell
    // in those views so walls/floor cannot hide the reflected station.
    if (metro_reflection_clip && CAMERA_VISIBLE_LAYERS == 1u) {
        if (CAMERA_POSITION_WORLD.y < 0.02 && world_position.y < 0.025) { discard; }
        if (CAMERA_POSITION_WORLD.x < -9.65 && world_position.x < -9.65) { discard; }
    }
    vec2 uv = UV * uv_scale + uv_offset;
    if (use_height) {
        vec3 tangent_view = vec3(dot(VIEW, normalize(TANGENT)), dot(VIEW, normalize(BINORMAL)), dot(VIEW, normalize(NORMAL)));
        vec2 step_uv = tangent_view.xy / max(abs(tangent_view.z), 0.25) * height_scale / 12.0;
        float depth = 0.0;
        for (int step = 0; step < 12; step++) {
            if (depth >= 1.0 - texture(height_map, uv).r) { break; }
            uv -= step_uv;
            depth += 1.0 / 12.0;
        }
    }
    vec3 base = surface_color.rgb;
    if (use_albedo) { base *= texture(albedo_map, uv).rgb; }
    if (metro_graffiti) {
        vec4 paint = vec4(0.0);
        // World-space paint stays on the existing tile mesh: no z-fighting or extra draws.
        if (abs(world_position.x) > 10.15) {
            float cell = floor((world_position.z+15.0)/6.0);
            vec2 tag_uv = vec2(mod(world_position.z+15.0,6.0)/3.5, (2.35-world_position.y)/1.05);
            paint = paint_tag(tag_uv,int(mod(cell + (world_position.x>0.0 ? 2.0 : 0.0),4.0)));
        } else if (abs(world_position.x+2.7)<0.34 || abs(world_position.x-8.3)<0.34) {
            float pillar = floor((world_position.z+16.5)/3.0);
            if (mod(pillar,3.0) != 1.0) {
                float center_x = world_position.x<0.0 ? -2.7 : 8.3;
                float center_z = pillar*3.0-15.0;
                vec2 tag_uv = vec2((world_position.x-center_x+world_position.z-center_z)/0.68+0.5,(2.2-world_position.y)/0.85);
                paint = paint_tag(tag_uv,int(mod(pillar,4.0)));
            }
        }
        base = mix(base,paint.rgb,paint.a*0.86);
    }
    vec3 geometric_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    if (use_normal) {
        vec2 xy = (texture(normal_map, uv).xy * 2.0 - 1.0) * normal_strength;
        vec3 mapped = vec3(xy, sqrt(max(0.0, 1.0 - dot(xy, xy))));
        NORMAL = normalize(mat3(normalize(TANGENT), normalize(BINORMAL), normalize(NORMAL)) * mapped);
    }
    vec3 normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
    vec3 irradiance = sample_lighting(world_position + geometric_normal * probe_spacing * 0.6, normal);
    ROUGHNESS = clamp(roughness_factor * (use_roughness ? dot(texture(roughness_map, uv), roughness_channel) : 1.0), 0.06, 1.0);
    METALLIC = metallic_factor * (use_metallic ? dot(texture(metallic_map, uv), metallic_channel) : 1.0);
    ALBEDO = base;
    EMISSION = emission_color * station_power + base * irradiance * gi_strength * (1.0 - METALLIC);
    if (luminaire) {
        float ribs = 0.65 + 0.35 * pow(abs(sin(UV.y * 150.8)), 3.0);
        ALBEDO *= ribs;
        ROUGHNESS = 0.28 + (1.0 - ribs) * 0.4;
        EMISSION = emission_color * station_power * ribs + base * irradiance * gi_strength;
    }
    if (view_mode != 0) {
        ALBEDO = vec3(0.0);
        EMISSION = view_mode == 1 ? irradiance : base;
        METALLIC = 0.0;
    }
}
void light() {
    // RC already includes emitter-to-surface diffuse transport. Lamps add only
    // GGX specular highlights, avoiding a second direct diffuse contribution.
    vec3 h = normalize(VIEW + LIGHT);
    float nl = max(dot(NORMAL, LIGHT), 0.0);
    float nv = max(dot(NORMAL, VIEW), 0.001);
    float nh = max(dot(NORMAL, h), 0.0);
    float vh = max(dot(VIEW, h), 0.0);
    float a = max(ROUGHNESS * ROUGHNESS, 0.004);
    float a2 = a * a;
    float d = a2 / (PI * pow(nh * nh * (a2 - 1.0) + 1.0, 2.0));
    float k = pow(ROUGHNESS + 1.0, 2.0) / 8.0;
    float g = nv / (nv * (1.0 - k) + k) * nl / (nl * (1.0 - k) + k);
    vec3 f0 = mix(vec3(0.04), ALBEDO, METALLIC);
    vec3 f = f0 + (1.0 - f0) * pow(1.0 - vh, 5.0);
    if (view_mode == 0) {
        if (local_diffuse || (metro_reflection_clip && SPECULAR_AMOUNT < 0.01)) {
            // Godot multiplies the accumulated diffuse by ALBEDO afterwards.
            DIFFUSE_LIGHT += (1.0 - METALLIC) * nl * LIGHT_COLOR * ATTENUATION / PI;
        }
        SPECULAR_LIGHT += d * g * f / max(4.0 * nv * nl, 0.001) * nl * LIGHT_COLOR * ATTENUATION;
    }
}
