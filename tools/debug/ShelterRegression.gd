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
	world._spawn_player_shelter_with_id("test", Vector3.ZERO)
	check(world.world_actions_by_id.size() == 1, "Repeated network spawn does not duplicate shelter")
	if "--preview" in OS.get_cmdline_user_args():
		await preview(world)
	world._net_shelter_dismantled("test")
	await process_frame
	check(world.get_node_or_null("PlayerShelter_test") == null, "Dismantling removes entire shelter")
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
	camera.position = Vector3(4.6,3.25,5.5)
	camera.look_at(Vector3(0,.90,-.1))
	camera.fov = 43
	for i in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/branch_shelter_preview.png")
