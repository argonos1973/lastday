extends CanvasLayer
class_name HUD

const CraftingSystemScript = preload("res://scripts/CraftingSystem.gd")
const HudIconScript = preload("res://scripts/HudIcon.gd")
const ItemThumbnail3DScript = preload("res://scripts/ItemThumbnail3D.gd")

var player
var day_cycle
var main_node = null
var _damage_overlay: ColorRect = null
var _damage_flash: float = 0.0
var _prev_health: float = 100.0

var root: Control
var status_panel: PanelContainer
var inventory_panel: PanelContainer
var inventory_grid: GridContainer
var inventory_weight_label: Label
var real_clock_label: Label
var survival_label: Label
var temp_label: Label
var _weather_timer := 0.0
var _weather_http: HTTPRequest
var _real_temp := "--"
var _real_temp_parsed := -999.0
var _weather_loading := false
var _weather_retry_timer := 0.0
var _real_weather_code := -1
var _real_rain := 0.0
var _real_snow := 0.0
var _real_weather_desc := ""
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
var status_icons := {}
var selected_slot_index := -1
var slot_action_label: Label = null
var _inv_refresh_timer := 0.0
var _debug_temp_timer := 0.0
var _context_menu: PanelContainer = null
var _context_menu_slot_index := -1
var _context_menu_recipes: Array = []
var _context_menu_has_eat := false
var _context_menu_has_light := false
var _context_menu_has_drink := false
var _context_menu_has_cut := false

func setup(new_player, new_day_cycle, new_main_node = null) -> void:
	player = new_player
	day_cycle = new_day_cycle
	main_node = new_main_node
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
	if _weather_timer >= 300.0:
		_weather_timer = 0.0
		_fetch_weather()
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

	_build_damage_overlay()
	_build_status_panel()
	_build_inventory_panel()
	_build_center_messages()
	_build_real_clock_panel()
	_add_shadows_recursive(root)

func _build_real_clock_panel() -> void:
	var panel := PanelContainer.new()
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = 250
	panel.offset_bottom = 108
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.07, 0.06, 0.88), Color(0.45, 0.48, 0.42, 0.7), 1))
	root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)

	real_clock_label = Label.new()
	real_clock_label.add_theme_font_size_override("font_size", 20)
	real_clock_label.add_theme_color_override("font_color", Color(0.95, 0.96, 0.90))
	real_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(real_clock_label)

	survival_label = Label.new()
	survival_label.add_theme_font_size_override("font_size", 13)
	survival_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.42))
	survival_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(survival_label)

	temp_label = Label.new()
	temp_label.add_theme_font_size_override("font_size", 14)
	temp_label.add_theme_color_override("font_color", Color(0.70, 0.74, 0.68))
	temp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(temp_label)

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
	var url := "https://api.open-meteo.com/v1/forecast?latitude=41.38&longitude=2.17&current=temperature_2m,weather_code,rain,snowfall&timezone=auto"
	var err := _weather_http.request(url, [], HTTPClient.METHOD_GET, "")
	if err != OK:
		_weather_loading = false

func _on_weather_received(result: int, _response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_weather_loading = false
	if result == HTTPRequest.RESULT_SUCCESS:
		var text := body.get_string_from_utf8().strip_edges()
		var json = JSON.new()
		if json.parse(text) == OK:
			var data: Dictionary = json.data
			if data.has("current"):
				var current: Dictionary = data["current"]
				if current.has("temperature_2m"):
					var temp: float = float(current["temperature_2m"])
					_real_temp = "%.0f°C" % temp
					_real_temp_parsed = temp
				if current.has("weather_code"):
					_real_weather_code = int(current["weather_code"])
					_real_weather_desc = _weather_code_to_desc(_real_weather_code)
				if current.has("rain"):
					_real_rain = float(current["rain"])
				if current.has("snowfall"):
					_real_snow = float(current["snowfall"])
				return
		_real_temp = "N/A"
		_weather_retry_timer = 15.0
	else:
		_real_temp = "N/A"
		_weather_retry_timer = 15.0

func _weather_code_to_desc(code: int) -> String:
	if code == 0: return "Despejado"
	if code <= 3: return "Parcialmente nublado"
	if code in [45, 48]: return "Niebla"
	if code in [51, 53, 55]: return "Llovizna"
	if code in [56, 57]: return "Llovizna helada"
	if code in [61, 63, 65]: return "Lluvia"
	if code in [66, 67]: return "Lluvia helada"
	if code in [71, 73, 75]: return "Nieve"
	if code == 77: return "Granizo"
	if code in [80, 81, 82]: return "Aguaceros"
	if code in [85, 86]: return "Aguaceros de nieve"
	if code == 95: return "Tormenta"
	if code in [96, 99]: return "Tormenta con granizo"
	return "Nublado"

func _update_real_clock() -> void:
	if real_clock_label == null or player == null or player.stats == null or day_cycle == null:
		return
	var day_num: int = player.stats.get_survival_days() + 1 if player.stats.has_method("get_survival_days") else 1
	real_clock_label.text = "DIA %d - %s" % [day_num, day_cycle.get_hour_text()]
	if survival_label != null:
		var survival_seconds: float = player.stats.survival_seconds if "survival_seconds" in player.stats else 0.0
		var total_seconds: int = int(survival_seconds)
		var hrs: int = total_seconds / 3600
		var mins: int = (total_seconds / 60) % 60
		var secs: int = total_seconds % 60
		survival_label.text = "Supervivencia: %02d:%02d:%02d" % [hrs, mins, secs]
	if temp_label != null:
		if _real_weather_desc != "":
			temp_label.text = "Temp: %s | %s" % [_real_temp, _real_weather_desc]
		else:
			temp_label.text = "Temp: %s" % _real_temp

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
	status_panel.offset_top = -70
	status_panel.offset_bottom = 0
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.07, 0.06, 0.88), Color(0.45, 0.48, 0.42, 0.7), 1))
	root.add_child(status_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.add_child(row)

	_add_vital_icon(row, "health", "heart", true)
	_add_vital_icon(row, "hunger", "apple", true)
	_add_vital_icon(row, "thirst", "drop", true)
	_add_vital_icon(row, "temp", "thermometer", true)
	_add_vital_icon(row, "energy", "bolt", true)
	_add_vital_icon(row, "sleep", "bed", true)
	_add_vital_icon(row, "sick", "warning", false)

func _add_vital_icon(parent: HBoxContainer, key: String, shape: String, always_visible: bool) -> void:
	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size = Vector2(34, 48)
	wrapper.visible = always_visible
	wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrapper.add_theme_constant_override("separation", 2)
	parent.add_child(wrapper)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(34, 34)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var neutral := Color(0.32, 0.35, 0.31)
	panel.add_theme_stylebox_override("panel", _panel_style(neutral.darkened(0.55), neutral, 1))
	wrapper.add_child(panel)
	var icon := HudIconScript.new()
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_shape(shape)
	icon.set_icon_color(Color(0.92, 0.94, 0.88))
	panel.add_child(icon)
	# Level bar below the icon
	var bar_bg := Control.new()
	bar_bg.custom_minimum_size = Vector2(30, 6)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.clip_contents = true
	var bar_bg_style := PanelContainer.new()
	bar_bg_style.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg_style.add_theme_stylebox_override("panel", _panel_style(Color(0.05, 0.05, 0.05, 0.9), Color(0.2, 0.2, 0.2, 0.6), 1))
	bar_bg_style.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.add_child(bar_bg_style)
	wrapper.add_child(bar_bg)
	var bar_fill := ColorRect.new()
	bar_fill.custom_minimum_size = Vector2(0, 6)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_fill.color = Color(0.32, 0.35, 0.31)
	bar_fill.size = Vector2(30, 6)
	bar_bg.add_child(bar_fill)
	status_icons[key] = {"panel": panel, "icon": icon, "always": always_visible, "wrapper": wrapper, "bar_fill": bar_fill, "bar_bg": bar_bg}

func _tier_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color(0.32, 0.35, 0.31)
	elif ratio > 0.3:
		return Color(0.78, 0.55, 0.10)
	else:
		return Color(0.80, 0.12, 0.10)

func _temp_color(ratio: float, is_hot: bool) -> Color:
	# ratio: 0.0 = freezing (33°C), 0.514 = normal (36.6°C), 1.0 = overheating (40°C)
	if ratio > 0.45 and ratio < 0.58:
		return Color(0.32, 0.35, 0.31)
	if is_hot:
		if ratio < 0.75:
			return Color(0.90, 0.45, 0.08)
		return Color(0.95, 0.15, 0.05)
	else:
		if ratio > 0.25:
			return Color(0.15, 0.45, 0.85)
		return Color(0.05, 0.20, 0.70)

func _tier_bar_color(ratio: float) -> Color:
	if ratio > 0.6:
		return Color.WHITE
	elif ratio > 0.3:
		return Color(0.78, 0.55, 0.10)
	else:
		return Color(0.80, 0.12, 0.10)

func _overfull_bar_color(count: int) -> Color:
	if count >= 2:
		return Color(0.6, 0.1, 0.6)
	else:
		return Color(0.6, 0.4, 0.8)

func _set_vital_icon_color(key: String, color: Color) -> void:
	if not status_icons.has(key):
		return
	var panel := status_icons[key]["panel"] as PanelContainer
	panel.add_theme_stylebox_override("panel", _panel_style(color.darkened(0.65), color, 2))

func _set_vital_bar(key: String, ratio: float) -> void:
	if not status_icons.has(key):
		return
	if not status_icons[key].has("bar_fill"):
		return
	var bar_fill: ColorRect = status_icons[key]["bar_fill"]
	var bar_bg: Control = status_icons[key]["bar_bg"]
	bar_fill.color = _tier_bar_color(ratio)
	var max_w: float = bar_bg.size.x
	if max_w <= 0.0:
		max_w = 30.0
	bar_fill.size.x = max_w * clamp(ratio, 0.0, 1.0)

func _set_vital_bar_color(key: String, color: Color) -> void:
	if not status_icons.has(key):
		return
	if not status_icons[key].has("bar_fill"):
		return
	var bar_fill: ColorRect = status_icons[key]["bar_fill"]
	var bar_bg: Control = status_icons[key]["bar_bg"]
	bar_fill.color = color
	var max_w: float = bar_bg.size.x
	if max_w <= 0.0:
		max_w = 30.0
	bar_fill.size.x = max_w

func _update_status_icons() -> void:
	if player == null or player.stats == null:
		return
	var stats = player.stats
	var health_ratio: float = float(stats.health) / float(stats.max_health)
	var hunger_ratio: float = float(stats.hunger) / float(stats.max_stat)
	var thirst_ratio: float = float(stats.thirst) / float(stats.max_stat)
	var temp_ratio: float = clamp((stats.body_temperature - 33.0) / 7.0, 0.0, 1.0)
	var temp_is_hot: bool = stats.body_temperature > 36.6
	var energy_ratio: float = float(stats.energy) / float(stats.max_stat)
	var sleep_ratio: float = float(stats.sleep) / float(stats.max_stat)
	_set_vital_icon_color("health", _tier_color(health_ratio))
	var hunger_overfull: bool = int(stats.overeat_count) > 0
	var thirst_overfull: bool = int(stats.overdrink_count) > 0
	if hunger_overfull:
		_set_vital_icon_color("hunger", _overfull_bar_color(int(stats.overeat_count)))
	else:
		_set_vital_icon_color("hunger", _tier_color(hunger_ratio))
	if thirst_overfull:
		_set_vital_icon_color("thirst", _overfull_bar_color(int(stats.overdrink_count)))
	else:
		_set_vital_icon_color("thirst", _tier_color(thirst_ratio))
	_set_vital_icon_color("temp", _temp_color(temp_ratio, temp_is_hot))
	_set_vital_icon_color("energy", _tier_color(energy_ratio))
	_set_vital_icon_color("sleep", _tier_color(sleep_ratio))
	if status_icons.has("sick"):
		status_icons["sick"]["wrapper"].visible = bool(stats.sick)
		_set_vital_icon_color("sick", Color(0.80, 0.12, 0.10))
	# Update level bars
	_set_vital_bar("health", health_ratio)
	if hunger_overfull:
		_set_vital_bar_color("hunger", _overfull_bar_color(int(stats.overeat_count)))
	else:
		_set_vital_bar("hunger", hunger_ratio)
	if thirst_overfull:
		_set_vital_bar_color("thirst", _overfull_bar_color(int(stats.overdrink_count)))
	else:
		_set_vital_bar("thirst", thirst_ratio)
	_set_vital_bar_color("temp", _temp_color(temp_ratio, temp_is_hot))
	_set_vital_bar("temp", temp_ratio)
	_set_vital_bar("energy", energy_ratio)
	_set_vital_bar("sleep", sleep_ratio)
	if status_icons.has("sick") and bool(stats.sick):
		_set_vital_bar("sick", 1.0)

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
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.07, 0.08, 0.07, 0.95), Color(0.50, 0.52, 0.45, 0.75), 1))
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
	_update_status_icons()
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
	slot.custom_minimum_size = Vector2(96, 86)
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
	thumbnail.custom_minimum_size = Vector2(56, 48)
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var thumb_fill := Color(0.075, 0.080, 0.072, 0.86)
	var thumb_border := Color(0.22, 0.24, 0.20, 0.72)
	if item != null:
		thumb_fill = _item_thumbnail_color(item)
		thumb_border = thumb_fill.lightened(0.28)
	thumbnail.add_theme_stylebox_override("panel", _panel_style(thumb_fill, thumb_border, 1))
	top_row.add_child(thumbnail)

	if item != null:
		var model_paths: Array = []
		var model_scale: float = 1.0
		if main_node != null and main_node.has_method("_get_drop_model_paths"):
			model_paths = main_node._get_drop_model_paths(item.item_name, item.item_type)
			model_scale = main_node._get_drop_scale(item.item_name, item.item_type)
		if not model_paths.is_empty():
			var thumb3d := ItemThumbnail3DScript.new()
			thumb3d.custom_minimum_size = Vector2(48, 42)
			thumb3d.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumbnail.add_child(thumb3d)
			thumb3d.set_model(model_paths, model_scale)
		else:
			var thumb_icon := HudIconScript.new()
			thumb_icon.custom_minimum_size = Vector2(36, 30)
			thumb_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			thumb_icon.set_shape(_item_icon_shape(item))
			thumb_icon.set_icon_color(_item_thumbnail_color(item))
			thumbnail.add_child(thumb_icon)

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
		if (item.item_name == "Botella de agua" or item.item_name == "Botella de agua llena") and item.has_method("durability_pct"):
			var wpct := int(item.durability_pct() * 100.0)
			label.text += "\nAgua: %d%%" % wpct
			if wpct < 25:
				label.add_theme_color_override("font_color", Color(0.96, 0.40, 0.30))
			elif wpct < 50:
				label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
		elif item.item_name.begins_with("Lata de ") and item.item_name.ends_with(" abierta") and item.has_method("durability_pct"):
			var cpct := int(item.durability_pct() * 100.0)
			label.text += "\nComida: %d%%" % cpct
			if cpct < 25:
				label.add_theme_color_override("font_color", Color(0.96, 0.40, 0.30))
			elif cpct < 50:
				label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
		elif item.has_method("durability_pct") and item.item_type != "food" and item.item_type != "water":
			var pct := int(item.durability_pct() * 100.0)
			if pct < 100:
				label.text += "\n%d%%" % pct
				if pct < 25:
					label.add_theme_color_override("font_color", Color(0.96, 0.40, 0.30))
				elif pct < 50:
					label.add_theme_color_override("font_color", Color(0.92, 0.78, 0.30))
		if item.has_method("is_perishable") and item.is_perishable():
			label.text += "\n[%s]" % item.spoil_state_label()
			label.add_theme_color_override("font_color", item.spoil_state_color())
	box.add_child(label)

func _item_thumbnail_color(item) -> Color:
	if str(item.item_type) == "clothing" and item.has_meta("clothing_color"):
		var c: Color = item.get_meta("clothing_color")
		if c.a > 0.0:
			return c
	if item.item_name == "Naranja":
		return Color(1.0, 0.5, 0.05)
	if item.item_name == "Higo":
		return Color(0.35, 0.2, 0.08)
	match str(item.item_type):
		"food":
			return Color(0.50, 0.20, 0.08)
		"water":
			return Color(0.10, 0.32, 0.52)
		"medical":
			return Color(0.62, 0.16, 0.12)
		"weapon", "weapon_rifle":
			return Color(0.32, 0.32, 0.30)
		"tool", "tool_axe", "tool_hoe", "tool_shovel", "tool_hammer", "tool_pickaxe":
			return Color(0.36, 0.27, 0.12)
		"clothing":
			return Color(0.16, 0.22, 0.12)
		"backpack":
			return Color(0.08, 0.13, 0.07)
		"resource", "material":
			return Color(0.24, 0.15, 0.07)
		"seed":
			return Color(0.22, 0.36, 0.10)
		"battery":
			return Color(0.12, 0.12, 0.10)
		"tool_spear":
			return Color(0.38, 0.26, 0.10)
		"tool_fishing":
			return Color(0.30, 0.22, 0.08)
		"tool_matches":
			return Color(0.30, 0.16, 0.06)
		"tool_torch":
			return Color(0.34, 0.20, 0.08)
		"campfire":
			return Color(0.20, 0.12, 0.04)
		"shelter":
			return Color(0.14, 0.16, 0.10)
		_:
			return Color(0.18, 0.18, 0.16)

func _item_icon_shape(item) -> String:
	if item.item_name == "Naranja":
		return "circle"
	if item.item_name == "Higo":
		return "pear"
	match str(item.item_type):
		"food":
			return "apple"
		"water":
			return "drop"
		"medical":
			return "cross"
		"weapon", "weapon_rifle":
			return "gun"
		"tool_axe":
			return "axe"
		"tool_hammer":
			return "hammer"
		"tool_pickaxe":
			return "pickaxe"
		"tool_shovel", "tool_hoe":
			return "shovel"
		"tool_spear":
			return "spear"
		"tool_fishing":
			return "fishing"
		"tool_matches":
			return "match"
		"tool_torch":
			return "torch"
		"clothing":
			return "shirt"
		"backpack":
			return "backpack"
		"resource", "material":
			return "log"
		"seed":
			return "seed"
		"battery":
			return "battery"
		"campfire":
			return "flame"
		"shelter":
			return "tent"
		_:
			return "box"

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

func _build_damage_overlay() -> void:
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

func _add_shadows_recursive(node: Node) -> void:
	if node is Label:
		var label := node as Label
		label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 1)
	for child in node.get_children():
		_add_shadows_recursive(child)

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
	_context_menu_has_light = false
	_context_menu_has_cut = false
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
	# Add Encender button for torch when matches or 2 palos are available (only if not already lit)
	if str(item.item_type) == "tool_torch":
		var torch_already_lit: bool = item.has_meta("torch_lit") and bool(item.get_meta("torch_lit", false))
		if not torch_already_lit:
			var has_matches: bool = player.inventory.has_item_name("Cerillas")
			var has_sticks: bool = player.inventory.has_item_name("Palo", 2)
			if has_matches or has_sticks:
				var light_btn := Button.new()
				if has_matches:
					light_btn.text = "Encender con cerillas"
				else:
					light_btn.text = "Encender con 2 palos (8s)"
				light_btn.add_theme_font_size_override("font_size", 14)
				light_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
				vbox.add_child(light_btn)
				_context_menu_has_light = true
	# Add Cortar en trapos button for clothing when holding knife/axe
	if str(item.item_type) == "clothing" and item.item_name != "Zapatillas" and item.item_name != "Botas survival":
		var has_knife := false
		for _inv_i in player.inventory.items:
			if _inv_i.item_name == "Cuchillo" or _inv_i.item_name == "Hacha":
				has_knife = true
				break
		if has_knife:
			var cut_btn := Button.new()
			cut_btn.text = "Cortar en trapos"
			cut_btn.add_theme_font_size_override("font_size", 14)
			cut_btn.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(cut_btn)
			_context_menu_has_cut = true
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
	var item_type := str(item.item_type)
	var recipes := CraftingSystemScript.get_recipes_for_item(item_name, item_type)
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
		var light_index := -1
		if _context_menu_has_drink:
			drink_index = idx
			idx += 1
		if _context_menu_has_eat:
			eat_index = idx
			idx += 1
		if _context_menu_has_light:
			light_index = idx
			idx += 1
		var cut_index := -1
		if _context_menu_has_cut:
			cut_index = idx
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
			if light_index >= 0:
				var light_btn = vbox.get_child(light_index)
				if light_btn is Button and light_btn.get_global_rect().has_point(mouse_pos):
					_on_light_torch_pressed()
					return true
			if cut_index >= 0:
				var cut_btn = vbox.get_child(cut_index)
				if cut_btn is Button and cut_btn.get_global_rect().has_point(mouse_pos):
					_on_cut_clothing_pressed()
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

func _on_cut_clothing_pressed() -> void:
	if player == null or player.inventory == null:
		return
	if _context_menu_slot_index < 0 or _context_menu_slot_index >= player.inventory.items.size():
		return
	var item = player.inventory.items[_context_menu_slot_index]
	var item_name := str(item.item_name)
	# Find the cut recipe for this clothing item
	var recipes := CraftingSystemScript.get_recipes_for_item(item_name, str(item.item_type))
	for recipe in recipes:
		if recipe["inputs"].has(item_name) and recipe["output"]["name"] == "Trapos":
			selected_slot_index = -1
			_close_context_menu()
			if inventory_visible:
				toggle_inventory()
			if player.has_method("craft_recipe"):
				player.craft_recipe(recipe)
			return

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
	var was_in_hand: bool = player.held_index == selected_slot_index and player.hands != null and player.hands.has_item_in_hands()
	player._use_inventory_index(selected_slot_index)
	if not was_in_hand and player.held_index == selected_slot_index and player.has_method("_eat_held_item"):
		player._eat_held_item()
	selected_slot_index = -1

func _on_light_torch_pressed() -> void:
	if selected_slot_index < 0 or selected_slot_index >= player.inventory.items.size():
		return
	player.held_index = selected_slot_index
	player._sync_held_item()
	_close_context_menu()
	if inventory_visible:
		toggle_inventory()
	player._toggle_flashlight()
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
