extends SceneTree

# Retrato de inventario con rifle/M4 en mano:
# - En el rig vivo, _update_rifle_ik pone WeaponOffset en top_level y lo
#   resuelve cada frame en espacio mundo.
# - El duplicado del retrato conserva esa transform MUNDIAL del fotograma de
#   apertura, asi que el arma quedaba fuera del encuadre del thumbnail.
# - pose_rifle_for_portrait re-sienta el rifle sobre el esqueleto posado del
#   duplicado con la misma resolucion de reposo que el solver vivo.

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _setup_third_person_animation(_character: Node3D) -> void: pass

var errors := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _pose_dup_like_portrait(actor, dup: Node3D) -> Skeleton3D:
	# Mismo flujo que SurvivalInventory.update_portrait: rest pose -> sync.
	for modifier in dup.find_children("*", "SkeletonModifier3D", true, false):
		(modifier as SkeletonModifier3D).active = false
	var dup_skel: Skeleton3D = actor._find_skeleton(dup)
	if dup_skel != null:
		dup_skel.clear_bones_global_pose_override()
		for i in range(dup_skel.get_bone_count()):
			var rest := dup_skel.get_bone_rest(i)
			dup_skel.set_bone_pose_position(i, rest.origin)
			dup_skel.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
			dup_skel.set_bone_pose_scale(i, rest.basis.get_scale())
		dup_skel.force_update_all_bone_transforms()
		actor._sync_posed_attachments(dup, dup_skel)
	return dup_skel

func _rifle_mesh_center(model: Node3D) -> Vector3:
	var rifle_mesh := model.find_child("RifleMesh", true, false)
	if rifle_mesh == null:
		return Vector3.INF
	var bounds := AABB()
	var has_aabb := false
	for node in rifle_mesh.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.mesh == null:
			continue
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		bounds = world_aabb if not has_aabb else bounds.merge(world_aabb)
		has_aabb = true
	if not has_aabb:
		return Vector3.INF
	return bounds.get_center()

func _test_rifle(rifle_name: String) -> void:
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.global_position = Vector3(150.0, 2.0, 300.0)
	actor.equip_clothing("Camiseta")
	var live_skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	check(live_skel != null, "[%s] live skeleton found" % rifle_name)
	actor._build_third_person_rifle(rifle_name)
	check(actor._rifle_weapon_offset != null, "[%s] held rifle mounted" % rifle_name)
	# Simula el solver por frame del juego: top_level + posicion en el mundo.
	actor._update_rifle_ik(live_skel, 0.016)
	check(actor._rifle_weapon_offset.top_level, "[%s] live WeaponOffset runs top_level" % rifle_name)
	var rh_name := actor._resolve_bone_name_safe(actor.right_hand_bone_name, live_skel)
	var live_rh := live_skel.find_bone(rh_name)
	check(live_rh >= 0, "[%s] right hand bone found" % rifle_name)

	# Duplicado del retrato, en otra parte del arbol (como el SubViewport).
	var dup: Node3D = actor.third_person_model.duplicate(0)
	dup.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(dup)
	var dup_skel := _pose_dup_like_portrait(actor, dup)
	check(dup_skel != null, "[%s] dup skeleton found" % rifle_name)
	var dup_wo := dup.find_child("WeaponOffset", true, false) as Node3D
	var dup_rg := dup.find_child("RightGrip", true, false) as Marker3D
	check(dup_wo != null and dup_rg != null, "[%s] dup rifle nodes present" % rifle_name)
	var dup_rh := dup_skel.find_bone(rh_name)
	var dup_rh_pos: Vector3 = (dup_skel.global_transform * dup_skel.get_bone_global_pose(dup_rh)).origin
	# BUG: sin re-sentar, el arma duplicada sigue en la posicion del mundo vivo.
	var stale_dist := dup_rg.global_position.distance_to(dup_rh_pos)
	check(stale_dist > 20.0, "[%s] repro: duplicated rifle keeps stale world transform (dist %.1f)" % [rifle_name, stale_dist])
	# FIX: re-sentar como hace update_portrait.
	var seated: bool = actor.pose_rifle_for_portrait(dup, dup_skel)
	check(seated, "[%s] pose_rifle_for_portrait seats the rifle" % rifle_name)
	var grip_err := dup_rg.global_position.distance_to(dup_rh_pos)
	check(grip_err < 0.60, "[%s] rifle grip sits on the portrait hand (err %.3f)" % [rifle_name, grip_err])
	var center := _rifle_mesh_center(dup)
	check(center != Vector3.INF, "[%s] rifle mesh AABB resolved" % rifle_name)
	var frame_err := center.distance_to(Vector3(0.0, 1.0, 0.0))
	check(frame_err < 2.0, "[%s] rifle renders inside the portrait frame (dist %.2f)" % [rifle_name, frame_err])
	print("[%s] grip_err=%.3f frame_err=%.2f stale=%.1f" % [rifle_name, grip_err, frame_err, stale_dist])
	dup.queue_free()
	actor.stats.free()
	actor.queue_free()

func run() -> void:
	_test_rifle("Rifle francotirador")
	await process_frame
	_test_rifle("Fusil de asalto")
	await process_frame
	print("PORTRAIT_RIFLE_ERRORS=", errors)
	quit(1 if errors else 0)
