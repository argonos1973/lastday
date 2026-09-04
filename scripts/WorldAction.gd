extends StaticBody3D
class_name WorldAction

@export var action_id := ""
@export var action_type := ""
@export var display_name := ""
@export var depleted := false
@export var repeatable := false
@export var action_state := ""
@export var growth := 0.0
@export var grow_time := 45.0
var _rot_timer := 0.0

var _mesh_instance: MeshInstance3D
var _collision: CollisionShape3D
var _visual_children: Array[Node] = []

func setup(id: String, type: String, label: String, size: Vector3, color: Color, can_repeat := false, marker_visible := true) -> void:
	action_id = id
	action_type = type
	display_name = label
	repeatable = can_repeat
	_make_box(size, color)
	if _mesh_instance != null:
		_mesh_instance.visible = false
	add_to_group("world_actions")
	add_to_group("interactable")

func disable_collision() -> void:
	if action_type == "fell_bush" or action_type == "fell_tree":
		collision_layer = 0
		collision_mask = 0
		if _collision != null:
			_collision.disabled = true
	elif action_type == "pick_fruit":
		collision_layer = 1
		collision_mask = 0
	else:
		collision_layer = 2
		collision_mask = 0

func interact(player) -> void:
	if has_meta("no_pickup") and bool(get_meta("no_pickup")):
		player.notice.emit("%s esta rota y no se puede coger." % display_name)
		return
	if depleted and not repeatable:
		player.notice.emit("%s ya no tiene nada util." % display_name)
		return
	var main := get_tree().current_scene
	if main != null and main.has_method("handle_world_action"):
		main.handle_world_action(self, player)

func collect(player) -> void:
	if has_meta("no_pickup") and bool(get_meta("no_pickup")):
		player.notice.emit("%s esta rota y no se puede coger." % display_name)
		return
	if depleted and not repeatable:
		player.notice.emit("%s ya no tiene nada util." % display_name)
		return
	var main := get_tree().current_scene
	if main != null and main.has_method("handle_world_action_collect"):
		main.handle_world_action_collect(self, player)

func mark_depleted() -> void:
	depleted = true
	if _mesh_instance != null:
		_mesh_instance.visible = false
	if _collision != null:
		_collision.disabled = true
	collision_layer = 0
	collision_mask = 0
	remove_from_group("interactable")
	_clear_visual_children()
	# Auto-register in Main's depleted list so it persists across save/load
	var main := get_tree().current_scene
	if main != null and main.get("_depleted_action_ids") != null:
		if not main._depleted_action_ids.has(action_id):
			main._depleted_action_ids.append(action_id)

func set_crop_state(state: String, new_growth := 0.0) -> void:
	action_state = state
	growth = new_growth
	_update_crop_visual()

func tick_growth(delta: float) -> void:
	if action_type == "farm_plot" and action_state == "planted":
		growth += delta
		if growth >= grow_time:
			action_state = "ready"
			_update_crop_visual()
	if action_type == "wolf_meat_raw" or action_type == "deer_meat_raw" or action_type == "fox_meat_raw":
		if _rot_timer <= 0.0:
			_rot_timer = 600.0
		_rot_timer = max(0.0, _rot_timer - delta)
		if _rot_timer <= 0.0:
			var main := get_tree().current_scene
			if main != null and "world_actions_by_id" in main:
				main.world_actions_by_id.erase(action_id)
			queue_free()

func get_interaction_text(_player = null) -> String:
	if has_meta("no_pickup") and bool(get_meta("no_pickup")):
		return "%s - Ropa rota, no se puede coger" % display_name
	if action_type == "farm_plot":
		match action_state:
			"planted":
				return "%s creciendo" % display_name
			"ready":
				return "%s - [E] Cosechar" % display_name
			_:
				return "%s - [E] Plantar semillas" % display_name
	match action_type:
		"gut_wolf":
			if get_meta("gutted", false):
				return "%s vacio" % display_name
			if not _player_has_blade(_player):
				return ""
			return "Destripar - [E] | Coger - [C] (mochila)"
		"wolf_meat_raw":
			return "%s - [C] Coger | [M] Comer (cruda)" % display_name
		"fell_tree":
			if not _player_has_axe(_player):
				return ""
			return "%s - [E] Talar (10s)" % display_name
		"fell_bush":
			if not _player_has_blade(_player):
				return ""
			return "%s - [E] Cortar (5s)" % display_name
		"cut_log":
			if not _player_has_axe(_player):
				return ""
			return "%s - [E] Cortar" % display_name
		"build_cabin":
			return "%s - [E] Construir cabana" % display_name
		"pickup_item", "axe_tool", "hoe_tool", "shovel_tool", "hammer_tool", "pickaxe_tool", "matches_tool", "backpack_pickup", "coat":
			if _is_clothing():
				if _player_has_knife(_player) and not _is_footwear():
					return "%s - [E] Cortar para trapos | [C] Coger" % display_name
				return "%s - [E] Equipar | [C] Coger" % display_name
			return "%s - [C] Coger" % display_name
		"eat_food":
			return "%s - [M] Comer | [C] Coger" % display_name
		"wood", "stone":
			return "%s - [C] Coger" % display_name
		"forage":
			return "%s - [E] Recolectar | [C] Coger" % display_name
		"fish":
			return "%s - [E] Pescar" % display_name
		"hunt":
			return "%s - [E] Rastrear" % display_name
		"pick_fruit":
			var now := Time.get_unix_time_from_system()
			var ready: float = float(get_meta("fruit_ready_time", 0.0))
			if now < ready:
				return "%s - Fruta madurando (%ds)" % [display_name, int(ceil(ready - now))]
			return "%s - [E] Recoger fruta" % display_name
		"drink_water":
			if _player != null and _player.has_method("get_held_item"):
				var held = _player.get_held_item()
				if held != null and held.item_name == "Botella de plastico":
					return "Llenar botella - [E]"
				if held != null and held.item_name == "Botella de agua" and held.has_method("is_broken") and not held.is_broken() and float(held.durability) < float(held.max_durability):
					return "Llenar botella - [E]"
			return "Beber agua - [E]"
		"light_campfire":
			return "Encender fogata - [E] (cerillas o 2 palos)"
		"cook":
			return "Cocinar carne ensartada - [E]"
		"shelter":
			return "Desmontar refugio - [E] (recuperar 11 palos)"
	return "%s - [E]" % display_name

func to_dict() -> Dictionary:
	var meta_dict := {}
	for mk in get_meta_list():
		meta_dict[mk] = get_meta(mk)
	return {
		"id": action_id,
		"action_type": action_type,
		"display_name": display_name,
		"depleted": depleted,
		"state": action_state,
		"growth": growth,
		"meta": meta_dict
	}

func from_dict(data: Dictionary) -> void:
	var saved_type := str(data.get("action_type", ""))
	if not saved_type.is_empty():
		action_type = saved_type
	var saved_name := str(data.get("display_name", ""))
	if not saved_name.is_empty():
		display_name = saved_name
	depleted = bool(data.get("depleted", depleted))
	action_state = str(data.get("state", action_state))
	growth = float(data.get("growth", growth))
	var saved_meta = data.get("meta", {})
	if saved_meta is Dictionary:
		for mk in saved_meta.keys():
			set_meta(mk, saved_meta[mk])
	if depleted and not repeatable:
		mark_depleted()
	else:
		_update_crop_visual()

func _make_box(size: Vector3, color: Color) -> void:
	_mesh_instance = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	_mesh_instance.mesh = box
	_mesh_instance.position.y = size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_mesh_instance.material_override = material
	add_child(_mesh_instance)

	_collision = CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	_collision.shape = shape
	_collision.position.y = size.y * 0.5
	add_child(_collision)

func _update_crop_visual() -> void:
	if action_type != "farm_plot":
		return
	_clear_visual_children()
	if _mesh_instance != null:
		_mesh_instance.visible = true
	var material := StandardMaterial3D.new()
	material.roughness = 1.0
	match action_state:
		"planted":
			material.albedo_color = Color(0.14, 0.24, 0.08)
			_add_crop_blades(0.28, material)
		"ready":
			material.albedo_color = Color(0.26, 0.36, 0.09)
			_add_crop_blades(0.58, material)
		_:
			material.albedo_color = Color(0.20, 0.12, 0.055)
	if _mesh_instance != null:
		_mesh_instance.material_override = material

func _add_crop_blades(height: float, material: StandardMaterial3D) -> void:
	for x in [-0.55, 0.0, 0.55]:
		for z in [-0.45, 0.15, 0.55]:
			var blade := MeshInstance3D.new()
			blade.name = "CropShoot"
			blade.position = Vector3(x, height * 0.5 + 0.06, z)
			blade.rotation_degrees = Vector3(randf_range(-7, 7), randf_range(0, 180), randf_range(-6, 6))
			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.08, height, 0.08)
			blade.mesh = mesh
			blade.material_override = material
			add_child(blade)
			_visual_children.append(blade)

func _clear_visual_children() -> void:
	for child in _visual_children:
		if is_instance_valid(child):
			child.queue_free()
	_visual_children.clear()

func _is_clothing() -> bool:
	if action_type == "pickup_item" and has_meta("item_type"):
		return str(get_meta("item_type")) == "clothing"
	return false

func _player_has_axe(player) -> bool:
	if player == null or not player.has_method("get_held_item"):
		return false
	var held = player.get_held_item()
	if held == null:
		return false
	if held.item_type == "tool_axe":
		return true
	if held.item_type == "tool" and held.item_name == "Hacha":
		return true
	return false

func _player_has_blade(player) -> bool:
	if player == null or not player.has_method("get_held_item"):
		return false
	var held = player.get_held_item()
	if held == null:
		return false
	if held.item_type == "weapon":
		return true
	if held.item_type == "tool_axe":
		return true
	if held.item_type == "tool" and held.item_name == "Hacha":
		return true
	return false

func _player_has_knife(player) -> bool:
	if player == null:
		return false
	if player.has_method("get_held_item"):
		var held = player.get_held_item()
		if held != null and (held.item_name == "Cuchillo" or held.item_name == "Hacha"):
			return true
	return false

func _is_footwear() -> bool:
	if not has_meta("item_name"):
		return false
	var n := str(get_meta("item_name"))
	return n == "Zapatillas" or n == "Botas survival"
