shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool canopy_enabled = false;
uniform sampler2D canopy_mask : filter_linear, repeat_disable;
uniform vec2 canopy_minimum = vec2(-500.0);
uniform vec2 canopy_span = vec2(1000.0,1400.0);
uniform float leaf_scale = 0.45;
uniform bool cut_water_channels = false;
uniform sampler2D water_channel_mask : filter_nearest, repeat_disable;
uniform float terrain_extent = 500.0;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	if (cut_water_channels && texture(water_channel_mask, world_position.xz/(terrain_extent*2.0)+vec2(.5)).r > .5) { discard; }
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec2 uv = world_position.xz * leaf_scale;
	float patches = texture(variation, world_position.xz * 0.009).r;
	float detail = texture(variation, world_position.xz * 0.057 + vec2(0.31)).r;
	vec3 leaves_a = texture(leaf_albedo, uv).rgb;
	vec3 leaves_b = texture(leaf_albedo, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.79 + vec2(0.37, 0.61)).rgb;
	vec3 leaves = mix(leaves_a, leaves_b, smoothstep(0.32, 0.68, detail) * 0.62);
	vec3 p = world_position * 0.32;
	vec3 soil = texture(soil_albedo, p.zy).rgb * weights.x;
	soil += texture(soil_albedo, p.xz).rgb * weights.y;
	soil += texture(soil_albedo, p.xy).rgb * weights.z;
	soil *= vec3(0.65, 0.58, 0.47);
	float exposed = smoothstep(0.47, 0.69, patches + detail * 0.16);
	exposed = max(exposed * 0.8, 1.0 - smoothstep(0.50, 0.88, n.y));
	vec3 needles_tint = mix(vec3(0.78, 0.78, 0.69), vec3(0.88, 0.87, 0.77), smoothstep(0.25, 0.75, patches));
	vec3 surface = mix(leaves * needles_tint, soil, exposed);
	float canopy = canopy_enabled ? texture(canopy_mask,(world_position.xz-canopy_minimum)/canopy_span).r : 0.0;
	// Leaf litter accumulates under real crowns; clearings retain exposed soil.
	surface = mix(surface,leaves*vec3(.95,.85,.67),canopy*.92);
	float moss = smoothstep(0.48, 0.72, detail) * (1.0 - exposed) * 0.58;
	surface = mix(surface, surface * vec3(0.68, 0.80, 0.56), moss);
	// Micro-contraste de hojarasca y humedad en depresiones
	float micro_ao = mix(0.72, 1.05, smoothstep(0.22, 0.78, detail));
	// Embedded bedrock follows the slope; no floating decorative boulders.
	float bedrock = (1.0-smoothstep(.58,.86,n.y))*smoothstep(.25,.65,detail);
	vec3 rock_p = world_position*.55;
	vec3 rock = texture(rock_albedo,rock_p.zy).rgb*weights.x
		+ texture(rock_albedo,rock_p.xz).rgb*weights.y
		+ texture(rock_albedo,rock_p.xy).rgb*weights.z;
	surface = mix(surface,rock*.85,bedrock);
	float wet_bank = 0.0;
	if (cut_water_channels) {
		vec2 mask_uv = world_position.xz/(terrain_extent*2.0)+vec2(.5);
		wet_bank = texture(water_channel_mask,mask_uv).g;
		wet_bank *= .35 + detail*.45;
	}
	ALBEDO = surface * mix(0.74, 1.02, patches) * micro_ao * (1.0-wet_bank*.24);
	vec3 leaf_n = texture(leaf_normal, uv).xyz * 2.0 - 1.0;
	float relief_strength = mix(0.12, 0.48, 1.0 - smoothstep(12.0, 55.0, length(VERTEX)));
	vec3 relief = normalize(vec3(leaf_n.x * relief_strength, max(leaf_n.z, 0.4), leaf_n.y * relief_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(n, relief, weights.y * (1.0 - exposed * 0.65) * (1.0-bedrock))), 0.0)).xyz);
	ROUGHNESS = mix(clamp(texture(leaf_roughness, uv).r, 0.68, 0.96), 0.98, exposed);
	ROUGHNESS = max(.65, ROUGHNESS-wet_bank*.18);
	SPECULAR = mix(.20,.28,wet_bank);
}
