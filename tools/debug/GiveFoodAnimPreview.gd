extends SceneTree

# Preview de la animación cooperativa GiveFood.glb retargetada sobre el
# modelo real del jugador: carga el clip vía _load_give_food_animation(),
# lo reproduce en mitad de la oferta y guarda un PNG en build/tmp/.

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(560, 720)
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.equip_clothing("Camiseta")
	actor.equip_clothing("Pantalones camuflaje")

	var ap := actor.third_person_animation_player
	if ap == null or not ap.has_animation("give/GiveFoodExternal"):
		print("FAIL: give/GiveFoodExternal no cargó")
		quit(1)
		return
	var seek_t := 1.0
	var yaw := 2.6
	var output := "res://build/tmp/give_food_anim.png"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seek="):
			seek_t = float(argument.trim_prefix("--seek="))
		elif argument.begins_with("--yaw="):
			yaw = float(argument.trim_prefix("--yaw="))
		elif argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	ap.play("give/GiveFoodExternal")
	ap.seek(seek_t, true)
	ap.advance(0.0)
	ap.pause()

	# Reparentar el modelo YA poseado dentro del visor de miniatura.
	var portrait = preload("res://scripts/ItemThumbnail3D.gd").new()
	portrait.custom_minimum_size = Vector2(560, 720)
	root.add_child(portrait)
	var model: Node3D = actor.third_person_model
	model.get_parent().remove_child(model)
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
	model.position = Vector3.ZERO
	model.visible = true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1
	var skel: Skeleton3D = actor._find_skeleton(model)
	var box := AABB(Vector3(-0.4, -0.95, -0.4), Vector3(0.8, 1.9, 0.8))
	if skel != null:
		var first := true
		for i in range(skel.get_bone_count()):
			var bp: Vector3 = skel.to_global(skel.get_bone_global_pose(i).origin)
			box = AABB(bp, Vector3.ZERO) if first else box.expand(bp)
			first = false
		if first:
			box = AABB(Vector3(-0.4, -0.95, -0.4), Vector3(0.8, 1.9, 0.8))
	box = box.grow(0.08)
	var focus := box.get_center()
	var cam: Camera3D = portrait._cam
	cam.size = maxf(box.size.y, 0.9)
	cam.near = 0.05
	cam.far = 30.0
	cam.position = focus + Vector3(sin(yaw), 0.15, cos(yaw)).normalized() * 4.2
	cam.look_at(focus, Vector3.UP)
	portrait._viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	for frame in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://build/tmp")
	root.get_texture().get_image().save_png(output)
	print("Preview saved: ", output)
	quit()
