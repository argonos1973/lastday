extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const HUDScript = preload("res://scripts/HUD.gd")

class TestMain extends MainScript:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass

const SurvivalStatsScript = preload("res://scripts/SurvivalStats.gd")

class DummyInventory extends Node:
	signal changed
	var items: Array = []
	var max_weight := 25.0
	var max_slots := 8
	func get_total_weight() -> float: return 0.0
	func get_stored_count() -> int: return 0

class DummyDayCycle extends Node:
	func get_hour_text() -> String: return "12:00"
	func get_ambient_temperature() -> float: return 20.0

class DummyPlayer extends Node3D:
	signal prompt_changed(text)
	signal notice(text)
	var is_dead := false
	var is_sleeping := false
	var inventory: DummyInventory
	var stats: SurvivalStats
	func _init() -> void:
		inventory = DummyInventory.new()
		add_child(inventory)
		stats = SurvivalStatsScript.new()
		add_child(stats)
	func get_held_item():
		return null

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var net = root.get_node_or_null("/root/NetworkManager")
	check(net != null, "NetworkManager autoload exists")

	var world := TestMain.new()
	root.add_child(world)
	current_scene = world
	world.net = net

	var player := DummyPlayer.new()
	player.name = "Player"
	world.add_child(player)
	world.player = player

	var day_cycle := DummyDayCycle.new()
	world.add_child(day_cycle)
	world.day_cycle = day_cycle

	var hud := HUDScript.new()
	world.add_child(hud)
	world.hud = hud
	hud.setup(player, day_cycle, world)

	# 1. Abrir y cerrar el chat
	check(not hud.chat_open, "Chat starts closed")
	hud.open_chat()
	check(hud.chat_open and hud.chat_panel.visible and hud.chat_input.visible, "open_chat makes panel and LineEdit visible")
	hud.close_chat()
	check(not hud.chat_open and not hud.chat_input.visible, "close_chat hides LineEdit and clears chat_open")

	# 2. Historial de mensajes y límite de CHAT_MAX_MESSAGES
	for i in range(10):
		hud.add_chat_message("Superviviente", "Mensaje %d" % i, i % 2 == 0)
	check(hud._chat_history.size() == hud.CHAT_MAX_MESSAGES, "Chat history caps at CHAT_MAX_MESSAGES (8)")
	check(str(hud._chat_history[0].get("text", "")) == "Mensaje 2", "Oldest messages are evicted FIFO")
	check(hud.chat_panel.visible and hud._chat_fade_timer > 0.0, "Receiving a message makes chat panel visible")

	# 3. Recepción de mensaje desde servidor: actualiza HUD y crea burbuja 3D sobre el personaje
	var remote := Node3D.new()
	remote.name = "RemotePlayer_7"
	world.add_child(remote)
	world.remote_players[7] = remote

	net.receive_chat_message(7, "Remy", "Hola desde el campamento")
	check(str(hud._chat_history.back().get("sender", "")) == "Remy" and str(hud._chat_history.back().get("text", "")) == "Hola desde el campamento", "receive_chat_message appends to HUD chat")
	var bubble := remote.get_node_or_null("ChatBubble3D") as Label3D
	check(bubble != null and bubble.text == "Remy: Hola desde el campamento", "3D ChatBubble spawns above speaking remote player")

	# 4. Envío autoritativo en host (recorta saltos de línea y longitud >160, rechaza vacío)
	net.is_host = true
	net.is_connected = true
	net.is_dedicated_server = false
	net.players[1] = {"name": "Host", "char_name": "Líder"}
	var count_before := hud._chat_history.size()
	net.send_chat_message("   ")
	check(hud._chat_history.size() == count_before and str(hud._chat_history.back().get("text", "")) == "Hola desde el campamento", "Blank chat message is ignored")
	var long_msg := "A".repeat(200) + "\ninyeccion"
	net.send_chat_message(long_msg)
	var last_entry: Dictionary = hud._chat_history.back()
	check(str(last_entry.get("sender", "")) == "Líder", "Host send_chat_message uses authoritative char_name")
	check(str(last_entry.get("text", "")).length() == 160 and not str(last_entry.get("text", "")).contains("\n"), "Chat message is sanitized and clamped to 160 chars")

	world.queue_free()
	await process_frame
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
