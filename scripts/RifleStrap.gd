extends RefCounted

# ================================================================
# RIFLE STRAP
#
# Webbing sling from the barrel swivel, over the near shoulder,
# diagonally across the chest, around the opposite flank and across
# the lower back to the stock swivel.
#
# The body part of the route is solved once in the character's rest
# pose: guide points are densified and shrink-wrapped onto the
# outermost visible torso garment (nearest-vertex planes + clearance),
# so the band rests on the shirt/jacket instead of sinking into it.
# Every wrapped point is skinned to its two nearest torso bones; per
# update only those rigid transforms run, plus the exact rifle anchors
# at both ends. The route is rebuilt when the worn torso garment or the
# rifle instance changes.
# ================================================================

var player: Node

# Model units: shoulder-to-shoulder is ~0.78, so 0.075 reads as a ~4 cm band.
const WIDTH: float = 0.075
const THICKNESS: float = 0.012
const CLEARANCE: float = 0.016
const BODY_POINTS: int = 44
const CONNECTOR_POINTS: int = 7
const UV_REPEAT: float = 0.32
const GRID_CELL: float = 0.10
const RADIAL_COLUMN: float = 0.055
const RADIAL_SEARCH: float = 0.16
const SKIN_INFLUENCES: int = 3
const SKIN_FALLOFF: float = 0.20
const MAX_SURFACE_VERTICES: int = 6000

# Wrap-surface layers, outermost first. Near any point only the outermost
# layer present counts, so a jacket hides the skin and shirt beneath it.
const SURFACE_LAYERS := [
	["soldier_torso", "field_jacket_"],
	["Tops", "Ch42_Shirt"],
	["Desnudo_torso", "Body_torso", "BodyNoHead", "Body", "Desnudo_arms", "Body_arms"],
]

const BONE_NAMES := {
	"hips": ["mixamorig_Hips", "mixamorig:Hips", "Hips"],
	"spine": ["mixamorig_Spine", "mixamorig:Spine", "Spine"],
	"spine1": ["mixamorig_Spine1", "mixamorig:Spine1", "Spine1"],
	"spine2": ["mixamorig_Spine2", "mixamorig:Spine2", "Spine2"],
	"neck": ["mixamorig_Neck", "mixamorig:Neck", "Neck"],
	"left_shoulder": ["mixamorig_LeftShoulder", "mixamorig:LeftShoulder", "LeftShoulder"],
	"right_shoulder": ["mixamorig_RightShoulder", "mixamorig:RightShoulder", "RightShoulder"],
	"left_arm": ["mixamorig_LeftArm", "mixamorig:LeftArm", "LeftArm"],
	"right_arm": ["mixamorig_RightArm", "mixamorig:RightArm", "RightArm"],
}

static var _webbing_material: StandardMaterial3D = null
static var _metal_material: StandardMaterial3D = null

var _skeleton: Skeleton3D = null
var _skeleton_children := -1
var _bones: Dictionary = {}
var _candidates: Array = []
var _signature := ""
# Each entry: {"b": bone indices, "w": weights, "o": rest offsets, "n": rest normals}
var _route: Array = []
var _previous := PackedVector3Array()
var _mesh_instance: MeshInstance3D = null
var _hardware: Node3D = null
var _last_points := PackedVector3Array()
# Rest-space surface of the last build (kept for diagnostics/regressions).
var _grid: Dictionary = {}
var _rest_body_points := PackedVector3Array()
var _surface_clearance: float = CLEARANCE
var _spine_axis := PackedVector3Array()
var _radial_limit_y: float = INF

# ================================================================
# UPDATE
# ================================================================

func _update_rifle_strap(delta: float) -> void:
	if player == null:
		return
	var model: Node3D = player.third_person_model
	if model == null or not is_instance_valid(model):
		return
	var barrel_marker: Node3D = player._strap_barrel_marker
	var stock_marker: Node3D = player._strap_stock_marker
	if barrel_marker == null or not is_instance_valid(barrel_marker) or stock_marker == null or not is_instance_valid(stock_marker):
		return
	if not barrel_marker.is_inside_tree() or not stock_marker.is_inside_tree():
		return
	var skel := _find_character_skeleton(model)
	if skel == null:
		return
	var barrel: Vector3 = model.to_local(barrel_marker.global_position)
	var stock: Vector3 = model.to_local(stock_marker.global_position)
	var signature := _current_signature(skel)
	if signature != _signature or _route.is_empty():
		_signature = signature
		_build_route(model, skel, barrel, stock)
		_previous = PackedVector3Array()
	if _route.is_empty():
		return
	var frame := _skinned_body(model, skel)
	var points: PackedVector3Array = frame[0]
	var normals: PackedVector3Array = frame[1]
	var path := _assemble_path(barrel, stock, points, normals)
	var path_points: PackedVector3Array = path[0]
	var path_normals: PackedVector3Array = path[1]
	# Damp interior jitter while both weapon anchors stay exact.
	if _previous.size() == path_points.size():
		var blend := 1.0 - exp(-18.0 * delta)
		for i in range(1, path_points.size() - 1):
			if _previous[i].distance_to(path_points[i]) < 0.25:
				path_points[i] = _previous[i].lerp(path_points[i], blend)
	_previous = path_points.duplicate()
	_update_mesh(model, path_points, path_normals)
	_update_hardware(model, path_points, path_normals)
	var rigged: Node3D = player._rifle_on_back_strap
	if rigged != null and is_instance_valid(rigged):
		rigged.visible = false

# ================================================================
# SURFACE + ROUTE (rest pose, once per garment/rifle change)
# ================================================================

func _find_character_skeleton(model: Node3D) -> Skeleton3D:
	var skel: Skeleton3D = player._spine_skeleton if player._spine_skeleton != null and is_instance_valid(player._spine_skeleton) else null
	if skel == null:
		skel = _find_skeleton(model)
	if skel != _skeleton:
		_skeleton = skel
		_skeleton_children = -1
		_bones.clear()
		_route.clear()
		if skel != null:
			for key in BONE_NAMES:
				for bone_name in BONE_NAMES[key]:
					var idx := skel.find_bone(bone_name)
					if idx >= 0:
						_bones[key] = idx
						break
	# Field jackets are hung on the skeleton when first worn: rescan on change.
	if skel != null and skel.get_child_count() != _skeleton_children:
		_skeleton_children = skel.get_child_count()
		_candidates.clear()
		for mi in skel.find_children("*", "MeshInstance3D", true, false):
			if _layer_of(str(mi.name)) >= 0:
				_candidates.append(mi)
	return skel

static func _layer_of(mesh_name: String) -> int:
	for layer in SURFACE_LAYERS.size():
		for pattern in SURFACE_LAYERS[layer]:
			if mesh_name == pattern or (pattern.ends_with("_") and mesh_name.begins_with(pattern)):
				return layer
	return -1

func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root
	for child in root.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _current_signature(_skel: Skeleton3D) -> String:
	var parts := PackedStringArray()
	var rifle: Node = player._rifle_on_back
	parts.append(str(rifle.get_instance_id()) if rifle != null and is_instance_valid(rifle) else "0")
	for mi in _candidates:
		if is_instance_valid(mi) and mi.visible and mi.mesh != null:
			parts.append("%s:%d:%d" % [mi.name, mi.mesh.get_instance_id(), mi.material_override.get_instance_id() if mi.material_override != null else 0])
	return "|".join(parts)

func _rest_model(model: Node3D, skel: Skeleton3D, idx: int) -> Transform3D:
	return model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_rest(idx)

func _pose_model(model: Node3D, skel: Skeleton3D, idx: int) -> Transform3D:
	return model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(idx)

func _bone(key: String, fallback: String = "") -> int:
	if _bones.has(key):
		return int(_bones[key])
	return int(_bones.get(fallback, -1))

func _build_route(model: Node3D, skel: Skeleton3D, barrel: Vector3, stock: Vector3) -> void:
	_route.clear()
	var spine := _bone("spine", "spine1")
	var spine1 := _bone("spine1", "spine2")
	var spine2 := _bone("spine2", "spine1")
	var hips := _bone("hips", "spine")
	var neck := _bone("neck", "spine2")
	if spine < 0 or spine1 < 0 or spine2 < 0 or hips < 0 or neck < 0:
		return
	# Role -> bone index, with spine fallbacks already resolved.
	var roles := {"hips": hips, "spine": spine, "spine1": spine1, "spine2": spine2, "neck": neck}
	for key in ["left_shoulder", "right_shoulder", "left_arm", "right_arm"]:
		if _bones.has(key):
			roles[key] = int(_bones[key])
	var rest := {}
	for key in roles:
		rest[key] = _rest_model(model, skel, int(roles[key]))
	# Anchors carried from the current pose into rest space through Spine2,
	# the bone the back-item root follows.
	var to_rest: Transform3D = rest["spine2"] * _pose_model(model, skel, spine2).affine_inverse()
	var rest_barrel: Vector3 = to_rest * barrel
	var rest_stock: Vector3 = to_rest * stock
	var s2: Vector3 = rest["spine2"].origin
	var s1: Vector3 = rest["spine1"].origin
	var s0: Vector3 = rest["spine"].origin
	var hip: Vector3 = rest["hips"].origin
	var neck_pos: Vector3 = rest["neck"].origin
	var torso_center := (s2 + s1 + s0) / 3.0
	var back_dir := (rest_barrel + rest_stock) * 0.5 - torso_center
	back_dir.y = 0.0
	back_dir = back_dir.normalized() if back_dir.length_squared() > 0.000001 else Vector3.BACK
	var front := -back_dir
	var right := front.cross(Vector3.UP).normalized()
	# The sling goes over the shoulder on the rifle's muzzle side.
	var side := 1.0 if (rest_barrel - torso_center).dot(right) >= 0.0 else -1.0
	var near := right * side
	var near_key := "right" if near.dot(Vector3.LEFT) > 0.0 else "left"
	var far_key := "left" if near_key == "right" else "right"
	var shoulder: Vector3 = rest.get(near_key + "_shoulder", Transform3D(Basis(), s2 + near * 0.13 + Vector3.UP * 0.19)).origin
	var arm: Vector3 = rest.get(near_key + "_arm", Transform3D(Basis(), shoulder + near * 0.26)).origin
	var far_arm: Vector3 = rest.get(far_key + "_arm", Transform3D(Basis(), s2 - near * 0.39 + Vector3.UP * 0.2)).origin
	var trap := shoulder.lerp(arm, 0.45)
	var flank := maxf(0.2, absf((far_arm - s2).dot(near)) * 0.62)
	var guides: Array[Vector3] = [
		trap + back_dir * 0.10 + Vector3.UP * 0.02,
		trap + Vector3.UP * 0.10,
		shoulder.lerp(arm, 0.32) + front * 0.10 + Vector3.UP * 0.02,
		s2 + near * 0.11 + front * 0.25 - Vector3.UP * 0.04,
		s1.lerp(s2, 0.45) + front * 0.27,
		s1 - near * 0.13 + front * 0.26 - Vector3.UP * 0.02,
		s0.lerp(s1, 0.45) - near * flank * 0.85 + front * 0.15,
		s0.lerp(s1, 0.30) - near * flank,
		s0.lerp(s1, 0.25) - near * flank * 0.85 + back_dir * 0.14,
		s0.lerp(s1, 0.35) - near * 0.12 + back_dir * 0.22,
	]
	_build_surface(rest, hip, neck_pos, s2, near)
	var dense := _resample(_catmull_rom(guides, 12), BODY_POINTS)
	for _iteration in 4:
		for i in dense.size():
			dense[i] = _project(dense[i], true)
		dense = _relax(dense, 0.5)
	dense = _resample(dense, BODY_POINTS)
	# Taut band: relaxing then pushing back out converges on a smooth envelope
	# that bridges over pouches and folds instead of following every lump.
	for _iteration in 4:
		for i in dense.size():
			dense[i] = _project(dense[i], false)
		dense = _relax(dense, 0.5)
	for i in dense.size():
		dense[i] = _project(dense[i], false)
	_rest_body_points = PackedVector3Array(dense)
	var band_normals: Array[Vector3] = []
	for p in dense:
		band_normals.append(_surface_normal(p))
	for _pass in 3:
		var smoothed: Array[Vector3] = band_normals.duplicate()
		for i in range(1, band_normals.size() - 1):
			smoothed[i] = (band_normals[i - 1] + band_normals[i] * 2.0 + band_normals[i + 1]).normalized()
		band_normals = smoothed
	# Skin every wrapped point to its two nearest torso bones.
	var skin_keys := ["hips", "spine", "spine1", "spine2", "neck", near_key + "_shoulder", far_key + "_shoulder"]
	for i in dense.size():
		var p: Vector3 = dense[i]
		var n := band_normals[i]
		# Smooth Gaussian falloff over the nearest bones: a hard nearest-pair
		# switch kinks the band wherever the pair changes once the torso bends.
		var ranked: Array = []
		for key in skin_keys:
			if rest.has(key):
				ranked.append([p.distance_squared_to(rest[key].origin), key])
		ranked.sort_custom(func(a, b): return a[0] < b[0])
		var entry := {"b": [], "w": [], "o": [], "n": []}
		var total := 0.0
		for k in mini(SKIN_INFLUENCES, ranked.size()):
			var key: String = ranked[k][1]
			var w := exp(-float(ranked[k][0]) / (SKIN_FALLOFF * SKIN_FALLOFF)) + 0.000001
			var t: Transform3D = rest[key]
			entry.b.append(int(roles[key]))
			entry.w.append(w)
			entry.o.append(t.affine_inverse() * p)
			entry.n.append((t.basis.inverse() * n).normalized())
			total += w
		for k in entry.w.size():
			entry.w[k] = float(entry.w[k]) / total
		_route.append(entry)

static func _closest_on_polyline(line: PackedVector3Array, p: Vector3) -> Vector3:
	var best := line[0]
	var best_d := INF
	for i in line.size() - 1:
		var c := Geometry3D.get_closest_point_to_segment(p, line[i], line[i + 1])
		var d := c.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = c
	return best

func _build_surface(rest: Dictionary, hip: Vector3, neck_pos: Vector3, s2: Vector3, near: Vector3) -> void:
	_grid.clear()
	var spine_axis := PackedVector3Array([hip, rest["spine"].origin, rest["spine1"].origin, s2, neck_pos])
	_spine_axis = spine_axis
	_radial_limit_y = neck_pos.y
	for key in ["left_shoulder", "right_shoulder"]:
		if rest.has(key):
			_radial_limit_y = minf(_radial_limit_y, rest[key].origin.y - 0.08)
	_surface_clearance = CLEARANCE
	var arm_reach := 0.45
	for key in ["left_arm", "right_arm"]:
		if rest.has(key):
			arm_reach = maxf(arm_reach, absf((rest[key].origin - s2).dot(near)) + 0.10)
	var y_min := hip.y - 0.05
	var y_max := neck_pos.y + 0.10
	var meshes: Array = []
	var total := 0
	for mi in _candidates:
		if is_instance_valid(mi) and mi.visible and mi.mesh != null and mi.mesh.get_surface_count() > 0:
			meshes.append(mi)
			total += (mi.mesh as Mesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
	var stride := maxi(1, int(ceil(float(total) / float(MAX_SURFACE_VERTICES))))
	var model: Node3D = player.third_person_model
	for mi in meshes:
		var layer := _layer_of(str(mi.name))
		var grow := _grow_in_model(mi)
		var to_model := _rest_mesh_to_model(model, mi)
		var normal_basis := to_model.basis.inverse().transposed()
		var mesh: Mesh = mi.mesh
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			for vi in range(0, verts.size(), stride):
				var v := to_model * verts[vi]
				if v.y < y_min or v.y > y_max or absf((v - s2).dot(near)) > arm_reach:
					continue
				var outward := v - _closest_on_polyline(spine_axis, v)
				var n := (normal_basis * norms[vi]).normalized() if vi < norms.size() else outward.normalized()
				# Garments are double-sided (inner lining with inverted normals):
				# inward-facing samples would read as "outside" and let the
				# band sink, so only outward-facing surface counts.
				if n.dot(outward.normalized()) < -0.2:
					continue
				# Store the rendered surface: vertex data inflated by the material grow.
				v += n * grow
				var cell := Vector3i(floori(v.x / GRID_CELL), floori(v.y / GRID_CELL), floori(v.z / GRID_CELL))
				if not _grid.has(cell):
					_grid[cell] = []
				_grid[cell].append([v, n, layer])

# Rest-pose mesh->model transform of a skinned garment. Exported skins share
# one mesh-to-skeleton frame (rest_i * bind_i is the same for every bind), so
# the first bind is enough — and it also covers garments imported from other
# files (field jackets) whose vertex data is not in model space.
func _rest_mesh_to_model(model: Node3D, mi: MeshInstance3D) -> Transform3D:
	var skel := _skeleton
	if mi.skin == null or mi.skin.get_bind_count() == 0 or skel == null:
		return model.global_transform.affine_inverse() * mi.global_transform
	var bone := mi.skin.get_bind_bone(0)
	var bind_name := String(mi.skin.get_bind_name(0))
	if not bind_name.is_empty():
		bone = skel.find_bone(bind_name)
	if bone < 0:
		return model.global_transform.affine_inverse() * mi.global_transform
	return model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_rest(bone) * mi.skin.get_bind_pose(0)

# Garment materials inflate the rendered surface with grow, applied in the
# skinned MeshInstance's local units (Armature-scaled, ~0.01 of the model):
# a shirt's grow 3.0 sits ~0.03 model units outside its vertex data.
func _grow_in_model(mi: MeshInstance3D) -> float:
	var mat := mi.material_override as BaseMaterial3D
	if mat == null and mi.mesh.get_surface_count() > 0:
		mat = mi.get_active_material(0) as BaseMaterial3D
	if mat == null or not mat.grow:
		return 0.0
	var model: Node3D = player.third_person_model
	var scale := (model.global_transform.affine_inverse() * mi.global_transform).basis.get_scale()
	return maxf(0.0, mat.grow_amount) * maxf(scale.x, maxf(scale.y, scale.z))

# Nearest-surface frame: inverse-distance blend of the closest vertices.
func _surface_frame(p: Vector3) -> Array:
	var cell := Vector3i(floori(p.x / GRID_CELL), floori(p.y / GRID_CELL), floori(p.z / GRID_CELL))
	for ring in range(1, 5):
		var found: Array = []
		for x in range(-ring, ring + 1):
			for y in range(-ring, ring + 1):
				for z in range(-ring, ring + 1):
					var key := cell + Vector3i(x, y, z)
					if _grid.has(key):
						found.append_array(_grid[key])
		if found.is_empty():
			continue
		found.sort_custom(func(a, b): return p.distance_squared_to(a[0]) < p.distance_squared_to(b[0]))
		# Outermost layer among the local neighbourhood wins.
		var outer := 99
		for k in mini(24, found.size()):
			outer = mini(outer, int(found[k][2]))
		var origin := Vector3.ZERO
		var normal := Vector3.ZERO
		var weight := 0.0
		var used := 0
		for k in found.size():
			if int(found[k][2]) != outer:
				continue
			var w := 1.0 / (p.distance_squared_to(found[k][0]) + 0.0004)
			origin += found[k][0] * w
			normal += found[k][1] * w
			weight += w
			used += 1
			if used >= 8:
				break
		if normal.length_squared() < 0.000001:
			return []
		return [origin / weight, normal.normalized()]
	return []

func _surface_normal(p: Vector3) -> Vector3:
	var frame := _surface_frame(p)
	return frame[1] if not frame.is_empty() else Vector3.UP

# Places p at the clearance height over the local surface plane. With
# two_sided the band is also pulled down onto the body (tension); otherwise
# it is only pushed out of the garment.
func _project(p: Vector3, two_sided: bool) -> Vector3:
	var frame := _surface_frame(p)
	if frame.is_empty():
		return p
	var height: float = (p - frame[0]).dot(frame[1])
	if two_sided or height < _surface_clearance:
		p += frame[1] * (_surface_clearance - height)
	return _clear_radially(p)

# The nearest-plane wrap only sees the closest shell; vest pouches and other
# relief that stand proud of it further along the outward direction would
# still cover the band. Below the shoulders, also clear the highest
# outward-facing sample in a narrow column around the spine-radial ray.
func _clear_radially(p: Vector3) -> Vector3:
	if p.y > _radial_limit_y:
		return p
	var axis_point := _closest_on_polyline(_spine_axis, p)
	var dir := p - axis_point
	var radius := dir.length()
	if radius < 0.001:
		return p
	dir /= radius
	var highest := -INF
	var visited := {}
	var step := 0.0
	while step <= radius + RADIAL_SEARCH:
		var probe := axis_point + dir * step
		var cell := Vector3i(floori(probe.x / GRID_CELL), floori(probe.y / GRID_CELL), floori(probe.z / GRID_CELL))
		for x in range(-1, 2):
			for y in range(-1, 2):
				for z in range(-1, 2):
					var key := cell + Vector3i(x, y, z)
					if visited.has(key) or not _grid.has(key):
						continue
					visited[key] = true
					for sample in _grid[key]:
						var offset: Vector3 = sample[0] - axis_point
						var along := offset.dot(dir)
						if along <= 0.0 or along > radius + RADIAL_SEARCH:
							continue
						if (offset - dir * along).length_squared() < RADIAL_COLUMN * RADIAL_COLUMN:
							highest = maxf(highest, along)
		step += GRID_CELL * 0.5
	if highest > -INF and radius < highest + _surface_clearance:
		p += dir * (highest + _surface_clearance - radius)
	return p

func _catmull_rom(points: Array[Vector3], per_segment: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in points.size() - 1:
		var p0: Vector3 = points[maxi(i - 1, 0)]
		var p1: Vector3 = points[i]
		var p2: Vector3 = points[i + 1]
		var p3: Vector3 = points[mini(i + 2, points.size() - 1)]
		for s in per_segment:
			var t := float(s) / float(per_segment)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(points[points.size() - 1])
	return out

func _resample(points: Array[Vector3], count: int) -> Array[Vector3]:
	var lengths: Array[float] = [0.0]
	for i in range(1, points.size()):
		lengths.append(lengths[i - 1] + points[i - 1].distance_to(points[i]))
	var total: float = lengths[lengths.size() - 1]
	var out: Array[Vector3] = []
	var seg := 0
	for k in count:
		var target := total * float(k) / float(count - 1)
		while seg < points.size() - 2 and lengths[seg + 1] < target:
			seg += 1
		var span: float = lengths[seg + 1] - lengths[seg]
		var t: float = (target - lengths[seg]) / span if span > 0.00001 else 0.0
		out.append(points[seg].lerp(points[seg + 1], clampf(t, 0.0, 1.0)))
	return out

func _relax(points: Array[Vector3], amount: float) -> Array[Vector3]:
	var out: Array[Vector3] = points.duplicate()
	for i in range(1, points.size() - 1):
		out[i] = points[i].lerp((points[i - 1] + points[i + 1]) * 0.5, amount)
	return out

# ================================================================
# PER-FRAME SKINNING + PATH
# ================================================================

func _skinned_body(model: Node3D, skel: Skeleton3D) -> Array:
	var poses := {}
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	points.resize(_route.size())
	normals.resize(_route.size())
	for i in _route.size():
		var entry: Dictionary = _route[i]
		var p := Vector3.ZERO
		var n := Vector3.ZERO
		for k in entry.b.size():
			var idx: int = entry.b[k]
			if not poses.has(idx):
				poses[idx] = _pose_model(model, skel, idx)
			var pose: Transform3D = poses[idx]
			p += (pose * (entry.o[k] as Vector3)) * float(entry.w[k])
			n += (pose.basis * (entry.n[k] as Vector3)) * float(entry.w[k])
		points[i] = p
		normals[i] = n.normalized() if n.length_squared() > 0.000001 else Vector3.UP
	return [points, normals]

# Joins the rifle swivels to the skinned body run with quadratic curves that
# leave each body end along its own tangent (no kink, no overshoot inward).
func _assemble_path(barrel: Vector3, stock: Vector3, body: PackedVector3Array, body_normals: PackedVector3Array) -> Array:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var last := body.size() - 1
	var start_tangent := (body[1] - body[0]).normalized()
	var control_a := body[0] - start_tangent * barrel.distance_to(body[0]) * 0.45
	for s in CONNECTOR_POINTS:
		var t := float(s) / float(CONNECTOR_POINTS)
		points.append(barrel.lerp(control_a, t).lerp(control_a.lerp(body[0], t), t))
		normals.append(body_normals[0])
	points.append_array(body)
	normals.append_array(body_normals)
	var end_tangent := (body[last] - body[last - 1]).normalized()
	var control_b := body[last] + end_tangent * stock.distance_to(body[last]) * 0.45
	for s in range(1, CONNECTOR_POINTS + 1):
		var t := float(s) / float(CONNECTOR_POINTS)
		points.append(body[last].lerp(control_b, t).lerp(control_b.lerp(stock, t), t))
		normals.append(body_normals[last])
	return [points, normals]

# ================================================================
# MESH: rectangular webbing band (width x thickness)
# ================================================================

func _update_mesh(model: Node3D, points: PackedVector3Array, normals: PackedVector3Array) -> void:
	if _mesh_instance == null or not is_instance_valid(_mesh_instance) or _mesh_instance.get_parent() != model:
		_mesh_instance = model.find_child("ProceduralStrapMesh", false, false) as MeshInstance3D
		_last_points = PackedVector3Array()
		if _mesh_instance == null:
			_mesh_instance = MeshInstance3D.new()
			_mesh_instance.name = "ProceduralStrapMesh"
			_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			model.add_child(_mesh_instance)
		_mesh_instance.material_override = _get_webbing_material()
		_mesh_instance.custom_aabb = AABB(Vector3(-5, -5, -5), Vector3(10, 10, 10))
	if _last_points.size() == points.size():
		var moved := false
		for i in points.size():
			if points[i].distance_squared_to(_last_points[i]) > 0.0000004:
				moved = true
				break
		if not moved:
			return
	_last_points = points.duplicate()
	var count := points.size()
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	verts.resize(count * 8)
	norms.resize(count * 8)
	uvs.resize(count * 8)
	var half_w := WIDTH * 0.5
	var distance := 0.0
	var prev_side := Vector3.ZERO
	for i in count:
		if i > 0:
			distance += points[i].distance_to(points[i - 1])
		var tangent := (points[mini(i + 1, count - 1)] - points[maxi(i - 1, 0)]).normalized()
		var up := normals[i]
		var side := tangent.cross(up)
		side = side.normalized() if side.length_squared() > 0.000001 else (prev_side if prev_side != Vector3.ZERO else Vector3.RIGHT)
		if prev_side != Vector3.ZERO and side.dot(prev_side) < 0.0:
			side = -side
		prev_side = side
		up = side.cross(tangent).normalized()
		if up.dot(normals[i]) < 0.0:
			up = -up
		var base := points[i]
		var top := base + up * THICKNESS
		var v := distance / UV_REPEAT
		# 0-1 top face, 2-3 bottom face, 4-5 near edge, 6-7 far edge.
		var ring := [
			[top - side * half_w, up, Vector2(0.0, v)], [top + side * half_w, up, Vector2(1.0, v)],
			[base + side * half_w, -up, Vector2(1.0, v)], [base - side * half_w, -up, Vector2(0.0, v)],
			[base - side * half_w, -side, Vector2(0.0, v)], [top - side * half_w, -side, Vector2(0.04, v)],
			[top + side * half_w, side, Vector2(0.96, v)], [base + side * half_w, side, Vector2(1.0, v)],
		]
		for k in 8:
			verts[i * 8 + k] = ring[k][0]
			norms[i * 8 + k] = ring[k][1]
			uvs[i * 8 + k] = ring[k][2]
	for i in count - 1:
		var a := i * 8
		var b := a + 8
		for face in 4:
			var f := face * 2
			indices.append_array([a + f, b + f, a + f + 1, a + f + 1, b + f, b + f + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_instance.mesh = mesh
	_mesh_instance.visible = true

# ================================================================
# HARDWARE: swivel loops at the rifle, tri-glide adjuster on the chest
# ================================================================

func _update_hardware(model: Node3D, points: PackedVector3Array, normals: PackedVector3Array) -> void:
	if _hardware == null or not is_instance_valid(_hardware) or _hardware.get_parent() != model:
		_hardware = model.find_child("RifleSlingHardware", false, false) as Node3D
		if _hardware == null:
			_hardware = Node3D.new()
			_hardware.name = "RifleSlingHardware"
			model.add_child(_hardware)
			var torus := TorusMesh.new()
			torus.inner_radius = WIDTH * 0.42
			torus.outer_radius = WIDTH * 0.58
			torus.rings = 16
			torus.ring_segments = 8
			for loop_name in ["BarrelSwivel", "StockSwivel"]:
				var loop := MeshInstance3D.new()
				loop.name = loop_name
				loop.mesh = torus
				loop.material_override = _get_metal_material()
				_hardware.add_child(loop)
			var glide := MeshInstance3D.new()
			glide.name = "TriGlide"
			var box := BoxMesh.new()
			box.size = Vector3(WIDTH * 1.18, THICKNESS * 2.6, WIDTH * 0.42)
			glide.mesh = box
			glide.material_override = _get_metal_material()
			_hardware.add_child(glide)
	var last := points.size() - 1
	_place_hardware(_hardware.get_node("BarrelSwivel"), points, normals, 0, true)
	_place_hardware(_hardware.get_node("StockSwivel"), points, normals, last, true)
	_place_hardware(_hardware.get_node("TriGlide"), points, normals, CONNECTOR_POINTS + int(BODY_POINTS * 0.30), false)

func _place_hardware(node: Node3D, points: PackedVector3Array, normals: PackedVector3Array, index: int, loop: bool) -> void:
	var count := points.size()
	var tangent := (points[mini(index + 1, count - 1)] - points[maxi(index - 1, 0)]).normalized()
	var up := normals[index]
	var side := tangent.cross(up)
	if side.length_squared() < 0.000001:
		return
	side = side.normalized()
	up = side.cross(tangent).normalized()
	if loop:
		# Ring plane holds tangent and normal so the band wraps through it.
		node.transform = Transform3D(Basis(tangent, side, up), points[index])
	else:
		node.transform = Transform3D(Basis(side, up, tangent), points[index] + up * THICKNESS * 0.5)

# Moves a swivel marker onto the nearest point of the rifle's own geometry,
# so the sling hardware sits on the gun instead of floating beside it.
static func snap_to_mesh(marker: Node3D, mesh_root: Node3D, max_samples: int = 12000) -> void:
	if marker == null or mesh_root == null or marker.get_parent() == null:
		return
	var parent := marker.get_parent() as Node3D
	var target := marker.position
	var to_parent := parent.global_transform.affine_inverse()
	var meshes := mesh_root.find_children("*", "MeshInstance3D", true, false)
	if mesh_root is MeshInstance3D:
		meshes.append(mesh_root)
	var total := 0
	for mi in meshes:
		if mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				total += mi.mesh.surface_get_array_len(s)
	var stride := maxi(1, int(ceil(float(total) / float(max_samples))))
	var best := target
	var best_d := INF
	for mi in meshes:
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var xf: Transform3D = to_parent * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var verts: PackedVector3Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for i in range(0, verts.size(), stride):
				var v: Vector3 = xf * verts[i]
				var d := v.distance_squared_to(target)
				if d < best_d:
					best_d = d
					best = v
	if best_d < INF:
		marker.position = best

# ================================================================
# MATERIALS
# ================================================================

static func _get_webbing_material() -> StandardMaterial3D:
	if _webbing_material == null:
		_webbing_material = StandardMaterial3D.new()
		_webbing_material.resource_name = "RifleSlingWebbing"
		_webbing_material.albedo_texture = _make_webbing_texture()
		_webbing_material.roughness = 0.88
		_webbing_material.metallic = 0.0
		_webbing_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return _webbing_material

static func _get_metal_material() -> StandardMaterial3D:
	if _metal_material == null:
		_metal_material = StandardMaterial3D.new()
		_metal_material.resource_name = "RifleSlingMetal"
		_metal_material.albedo_color = Color(0.13, 0.135, 0.13)
		_metal_material.metallic = 0.75
		_metal_material.roughness = 0.42
	return _metal_material

# Olive-drab nylon webbing: tight twill, bound edges with stitch lines and
# light grime. u runs across the band, v along it (tiles seamlessly).
static func _make_webbing_texture() -> ImageTexture:
	var w := 64
	var h := 256
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var base := Color(0.25, 0.28, 0.18)
	var dark := Color(0.15, 0.17, 0.11)
	var light := Color(0.34, 0.37, 0.25)
	var thread := Color(0.11, 0.12, 0.08)
	for y in h:
		for x in w:
			var col := base
			# 2/2 twill: diagonal ribs that repeat every 4 px in both axes.
			var rib := (x + y) % 4
			col = col.lerp(light, 0.22) if rib < 2 else col.lerp(dark, 0.18)
			if y % 2 == 0:
				col = col.lerp(dark, 0.06)
			var edge := mini(x, w - 1 - x)
			if edge < 4:
				col = base.lerp(dark, 0.55 - float(edge) * 0.08)
			elif edge == 6 and y % 8 < 5:
				col = thread
			# Grime: low-frequency tileable blotches plus fine fibre noise.
			var blotch := 0.5 + 0.5 * sin(float(y) / float(h) * TAU * 3.0 + sin(float(x) * 0.19) * 1.3)
			col = col.lerp(dark, blotch * 0.12)
			var n := sin(x * 12.9898 + y * 78.233) * 43758.5453
			n = (n - floor(n) - 0.5) * 0.05
			img.set_pixel(x, y, Color(clampf(col.r + n, 0.0, 1.0), clampf(col.g + n, 0.0, 1.0), clampf(col.b + n, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
