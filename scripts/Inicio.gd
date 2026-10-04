extends Control

const NetworkManagerScript = preload("res://scripts/NetworkManager.gd")
const SaveIntegration = preload("res://scripts/InicioSaveIntegration.gd")
const DISCOVERY_PORT := 5006

var _started: bool = false
var _mode: String = ""  # "single", "host", "join"
var _net = null
var _ip_edit: LineEdit = null
var _btn_connect: Button = null
var _rejected := false
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
var _char_title_label: Label = null
var _char_preview_anchor: Node3D = null
var _char_preview_cam: Camera3D = null
var _btn_prev: Button = null
var _btn_next: Button = null
var _btn_enter: Button = null
var _name_panel: PanelContainer = null
var _name_edit: LineEdit = null
var _name_request_pending := false
# El servidor reivindico un personaje vivo: el selector queda bloqueado sobre
# la tarjeta saved_server hasta entrar. Solo se libera en partida nueva o
# tras morir (cuando el servidor pide nombre).
var _mp_locked := false
# En un join las tarjetas guardadas (partida local y la del servidor) no son
# elegibles: un personaje nuevo nace de las tarjetas base — el reclaim fija
# saved_server por su cuenta. Se guarda la tarjeta previa para restaurarla
# si la conexion falla o se cancela.
var _prejoin_card_id := ""

# Los args de linea de comandos persisten durante todo el proceso. Este flag
# evita que volver al menu (p.ej. con Shift+Q) rearranque el juego solo.
static var _auto_launch_consumed := false

const REMY_PREVIEW_SCENE := "res://assets/characters/Remy.glb"
const SAVED_PREVIEW_SCENE := "res://assets/characters/adapted/player_with_clothes.glb"
var CHAR_CONFIGS := [
	{"id": "remy", "name": "Remy", "top": Color(0.3, 0.4, 0.6), "bottom": Color(0.15, 0.12, 0.1), "shoes": Color(0.6, 0.5, 0.2), "hair": Color(0.35, 0.22, 0.12), "skin": Color(0.85, 0.72, 0.58)},
	{"id": "laura", "name": "Luis", "top": Color(0.6, 0.2, 0.3), "bottom": Color(0.1, 0.15, 0.25), "shoes": Color(0.2, 0.2, 0.22), "hair": Color(0.08, 0.06, 0.04), "skin": Color(0.78, 0.65, 0.52)},
	{"id": "marc", "name": "Marc", "top": Color(0.2, 0.5, 0.3), "bottom": Color(0.35, 0.3, 0.15), "shoes": Color(0.5, 0.25, 0.15), "hair": Color(0.75, 0.6, 0.3), "skin": Color(0.7, 0.58, 0.45)},
	{"id": "elena", "name": "Edu", "top": Color(0.5, 0.45, 0.2), "bottom": Color(0.2, 0.2, 0.5), "shoes": Color(0.35, 0.15, 0.1), "hair": Color(0.65, 0.25, 0.1), "skin": Color(0.82, 0.68, 0.55)},
	{"id": "soldado", "name": "Soldado", "top": "camo", "bottom": "camo", "shoes": Color(0.15, 0.12, 0.08), "hair": Color(0.05, 0.04, 0.03), "skin": Color(0.75, 0.62, 0.48)},
	{"id": "dris", "name": "Dris", "top": Color(0.8, 0.7, 0.6), "bottom": Color(0.3, 0.3, 0.35), "shoes": Color(0.1, 0.1, 0.12), "hair": Color(0.02, 0.02, 0.02), "skin": Color(0.25, 0.18, 0.12)},
]

func _ready() -> void:
	# Dedicated server: skip UI entirely, load the world immediately
	var net_check = get_node_or_null("/root/NetworkManager")
	if net_check != null and net_check.is_dedicated_server:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")
		return
	SaveIntegration.maybe_insert_saved_character(self)
	var args := OS.get_cmdline_user_args()
	if not _auto_launch_consumed and args.has("--auto-single"):
		_auto_launch_consumed = true
		# Auto-start single player after a short delay so UI is ready
		get_tree().create_timer(1.0).timeout.connect(_on_single_player)
		return
	if not _auto_launch_consumed and args.has("--cinematic"):
		_auto_launch_consumed = true
		get_tree().create_timer(1.0).timeout.connect(_on_single_player)
		return
	if not _auto_launch_consumed and args.size() >= 2 and args[0] == "--client":
		_auto_launch_consumed = true
		var ip := args[1]
		_net = get_node("/root/NetworkManager")
		_net.connection_succeeded.connect(_on_net_connected)
		_net.connection_failed.connect(_on_net_failed)
		_net.auth_rejected.connect(_on_auth_rejected)
		_net.all_players_ready.connect(_on_net_ready)
		# Cliente de linea de comandos (debug): responde el nombre solo.
		var cli_name := "Jugador"
		var ni := args.find("--name")
		if ni >= 0 and ni + 1 < args.size():
			cli_name = args[ni + 1]
			_net.pending_player_name = cli_name
		_net.player_name_required.connect(func():
			_net.submit_player_name.rpc_id(1, cli_name))
		var pw := String(args[2]) if args.size() >= 3 else ""
		if _net.join_game(ip, pw):
			pass # print("[CLIENT] Conectando a %s..." % ip)
			_mode = "join"
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

	var screen_w := get_viewport().get_visible_rect().size.x
	var screen_h := get_viewport().get_visible_rect().size.y

	# Background color (dark)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.03, 0.05)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Load inicio.png
	var tex_rect := TextureRect.new()
	var loaded := false
	if ResourceLoader.exists("res://assets/textures/inicio.png"):
		var tex = load("res://assets/textures/inicio.png")
		if tex is Texture2D:
			tex_rect.texture = tex as Texture2D
			loaded = true
	if not loaded:
		var abs_path := ProjectSettings.globalize_path("res://assets/textures/inicio.png")
		var img := Image.load_from_file(abs_path)
		if img != null:
			tex_rect.texture = ImageTexture.create_from_image(img)
			loaded = true
	if not loaded:
		var img2 := Image.new()
		var err := img2.load_png_from_buffer(FileAccess.get_file_as_bytes("res://assets/textures/inicio.png"))
		if err == OK:
			tex_rect.texture = ImageTexture.create_from_image(img2)
			loaded = true
	tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.anchors_preset = Control.PRESET_FULL_RECT
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	add_child(tex_rect)

	# --- Left panel: Main menu ---
	var left_panel := PanelContainer.new()
	var left_panel_w := 280
	var char_panel_w := 340
	var total_w := left_panel_w + char_panel_w + 40
	left_panel.position = Vector2(screen_w * 0.5 - total_w * 0.5, screen_h - 440)
	left_panel.custom_minimum_size = Vector2(left_panel_w, 0)
	var left_bg := StyleBoxFlat.new()
	left_bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	left_bg.border_width_left = 2
	left_bg.border_width_right = 2
	left_bg.border_width_top = 2
	left_bg.border_width_bottom = 2
	left_bg.border_color = Color(0.2, 0.2, 0.3, 0.8)
	left_bg.corner_radius_top_left = 12
	left_bg.corner_radius_top_right = 12
	left_bg.corner_radius_bottom_left = 12
	left_bg.corner_radius_bottom_right = 12
	left_bg.content_margin_left = 20
	left_bg.content_margin_right = 20
	left_bg.content_margin_top = 20
	left_bg.content_margin_bottom = 20
	left_panel.add_theme_stylebox_override("panel", left_bg)
	add_child(left_panel)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	left_panel.add_child(vbox)

	var menu_title := Label.new()
	menu_title.text = "MENU PRINCIPAL"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 20)
	menu_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	vbox.add_child(menu_title)

	var sep1 := HSeparator.new()
	sep1.add_theme_constant_override("separation", 8)
	vbox.add_child(sep1)

	# --- Main buttons ---
	var btn_single := Button.new()
	btn_single.text = "  Un jugador"
	btn_single.custom_minimum_size = Vector2(240, 48)
	btn_single.add_theme_font_size_override("font_size", 18)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
	btn_style.border_color = Color(0.3, 0.4, 0.5)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.corner_radius_top_left = 8
	btn_style.corner_radius_top_right = 8
	btn_style.corner_radius_bottom_left = 8
	btn_style.corner_radius_bottom_right = 8
	btn_style.content_margin_left = 16
	btn_style.content_margin_right = 16
	btn_style.content_margin_top = 8
	btn_style.content_margin_bottom = 8
	btn_single.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.2, 0.3, 0.45, 1.0)
	btn_single.add_theme_stylebox_override("hover", btn_hover)
	var btn_pressed := btn_style.duplicate() as StyleBoxFlat
	btn_pressed.bg_color = Color(0.1, 0.15, 0.25, 1.0)
	btn_single.add_theme_stylebox_override("pressed", btn_pressed)
	btn_single.pressed.connect(_on_single_player)
	vbox.add_child(btn_single)

	var btn_join := Button.new()
	btn_join.text = "  Conectar por IP"
	btn_join.custom_minimum_size = Vector2(240, 48)
	btn_join.add_theme_font_size_override("font_size", 18)
	btn_join.add_theme_stylebox_override("normal", btn_style)
	btn_join.add_theme_stylebox_override("hover", btn_hover)
	btn_join.add_theme_stylebox_override("pressed", btn_pressed)
	btn_join.pressed.connect(_on_show_join)
	vbox.add_child(btn_join)

	var btn_official := Button.new()
	btn_official.text = "  Servidor oficial"
	btn_official.custom_minimum_size = Vector2(240, 48)
	btn_official.add_theme_font_size_override("font_size", 18)
	btn_official.add_theme_stylebox_override("normal", btn_style)
	btn_official.add_theme_stylebox_override("hover", btn_hover)
	btn_official.add_theme_stylebox_override("pressed", btn_pressed)
	btn_official.pressed.connect(_on_join_official)
	vbox.add_child(btn_official)

	# IP input (hidden initially)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP del host o wss://servidor"
	_ip_edit.text = _load_saved_ip()
	_ip_edit.custom_minimum_size = Vector2(240, 38)
	_ip_edit.visible = false
	_ip_edit.add_theme_font_size_override("font_size", 16)
	var ip_style := StyleBoxFlat.new()
	ip_style.bg_color = Color(0.05, 0.05, 0.08, 0.9)
	ip_style.border_color = Color(0.3, 0.3, 0.4)
	ip_style.border_width_left = 1
	ip_style.border_width_right = 1
	ip_style.border_width_top = 1
	ip_style.border_width_bottom = 1
	ip_style.corner_radius_top_left = 6
	ip_style.corner_radius_top_right = 6
	ip_style.corner_radius_bottom_left = 6
	ip_style.corner_radius_bottom_right = 6
	ip_style.content_margin_left = 10
	ip_style.content_margin_right = 10
	_ip_edit.add_theme_stylebox_override("normal", ip_style)
	vbox.add_child(_ip_edit)

	var btn_connect := Button.new()
	btn_connect.text = "  Conectar"
	btn_connect.custom_minimum_size = Vector2(240, 40)
	btn_connect.add_theme_font_size_override("font_size", 16)
	btn_connect.add_theme_stylebox_override("normal", btn_style)
	btn_connect.add_theme_stylebox_override("hover", btn_hover)
	btn_connect.add_theme_stylebox_override("pressed", btn_pressed)
	btn_connect.visible = false
	btn_connect.pressed.connect(_on_join)
	vbox.add_child(btn_connect)
	_btn_connect = btn_connect

	# Status label
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 15)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.3))
	_status_label.custom_minimum_size = Vector2(240, 24)
	vbox.add_child(_status_label)

	# Boton "Entrar" para el personaje bloqueado del servidor: aparece solo
	# cuando el servidor reclama un personaje vivo tras conectar.
	_btn_enter = Button.new()
	_btn_enter.text = "  Entrar"
	_btn_enter.custom_minimum_size = Vector2(240, 44)
	_btn_enter.add_theme_font_size_override("font_size", 17)
	_btn_enter.add_theme_stylebox_override("normal", btn_style)
	_btn_enter.add_theme_stylebox_override("hover", btn_hover)
	_btn_enter.add_theme_stylebox_override("pressed", btn_pressed)
	_btn_enter.visible = false
	_btn_enter.pressed.connect(_on_enter_locked)
	vbox.add_child(_btn_enter)

	# --- Right panel: Character selection ---
	var char_panel := PanelContainer.new()
	char_panel.position = Vector2(screen_w * 0.5 - total_w * 0.5 + left_panel_w + 40, screen_h - 440)
	char_panel.custom_minimum_size = Vector2(char_panel_w, 0)
	var char_bg := StyleBoxFlat.new()
	char_bg.bg_color = Color(0.08, 0.08, 0.12, 0.85)
	char_bg.border_width_left = 2
	char_bg.border_width_right = 2
	char_bg.border_width_top = 2
	char_bg.border_width_bottom = 2
	char_bg.border_color = Color(0.2, 0.2, 0.3, 0.8)
	char_bg.corner_radius_top_left = 12
	char_bg.corner_radius_top_right = 12
	char_bg.corner_radius_bottom_left = 12
	char_bg.corner_radius_bottom_right = 12
	char_bg.content_margin_left = 20
	char_bg.content_margin_right = 20
	char_bg.content_margin_top = 16
	char_bg.content_margin_bottom = 16
	char_panel.add_theme_stylebox_override("panel", char_bg)
	add_child(char_panel)

	var char_vbox := VBoxContainer.new()
	char_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	char_vbox.add_theme_constant_override("separation", 8)
	char_panel.add_child(char_vbox)

	var char_title := Label.new()
	char_title.text = "SELECCIONA PERSONAJE"
	char_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	char_title.add_theme_font_size_override("font_size", 20)
	char_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
	char_vbox.add_child(char_title)
	_char_title_label = char_title

	_char_name_label = Label.new()
	_char_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_name_label.add_theme_font_size_override("font_size", 22)
	_char_name_label.add_theme_color_override("font_color", Color(1, 1, 1))
	char_vbox.add_child(_char_name_label)

	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(220, 220)
	viewport_container.stretch = false
	viewport_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	char_vbox.add_child(viewport_container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(220, 220)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = true
	viewport_container.add_child(viewport)

	var light := DirectionalLight3D.new()
	light.position = Vector3(2.0, 3.0, 2.0)
	light.light_energy = 1.2
	light.look_at_from_position(light.position, Vector3.ZERO)
	viewport.add_child(light)

	var fill_light := DirectionalLight3D.new()
	fill_light.position = Vector3(-2.0, 2.0, -1.0)
	fill_light.light_energy = 0.4
	fill_light.look_at_from_position(fill_light.position, Vector3.ZERO)
	viewport.add_child(fill_light)

	_char_preview_cam = Camera3D.new()
	_char_preview_cam.position = Vector3(0.0, 0.0, 2.5)
	_char_preview_cam.fov = 35.0
	viewport.add_child(_char_preview_cam)

	_char_preview_anchor = Node3D.new()
	_char_preview_anchor.name = "PreviewAnchor"
	viewport.add_child(_char_preview_anchor)

	var nav_hbox := HBoxContainer.new()
	nav_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_hbox.add_theme_constant_override("separation", 12)
	char_vbox.add_child(nav_hbox)

	var prev_btn := Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(50, 40)
	prev_btn.add_theme_font_size_override("font_size", 20)
	prev_btn.add_theme_stylebox_override("normal", btn_style)
	prev_btn.add_theme_stylebox_override("hover", btn_hover)
	prev_btn.add_theme_stylebox_override("pressed", btn_pressed)
	prev_btn.pressed.connect(_on_char_prev)
	nav_hbox.add_child(prev_btn)
	_btn_prev = prev_btn

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(50, 40)
	next_btn.add_theme_font_size_override("font_size", 20)
	next_btn.add_theme_stylebox_override("normal", btn_style)
	next_btn.add_theme_stylebox_override("hover", btn_hover)
	next_btn.add_theme_stylebox_override("pressed", btn_pressed)
	next_btn.pressed.connect(_on_char_next)
	nav_hbox.add_child(next_btn)
	_btn_next = next_btn

	_update_char_view()

func _process(_delta: float) -> void:
	if _started:
		return
	# Rotate preview character
	if _char_preview_anchor != null and _char_preview_anchor.get_child_count() > 0:
		var model := _char_preview_anchor.get_child(0) as Node3D
		if model != null:
			model.rotation_degrees.y += 30.0 * _delta
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
	# Un jugador: seleccion libre — cualquier bloqueo de un join previo se
	# quita y se restaura la tarjeta que el jugador tenia elegida.
	_set_picker_locked(false)
	_mode = "single"
	_exit_join_pick()
	_apply_char_selection()
	_start_game()

func _on_host() -> void:
	if _started:
		return
	_exit_join_pick()
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

func _on_join_official() -> void:
	if _started:
		return
	_begin_join(NetworkManagerScript.OFFICIAL_SERVER_URL)

func _on_join() -> void:
	if _started:
		return
	var ip := _ip_edit.text.strip_edges()
	if ip.is_empty():
		_status_label.text = "Introduce una IP"
		return
	_save_ip(ip)
	_begin_join(ip)

func _begin_join(target: String) -> void:
	# La tarjeta elegida no se aplica todavia: si el servidor reclama un
	# personaje vivo, la seleccion queda bloqueada a ese personaje; si pide
	# nombre (personaje nuevo o muerto) se aplica la tarjeta elegida entonces.
	_net = get_node("/root/NetworkManager")
	_net.connection_succeeded.connect(_on_net_connected)
	_net.connection_failed.connect(_on_net_failed)
	_net.auth_rejected.connect(_on_auth_rejected)
	_net.all_players_ready.connect(_on_net_ready)
	_net.player_name_required.connect(_on_player_name_required)
	_net.server_character_locked.connect(_on_server_character_locked)
	_name_request_pending = false
	_set_picker_locked(false)
	_rejected = false
	var pw := NetworkManagerScript.OFFICIAL_SERVER_PASSWORD if target == NetworkManagerScript.OFFICIAL_SERVER_URL else ""
	if _net.join_game(target, pw):
		_status_label.text = "Conectando al servidor oficial..." if target == NetworkManagerScript.OFFICIAL_SERVER_URL else "Conectando..."
		_mode = "join"
		_prejoin_card_id = str(CHAR_CONFIGS[_char_index].get("id", "")) if _char_index >= 0 and _char_index < CHAR_CONFIGS.size() else ""
		_clamp_to_selectable_card()
	else:
		_status_label.text = "Error al conectar"

# El servidor pide el nombre solo cuando la conexion abre un personaje nuevo:
# con un personaje vivo en el registro del servidor se entra directo con el
# nombre guardado — solo se vuelve a preguntar al morir o reiniciar.
func _on_player_name_required() -> void:
	_name_request_pending = true
	if not _started:
		_prompt_player_name()

func _prompt_player_name() -> void:
	if _name_panel == null:
		_name_panel = PanelContainer.new()
		var pw := 340.0
		var screen_w := get_viewport().get_visible_rect().size.x
		var screen_h := get_viewport().get_visible_rect().size.y
		_name_panel.position = Vector2(screen_w * 0.5 - pw * 0.5, screen_h * 0.5 - 90)
		_name_panel.custom_minimum_size = Vector2(pw, 0)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0.08, 0.08, 0.12, 0.95)
		bg.border_width_left = 2
		bg.border_width_right = 2
		bg.border_width_top = 2
		bg.border_width_bottom = 2
		bg.border_color = Color(0.2, 0.2, 0.3, 0.9)
		bg.corner_radius_top_left = 12
		bg.corner_radius_top_right = 12
		bg.corner_radius_bottom_left = 12
		bg.corner_radius_bottom_right = 12
		bg.content_margin_left = 20
		bg.content_margin_right = 20
		bg.content_margin_top = 18
		bg.content_margin_bottom = 18
		_name_panel.add_theme_stylebox_override("panel", bg)
		add_child(_name_panel)
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 12)
		_name_panel.add_child(vbox)
		var title := Label.new()
		title.text = "NOMBRE DE JUGADOR"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.5))
		vbox.add_child(title)
		_name_edit = LineEdit.new()
		_name_edit.placeholder_text = "Tu nombre..."
		_name_edit.max_length = 24
		_name_edit.custom_minimum_size = Vector2(280, 38)
		_name_edit.add_theme_font_size_override("font_size", 16)
		var edit_style := StyleBoxFlat.new()
		edit_style.bg_color = Color(0.05, 0.05, 0.08, 0.9)
		edit_style.border_color = Color(0.3, 0.3, 0.4)
		edit_style.border_width_left = 1
		edit_style.border_width_right = 1
		edit_style.border_width_top = 1
		edit_style.border_width_bottom = 1
		edit_style.corner_radius_top_left = 6
		edit_style.corner_radius_top_right = 6
		edit_style.corner_radius_bottom_left = 6
		edit_style.corner_radius_bottom_right = 6
		edit_style.content_margin_left = 10
		edit_style.content_margin_right = 10
		_name_edit.add_theme_stylebox_override("normal", edit_style)
		_name_edit.text_submitted.connect(func(_t): _on_name_confirmed())
		vbox.add_child(_name_edit)
		var btn_row := HBoxContainer.new()
		btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_row.add_theme_constant_override("separation", 12)
		vbox.add_child(btn_row)
		var btn_style := StyleBoxFlat.new()
		btn_style.bg_color = Color(0.15, 0.2, 0.3, 0.9)
		btn_style.border_color = Color(0.3, 0.4, 0.5)
		btn_style.border_width_left = 1
		btn_style.border_width_right = 1
		btn_style.border_width_top = 1
		btn_style.border_width_bottom = 1
		btn_style.corner_radius_top_left = 8
		btn_style.corner_radius_top_right = 8
		btn_style.corner_radius_bottom_left = 8
		btn_style.corner_radius_bottom_right = 8
		var btn_go := Button.new()
		btn_go.text = "Entrar"
		btn_go.custom_minimum_size = Vector2(120, 38)
		btn_go.add_theme_font_size_override("font_size", 16)
		btn_go.add_theme_stylebox_override("normal", btn_style)
		btn_go.pressed.connect(_on_name_confirmed)
		btn_row.add_child(btn_go)
		var btn_cancel := Button.new()
		btn_cancel.text = "Cancelar"
		btn_cancel.custom_minimum_size = Vector2(120, 38)
		btn_cancel.add_theme_font_size_override("font_size", 16)
		btn_cancel.add_theme_stylebox_override("normal", btn_style)
		btn_cancel.pressed.connect(func():
			_name_panel.visible = false
			_name_request_pending = false
			if _net != null:
				_net.close_connection()
				_net = null
			_mode = ""
			_exit_join_pick()
			if _status_label != null:
				_status_label.text = "Conexion cancelada")
		btn_row.add_child(btn_cancel)
	# Prefill con el nombre del personaje seleccionado — se puede editar.
	if _char_index >= 0 and _char_index < CHAR_CONFIGS.size():
		_name_edit.text = str(CHAR_CONFIGS[_char_index].get("name", ""))
	_name_panel.visible = true
	_name_edit.grab_focus()
	_name_edit.select_all()

func _on_name_confirmed() -> void:
	var pname := _name_edit.text.strip_edges()
	if pname.is_empty():
		_name_edit.placeholder_text = "Escribe un nombre"
		_name_edit.grab_focus()
		return
	_name_panel.visible = false
	_name_request_pending = false
	# La seleccion local se aplica aqui: para personaje nuevo/muerto vale la
	# tarjeta elegida; en reclaim con placeholder queda la del servidor.
	_apply_char_selection()
	# El nombre tecleado es el nombre del personaje en este servidor.
	var gsess := get_node_or_null("/root/GameSession")
	if gsess != null:
		gsess.set_meta("char_name", pname)
	if _net != null:
		_net.submit_player_name.rpc_id(1, pname)
	if not _started:
		_start_game()

func _on_auth_rejected(reason: String) -> void:
	_rejected = true
	if _status_label != null:
		_status_label.text = "Servidor lleno" if reason == "full" else "Contraseña incorrecta"

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
	if _status_label != null:
		_status_label.text = "Conectado, cargando..."
	# En join el mundo solo arranca tras _sync_player_list (registro aceptado):
	# un rechazo puede tardar ~0.5 s y el guard de _start_game debe fallar.
	if _mode != "join":
		get_tree().create_timer(0.3).timeout.connect(_start_game)

func _on_net_ready() -> void:
	if _mode != "join" or _started:
		return
	if _status_label != null:
		_status_label.text = "Conectado!"
	get_tree().create_timer(0.3).timeout.connect(_maybe_start_game)

func _maybe_start_game() -> void:
	if _started or _mode != "join":
		return
	# Si el servidor pidio nombre (personaje nuevo) el mundo espera al prompt.
	if _name_request_pending:
		_prompt_player_name()
		return
	# Personaje reclamado: el picker ya muestra la tarjeta del servidor; el
	# mundo arranca al pulsar Entrar para que se vea el equipo que lleva.
	if _mp_locked:
		if _btn_enter != null:
			_btn_enter.visible = true
		if _status_label != null:
			_status_label.text = "Tu personaje sigue en el servidor"
		return
	_start_game()

func _on_enter_locked() -> void:
	if _started or not _mp_locked:
		return
	_start_game()

# El servidor reivindico el personaje vivo de este cliente: inserta/actualiza
# la tarjeta saved_server con los datos reales de la partida, salta a ella y
# bloquea las flechas. La apariencia/equipo vienen del servidor, no del save
# local, asi el preview muestra exactamente lo que lleva puesto en juego.
func _on_server_character_locked(payload: Dictionary) -> void:
	_char_index = _upsert_server_card(payload)
	_update_char_view()
	# GameSession debe llevar el personaje del servidor: sync/restores lo usan.
	_apply_char_selection()
	_set_picker_locked(true)
	if _status_label != null and _status_label.text.begins_with("Conect"):
		_status_label.text = "Personaje encontrado en el servidor"
	# Si la lista ya llego antes que este aviso, respeta tambien el Entrar.
	if _mode == "join" and not _started and not _name_request_pending and _btn_enter != null and _net != null and _net.is_connected:
		_btn_enter.visible = true

# Solo colores con alpha>0 cuentan: un registro sin apariencia produce
# Color(0,0,0,0) y pintaria la tarjeta — y el personaje — de negro.
# Server colors with alpha 0 mean "no data" (record never synced appearance) —
# transparent black would paint the character pitch black. Keep the card's
# previous color when valid, else the project default. Never propagate a==0.
static func _payload_color(payload: Dictionary, key: String, existing: Variant, default_color: Color) -> Color:
	var c: Variant = payload.get(key, null)
	if c is Color and c.a > 0.0:
		return c
	if existing is Color and existing.a > 0.0:
		return existing
	return default_color

func _upsert_server_card(payload: Dictionary) -> int:
	var char_name := str(payload.get("char_name", ""))
	if char_name.is_empty() or char_name.begins_with("Jugador_"):
		char_name = "Superviviente"
	# Fallbacks: colores de la tarjeta saved_server existente (ultimo estado
	# conocido local) o los defaults si nunca hubo una.
	var existing := {}
	for c in CHAR_CONFIGS:
		if str(c.get("id", "")) == "saved_server":
			existing = c
			break
	var cfg := {
		"id": "saved_server",
		"name": char_name,
		"top": _payload_color(payload, "top", existing.get("top"), Color(0.5, 0.5, 0.5)),
		"bottom": _payload_color(payload, "bottom", existing.get("bottom"), Color(0.3, 0.3, 0.3)),
		"shoes": _payload_color(payload, "shoes", existing.get("shoes"), Color(0.15, 0.15, 0.15)),
		"hair": _payload_color(payload, "hair", existing.get("hair"), Color(0.2, 0.15, 0.1)),
		"skin": _payload_color(payload, "skin", existing.get("skin"), Color(0.8, 0.7, 0.6)),
		"top_camo": bool(payload.get("top_camo", existing.get("top_camo", false))),
		"bottom_camo": bool(payload.get("bottom_camo", existing.get("bottom_camo", false))),
		"is_saved": true,
		"is_server_save": true,
		"server_pd": {
			"clothing": str(payload.get("equipped_clothing", "")),
			"backpack": str(payload.get("equipped_backpack", "")),
			"held_item": str(payload.get("held_item", "")),
			"inventory": payload.get("inventory", []),
			"extra": {"stats_extra": {"survival_seconds": float(payload.get("survival_seconds", 0.0))}},
		},
	}
	for i in range(CHAR_CONFIGS.size()):
		if str(CHAR_CONFIGS[i].get("id", "")) == "saved_server":
			CHAR_CONFIGS[i] = cfg
			return i
	CHAR_CONFIGS.push_front(cfg)
	return 0

func _set_picker_locked(locked: bool) -> void:
	_mp_locked = locked
	if _btn_prev != null:
		_btn_prev.disabled = locked
	if _btn_next != null:
		_btn_next.disabled = locked
	if _char_title_label != null:
		_char_title_label.text = "PERSONAJE EN SERVIDOR" if locked else "SELECCIONA PERSONAJE"
	if not locked and _btn_enter != null:
		_btn_enter.visible = false

func _on_net_failed() -> void:
	if _status_label != null and not _rejected:
		_status_label.text = "Fallo de conexion"
	_set_picker_locked(false)
	_mode = ""
	_exit_join_pick()
	_net = null

func _start_game() -> void:
	if _started:
		return
	# A join that never connected (dead server or it died during the wait) must
	# not enter the world as if it were single-player — it would load and
	# overwrite savegame.json (open doors, drops) with the local save.
	if _mode == "join" and (_net == null or not _net.is_connected):
		if _status_label != null and not _rejected:
			_status_label.text = "Fallo de conexion"
		return
	_started = true
	# A non-saved character starts a fresh game: drop the old save so it can
	# never be restored over the new run or linger as a stale "Continuar" slot.
	# Cinematic mode only stages a showcase — it must never touch the save.
	var gsess := get_node_or_null("/root/GameSession")
	var sgm := get_node_or_null("/root/SaveGameManager")
	var is_cinematic := OS.get_cmdline_user_args().has("--cinematic")
	if not is_cinematic and gsess != null and sgm != null:
		# The server-save card belongs to multiplayer; picking it for a local run
		# must not wipe the single-player save.
		var cid := String(gsess.selected_character_id)
		# Only a fresh single-player run may drop the local save; joining or
		# hosting a server never touches savegame.json.
		if _mode == "single" and cid != "saved" and cid != "saved_server" and sgm.has_save():
			sgm.delete_save()
		# Hosting with any other character starts a fresh server world.
		if _mode == "host" and cid != "saved_server" and sgm.has_server_save():
			sgm.delete_server_save()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _apply_char_selection() -> void:
	var gs := get_node_or_null("/root/GameState")
	if gs != null:
		gs.select_character(0)
	var gsess := get_node_or_null("/root/GameSession")
	if gsess != null and _char_index >= 0 and _char_index < CHAR_CONFIGS.size():
		var cfg: Dictionary = CHAR_CONFIGS[_char_index]
		gsess.selected_character_id = cfg["id"]
		var top_val: Variant = cfg["top"]
		var bottom_val: Variant = cfg["bottom"]
		if top_val is String and top_val == "camo":
			gsess.selected_top_color = Color(0.2, 0.25, 0.12)
			gsess.set_meta("top_camo", true)
		else:
			gsess.selected_top_color = top_val as Color
			gsess.set_meta("top_camo", false)
		if bottom_val is String and bottom_val == "camo":
			gsess.selected_bottom_color = Color(0.2, 0.25, 0.12)
			gsess.set_meta("bottom_camo", true)
		else:
			gsess.selected_bottom_color = bottom_val as Color
			gsess.set_meta("bottom_camo", false)
		gsess.selected_shoes_color = cfg["shoes"]
		gsess.selected_hair_color = cfg["hair"]
		gsess.selected_skin_color = cfg["skin"]
		gsess.set_meta("char_name", cfg["name"])
		SaveIntegration.apply_saved_camo(gsess, cfg)

# En modo join solo se elige personaje nuevo: las tarjetas guardadas
# ("saved" partida local y "saved_server") no se ofrecen. En cualquier otro
# modo (menu, host, un jugador) todas las tarjetas son elegibles.
func _is_mp_save_card(cfg: Dictionary) -> bool:
	var cid := str(cfg.get("id", ""))
	return cid == "saved" or cid == "saved_server"

func _card_selectable(cfg: Dictionary) -> bool:
	return _mode != "join" or not _is_mp_save_card(cfg)

func _clamp_to_selectable_card() -> void:
	var n := CHAR_CONFIGS.size()
	for i in range(n):
		var idx := (_char_index + i) % n
		if _card_selectable(CHAR_CONFIGS[idx]):
			_char_index = idx
			_update_char_view()
			return

func _restore_prejoin_card() -> void:
	if _prejoin_card_id.is_empty():
		return
	for i in range(CHAR_CONFIGS.size()):
		if str(CHAR_CONFIGS[i].get("id", "")) == _prejoin_card_id:
			_char_index = i
			break
	_prejoin_card_id = ""

func _exit_join_pick() -> void:
	# La tarjeta saved_server solo existe mientras el servidor la tiene
	# reclamada: al salir del join sin entrar se retira para que nunca quede
	# como "partida" seleccionable.
	for i in range(CHAR_CONFIGS.size() - 1, -1, -1):
		if str(CHAR_CONFIGS[i].get("id", "")) == "saved_server":
			CHAR_CONFIGS.remove_at(i)
	_restore_prejoin_card()
	_char_index = clampi(_char_index, 0, CHAR_CONFIGS.size() - 1)
	_update_char_view()

func _on_char_next() -> void:
	if _mp_locked:
		return
	var n := CHAR_CONFIGS.size()
	for _i in range(n):
		_char_index = (_char_index + 1) % n
		if _card_selectable(CHAR_CONFIGS[_char_index]):
			break
	_update_char_view()

func _on_char_prev() -> void:
	if _mp_locked:
		return
	var n := CHAR_CONFIGS.size()
	for _i in range(n):
		_char_index = (_char_index - 1 + n) % n
		if _card_selectable(CHAR_CONFIGS[_char_index]):
			break
	_update_char_view()

func _update_char_view() -> void:
	_char_index = clampi(_char_index, 0, CHAR_CONFIGS.size() - 1)
	var cfg: Dictionary = CHAR_CONFIGS[_char_index]
	if _char_name_label != null:
		_char_name_label.text = String(cfg.get("name", "?"))
	SaveIntegration.update_saved_info(self, cfg)
	if _char_preview_anchor == null:
		return
	for child in _char_preview_anchor.get_children():
		child.queue_free()
	var model_path := REMY_PREVIEW_SCENE
	if cfg.get("is_saved", false):
		model_path = SAVED_PREVIEW_SCENE
	var packed := load(model_path)
	if packed is PackedScene:
		var instance := (packed as PackedScene).instantiate()
		if instance is Node3D:
			var model := instance as Node3D
			model.position = Vector3.ZERO
			model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			model.scale = Vector3.ONE
			_char_preview_anchor.add_child(model)
			if cfg.get("is_saved", false):
				_apply_preview_colors(model, cfg)
				SaveIntegration.apply_saved_equipment_preview(model, cfg)
				_fit_char_preview(model, true)
				_play_preview_animation(model)
			else:
				_apply_preview_colors(model, cfg, true)
				_fit_char_preview(model, false)
				_play_preview_animation(model)

const PREVIEW_IDLE_SCENE := "res://assets/animations/Idle.fbx"
static var _preview_idle_anim: Animation = null
# Rest rotations del esqueleto fuente (Idle.fbx): el rig FBX liga con otros
# ejes que los GLB y las rotaciones absolutas tuerce la pose (cabeza girada).
static var _preview_idle_rest: Dictionary = {}

func _load_preview_idle_animation() -> Animation:
	if _preview_idle_anim != null:
		return _preview_idle_anim
	var packed := load(PREVIEW_IDLE_SCENE)
	if not (packed is PackedScene):
		return null
	var inst := (packed as PackedScene).instantiate()
	var player := _find_animation_player(inst)
	if player == null:
		inst.free()
		return null
	var src_skel := SaveIntegration._find_skeleton(inst)
	if src_skel != null:
		for i in range(src_skel.get_bone_count()):
			_preview_idle_rest[src_skel.get_bone_name(i)] = src_skel.get_bone_rest(i).basis.get_rotation_quaternion()
	var best: Animation = null
	for anim_name in player.get_animation_list():
		var a := player.get_animation(anim_name)
		if a != null and (best == null or a.length > best.length):
			best = a
	if best != null:
		_preview_idle_anim = best
	inst.free()
	return _preview_idle_anim

func _play_preview_animation(model: Node3D) -> void:
	# Idle.fbx del proyecto retargetado al esqueleto del modelo — las rigs del
	# menu son Mixamo como el clip, asi que basta resolver el nombre del hueso.
	var src := _load_preview_idle_animation()
	var skel := SaveIntegration._find_skeleton(model)
	if src != null and skel != null:
		var player := _find_animation_player(model)
		if player == null:
			player = AnimationPlayer.new()
			player.name = "PreviewAnimPlayer"
			model.add_child(player)
			player.root_node = player.get_path_to(model)
		var anim := src.duplicate(true)
		anim.loop_mode = Animation.LOOP_LINEAR
		_retarget_preview_animation(anim, model, player, skel)
		var lib := player.get_animation_library("preview") if player.has_animation_library("preview") else null
		if lib == null:
			lib = AnimationLibrary.new()
			player.add_animation_library("preview", lib)
		if lib.has_animation("idle"):
			lib.remove_animation("idle")
		lib.add_animation("idle", anim)
		player.play("preview/idle")
		return
	var anim_player := _find_animation_player(model)
	if anim_player != null:
		var anims := anim_player.get_animation_list()
		var chosen := ""
		for anim_name in anims:
			if anim_name.find("idle") >= 0 or anim_name.find("Idle") >= 0 or anim_name.find("IDLE") >= 0:
				chosen = anim_name
				break
		if chosen.is_empty() and anims.size() > 0:
			chosen = anims[0]
		if not chosen.is_empty():
			anim_player.play(chosen)

# Reapunta las pistas del clip a la ruta real del esqueleto del modelo y
# descarta posiciones/escalas: player_with_clothes liga en centimetros y Remy
# en metros — solo las rotaciones son seguras entre rigs.
func _retarget_preview_animation(anim: Animation, model: Node, player: AnimationPlayer, skel: Skeleton3D) -> void:
	var anim_root: Node = player.get_node_or_null(player.root_node)
	if anim_root == null:
		anim_root = model
	var skel_path := str(anim_root.get_path_to(skel))
	for t in range(anim.get_track_count() - 1, -1, -1):
		var path_text := str(anim.track_get_path(t))
		var colon := path_text.find(":")
		if colon < 0:
			anim.remove_track(t)
			continue
		var src_bone := path_text.substr(colon + 1)
		var bone := _resolve_preview_bone(skel, src_bone)
		# La toma mixamo_com lleva un gesto de "mirar alrededor" en cuello y
		# cabeza — para el menu el personaje debe mirar al frente siempre.
		if bone.is_empty() or anim.track_get_type(t) != Animation.TYPE_ROTATION_3D or bone.find("Head") >= 0 or bone.find("Neck") >= 0:
			anim.remove_track(t)
			continue
		anim.track_set_path(t, NodePath("%s:%s" % [skel_path, bone]))
		# Compensa el rest pose distinto del rig fuente (misma formula que
		# PlayerController._retarget_rotation_tracks): new = tgt*src^-1*old.
		var src_rest: Quaternion = _preview_idle_rest.get(src_bone, Quaternion.IDENTITY)
		var tgt_idx := skel.find_bone(bone)
		var tgt_rest := skel.get_bone_rest(tgt_idx).basis.get_rotation_quaternion()
		var offset := tgt_rest * src_rest.inverse()
		if offset == Quaternion.IDENTITY:
			continue
		for k in range(anim.track_get_key_count(t)):
			var rot: Quaternion = anim.track_get_key_value(t, k)
			anim.track_set_key_value(t, k, offset * rot)

func _resolve_preview_bone(skel: Skeleton3D, name_in: String) -> String:
	var candidates: Array = [name_in]
	if name_in.begins_with("mixamorig:"):
		candidates.append("mixamorig_" + name_in.substr("mixamorig:".length()))
	elif name_in.begins_with("mixamorig_"):
		candidates.append("mixamorig:" + name_in.substr("mixamorig_".length()))
	var digit_index := name_in.find("mixamorig")
	if digit_index >= 0:
		var after := name_in.substr(digit_index + "mixamorig".length())
		var d_end := 0
		while d_end < after.length() and after[d_end] >= '0' and after[d_end] <= '9':
			d_end += 1
		if d_end > 0 and d_end < after.length() and after[d_end] == '_':
			var bare := after.substr(d_end + 1)
			candidates.append("mixamorig_" + bare)
			candidates.append("mixamorig:" + bare)
	for candidate in candidates:
		if skel.find_bone(candidate) != -1:
			return candidate
	return ""

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var result := _find_animation_player(c)
		if result != null:
			return result
	return null

func _fit_char_preview(model: Node3D, is_saved: bool = false) -> void:
	await get_tree().process_frame
	if not is_instance_valid(model):
		return
	if is_saved:
		_hide_export_helpers(model)
		var smeshes: Array = []
		_collect_meshes(model, smeshes)
		var smin_y := 999999.0
		var smax_y := -999999.0
		for mi2 in smeshes:
			if not is_instance_valid(mi2):
				continue
			var mesh2: MeshInstance3D = mi2 as MeshInstance3D
			if not mesh2.visible:
				continue
			# Skip meshes from gloves source
			if mesh2.get_parent() != null and mesh2.get_parent().get_parent() != null:
				var gp = mesh2.get_parent().get_parent()
				if gp is Node3D and gp.name == "PreviewGlovesSrc":
					continue
			# Skip cloth_hands (gloves mesh reparented to main skeleton)
			if mesh2.name.to_lower() == "cloth_hands":
				continue
			# Skip preview accessories (hat, backpack, knife) — their AABBs
			# are in a different local space and would corrupt the height calc
			if SaveIntegration._is_accessory_mesh(mesh2):
				continue
			# Skip phantom meshes (animation targets with zero scale)
			if mesh2.name.find("default") >= 0:
				continue
			var raw_aabb: AABB = mesh2.get_aabb()
			smin_y = min(smin_y, raw_aabb.position.y)
			smax_y = max(smax_y, raw_aabb.end.y)
		if smin_y < 999999.0 and smax_y > -999999.0:
			var raw_height := smax_y - smin_y
			if raw_height > 0.01:
				var s := 1.9 / raw_height
				model.scale = Vector3.ONE * s
				var mid_y := (smin_y + smax_y) * 0.5
				model.position.y = -mid_y * s
		if _char_preview_cam != null:
			_char_preview_cam.position = Vector3(0.0, 0.0, 3.0)
			_char_preview_cam.look_at_from_position(_char_preview_cam.position, Vector3.ZERO)
		return
	var meshes: Array = []
	_collect_meshes(model, meshes)
	var min_y := 999999.0
	var max_y := -999999.0
	for mi in meshes:
		if not is_instance_valid(mi):
			continue
		var mesh: MeshInstance3D = mi as MeshInstance3D
		if not mesh.visible:
			continue
		var aabb: AABB = mesh.get_aabb()
		var world_aabb: AABB = mesh.global_transform * aabb
		min_y = min(min_y, world_aabb.position.y)
		max_y = max(max_y, world_aabb.end.y)
	if min_y < 999999.0 and max_y > -999999.0:
		var height := max_y - min_y
		if height > 0.01:
			var s := 1.9 / height
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
				if not mesh2.visible:
					continue
				var aabb2: AABB = mesh2.get_aabb()
				var world_aabb2: AABB = mesh2.global_transform * aabb2
				min_y = min(min_y, world_aabb2.position.y)
				max_y = max(max_y, world_aabb2.end.y)
			if min_y < 999999.0:
				var mid_y := (min_y + max_y) * 0.5
				model.position.y = -mid_y
	if _char_preview_cam != null:
		_char_preview_cam.position = Vector3(0.0, 0.0, 3.0)
		_char_preview_cam.look_at_from_position(_char_preview_cam.position, Vector3.ZERO)

func _collect_meshes(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for c in root.get_children():
		_collect_meshes(c, result)

func _hide_export_helpers(root: Node) -> void:
	var nl := root.name.to_lower()
	if nl == "cube" or nl.find("placeholder") >= 0 or nl.find("floor") >= 0:
		if root is Node3D:
			(root as Node3D).visible = false
	for c in root.get_children():
		_hide_export_helpers(c)

func _apply_preview_colors(model: Node3D, cfg: Dictionary, meter_units := false) -> void:
	# Remy.glb binds in metres; player_with_clothes.glb binds in centimetres.
	# The garment grow values are tuned in cm, so meter models get 0.01.
	var us := 0.01 if meter_units else 1.0
	var top_val: Variant = cfg.get("top", Color(0.5, 0.5, 0.5))
	var bottom_val: Variant = cfg.get("bottom", Color(0.3, 0.3, 0.3))
	var shoes_color: Color = cfg.get("shoes", Color(0.15, 0.15, 0.15))
	var hair_color: Color = cfg.get("hair", Color(0.2, 0.15, 0.1))
	var skin_color: Color = cfg.get("skin", Color(0.8, 0.7, 0.6))
	var camo_tex := _make_camo_texture()
	var meshes: Array = []
	_collect_meshes(model, meshes)
	for mi in meshes:
		var mesh_inst := mi as MeshInstance3D
		var name_lower := mesh_inst.name.to_lower()
		var cloth_kind := MaterialFactory.clothing_kind_for_mesh(mesh_inst.name)
		if name_lower.find("hair") < 0 and not cloth_kind.is_empty():
			if name_lower.find("shoes") >= 0:
				mesh_inst.material_override = MaterialFactory.make_clothing_material("shoes", shoes_color, -999.0, us)
			elif name_lower.find("bottoms") >= 0:
				if bottom_val is String and bottom_val == "camo":
					mesh_inst.material_override = _camo_material(camo_tex, cloth_kind, us)
				else:
					mesh_inst.material_override = MaterialFactory.make_clothing_material("bottom", bottom_val as Color, -999.0, us)
			elif name_lower.find("tops") >= 0:
				if top_val is String and top_val == "camo":
					mesh_inst.material_override = _camo_material(camo_tex, cloth_kind, us)
				else:
					mesh_inst.material_override = MaterialFactory.make_clothing_material("top", top_val as Color, -999.0, us)
			elif name_lower.find("cloth_") >= 0:
				mesh_inst.material_override = MaterialFactory.make_clothing_material(cloth_kind, Color(0.05, 0.05, 0.05), -999.0, us)
			else:
				mesh_inst.material_override = MaterialFactory.make_clothing_material(cloth_kind, Color(0.2, 0.25, 0.12), -999.0, us)
			continue
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.8
		if name_lower.find("hair") >= 0:
			mat.albedo_color = hair_color
		elif name_lower.find("desnudo") >= 0 or name_lower.find("body") >= 0 or name_lower.find("skin") >= 0 or name_lower.find("head") >= 0:
			mat.albedo_color = skin_color
		elif name_lower.find("eyes") >= 0:
			mat.albedo_color = Color(0.2, 0.15, 0.1)
		elif name_lower.find("eyelashes") >= 0:
			mat.albedo_color = Color(0.1, 0.05, 0.03)
		else:
			mat.albedo_color = skin_color
		mesh_inst.material_override = mat

func _camo_material(camo_tex: Texture2D, kind: String, unit_scale: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = camo_tex
	mat.albedo_color = Color.WHITE
	mat.roughness = 0.8
	MaterialFactory.cloth_detail(mat, kind if not kind.is_empty() else "denim", unit_scale)
	return mat

func _make_camo_texture() -> Texture2D:
	return MaterialFactory.make_camo_texture()
