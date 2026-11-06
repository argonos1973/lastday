extends RefCounted
## Low curled leaves supplement the canopy texture at walking distance.
static func build(world: Node3D, trees: Array) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Five broadleaf silhouettes (beach, oak, birch, aspen, linden-like)
	# cycle through the seven leaves of each cluster so every cluster mixes
	# shapes like real leaf litter. Local space: z+ is the tip, z- the stem.
	var outlines := [
		[Vector3(0,.004,-.115),Vector3(.026,.008,-.07),Vector3(.05,.012,-.01),Vector3(.042,.015,.05),Vector3(0,.018,.118),Vector3(-.042,.015,.05),Vector3(-.05,.012,-.01),Vector3(-.026,.008,-.07)],
		[Vector3(0,.005,-.105),Vector3(.032,.009,-.075),Vector3(.055,.013,-.025),Vector3(.052,.016,.03),Vector3(.032,.019,.085),Vector3(0,.02,.118),Vector3(-.032,.019,.085),Vector3(-.052,.016,.03),Vector3(-.055,.013,-.025),Vector3(-.032,.009,-.075)],
		[Vector3(0,.004,-.11),Vector3(.035,.008,-.085),Vector3(.062,.011,-.045),Vector3(.038,.014,-.015),Vector3(.065,.017,.025),Vector3(.04,.02,.06),Vector3(0,.021,.115),Vector3(-.04,.02,.06),Vector3(-.065,.017,.025),Vector3(-.038,.014,-.015),Vector3(-.062,.011,-.045),Vector3(-.035,.008,-.085)],
		[Vector3(0,.004,-.10),Vector3(.048,.009,-.055),Vector3(.06,.013,.005),Vector3(.028,.017,.095),Vector3(0,.019,.115),Vector3(-.028,.017,.095),Vector3(-.06,.013,.005),Vector3(-.048,.009,-.055)],
		[Vector3(0,.004,-.12),Vector3(.018,.007,-.08),Vector3(.03,.011,-.02),Vector3(.026,.015,.04),Vector3(0,.018,.12),Vector3(-.026,.015,.04),Vector3(-.03,.011,-.02),Vector3(-.018,.007,-.08)]
	]
	# Per-outline UV bounds so the procedural veins fit every silhouette.
	var uv_bounds: Array = []
	for o: Array in outlines:
		var minx := INF
		var maxx := -INF
		var minz := INF
		var maxz := -INF
		for p: Vector3 in o:
			minx = minf(minx, p.x)
			maxx = maxf(maxx, p.x)
			minz = minf(minz, p.z)
			maxz = maxf(maxz, p.z)
		uv_bounds.append([minx, maxx, minz, maxz])
	# Dried broadleaf tones cycle through the seven leaves of each cluster:
	# every cluster mixes dark umber, chestnut, straw, olive and russet like
	# real litter under the game's broadleaf trees. Vertex colors multiply
	# the per-instance tint, so clusters still vary in overall warmth.
	var leaf_tones := [
		Color(.34,.19,.09),Color(.50,.32,.14),Color(.60,.47,.23),
		Color(.42,.40,.18),Color(.56,.28,.11),Color(.64,.54,.32)
	]
	# Seven overlapping leaves per instance give a readable bed without seven
	# times as many terrain probes or instance transforms.
	for leaf in range(7):
		var outline: Array = outlines[leaf % outlines.size()]
		var bounds: Array = uv_bounds[leaf % outlines.size()]
		var angle := float(leaf)*2.399963
		var offset := Vector3(cos(angle),0,sin(angle))*.18*sqrt(float(leaf)/6.0)
		# Per-leaf yaw plus a small deterministic tilt so litter is not flat.
		var leaf_basis := Basis.from_euler(Vector3(sin(float(leaf)*2.13)*.28,angle,cos(float(leaf)*1.71)*.28))
		var leaf_scale := .60 + .42*float((leaf*37)%11)/10.0
		var lift := Vector3.UP*float(leaf%3)*.003
		var tone: Color = leaf_tones[leaf % leaf_tones.size()]*(.90+.10*float((leaf*13)%5)/4.0)
		for i in range(outline.size()):
			var a: Vector3 = outline[i]
			var b: Vector3 = outline[(i+1)%outline.size()]
			for raw: Vector3 in [Vector3(0,.02,0),b,a]:
				var u := clampf((raw.x-bounds[0])/(bounds[1]-bounds[0]),0.0,1.0)
				var v := clampf((raw.z-bounds[2])/(bounds[3]-bounds[2]),0.0,1.0)
				st.set_uv(Vector2(u,v))
				st.set_color(tone)
				st.add_vertex(leaf_basis*(raw*leaf_scale)+offset+lift)
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
	# Reuse one query and exclusion list: one probe gives both height and
	# normal, instead of five probes per cluster. Never clamp to the analytic
	# hill: its smoothed profile differs from the rendered mesh.
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	var excluded: Array[RID] = []
	for prop in world.get_tree().get_nodes_in_group("prop_collision"):
		if prop is CollisionObject3D: excluded.append(prop.get_rid())
	query.exclude = excluded
	var space := world.get_world_3d().direct_space_state
	var batches: Dictionary = {}
	var slice_start := Time.get_ticks_usec()
	for tree: Vector3 in trees:
		if Time.get_ticks_usec()-slice_start >= 10000:
			await world.get_tree().process_frame
			slice_start=Time.get_ticks_usec()
		var rng := RandomNumberGenerator.new()
		rng.seed=hash(tree)^0x1EAFF
		for i in range(72):
			var angle := rng.randf_range(0,TAU)
			var pos := tree+Vector3(cos(angle),0,sin(angle))*rng.randf_range(.3,4.0)
			var yaw := rng.randf_range(0,TAU)
			var scale_value := rng.randf_range(.65,1.3)
			# Near-white tint: vertex colors carry the leaf tones, this only
			# shifts each cluster's overall warmth/brightness a little.
			var color := Color(rng.randf_range(.86,1.0),rng.randf_range(.82,1.0),rng.randf_range(.76,1.0))
			if not world._can_place_ground_vegetation(pos): continue
			# Short probe around the analytic height: terrain cannot sit
			# farther than a few meters from it, so +-35 m always brackets it.
			var gy0: float = world._get_ground_height(pos)
			query.from = Vector3(pos.x,gy0+35,pos.z)
			query.to = Vector3(pos.x,gy0-35,pos.z)
			var hit := space.intersect_ray(query)
			var normal := Vector3.UP
			if not hit.is_empty():
				pos.y = hit.position.y + .018
				normal = hit.normal
			else:
				# Supports isolated previews without physics terrain.
				pos.y = world._get_ground_height(pos) + .018
				var dx: float = (world._get_ground_height(pos+Vector3(.15,0,0))-world._get_ground_height(pos-Vector3(.15,0,0)))/.3
				var dz: float = (world._get_ground_height(pos+Vector3(0,0,.15))-world._get_ground_height(pos-Vector3(0,0,.15)))/.3
				normal = Vector3(-dx,1,-dz).normalized()
			if normal.y < .64: continue
			var basis := Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,yaw)
			var key := Vector2i(floori(pos.x/16),floori(pos.z/16))
			if not batches.has(key): batches[key]=[]
			batches[key].append([Transform3D(basis.scaled(Vector3.ONE*scale_value),pos),color])
	for key: Vector2i in batches:
		if Time.get_ticks_usec()-slice_start >= 10000:
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
