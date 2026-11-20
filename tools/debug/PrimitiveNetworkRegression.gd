extends SceneTree

class World extends "res://scripts/Main.gd":
	var drops: Array = []
	var shots: Array = []
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	func _spawn_ground_pickup(n: String, t: String, p: Vector3, w: float, q: int, u: float, id: String = "", a: String = "", wet: float = 0.0, c: Color = Color(0,0,0,0)) -> void:
		drops.append({"name": n, "qty": q, "id": id})
	func _net_primitive_shot(id: int, origin: Vector3, dir: Vector3, item: String, speed: float, wind: Vector3 = Vector3.ZERO):
		shots.append([id, wind])

class Animal extends "res://scripts/WildlifeController.gd":
	var damage := 0.0
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
	func _remove_corpse(): pass
	func take_damage(amount: float, _knife: bool = false, _attacker: Node = null): damage += amount

class Shooter extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass

class PresentationWorld extends "res://scripts/Main.gd":
	func _ready(): set_process(false); set_physics_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass

var failures := 0
var recovered := 0
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func _initialize(): call_deferred("run")
func run():
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var network = root.get_node("NetworkManager")
	world.net = network
	network.is_host = true
	network.is_dedicated_server = true
	var animal := Animal.new()
	animal.name = "Wildlife_deer_test"
	animal.animal_type = "deer"
	animal._is_dead = true
	world.add_child(animal)
	world._net_gut_animal(str(animal.name), 1)
	var first_count := world.drops.size()
	check(first_count == 11, "Deer yields 8 meat, hide, bone and sinew stacks")
	world._net_gut_animal(str(animal.name), 1)
	check(world.drops.size() == first_count, "Duplicate corpse request cannot award resources twice")
	var ids: Array = world.drops.map(func(d): return d.id)
	animal._gutted = false # A new spawn may reuse the same animal name.
	world._net_gut_animal(str(animal.name), 1)
	for drop in world.drops.slice(first_count):
		check(not ids.has(drop.id), "Respawn must not reuse depleted pickup IDs")
	animal._is_dead = false
	world._net_damage_animal(str(animal.name), 25, false, 1, true)
	check(animal.damage == 25 and float(animal.get_meta("bola_slow_until", 0)) > Time.get_unix_time_from_system(), "Bola slows authoritative animal and deals one hit")
	var wind := Vector3(2,0,1)
	network.primitive_shot(1, Vector3.ZERO, Vector3.FORWARD, "Lanza", 28, wind)
	check(world.shots.size() == 1 and world.shots[0][1] == wind, "Host launch is accepted with exact wind")
	network.primitive_shot(42, Vector3.ZERO, Vector3.FORWARD, "Lanza", 28, wind)
	network.primitive_shot(1, Vector3.ZERO, Vector3.FORWARD, "Lanza", 1000, wind)
	check(world.shots.size() == 1, "Forged shooter and invalid speed rejected")
	var host_shooter := Shooter.new()
	world.add_child(host_shooter)
	network.is_connected = true
	host_shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, 65, [], 30, "Lanza", "weapon", 1, 0, false)
	check(world.shots.size() == 2, "Actual host launch dispatches locally instead of RPC to itself")
	network.is_connected = false
	world.get_child(world.get_child_count()-1).queue_free()
	host_shooter.queue_free()
	# Empty world isolates actual projectile expiry without map or saves.
	var arena := Node3D.new()
	root.add_child(arena)
	current_scene = arena
	var shooter := Shooter.new()
	arena.add_child(shooter)
	shooter.item_dropped.connect(func(_n,_t,_w,_q,_u,_p,_c,_b,_s): recovered += 1)
	shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, 0.1, [], 30, "Lanza", "weapon", 1.0, 0.0, false)
	var projectile = arena.get_child(arena.get_child_count()-1)
	projectile._physics_process(0.1)
	check(recovered == 1, "Range expiry recovers thrown spear once")
	projectile._physics_process(0.1)
	check(recovered == 1, "Queued projectile cannot recover twice")
	shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, 0.1, [], 0, "Lanza", "weapon", 0, 0, false, true, wind)
	projectile = arena.get_child(arena.get_child_count()-1)
	check(projectile.wind_velocity == wind, "Remote projectile uses transmitted wind")
	check(projectile.impact.get_connections().is_empty(), "Remote visual cannot apply duplicate damage")
	projectile._physics_process(0.1)
	check(recovered == 1, "Remote visual cannot duplicate recovered loot")
	var recovered_durabilities: Array = []
	shooter.item_dropped.connect(func(_n,_t,_w,_q,_u,_p,_c,_b,_s):
		recovered_durabilities.append(shooter.get_meta("last_dropped_durability", -1)))
	var in_flight: Array = []
	for durability in [16.0, 72.0]:
		shooter.set_meta("last_dropped_durability", durability)
		shooter.set_meta("last_dropped_max_durability", 100.0)
		shooter._launch_primitive_projectile(Vector3(0,100,0), Vector3.FORWARD, 28, .1, [], 0, "Lanza", "tool_spear", 1, 0, false)
		in_flight.append(arena.get_child(arena.get_child_count()-1))
		check(not shooter.has_meta("last_dropped_durability"), "Flight captures durability instead of leaking it to other drops")
	in_flight[1]._physics_process(.1)
	in_flight[0]._physics_process(.1)
	check(recovered_durabilities == [72.0,16.0], "Concurrent spears retain individual durability regardless of landing order")
	# Reliable launch may precede the avatar snapshot. Exercise the real
	# Main handler and visual builder, not the logging stub above.
	var presentation := PresentationWorld.new()
	root.add_child(presentation); current_scene = presentation
	var viewer := Shooter.new(); presentation.add_child(viewer); presentation.player = viewer
	presentation._net_primitive_shot(901, Vector3(0, 10, -5), Vector3.FORWARD, "Lanza", GameConst.SPEAR_THROW_SPEED)
	var visible_flights := presentation.get_children().filter(func(n): return n.get_script() == preload("res://scripts/RifleProjectile.gd"))
	check(visible_flights.size() == 1, "missing bot avatar does not discard a reliable spear visual")
	if not visible_flights.is_empty():
		var visible = visible_flights[0]
		check(visible.get_node_or_null("ProjectileVisual") != null and visible.impact.get_connections().is_empty(),
			"remote spear has geometry and cannot inflict damage")
		var start: Vector3 = visible.position
		visible._physics_process(0.08)
		check(not visible.is_queued_for_deletion() and visible.position.distance_to(start) > 1.0,
			"spear remains visible in flight after release")
		if DisplayServer.get_name() != "headless":
			visible.set_physics_process(false)
			root.size = Vector2i(800, 500)
			var camera := Camera3D.new(); presentation.add_child(camera)
			camera.position = visible.position + Vector3(3, 0.7, .5)
			camera.look_at(visible.position); camera.make_current()
			var light := DirectionalLight3D.new(); presentation.add_child(light)
			light.rotation_degrees = Vector3(-35, -30, 0)
			var environment := WorldEnvironment.new(); presentation.add_child(environment)
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color(.1, .16, .22)
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color.WHITE
			environment.environment.ambient_light_energy = .7
			await process_frame
			await RenderingServer.frame_post_draw
			var image := root.get_texture().get_image()
			var background := image.get_pixel(5, 5)
			var shaft_pixels := 0
			for y in range(50, 450):
				for x in range(50, 750):
					var pixel := image.get_pixel(x, y)
					if absf(pixel.r-background.r) + absf(pixel.g-background.g) + absf(pixel.b-background.b) > .08:
						shaft_pixels += 1
			check(shaft_pixels > 100, "remote spear produces visible pixels in the real renderer")
			if OS.get_cmdline_user_args().has("--capture-spear"):
				image.save_png(ProjectSettings.globalize_path("res://build/tmp/spear_flight.png"))
	# A host's invisible authoritative twin cannot swallow its own visual.
	var bot_avatar := Shooter.new(); bot_avatar.set_meta("peer_id", 901); presentation.add_child(bot_avatar)
	bot_avatar.position = Vector3(5,10,0)
	presentation.remote_players[901] = bot_avatar
	var twin := Node3D.new(); presentation.add_child(twin); twin.position = bot_avatar.position
	twin.set_meta("peer_id", 901); twin.add_to_group("net_player_proxy")
	presentation._net_primitive_shot(901, twin.position + Vector3.UP*1.4, Vector3.FORWARD, "Lanza", GameConst.SPEAR_THROW_SPEED)
	var last_visual = presentation.get_child(presentation.get_child_count()-1)
	last_visual._physics_process(0.08)
	check(not last_visual.is_queued_for_deletion() and last_visual.position.z < -1.0,
		"listen-host spear escapes its own proxy instead of disappearing on launch")
	var landed := {"id": "landed_spear", "name": "Lanza", "type": "tool_spear", "weight": 1.0,
		"qty": 1, "use": 0, "pos": [-10, 0, -10], "durability": 78.0, "max_durability": 100.0}
	presentation._net_world_action_completed("", [landed], "", Vector3.ZERO)
	var action = presentation.world_actions_by_id.get("landed_spear")
	check(action != null and float(action.get_meta("item_durability", -1)) == 78,
		"replicated landed spear retains wear on the receiving client's pickup action")
	current_scene = null
	presentation.queue_free()
	arena.queue_free()
	world.queue_free()
	await process_frame
	print("PrimitiveNetworkRegression failures=", failures)
	quit(1 if failures else 0)
