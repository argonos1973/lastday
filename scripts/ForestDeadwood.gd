extends RefCounted
## Thin fallen deadwood, kept low enough to be floor dressing, not a new obstacle.
static func mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(preload("res://scripts/MaterialFactory.gd").make_log_bark_material())
	for ring in range(5):
		for side in range(12):
			for ij in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
				var along := float(ring+ij.x)/5.0
				var angle := float(side+ij.y)/12.0*TAU
				var radius := lerpf(.08,.035,along)*(1.0+.12*sin(angle*3.0+along*4.0))
				st.set_uv(Vector2(along*2.0,float(side+ij.y)/12.0))
				st.add_vertex(Vector3((along-.5)*2.4,cos(angle)*radius,sin(angle)*radius))
	st.generate_normals()
	var result := st.commit()
	st.clear()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var end_material: ShaderMaterial = preload("res://scripts/MaterialFactory.gd").make_log_end_material().duplicate()
	var end_shader := Shader.new()
	end_shader.code = end_material.shader.code.replace("vec2 p = lpos.xz * 6.5", "vec2 p = (UV - vec2(.5)) * 1.6")
	end_material.shader = end_shader
	st.set_material(end_material)
	for end in [0.0,1.0]:
		for side in range(12):
			for corner in ([-1,side,side+1] if end == 0.0 else [-1,side+1,side]):
				var angle := float(corner)/12.0*TAU
				var radius := lerpf(.08,.035,end)*(1.0+.12*sin(angle*3.0+end*4.0)) if corner>=0 else 0.0
				st.set_uv(Vector2(.5,.5)+Vector2(cos(angle),sin(angle))*.48*(1.0 if corner>=0 else 0.0))
				st.add_vertex(Vector3((end-.5)*2.4,cos(angle)*radius,sin(angle)*radius))
	st.generate_normals()
	st.commit(result)
	return result

static func build(world: Node3D, trees: Array) -> void:
	var batches: Dictionary = {}
	for tree: Vector3 in trees:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(tree)^0xDEA01
		if rng.randf() > .035: continue
		var center := tree + Vector3(rng.randf_range(-3,3),0,rng.randf_range(-3,3))
		var angle := rng.randf_range(0,TAU)
		var axis := Vector3(cos(angle),0,sin(angle))
		var a := center-axis*1.2
		var b := center+axis*1.2
		var valid := true
		for point in [a,center,b]:
			if not world._can_place_ground_vegetation(point) or world._road_verge_growth(point)<.95: valid=false
		if not valid: continue
		a.y = world._get_exact_ground_y(a.x,a.z)
		b.y = world._get_exact_ground_y(b.x,b.z)
		var ground: float = world._get_exact_ground_y(center.x,center.z)
		# Reject uneven beds rather than leaving the wood suspended in mid-air.
		if absf((a.y+b.y)*.5-ground)>.06 or absf(a.y-b.y)>.65: continue
		center.y = (a.y+b.y)*.5+.025
		var x := (b-a).normalized()
		var z := x.cross(Vector3.UP).normalized()
		var basis := Basis(x,z.cross(x).normalized(),z)
		var key := Vector2i(floori(center.x/32.0),floori(center.z/32.0))
		if not batches.has(key): batches[key]=[]
		batches[key].append(Transform3D(basis,center))
	var source := mesh()
	for key: Vector2i in batches:
		var node := MultiMeshInstance3D.new()
		node.name = "ForestDeadwood_%s_%s"%[key.x,key.y]
		node.position = Vector3((key.x+.5)*32,0,(key.y+.5)*32)
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = source
		node.multimesh.instance_count = batches[key].size()
		for i in range(batches[key].size()):
			var transform: Transform3D = batches[key][i]
			transform.origin -= node.position
			node.multimesh.set_instance_transform(i,transform)
		node.visibility_range_end = 85
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(node)
