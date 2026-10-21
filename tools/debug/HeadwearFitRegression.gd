extends SceneTree

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _setup_third_person_animation(character: Node3D) -> void: super._setup_third_person_animation(character)

var errors := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)

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
	var hair := actor.third_person_model.find_child("Hair", true, false) as MeshInstance3D
	var original_hair := hair.mesh
	actor.equip_clothing("Sombrero de pescador")
	check(hair.mesh != original_hair, "Hair is tucked using an instance-local mesh")
	check(hair.mesh.get_aabb().size.x > original_hair.get_aabb().size.x * 0.95, "Fisherman hat preserves the natural side and nape hair")
	var model := actor.third_person_model
	var hat := model.get_node("Worn_Sombrero de pescador") as Node3D
	var rest := hat.transform
	var fit: Transform3D = actor._head_worn_rel[hat.name]
	# Mide el sombrero en el espacio bind del HeadMesh a traves del frame que
	# usa el skinning (skeleton * bone_rest * bind_pose): la ruta por nodos
	# (Armature 0.01/-90°X) no es donde los vertices se renderizan.
	var skeleton := actor._head_skeleton
	var bind := Transform3D.IDENTITY
	var skin := actor._head_mesh.skin
	for i in skin.get_bind_count():
		if skin.get_bind_bone(i) == actor._head_bone_idx or String(skin.get_bind_name(i)) == skeleton.get_bone_name(actor._head_bone_idx):
			bind = skin.get_bind_pose(i)
			break
	var mesh_to_model: Transform3D = model.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_rest(actor._head_bone_idx) * bind
	var bounds := mesh_to_model.affine_inverse() * actor._local_aabb_in(model, hat, false)
	var head := actor._head_mesh.get_aabb()
	check(bounds.end.y > head.end.y and bounds.end.y < head.end.y + head.size.y * 0.15, "Crown clears the skull without floating above it")
	check(bounds.size.x < head.size.x * 1.3, "Brim stays proportional to the head")
	var bone := actor._head_bone_idx
	var original := skeleton.get_bone_pose_rotation(bone)
	for angle in [-0.5, 0.3, 0.6]:
		skeleton.set_bone_pose_rotation(bone, original * Quaternion(Vector3.RIGHT, angle))
		skeleton.force_update_all_bone_transforms()
		skeleton.emit_signal("skeleton_updated")
		var bone_local: Transform3D = model.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		var got: Transform3D = bone_local.affine_inverse() * hat.transform
		# Explicit epsilon: re-equips inside the loop recapture the stored rel
		# through several compose/inverse chains, drifting ~5e-5 at ~27 units —
		# is_equal_approx's default epsilon is too tight for that magnitude.
		check(got.origin.distance_to(fit.origin) < 0.005 and got.basis.is_equal_approx(fit.basis), "Hat remains anchored when the head tilts")
		var before := hat.transform
		actor._wear_clothing_visual("Sombrero de pescador")
		hat = model.get_node("Worn_Sombrero de pescador")
		check(before.is_equal_approx(hat.transform), "Equipping during an animation does not bake a pose offset")
	var walk_clip := actor.third_person_walk_animation
	check(not walk_clip.is_empty() and actor.third_person_animation_player.has_animation(walk_clip), "Walk animation is loaded for headwear movement validation")
	if not walk_clip.is_empty() and actor.third_person_animation_player.has_animation(walk_clip):
		var saved_pose: Array[Transform3D] = []
		for pose_idx in skeleton.get_bone_count():
			saved_pose.append(skeleton.get_bone_pose(pose_idx))
		actor.third_person_animation_player.play(walk_clip, 0.0)
		actor.third_person_animation_player.advance(0.45)
		skeleton.force_update_all_bone_transforms()
		skeleton.emit_signal("skeleton_updated")
		var walking_bone: Transform3D = model.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone)
		var walking_hat_rel: Transform3D = walking_bone.affine_inverse() * hat.transform
		check(walking_hat_rel.origin.distance_to(fit.origin) < 0.01 and walking_hat_rel.basis.is_equal_approx(fit.basis), "Fisherman hat follows the animated head during the walk cycle")
		actor.third_person_animation_player.stop()
		for pose_idx in skeleton.get_bone_count():
			skeleton.set_bone_pose(pose_idx, saved_pose[pose_idx])
		skeleton.force_update_all_bone_transforms()
		skeleton.emit_signal("skeleton_updated")
	skeleton.set_bone_pose_rotation(bone, original)
	skeleton.force_update_all_bone_transforms()
	actor._update_head_worn_items()
	check(rest.is_equal_approx(hat.transform), "Rest pose is restored without drift")
	var helper := MeshInstance3D.new()
	helper.mesh = BoxMesh.new()
	helper.mesh.size = Vector3.ONE * 100
	helper.name = "ExportHelper"
	model.add_child(helper)
	actor._wear_clothing_visual("Sombrero de pescador")
	hat = model.get_node("Worn_Sombrero de pescador")
	check(rest.is_equal_approx(hat.transform), "Export helpers cannot change hat fit")
	helper.free()
	preload("res://scripts/InicioSaveIntegration.gd")._add_preview_hat(model, "Sombrero de pescador")
	var preview := model.get_node("PreviewHat") as Node3D
	check(preview.transform.is_equal_approx(rest), "Character-selection preview uses the gameplay fit")
	preview.free()
	actor.unequip_clothing("Sombrero de pescador")
	check(hair.mesh == original_hair, "Removing the hat restores the original hairstyle")
	actor.equip_clothing("Sombrero de pescador")
	if "--preview" in OS.get_cmdline_user_args():
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-35, -20, 0)
		root.add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.14, 0.16, 0.18)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.65
		root.add_child(env)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 1.15
		root.add_child(camera)
		var center := model.to_global(Vector3(0, head.end.y - 0.2, 0))
		var views := {"front": Vector3(0.7, 0.18, -1.7), "side": Vector3(1.7, 0.12, 0), "back": Vector3(0.4, 0.25, 1.7)}
		for view in views:
			camera.position = center + views[view]
			camera.look_at(center)
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/hat_fit_%s.png" % view)
	actor._puppet_swap_to_naked()
	check(hair.mesh == original_hair, "Remote equipment reset restores the hairstyle too")
	# Casco militar: same bone-anchored fit but the open harness/strap meshes are
	# display-only — worn they must be hidden and excluded from fit bounds.
	actor.equip_clothing("Casco militar")
	var helmet := model.get_node("Worn_Casco militar") as Node3D
	check(helmet != null, "Helmet wears through the head-slot visuals path")
	var straps_visible := 0
	for mi in helmet.find_children("*", "MeshInstance3D", true, false):
		if mi.visible and (mi.name.begins_with("Chin") or mi.name.begins_with("Front harness") or mi.name.begins_with("Rear harness") or mi.name.find("Strap adjuster") >= 0):
			straps_visible += 1
	check(straps_visible == 0, "Helmet harness and chin strap are hidden while worn")
	var helmet_fit: Transform3D = actor._head_worn_rel[helmet.name]
	var helmet_bounds := mesh_to_model.affine_inverse() * actor._local_aabb_in(model, helmet, false)
	check(helmet_bounds.end.y > head.end.y and helmet_bounds.end.y < head.end.y + head.size.y * 0.30, "Helmet dome clears the skull without floating")
	skeleton.set_bone_pose_rotation(bone, original * Quaternion(Vector3.RIGHT, 0.5))
	skeleton.force_update_all_bone_transforms()
	skeleton.emit_signal("skeleton_updated")
	var helmet_local: Transform3D = model.global_transform.affine_inverse() * skeleton.global_transform * skeleton.get_bone_global_pose(bone)
	check((helmet_local.affine_inverse() * helmet.transform).is_equal_approx(helmet_fit), "Helmet remains anchored when the head tilts")
	skeleton.set_bone_pose_rotation(bone, original)
	skeleton.force_update_all_bone_transforms()
	actor._update_head_worn_items()
	preload("res://scripts/InicioSaveIntegration.gd")._add_preview_hat(model, "Casco militar")
	var preview_helmet := model.get_node_or_null("PreviewHat") as Node3D
	check(preview_helmet != null, "Preview accepts the military helmet too")
	if preview_helmet != null:
		check(preview_helmet.transform.is_equal_approx(helmet.transform), "Helmet preview uses the gameplay fit")
		preview_helmet.free()
	if "--preview" in OS.get_cmdline_user_args():
		var camera := root.get_viewport().get_camera_3d()
		var center := model.to_global(Vector3(0, head.end.y - 0.2, 0))
		for view in {"front": Vector3(0.7, 0.18, -1.7), "side": Vector3(1.7, 0.12, 0), "back": Vector3(0.4, 0.25, 1.7)}:
			var offset: Vector3 = {"front": Vector3(0.7, 0.18, -1.7), "side": Vector3(1.7, 0.12, 0), "back": Vector3(0.4, 0.25, 1.7)}[view]
			camera.position = center + offset
			camera.look_at(center)
			await create_timer(0.2).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/tactical_helmet_%s.png" % view)
	actor.unequip_clothing("Casco militar")
	check(hair.mesh == original_hair, "Removing the helmet restores the original hairstyle")
	# Balaclavas stack under headwear in their own face slot: they hide the
	# hair while hats only tuck it, so removing one must not revive the hair.
	actor.equip_clothing("Pasamontañas")
	check(str(actor._equipped_slots.get("face", "")) == "Pasamontañas", "Balaclava occupies its own face slot")
	check(not hair.visible, "Balaclava hides the hair")
	actor.equip_clothing("Sombrero de pescador")
	check(str(actor._equipped_slots.get("head", "")) == "Sombrero de pescador" and str(actor._equipped_slots.get("face", "")) == "Pasamontañas", "Hat equips over the balaclava without dropping it")
	check(not hair.visible, "Hair stays hidden while the balaclava remains")
	actor.unequip_clothing("Sombrero de pescador")
	check(not hair.visible and str(actor._equipped_slots.get("face", "")) == "Pasamontañas", "Removing the hat keeps the balaclava and the hidden hair")
	actor.equip_clothing("Sombrero de pescador")
	actor.unequip_clothing("Pasamontañas")
	check(hair.visible and hair.mesh != original_hair, "Removing the balaclava reveals hair still tucked by the hat")
	actor.unequip_clothing("Sombrero de pescador")
	check(hair.visible and hair.mesh == original_hair, "Removing the last headwear restores the hairstyle")
	actor.stats.free()
	actor.queue_free()
	await process_frame
	print("HEADWEAR_ERRORS=", errors)
	quit(1 if errors else 0)
