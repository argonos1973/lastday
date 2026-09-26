shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled;

uniform sampler2D water_noise_1 : repeat_enable, filter_linear_mipmap;
uniform sampler2D water_noise_2 : repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_texture : repeat_enable, filter_linear_mipmap;
uniform vec3 water_color : source_color = vec3(.055,.105,.085);
uniform vec3 night_water_color : source_color = vec3(.009,.018,.025);
uniform float night_amount = 0.0;
uniform float normal_scale = .22;
uniform float roughness_scale = .18;
uniform float beers_law = .8;
uniform bool use_vertex_waves = true;
uniform float wave_height = .025;
uniform bool use_river_flow = true;
uniform vec2 current_direction = vec2(1.0,0.0);
uniform float flow_speed = .35;
uniform float flow_direction_multiplier = -1.0;
uniform bool use_foam = true;
uniform vec3 foam_color : source_color = vec3(.55,.57,.50);
uniform float mirror_strength = .35;
uniform vec3 mirror_color : source_color = vec3(.62,.78,.97);
uniform float mirror_fresnel_power = 5.0;
varying vec3 world_pos;

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
    if (use_vertex_waves) {
        // Low-frequency noise avoids the long parallel ridges of sine waves.
        float wave = textureLod(foam_texture,world_pos.xz*.027+vec2(TIME*.004,-TIME*.003),0.0).r-.5;
        VERTEX.y += wave * wave_height;
    }
}

void fragment() {
    vec2 flow = current_direction * flow_speed * flow_direction_multiplier;
    if (!use_river_flow) { flow = vec2(.10,.07); }
    vec2 p = world_pos.xz;
    // Independent rotated noise layers: no periodic cosine bands.
    vec3 n1 = texture(water_noise_1,p*.48 - flow*TIME*.18).rgb*2.0-1.0;
    mat2 turn = mat2(vec2(.6,.8),vec2(-.8,.6));
    vec3 n2 = texture(water_noise_2,turn*(p*.79-flow*TIME*.13)+vec2(.37,.19)).rgb*2.0-1.0;
    vec3 broad = texture(water_noise_1,p*.17+vec2(-TIME*.009,TIME*.012)).rgb*2.0-1.0;
    float distant = smoothstep(12.0,90.0,length(VERTEX));
    vec2 slopes = (n1.xy+transpose(turn)*n2.xy*.55)*(1.0-distant*.85)+broad.xy*.4;
    vec3 ripple = normalize(vec3(slopes,1.0));
    // Procedural river/lake meshes have no tangent arrays. World-space
    // normals keep the animated ripples visible on those meshes as well.
    vec3 world_normal = normalize(vec3(-ripple.x*normal_scale,ripple.z,-ripple.y*normal_scale));
    NORMAL = normalize((VIEW_MATRIX*vec4(world_normal,0.0)).xyz);
    if (dot(NORMAL,VIEW) < 0.0) { NORMAL = -NORMAL; }
    // Depth approximation from mesh UVs: the river crosses the channel on
    // UV.y 0..1 and the lake runs from center (.5,.5) to the rim, so the
    // shoreline needs no depth texture (unavailable in Compatibility).
    float edge_dist = use_river_flow
        ? min(UV.y, 1.0-UV.y)*2.0
        : 1.0 - clamp(length(UV-vec2(.5))*2.0, 0.0, 1.0);
    float absorption = 1.0-exp(-edge_dist*beers_law*4.5);
    float fresnel = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),mirror_fresnel_power);
    vec3 tint = mix(water_color,night_water_color,night_amount);
    ALBEDO = mix(tint,mirror_color,fresnel*mirror_strength*.65);
    // Distant tiny ripples blend together instead of producing glittering aliasing.
    ROUGHNESS = roughness_scale + smoothstep(18.0,85.0,length(VERTEX))*.12;
    METALLIC = 0.0;
    SPECULAR = .35;
    ALPHA = clamp(.13+absorption*.66,.13,.92);
    ALPHA = mix(ALPHA, 1.0, fresnel*mirror_strength);
    if (use_foam) {
        float contact = (1.0-smoothstep(.02,.16,edge_dist))*smoothstep(.001,.03,edge_dist);
        float flecks = smoothstep(.62,.82,texture(foam_texture,p*.9-flow*TIME*.12).r);
        float foam = contact*flecks*.35;
        ALBEDO = mix(ALBEDO,foam_color,foam);
        ROUGHNESS = mix(ROUGHNESS,.75,foam);
    }
}
