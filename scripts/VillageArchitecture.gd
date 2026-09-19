extends RefCounted
## Static architectural details batched into three draws per house.

const TEXTURE_DIR := "res://assets/textures/overgrowth/village_"
const MOSS_MAX_HEIGHT := 0.85
const STYLES := [
	["lime", Color(1.0,0.99,0.94), "slate", 2.65, Color(0.38,0.49,0.37), 2, 5, false, -1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 1.55, Color(0.36,0.44,0.49), 3, 3, false, 1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 2.10, Color(0.45,0.35,0.26), 0, 4, false, -1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 2.85, Color(0.42,0.25,0.22), 1, 6, true, 1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 1.30, Color(0.27,0.38,0.43), 4, 3, false, 1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 2.35, Color(0.34,0.41,0.30), 2, 4, true, -1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 1.80, Color(0.46,0.34,0.23), 3, 6, true, -1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 2.50, Color(0.46,0.43,0.37), 1, 5, false, 1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 3.05, Color(0.28,0.36,0.29), 4, 4, true, -1.0],
	["lime", Color(1.0,0.99,0.94), "slate", 1.65, Color(0.49,0.43,0.32), 0, 2, false, 1.0],
]

static func profile(key: String) -> Dictionary:
	var suffix := key.get_slice("_", key.get_slice_count("_") - 1)
	if not suffix.is_valid_int():
		suffix = key.get_slice(" ", key.get_slice_count(" ") - 1)
	var index := posmod(int(suffix) - 1, STYLES.size()) if suffix.is_valid_int() else 0
	var row: Array = STYLES[index]
	return {"index": index, "wall": row[0], "tint": row[1], "roof": row[2], "rise": row[3], "wood": row[4], "porch": row[5], "slats": row[6], "timber": row[7], "chimney_side": row[8], "window_ratio": 0.85 + (index % 4) * 0.15}

static func material(kind: String, tint: Color = Color.WHITE, scale_value: float = 0.32) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(TEXTURE_DIR + kind + "_albedo.png")
	mat.normal_enabled = true
	mat.normal_texture = load(TEXTURE_DIR + kind + "_normal.png")
	mat.normal_scale = 0.65
	mat.roughness_texture = load(TEXTURE_DIR + kind + "_roughness.png")
	mat.roughness = 1.0
	mat.albedo_color = tint
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3.ONE * scale_value
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return mat

static func decorate(world: Node3D, origin: Vector3, label: String, width: float, depth: float, height: float, window_x: float, window_w: float, style: Dictionary = {}) -> void:
	if style.is_empty():
		style = profile(label)
	var root := Node3D.new()
	root.name = label + " Architecture"
	root.position = origin
	root.set_meta("house_style", style["index"])
	world.add_child(root)
	var stone: Array[Transform3D] = []
	var wood: Array[Transform3D] = []
	var metal: Array[Transform3D] = []
	var hw := width * 0.5
	var hd := depth * 0.5
	var rise: float = style["rise"]
	var course_h := 0.32 + int(style["index"]) % 3 * 0.08
	# Dressed corner stones and a continuous cornice give the walls depth.
	for x in [-hw, hw]:
		for z in [-hd, hd]:
			for course in range(int(height / course_h)):
				box(stone, Vector3(x, course_h * (course + 0.5), z), Vector3(0.43 if course % 2 == 0 else 0.36, course_h - 0.03, 0.43 if course % 2 == 1 else 0.36))
	for z in [-hd, hd]:
		box(stone, Vector3(0,height-0.22,z), Vector3(width+0.3,0.18,0.48))
	for x in [-hw, hw]:
		box(stone, Vector3(x,height-0.22,0), Vector3(0.48,0.18,depth))
		box(metal, Vector3(x + signf(x)*0.6,height-0.1,0), Vector3(0.16,0.14,depth+0.9))
		box(metal, Vector3(x+signf(x)*0.3,height*0.5,-hd-0.25), Vector3(0.10,height-0.2,0.10))
	# Roof edge boards follow the actual gable slope, with a ridge cap.
	var roof_half := hw + 0.6
	var slope := atan2(rise,roof_half)
	var length := Vector2(roof_half,rise).length()
	for z in [-hd-0.42,hd+0.42]:
		for side in [-1.0,1.0]:
			box(wood, Vector3(side*roof_half*0.5,height-0.1+rise*0.5,z), Vector3(length,0.14,0.14), -side*slope)
	box(metal, Vector3(0,height+rise-0.07,0), Vector3(0.20,0.12,depth+0.95))
	# Shutters flank the opening, never covering glass or the doorway.
	var window_h: float = window_w * style["window_ratio"]
	for center_x in [-window_x,window_x]:
		box(stone, Vector3(center_x,height*0.6-window_h*0.5-0.12,hd+0.24), Vector3(window_w+0.28,0.16,0.40))
		for side in [-1.0,1.0]:
			var sx: float = center_x + side*(window_w*0.5+0.25)
			var slats: int = style["slats"]
			for slat in range(slats):
				var slat_w := 0.42 / slats
				box(wood,Vector3(sx+(slat-(slats-1)*0.5)*slat_w,height*0.6,hd+0.23),Vector3(slat_w-0.012,window_h+0.12,0.08), side * 0.018 * (int(style["index"]) % 3))
			for sy in [-0.32,0.32]:
				box(metal,Vector3(sx,height*0.6+sy*window_h,hd+0.28),Vector3(0.40,0.045,0.035))
	var chimney_x: float = hw * 0.46 * style["chimney_side"]
	var chimney_top := height - 0.1 + rise * (1.0 - absf(chimney_x) / roof_half) + 0.95
	box(stone,Vector3(chimney_x,chimney_top,-hd*0.38),Vector3(0.84,0.14,0.84))
	if style["timber"]:
		for x in [-hw * 0.55, hw * 0.55]:
			box(wood,Vector3(x,height+rise*0.19,hd+0.46),Vector3(0.12,rise*0.35,0.10))
		box(wood,Vector3(0,height+rise*0.32,hd+0.46),Vector3(0.14,rise*0.7,0.10))
		box(wood,Vector3(0,height+0.04,hd+0.46),Vector3(width,0.15,0.10))
	var vent_y := height + rise * 0.42
	for i in range(3 + int(style["index"]) % 4):
		box(wood,Vector3(0,vent_y+i*0.09,hd+0.46),Vector3(0.65,0.06,0.10))
	porch(world, root, origin, label, width, hd, style, wood, stone)
	batch(root,"StoneTrim",stone,Color(0.70,0.68,0.63),0.95,material("stone",Color(0.90,0.88,0.82),0.42))
	batch(root,"Woodwork",wood,style["wood"],0.88,material("wood",style["wood"],0.55))
	batch(root,"RainwaterMetal",metal,Color(0.16,0.18,0.18),0.82)
	# World-aligned weathered plaster keeps texel scale continuous across
	# window cutouts; grime and ivy decals add the damp, overgrown decay.
	var wall := material(style["wall"], style["tint"], 0.18)
	var roof_mat := material(style["roof"], Color.WHITE, 0.42)
	var roof := world.get_node(label + " Roof") as MeshInstance3D
	finish_roof(roof, roof_mat, wall)
	for child in world.get_children():
		if child is StaticBody3D and str(child.name).begins_with(label+" "):
			for part in child.get_children():
				if part is MeshInstance3D and (" S" in str(child.name) or "Return" in str(child.name) or "DoorLintel" in str(child.name)):
					part.material_override = wall
				elif part is MeshInstance3D and " Chimney" in str(child.name):
					part.material_override = material("brick", Color(0.78,0.73,0.67))
		if child is MeshInstance3D and str(child.name).begins_with(label + " Foundation"):
			child.material_override = material("stone", Color(0.63,0.62,0.56))
	var door := world.get_node_or_null(label + " Door")
	if door != null:
		var door_mat := material("wood", style["wood"], 0.65)
		door_mat.uv1_world_triplanar = false
		for part in door.get_children():
			if part is MeshInstance3D and part.material_override is StandardMaterial3D and part.material_override.metallic < 0.4:
				part.material_override = door_mat

static func finish_roof(roof: MeshInstance3D, roof_mat: Material, wall_mat: Material) -> void:
	var arrays := roof.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	var count := indices.size() if not indices.is_empty() else vertices.size()
	var center := roof.mesh.get_aabb().get_center()
	center.y = roof.mesh.get_aabb().position.y + roof.mesh.get_aabb().size.y / 3.0
	var mesh := ArrayMesh.new()
	for is_roof in [true, false]:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for triangle in range(0, count, 3):
			var a := vertices[indices[triangle] if not indices.is_empty() else triangle]
			var b := vertices[indices[triangle+1] if not indices.is_empty() else triangle+1]
			var c := vertices[indices[triangle+2] if not indices.is_empty() else triangle+2]
			var normal := (c-a).cross(b-a).normalized()
			if normal.dot((a+b+c)/3.0-center) < 0.0:
				var swap := b
				b = c
				c = swap
				normal = -normal
			if (normal.y > 0.1) != is_roof:
				continue
			for vertex in [a, b, c]:
				surface.set_normal(normal)
				surface.set_uv(Vector2(vertex.x, -vertex.y) if absf(normal.z) > 0.9 else Vector2(vertex.z, vertex.x))
				surface.add_vertex(vertex)
		surface.generate_tangents()
		surface.set_material(roof_mat if is_roof else wall_mat)
		surface.commit(mesh)
	roof.mesh = mesh
	roof.material_override = null

static func porch(world: Node3D, root: Node3D, origin: Vector3, label: String, width: float, hd: float, style: Dictionary, wood: Array[Transform3D], stone: Array[Transform3D]) -> void:
	var kind: int = style["porch"]
	if kind == 0:
		return
	var span := minf(width - 0.7, 7.0) if kind == 3 else 3.3
	var depth := 1.65 if kind in [2, 3] else 1.2
	var top := 3.48
	for side in [-1.0, 1.0]:
		box(wood,Vector3(side*span*0.5,top*0.5,hd+depth),Vector3(0.15,top,0.15))
		box(stone,Vector3(side*span*0.5,0.12,hd+depth),Vector3(0.28,0.24,0.28))
	box(wood,Vector3(0,top-0.10,hd+depth),Vector3(span+0.2,0.17,0.16))
	if kind == 2:
		world._create_visual_gable_roof(label + " PorchRoof", origin + Vector3(0,top,hd+depth*0.5),span+0.4,depth+0.5,0.85,Color(0.2,0.2,0.2))
		var porch_roof := world.get_node(label + " PorchRoof") as MeshInstance3D
		finish_roof(porch_roof,material(style["roof"]),material("wood",style["wood"]))
	else:
		var rafters: Array[Transform3D] = []
		var slope := 0.18
		for i in range(5 + int(style["index"]) % 4):
			var x := -span*0.5 + span*i/float(4 + int(style["index"]) % 4)
			if kind == 4 and i % 3 == 1:
				continue
			var basis := Basis(Vector3.RIGHT,slope).scaled_local(Vector3(0.10,0.12,depth+0.4))
			rafters.append(Transform3D(basis,Vector3(x,top+0.12,hd+depth*0.5)))
		if kind != 4:
			var basis := Basis(Vector3.RIGHT,slope).scaled_local(Vector3(span+0.4,0.09,depth+0.5))
			rafters.append(Transform3D(basis,Vector3(0,top+0.21,hd+depth*0.5)))
		batch(root,"PorchCanopy",rafters,Color.WHITE,0.95,material("wood" if kind == 4 else style["roof"],Color(0.8,0.8,0.76)))
	if kind == 3:
		for side in [-1.0,1.0]:
			for i in range(4):
				box(wood,Vector3(side*(1.25+i*0.55),0.60,hd+depth),Vector3(0.07,1.0,0.08))
			box(wood,Vector3(side*(span*0.25+0.55),1.1,hd+depth),Vector3(span*0.5-1.1,0.08,0.10))

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

static func batch(root: Node3D, title: String, transforms: Array[Transform3D], color: Color, roughness: float, surface: Material = null) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mesh.material = surface if surface != null else mat
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
