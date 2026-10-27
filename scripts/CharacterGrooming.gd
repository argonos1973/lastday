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
	var clean_base := base_name_from_identity(base_name)
	if clean_base.is_empty():
		clean_base = "Remy"
	var clean_style := style_for(style if not style.is_empty() else clean_base)
	return "%s|%s:%d" % [clean_base, clean_style, clampi(stage, 0, 4)]

# Crecimiento progresivo de barba con el tiempo sobrevivido:
# 0: < 10 min | 1: 10–25 min | 2: 25–50 min | 3: 50–90 min | 4: > 90 min
static func beard_stage(seconds: float) -> int:
	if seconds >= 5400.0:
		return 4
	if seconds >= 3000.0:
		return 3
	if seconds >= 1500.0:
		return 2
	if seconds >= 600.0:
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
		tinted.albedo_color = color
		tinted.roughness = 0.92
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
						v.y = lerpf(v.y, 3.49, 0.68)
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
	var sides := 8
	var base_idx := points.size()
	for r in range(rings):
		var t := float(r) / float(rings - 1)
		var center := Vector3(
			cx,
			lerpf(3.45, 3.06, pow(t, 1.08)),
			lerpf(-0.20, -0.33, sin(t * PI * 0.65))
		)
		var radius := lerpf(0.048, 0.082, sin(t * PI * 0.78)) * (1.0 - 0.50 * pow(t, 2.2))
		for s in range(sides):
			var ang := float(s) * TAU / float(sides)
			var n := Vector3(cos(ang), 0.15, sin(ang)).normalized()
			var p := center + Vector3(cos(ang) * radius * 1.15, 0.0, sin(ang) * radius * 0.95)
			points.append(p)
			if not normals.is_empty():
				normals.append(n)
			if not uvs.is_empty():
				uvs.append(Vector2(float(s) / float(sides), t))
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
			var sn := (s + 1) % sides
			var i00 := base_idx + r * sides + s
			var i01 := base_idx + r * sides + sn
			var i10 := base_idx + (r + 1) * sides + s
			var i11 := base_idx + (r + 1) * sides + sn
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
	var out_push: float = [0.0, 0.0022, 0.0085, 0.019, 0.032][clampi(stage, 0, 4)]
	var chin_drop: float = [0.0, 0.0, 0.020, 0.068, 0.145][clampi(stage, 0, 4)]
	var jaw_flare: float = [0.0, 0.0, 0.005, 0.015, 0.028][clampi(stage, 0, 4)]

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
		# Excluir cuello bajo, nariz/ojos y lóbulos de las orejas (ax > 0.142)
		var min_y := 3.258 if stage == 1 else 3.242
		if cy < min_y or cy > 3.445 or cz < 0.055 or ax > 0.142:
			continue
		# Descartar cavidad interna de la boca (dientes/lengua tienen cz < 0.198)
		if ax < 0.052 and cy > 3.320 and cy < 3.382 and cz < 0.198:
			continue
		# Hueco de los labios (boca despejada; comisuras conectan bigote con barba)
		if ax < 0.036 and cy > 3.334 and cy < 3.360:
			continue
		# Límite superior: bigote bajo la nariz (cy <= 3.384), mejillas en curva hacia las patillas
		var upper_y := 3.384
		if ax >= 0.038:
			var side_t := clampf((ax - 0.038) / 0.095, 0.0, 1.0)
			var cheek_low := 3.366 if stage == 1 else 3.372
			var sideburn_top := 3.428 if stage == 1 else 3.442
			upper_y = lerpf(cheek_low, sideburn_top, pow(side_t, 0.85))
		if cy > upper_y:
			continue
		if ax < 0.066 and cy > 3.384:
			continue
		beard_faces.append(fi)

	if beard_faces.is_empty():
		return mesh

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var indices := PackedInt32Array()
	var vmap := {}
	for fi in beard_faces:
		for fv in range(3):
			var ovi := mdt.get_face_vertex(fi, fv)
			if not vmap.has(ovi):
				var ni := verts.size()
				vmap[ovi] = ni
				var v := mdt.get_vertex(ovi)
				var n := mdt.get_vertex_normal(ovi).normalized()
				var ax := absf(v.x - cx)
				# Suavizar el borde superior de la mejilla y el borde inferior del cuello
				var side_t := clampf((ax - 0.045) / 0.088, 0.0, 1.0)
				var target_upper := 3.384 if ax < 0.045 else lerpf(3.355, 3.440, pow(side_t, 0.85))
				if v.y > target_upper:
					v.y = lerpf(v.y, target_upper, 0.72)
				var target_lower := 3.258 if stage == 1 else 3.245
				if v.y < target_lower and v.z < 0.14:
					v.y = lerpf(v.y, target_lower, 0.68)
				var chin_w := clampf((3.335 - v.y) / 0.075, 0.0, 1.0) * clampf((v.z - 0.07) / 0.15, 0.0, 1.0)
				var center_w := clampf(1.0 - ax / 0.115, 0.20, 1.0)
				var mustache_w := 0.48 if (ax < 0.062 and v.y > 3.356) else 1.0
				var edge_fade := clampf((target_upper - v.y) / 0.025, 0.25, 1.0)
				var out_dir := Vector3(n.x * 0.85, minf(0.05, n.y * 0.35), maxf(0.35, n.z)).normalized()
				var displaced := v + out_dir * (out_push * mustache_w * edge_fade * (0.65 + 0.65 * chin_w))
				displaced.y -= chin_drop * chin_w * (0.50 + 0.50 * center_w)
				displaced.z += chin_drop * 0.20 * chin_w * center_w
				displaced.x += signf(v.x - cx) * jaw_flare * chin_w * (1.0 - center_w * 0.45)
				verts.append(displaced)
				normals.append(out_dir)
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
	return mesh

static var _beard_tex_cache: ImageTexture = null

static func _beard_grain_texture() -> ImageTexture:
	if _beard_tex_cache != null:
		return _beard_tex_cache
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 918273
	for y in range(64):
		for x in range(64):
			var streak := rng.randf_range(0.68, 1.0)
			img.set_pixel(x, y, Color(streak, streak * 0.97, streak * 0.94, 1.0))
	_beard_tex_cache = ImageTexture.create_from_image(img)
	return _beard_tex_cache

static func _beard_material(color: Color, stage: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var darken := 0.85 if stage == 1 else 0.92
	var alpha := 0.48 if stage == 1 else (0.86 if stage == 2 else 1.0)
	mat.albedo_color = Color(color.r * darken, color.g * darken, color.b * darken, alpha)
	mat.albedo_texture = _beard_grain_texture()
	mat.uv1_scale = Vector3(14.0, 14.0, 14.0)
	mat.roughness = 0.95
	if alpha < 0.99:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat
