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
	var survival_seconds: float = float(player_data.get("survival_seconds", 0.0))
	var total_seconds: int = int(survival_seconds)
	var days: int = total_seconds / 86400
	var hrs: int = (total_seconds / 3600) % 24
	var mins: int = (total_seconds / 60) % 60
	if days > 0:
		info_text += "Supervivencia: Dia %d - %02d:%02d" % [days + 1, hrs, mins]
	else:
		info_text += "Supervivencia: %02d:%02d:%02d" % [hrs, mins, total_seconds % 60]
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
	var _removed_items := ["Chaqueta militar", "Chaqueta militar azul", "Chaqueta militar negra II"]
	var _filtered_eq: Array = []
	for _s in eq.split(",", false):
		var _sn := str(_s).strip_edges()
		if not _sn.is_empty() and _sn not in _removed_items:
			_filtered_eq.append(_sn)
	var equipped_items: Array = _filtered_eq
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
	var head_item := ""
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
		elif n.find("Sombrero") >= 0:
			head_item = n
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
	var is_military_legs := legs_item.find("Pantalones m") >= 0
	# Determine which clothing meshes to show
	var show_tops := has_torso and (torso_item == "Camiseta")
	var show_bottoms := has_legs and (legs_item == "Pantalones")
	var show_shoes := has_feet and (feet_item == "Zapatillas")
	var show_cloth_feet := has_feet and is_survival_feet
	var show_soldier_legs := has_legs and is_military_legs
	var meshes: Array = []
	_collect_meshes(model, meshes)
	for mi in meshes:
		var m := mi as MeshInstance3D
		var nl := m.name.to_lower()
		if nl == "tops":
			m.visible = show_tops
			if m.visible:
				if bool(cfg.get("top_camo", false)):
					_mat_camo(m)
				else:
					_mat(m, top_color)
		elif nl == "bottoms":
			m.visible = show_bottoms
			if m.visible:
				if bool(cfg.get("bottom_camo", false)):
					_mat_camo(m)
				else:
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
			m.visible = false
		elif nl == "body_feet":
			m.visible = has_feet and (is_survival_feet or feet_item == "Zapatillas")
		elif nl == "body_torso":
			m.visible = has_torso
		elif nl == "body_arms":
			m.visible = has_torso
		elif nl == "body_legs":
			m.visible = has_legs and not is_military_legs
		elif nl == "desnudo_torso":
			m.visible = not has_torso
			if m.visible:
				_mat(m, skin_color)
			_extract_and_add_head_mesh(m, model, skin_color)
		elif nl == "desnudo_arms":
			m.visible = not has_torso
			if m.visible:
				_mat(m, skin_color)
		elif nl == "desnudo_legs":
			m.visible = not (has_legs or is_military_legs)
			if m.visible:
				_mat(m, skin_color)
		elif nl == "desnudo_feet":
			m.visible = not (has_feet and (is_survival_feet or feet_item == "Zapatillas"))
			if m.visible:
				_mat(m, skin_color)
		elif nl == "desnudo_hands":
			m.visible = hands_item.is_empty()
			if m.visible:
				_mat(m, skin_color)
		elif nl.begins_with("desnudo_"):
			m.visible = false
		elif nl.begins_with("soldier_"):
			if nl == "soldier_legs":
				m.visible = show_soldier_legs
				if m.visible and legs_item.find("militares ") >= 0:
					_mat(m, _MILITARY_TINTS.get(legs_item, Color(0.2, 0.25, 0.12)))
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
	# Add hat
	if not head_item.is_empty():
		_add_preview_hat(model, head_item)
	# Add held item (weapon/tool in hand)
	var held_item_name := str(pd.get("held_item", ""))
	if held_item_name == "Cuchillo":
		_add_preview_knife(model)

const _SKIN_HIDES := {"Pantalones":["Desnudo_legs"],"Zapatillas":["Desnudo_feet"],"Botas survival":["Desnudo_feet"],"Guantes survival":["Desnudo_hands"],"Guantes militares":["Desnudo_hands"],"Pantalones militares":["Desnudo_legs"]}
const _BODY_HIDES := {"Zapatillas":["Body_feet"],"Botas survival":["Body_feet"],"Pantalones militares":["Body_legs"]}
const _DEF_CLOTH := {"Camiseta":"Tops","Pantalones":"Bottoms","Zapatillas":"Shoes"}
const _SURV_CLOTH := {"Botas survival":"cloth_feet","Guantes survival":"cloth_hands","Guantes militares":"cloth_hands","Pantalones militares":"soldier_legs"}

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

static var _camo_texture_cache: Dictionary = {}

static func _make_camo_texture(base_color: Color = Color(0.25, 0.3, 0.15)) -> ImageTexture:
	var cache_key := str(base_color)
	if _camo_texture_cache.has(cache_key):
		return _camo_texture_cache[cache_key]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var camo_colors := [base_color, base_color.darkened(0.3), base_color.lightened(0.2), base_color.darkened(0.5)]
	img.fill(camo_colors[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for blob in range(40):
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var radius := rng.randi_range(8, 25)
		var color: Color = camo_colors[rng.randi() % camo_colors.size()]
		for x in range(maxi(0, cx - radius), mini(size, cx + radius)):
			for y in range(maxi(0, cy - radius), mini(size, cy + radius)):
				var dx := x - cx
				var dy := y - cy
				if dx * dx + dy * dy <= radius * radius:
					img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_camo_texture_cache[cache_key] = tex
	return tex

static func _mat_camo(m: MeshInstance3D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _make_camo_texture()
	mat.albedo_color = Color.WHITE
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

const _MILITARY_TINTS := {
	"Pantalones militares azules": Color(0.02, 0.04, 0.08),
	"Pantalones militares negros II": Color(0.02, 0.02, 0.03),
}

const _HAT_MODEL := "res://assets/external/polyhaven/fishermans_hat/fishermans_hat_1k.gltf"
const _KNIFE_MODEL := "res://assets/external/quaternius_zombie_apocalypse/Weapons/glTF/Knife.gltf"

static func _add_preview_hat(model: Node3D, item_name: String) -> void:
	if item_name != "Sombrero de pescador":
		return
	var packed := load(_HAT_MODEL)
	if packed == null or not packed is PackedScene:
		return
	var hat := (packed as PackedScene).instantiate() as Node3D
	if hat == null:
		return
	hat.name = "PreviewHat"
	var body_meshes: Array = []
	_collect_meshes(model, body_meshes)
	var bmin := Vector3(999999.0, 999999.0, 999999.0)
	var bmax := Vector3(-999999.0, -999999.0, -999999.0)
	var has_body := false
	for mi in body_meshes:
		var m := mi as MeshInstance3D
		if not m.visible or m.mesh == null:
			continue
		var aabb: AABB = m.get_aabb()
		bmin.x = min(bmin.x, aabb.position.x)
		bmin.y = min(bmin.y, aabb.position.y)
		bmin.z = min(bmin.z, aabb.position.z)
		bmax.x = max(bmax.x, aabb.position.x + aabb.size.x)
		bmax.y = max(bmax.y, aabb.position.y + aabb.size.y)
		bmax.z = max(bmax.z, aabb.position.z + aabb.size.z)
		has_body = true
	if not has_body:
		hat.queue_free()
		return
	var body_size := bmax - bmin
	model.add_child(hat)
	var item_aabb := _hierarchy_local_aabb(hat)
	if item_aabb.size.y > 0.001:
		var target: float = 0.06 * body_size.y
		hat.scale = Vector3.ONE * (target / item_aabb.size.y)
	item_aabb = _hierarchy_local_aabb(hat)
	var anchor := Vector3(
		bmin.x + body_size.x * 0.5,
		bmin.y + 0.94 * body_size.y,
		bmin.z + body_size.z * 0.5 + 0.04 * body_size.z
	)
	var item_center := item_aabb.position + item_aabb.size * 0.5
	item_center.y = item_aabb.position.y
	hat.position = anchor - item_center

static func _add_preview_knife(model: Node3D) -> void:
	var packed := load(_KNIFE_MODEL)
	if packed == null or not packed is PackedScene:
		return
	var knife := (packed as PackedScene).instantiate() as Node3D
	if knife == null:
		return
	knife.name = "PreviewKnife"
	var skel := _find_skeleton(model)
	if skel == null:
		knife.queue_free()
		return
	var hand_bone_idx := -1
	for bone_name in ["mixamorig:RightHand", "mixamorig_RightHand", "RightHand"]:
		hand_bone_idx = skel.find_bone(bone_name)
		if hand_bone_idx != -1:
			break
	if hand_bone_idx == -1:
		knife.queue_free()
		return
	skel.add_child(knife)
	var bone_pose := skel.get_bone_global_pose(hand_bone_idx)
	knife.transform = bone_pose
	knife.scale = Vector3.ONE * 0.55
	knife.position += Vector3(0.10, 0.0, -0.10)

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
