shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
varying vec4 tint;
varying vec3 water_position;
void vertex() {
	tint = COLOR;
	water_position = VERTEX;
}
void fragment() {
	float across = UV.x * 2.0 - 1.0;
	float bend = sin(UV.y * 4.0 + TIME * 1.3) * 0.10;
	float crest = exp(-pow((across + bend) * 3.2, 2.0));
	float companion = exp(-pow((across + 0.62 + bend) * 7.0, 2.0)) * 0.25;
	float grain = 0.5 + 0.5 * sin(water_position.x * 23.0 + sin(water_position.z * 19.0)) * sin(water_position.z * 31.0 - TIME);
	float foam = smoothstep(0.5, 0.85, grain);
	ALBEDO = mix(vec3(0.19, 0.32, 0.31), vec3(0.68, 0.78, 0.73), foam * 0.6);
	ROUGHNESS = mix(0.18, 0.65, foam);
	SPECULAR = 0.55;
	NORMAL = normalize(NORMAL + vec3(sin(across * 5.0) * 0.2, 0.0, 0.0));
	ALPHA = (crest + companion) * tint.a * (0.18 + foam * 0.25);
}
