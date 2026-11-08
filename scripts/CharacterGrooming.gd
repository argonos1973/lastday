extends RefCounted

# Lista ordenada de peinados disponibles para personajes y selector.
const STYLES := ["buzz", "crop", "short", "medium", "ponytail", "long"]

const STYLE_LABELS := {
	"buzz": "Rapado",
	"crop": "Corto",
	"short": "Clásico",
	"medium": "Raya atrás",
	"ponytail": "Coleta",
	"long": "Pelo largo",
}

const BEARD_LABELS := [
	"Sin barba",
	"Barba de 3 días",
	"Barba corta",
	"Barba poblada",
	"Barba larga",
]

# Styles are deterministic by character identity, including existing saves.
static func style_for(identity: String) -> String:
	var clean := identity.strip_edges().to_lower()
	if clean.contains("|"):
		var parts := clean.split("|", false)
		if parts.size() >= 2:
			var sub := parts[1].split(":", false)[0].strip_edges()
			if sub in STYLES:
				return sub
		clean = parts[0].strip_edges()
	elif clean.contains(":"):
		clean = clean.split(":", false)[0].strip_edges()
	if clean in STYLES:
		return clean
	match clean:
		"laura", "luis":
			return "long"
		"marc":
			return "medium"
		"elena", "edu":
			return "ponytail"
		"soldado":
			return "buzz"
		"dris":
			return "crop"
	return "short"

static func stage_from_identity(identity: String, fallback_seconds: float = 0.0) -> int:
	if identity.contains(":"):
		var tail := identity.substr(identity.rfind(":") + 1).strip_edges()
		if tail.is_valid_int():
			return clampi(int(tail), 0, 4)
	return beard_stage(fallback_seconds)

static func base_name_from_identity(identity: String) -> String:
	var s := identity.strip_edges()
	if s.contains("|"):
		return s.split("|", false)[0].strip_edges()
	if s.contains(":"):
		return s.split(":", false)[0].strip_edges()
	return s

static func encode_identity(base_name: String, style: String, stage: int) -> String:
	var clean_base := base_name_from_identity(base_name).replace("|", "").replace(":", "").strip_edges()
	if clean_base.is_empty():
		clean_base = "Remy"
	var clean_style := style_for(style if not style.is_empty() else clean_base)
	return "%s|%s:%d" % [clean_base, clean_style, clampi(stage, 0, 4)]

# Crecimiento progresivo de barba con el tiempo sobrevivido:
# 0: < 1 h | 1: 1–3 h | 2: 3–6 h | 3: 6–12 h | 4: > 12 h
static func beard_stage(seconds: float) -> int:
	if seconds >= 43200.0:
		return 4
	if seconds >= 21600.0:
		return 3
	if seconds >= 10800.0:
		return 2
	if seconds >= 3600.0:
		return 1
	return 0

static func _find_head_source(model: Node3D) -> MeshInstance3D:
	var head := model.find_child("HeadMesh", true, false) as MeshInstance3D
	if head != null and head.mesh != null:
		return head
	var body := model.find_child("Body", true, false) as MeshInstance3D
	if body != null and body.mesh != null:
		return body
	return null

static func apply(model: Node3D, style: String, color: Color, stage: int) -> void:
	if model == null:
		return
	var resolved_style := style_for(style)
	var clamped_stage := clampi(stage, 0, 4)
	var hair := model.find_child("Hair", true, false) as MeshInstance3D
	var head := _find_head_source(model)
	if head == null or head.mesh == null:
		return
	var key := resolved_style + ":" + str(clamped_stage) + ":" + color.to_html()
	if model.get_meta("grooming_key", "") == key:
		return
	model.set_meta("grooming_key", key)

	if hair != null and hair.mesh != null:
		if not hair.has_meta("grooming_original"):
			hair.set_meta("grooming_original", hair.mesh)
		if not hair.has_meta("grooming_material"):
			hair.set_meta("grooming_material", hair.get_active_material(0))
		var original: Mesh = hair.get_meta("grooming_original")
		var styled_mesh := _build_styled_hair_mesh(original, head.mesh, resolved_style)
		if hair.has_meta("headwear_original_mesh"):
			hair.set_meta("headwear_original_mesh", styled_mesh)
		else:
			hair.mesh = styled_mesh
		var hair_mat := hair.get_meta("grooming_material") as StandardMaterial3D
		var tinted: StandardMaterial3D
		if hair_mat != null:
			tinted = hair_mat.duplicate() as StandardMaterial3D
		else:
			tinted = StandardMaterial3D.new()
		# The adapted FBX lost the strand opacity; the original atlas retains it.
		if resolved_style != "buzz":
			tinted.albedo_texture = preload("res://assets/characters/Remy_Remy_alpha_0.png")
			tinted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			tinted.alpha_scissor_threshold = 0.35
		else:
			# Buzz cut uses scalp UVs, not the strand atlas's cutout layout.
			tinted.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			tinted.albedo_texture = _stubble_texture()
			tinted.normal_enabled = false
		# The atlas already contains brown pigment: avoid multiplying it to black.
		tinted.albedo_color = Color(sqrt(color.r), sqrt(color.g), sqrt(color.b), 1.0)
		# FBX gloss was imported into both metallic and roughness slots.
		# A gloss value near zero must not turn hair into polished metal.
		tinted.metallic = 0.0
		tinted.metallic_texture = null
		tinted.roughness_texture = null
		tinted.roughness = 0.78
		tinted.metallic_specular = 0.20
		tinted.normal_scale = 0.35
		hair.material_override = tinted

	var beard := model.find_child("GrowingBeard", true, false) as MeshInstance3D
	if beard == null:
		beard = MeshInstance3D.new()
		beard.name = "GrowingBeard"
		head.get_parent().add_child(beard)
		beard.transform = head.transform
		beard.skin = head.skin
		beard.skeleton = head.skeleton
	beard.visible = clamped_stage > 0
	if clamped_stage <= 0:
		return
	beard.mesh = _build_beard_mesh(head.mesh, clamped_stage)
	beard.material_override = _beard_material(color, clamped_stage)

static var _stubble_atlas: Texture2D

static func _stubble_texture() -> Texture2D:
	if _stubble_atlas != null:
		return _stubble_atlas
	# Fine, isotropic stubble rather than long directional strands on scalp UVs.
	var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71023
	for y in range(256):
		for x in range(256):
			var value := rng.randf_range(0.32, 0.58)
			image.set_pixel(x, y, Color(value, value, value))
	image.generate_mipmaps()
	_stubble_atlas = ImageTexture.create_from_image(image)
	return _stubble_atlas

static func _build_styled_hair_mesh(original: Mesh, head_mesh: Mesh, style: String) -> ArrayMesh:
	if style == "buzz":
		var buzz := _build_buzzcut_mesh(head_mesh, original)
		if buzz.get_surface_count() > 0:
			return buzz
	var mesh := ArrayMesh.new()
	var box := original.get_aabb()
	var cx := box.get_center().x
	for surface in range(original.get_surface_count()):
		var arrays := original.surface_get_arrays(surface)
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX].duplicate()
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL].duplicate() if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		for i in range(points.size()):
			var v := points[i]
			var h := clampf((v.y - box.position.y) / maxf(box.size.y, 0.001), 0.0, 1.0)
			var back := clampf((box.get_center().z - v.z) / maxf(box.size.z * 0.42, 0.001), 0.0, 1.0)
			var front := clampf((v.z - box.get_center().z) / maxf(box.size.z * 0.38, 0.001), 0.0, 1.0)
			var side := clampf(absf(v.x - cx) / maxf(box.size.x * 0.35, 0.001), 0.0, 1.0)
			match style:
				"crop":
					# Pelo corto: despejar frente (subir flequillo) y recortar patillas y nuca sobre las orejas
					if v.y < 3.58 and front > 0.15:
						v.y = lerpf(v.y, 3.58, 0.72 * front)
						v.z -= 0.024 * front * (1.0 - h)
					if v.y < 3.49:
						v.y = lerpf(v.y, 3.49, 0.38)
					v.x = cx + (v.x - cx) * lerpf(0.86, 0.95, h)
					if back > 0.2 and v.y < 3.46:
						v.y = lerpf(v.y, 3.46, 0.65)
						v.z += 0.022 * back * (1.0 - h)
				"medium":
					# Peinado con raya / hacia atrás: frente despejada hacia un lado y laterales con volumen
					if front > 0.10 and v.y < 3.63:
						var sweep := front * clampf((3.63 - v.y) / 0.22, 0.0, 1.0)
						v.y += 0.065 * sweep
						v.x += 0.055 * sweep
						v.z -= 0.020 * sweep
					v.y -= 0.14 * pow(1.0 - h, 1.45) * back
					v.x = cx + (v.x - cx) * (1.06 + 0.05 * (1.0 - h))
				"ponytail":
					# Pelo recogido hacia atrás con coleta trasera
					if front > 0.08 and v.y < 3.62:
						var pull := front * clampf((3.62 - v.y) / 0.22, 0.0, 1.0)
						v.y += 0.065 * pull
						v.z -= 0.028 * pull
					v.x = cx + (v.x - cx) * lerpf(0.87, 0.95, h)
					if back > 0.25 and v.y < 3.46:
						var gather := back * clampf((3.48 - v.y) / 0.24, 0.0, 1.0)
						v.x = lerpf(v.x, cx, 0.58 * gather)
						v.y = lerpf(v.y, 3.43, 0.48 * gather)
						v.z -= 0.025 * gather
				"long":
					# Melena larga hasta los hombros y espalda alta
					var drape := maxf(back, side * 0.82 * (1.0 - front * 0.65))
					var low := pow(1.0 - h, 1.32)
					v.y -= 0.34 * low * drape
					v.x = cx + (v.x - cx) * (1.05 + 0.24 * low * drape)
					if back > 0.2:
						v.z -= 0.065 * low * back
			points[i] = v
		if style == "ponytail" and surface == 0:
			_append_ponytail_geometry(points, normals, arrays, cx)
		arrays[Mesh.ARRAY_VERTEX] = points
		if not normals.is_empty():
			arrays[Mesh.ARRAY_NORMAL] = normals
		if style != "short":
			# Deforming the hairstyle invalidates the imported normal/tangent basis.
			# SurfaceTool preserves UVs and skin weights while rebuilding lighting.
			var deformed := ArrayMesh.new()
			deformed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var st := SurfaceTool.new()
			st.create_from(deformed, 0)
			st.generate_normals()
			if arrays[Mesh.ARRAY_TEX_UV] != null:
				st.generate_tangents()
			arrays = st.commit_to_arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if mesh.get_surface_count() > surface:
			mesh.surface_set_material(surface, original.surface_get_material(surface))
	return mesh

static func _build_buzzcut_mesh(head_mesh: Mesh, hair_original: Mesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if head_mesh == null or head_mesh.get_surface_count() == 0:
		return mesh
	var mdt := MeshDataTool.new()
	if mdt.create_from_surface(head_mesh, 0) != OK:
		return mesh
	var cx := 0.008
	var scalp_faces := PackedInt32Array()
	for fi in range(mdt.get_face_count()):
		var v0 := mdt.get_vertex(mdt.get_face_vertex(fi, 0))
		var v1 := mdt.get_vertex(mdt.get_face_vertex(fi, 1))
		var v2 := mdt.get_vertex(mdt.get_face_vertex(fi, 2))
		var cy := (v0.y + v1.y + v2.y) / 3.0
		var cz := (v0.z + v1.z + v2.z) / 3.0
		var ax := absf((v0.x + v1.x + v2.x) / 3.0 - cx)
		# Excluir orejas (que sobresalen más allá de ax=0.148 entre cz=-0.10..0.05 y cy<3.54)
		if cy < 3.33 or ax > 0.165:
			continue
		if ax > 0.128 and cz > -0.11 and cz < 0.06 and cy < 3.535:
			continue
		# Línea frontal alta de rapado militar (con ligera entrada natural en las sienes)
		var min_y := 3.34
		if cz > 0.04:
			min_y = 3.575 + 0.025 * clampf((ax - 0.06) / 0.07, 0.0, 1.0)
		elif cz > -0.06:
			min_y = lerpf(3.49, 3.57, (cz + 0.06) / 0.10)
		if cy >= min_y:
			scalp_faces.append(fi)
	if scalp_faces.is_empty():
		return mesh
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var vmap := {}
	for fi in scalp_faces:
		for fv in range(3):
			var ovi := mdt.get_face_vertex(fi, fv)
			if not vmap.has(ovi):
				var ni := verts.size()
				vmap[ovi] = ni
				var v := mdt.get_vertex(ovi)
				var n := mdt.get_vertex_normal(ovi).normalized()
				var ax := absf(v.x - cx)
				# Suavizar el borde inferior del rapado hacia el cráneo para que no haga escalón
				var border_y := 3.575 if v.z > 0.04 else (3.49 if v.z > -0.06 else 3.34)
				var edge_t := clampf((v.y - border_y) / 0.035, 0.15, 1.0)
				if v.z > 0.04 and v.y < border_y:
					v.y = lerpf(v.y, border_y, 0.65)
				verts.append(v + n * (0.005 * edge_t))
				normals.append(n)
				uvs.append(mdt.get_vertex_uv(ovi))
				var bs: PackedInt32Array = mdt.get_vertex_bones(ovi)
				var ws: PackedFloat32Array = mdt.get_vertex_weights(ovi)
				for b in range(4):
					bones.append(bs[b] if b < bs.size() else 0)
				for w in range(4):
					weights.append(ws[w] if w < ws.size() else 0.0)
			indices.append(vmap[ovi])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_BONES] = bones
	arr[Mesh.ARRAY_WEIGHTS] = weights
	arr[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	if hair_original != null and hair_original.get_surface_count() > 0:
		mesh.surface_set_material(0, hair_original.surface_get_material(0))
	return mesh

static func _append_ponytail_geometry(points: PackedVector3Array, normals: PackedVector3Array, arrays: Array, cx: float) -> void:
	var old_count := points.size()
	if old_count == 0:
		return
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV].duplicate() if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR].duplicate() if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2].duplicate() if arrays[Mesh.ARRAY_TEX_UV2] != null else PackedVector2Array()
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT].duplicate() if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES].duplicate() if arrays[Mesh.ARRAY_BONES] != null else PackedInt32Array()
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS].duplicate() if arrays[Mesh.ARRAY_WEIGHTS] != null else PackedFloat32Array()
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX].duplicate() if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for idx in range(old_count):
			indices.append(idx)
	var bone_stride := int(bones.size() / old_count) if not bones.is_empty() else 0
	var ref_vi := 0
	var best_y := -999.0
	for i in range(old_count):
		if points[i].y > best_y:
			best_y = points[i].y
			ref_vi = i

	# Coleta tubular curvada desde la nuca alta (y=3.45, z=-0.20) hasta la espalda alta (y=3.06, z=-0.33)
	var rings := 8
	var sides := 12
	var base_idx := points.size()
	for r in range(rings):
		var t := float(r) / float(rings - 1)
		var center := Vector3(
			cx,
			lerpf(3.45, 3.06, pow(t, 1.08)),
			lerpf(-0.20, -0.33, sin(t * PI * 0.65))
		)
		var radius := lerpf(0.045, 0.065, sin(t * PI)) * (1.0 - 0.88 * pow(t, 2.2))
		for s in range(sides + 1):
			var ang := float(s) * TAU / float(sides)
			var n := Vector3(cos(ang), 0.15, sin(ang)).normalized()
			var p := center + Vector3(cos(ang) * radius * 1.15, 0.0, sin(ang) * radius * 0.95)
			points.append(p)
			if not normals.is_empty():
				normals.append(n)
			if not uvs.is_empty():
				# Stay inside one opaque strand island; the full atlas has gaps.
				uvs.append(Vector2(lerpf(0.07, 0.18, float(s) / float(sides)), lerpf(0.12, 0.70, t)))
			if not uv2s.is_empty():
				uv2s.append(Vector2(float(s) / float(sides), t))
			if not colors.is_empty():
				colors.append(colors[ref_vi])
			if not tangents.is_empty():
				for tg in range(4):
					tangents.append(tangents[ref_vi * 4 + tg])
			if bone_stride > 0:
				for b in range(bone_stride):
					bones.append(bones[ref_vi * bone_stride + b])
					weights.append(weights[ref_vi * bone_stride + b])
	for r in range(rings - 1):
		for s in range(sides):
			var sn := s + 1
			var stride := sides + 1
			var i00 := base_idx + r * stride + s
			var i01 := base_idx + r * stride + sn
			var i10 := base_idx + (r + 1) * stride + s
			var i11 := base_idx + (r + 1) * stride + sn
			indices.append(i00); indices.append(i10); indices.append(i01)
			indices.append(i01); indices.append(i10); indices.append(i11)
	if not uvs.is_empty():
		arrays[Mesh.ARRAY_TEX_UV] = uvs
	if not uv2s.is_empty():
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	if not colors.is_empty():
		arrays[Mesh.ARRAY_COLOR] = colors
	if not tangents.is_empty():
		arrays[Mesh.ARRAY_TANGENT] = tangents
	if bone_stride > 0:
		arrays[Mesh.ARRAY_BONES] = bones
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	arrays[Mesh.ARRAY_INDEX] = indices

static func _build_beard_mesh(head_mesh: Mesh, stage: int) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if head_mesh == null or head_mesh.get_surface_count() == 0 or stage <= 0:
		return mesh
	var mdt := MeshDataTool.new()
	if mdt.create_from_surface(head_mesh, 0) != OK:
		return mesh
	var cx := 0.008
	var out_push: float = [0.0, 0.0020, 0.0075, 0.0155, 0.025][clampi(stage, 0, 4)]
	var chin_drop: float = [0.0, 0.0, 0.014, 0.044, 0.088][clampi(stage, 0, 4)]
	var jaw_flare: float = [0.0, 0.0, 0.004, 0.011, 0.019][clampi(stage, 0, 4)]

	var beard_faces := PackedInt32Array()
	for fi in range(mdt.get_face_count()):
		var i0 := mdt.get_face_vertex(fi, 0)
		var i1 := mdt.get_face_vertex(fi, 1)
		var i2 := mdt.get_face_vertex(fi, 2)
		var v0 := mdt.get_vertex(i0)
		var v1 := mdt.get_vertex(i1)
		var v2 := mdt.get_vertex(i2)
		var cy := (v0.y + v1.y + v2.y) / 3.0
		var cz := (v0.z + v1.z + v2.z) / 3.0
		var ax := absf((v0.x + v1.x + v2.x) / 3.0 - cx)
		# Incluir la zona de mejillas, bigote y barbilla con margen suficiente
		# para que el shader trace toda la silueta por pixel (sin cortes poligonales).
		var min_y := 3.240 if stage == 1 else 3.224
		if cy < min_y or cy > 3.458 or cz < 0.045 or ax > 0.148:
			continue
		# Descartar cavidad interna de la boca (dientes/lengua tienen cz < 0.198)
		if ax < 0.052 and cy > 3.320 and cy < 3.382 and cz < 0.198:
			continue
		# No incluir los poligonos del puente nasal (encima de 3.394 en el centro)
		if ax < 0.070 and cy > 3.395:
			continue
		beard_faces.append(fi)

	if beard_faces.is_empty():
		return mesh

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var vmap := {}
	var colors := PackedColorArray()
	for fi in beard_faces:
		for fv in range(3):
			var ovi := mdt.get_face_vertex(fi, fv)
			if not vmap.has(ovi):
				var ni := verts.size()
				vmap[ovi] = ni
				var v := mdt.get_vertex(ovi)
				var n := mdt.get_vertex_normal(ovi).normalized()
				var ax := absf(v.x - cx)
				var side_t := clampf((ax - 0.036) / 0.092, 0.0, 1.0)
				var target_upper := 3.380 if ax < 0.038 else lerpf(3.358, 3.438, pow(side_t, 0.82))
				var target_lower := 3.258 if stage == 1 else 3.244
				var chin_w := pow(clampf((3.332 - v.y) / 0.072, 0.0, 1.0), 1.25) * clampf((v.z - 0.065) / 0.145, 0.0, 1.0)
				# Silueta inferior ancha y redondeada (toda la mandibula baja, no solo el pico central)
				var round_w := clampf(1.0 - pow(ax / 0.138, 2.6), 0.18, 1.0)
				var mustache_w := 0.45 if (ax < 0.062 and v.y > 3.354) else 1.0
				var edge_fade := clampf((target_upper - v.y + 0.010) / 0.032, 0.12, 1.0)
				var out_dir := Vector3(n.x * 0.82, minf(0.04, n.y * 0.30), maxf(0.38, n.z)).normalized()
				var displaced := v + out_dir * (out_push * mustache_w * edge_fade * (0.58 + 0.62 * chin_w))
				displaced.y -= chin_drop * chin_w * (0.55 + 0.45 * round_w)
				displaced.z += chin_drop * 0.16 * chin_w * round_w
				displaced.x += signf(v.x - cx) * jaw_flare * chin_w * (0.65 + 0.35 * (1.0 - round_w))
				var root_shade := lerpf(0.80, 1.0, clampf((target_upper - v.y) / 0.030, 0.0, 1.0)) * lerpf(1.0, 0.86, chin_w * 0.55)
				verts.append(displaced)
				normals.append(out_dir)
				var theta := atan2(v.x - cx, maxf(0.04, v.z + 0.06))
				uvs.append(Vector2(theta * 1.45 + 0.5, (3.445 - displaced.y) * 4.2))
				# UV2 guarda la posicion anatomica en la cara (x centrado, y, z) para que
				# el fragment shader trace el contorno curvo exacto por pixel.
				uv2s.append(Vector2(v.x - cx, v.y))
				colors.append(Color(root_shade, clampf((v.z - 0.05) / 0.22, 0.0, 1.0), clampf(chin_w, 0.0, 1.0), 1.0))
				var bs: PackedInt32Array = mdt.get_vertex_bones(ovi)
				var ws: PackedFloat32Array = mdt.get_vertex_weights(ovi)
				for b in range(4):
					bones.append(bs[b] if b < bs.size() else 0)
				for w in range(4):
					weights.append(ws[w] if w < ws.size() else 0.0)
			indices.append(vmap[ovi])

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for idx in indices:
		st.set_uv(uvs[idx])
		st.set_uv2(uv2s[idx])
		st.set_color(colors[idx])
		var b4 := PackedInt32Array([bones[idx * 4], bones[idx * 4 + 1], bones[idx * 4 + 2], bones[idx * 4 + 3]])
		var w4 := PackedFloat32Array([weights[idx * 4], weights[idx * 4 + 1], weights[idx * 4 + 2], weights[idx * 4 + 3]])
		st.set_bones(b4)
		st.set_weights(w4)
		st.add_vertex(verts[idx])
	st.generate_normals()
	st.generate_tangents()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	return mesh

static var _beard_shader_cache: Shader = null

static func _beard_material(color: Color, stage: int) -> ShaderMaterial:
	if _beard_shader_cache == null:
		_beard_shader_cache = Shader.new()
		_beard_shader_cache.code = """
shader_type spatial;
render_mode blend_mix, depth_prepass_alpha, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform vec3 hair_color : source_color = vec3(0.22, 0.14, 0.08);
uniform float stage_density = 0.85;
uniform float strand_freq = 72.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	float ax = abs(UV2.x);
	float fy = UV2.y;

	// 1) Linea anatomica de la mejilla y del bigote: curva concava natural desde
	// la patilla hasta la comisura del bigote, con ligera ondulacion folicular
	float strand_wave = (noise2(vec2(UV.x * strand_freq * 0.85, 2.7)) - 0.5) * 0.0045;
	float cheek_t = clamp((ax - 0.032) / 0.095, 0.0, 1.0);
	float cheek_curve = mix(3.354, 3.434, pow(cheek_t, 1.25)) + strand_wave;
	float philtrum_dip = 0.0035 * exp(-pow(ax / 0.008, 2.0));
	float mustache_top = 3.382 - philtrum_dip - 0.014 * smoothstep(0.014, 0.040, ax) + strand_wave * 0.5;
	float must_blend = smoothstep(0.044, 0.024, ax);
	float upper_line = mix(cheek_curve, mustache_top, must_blend);

	// 2) Recorte eliptico amplio y suave sobre los labios (sin bigotes colgando dentro de la boca)
	float lip_x = ax / 0.034;
	float lip_y = (fy - 3.345) / 0.0145;
	float lip_r = sqrt(lip_x * lip_x + lip_y * lip_y);
	float mouth_mask = smoothstep(0.86, 1.26, lip_r);
	float soul_gap = 1.0;
	if (fy < 3.337 && fy > 3.321 && ax > 0.011 && ax < 0.028) {
		float g = smoothstep(0.011, 0.019, ax) * smoothstep(0.028, 0.019, ax);
		soul_gap = 1.0 - 0.60 * g * smoothstep(3.321, 3.330, fy) * smoothstep(3.337, 3.330, fy);
	}

	// 3) Transiciones amplias y difuminadas en mejilla, cuello y patillas
	float top_fade = smoothstep(upper_line + 0.005, upper_line - 0.024, fy);
	float neck_wave = strand_wave * (1.0 - COLOR.b * 0.6);
	float neck_line = mix(3.250, 3.272, clamp(ax / 0.12, 0.0, 1.0)) + neck_wave;
	float bot_fade = mix(smoothstep(neck_line - 0.005, neck_line + 0.024, fy), 1.0, COLOR.b * 0.85);
	float side_fade = smoothstep(0.140, 0.114, ax);
	float shape_mask = clamp(top_fade * bot_fade * side_fade * mouth_mask * soul_gap, 0.0, 1.0);

	// 4) Hebras finas multicapa + foliculos
	vec2 uv_fine = vec2(UV.x * strand_freq, UV.y * (strand_freq * 0.24));
	vec2 uv_micro = vec2(UV.x * (strand_freq * 1.85), UV.y * (strand_freq * 0.42));
	float s1 = noise2(uv_fine);
	float s2 = noise2(uv_micro + vec2(11.7, 4.3));
	float pore = noise2(UV * (strand_freq * 1.6) + vec2(3.1, 9.2));
	float hairs = s1 * 0.42 + s2 * 0.38 + pore * 0.20;

	// 5) Color natural acorde al pelo
	vec3 dark_tone = hair_color * 0.72;
	vec3 light_tone = min(vec3(1.0), hair_color * 1.10 + vec3(0.02, 0.015, 0.008));
	vec3 col = mix(dark_tone, light_tone, smoothstep(0.22, 0.82, hairs));
	col *= mix(0.84, 1.0, COLOR.r);

	// 6) Degradado progresivo en los bordes + pelillos sueltos
	float soft_outline = pow(shape_mask, 0.75);
	float hair_modulation = mix(0.35 + 0.65 * smoothstep(0.25, 0.82, hairs), 0.90 + 0.10 * hairs, smoothstep(0.25, 0.75, shape_mask));
	float alpha = clamp(soft_outline * hair_modulation * stage_density, 0.0, 1.0);

	float dx = noise2(uv_micro + vec2(0.4, 0.0)) - s2;
	float dy = noise2(uv_micro + vec2(0.0, 0.4)) - s2;
	NORMAL_MAP = normalize(vec3(-dx * 0.55, -dy * 0.25, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 0.38;

	ALBEDO = col;
	ROUGHNESS = mix(0.86, 0.76, hairs);
	SPECULAR = 0.20;
	ALPHA = alpha;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = _beard_shader_cache
	var base := Color(
		clampf(pow(maxf(color.r, 0.02), 0.75) * 0.84, 0.04, 0.92),
		clampf(pow(maxf(color.g, 0.015), 0.77) * 0.82, 0.03, 0.88),
		clampf(pow(maxf(color.b, 0.01), 0.79) * 0.80, 0.02, 0.82)
	)
	var density: float = [0.0, 0.46, 0.82, 0.96, 1.0][clampi(stage, 0, 4)]
	var freq: float = [72.0, 92.0, 78.0, 68.0, 62.0][clampi(stage, 0, 4)]
	mat.set_shader_parameter("hair_color", Vector3(base.r, base.g, base.b))
	mat.set_shader_parameter("stage_density", density)
	mat.set_shader_parameter("strand_freq", freq)
	return mat
