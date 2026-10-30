extends SceneTree

const ItemData = preload("res://scripts/Item.gd")

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1100, 760)
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.set_process(false)
	actor.equip_clothing("Camiseta")
	actor.equip_clothing("Pantalones camuflaje")

	var bow_item = ItemData.create("Arco reforzado", "weapon_bow", 0.9, 1, 0.0)
	var arrow_item = ItemData.create("Flecha de piedra", "ammo_arrow", 0.08, 6, 0.0)
	actor.inventory.add_item(bow_item)
	actor.inventory.add_item(arrow_item)
	actor.is_puppet = false
	actor._held_item_reference = bow_item
	actor._held_item_external = true
	actor._sync_third_person_equipment(bow_item)
	actor._fit_held_prop_to_palm(bow_item)
	actor._is_aiming = true

	var ap: AnimationPlayer = actor.third_person_animation_player
	print("BOW_AIM=", actor._bow_aim_idle_animation, " has=", ap != null and ap.has_animation(actor._bow_aim_idle_animation))
	print("BOW_SHOOT=", actor._bow_shoot_animation, " has=", ap != null and ap.has_animation(actor._bow_shoot_animation))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -25, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.16, 0.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.68
	root.add_child(env)

	var camera := Camera3D.new()
	camera.fov = 50.0
	root.add_child(camera)
	camera.make_current()

	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	if DisplayServer.get_name() == "headless":
		quit()
		return
	DirAccess.make_dir_recursive_absolute("res://build/tmp")
	# Real local PlayerController test (with _ready and _physics_process on a floor)
	actor.visible = false
	var floor_body := StaticBody3D.new()
	var floor_col := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20.0, 1.0, 20.0)
	floor_col.shape = floor_box
	floor_col.position = Vector3(0.0, -0.5, 0.0)
	floor_body.add_child(floor_col)
	root.add_child(floor_body)
	current_scene = floor_body
	var real_p := preload("res://scripts/PlayerController.gd").new()
	root.add_child(real_p)
	var r_bow = ItemData.create("Arco reforzado", "weapon_bow", 0.9, 1, 0.0)
	var r_arrow = ItemData.create("Flecha de piedra", "ammo_arrow", 0.08, 6, 0.0)
	real_p.receive_pickup_item(r_bow)
	real_p.inventory.add_item(r_arrow)
	real_p.camera.make_current()
	for f in range(20):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/real_player_shoulder_bow.png")
	print("Saved res://build/tmp/real_player_shoulder_bow.png shoulder0=", real_p.get_back_item_data(0))
	real_p.use_back_item(0)
	for f in range(20):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	print("REAL_CARRY anim=", real_p.third_person_animation_player.current_animation, " sock=", real_p.third_person_hand_item_root.global_position, " cam=", real_p.camera.global_position, " aabb=", preload("res://scripts/NodeUtils.gd").compute_node_world_aabb(real_p.third_person_hand_item_root))
	root.get_texture().get_image().save_png("res://build/tmp/real_player_carry_bow.png")
	real_p._toggle_aim()
	for f in range(30):
		await physics_frame
		await process_frame
	await RenderingServer.frame_post_draw
	print("REAL_AIM anim=", real_p.third_person_animation_player.current_animation, " sock=", real_p.third_person_hand_item_root.global_position, " cam=", real_p.camera.global_position, " aabb=", preload("res://scripts/NodeUtils.gd").compute_node_world_aabb(real_p.third_person_hand_item_root))
	root.get_texture().get_image().save_png("res://build/tmp/real_player_aim_bow.png")
	# Trigger an actual bow shot on real_p and capture the frame right as the arrow projectile leaves the bow
	real_p._shoot_bow()
	while real_p._bow_release_item != null:
		real_p._tick_primitive_releases(0.05)
	var spawned_arrow: Node3D = null
	for ch in floor_body.get_children():
		if "velocity" in ch:
			spawned_arrow = ch as Node3D
			spawned_arrow.set_physics_process(false)
			print("SPAWNED_ARROW origin=", spawned_arrow.global_position, " player_pos=", real_p.global_position, " bow_pos=", real_p.third_person_hand_item_root.global_position)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/real_player_shot_release.png")
	camera.global_position = real_p.global_position + Vector3(2.1, 1.85, -1.1)
	camera.look_at(real_p.global_position + Vector3(0.2, 1.85, -1.35), Vector3.UP)
	camera.make_current()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/real_player_shot_release_side.png")
	real_p.queue_free()
	floor_body.queue_free()
	actor.visible = true
	camera.make_current()

	for clip_info in [
		["aim", actor._bow_aim_idle_animation, 0.5],
		["shoot_draw", actor._bow_shoot_animation, 0.22],
	]:
		var tag: String = clip_info[0]
		var anim_name: String = clip_info[1]
		var seek_t: float = clip_info[2]
		if ap != null and ap.has_animation(anim_name):
			ap.play(anim_name, 0.0)
			ap.seek(seek_t, true)
			ap.advance(0.0)
			ap.pause()
		for i in range(6):
			skel.force_update_all_bone_transforms()
			actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
			actor._update_hand_socket()
			await process_frame

		var focus := actor.global_position + Vector3(0.0, 1.42, -0.22)
		var views := {
			"front": [focus + Vector3(0.0, 0.12, -2.55), focus],
			"side": [focus + Vector3(2.55, 0.10, 0.0), focus],
			"three_quarter": [focus + Vector3(1.85, 0.16, -1.75), focus],
			"over_shoulder": [actor.global_position + Vector3(0.36, 1.50, 1.45), actor.global_position + Vector3(-0.04, 1.48, -6.5)],
		}
		for vname in views:
			camera.global_position = views[vname][0]
			camera.look_at(views[vname][1], Vector3.UP)
			for f in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			var out_path := "res://build/tmp/bow_%s_%s.png" % [tag, vname]
			root.get_texture().get_image().save_png(out_path)
			print("Saved ", out_path)

	# 2) Scene preview of harvested animal corpse on the ground surrounded by Hueso, Tendón, Carne, Piel and Cuerda
	actor.visible = false
	var stage := Node3D.new()
	root.add_child(stage)
	var ground := MeshInstance3D.new()
	var gplane := PlaneMesh.new()
	gplane.size = Vector2(8.0, 8.0)
	ground.mesh = gplane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.24, 0.28, 0.19)
	gmat.roughness = 0.95
	ground.material_override = gmat
	stage.add_child(ground)

	var deer_scn = load("res://assets/models/wildlife/deer.glb")
	if deer_scn is PackedScene:
		var corpse := (deer_scn as PackedScene).instantiate() as Node3D
		corpse.position = Vector3(-0.35, 0.22, -0.25)
		corpse.rotation_degrees = Vector3(0.0, 25.0, -88.0)
		corpse.scale = Vector3.ONE * 0.72
		stage.add_child(corpse)

	var showcase_items := [
		["Hueso", "res://assets/models/props/animal_bone.glb", Vector3(-0.34, 0.02, 0.34), Vector3(0, 28, 0), 0.85],
		["Hueso 2", "res://assets/models/props/animal_bone.glb", Vector3(-0.08, 0.02, 0.44), Vector3(0, -42, 0), 0.80],
		["Tendón", "res://assets/models/props/animal_sinew.glb", Vector3(0.22, 0.02, 0.34), Vector3(0, 18, 0), 0.90],
		["Tendón 2", "res://assets/models/props/animal_sinew.glb", Vector3(0.42, 0.02, 0.44), Vector3(0, 75, 0), 0.85],
		["Cuerda", "res://assets/models/props/rope_coil.glb", Vector3(0.58, 0.02, 0.06), Vector3(0, 15, 0), 0.95],
		["Carne cruda", "res://assets/models/props/cc0_-_raw_meat_4.glb", Vector3(-0.52, 0.03, 0.06), Vector3(0, 40, 0), 0.95],
	]
	for entry in showcase_items:
		var ps = load(entry[1])
		if ps is PackedScene:
			var inst := (ps as PackedScene).instantiate() as Node3D
			inst.position = entry[2]
			inst.rotation_degrees = entry[3]
			inst.scale = Vector3.ONE * float(entry[4])
			stage.add_child(inst)

	camera.fov = 42.0
	camera.global_position = Vector3(0.08, 1.25, 1.55)
	camera.look_at(Vector3(0.02, 0.08, 0.12), Vector3.UP)
	for f in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/corpse_harvest_bone_sinew_preview.png")
	print("Saved res://build/tmp/corpse_harvest_bone_sinew_preview.png")

	# Close-up of Rope, Bone and Sinew models side by side
	stage.visible = false
	var closeup := Node3D.new()
	root.add_child(closeup)
	var pedestal := MeshInstance3D.new()
	var pmesh := PlaneMesh.new()
	pmesh.size = Vector2(4.0, 4.0)
	pedestal.mesh = pmesh
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.15, 0.17, 0.20)
	pmat.roughness = 0.85
	pedestal.material_override = pmat
	closeup.add_child(pedestal)
	for item_cfg in [
		["res://assets/models/props/rope_coil.glb", Vector3(-0.48, 0.02, 0.0), Vector3(18, 25, 0), 1.45],
		["res://assets/models/props/animal_bone.glb", Vector3(0.0, 0.03, 0.0), Vector3(14, -30, 0), 1.45],
		["res://assets/models/props/animal_sinew.glb", Vector3(0.48, 0.03, 0.0), Vector3(16, 28, 0), 1.55],
	]:
		var ps2 = load(item_cfg[0])
		if ps2 is PackedScene:
			var node2 := (ps2 as PackedScene).instantiate() as Node3D
			node2.position = item_cfg[1]
			node2.rotation_degrees = item_cfg[2]
			node2.scale = Vector3.ONE * float(item_cfg[3])
			closeup.add_child(node2)

	camera.fov = 36.0
	camera.global_position = Vector3(0.0, 0.78, 1.18)
	camera.look_at(Vector3(0.0, 0.05, 0.0), Vector3.UP)
	for f in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/closeup_rope_bone_sinew.png")
	print("Saved res://build/tmp/closeup_rope_bone_sinew.png")

	# 3) Real Inventory UI slots preview (ItemThumbnail3D cards for Cuerda, Hueso, Tendón, Arco de madera, Arco reforzado, Flecha de hueso)
	closeup.visible = false
	var ui_layer := CanvasLayer.new()
	root.add_child(ui_layer)
	var bg_rect := ColorRect.new()
	bg_rect.color = Color(0.08, 0.10, 0.12, 1.0)
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(bg_rect)
	var hbox := HBoxContainer.new()
	hbox.position = Vector2(55, 220)
	hbox.add_theme_constant_override("separation", 22)
	ui_layer.add_child(hbox)
	var thumb_script = preload("res://scripts/ItemThumbnail3D.gd")
	var inv_cards := [
		["Cuerda", ["res://assets/models/props/rope_coil.glb"]],
		["Hueso", ["res://assets/models/props/animal_bone.glb"]],
		["Tendón", ["res://assets/models/props/animal_sinew.glb"]],
		["Arco de madera", ["res://assets/models/weapons/wooden_bow.glb"]],
		["Arco reforzado", ["res://assets/models/weapons/reinforced_bow.glb"]],
		["Flecha de hueso", ["res://assets/models/weapons/arrow_bone.glb"]],
	]
	for card in inv_cards:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(145, 185)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.14, 0.17, 0.21, 0.96)
		sb.border_color = Color(0.75, 0.58, 0.32, 0.9)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", sb)
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(vbox)
		var th = thumb_script.new()
		th.custom_minimum_size = Vector2(130, 130)
		vbox.add_child(th)
		var lbl := Label.new()
		lbl.text = card[0]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.78))
		vbox.add_child(lbl)
		hbox.add_child(panel)
		th.set_model(card[1], 1.0, Vector3.ZERO, 1.0, "", Color(0,0,0,0), Color(0,0,0,0), "", card[0])

	for f in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/inventory_rope_bone_sinew_preview.png")
	print("Saved res://build/tmp/inventory_rope_bone_sinew_preview.png")

	# 4) In-game Archer Aiming View WITH Crosshair + Ballistic Drop Pins
	ui_layer.visible = false
	actor.visible = true
	stage.visible = true
	stage.position = Vector3(0.0, 0.0, -6.5)
	if ap != null and ap.has_animation(actor._bow_aim_idle_animation):
		ap.play(actor._bow_aim_idle_animation, 0.0)
		ap.seek(0.5, true)
		ap.advance(0.0)
		ap.pause()
	for i in range(4):
		skel.force_update_all_bone_transforms()
		actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
		actor._update_hand_socket()
		await process_frame
	camera.fov = 45.0
	actor._pitch = 0.0
	camera.global_position = actor.global_position + Vector3(0.46, 1.64, 1.42)
	camera.global_rotation = Vector3.ZERO
	actor.camera = camera
	for i in range(4):
		skel.force_update_all_bone_transforms()
		actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
		actor._update_hand_socket()
		await process_frame

	var aim_hud := preload("res://scripts/HUD.gd").new()
	root.add_child(aim_hud)
	aim_hud.root = Control.new()
	aim_hud.root.set_anchors_preset(Control.PRESET_FULL_RECT)
	aim_hud.add_child(aim_hud.root)
	aim_hud._build_center_messages()
	aim_hud.set_crosshair_bow_aim(true, true)
	aim_hud.set_crosshair_spread(5.5)

	for f in range(15):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/bow_aim_crosshair_preview.png")
	print("Saved res://build/tmp/bow_aim_crosshair_preview.png")

	# 4b) Aiming at the SKY (+42 deg pitch): side view + real orbiting aiming camera view
	actor._pitch = deg_to_rad(42.0)
	camera.global_rotation = Vector3(actor._pitch, 0.0, 0.0)
	for i in range(6):
		skel.force_update_all_bone_transforms()
		actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
		actor._update_hand_socket()
		await process_frame
	var sky_pivot := actor.global_position + Vector3(0.46, 1.22, 0.0)
	camera.global_position = sky_pivot + Vector3(0.0, 0.42, 1.42).rotated(Vector3.RIGHT, actor._pitch)
	camera.global_rotation = Vector3(actor._pitch, 0.0, 0.0)
	for f in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/bow_aim_sky_camera.png")
	print("Saved res://build/tmp/bow_aim_sky_camera.png")

	aim_hud.visible = false
	camera.global_position = actor.global_position + Vector3(2.35, 1.55, -0.15)
	camera.look_at(actor.global_position + Vector3(0.0, 1.55, -0.25), Vector3.UP)
	# Keep actor._pitch at +42 deg while rendering from side camera
	actor.camera = null
	for i in range(4):
		skel.force_update_all_bone_transforms()
		actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
		actor._update_hand_socket()
		await process_frame
	for f in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/bow_aim_sky_side.png")
	print("Saved res://build/tmp/bow_aim_sky_side.png")
	actor._pitch = 0.0
	for i in range(4):
		skel.force_update_all_bone_transforms()
		actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
		actor._update_hand_socket()
		await process_frame

	# 5) Arrow GLB lineup close-up: wood / stone / bone side by side
	aim_hud.visible = false
	actor.visible = false
	stage.visible = false
	var arrows_stage := Node3D.new()
	root.add_child(arrows_stage)
	var table := MeshInstance3D.new()
	var tmesh := PlaneMesh.new()
	tmesh.size = Vector2(4.0, 4.0)
	table.mesh = tmesh
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.16, 0.14, 0.11)
	tmat.roughness = 0.9
	table.material_override = tmat
	arrows_stage.add_child(table)
	for arrow_cfg in [
		["res://assets/models/weapons/arrow_wood.glb", Vector3(0.0, 0.03, -0.30), Vector3(0, 90, 0)],
		["res://assets/models/weapons/arrow_stone.glb", Vector3(0.0, 0.03, 0.0), Vector3(0, 90, 0)],
		["res://assets/models/weapons/arrow_bone.glb", Vector3(0.0, 0.03, 0.30), Vector3(0, 90, 0)],
	]:
		var aps = load(arrow_cfg[0])
		if aps is PackedScene:
			var an := (aps as PackedScene).instantiate() as Node3D
			an.position = arrow_cfg[1]
			an.rotation_degrees = arrow_cfg[2]
			an.scale = Vector3.ONE * 1.6
			arrows_stage.add_child(an)
	camera.fov = 40.0
	camera.global_position = Vector3(-0.15, 0.72, 1.05)
	camera.look_at(Vector3(0.0, 0.02, 0.0), Vector3.UP)
	for f in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/arrows_lineup_preview.png")
	print("Saved res://build/tmp/arrows_lineup_preview.png")

	# 6) Bow + nocked arrow close-up: tight on the hands, string in V, arrow on the grip
	arrows_stage.visible = false
	actor.visible = true
	if ap != null and ap.has_animation(actor._bow_aim_idle_animation):
		ap.play(actor._bow_aim_idle_animation, 0.0)
		ap.seek(0.5, true)
		ap.advance(0.0)
		ap.pause()
	for i in range(6):
		skel.force_update_all_bone_transforms()
		actor.third_person_model.position.y = actor._compute_skeleton_ground_target_y()
		actor._update_hand_socket()
		await process_frame
	# Frame on the real bow socket AABB (bow + string + nocked arrow live
	# under third_person_hand_item_root, parented to the animated model).
	var NodeUtilsScript = preload("res://scripts/NodeUtils.gd")
	var bow_aabb := NodeUtilsScript.compute_node_world_aabb(actor.third_person_hand_item_root)
	if bow_aabb.size.length() < 0.05:
		bow_aabb = NodeUtilsScript.compute_node_world_aabb(actor.third_person_model)
	var aabb_c := bow_aabb.get_center()
	camera.fov = 30.0
	camera.global_position = aabb_c + Vector3(0.85, 0.30, 0.55)
	camera.look_at(aabb_c, Vector3.UP)
	for f in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/bow_with_arrow_closeup.png")
	print("Saved res://build/tmp/bow_with_arrow_closeup.png")

	# 7) Real ballistic flight: spawn an actual arrow projectile with drag +
	# align_flight and capture it nosing down along the arc mid-flight.
	actor.visible = false
	var proj_script = load("res://scripts/RifleProjectile.gd")
	var proj: Node3D = proj_script.new()
	proj.velocity = Vector3(0.0, 7.2, -21.0)
	proj.max_distance = 120.0
	proj.drag_coeff = 0.28
	proj.align_flight = true
	proj.launch_speed = proj.velocity.length()
	var arrow_vis = load("res://assets/models/weapons/arrow_stone.glb")
	if arrow_vis is PackedScene:
		var av := (arrow_vis as PackedScene).instantiate() as Node3D
		av.rotation_degrees.y = 180.0
		proj.add_child(av)
	root.add_child(proj)
	proj.global_position = Vector3(0.0, 2.1, 0.0)
	proj.look_at(Vector3(0.0, 2.1 + 7.2, -21.0), Vector3.UP)
	# Fly until it is well past the apex (~14 m) so the nose-down tilt shows.
	var sim_frames := 0
	while is_instance_valid(proj) and proj.traveled < 13.0 and sim_frames < 600:
		await physics_frame
		sim_frames += 1
	if is_instance_valid(proj):
		var pf := proj.global_position
		camera.fov = 28.0
		camera.global_position = pf + Vector3(1.10, 0.22, 0.72)
		camera.look_at(pf + Vector3(0.0, -0.05, -0.5), Vector3.UP)
		for f in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/tmp/arrow_flight_arc_preview.png")
		print("Saved res://build/tmp/arrow_flight_arc_preview.png v=", proj.velocity)
		proj.queue_free()

	# 8) Stuck arrows ("flechas clavadas") embedded in ground, wooden post/wall, and animal body
	current_scene = stage
	stage.visible = true
	stage.position = Vector3.ZERO
	var post := MeshInstance3D.new()
	var post_cyl := CylinderMesh.new()
	post_cyl.top_radius = 0.16
	post_cyl.bottom_radius = 0.18
	post_cyl.height = 1.6
	post.mesh = post_cyl
	var bark_mat := StandardMaterial3D.new()
	bark_mat.albedo_color = Color(0.32, 0.21, 0.12)
	bark_mat.roughness = 0.92
	post.material_override = bark_mat
	post.position = Vector3(0.55, 0.80, -0.20)
	stage.add_child(post)
	actor._embed_stuck_projectile_visual(Vector3(0.41, 0.92, -0.12), Vector3(0.82, -0.18, -0.54).normalized(), "Flecha de piedra", "ammo_arrow", null, post)
	actor._embed_stuck_projectile_visual(Vector3(-0.28, 0.30, -0.18), Vector3(0.25, -0.58, -0.77).normalized(), "Flecha de hueso", "ammo_arrow", stage, stage)
	actor._embed_stuck_projectile_visual(Vector3(0.10, 0.02, 0.25), Vector3(0.10, -0.76, -0.64).normalized(), "Flecha de madera", "ammo_arrow", null, ground)
	camera.fov = 40.0
	camera.global_position = Vector3(-0.35, 1.15, 1.45)
	camera.look_at(Vector3(0.12, 0.42, -0.12), Vector3.UP)
	for f in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/tmp/bow_stuck_arrows_preview.png")
	print("Saved res://build/tmp/bow_stuck_arrows_preview.png")

	quit()
