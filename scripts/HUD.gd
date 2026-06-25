extends CanvasLayer
class_name HUD

const MiniMapScript = preload("res://scripts/MiniMap.gd")

var player
var day_cycle

var root: Control
var status_panel: PanelContainer
var inventory_panel: PanelContainer
var inventory_grid: GridContainer
var minimap
var inventory_weight_label: Label
var time_label: Label
var prompt_label: Label
var crosshair_dot: ColorRect
var crosshair_ring_h: ColorRect
var crosshair_ring_v: ColorRect
var notice_label: Label
var objective_label: Label
var equipment_hand_label: Label
var equipment_clothing_label: Label
var equipment_backpack_label: Label
var inventory_visible := false
var notice_timer := 0.0
var status_bars := {}

func setup(new_player, new_day_cycle) -> void:
	player = new_player
	day_cycle = new_day_cycle
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
	if notice_timer > 0.0:
		notice_timer -= delta
		if notice_timer <= 0.0:
			notice_label.text = ""

func toggle_inventory() -> void:
	inventory_visible = not inventory_visible
	if inventory_visible:
		inventory_panel.visible = true
		objective_label.visible = false
		inventory_panel.offset_transform_enabled = true
		var tw := create_tween()
		tw.tween_property(inventory_panel, "offset_transform_position:x", 0.0, 0.25).from(80.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.parallel().tween_property(inventory_panel, "offset_transform_scale", Vector2.ONE, 0.25).from(Vector2(0.92, 0.92)).set_ease(Tween.EASE_OUT)
	else:
		var tw2 := create_tween()
		tw2.tween_property(inventory_panel, "offset_transform_position:x", 80.0, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
		tw2.parallel().tween_property(inventory_panel, "modulate:a", 0.0, 0.2)
		await tw2.finished
		inventory_panel.visible = false
		inventory_panel.modulate.a = 1.0
		inventory_panel.offset_transform_position = Vector2.ZERO
		inventory_panel.offset_transform_scale = Vector2.ONE
		objective_label.visible = true

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
	_build_minimap()

func _build_minimap() -> void:
	minimap = MiniMapScript.new()
	minimap.name = "MiniMap"
	minimap.position = Vector2(1010, 18)
	minimap.size = Vector2(160, 160)
	minimap.setup(player)
	root.add_child(minimap)

func _build_status_panel() -> void:
	status_panel = PanelContainer.new()
	status_panel.position = Vector2(18, 530)
	status_panel.size = Vector2(250, 164)
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
	_create_status_bar(box, "energy", "ENERGIA", Color(0.72, 0.70, 0.46))
	_create_status_bar(box, "cold", "FRIO", Color(0.30, 0.58, 0.78))

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
		"energy":
			return "EN"
		"cold":
			return "T"
		_:
			return "?"

func _build_inventory_panel() -> void:
	inventory_panel = PanelContainer.new()
	inventory_panel.position = Vector2(250, 86)
	inventory_panel.size = Vector2(780, 548)
	inventory_panel.visible = inventory_visible
	inventory_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.020, 0.018, 0.91), Color(0.47, 0.49, 0.42, 0.52), 1))
	root.add_child(inventory_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	columns.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(columns)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(250, 420)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(left)
	_add_inventory_section_title(left, "EQUIPO")
	equipment_hand_label = _add_equipment_line(left, "Manos", "Vacio")
	equipment_clothing_label = _add_equipment_line(left, "Ropa", "Sin abrigo")
	equipment_backpack_label = _add_equipment_line(left, "Mochila", "Sin mochila")
	_add_equipment_line(left, "Objetivo", "Construir cabana")
	_add_inventory_hint(left)

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(480, 420)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	columns.add_child(right)
	_add_inventory_section_title(right, "MOCHILA")

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
	label.text = "Usa 1-9 para consumir/equipar ranuras.\nI o Tab abre/cierra la mochila."
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.64, 0.66, 0.59))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)

func _build_center_messages() -> void:
	objective_label = Label.new()
	objective_label.position = Vector2(18, 18)
	objective_label.size = Vector2(440, 54)
	objective_label.text = "OBJETIVO: recolecta madera, piedra, comida y abrigo. Construye una cabana."
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.add_theme_font_size_override("font_size", 15)
	objective_label.add_theme_color_override("font_color", Color(0.82, 0.84, 0.75))
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(objective_label)

	crosshair_ring_h = ColorRect.new()
	crosshair_ring_h.position = Vector2(728, 325)
	crosshair_ring_h.size = Vector2(16, 2)
	crosshair_ring_h.color = Color(0.86, 0.88, 0.82, 0.62)
	crosshair_ring_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_ring_h.visible = false
	root.add_child(crosshair_ring_h)

	crosshair_ring_v = ColorRect.new()
	crosshair_ring_v.position = Vector2(735, 318)
	crosshair_ring_v.size = Vector2(2, 16)
	crosshair_ring_v.color = Color(0.86, 0.88, 0.82, 0.62)
	crosshair_ring_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair_ring_v.visible = false
	root.add_child(crosshair_ring_v)

	crosshair_dot = ColorRect.new()
	crosshair_dot.position = Vector2(734, 324)
	crosshair_dot.size = Vector2(4, 4)
	crosshair_dot.color = Color(0.96, 0.94, 0.84, 0.92)
	crosshair_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(crosshair_dot)

	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(486, 348)
	prompt_label.size = Vector2(500, 40)
	prompt_label.add_theme_font_size_override("font_size", 18)
	prompt_label.add_theme_color_override("font_color", Color(0.94, 0.92, 0.82))
	prompt_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	prompt_label.add_theme_constant_override("shadow_offset_x", 1)
	prompt_label.add_theme_constant_override("shadow_offset_y", 1)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(prompt_label)

	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.position = Vector2(340, 52)
	notice_label.size = Vector2(600, 70)
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 19)
	notice_label.add_theme_color_override("font_color", Color(0.96, 0.86, 0.66))
	notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notice_label)

func _apply_aim_layout() -> void:
	if player == null or not player.has_method("get_aim_screen_offset"):
		return
	var center := Vector2(640.0, 360.0)
	var aim: Vector2 = center + player.get_aim_screen_offset()
	if crosshair_ring_h != null:
		crosshair_ring_h.position = aim - crosshair_ring_h.size * 0.5
	if crosshair_ring_v != null:
		crosshair_ring_v.position = aim - crosshair_ring_v.size * 0.5
	if crosshair_dot != null:
		crosshair_dot.position = aim - crosshair_dot.size * 0.5
	if prompt_label != null:
		prompt_label.position = aim + Vector2(-250.0, 24.0)

func _update_stats() -> void:
	if player == null or day_cycle == null:
		return
	time_label.text = "%s  |  %.1f / %.1f kg" % [
		day_cycle.get_hour_text(),
		player.inventory.get_total_weight(),
		player.inventory.max_weight
	]
	_set_bar("health", player.stats.health / player.stats.max_health, "%.0f" % player.stats.health)
	_set_bar("hunger", player.stats.hunger / player.stats.max_stat, "%.0f" % player.stats.hunger)
	_set_bar("thirst", player.stats.thirst / player.stats.max_stat, "%.0f" % player.stats.thirst)
	_set_bar("energy", player.stats.energy / player.stats.max_stat, "%.0f" % player.stats.energy)
	var cold_percent: float = clamp((36.6 - player.stats.body_temperature) / 3.0, 0.0, 1.0)
	_set_bar("cold", cold_percent, "%.1f C" % player.stats.body_temperature)
	if inventory_visible:
		_update_inventory()

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
	inventory_weight_label.text = "PESO %.1f / %.1f KG" % [player.inventory.get_total_weight(), player.inventory.max_weight]
	var slot_count: int = max(player.inventory.max_slots, 15)
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
		var clothing_text := "Sin abrigo"
		if not player.equipped_clothing.is_empty():
			clothing_text = player.equipped_clothing
		elif player.inventory.has_item_name("Chaqueta de abrigo"):
			clothing_text = "Chaqueta de abrigo"
		equipment_clothing_label.text = "Ropa\n%s" % clothing_text
	if equipment_backpack_label != null:
		var backpack_text := "Sin mochila"
		if not player.equipped_backpack.is_empty():
			backpack_text = player.equipped_backpack
		elif player.inventory.has_item_name("Mochila pequena"):
			backpack_text = "Mochila pequena"
		equipment_backpack_label.text = "Mochila\n%s" % backpack_text

func _create_inventory_slot(index: int, item) -> void:
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(86, 76)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.060, 0.055, 0.86), Color(0.25, 0.27, 0.23, 0.82), 1))
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
		"tool", "tool_axe", "tool_hoe", "tool_shovel", "tool_hammer", "tool_pickaxe":
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
