extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const SurvivalStatsScript = preload("res://scripts/SurvivalStats.gd")

class TestMain extends MainScript:
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass

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

	# 1. Con 0 o 1 jugador conectado, el chat NO se abre ni aparece
	net.is_host = true
	net.is_connected = true
	net.is_dedicated_server = false
	net.players = {1: {"name": "Host", "char_name": "Líder"}}
	check(not hud.can_use_chat(), "Chat is disabled when only 1 player is online")
	hud.open_chat()
	check(not hud.chat_open and not hud.chat_panel.visible, "open_chat is ignored when <2 players are online")

	# 2. Al conectarse un 2º jugador (>=2 online), el chat se habilita
	net.players[7] = {"name": "Jugador_7", "char_name": "Remy"}
	check(hud.can_use_chat(), "Chat is enabled when >=2 players are online")
	hud.open_chat()
	check(hud.chat_open and hud.chat_panel.visible and hud.chat_input.visible, "open_chat opens panel and LineEdit with 2+ players")

	# 3. Alternar destinatario privado con Tab (cycle_chat_target) y cerrar con close_chat / botón Salir
	check(hud.chat_target_peer_id == 0, "Default chat target is 0 (Todos)")
	hud.cycle_chat_target()
	check(hud.chat_target_peer_id == 7, "Tab cycles chat target to connected peer 7 (Remy)")
	hud.cycle_chat_target()
	check(hud.chat_target_peer_id == 0, "Tab cycles back to 0 (Todos)")
	hud.chat_close_btn.pressed.emit()
	check(not hud.chat_open and not hud.chat_input.visible, "Close button exits chat")

	# 4. Historial de mensajes y límite de CHAT_MAX_MESSAGES
	for i in range(10):
		hud.add_chat_message("Superviviente", "Mensaje %d" % i, i % 2 == 0)
	check(hud._chat_history.size() == hud.CHAT_MAX_MESSAGES, "Chat history caps at CHAT_MAX_MESSAGES (8)")
	check(str(hud._chat_history[0].get("text", "")) == "Mensaje 2", "Oldest messages are evicted FIFO")
	check(hud.chat_panel.visible and hud._chat_fade_timer > 0.0, "Receiving a message makes chat panel visible")

	# 5. Mensaje público vs. privado (el público crea burbuja 3D; el privado NO crea burbuja 3D pública)
	var remote := Node3D.new()
	remote.name = "RemotePlayer_7"
	world.add_child(remote)
	world.remote_players[7] = remote

	net.receive_chat_message(7, "Remy", "Hola a todos", 0, "")
	var bubble := remote.get_node_or_null("ChatBubble3D") as Label3D
	check(bubble != null and bubble.text == "Remy: Hola a todos", "Public message spawns 3D ChatBubble above remote player")
	if bubble != null:
		bubble.free()

	net.send_chat_message("Mensaje secreto", 7)
	var priv_entry: Dictionary = hud._chat_history.back()
	check(bool(priv_entry.get("private", false)) and str(priv_entry.get("target", "")) == "Remy", "Private message records private flag and target name")
	check(remote.get_node_or_null("ChatBubble3D") == null, "Private message does not spawn a public 3D speech bubble")

	# Comando "/w Remy hola" también resuelve destinatario privado
	net.send_chat_message("/w remy Coordenadas 120 -80", 0)
	var whisper_entry: Dictionary = hud._chat_history.back()
	check(bool(whisper_entry.get("private", false)) and str(whisper_entry.get("text", "")) == "Coordenadas 120 -80", "/w command resolves private target and strips prefix")

	# 6. Si el 2º jugador pasa a offline (queda 1 jugador online), el chat se cierra y oculta solo
	hud.open_chat()
	net.players[7]["offline"] = true
	hud._process(0.1)
	check(not hud.chat_open and not hud.chat_panel.visible, "Chat auto-closes and hides when online player count drops below 2")

	world.queue_free()
	await process_frame
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
