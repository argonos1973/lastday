shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform bool shore_blend = false;
uniform sampler2D shore_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D shore_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform int shore_roughness_channel = 1;
uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float shore_ground_y = 0.0;
uniform float shore_water_y = 0.085;
uniform vec2 shore_center = vec2(0.0);
uniform vec2 shore_radii = vec2(63.75, 38.25);
uniform float shore_yaw = 0.0;
varying vec3 world_position;
varying vec3 world_normal;
varying float local_height;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	local_height = VERTEX.y;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= max(dot(w, vec3(1.0)), 0.001);
	vec3 p = world_position * 0.65;
	vec3 stone = texture(rock_albedo, p.zy).rgb * w.x;
	stone += texture(rock_albedo, p.xz).rgb * w.y;
	stone += texture(rock_albedo, p.xy).rgb * w.z;
	float patches = texture(variation, world_position.xz * 0.16).r;
	float damp = 1.0 - smoothstep(-0.65, 0.2, local_height);
	ALBEDO = stone * tint * mix(vec3(0.90, 0.88, 0.82), vec3(0.68, 0.67, 0.62), patches * 0.5) * (1.0 - damp * 0.17);
	float h = texture(rock_height, p.zy).r * w.x + texture(rock_height, p.xz).r * w.y + texture(rock_height, p.xy).r * w.z;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float determinant = dot(dpdx, r1);
	vec3 gradient = sign(determinant) * (dFdx(h) * r1 + dFdy(h) * r2);
	NORMAL = normalize(abs(determinant) * NORMAL - gradient * 0.055);
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	if (shore_blend) {
		vec2 offset = world_position.xz - shore_center;
		vec2 local = vec2(dot(offset, vec2(cos(shore_yaw), -sin(shore_yaw))), dot(offset, vec2(sin(shore_yaw), cos(shore_yaw))));
		float bank_distance = (length(local / shore_radii) - 1.0) * min(shore_radii.x, shore_radii.y);
		float land = smoothstep(-0.1, 1.4, bank_distance);
		float edge_noise = texture(variation, world_position.xz * .43).r;
		float cover = (1.0 - smoothstep(.025, .26 + edge_noise * .24, world_position.y - shore_ground_y)) * land;
		vec2 uv = world_position.xz * .45;
		float ground_patches = texture(variation, world_position.xz * .009).r;
		float detail = texture(variation, world_position.xz * .057 + vec2(.31)).r;
		vec3 leaves_a = texture(leaf_albedo, uv).rgb;
		vec3 leaves_b = texture(leaf_albedo, mat2(vec2(.8, .6), vec2(-.6, .8)) * uv * .79 + vec2(.37, .61)).rgb;
		vec3 leaves = mix(leaves_a, leaves_b, smoothstep(.32, .68, detail) * .62);
		vec3 soil = texture(soil_albedo, world_position.xz * .32).rgb * vec3(.65, .58, .47);
		float exposed = smoothstep(.47, .69, ground_patches + detail * .16) * .8;
		vec3 ground = mix(leaves * vec3(.62, .78, .58), soil, exposed);
		float moss = smoothstep(.53, .72, detail) * (1.0 - exposed) * .45;
		ground = mix(ground, ground * vec3(.62, .84, .44), moss) * mix(.76, 1.0, ground_patches);
		float wet = 1.0 - smoothstep(shore_water_y - .04, shore_water_y + .18 + edge_noise * .08, world_position.y);
		vec3 granite = texture(rock_albedo, UV).rgb * tint;
		granite *= mix(vec3(1.0), vec3(.57, .64, .62), wet);
		ALBEDO = mix(granite, ground, cover);
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		NORMAL_MAP = texture(shore_normal, UV).rgb;
		NORMAL_MAP_DEPTH = .75 * (1.0 - cover);
		ROUGHNESS = mix(texture(shore_roughness, UV)[shore_roughness_channel], .98, cover) - wet * .24 * (1.0 - cover);
		SPECULAR = mix(.23, .38, wet);
	}
}
