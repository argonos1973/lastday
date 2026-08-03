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

const REMY_PREVIEW_SCENE := "res://assets/characters/Remy.glb"
const CHAR_CONFIGS := [
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
	var args := OS.get_cmdline_user_args()
	if args.has("--auto-single"):
		# Auto-start single player after a short delay so UI is ready
		get_tree().create_timer(1.0).timeout.connect(_on_single_player)
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

	# IP input (hidden initially)
	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "IP del host (ej: 192.168.1.100)"
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

	var next_btn := Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(50, 40)
	next_btn.add_theme_font_size_override("font_size", 20)
	next_btn.add_theme_stylebox_override("normal", btn_style)
	next_btn.add_theme_stylebox_override("hover", btn_hover)
	next_btn.add_theme_stylebox_override("pressed", btn_pressed)
	next_btn.pressed.connect(_on_char_next)
	nav_hbox.add_child(next_btn)

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
	if _status_label != null:
		_status_label.text = "Conectado!"
	get_tree().create_timer(0.3).timeout.connect(_start_game)

func _on_net_failed() -> void:
	if _status_label != null:
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

func _on_char_next() -> void:
	_char_index = (_char_index + 1) % CHAR_CONFIGS.size()
	_update_char_view()

func _on_char_prev() -> void:
	_char_index = (_char_index - 1 + CHAR_CONFIGS.size()) % CHAR_CONFIGS.size()
	_update_char_view()

func _update_char_view() -> void:
	_char_index = clampi(_char_index, 0, CHAR_CONFIGS.size() - 1)
	var cfg: Dictionary = CHAR_CONFIGS[_char_index]
	if _char_name_label != null:
		_char_name_label.text = String(cfg.get("name", "?"))
	if _char_preview_anchor == null:
		return
	for child in _char_preview_anchor.get_children():
		child.queue_free()
	var packed := load(REMY_PREVIEW_SCENE)
	if packed is PackedScene:
		var instance := (packed as PackedScene).instantiate()
		if instance is Node3D:
			var model := instance as Node3D
			model.position = Vector3.ZERO
			model.rotation_degrees = Vector3(0.0, 180.0, 0.0)
			model.scale = Vector3.ONE
			_char_preview_anchor.add_child(model)
			_apply_preview_colors(model, cfg)
			_fit_char_preview(model)
			_play_preview_animation(model)

func _play_preview_animation(model: Node3D) -> void:
	var anim_player := _find_animation_player(model)
	if anim_player != null:
		var anims := anim_player.get_animation_list()
		for anim_name in anims:
			if anim_name.find("idle") >= 0 or anim_name.find("Idle") >= 0 or anim_name.find("IDLE") >= 0:
				anim_player.play(anim_name)
				return
		if anims.size() > 0:
			anim_player.play(anims[0])

func _find_animation_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for c in root.get_children():
		var result := _find_animation_player(c)
		if result != null:
			return result
	return null

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

func _apply_preview_colors(model: Node3D, cfg: Dictionary) -> void:
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
		var mat := StandardMaterial3D.new()
		mat.roughness = 0.8
		var name_lower := mesh_inst.name.to_lower()
		if name_lower.find("hair") >= 0:
			mat.albedo_color = hair_color
		elif name_lower.find("shoes") >= 0:
			mat.albedo_color = shoes_color
		elif name_lower.find("bottoms") >= 0:
			if bottom_val is String and bottom_val == "camo":
				mat.albedo_texture = camo_tex
			else:
				mat.albedo_color = bottom_val as Color
		elif name_lower.find("tops") >= 0:
			if top_val is String and top_val == "camo":
				mat.albedo_texture = camo_tex
			else:
				mat.albedo_color = top_val as Color
		elif name_lower.find("body") >= 0 or name_lower.find("skin") >= 0 or name_lower.find("head") >= 0:
			mat.albedo_color = skin_color
		else:
			mat.albedo_color = skin_color
		mesh_inst.material_override = mat

func _make_camo_texture() -> ImageTexture:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var camo_colors := [Color(0.25, 0.3, 0.15), Color(0.15, 0.18, 0.1), Color(0.35, 0.32, 0.18), Color(0.1, 0.12, 0.08)]
	img.fill(camo_colors[0])
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for blob in range(80):
		var cx := rng.randi_range(0, size - 1)
		var cy := rng.randi_range(0, size - 1)
		var radius := rng.randi_range(10, 35)
		var color: Color = camo_colors[rng.randi() % camo_colors.size()]
		for x in range(maxi(0, cx - radius), mini(size, cx + radius)):
			for y in range(maxi(0, cy - radius), mini(size, cy + radius)):
				var dx := x - cx
				var dy := y - cy
				if dx * dx + dy * dy <= radius * radius:
					img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
