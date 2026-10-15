shader_type spatial;
render_mode cull_disabled;

// Fur clothing: the crafted garment wears the real hide of the hunted animal.
// In Godot 4, `VERTEX` in `vertex()` has already been multiplied by the skin
// matrix (`combined0` = 100x cm scale + 90 deg X rotation on Mixamo rigs, then
// canceled by `Armature`'s 0.01 scale in `MODEL_MATRIX`). Normalizing `lp` back
// to meter-space Y-up ensures the animal hide maps at real-world pelt scale
// (~1 hide across the chest/back) instead of tiling 100 times per meter.
uniform sampler2D fur_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float fur_scale = 1.15;

varying vec3 lp;
varying vec3 ln;

vec3 sample_fur(vec2 uv) {
	vec2 warp = vec2(
		sin(uv.y * 5.2 + uv.x * 3.1) * 0.03,
		cos(uv.x * 4.7 - uv.y * 2.6) * 0.04
	);
	vec3 a = texture(fur_tex, uv + warp).rgb;
	vec3 b = texture(fur_tex, uv * 1.57 + vec2(0.37, 0.61) - warp * 0.6).rgb;
	float blend = smoothstep(-0.35, 0.35, sin(uv.x * 3.8 + cos(uv.y * 2.9) * 1.4));
	return mix(a, b, blend * 0.32);
}

void vertex() {
	float m_scale = length(MODEL_MATRIX[0].xyz);
	if (m_scale < 0.05) {
		// Skinned Mixamo garment in cm Z-up space -> restore meter-space Y-up
		lp = vec3(VERTEX.x, VERTEX.z, -VERTEX.y) * 0.01;
		ln = normalize(vec3(NORMAL.x, NORMAL.z, -NORMAL.y));
	} else {
		lp = VERTEX;
		ln = normalize(NORMAL);
	}
}

void fragment() {
	vec3 n = normalize(ln);
	vec3 w = pow(abs(n), vec3(2.2));
	w /= (w.x + w.y + w.z + 0.0001);

	// Center X at 0.5 so the midline of the animal hide sits on the chest/spine
	// of the jacket, with hair flowing vertically (-lp.y).
	vec2 uv_z = vec2(lp.x * fur_scale + 0.5, -lp.y * fur_scale * 1.05);
	vec2 uv_x = vec2(lp.z * fur_scale + 0.5, -lp.y * fur_scale * 1.05);
	vec2 uv_y = vec2(lp.x * fur_scale + 0.5, lp.z * fur_scale + 0.5);

	vec3 fur = sample_fur(uv_x) * w.x
	         + sample_fur(uv_y) * w.y
	         + sample_fur(uv_z) * w.z;

	// Strand relief from the hide texture luminance so fur catches sunlight
	vec2 dom_uv = (w.z >= w.x && w.z >= w.y) ? uv_z : ((w.x >= w.y) ? uv_x : uv_y);
	float eps = 0.003;
	float h0 = dot(texture(fur_tex, dom_uv).rgb, vec3(0.333));
	float hx = dot(texture(fur_tex, dom_uv + vec2(eps, 0.0)).rgb, vec3(0.333)) - h0;
	float hy = dot(texture(fur_tex, dom_uv + vec2(0.0, eps)).rgb, vec3(0.333)) - h0;
	NORMAL = normalize(NORMAL + vec3(-hx * 2.4, -hy * 1.6, 0.0));

	float dorsal = mix(0.93, 1.04, smoothstep(0.0, 0.38, abs(lp.x)));
	ALBEDO = fur * tint * dorsal;
	ROUGHNESS = clamp(0.92 - (h0 - 0.45) * 0.22, 0.76, 0.98);
	SPECULAR = 0.18;
	RIM = 0.24;
	RIM_TINT = 0.65;
}
