extends CanvasLayer
class_name HUD

const CraftingSystemScript = preload("res://scripts/CraftingSystem.gd")

var player
var day_cycle
var _damage_overlay: ColorRect = null
var _damage_flash: float = 0.0
var _prev_health: float = 100.0

var root: Control
var status_panel: PanelContainer
var inventory_panel: PanelContainer
var inventory_grid: GridContainer
var inventory_weight_label: Label
var time_label: Label
var real_clock_label: Label
var weather_label: Label
var _weather_timer := 0.0
var _weather_http: HTTPRequest
var _real_temp := "--"
var _real_temp_parsed := -999.0
var _weather_loading := false
var prompt_label: Label
var crosshair_dot: ColorRect
var crosshair_ring_h: ColorRect
var crosshair_ring_v: ColorRect
var _crosshair_rifle_mode := false
var notice_label: Label
var objective_label: Label
var equipment_hand_label: Label
var equipment_clothing_label: Label
var equipment_backpack_label: Label
var inventory_visible := false
var notice_timer := 0.0
var countdown_label: Label = null
var countdown_timer := 0.0
var countdown_total := 0.0
var countdown_text := ""
var status_bars := {}
var stamina_bar: ProgressBar = null
var stamina_label: Label = null
var selected_slot_index := -1
var slot_action_label: Label = null
var _inv_refresh_timer := 0.0
var _debug_temp_timer := 0.0
var _weather_retry_timer := 0.0
var _context_menu: PanelContainer = null
var _context_menu_slot_index := -1
var _context_menu_recipes: Array = []
var _context_menu_has_eat := false
var _context_menu_has_drink := false

func setup(new_player, new_day_cycle) -> void:
	player = new_player
	day_cycle = new_day_cycle
	add_to_group("hud")
	_build_ui()
	_apply_aim_layout()
	player.prompt_changed.connect(_set_prompt)
	player.notice.connect(show_notice)
	player.inventory.changed.connect(_update_inventory)
	player.stats.changed.connect(_update_stats)
	_update_inventory()
	_update_stats()

func _process(delta: float) -> void:
	if player == null:
		return
	_update_stats()
	_update_real_clock()
	_weather_timer += delta
	if _weather_timer >= 600.0:
		_weather_timer = 0.0
		_fetch_weather()
	# Retry weather fetch if it failed
	if _weather_retry_timer > 0.0:
		_weather_retry_timer -= delta
		if _weather_retry_timer <= 0.0 and _real_temp_parsed == -999.0:
			_fetch_weather()
			_weather_retry_timer = 15.0
	_update_damage_overlay(delta)
	if inventory_visible:
		_inv_refresh_timer += delta
		if _inv_refresh_timer >= 0.5 and selected_slot_index < 0:
			_inv_refresh_timer = 0.0
			_update_inventory()
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			notice_label.text = ""
	if countdown_timer > 0.0:
		countdown_timer -= delta
		if countdown_timer <= 0.0:
			countdown_timer = 0.0
			countdown_label.visible = false
		else:
			var remaining: int = ceili(countdown_timer)
			countdown_label.text = "%s... %ds" % [countdown_text, remaining]

func show_countdown(text: String, duration: float) -> void:
	countdown_text = text
	countdown_total = duration
	countdown_timer = duration
	countdown_label.visible = true
	countdown_label.text = "%s... %ds" % [text, ceili(duration)]

func toggle_inventory() -> void:
	_close_context_menu()
	inventory_visible = not inventory_visible
	if inventory_visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		inventory_panel.visible = true
		objective_label.visible = false
		_update_inventory()
		inventory_panel.offset_transform_enabled = true
		var tw := create_tween()
		tw.tween_property(inventory_panel, "offset_transform_position:x", 0.0, 0.25).from(80.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(inventory_panel, "offset_transform_scale", Vector2.ONE, 0.25).from(Vector2(0.92, 0.92)).set_ease(Tween.EASE_OUT)
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var tw2 := create_tween()
		tw2.tween_property(inventory_panel, "offset_transform_position:x", 80.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw2.parallel().tween_property(inventory_panel, "modulate:a", 0.0, 0.2)
		await tw2.finished
		inventory_panel.visible = false
		inventory_panel.modulate.a = 1.0
		inventory_panel.offset_transform_position = Vector2.ZERO
		inventory_panel.offset_transform_scale = Vector2.ONE
		objective_label.visible = true
	selected_slot_index = -1
	if slot_action_label != null:
		slot_action_label.text = ""

func show_notice(text: String) -> void:
	notice_label.text = text
	notice_timer = 4.0
	notice_label.offset_transform_enabled = true
	notice_label.offset_transform_position = Vector2(0.0, -30.0)
	notice_label.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(notice_label, "offset_transform_position:y", 0.0, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.parallel().tween_property(notice_label, "modulate:a", 1.0, 0.25)

func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_build_status_panel()
	_build_inventory_panel()
	_build_center_messages()
	_build_real_clock_panel()

func _build_real_clock_panel() -> void:
	var panel := PanelContainer.new()
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = 218
	panel.offset_bottom = 88
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.017, 0.016, 0.66), Color(0.34, 0.37, 0.32, 0.45), 1))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	real_clock_label = Label.new()
	real_clock_label.add_theme_font_size_override("font_size", 22)
	real_clock_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.85))
	real_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(real_clock_label)

	weather_label = Label.new()
	weather_label.add_theme_font_size_override("font_size", 14)
	weather_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.68))
	weather_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(weather_label)

	_weather_http = HTTPRequest.new()
	_weather_http.timeout = 10.0
	add_child(_weather_http)
	_weather_http.request_completed.connect(_on_weather_received)
	_fetch_weather()
	_weather_retry_timer = 15.0

func _fetch_weather() -> void:
	if _weather_loading:
		return
	if not is_instance_valid(_weather_http):
		return
	_weather_loading = true
	var url := "https://api.open-meteo.com/v1/forecast?latitude=41.38&longitude=2.17&current=temperature_2m&timezone=auto"
	var err := _weather_http.request(url, [], HTTPClient.METHOD_GET, "")
	if err != OK:
		_weather_loading = false
		pass # print("[HUD] Weather request init failed, err=%d" % err)

func _on_weather_received(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_weather_loading = false
	if result == HTTPRequest.RESULT_SUCCESS:
		var text := body.get_string_from_utf8().strip_edges()
		pass # print("[HUD] Weather received: '%s'" % text.left(120))
		var json = JSON.new()
		if json.parse(text) == OK:
			var data: Dictionary = json.data
			if data.has("current"):
				var current: Dictionary = data["current"]
				if current.has("temperature_2m"):
					var temp: float = float(current["temperature_2m"])
					_real_temp = "%.0f°C" % temp
					_real_temp_parsed = temp
					pass # print("[HUD] Parsed temperature: %.1f" % temp)
					return
		pass # print("[HUD] Failed to parse weather JSON")
		_real_temp = "N/A"
		_weather_retry_timer = 15.0
	else:
		pass # print("[HUD] Weather request failed, result=%d" % result)
		_real_temp = "N/A"
		_weather_retry_timer = 15.0

func _update_real_clock() -> void:
	if real_clock_label == null:
		return
	var now := Time.get_time_dict_from_system()
	real_clock_label.text = "%02d:%02d:%02d" % [now.hour, now.minute, now.second]
	if weather_label != null:
		weather_label.text = "Temp: %s" % _real_temp

func _build_status_panel() -> void:
	status_panel = PanelContainer.new()
	status_panel.offset_left = 18
	status_panel.offset_top = 420
	status_panel.offset_right = 268
	status_panel.offset_bottom = 720
	status_panel.anchor_left = 0.0
	status_panel.anchor_top = 1.0
	status_panel.anchor_right = 0.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_top = -300
	status_panel.offset_bottom = 0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.017, 0.016, 0.66), Color(0.34, 0.37, 0.32, 0.45), 1))
	root.add_child(status_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(box)

	time_label = Label.new()
	time_label.add_theme_font_size_override("font_size", 15)
	time_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.78))
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(time_label)

	_create_status_bar(box, "health", "SALUD", Color(0.62, 0.10, 0.08))
	_create_status_bar(box, "hunger", "COMIDA", Color(0.62, 0.48, 0.15))
	_create_status_bar(box, "thirst", "AGUA", Color(0.18, 0.42, 0.66))
	_create_status_bar(box, "sleep", "SUEÑO", Color(0.35, 0.20, 0.55))
	_create_status_bar(box, "cold", "FRIO", Color(0.30, 0.58, 0.78))
	_build_stamina_bar()

func _create_status_bar(parent: VBoxContainer, key: String, title: String, color: Color) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(220, 21)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var icon_panel := PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(32, 21)
	icon_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.add_theme_stylebox_override("panel", _panel_style(color.darkened(0.50), color, 1))
	row.add_child(icon_panel)

	var icon_label := Label.new()
	icon_label.text = _status_icon_text(key)
	icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_label.add_theme_font_size_override("font_size", 13)
	icon_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.88))
	icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_panel.add_child(icon_label)

	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(78, 20)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.70, 0.73, 0.66))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	var value_label := Label.new()
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.custom_minimum_size = Vector2(70, 20)
	value_label.add_theme_font_size_override("font_size", 13)
	value_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.84))
	value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(value_label)

	status_bars[key] = {
		"icon_panel": icon_panel,
		"icon": icon_label,
		"value": value_label,
		"base_color": color
	}

func _status_icon_text(key: String) -> String:
	match key:
		"health":
			return "+"
		"hunger":
			return "FO"
		"thirst":
			return "WA"
		"cold":
			return "T"
		_:
			return "?"

func _build_inventory_panel() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.anchor_left = 0.5
	inventory_panel.anchor_top = 0.0
	inventory_panel.anchor_right = 0.5
	inventory_panel.anchor_bottom = 1.0
	inventory_panel.offset_left = -390
	inventory_panel.offset_top = 86
	inventory_panel.offset_right = 390
	inventory_panel.offset_bottom = -86
	inventory_panel.visible = inventory_visible
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.020, 0.018, 0.91), Color(0.47, 0.49, 0.42, 0.52), 1))
	root.add_child(inventory_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	inventory_panel.add_child(box)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_row)

	var title := Label.new()
	title.text = "INVENTARIO"
	title.custom_minimum_size = Vector2(480, 32)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.86, 0.87, 0.80))
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(title)

	inventory_weight_label = Label.new()
	inventory_weight_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	inventory_weight_label.custom_minimum_size = Vector2(250, 32)
	inventory_weight_label.add_theme_font_size_override("font_size", 16)
	inventory_weight_label.add_theme_color_override("font_color", Color(0.78, 0.80, 0.72))
	inventory_weight_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(inventory_weight_label)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.mouse_filter = Control.MOUSE_FILTER_PASS
	box.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 420)
	left.mouse_filter = Control.MOUSE_FILTER_PASS
	columns.add_child(left)
	_add_inventory_section_title(left, "EQUIPO")
	equipment_hand_label = _add_equipment_line(left, "Manos", "Vacio")
	equipment_clothing_label = _add_equipment_line(left, "Ropa", "Sin abrigo")
	equipment_backpack_label = _add_equipment_line(left, "Mochila", "Sin mochila")
	_add_inventory_hint(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(480, 420)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)
	_add_inventory_section_title(right, "INVENTARIO")

	inventory_grid = GridContainer.new()
	inventory_grid.columns = 5
	inventory_grid.add_theme_constant_override("h_separation", 8)
	inventory_grid.add_theme_constant_override("v_separation", 8)
	inventory_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(inventory_grid)

func _add_inventory_section_title(parent: VBoxContainer, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.56, 0.62, 0.52))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _add_equipment_line(parent: VBoxContainer, left_text: String, right_text: String) -> Label:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(230, 48)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.060, 0.055, 0.84), Color(0.22, 0.24, 0.21, 0.75), 1))
	parent.add_child(panel)
	var label := Label.new()
	label.text = "%s\n%s" % [left_text, right_text]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.76, 0.78, 0.70))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	return label

func _add_inventory_hint(parent: VBoxContainer) -> void:
	var label := Label.new()
	label.text = "Clic izq en objeto para ver opciones.\nClic der para soltar directamente.\nI o Tab abre/cierra la mochila."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.64, 0.66, 0.59))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

	var craft_btn := Button.new()
	craft_btn.text = "Craftear Fogata (2 Troncos + 1 Palo + Cerillas)"
	craft_btn.add_theme_font_size_override("font_size", 14)
	craft_btn.custom_minimum_size = Vector2(230, 36)
	craft_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	craft_btn.pressed.connect(_on_craft_campfire_pressed)
	parent.add_child(craft_btn)

func _on_craft_campfire_pressed() -> void:
	if player == null or player.inventory == null:
		return
	if player.has_method("_craft_campfire"):
		player._craft_campfire()

func _build_center_messages() -> void:
	objective_label = Label.new()
	objective_label.offset_left = 18
	objective_label.offset_top = 18
	objective_label.offset_right = 458
	objective_label.offset_bottom = 72
	objective_label.anchor_left = 0.0
	objective_label.anchor_top = 0.0
	objective_label.anchor_right = 0.0
	objective_label.anchor_bottom = 0.0
	objective_label.text = ""
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.75))
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(objective_label)

	crosshair_ring_h = ColorRect.new()
	crosshair_ring_h.anchor_left = 0.5
	crosshair_ring_h.anchor_top = 0.5
	crosshair_ring_h.anchor_right = 0.5
	crosshair_ring_h.anchor_bottom = 0.5
	crosshair_ring_h.offset_left = -8
	crosshair_ring_h.offset_top = -1
	crosshair_ring_h.offset_right = 8
	crosshair_ring_h.offset_bottom = 1
	crosshair_ring_h.color = Color(0.86, 0.88, 0.82, 0.62)
	crosshair_ring_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_ring_h.visible = false
	root.add_child(crosshair_ring_h)

	crosshair_ring_v = ColorRect.new()
	crosshair_ring_v.anchor_left = 0.5
	crosshair_ring_v.anchor_top = 0.5
	crosshair_ring_v.anchor_right = 0.5
	crosshair_ring_v.anchor_bottom = 0.5
	crosshair_ring_v.offset_left = -1
	crosshair_ring_v.offset_top = -8
	crosshair_ring_v.offset_right = 1
	crosshair_ring_v.offset_bottom = 8
	crosshair_ring_v.color = Color(0.86, 0.88, 0.82, 0.62)
	crosshair_ring_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_ring_v.visible = false
	root.add_child(crosshair_ring_v)

	crosshair_dot = ColorRect.new()
	crosshair_dot.anchor_left = 0.5
	crosshair_dot.anchor_top = 0.5
	crosshair_dot.anchor_right = 0.5
	crosshair_dot.anchor_bottom = 0.5
	crosshair_dot.offset_left = -2
	crosshair_dot.offset_top = -2
	crosshair_dot.offset_right = 2
	crosshair_dot.offset_bottom = 2
	crosshair_dot.color = Color(0.96, 0.94, 0.84, 0.92)
	crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair_dot)

	_damage_overlay = ColorRect.new()
	_damage_overlay.anchor_left = 0.0
	_damage_overlay.anchor_top = 0.0
	_damage_overlay.anchor_right = 1.0
	_damage_overlay.anchor_bottom = 1.0
	_damage_overlay.offset_left = 0
	_damage_overlay.offset_top = 0
	_damage_overlay.offset_right = 0
	_damage_overlay.offset_bottom = 0
	_damage_overlay.color = Color(0.4, 0.0, 0.0, 0.0)
	_damage_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_overlay)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.anchor_left = 0.5
	prompt_label.anchor_top = 0.5
	prompt_label.anchor_right = 0.5
	prompt_label.anchor_bottom = 0.5
	prompt_label.offset_left = -250
	prompt_label.offset_top = 8
	prompt_label.offset_right = 250
	prompt_label.offset_bottom = 48
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.82))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_label)

	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.anchor_left = 0.5
	notice_label.anchor_top = 0.0
	notice_label.anchor_right = 0.5
	notice_label.anchor_bottom = 0.0
	notice_label.offset_left = -300
	notice_label.offset_top = 52
	notice_label.offset_right = 300
	notice_label.offset_bottom = 122
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 19)
	notice_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.66))
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notice_label)

	countdown_label = Label.new()
	countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	countdown_label.anchor_left = 0.5
	countdown_label.anchor_top = 0.0
	countdown_label.anchor_right = 0.5
	countdown_label.anchor_bottom = 0.0
	countdown_label.offset_left = -300
	countdown_label.offset_top = 130
	countdown_label.offset_right = 300
	countdown_label.offset_bottom = 180
	countdown_label.add_theme_font_size_override("font_size", 28)
	countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	countdown_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	countdown_label.add_theme_constant_override("shadow_offset_x", 1)
	countdown_label.add_theme_constant_override("shadow_offset_y", 1)
	countdown_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	countdown_label.visible = false
	root.add_child(countdown_label)

func _apply_aim_layout() -> void:
	if player == null or not player.has_method("get_aim_screen_offset"):
		return
	var aim_offset: Vector2 = player.get_aim_screen_offset()
	if aim_offset == Vector2.ZERO:
		return
	if crosshair_ring_h != null:
		crosshair_ring_h.position = aim_offset - crosshair_ring_h.size * 0.5
	if crosshair_ring_v != null:
		crosshair_ring_v.position = aim_offset - crosshair_ring_v.size * 0.5
	if crosshair_dot != null:
		crosshair_dot.position = aim_offset - crosshair_dot.size * 0.5
	if prompt_label != null:
		prompt_label.position = aim_offset + Vector2(-250.0, 24.0)

func _update_stats() -> void:
	if player == null or day_cycle == null:
		return
	if player.inventory == null:
		return
	time_label.text = "%s  |  %.1f / %.1f kg" % [
		day_cycle.get_hour_text(),
		player._get_total_carry_weight() if player.has_method("_get_total_carry_weight") else player.inventory.get_total_weight(),
		player.inventory.max_weight
	]
	_set_bar("health", player.stats.health / player.stats.max_health, "%.0f" % player.stats.health)
	_set_bar("hunger", player.stats.hunger / player.stats.max_stat, "%.0f" % player.stats.hunger)
	_set_bar("thirst", player.stats.thirst / player.stats.max_stat, "%.0f" % player.stats.thirst)
	_set_bar("sleep", player.stats.sleep / player.stats.max_stat, "%.0f" % player.stats.sleep)
	var cold_percent: float = clamp((36.6 - player.stats.body_temperature) / 3.0, 0.0, 1.0)
	_set_bar("cold", cold_percent, "%.1f C" % player.stats.body_temperature)
	_update_stamina_bar()
	if _prev_health > player.stats.health + 0.1:
		_damage_flash = 1.0
	_prev_health = player.stats.health

func _update_damage_overlay(delta: float) -> void:
	if _damage_overlay == null or player == null:
		return
	_damage_flash = max(0.0, _damage_flash - delta * 1.5)
	var health_ratio: float = float(player.stats.health) / float(player.stats.max_health)
	var persistent_alpha: float = 0.0
	if health_ratio < 0.5:
		persistent_alpha = (0.5 - health_ratio) * 0.6
	var flash_alpha := _damage_flash * 0.5
	var total_alpha: float = clamp(persistent_alpha + flash_alpha, 0.0, 0.85)
	_damage_overlay.color = Color(0.4, 0.0, 0.0, total_alpha)

func _build_stamina_bar() -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(220, 24)
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.get_child(0).add_child(row)

	var label := Label.new()
	label.text = "STAMINA"
	label.custom_minimum_size = Vector2(78, 20)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.70, 0.73, 0.66))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)

	stamina_bar = ProgressBar.new()
	stamina_bar.custom_minimum_size = Vector2(110, 18)
	stamina_bar.min_value = 0.0
	stamina_bar.max_value = 100.0
	stamina_bar.value = 100.0
	stamina_bar.show_percentage = false
	stamina_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.18, 0.66, 0.40)
	fill_style.set_corner_radius_all(2)
	stamina_bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.06, 0.05, 0.8)
	bg_style.border_color = Color(0.20, 0.22, 0.19, 0.7)
	bg_style.set_border_width_all(1)
	bg_style.set_corner_radius_all(2)
	stamina_bar.add_theme_stylebox_override("background", bg_style)
	row.add_child(stamina_bar)

	stamina_label = Label.new()
	stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stamina_label.custom_minimum_size = Vector2(32, 20)
	stamina_label.add_theme_font_size_override("font_size", 12)
	stamina_label.add_theme_color_override("font_color", Color(0.88, 0.90, 0.84))
	stamina_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(stamina_label)

func _update_stamina_bar() -> void:
	if stamina_bar == null or player == null:
		return
	var ratio: float = player.stats.energy / player.stats.max_stat
	stamina_bar.value = ratio * 100.0
	if stamina_label != null:
		stamina_label.text = "%.0f" % player.stats.energy
	var fill := stamina_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill != null:
		if ratio > 0.5:
			fill.bg_color = Color(0.18, 0.66, 0.40)
		elif ratio > 0.2:
			fill.bg_color = Color(0.72, 0.62, 0.16)
		else:
			fill.bg_color = Color(0.72, 0.16, 0.10)

func _set_bar(key: String, ratio: float, value_text: String) -> void:
	if not status_bars.has(key):
		return
	var data: Dictionary = status_bars[key]
	var icon_panel := data["icon_panel"] as PanelContainer
	var icon_label := data["icon"] as Label
	var value_label := data["value"] as Label
	var base_color: Color = data["base_color"]
	var amount: float = clamp(ratio, 0.0, 1.0)
	if key == "cold":
		amount = 1.0 - amount
	var warning_color := Color(0.75, 0.12, 0.08)
	var shown_color: Color = warning_color.lerp(base_color, amount)
	icon_panel.add_theme_stylebox_override("panel", _panel_style(shown_color.darkened(0.50), shown_color, 1))
	icon_label.add_theme_color_override("font_color", Color(0.93, 0.95, 0.88).lerp(Color(0.96, 0.55, 0.42), 1.0 - amount))
	value_label.text = value_text

func _update_inventory() -> void:
	if player == null or inventory_grid == null:
		return
	_update_equipment_labels()
	for child in inventory_grid.get_children():
		child.queue_free()
	inventory_weight_label.text = "PESO %.1f / %.1f KG" % [
		player._get_total_carry_weight() if player.has_method("_get_total_carry_weight") else player.inventory.get_total_weight(),
		player.inventory.max_weight
	]
	var slot_count: int = max(player.inventory.max_slots, player.inventory.items.size())
	for i in range(slot_count):
		var item = player.inventory.items[i] if i < player.inventory.items.size() else null
		_create_inventory_slot(i, item)

func _update_equipment_labels() -> void:
	if equipment_hand_label != null:
		var hand_text := "Vacio"
		if player.inventory.items.size() > 0:
			var held_index: int = clampi(player.held_index, 0, player.inventory.items.size() - 1)
			hand_text = player.inventory.items[held_index].item_name
		equipment_hand_label.text = "Manos\n%s" % hand_text
	if equipment_clothing_label != null:
		var parts: Array = []
		if "_equipped_slots" in player:
			for slot in player._equipped_slots:
				parts.append(str(player._equipped_slots[slot]))
		if parts.is_empty():
			var clothing_text := "Sin ropa"
			if not player.equipped_clothing.is_empty():
				clothing_text = player.equipped_clothing
			parts.append(clothing_text)
		equipment_clothing_label.text = "Ropa\n%s" % "\n".join(parts)
	if equipment_backpack_label != null:
		var backpack_text := "Sin mochila"
		if not player.equipped_backpack.is_empty():
			backpack_text = player.equipped_backpack
		var cap_text := "Slots: %d | Peso: %.1f/%.1f kg" % [
			player.inventory.max_slots,
			player._get_total_carry_weight() if player.has_method("_get_total_carry_weight") else player.inventory.get_total_weight(),
			player.inventory.max_weight
		]
		equipment_backpack_label.text = "Mochila\n%s\n%s" % [backpack_text, cap_text]

func _create_inventory_slot(index: int, item) -> void:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(86, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var is_selected := index == selected_slot_index
	var border_color := Color(0.72, 0.74, 0.40, 0.95) if is_selected else Color(0.25, 0.27, 0.23, 0.82)
	slot.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.060, 0.055, 0.86), border_color, 2 if is_selected else 1))
	inventory_grid.add_child(slot)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(box)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 5)
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(top_row)

	var slot_number := Label.new()
	slot_number.text = str(index + 1)
	slot_number.custom_minimum_size = Vector2(16, 18)
	slot_number.add_theme_font_size_override("font_size", 11)
	slot_number.add_theme_color_override("font_color", Color(0.56, 0.59, 0.52))
	slot_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(slot_number)

	var thumbnail := PanelContainer.new()
	thumbnail.custom_minimum_size = Vector2(36, 28)
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb_fill := Color(0.075, 0.080, 0.072, 0.86)
	var thumb_border := Color(0.22, 0.24, 0.20, 0.72)
	if item != null:
		thumb_fill = _item_thumbnail_color(item)
		thumb_border = thumb_fill.lightened(0.28)
	thumbnail.add_theme_stylebox_override("panel", _panel_style(thumb_fill, thumb_border, 1))
	top_row.add_child(thumbnail)

	var thumb_label := Label.new()
	thumb_label.text = "-" if item == null else _item_thumbnail_text(item)
	thumb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	thumb_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	thumb_label.add_theme_font_size_override("font_size", 10)
	thumb_label.add_theme_color_override("font_color", Color(0.92, 0.94, 0.86))
	thumb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.add_child(thumb_label)

	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.77))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if item == null:
		label.text = "-"
		label.add_theme_color_override("font_color", Color(0.36, 0.38, 0.34))
	else:
		label.text = "%s\nx%d" % [item.item_name, item.quantity]
		if item.item_name == "Botella de agua" and item.has_method("durability_pct"):
			var wpct := int(item.durability_pct() * 100.0)
			label.text += "\nAgua: %d%%" % wpct
			if wpct < 25:
				label.add_theme_color_override("font_color", Color(0.96, 0.40, 0.30))
			elif wpct < 50:
				label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
		elif item.has_method("durability_pct") and item.item_type != "food" and item.item_type != "water":
			var pct := int(item.durability_pct() * 100.0)
			if pct < 100:
				label.text += "\n%d%%" % pct
				if pct < 25:
					label.add_theme_color_override("font_color", Color(0.96, 0.40, 0.30))
				elif pct < 50:
					label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
	box.add_child(label)

func _item_thumbnail_color(item) -> Color:
	match str(item.item_type):
		"food":
			return Color(0.50, 0.20, 0.08)
		"water":
			return Color(0.10, 0.32, 0.52)
		"medical":
			return Color(0.62, 0.16, 0.12)
		"weapon":
			return Color(0.32, 0.32, 0.30)
		"tool", "tool_axe", "tool_hoe", "tool_shovel", "tool_hammer", "tool_pickaxe":
			return Color(0.36, 0.27, 0.12)
		"clothing":
			return Color(0.16, 0.22, 0.12)
		"backpack":
			return Color(0.08, 0.13, 0.07)
		"resource":
			return Color(0.24, 0.15, 0.07)
		"seed":
			return Color(0.22, 0.36, 0.10)
		"battery":
			return Color(0.12, 0.12, 0.10)
		"tool_spear":
			return Color(0.38, 0.26, 0.10)
		"tool_fishing":
			return Color(0.30, 0.22, 0.08)
		"campfire":
			return Color(0.20, 0.12, 0.04)
		_:
			return Color(0.18, 0.18, 0.16)

func _item_thumbnail_text(item) -> String:
	match str(item.item_type):
		"food":
			return "FO"
		"water":
			return "WA"
		"medical":
			return "ME"
		"weapon":
			return "WE"
		"tool", "tool_axe", "tool_hoe", "tool_shovel", "tool_hammer", "tool_pickaxe", "tool_spear", "tool_fishing":
			return "TO"
		"clothing":
			return "CL"
		"backpack":
			return "BP"
		"resource":
			return "RS"
		"seed":
			return "SE"
		"battery":
			return "BA"
		_:
			return "IT"

func _set_prompt(text: String) -> void:
	prompt_label.text = text
	var active := not text.is_empty()
	var color := _get_crosshair_action_color(text, active)
	var span := 16.0
	var thickness := 0.0
	var dot_size := 4.0
	if active:
		span = 0.0
		thickness = 0.0
		dot_size = 6.0
	if text.to_lower().find("talar") >= 0:
		span = 30.0
	elif text.to_lower().find("pescar") >= 0:
		span = 28.0
	elif text.to_lower().find("plantar") >= 0 or text.to_lower().find("cosechar") >= 0:
		span = 26.0
	if _crosshair_rifle_mode:
		if crosshair_dot != null:
			crosshair_dot.visible = false
		if crosshair_ring_h != null:
			crosshair_ring_h.size = Vector2(16.0, 2.0)
			crosshair_ring_h.visible = true
		if crosshair_ring_v != null:
			crosshair_ring_v.size = Vector2(2.0, 16.0)
			crosshair_ring_v.visible = true
	else:
		if crosshair_ring_h != null:
			crosshair_ring_h.size = Vector2(span, thickness)
			crosshair_ring_h.visible = false
		if crosshair_ring_v != null:
			crosshair_ring_v.size = Vector2(thickness, span)
			crosshair_ring_v.visible = false
		if crosshair_dot != null:
			crosshair_dot.size = Vector2(dot_size, dot_size)
		if crosshair_dot != null:
			crosshair_dot.color = color
	if not _crosshair_rifle_mode:
		if crosshair_ring_h != null:
			crosshair_ring_h.color = Color(color.r, color.g, color.b, 0.68 if active else 0.34)
		if crosshair_ring_v != null:
			crosshair_ring_v.color = Color(color.r, color.g, color.b, 0.68 if active else 0.34)
	_apply_aim_layout()

func _get_crosshair_action_color(text: String, active: bool) -> Color:
	if not active:
		return Color(0.86, 0.88, 0.82, 0.48)
	var lower := text.to_lower()
	if lower.find("abrir puerta") >= 0 or lower.find("cerrar puerta") >= 0:
		return Color(0.50, 0.72, 1.0, 0.96)
	if lower.find("recoger") >= 0:
		return Color(0.78, 0.92, 0.48, 0.96)
	if lower.find("recolectar") >= 0 or lower.find("cosechar") >= 0:
		return Color(0.45, 0.95, 0.45, 0.96)
	if lower.find("plantar") >= 0:
		return Color(0.45, 0.82, 0.35, 0.96)
	if lower.find("pescar") >= 0:
		return Color(0.35, 0.72, 1.0, 0.96)
	if lower.find("talar") >= 0:
		return Color(1.0, 0.60, 0.26, 0.96)
	return Color(0.96, 0.94, 0.84, 0.96)

func _panel_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(2)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _update_slot_buttons() -> void:
	pass

func _handle_slot_key_input() -> void:
	pass

func _input(event: InputEvent) -> void:
	pass

func handle_slot_click(mouse_pos: Vector2, button_index: int) -> void:
	if not inventory_visible or inventory_grid == null:
		return
	if _context_menu != null:
		_close_context_menu()
		return
	for i in range(inventory_grid.get_child_count()):
		var slot = inventory_grid.get_child(i)
		if slot is PanelContainer:
			var rect = slot.get_global_rect()
			if rect.has_point(mouse_pos):
				if i < player.inventory.items.size() and player.inventory.items[i] != null:
					if button_index == MOUSE_BUTTON_LEFT:
						_show_context_menu(i, rect)
					elif button_index == MOUSE_BUTTON_RIGHT:
						selected_slot_index = i
						_on_drop_pressed()
				return

func is_click_on_slot(mouse_pos: Vector2) -> bool:
	if not inventory_visible or inventory_grid == null:
		return false
	for i in range(inventory_grid.get_child_count()):
		var slot = inventory_grid.get_child(i)
		if slot is PanelContainer:
			if slot.get_global_rect().has_point(mouse_pos):
				return true
	return false

func _show_context_menu(slot_index: int, slot_rect: Rect2) -> void:
	_close_context_menu()
	selected_slot_index = slot_index
	_context_menu_slot_index = slot_index
	_context_menu_has_drink = false
	_context_menu_has_eat = false
	_context_menu = PanelContainer.new()
	_context_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_menu.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.04, 0.96), Color(0.72, 0.74, 0.40, 0.95), 2))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_context_menu.add_child(vbox)
	var item = player.inventory.items[slot_index]
	var name_label := Label.new()
	name_label.text = item.item_name
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.90, 0.88, 0.72))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_label)
	var use_btn := Button.new()
	use_btn.text = "Usar"
	use_btn.add_theme_font_size_override("font_size", 14)
	use_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(use_btn)
	# Add Beber button for water items
	if str(item.item_type) == "water":
		var drink_btn := Button.new()
		drink_btn.text = "Beber"
		drink_btn.add_theme_font_size_override("font_size", 14)
		drink_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(drink_btn)
		_context_menu_has_drink = true
	# Add Comer button for food items
	if str(item.item_type) == "food":
		var eat_btn := Button.new()
		eat_btn.text = "Comer"
		eat_btn.add_theme_font_size_override("font_size", 14)
		eat_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(eat_btn)
		_context_menu_has_eat = true
	var drop_btn := Button.new()
	drop_btn.text = "Soltar"
	drop_btn.add_theme_font_size_override("font_size", 14)
	drop_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(drop_btn)
	var store_btn := Button.new()
	store_btn.text = "Guardar"
	store_btn.add_theme_font_size_override("font_size", 14)
	store_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(store_btn)
	# Add combine button if there are recipes available for this item
	var item_name := str(item.item_name)
	var recipes := CraftingSystemScript.get_recipes_for_item(item_name)
	_context_menu_recipes = []
	for recipe in recipes:
		if CraftingSystemScript._can_craft(recipe, player.inventory.items):
			var recipe_label = CraftingSystemScript.get_recipe_label(recipe)
			var combine_btn := Button.new()
			combine_btn.text = "Combinar: %s" % recipe_label
			combine_btn.add_theme_font_size_override("font_size", 13)
			combine_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			combine_btn.custom_minimum_size = Vector2(220, 30)
			vbox.add_child(combine_btn)
			_context_menu_recipes.append(recipe)
	_context_menu.position = Vector2(slot_rect.position.x + slot_rect.size.x + 6, slot_rect.position.y)
	_context_menu.z_index = 100
	root.add_child(_context_menu)
	_update_inventory()

func _close_context_menu() -> void:
	if _context_menu != null:
		_context_menu.queue_free()
		_context_menu = null
	_context_menu_slot_index = -1

func handle_context_menu_click(mouse_pos: Vector2, button_index: int) -> bool:
	if _context_menu == null:
		return false
	var rect = _context_menu.get_global_rect()
	if rect.has_point(mouse_pos):
		var vbox = _context_menu.get_child(0)
		# child 0 = name label, child 1 = use_btn
		# Dynamic indices based on which optional buttons exist
		var idx := 2
		var drink_index := -1
		var eat_index := -1
		if _context_menu_has_drink:
			drink_index = idx
			idx += 1
		if _context_menu_has_eat:
			eat_index = idx
			idx += 1
		var drop_index := idx
		idx += 1
		var store_index := idx
		idx += 1
		var combine_start := idx
		if button_index == MOUSE_BUTTON_LEFT:
			var use_btn = vbox.get_child(1)
			if use_btn is Button and use_btn.get_global_rect().has_point(mouse_pos):
				_on_use_pressed()
				return true
			if drink_index >= 0:
				var drink_btn = vbox.get_child(drink_index)
				if drink_btn is Button and drink_btn.get_global_rect().has_point(mouse_pos):
					_on_drink_pressed()
					return true
			if eat_index >= 0:
				var eat_btn = vbox.get_child(eat_index)
				if eat_btn is Button and eat_btn.get_global_rect().has_point(mouse_pos):
					_on_eat_pressed()
					return true
			var drop_btn = vbox.get_child(drop_index)
			if drop_btn is Button and drop_btn.get_global_rect().has_point(mouse_pos):
				_on_drop_pressed()
				return true
			var store_btn = vbox.get_child(store_index)
			if store_btn is Button and store_btn.get_global_rect().has_point(mouse_pos):
				_on_store_pressed()
				return true
			# Check combine buttons
			for i in range(combine_start, vbox.get_child_count()):
				var btn = vbox.get_child(i)
				if btn is Button and btn.get_global_rect().has_point(mouse_pos):
					var recipe_index := i - combine_start
					if recipe_index < _context_menu_recipes.size():
						_on_combine_pressed(_context_menu_recipes[recipe_index])
						return true
		return true
	_close_context_menu()
	return false

func _on_combine_pressed(recipe: Dictionary) -> void:
	if player == null or player.inventory == null:
		return
	# Close inventory immediately so the crafting animation is visible
	selected_slot_index = -1
	_close_context_menu()
	if inventory_visible:
		toggle_inventory()
	if player.has_method("craft_recipe"):
		player.craft_recipe(recipe)

func _on_eat_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= player.inventory.items.size():
		return
	player.held_index = selected_slot_index
	var item = player.inventory.items[selected_slot_index]
	if str(item.item_type) != "food":
		return
	# Close inventory so animation is visible
	_close_context_menu()
	if inventory_visible:
		toggle_inventory()
	# Put food in hand and eat immediately
	player._use_inventory_index(selected_slot_index)
	if player.held_index == selected_slot_index and player.has_method("_eat_held_item"):
		player._eat_held_item()
	selected_slot_index = -1

func _on_use_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= player.inventory.items.size():
		return
	player.held_index = selected_slot_index
	var item = player.inventory.items[selected_slot_index]
	var item_type := str(item.item_type)
	var item_name := str(item.item_name)
	# Items that should go to hand instead of being consumed
	var to_hand := item_name.find("ensartada") >= 0 or item_name.find("asada") >= 0 or (item_name == "Palo") or (item_name == "Palo afilado")
	match item_type:
		"food", "water", "medical", "clothing":
			if to_hand and item_type == "food":
				player._use_inventory_index(selected_slot_index)
			elif to_hand:
				player._sync_held_item()
			else:
				player._use_inventory_index(selected_slot_index)
		_:
			player._sync_held_item()
	selected_slot_index = -1
	_close_context_menu()
	if inventory_visible:
		toggle_inventory()

func _on_drop_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= player.inventory.items.size():
		return
	player.drop_inventory_item(selected_slot_index)
	selected_slot_index = -1
	_close_context_menu()
	if inventory_visible:
		toggle_inventory()

func _on_drink_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= player.inventory.items.size():
		return
	var item = player.inventory.items[selected_slot_index]
	if str(item.item_type) != "water":
		return
	player.held_index = selected_slot_index
	player._sync_held_item()
	player._drink_held_item()
	selected_slot_index = -1
	_close_context_menu()
	if inventory_visible:
		toggle_inventory()

func _on_store_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= player.inventory.items.size():
		return
	player.held_index = selected_slot_index
	if player.has_method("_store_held_item"):
		player._store_held_item()
	selected_slot_index = -1
	_close_context_menu()
	if inventory_visible:
		toggle_inventory()

func set_crosshair_rifle(active: bool) -> void:
	_crosshair_rifle_mode = active
	if crosshair_dot == null or crosshair_ring_h == null or crosshair_ring_v == null:
		pass # print("DEBUG CROSSHAIR RIFLE: null nodes dot=", crosshair_dot, " h=", crosshair_ring_h, " v=", crosshair_ring_v)
		return
	crosshair_dot.visible = not active
	if active:
		crosshair_ring_h.offset_left = -8
		crosshair_ring_h.offset_top = -1
		crosshair_ring_h.offset_right = 8
		crosshair_ring_h.offset_bottom = 1
		crosshair_ring_v.offset_left = -1
		crosshair_ring_v.offset_top = -8
		crosshair_ring_v.offset_right = 1
		crosshair_ring_v.offset_bottom = 8
		crosshair_ring_h.color = Color(0.96, 0.94, 0.84, 0.92)
		crosshair_ring_v.color = Color(0.96, 0.94, 0.84, 0.92)
	crosshair_ring_h.visible = active
	crosshair_ring_v.visible = active
	pass # print("DEBUG CROSSHAIR RIFLE: active=", active, " dot.visible=", crosshair_dot.visible, " h.visible=", crosshair_ring_h.visible, " v.visible=", crosshair_ring_v.visible, " h.pos=", crosshair_ring_h.position, " h.size=", crosshair_ring_h.size)
	_apply_aim_layout()
