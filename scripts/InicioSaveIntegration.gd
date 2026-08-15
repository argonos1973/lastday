extends Node
class_name InicioSaveIntegration

static func maybe_insert_saved_character(inicio: Node) -> void:
	var sgm = inicio.get_node_or_null("/root/SaveGameManager")
	if sgm == null or not sgm.has_save():
		return
	var saved_cfg: Dictionary = sgm.get_saved_character_config()
	if saved_cfg.is_empty():
		return
	inicio.CHAR_CONFIGS.insert(0, saved_cfg)

static func update_saved_info(inicio: Node, cfg: Dictionary) -> void:
	_remove_existing_info(inicio)
	if not cfg.get("is_saved", false):
		return
	var sgm = inicio.get_node_or_null("/root/SaveGameManager")
	if sgm == null:
		return
	var player_data: Dictionary = sgm.get_saved_player()
	if player_data.is_empty():
		return
	var info_text := "Continuar partida\n"
	info_text += "Vida: %d  Comida: %d  Agua: %d" % [int(player_data.get("health", 100)), int(player_data.get("hunger", 100)), int(player_data.get("thirst", 100))]
	var lbl := Label.new()
	lbl.text = info_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.6))
	lbl.name = "SavedCharInfo"
	var char_panel = inicio._char_name_label.get_parent()
	if char_panel != null:
		char_panel.add_child(lbl)
		char_panel.move_child(lbl, inicio._char_name_label.get_index() + 1)

static func _remove_existing_info(inicio: Node) -> void:
	if inicio._char_name_label == null or not is_instance_valid(inicio._char_name_label):
		return
	var char_panel = inicio._char_name_label.get_parent()
	if char_panel == null:
		return
	var existing = char_panel.get_node_or_null("SavedCharInfo")
	if existing != null:
		existing.queue_free()

static func apply_saved_camo(gsess: Node, cfg: Dictionary) -> void:
	if not cfg.get("is_saved", false):
		return
	if cfg.get("top_camo", false):
		gsess.selected_top_color = Color(0.2, 0.25, 0.12)
		gsess.set_meta("top_camo", true)
	if cfg.get("bottom_camo", false):
		gsess.selected_bottom_color = Color(0.2, 0.25, 0.12)
		gsess.set_meta("bottom_camo", true)

static func apply_saved_equipment_preview(model: Node3D, cfg: Dictionary) -> void:
	var sgm = model.get_node_or_null("/root/SaveGameManager")
	if sgm == null:
		return
	var pd: Dictionary = sgm.get_saved_player()
	if pd.is_empty():
		return
	var eq := str(pd.get("equipped_clothing", ""))
	var equipped_items: Array = eq.split(",", false)
	# Build a map of item_name -> clothing_color from save inventory
	var inv_colors: Dictionary = {}
	var inv: Array = pd.get("inventory", [])
	for inv_item in inv:
		var iname := str(inv_item.get("name", ""))
		if inv_item.has("clothing_color"):
			var cc = inv_item["clothing_color"]
			if cc is Array and cc.size() >= 3:
				inv_colors[iname] = Color(float(cc[0]), float(cc[1]), float(cc[2]))
	# Determine what's equipped in each slot
	var torso_item := ""
	var legs_item := ""
	var feet_item := ""
	var hands_item := ""
	for it in equipped_items:
		var n := str(it).strip_edges()
		if n == "Camiseta" or n.find("Chaqueta") >= 0:
			torso_item = n
		elif n == "Pantalones" or n.find("Pantalones") >= 0:
			legs_item = n
		elif n == "Zapatillas" or n.find("Botas") >= 0:
			feet_item = n
		elif n.find("Guantes") >= 0:
			hands_item = n
	var has_torso := not torso_item.is_empty()
	var has_legs := not legs_item.is_empty()
	var has_feet := not feet_item.is_empty()
	# Default colors from character config
	var top_color: Color = cfg.get("top", Color(0.5, 0.5, 0.5))
	var bottom_color: Color = cfg.get("bottom", Color(0.3, 0.3, 0.3))
	var shoes_color: Color = cfg.get("shoes", Color(0.15, 0.15, 0.15))
	var skin_color: Color = cfg.get("skin", Color(0.8, 0.7, 0.6))
	# Override with inventory clothing_color if available
	if inv_colors.has(torso_item):
		top_color = inv_colors[torso_item]
	if inv_colors.has(legs_item):
		bottom_color = inv_colors[legs_item]
	if inv_colors.has(feet_item):
		shoes_color = inv_colors[feet_item]
	# Survival/military approximations on base meshes
	var is_survival_feet := feet_item == "Botas survival"
	var is_military_torso := torso_item.find("Chaqueta") >= 0
	var is_military_legs := legs_item.find("Pantalones m") >= 0
	# Determine which clothing meshes to show
	var show_tops := has_torso and (torso_item == "Camiseta")
	var show_bottoms := has_legs and (legs_item == "Pantalones")
	var show_shoes := has_feet and (feet_item == "Zapatillas")
	var show_cloth_feet := has_feet and is_survival_feet
	var show_soldier_torso := has_torso and is_military_torso
	var show_soldier_legs := has_legs and is_military_legs
	var meshes: Array = []
	_collect_meshes(model, meshes)
	for mi in meshes:
		var m := mi as MeshInstance3D
		var nl := m.name.to_lower()
		if nl == "tops":
			m.visible = show_tops
			if m.visible:
				_mat(m, top_color)
		elif nl == "bottoms":
			m.visible = show_bottoms
			if m.visible:
				_mat(m, bottom_color)
		elif nl == "shoes":
			m.visible = show_shoes
			if m.visible:
				_mat(m, shoes_color)
		elif nl == "cloth_feet":
			m.visible = show_cloth_feet
			if m.visible:
				_mat(m, Color(0.05, 0.05, 0.05))
		elif nl == "cloth_hands":
			m.visible = false
		elif nl == "body_hands":
			m.visible = hands_item.is_empty()
		elif nl == "body_feet":
			m.visible = not (has_feet and (is_survival_feet or feet_item == "Zapatillas"))
		elif nl == "body_torso":
			m.visible = not is_military_torso
		elif nl == "body_arms":
			m.visible = not is_military_torso
		elif nl == "body_legs":
			m.visible = not is_military_legs
		elif nl == "desnudo_torso":
			m.visible = false
			_extract_and_add_head_mesh(m, model, skin_color)
		elif nl.begins_with("desnudo_"):
			m.visible = false
		elif nl.begins_with("soldier_"):
			if nl == "soldier_torso":
				m.visible = show_soldier_torso
				if m.visible:
					_mat(m, Color(0.2, 0.25, 0.12))
			elif nl == "soldier_legs":
				m.visible = show_soldier_legs
				if m.visible:
					_mat(m, Color(0.2, 0.25, 0.12))
			else:
				m.visible = false
		elif nl == "cube":
			m.visible = false
		elif nl.begins_with("default"):
			m.visible = false
	# Add backpack
	var backpack := str(pd.get("equipped_backpack", ""))
	if not backpack.is_empty():
		_add_preview_backpack(model)
	# Add gloves
	if not hands_item.is_empty():
		_add_preview_gloves(model, hands_item)

const _SKIN_HIDES := {"Pantalones":["Desnudo_legs"],"Zapatillas":["Desnudo_feet"],"Botas survival":["Desnudo_feet"],"Guantes survival":["Desnudo_hands"],"Guantes militares":["Desnudo_hands"],"Pantalones militares":["Desnudo_legs"]}
const _BODY_HIDES := {"Zapatillas":["Body_feet"],"Botas survival":["Body_feet"],"Chaqueta militar":["Body_torso","Body_arms"],"Pantalones militares":["Body_legs"]}
const _DEF_CLOTH := {"Camiseta":"Tops","Pantalones":"Bottoms","Zapatillas":"Shoes"}
const _SURV_CLOTH := {"Botas survival":"cloth_feet","Guantes survival":"cloth_hands","Guantes militares":"cloth_hands","Chaqueta militar":"soldier_torso","Pantalones militares":"soldier_legs"}

static func _apply_equipment_overrides(meshes: Array, items: Array) -> void:
	var hide: Array = []
	for it in items:
		var n := str(it).strip_edges()
		if _SKIN_HIDES.has(n):
			for s in _SKIN_HIDES[n]:
				if not hide.has(s): hide.append(s)
		if _BODY_HIDES.has(n):
			for b in _BODY_HIDES[n]:
				if not hide.has(b): hide.append(b)
		if n == "Botas survival" and not hide.has("Shoes"):
			hide.append("Shoes")
		elif n.find("Chaqueta") >= 0 and not hide.has("Tops"):
			hide.append("Tops")
		elif n.find("Pantalones m") >= 0 and not hide.has("Bottoms"):
			hide.append("Bottoms")
		elif n.find("Pantalones c") >= 0 and not hide.has("Bottoms"):
			hide.append("Bottoms")
	for mi in meshes:
		var m := mi as MeshInstance3D
		if hide.has(m.name):
			m.visible = false

static func _mat(m: MeshInstance3D, c: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.8
	m.material_override = mat

static func _c(s: String) -> Color:
	var p := s.split(",")
	if p.size() >= 3:
		return Color(float(p[0]), float(p[1]), float(p[2]))
	return Color(0.5, 0.5, 0.5)

static func _collect_meshes(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for c in root.get_children():
		_collect_meshes(c, result)

const _BACKPACK_MODEL := "res://assets/external/realistic/root_glb/low_poly_game_ready_military_tactical_backpack.glb"

static func _add_preview_backpack(model: Node3D) -> void:
	var packed := load(_BACKPACK_MODEL)
	if packed == null or not packed is PackedScene:
		return
	var bp := (packed as PackedScene).instantiate() as Node3D
	if bp == null:
		return
	bp.name = "PreviewBackpack"
	bp.rotation_degrees = Vector3(0, 180, 0)
	model.add_child(bp)
	# Now that bp is in the tree, compute its AABB
	var raw_aabb := _hierarchy_local_aabb(bp)
	if raw_aabb.size.y <= 0.0001:
		bp.queue_free()
		return
	# Use exact same scale as in-game: 1.3 / raw_aabb.size.y
	var bp_scale := 1.3 / raw_aabb.size.y
	bp.scale = Vector3.ONE * bp_scale
	var center_offset := Vector3(
		-(raw_aabb.position.x + raw_aabb.size.x * 0.5) * bp_scale,
		-(raw_aabb.position.y + raw_aabb.size.y * 0.5) * bp_scale,
		-(raw_aabb.position.z + raw_aabb.size.z * 0.5) * bp_scale
	)
	bp.position = center_offset + Vector3(0.0, 2.6, -0.15)

const _PWC_MODEL := "res://assets/characters/adapted/player_with_clothes.glb"

static func _add_preview_gloves(model: Node3D, item_name: String) -> void:
	# Load player_with_clothes.glb to extract cloth_hands mesh
	var pwc_packed := load(_PWC_MODEL)
	if pwc_packed == null or not pwc_packed is PackedScene:
		return
	var pwc := (pwc_packed as PackedScene).instantiate() as Node3D
	if pwc == null:
		return
	# Find cloth_hands MeshInstance3D in pwc
	var cloth_hands_mi: MeshInstance3D = null
	var pwc_meshes: Array = []
	_collect_meshes(pwc, pwc_meshes)
	for mi in pwc_meshes:
		var m := mi as MeshInstance3D
		if m.name.to_lower() == "cloth_hands":
			cloth_hands_mi = m
			break
	if cloth_hands_mi == null:
		pwc.queue_free()
		return
	# Find Skeleton3D in inicio.glb model
	var target_skel: Skeleton3D = _find_skeleton(model)
	if target_skel == null:
		pwc.queue_free()
		return
	# Reparent cloth_hands to the main skeleton.
	# Both skeletons have identical bone rest poses (in centimeters), so the Skin works.
	var pwc_skel := cloth_hands_mi.get_parent()
	if pwc_skel != null:
		pwc_skel.remove_child(cloth_hands_mi)
	target_skel.add_child(cloth_hands_mi)
	cloth_hands_mi.skeleton = cloth_hands_mi.get_path_to(target_skel)
	cloth_hands_mi.visible = true
	# Free the rest of pwc
	pwc.queue_free()
	# Apply glove material
	var is_military := item_name.find("militar") >= 0
	var glove_color := Color(0.2, 0.2, 0.2) if is_military else Color(0.35, 0.25, 0.15)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = glove_color
	cloth_hands_mi.material_override = mat

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for c in root.get_children():
		var s := _find_skeleton(c)
		if s != null:
			return s
	return null

static func _find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var ap := _find_anim_player(c)
		if ap != null:
			return ap
	return null

static func _hierarchy_local_aabb(root: Node) -> AABB:
	var combined := AABB()
	var has_any := false
	if root is MeshInstance3D and (root as MeshInstance3D).mesh != null:
		combined = (root as MeshInstance3D).get_aabb()
		has_any = true
	var stack: Array = []
	for child in root.get_children():
		if child is Node3D:
			stack.append([child, (child as Node3D).transform])
	while not stack.is_empty():
		var entry = stack.pop_back()
		var node: Node3D = entry[0]
		var xform: Transform3D = entry[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var local_aabb: AABB = xform * (node as MeshInstance3D).get_aabb()
			if not has_any:
				combined = local_aabb
				has_any = true
			else:
				combined = combined.merge(local_aabb)
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, xform * (c as Node3D).transform])
	return combined

static func _find_mesh_by_name(root: Node, mesh_name: String) -> MeshInstance3D:
	if root is MeshInstance3D and root.name == mesh_name:
		return root as MeshInstance3D
	for c in root.get_children():
		var m := _find_mesh_by_name(c, mesh_name)
		if m != null:
			return m
	return null

static func _extract_and_add_head_mesh(_src_mi: MeshInstance3D, model: Node3D, skin_color: Color) -> void:
	var skeleton := _find_skeleton(model)
	if skeleton == null:
		return
	var src_scene := load("res://assets/animations/inicio.glb")
	if src_scene == null:
		return
	var src_instance := (src_scene as PackedScene).instantiate()
	var src_body: MeshInstance3D = _find_mesh_by_name(src_instance, "Body")
	if src_body == null or src_body.mesh == null:
		src_instance.queue_free()
		return
	var mesh_res := src_body.mesh
	if mesh_res.get_surface_count() == 0:
		src_instance.queue_free()
		return
	var orig_mat := mesh_res.surface_get_material(0)
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(mesh_res, 0)
	var head_faces: PackedInt32Array = []
	for face_idx in range(mdt.get_face_count()):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(face_idx, 2))
		var cy := (v0.y + v1.y + v2.y) / 3.0
		var cx := (v0.x + v1.x + v2.x) / 3.0
		if cy >= 3.0 and absf(cx) < 0.4:
			head_faces.append(face_idx)
	if head_faces.is_empty():
		src_instance.queue_free()
		return
	var verts: PackedVector3Array = []
	var normals: PackedVector3Array = []
	var uvs: PackedVector2Array = []
	var bones_arr: PackedInt32Array = []
	var weights_arr: PackedFloat32Array = []
	var indices: PackedInt32Array = []
	var vert_map := {}
	for face_idx in head_faces:
		for fv in range(3):
			var orig_vi := mdt.get_face_vertex(face_idx, fv)
			var key := orig_vi
			if not vert_map.has(key):
				var new_idx := verts.size()
				vert_map[key] = new_idx
				verts.append(mdt.get_vertex(orig_vi))
				normals.append(mdt.get_vertex_normal(orig_vi))
				uvs.append(mdt.get_vertex_uv(orig_vi))
				var bs: PackedInt32Array = mdt.get_vertex_bones(orig_vi)
				var ws: PackedFloat32Array = mdt.get_vertex_weights(orig_vi)
				for b in range(4):
					if b < bs.size():
						bones_arr.append(bs[b])
					else:
						bones_arr.append(0)
				for w in range(4):
					if w < ws.size():
						weights_arr.append(ws[w])
					else:
						weights_arr.append(0.0)
			indices.append(vert_map[key])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_BONES] = bones_arr
	arrays[Mesh.ARRAY_WEIGHTS] = weights_arr
	arrays[Mesh.ARRAY_INDEX] = indices
	var head_mesh := ArrayMesh.new()
	head_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if head_mesh.get_surface_count() > 0 and orig_mat != null:
		head_mesh.surface_set_material(0, orig_mat)
	# Duplicate src_body to preserve its Skin resource, then replace mesh
	var head_mi := src_body.duplicate() as MeshInstance3D
	if head_mi == null:
		src_instance.queue_free()
		return
	head_mi.name = "HeadMesh"
	head_mi.mesh = head_mesh
	head_mi.visible = true
	skeleton.add_child(head_mi)
	head_mi.skeleton = head_mi.get_path_to(skeleton)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = skin_color
	mat.roughness = 0.8
	head_mi.material_override = mat
	src_instance.queue_free()
