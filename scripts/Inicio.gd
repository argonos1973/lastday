extends Control

const NetworkManagerScript = preload("res://scripts/NetworkManager.gd")
const SERVER_PUBLIC_IP := "89.6.96.200"

var _started: bool = false
var _mode: String = ""  # "single", "host", "join"
var _net = null
var _ip_edit: LineEdit = null
var _btn_connect: Button = null
var _status_label: Label = null

func _ready() -> void:
	# Dedicated server: skip UI entirely, load the world immediately
	var net_check = get_node_or_null("/root/NetworkManager")
	if net_check != null and net_check.is_dedicated_server:
		get_tree().call_deferred("change_scene_to_file", "res://scenes/Main.tscn")
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

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
	vbox.position = Vector2(get_viewport().get_visible_rect().size.x * 0.5 - 120, 180)
	vbox.custom_minimum_size = Vector2(240, 0)
	add_child(vbox)

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

func _on_single_player() -> void:
	if _started:
		return
	_mode = "single"
	_start_game()

func _on_host() -> void:
	if _started:
		return
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
		var saved := cfg.get_value("network", "last_ip", "")
		if not saved.is_empty():
			return saved
	return SERVER_PUBLIC_IP

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
