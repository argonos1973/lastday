shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D albedo_texture : source_color, filter_linear, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_cutoff = 0.4;
varying float tree_tone;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_tone = fract(sin(dot(origin.xz, vec2(0.1271, 0.3117))) * 437.585);
	float crown = smoothstep(1.2, 5.0, VERTEX.z);
	float gust = sin(TIME * 1.1 + origin.x * 0.16 + origin.z * 0.11);
	float flutter = sin(TIME * 2.7 + VERTEX.x * 2.5 + VERTEX.y * 1.7);
	VERTEX.x += (gust * 0.035 + flutter * 0.012) * crown;
	VERTEX.y += gust * 0.018 * crown;
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * albedo_tint;
	ALBEDO = tex.rgb * mix(vec3(0.78, 0.86, 0.69), vec3(0.98, 0.96, 0.81), tree_tone);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = 0.91;
	SPECULAR = 0.16;
	BACKLIGHT = ALBEDO * 0.22;
}
