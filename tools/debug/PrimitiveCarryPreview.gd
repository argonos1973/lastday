extends SceneTree
const ITEMS := [
	["bow", "Arco reforzado", "weapon_bow"], ["spear", "Lanza", "tool_spear"],
	["bone_spear", "Lanza de hueso", "tool_spear"], ["bolas", "Boleadoras", "weapon_bolas"],
	["knife", "Cuchillo", "weapon"], ["axe", "Hacha", "tool_axe"],
	["shovel", "Pala", "tool_shovel"], ["hoe", "Azada", "tool_hoe"],
	["rod", "Caña de pescar", "tool_fishing"], ["torch", "Antorcha", "tool_torch"],
	["bottle", "Botella de agua", "water"],
	["food", "Naranja", "food"],
]
var failures := 0
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _physics_process(_d): pass
func _initialize(): call_deferred("run")
func run():
	root.always_on_top = true
	root.size = Vector2i(800,800)
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.flashlight = SpotLight3D.new()
	actor.flashlight.visible = false
	actor.add_child(actor.flashlight)
	actor.setup_as_puppet()
	actor.set_process(false)
	actor.equip_clothing("Camiseta")
	actor.equip_clothing("Pantalones")
	actor.is_puppet = false
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35,-25,0)
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.13,.16,.19)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .7
	root.add_child(env)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.6
	camera.position = Vector3(3,2.6,-4)
	camera.look_at(Vector3(0,1.3,0))
	camera.make_current()
	var ap := actor.third_person_animation_player
	var skel := actor._find_skeleton(actor.third_person_model)
	var shovel_contact := {}
	actor._grip_modifier.modification_processed.connect(func():
		if actor._puppet_held == "Pala" and ap.current_animation == actor._motion("dig"):
			var pivot := actor.third_person_hand_item_root.get_node_or_null("PalmGripVisual")
			if pivot != null and pivot.has_meta("dig_support"):
				shovel_contact["palm"] = skel.global_transform * skel.get_bone_global_pose(actor._left_hand_bone_idx) * actor._spear_palm_point(skel, actor._left_hand_bone_idx, true)
				shovel_contact["shaft"] = actor.third_person_hand_item_root.global_transform * (pivot.get_meta("dig_support") as Vector3)
	)
	var local_bounds := {}
	var selected_items: PackedStringArray = []
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--items="):
			selected_items = arg.trim_prefix("--items=").split(",")
	for remote in [false, true]:
		actor.is_puppet = remote
		for entry in ITEMS:
			if not selected_items.is_empty() and not entry[0] in selected_items:
				continue
			var item = preload("res://scripts/Item.gd").create(entry[1],entry[2],1,1,0)
			actor._held_item_reference = item
			actor._held_item_external = true
			actor._puppet_held = entry[1]
			if remote:
				actor._update_puppet_held_item(entry[1])
			else:
				actor._sync_third_person_equipment(item)
				actor._fit_held_prop_to_palm(item)
			var item_root: Node3D = actor._torch_hand_root if entry[0] == "torch" else actor.third_person_hand_item_root
			var bounds: AABB = actor._hierarchy_local_aabb(item_root)
			if remote:
				var expected: AABB = local_bounds[entry[0]]
				# The flame billboards move within a few centimetres.
				var tolerance := 0.03 if entry[0] == "torch" else 0.005
				if bounds.size.distance_to(expected.size) > tolerance or bounds.position.distance_to(expected.position) > tolerance:
					failures += 1
					push_error("Local/remote prop mismatch: %s local=%s remote=%s" % [entry[0], expected, bounds])
			else:
				local_bounds[entry[0]] = bounds
			actor._is_aiming = false
			var modes := ["carry", "walk", "action"]
			if entry[0] in ["spear", "bone_spear", "bolas"]:
				modes.append("throw")
			for mode in modes:
				var clip: String = actor.third_person_walk_animation if mode == "walk" else actor.third_person_idle_animation
				if mode == "throw":
					clip = actor._throw_animation_name()
					if remote:
						actor._puppet_anim = "throw"
					else:
						actor._throw_release_item = item
						actor._throw_release_target = Vector3(0, 2.0, -20)
				elif entry[0] == "torch":
					actor._load_torch_animations()
					clip = actor._torch_walk_animation if mode == "walk" else actor._torch_idle_animation
				elif mode == "action":
					if entry[0] == "bow":
						clip = actor._bow_shoot_animation
					elif entry[0] == "bottle":
						item_root.visible = false
						actor._generic_hand_grip = false
						actor._build_third_person_drink_bottle_left_hand()
						clip = actor.third_person_drink_animation
					elif entry[0] == "food":
						actor._build_eating_prop()
						clip = actor.third_person_eat_animation
					elif entry[0] == "shovel":
						clip = actor._motion("dig")
					elif entry[0] == "rod":
						actor._load_rod_animations()
						clip = actor._rod_fish_start_animation
						actor._is_fishing = true
						actor.third_person_action_animation = clip
						actor.third_person_action_timer = ap.get_animation(clip).length
						actor._activate_rod_visual_overlay(actor.THIRD_PERSON_EXTERNAL_ROD_FISH_START_ANIMATION)
					else:
						clip = actor.third_person_attack_animation
				if clip.is_empty() or not ap.has_animation(clip):
					failures += 1
					push_error("Missing held-item clip: " + str(entry))
					continue
				print(entry[0], " ", mode, " remote=", remote, " clip=", clip)
				ap.play(clip,0)
				ap.speed_scale = 0.0
				var folder := "res://build/tmp/held_%s_%s_%s" % [entry[0], mode, "remote" if remote else "local"]
				DirAccess.make_dir_recursive_absolute(folder)
				for frame in 24:
					var time := frame * ap.get_animation(clip).length / 24.0
					if mode == "throw":
						var phase := frame / 23.0
						time = actor.THROW_ANIM_FREEZE_TIME + phase * actor.THROW_RELEASE_DELAY
						actor._throw_release_timer = (1.0 - phase) * actor.THROW_RELEASE_DELAY
					ap.seek(time, true)
					ap.advance(0.0)
					if entry[0] == "rod" and mode == "action":
						actor._update_rod_visual_overlay()
					await process_frame
					await RenderingServer.frame_post_draw
					var socket: Node3D = actor._drink_hand_root if entry[0] == "bottle" and mode == "action" else item_root
					if socket == null or socket.get_child_count() == 0 or not socket.global_position.is_finite():
						failures += 1
						push_error("Missing or invalid held object: " + str(entry))
					if entry[0] == "shovel" and mode == "action":
						if shovel_contact.is_empty() or shovel_contact.palm.distance_to(shovel_contact.shaft) > 0.015:
							failures += 1
							push_error("Digging support hand misses the real shaft at %d: %s" % [frame, shovel_contact])
					if frame in [0, 8, 16] or "--frames" in OS.get_cmdline_user_args():
						root.get_texture().get_image().save_png(folder+"/%03d.png"%frame)
				actor._clear_third_person_drink_bottle_left_hand()
				actor._throw_release_item = null
				actor._puppet_anim = ""
				item_root.visible = true
				if entry[0] == "rod":
					actor._deactivate_rod_visual_overlay()
					actor._is_fishing = false
					actor.third_person_action_animation = ""
					actor.third_person_action_timer = 0.0
	actor.queue_free()
	await process_frame
	print("PRIMITIVE_CARRY_PREVIEW_DONE failures=", failures)
	quit(1 if failures else 0)
