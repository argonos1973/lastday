extends RefCounted

# Meshes hidden while the item is worn (name prefixes). The helmet is modelled
# with its harness and chin strap hanging open for display on the ground, but
# worn they would clip through the jaw — they are excluded from fit bounds and
# made invisible. Dropped/pickup copies keep the full detail.
const WORN_HIDE := {
	"Casco militar": ["Front harness", "Rear harness", "Chin support strap", "Chin comfort pad",
		"Strap adjuster", "Adjuster opening", "Removable suspension pad", "Crown comfort pad"],
	"Pasamontañas": ["Hair"],
	"Pasamontañas navideño": ["Hair"],
}
# Hair tuck depth per item, as a fraction of head height applied to the brim
# line (positive raises the tuck, negative lowers it inside the skull volume).
# The helmet swallows the whole scalp, so hair collapses down into the head
# instead of just under the rim — no tufts can poke through the shell.
const TUCK_DROP := {
	"Sombrero de pescador": 0.02,
	"Casco militar": -0.23,
	"Tocado de piel animal": -0.28,
}
# Items that bury the scalp also pull the collapsed hair verts inward, so the
# squashed layer stays inside the skull instead of ringing the face.
const TUCK_SHRINK := {
	"Sombrero de pescador": 0.0,
	"Casco militar": 0.72,
	"Tocado de piel animal": 0.68,
}

# Shared by the saved-character preview and the animated actor.
static func fit_pelt(model: Node3D, hat: Node3D, species: String = "") -> bool:
	return seat_on_scalp(model, hat, "Tocado de piel animal", 0.52, 0.35, species)

# Bind-space cloth, shared by the character and saved-game preview.
static func fit_face(model: Node3D, wrapper: Node3D, _item_name: String) -> bool:
	var head := model.find_child("HeadMesh", true, false) as MeshInstance3D
	if head == null or head.mesh == null or wrapper.get_parent() == null:
		return false
	# These adapted meshes are authored directly in the character head bind
	# frame by adapt_balaclavas.py; no generic AABB scaling or axis guesswork.
	if wrapper.find_child("FaceFittedBind", true, false) == null:
		return false
	wrapper.transform = _head_frame(model, head, wrapper.get_parent() as Node3D)
	for mesh_name in ["Hair", "GrowingBeard"]:
		for mesh in model.find_children(mesh_name, "MeshInstance3D", true, false):
			if not mesh.has_meta("headwear_original_visible"):
				mesh.set_meta("headwear_original_visible", mesh.visible)
			mesh.visible = false
	return true

# Seats a headpiece whose GLB is authored with the scalp seat at the local
# origin and the trophy rising +Y (the pelt tocados): scales it to
# `fit_height` and puts the origin on top of the head, centered on the scalp.
# Unlike fit(), the animal head keeps its authored size relative to the human
# head instead of being squashed onto the crown.
static func seat_on_scalp(model: Node3D, hat: Node3D, item_name: String, fit_height: float, sink: float = 0.06, species: String = "") -> bool:
	var head := model.find_child("HeadMesh", true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return false
	var parent := hat.get_parent() as Node3D
	if parent == null:
		return false
	var head_bounds := head.get_aabb()
	var scalp := upper_bounds(head, Transform3D.IDENTITY, head_bounds.end.y - head_bounds.size.y * 0.34)
	if scalp.size.x <= 0.001 or scalp.size.z <= 0.001:
		return false
	hat.transform = Transform3D.IDENTITY
	var raw := AABB()
	var first := true
	for mesh in hat.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		var frame: Transform3D = hat.global_transform.affine_inverse() * mesh.global_transform
		var bounds: AABB = frame * mesh.get_aabb()
		raw = bounds if first else raw.merge(bounds)
		first = false
	if first or raw.size.y <= 0.001:
		return false
	# The trophy rises above the GLB origin (the throat seat); the pelt sheet
	# hangs below it. Scale by the part above the seat so the animal head
	# keeps its authored size relative to the wearer regardless of pelt length.
	var above := maxf(raw.end.y, 0.001)
	var s := fit_height / above
	var center := scalp.get_center()
	var seat_y := head_bounds.end.y - head_bounds.size.y * sink
	# Seating the upper lip arch right above the eyebrows frames the forehead
	# and eyes like the reference wolf/bear tocados.
	var raise := head_bounds.size.y * 0.048
	# Animal GLBs face -Z; the character bind mesh faces +Z.
	# Rotate in bind space before composing the animated head frame.
	var pitched := Basis.from_euler(Vector3(0.0, PI, 0.0)) * Basis.from_scale(Vector3.ONE * s)
	var in_head := Transform3D(pitched,
		Vector3(center.x, seat_y + raise, center.z + head_bounds.size.z * 0.22))
	hat.transform = _head_frame(model, head, parent) * in_head
	var tuck := float(TUCK_DROP.get(item_name, 0.02))
	var shrink := float(TUCK_SHRINK.get(item_name, 0.0))
	_tuck_hair(model, seat_y + head_bounds.size.y * tuck, shrink)
	return true

# These character meshes contain baked bind-pose coordinates. Use only the
# scalp, never whole-body bounds (arms, footwear and export helpers vary).
static func fit(model: Node3D, hat: Node3D, item_name: String = "") -> bool:
	var head := model.find_child("HeadMesh", true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return false
	var parent := hat.get_parent() as Node3D
	if parent == null:
		return false
	for mesh in hat.find_children("*", "MeshInstance3D", true, false):
		for prefix in WORN_HIDE.get(item_name, []):
			if String(mesh.name).begins_with(prefix):
				mesh.visible = false
	var head_bounds := head.get_aabb()
	var scalp := upper_bounds(head, Transform3D.IDENTITY, head_bounds.end.y - head_bounds.size.y * 0.34)
	if scalp.size.x <= 0.001 or scalp.size.z <= 0.001:
		return false
	hat.transform = Transform3D.IDENTITY
	var raw := AABB()
	var first := true
	for mesh in hat.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		var frame: Transform3D = hat.global_transform.affine_inverse() * mesh.global_transform
		var bounds: AABB = frame * mesh.get_aabb()
		raw = bounds if first else raw.merge(bounds)
		first = false
	if first or raw.size.y <= 0.001:
		return false
	# Measure the crown above the brim, so brim width cannot determine head fit.
	var crown := AABB()
	first = true
	for mesh in hat.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible:
			continue
		var frame: Transform3D = hat.global_transform.affine_inverse() * mesh.global_transform
		var bounds := upper_bounds(mesh, frame, raw.position.y + raw.size.y * 0.45)
		if bounds.size.length_squared() == 0.0:
			continue
		crown = bounds if first else crown.merge(bounds)
		first = false
	if first or crown.size.x <= 0.001 or crown.size.z <= 0.001:
		return false
	var padding := head_bounds.size.y * 0.035
	var scale_x := (scalp.size.x + padding) / crown.size.x
	var scale_z := (scalp.size.z + padding) / crown.size.z
	var hat_scale := Vector3(scale_x, sqrt(scale_x * scale_z), scale_z)
	var center := scalp.get_center()
	var crown_center := crown.get_center() * hat_scale
	# La posicion sale en espacio del HeadMesh (bind, +Y = up): hay que
	# componerla con el frame correcto, no escribirla directa en el padre.
	var origin_in_head := Vector3(center.x - crown_center.x,
		head_bounds.end.y + head_bounds.size.y * 0.10 - raw.end.y * hat_scale.y,
		center.z - crown_center.z)
	var in_head := Transform3D(Basis.from_scale(hat_scale), origin_in_head)
	# La composicion mesh->padre debe seguir la ruta del skinning
	# (bone_rest * bind_pose), no la cadena de nodos: el Armature lleva
	# escala 0.01 y rotacion -90°X que los vertices skinneados no heredan
	# — anclar via head.global_transform dejaba el sombrero ~100x desplazado
	# o girado 90° respecto a la cabeza renderizada.
	hat.transform = _head_frame(model, head, parent) * in_head
	var tuck := float(TUCK_DROP.get(item_name, 0.02))
	var shrink := float(TUCK_SHRINK.get(item_name, 0.0))
	_tuck_hair(model, origin_in_head.y + raw.position.y * hat_scale.y + head_bounds.size.y * tuck, shrink)
	return true

static func restore_hair(model: Node3D) -> void:
	restore_hair_visible(model)
	restore_hair_mesh(model)

# Face-worn items (balaclavas) hide the hair; hats only tuck it. Restoring
# each effect separately lets the two stack: removing a hat over a balaclava
# untucks the hair but keeps it hidden under the mask.
static func restore_hair_visible(model: Node3D) -> void:
	for mesh_name in ["Hair", "GrowingBeard"]:
		for hair in model.find_children(mesh_name, "MeshInstance3D", true, false):
			if hair.has_meta("headwear_original_visible"):
				hair.visible = bool(hair.get_meta("headwear_original_visible"))
				hair.remove_meta("headwear_original_visible")

static func restore_hair_mesh(model: Node3D) -> void:
	for hair in model.find_children("Hair", "MeshInstance3D", true, false):
		if hair.has_meta("headwear_original_mesh"):
			hair.mesh = hair.get_meta("headwear_original_mesh")
			hair.remove_meta("headwear_original_mesh")

# The military cap is a skinned garment already in the character's bind space,
# so fit its hairline directly from the cap brim instead of re-transforming it
# as an external GLB. Keep side and nape hair visible while tucking stray locks.
static func tuck_hair_under_skinned_cap(model: Node3D, cap: MeshInstance3D) -> void:
	if model == null or cap == null or cap.mesh == null:
		return
	var head := model.find_child("HeadMesh", true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return
	var cap_bounds := cap.get_aabb()
	# get_aabb() is in the same bind-space coordinates used by the imported
	# skinned mesh. Trim only strands whose triangles rise above the lower band.
	var brim_height := cap_bounds.position.y + 0.018
	_tuck_hair(model, brim_height, 0.0, true)

static func _tuck_hair(model: Node3D, brim_height: float, shrink: float = 0.0, upper_only: bool = false) -> void:
	for hair in model.find_children("Hair", "MeshInstance3D", true, false):
		if hair.mesh == null:
			continue
		# Preserve skinning, materials and the original shared asset. Only this
		# character's upper hair is compressed under the brim while wearing it.
		if not hair.has_meta("headwear_original_mesh"):
			hair.set_meta("headwear_original_mesh", hair.mesh)
		var original: Mesh = hair.get_meta("headwear_original_mesh")
		var tucked := ArrayMesh.new()
		for surface in range(original.get_surface_count()):
			var arrays := original.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
			if upper_only and original.surface_get_primitive_type(surface) == Mesh.PRIMITIVE_TRIANGLES:
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					indices = PackedInt32Array()
					for vertex_idx in vertices.size(): indices.append(vertex_idx)
				var kept := PackedInt32Array()
				for tri in range(0, indices.size(), 3):
					var center_y := (vertices[indices[tri]].y + vertices[indices[tri + 1]].y + vertices[indices[tri + 2]].y) / 3.0
					if center_y <= brim_height:
						kept.append(indices[tri]); kept.append(indices[tri + 1]); kept.append(indices[tri + 2])
				arrays[Mesh.ARRAY_INDEX] = kept
				tucked.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
				tucked.surface_set_material(surface, original.surface_get_material(surface))
				continue
			var center := Vector2.ZERO
			if shrink > 0.0 and not vertices.is_empty():
				for vertex in vertices:
					center += Vector2(vertex.x, vertex.z)
				center /= vertices.size()
			for index in range(vertices.size()):
				if vertices[index].y > brim_height:
					vertices[index].y = brim_height + (vertices[index].y - brim_height) * 0.02
				elif shrink <= 0.0:
					continue
				if shrink > 0.0 and (not upper_only or vertices[index].y >= brim_height):
					vertices[index].x = center.x + (vertices[index].x - center.x) * (1.0 - shrink)
					vertices[index].z = center.y + (vertices[index].z - center.y) * (1.0 - shrink)
			arrays[Mesh.ARRAY_VERTEX] = vertices
			tucked.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
			tucked.surface_set_material(surface, original.surface_get_material(surface))
		hair.mesh = tucked

static func _head_frame(model: Node3D, head_mi: MeshInstance3D, parent: Node3D) -> Transform3D:
	var fallback: Transform3D = parent.global_transform.affine_inverse() * head_mi.global_transform
	var skeleton := _find_skeleton(model)
	if skeleton == null or head_mi.skin == null:
		return fallback
	var bone_idx := -1
	for bone_name in ["mixamorig:Head", "mixamorig_Head", "Head", "head", "Cabeza"]:
		bone_idx = skeleton.find_bone(bone_name)
		if bone_idx >= 0:
			break
	if bone_idx < 0:
		return fallback
	var skin := head_mi.skin
	var bind := Transform3D.IDENTITY
	var found := false
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == bone_idx or String(skin.get_bind_name(i)) == skeleton.get_bone_name(bone_idx):
			bind = skin.get_bind_pose(i)
			found = true
			break
	if not found:
		return fallback
	return parent.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(bone_idx) * bind

static func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

static func upper_bounds(mesh: MeshInstance3D, frame: Transform3D, cutoff: float) -> AABB:
	var bounds := AABB()
	var first := true
	for surface in range(mesh.mesh.get_surface_count()):
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices:
			var point := frame * vertex
			if point.y < cutoff:
				continue
			bounds = AABB(point, Vector3.ZERO) if first else bounds.expand(point)
			first = false
	return bounds

# Fits the two-part tactical headlamp (`LampHousing` + `HeadbandStrap`) onto the
# character's head in bind space, adapting height, tilt and elastic band span to
# whatever headwear/balaclava is currently worn so the rigid housing never
# distorts and the strap neither clips nor floats.
static func fit_headlamp(model: Node3D, headlamp: Node3D, head_item: String = "", face_item: String = "", pelt_species: String = "") -> bool:
	if model == null or headlamp == null or headlamp.get_parent() == null:
		return false
	var parent := headlamp.get_parent() as Node3D
	var head := model.find_child("HeadMesh", true, false) as MeshInstance3D
	if head == null or head.mesh == null:
		return false
	var bind_frame := _head_frame(model, head, parent)
	var world_to_bind := (parent.global_transform * bind_frame).affine_inverse()
	var bind_to_world := parent.global_transform * bind_frame
	# Heights are in the imported HeadMesh's bind space, above the brow or brim.
	var band_y := 3.572
	var down_deg := 4.0
	var wrap_outer_hat := false
	match head_item:
		"Casco militar":
			band_y = 3.602
			down_deg = 5.0
			wrap_outer_hat = true
		"Sombrero de pescador", "Gorro de piel":
			band_y = 3.658
			down_deg = 6.0
			wrap_outer_hat = true
		"Gorra militar", "Gorro de otoño":
			band_y = 3.636
			down_deg = 6.5
			wrap_outer_hat = true
		"Tocado de piel animal":
			# Mount over the trophy's forehead/crown above its eyes and below its ears
			# so neither the wearer's eyes nor the animal's eyes/jaws are covered.
			match pelt_species:
				"ciervo": band_y = 3.800
				"oso": band_y = 3.798
				"zorro": band_y = 3.788
				_: band_y = 3.762
			down_deg = 8.0
			wrap_outer_hat = true

	# Collect bind-space meshes that the strap wraps around at band_y.
	# On bare head we measure HeadMesh (cranium) rather than flared side hair tufts
	# so the elastic band hugs the temples instead of floating outside loose locks.
	var slice_meshes: Array = [[head, bind_to_world]]
	if not face_item.is_empty():
		var face_node := model.get_node_or_null("Worn_" + face_item)
		if face_node == null:
			for ch in model.get_children():
				if ch.name == "PreviewHat" and ch.find_child("FaceFittedBind", true, false) != null:
					face_node = ch
					break
		if face_node != null:
			for mi in face_node.find_children("*", "MeshInstance3D", true, false):
				if mi.visible:
					slice_meshes.append([mi, mi.global_transform])

	if wrap_outer_hat:
		if head_item in ["Gorra militar", "Gorro de otoño"]:
			var cap := model.find_child("autumn_hat", true, false) as MeshInstance3D
			if cap != null and cap.visible:
				slice_meshes.append([cap, bind_to_world])
		else:
			var hat_node := model.get_node_or_null("Worn_" + head_item)
			if hat_node == null:
				hat_node = model.get_node_or_null("PreviewHat")
			if hat_node != null:
				for mi in hat_node.find_children("*", "MeshInstance3D", true, false):
					if mi.visible:
						slice_meshes.append([mi, mi.global_transform])

	var min_x := INF; var max_x := -INF
	var min_z := INF; var max_z := -INF
	var front_z := -INF
	var count := 0
	var half_band := 0.016
	for entry in slice_meshes:
		var mi: MeshInstance3D = entry[0]
		var xf: Transform3D = world_to_bind * entry[1]
		if mi.mesh == null:
			continue
		for s in range(mi.mesh.get_surface_count()):
			var arr := mi.mesh.surface_get_arrays(s)
			if arr.is_empty():
				continue
			for v in arr[Mesh.ARRAY_VERTEX]:
				var p: Vector3 = xf * v
				if absf(p.y - band_y) <= half_band:
					# Exclude wide animal ears/antlers when measuring pelt crown width.
					if head_item == "Tocado de piel animal" and absf(p.x) > 0.205:
						continue
					min_x = minf(min_x, p.x)
					max_x = maxf(max_x, p.x)
					min_z = minf(min_z, p.z)
					max_z = maxf(max_z, p.z)
					if absf(p.x) <= 0.072:
						front_z = maxf(front_z, p.z)
					count += 1
	if count == 0:
		min_x = -0.20; max_x = 0.20; min_z = -0.21; front_z = 0.265
	elif front_z == -INF:
		front_z = max_z

	var pad_x := 0.020 if wrap_outer_hat else (0.014 if not face_item.is_empty() else 0.018)
	var pad_front := 0.005
	var pad_back := 0.022 if head_item.is_empty() and face_item.is_empty() else 0.018
	var mid_x := (min_x + max_x) * 0.5
	var target_w := maxf(0.38, (max_x - min_x) + pad_x * 2.0)
	var seat_z := front_z + pad_front
	var target_d := maxf(0.36, seat_z - (min_z - pad_back))

	var housing := headlamp.find_child("LampHousing", true, false) as MeshInstance3D
	var strap := headlamp.find_child("HeadbandStrap", true, false) as MeshInstance3D
	var housing_scale := 0.82
	if housing != null:
		housing.position = Vector3.ZERO
		# Tilt ONLY the front lamp housing downward; keep the elastic band level
		# around the head/hat/helmet cylinder so its sides never dip or rise into the crown.
		housing.basis = Basis(Vector3.RIGHT, deg_to_rad(down_deg)) * Basis.from_scale(Vector3.ONE * housing_scale)
		_ensure_headlamp_lens_glow(housing)
	if strap != null:
		var raw_s := strap.get_aabb()
		var raw_w := maxf(raw_s.size.x, 0.01)
		var raw_back := maxf(-raw_s.position.z, 0.01)
		strap.position = Vector3.ZERO
		strap.rotation = Vector3.ZERO
		strap.scale = Vector3(target_w / raw_w, housing_scale, target_d / raw_back)

	var in_head := Transform3D(Basis.IDENTITY, Vector3(mid_x, band_y, seat_z))
	headlamp.transform = bind_frame * in_head
	return true

static func _ensure_headlamp_lens_glow(housing: MeshInstance3D) -> void:
	if housing.get_node_or_null("HeadlampLensGlow") != null:
		return
	var glow_root := Node3D.new()
	glow_root.name = "HeadlampLensGlow"
	glow_root.visible = false
	var hb := housing.get_aabb()
	var lens_z := hb.end.z + 0.0015
	# Center tactical projector emitter disc (cool high-intensity military LED)
	var main_disc := MeshInstance3D.new()
	main_disc.name = "MainEmitter"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.016
	cyl.bottom_radius = 0.016
	cyl.height = 0.002
	cyl.radial_segments = 16
	main_disc.mesh = cyl
	main_disc.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	main_disc.position = Vector3(0.0, -0.003, lens_z)
	var emat := StandardMaterial3D.new()
	emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emat.albedo_color = Color(0.88, 0.96, 1.0)
	main_disc.material_override = emat
	glow_root.add_child(main_disc)
	# Tactical olive-green auxiliary corner LEDs
	var aux_mat := StandardMaterial3D.new()
	aux_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aux_mat.albedo_color = Color(0.52, 0.92, 0.62)
	for sx in [-1.0, 1.0]:
		var pip := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.0055
		sph.height = 0.011
		pip.mesh = sph
		pip.position = Vector3(0.036 * sx, 0.012, lens_z - 0.006)
		pip.material_override = aux_mat
		glow_root.add_child(pip)
	housing.add_child(glow_root)
