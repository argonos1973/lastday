extends SceneTree
## Isolated real-player clothing review. No map generation or save writes.
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
	var test_rifle := false
	func _has_rifle_equipped() -> bool: return test_rifle
	func _create_scope_overlay(): pass
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func check_cuffs(garment: MeshInstance3D, skel: Skeleton3D, label: String):
	for side in ["Left", "Right"]:
		var hand := skel.find_bone("mixamorig_"+side+"Hand")
		var anchor := skel.global_transform * skel.get_bone_global_rest(hand).origin
		var target := skel.global_transform * skel.get_bone_global_pose(hand).origin
		var center := Vector3.ZERO
		var count := 0
		for surf in garment.mesh.get_surface_count():
			var a := garment.mesh.surface_get_arrays(surf)
			var verts: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array = a[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = a[Mesh.ARRAY_WEIGHTS]
			var influences: int = bones.size()/verts.size()
			for v in verts.size():
				var rest := Vector3.ZERO
				var pose := Vector3.ZERO
				for k in influences:
					var offset := v*influences+k
					var bind := bones[offset]
					var bone := garment.skin.get_bind_bone(bind)
					var local := garment.skin.get_bind_pose(bind)*verts[v]
					rest += (skel.get_bone_global_rest(bone)*local)*weights[offset]
					pose += (skel.get_bone_global_pose(bone)*local)*weights[offset]
				rest = skel.global_transform*rest
				if absf(rest.x-anchor.x)<.035 and rest.distance_to(anchor)<.12:
					center += skel.global_transform*pose
					count += 1
		check(count>8,"Cuff vertices found: "+side)
		if count>0:
			var distance := (center/count).distance_to(target)
			print("CUFF ",label," ",side," ",snappedf(distance,.001)," m")
			check(distance<.085,"Cuff detached from wrist: "+label+" "+side)
func _initialize(): call_deferred("run")
func run():
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	root.size = Vector2i(1500,1000)
	var actors: Array = []
	for i in 3:
		var actor := Actor.new()
		stage.add_child(actor)
		actor.position.x = (i-1)*1.5
		actor.stats = preload("res://scripts/SurvivalStats.gd").new()
		actor.inventory = preload("res://scripts/Inventory.gd").new()
		actor.add_child(actor.inventory)
		actor.setup_as_puppet()
		for item in ["Chaqueta militar digital", "Pantalones cargo con rodilleras", "Botas de montaña", "Gorra militar"]:
			actor.equip_clothing(item)
		var head := actor.third_person_model.find_child("HeadMesh", true, false) as MeshInstance3D
		check(head != null and head.has_meta("autumn_original_head"), "Head mask created")
		if head != null and head.has_meta("autumn_original_head"):
			var original := head.get_meta("autumn_original_head") as Mesh
			var masked := head.mesh
			check(masked != original, "Covered shoulder skin masked")
			actor.unequip_clothing("Chaqueta militar digital")
			check(head.mesh == original, "Original head restored on unequip")
			actor.equip_clothing("Chaqueta militar digital")
			check(head.mesh == masked, "Mask restored on re-equip")
		if i == 2:
			actor.test_rifle = true
			actor._update_puppet_held_item("Rifle francotirador")
			actor._is_aiming = true
		var anim: String = [actor.third_person_idle_animation, actor.third_person_walk_animation, actor._rifle_aim_idle_animation][i]
		actor.third_person_animation_player.play(anim, 0.0)
		actor.third_person_animation_player.advance(.4)
		actor.third_person_animation_player.pause()
		var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
		if i == 2:
			actor._update_rifle_ik(skel, 1.0/30.0)
			actor._on_skeleton_updated()
		var coat: MeshInstance3D = actor._survival_cloth_nodes.get("digital_field_jacket")
		check(coat != null and coat.is_visible_in_tree(), "Coat visible")
		if coat != null:
			check_cuffs(coat,skel,anim)
		actors.append(actor)
	var env := WorldEnvironment.new()
	env.environment=Environment.new()
	env.environment.background_mode=Environment.BG_COLOR
	env.environment.background_color=Color(.18,.21,.24)
	env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color=Color.WHITE
	env.environment.ambient_light_energy=.6
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees=Vector3(-40,-35,0)
	sun.light_energy=1.2
	stage.add_child(sun)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.projection=Camera3D.PROJECTION_ORTHOGONAL
	cam.size=3.9
	var middle_skel: Skeleton3D = actors[1]._find_skeleton(actors[1].third_person_model)
	var focus: Vector3 = middle_skel.global_transform * middle_skel.get_bone_global_pose(middle_skel.find_bone("mixamorig_Hips")).origin
	for view in ([] if DisplayServer.get_name()=="headless" else ["front","back"]):
		cam.position = Vector3(0,focus.y+.25,-7) if view=="front" else Vector3(0,focus.y+.25,7)
		cam.look_at(focus)
		await create_timer(.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/root_clothes_"+view+".png")
	for actor in actors: actor.stats.free()
	stage.free()
	print("ROOT_CLOTHES_ERRORS=",errors)
	quit(1 if errors else 0)
