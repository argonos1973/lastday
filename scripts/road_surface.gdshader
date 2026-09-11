shader_type spatial;
render_mode cull_disabled;

uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

float hash21(vec2 p) {
	return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);
}
float erosion(vec2 p) {
	vec2 i=floor(p);
	vec2 f=fract(p);
	f=f*f*(3.0-2.0*f);
	return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}

void fragment() {
	// UV2 is measured across the road and continuously along its full route.
	float across = UV2.x;
	float distance_along = UV2.y;
	vec3 grain = texture(aggregate, UV * 1.4).rgb;
	float detail = dot(grain, vec3(0.299, 0.587, 0.114));
	float wear = texture(aggregate, UV * 0.17 + vec2(0.31, 0.64)).g;
	vec3 asphalt = vec3(0.105,0.11,0.115) * (0.65 + detail * 1.1);
	float broad = erosion(UV*1.1);
	float chips = erosion(UV*12.0);
	float edge_damage = erosion(vec2(across*3.0,distance_along*0.38));
	float shoulder = smoothstep(0.64, 0.97, abs(across) + (edge_damage-0.45)*0.40 + (chips-0.5)*0.10);
	vec3 gravel = vec3(0.30,0.265,0.215) * (0.65 + detail);
	// Irregular repairs, soil pockets and thin wandering fractures.
	float patches = smoothstep(0.59,0.76,broad + (chips-0.5)*0.16);
	asphalt = mix(asphalt,vec3(0.19,0.17,0.135)*(0.7+detail),patches*0.8);
	float fracture_field = erosion(UV*2.2 + vec2(erosion(UV*5.0)) * 0.5);
	float fracture_width = max(fwidth(fracture_field),0.002);
	float cracks = (1.0-smoothstep(0.004,0.004+fracture_width,abs(fracture_field-0.48))) * smoothstep(0.36,0.6,broad);
	asphalt = mix(asphalt,vec3(0.025,0.022,0.018),cracks*0.8);
	float aa = max(fwidth(across), 0.0005);
	float center = 1.0-smoothstep(0.012-aa,0.012+aa,abs(across));
	float dash = 1.0-smoothstep(3.0,3.05,mod(distance_along,7.0));
	// Only scattered remnants of centre paint survive; no clean edge stripes.
	float paint_wear = smoothstep(0.48,0.7,erosion(UV*3.8)) * smoothstep(0.30,0.58,chips);
	float paint = center*dash*paint_wear*0.45;
	ALBEDO = mix(mix(asphalt,gravel,shoulder),vec3(0.68,0.65,0.54),paint);
	ROUGHNESS = mix(0.93,0.82,paint);
}
