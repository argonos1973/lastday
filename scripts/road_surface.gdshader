shader_type spatial;
render_mode cull_disabled;

uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float erosion(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), f.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	return erosion(p) * 0.55 + erosion(p * 2.13 + vec2(1.7, 3.2)) * 0.30 + erosion(p * 4.7 - vec2(2.4, 1.1)) * 0.15;
}

void fragment() {
	// UV2.x: across road (-1..+1), UV2.y: distance along road
	// COLOR.r: river bank transition (0 = dry road, 1 = water edge/ford)
	// COLOR.g: submerged factor inside river channel
	float across = UV2.x;
	float distance_along = UV2.y;
	float river_prox = clamp(COLOR.r, 0.0, 1.0);
	float submerged = clamp(COLOR.g, 0.0, 1.0);

	float breakup_noise = fbm(UV * 1.85);
	float fine_noise = erosion(UV * 11.5);

	// Inside the river channel, dissolve the road edge organically into stones
	// instead of leaving a straight polygon cut across the water.
	if (submerged > 0.02) {
		float cutout = submerged + (breakup_noise - 0.48) * 0.55 + (fine_noise - 0.5) * 0.20 + abs(across) * 0.18;
		if (cutout > 0.62) {
			discard;
		}
	}

	vec3 grain = texture(aggregate, UV * 1.4).rgb;
	float detail = dot(grain, vec3(0.299, 0.587, 0.114));
	vec3 coarse_grain = texture(aggregate, UV * 3.2 + vec2(0.37, 0.19)).rgb;
	float pebbles = dot(coarse_grain, vec3(0.333));

	vec3 asphalt = vec3(0.095, 0.10, 0.106) * (0.68 + detail * 1.05);
	float broad = erosion(UV * 1.1);
	float chips = fine_noise;
	float edge_damage = erosion(vec2(across * 3.0, distance_along * 0.38));

	// Subtle polished wheel tracks along both lanes
	float rut = exp(-pow((abs(across) - 0.42) * 5.2, 2.0));
	asphalt *= mix(1.0, 0.84, rut * 0.65);

	float shoulder = smoothstep(0.64, 0.97, abs(across) + (edge_damage - 0.45) * 0.40 + (chips - 0.5) * 0.10);
	vec3 gravel = vec3(0.28, 0.245, 0.195) * (0.62 + detail * 0.95);

	// Irregular tarmac repairs, weathered tar patches and branching cracks
	float patches = smoothstep(0.58, 0.76, broad + (chips - 0.5) * 0.16);
	asphalt = mix(asphalt, vec3(0.175, 0.158, 0.128) * (0.72 + detail), patches * 0.75);

	float fracture_field = erosion(UV * 2.2 + vec2(erosion(UV * 5.0)) * 0.5);
	float fracture_width = max(fwidth(fracture_field), 0.002);
	float cracks = (1.0 - smoothstep(0.004, 0.004 + fracture_width, abs(fracture_field - 0.48))) * smoothstep(0.34, 0.60, broad);
	asphalt = mix(asphalt, vec3(0.022, 0.020, 0.016), cracks * 0.85);

	// Center line & faded urban crosswalk bars near street intersections
	float aa = max(fwidth(across), 0.0005);
	float center = 1.0 - smoothstep(0.012 - aa, 0.012 + aa, abs(across));
	float dash = 1.0 - smoothstep(3.0, 3.05, mod(distance_along, 7.0));
	float paint_wear = smoothstep(0.46, 0.70, erosion(UV * 3.8)) * smoothstep(0.28, 0.58, chips);
	float paint = center * dash * paint_wear * 0.48 * (1.0 - river_prox);

	vec3 road_col = mix(mix(asphalt, gravel, shoulder), vec3(0.68, 0.65, 0.54), paint);

	// Natural river crossing / bank erosion: broken asphalt chunks -> river shingle & wet mud
	float bank_break = smoothstep(0.14, 0.68, river_prox + (breakup_noise - 0.5) * 0.48 + (chips - 0.5) * 0.22 + shoulder * 0.25);
	vec3 river_shingle = mix(
		vec3(0.20, 0.17, 0.13) * (0.55 + pebbles * 1.15),
		vec3(0.12, 0.105, 0.085) * (0.60 + detail * 0.9),
		smoothstep(0.35, 0.85, river_prox)
	);
	// Wet darkening near water edge
	float wetness = smoothstep(0.42, 0.95, river_prox + (breakup_noise - 0.5) * 0.2);
	river_shingle *= mix(1.0, 0.58, wetness);
	road_col = mix(road_col, river_shingle, bank_break);

	// Micro-normal from aggregate + cracks + broken asphalt edge
	float h_here = detail * 0.55 - cracks * 0.35 - bank_break * 0.45 + pebbles * bank_break * 0.35;
	vec3 n_perturb = normalize(vec3(-dFdx(h_here) * 3.2, 1.0, -dFdy(h_here) * 3.2));
	NORMAL = normalize(mix(NORMAL, n_perturb, 0.42));

	ALBEDO = road_col;
	float base_rough = mix(0.92, 0.78, rut * 0.5 + paint * 0.6);
	ROUGHNESS = mix(base_rough, 0.26, wetness * 0.85);
	SPECULAR = mix(0.18, 0.48, wetness);
}
