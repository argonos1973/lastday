extends Control

const NetworkManagerScript = preload("res://scripts/NetworkManager.gd")
const DISCOVERY_PORT := 5006

var _started: bool = false
var _mode: String = ""  # "single", "host", "join"
var _net = null
var _ip_edit: LineEdit = null
var _btn_connect: Button = null
var _status_label: Label = null
var _discovery: PacketPeerUDP = null
var _discovered_ips: Array = []
var _scan_timer := 0.0
var _scan_index := 0
var _scan_probe: PacketPeerUDP = null
var _scanning := false
var _scan_subnet := "192.168.0"

var _char_index := 0
var _char_name_label: Label = null
var _char_preview_anchor: Node3D = null
var _char_preview_cam: Camera3D = null

func _ready() -> void:
	# Dedicated server: skip UI entirely, load the world immediately
	var net_check = get_node_or_null("/root/NetworkManager")
	if net_check != null and net_check.is_dedicated_server:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")
		return
	# TEMP: auto-start for testing
	var args := OS.get_cmdline_user_args()
	if args.has("--test-drop"):
		var gs_debug := get_node_or_null("/root/GameState")
		if gs_debug != null:
			gs_debug.select_character(0)
		get_tree().create_timer(2.0).timeout.connect(_start_game)
		return
	if args.size() >= 2 and args[0] == "--client":
		var ip := args[1]
		_net = get_node("/root/NetworkManager")
		_net.connection_succeeded.connect(_on_net_connected)
		_net.connection_failed.connect(_on_net_failed)
		if _net.join_game(ip):
			pass # print("[CLIENT] Conectando a %s..." % ip)
			_mode = "join"
			get_tree().create_timer(1.0).timeout.connect(_start_game)
		else:
			pass # print("[CLIENT] Error al conectar a %s" % ip)
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	# Forzar ventana al frente (necesario en macOS al lanzar desde terminal)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, false)

	# Start UDP discovery listener to auto-find server on local network
	_discovery = PacketPeerUDP.new()
	var bind_err := _discovery.bind(DISCOVERY_PORT)
	if bind_err == OK:
		pass # print("[DISCOVERY] Escuchando broadcasts del servidor en puerto %d" % DISCOVERY_PORT)
	else:
		pass # print("[DISCOVERY] No se pudo bind puerto %d: %d" % [DISCOVERY_PORT, bind_err])
		_discovery = null

	# Background color (dark) in case image fails
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Load inicio.png
	var tex_rect := TextureRect.new()
	var abs_path := ProjectSettings.globalize_path("res://assets/textures/inicio.png")
	var loaded := false
	var img := Image.load_from_file(abs_path)
	if img != null:
		tex_rect.texture = ImageTexture.create_from_image(img)
		loaded = true
	if not loaded:
		var img2 := Image.new()
		var err := img2.load_png_from_buffer(FileAccess.get_file_as_bytes(abs_path))
		if err == OK:
			tex_rect.texture = ImageTexture.create_from_image(img2)
			loaded = true
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.anchors_preset = Control.PRESET_FULL_RECT
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	add_child(tex_rect)

	# Title
	var title := Label.new()
	title.text = "UN DIA MAS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1.0))
	title.position = Vector2(0, 60)
	title.size = Vector2(get_viewport().get_visible_rect().size.x, 60)
	add_child(title)

	# Button container
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	vbox.anchors_preset = Control.PRESET_CENTER
	vbox.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 280, 180)
	vbox.custom_minimum_size = Vector2(240, 0)
	add_child(vbox)

	# --- Character selection (right side) ---
	var char_panel := VBoxContainer.new()
	char_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	char_panel.add_theme_constant_override("separation", 8)
	char_panel.position = Vector2(get_viewport().get_visible_rect().size.x - 360, 120)
	char_panel.custom_minimum_size = Vector2(300, 0)
	add_child(char_panel)

	var char_title := Label.new()
	char_title.text = "PERSONAJE"
	char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_title.add_theme_font_size_override("font_size", 22)
	char_title.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	char_panel.add_child(char_title)

	_char_name_label = Label.new()
	_char_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_name_label.add_theme_font_size_override("font_size", 18)
	char_panel.add_child(_char_name_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(300, 400)
	viewport_container.stretch = false
	char_panel.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(300, 400)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport_container.add_child(viewport)

	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.25)
	world_env.environment = env
	viewport.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.position = Vector3(2.0, 3.0, 2.0)
	light.look_at_from_position(light.position, Vector3.ZERO)
	viewport.add_child(light)

	_char_preview_cam = Camera3D.new()
	_char_preview_cam.position = Vector3(0.0, 1.0, 3.5)
	_char_preview_cam.fov = 35.0
	viewport.add_child(_char_preview_cam)

	_char_preview_anchor = Node3D.new()
	_char_preview_anchor.name = "PreviewAnchor"
	viewport.add_child(_char_preview_anchor)

	var nav_hbox := HBoxContainer.new()
	char_panel.add_child(nav_hbox)

	var prev_btn := Button.new()
	prev_btn.text = "< Anterior"
	prev_btn.custom_minimum_size = Vector2(140, 36)
	prev_btn.pressed.connect(_on_char_prev)
	nav_hbox.add_child(prev_btn)

	var next_btn := Button.new()
	next_btn.text = "Siguiente >"
	next_btn.custom_minimum_size = Vector2(140, 36)
	next_btn.pressed.connect(_on_char_next)
	nav_hbox.add_child(next_btn)

	_update_char_view()

	# --- Main buttons (left side) ---
	var btn_single := Button.new()
	btn_single.text = "Un jugador"
	btn_single.custom_minimum_size = Vector2(240, 44)
	btn_single.add_theme_font_size_override("font_size", 18)
	btn_single.pressed.connect(_on_single_player)
	vbox.add_child(btn_single)

	var btn_join := Button.new()
	btn_join.text = "Conectar por IP"
	btn_join.custom_minimum_size = Vector2(240, 44)
	btn_join.add_theme_font_size_override("font_size", 18)
	btn_join.pressed.connect(_on_show_join)
	vbox.add_child(btn_join)

	# IP input (hidden initially)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP del host (ej: 192.168.1.100)"
	_ip_edit.text = _load_saved_ip()
	_ip_edit.custom_minimum_size = Vector2(240, 36)
	_ip_edit.visible = false
	_ip_edit.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_ip_edit)

	var btn_connect := Button.new()
	btn_connect.text = "Conectar"
	btn_connect.custom_minimum_size = Vector2(240, 36)
	btn_connect.add_theme_font_size_override("font_size", 16)
	btn_connect.visible = false
	btn_connect.pressed.connect(_on_join)
	vbox.add_child(btn_connect)
	_btn_connect = btn_connect

	# Status label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 16)
	_status_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.4))
	_status_label.custom_minimum_size = Vector2(240, 24)
	vbox.add_child(_status_label)

func _process(_delta: float) -> void:
	if _started:
		return
	# Passive: listen for broadcast from server
	if _discovery != null:
		var count := _discovery.get_available_packet_count()
		while count > 0:
			var packet := _discovery.get_packet()
			var msg := packet.get_string_from_utf8()
			if msg.begins_with("LASTDAY_SERVER:"):
				var ip_list_str := msg.substr("LASTDAY_SERVER:".length())
				if not ip_list_str.is_empty():
					var ip_list := ip_list_str.split(",")
					if _discovered_ips.is_empty():
						_discovered_ips = ip_list
						if _ip_edit != null and not _discovered_ips.is_empty():
							_ip_edit.text = str(_discovered_ips[0])
						if _status_label != null:
							_status_label.text = "Servidor encontrado: %s" % str(_discovered_ips[0])
						pass # print("[DISCOVERY] Servidor encontrado: %s" % str(_discovered_ips))
			count -= 1
	# Active scan fallback: probe IPs on local subnet if no server found yet
	if _discovered_ips.is_empty() and not _scanning:
		_scan_timer += _delta
		if _scan_timer >= 3.0:
			_scan_timer = 0.0
			_start_active_scan()
	if _scanning:
		_process_scan(_delta)

func _start_active_scan() -> void:
	_scanning = true
	_scan_index = 1
	_scan_probe = PacketPeerUDP.new()
	_scan_probe.bind(0)
	_scan_subnet = _get_local_subnet_prefix()
	pass # print("[DISCOVERY] Iniciando scan activo de red local (%s.x)..." % _scan_subnet)

func _get_local_subnet_prefix() -> String:
	for addr in IP.get_local_addresses():
		if addr.begins_with("127.") or addr.find(":") != -1:
			continue
		var parts := addr.split(".")
		if parts.size() == 4:
			return "%s.%s.%s" % [parts[0], parts[1], parts[2]]
	return "192.168.0"

func _process_scan(_delta: float) -> void:
	if not _scanning or _scan_probe == null:
		return
	# Send a few probes per frame
	for _i in range(5):
		if _scan_index > 254:
			_scanning = false
			if _scan_probe != null:
				_scan_probe.close()
				_scan_probe = null
			if _discovered_ips.is_empty():
				pass # print("[DISCOVERY] Scan completado, servidor no encontrado")
			return
		var ip := "%s.%d" % [_scan_subnet, _scan_index]
		_scan_probe.set_dest_address(ip, DISCOVERY_PORT)
		_scan_probe.put_packet("LASTDAY_PROBE".to_utf8_buffer())
		_scan_index += 1
	# Check for responses
	var count := _scan_probe.get_available_packet_count()
	while count > 0:
		var packet := _scan_probe.get_packet()
		var msg := packet.get_string_from_utf8()
		if msg.begins_with("LASTDAY_SERVER:"):
			var ip_list_str := msg.substr("LASTDAY_SERVER:".length())
			if not ip_list_str.is_empty():
				var ip_list := ip_list_str.split(",")
				if _discovered_ips.is_empty():
					_discovered_ips = ip_list
					if _ip_edit != null and not _discovered_ips.is_empty():
						_ip_edit.text = str(_discovered_ips[0])
					if _status_label != null:
						_status_label.text = "Servidor encontrado: %s" % str(_discovered_ips[0])
					pass # print("[DISCOVERY] Servidor encontrado via scan: %s" % str(_discovered_ips))
				_scanning = false
				if _scan_probe != null:
					_scan_probe.close()
					_scan_probe = null
				return
		count -= 1

func _exit_tree() -> void:
	if _discovery != null:
		_discovery.close()
		_discovery = null
	if _scan_probe != null:
		_scan_probe.close()
		_scan_probe = null

func _on_single_player() -> void:
	if _started:
		return
	_apply_char_selection()
	_mode = "single"
	_start_game()

func _on_host() -> void:
	if _started:
		return
	_apply_char_selection()
	_net = get_node("/root/NetworkManager")
	if _net.host_game():
		_status_label.text = "Servidor iniciado en puerto %d" % NetworkManagerScript.PORT
		_mode = "host"
		# Give a moment for the server to be ready
		get_tree().create_timer(0.5).timeout.connect(_start_game)
	else:
		_status_label.text = "Error al crear servidor"

func _on_show_join() -> void:
	_ip_edit.visible = true
	_btn_connect.visible = true
	_ip_edit.grab_focus()

func _on_join() -> void:
	if _started:
		return
	var ip := _ip_edit.text.strip_edges()
	if ip.is_empty():
		_status_label.text = "Introduce una IP"
		return
	_save_ip(ip)
	_apply_char_selection()
	_net = get_node("/root/NetworkManager")
	_net.connection_succeeded.connect(_on_net_connected)
	_net.connection_failed.connect(_on_net_failed)
	if _net.join_game(ip):
		_status_label.text = "Conectando a %s..." % ip
		_mode = "join"
	else:
		_status_label.text = "Error al conectar"

func _save_ip(ip: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("network", "last_ip", ip)
	cfg.save("user://last_ip.cfg")

func _load_saved_ip() -> String:
	var cfg := ConfigFile.new()
	if cfg.load("user://last_ip.cfg") == OK:
		var saved: String = cfg.get_value("network", "last_ip", "")
		if not saved.is_empty():
			return saved
	return ""

func _on_net_connected() -> void:
	_status_label.text = "Conectado!"
	get_tree().create_timer(0.3).timeout.connect(_start_game)

func _on_net_failed() -> void:
	_status_label.text = "Fallo de conexion"
	_net = null

func _start_game() -> void:
	if _started:
		return
	_started = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _apply_char_selection() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.select_character(_char_index)

func _on_char_next() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var chars: Array = gs.get_available_characters()
	if chars.is_empty():
		return
	_char_index = (_char_index + 1) % chars.size()
	_update_char_view()

func _on_char_prev() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var chars: Array = gs.get_available_characters()
	if chars.is_empty():
		return
	_char_index = (_char_index - 1 + chars.size()) % chars.size()
	_update_char_view()

func _update_char_view() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs == null:
		return
	var chars: Array = gs.get_available_characters()
	if chars.is_empty():
		if _char_name_label != null:
			_char_name_label.text = "No hay personajes"
		return
	_char_index = clampi(_char_index, 0, chars.size() - 1)
	var sel: Dictionary = chars[_char_index]
	if _char_name_label != null:
		_char_name_label.text = String(sel.get("name", "?"))
	if _char_preview_anchor == null:
		return
	for child in _char_preview_anchor.get_children():
		child.queue_free()
	var model_path := String(sel.get("model", ""))
	if model_path.is_empty():
		return
	var packed := load(model_path)
	if packed is PackedScene:
		var instance := (packed as PackedScene).instantiate()
		if instance is Node3D:
			var model := instance as Node3D
			model.position = Vector3.ZERO
			model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			model.scale = Vector3.ONE
			_char_preview_anchor.add_child(model)
			_fit_char_preview(model)

func _fit_char_preview(model: Node3D) -> void:
	await get_tree().process_frame
	if not is_instance_valid(model):
		return
	var meshes: Array = []
	_collect_meshes(model, meshes)
	var min_y := 999999.0
	var max_y := -999999.0
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		var mesh: MeshInstance3D = mi as MeshInstance3D
		var aabb: AABB = mesh.get_aabb()
		var world_aabb: AABB = mesh.global_transform * aabb
		min_y = min(min_y, world_aabb.position.y)
		max_y = max(max_y, world_aabb.end.y)
	if min_y < 999999.0 and max_y > -999999.0:
		var height := max_y - min_y
		if height > 0.01:
			var s := 2.0 / height
			model.scale = Vector3.ONE * s
			await get_tree().process_frame
			if not is_instance_valid(model):
				return
			min_y = 999999.0
			max_y = -999999.0
			for mi2 in meshes:
				if not is_instance_valid(mi2):
					continue
				var mesh2: MeshInstance3D = mi2 as MeshInstance3D
				var aabb2: AABB = mesh2.get_aabb()
				var world_aabb2: AABB = mesh2.global_transform * aabb2
				min_y = min(min_y, world_aabb2.position.y)
				max_y = max(max_y, world_aabb2.end.y)
			if min_y < 999999.0:
				model.position.y = -min_y
	if _char_preview_cam != null:
		_char_preview_cam.look_at_from_position(_char_preview_cam.position, Vector3(0.0, 1.0, 0.0))

func _collect_meshes(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for c in root.get_children():
		_collect_meshes(c, result)
