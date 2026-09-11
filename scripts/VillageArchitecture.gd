extends RefCounted
## Static architectural details batched into three draws per house.

static func decorate(world: Node3D, origin: Vector3, label: String, width: float, depth: float, height: float, window_x: float, window_w: float) -> void:
	var root := Node3D.new()
	root.name = label + " Architecture"
	root.position = origin
	world.add_child(root)
	var stone: Array[Transform3D] = []
	var wood: Array[Transform3D] = []
	var metal: Array[Transform3D] = []
	var hw := width * 0.5
	var hd := depth * 0.5
	# Dressed corner stones and a continuous cornice give the walls depth.
	for x in [-hw, hw]:
		for z in [-hd, hd]:
			for course in range(int(height / 0.38)):
				box(stone, Vector3(x, 0.2 + course * 0.38, z), Vector3(0.52 if course % 2 == 0 else 0.42, 0.33, 0.52 if course % 2 == 1 else 0.42))
	for z in [-hd, hd]:
		box(stone, Vector3(0,height-0.22,z), Vector3(width+0.3,0.18,0.48))
	for x in [-hw, hw]:
		box(stone, Vector3(x,height-0.22,0), Vector3(0.48,0.18,depth))
		box(metal, Vector3(x + signf(x)*0.6,height-0.1,0), Vector3(0.16,0.14,depth+0.9))
		box(metal, Vector3(x+signf(x)*0.3,height*0.5,-hd-0.25), Vector3(0.10,height-0.2,0.10))
	# Roof edge boards follow the actual gable slope, with a ridge cap.
	var roof_half := hw + 0.6
	var slope := atan2(1.85,roof_half)
	var length := Vector2(roof_half,1.85).length()
	for z in [-hd-0.42,hd+0.42]:
		for side in [-1.0,1.0]:
			box(wood, Vector3(side*roof_half*0.5,height+0.825,z), Vector3(length,0.18,0.18), -side*slope)
	box(metal, Vector3(0,height+1.78,0), Vector3(0.24,0.16,depth+0.95))
	# Shutters flank the opening, never covering glass or the doorway.
	var window_h := window_w * 0.8
	for center_x in [-window_x,window_x]:
		box(stone, Vector3(center_x,height*0.6-window_h*0.5-0.12,hd+0.24), Vector3(window_w+0.28,0.16,0.40))
		for side in [-1.0,1.0]:
			var sx: float = center_x + side*(window_w*0.5+0.25)
			for slat in range(3):
				box(wood,Vector3(sx+(slat-1)*0.135,height*0.6,hd+0.23),Vector3(0.125,window_h+0.12,0.08))
			for sy in [-0.32,0.32]:
				box(metal,Vector3(sx,height*0.6+sy*window_h,hd+0.28),Vector3(0.40,0.045,0.035))
	box(stone,Vector3(hw*0.6,height+1.65,-hd*0.38),Vector3(0.84,0.14,0.84))
	batch(root,"StoneTrim",stone,Color(0.48,0.44,0.35),0.95)
	var palette := [Color(0.18,0.25,0.21),Color(0.25,0.30,0.32),Color(0.32,0.20,0.14)]
	batch(root,"Woodwork",wood,palette[absi(label.hash()) % palette.size()],0.88)
	batch(root,"RainwaterMetal",metal,Color(0.16,0.18,0.18),0.72)
	# World-aligned brick keeps texel scale continuous across window cutouts.
	# Use the moss-free brick set: plaster_brick_01 has broad green stains.
	var wall := StandardMaterial3D.new()
	wall.albedo_texture = load("res://assets/external/textures/red_brick_03/red_brick_03_diff_4k.jpg")
	wall.roughness_texture = load("res://assets/external/textures/red_brick_03/red_brick_03_rough_4k.jpg")
	wall.albedo_color = [Color(0.92,0.88,0.83),Color(0.85,0.82,0.78),Color(0.90,0.82,0.74)][absi(label.hash()) % 3]
	wall.uv1_triplanar = true
	wall.uv1_world_triplanar = true
	wall.uv1_scale = Vector3.ONE * 0.8
	wall.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	for child in world.get_children():
		if child is StaticBody3D and str(child.name).begins_with(label+" "):
			for part in child.get_children():
				if part is MeshInstance3D and (" S" in str(child.name) or "Return" in str(child.name) or "DoorLintel" in str(child.name)):
					part.material_override = wall

static func box(list: Array[Transform3D], pos: Vector3, size: Vector3, roll: float = 0.0) -> void:
	list.append(Transform3D(Basis(Vector3.FORWARD, -roll).scaled_local(size),pos))

static func interior(world: Node3D, origin: Vector3, label: String, width: float, depth: float, height: float) -> void:
	var root := Node3D.new()
	root.name = label + " InteriorFinish"
	root.position = origin
	world.add_child(root)
	var trim: Array[Transform3D] = []
	var plaster: Array[Transform3D] = []
	var hw := width * 0.5 - 0.22
	var hd := depth * 0.5 - 0.22
	# Low wainscoting sits below the windows; the entrance remains clear.
	for x in [-hw, hw]:
		box(plaster, Vector3(x,0.65,0),Vector3(0.04,1.1,depth-0.44))
		for y in [0.18,1.22]:
			box(trim,Vector3(x,y,0),Vector3(0.09,0.1,depth-0.44))
	box(plaster,Vector3(0,0.65,-hd),Vector3(width-0.44,1.1,0.04))
	for y in [0.18,1.22]:
		box(trim,Vector3(0,y,-hd),Vector3(width-0.44,0.1,0.09))
	# Ceiling and beams close off the underside of the roof.
	box(plaster,Vector3(0,height-0.12,0),Vector3(width-0.4,0.08,depth-0.4))
	for z in [-hd*0.65,0.0,hd*0.65]:
		box(trim,Vector3(0,height-0.23,z),Vector3(width-0.4,0.18,0.16))
	batch(root,"InteriorWood",trim,Color(0.30,0.21,0.14),0.9)
	batch(root,"WarmPlaster",plaster,Color(0.66,0.60,0.50),0.95)
	# Furnishings cannot be resolved from the opposite end of the village.
	# Only geometry is culled; sleep interactions and save nodes remain active.
	for suffix in [" Bed"," Furniture"," Fridge"," Toilet"," Sink"," Stove"," SinkCabinet"]:
		var furniture := world.get_node_or_null(NodePath(label + suffix))
		if furniture != null:
			limit_detail(furniture)

static func limit_detail(node: Node) -> void:
	if node is GeometryInstance3D:
		node.visibility_range_end = 65.0
		node.visibility_range_end_margin = 8.0
	for child in node.get_children():
		limit_detail(child)

static func batch(root: Node3D, title: String, transforms: Array[Transform3D], color: Color, roughness: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size(): mm.set_instance_transform(i,transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = title
	instance.multimesh = mm
	instance.visibility_range_end = 180.0
	root.add_child(instance)
