extends SceneTree
# Non-headless capture of the rifle sling worn on the back:
#   Godot --path . --script tools/debug/RifleStrapPreview.gd
# Writes /tmp/rifle_strap_{front,side,back,three_quarter}.png

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _setup_third_person_animation(_character: Node3D) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var actor := Actor.new()
	root.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.equip_clothing("Camiseta")
	var suffix := ""
	if "--jacket" in OS.get_cmdline_user_args():
		actor.equip_clothing("Chaqueta camuflaje")
		suffix = "_jacket"
	actor._build_rifle_on_back()
	if "--pose" in OS.get_cmdline_user_args():
		# Arms down, torso leaning forward and twisted: the band must follow
		# the skinned torso and stay on top of the shirt.
		suffix += "_posed"
		var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
		actor._update_rifle_strap(1.0 / 30.0)
		var bends := {"mixamorig_LeftArm": Quaternion(Vector3.FORWARD, deg_to_rad(-70.0)), "mixamorig_RightArm": Quaternion(Vector3.FORWARD, deg_to_rad(70.0)), "mixamorig_Spine1": Quaternion(Vector3.RIGHT, deg_to_rad(18.0)), "mixamorig_Spine2": Quaternion(Vector3.UP, deg_to_rad(14.0))}
		for bone_name in bends:
			var idx := skel.find_bone(bone_name)
			if idx >= 0:
				skel.set_bone_pose_rotation(idx, skel.get_bone_pose_rotation(idx) * bends[bone_name])
		skel.force_update_all_bone_transforms()
		actor._update_backpack_socket()
	for i in 6:
		actor._update_rifle_strap(1.0 / 30.0)
		await process_frame
	var strap := actor.third_person_model.find_child("ProceduralStrapMesh", true, false) as MeshInstance3D
	print("STRAP_MESH=", strap != null and strap.mesh != null)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -20, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.14, 0.16, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	root.add_child(env)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.5
	root.add_child(camera)
	var body: AABB = actor._baked_aabb(actor.third_person_model, true)
	var center := actor.third_person_model.to_global(body.position + Vector3(body.size.x * 0.5, body.size.y * 0.72, body.size.z * 0.5))
	var front := (actor.third_person_model.global_basis * Vector3.BACK).normalized()
	var right := front.cross(Vector3.UP).normalized()
	var views := {
		"front": front * 3.0 + Vector3.UP * 0.2,
		"side": right * 3.0 + Vector3.UP * 0.1,
		"back": -front * 3.0 + Vector3.UP * 0.25,
		"three_quarter": (front - right).normalized() * 3.0 + Vector3.UP * 0.4,
	}
	for view in views:
		camera.position = center + views[view]
		camera.look_at(center)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/rifle_strap_%s%s.png" % [view, suffix])
	print("RIFLE_STRAP_PREVIEW_DONE")
	quit(0)
