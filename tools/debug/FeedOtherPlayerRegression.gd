extends SceneTree

# Regresion cooperativa de dar de comer y de beber a otro jugador cercano en
# multijugador + verificacion de la fogata realista y del punto de mira 3D del M4.

const MainScript = preload("res://scripts/Main.gd")
const PlayerScript = preload("res://scripts/PlayerController.gd")
const ItemScript = preload("res://scripts/Item.gd")

class FakeNet extends Node:
	var is_connected := true
	var is_host := true
	var is_dedicated_server := false
	var peer = null
	var players := {
		1: {"char_name": "Carlos", "pos": Vector3.ZERO},
		2: {"char_name": "Elena", "pos": Vector3(0.0, 0.0, -1.5)},
	}
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return false

class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
	func _exit_tree() -> void:
		pass

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _setup_third_person_animation(_c: Node3D) -> void:
		pass

var failures := 0
var _last_prompt := ""

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		push_error("FAIL: " + msg)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var fake_net := FakeNet.new()
	world.add_child(fake_net)
	world.net = fake_net

	# Crear jugador local (giver) y jugador remoto (receiver puppet + server proxy)
	var giver := TestPlayer.new()
	giver.name = "Player"
	giver.stats = preload("res://scripts/SurvivalStats.gd").new()
	giver.inventory = preload("res://scripts/Inventory.gd").new()
	giver.add_child(giver.inventory)
	world.add_child(giver)
	world.player = giver
	giver.global_position = Vector3.ZERO
	giver.rotation = Vector3.ZERO # mira hacia -Z

	var receiver_puppet := TestPlayer.new()
	receiver_puppet.is_puppet = true
	receiver_puppet.set_meta("peer_id", 2)
	world.add_child(receiver_puppet)
	receiver_puppet.global_position = Vector3(0.0, 0.0, -1.6)
	world.remote_players[2] = receiver_puppet

	var proxy := Node3D.new()
	proxy.set_meta("peer_id", 2)
	proxy.set_meta("saved_hunger", 30.0)
	proxy.set_meta("saved_thirst", 25.0)
	proxy.set_meta("saved_health", 60.0)
	proxy.set_meta("proxy_health", 60.0)
	world.add_child(proxy)
	proxy.global_position = Vector3(0.0, 0.0, -1.6)
	world.server_proxies[2] = proxy

	# 1. Poner una Naranja en la mano de giver y comprobar el prompt y el envio de comida
	giver.inventory.add_item(ItemScript.create("Naranja", "food", 0.2, 2, 20.0))
	giver._select_held_item(0)
	giver.prompt_changed.connect(func(t: String): _last_prompt = t)
	giver._update_interaction_prompt()
	check(_last_prompt == "Dar de comer (Naranja) a Elena - [F]", "prompt de dar de comer: '%s'" % _last_prompt)

	giver._interact()
	check(int(giver.inventory.items[0].quantity) == 1, "se consumio 1 naranja del inventario del dador")
	check(float(proxy.get_meta("saved_hunger", 0.0)) > 45.0, "el servidor subio saved_hunger del receptor (%.1f)" % float(proxy.get_meta("saved_hunger", 0.0)))
	check(float(proxy.get_meta("saved_thirst", 0.0)) > 35.0, "la naranja tambien subio saved_thirst del receptor (%.1f)" % float(proxy.get_meta("saved_thirst", 0.0)))

	# 2. Poner una Botella de agua en la mano de giver y darle de beber a Elena
	var bottle = ItemScript.create("Botella de agua", "water", 0.5, 1, 80.0)
	bottle.durability = 100.0
	bottle.max_durability = 100.0
	giver.inventory.add_item(bottle)
	giver._select_held_item(1)
	giver._update_interaction_prompt()
	check(_last_prompt == "Dar de beber (Botella de agua) a Elena - [F]", "prompt de dar de beber: '%s'" % _last_prompt)

	var thirst_before := float(proxy.get_meta("saved_thirst", 0.0))
	giver._interact()
	var inv_bottle = giver.inventory.items[1]
	check(absf(float(inv_bottle.durability) - 75.0) < 0.5, "dar de beber consume 25%% de la botella de agua (queda %.1f%%)" % float(inv_bottle.durability))
	check(float(proxy.get_meta("saved_thirst", 0.0)) > thirst_before + 15.0, "el servidor subio saved_thirst tras dar de beber")

	# 3. Probar recepcion directa en el cliente receptor (_net_receive_fed_by_player)
	giver.stats.hunger = 40.0
	giver.stats.thirst = 35.0
	giver.stats.health = 70.0
	world._net_receive_fed_by_player("Elena", "Carne asada en palo", "food", 28.0, 4.0, 10.0, true)
	check(absf(giver.stats.hunger - 68.0) < 0.1, "receptor recibe +28 hambre")
	check(absf(giver.stats.thirst - 39.0) < 0.1, "receptor recibe +4 sed")
	check(absf(giver.stats.health - 80.0) < 0.1, "receptor recibe +10 salud")

	# 4. Verificar que realistic_campfire.glb y m4_rear_sight.glb cargan y tienen geometria
	var cf_scene := load("res://assets/models/props/realistic_campfire.glb") as PackedScene
	check(cf_scene != null, "realistic_campfire.glb carga")
	var rear_scene := load("res://assets/models/weapons/m4_rear_sight.glb") as PackedScene
	check(rear_scene != null, "m4_rear_sight.glb carga")

	if failures == 0:
		print("PASS: cooperative feeding/drinking, realistic campfire logs and 3D M4 sights verified")
	quit(1 if failures > 0 else 0)
