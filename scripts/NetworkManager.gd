extends Node

signal player_connected(id: int)
signal player_disconnected(id: int)
signal connection_failed()
signal connection_succeeded()
signal all_players_ready()
signal auth_rejected(reason: String)
# El servidor pide el nombre del jugador cuando la conexión abre un personaje
# nuevo (no hay personaje vivo que reclamar o murió). El cliente responde con
# submit_player_name.
signal player_name_required()
# Server reclaimed a live character for this client — the menu picker locks
# to that character (payload: name, colors, current equipment).
signal server_character_locked(payload: Dictionary)
signal chat_message_received(sender_id: int, sender_name: String, text: String, target_id: int, target_name: String, group_id: String)
signal chat_group_synced(group_id: String, group_name: String, member_ids: Array, member_names: Array)
signal voice_packet_received(sender_id: int, sender_name: String, pcm_bytes: PackedByteArray, target_id: int, target_name: String, group_id: String)

const MAX_PLAYERS := 4
# Un peer conectado tiene esta ventana para completar _register_player; si no
# lo hace (scan, peer fantasma) se expulsa — si no aguantaba para siempre,
# ocupaba un slot de ENet y podía recibir estado del mundo.
const REGISTRATION_TIMEOUT := 30.0
const SPAWN_POS := Vector3(8.0, 0.4, 2.5)
# Servidor público: WebSocket local al que solo llega cloudflared.
const WS_PORT := 8081
const WS_BIND := "127.0.0.1"
const OFFICIAL_SERVER_URL := "wss://servidor.cronicasdesupervivencia.com"
# Cargada de res://server_secret.cfg (versionada por decisión de proyecto).
# El cliente la envía solo al entrar por "Servidor oficial" — el jugador no la ve.
static var OFFICIAL_SERVER_PASSWORD := _load_official_password()

static func _load_official_password() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("res://server_secret.cfg") == OK:
		return String(cfg.get_value("official", "password", ""))
	return ""

var peer: MultiplayerPeer = null
var is_host := false
var is_connected := false
var is_dedicated_server := false
var _broadcast_server: PacketPeerUDP = null
var _probe_listener: PacketPeerUDP = null
var _broadcast_timer := 0.0
var client_id := ""
var _public_server := false
var _server_password := ""
var _join_password := ""
# Nombre tecleado en el menu al unirse a un servidor — se consume al conectar
# y viaja en _register_player como nombre del personaje (hasta que muera).
var pending_player_name := ""

# player_id -> { "name": String, "pos": Vector3, "rot": float, "ready": bool }
var players: Dictionary = {}
var rowboat_state: Dictionary = {}
var chat_groups: Dictionary = {} # group_id -> { "id": String, "name": String, "members": Array, "member_names": Array }
var _chat_group_seq := 0

func _load_or_generate_client_id() -> void:
	# Dedicated server doesn't need a client_id — skip to avoid overwriting client's file
	if is_dedicated_server:
		return
	var path := "user://client_id.txt"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			client_id = f.get_as_text().strip_edges()
			if client_id.length() > 0:
				return
	client_id = str(randi()) + "_" + str(Time.get_ticks_msec())
	var f2 := FileAccess.open(path, FileAccess.WRITE)
	if f2 != null:
		f2.store_string(client_id)

func _arg_value(flag: String) -> String:
	for src in [OS.get_cmdline_args(), OS.get_cmdline_user_args()]:
		var i: int = src.find(flag)
		if i >= 0 and i + 1 < src.size():
			return String(src[i + 1])
	return ""

func _ready() -> void:
	# Auto-start dedicated server if --server argument is passed or this is a dedicated-server export
	var args := OS.get_cmdline_args()
	var user_args := OS.get_cmdline_user_args()
	var dedicated_build := OS.has_feature("dedicated_server")
	var public_arg := args.has("--server-public") or user_args.has("--server-public")
	if public_arg:
		_public_server = true
		_server_password = _arg_value("--password")
	if args.has("--server") or user_args.has("--server") or dedicated_build or public_arg:
		is_dedicated_server = true
	_load_or_generate_client_id()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	if is_dedicated_server:
		pass # print("[NETWORK] Starting dedicated server...")
		start_dedicated_server()

func start_dedicated_server(from_retry: bool = false) -> bool:
	if not from_retry:
		close_connection()
		is_dedicated_server = true
	var err := OK
	var bind_port := GameConst.GAME_PORT
	if _public_server:
		# Solo cloudflared (mismo host) alcanza este socket — sin UDP ni LAN.
		var ws := WebSocketMultiplayerPeer.new()
		# El burst de sync_world_state supera los 64 KB por defecto: al desbordar
		# el buffer de salida el socket queda roto y los replies (pickup_claim,
		# syncs) se pierden en silencio. 4 MB da margen de sobra por conexión.
		ws.outbound_buffer_size = 16 * 1024 * 1024
		ws.inbound_buffer_size = 4 * 1024 * 1024
		if "max_queued_packets" in ws:
			ws.max_queued_packets = 32768
		err = ws.create_server(WS_PORT, WS_BIND)
		bind_port = WS_PORT
		if err == OK:
			peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_server(GameConst.GAME_PORT, MAX_PLAYERS)
		if err == OK:
			peer = enet
	if err != OK:
		push_error("[SERVER] No se pudo bindear el puerto %d (err %d) — ¿queda otro servidor vivo?" % [bind_port, err])
		peer = null
		# A process without a bound socket still deletes the save and generates
		# a world nobody can join — retry briefly while an old instance finishes
		# releasing the port, then exit so a zombie is never left serving.
		if not from_retry:
			_dedicated_bind_retries = 10
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	is_dedicated_server = true
	_dedicated_bind_retries = 0
	if _public_server:
		print("[SERVER] Público WebSocket en %s:%d" % [WS_BIND, WS_PORT])
	else:
		_start_broadcast()
	return true

func host_game() -> bool:
	close_connection()
	var enet := ENetMultiplayerPeer.new()
	var err := enet.create_server(GameConst.GAME_PORT, MAX_PLAYERS)
	peer = enet
	if err != OK:
		push_error("No se pudo crear el servidor: %d" % err)
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_connected = true
	_start_broadcast()
	players[multiplayer.get_unique_id()] = {
		"name": "Host",
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true
	}
	return true

func _start_broadcast() -> void:
	# Sender socket on ephemeral port for broadcasting
	_broadcast_server = PacketPeerUDP.new()
	_broadcast_server.set_broadcast_enabled(true)
	_broadcast_server.bind(0)
	_broadcast_server.set_dest_address("255.255.255.255", GameConst.DISCOVERY_PORT)
	# Listener socket on GameConst.DISCOVERY_PORT for responding to probes
	_probe_listener = PacketPeerUDP.new()
	_probe_listener.bind(GameConst.DISCOVERY_PORT)

func _get_local_ip() -> String:
	var ips := IP.get_local_addresses()
	for ip in ips:
		var s := str(ip)
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			return s
	if ips.size() > 0:
		return str(ips[0])
	return "127.0.0.1"

func _get_all_local_ips() -> Array:
	var result: Array = []
	var ips := IP.get_local_addresses()
	for ip in ips:
		var s := str(ip)
		if s.begins_with("192.168.") or s.begins_with("10.") or s.begins_with("172."):
			result.append(s)
	if result.is_empty() and ips.size() > 0:
		result.append(str(ips[0]))
	return result

var _dedicated_bind_retries := 0
var _dedicated_bind_wait := 0.0
var water_world_time := 0.0
var _water_clock_timer := 0.0
var authoritative_weather: Dictionary = {}
var _weather_source_peer := 0

func publish_weather_observation(observation: Dictionary) -> void:
	if not is_connected or peer == null:
		return
	if is_host:
		_accept_weather_observation(observation, multiplayer.get_unique_id())
	else:
		_submit_weather_observation.rpc_id(1, observation)

@rpc("any_peer", "call_remote", "reliable")
func _submit_weather_observation(observation: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host or not _accepts_client_request(sender):
		return
	_accept_weather_observation(observation, sender)

func _accept_weather_observation(observation: Dictionary, sender: int) -> void:
	# A single publisher is chosen for this session so clients cannot race their
	# local geolocation/weather requests and show different conditions.
	if _weather_source_peer != 0 and sender != _weather_source_peer:
		_send_weather_state_to(sender)
		return
	var clean := _sanitize_weather_observation(observation)
	if clean.is_empty():
		return
	_weather_source_peer = sender
	authoritative_weather = clean
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_apply_network_weather"):
		scene.call("_apply_network_weather", clean)
	if is_host and peer != null:
		for pid in players.keys():
			if pid == multiplayer.get_unique_id() or players[pid].get("offline", false) or not peer_alive(pid):
				continue
			_sync_weather_state.rpc_id(pid, clean)

static func _sanitize_weather_observation(observation: Dictionary) -> Dictionary:
	var result := {}
	for key in ["temperature", "rain", "snow", "cloud_cover", "wind_speed", "wind_direction"]:
		var value = observation.get(key)
		if not (value is float or value is int) or not is_finite(float(value)):
			return {}
	result["weather_code"] = clampi(int(observation.get("weather_code", -1)), -1, 99)
	result["temperature"] = clampf(float(observation.temperature), -80.0, 65.0)
	result["rain"] = clampf(float(observation.rain), 0.0, 500.0)
	result["snow"] = clampf(float(observation.snow), 0.0, 500.0)
	result["cloud_cover"] = clampf(float(observation.cloud_cover), -1.0, 1.0)
	result["wind_speed"] = clampf(float(observation.wind_speed), 0.0, 300.0)
	result["wind_direction"] = fposmod(float(observation.wind_direction), 360.0)
	result["updated_at"] = Time.get_unix_time_from_system()
	return result

@rpc("authority", "call_remote", "reliable")
func _sync_weather_state(observation: Dictionary) -> void:
	if is_host:
		return
	var clean := _sanitize_weather_observation(observation)
	if clean.is_empty():
		return
	authoritative_weather = clean
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_apply_network_weather"):
		scene.call("_apply_network_weather", clean)

func _send_weather_state_to(pid: int) -> void:
	if not is_host or authoritative_weather.is_empty() or peer == null or not peer_alive(pid):
		return
	_sync_weather_state.rpc_id(pid, authoritative_weather)

# Consulta del flag "mundo listo": el cliente la repite cada ~10 s mientras
# espera el estado del mundo — cada respuesta prueba que el servidor vive.
@rpc("any_peer", "reliable")
func request_world_status() -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host or sender <= 1:
		return
	world_status.rpc_id(sender, world_ready)

@rpc("authority", "reliable")
func world_status(ready: bool) -> void:
	if is_host:
		return
	_last_inbound_ms = Time.get_ticks_msec()
	world_status_received.emit(ready)

@rpc("authority", "unreliable_ordered")
func sync_water_clock(seconds: float) -> void:
	if is_host or not is_finite(seconds) or seconds < 0.0:
		return
	_last_inbound_ms = Time.get_ticks_msec()
	water_world_time = seconds

static func accepts_player_state(host: bool, sender: int, player_id: int) -> bool:
	# Clients only accept the server relay; a peer cannot impersonate another.
	return sender == player_id if host else sender == 1

func _accepts_client_request(sender: int) -> bool:
	if not is_host:
		return false
	# sender 0 = llamada local sin RPC; sender == id propio = loopback del host
	# jugador (host_game también tiene personaje). Solo clientes remotos se validan.
	if sender == 0 or sender == multiplayer.get_unique_id():
		return true
	if not (sender > 1 and players.has(sender) and not bool(players[sender].get("offline", false))):
		return false
	players[sender]["last_seen"] = Time.get_ticks_msec()
	# Un personaje muerto ya no puede actuar — el proxy del servidor decide.
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_server_proxy_for_sender"):
		var sp = scene._server_proxy_for_sender(sender)
		if sp != null and is_instance_valid(sp) and sp.get_meta("proxy_dead", false):
			return false
	return true

func _accepts_world_sender(sender: int) -> bool:
	return _accepts_client_request(sender) if is_host else sender == 1

func peer_alive(pid: int) -> bool:
	if peer == null:
		return false
	# get_peers() es genérico (ENet y WS) y no escupe errores al consultar un
	# id ya desconectado — get_peer() lo hace.
	if not multiplayer.get_peers().has(pid):
		return false
	# Un WebSocket medio muerto (TCP abierto pero WS cerrado) sigue listado en
	# get_peers() hasta que TCP expira — durante minutos sus reservas de pickup
	# bloquean al resto y los broadcasts lanzan errores a cada send. El
	# ready_state del socket lo delata de inmediato.
	if peer is WebSocketMultiplayerPeer:
		var conn = (peer as WebSocketMultiplayerPeer).get_peer(pid)
		# Peer listado sin socket (o socket no OPEN) = peer muerto aunque
		# get_peers() lo siga incluyendo.
		if conn == null or not conn.has_method("get_ready_state") \
				or conn.get_ready_state() != WebSocketPeer.STATE_OPEN:
			return false
	return true

# Transient snapshots must never fill the reliable WebSocket queue. Dropping
# an old pose is safe; dropping a pickup reply or world transaction is not.
const SNAPSHOT_QUEUE_LIMIT := 256 * 1024
var _ws_congested_since: Dictionary = {}

func can_send_snapshot(pid: int) -> bool:
	if not peer_alive(pid):
		return false
	if peer is WebSocketMultiplayerPeer:
		var socket := (peer as WebSocketMultiplayerPeer).get_peer(pid)
		return socket != null and socket.get_current_outbound_buffered_amount() < SNAPSHOT_QUEUE_LIMIT
	return true

func snapshot_recipients() -> Array[int]:
	var recipients: Array[int] = []
	for pid in multiplayer.get_peers():
		if players.has(pid) and not players[pid].get("offline", false) and can_send_snapshot(pid):
			recipients.append(pid)
	return recipients

var _ws_dead_peer_scan := 0.0
# Cliente WS: heartbeat armado al conectar y marca del último dato entrante.
# El TCP puede quedar vivo aunque el stream real haya muerto en el túnel —
# entonces el reloj de agua (que llega cada 2 s) deja de entrar y hay que
# sacar al jugador al menú en vez de dejarle en un mundo fantasma.
var _ws_hb_armed := false
var _last_inbound_ms := 0
var _joined_ms := 0
var _status_probe_ms := 0
var _world_state_seen := false
var _was_world_built := false
# Flag "mundo listo": el servidor lo levanta al terminar la generación; el
# cliente lo consulta para saber si debe seguir esperando o ya puede recibir
# el estado del mundo — sin cortar por tiempo mientras el servidor responda.
var world_ready := false
signal world_status_received(ready: bool)

func _process(_delta: float) -> void:
	water_world_time += _delta
	if is_host and is_connected and multiplayer.has_multiplayer_peer():
		_water_clock_timer += _delta
		if _water_clock_timer >= 2.0:
			_water_clock_timer = 0.0
			for pid in snapshot_recipients():
				sync_water_clock.rpc_id(pid, water_world_time)
	if _dedicated_bind_retries > 0:
		_dedicated_bind_wait += _delta
		if _dedicated_bind_wait >= 1.0:
			_dedicated_bind_wait = 0.0
			_dedicated_bind_retries -= 1
			if start_dedicated_server(true):
				print("[SERVER] Puerto %d libre tras reintento — servidor activo" % GameConst.GAME_PORT)
			elif _dedicated_bind_retries <= 0:
				push_error("[SERVER] El puerto %d sigue ocupado — cerrando esta instancia" % GameConst.GAME_PORT)
				get_tree().quit()
	# A socket may remain OPEN while its receiver stops draining TCP. Bound
	# this condition as well as closed sockets, without disconnecting healthy peers.
	if is_host and is_dedicated_server and peer is WebSocketMultiplayerPeer:
		_ws_dead_peer_scan += _delta
		if _ws_dead_peer_scan >= 3.0:
			_ws_dead_peer_scan = 0.0
			var wsp := peer as WebSocketMultiplayerPeer
			for pid in multiplayer.get_peers():
				var conn := wsp.get_peer(pid)
				if conn == null:
					print("[NET] Peer ", pid, " sin socket en get_peer — desconectando")
					wsp.disconnect_peer(pid)
					continue
				var closed := conn.get_ready_state() in [WebSocketPeer.STATE_CLOSING, WebSocketPeer.STATE_CLOSED]
				var congested := conn.get_current_outbound_buffered_amount() >= SNAPSHOT_QUEUE_LIMIT
				if congested and not _ws_congested_since.has(pid):
					_ws_congested_since[pid] = Time.get_ticks_msec()
				elif not congested:
					_ws_congested_since.erase(pid)
				var stalled := congested and Time.get_ticks_msec() - int(_ws_congested_since.get(pid, 0)) > 180000
				if closed or stalled:
					print("[NET] Disconnect stalled WebSocket peer ", pid, " queued=", conn.get_current_outbound_buffered_amount())
					wsp.disconnect_peer(pid)
	# Cliente: heartbeat en WS (el socket aparece tras el handshake), sondeo
	# del flag "mundo listo" hasta que llega el primer dato, y detección del
	# stream muerto que el TCP no revela.
	if not is_host and multiplayer.has_multiplayer_peer():
		if peer is WebSocketMultiplayerPeer and not _ws_hb_armed:
			var wcl := peer as WebSocketMultiplayerPeer
			# La lista de peers vive en la API de alto nivel: el peer WS solo
			# expone get_peer(id), no get_peers().
			for pid in multiplayer.get_peers():
				var c = wcl.get_peer(pid)
				if c != null and c.get_ready_state() == WebSocketPeer.STATE_OPEN:
					c.heartbeat_interval = 60.0
					_ws_hb_armed = true
		if is_connected:
			# Hasta que el mundo local está construido (join + sync +
			# generación propia, que puede tardar minutos) el cliente
			# consulta el flag del servidor cada 10 s — cada respuesta
			# refresca el contador de silencio, así que solo se corta si el
			# servidor deja de responder del todo, nunca por tiempo de
			# espera ni por lo que tarde la generación local.
			var scene := get_tree().current_scene
			var world_built: bool = scene != null and scene.get("player") != null and scene.get("_loading_overlay") == null
			# Si el frame acaba de sufrir un bloqueo local de carga o compilación
			# de shaders (o acaba de terminar la pantalla de carga), reiniciamos
			# el reloj de silencio para no confundir un tirón del PC con caída de red.
			if _delta > 0.5 or (world_built and not _was_world_built):
				_last_inbound_ms = Time.get_ticks_msec()
			_was_world_built = world_built
			if _joined_ms > 0 and not world_built \
					and Time.get_ticks_msec() - _status_probe_ms > 10000:
				_status_probe_ms = Time.get_ticks_msec()
				request_world_status.rpc_id(1)
			if _joined_ms > 0:
				var since_ms := Time.get_ticks_msec() - \
					(_last_inbound_ms if _last_inbound_ms > 0 else _joined_ms)
				var limit_ms := 90000 if world_built else 240000
				if since_ms > limit_ms:
					print("[NET] >", limit_ms / 1000, "s sin datos del servidor — cerrando")
					_last_inbound_ms = 0
					_joined_ms = 0
					close_connection()
					connection_failed.emit()
	if is_host:
		# Listen for probe packets from clients doing active scan
		if _probe_listener != null:
			var count := _probe_listener.get_available_packet_count()
			while count > 0:
				var packet := _probe_listener.get_packet()
				var msg := packet.get_string_from_utf8()
				if msg == "LASTDAY_PROBE":
					var sender_ip := _probe_listener.get_packet_ip()
					var sender_port := _probe_listener.get_packet_port()
					var all_ips := _get_all_local_ips()
					var response := "LASTDAY_SERVER:" + ",".join(all_ips)
					_broadcast_server.set_dest_address(sender_ip, sender_port)
					_broadcast_server.put_packet(response.to_utf8_buffer())
					# Reset back to broadcast mode
					_broadcast_server.set_dest_address("255.255.255.255", GameConst.DISCOVERY_PORT)
				count -= 1
		# Periodic broadcast
		if _broadcast_server != null:
			_broadcast_timer += _delta
			if _broadcast_timer >= 2.0:
				_broadcast_timer = 0.0
				var all_ips := _get_all_local_ips()
				var msg := "LASTDAY_SERVER:" + ",".join(all_ips)
				_broadcast_server.set_dest_address("255.255.255.255", GameConst.DISCOVERY_PORT)
				_broadcast_server.put_packet(msg.to_utf8_buffer())

func _exit_tree() -> void:
	_close_discovery_sockets()

func _close_discovery_sockets() -> void:
	if _broadcast_server != null:
		_broadcast_server.close()
		_broadcast_server = null
	if _probe_listener != null:
		_probe_listener.close()
		_probe_listener = null

func join_game(ip: String, password: String = "") -> bool:
	close_connection()  # clears buffered state from any previous session
	var target := ip.strip_edges()
	# El host oficial autentica siempre con la pw embebida, da igual la vía
	# (botón, IP guardada, wss:// escrito a mano o dominio sin esquema).
	if target == OFFICIAL_SERVER_URL or target == "servidor.cronicasdesupervivencia.com":
		target = OFFICIAL_SERVER_URL
		if password.is_empty():
			password = OFFICIAL_SERVER_PASSWORD
	_join_password = password
	var err := OK
	if target.begins_with("ws://") or target.begins_with("wss://"):
		var ws := WebSocketMultiplayerPeer.new()
		# Mismo motivo que en el servidor: syncs grandes no deben desbordar el
		# buffer de salida y corromper la conexión a mitad de sesión.
		ws.outbound_buffer_size = 16 * 1024 * 1024
		ws.inbound_buffer_size = 16 * 1024 * 1024
		if "max_queued_packets" in ws:
			ws.max_queued_packets = 32768
		if target.begins_with("wss://"):
			err = ws.create_client(target, TLSOptions.client())
		else:
			err = ws.create_client(target)
		if err == OK:
			peer = ws
	else:
		var enet := ENetMultiplayerPeer.new()
		err = enet.create_client(target, GameConst.GAME_PORT)
		if err == OK:
			peer = enet
	if err != OK:
		push_error("No se pudo conectar al servidor: %d" % err)
		peer = null
		return false
	multiplayer.multiplayer_peer = peer
	is_host = false
	_last_inbound_ms = Time.get_ticks_msec()
	_joined_ms = Time.get_ticks_msec()
	_status_probe_ms = 0
	_world_state_seen = false
	_was_world_built = false
	_ws_hb_armed = false
	return true

func close_connection() -> void:
	_close_discovery_sockets()
	_broadcast_timer = 0.0
	_dedicated_bind_retries = 0
	_dedicated_bind_wait = 0.0
	is_dedicated_server = false
	_buffered_spawn_pos = Vector3.ZERO
	_has_buffered_spawn_pos = false
	_buffered_spawn_died = false
	_buffered_restore.clear()
	_has_buffered_restore = false
	_buffered_world_state.clear()
	_has_buffered_world_state = false
	_buffered_appearance.clear()
	_has_buffered_appearance = false
	animals.clear()
	_animals_seen.clear()
	_animals_gen = -1
	water_world_time = 0.0
	_water_clock_timer = 0.0
	_ws_congested_since.clear()
	_ws_hb_armed = false
	_last_inbound_ms = 0
	_joined_ms = 0
	_status_probe_ms = 0
	_world_state_seen = false
	_was_world_built = false
	world_ready = false
	authoritative_weather.clear()
	_weather_source_peer = 0
	if peer != null:
		peer.close()
		peer = null
	multiplayer.multiplayer_peer = null
	is_connected = false
	is_host = false
	players.clear()
	rowboat_state.clear()
	chat_groups.clear()
	_chat_group_seq = 0

func _on_peer_connected(id: int) -> void:
	# Only server has direct ENet connections to all peers — set timeout there.
	# WebSocket ya hereda la detección de pares muertos de TCP.
	if is_host and peer is ENetMultiplayerPeer:
		var enet_peer := (peer as ENetMultiplayerPeer).get_peer(id)
		if enet_peer != null:
			enet_peer.set_timeout(120000, 120000, 180000)
	# Ping WS periódico por conexión aceptada: mantiene viva la ruta
	# NAT/edge del cliente y delata sockets muertos en segundos, no minutos.
	if is_host and peer is WebSocketMultiplayerPeer:
		var ws_conn = (peer as WebSocketMultiplayerPeer).get_peer(id)
		if ws_conn != null:
			ws_conn.heartbeat_interval = 60.0
	if is_host:
		_kick_if_unregistered(id)
	# Don't send player list here — wait for _register_player so client_id is processed
	# and old offline entries are removed before sending the list
	player_connected.emit(id)

func _kick_if_unregistered(id: int) -> void:
	await get_tree().create_timer(REGISTRATION_TIMEOUT).timeout
	if not is_host or peer == null or players.has(id):
		return
	var p := multiplayer.multiplayer_peer
	if p != null and peer_alive(id):
		p.disconnect_peer(id)

func _on_peer_disconnected(id: int) -> void:
	_ws_congested_since.erase(id)
	if is_host and id == _weather_source_peer:
		_weather_source_peer = 0
	if is_host:
		# On server: keep player in list but mark as offline (don't erase)
		# so other clients still see the character in the world
		if players.has(id):
			players[id]["offline"] = true
	else:
		# On client: don't erase if player is marked offline (server keeps them)
		# The _sync_player_list RPC will update the list authoritatively
		if players.has(id) and not players[id].get("offline", false):
			players.erase(id)
	player_disconnected.emit(id)

func _on_connected_to_server() -> void:
	# Generous timeout so we don't drop the server while loading the world
	if peer is ENetMultiplayerPeer:
		var server_peer := (peer as ENetMultiplayerPeer).get_peer(1)
		if server_peer != null:
			server_peer.set_timeout(120000, 120000, 180000)
	is_connected = true
	var my_id := multiplayer.get_unique_id()
	# El nombre pedido en el menu al unirse (pending_player_name) es el nombre
	# del personaje: viaja en el registro y se mantiene hasta que muera.
	var my_name := pending_player_name.strip_edges()
	pending_player_name = ""
	if my_name.is_empty():
		my_name = "Jugador_%d" % my_id
	players[my_id] = {
		"name": my_name,
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true
	}
	_register_player.rpc_id(1, my_id, my_name, client_id, _join_password)
	connection_succeeded.emit()

func _on_connection_failed() -> void:
	close_connection()
	connection_failed.emit()

func _on_server_disconnected() -> void:
	close_connection()
	connection_failed.emit()

# El servidor pide el nombre solo para personajes nuevos; con un personaje
# vivo reclamado el nombre guardado gana y no se pregunta.
@rpc("authority", "reliable")
func request_player_name() -> void:
	if is_host:
		return
	player_name_required.emit()

@rpc("any_peer", "reliable")
func submit_player_name(new_name: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host or not players.has(sender):
		return
	# Solo un registro marcado como personaje nuevo acepta el nombre — un
	# jugador no puede renombrar un personaje vivo en mitad de sesión.
	if not players[sender].get("needs_name", false):
		return
	new_name = new_name.replace("|", "").replace(":", "").strip_edges()
	if new_name.is_empty() or new_name.length() > 80:
		return
	players[sender].erase("needs_name")
	players[sender]["name"] = new_name
	players[sender]["char_name"] = new_name
	_broadcast_player_list()

@rpc("authority", "reliable")
func _auth_rejected(reason: String = "password") -> void:
	if is_host:
		return
	auth_rejected.emit(reason)
	# Corta en local de inmediato — sin esperar al disconnect del servidor,
	# para que un intento de entrar al mundo falle el guard de is_connected.
	close_connection()

func _reject_registration(sender: int, reason: String) -> void:
	_auth_rejected.rpc_id(sender, reason)
	# Deja que el RPC se envíe antes de cortar la conexión.
	await get_tree().create_timer(0.25).timeout
	var p := multiplayer.multiplayer_peer
	if p != null:
		p.disconnect_peer(sender)

@rpc("any_peer", "reliable")
func _register_player(id: int, player_name: String, cid: String = "", pw: String = "") -> void:
	var sender := multiplayer.get_remote_sender_id()
	player_name = player_name.replace("|", "").replace(":", "").strip_edges()
	if player_name.is_empty():
		player_name = "Jugador_%d" % sender
	if not is_host or sender <= 1 or sender != id or cid.length() > 128 or player_name.length() > 80:
		return
	if not _server_password.is_empty() and pw != _server_password:
		push_error("[AUTH] pw mismatch peer=%d got_len=%d want_len=%d" % [sender, pw.length(), _server_password.length()])
		_reject_registration(sender, "password")
		return
	# Registration is idempotent; a replay must not reset a live character.
	if players.has(id) and not players[id].get("offline", false):
		return
	for pid in players:
		if not cid.is_empty() and pid != id and players[pid].get("client_id", "") == cid and not players[pid].get("offline", false):
			# Mismo client_id con la conexión anterior aún viva (TCP medio
			# abierto, timeout ENet pendiente): la nueva conexión gana — se
			# corta la vieja y sigue el registro. Un return silencioso aquí
			# dejaba al cliente esperando _sync_player_list para siempre. Va
			# antes del límite de jugadores para que la reconexión no se
			# rechace por su propia entrada obsoleta.
			if peer_alive(pid):
				var p := multiplayer.multiplayer_peer
				if p != null:
					p.disconnect_peer(pid)
			players.erase(pid)
			break
	if _public_server:
		# WebSocket no tiene el límite de pares de ENet — se aplica aquí.
		var online := 0
		for pid in players:
			if not players[pid].get("offline", false):
				online += 1
		if online >= MAX_PLAYERS:
			_reject_registration(sender, "full")
			return
	pass # print("[PERSIST] _register_player: id=%d name=%s cid=%s" % [id, player_name, cid])
	players[id] = {
		"name": player_name,
		"pos": SPAWN_POS,
		"rot": 0.0,
		"ready": true,
		"last_seen": Time.get_ticks_msec()
	}
	# Store client_id for proxy matching
	if not cid.is_empty():
		players[id]["client_id"] = cid
		# Remove old offline entry with same client_id
		var old_pid_to_remove := -1
		for pid in players.keys():
			if pid != id and players[pid].get("client_id", "") == cid:
				old_pid_to_remove = pid
				break
		if old_pid_to_remove != -1:
			players.erase(old_pid_to_remove)
		var scene := get_tree().current_scene
		if scene != null and scene.has_method("_match_proxy_to_client"):
			var reclaimed := bool(scene.call("_match_proxy_to_client", id, cid))
			if reclaimed:
				# En reclaim el nombre del personaje vivo es el del registro del
				# servidor — no se vuelve a preguntar mientras la partida siga.
				if scene.has_method("_saved_appearance_args"):
					var saved_app: Array = scene.call("_saved_appearance_args", cid)
					if not saved_app.is_empty() and not str(saved_app[0]).is_empty():
						players[id]["name"] = str(saved_app[0])
				# Reclaim de un personaje que nunca respondió el prompt (se fue
				# antes de escribir el nombre): su placeholder no es un nombre
				# real — hay que seguir pidiéndolo o queda "Jugador_N" para
				# siempre.
				var known_name := str(players[id].get("name", ""))
				if known_name.is_empty() or known_name.begins_with("Jugador_"):
					players[id]["needs_name"] = true
					request_player_name.rpc_id(id)
				# Bloquea la seleccion en el menu: el personaje del servidor es
				# el que se inicio la partida y no puede cambiarse hasta morir.
				if scene.has_method("_character_lock_payload"):
					notify_character_locked.rpc_id(id, scene.call("_character_lock_payload", id, cid))
			else:
				# Personaje nuevo o respawn tras muerte: el servidor pide el
				# nombre. Va antes del broadcast de la lista para que llegue a
				# la pantalla de conexión antes que all_players_ready.
				players[id]["needs_name"] = true
				request_player_name.rpc_id(id)
			# After matching, update player position from restored proxy
			if scene.server_proxies.has(id):
				players[id]["pos"] = scene.server_proxies[id].global_position
				players[id]["equipped_clothing"] = scene.server_proxies[id].get_meta("saved_clothing", "")
				players[id]["equipped_backpack"] = scene.server_proxies[id].get_meta("saved_backpack", "")
				players[id]["held_item"] = scene.server_proxies[id].get_meta("saved_held_item", "")
	# Send updated list to all clients (including new one)
	_broadcast_player_list()
	# Send current positions of all online players to the new client
	var peer_alive := true
	if peer is ENetMultiplayerPeer:
		peer_alive = (peer as ENetMultiplayerPeer).get_peer(id) != null
	if peer_alive:
		for pid in players.keys():
			if pid == id or pid == multiplayer.get_unique_id():
				continue
			if players[pid].get("offline", false):
				continue
			var pdata: Dictionary = players[pid]
			sync_player_state.rpc_id(id, pid, pdata.get("pos", Vector3(8.0, 0.4, 2.5)), pdata.get("rot", 0.0), pdata.get("anim", "idle"), pdata.get("equipped_clothing", ""), pdata.get("held_item", ""), pdata.get("equipped_backpack", ""), pdata.get("is_aiming", false), pdata.get("has_rifle", false), pdata.get("sleeping", false), pdata.get("sitting", false), pdata.get("prone", false), pdata.get("crouching", false), pdata.get("torch_lit", false), pdata.get("flashlight_on", false), pdata.get("clothing_colors", []))
			# Send character appearance if available
			if pdata.has("top_color"):
				var Grooming = preload("res://scripts/CharacterGrooming.gd")
				var wire_cn := str(pdata.get("char_name", ""))
				if pdata.has("hair_style") or pdata.has("beard_stage"):
					wire_cn = Grooming.encode_identity(wire_cn, str(pdata.get("hair_style", "")), int(pdata.get("beard_stage", 0)))
				sync_character_appearance_remote.rpc_id(id, pid, wire_cn, pdata.get("top_color", Color(0.5,0.5,0.5)), pdata.get("bottom_color", Color(0.3,0.3,0.3)), pdata.get("shoes_color", Color(0.15,0.15,0.15)), pdata.get("hair_color", Color(0.2,0.15,0.1)), pdata.get("skin_color", Color(0.8,0.7,0.6)), pdata.get("top_camo", false), pdata.get("bottom_camo", false))
		for gid in chat_groups.keys():
			var ginfo: Dictionary = chat_groups[gid]
			sync_chat_group.rpc_id(id, str(ginfo.get("id", gid)), str(ginfo.get("name", "Grupo")), ginfo.get("members", []), ginfo.get("member_names", []))
	_check_all_ready()
	_send_weather_state_to(id)

# client_id es el token con el que se reivindica el personaje del servidor al
# reconectar — nunca se broadcastea: quien lo tuviera podría apropiarse del
# personaje de otro jugador esperando a que se desconecte.
func _public_player_list() -> Dictionary:
	var out := players.duplicate(true)
	for pid in out.keys():
		var e = out[pid]
		if e is Dictionary:
			e.erase("client_id")
	return out

# La lista solo se envía a peers registrados — nunca .rpc() broadcast, que
# también alcanzaría conexiones sin registrar.
func _broadcast_player_list() -> void:
	if not is_host or peer == null:
		return
	var list := _public_player_list()
	for pid in players.keys():
		if pid == multiplayer.get_unique_id() or players[pid].get("offline", false) or not peer_alive(pid):
			continue
		_sync_player_list.rpc_id(pid, list)

@rpc("authority", "reliable")
func _sync_player_list(list: Dictionary) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	for pid in list.keys():
		pass
	players = list
	if players.size() >= 1:
		all_players_ready.emit()

func _check_all_ready() -> void:
	if players.size() >= 1:
		all_players_ready.emit()

# Position sync — called by each client for their own player
# Server relays to all other clients (dedicated server doesn't auto-forward)
@rpc("any_peer", "unreliable_ordered")
func sync_player_state(id: int, pos: Vector3, rot: float, anim: String, equipped_clothing: String, held_item: String, equipped_backpack: String, is_aiming: bool = false, has_rifle: bool = false, sleeping: bool = false, sitting: bool = false, prone: bool = false, crouching: bool = false, torch_lit: bool = false, flashlight_on: bool = false, clothing_colors: Array = []) -> void:
	if not accepts_player_state(is_host, multiplayer.get_remote_sender_id(), id):
		return
	# A NaN/inf position would poison proxies, broadcasts and the saved record.
	if not pos.is_finite() or not is_finite(rot):
		return
	if not players.has(id):
		if is_host:
			# La puerta de entrada es _register_player: un estado suelto no
			# puede crear jugadores. Sin este corte, un peer conectado sin
			# registrar (ni contraseña) se inyectaba en players y se
			# replicaba a todos los clientes como jugador real.
			return
		players[id] = {"name": "Jugador_%d" % id, "pos": pos, "rot": rot, "ready": true, "last_seen": Time.get_ticks_msec()}
	if is_host:
		# Heartbeat de actividad: el bote (Rowboat._peer_alive) y cualquier
		# otro recurso exclusivo liberan al ocupante cuando este valor envejece,
		# aunque el transporte tarde o nunca declare la desconexión.
		players[id]["last_seen"] = Time.get_ticks_msec()
		players[id]["in_world"] = true
	else:
		_last_inbound_ms = Time.get_ticks_msec()
	var boat_scene := get_tree().current_scene
	if is_host and boat_scene != null and is_instance_valid(boat_scene.get("lake_rowboat")):
		var boat = boat_scene.lake_rowboat
		if boat.occupant == id:
			pos = boat.global_position
			rot = boat.rotation.y + PI
			anim = "rowing/Stroke"
			held_item = ""
			is_aiming = false
			sleeping = false
			sitting = false
			prone = false
			crouching = false
	# Ignore position updates from reconnecting clients (they're still at spawn pos)
	if is_host:
		var scene := get_tree().current_scene
		if scene != null and scene.server_proxies.has(id):
			var proxy: Node3D = scene.server_proxies[id]
			# First real position sync = the client finished loading the world.
			# Restart spawn protection now so its 30s cover actual gameplay —
			# otherwise it expires during the loading screen and wolves can
			# maul the proxy before the player even sees it.
			if not proxy.get_meta("client_live", false):
				proxy.set_meta("client_live", true)
				proxy.set_meta("protection_timer", 30.0)
			if proxy.get_meta("reconnecting", false):
				return
			# Dead proxies are pinned at the death position where the loot
			# dropped — late syncs from the dying client must not move the
			# corpse. Still relay the dead state onward.
			if scene.server_proxies[id].get_meta("proxy_dead", false):
				# Keep the server-recorded death anim (e.g. "dead_melee") so a
				# late client sync does not downgrade the kill cause.
				var stored_anim := str(players[id].get("anim", ""))
				anim = stored_anim if stored_anim.begins_with("dead") else "dead"
				pos = players[id].get("pos", pos)
				rot = players[id].get("rot", rot)
				equipped_clothing = ""
				held_item = ""
				equipped_backpack = ""
				clothing_colors = []
	if not is_host:
		_last_inbound_ms = Time.get_ticks_msec()
	players[id]["pos"] = pos
	players[id]["rot"] = rot
	players[id]["anim"] = anim
	players[id]["equipped_clothing"] = equipped_clothing
	players[id]["clothing_colors"] = clothing_colors
	players[id]["held_item"] = held_item
	players[id]["equipped_backpack"] = equipped_backpack
	players[id]["is_aiming"] = is_aiming
	players[id]["has_rifle"] = has_rifle
	players[id]["sleeping"] = sleeping
	players[id]["sitting"] = sitting
	players[id]["prone"] = prone
	players[id]["crouching"] = crouching
	players[id]["torch_lit"] = torch_lit
	players[id]["flashlight_on"] = flashlight_on
	# Server relays to all other clients
	if is_host and peer != null:
		for pid in players.keys():
			if pid != id and pid != multiplayer.get_unique_id():
				# Skip offline players
				if players[pid].get("offline", false):
					continue
				# Skip peers that are not actually connected
				if not can_send_snapshot(pid):
					continue
				sync_player_state.rpc_id(pid, id, pos, rot, anim, equipped_clothing, held_item, equipped_backpack, is_aiming, has_rifle, sleeping, sitting, prone, crouching, torch_lit, flashlight_on, clothing_colors)

# Server->client payloads buffered when they arrive while the client is still
# in Inicio.tscn (before Main.tscn and its player exist). Main consumes them.
var _buffered_spawn_pos := Vector3.ZERO
var _has_buffered_spawn_pos := false
var _buffered_spawn_died := false
var _buffered_restore: Array = []
var _has_buffered_restore := false
var _buffered_world_state: Array = []
var _has_buffered_world_state := false
var _buffered_appearance: Array = []
var _has_buffered_appearance := false

@rpc("authority", "reliable")
func set_client_spawn_pos(pos: Vector3, _arg2: Variant = null, _arg3: Variant = null, _arg4: Variant = null, _arg5: Variant = null, _arg6: Variant = null, _arg7: Variant = null) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	var scene := get_tree().current_scene
	# _arg2 carries "died while offline" so the client can warn that this is a
	# fresh character, not a silent relocation.
	var died: bool = _arg2 is bool and _arg2
	if scene != null and scene.has_method("_apply_net_spawn_pos"):
		scene.call("_apply_net_spawn_pos", pos, died)
	else:
		_buffered_spawn_pos = pos
		_buffered_spawn_died = died
		_has_buffered_spawn_pos = true

@rpc("any_peer", "reliable")
func sync_player_inventory(items_data: Array, health: float, hunger: float, thirst: float, equipped_clothing: String, equipped_backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float, prone: bool = false, crouching: bool = false, extra: Dictionary = {}) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender) or not is_finite(health) or not is_finite(hunger) or not is_finite(thirst) or not is_finite(rot) or items_data.size() > 256 or extra.size() > 64:
		return
	if players.has(sender):
		players[sender]["in_world"] = true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_store_player_inventory"):
		scene.call("_store_player_inventory", sender, items_data, health, hunger, thirst, equipped_clothing, equipped_backpack, held_item, held_idx, sleeping, sitting, rot, prone, crouching, extra)

@rpc("authority", "reliable")
func restore_player_inventory(items_data: Array, health: float, hunger: float, thirst: float, equipped_clothing: String, equipped_backpack: String, held_item: String, held_idx: int, sleeping: bool, sitting: bool, rot: float, prone: bool = false, crouching: bool = false, extra: Dictionary = {}) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_apply_restored_inventory"):
		scene.call("_apply_restored_inventory", items_data, health, hunger, thirst, equipped_clothing, equipped_backpack, held_item, held_idx, sleeping, sitting, rot, prone, crouching, extra)
	else:
		_buffered_restore = [items_data, health, hunger, thirst, equipped_clothing, equipped_backpack, held_item, held_idx, sleeping, sitting, rot, prone, crouching, extra]
		_has_buffered_restore = true

# Client sends final position to server reliably before quitting
@rpc("any_peer", "reliable")
func final_player_state(pos: Vector3, rot: float, anim: String, equipped_clothing: String, held_item: String, equipped_backpack: String, sleeping: bool = false, sitting: bool = false, prone: bool = false, crouching: bool = false) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	pass # print("[PERSIST] final_player_state received from peer %d: pos=%s rot=%.2f sitting=%s prone=%s crouching=%s" % [sender, pos, rot, sitting, prone, crouching])
	if not pos.is_finite() or not is_finite(rot):
		return
	if not players.has(sender):
		pass # print("[PERSIST] final_player_state: peer %d not in players dict, ignoring" % sender)
		return
	var scene := get_tree().current_scene
	# Dead players stay pinned at the death position where their loot dropped —
	# a late final-state packet must not drag the corpse away from the items.
	if players[sender].get("anim", "").begins_with("dead"):
		return
	if scene != null and scene.server_proxies.has(sender) and scene.server_proxies[sender].get_meta("proxy_dead", false):
		return
	players[sender]["pos"] = pos
	players[sender]["rot"] = rot
	players[sender]["anim"] = anim
	players[sender]["equipped_clothing"] = equipped_clothing
	players[sender]["held_item"] = held_item
	players[sender]["equipped_backpack"] = equipped_backpack
	players[sender]["sleeping"] = sleeping
	players[sender]["sitting"] = sitting
	players[sender]["prone"] = prone
	players[sender]["crouching"] = crouching
	if scene != null and scene.server_proxies.has(sender):
		var proxy: Node3D = scene.server_proxies[sender]
		proxy.global_position = pos
		proxy.set_meta("saved_pos", pos)
		proxy.set_meta("saved_sleeping", sleeping)
		proxy.set_meta("saved_sitting", sitting)
		proxy.set_meta("saved_prone", prone)
		proxy.set_meta("saved_crouching", crouching)
		proxy.set_meta("saved_rot", rot)
		pass # print("[PERSIST] final_player_state: updated proxy for peer %d to pos=%s sitting=%s prone=%s" % [sender, pos, sitting, prone])
	elif scene != null:
		# Proxy may have already been moved to proxy_by_client_id on disconnect
		for cid in scene.proxy_by_client_id:
			var p: Node3D = scene.proxy_by_client_id[cid]
			if p != null and p.get_meta("peer_id", -1) == sender:
				p.global_position = pos
				p.set_meta("saved_pos", pos)
				p.set_meta("saved_sleeping", sleeping)
				p.set_meta("saved_sitting", sitting)
				p.set_meta("saved_prone", prone)
				p.set_meta("saved_crouching", crouching)
				p.set_meta("saved_rot", rot)
				pass # print("[PERSIST] final_player_state: updated disconnected proxy for peer %d to pos=%s sitting=%s prone=%s" % [sender, pos, sitting, prone])
				break
	else:
		pass # print("[PERSIST] final_player_state: no server proxy for peer %d" % sender)

# Animal state broadcast — server sends to all clients
# animal_id -> { "type": String, "pos": Vector3, "rot": float, "anim": String, "dead": bool }
var animals: Dictionary = {}

var _animals_gen := -1
var _animals_seen := {}

@rpc("authority", "call_remote", "reliable", 2)
func sync_bear_animals(data: Dictionary) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	# The ordinary wildlife stream is deliberately split into small UDP packets.
	# Bears are rare and distant, so send their compact state on a reliable lane
	# too; a lost chunk must never hide the only bear in a territory.
	for aid in animals.keys():
		if str(animals[aid].get("t", "")) == "bear" and not data.has(aid):
			animals.erase(aid)
	for aid in data.keys():
		var entry = data[aid]
		if not (entry is Dictionary) or str(entry.get("t", "")) != "bear":
			continue
		animals[aid] = entry.duplicate(true)
		animals[aid]["_sample"] = Time.get_ticks_usec()

@rpc("authority", "call_remote", "unreliable_ordered", 2)
func sync_animals(data: Dictionary) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	# Chunks carry "_gen"/"_total" so a broadcast split across packets is only
	# pruned once every chunk arrived. Without this, animals deleted on the
	# server lingered forever client-side.
	var gen := int(data.get("_gen", -1))
	var total := int(data.get("_total", -1))
	if gen >= 0 and gen < _animals_gen:
		return
	if gen < 0:
		# Legacy chunk without batch info: plain merge.
		for key in data.keys():
			animals[key] = data[key]
			animals[key]["_sample"] = Time.get_ticks_usec()
		return
	if gen != _animals_gen:
		_animals_gen = gen
		_animals_seen = {}
	for key in data.keys():
		if key == "_gen" or key == "_total":
			continue
		animals[key] = data[key]
		animals[key]["_sample"] = Time.get_ticks_usec()
		_animals_seen[key] = true
	if total >= 0 and _animals_seen.size() >= total:
		# Batch complete: drop animals the server stopped sending.
		for key in animals.keys():
			if not _animals_seen.has(key):
				animals.erase(key)

# Server tells specific client to apply damage
# Server relays wolf sound events (howl, attack) so client puppets play them.
@rpc("authority", "unreliable")
func animal_sound(animal_name: String, sound_type: String) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_animal_sound"):
		scene._net_animal_sound(animal_name, sound_type)

# Server tells specific client to apply damage
@rpc("authority", "reliable")
func apply_damage_to_client(amount: float, weapon: String = "") -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_apply_damage"):
		scene._net_apply_damage(amount, weapon)

# One-shot impacts and condition sounds travel separately from the frequent,
# unreliable pose snapshots so packet loss cannot hide a hit reaction.
@rpc("any_peer", "reliable")
func player_condition_audio(condition: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender) or (condition != "sick" and condition != "critical"):
		return
	_broadcast_player_condition_audio(sender, condition)

func _broadcast_player_condition_audio(peer_id: int, condition: String) -> void:
	if not is_host or peer == null:
		return
	for pid in players.keys():
		if pid == peer_id or pid == multiplayer.get_unique_id() or players[pid].get("offline", false) or not peer_alive(pid):
			continue
		player_condition_audio_event.rpc_id(pid, peer_id, condition)

@rpc("authority", "reliable")
func player_condition_audio_event(peer_id: int, condition: String) -> void:
	if condition != "sick" and condition != "critical":
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_player_condition_audio"):
		scene._net_player_condition_audio(peer_id, condition)

func _broadcast_player_hit(peer_id: int, kind: String, pos: Vector3, include_victim: bool = false) -> void:
	if not is_host or peer == null:
		return
	var scene := get_tree().current_scene
	if include_victim and peer_alive(peer_id) and peer_id != multiplayer.get_unique_id():
		player_hit_event.rpc_id(peer_id, peer_id, kind, pos)
	elif include_victim and peer_id == multiplayer.get_unique_id() and scene != null and scene.has_method("_net_player_hit_event"):
		scene._net_player_hit_event(peer_id, kind, pos)
	for pid in players.keys():
		if pid == peer_id or pid == multiplayer.get_unique_id() or players[pid].get("offline", false) or not peer_alive(pid):
			continue
		player_hit_event.rpc_id(pid, peer_id, kind, pos)

@rpc("authority", "reliable")
func player_hit_event(peer_id: int, kind: String, pos: Vector3) -> void:
	if kind not in ["rifle", "melee", "wolf_bite", "bear_bite"] or not pos.is_finite():
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_player_hit_event"):
		scene._net_player_hit_event(peer_id, kind, pos)

# Server tells specific client that they are dead (HP reached 0 on server).
# `cause` lets the victim pick the right death visual ("melee" = beaten).
@rpc("authority", "reliable")
func force_death_to_client(cause: String = "") -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_force_death"):
		scene._net_force_death(cause)

# Server reliably broadcasts player death to all clients
@rpc("authority", "reliable")
func broadcast_player_death(peer_id: int, pos: Vector3, rot: float, cause: String = "") -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_player_death_broadcast"):
		scene._net_player_death_broadcast(peer_id, pos, rot, cause)

# Client tells server to damage another player (PvP). `weapon` lets the
# server validate the hit distance per weapon type (melee vs rifle).
@rpc("any_peer", "reliable")
func damage_player(target_peer_id: int, amount: float, weapon: String = "melee") -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_damage_player"):
		scene._net_damage_player(target_peer_id, amount, sender, weapon)

# Client tells server to damage an animal
@rpc("any_peer", "reliable")
func damage_animal(animal_name: String, amount: float, from_knife: bool, bola: bool = false) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_damage_animal"):
		scene._net_damage_animal(animal_name, amount, from_knife, sender, bola)

# Server broadcasts animal hit to all clients so they play pain sound on puppets
@rpc("authority", "reliable")
func animal_hit(animal_name: String) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_animal_hit"):
		scene._net_animal_hit(animal_name)

# Cliente pide un comando a su lobo domesticado; el servidor valida que el peer
# sea el dueño antes de obedecer.
@rpc("any_peer", "reliable")
func command_wolf(animal_name: String, mode: String, target_name: String = "") -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_command_wolf"):
		scene._net_command_wolf(animal_name, mode, sender, target_name)

# Cooperativo: un jugador da de comer o de beber a otro jugador cercano.
# El servidor valida alcance (<4.5 m) y que ambos esten vivos, actualiza las
# estadisticas guardadas del receptor y le reenvia el efecto en vivo.
@rpc("any_peer", "reliable")
func feed_other_player(target_peer_id: int, item_name: String, item_type: String, d_hunger: float, d_thirst: float, d_health: float, is_hot: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_feed_other_player"):
		scene._net_feed_other_player(target_peer_id, item_name, item_type, d_hunger, d_thirst, d_health, is_hot, sender)

@rpc("authority", "reliable")
func receive_fed_by_player(giver_name: String, item_name: String, item_type: String, d_hunger: float, d_thirst: float, d_health: float, is_hot: bool) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_receive_fed_by_player"):
		scene._net_receive_fed_by_player(giver_name, item_name, item_type, d_hunger, d_thirst, d_health, is_hot)

# Aviso puntual del servidor a un cliente concreto (domesticación, órdenes, ...)
@rpc("authority", "reliable")
func notice_to_client(text: String) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_notice"):
		scene._net_notice(text)

# Client tells server to gut an animal (server processes and relays to all clients)
@rpc("any_peer", "reliable")
func gut_animal(animal_name: String, collect_mode: bool = false) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_gut_animal"):
		scene._net_gut_animal(animal_name, sender, collect_mode)

# Server tells all clients to remove gutted animal and spawn meat
@rpc("authority", "reliable")
func animal_gutted(animal_name: String, meat_drops: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_animal_gutted"):
		scene._net_animal_gutted(animal_name, meat_drops)

# Client tells server it picked up an item (server relays to all other clients)
@rpc("any_peer", "reliable")
func request_pickup_claim(action_id: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	var accepted := scene != null and scene.has_method("_claim_world_pickup") and bool(scene._claim_world_pickup(action_id, sender))
	pickup_claim_result.rpc_id(sender, action_id, accepted)

@rpc("authority", "reliable")
func pickup_claim_result(action_id: String, accepted: bool) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.get("_pickup_replies") is Dictionary and scene._pickup_replies.has(action_id):
		scene._pickup_replies[action_id] = accepted

@rpc("any_peer", "reliable")
func release_pickup_claim(action_id: String) -> void:
	# Allow cleanup after death too; only the owning peer can release a claim.
	if not is_host:
		return
	var sender := multiplayer.get_remote_sender_id()
	var scene := get_tree().current_scene
	if scene != null and scene.get("_pickup_claims") is Dictionary and int(scene._pickup_claims.get(action_id, 0)) == sender:
		scene._pickup_claims.erase(action_id)
		if scene.get("_pickup_claim_until") is Dictionary:
			scene._pickup_claim_until.erase(action_id)

@rpc("any_peer", "reliable")
func item_picked_up(action_id: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		# The authority validates first — a rejected pickup is neither applied
		# nor relayed to other clients.
		if scene != null and scene.has_method("_net_item_picked_up") and not scene._net_item_picked_up(action_id, sender):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						item_picked_up.rpc_id(pid, action_id)
		return
	# Client: authoritative broadcast — apply unconditionally.
	if scene != null and scene.has_method("_net_item_picked_up"):
		scene._net_item_picked_up(action_id)

# Client tells server it dropped an item in the world (server relays to all other clients)
@rpc("any_peer", "reliable")
func item_dropped(drop_id: String, item_name: String, item_type: String, item_weight: float, item_quantity: int, item_use_value: float, pos: Vector3, color: Color = Color(0, 0, 0, 0), contents: Array = [], wetness: float = 0.0, camo: bool = false, pelt: String = "", lit: bool = false, durability: float = 0.0) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		# The authority validates first — a rejected drop is neither applied
		# nor relayed to other clients.
		if scene != null and scene.has_method("_net_item_dropped") and not scene._net_item_dropped(drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos, color, sender, contents, wetness, camo, pelt, lit, durability):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						item_dropped.rpc_id(pid, drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos, color, contents, wetness, camo, pelt, lit, durability)
		return
	# Client: spawn the visual for a server-relayed drop.
	if scene != null and scene.has_method("_net_item_dropped"):
		scene._net_item_dropped(drop_id, item_name, item_type, item_weight, item_quantity, item_use_value, pos, color, 0, contents, wetness, camo, pelt, lit, durability)

# Cliente: saca un objeto de una mochila tirada en el suelo
@rpc("any_peer", "reliable")
func backpack_take(drop_id: String, item_index: int, expected_contents: Array = []) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if is_host and scene != null and scene.has_method("_net_backpack_take"):
		scene._net_backpack_take(sender, drop_id, item_index, expected_contents)

# Cliente: mete un objeto dentro de una mochila tirada en el suelo
@rpc("any_peer", "reliable")
func backpack_store(drop_id: String, item_dict: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if is_host and scene != null and scene.has_method("_net_backpack_store"):
		scene._net_backpack_store(sender, drop_id, item_dict)

# Host → cliente que sacó: le entrega el objeto
@rpc("authority", "reliable")
func backpack_give(item_dict: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_backpack_give"):
		scene._net_backpack_give(item_dict)

# Host → todos: contenido actualizado de la mochila tirada
@rpc("authority", "reliable")
func backpack_contents_synced(drop_id: String, contents: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_backpack_contents_synced"):
		scene._net_backpack_contents_synced(drop_id, contents)

# Client tells server its player died (server drops inventory as loot)
@rpc("any_peer", "reliable")
func notify_death(inventory_data: Array = [], hp: float = 0.0, hunger: float = 0.0, thirst: float = 0.0, clothing: String = "", backpack: String = "", held: String = "", held_index: int = 0, sleeping: bool = false, sitting: bool = false, rot: float = 0.0, death_pos: Vector3 = Vector3.ZERO) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_player_died"):
		scene._net_player_died(sender, inventory_data, death_pos, backpack, held)

@rpc("any_peer", "reliable")
func ground_craft_state_changed(action_id: String, quantity: int, durability: float) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if scene == null or not scene.has_method("_apply_ground_craft_state"):
		return
	if not scene._apply_ground_craft_state(action_id, quantity, durability, sender):
		return
	if is_host and peer != null:
		for pid in players.keys():
			if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false) and peer_alive(pid):
				ground_craft_state_changed.rpc_id(pid, action_id, quantity, durability)

func get_player_list() -> Dictionary:
	return players

# Generic RPC: client tells server a world action was completed.
# action_id: the action to remove (empty string if none)
# spawns: array of dictionaries with item spawn data
# extra_visual: "tree_remains", "cabin", or ""
# extra_pos: position for the extra visual
@rpc("any_peer", "reliable")
func world_action_completed(action_id: String, spawns: Array, extra_visual: String, extra_pos: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		# The authority validates first — a rejected action is neither applied
		# nor relayed to other clients.
		if scene != null and scene.has_method("_net_world_action_completed") and not scene._net_world_action_completed(action_id, spawns, extra_visual, extra_pos, sender):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						world_action_completed.rpc_id(pid, action_id, spawns, extra_visual, extra_pos)
		return
	if scene != null and scene.has_method("_net_world_action_completed"):
		scene._net_world_action_completed(action_id, spawns, extra_visual, extra_pos)

# Client tells server it built a campfire (server relays to all other clients)
@rpc("any_peer", "reliable")
func campfire_built(cf_id: String, pos: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		if scene != null and scene.has_method("_net_campfire_built") and not scene._net_campfire_built(cf_id, pos, sender):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						campfire_built.rpc_id(pid, cf_id, pos)
		return
	if scene != null and scene.has_method("_net_campfire_built"):
		scene._net_campfire_built(cf_id, pos)

# Client tells server it built a shelter (server relays to all other clients)
@rpc("any_peer", "reliable")
func shelter_built(sh_id: String, pos: Vector3, yaw: float = 0.0) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		if scene != null and scene.has_method("_net_shelter_built") and not scene._net_shelter_built(sh_id, pos, sender, yaw):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						shelter_built.rpc_id(pid, sh_id, pos, yaw)
		return
	if scene != null and scene.has_method("_net_shelter_built"):
		scene._net_shelter_built(sh_id, pos, 0, yaw)

@rpc("any_peer", "reliable")
func shelter_lined(sh_id: String, lined: bool = true) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		if scene == null or not scene.has_method("_net_shelter_lined") or not scene._net_shelter_lined(sh_id, sender, lined):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false) and peer_alive(pid):
					shelter_lined.rpc_id(pid, sh_id, lined)
		return
	if scene != null and scene.has_method("_net_shelter_lined"):
		scene._net_shelter_lined(sh_id, 0, lined)

@rpc("any_peer", "reliable")
func shelter_camo_changed(sh_id: String, covered: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		if scene == null or not scene.has_method("_net_shelter_camo_changed") or not scene._net_shelter_camo_changed(sh_id, covered, sender):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false) and peer_alive(pid):
					shelter_camo_changed.rpc_id(pid, sh_id, covered)
		return
	if scene != null and scene.has_method("_net_shelter_camo_changed"):
		scene._net_shelter_camo_changed(sh_id, covered)

# Client tells server it dismantled a shelter (server relays to all other clients)
@rpc("any_peer", "reliable")
func shelter_dismantled(sh_id: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		if scene != null and scene.has_method("_net_shelter_dismantled") and not scene._net_shelter_dismantled(sh_id, sender):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						shelter_dismantled.rpc_id(pid, sh_id)
		return
	if scene != null and scene.has_method("_net_shelter_dismantled"):
		scene._net_shelter_dismantled(sh_id)

# Client tells server it lit a campfire (server relays to all other clients)
@rpc("any_peer", "reliable")
func campfire_lit(action_id: String, fire_name: String, pos: Vector3) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		if scene != null and scene.has_method("_net_campfire_lit") and not scene._net_campfire_lit(action_id, fire_name, pos, sender):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						campfire_lit.rpc_id(pid, action_id, fire_name, pos)
		return
	if scene != null and scene.has_method("_net_campfire_lit"):
		scene._net_campfire_lit(action_id, fire_name, pos)

# Server sends world state to a newly connected client
@rpc("authority", "reliable")
func sync_world_state(depleted_ids: Array, dropped_items: Array, campfires: Array, lit_campfires: Array, open_doors: Array, shelters: Array, planted_crops: Array = []) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	_world_state_seen = true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_sync_world_state") and scene.get("player") != null:
		scene._net_sync_world_state(depleted_ids, dropped_items, campfires, lit_campfires, open_doors, shelters, planted_crops)
	elif not is_host:
		_buffered_world_state = [depleted_ids, dropped_items, campfires, lit_campfires, open_doors, shelters, planted_crops]
		_has_buffered_world_state = true

# Client tells server a door was toggled (server relays to all other clients)
@rpc("any_peer", "reliable")
func door_state_changed(door_name: String, is_open: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender):
		return
	var scene := get_tree().current_scene
	if is_host:
		# The authority validates first — a rejected toggle is neither applied
		# nor relayed to other clients.
		if scene != null and scene.has_method("_net_door_state_changed") and not scene._net_door_state_changed(door_name, is_open, sender):
			return
		if peer != null:
			for pid in players.keys():
				if pid != sender and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						door_state_changed.rpc_id(pid, door_name, is_open)
		return
	if scene != null and scene.has_method("_net_door_state_changed"):
		scene._net_door_state_changed(door_name, is_open)

@rpc("any_peer", "reliable")
func request_rowboat(action: String) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and is_instance_valid(scene.get("lake_rowboat")):
		scene.lake_rowboat.request_action(sender, action)

@rpc("any_peer", "unreliable_ordered")
func rowboat_input(axis: Vector2) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender) or not axis.is_finite():
		return
	var scene := get_tree().current_scene
	if scene != null and is_instance_valid(scene.get("lake_rowboat")):
		scene.lake_rowboat.accept_input(sender, axis)

@rpc("authority", "reliable")
func sync_rowboat(state: Dictionary) -> void:
	if is_host:
		return
	rowboat_state = state
	var scene := get_tree().current_scene
	if scene != null and is_instance_valid(scene.get("lake_rowboat")):
		scene.lake_rowboat.apply_network_state(state)

func get_my_id() -> int:
	if multiplayer == null or not multiplayer.has_multiplayer_peer():
		return 1
	if peer != null and peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return 1
	return multiplayer.get_unique_id()

# Client tells server it fired the rifle (server relays to all other clients)
@rpc("any_peer", "reliable")
func player_shot_rifle(shooter_id: int, origin: Vector3, dir: Vector3, wind: Vector3 = Vector3.ZERO) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_world_sender(sender) or (is_host and shooter_id != sender):
		return
	if not origin.is_finite() or not dir.is_finite() or not wind.is_finite() or wind.length() > 100.0 or dir.length_squared() < 0.0001:
		return
	dir = dir.normalized()
	var scene := get_tree().current_scene
	if is_host and peer != null:
		# Don't relay shots from dead or unknown shooters.
		if scene == null or not scene.has_method("_is_shooter_valid") or scene._is_shooter_valid(shooter_id):
			for pid in players.keys():
				if pid != shooter_id and pid != multiplayer.get_unique_id() and not players[pid].get("offline", false):
					if peer_alive(pid):
						player_shot_rifle.rpc_id(pid, shooter_id, origin, dir, wind)
	if scene != null and scene.has_method("_net_player_shot_rifle"):
		scene._net_player_shot_rifle(shooter_id, origin, dir, wind)

# Client requests loot inventory from a dead player corpse
@rpc("any_peer", "reliable")
func request_loot(dead_peer_id: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_request_loot"):
		scene._net_request_loot(sender, dead_peer_id)

# Server sends corpse inventory to requesting client
@rpc("authority", "reliable")
func send_loot(dead_peer_id: int, items_data: Array) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_receive_loot"):
		scene._net_receive_loot(dead_peer_id, items_data)

# Client takes an item from a dead player corpse
@rpc("any_peer", "reliable")
func take_loot(dead_peer_id: int, item_index: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender):
		return
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_take_loot"):
		scene._net_take_loot(sender, dead_peer_id, item_index)

# Server sends a single looted item to the taker's client
@rpc("authority", "reliable")
func add_looted_item(item_data: Dictionary) -> void:
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_add_looted_item"):
		scene._net_add_looted_item(item_data)

# Client sends character appearance to server (name, colors, camo flags)
@rpc("any_peer", "reliable")
func sync_character_appearance(char_name: String, top_color: Color, bottom_color: Color, shoes_color: Color, hair_color: Color, skin_color: Color, top_camo: bool, bottom_camo: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not _accepts_client_request(sender) or char_name.length() > 80:
		return
	if not players.has(sender):
		return
	# El nombre lo fija el registro/submit_player_name y dura hasta la muerte:
	# la apariencia periódica no puede renombrar un personaje vivo — se clampa
	# al nombre que el servidor ya conoce, pero conserva el peinado y la barba.
	var Grooming = preload("res://scripts/CharacterGrooming.gd")
	var has_groom_meta := char_name.contains("|") or char_name.contains(":")
	var h_style: String = Grooming.style_for(char_name)
	var b_stage: int = Grooming.stage_from_identity(char_name, 0.0)
	var clean_name: String = Grooming.base_name_from_identity(char_name)
	var fixed_name := Grooming.base_name_from_identity(str(players[sender].get("name", "")))
	if sender != multiplayer.get_unique_id() and not players[sender].get("needs_name", false) and not fixed_name.is_empty() and not fixed_name.begins_with("Jugador_"):
		clean_name = fixed_name
	players[sender]["char_name"] = clean_name
	players[sender]["in_world"] = true
	if has_groom_meta or not players[sender].has("hair_style"):
		players[sender]["hair_style"] = h_style
	if has_groom_meta or not players[sender].has("beard_stage"):
		players[sender]["beard_stage"] = b_stage
	players[sender]["top_color"] = top_color
	players[sender]["bottom_color"] = bottom_color
	players[sender]["shoes_color"] = shoes_color
	players[sender]["hair_color"] = hair_color
	players[sender]["skin_color"] = skin_color
	players[sender]["top_camo"] = top_camo
	players[sender]["bottom_camo"] = bottom_camo
	var wire_name: String = Grooming.encode_identity(clean_name, str(players[sender].get("hair_style", h_style)), int(players[sender].get("beard_stage", b_stage)))
	# Relay to all other clients
	if is_host and peer != null:
		for pid in players.keys():
			if pid != sender and pid != multiplayer.get_unique_id():
				if players[pid].get("offline", false):
					continue
				if not peer_alive(pid):
					continue
				sync_character_appearance_remote.rpc_id(pid, sender, wire_name, top_color, bottom_color, shoes_color, hair_color, skin_color, top_camo, bottom_camo)

# Server sends the persisted character appearance back to its owner on
# reconnect — the client_id's server character is fixed until it dies, so
# whatever card was picked in Inicio gets overridden.
@rpc("authority", "reliable")
func restore_character_appearance(char_name: String, top_color: Color, bottom_color: Color, shoes_color: Color, hair_color: Color, skin_color: Color, top_camo: bool, bottom_camo: bool) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_apply_restored_appearance"):
		scene._apply_restored_appearance(char_name, top_color, bottom_color, shoes_color, hair_color, skin_color, top_camo, bottom_camo)
	else:
		_buffered_appearance = [char_name, top_color, bottom_color, shoes_color, hair_color, skin_color, top_camo, bottom_camo]
		_has_buffered_appearance = true

# Server tells a reclaiming client its character is locked: the menu must
# show that character (with its equipment) instead of a free selection.
# Sent before the player-list broadcast so it lands before all_players_ready.
@rpc("authority", "reliable")
func notify_character_locked(payload: Dictionary) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	server_character_locked.emit(payload)

# Server relays character appearance to a specific client
@rpc("authority", "reliable")
func sync_character_appearance_remote(peer_id: int, char_name: String, top_color: Color, bottom_color: Color, shoes_color: Color, hair_color: Color, skin_color: Color, top_camo: bool, bottom_camo: bool) -> void:
	_last_inbound_ms = Time.get_ticks_msec()
	var Grooming = preload("res://scripts/CharacterGrooming.gd")
	var has_groom_meta := char_name.contains("|") or char_name.contains(":")
	var clean_name: String = Grooming.base_name_from_identity(char_name)
	if not players.has(peer_id):
		players[peer_id] = {"name": "Jugador_%d" % peer_id, "pos": SPAWN_POS, "rot": 0.0, "ready": true}
	players[peer_id]["char_name"] = clean_name
	if has_groom_meta or not players[peer_id].has("hair_style"):
		players[peer_id]["hair_style"] = Grooming.style_for(char_name)
	if has_groom_meta or not players[peer_id].has("beard_stage"):
		players[peer_id]["beard_stage"] = Grooming.stage_from_identity(char_name, 0.0)
	players[peer_id]["top_color"] = top_color
	players[peer_id]["bottom_color"] = bottom_color
	players[peer_id]["shoes_color"] = shoes_color
	players[peer_id]["hair_color"] = hair_color
	players[peer_id]["skin_color"] = skin_color
	players[peer_id]["top_camo"] = top_camo
	players[peer_id]["bottom_camo"] = bottom_camo

func _broadcast_chat_group(gid: String) -> void:
	if not chat_groups.has(gid):
		return
	var ginfo: Dictionary = chat_groups[gid]
	var gname := str(ginfo.get("name", "Grupo"))
	var valid_members: Array = ginfo.get("members", [])
	var member_names: Array = ginfo.get("member_names", [])
	var my_uid := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if not is_dedicated_server:
		sync_chat_group(gid, gname, valid_members, member_names)
	if peer != null:
		for pid in players.keys():
			var p_int := int(pid)
			if p_int <= 1 or p_int == my_uid:
				continue
			if not players[pid].get("offline", false) and peer_alive(p_int):
				sync_chat_group.rpc_id(p_int, gid, gname, valid_members, member_names)

@rpc("any_peer", "reliable")
func create_chat_group(group_name: String, member_ids: Array = []) -> String:
	var sender := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 0
	if sender == 0 and is_host:
		sender = get_my_id()
	if not _accepts_client_request(sender):
		return ""
	var gname := group_name.strip_edges().replace("\n", " ").replace("\r", " ").substr(0, 40)
	if gname.is_empty():
		return ""
	var valid_members: Array = []
	var member_names: Array = []
	var requested := [sender]
	for mid in member_ids:
		var pid := int(mid)
		if not requested.has(pid):
			requested.append(pid)
	for pid in requested:
		if not players.has(pid) or players[pid].get("offline", false):
			continue
		valid_members.append(pid)
		var pdata: Dictionary = players[pid]
		var pname := str(pdata.get("char_name", ""))
		if pname.is_empty():
			pname = str(pdata.get("name", "Jugador_%d" % pid))
		member_names.append(pname)
	if valid_members.is_empty():
		return ""
	_chat_group_seq += 1
	var gid := "grp_%d_%d" % [_chat_group_seq, Time.get_ticks_msec() % 100000]
	chat_groups[gid] = {"id": gid, "name": gname, "members": valid_members, "member_names": member_names}
	_broadcast_chat_group(gid)
	return gid

@rpc("any_peer", "reliable")
func join_chat_group(group_id: String) -> bool:
	var sender := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 0
	if sender == 0 and is_host:
		sender = get_my_id()
	if not _accepts_client_request(sender):
		return false
	if not chat_groups.has(group_id):
		return false
	var ginfo: Dictionary = chat_groups[group_id]
	var members: Array = (ginfo.get("members", []) as Array).duplicate()
	var mnames: Array = (ginfo.get("member_names", []) as Array).duplicate()
	if not members.has(sender):
		members.append(sender)
		var pname := "Jugador_%d" % sender
		if players.has(sender):
			var pdata: Dictionary = players[sender]
			pname = str(pdata.get("char_name", ""))
			if pname.is_empty():
				pname = str(pdata.get("name", pname))
		mnames.append(pname)
		ginfo["members"] = members
		ginfo["member_names"] = mnames
		chat_groups[group_id] = ginfo
	_broadcast_chat_group(group_id)
	return true

@rpc("authority", "reliable")
func sync_chat_group(group_id: String, group_name: String, member_ids: Array, member_names: Array) -> void:
	chat_groups[group_id] = {"id": group_id, "name": group_name, "members": member_ids.duplicate(), "member_names": member_names.duplicate()}
	chat_group_synced.emit(group_id, group_name, member_ids, member_names)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_sync_chat_group"):
		scene._net_sync_chat_group(group_id, group_name, member_ids, member_names)

@rpc("any_peer", "reliable")
func send_chat_message(text: String, target_peer_id: int = 0, group_id: String = "") -> void:
	var sender := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 0
	if sender == 0 and is_host:
		sender = get_my_id()
	if not _accepts_client_request(sender):
		return
	var clean := text.strip_edges().replace("\n", " ").replace("\r", " ")
	if clean.length() > 160:
		clean = clean.substr(0, 160)
	if clean.is_empty():
		return
	# No existe chat público global: exige destinatario directo (target_peer_id > 0) o grupo válido (group_id != "")
	if target_peer_id <= 0 and group_id.is_empty():
		return
	var sender_name := "Jugador"
	if players.has(sender):
		var pdata: Dictionary = players[sender]
		sender_name = str(pdata.get("char_name", ""))
		if sender_name.is_empty():
			sender_name = str(pdata.get("name", "Jugador"))
	var my_uid := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if not group_id.is_empty():
		if not chat_groups.has(group_id):
			return
		var ginfo: Dictionary = chat_groups[group_id]
		var members: Array = ginfo.get("members", [])
		if not members.has(sender):
			return
		var gname := str(ginfo.get("name", "Grupo"))
		if not is_dedicated_server and members.has(my_uid):
			receive_chat_message(sender, sender_name, clean, 0, gname, group_id)
		if peer != null:
			for pid in members:
				var m_pid := int(pid)
				if m_pid <= 1 or m_pid == my_uid:
					continue
				if players.has(m_pid) and not players[m_pid].get("offline", false) and peer_alive(m_pid):
					receive_chat_message.rpc_id(m_pid, sender, sender_name, clean, 0, gname, group_id)
		return
	if not players.has(target_peer_id) or players[target_peer_id].get("offline", false):
		return
	var tdata: Dictionary = players[target_peer_id]
	var target_name := str(tdata.get("char_name", ""))
	if target_name.is_empty():
		target_name = str(tdata.get("name", "Jugador"))
	if not is_dedicated_server and (sender == my_uid or target_peer_id == my_uid):
		receive_chat_message(sender, sender_name, clean, target_peer_id, target_name, "")
	if peer != null:
		for recipient in [sender, target_peer_id]:
			if recipient <= 1 or recipient == my_uid:
				continue
			if players.has(recipient) and not players[recipient].get("offline", false) and peer_alive(recipient):
				receive_chat_message.rpc_id(recipient, sender, sender_name, clean, target_peer_id, target_name, "")
			if sender == target_peer_id:
				break

@rpc("authority", "reliable")
func receive_chat_message(sender_id: int, sender_name: String, text: String, target_id: int = 0, target_name: String = "", group_id: String = "") -> void:
	chat_message_received.emit(sender_id, sender_name, text, target_id, target_name, group_id)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_receive_chat_message"):
		scene._net_receive_chat_message(sender_id, sender_name, text, target_id, target_name, group_id)

# La voz va "unreliable" a secas, sin ordenar: si compartiera la secuencia
# ordenada del canal 0 con sync_player_state/sync_animals (20 Hz + fauna), los
# paquetes de voz que llegaran tras un estado más nuevo se descartarían como
# obsoletos — cortes al quieto y silencio total al moverse. Sin orden, cada
# chunk se entrega siempre; en LAN el reordenamiento real es raro.
@rpc("any_peer", "unreliable")
func send_voice_packet(pcm_bytes: PackedByteArray, target_peer_id: int = 0, group_id: String = "") -> void:
	var sender := multiplayer.get_remote_sender_id() if multiplayer.has_multiplayer_peer() else 0
	if sender == 0 and is_host:
		sender = get_my_id()
	if not _accepts_client_request(sender):
		return
	if pcm_bytes.is_empty() or pcm_bytes.size() > 1200:
		return
	# Sin canal público: requiere destinatario 1-a-1 o un grupo al que el emisor pertenezca
	if target_peer_id <= 0 and group_id.is_empty():
		return
	var sender_name := "Jugador"
	if players.has(sender):
		var pdata: Dictionary = players[sender]
		sender_name = str(pdata.get("char_name", ""))
		if sender_name.is_empty():
			sender_name = str(pdata.get("name", "Jugador"))
	var my_uid := multiplayer.get_unique_id() if multiplayer.has_multiplayer_peer() else 1
	if not group_id.is_empty():
		if not chat_groups.has(group_id):
			return
		var ginfo: Dictionary = chat_groups[group_id]
		var members: Array = ginfo.get("members", [])
		if not members.has(sender):
			return
		var gname := str(ginfo.get("name", "Grupo"))
		# Todos los demás miembros del grupo reciben el audio y pueden hablar simultáneamente
		if not is_dedicated_server and members.has(my_uid) and sender != my_uid:
			receive_voice_packet(sender, sender_name, pcm_bytes, 0, gname, group_id)
		if peer != null:
			for pid in members:
				var m_pid := int(pid)
				if m_pid <= 1 or m_pid == my_uid or m_pid == sender:
					continue
				if players.has(m_pid) and not players[m_pid].get("offline", false) and peer_alive(m_pid):
					receive_voice_packet.rpc_id(m_pid, sender, sender_name, pcm_bytes, 0, gname, group_id)
		return
	if target_peer_id == sender or not players.has(target_peer_id) or players[target_peer_id].get("offline", false):
		return
	var tdata: Dictionary = players[target_peer_id]
	var target_name := str(tdata.get("char_name", ""))
	if target_name.is_empty():
		target_name = str(tdata.get("name", "Jugador"))
	if not is_dedicated_server and target_peer_id == my_uid:
		receive_voice_packet(sender, sender_name, pcm_bytes, target_peer_id, target_name, "")
	elif peer != null and target_peer_id > 1 and peer_alive(target_peer_id):
		receive_voice_packet.rpc_id(target_peer_id, sender, sender_name, pcm_bytes, target_peer_id, target_name, "")

@rpc("authority", "unreliable")
func receive_voice_packet(sender_id: int, sender_name: String, pcm_bytes: PackedByteArray, target_id: int = 0, target_name: String = "", group_id: String = "") -> void:
	voice_packet_received.emit(sender_id, sender_name, pcm_bytes, target_id, target_name, group_id)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("_net_receive_voice_packet"):
		scene._net_receive_voice_packet(sender_id, sender_name, pcm_bytes, target_id, target_name, group_id)

# Each accepted message represents one projectile, never an inventory drop.
@rpc("any_peer", "reliable")
func primitive_shot(shooter_id: int, origin: Vector3, direction: Vector3, item_name: String, speed: float, wind: Vector3 = Vector3.ZERO) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if is_host and sender == 0:
		sender = get_my_id()
	if not _accepts_world_sender(sender) or (is_host and shooter_id != sender):
		return
	if not wind.is_finite() or wind.length() > 100.0:
		return
	if not origin.is_finite() or not direction.is_finite() or direction.length_squared() < 0.001 or not is_finite(speed):
		return
	if not item_name in ["Flecha de madera", "Flecha de piedra", "Flecha de hueso", "Flecha improvisada", "Lanza", "Lanza de hueso", "Palo afilado", "Boleadoras"]:
		return
	if speed < 1.0 or speed > 95.0:
		return
	var scene := get_tree().current_scene
	if scene == null:
		return
	if is_host:
		if not scene._is_shooter_valid(shooter_id) or (shooter_id != get_my_id() and not scene._sender_within(shooter_id, origin, 5.0)):
			return
		if peer != null:
			for pid in players.keys():
				if pid != shooter_id and pid != get_my_id() and peer_alive(pid):
					primitive_shot.rpc_id(pid, shooter_id, origin, direction, item_name, speed, wind)
	if scene.has_method("_net_primitive_shot"):
		scene._net_primitive_shot(shooter_id, origin, direction, item_name, speed, wind)
