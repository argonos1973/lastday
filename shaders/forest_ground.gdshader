shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation : filter_linear_mipmap, repeat_enable;
uniform float leaf_scale = 0.45;
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
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
	vec3 surface = mix(leaves * vec3(0.62, 0.78, 0.58), soil, exposed);
	float moss = smoothstep(0.53, 0.72, detail) * (1.0 - exposed) * 0.45;
	surface = mix(surface, surface * vec3(0.62, 0.84, 0.44), moss);
	ALBEDO = surface * mix(0.76, 1.0, patches);
	vec3 leaf_n = texture(leaf_normal, uv).xyz * 2.0 - 1.0;
	vec3 relief = normalize(vec3(leaf_n.x * 0.55, max(leaf_n.z, 0.25), leaf_n.y * 0.55));
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(n, relief, weights.y * (1.0 - exposed))), 0.0)).xyz);
	ROUGHNESS = mix(clamp(texture(leaf_roughness, uv).r, 0.72, 1.0), 0.98, exposed);
	SPECULAR = 0.18;
}
