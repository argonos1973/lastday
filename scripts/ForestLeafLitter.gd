extends RefCounted
## Low curled leaves supplement the canopy texture at walking distance.
static func build(world: Node3D, trees: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [Vector3(0,0,-.12),Vector3(-.055,0,-.035),Vector3(-.045,.008,.055),Vector3(0,.015,.12),Vector3(.045,.008,.055),Vector3(.055,0,-.035)]
	# Seven overlapping leaves per instance give a readable bed without seven
	# times as many terrain probes or instance transforms.
	for leaf in range(7):
		var angle := float(leaf)*2.399963
		var offset := Vector3(cos(angle),0,sin(angle))*.18*sqrt(float(leaf)/6.0)
		var rotation := Basis(Vector3.UP,angle)
		for i in range(outline.size()):
			for point: Vector3 in [Vector3(0,.018,0),outline[(i+1)%outline.size()],outline[i]]:
				st.set_uv(Vector2(point.x/.12+.5,point.z/.24+.5))
				st.add_vertex(rotation*point+offset+Vector3.UP*float(leaf%3)*.003)
	st.generate_normals()
	var mesh := st.commit()
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode cull_disabled;
varying vec4 tint;
void vertex(){tint=COLOR;}
void fragment(){
 float vein=1.0-smoothstep(.012,.035,abs(UV.x-.5));
 float ribs=pow(max(0.0,cos((UV.y-abs(UV.x-.5)*.65)*85.0)),16.0);
 ALBEDO=tint.rgb*mix(.75,1.15,UV.y)+vec3(.06,.035,.012)*(vein+ribs*.3);
 ROUGHNESS=.94;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	var batches: Dictionary = {}
	var slice_start := Time.get_ticks_usec()
	for tree: Vector3 in trees:
		if Time.get_ticks_usec()-slice_start >= 30000:
			await world.get_tree().process_frame
			slice_start=Time.get_ticks_usec()
		var rng := RandomNumberGenerator.new()
		rng.seed=hash(tree)^0x1EAFF
		for i in range(64):
			var angle := rng.randf_range(0,TAU)
			var pos := tree+Vector3(cos(angle),0,sin(angle))*rng.randf_range(.4,2.8)
			var yaw := rng.randf_range(0,TAU)
			var scale_value := rng.randf_range(.65,1.3)
			var color := Color(.29,.15,.065).lerp(Color(.52,.36,.16),rng.randf())
			if not world._can_place_ground_vegetation(pos): continue
			# Analytic terrain height: identical to the raycast on open forest
			# floor but ~100x cheaper — this runs ~850k times during world gen.
			var gy: float = world._get_ground_height(pos)
			var dx: float = (world._get_ground_height(pos+Vector3(.15,0,0))-world._get_ground_height(pos-Vector3(.15,0,0)))/.3
			var dz: float = (world._get_ground_height(pos+Vector3(0,0,.15))-world._get_ground_height(pos-Vector3(0,0,.15)))/.3
			if Vector2(dx,dz).length()>1.2: continue
			pos.y=gy+.012
			var normal := Vector3(-dx,1,-dz).normalized()
			var basis := Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,yaw)
			var key := Vector2i(floori(pos.x/16),floori(pos.z/16))
			if not batches.has(key): batches[key]=[]
			batches[key].append([Transform3D(basis.scaled(Vector3.ONE*scale_value),pos),color])
	for key: Vector2i in batches:
		if Time.get_ticks_usec()-slice_start >= 30000:
			await world.get_tree().process_frame
			slice_start=Time.get_ticks_usec()
		var node := MultiMeshInstance3D.new()
		node.name="ForestLeafLitter_%s_%s"%[key.x,key.y]
		node.position=Vector3((key.x+.5)*16,0,(key.y+.5)*16)
		node.multimesh=MultiMesh.new()
		node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
		node.multimesh.use_colors=true
		node.multimesh.mesh=mesh
		node.multimesh.instance_count=batches[key].size()
		for i in range(batches[key].size()):
			var transform: Transform3D=batches[key][i][0]
			transform.origin-=node.position
			node.multimesh.set_instance_transform(i,transform)
			node.multimesh.set_instance_color(i,batches[key][i][1])
		node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end=55
		world.add_child(node)
