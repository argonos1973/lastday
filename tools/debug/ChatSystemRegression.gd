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

	# 2. En [P] Jugadores, hacer clic directamente en el nombre del jugador abre el chat con él (sin botón 'Chatear' separado)
	net.players[7] = {"name": "Jugador_7", "char_name": "Remy"}
	net.players[9] = {"name": "Jugador_9", "char_name": "Alex"}
	hud.toggle_players_list()
	var remy_btn: Button = null
	var has_separate_chatear_btn := false
	for child in hud.players_list_box.get_children():
		if child is Button and (child as Button).text.find("Remy") >= 0:
			remy_btn = child as Button
		if child is Button and (child as Button).text == "Chatear":
			has_separate_chatear_btn = true
	check(remy_btn != null and not has_separate_chatear_btn, "Player name itself is the clickable button (no separate 'Chatear' button)")
	if remy_btn != null:
		remy_btn.pressed.emit()
	check(hud.chat_open and hud.chat_target_peer_id == 7, "Clicking player name directly opens 1-on-1 chat with that player")

	# 3. No existe chat público: enviar sin destinatario ni grupo es rechazado
	net.send_chat_message("Mensaje público sin destinatario", 0, "")
	check(hud._chat_conversations.is_empty(), "Public broadcast (target=0, group='') is rejected")

	# 4. Conversaciones 1-a-1 separadas al hacer clic en el nombre de cada jugador
	net.send_chat_message("Hola Remy", 7, "")
	check(hud._chat_conversations.has("dm_7") and (hud._chat_conversations["dm_7"] as Array).size() == 1, "Direct message to peer 7 stored in dm_7 conversation")
	hud.set_chat_target(9)
	check(hud._chat_history.is_empty(), "Switching to peer 9 shows peer 9's separate conversation")
	net.send_chat_message("Hola Alex", 9, "")
	check(hud._chat_conversations.has("dm_9") and (hud._chat_conversations["dm_9"] as Array).size() == 1, "Direct message to peer 9 stored in dm_9 conversation")

	# 5. Crear un grupo poniendo solo el nombre del grupo; queda listado para poderse unir después
	hud.open_chat_group_builder()
	check(hud.chat_group_builder_open and hud.chat_group_name_input != null, "Group builder opens with group name input")
	hud.chat_group_name_input.text = "Patrulla Norte"
	hud._confirm_create_chat_group()
	var all_groups: Array = hud._all_chat_groups()
	check(all_groups.size() == 1 and str(all_groups[0].get("name", "")) == "Patrulla Norte", "Group created by name and listed in _all_chat_groups")
	var gid := str(all_groups[0].get("id", "")) if not all_groups.is_empty() else ""
	check(not gid.is_empty() and hud.chat_target_group_id == gid, "Newly created group is selected")

	# 6. Un grupo creado por otro jugador aparece listado y al hacer clic nos unimos a él
	net.sync_chat_group("grp_ext_1", "Supervivientes Sur", [7], ["Remy"])
	check(hud._all_chat_groups().size() == 2 and hud._my_chat_groups().size() == 1, "External group appears in listed groups before joining")
	hud.join_or_select_chat_group("grp_ext_1")
	check(hud._my_chat_groups().size() == 2 and hud.chat_target_group_id == "grp_ext_1", "Clicking listed group joins it and selects it for chat")
	net.send_chat_message("Ya me he unido al grupo", 0, "grp_ext_1")
	check(hud._chat_conversations.has("grp_grp_ext_1") and (hud._chat_conversations["grp_grp_ext_1"] as Array).size() == 1, "Joined player can send and receive messages in the group")

	# 7. Voz por micrófono: toggle_voice_mic, paquetes de voz 1-a-1 y en grupo
	hud.toggle_voice_mic()
	check(hud.voice_mic_active, "toggle_voice_mic activates microphone for active group/player")
	var sample_pkt := PackedByteArray([128, 160, 200, 90, 128])
	net.receive_voice_packet(7, "Remy", sample_pkt, 0, "Supervivientes Sur", "grp_ext_1")
	check(hud._voice_speaking_timers.has(7) and str(hud._voice_speaking_timers[7].get("group", "")) == "Supervivientes Sur", "Incoming group voice packet registers speaker and group in HUD")
	net.receive_voice_packet(9, "Alex", sample_pkt, 1, "Líder", "")
	check(hud._voice_speaking_timers.has(9) and hud._voice_speaking_timers.has(7), "Multiple speakers in group/chat can speak simultaneously without overwriting each other")
	hud._process_voice_chat(0.05)
	check(hud.voice_status_label.visible and hud.voice_status_label.text.find("Remy") >= 0 and hud.voice_status_label.text.find("Alex") >= 0, "HUD voice_status_label displays active microphone and all simultaneous speakers")
	hud.toggle_voice_mic()
	check(not hud.voice_mic_active, "toggle_voice_mic deactivates microphone")

	# 8. Salir del chat con el botón Salir [Esc]
	hud.chat_close_btn.pressed.emit()
	check(not hud.chat_open and not hud.chat_input.visible, "Close button exits chat")

	world.queue_free()
	await process_frame
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
