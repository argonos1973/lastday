extends StaticBody3D
class_name WorldAction

@export var action_id := ""
@export var action_type := "":
	set(value):
		_remove_interaction_index()
		action_type = value
		_update_interaction_index()
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

static var _interaction_cells: Dictionary = {}
static var _wide_interactions: Dictionary = {}
var _interaction_cell := Vector2i.ZERO
var _interaction_indexed := false
var _interaction_spatial := false

func _enter_tree() -> void:
	set_notify_transform(true)
	_update_interaction_index()

func _exit_tree() -> void:
	_remove_interaction_index()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_interaction_index()

func _update_interaction_index() -> void:
	if not is_inside_tree():
		return
	if action_type == "wolf_meat_raw" or has_meta("wolf_food"):
		add_to_group("wolf_meat_pickups")
	elif is_in_group("wolf_meat_pickups"):
		remove_from_group("wolf_meat_pickups")
	var spatial := action_type in ["fell_tree", "fell_bush", "pickup_item", "wolf_meat_raw", "bird_meat_raw", "axe_tool", "hoe_tool", "shovel_tool", "hammer_tool", "pickaxe_tool", "matches_tool", "plant_seeds", "farm_plot"]
	var pos := global_position
	var cell := Vector2i(floori(pos.x / GameConst.INTERACTION_CELL_SIZE), floori(pos.z / GameConst.INTERACTION_CELL_SIZE))
	if _interaction_indexed and _interaction_spatial == spatial and (not spatial or cell == _interaction_cell):
		return
	_remove_interaction_index()
	_interaction_cell = cell
	_interaction_spatial = spatial
	if spatial:
		if not _interaction_cells.has(cell):
			_interaction_cells[cell] = {}
		_interaction_cells[cell][get_instance_id()] = self
	elif action_type in ["cut_log", "eat_food", "light_campfire", "cook"]:
		_wide_interactions[get_instance_id()] = self
	else:
		return
	_interaction_indexed = true

func _remove_interaction_index() -> void:
	if not _interaction_indexed:
		return
	if _interaction_spatial:
		var entries: Dictionary = _interaction_cells.get(_interaction_cell, {})
		entries.erase(get_instance_id())
		if entries.is_empty():
			_interaction_cells.erase(_interaction_cell)
	else:
		_wide_interactions.erase(get_instance_id())
	_interaction_indexed = false

static func get_nearby_interactables(pos: Vector3, pad: float = 2.0) -> Array:
	var candidates: Array = _wide_interactions.values()
	var min_cell := Vector2i(floori((pos.x - pad) / GameConst.INTERACTION_CELL_SIZE), floori((pos.z - pad) / GameConst.INTERACTION_CELL_SIZE))
	var max_cell := Vector2i(floori((pos.x + pad) / GameConst.INTERACTION_CELL_SIZE), floori((pos.z + pad) / GameConst.INTERACTION_CELL_SIZE))
	for x in range(min_cell.x, max_cell.x + 1):
		for z in range(min_cell.y, max_cell.y + 1):
			var entries: Dictionary = _interaction_cells.get(Vector2i(x, z), {})
			candidates.append_array(entries.values())
	return candidates

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
	var swarm := get_node_or_null("FlySwarm")
	if swarm != null:
		swarm.queue_free()
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
		var prev_stage := clampi(int(growth / maxf(grow_time, 1.0) * 3.0), 0, 2)
		growth += delta
		if growth >= grow_time:
			action_state = "ready"
			_update_crop_visual()
		elif clampi(int(growth / maxf(grow_time, 1.0) * 3.0), 0, 2) != prev_stage:
			_update_crop_visual()
	if action_type == "wolf_meat_raw" or action_type == "deer_meat_raw" or action_type == "fox_meat_raw" or action_type == "bird_meat_raw":
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
	# Indicador de putrefacción para comida en el suelo
	var spoil_tag := ""
	if has_meta("item_spoilage"):
		var spoil: float = float(get_meta("item_spoilage", 0.0))
		if spoil >= 100.0:
			spoil_tag = " (PODRIDO)"
		elif spoil >= 50.0:
			spoil_tag = " (CADUCADO)"
	# Indicador de humedad para ropa/items mojados en el suelo
	var wet_tag := ""
	if has_meta("item_wetness"):
		var w: float = float(get_meta("item_wetness", 0.0))
		if w >= 0.8:
			wet_tag = " (EMPAPADA)"
		elif w >= 0.45:
			wet_tag = " (MOJADA)"
		elif w > 0.02:
			wet_tag = " (HUMEDA)"
	if action_type == "farm_plot":
		match action_state:
			"planted":
				return "%s creciendo" % display_name
			"ready":
				return "%s - [F] Cosechar" % display_name
			_:
				return "%s - [F] Plantar semillas" % display_name
	match action_type:
		"gut_wolf":
			if get_meta("gutted", false):
				return "%s vacio" % display_name
			if not _player_has_blade(_player):
				return ""
			return "Destripar - [F] | Coger - [C] (mochila)"
		"wolf_meat_raw", "bird_meat_raw":
			return "%s - [C] Coger | [M] Comer (cruda)" % display_name
		"fell_tree":
			if not _player_has_axe(_player):
				return ""
			return "%s - [F] Talar (10s)" % display_name
		"fell_bush":
			if not _player_has_blade(_player):
				return ""
			return "%s - [F] Cortar (5s)" % display_name
		"cut_log":
			if not _player_has_axe(_player):
				return ""
			return "%s - [F] Cortar" % display_name
		"build_cabin":
			return "%s - [F] Construir cabana" % display_name
		"pickup_item", "axe_tool", "hoe_tool", "shovel_tool", "hammer_tool", "pickaxe_tool", "matches_tool", "backpack_pickup", "coat":
			if action_type == "backpack_pickup" or str(get_meta("item_type", "")) == "backpack":
				var n_contents: int = (get_meta("contents", []) as Array).size()
				var count_tag := " (%d)" % n_contents if n_contents > 0 else ""
				return "%s%s%s%s - [C] Coger | [K] Abrir" % [display_name, spoil_tag, wet_tag, count_tag]
			if _is_clothing():
				if _player_has_knife(_player) and not _is_footwear():
					return "%s%s%s - [F] Cortar para trapos | [C] Coger" % [display_name, spoil_tag, wet_tag]
				return "%s%s%s - [F] Equipar | [C] Coger" % [display_name, spoil_tag, wet_tag]
			return "%s%s%s - [C] Coger" % [display_name, spoil_tag, wet_tag]
		"eat_food":
			return "%s%s%s - [M] Comer | [C] Coger" % [display_name, spoil_tag, wet_tag]
		"plant_seeds":
			return "%s - [F] Plantar (azada/pala) | [C] Coger" % display_name
		"wood", "stone":
			return "%s - [C] Coger" % display_name
		"forage":
			return "%s - [F] Recolectar | [C] Coger" % display_name
		"fish":
			return "%s - [F] Pescar" % display_name
		"hunt":
			return "%s - [F] Rastrear" % display_name
		"pick_fruit":
			var now := Time.get_unix_time_from_system()
			var ready: float = float(get_meta("fruit_ready_time", 0.0))
			if now < ready:
				return "%s - Fruta madurando (%ds)" % [display_name, int(ceil(ready - now))]
			return "%s - [F] Recoger fruta" % display_name
		"drink_water":
			if _player != null and _player.has_method("get_held_item"):
				var held = _player.get_held_item()
				var _hands = _player.get("hands") if _player.has_method("get") else null
				var _in_hands = _hands != null and _hands.has_method("has_item_in_hands") and _hands.has_item_in_hands()
				if _in_hands and held != null and held.item_name == "Botella de plastico":
					return "Llenar botella - [F]"
				if _in_hands and held != null and (held.item_name == "Botella de agua" or held.item_name == "Botella de agua llena") and held.has_method("is_broken") and not held.is_broken() and float(held.durability) < float(held.max_durability):
					return "Llenar botella - [F]"
			return "Beber agua - [F]"
		"light_campfire":
			return "Encender fogata - [F] (cerillas o 2 palos)"
		"cook":
			if get_meta("cooking", false):
				return ""
			if _player != null and _player.has_method("get_held_item"):
				var held = _player.get_held_item()
				if held != null and held.item_name == "Carne ensartada":
					return "Cocinar carne ensartada - [F]"
				if held != null and held.item_name == "Pez ensartado":
					return "Cocinar pez ensartado - [F]"
				var inv = _player.get("inventory")
				if inv != null and inv.has_method("has_item_name"):
					if inv.has_item_name("Carne ensartada") or inv.has_item_name("Pez ensartado"):
						return "Cocinar - [F] (pondras la carne ensartada en la mano)"
			return "Fogata encendida - lleva carne o pez ensartado en la mano"
		"shelter":
			var stash_n: int = (get_meta("contents", []) as Array).size()
			var stash_tag := " (%d)" % stash_n if stash_n > 0 else ""
			return "Desmontar - [F] (recuperar 11 palos) | Objetos%s - [K]" % stash_tag
	return "%s - [F]" % display_name

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

const FARM_BED_MODEL := "res://assets/models/props/farming/farm_plot.glb"

func _update_crop_visual() -> void:
	if action_type != "farm_plot":
		return
	_clear_visual_children()
	# The procedural box stays hidden — it only carries the interaction
	# collision. The tilled soil bed comes from the Blender model.
	if _mesh_instance != null:
		_mesh_instance.visible = false
	_add_farm_bed()
	match action_state:
		"planted":
			var stage := clampi(int(growth / maxf(grow_time, 1.0) * 3.0), 0, 2)
			_add_crop_rows(stage)
		"ready":
			_add_crop_rows(3)

func _add_farm_bed() -> void:
	if not ResourceLoader.exists(FARM_BED_MODEL):
		if _mesh_instance != null:
			_mesh_instance.visible = true
		return
	var scene := load(FARM_BED_MODEL) as PackedScene
	if scene == null:
		return
	var bed := scene.instantiate()
	bed.name = "FarmBed"
	add_child(bed)
	_visual_children.append(bed)

func _add_crop_rows(stage: int) -> void:
	var path := "res://assets/models/props/farming/crop_stage_%d.glb" % stage
	if not ResourceLoader.exists(path):
		return
	var scene := load(path) as PackedScene
	if scene == null:
		return
	# Plants grow on the bed's three furrow ridges.
	for rx in [-0.34, 0.0, 0.34]:
		for rz in [-0.30, 0.0, 0.30]:
			var plant := scene.instantiate()
			plant.name = "CropPlant"
			plant.position = Vector3(rx, 0.13, rz)
			add_child(plant)
			_visual_children.append(plant)

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
	if held.item_type in ["tool_axe", "axe_tool"]:
		return true
	if held.item_type == "tool" and held.item_name == "Hacha":
		return true
	# Fallback by name (matches PlayerController.has_axe_in_hand)
	if str(held.item_name) == "Hacha":
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
	if held.item_type in ["tool_axe", "axe_tool"]:
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
	return n == "Zapatillas" or n.begins_with("Botas")
