shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D leaf_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaf_roughness : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D granite_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rock_height : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D variation : filter_linear_mipmap, repeat_enable;
uniform float leaf_scale = 0.45;

varying vec3 world_position;
varying vec3 world_normal;
varying float vertex_ridge_ao;

vec3 triplanar_rgb(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).rgb * w.x
		+ texture(tex, p.xz).rgb * w.y
		+ texture(tex, p.xy).rgb * w.z;
}

float triplanar_r(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy).r * w.x
		+ texture(tex, p.xz).r * w.y
		+ texture(tex, p.xy).r * w.z;
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vertex_ridge_ao = COLOR.r;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = pow(abs(n), vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);

	// 1) Suelo de bosque base (idéntico en y~0 a forest_ground.gdshader para fusión sin costura)
	vec2 uv = world_position.xz * leaf_scale;
	float patches = texture(variation, world_position.xz * 0.009).r;
	float detail = texture(variation, world_position.xz * 0.057 + vec2(0.31)).r;
	float macro_var = texture(variation, world_position.xz * 0.0032 + vec2(0.17, 0.73)).r;

	vec3 leaves_a = texture(leaf_albedo, uv).rgb;
	vec3 leaves_b = texture(leaf_albedo, mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * uv * 0.79 + vec2(0.37, 0.61)).rgb;
	vec3 leaves = mix(leaves_a, leaves_b, smoothstep(0.32, 0.68, detail) * 0.62);

	vec3 p_soil = world_position * 0.32;
	vec3 soil_raw = triplanar_rgb(soil_albedo, p_soil, weights);
	vec3 soil = soil_raw * vec3(0.65, 0.58, 0.47);

	float exposed = smoothstep(0.47, .69, patches + detail * 0.16);
	exposed = max(exposed * 0.8, 1.0 - smoothstep(0.50, 0.88, n.y));
	vec3 needles_tint = mix(vec3(0.54, 0.70, 0.48), vec3(0.68, 0.80, 0.56), smoothstep(0.25, 0.75, patches));
	vec3 forest_surface = mix(leaves * needles_tint, soil, exposed);
	float moss = smoothstep(0.48, 0.72, detail) * (1.0 - exposed) * 0.58;
	forest_surface = mix(forest_surface, forest_surface * vec3(0.56, 0.86, 0.40), moss);
	float micro_ao = mix(0.72, 1.05, smoothstep(0.22, 0.78, detail));
	forest_surface *= mix(0.74, 1.02, patches) * micro_ao;

	// 2) Roca granítica y pizarra de montaña (proyección triplanar multiescala)
	vec3 rock_macro = triplanar_rgb(rock_albedo, world_position * 0.085, weights);
	vec3 rock_mid = triplanar_rgb(rock_albedo, world_position * 0.26 + vec3(1.7, 0.9, 2.3), weights);
	vec3 granite_fine = triplanar_rgb(granite_albedo, world_position * 0.48, weights);
	vec3 rock_base = mix(rock_macro, rock_mid, 0.52);
	rock_base = mix(rock_base, granite_fine, 0.36);

	// Estratos geológicos, fisuras horizontales y escorrentías verticales en paredes
	float strata_y = world_position.y * 0.52 + (macro_var - 0.5) * 6.5 + (patches - 0.5) * 2.4;
	float strata_wave = sin(strata_y * 3.14159) * 0.5 + 0.5;
	float strata_fine = sin(strata_y * 11.5 + detail * 4.2) * 0.5 + 0.5;
	float ledge_crevice = smoothstep(0.82, 0.97, strata_fine) * (1.0 - smoothstep(0.62, 0.90, n.y));
	vec3 strata_tint = mix(vec3(0.60, 0.59, 0.56), vec3(0.92, 0.90, 0.86), smoothstep(0.20, 0.80, strata_wave));
	vec3 cliff_color = rock_base * strata_tint;
	// Escorrentías oscuras verticales (humedad en canales de roca)
	float seepage_noise = texture(variation, vec2((world_position.x - world_position.z) * 0.018, world_position.y * 0.006)).r;
	float seepage = smoothstep(0.58, 0.80, seepage_noise) * (1.0 - smoothstep(0.55, 0.84, n.y));
	cliff_color *= mix(1.0, 0.62, seepage * 0.65);
	cliff_color *= mix(1.0, 0.48, ledge_crevice * 0.75);

	// Liquen alpino en caras rocosas soleadas de media/alta montaña
	float lichen_mask = smoothstep(0.58, 0.78, detail) * smoothstep(8.0, 28.0, world_position.y) * smoothstep(0.35, 0.75, n.y);
	cliff_color = mix(cliff_color, vec3(0.46, 0.52, 0.30) * (0.75 + 0.35 * rock_mid.g), lichen_mask * 0.42);

	// 3) Pedregal subalpino (scree / grava fría) en pendientes medias y meseta alta
	vec3 scree_color = mix(soil_raw * vec3(0.68, 0.66, 0.62), granite_fine * vec3(0.76, 0.75, 0.72), 0.55);
	vec3 alpine_meadow = mix(forest_surface * vec3(0.88, 0.84, 0.74), scree_color, smoothstep(16.0, 44.0, world_position.y + (patches - 0.5) * 8.0) * 0.68);
	float plateau_gravel = smoothstep(48.0, 55.2, world_position.y) * smoothstep(0.86, 0.97, n.y);
	alpine_meadow = mix(alpine_meadow, scree_color * mix(0.82, 1.04, detail), plateau_gravel * 0.65);

	// 4) Mezcla de Roca Escarpada vs Suelo/Pradera según pendiente y altitud
	float alt_rock_boost = smoothstep(4.0, 38.0, world_position.y) * 0.20;
	float slope_rock = 1.0 - smoothstep(0.52 + alt_rock_boost * 0.45, 0.84 + alt_rock_boost * 0.25, n.y - (detail - 0.5) * 0.12);
	// En cumbres muy altas (> 57 m) la roca aflora incluso en pendientes moderadas
	float high_peak_rock = smoothstep(56.6, 63.0, world_position.y) * (1.0 - smoothstep(0.65, 0.92, n.y));
	float rock_weight = clamp(max(slope_rock, high_peak_rock), 0.0, 1.0);
	// En la base misma (y < 1.2 m) suavizamos hacia el suelo del bosque para evitar cualquier corte
	float foot_blend = smoothstep(0.15, 2.4, world_position.y);
	rock_weight *= mix(0.25, 1.0, foot_blend);

	vec3 mountain_col = mix(alpine_meadow, cliff_color, rock_weight);

	// 5) Nieve y escarcha en las cumbres alpinas (> 57.5 m, por encima de la explanada militar de 56 m)
	float north_bias = clamp(-n.z * 0.35, -0.15, 0.25);
	float snow_alt = smoothstep(57.4, 65.0, world_position.y + (macro_var - 0.5) * 4.5 + (detail - 0.5) * 2.2 + north_bias * 5.0);
	float snow_slope = smoothstep(0.38, 0.68, n.y + (detail - 0.5) * 0.14);
	float snow_mask = clamp(snow_alt * snow_slope, 0.0, 1.0);
	vec3 snow_col = mix(vec3(0.84, 0.88, 0.93), vec3(0.96, 0.97, 0.99), smoothstep(0.3, 0.8, detail));
	mountain_col = mix(mountain_col, snow_col, snow_mask * 0.88);

	// Oclusión de barrancos / concavidades codificada opcionalmente en COLOR.r (por defecto 1.0)
	float valley_ao = mix(0.68, 1.06, clamp(vertex_ridge_ao, 0.0, 1.0));
	ALBEDO = mountain_col * valley_ao;

	// 6) Relieve normal combinando hojarasca en llano y relieve pétreo triplanar en roca/montaña
	float h_coarse = triplanar_r(rock_height, world_position * 0.22, weights);
	float h_fine = triplanar_r(rock_height, world_position * 0.68 + vec3(0.41, 0.83, 0.19), weights);
	float h_rock = mix(h_coarse, h_fine, 0.48) - ledge_crevice * 0.35 + strata_wave * 0.12;

	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	float bump_strength = mix(0.028, 0.085, rock_weight) * (1.0 - snow_mask * 0.65);
	vec3 rock_gradient = sign(det) * (dFdx(h_rock) * r1 + dFdy(h_rock) * r2);
	vec3 bumped_view_n = normalize(abs(det) * NORMAL - rock_gradient * bump_strength);

	vec3 leaf_n = texture(leaf_normal, uv).xyz * 2.0 - 1.0;
	vec3 relief_world = normalize(vec3(leaf_n.x * 0.68, max(leaf_n.z, 0.22), leaf_n.y * 0.68));
	vec3 forest_view_n = normalize((VIEW_MATRIX * vec4(normalize(mix(n, relief_world, weights.y * (1.0 - exposed * 0.65))), 0.0)).xyz);

	NORMAL = normalize(mix(forest_view_n, bumped_view_n, clamp(rock_weight * 0.88 + foot_blend * 0.35, 0.0, 1.0)));

	float base_rough = mix(clamp(texture(leaf_roughness, uv).r, 0.68, 0.96), 0.96, exposed);
	float rock_rough = mix(0.88, 0.72, seepage * 0.6);
	ROUGHNESS = mix(mix(base_rough, rock_rough, rock_weight), 0.52, snow_mask);
	SPECULAR = mix(mix(0.20, 0.28, rock_weight), 0.42, snow_mask);
}
