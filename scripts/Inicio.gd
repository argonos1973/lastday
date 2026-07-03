extends Control

var _countdown: float = 5.0
var _countdown_label: Label
var _started: bool = false
var _input_blocked: float = 1.0

func _ready() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Background color (dark) in case image fails
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.05, 0.06)
	bg.anchors_preset = Control.PRESET_FULL_RECT
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# Load inicio.png
	var tex_rect := TextureRect.new()
	var abs_path := ProjectSettings.globalize_path("res://inicio.png")
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

	# Countdown label
	_countdown_label = Label.new()
	_countdown_label.text = "El mundo carga en 5..."
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_countdown_label.anchors_preset = Control.PRESET_FULL_RECT
	_countdown_label.anchor_right = 1.0
	_countdown_label.anchor_bottom = 1.0
	_countdown_label.add_theme_font_size_override("font_size", 32)
	_countdown_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1.0))
	_countdown_label.add_theme_constant_override("offset_bottom", 80)
	add_child(_countdown_label)

	# Use a Timer instead of _process for reliability
	var timer := Timer.new()
	timer.name = "CountdownTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_on_timer_tick)
	add_child(timer)

func _on_timer_tick() -> void:
	if _started:
		return
	_countdown -= 1.0
	if _countdown <= 0.0:
		_start_game()
		return
	_countdown_label.text = "El mundo carga en %d..." % ceili(_countdown)

func _input(event: InputEvent) -> void:
	if _started:
		return
	# Block input for the first second to avoid spurious events
	_input_blocked -= get_process_delta_time()
	if _input_blocked > 0.0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode != 0:
			_start_game()
	elif event is InputEventMouseButton and event.pressed:
		_start_game()

func _start_game() -> void:
	if _started:
		return
	_started = true
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
