# deformable_camo_net.gd
# Adapta la red de camuflaje (camo_net_stick_shelter_deformable.glb) a un
# refugio de palos mediante raycasts o marcadores manuales.
#
# USO:
# 1. Instancia el GLB en tu escena.
# 2. Adjunta este script al nodo raiz del GLB instanciado (Node3D).
# 3. Marca los palos del refugio con StaticBody3D en la capa de colision
#    indicada en collision_mask (por defecto capa 1).
# 4. Llama adapt_to_shelter() o activa update_continuously.
extends Node3D

enum AdaptationMode { RAYCAST, MANUAL_POINTS, HYBRID }

@export var skeleton_path: NodePath
@export var mesh_path: NodePath
@export var collision_node_path: NodePath

@export var adapt_enabled: bool = true
@export var adaptation_mode: AdaptationMode = AdaptationMode.RAYCAST
@export var collision_mask: int = 1
@export var ray_start_height: float = 3.0
@export var ray_length: float = 6.0
@export var surface_offset: float = 0.08
@export var smoothing_speed: float = 6.0
@export var use_smoothing: bool = true
@export var fall_amount: float = 0.35
@export var max_height: float = 4.0
@export var min_height: float = 0.02
@export var update_continuously: bool = false
@export var update_interval: float = 0.25
@export var edge_influence: float = 1.0
@export var center_influence: float = 1.0
@export var sag_amount: float = 0.12
@export var use_noise: bool = true
@export var noise_strength: float = 0.025
@export var noise_frequency: float = 0.8
@export var noise_seed: int = 12345
@export var align_to_surface_normal: bool = false
@export_range(0.0, 1.0) var normal_alignment: float = 0.25
@export var disable_aux_collision: bool = true
@export var manual_control_points: Array[NodePath] = []

var _skeleton: Skeleton3D = null
var _mesh_instance: MeshInstance3D = null
var _noise: FastNoiseLite = null
var _timer: float = 0.0
var _initialized: bool = false
var _did_initial_adapt: bool = false
var _warned_no_skeleton: bool = false

# Cache por hueso de control
# Cada entrada: {index, name, rest_pose, initial_pose, target_pos, current_pos,
#                row, col, is_grid, grid_norm_dist}
var _bones: Array[Dictionary] = []

const BONE_PREFIX := "NetBone_"
const CORNER_PREFIX := "NetCorner_"
const RIDGE_PREFIX := "NetRidge_"
const CENTER_NAME := "NetCenter"


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	_initialize()
	if _initialized and adapt_enabled:
		# Adaptar tras el primer frame de fisica para que el mundo este listo
		_did_initial_adapt = false


func _initialize() -> void:
	_skeleton = _resolve_skeleton()
	_mesh_instance = _resolve_mesh()
	if _skeleton == null:
		if not _warned_no_skeleton:
			push_error("deformable_camo_net: Skeleton3D no encontrado.")
			_warned_no_skeleton = true
		return
	if _mesh_instance == null:
		push_warning("deformable_camo_net: MeshInstance3D no encontrada; la adaptacion de huesos funcionara igualmente.")
	_setup_noise()
	refresh_bone_cache()
	_apply_collision_toggle()
	_initialized = true


func _resolve_skeleton() -> Skeleton3D:
	if skeleton_path != NodePath() and has_node(skeleton_path):
		var n := get_node(skeleton_path)
		if n is Skeleton3D:
			return n
	return _find_first(self, "Skeleton3D") as Skeleton3D


func _resolve_mesh() -> MeshInstance3D:
	if mesh_path != NodePath() and has_node(mesh_path):
		var n := get_node(mesh_path)
		if n is MeshInstance3D:
			return n
	return _find_first(self, "MeshInstance3D") as MeshInstance3D


func _find_first(root: Node, klass: String) -> Node:
	if root.is_class(klass):
		return root
	for child in root.get_children():
		var found := _find_first(child, klass)
		if found != null:
			return found
	return null


func _setup_noise() -> void:
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = noise_frequency
	_noise.noise_type = FastNoiseLite.TYPE_PERLIN


func refresh_bone_cache() -> void:
	_bones.clear()
	if _skeleton == null:
		return
	for i in range(_skeleton.get_bone_count()):
		var bname := _skeleton.get_bone_name(i)
		var is_grid := bname.begins_with(BONE_PREFIX)
		var is_helper := bname.begins_with(CORNER_PREFIX) \
			or bname.begins_with(RIDGE_PREFIX) or bname == CENTER_NAME
		if not is_grid and not is_helper:
			continue
		var row := -1
		var col := -1
		if is_grid:
			# Formato: NetBone_R00_C00
			var parts := bname.split("_")
			if parts.size() >= 3:
				row = int(parts[1].substr(1))
				col = int(parts[2].substr(1))
		var rest := _skeleton.get_bone_global_rest(i)
		var entry := {
			"index": i,
			"name": bname,
			"rest_pose": rest,
			"initial_pose": _skeleton.get_bone_pose(i),
			"target_pos": rest.origin,
			"current_pos": rest.origin,
			"target_basis": rest.basis,
			"row": row,
			"col": col,
			"is_grid": is_grid,
		}
		_bones.append(entry)
	if _bones.is_empty():
		push_warning("deformable_camo_net: no se encontraron huesos de control (NetBone_*).")


func _apply_collision_toggle() -> void:
	var coll_node: Node = null
	if collision_node_path != NodePath() and has_node(collision_node_path):
		coll_node = get_node(collision_node_path)
	else:
		coll_node = find_child("CamoNet_StickShelter_Collision*", true, false)
	if coll_node == null:
		return
	if disable_aux_collision:
		if coll_node is CollisionShape3D:
			coll_node.disabled = true
		if coll_node is Node3D:
			coll_node.visible = false
		coll_node.process_mode = Node.PROCESS_MODE_DISABLED


func set_aux_collision_enabled(enabled: bool) -> void:
	disable_aux_collision = not enabled
	_apply_collision_toggle()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if not _initialized or not adapt_enabled:
		return
	if not _did_initial_adapt:
		_did_initial_adapt = true
		_compute_targets()
	if update_continuously:
		_timer += delta
		if _timer >= update_interval:
			_timer = 0.0
			_compute_targets()
	_apply_poses(delta)


# ------------------------------------------------------------ calculo de objetivos
func _compute_targets() -> void:
	if _skeleton == null or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var manual_map := _build_manual_map()
	var skel_global := _skeleton.global_transform
	for entry in _bones:
		var rest: Transform3D = entry["rest_pose"]
		var rest_global: Vector3 = skel_global * rest.origin
		var target_global := rest_global
		var surface_normal := Vector3.UP
		var found := false

		var marker := manual_map.get(entry["name"], null) as Node3D
		var use_marker: bool = marker != null and (
			adaptation_mode == AdaptationMode.MANUAL_POINTS
			or adaptation_mode == AdaptationMode.HYBRID)

		if use_marker:
			target_global = marker.global_position + Vector3.UP * surface_offset
			found = true
		elif adaptation_mode != AdaptationMode.MANUAL_POINTS:
			var from := Vector3(rest_global.x, rest_global.y + ray_start_height, rest_global.z)
			var to := from + Vector3.DOWN * ray_length
			var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
			query.exclude = _own_rids()
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				target_global = hit["position"] + Vector3.UP * surface_offset
				surface_normal = hit["normal"]
				found = true

		if not found:
			# Sin superficie: caida suave configurable desde la pose de reposo
			target_global = rest_global + Vector3.DOWN * fall_amount

		# Limites de altura relativos al origen de la red
		var local_h := target_global.y - global_position.y
		local_h = clampf(local_h, min_height, max_height)
		target_global.y = global_position.y + local_h

		# Caida entre apoyos: mayor cerca del centro y en zonas sin contacto
		var sag := _compute_sag(entry, found)
		target_global.y -= sag

		# Ruido estable para variacion natural
		if use_noise and _noise != null:
			target_global.y += _noise.get_noise_2d(rest.origin.x * 10.0, rest.origin.z * 10.0) * noise_strength

		# Influencia borde/centro
		var infl := _influence_factor(entry)
		var final_global: Vector3 = rest_global.lerp(target_global, infl)

		entry["target_pos"] = skel_global.affine_inverse() * final_global

		if align_to_surface_normal and found:
			var base_basis: Basis = rest.basis
			var aligned := Basis(Quaternion(Vector3.UP, surface_normal.normalized())) * base_basis
			entry["target_basis"] = base_basis.slerp(aligned, normal_alignment)
		else:
			entry["target_basis"] = rest.basis


func _compute_sag(entry: Dictionary, found: bool) -> float:
	var sag := 0.0
	if entry["is_grid"]:
		var r: int = entry["row"]
		var c: int = entry["col"]
		# Normalizar la distancia al centro de la cuadricula 5x7
		var nr := absf(float(r) - 2.0) / 2.0
		var nc := absf(float(c) - 3.0) / 3.0
		var center_closeness: float = 1.0 - maxf(nr, nc)
		sag = sag_amount * center_closeness
	if not found:
		sag += sag_amount * 0.5
	return sag


func _influence_factor(entry: Dictionary) -> float:
	if not entry["is_grid"]:
		return clampf(edge_influence, 0.0, 1.0)
	var r: int = entry["row"]
	var c: int = entry["col"]
	var is_edge: bool = r == 0 or r == 4 or c == 0 or c == 6
	return clampf(edge_influence if is_edge else center_influence, 0.0, 1.0)


func _build_manual_map() -> Dictionary:
	var map := {}
	if manual_control_points.is_empty():
		return map
	var grid_names: Array[String] = []
	for entry in _bones:
		if entry["is_grid"]:
			grid_names.append(entry["name"])
	var idx := 0
	for np in manual_control_points:
		if np == NodePath() or not has_node(np):
			continue
		var node := get_node(np)
		if node is Node3D and idx < grid_names.size():
			map[grid_names[idx]] = node
			idx += 1
	return map


func _own_rids() -> Array[RID]:
	var rids: Array[RID] = []
	_collect_rids(self, rids)
	return rids


func _collect_rids(node: Node, rids: Array[RID]) -> void:
	if node is CollisionObject3D:
		rids.append(node.get_rid())
	for child in node.get_children():
		_collect_rids(child, rids)


# ------------------------------------------------------------ aplicar poses
func _apply_poses(delta: float) -> void:
	if _skeleton == null:
		return
	for entry in _bones:
		var idx: int = entry["index"]
		var target: Vector3 = entry["target_pos"]
		var current: Vector3 = entry["current_pos"]
		if use_smoothing:
			current = current.lerp(target, clampf(smoothing_speed * delta, 0.0, 1.0))
		else:
			current = target
		entry["current_pos"] = current
		var rest: Transform3D = entry["rest_pose"]
		var pose := Transform3D(entry["target_basis"], current)
		# Convertir de espacio global del esqueleto a pose local del hueso
		var parent_idx := _skeleton.get_bone_parent(idx)
		var parent_global := Transform3D.IDENTITY
		if parent_idx >= 0:
			parent_global = _skeleton.get_bone_global_pose(parent_idx)
		var local_pose := parent_global.affine_inverse() * pose
		_skeleton.set_bone_pose_position(idx, local_pose.origin)
		if align_to_surface_normal:
			_skeleton.set_bone_pose_rotation(idx, local_pose.basis.get_rotation_quaternion())


# ------------------------------------------------------------ API publica
func adapt_to_shelter() -> void:
	if not _initialized:
		_initialize()
	if not _initialized:
		return
	_did_initial_adapt = true
	_compute_targets()


func update_net_immediately() -> void:
	adapt_to_shelter()
	var prev := use_smoothing
	use_smoothing = false
	_apply_poses(0.0)
	use_smoothing = prev


func reset_net_pose() -> void:
	if _skeleton == null:
		return
	for entry in _bones:
		var idx: int = entry["index"]
		var initial: Transform3D = entry["initial_pose"]
		_skeleton.set_bone_pose_position(idx, initial.origin)
		_skeleton.set_bone_pose_rotation(idx, initial.basis.get_rotation_quaternion())
		entry["target_pos"] = entry["rest_pose"].origin
		entry["current_pos"] = entry["rest_pose"].origin


func set_adaptation_enabled(enabled: bool) -> void:
	adapt_enabled = enabled
	if enabled:
		adapt_to_shelter()


func set_collision_mask(mask: int) -> void:
	collision_mask = mask
