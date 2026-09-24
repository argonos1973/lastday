shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation : filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
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
}
