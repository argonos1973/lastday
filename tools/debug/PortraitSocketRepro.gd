extends SceneTree

# Reproduce el bug del retrato de inventario: el duplicado congela la pose
# in-game pero el AnimationPlayer del retrato fuerza idle. Los accesorios
# cuyo transform solo actualiza el script del jugador (sombrero, mochila)
# quedan en la pose vieja.

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

var _sit_bones := {
	"mixamorig_Hips": Quaternion(Vector3(0.12, -0.99, 0.0).normalized(), 0.9),
	"mixamorig_Spine": Quaternion(Vector3.RIGHT, 0.30),
	"mixamorig_Spine1": Quaternion(Vector3.RIGHT, 0.30),
	"mixamorig_Spine2": Quaternion(Vector3.RIGHT, 0.25),
	"mixamorig_Neck": Quaternion(Vector3.RIGHT, -0.35),
	"mixamorig_Head": Quaternion(Vector3.RIGHT, -0.20),
	"mixamorig_LeftUpLeg": Quaternion(Vector3.RIGHT, -1.1),
	"mixamorig_RightUpLeg": Quaternion(Vector3.RIGHT, -1.1),
}

func _make_pose_ap(model: Node3D, skel: Skeleton3D) -> AnimationPlayer:
	# AnimationPlayer de prueba: "sit" encorva el esqueleto, "idle" lo devuelve
	# al rest pose. Misma mecánica que las anims external/ del juego real.
	var ap := AnimationPlayer.new()
	model.add_child(ap)
	ap.root_node = ap.get_path_to(skel)
	var sit := Animation.new()
	var idle := Animation.new()
	for bone_name in _sit_bones.keys():
		var idx := skel.find_bone(bone_name)
		if idx < 0:
			continue
		var rest: Quaternion = skel.get_bone_rest(idx).basis.get_rotation_quaternion()
		var t_sit := sit.add_track(Animation.TYPE_ROTATION_3D)
		sit.track_set_path(t_sit, NodePath(".:" + bone_name))
		sit.rotation_track_insert_key(t_sit, 0.0, _sit_bones[bone_name])
		var t_idle := idle.add_track(Animation.TYPE_ROTATION_3D)
		idle.track_set_path(t_idle, NodePath(".:" + bone_name))
		idle.rotation_track_insert_key(t_idle, 0.0, rest)
		# La cadera también baja en la sentadura
	var hips_idx := skel.find_bone("mixamorig_Hips")
	if hips_idx >= 0:
		var rest_pos: Vector3 = skel.get_bone_rest(hips_idx).origin
		var tp := sit.add_track(Animation.TYPE_POSITION_3D)
		sit.track_set_path(tp, NodePath(".:mixamorig_Hips"))
		sit.position_track_insert_key(tp, 0.0, rest_pos + Vector3(0.0, -0.30, 0.15))
		var tp2 := idle.add_track(Animation.TYPE_POSITION_3D)
		idle.track_set_path(tp2, NodePath(".:mixamorig_Hips"))
		idle.position_track_insert_key(tp2, 0.0, rest_pos)
	var lib := AnimationLibrary.new()
	lib.add_animation("sit", sit)
	lib.add_animation("idle", idle)
	ap.add_animation_library("external", lib)
	return ap

func _apply_pose(ap: AnimationPlayer, anim_name: String, skel: Skeleton3D) -> void:
	ap.play(anim_name)
	ap.seek(0.0, true)
	ap.advance(0.0)
	skel.force_update_all_bone_transforms()

func run() -> void:
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.equip_clothing("Camiseta")
	actor.equip_clothing("Sombrero de pescador")
	actor.equipped_backpack = "Mochila"
	actor._build_third_person_backpack()

	var model: Node3D = actor.third_person_model
	var skel: Skeleton3D = actor._head_skeleton
	var hat: Node3D = model.get_node("Worn_Sombrero de pescador")
	var back_root: Node3D = model.get_node("BackpackSocket")
	check(hat != null, "hat equipped")
	check(back_root != null and back_root.get_child_count() > 0, "backpack asset built")
	var head_idx := actor._head_bone_idx
	var spine_idx := actor._spine_bone_idx
	check(head_idx >= 0, "head bone found")
	check(spine_idx >= 0, "spine bone found")

	var ap := _make_pose_ap(model, skel)
	actor.third_person_idle_animation = "external/idle"

	# Referencia en pose idle/de pie (la anim aún no ha movido nada).
	var head_local := model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(head_idx)
	var ref_hat_offset: Vector3 = head_local.affine_inverse() * hat.transform.origin
	var spine_local := model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(spine_idx)
	var ref_bp_offset: Vector3 = spine_local.affine_inverse() * back_root.transform.origin

	# --- El jugador se sienta: los sockets siguen al hueso en el modelo vivo ---
	_apply_pose(ap, "external/sit", skel)
	# Un hueso posado por código (IK/aim) que la anim de idle no cubre.
	var thumb_idx := skel.find_bone("mixamorig_LeftHandThumb1")
	if thumb_idx >= 0:
		skel.set_bone_pose_rotation(thumb_idx, Quaternion(Vector3.FORWARD, 0.9))
	skel.force_update_all_bone_transforms()
	actor._update_head_worn_items()
	actor._update_backpack_socket()

	var sit_head_local := model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(head_idx)
	var sit_hat_offset: Vector3 = sit_head_local.affine_inverse() * hat.transform.origin
	check(sit_hat_offset.distance_to(ref_hat_offset) < 0.02, "in-game: hat tracks the head bone while sitting (off=%s ref=%s)" % [sit_hat_offset, ref_hat_offset])
	var sit_spine_local := model.global_transform.affine_inverse() * skel.global_transform * skel.get_bone_global_pose(spine_idx)
	var sit_bp_offset: Vector3 = sit_spine_local.affine_inverse() * back_root.transform.origin
	check(sit_bp_offset.distance_to(ref_bp_offset) < 0.02, "in-game: backpack tracks the spine bone while sitting (off=%s ref=%s)" % [sit_bp_offset, ref_bp_offset])

	# --- Preview de inventario: duplicar y forzar idle como update_portrait ---
	var dup: Node3D = model.duplicate(0)
	dup.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(dup)
	var dup_ap: AnimationPlayer = null
	for node in dup.find_children("*", "AnimationPlayer", true, false):
		dup_ap = node as AnimationPlayer
		break
	var idle_name := str(actor.third_person_idle_animation)
	if dup_ap != null and not idle_name.is_empty() and dup_ap.has_animation(idle_name):
		dup_ap.play(idle_name)
		dup_ap.seek(0.4, true)
		dup_ap.advance(0.0)
	var dup_skel := actor._find_skeleton(dup)
	if dup_skel != null:
		# Mismo flujo que update_portrait: reset a rest → idle → seek → sync.
		dup_skel.clear_bones_global_pose_override()
		for i in range(dup_skel.get_bone_count()):
			var rest := dup_skel.get_bone_rest(i)
			dup_skel.set_bone_pose_position(i, rest.origin)
			dup_skel.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
			dup_skel.set_bone_pose_scale(i, rest.basis.get_scale())
		if dup_ap != null and not idle_name.is_empty() and dup_ap.has_animation(idle_name):
			dup_ap.play(idle_name)
			dup_ap.seek(0.4, true)
			dup_ap.advance(0.0)
		dup_skel.force_update_all_bone_transforms()
		actor._sync_posed_attachments(dup, dup_skel)

	# Sanity: el cuerpo del retrato sí volvió a idle
	if dup_skel != null:
		var dup_head_pose := dup_skel.get_bone_global_pose(head_idx)
		var live_head_pose := skel.get_bone_global_pose(head_idx)
		print("HEAD_POSE dup=", dup_head_pose.origin, " live_sit=", live_head_pose.origin)

	var dup_hat: Node3D = dup.get_node_or_null("Worn_Sombrero de pescador")
	var dup_back: Node3D = dup.get_node_or_null("BackpackSocket")
	check(dup_hat != null, "dup hat present")
	check(dup_back != null, "dup backpack present")
	if dup_skel != null and dup_hat != null and dup_back != null:
		var dup_model_inv := dup.global_transform.affine_inverse()
		var dup_head_local := dup_model_inv * dup_skel.global_transform * dup_skel.get_bone_global_pose(head_idx)
		var dup_hat_offset: Vector3 = dup_head_local.affine_inverse() * dup_hat.transform.origin
		var hat_err := dup_hat_offset.distance_to(ref_hat_offset)
		check(hat_err < 0.03, "preview: hat sits on the idle head (error %.3f)" % hat_err)
		var dup_spine_local := dup_model_inv * dup_skel.global_transform * dup_skel.get_bone_global_pose(spine_idx)
		var dup_bp_offset: Vector3 = dup_spine_local.affine_inverse() * dup_back.transform.origin
		var bp_err := dup_bp_offset.distance_to(ref_bp_offset)
		check(bp_err < 0.03, "preview: backpack follows the idle spine (error %.3f)" % bp_err)
		print("HAT_OFFSET ref=%s dup=%s err=%.4f" % [ref_hat_offset, dup_hat_offset, hat_err])
		print("BP_OFFSET ref=%s dup=%s err=%.4f" % [ref_bp_offset, dup_bp_offset, bp_err])
	# El hueso posado por código (fuera de la anim) debe quedar en rest:
	# el retrato siempre muestra idle completo, sin restos de la pose vieja.
	if dup_skel != null and thumb_idx >= 0:
		var rest_rot: Quaternion = dup_skel.get_bone_rest(thumb_idx).basis.get_rotation_quaternion()
		var dup_rot: Quaternion = dup_skel.get_bone_pose_rotation(thumb_idx)
		var rot_err := absf(dup_rot.angle_to(rest_rot))
		check(rot_err < 0.05, "preview: code-posed bones reset to idle too (err %.3f rad)" % rot_err)

	actor.stats.free()
	actor.queue_free()
	await process_frame
	print("PORTRAIT_SOCKET_ERRORS=", errors)
	quit(1 if errors else 0)
