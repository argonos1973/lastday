extends SceneTree
class World extends "res://scripts/Main.gd":
	func _ready(): set_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_delta): pass
	func _physics_process(_delta): pass
func posed_bounds(garment: MeshInstance3D, skeleton: Skeleton3D) -> AABB:
	var bounds := AABB()
	var first := true
	for surface in garment.mesh.get_surface_count():
		var data := garment.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = data[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
		var influences := bones.size() / vertices.size()
		for index in range(0, vertices.size(), 13):
			var point := Vector3.ZERO
			for k in influences:
				var offset := index*influences+k
				var bind := bones[offset]
				var pose := skeleton.get_bone_global_pose(garment.skin.get_bind_bone(bind)) * garment.skin.get_bind_pose(bind)
				point += (pose * vertices[index]) * weights[offset]
			point = skeleton.global_transform * point
			if first:
				bounds = AABB(point,Vector3.ZERO)
				first=false
			else: bounds=bounds.expand(point)
	return bounds
var errors := 0
func check(ok: bool, label: String):
	print("PASS " if ok else "FAIL ", label)
	if not ok: errors += 1
func _initialize(): call_deferred("run")
func run():
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var actors: Array = []
	for i in 2:
		var actor := Actor.new()
		world.add_child(actor)
		actor.position.x = (i-.5)*1.5
		actor.stats = preload("res://scripts/SurvivalStats.gd").new()
		actor.inventory = preload("res://scripts/Inventory.gd").new()
		actor.add_child(actor.inventory)
		actor.setup_as_puppet()
		actor.equip_clothing("Camiseta")
		actor.equip_clothing("Pantalones")
		actor.equip_clothing("Zapatillas")
		actor.equip_clothing("Chaqueta de cuadros" if i==0 else "Chaleco táctico")
		actor.equipped_backpack = "Mochila militar"
		actor._sync_third_person_equipment(null)
		var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
		var garment: MeshInstance3D = actor._survival_cloth_nodes.get("field_jacket_plaid" if i==0 else "field_jacket_plate_carrier")
		check(garment != null and garment.is_visible_in_tree(), "new garment visible on character %d" % i)
		check(garment != null and garment.skin != null and garment.get_node(garment.skeleton)==skel, "garment bound to live skeleton %d" % i)
		if garment != null:
			for b in garment.skin.get_bind_count():
				check(skel.find_bone(garment.skin.get_bind_name(b)) >= 0, "valid garment bone %d/%d" % [i,b])
		for animation in [actor.third_person_idle_animation,actor.third_person_walk_animation,actor._rifle_aim_idle_animation]:
			actor.third_person_animation_player.play(animation,0.0)
			actor.third_person_animation_player.advance(.4)
			var fitted := posed_bounds(garment,skel)
			check(fitted.size.length()<2.5 and fitted.position.y>0.7, "animated garment stays on upper body: "+animation)
		actor.third_person_animation_player.play(actor.third_person_walk_animation)
		actor.third_person_animation_player.advance(.4)
		actor.third_person_animation_player.pause()
		actor._update_backpack_socket()
		actors.append(actor)
	var entries := [["Chaqueta de cuadros","clothing",Vector3(90,0,0)], ["Chaleco táctico","clothing",Vector3(90,0,0)], ["Mochila militar","backpack",Vector3.ZERO], ["Azada","tool_hoe",Vector3(0,0,90)], ["Pala","tool_shovel",Vector3(0,0,90)], ["Semillas","seed",Vector3.ZERO]]
	for i in entries.size():
		var e: Array = entries[i]
		var id := "audit_"+str(i)
		world._create_pickup_item({"id":id,"name":e[0],"type":e[1],"pos":Vector3(-1.6+i*.65,0,-1),"floor_y":0.0,"paths":world._get_drop_model_paths(e[0],e[1]),"scale":world._get_drop_scale(e[0],e[1]),"rot":e[2],"weight":1.0,"qty":1,"use":0.0})
		var visual := world.get_node_or_null("Pickup_"+id)
		check(visual!=null, e[0]+" loot model loads")
		check(world.world_actions_by_id.has(id),e[0]+" pickup action exists")
		if visual!=null:
			var bounds: AABB = visual.global_transform * actors[0]._hierarchy_local_aabb(visual)
			print("LOOT_BOUNDS ",e[0]," ",bounds)
			check(bounds.end.y > 0.01 and bounds.position.y > -0.025, e[0]+" loot rests above the floor")
			check(bounds.size.length() < 3.0, e[0]+" loot has plausible dimensions")
			var visible_count := 0
			for mi in visual.find_children("*","MeshInstance3D",true,false):
				if mi.is_visible_in_tree() and mi.mesh!=null: visible_count+=1
			check(visible_count>0,e[0]+" has visible loot mesh")
	if "--preview" in OS.get_cmdline_user_args():
		var env := WorldEnvironment.new()
		env.environment=Environment.new();env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color(.13,.16,.19);env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;env.environment.ambient_light_energy=.65
		world.add_child(env)
		var sun := DirectionalLight3D.new();sun.rotation_degrees=Vector3(-40,-35,0);world.add_child(sun)
		var cam := Camera3D.new();world.add_child(cam);cam.projection=Camera3D.PROJECTION_ORTHOGONAL;cam.size=4.3
		for view in ["front","back","loot"]:
			cam.position = Vector3(0,2.3,-6) if view=="front" else Vector3(0,2.3,6)
			cam.look_at(Vector3(0,1.4,0))
			if view=="loot":
				cam.position=Vector3(0,3,-3);cam.look_at(Vector3(0,0,-1));cam.size=4.0
			await create_timer(.3).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/recent_gear_"+view+".png")
	for actor in actors: actor.stats.free()
	world.free()
	print("RECENT_GEAR_ERRORS=",errors)
	quit(1 if errors else 0)
