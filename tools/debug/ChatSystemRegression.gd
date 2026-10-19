extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const SurvivalStatsScript = preload("res://scripts/SurvivalStats.gd")

class ProbeVoiceNet extends "res://scripts/NetworkManager.gd":
	var received_voice: Array = []
	func _ready() -> void:
		super._ready()
		voice_packet_received.connect(func(sid: int, sname: String, pcm: PackedByteArray, tid: int, tname: String, gid: String):
			received_voice.append({"sender_id": sid, "sender_name": sname, "size": pcm.size(), "target_id": tid, "target_name": tname, "group_id": gid})
		)
	func _on_connected_to_server() -> void:
		is_connected = true
		var my_id := multiplayer.get_unique_id()
		players[my_id] = {"name": pending_player_name, "char_name": pending_player_name, "pos": SPAWN_POS, "rot": 0.0, "ready": true}
		_register_player.rpc_id(1, my_id, pending_player_name, client_id, _join_password)
		connection_succeeded.emit()

func _make_voice_client(scope_name: String, cid: String, pname: String) -> ProbeVoiceNet:
	var scope := Node.new()
	scope.name = scope_name
	root.add_child(scope)
	var api := MultiplayerAPI.create_default_interface()
	api.root_path = scope.get_path()
	set_multiplayer(api, scope.get_path())
	var c := ProbeVoiceNet.new()
	c.name = "NetworkManager"
	scope.add_child(c)
	c.client_id = cid
	c.pending_player_name = pname
	return c

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

	# A disappearing target must not carry the microphone into the UI fallback.
	hud.set_chat_target(7)
	hud.set_voice_mic_active(true)
	hud._mic_out_buffer = sample_pkt.duplicate()
	net.players[7]["offline"] = true
	hud._process_voice_chat(0.05)
	check(not hud.voice_mic_active and hud._mic_out_buffer.is_empty(), "Disconnect mutes capture and discards pending audio")
	check(hud.chat_target_peer_id == 9, "Text chat can still fall back without transferring the microphone")
	net.players[7]["offline"] = false
	hud.set_chat_target(7)
	hud.set_voice_mic_active(true)
	net.players[7]["offline"] = true
	hud._refresh_chat_target_ui()
	check(not hud.voice_mic_active, "UI refresh before audio processing also mutes a disconnected target")
	net.players[7]["offline"] = false

	# Losing group membership and explicit conversation changes clear capture.
	hud.set_chat_group("grp_ext_1")
	hud.set_voice_mic_active(true)
	net.chat_groups["grp_ext_1"]["members"] = [7]
	hud._process_voice_chat(0.05)
	check(not hud.voice_mic_active, "Losing group membership mutes instead of falling back to a DM")
	hud.set_chat_target(7)
	hud.set_voice_mic_active(true)
	hud._mic_out_buffer = sample_pkt.duplicate()
	hud.set_chat_target(9)
	check(not hud.voice_mic_active and hud._mic_out_buffer.is_empty(), "Changing conversation discards audio captured for the previous recipient")

	# An incoming text can retarget a closed chat without refreshing its UI.
	hud.set_chat_target(7)
	hud.set_voice_mic_active(true)
	hud.add_chat_message("Alex", "Hola", false, true, "Líder", 9, "")
	hud._dispatch_voice_packet(sample_pkt)
	check(not hud.voice_mic_active, "Dispatch rejects audio after an incoming text changes the conversation")

	# Exercise stop() without opening a real microphone or touching saves.
	hud.set_chat_target(7)
	hud.set_voice_mic_active(true)
	hud._mic_player = AudioStreamPlayer.new()
	hud._mic_player.stream = AudioStreamGenerator.new()
	hud.add_child(hud._mic_player)
	hud._mic_player.play()
	hud._mic_out_buffer = sample_pkt.duplicate()
	player.is_dead = true
	hud._process_voice_chat(0.05)
	check(not hud.voice_mic_active and not hud._mic_player.playing and hud._mic_out_buffer.is_empty(), "Death stops audio input and discards pending audio")
	hud.toggle_voice_mic()
	check(not hud.voice_mic_active, "Dead player cannot restart the microphone")
	player.is_dead = false
	world.game_over = true
	hud.toggle_voice_mic()
	check(not hud.voice_mic_active, "Game-over blocks capture even before the player dead flag updates")
	world.game_over = false
	hud.set_voice_mic_active(true)
	check(hud.voice_mic_active, "A living player can explicitly enable voice again")
	world.game_over = true
	world._on_player_died() # Reentrant death path returns before save/scene work.
	check(not hud.voice_mic_active, "Death handler immediately mutes even when game-over is already set")

	hud._mic_player.stream = null
	# Let the audio server retire the stopped test playback before shutdown.
	await create_timer(0.1).timeout

	# 9. Prueba end-to-end del pipeline de Audio (AudioEffectCapture -> 12kHz PCM -> AudioStreamGeneratorPlayback)
	if DisplayServer.get_name() != "headless":
		world.game_over = false
		player.is_dead = false
		hud._mic_player.queue_free()
		hud._mic_player = null
		hud._mic_capture = null
		hud.set_process(false)
		hud.set_chat_target(7)
		hud.set_voice_mic_active(true)
		var bus_idx := AudioServer.get_bus_index("VoiceMicCapture")
		check(bus_idx >= 0 and not AudioServer.is_bus_mute(bus_idx) and AudioServer.get_bus_volume_db(bus_idx) <= -79.0, "Real audio bus VoiceMicCapture is active for effect processing and silenced at output")
		check(hud._mic_capture != null and hud._mic_player != null, "Real AudioEffectCapture and microphone player initialized")
		var dispatched_packets: Array = []
		# Inyectamos un tono sinusoidal de 440 Hz en el bus VoiceMicCapture para probar la captura real y el submuestreo a 12 kHz
		var synth := AudioStreamPlayer.new()
		synth.bus = "VoiceMicCapture"
		var sgen := AudioStreamGenerator.new()
		sgen.mix_rate = AudioServer.get_mix_rate()
		sgen.buffer_length = 0.35
		synth.stream = sgen
		hud.add_child(synth)
		synth.play()
		var spb := synth.get_stream_playback() as AudioStreamGeneratorPlayback
		var srate := AudioServer.get_mix_rate()
		for i in range(int(srate * 0.25)):
			var s := sin(TAU * 440.0 * float(i) / srate) * 0.65
			spb.push_frame(Vector2(s, s))
		for _step in range(10):
			await create_timer(0.03).timeout
			if hud._mic_capture != null and hud._mic_capture.get_frames_available() > 0:
				var frames: PackedVector2Array = hud._mic_capture.get_buffer(hud._mic_capture.get_frames_available())
				var step := maxf(AudioServer.get_mix_rate(), hud.VOICE_SAMPLE_RATE) / hud.VOICE_SAMPLE_RATE
				var f_idx := 0.0
				var pkt := PackedByteArray()
				while int(f_idx) < frames.size() and pkt.size() < hud.VOICE_PACKET_SAMPLES:
					var fr: Vector2 = frames[int(f_idx)]
					var mono := clampf((fr.x + fr.y) * 0.5, -1.0, 1.0)
					pkt.append(clampi(int(round(mono * 127.0 + 128.0)), 0, 255))
					f_idx += step
				if pkt.size() >= 100:
					dispatched_packets.append(pkt)
		synth.stop()
		synth.queue_free()
		check(dispatched_packets.size() >= 1, "AudioEffectCapture captures real waveform from VoiceMicCapture bus")
		if not dispatched_packets.is_empty():
			var pkt0: PackedByteArray = dispatched_packets[0]
			var min_v := 255
			var max_v := 0
			for b in pkt0:
				min_v = mini(min_v, int(b))
				max_v = maxi(max_v, int(b))
			check(min_v < 90 and max_v > 165, "Captured 12kHz PCM packet carries real dynamic range (min=%d, max=%d)" % [min_v, max_v])
			# Ahora inyectamos ese paquete capturado en el reproductor de voz receptor
			hud.on_voice_packet_received(7, "Remy", pkt0, 1, "Líder", "")
			var rx_player: AudioStreamPlayer = hud._voice_players.get(7)
			check(rx_player != null and rx_player.playing, "Real AudioStreamGenerator player starts playing incoming voice packet")
		hud.set_voice_mic_active(false)
		await create_timer(0.1).timeout

	world.queue_free()
	await process_frame

	# 10. Prueba de red ENet real (Servidor + 3 Clientes: voz 1-a-1 y voz en grupo multi-emisor)
	net.close_connection()
	var host_ok: bool = net.host_game()
	check(host_ok, "Real ENet test server started via host_game()")
	if host_ok:
		net.is_dedicated_server = true
		var cli_a := _make_voice_client("VoiceCliA", "cid_va", "Remy")
		var cli_b := _make_voice_client("VoiceCliB", "cid_vb", "Alex")
		var cli_c := _make_voice_client("VoiceCliC", "cid_vc", "Sara")
		cli_a.join_game("127.0.0.1")
		cli_b.join_game("127.0.0.1")
		cli_c.join_game("127.0.0.1")
		await create_timer(0.6).timeout
		var id_a := cli_a.multiplayer.get_unique_id() if cli_a.is_connected else 0
		var id_b := cli_b.multiplayer.get_unique_id() if cli_b.is_connected else 0
		var id_c := cli_c.multiplayer.get_unique_id() if cli_c.is_connected else 0
		check(cli_a.is_connected and cli_b.is_connected and cli_c.is_connected, "3 real ENet clients connected and registered (%d, %d, %d)" % [id_a, id_b, id_c])

		# 10a. Voz 1 a 1 sobre ENet: Remy (A) habla con Alex (B) -> solo B recibe el audio, C no recibe nada
		var voice_dm := PackedByteArray()
		voice_dm.resize(600)
		voice_dm.fill(180)
		cli_a.send_voice_packet.rpc_id(1, voice_dm, id_b, "")
		await create_timer(0.15).timeout
		check(cli_b.received_voice.size() == 1 and int(cli_b.received_voice[0]["sender_id"]) == id_a and int(cli_b.received_voice[0]["size"]) == 600, "ENet 1-on-1 voice packet delivered from Remy to Alex")
		check(cli_c.received_voice.is_empty() and cli_a.received_voice.is_empty(), "ENet 1-on-1 voice packet is completely isolated from third-party client Sara")

		# 10b. Voz en grupo sobre ENet: Remy (A) crea el grupo 'Radio Alfa', aparece listado en B y C; Alex (B) se une, Sara (C) no se une
		cli_a.create_chat_group.rpc_id(1, "Radio Alfa")
		await create_timer(0.25).timeout
		check(cli_b.chat_groups.size() == 1 and cli_c.chat_groups.size() == 1, "Created group 'Radio Alfa' is broadcast and listed to all online clients")
		var radio_gid := str(cli_b.chat_groups.keys()[0])
		cli_b.join_chat_group.rpc_id(1, radio_gid)
		await create_timer(0.25).timeout
		var g_members: Array = net.chat_groups[radio_gid].get("members", [])
		check(g_members.has(id_a) and g_members.has(id_b) and not g_members.has(id_c), "Alex joined 'Radio Alfa' while Sara remains outside the group")

		# Ambos miembros del grupo (Remy y Alex) hablan en el grupo -> ambos se escuchan y Sara (C) no escucha nada
		cli_a.received_voice.clear()
		cli_b.received_voice.clear()
		cli_c.received_voice.clear()
		cli_a.send_voice_packet.rpc_id(1, voice_dm, 0, radio_gid)
		cli_b.send_voice_packet.rpc_id(1, voice_dm, 0, radio_gid)
		# Sara (no miembro) intenta enviar voz al grupo -> el servidor lo bloquea
		cli_c.send_voice_packet.rpc_id(1, voice_dm, 0, radio_gid)
		await create_timer(0.2).timeout
		check(cli_b.received_voice.size() == 1 and int(cli_b.received_voice[0]["sender_id"]) == id_a and str(cli_b.received_voice[0]["group_id"]) == radio_gid, "Group member Alex receives Remy's group voice packet over ENet")
		check(cli_a.received_voice.size() == 1 and int(cli_a.received_voice[0]["sender_id"]) == id_b and str(cli_a.received_voice[0]["group_id"]) == radio_gid, "Group member Remy simultaneously receives Alex's group voice packet over ENet")
		check(cli_c.received_voice.is_empty(), "Non-member Sara receives 0 voice packets from the group")

		for cli in [cli_a, cli_b, cli_c]:
			cli.close_connection()
			cli.get_parent().queue_free()
		net.close_connection()
		await process_frame

	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
