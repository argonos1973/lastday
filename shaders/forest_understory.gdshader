shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying float height;
varying float detail_fade;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	height = VERTEX.y;
	detail_fade = 1.0-smoothstep(5.0,18.0,distance(CAMERA_POSITION_WORLD,world));
	float fade = 1.0-smoothstep(45.0,65.0,distance(CAMERA_POSITION_WORLD.xz,world.xz));
	VERTEX.x += sin(TIME*1.3+world.x*.6+world.z*.4)*.018*height;
	VERTEX.y *= fade;
}
void fragment() {
	float leaf = step(COLOR.r*.95, COLOR.g);
	float mid_distance = abs(UV.x-.5);
	float midrib = 1.0-smoothstep(.009,.025+fwidth(UV.x),mid_distance);
	float branch_phase = UV.y*10.0-mid_distance*4.0;
	float branch_distance = abs(fract(branch_phase)-.5);
	float veins = 1.0-smoothstep(.035,.07+fwidth(branch_phase),branch_distance);
	veins *= smoothstep(.025,.08,mid_distance)*(1.0-smoothstep(.40,.49,mid_distance));
	float tissue = sin(UV.y*45.0+sin(UV.x*19.0))*sin(UV.x*37.0)*.025;
	float detail = (midrib*.12+veins*.055+tissue)*detail_fade*leaf;
	float edge = smoothstep(.34,.5,mid_distance)*leaf;
	vec3 pigment = mix(vec3(1.0),vec3(.94,.98,.86),edge*.35);
	ALBEDO = COLOR.rgb * pigment * (mix(.78,1.05,clamp(height*2.0,0.0,1.0))+detail);
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = mix(.94,.82,leaf)-midrib*.035*detail_fade;
	SPECULAR = .16;
	BACKLIGHT = ALBEDO*.22*leaf;
}
