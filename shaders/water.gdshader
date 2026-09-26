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
        float wave = sin(dot(world_pos.xz,vec2(.74,.35)) + TIME*.8);
        wave += sin(dot(world_pos.xz,vec2(-.33,1.17)) - TIME*1.1)*.4;
        VERTEX.y += wave * wave_height * .5;
    }
}

void fragment() {
    vec2 flow = current_direction * flow_speed * flow_direction_multiplier;
    if (!use_river_flow) { flow = vec2(.025,.018); }
    vec2 p = world_pos.xz;
    // Different wavelengths/speeds avoid a uniformly pulsing surface.
    vec3 n1 = texture(water_noise_1,p*.48 - flow*TIME*.18).rgb*2.0-1.0;
    vec3 n2 = texture(water_noise_2,p*.91 + vec2(.37,.19) - flow*TIME*.11).rgb*2.0-1.0;
    vec3 ripple = normalize(vec3(n1.xy+n2.xy*.45,1.0));
    NORMAL_MAP = ripple*.5+.5;
    NORMAL_MAP_DEPTH = normal_scale;
    if (!FRONT_FACING) { NORMAL = -NORMAL; }
    // Depth approximation from mesh UVs: the river crosses the channel on
    // UV.y 0..1 and the lake runs from center (.5,.5) to the rim, so the
    // shoreline needs no depth texture (unavailable in Compatibility).
    float edge_dist = use_river_flow
        ? min(UV.y, 1.0-UV.y)*2.0
        : 1.0 - clamp(length(UV-vec2(.5))*2.0, 0.0, 1.0);
    float absorption = 1.0-exp(-edge_dist*beers_law*4.5);
    float fresnel = pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.0,1.0),mirror_fresnel_power);
    ALBEDO = mix(water_color,night_water_color,night_amount);
    ROUGHNESS = roughness_scale;
    METALLIC = mirror_strength * 0.55;
    SPECULAR = 1.0;
    ALPHA = clamp(.13+absorption*.78,.13,.96);
    ALPHA = mix(ALPHA, 1.0, fresnel*mirror_strength);
    if (use_foam) {
        float contact = (1.0-smoothstep(.02,.16,edge_dist))*smoothstep(.001,.03,edge_dist);
        float flecks = smoothstep(.62,.82,texture(foam_texture,p*.9-flow*TIME*.12).r);
        float foam = contact*flecks*.35;
        ALBEDO = mix(ALBEDO,foam_color,foam);
        ROUGHNESS = mix(ROUGHNESS,.75,foam);
    }
}
