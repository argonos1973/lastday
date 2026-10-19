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

	# 2. Al conectarse otros jugadores (>=2 online), el chat se habilita y selecciona al primer jugador
	net.players[7] = {"name": "Jugador_7", "char_name": "Remy"}
	net.players[9] = {"name": "Jugador_9", "char_name": "Alex"}
	check(hud.can_use_chat(), "Chat is enabled when >=2 players are online")
	hud.open_chat()
	check(hud.chat_open and hud.chat_panel.visible and hud.chat_input.visible, "open_chat opens panel and LineEdit with 2+ players")
	check(hud.chat_target_peer_id == 7 and hud.chat_target_group_id.is_empty(), "Chat defaults to first connected player (no public 'Todos' channel)")

	# 3. No existe chat público: enviar sin destinatario ni grupo es rechazado
	net.send_chat_message("Mensaje público sin destinatario", 0, "")
	check(hud._chat_conversations.is_empty(), "Public broadcast (target=0, group='') is rejected")

	# 4. Seleccionar jugador con el ratón (set_chat_target / open_chat(pid)) mantiene conversaciones 1-a-1 separadas
	hud.set_chat_target(7)
	net.send_chat_message("Hola Remy", 7, "")
	check(hud._chat_conversations.has("dm_7") and (hud._chat_conversations["dm_7"] as Array).size() == 1, "Direct message to peer 7 stored in dm_7 conversation")
	hud.set_chat_target(9)
	check(hud._chat_history.is_empty(), "Switching to peer 9 shows peer 9's separate conversation")
	net.send_chat_message("Hola Alex", 9, "")
	check(hud._chat_conversations.has("dm_9") and (hud._chat_conversations["dm_9"] as Array).size() == 1, "Direct message to peer 9 stored in dm_9 conversation")

	# 5. Crear un grupo de chat con jugadores seleccionados y escribir al grupo
	hud.open_chat_group_builder()
	check(hud.chat_group_builder_open and hud.chat_group_builder_box.visible, "Group builder UI opens with player checkboxes")
	hud.chat_selected_group_members = {7: true, 9: true}
	hud.chat_group_name_input.text = "Patrulla Norte"
	hud._confirm_create_chat_group()
	var groups: Array = hud._my_chat_groups()
	check(groups.size() == 1, "Group created and registered in NetworkManager.chat_groups")
	var gid := str(groups[0].get("id", "")) if not groups.is_empty() else ""
	check(not gid.is_empty() and hud.chat_target_group_id == gid, "Newly created group becomes the active chat target")
	net.send_chat_message("Nos vemos en la torre", 0, gid)
	check(hud._chat_conversations.has("grp_" + gid) and (hud._chat_conversations["grp_" + gid] as Array).size() == 1, "Group message stored in group conversation")
	check(str((hud._chat_conversations["grp_" + gid] as Array)[0].get("text", "")) == "Nos vemos en la torre", "Group message content matches")

	# 6. Salir del chat con el botón Salir [Esc]
	hud.chat_close_btn.pressed.emit()
	check(not hud.chat_open and not hud.chat_input.visible, "Close button exits chat")

	# 7. Si los demás jugadores se desconectan (queda 1 online), el chat se cierra y oculta solo
	hud.open_chat()
	net.players[7]["offline"] = true
	net.players[9]["offline"] = true
	hud._process(0.1)
	check(not hud.chat_open and not hud.chat_panel.visible, "Chat auto-closes and hides when online player count drops below 2")

	world.queue_free()
	await process_frame
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
