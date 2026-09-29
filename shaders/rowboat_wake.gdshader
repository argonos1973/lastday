shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;
varying vec4 tint;
varying vec3 water_position;
float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}
void vertex() {
	tint = COLOR;
	water_position = VERTEX;
}
void fragment() {
	float across = UV.x * 2.0 - 1.0;
	vec2 flow = water_position.xz + vec2(TIME * 0.07, -TIME * 0.04);
	float coarse = noise(flow * 2.8);
	float bend = (coarse - 0.5) * 0.28;
	float crest = exp(-pow((across + bend) * 3.2, 2.0));
	float companion = exp(-pow((across + 0.62 + bend) * 7.0, 2.0)) * 0.25;
	float grain = noise(flow * 24.0) * 0.65 + noise(flow * 57.0) * 0.35;
	float foam = smoothstep(0.43, 0.72, grain) * smoothstep(0.22, 0.65, coarse);
	float center_churn = (1.0 - smoothstep(0.25, 1.0, abs(across))) * foam;
	float shape = mix(center_churn, crest + companion, tint.r);
	ALBEDO = mix(vec3(0.26, 0.39, 0.37), vec3(0.83, 0.89, 0.82), foam);
	ROUGHNESS = mix(0.18, 0.65, foam);
	SPECULAR = 0.55;
	ALPHA = shape * tint.a * (0.28 + foam * 0.44);
}
