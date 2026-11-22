extends SceneTree
## Renders isolated GPU previews of Linterna frontal across headwear combinations
## plus a night-time tactical military beam scene into build/tmp/headlamp_previews/.

class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass

func _initialize():
	call_deferred("run")

func run():
	var out_dir := ProjectSettings.globalize_path("res://build/tmp/headlamp_previews")
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.size = Vector2i(1000, 800)

	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.19, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.72
	stage.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -32, 0)
	sun.light_energy = 1.25
	stage.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 145, 0)
	fill.light_energy = 0.45
	stage.add_child(fill)

	var actor := Actor.new()
	stage.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	for base_item in ["Chaqueta militar digital", "Pantalones cargo con rodilleras", "Botas de montaña", "Chaleco táctico"]:
		actor.equip_clothing(base_item)
	actor.third_person_animation_player.play(actor.third_person_idle_animation, 0.0)
	actor.third_person_animation_player.advance(0.4)
	actor.third_person_animation_player.pause()

	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 0.72
	cam.make_current()

	var sk: Skeleton3D = actor._head_skeleton
	var focus: Vector3 = sk.global_transform * sk.get_bone_global_pose(actor._head_bone_idx).origin + Vector3(0.0, 0.03, 0.0)

	# [slug, face_item, head_item, pelt_species, ortho_size]
	var combos := [
		["01_bare_head", "", "", "", 0.62],
		["02_balaclava", "Pasamontañas", "", "", 0.62],
		["03_casco_militar_balaclava", "Pasamontañas", "Casco militar", "", 0.68],
		["04_gorra_militar", "", "Gorra militar", "", 0.66],
		["04b_gorro_otono", "Pasamontañas", "Gorro de otoño", "", 0.66],
		["05_sombrero_pescador", "", "Sombrero de pescador", "", 0.78],
		["06_gorro_piel", "", "Gorro de piel", "lobo", 0.78],
		["07_tocado_lobo_negro", "", "Tocado de piel animal", "lobo negro", 0.92],
		["08_tocado_ciervo", "", "Tocado de piel animal", "ciervo", 1.05],
		["09_tocado_oso", "", "Tocado de piel animal", "oso", 0.92],
		["10_tocado_zorro", "", "Tocado de piel animal", "zorro", 0.88],
	]

	actor.equip_clothing(GameConst.HEADLAMP_ITEM_NAME)
	actor.puppet_set_flashlight(true)

	for c in combos:
		var slug: String = c[0]
		var face_nm: String = c[1]
		var head_nm: String = c[2]
		var pelt_sp: String = c[3]
		cam.size = float(c[4])
		if not face_nm.is_empty():
			actor.equip_clothing(face_nm)
		if not head_nm.is_empty():
			actor.equip_clothing(head_nm, Color(0, 0, 0, 0), null, pelt_sp)
		actor._update_head_worn_items()
		actor._sync_headlamp_light_pose()
		var sub_focus := focus + (Vector3(0.0, 0.06, 0.0) if head_nm == "Tocado de piel animal" else Vector3.ZERO)
		for view in ["front", "side"]:
			# Character model is rotated 180° Y, so character faces -Z in world space!
			var offset := Vector3(0.35, 0.06, -3.2) if view == "front" else Vector3(3.2, 0.06, -0.55)
			cam.position = sub_focus + offset
			cam.look_at(sub_focus)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/%s_%s.png" % [out_dir, slug, view])
		if not head_nm.is_empty():
			actor.unequip_clothing(head_nm)
		if not face_nm.is_empty():
			actor.unequip_clothing(face_nm)

	# --- Night tactical military beam preview (player + bot companion in darkness) ---
	sun.visible = false
	fill.visible = false
	env.environment.background_color = Color(0.015, 0.022, 0.032)
	env.environment.ambient_light_color = Color(0.05, 0.07, 0.11)
	env.environment.ambient_light_energy = 0.22

	var ground := MeshInstance3D.new()
	var gplane := PlaneMesh.new()
	gplane.size = Vector2(60, 80)
	ground.mesh = gplane
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.16, 0.20, 0.14)
	gmat.roughness = 0.92
	ground.material_override = gmat
	stage.add_child(ground)

	# Distance marker crates at 8 m, 18 m, 30 m ahead (-Z) to prove night visibility
	for dist in [8.0, 18.0, 30.0]:
		for side in [-1.4, 1.4]:
			var box_mi := MeshInstance3D.new()
			var bmesh := BoxMesh.new()
			bmesh.size = Vector3(1.1, 1.1, 1.1)
			box_mi.mesh = bmesh
			var bmat := StandardMaterial3D.new()
			bmat.albedo_color = Color(0.36, 0.33, 0.26)
			bmat.roughness = 0.85
			box_mi.material_override = bmat
			box_mi.position = Vector3(side, 0.55, -float(dist))
			stage.add_child(box_mi)

	actor.equip_clothing("Pasamontañas")
	actor.equip_clothing("Casco militar")
	actor.equip_clothing(GameConst.HEADLAMP_ITEM_NAME)
	actor.puppet_set_flashlight(true)
	actor._update_head_worn_items()
	actor._sync_headlamp_light_pose()

	# Second actor representing a survivor bot wearing pelt hood + headlamp at night
	var bot := Actor.new()
	stage.add_child(bot)
	bot.stats = preload("res://scripts/SurvivalStats.gd").new()
	bot.inventory = preload("res://scripts/Inventory.gd").new()
	bot.add_child(bot.inventory)
	bot.setup_as_puppet()
	bot.position = Vector3(2.1, 0.0, -2.5)
	bot.rotation_degrees.y = 14.0
	for b_item in ["Chaqueta de piel", "Pantalones de piel", "Botas de piel"]:
		bot.equip_clothing(b_item, Color(0, 0, 0, 0), null, "lobo")
	bot.equip_clothing("Tocado de piel animal", Color(0, 0, 0, 0), null, "lobo")
	bot.equip_clothing(GameConst.HEADLAMP_ITEM_NAME)
	bot.puppet_apply_visuals("Chaqueta de piel|lobo,Pantalones de piel|lobo,Botas de piel|lobo,Tocado de piel animal|lobo," + GameConst.HEADLAMP_ITEM_NAME, actor.M4_NAME, "Mochila militar")
	bot.puppet_set_rifle(true)
	bot.puppet_set_flashlight(true)
	bot.third_person_animation_player.play(bot._rifle_idle_animation if not bot._rifle_idle_animation.is_empty() else bot.third_person_idle_animation, 0.0)
	bot.third_person_animation_player.advance(0.3)
	bot.third_person_animation_player.pause()
	bot._update_head_worn_items()
	bot._sync_headlamp_light_pose()

	cam.projection = Camera3D.PROJECTION_PERSPECTIVE
	cam.fov = 60.0
	# Over-the-shoulder 3P night view
	cam.position = Vector3(0.45, 2.05, 2.6)
	cam.look_at(Vector3(0.4, 1.0, -16.0))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/11_night_beam_3p.png" % out_dir)
	actor.puppet_set_flashlight(false)
	bot.puppet_set_flashlight(false)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/11_night_off_3p.png" % out_dir)
	actor.puppet_set_flashlight(true)
	bot.puppet_set_flashlight(true)

	# Front-quarter night view showing both soldier & bot with active tactical beams
	cam.position = Vector3(-2.6, 1.75, -6.2)
	cam.look_at(Vector3(0.9, 1.35, -1.2))
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/12_night_soldier_and_bot.png" % out_dir)

	bot.stats.free()
	actor.stats.free()
	stage.free()
	await process_frame
	print("HEADLAMP_PREVIEWS_OK dir=", out_dir)
	quit(0)
