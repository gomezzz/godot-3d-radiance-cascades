shader_type spatial;
render_mode cull_disabled;
varying vec3 flake_position;
void vertex() {
    // Stable per-particle distortion makes every torn outline and fold distinct.
    float seed = float(INSTANCE_ID) * 2.39996;
    float polar = atan(VERTEX.y, VERTEX.x);
    float edge = length(VERTEX.xy);
    float tear = 1.0 + .27*sin(polar*5.0+seed) + .13*cos(polar*9.0-seed*1.7);
    VERTEX.xy *= tear * vec2(.8+.28*sin(seed*1.3), 1.0+.23*cos(seed*.9));
    VERTEX.z += edge * .3 * sin(polar*3.0+seed);
    flake_position = VERTEX;
    // ParticleProcessMaterial publishes its randomized angle; a custom mesh
    // shader must consume it. Spin around two axes, not a shared billboard axis.
    float angle = INSTANCE_CUSTOM.x;
    float tilt = angle * 0.73 + float(INSTANCE_ID) * 2.39996;
    mat3 spin = mat3(vec3(cos(angle), sin(angle), 0.0),
        vec3(-sin(angle), cos(angle), 0.0), vec3(0.0, 0.0, 1.0));
    mat3 tumble = mat3(vec3(1.0, 0.0, 0.0),
        vec3(0.0, cos(tilt), sin(tilt)), vec3(0.0, -sin(tilt), cos(tilt)));
    VERTEX = tumble * spin * VERTEX;
    NORMAL = tumble * spin * NORMAL;
}
void fragment() {
    // Vertex deformation changes the fold normals, so derive them from geometry.
    vec3 fold_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
    NORMAL = dot(fold_normal, VIEW) < 0.0 ? -fold_normal : fold_normal;
    float char = .65 + .35*sin(dot(flake_position,vec3(71.3,93.7,51.1)))*
        sin(dot(flake_position,vec3(39.1,61.7,87.3)));
    ALBEDO = COLOR.rgb * char;
    ROUGHNESS = 0.95;
    // Only hot orange flakes emit; neutral ash must not remain a glowing dot.
    float heat = max(COLOR.r - COLOR.g, 0.0);
    EMISSION = ALBEDO * heat * 7.0;
    ALPHA = COLOR.a;
}
