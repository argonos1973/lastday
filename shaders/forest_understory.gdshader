shader_type spatial;
render_mode cull_disabled, diffuse_burley;
varying float height;
void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
	height = VERTEX.y;
	float fade = 1.0-smoothstep(45.0,65.0,distance(CAMERA_POSITION_WORLD.xz,world.xz));
	VERTEX.x += sin(TIME*1.3+world.x*.6+world.z*.4)*.018*height;
	VERTEX.y *= fade;
}
void fragment() {
	ALBEDO = COLOR.rgb * mix(.78,1.05,clamp(height*2.0,0.0,1.0));
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = .88;
	SPECULAR = .16;
	BACKLIGHT = ALBEDO*.22;
}
