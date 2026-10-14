shader_type spatial;
render_mode cull_disabled;

// Fur clothing: the crafted garment keeps the real hide of the hunted animal.
// Garment UVs were authored for cloth prints, so the hide texture is projected
// triplanar in model space — the pelt reads as fur on any mesh layout.
uniform sampler2D fur_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float fur_scale = 2.2;

varying vec3 lp;
varying vec3 ln;

void vertex() {
	// VERTEX here is the (bind/skin) model-space position — stable per mesh,
	// so the pelt pattern rides the garment instead of swimming on screen.
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	vec3 w = abs(normalize(ln));
	w /= (w.x + w.y + w.z + 0.0001);
	vec3 p = lp * fur_scale;
	vec3 fur = texture(fur_tex, p.zy).rgb * w.x
	         + texture(fur_tex, p.xz).rgb * w.y
	         + texture(fur_tex, p.xy).rgb * w.z;
	ALBEDO = fur * tint;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
