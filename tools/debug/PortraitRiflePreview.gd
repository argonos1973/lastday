extends SceneTree

# Preview GPU del retrato de inventario con rifle/M4 en mano: reproduce el
# flujo de SurvivalInventory.update_portrait (duplicar -> pose idle -> sync
# -> pose_rifle_for_portrait) dentro de un ItemThumbnail3D real.

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _setup_third_person_animation(_character: Node3D) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(520, 720)
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.equip_clothing("Camiseta")
	actor.equip_clothing("Pantalones camuflaje")
	actor.equip_clothing("Chaqueta de campaña verde")
	var rifle_name := "Fusil de asalto"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--rifle="):
			rifle_name = argument.trim_prefix("--rifle=")
	actor._build_third_person_rifle(rifle_name)
	var live_skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	actor._update_rifle_ik(live_skel, 0.016)

	# --- update_portrait ---
	var portrait = preload("res://scripts/ItemThumbnail3D.gd").new()
	portrait.custom_minimum_size = Vector2(520, 720)
	root.add_child(portrait)
	var model: Node3D = actor.third_person_model.duplicate(0)
	model.process_mode = Node.PROCESS_MODE_DISABLED
	var removable: Array = []
	for node in model.find_children("*", "", true, false):
		if node is Light3D or node is CollisionObject3D:
			removable.append(node)
	for node in removable:
		if is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.free()
	portrait._model_root.add_child(model)
	model.rotation = Vector3.ZERO
	model.visible = true
	var portrait_skel: Skeleton3D = actor._find_skeleton(model)
	for modifier in model.find_children("*", "SkeletonModifier3D", true, false):
		(modifier as SkeletonModifier3D).active = false
	if portrait_skel != null:
		portrait_skel.clear_bones_global_pose_override()
		for i in range(portrait_skel.get_bone_count()):
			var rest := portrait_skel.get_bone_rest(i)
			portrait_skel.set_bone_pose_position(i, rest.origin)
			portrait_skel.set_bone_pose_rotation(i, rest.basis.get_rotation_quaternion())
			portrait_skel.set_bone_pose_scale(i, rest.basis.get_scale())
	if portrait_skel != null:
		portrait_skel.force_update_all_bone_transforms()
		actor._sync_posed_attachments(model, portrait_skel)
	if actor.pose_rifle_for_portrait(model, portrait_skel):
		for strap_name in ["ProceduralStrapMesh", "RifleSlingHardware"]:
			var strap := model.find_child(strap_name, true, false) as Node3D
			if strap != null:
				strap.visible = false
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1
	var box := AABB()
	var first_bone := true
	if portrait_skel != null:
		for i in range(portrait_skel.get_bone_count()):
			var bone_pos: Vector3 = portrait_skel.to_global(portrait_skel.get_bone_global_pose(i).origin)
			if first_bone:
				box = AABB(bone_pos, Vector3.ZERO)
				first_bone = false
			else:
				box = box.expand(bone_pos)
	var cam: Camera3D = portrait._cam
	if first_bone:
		box = AABB(Vector3(-0.4, -0.95, -0.4), Vector3(0.8, 1.9, 0.8))
	box = box.grow(0.06)
	box.size.y += 0.2
	var focus := box.get_center()
	cam.size = maxf(box.size.y, 0.8)
	cam.near = 0.05
	cam.far = 20.0
	var yaw := 0.5
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--yaw="):
			yaw = float(argument.trim_prefix("--yaw="))
	cam.position = focus + Vector3(sin(yaw), 0.18, cos(yaw)).normalized() * 4.5
	cam.look_at(focus, Vector3.UP)
	portrait._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for frame in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/tmp")
	var output := "res://build/tmp/portrait_rifle.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	root.get_texture().get_image().save_png(output)
	print("Preview saved: ", output)
	quit()
