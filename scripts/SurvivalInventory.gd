extends PanelContainer

const Card = preload("res://scripts/InventoryCard.gd")
const Cargo = preload("res://scripts/InventoryCargo.gd")
const WorldActions = preload("res://scripts/WorldAction.gd")
const Crafting = preload("res://scripts/CraftingSystem.gd")
var hud
var player
var vicinity: VBoxContainer
var equipment: VBoxContainer
var cargo: VBoxContainer
var weight: Label
var search: LineEdit
var menu: PopupMenu
var actions: Array[Callable] = []
var split_dialog: ConfirmationDialog
var split_amount: SpinBox
var split_item
var collapsed_compartments: Dictionary = {}
var signature := ""
var selected_filter := "all"
var refresh_pending := false
var _vicinity_timer := 0.0
var portrait: SubViewportContainer
var portrait_signature := ""
var portrait_focus := Vector3.ZERO
var portrait_yaw := 0.5
var portrait_dragging := false
const PICKUPS := ["pickup_item", "axe_tool", "hoe_tool", "shovel_tool", "hammer_tool", "pickaxe_tool", "matches_tool", "backpack_pickup", "coat", "eat_food", "wood", "stone", "wolf_meat_raw", "bird_meat_raw", "pickup_torch"]

func setup(owner_hud) -> void:
	hud = owner_hud
	player = hud.player
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = 24
	offset_right = -24
	offset_top = 70
	offset_bottom = -65
	add_theme_stylebox_override("panel", style(Color(0.035, 0.042, 0.039, 0.96)))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	add_child(layout)
	var bar := HBoxContainer.new()
	layout.add_child(bar)
	var title := text_label("INVENTARIO", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title)
	weight = text_label("", 16)
	bar.add_child(weight)
	var close := Button.new()
	close.text = "CERRAR  [TAB]"
	close.pressed.connect(hud.toggle_inventory)
	bar.add_child(close)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	layout.add_child(columns)
	vicinity = column(columns, "CERCANÍA", 0.8)
	equipment = column(columns, "SUPERVIVIENTE / EQUIPO", 0.9)
	var right := column(columns, "ALMACENAMIENTO", 1.5)
	search = LineEdit.new()
	search.placeholder_text = "Buscar objeto…"
	search.text_changed.connect(func(_value): request_refresh(true))
	right.add_child(search)
	var filters := OptionButton.new()
	for label in ["Todos los objetos", "Comida", "Agua", "Herramientas", "Armas", "Ropa", "Materiales", "Medicina"]:
		filters.add_item(label)
	filters.item_selected.connect(func(index):
		selected_filter = ["all", "food", "water", "tool", "weapon", "clothing", "resource", "medical"][index]
		request_refresh(true))
	right.add_child(filters)
	cargo = VBoxContainer.new()
	right.add_child(cargo)
	var footer := text_label("ARRASTRAR  mover / combinar     DOBLE CLIC  coger / usar     CLIC DERECHO  acciones", 13)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(footer)
	menu = PopupMenu.new()
	add_child(menu)
	menu.id_pressed.connect(func(id):
		if id >= 0 and id < actions.size():
			actions[id].call()
		request_refresh(true))
	split_dialog = ConfirmationDialog.new()
	split_dialog.title = "Separar pila"
	split_dialog.ok_button_text = "Separar"
	split_dialog.cancel_button_text = "Cancelar"
	var split_layout := VBoxContainer.new()
	split_layout.add_child(text_label("Unidades para la nueva pila", 16))
	split_amount = SpinBox.new()
	split_amount.min_value = 1
	split_amount.step = 1
	split_amount.custom_minimum_size.x = 280
	split_layout.add_child(split_amount)
	split_dialog.add_child(split_layout)
	add_child(split_dialog)
	split_dialog.confirmed.connect(func():
		if not player.inventory.split_stack(split_item, int(split_amount.value)):
			player.notice.emit("No se puede separar: revisa la cantidad y el espacio libre.")
		split_item = null
		request_refresh(true))
	visibility_changed.connect(func():
		if not visible:
			menu.hide()
			split_dialog.hide()
			split_item = null
		else:
			portrait_signature = ""
			request_refresh(true))
	request_refresh(true)

func style(color: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = color
	result.set_border_width_all(1)
	result.border_color = Color(0.28, 0.31, 0.28)
	result.set_content_margin_all(10)
	return result

func text_label(value: String, font_size := 14) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func column(parent: Control, title: String, ratio: float) -> VBoxContainer:
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.size_flags_stretch_ratio = ratio
	parent.add_child(outer)
	outer.add_child(text_label(title, 17))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 8)
	scroll.add_child(contents)
	return contents

func _process(delta: float) -> void:
	if not visible:
		return
	_vicinity_timer += delta
	if _vicinity_timer >= 0.7:
		_vicinity_timer = 0.0
		request_refresh()

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_pressed() and event.keycode == KEY_ESCAPE:
		hud.toggle_inventory()
		get_viewport().set_input_as_handled()

func request_refresh(force := false) -> void:
	if force:
		signature = ""
	if not refresh_pending:
		refresh_pending = true
		call_deferred("refresh")

func nearby() -> Array:
	var result: Array = []
	for action in WorldActions.get_nearby_interactables(player.global_position, 2.0):
		if reachable(action):
			result.append(action)
	result.sort_custom(func(a, b): return player.global_position.distance_squared_to(a.global_position) < player.global_position.distance_squared_to(b.global_position))
	return result

func reachable(action) -> bool:
	if not is_instance_valid(action) or action.is_queued_for_deletion() or action.depleted or action.action_type not in PICKUPS or bool(action.get_meta("no_pickup", false)):
		return false
	if player.global_position.distance_to(action.global_position) > 2.0:
		return false
	# Do not collect through walls or the floor above/below the player.
	var query := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, action.global_position + Vector3.UP * 0.1)
	query.exclude = [player.get_rid()]
	var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == action

func refresh() -> void:
	refresh_pending = false
	if not visible or menu.visible or split_dialog.visible or get_viewport().gui_is_dragging():
		return
	var ground := nearby()
	var state := str(player.inventory.to_array()) + str(player._equipped_slots) + str(player.get_held_item()) + str(player.equipped_backpack)
	for slot in range(2):
		state += str(player.get_back_item_data(slot))
	for action in ground:
		state += str(action.get_instance_id())
	state += search.text + selected_filter
	if state == signature:
		return
	signature = state
	# Keep the character preview alive while cargo/search changes.
	if portrait != null and portrait.get_parent() == equipment:
		equipment.remove_child(portrait)
	for parent in [vicinity, equipment, cargo]:
		for child in parent.get_children():
			parent.remove_child(child)
			child.queue_free()
	var carry_weight: float = player._get_total_carry_weight() if player.has_method("_get_total_carry_weight") else player.inventory.get_total_weight()
	weight.text = "%.1f / %.1f kg · %d / %d espacios" % [carry_weight, player.inventory.max_weight, player.inventory.items.size(), player.inventory.max_slots]
	var floor_card = make_card("Soltar al suelo", {}, "ground")
	floor_card.tooltip_text = "Arrastra aquí para soltar una unidad. Alcance de recogida: 2 m."
	vicinity.add_child(floor_card)
	for action in ground:
		vicinity.add_child(make_card(action.display_name, {"world": action, "label": action.display_name}, ""))
	if ground.is_empty():
		vicinity.add_child(text_label("No hay objetos al alcance."))
	var held = player.get_held_item()
	update_portrait()
	if portrait != null:
		equipment.add_child(portrait)
	equipment.add_child(text_label("MANOS", 16))
	equipment.add_child(make_card("Manos libres" if held == null else item_text(held), {} if held == null else {"item": held, "label": held.item_name}, "hands"))
	if held != null:
		button(equipment, "Guardar", func(): player._store_held_item(); request_refresh(true))
	equipment.add_child(text_label("EQUIPAMIENTO", 16))
	var equip_zone = make_card("Equipar", {}, "equipment")
	equip_zone.tooltip_text = "Arrastra ropa o una mochila aquí para equiparla."
	equipment.add_child(equip_zone)
	var equipment_grid := GridContainer.new()
	equipment_grid.columns = 2
	equipment.add_child(equipment_grid)
	for slot in ["head", "torso", "hands", "legs", "feet", "backpack"]:
		var names := {"head": "Cabeza", "torso": "Torso", "hands": "Guantes", "legs": "Piernas", "feet": "Pies", "backpack": "Mochila"}
		var name: String = player.equipped_backpack if slot == "backpack" else str(player._equipped_slots.get(slot, ""))
		var item = find_item(name)
		equipment_grid.add_child(make_card(names[slot] if item == null else name, {} if item == null else {"item": item, "label": name}, "equip:" + slot))
	for slot in range(2):
		var data: Dictionary = player.get_back_item_data(slot)
		button(equipment, "Hombro %d · %s" % [slot + 1, data.get("name", "Vacío")], func(): player.use_back_item(slot); request_refresh(true))
	var containers := Cargo.compartments(player)
	var groups := Cargo.arrange(player.inventory.items, containers)
	if groups.has("overflow"):
		containers.append({"id": "overflow", "name": "SIN ESPACIO", "capacity": groups.overflow.size()})
	for container in containers:
		var items: Array = groups[container.id]
		var folded: bool = bool(collapsed_compartments.get(container.id, false)) and search.text.is_empty() and selected_filter == "all"
		var header = make_card("%s  %s   %d / %d" % ["▸" if folded else "▾", container.name, items.size(), container.capacity], {}, container.id)
		header.set_meta("compartment_header", container.id)
		header.tooltip_text = "Clic: plegar / desplegar. Arrastra aquí para guardar."
		cargo.add_child(header)
		if folded:
			continue
		var grid := GridContainer.new()
		grid.columns = 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cargo.add_child(grid)
		for item in items:
			if matches_filter(item):
				grid.add_child(make_card(item_text(item), {"item": item, "label": item.item_name}, container.id))
		if items.size() < container.capacity:
			var free_slot = make_card("+", {}, container.id)
			free_slot.tooltip_text = "Espacio libre: arrastra un objeto aquí."
			grid.add_child(free_slot)

func toggle_compartment(id: String) -> void:
	collapsed_compartments[id] = not bool(collapsed_compartments.get(id, false))
	request_refresh(true)

func item_text(item) -> String:
	var state: String = "EN MANOS · " if player.get_held_item() == item else ""
	if player._equipped_slots.values().has(item.item_name) or item.item_name == player.equipped_backpack:
		state += "EQUIPADO · "
	return "%s%s\nx%d · %.2f kg · %d%%" % [state, item.item_name, item.quantity, item.weight * item.quantity, item.durability_pct() * 100]

func matches_filter(item) -> bool:
	if not search.text.is_empty() and not search.text.to_lower() in item.item_name.to_lower():
		return false
	if selected_filter == "all":
		return true
	if selected_filter == "resource":
		return item.item_type in ["resource", "material", "misc", "seed", "battery"]
	if selected_filter == "clothing":
		return item.item_type in ["clothing", "backpack"]
	return str(item.item_type).begins_with(selected_filter)

func make_card(title: String, payload: Dictionary, destination: String):
	var card = Card.new()
	card.screen = self
	card.payload = payload
	card.destination = destination
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 32)
	var panel := style(Color(0.085, 0.10, 0.09, 0.95))
	panel.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", panel)
	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(details)
	var item = payload.get("item")
	if payload.has("world"):
		var action = payload.world
		var types := {"pickup_torch": "tool_torch", "backpack_pickup": "backpack", "wolf_meat_raw": "food", "bird_meat_raw": "food", "axe_tool": "tool_axe", "hoe_tool": "tool_hoe", "shovel_tool": "tool_shovel", "hammer_tool": "tool_hammer", "pickaxe_tool": "tool_pickaxe", "matches_tool": "tool_matches"}
		var type: String = types.get(action.action_type, str(action.get_meta("item_type", "resource")))
		var name: String = {"wood": "Tronco", "stone": "Piedra"}.get(action.action_type, str(action.get_meta("item_name", action.display_name)))
		item = preload("res://scripts/Item.gd").create(name, type, float(action.get_meta("item_weight", 0.0)), int(action.get_meta("item_quantity", 1)))
		if action.has_meta("item_color"):
			item.set_meta("clothing_color", action.get_meta("item_color"))
	if item != null:
		card.custom_minimum_size.x = 96
		var image := Control.new()
		image.custom_minimum_size.y = 78
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		details.add_child(image)
		add_item_thumbnail(image, item)
		if item.quantity > 1:
			var quantity := text_label("×%d" % item.quantity, 13)
			quantity.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
			quantity.grow_horizontal = Control.GROW_DIRECTION_BEGIN
			image.add_child(quantity)
		if payload.has("item") and (player.get_held_item() == item or player._equipped_slots.values().has(item.item_name) or player.equipped_backpack == item.item_name):
			panel.border_color = Color(0.65, 0.74, 0.43)
	var label := text_label(str(item.item_name) if item != null else title, 12 if item != null else 13)
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if item != null else HORIZONTAL_ALIGNMENT_LEFT
	details.add_child(label)
	if payload.has("item"):
		var condition := ProgressBar.new()
		condition.custom_minimum_size.y = 3
		condition.show_percentage = false
		condition.value = item.durability_pct() * 100.0
		condition.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var background := StyleBoxFlat.new()
		background.bg_color = Color(0.14, 0.15, 0.14)
		condition.add_theme_stylebox_override("background", background)
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.52, 0.62, 0.34) if condition.value > 50 else Color(0.77, 0.48, 0.25)
		condition.add_theme_stylebox_override("fill", fill)
		details.add_child(condition)
	card.tooltip_text = (item_text(item) if payload.has("item") else title) + "\nDoble clic: usar · Clic derecho: opciones"
	return card

func add_item_thumbnail(parent: Control, item) -> void:
	var thumbnail = preload("res://scripts/ItemThumbnail3D.gd").new()
	thumbnail.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	thumbnail.ready.connect(func():
		var paths: Array = []
		var scale_value := 1.0
		if hud.main_node != null and hud.main_node.has_method("_get_drop_model_paths"):
			paths = hud.main_node._get_drop_model_paths(item.item_name, item.item_type)
			scale_value = hud.main_node._get_drop_scale(item.item_name, item.item_type)
		if item.item_name == "Trapos":
			paths = []
		var colors: Dictionary = hud._clothing_thumbnail_colors(item) if item.item_type == "clothing" else {"tint": Color.TRANSPARENT, "camo": Color.TRANSPARENT}
		var only_mesh := "shoes" if item.item_name == "Botas survival" else ""
		if not only_mesh.is_empty():
			colors.tint = Color(0.05, 0.05, 0.05)
		thumbnail.set_model(paths, scale_value, Vector3.ZERO, 1.0, only_mesh, colors.tint, colors.camo)
		if paths.is_empty() and item.item_name == "Trapos":
			var mesh := MeshInstance3D.new()
			var cylinder := CylinderMesh.new()
			cylinder.top_radius = 0.25
			cylinder.bottom_radius = 0.25
			cylinder.height = 0.06
			mesh.mesh = cylinder
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.9, 0.85, 0.7)
			mesh.material_override = material
			thumbnail._model_root.add_child(mesh)
			thumbnail._frame_camera(mesh)
		thumbnail._viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		thumbnail.resized.connect(func(): thumbnail._viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)
	, CONNECT_ONE_SHOT)
	parent.add_child(thumbnail)

func update_portrait() -> void:
	if player.third_person_model == null:
		return
	var held = player.get_held_item()
	var current: String = str(player.third_person_model.get_instance_id()) + str(player._equipped_slots) + player.equipped_backpack + str(player.inventory.to_array())
	current += str(held.to_dict()) if held != null else ""
	for slot in range(2):
		current += str(player.get_back_item_data(slot))
	if portrait != null and portrait_signature == current:
		return
	if portrait != null:
		portrait.queue_free()
	portrait_signature = current
	portrait = preload("res://scripts/ItemThumbnail3D.gd").new()
	portrait.custom_minimum_size = Vector2(0, 290)
	equipment.add_child(portrait)
	portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	portrait.tooltip_text = "Arrastra para girar y ver el equipo."
	portrait.gui_input.connect(_portrait_input)
	var model: Node3D = player.third_person_model.duplicate(0)
	model.process_mode = Node.PROCESS_MODE_DISABLED
	# Conserva los accesorios en tiempo real (sockets de manos/espalda,
	# attachments de rifle y overlays de caña), sin usarlos para encuadrar.
	# Solo se retiran luces y colisiones del duplicado del retrato.
	# El cuerpo, la ropa y el equipo mantienen su estado visual real.
	var removable: Array = []
	for node in model.find_children("*", "", true, false):
		if node is Light3D or node is CollisionObject3D:
			removable.append(node)
	for node in removable:
		if is_instance_valid(node) and node.get_parent() != null:
			node.get_parent().remove_child(node)
			node.free()
	portrait._model_root.add_child(model)
	model.rotation = Vector3.ZERO
	model.visible = true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1
	# Los meshes del personaje son skinned: su AABB estatico esta en escala
	# centimetros y _frame_camera no sirve. El encuadre sale de la pose real
	# de los huesos del esqueleto.
	var box := AABB()
	var first_bone := true
	var skel: Skeleton3D = player._find_skeleton(model)
	if skel != null:
		for i in range(skel.get_bone_count()):
			var bone_pos: Vector3 = skel.to_global(skel.get_bone_global_pose(i).origin)
			if first_bone:
				box = AABB(bone_pos, Vector3.ZERO)
				first_bone = false
			else:
				box = box.expand(bone_pos)
	var cam: Camera3D = portrait._cam
	if first_bone:
		box = AABB(Vector3(-0.4, -0.95, -0.4), Vector3(0.8, 1.9, 0.8))
	box = box.grow(0.06)
	# El hueso de la cabeza nace en el cuello: la coronilla queda ~0.2 m arriba.
	box.size.y += 0.2
	portrait_focus = box.get_center()
	cam.size = maxf(box.size.y, 0.8)
	cam.near = 0.05
	cam.far = 20.0
	_position_portrait_camera()
	equipment.remove_child(portrait)

func _position_portrait_camera() -> void:
	var cam: Camera3D = portrait._cam
	cam.position = portrait_focus + Vector3(sin(portrait_yaw), 0.18, cos(portrait_yaw)).normalized() * 4.5
	cam.look_at(portrait_focus, Vector3.UP)
	portrait._viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _portrait_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		portrait_dragging = event.pressed
		portrait.accept_event()
	elif event is InputEventMouseMotion and portrait_dragging and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		portrait_yaw -= event.relative.x * 0.012
		_position_portrait_camera()
		portrait.accept_event()

func button(parent: Control, title: String, action: Callable) -> void:
	var control := Button.new()
	control.text = title
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.pressed.connect(action)
	parent.add_child(control)

func find_item(name: String):
	for item in player.inventory.items:
		if item.item_name == name:
			return item
	return null

func can_transfer(data: Dictionary, destination: String, target: Dictionary) -> bool:
	if data.has("world"):
		return destination in Cargo.compartments(player).map(func(c): return c.id) and reachable(data.world)
	if not data.has("item") or data.item == null:
		return false
	var item = data.item
	if not player.inventory.items.has(item):
		return player.get_held_item() == item and destination == "ground"
	if destination.begins_with("equip:"):
		var slot := destination.trim_prefix("equip:")
		return (item.item_type == "backpack" and slot == "backpack") or (item.item_type == "clothing" and player.CLOTHING_SLOTS.get(item.item_name, "") == slot)
	if destination == "equipment":
		return item.item_type == "backpack" or (item.item_type == "clothing" and player.CLOTHING_SLOTS.has(item.item_name))
	if destination in ["ground", "hands"]:
		return true
	if target.has("item") and player.inventory.items.has(target.item) and target.item != item and target.item.can_stack_with(item, true):
		return true
	return Cargo.can_move(item, destination, player.inventory, Cargo.compartments(player))

func transfer(data: Dictionary, destination: String, target: Dictionary) -> void:
	if not can_transfer(data, destination, target):
		return
	if data.has("world"):
		collect(data.world)
	elif destination == "ground":
		if player.inventory.items.has(data.item):
			player.drop_inventory_item(player.inventory.items.find(data.item))
		else:
			player._drop_held_item()
	elif destination == "hands":
		player._select_held_item(player.inventory.items.find(data.item))
	elif destination == "equipment" or destination.begins_with("equip:"):
		equip(data.item)
	elif target.has("item") and target.item != data.item and target.item.can_stack_with(data.item, true):
		# Store a held source before removing its resource during merge.
		if player.get_held_item() == data.item:
			player._store_held_item()
		player.inventory.combine_stack(data.item, target.item)
	elif not Cargo.move(data.item, destination, player.inventory, Cargo.compartments(player)):
		player.notice.emit("Ese compartimento está lleno.")
	request_refresh(true)

func collect(action) -> void:
	if reachable(action):
		action.collect(player)
	request_refresh(true)

func equip(item) -> void:
	if not player.inventory.items.has(item):
		return
	if item.item_type == "clothing":
		player.equip_clothing(item.item_name, item.get_meta("clothing_color", Color(0, 0, 0, 0)), item)
	elif item.item_type == "backpack":
		player.equip_backpack(item.item_name)
	request_refresh(true)

func activate(data: Dictionary) -> void:
	if data.has("world"):
		collect(data.world)
	elif data.has("item") and player.inventory.items.has(data.item):
		if data.item.item_type in ["clothing", "backpack"]:
			equip(data.item)
		else:
			player._select_held_item(player.inventory.items.find(data.item))
	request_refresh(true)

func open_split(item) -> void:
	if not player.inventory.items.has(item) or item.quantity < 2:
		return
	split_item = item
	split_dialog.title = "Separar: " + str(item.item_name)
	split_amount.max_value = item.quantity - 1
	split_amount.value = maxi(1, item.quantity / 2)
	split_dialog.popup_centered()
	split_amount.get_line_edit().grab_focus()
	split_amount.get_line_edit().select_all()

func add_action(title: String, callback: Callable) -> void:
	menu.add_item(title, actions.size())
	actions.append(callback)

func open_actions(data: Dictionary, position_on_screen: Vector2) -> void:
	menu.clear()
	actions.clear()
	if data.has("world"):
		add_action("Recoger", func(): collect(data.world))
	elif data.has("item"):
		var item = data.item
		if not player.inventory.items.has(item):
			if player.get_held_item() == item:
				add_action("Guardar", func(): player._store_held_item())
				add_action("Soltar", func(): player._drop_held_item())
		else:
			add_action("Llevar a las manos", func(): activate({"item": item}) if item.item_type not in ["clothing", "backpack"] else player._select_held_item(player.inventory.items.find(item)))
			if item.item_type in ["clothing", "backpack"]:
				add_action("Equipar", func(): equip(item))
			if item.item_type == "clothing" and player._equipped_slots.values().has(item.item_name):
				add_action("Quitar prenda", func(): player.unequip_clothing(item.item_name))
			if player.get_held_item() == item:
				add_action("Guardar en inventario", func(): player._store_held_item())
			if item.item_type == "tool_torch":
				add_action("Encender / apagar", func():
					player._select_held_item(player.inventory.items.find(item))
					player._toggle_flashlight())
			if item.quantity > 1:
				add_action("Separar unidades…", func(): open_split(item))
			for container in Cargo.compartments(player):
				if container.id != item.cargo_location and Cargo.can_move(item, container.id, player.inventory, Cargo.compartments(player)):
					add_action("Mover a " + str(container.name).to_lower(), func(): transfer({"item": item}, container.id, {}))
			if player.can_store_item_on_back(item):
				add_action("Colgar en la espalda", func():
					player._select_held_item(player.inventory.items.find(item))
					player.store_held_on_back())
			if item.item_type in ["food", "water", "medical"]:
				add_action("Comer" if item.item_type == "food" else ("Beber" if item.item_type == "water" else "Aplicar"), func():
					var index: int = player.inventory.items.find(item)
					if index >= 0:
						player._select_held_item(index)
						hud.toggle_inventory()
						player._use_inventory_index(index))
			for recipe in Crafting.get_recipes_for_item(item.item_name, item.item_type):
				if Crafting._can_craft(recipe, player.inventory.items):
					add_action("Combinar: " + Crafting.get_recipe_label(recipe), func(): hud.toggle_inventory(); player.craft_recipe(recipe))
			add_action("Soltar una unidad", func():
				var index: int = player.inventory.items.find(item)
				if index >= 0:
					player.drop_inventory_item(index))
	menu.position = Vector2i(position_on_screen)
	menu.popup()
