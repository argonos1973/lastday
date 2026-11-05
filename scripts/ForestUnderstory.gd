extends RefCounted
## Client-only, deterministic understory. Shared meshes and spatial batches.
const SHADER = preload("res://shaders/forest_understory.gdshader")

static func mesh_for(broad: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var fronds := 7 if not broad else 9
	for f in range(fronds):
		var angle := float(f) * 2.39996
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-sin(angle),0,cos(angle))
		var length := .52 + .19*sin(float(f)*1.7)
		if broad:
			var root := direction*.05 + Vector3.UP*.02
			var tip := direction*length + Vector3.UP*(.17 + .13*sin(float(f)*.8))
			leaf(st,root,tip,side,.09,Color(.25,.36,.13))
		else:
			var previous := Vector3.ZERO
			for j in range(1,10):
				var t := float(j)/10.0
				var center := direction*length*t + Vector3.UP*(.12 + .48*sin(t*PI*.75))
				leaf(st,previous,center,side,.006,Color(.25,.32,.11))
				previous = center
				var width := .16 * sin(t*PI) * (1.0-.45*t)
				for sign_value in [-1.0,1.0]:
					var tip: Vector3 = center + side*width*sign_value + direction*.075 + Vector3.DOWN*.025
					leaf(st,center,tip,direction,.026*(1.0-.65*t),Color(.20,.32,.105).lerp(Color(.34,.40,.17),t*.5))
	st.generate_normals()
	return st.commit()

static func bramble_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for branch in range(5):
		var angle := float(branch)*2.39996
		var direction := Vector3(cos(angle),0,sin(angle))
		var side := Vector3(-sin(angle),0,cos(angle))
		var previous := Vector3.ZERO
		for j in range(1,9):
			var t := float(j)/8.0
			var center := direction*(.35+.22*sin(float(branch)))*t + Vector3.UP*(sin(t*PI*.72)*.85)
			leaf(st,previous,center,side,.009,Color(.22,.18,.10))
			previous = center
			if j%2 == 0:
				for sign_value in [-1.0,1.0]:
					var tip: Vector3 = center + side*sign_value*.18 + direction*.10 + Vector3.UP*.04
					leaf(st,center,tip,direction,.065,Color(.18,.29,.10))
	st.generate_normals()
	return st.commit()

static func leaf(st: SurfaceTool, base: Vector3, tip: Vector3, side: Vector3, width: float, color: Color) -> void:
	# Rounded outline and a raised midrib: avoid diamond-shaped flat leaves.
	var steps := 6 if width > .04 else 3
	for segment in range(steps):
		var t0 := float(segment)/float(steps)
		var t1 := float(segment+1)/float(steps)
		var widths := Vector2(pow(sin(t0*PI),.75),pow(sin(t1*PI),.75))*width
		var c0 := base.lerp(tip,t0)
		var c1 := base.lerp(tip,t1)
		if width > .02:
			# Unequal, slightly curled leaf halves avoid a rigid symmetric silhouette.
			c0.y += width*(sin(t0*PI)*.25-t0*t0*.35)
			c1.y += width*(sin(t1*PI)*.25-t1*t1*.35)
		var asymmetry := 1.0 + .10*sin(base.x*17.0+base.y*23.0+base.z*11.0)
		var points := [c0-side*widths.x*asymmetry,c0+Vector3.UP*widths.x*.22,c0+side*widths.x/asymmetry,
			c1-side*widths.y*asymmetry,c1+Vector3.UP*widths.y*.22,c1+side*widths.y/asymmetry]
		for tri in [[0,1,3],[1,4,3],[1,2,4],[2,5,4]]:
			for index in tri:
				st.set_color(color * (1.06 if index%3 == 1 else 1.0))
				st.set_uv(Vector2(float(index%3)*.5,t0 if index<3 else t1))
				st.add_vertex(points[index])

static func build(world: Node3D, tree_positions: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = GameConst.WORLD_SEED ^ 0xFE471
	var batches: Dictionary = {}
	var quality := clampf(preload("res://scripts/GraphicsSettings.gd").detail_factor()/1.35,.3,1.0)
	var slice_start := Time.get_ticks_usec()
	for tree: Vector3 in tree_positions:
		# Stable per-tree samples keep quality settings from rearranging plants.
		if Time.get_ticks_usec() - slice_start >= 4000:
			await world.get_tree().process_frame
			slice_start = Time.get_ticks_usec()
		rng.seed = hash(tree) ^ 0xFE471
		if rng.randf() > .56: continue
		for i in range(4):
			var angle := rng.randf_range(0,TAU)
			var pos := tree + Vector3(cos(angle),0,sin(angle))*rng.randf_range(.8,5.5)
			var variant := rng.randi_range(0,2)
			var scale_value := rng.randf_range(.65,1.25)
			var yaw := rng.randf_range(0,TAU)
			var visible_sample := rng.randf()
			if visible_sample > quality: continue
			if not world._can_place_ground_vegetation(pos): continue
			if world._road_verge_growth(pos) < .45: continue
			if preload("res://scripts/HighMountainZone.gd").blocks_vegetation(pos) or preload("res://scripts/HighMountainZone.gd").on_road(pos,1.0): continue
			pos.y = world._get_exact_ground_y(pos.x,pos.z) + .005
			var key := Vector3i(floori(pos.x/24.0),floori(pos.z/24.0),variant)
			if not batches.has(key): batches[key] = []
			batches[key].append(Transform3D(Basis(Vector3.UP,yaw).scaled(Vector3.ONE*scale_value),pos))
	var meshes := [mesh_for(false),mesh_for(true),bramble_mesh()]
	var material := ShaderMaterial.new()
	material.shader = SHADER
	for key: Vector3i in batches:
		if Time.get_ticks_usec() - slice_start >= 4000:
			await world.get_tree().process_frame
			slice_start = Time.get_ticks_usec()
		var transforms: Array = batches[key]
		var node := MultiMeshInstance3D.new()
		node.name = "ForestUnderstory_%s_%s_%s" % [key.x,key.y,key.z]
		var origin := Vector3((key.x+.5)*24.0,0,(key.y+.5)*24.0)
		node.position = origin
		node.multimesh = MultiMesh.new()
		node.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		node.multimesh.mesh = meshes[key.z]
		node.multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			var t: Transform3D = transforms[i]
			t.origin -= origin
			node.multimesh.set_instance_transform(i,t)
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 80
		world.add_child(node)
