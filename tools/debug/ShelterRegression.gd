extends SceneTree

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _save_world_change_silent() -> void:
		pass

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	world._spawn_player_shelter_with_id("test", Vector3.ZERO)
	var shelter := world.get_node_or_null("PlayerShelter_test") as Node3D
	check(shelter != null, "New shelter must load through crafting/spawn path")
	if shelter == null:
		quit(1)
		return
	check(shelter.is_in_group("world_action_visual"), "Shelter supports standard visual cleanup")
	var meshes := shelter.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1, "Shelter stays batched in one mesh")
	var box: AABB = meshes[0].get_aabb()
	check(box.size.y > 1.9 and box.size.y < 2.4 and box.size.z > 3.0, "Shelter uses human-scale dimensions")
	check(absf(shelter.scale.x - world.SHELTER_SCALE) < 0.001, "Shelter spawns enlarged so a standing player fits inside")
	var world_box := NodeUtils.compute_node_world_aabb(shelter)
	check(world_box.size.y > 2.4 and world_box.size.z > 4.0, "Enlarged shelter gives real interior space")
	check(world._apply_shelter_lining_state("test"), "A built shelter accepts its hide lining")
	check(world.get_node_or_null("PlayerShelter_test_PeltLining") != null, "Hide lining has a persistent visual node")
	check(bool(world._built_shelters[0].get("pelt_lined", false)), "Hide lining is stored with shelter world state")
	check(world._apply_shelter_camo_state("test", true), "A built shelter accepts its camouflage net")
	var camo_node := world.get_node_or_null("PlayerShelter_test_CamoNet") as Node3D
	check(camo_node != null, "Camo net has a persistent visual node over the shelter")
	if camo_node != null:
		var cols := camo_node.find_children("*", "CollisionObject3D", true, false)
		check(cols.is_empty(), "Camo net over shelter has no collision so the player can walk through the entrance")
		var net_box := NodeUtils.compute_node_world_aabb(camo_node)
		check(net_box.size.x > world_box.size.x + 0.6, "Camo net pools past the shelter sides onto the ground")
		check(net_box.size.z > world_box.size.z + 0.6, "Camo net pools past the shelter front/back onto the ground")
		check(net_box.position.y < 0.08, "Camo net skirt reaches down to the ground")
		var net_mat: Material = null
		for nm in camo_node.find_children("*", "MeshInstance3D", true, false):
			if (nm as MeshInstance3D).material_override != null:
				net_mat = (nm as MeshInstance3D).material_override
				break
		check(net_mat != null and net_mat.cull_mode == BaseMaterial3D.CULL_DISABLED, "Camo net renders double-sided so it is visible from inside the shelter")
	check(bool(world._built_shelters[0].get("camo_covered", false)), "Camo state is stored with shelter world state")
	if "--preview" in OS.get_cmdline_user_args():
		await preview(world)
	check(world._apply_shelter_camo_state("test", false), "Camo net can be removed from the shelter")
	check(world.get_node_or_null("PlayerShelter_test_CamoNet") == null, "Removing camo net frees its visual node")
	check(not bool(world._built_shelters[0].get("camo_covered", false)), "Removing camo net updates shelter world state")
	world._spawn_player_shelter_with_id("test", Vector3.ZERO)
	check(world.world_actions_by_id.size() == 1, "Repeated network spawn does not duplicate shelter")
	world._net_shelter_dismantled("test")
	await process_frame
	check(world.get_node_or_null("PlayerShelter_test") == null, "Dismantling removes entire shelter")
	check(world.get_node_or_null("PlayerShelter_test_PeltLining") == null, "Dismantling removes hide lining too")
	check(not world.world_actions_by_id.has("test"), "Dismantling removes interaction")
	world.free()
	if failures == 0:
		print("PASS: shelter loads, scale, batching, duplicate sync and complete dismantling")
	quit(1 if failures else 0)

func preview(world: Node3D) -> void:
	root.size = Vector2i(1400, 900)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/external/polyhaven/forest_leaves_02/textures/forest_leaves_02_diffuse_2k.jpg")
	mat.albedo_color = Color(.38,.40,.32)
	mat.uv1_scale = Vector3(55,55,1)
	mat.roughness = 1.0
	floor_mesh.material_override = mat
	floor_mesh.position.y = -.06
	world.add_child(floor_mesh)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.15,.19,.20)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.80,.87,1.0)
	env.environment.ambient_light_energy = .50
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-35,0)
	sun.light_energy = .7
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.fov = 62
	var shots := [
		{"file": "shelter_camo_exterior.png", "pos": Vector3(5.4, 3.6, 6.6), "look": Vector3(0, 1.0, -0.1)},
		{"file": "shelter_camo_inside.png", "pos": Vector3(0, 0.95, -0.55), "look": Vector3(0, 1.05, 4.0)},
		{"file": "shelter_camo_inside_up.png", "pos": Vector3(0, 0.55, -0.15), "look": Vector3(0, 2.6, 0.8)},
	]
	for shot in shots:
		camera.position = shot["pos"]
		camera.look_at(shot["look"])
		for i in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://build/tmp")
		root.get_texture().get_image().save_png("res://build/tmp/" + shot["file"])
		print("Preview saved: build/tmp/" + shot["file"])
