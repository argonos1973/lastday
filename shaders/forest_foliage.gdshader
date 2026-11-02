shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D albedo_texture : source_color, filter_linear, repeat_enable;
uniform vec4 albedo_tint : source_color = vec4(1.0);
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float alpha_cutoff = 0.4;
varying float tree_tone;
varying float tree_warmth;
varying float crown_factor;
varying float radial_ao;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	tree_tone = fract(sin(dot(origin.xz, vec2(0.1271, 0.3117))) * 437.585);
	tree_warmth = fract(sin(dot(origin.xz, vec2(0.2695, 0.1833))) * 291.731);
	float crown = smoothstep(1.1, 5.2, VERTEX.z);
	crown_factor = crown;
	float radial = length(VERTEX.xy);
	radial_ao = clamp(smoothstep(0.15, 1.65, radial) * 0.55 + crown * 0.45, 0.38, 1.0);
	float phase = origin.x * 0.19 + origin.z * 0.14 + tree_tone * 6.28318;
	float gust = sin(TIME * 1.15 + phase) + 0.35 * sin(TIME * 0.53 + phase * 1.7);
	float flutter = sin(TIME * 2.85 + VERTEX.x * 2.6 + VERTEX.y * 2.1 + phase);
	float branch_tip = smoothstep(0.25, 1.6, radial);
	VERTEX.x += (gust * 0.042 + flutter * 0.015 * branch_tip) * crown;
	VERTEX.y += (gust * 0.024 - flutter * 0.011 * branch_tip) * crown;
	// Mezclar la normal plana de la tarjeta con una normal hemisferica de copa
	// para que la luz solar envuelva el volumen del arbol con suavidad.
	vec3 canopy_dir = normalize(vec3(VERTEX.x * 0.85, VERTEX.y * 0.85, max(VERTEX.z - 1.4, 0.9)));
	NORMAL = normalize(mix(NORMAL, canopy_dir, 0.58));
	UV = UV * uv_scale.xy + uv_offset.xy;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV) * albedo_tint;
	vec3 deep_pine = vec3(0.70, 0.82, 0.62);
	vec3 lush_moss = vec3(0.86, 0.95, 0.72);
	vec3 sun_warm = vec3(1.02, 0.94, 0.76);
	vec3 palette = mix(deep_pine, lush_moss, tree_tone);
	palette = mix(palette, sun_warm, smoothstep(0.62, 0.98, tree_warmth) * 0.48);
	// Sombreado interno del tronco/ramas bajas y puntas mas luminosas arriba
	float foliage_shade = mix(0.66, 1.08, radial_ao) * mix(0.84, 1.06, crown_factor);
	ALBEDO = tex.rgb * palette * foliage_shade;
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_cutoff;
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	AO = clamp(radial_ao * 1.05, 0.42, 1.0);
	AO_LIGHT_AFFECT = 0.45;
	ROUGHNESS = mix(0.93, 0.82, crown_factor);
	SPECULAR = 0.20;
	BACKLIGHT = ALBEDO * mix(0.18, 0.36, crown_factor) * vec3(1.05, 1.02, 0.78);
}
