extends SceneTree
## Isolated pack, coat, corpse, save and network checks. Never writes saves.
const Packs = preload("res://scripts/WolfPack.gd")
const Saves = preload("res://scripts/SaveGameHooks.gd")
const Crafting = preload("res://scripts/CraftingSystem.gd")

class Net:
	var is_connected := true
	var is_host := true
	var is_dedicated_server := true
	var peer = null
	var players := {}
	var animals := {}
	func snapshot_recipients() -> Array[int]:
		return []

class World extends "res://scripts/Main.gd":
	var blocked_wolf_point := Vector3.INF
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _exit_tree() -> void: pass
	func _save_world_change_silent() -> void: pass
	func _save_server_world() -> void: pass
	func is_wolf_allowed_at(pos: Vector3) -> bool: return pos != blocked_wolf_point
	func is_wildlife_allowed_at(_pos: Vector3) -> bool: return true
	func _get_exact_ground_y(_x: float, _z: float, _reference_y: float = 100.0) -> float: return 0.0
	func find_path_wolf(_start: Vector3, goal: Vector3) -> Array: return [goal]
	func find_path_wildlife(_start: Vector3, goal: Vector3) -> Array: return [goal]

class CountingWolf extends WildlifeController:
	var prey_scans := 0
	var corpse_scans := 0
	func _build_animal() -> void: pass
	func _play_wolf_sound(_sound: String) -> void: pass
	func _find_nearest_prey() -> Node3D:
		prey_scans += 1
		return super._find_nearest_prey()
	func _find_nearest_corpse() -> Node3D:
		corpse_scans += 1
		return super._find_nearest_corpse()

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func spawn(world: World, group: RefCounted, pos: Vector3) -> WildlifeController:
	var wolf := world._create_wildlife_animal("wolf", [pos, pos + Vector3(0, 0, 12)], group)
	wolf.set_process(false)
	wolf._wolf_hunger = 90.0
	wolf._howl_timer = 1000.0
	wolf._chase_cooldown = 0.0 # Explicitly test post-spawn combat, past its 15 s grace.
	return wolf

func run() -> void:
	var engine_net = root.get_node("NetworkManager")
	var previous_dedicated: bool = engine_net.is_dedicated_server
	engine_net.is_dedicated_server = true
	var world := World.new()
	root.add_child(world)
	current_scene = world
	world.net = Net.new()
	var group := world._new_wolf_pack()
	var other_group := world._new_wolf_pack()
	var leader := spawn(world, group, Vector3.ZERO)
	var follower := spawn(world, group, Vector3(30, 0, 0))
	var rear := spawn(world, group, Vector3(3, 0, 0))
	var stranger := spawn(world, other_group, Vector3(2, 0, 0))
	check(leader.black_coat and leader.is_pack_leader(), "Pack starts with a black leader")
	check(not follower.black_coat and not follower.is_pack_leader(), "Followers retain their grey coat")
	check(group.members.size() == 3 and other_group.members.size() == 1, "Membership is explicit")
	var formation := follower._wolf_ai(0.1)
	check((formation["target"] as Vector3).distance_to(leader.global_position) < 12.0, "Straggler returns to its leader")
	check(float(formation["speed"]) > follower.move_speed, "Straggler catches up")
	check(float(group.patrol(leader)["speed"]) < leader.move_speed, "Leader slows to regroup")
	world.blocked_wolf_point = formation["target"]
	check(group.patrol(follower)["target"] != world.blocked_wolf_point, "Formation leaves room for a narrow riverbank")
	world.blocked_wolf_point = Vector3.INF
	check(follower._get_flank_sign() != rear._get_flank_sign(), "Pack members take opposite flanks")
	var threat := Node3D.new()
	world.add_child(threat)
	leader._alert_nearby_pack(threat)
	check(follower._chase_target == threat and rear._chase_target == threat, "Threat is relayed inside the pack")
	check(stranger._chase_target != threat, "Adjacent unrelated pack does not receive private alerts")
	follower._state = "patrol"
	rear._state = "patrol"
	stranger._state = "patrol"
	leader._rally_pack_on_howl()
	check(follower._noise_attract_timer > 0.0 and stranger._noise_attract_timer <= 0.0, "Howl rallies only this pack")
	var deer := world._create_wildlife_animal("deer", [Vector3(15, 0, 0), Vector3(20, 0, 0)])
	deer.set_process(false)
	follower._state = "chase_prey"
	follower._chase_target = deer
	check(group.hunting_prey(rear) == deer and other_group.hunting_prey(stranger) == null, "Hunt shares an observed target within the pack")
	leader._is_dead = true
	leader._rot_timer = 240.0
	group.prune()
	check(group.leader == null and group.guide() == follower, "Survivors stay together after leader death")
	check(not follower.black_coat, "Succession does not magically recolor an existing wolf")
	follower.patrol_points = [Vector3(0, 0, 240), Vector3(0, 0, 320)]
	world._note_wildlife_death("wolf", leader.global_position)
	check(world._respawn_pack_wolf(), "Leader replacement can reuse a surviving member's route")
	var replacement: WildlifeController = group.leader
	replacement.set_process(false)
	check(replacement.global_position.distance_to(leader.global_position) >= 200.0, "Replacement stays away from the recent death site")
	check(replacement.pack == group and replacement.black_coat and replacement.is_pack_leader(), "Normal population respawn supplies a new black leader")
	check(group.members[0] == replacement and group.patrol(follower)["target"] != group.patrol(rear)["target"], "Replacement preserves distinct follower positions")
	check(leader._corpse_item_name() == "Lobo negro muerto" and leader._hide_name() == "Piel de lobo negro", "Corpse and hide preserve the black identity")
	check(WildlifeController.corpse_species(leader._corpse_item_name()) == "wolf", "Black corpse remains harvestable as a wolf")
	check(world._get_drop_model_paths(leader._corpse_item_name(), "material") == [GameConst.WOLF_MODEL], "Black corpse reuses the wolf model")
	check(Crafting.pelt_species_of(leader._hide_name()) == "lobo negro", "Crafting carries black species metadata")
	check(Crafting._pelt_output({"name": "Tocado de piel animal"}, "lobo negro")["name"] == "Tocado de piel animal", "Black hide makes the real wolf headdress")
	var base := StandardMaterial3D.new()
	var black := MaterialFactory.black_wolf_material(base)
	check(black == MaterialFactory.black_wolf_material(base) and black != base, "Coat material is shared without changing the base")
	check(base.albedo_color == Color.WHITE and black.albedo_color.r < 0.2, "Regular wolves stay grey while leaders are black")
	var hide_mat := MaterialFactory.pelt_fur_material("lobo negro")
	check(hide_mat != null and hide_mat.get_shader_parameter("tint") == MaterialFactory.BLACK_WOLF_TINT, "Black pelt shader retains the dark tint")

	var saved := Saves.collect_world_data(world)
	var dead_entry: Dictionary = {}
	for row in saved["dead_wildlife"]:
		if row["name"] == leader.name:
			dead_entry = row
	check(dead_entry.get("black", false), "World save retains the dead leader's coat")
	Saves._apply_tamed_wildlife_entry(replacement, {"owner": "8", "black": true})
	check(replacement.pack == null and replacement.black_coat, "Taming detaches the leader without bleaching it")
	saved = Saves.collect_world_data(world)
	var pet_entry: Dictionary = {}
	for row in saved["tamed_wildlife"]:
		if row["name"] == replacement.name:
			pet_entry = row
	check(pet_entry.get("black", false), "Pet save retains black coat")
	Saves._apply_tamed_wildlife_entry(replacement, {"owner": "8", "black": false})
	check(not replacement.black_coat, "Restoring a grey pet clears accidental spawn leadership tint")
	Saves._apply_tamed_wildlife_entry(replacement, pet_entry)
	world._cached_wildlife = get_nodes_in_group("wildlife")
	world._broadcast_animals()
	var leader_packet: Dictionary = world.net.animals[str(leader.name)]
	check(leader_packet.get("black", false) and leader_packet.get("d", false), "Dead black coat travels in the animal snapshot")
	var client := World.new()
	root.add_child(client)
	client.net = Net.new()
	client.net.is_host = false
	client.net.is_dedicated_server = false
	client.net.animals = world.net.animals.duplicate(true)
	client._update_puppet_animals(true)
	var puppet = client.puppet_animals[str(leader.name)]
	puppet.set_process(false)
	check(puppet.black_coat and puppet._is_dead, "Remote corpse reconstructs its black identity")
	var other = client.puppet_animals[str(stranger.name)]
	other.set_process(false)
	check(other.black_coat and other.is_pack_leader() and other.pack_id == stranger.pack_id, "Remote leader receives coat, role and pack identity")
	client.free()

	# Actual near-wolf AI: broad searches are bounded while prey remains live.
	var thinker := CountingWolf.new()
	world.add_child(thinker)
	thinker.setup("wolf", [Vector3.ZERO, Vector3(0, 0, 12)])
	thinker.set_process(false)
	thinker._howl_timer = 1000.0
	thinker._cached_wildlife = [thinker, deer]
	deer.global_position = Vector3(35, 0, 0)
	for frame in 300:
		thinker._wolf_ai(1.0 / 60.0)
	check(thinker.prey_scans <= 2 and thinker._chase_target == deer, "Pursuit keeps a validated target without a world scan per frame")
	check(thinker.corpse_scans <= 27 and thinker.corpse_scans >= 20, "Empty corpse searches run at roughly five Hz")
	deer._is_dead = true
	deer.global_position = Vector3(1, 0, 0)
	thinker._wolf_ai(1.0 / 60.0)
	check(thinker._wolf_eating_target == deer, "A witnessed kill is found immediately despite the search timer")
	print("PACK_SENSE prey_scans=", thinker.prey_scans, " corpse_scans=", thinker.corpse_scans)
	world.free()
	var spawn_world := World.new()
	root.add_child(spawn_world)
	current_scene = spawn_world
	spawn_world.net = Net.new()
	spawn_world.process_mode = Node.PROCESS_MODE_DISABLED
	await spawn_world._create_wildlife()
	var wolf_count := 0
	var leader_count := 0
	for animal in spawn_world.get_children():
		if animal is WildlifeController and animal.animal_type == "wolf":
			wolf_count += 1
			if animal.is_pack_leader():
				leader_count += 1
	check(wolf_count == 23 and leader_count == 7 and spawn_world._wolf_packs.size() == 7, "Initial spawn keeps 23 wolves and exactly seven black pack leaders")
	spawn_world.free()
	engine_net.is_dedicated_server = previous_dedicated
	if OS.get_cmdline_user_args().has("--capture") and DisplayServer.get_name() != "headless":
		await capture(engine_net)
	print("WolfPackRegression failures=", failures)
	quit(1 if failures else 0)

func capture(engine_net: Node) -> void:
	engine_net.is_dedicated_server = false
	var stage := World.new()
	root.add_child(stage)
	current_scene = stage
	root.size = Vector2i(1200, 720)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.075, 0.09, 0.11)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.8, 0.86, 1.0)
	environment.environment.ambient_light_energy = 0.65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, -30, 0)
	sun.light_energy = 2.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(20, 20)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.21, 0.24, 0.26)
	floor_mat.roughness = 1.0
	floor_mesh.material_override = floor_mat
	stage.add_child(floor_mesh)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(5.8, 3.2, 7.0)
	camera.fov = 38.0
	camera.look_at(Vector3(0, 0.65, 0.5))
	camera.make_current()
	for i in 2:
		var wolf := WildlifeController.new()
		stage.add_child(wolf)
		wolf.setup_puppet("wolf")
		wolf.set_process(false)
		wolf.position = Vector3(-1.45 if i == 0 else 1.45, 0, 0)
		wolf.set_black_coat(i == 0)
		wolf._play_animation_by_name("idle")
		var label := Label3D.new()
		label.text = "Líder negro" if i == 0 else "Lobo gris"
		label.font_size = 48
		label.pixel_size = 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = wolf.position + Vector3(0, 1.5, 0)
		stage.add_child(label)
		var hide := MaterialFactory.build_pelt_hide_mesh("lobo negro" if i == 0 else "lobo")
		hide.position = Vector3(wolf.position.x, 0.035, 1.65)
		hide.scale = Vector3.ONE * 1.65
		stage.add_child(hide)
	for frame in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var path := "res://build/tmp/wolf_pack_preview.png"
	root.get_texture().get_image().save_png(path)
	print("WOLF_PACK_CAPTURE ", ProjectSettings.globalize_path(path))
	stage.free()
