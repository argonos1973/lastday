extends SceneTree
# Sample camera aiming without ADS while turning; both skinned knuckles must
# stay on the weapon contacts. Uses an isolated actor without world/saves.
# Run without --headless to also check the actual GPU skin matrices.

const ItemData = preload("res://scripts/Item.gd")

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

class World extends Node3D:
	var hud = null

var live_errors := 0
var worst_render_gap := 0.0

func check_live(ok: bool, message: String) -> void:
	if not ok:
		live_errors += 1
		if live_errors <= 12:
			push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() != "headless":
		root.always_on_top = true
	var aiming := false
	var use_m4 := true
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.set_process(false)
	# This first section tests the solver synchronously; the live section below
	# lets the engine run the modifier and checks the pose actually rendered.
	actor._grip_modifier.active = false
	if use_m4 and not aiming:
		actor.equip_clothing("Chaqueta militar digital")
		actor.equip_clothing("Chaleco táctico")
		actor.equip_clothing("Pantalones cargo con rodilleras")
		actor.equip_clothing("Guantes militares")
	else:
		actor.equip_clothing("Camiseta")
	var w_name: String = actor.M4_NAME if use_m4 else "Rifle francotirador"
	actor._puppet_held = w_name
	actor._update_puppet_held_item(w_name)
	actor._rifle_in_hands = true
	actor._has_rifle = true
	actor._is_aiming = aiming
	var hip_fire := "--hip-fire" in OS.get_cmdline_user_args()
	if hip_fire:
		actor.is_puppet = false
		actor._is_firing = true
		actor._frontal_camera = true
		actor.camera = Camera3D.new()
		actor.add_child(actor.camera)
		actor.camera.rotation.y = PI
	var player: AnimationPlayer = actor.third_person_animation_player
	var anim: String = actor._rifle_aim_idle_animation if aiming else actor._rifle_idle_animation
	if "--walk" in OS.get_cmdline_user_args():
		anim = actor._rifle_walk_animation
	if "--turn-left" in OS.get_cmdline_user_args():
		anim = actor._rifle_left_turn_animation
	if "--turn-right" in OS.get_cmdline_user_args():
		anim = actor._rifle_right_turn_animation
	print("ANIM=", anim, " has=", player != null and player.has_animation(anim))
	if player != null and player.has_animation(anim):
		player.play(anim, 0.0)
		player.advance(0.4)
	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	for i in 10:
		player.advance(0.016)
		skel.force_update_all_bone_transforms()
		actor._update_rifle_ik(skel, 1.0 / 60.0)
		await process_frame
	# Freeze the animation and converge manually so the measurements reflect the
	# steady pose, not per-frame anim drift. _solve_aim_arms only runs when
	# aiming — calling it in idle drags the hands to the aim markers.
	player.pause()
	for i in 6:
		actor._update_rifle_ik(skel, 1.0 / 60.0)
		skel.force_update_all_bone_transforms()
		if aiming:
			actor._solve_aim_arms()
		else:
			actor._on_skeleton_updated()
		skel.force_update_all_bone_transforms()
	# Settle the sling too — with the rifle held it drapes from the gun back to
	# the body guides and must be updated to render its true shape.
	for i in 8:
		actor._update_rifle_strap(1.0 / 30.0)
		await process_frame
	await process_frame
	var errors := 0
	var worst := 0.0
	player.play(anim, 0.0)
	var length := player.get_animation(anim).length
	for frame in 90:
		player.advance(length / 90.0)
		actor.rotation.y = frame * 0.07
		actor._pitch = deg_to_rad(55.0 * sin(frame * TAU / 90.0))
		actor._update_rifle_ik(skel, 1.0 / 30.0)
		actor._on_skeleton_updated()
		skel.force_update_all_bone_transforms()
		for side in ["Right", "Left"]:
			var idx := skel.find_bone("mixamorig_" + side + "HandMiddle1")
			var rig := actor._grip_rig_for(skel, skel.get_bone_parent(idx), side == "Left")
			var actual: Vector3 = skel.global_transform * skel.get_bone_global_pose(idx) * rig["middle_pivot"]
			var marker: Vector3 = actor._rg_right_knuckle if side == "Right" else actor._rg_left_knuckle
			var gap := actual.distance_to(actor._rifle_weapon_offset.global_transform * marker)
			worst = maxf(worst, gap)
			if gap > 0.015:
				errors += 1
				push_error("%s idle grip frame %d gap %.4f" % [side, frame, gap])
		var barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
		var sight := (-actor.global_basis.z).rotated(actor.global_basis.x, actor._pitch).normalized()
		if not barrel.is_finite() or barrel.dot(sight) < 0.999:
			errors += 1
			push_error("M4 must follow camera direction without ADS")
		var sh := skel.find_bone("mixamorig_RightShoulder")
		var shoulder: Vector3 = skel.global_transform * skel.get_bone_global_pose(sh).origin
		var up := (-sight).cross(actor.global_basis.x).normalized()
		var pocket := shoulder + actor.global_basis.x * 0.02 - up * 0.08 - sight * 0.04
		if actor._rifle_stock_ref.global_position.distance_to(pocket) > 0.002:
			errors += 1
			push_error("M4 stock detached from shoulder")
		if actor._is_aiming:
			errors += 1
			push_error("Camera posture must not enable ADS")
	if hip_fire:
		current_scene = actor
		actor._spawn_muzzle_flash(Vector3(99, 99, 99), Vector3.BACK)
		var flash := actor.get_node_or_null("MuzzleFlash") as Node3D
		if flash == null or flash.global_position.distance_to(actor._rifle_muzzle.global_position) > 0.001:
			errors += 1
			push_error("Flash must originate at visible muzzle, not collision-adjusted bullet origin")
		actor.rotation.y += 0.5
		if flash != null: flash._process(0.0)
		if flash != null and flash.global_position.distance_to(actor._rifle_muzzle.global_position) > 0.001:
			errors += 1
			push_error("Flash must follow barrel during recoil/turn")
	actor.queue_free()
	actor.stats.free()
	await process_frame
	await test_live_pipeline()
	errors += live_errors
	print("M4_IDLE_GRIP errors=%d worst_gap=%.6fm" % [errors, worst])
	quit(1 if errors else 0)

func test_live_pipeline() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var gpu := DisplayServer.get_name() != "headless"
	if gpu:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -20, 0)
		world.add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.14, 0.16, 0.18)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.65
		world.add_child(env)
	var view := Camera3D.new()
	view.projection = Camera3D.PROJECTION_ORTHOGONAL
	view.size = 3.5
	world.add_child(view)
	for local_player in [false, true]:
		var actor := Actor.new()
		world.add_child(actor)
		actor.stats = preload("res://scripts/SurvivalStats.gd").new()
		actor.add_child(actor.stats)
		actor.inventory = preload("res://scripts/Inventory.gd").new()
		actor.add_child(actor.inventory)
		actor.setup_as_puppet()
		actor.equip_clothing("Chaqueta militar digital")
		actor.equip_clothing("Chaleco táctico")
		actor.equip_clothing("Pantalones camuflaje")
		actor.equip_clothing("Botas militares")
		var weapon_name: String = "Rifle francotirador" if "--sniper" in OS.get_cmdline_user_args() else actor.M4_NAME
		actor.puppet_apply_visuals("", weapon_name, "")
		actor.puppet_set_rifle(true)
		if local_player:
			actor.is_puppet = false
			actor.camera = Camera3D.new()
			actor.add_child(actor.camera)
			var item = ItemData.create(weapon_name, "weapon_rifle", 3.5)
			actor.inventory.items.append(item)
			actor._held_item_reference = item
			actor._rifle_in_hands = true
		var ap: AnimationPlayer = actor.third_person_animation_player
		var skel: Skeleton3D = actor._hand_skeleton
		var mesh: MeshInstance3D = actor._find_mesh_in_third_person("Desnudo_hands")
		var skin := skel.register_skin(mesh.skin)
		var bind_by_name := {}
		for bind in mesh.skin.get_bind_count():
			bind_by_name[String(mesh.skin.get_bind_name(bind))] = bind
		var rendered := {}
		var animated_spine := [Basis.IDENTITY]
		var spine := skel.find_bone("mixamorig_Spine2")
		# Observe the animation BEFORE the controller's mixer callback.
		ap.mixer_applied.disconnect(actor._on_third_person_mixer_applied)
		ap.mixer_applied.connect(func():
			animated_spine[0] = skel.get_bone_global_pose(spine).basis.orthonormalized()
		)
		ap.mixer_applied.connect(actor._on_third_person_mixer_applied)
		actor._grip_modifier.modification_processed.connect(func():
			rendered["spine"] = skel.get_bone_global_pose(spine).basis.orthonormalized()
			rendered["spine_input"] = animated_spine[0]
			for side in ["Right", "Left"]:
				var bone := skel.find_bone("mixamorig_" + side + "HandMiddle1")
				rendered[side] = skel.get_bone_global_pose(bone)
		)
		var clips := [actor._rifle_aim_idle_animation, actor._rifle_walk_animation,
			actor._rifle_left_turn_animation, actor._rifle_aim_idle_animation,
			actor._rifle_fire_animation, actor._rifle_aim_idle_animation]
		if "--directions" in OS.get_cmdline_user_args():
			for family in ["walk", "run", "crouch_walk"]:
				for direction in actor.CharacterMotions.DIRECTIONS:
					var clip: String = actor._motion(family + "_" + direction)
					check_live(not clip.is_empty(), "Directional rifle clip exists: " + family + "/" + direction)
					if not clip.is_empty():
						clips.append(clip)
		if "--actions" in OS.get_cmdline_user_args():
			for role in ["prone_idle", "kneel_idle", "crouch_turn_left", "crouch_turn_right",
					"prone_turn_left", "prone_turn_right", "reload_stand", "reload_crouch", "reload_prone", "fire_crouch", "fire_prone",
					"jump_up", "jump_air", "jump_land", "stand_to_crouch", "crouch_to_stand",
					"stand_to_kneel", "kneel_to_stand", "kneel_to_prone", "prone_to_kneel"]:
				clips.append(actor._motion(role))
		for phase in clips.size():
			actor._puppet_anim = clips[phase]
			print("RIFLE_CLIP local=", local_player, " clip=", clips[phase])
			ap.play(clips[phase], 0.12 if phase < 6 else 0.0)
			actor._is_aiming = phase == 3
			actor._is_firing = phase == 4 or str(clips[phase]).contains("/fire_")
			actor.is_crouching = str(clips[phase]).contains("crouch")
			actor.is_prone = str(clips[phase]).contains("prone")
			actor.is_sitting = str(clips[phase]).contains("kneel")
			var running := str(clips[phase]).begins_with("motion/run_")
			# Local sprint is a controller flag; puppets only receive the tag.
			actor.is_sprinting = local_player and running
			var is_reload: bool = actor._is_rifle_reload_clip(clips[phase])
			if local_player:
				# Debug camera looks sideways, but ready pose must face forward.
				actor._side_camera = not actor._is_aiming
			for frame in 24:
				if phase >= 6:
					ap.seek(ap.get_animation(clips[phase]).length * float(frame) / 24.0, true)
				await process_frame
				actor.rotation.y = frame * 0.015
				actor._pitch = deg_to_rad(20.0 if phase == 0 else 55.0 * sin(frame * TAU / 24.0))
				if local_player and actor._is_aiming:
					actor.camera.rotation = Vector3(actor._pitch, 0, 0)
				view.position = actor.global_basis * Vector3(-3.5, 2.1, -1.5)
				view.look_at(Vector3(0, 1.5, -0.1))
				view.make_current()
				if gpu:
					await RenderingServer.frame_post_draw
				else:
					await process_frame
				if rendered.is_empty():
					continue
				if running and actor._mounted_rifle_is_m4:
					var barrel := (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
					check_live(not actor._m4_camera_ready() and not actor._rifle_aim_pose_active,
						"Running M4 must use carry, not shoulder aim (local=%s)" % local_player)
					check_live(barrel.dot(-actor.global_basis.z) < 0.85 and barrel.dot(actor.global_basis.y) < -0.12,
						"Running M4 must point across/down in its actual rendered pose (local=%s)" % local_player)
				for side in ["Right", "Left"]:
					var bone := skel.find_bone("mixamorig_" + side + "HandMiddle1")
					var rig := actor._grip_rig_for(skel, skel.get_bone_parent(bone), side == "Left")
					var pose: Transform3D = rendered[side]
					if gpu:
						var bind: int = bind_by_name[skel.get_bone_name(bone)]
						pose = RenderingServer.skeleton_bone_get_transform(skin.get_skeleton(), bind) * mesh.skin.get_bind_pose(bind).affine_inverse()
					var point: Vector3 = skel.global_transform * pose * rig["middle_pivot"]
					var contact: Vector3 = actor._rg_right_knuckle if side == "Right" else actor._rg_left_knuckle
					var expected_contact: Vector3 = actor._rifle_weapon_offset.global_transform * contact
					if is_reload and side == "Left":
						var progress := ap.current_animation_position / ap.get_animation(clips[phase]).length
						var grip = actor._rifle_action_grip
						if progress >= 0.08 and progress <= 0.55 and not grip._magazine.is_empty():
							var part: Dictionary = grip._magazine[0]
							expected_contact = part.node.global_transform * (part.root as Transform3D).affine_inverse() * grip._mag_contact
						elif progress >= 0.64 and progress <= 0.76 and not grip._bolt.is_empty():
							expected_contact = grip._bolt.node.global_transform * (grip._bolt.root as Transform3D).affine_inverse() * grip._bolt_contact
						elif progress > 0.04 and progress < 0.96:
							continue # Free travel between actual contacts.
					var gap := point.distance_to(expected_contact)
					worst_render_gap = maxf(worst_render_gap, gap)
					check_live(gap < 0.015, "Rendered %s %s hand detached: %.4f m (local=%s clip=%s)" % [weapon_name, side, gap, local_player, clips[phase]])
				var axis := skel.global_basis.orthonormalized().inverse() * actor.global_basis.x.normalized()
				var expected := Basis(axis, actor._pitch if actor._m4_camera_ready() and not actor._is_aiming else 0.0) * (rendered["spine_input"] as Basis)
				var angle := expected.get_rotation_quaternion().angle_to((rendered["spine"] as Basis).get_rotation_quaternion())
				check_live(angle < 0.005, "M4 spine pitch applied more than once (%.2f degrees)" % rad_to_deg(angle))
				if gpu and phase in [0, 3] and frame == 12 and "--preview" in OS.get_cmdline_user_args():
					DirAccess.make_dir_recursive_absolute("res://build/tmp")
					root.get_texture().get_image().save_png("res://build/tmp/m4_live_%s_%s.png" % ["local" if local_player else "remote", "ads" if phase == 3 else "ready"])
		actor.free()
	world.free()
	print("M4_LIVE_POSE gpu=%s errors=%d worst_contact=%.6fm" % [gpu, live_errors, worst_render_gap])
