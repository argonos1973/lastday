extends Node3D
class_name ProceduralRifleSling

## Runtime rifle + sling rig used while the rifle is stored on the back.
##
## The strap is rebuilt from the animated Mixamo bone positions. It is a small
## extruded ribbon, not a rigid model, so it follows the shoulder, chest and hip
## without behaving like a straight bar.

@export var strap_width := 0.065
@export var strap_thickness := 0.006
@export var front_clearance := 0.115
@export var rear_clearance := 0.19
@export var curve_steps_per_segment := 4
@export var strap_color := Color(0.38, 0.40, 0.25, 1.0)

var _skeleton: Skeleton3D
var _body_root: Node3D
var _visibility_root: Node3D
var _rifle_anchor: Node3D
var _rifle_visual: Node3D
var _strap_visual: MeshInstance3D
var _strap_mesh: ArrayMesh
var _rifle_raw_aabb := AABB()
var _weapon_scale := 5.94


func setup(
		skeleton: Skeleton3D,
		body_root: Node3D,
		visibility_root: Node3D,
		rifle_visual: Node3D,
		rifle_raw_aabb: AABB,
		weapon_scale: float
) -> bool:
	if skeleton == null or body_root == null or visibility_root == null or rifle_visual == null:
		return false
	_skeleton = skeleton
	_body_root = body_root
	_visibility_root = visibility_root
	_rifle_visual = rifle_visual
	_rifle_raw_aabb = rifle_raw_aabb
	_weapon_scale = weapon_scale

	# All generated positions are world-space. Keeping this rig top-level avoids
	# applying the imported armature scale a second time.
	top_level = true
	global_transform = Transform3D.IDENTITY
	process_priority = 200

	_rifle_anchor = Node3D.new()
	_rifle_anchor.name = "StowedRifleAnchor"
	add_child(_rifle_anchor)
	_rifle_visual.name = "StowedRifle"
	_rifle_visual.position = Vector3.ZERO
	_rifle_visual.rotation = Vector3.ZERO
	_rifle_anchor.add_child(_rifle_visual)

	_strap_visual = MeshInstance3D.new()
	_strap_visual.name = "ProceduralRifleStrap"
	_strap_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_strap_visual.material_override = _make_strap_material()
	_strap_mesh = ArrayMesh.new()
	_strap_visual.mesh = _strap_mesh
	add_child(_strap_visual)

	_update_rig()
	return true


func _process(_delta: float) -> void:
	if not _is_ready():
		return
	# In first-person the character model is hidden; the rifle and sling must be
	# hidden with it even though this rig uses a top-level transform.
	visible = _visibility_root.visible
	if visible:
		_update_rig()


func _is_ready() -> bool:
	return (
		_skeleton != null
		and is_instance_valid(_skeleton)
		and _body_root != null
		and is_instance_valid(_body_root)
		and _visibility_root != null
		and is_instance_valid(_visibility_root)
		and _rifle_anchor != null
		and is_instance_valid(_rifle_anchor)
		and _strap_visual != null
		and is_instance_valid(_strap_visual)
	)


func _update_rig() -> void:
	var frame := _body_frame()
	var right: Vector3 = frame["right"]
	var up: Vector3 = frame["up"]
	var back: Vector3 = frame["back"]
	var front := -back
	var hips: Vector3 = frame["hips"]
	var spine: Vector3 = frame["spine"]
	var right_shoulder: Vector3 = frame["right_shoulder"]
	var left_hip: Vector3 = frame["left_hip"]

	# Rifle stays entirely behind the torso: stock low-left, barrel high-right.
	var stock_target := left_hip - right * 0.10 + up * 0.06 + back * rear_clearance
	var barrel_target := right_shoulder + right * 0.035 + up * 0.20 + back * rear_clearance
	var rifle_z := (barrel_target - stock_target).normalized()
	var rifle_y := back
	var rifle_x := rifle_y.cross(rifle_z).normalized()
	if rifle_x.length_squared() < 0.0001:
		rifle_x = right
	rifle_y = rifle_z.cross(rifle_x).normalized()
	var rifle_basis := Basis(rifle_x, rifle_y, rifle_z).orthonormalized()

	var skeleton_scale := absf(_skeleton.global_transform.basis.get_scale().x)
	var effective_scale := maxf(0.0001, _weapon_scale * skeleton_scale)
	# The current rifle model's origin is the grip and its stock is 8.46 model
	# units down -Z (same measurement used by PlayerController for hand IK).
	var stock_to_grip := 8.46 * effective_scale
	var grip_world := stock_target + rifle_z * stock_to_grip
	_rifle_anchor.global_transform = Transform3D(rifle_basis, grip_world)
	_rifle_visual.scale = Vector3.ONE * effective_scale

	var raw_barrel_z := _rifle_raw_aabb.position.z + _rifle_raw_aabb.size.z * 0.94
	var grip_to_barrel := maxf(0.40, raw_barrel_z * effective_scale)
	var barrel_anchor := grip_world + rifle_z * grip_to_barrel
	var stock_anchor := grip_world - rifle_z * stock_to_grip

	# The middle points sit in front of the body; only the two short end runs
	# wrap over the shoulder/hip to meet the rifle behind the character.
	var controls: Array[Vector3] = [
		barrel_anchor,
		right_shoulder + up * 0.09 + back * (rear_clearance * 0.72),
		right_shoulder + up * 0.055 - right * 0.015 + front * 0.015,
		right_shoulder - right * 0.035 + front * front_clearance,
		spine + right * 0.015 + front * (front_clearance + 0.012),
		spine.lerp(hips, 0.54) - right * 0.105 + front * (front_clearance + 0.018) - up * 0.018,
		left_hip - right * 0.12 + up * 0.105 + front * (front_clearance * 0.82),
		left_hip - right * 0.14 + up * 0.065 + back * 0.025,
		stock_anchor,
	]
	var control_normals: Array[Vector3] = [
		back,
		(back + up * 0.35).normalized(),
		(front + up * 0.30).normalized(),
		front,
		front,
		front,
		(front - right * 0.22).normalized(),
		(back - right * 0.25).normalized(),
		back,
	]
	_rebuild_strap_mesh(controls, control_normals)


func _body_frame() -> Dictionary:
	var char_basis := _body_root.global_transform.basis.orthonormalized()
	var char_right := char_basis.x.normalized()
	var char_up := char_basis.y.normalized()
	var char_back := char_basis.z.normalized()
	var base := _skeleton.global_position

	var hips := _bone_world(["mixamorig:Hips", "mixamorig_Hips", "Hips"], base + char_up * 0.92)
	var spine := _bone_world(
		["mixamorig:Spine2", "mixamorig_Spine2", "Spine2", "mixamorig:Spine1", "mixamorig_Spine1", "Spine1"],
		hips + char_up * 0.48
	)
	var right_shoulder := _bone_world(
		["mixamorig:RightShoulder", "mixamorig_RightShoulder", "RightShoulder", "mixamorig:RightArm", "mixamorig_RightArm", "RightArm"],
		spine + char_right * 0.24 + char_up * 0.15
	)
	var left_shoulder := _bone_world(
		["mixamorig:LeftShoulder", "mixamorig_LeftShoulder", "LeftShoulder", "mixamorig:LeftArm", "mixamorig_LeftArm", "LeftArm"],
		spine - char_right * 0.24 + char_up * 0.15
	)
	var left_hip := _bone_world(
		["mixamorig:LeftUpLeg", "mixamorig_LeftUpLeg", "LeftUpLeg"],
		hips - char_right * 0.13
	)

	var right := right_shoulder - left_shoulder
	if right.length_squared() < 0.0001:
		right = char_right
	right = right.normalized()
	var up := spine - hips
	if up.length_squared() < 0.0001:
		up = char_up
	up = up.normalized()
	var back := right.cross(up).normalized()
	if back.length_squared() < 0.0001:
		back = char_back
	if back.dot(char_back) < 0.0:
		back = -back
	# Re-orthogonalize after resolving the imported skeleton's axis directions.
	right = up.cross(back).normalized()
	up = back.cross(right).normalized()

	return {
		"right": right,
		"up": up,
		"back": back,
		"hips": hips,
		"spine": spine,
		"right_shoulder": right_shoulder,
		"left_hip": left_hip,
	}


func _bone_world(candidates: Array, fallback: Vector3) -> Vector3:
	for candidate in candidates:
		var index := _skeleton.find_bone(str(candidate))
		if index >= 0:
			return (_skeleton.global_transform * _skeleton.get_bone_global_pose(index)).origin
	return fallback


func _rebuild_strap_mesh(controls: Array[Vector3], control_normals: Array[Vector3]) -> void:
	if controls.size() < 2 or controls.size() != control_normals.size():
		return
	var points: Array[Vector3] = []
	var surface_normals: Array[Vector3] = []
	var steps := maxi(2, curve_steps_per_segment)
	for segment in range(controls.size() - 1):
		var p0: Vector3 = controls[maxi(segment - 1, 0)]
		var p1: Vector3 = controls[segment]
		var p2: Vector3 = controls[segment + 1]
		var p3: Vector3 = controls[mini(segment + 2, controls.size() - 1)]
		for step in range(steps):
			var t := float(step) / float(steps)
			points.append(_catmull_rom(p0, p1, p2, p3, t))
			var n := control_normals[segment].lerp(control_normals[segment + 1], t).normalized()
			surface_normals.append(n)
	points.append(controls[-1])
	surface_normals.append(control_normals[-1].normalized())

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var half_width := strap_width * 0.5
	var half_thickness := strap_thickness * 0.5
	var accumulated_length := 0.0

	for i in range(points.size()):
		if i > 0:
			accumulated_length += points[i - 1].distance_to(points[i])
		var previous: Vector3 = points[maxi(i - 1, 0)]
		var following: Vector3 = points[mini(i + 1, points.size() - 1)]
		var tangent := (following - previous).normalized()
		var face_normal: Vector3 = surface_normals[i]
		var across := face_normal.cross(tangent).normalized()
		if across.length_squared() < 0.0001:
			across = Vector3.RIGHT
		face_normal = tangent.cross(across).normalized()
		var center: Vector3 = points[i]
		vertices.append(center - across * half_width + face_normal * half_thickness)
		vertices.append(center + across * half_width + face_normal * half_thickness)
		vertices.append(center - across * half_width - face_normal * half_thickness)
		vertices.append(center + across * half_width - face_normal * half_thickness)
		normals.append(face_normal)
		normals.append(face_normal)
		normals.append(-face_normal)
		normals.append(-face_normal)
		uvs.append(Vector2(0.0, accumulated_length / maxf(strap_width, 0.001)))
		uvs.append(Vector2(1.0, accumulated_length / maxf(strap_width, 0.001)))
		uvs.append(Vector2(0.0, accumulated_length / maxf(strap_width, 0.001)))
		uvs.append(Vector2(1.0, accumulated_length / maxf(strap_width, 0.001)))

	for i in range(points.size() - 1):
		var a := i * 4
		var b := (i + 1) * 4
		# Front and rear faces.
		_append_quad(indices, a, b, b + 1, a + 1)
		_append_quad(indices, a + 3, b + 3, b + 2, a + 2)
		# Narrow side faces give the strap real thickness in profile.
		_append_quad(indices, a + 2, b + 2, b, a)
		_append_quad(indices, a + 1, b + 1, b + 3, a + 3)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_strap_mesh.clear_surfaces()
	_strap_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)


func _append_quad(indices: PackedInt32Array, a: int, b: int, c: int, d: int) -> void:
	indices.append(a)
	indices.append(b)
	indices.append(c)
	indices.append(a)
	indices.append(c)
	indices.append(d)


func _catmull_rom(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * (
		2.0 * p1
		+ (p2 - p0) * t
		+ (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
		+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
	)


func _make_strap_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = strap_color
	material.roughness = 0.96
	material.metallic = 0.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material
