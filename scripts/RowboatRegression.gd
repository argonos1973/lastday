extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const PlayerScript = preload("res://scripts/PlayerController.gd")
const BoatScript = preload("res://scripts/Rowboat.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")
const ItemScript = preload("res://scripts/Item.gd")

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
	# Bow is +Z on the imported hull; face it into the lake like the real spawn yaw.
	boat.rotation.y = PI
	world.lake_rowboat = boat
	world.add_child(boat)
	var reflection_safe := boat.visual != null
	for part in boat.find_children("*", "GeometryInstance3D", true, false):
		reflection_safe = reflection_safe and part.layers == 1 << 17 and part.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	check(reflection_safe, "Hull and wake do not cast a water shadow or enter cached lake reflections")
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
			var target: Vector3 = oar.to_global(pair[2]) + boat.global_basis * Vector3(0, 0.02, -0.14)
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
	actor._physics_process(1.0 / 60.0)
	check(not actor.is_rowing, "Idle passenger is not marked as rowing")
	boat.accept_input(1, Vector2(0, -1))
	boat.simulate(1.0 / 60.0)
	actor._physics_process(1.0 / 60.0)
	check(actor.is_rowing and boat.rowing, "Rowing counts as exertion for survival drain")
	boat._axis = Vector2.ZERO
	boat.simulate(1.0 / 60.0)
	actor._physics_process(1.0 / 60.0)
	check(not actor.is_rowing, "Releasing the oars clears rowing exertion")
	boat.rowing_time = 0.3
	for i in range(120):
		boat.simulate(1.0 / 60.0)
	check(boat.rowing_time == 0.0, "Released oars settle back to rest pose")
	boat.rowing_time = 1.7
	for i in range(120):
		boat.simulate(1.0 / 60.0)
	check(boat.rowing_time == 0.0, "Late stroke settles forward into rest pose")
	check(boat.occupant == 1, "Resting keeps the character seated in the boat")
	boat._request_times.clear()
	boat.request_action(1, "stand")
	check(boat.occupant == 1 and boat.occupant_standing, "Stand request raises the character inside the hull")
	boat._process(0.016)
	check(actor._boat_standing, "Local occupant adopts standing mode")
	var deck_pos: Vector3 = boat.to_global(Vector3(0, BoatScript.STAND_Y, 0))
	check(actor.global_position.distance_to(deck_pos) < 0.05, "Standing pins feet on the deck")
	var hull_pos := boat.position
	boat.accept_input(1, Vector2(0, -1))
	check(boat._axis == Vector2.ZERO and boat._stand_offset.z == -1.0, "Standing input routes to occupant offset")
	for i in range(60):
		boat.simulate(1.0 / 60.0)
	check(boat.position.distance_squared_to(hull_pos) < 0.0001 and not boat.rowing, "Standing cannot row the boat")
	actor._boat_local_offset = Vector2(0.4, -1.0)
	boat._process(0.016)
	check(actor.global_position.distance_to(boat.to_global(Vector3(0.4, BoatScript.STAND_Y, -1.0))) < 0.05, "Local standing offset carried by the hull")
	var cam_fwd := -actor.camera.global_basis.z
	var expect_fwd := (boat.global_basis * Vector3(0, 0, 1)).normalized()
	check(cam_fwd.dot(expect_fwd) > 0.8, "Standing camera looks ahead of the character")
	actor.camera.global_position = boat.global_position + Vector3(0, 2.0, -8.0)
	actor.camera.look_at(boat.global_position, Vector3.UP)
	var prev_range := actor.interaction_distance
	actor.interaction_distance = 30.0
	var aim_col = actor._get_aim_collider()
	check(aim_col != boat, "Standing aim ray is not stopped by the hull")
	actor.interaction_distance = prev_range
	boat.accept_input(1, Vector2(50, 50))
	check(absf(boat._stand_offset.x) <= 1.01 and absf(boat._stand_offset.z) <= 2.71, "Server clamps occupant offset to hull rim")
	boat._request_times.clear()
	boat.request_action(1, "stand")
	check(not boat.occupant_standing and boat._stand_offset == Vector3.ZERO and boat._axis == Vector2.ZERO, "Sitting back down clears standing state")
	boat._process(0.016)
	check(not actor._boat_standing, "Occupant returns to seated mode")
	check(actor.global_position.distance_to(boat.global_position) < 0.05, "Seated occupant pinned at boat origin")
	actor._boat_local_offset = Vector2.ZERO
	boat.position = boat.clamp_to_lake(boat.lake_center)
	check(boat.find_exit_position().is_empty(), "Cannot exit in deep water")
	boat._request_times.clear()
	boat.request_action(1, "exit")
	check(boat.occupant == 1, "Exit request rejected away from shore")
	for i in range(3000):
		boat.accept_input(1, Vector2(0, -1))
		boat.simulate(1.0 / 60.0)
	check(boat.contains_hull(boat.position) and boat.speed == 0.0, "Hull cannot cross lake boundary")
	# The hull rests against the boundary; bring it back over open water so the
	# standing cast does not land on the shallow rim it just sailed into.
	boat.position = boat.clamp_to_lake(boat.lake_center)
	boat._request_times.clear()
	boat.request_action(1, "stand")
	check(boat.occupant == 1 and boat.occupant_standing, "Stands up in deep water")
	boat._process(0.016)
	var rod = ItemScript.create("Caña de pescar", "tool_fishing", 0.8)
	actor.inventory.items.append(rod)
	actor._held_item_reference = rod
	actor._has_fishing_rod = true
	check(actor._has_fishing_rod_in_hand(), "Rod equipped while standing")
	var fish_state := actor._get_fishing_water_state()
	check(bool(fish_state.get("near", false)) and bool(fish_state.get("facing", false)), "Standing cast finds open water")
	actor._start_fishing_near_water()
	check(actor._is_fishing, "Casting from the deck starts fishing")
	actor._fishing_session += 1
	actor._is_fishing = false
	actor._is_fishing_idle = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var cast_ev := InputEventMouseButton.new()
		cast_ev.button_index = MOUSE_BUTTON_LEFT
		cast_ev.pressed = true
		actor._input(cast_ev)
		check(actor._is_fishing, "LMB press while standing casts the line")
		actor._fishing_session += 1
		actor._is_fishing = false
		actor._is_fishing_idle = false
	actor._held_item_reference = null
	actor._has_fishing_rod = false
	boat._request_times.clear()
	boat.request_action(1, "stand")
	check(not boat.occupant_standing, "Sits back down to test auto-stand")
	boat._process(0.016)
	check(not actor._boat_standing, "Seated state synced before equipping")
	boat._request_times.clear()
	actor._select_held_item(actor.inventory.items.find(rod))
	var held_sel = actor.get_held_item()
	check(boat.occupant_standing and held_sel != null and str(held_sel.item_type) == "tool_fishing", "Selecting the rod while seated stands the character")
	boat._process(0.016)
	check(actor._boat_standing, "Auto-stand syncs to the local occupant")
	actor._fishing_session += 1
	actor._is_fishing = false
	actor._is_fishing_idle = false
	var fish_deck := boat.to_global(Vector3(0, BoatScript.STAND_Y, 0))
	check(world._pos_on_rowboat_deck(fish_deck), "Deck drop position detected")
	check(not world._is_water_drop_position(fish_deck), "Drops on deck are not lost to the water")
	check(world._is_water_drop_position(fish_deck + Vector3(3, 0, 0)), "Drops beside the hull still splash")
	var seen_text := {"t": "init"}
	actor.prompt_changed.connect(func(t): seen_text["t"] = t)
	actor._boat_prompt_shown = ""
	actor._boat_prompt_timer = 0.0
	actor._update_interaction_prompt()
	check(str(seen_text["t"]).contains("E:"), "Boat prompt appears on state change")
	actor._boat_prompt_timer = 0.0
	actor._update_interaction_prompt()
	check(seen_text["t"] == "", "Boat prompt fades after a few seconds")
	boat.accept_input(1, Vector2(0.95, 0))
	boat.simulate(1.0 / 60.0)
	check(boat.occupant == 0 and actor.rowing_boat == null, "Stepping over the gunwale drops the occupant into the water")
	check(world.get_river_depth_at(actor.position) > 0.0, "Overboard position lands in the lake")
	boat._request_times.clear()
	boat.request_action(1, "enter")
	check(boat.occupant == 1 and not boat.occupant_standing, "Swimming back aboard starts seated")
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
	net.is_host = true
	check(boat.get_node_or_null("WakeFx") != null, "Wake particles created")
	check(boat.get_node_or_null("OarSplashL") != null and boat.get_node_or_null("OarSplashR") != null, "Oar splash emitters created")
	var wake: GPUParticles3D = boat.get_node_or_null("WakeFx")
	var ribbon = boat._surface_wake
	if ribbon != null:
		ribbon.advance(0.1, Vector3.ZERO, Vector3.RIGHT, 0.8, true)
		for step in range(35):
			ribbon.advance(0.1, Vector3(0, 0, step * 0.25), Vector3.RIGHT, 0.8, false)
		check(ribbon.mesh.get_surface_count() == 5, "Wake uses five bounded surfaces for spreading waves and center turbulence")
		var old_position: Vector3 = ribbon.samples[0].pos
		ribbon.advance(0.1, Vector3(0.2, 0, 8.6), Vector3.FORWARD, 0.8, false)
		check(ribbon.samples[0].pos == old_position, "Turning leaves old wake samples fixed on the water")
		var old_track: int = ribbon.track
		ribbon.advance(0.1, Vector3(0.2, 0, 8.6), Vector3.RIGHT, 0.0, false)
		ribbon.advance(0.1, Vector3(0.4, 0, 8.6), Vector3.RIGHT, 0.8, false)
		check(ribbon.track > old_track, "Restart separates the new trail from the old one")
		ribbon.advance(9.0, Vector3.ZERO, Vector3.RIGHT, 0.0, false)
		check(ribbon.samples.is_empty() and ribbon.mesh.get_surface_count() == 0, "Wake fades completely after stopping")
		ribbon.advance(0.1, Vector3.ZERO, Vector3.RIGHT, 0.8, true)
		check(ribbon.samples.is_empty(), "Teleport clears wake geometry")
	if wake != null:
		boat._fx_prev_pos = boat.global_position
		boat.global_position += boat.global_basis.z * 0.05
		boat._update_water_fx(1.0 / 60.0)
		check(wake.emitting, "Wake emits while the boat moves")
		boat._fx_prev_pos = boat.global_position
		boat._update_water_fx(0.5)
		check(not wake.emitting, "Wake stops when the boat is still")
	var bow: GPUParticles3D = boat.get_node_or_null("BowFoamL")
	var churn: GPUParticles3D = boat.get_node_or_null("OarFoamL")
	check(bow != null and boat.get_node_or_null("BowFoamR") != null, "Bow foam created on both sides")
	check(churn != null and boat.get_node_or_null("OarFoamR") != null, "Oar surface foam created")
	if bow != null and churn != null:
		check((wake.process_material as ParticleProcessMaterial).gravity == Vector3.ZERO, "Wake stays on the water surface")
		check((bow.process_material as ParticleProcessMaterial).spread == 0.0, "Surface foam has no vertical spread")
		check(wake.draw_pass_1 is PlaneMesh and not wake.local_coords, "Foam lies flat and remains behind in world space")
		boat._fx_prev_pos = boat.global_position
		boat.global_position += boat.global_basis.z * 0.3
		boat._update_water_fx(0.1)
		check(bow.emitting and bow.position.z > 0, "Forward movement produces bow foam")
		check(bow.amount_ratio > 0.2 and bow.amount_ratio <= 1.0, "Foam density scales with speed")
		boat.global_position -= boat.global_basis.z * 0.9
		boat._update_water_fx(0.3)
		check(bow.emitting and bow.position.z < 0 and wake.position.z > 0, "Reverse movement swaps leading foam and wake")
		boat.global_position += Vector3(100, 0, 0)
		boat._update_water_fx(1.0 / 60.0)
		check(not bow.emitting and not wake.emitting, "Teleports do not produce a water burst")
		boat.rowing = true
		boat.rowing_time = 0.25
		boat._process(0.1)
		boat.rowing_time = 0.5
		boat._process(0.25)
		check(churn.emitting, "Oar churn emits during the power stroke")
		check(absf(churn.position.x) > 1.7 and is_equal_approx(churn.position.y, BoatScript.WATER_Y), "Oar foam follows the blade water contact, not the hull")
		var contact := churn.position
		boat.rowing_time = 0.75
		boat._process(0.25)
		check(contact.distance_to(churn.position) > 0.05, "Foam follows the animated oar")
		boat.rowing_time = 1.5
		boat._process(0.75)
		check(not churn.emitting, "Oar churn stops during recovery")
		boat.rowing = false
		boat._update_water_fx(0.5)
		check(not churn.emitting and not bow.emitting, "Idle boat stops generating foam")
		var intensity := boat._fx_speed
		boat._update_water_fx(0)
		check(is_equal_approx(boat._fx_speed, intensity), "Zero delta does not create artificial speed")
		for frame in range(180):
			if frame % 3 == 0:
				boat.global_position += boat.global_basis.z * BoatScript.MAX_SPEED / 60.0
			boat._update_water_fx(1.0 / 180.0)
		check(boat._fx_speed > BoatScript.MAX_SPEED * 0.85, "High render rates preserve wake intensity between physics ticks")
		boat.rotation.y += PI * 0.5
		boat._fx_velocity = Vector3.ZERO
		boat.global_position += boat.global_basis.z * 0.3
		boat._update_water_fx(0.1)
		check(bow.emitting and bow.position.z > 0, "Bow follows the boat heading after turning")
		boat._update_water_fx(0.5)
		boat.rowing = true
		boat.rowing_time = 0.2
		var interrupted_strokes := 0
		for frame in range(120):
			if frame % 3 == 0:
				boat.rowing_time += 1.0 / 60.0
			boat._process(1.0 / 180.0)
			if frame > 60 and not churn.emitting:
				interrupted_strokes += 1
		check(interrupted_strokes == 0, "High render rates do not interrupt or retrigger oar splashes between physics ticks")
		boat.rowing = false
		boat._update_water_fx(0.5)
	actor.rowing_boat = boat
	actor.position = Vector3(250, 0.2, -307)
	actor.is_in_water = true
	actor._water_query_timer = 1.0
	actor._update_water_state(0.3)
	check(not actor.is_in_water, "Rowing player is not flagged as wading")
	actor.rowing_boat = null
	world.net = null
	if OS.get_cmdline_user_args().has("--preview"):
		boat.position = boat.clamp_to_lake(boat.lake_center)
		boat.rotation.y = 0
		actor.position = boat.position + Vector3(0, 0.2, -1)
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
		var water := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(120, 120)
		water.mesh = plane
		water.material_override = load("res://shaders/river_water.tres").duplicate()
		water.material_override.set_shader_parameter("use_vertex_waves", false)
		water.material_override.set_shader_parameter("use_foam", false)
		water.material_override.set_shader_parameter("normal_scale", 0.10)
		water.material_override.set_shader_parameter("uv1_scale", Vector2(8, 8))
		water.position = boat.position + Vector3(0, BoatScript.WATER_Y - 0.035, 0)
		world.add_child(water)
		actor.camera.fov = 45
		boat._fx_prev_pos = boat.global_position
		boat.speed = 2.8
		boat.rowing_time = 0.0
		var elapsed := 0.0
		while elapsed < 6.65:
			await process_frame
			var dt := minf(world.get_process_delta_time(), 0.05)
			elapsed += dt
			boat.accept_input(1, Vector2(0, -1))
			boat.simulate(dt)
			boat._process(dt)
			actor.camera.global_position = boat.position + Vector3(7, 6, -8)
			actor.camera.look_at(boat.position + Vector3(0, 0.2, 0))
		print("PREVIEW_SPEED=", boat._fx_speed, " WAKE_SAMPLES=", boat._surface_wake.samples.size())
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/lastday_rowboat_preview.png")
	world._scene_quitting = true
	world.queue_free()
	await process_frame
	await process_frame
	print("ROWBOAT_ERRORS=", errors)
	quit(1 if errors else 0)
