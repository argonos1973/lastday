extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const PlayerScript = preload("res://scripts/PlayerController.gd")
const BoatScript = preload("res://scripts/Rowboat.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")

class TestWorld extends MainScript:
	func _ready() -> void:
		set_process(false)
		set_process_input(false)
	func _save_world_change_silent() -> void:
		pass

class TestBoat extends BoatScript:
	func _send_state() -> void:
		pass

class TestPlayer extends PlayerScript:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		inventory = preload("res://scripts/Inventory.gd").new()
		add_child(inventory)
		stats = preload("res://scripts/SurvivalStats.gd").new()
		add_child(stats)
		third_person_model = load(ADAPTED_PLAYER_MODEL).instantiate()
		third_person_model.scale = Vector3.ONE * MIXAMO_CHARACTER_SCALE
		third_person_model.rotation.y = PI
		add_child(third_person_model)
		for mesh in third_person_model.find_children("*", "MeshInstance3D", true, false):
			mesh.visible = str(mesh.name) in ["Body_arms", "Body_hands", "Body_legs", "Body_torso", "Tops", "Bottoms", "Shoes", "Eyes", "Eyelashes", "Hair"]
		third_person_animation_player = AnimationPlayer.new()
		third_person_model.add_child(third_person_animation_player)
		var lib := AnimationLibrary.new()
		lib.add_animation("Idle", Animation.new())
		third_person_animation_player.add_animation_library("", lib)
		third_person_idle_animation = "Idle"
		camera = Camera3D.new()
		add_child(camera)
	func _sync_held_item() -> void:
		pass

class TestNetwork extends Node:
	var is_connected := true
	var is_host := true
	var is_dedicated_server := false
	var peer = null
	var rowboat_state: Dictionary = {}
	var players := {1: {"pos": Vector3.ZERO}, 2: {"pos": Vector3.ZERO}, 3: {"pos": Vector3.ZERO}}
	func get_my_id() -> int:
		return 1

var errors := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok:
		errors += 1

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	world.river_segments_data = [{"center": Vector3(250, 0.085, -307), "size": Vector2(150, 90), "yaw": 0.0}]
	world._create_invisible_collision_box("Ground", Vector3(250, -0.3, -307), Vector3(220, 0.3, 140))
	var actor: PlayerScript = PlayerScript.new() if OS.get_cmdline_user_args().has("--full-player") else TestPlayer.new()
	world.player = actor
	world.add_child(actor)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.set_process_input(false)
	var boat := TestBoat.new()
	boat.name = "LakeRowboat"
	boat.lake_center = Vector3(250, 0.085, -307)
	boat.position = boat.clamp_to_lake(Vector3(260, 0, -270))
	world.lake_rowboat = boat
	world.add_child(boat)
	boat.set_physics_process(false)
	boat.set_process(false)
	await physics_frame
	await physics_frame
	actor.position = Vector3(260, 0.2, -268)
	check(boat.get_interaction_text().contains("Entrar"), "Boarding prompt")
	check(boat.can_board_from(actor.position), "Can board from nearby shore")
	check(not boat.can_board_from(Vector3.ZERO), "Cannot board remotely")
	check(not boat.can_board_from(Vector3(NAN, 0, 0)), "Reject non-finite positions")
	boat.request_action(1, "enter")
	check(boat.occupant == 1 and actor.rowing_boat == boat, "Enter boat attaches local character")
	check(actor.third_person_animation_player.has_animation("rowing/Stroke"), "Blender animation retargeted")
	var skeleton := actor._find_skeleton(actor.third_person_model)
	var max_grip_error := 0.0
	for t in [0.0, 0.5, 1.0, 1.5, 1.999]:
		boat.rowing_time = t
		boat._process(0)
		skeleton.force_update_all_bone_transforms()
		for pair in [["Left", "Right", Vector3(0.731112, 0.368468, 0.543565)], ["Right", "Left", Vector3(-0.745247, 0.378858, 0.558715)]]:
			var oar: Node3D = boat.visual.find_child("Oar" + pair[0], true, false)
			var target: Vector3 = oar.to_global(pair[2]) + Vector3(0, 0.02, -0.14)
			var wrist: Vector3 = skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_" + pair[1] + "Hand")).origin
			max_grip_error = maxf(max_grip_error, wrist.distance_to(target))
	print("MAX_GRIP_ERROR=", max_grip_error)
	check(max_grip_error < 0.04, "Hands stay aligned with oars throughout the cycle")
	var shore := boat.find_exit_position()
	check(not shore.is_empty(), "Safe disembark point on shore")
	var original := boat.position
	for i in range(120):
		boat.accept_input(1, Vector2(0, -1))
		boat.simulate(1.0 / 60.0)
	check(boat.position.distance_to(original) > 2.0, "Forward rowing moves boat")
	check(boat.speed <= BoatScript.MAX_SPEED, "Speed capped")
	boat.accept_input(999, Vector2(1, 1))
	check(boat._axis == Vector2(0, -1), "Non-occupants cannot steer")
	boat.accept_input(1, Vector2(INF, NAN))
	check(boat._axis.is_finite(), "Reject non-finite input")
	boat.accept_input(1, Vector2(1000, 1000))
	check(boat._axis.length() <= 1.001, "Clamp oversized input")
	boat.simulate(0.6)
	check(boat._axis == Vector2.ZERO and not boat.rowing, "Input timeout stops rowing")
	boat.position = boat.clamp_to_lake(boat.lake_center)
	check(boat.find_exit_position().is_empty(), "Cannot exit in deep water")
	boat._request_times.clear()
	boat.request_action(1, "exit")
	check(boat.occupant == 1, "Exit request rejected away from shore")
	for i in range(3000):
		boat.accept_input(1, Vector2(0, -1))
		boat.simulate(1.0 / 60.0)
	check(boat.contains_hull(boat.position) and boat.speed == 0.0, "Hull cannot cross lake boundary")
	boat.position = original
	boat.rotation.y = 0
	boat._request_times.clear()
	boat.request_action(1, "exit")
	check(boat.occupant == 0 and actor.rowing_boat == null, "Exit releases controls and passenger")
	check(world.get_river_depth_at(actor.position) == 0, "Exit lands on dry terrain")
	boat._request_times.clear()
	boat.request_action(1, "enter")
	var saved := boat.save_state()
	check(SaveHooks.collect_player_data(actor).get("rowboat_aboard", false), "Save records passenger state")
	boat._release_passenger()
	boat.position = boat.lake_center
	boat.restore_state(saved, actor)
	check(boat.position.distance_to(original) < 0.01 and boat.occupant == 1, "Save restores boat and seated character")
	var net := TestNetwork.new()
	world.add_child(net)
	world.net = net
	net.players[2].pos = actor.position
	boat.request_action(2, "enter")
	check(boat.occupant == 1, "Host rejects competing passenger")
	boat.accept_input(2, Vector2.ONE)
	check(boat._axis == Vector2.ZERO, "Host rejects another peer's controls")
	boat._request_times.clear()
	boat.request_action(99, "enter")
	check(boat.occupant == 1, "Host rejects unknown peer")
	actor.is_dead = true
	boat._physics_process(0.01)
	check(boat.occupant == 0 and net.players[1].anim == "dead", "Death releases seat without reviving passenger")
	actor.is_dead = false
	net.is_host = false
	boat.apply_network_state({"seq": 2, "pos": original, "yaw": 0.3, "occupant": 1, "time": 0.5, "rowing": true, "exit": actor.position, "can_exit": false})
	boat._process(0.1)
	check(boat.occupant == 1 and actor.rowing_boat == boat, "Client applies authoritative occupancy and animation")
	boat.apply_network_state({"seq": 1})
	check(boat.occupant == 1, "Client ignores stale snapshots")
	boat.apply_network_state({"seq": 3, "pos": original, "yaw": 0.3, "occupant": 0, "time": 0.5, "rowing": false, "exit": Vector3(260, 0.2, -267), "can_exit": true})
	check(actor.rowing_boat == null and actor.position.z == -267, "Client applies safe exit")
	world.net = null
	if OS.get_cmdline_user_args().has("--preview"):
		boat.position = original
		actor.position = Vector3(260, 0.2, -268)
		boat._request_times.clear()
		boat.request_action(1, "enter")
		boat.rowing_time = 0.5
		boat._process(0)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-50, -30, 0)
		world.add_child(light)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color(0.16, 0.22, 0.28)
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = 0.7
		world.add_child(env)
		actor.camera.global_position = boat.position + Vector3(5, 4, 6)
		actor.camera.look_at(boat.position + Vector3.UP)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lastday_rowboat_preview.png")
	world._scene_quitting = true
	world.queue_free()
	await process_frame
	await process_frame
	print("ROWBOAT_ERRORS=", errors)
	quit(1 if errors else 0)
