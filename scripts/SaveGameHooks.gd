extends Node
class_name SaveGameHooks

const ItemScript = preload("res://scripts/Item.gd")
const DoorScript = preload("res://scripts/Door.gd")

static func maybe_save_game(main: Node, player: Node) -> void:
	if main == null or not is_instance_valid(main):
		return
	if main.net != null and main.net.is_connected:
		return
	if player == null or not is_instance_valid(player):
		return
	var sgm = main.get_node_or_null("/root/SaveGameManager")
	if sgm == null:
		return
	sgm.save_game(collect_player_data(player), collect_world_data(main))

static func maybe_load_saved_game(main: Node, player: Node) -> void:
	if main == null or not is_instance_valid(main):
		return
	if main.net != null and main.net.is_connected:
		return
	# Enable auto-save for single player
	var sgm = main.get_node_or_null("/root/SaveGameManager")
	if sgm != null:
		sgm.enable_auto_save()
	var gsess: Node = main.get_node_or_null("/root/GameSession")
	if gsess == null or gsess.selected_character_id != "saved":
		return
	if sgm == null or not sgm.has_save():
		return
	var save_data: Dictionary = sgm.load_game()
	if save_data.is_empty():
		return
	apply_saved_player_data(player, save_data.get("player", {}))
	apply_saved_world_data(main, save_data.get("world", {}))
	# Merge duplicate stacks (e.g. torches that were in separate slots)
	if player != null and is_instance_valid(player) and player.inventory != null:
		player.inventory.merge_stacks()

static func preload_saved_world_state(main: Node) -> void:
	if main == null or not is_instance_valid(main):
		return
	if main.net != null and main.net.is_connected:
		return
	var gsess: Node = main.get_node_or_null("/root/GameSession")
	if gsess == null or gsess.selected_character_id != "saved":
		return
	var sgm = main.get_node_or_null("/root/SaveGameManager")
	if sgm == null or not sgm.has_save():
		return
	var save_data: Dictionary = sgm.load_game()
	if save_data.is_empty():
		return
	var world_data: Dictionary = save_data.get("world", {})
	# Pre-load depleted action IDs so world generation can skip cut trees
	var depleted = world_data.get("depleted_action_ids", [])
	# Load legitimately cut tree IDs to filter out fake fell_tree_* from _deactivate_tree bug
	var legit_cut: Array = world_data.get("legit_cut_trees", [])
	for tree_id in legit_cut:
		if not main._legit_cut_trees.has(tree_id):
			main._legit_cut_trees.append(tree_id)
	for action_id in depleted:
		# Only keep fell_tree_* IDs that were legitimately cut
		if str(action_id).begins_with("fell_tree_") and not legit_cut.has(action_id):
			continue
		if not main._depleted_action_ids.has(action_id):
			main._depleted_action_ids.append(action_id)
	# Pre-load picked-up loot IDs so world generation can skip already-collected loot
	var picked_up: Array = world_data.get("picked_up_loot_ids", [])
	for loot_id in picked_up:
		if not main._depleted_action_ids.has(loot_id):
			main._depleted_action_ids.append(loot_id)
	# Pre-load fruit tree cooldowns so they persist across sessions
	var fruit_cooldowns: Dictionary = world_data.get("fruit_tree_cooldowns", {})
	for action_id in fruit_cooldowns.keys():
		main._pending_fruit_cooldowns[action_id] = float(fruit_cooldowns[action_id])
	# Pre-load fruit tree types so the correct fruit is assigned after world gen
	var fruit_types: Dictionary = world_data.get("fruit_tree_types", {})
	for action_id in fruit_types.keys():
		main._pending_fruit_types[action_id] = str(fruit_types[action_id])

static func collect_player_data(player: Node) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	var data := {}
	data["pos"] = [player.global_position.x, player.global_position.y, player.global_position.z]
	data["rot"] = player.rotation.y
	var anim := "idle"
	if player.has_method("_get_current_anim"):
		anim = player._get_current_anim()
	data["anim"] = anim
	# Stats (full dict: health, hunger, thirst, energy, sleep, body_temperature, sick, wetness, survival_seconds, etc.)
	if player.get("stats") != null and player.stats.has_method("to_dict"):
		data["stats"] = player.stats.to_dict()
		# Legacy flat fields kept for backward-compat with older saves/tools
		data["health"] = player.stats.health
		data["hunger"] = player.stats.hunger
		data["thirst"] = player.stats.thirst
		data["survival_seconds"] = player.stats.survival_seconds
	else:
		data["health"] = 100.0
		data["hunger"] = 100.0
		data["thirst"] = 100.0
	# State flags
	data["sleeping"] = player.get("is_sleeping") != null and bool(player.get("is_sleeping"))
	data["sitting"] = player.get("is_sitting") != null and bool(player.get("is_sitting"))
	data["prone"] = player.get("is_prone") != null and bool(player.get("is_prone"))
	data["crouching"] = player.get("is_crouching") != null and bool(player.get("is_crouching"))
	# Inventory
	var items_data := []
	if player.get("inventory") != null:
		for item in player.inventory.items:
			if item != null:
				items_data.append(item.to_dict())
	data["inventory"] = items_data
	# Equipped clothing
	var clothing := ""
	var equipped_slots = player.get("_equipped_slots")
	if equipped_slots == null:
		equipped_slots = {}
	if equipped_slots != null and not equipped_slots.is_empty():
		var clothing_items: Array = []
		for slot in equipped_slots.keys():
			var item_name: String = str(equipped_slots[slot])
			if not item_name.is_empty():
				clothing_items.append(item_name)
		clothing = ",".join(clothing_items)
	data["equipped_clothing"] = clothing
	# Backpack
	var eb = player.get("equipped_backpack")
	data["equipped_backpack"] = str(eb) if eb != null else ""
	# Held item
	var held := ""
	var hi_raw = player.get("held_index")
	var held_idx := int(hi_raw) if hi_raw != null else 0
	if player.get("inventory") != null and player.inventory.items.size() > 0:
		var hi: int = clampi(held_idx, 0, player.inventory.items.size() - 1)
		if player.inventory.items[hi] != null:
			held = player.inventory.items[hi].item_name
	data["held_item"] = held
	data["held_index"] = held_idx
	# Character appearance
	var gsess: Node = Engine.get_main_loop().get_root().get_node_or_null("/root/GameSession")
	if gsess != null:
		data["char_name"] = str(gsess.get_meta("char_name", ""))
		data["character_id"] = gsess.selected_character_id
		data["top_color"] = _color_to_str(gsess.selected_top_color)
		data["bottom_color"] = _color_to_str(gsess.selected_bottom_color)
		data["shoes_color"] = _color_to_str(gsess.selected_shoes_color)
		data["hair_color"] = _color_to_str(gsess.selected_hair_color)
		data["skin_color"] = _color_to_str(gsess.selected_skin_color)
		data["top_camo"] = bool(gsess.get_meta("top_camo", false))
		data["bottom_camo"] = bool(gsess.get_meta("bottom_camo", false))
	return data

static func collect_world_data(main: Node) -> Dictionary:
	var data := {}
	# Depleted action IDs (trees chopped, mushrooms eaten, etc.)
	data["depleted_action_ids"] = main.get("_depleted_action_ids").duplicate()
	# Dropped items in the world
	var dropped := []
	for d in main.get("_dropped_items"):
		var dcopy: Dictionary = d.duplicate()
		if dcopy.has("pos") and dcopy["pos"] is Vector3:
			dcopy["pos"] = [dcopy["pos"].x, dcopy["pos"].y, dcopy["pos"].z]
		dropped.append(dcopy)
	data["dropped_items"] = dropped
	# Legitimately cut trees (to filter out fake fell_tree_* from _deactivate_tree bug)
	data["legit_cut_trees"] = main.get("_legit_cut_trees").duplicate()
	# Built campfires
	var campfires := []
	for cf in main.get("_built_campfires"):
		var cfcopy: Dictionary = cf.duplicate()
		if cfcopy.has("pos") and cfcopy["pos"] is Vector3:
			cfcopy["pos"] = [cfcopy["pos"].x, cfcopy["pos"].y, cfcopy["pos"].z]
		campfires.append(cfcopy)
	data["built_campfires"] = campfires
	# Lit campfires
	var lit := []
	for lc in main.get("_lit_campfires"):
		var lccopy: Dictionary = lc.duplicate()
		if lccopy.has("pos") and lccopy["pos"] is Vector3:
			lccopy["pos"] = [lccopy["pos"].x, lccopy["pos"].y, lccopy["pos"].z]
		lit.append(lccopy)
	data["lit_campfires"] = lit
	# Built shelters
	var shelters := []
	for sh in main.get("_built_shelters"):
		var shcopy: Dictionary = sh.duplicate()
		if shcopy.has("pos") and shcopy["pos"] is Vector3:
			shcopy["pos"] = [shcopy["pos"].x, shcopy["pos"].y, shcopy["pos"].z]
		shelters.append(shcopy)
	data["built_shelters"] = shelters
	# Open doors — in single player, check door nodes directly
	var open_doors: Array = []
	var net_node = main.get_node_or_null("/root/NetworkManager")
	if net_node != null and net_node.is_dedicated_server:
		var door_states = main.get("_server_door_states")
		if door_states != null:
			for door_name in door_states.keys():
				if bool(door_states[door_name]):
					open_doors.append(door_name)
	else:
		for door in main.get_tree().get_nodes_in_group("doors"):
			if is_instance_valid(door) and "is_open" in door and door.is_open:
				open_doors.append(door.name)
	data["open_doors"] = open_doors
	# Torch fire positions (lit torches on ground)
	data["torch_fire_positions"] = []
	var tfp = main.get("torch_fire_positions")
	if tfp == null:
		tfp = []
	for pos in tfp:
		if pos is Vector3:
			data["torch_fire_positions"].append([pos.x, pos.y, pos.z])
	# Campfire fire timers (remaining time)
	var cf_timers := {}
	var fire_timers = main.get("campfire_fire_timers")
	if fire_timers == null:
		fire_timers = {}
	for fire_name in fire_timers.keys():
		cf_timers[fire_name] = fire_timers[fire_name]
	data["campfire_fire_timers"] = cf_timers
	# Fruit tree cooldowns — persist pick_fruit ready times
	var fruit_cd := {}
	var wabi = main.get("world_actions_by_id")
	if wabi != null:
		for action_id in wabi.keys():
			var action = wabi[action_id]
			if action != null and is_instance_valid(action) and action.action_type == "pick_fruit":
				var rt = action.get_meta("fruit_ready_time", 0.0)
				fruit_cd[action_id] = rt
	data["fruit_tree_cooldowns"] = fruit_cd
	# Fruit tree types — persist which fruit each tree produces
	var fruit_types := {}
	if wabi != null:
		for action_id in wabi.keys():
			var action = wabi[action_id]
			if action != null and is_instance_valid(action) and action.action_type == "pick_fruit":
				fruit_types[action_id] = str(action.get_meta("fruit_type_name", "Higo"))
	data["fruit_tree_types"] = fruit_types
	# Cut tree positions — fallback for hiding trees when IDs don't match after load
	var cut_tree_positions := []
	for action_id in main.get("_depleted_action_ids"):
		if str(action_id).begins_with("fell_tree_") and main.get("world_actions_by_id").has(action_id):
			var action = main.world_actions_by_id[action_id]
			if action != null and is_instance_valid(action):
				cut_tree_positions.append([action.global_position.x, action.global_position.y, action.global_position.z])
	# Also include positions from _legit_cut_trees that have been deactivated (no WorldAction)
	for entry in main.get("_tree_grid").values():
		if entry is Array:
			for tree_entry in entry:
				var aid := "fell_tree_%d" % tree_entry.id
				if main.get("_depleted_action_ids").has(aid):
					cut_tree_positions.append([tree_entry.pos.x, tree_entry.pos.y, tree_entry.pos.z])
	data["cut_tree_positions"] = cut_tree_positions
	# Dead wildlife — persist corpses so they don't respawn alive
	var dead_wildlife := []
	for node in main.get_tree().get_nodes_in_group("wildlife"):
		if node == null or not is_instance_valid(node):
			continue
		if node.get("_is_dead") == true:
			dead_wildlife.append({
				"name": node.name,
				"type": node.get("animal_type"),
				"pos": [node.global_position.x, node.global_position.y, node.global_position.z],
				"rot": node.rotation.y,
				"gutted": bool(node.get("_gutted")),
				"health": float(node.get("health")),
				"rot_timer": float(node.get("_rot_timer"))
			})
	data["dead_wildlife"] = dead_wildlife
	return data

static func apply_saved_player_data(player: Node, data: Dictionary) -> void:
	if player == null or not is_instance_valid(player) or data.is_empty():
		return
	# Prevent _recalculate_carry_capacity from dropping items during restore
	var prev_init = player.get("_initializing")
	player.set("_initializing", true)
	# Position
	var pos_arr = data.get("pos", [8.0, 0.4, 2.5])
	if pos_arr is Array and pos_arr.size() >= 3:
		player.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
	# Rotation
	player.rotation.y = float(data.get("rot", 0.0))
	# Reset velocity
	player.velocity = Vector3.ZERO
	if "_is_falling_from_height" in player:
		player._is_falling_from_height = false
	if "_fall_height" in player:
		player._fall_height = 0.0
	if "_max_fall_height" in player:
		player._max_fall_height = 0.0
	if "is_jumping" in player:
		player.is_jumping = false
	if "_jump_velocity" in player:
		player._jump_velocity = 0.0
	# Stats
	if player.get("stats") != null:
		if data.has("stats") and player.stats.has_method("from_dict"):
			player.stats.from_dict(data["stats"])
		else:
			# Legacy fallback for older saves without full stats dict
			player.stats.health = float(data.get("health", 100.0))
			player.stats.hunger = float(data.get("hunger", 100.0))
			player.stats.thirst = float(data.get("thirst", 100.0))
			player.stats.survival_seconds = float(data.get("survival_seconds", 0.0))
			player.stats.changed.emit()
	# Inventory — filter out removed clothing items (migrated out of the game)
	var _removed_items := ["Chaqueta militar", "Chaqueta militar azul", "Chaqueta militar negra II"]
	var items_data = data.get("inventory", [])
	if player.has_node("Inventory"):
		var inv = player.get_node("Inventory")
		if inv != null and "items" in inv:
			inv.items.clear()
			for d in items_data:
				var item = ItemScript.from_dict(d)
				if item != null:
					if str(item.item_name) in _removed_items:
						continue
					inv.items.append(item)
	# Held index
	player.held_index = int(data.get("held_index", 0))
	# Restore character appearance colors into GameSession so
	# _apply_character_colors picks them up correctly.
	# This must happen BEFORE equipping clothing so that clothing_color
	# from inventory items overrides the default top_color.
	var gsess: Node = Engine.get_main_loop().get_root().get_node_or_null("/root/GameSession")
	if gsess != null:
		if data.has("top_color"):
			gsess.selected_top_color = _str_to_color(str(data["top_color"]))
		if data.has("bottom_color"):
			gsess.selected_bottom_color = _str_to_color(str(data["bottom_color"]))
		if data.has("shoes_color"):
			gsess.selected_shoes_color = _str_to_color(str(data["shoes_color"]))
		if data.has("hair_color"):
			gsess.selected_hair_color = _str_to_color(str(data["hair_color"]))
		if data.has("skin_color"):
			gsess.selected_skin_color = _str_to_color(str(data["skin_color"]))
		if data.has("top_camo"):
			gsess.set_meta("top_camo", bool(data["top_camo"]))
		if data.has("bottom_camo"):
			gsess.set_meta("bottom_camo", bool(data["bottom_camo"]))
	# Re-apply character colors on the player model BEFORE equipping saved clothing
	if player.has_method("_apply_character_colors"):
		player._apply_character_colors()
	# Restore equipped clothing — filter out removed items from save migration
	var equipped_clothing := str(data.get("equipped_clothing", ""))
	if not equipped_clothing.is_empty():
		var _filtered_slots: Array = []
		for _s in equipped_clothing.split(","):
			var _sn := str(_s).strip_edges()
			if not _sn.is_empty() and _sn not in _removed_items:
				_filtered_slots.append(_sn)
		equipped_clothing = ",".join(_filtered_slots)
	if not equipped_clothing.is_empty():
		if "_equipped_slots" in player:
			var old_slots: Dictionary = player._equipped_slots.duplicate()
			player._equipped_slots.clear()
			for old_item in old_slots.values():
				var oitem := str(old_item)
				if not oitem.is_empty():
					player.unequip_clothing(oitem)
		for default_item in ["Camiseta", "Pantalones", "Zapatillas"]:
			player.unequip_clothing(default_item)
		var slots := equipped_clothing.split(",")
		for slot_name in slots:
			if not slot_name.is_empty():
				var _load_color := Color(0, 0, 0, 0)
				var _found_in_inv := false
				if player.get("inventory") != null:
					for inv_item in player.inventory.items:
						if str(inv_item.item_name) == slot_name:
							_found_in_inv = true
							if inv_item.has_meta("clothing_color"):
								_load_color = inv_item.get_meta("clothing_color")
							break
				if not _found_in_inv and player.get("inventory") != null:
					var _weight := 0.3
					var _use := 0.05
					if slot_name == "Pantalones":
						_weight = 0.5
						_use = 0.10
					elif slot_name == "Zapatillas":
						_weight = 0.4
						_use = 0.08
					player.inventory.add_item(ItemScript.create(slot_name, "clothing", _weight, 1, _use))
				player.equip_clothing(slot_name, _load_color)
	# Restore equipped backpack
	var equipped_backpack := str(data.get("equipped_backpack", ""))
	if not equipped_backpack.is_empty() and player.has_method("equip_backpack"):
		player.equip_backpack(equipped_backpack)
	# Sync held item
	if player.has_method("_sync_held_item"):
		player._sync_held_item()
	# State flags — don't restore sleeping to prevent being stuck on load
	player.is_sleeping = false
	player.is_sitting = bool(data.get("sitting", false))
	player.is_prone = bool(data.get("prone", false))
	player.is_crouching = bool(data.get("crouching", false))
	# Restore _initializing flag
	player.set("_initializing", prev_init)

static func apply_saved_world_data(main: Node, data: Dictionary) -> void:
	if data.is_empty():
		return
	# Depleted action IDs — remove from world
	var depleted = data.get("depleted_action_ids", [])
	var legit_cut: Array = data.get("legit_cut_trees", [])
	# Restore legit cut trees list
	for tree_id in legit_cut:
		if not main._legit_cut_trees.has(tree_id):
			main._legit_cut_trees.append(tree_id)
	for action_id in depleted:
		# Skip fake fell_tree_* IDs (from _deactivate_tree bug)
		if str(action_id).begins_with("fell_tree_") and not legit_cut.has(action_id):
			continue
		if main.world_actions_by_id.has(action_id):
			var action = main.world_actions_by_id[action_id]
			if main.has_method("_hide_action_visual"):
				main._hide_action_visual(action)
			action.mark_depleted()
			main.world_actions_by_id.erase(action_id)
		if not main._depleted_action_ids.has(action_id):
			main._depleted_action_ids.append(action_id)
	# Fallback: use saved cut tree positions to hide any trees that weren't caught by ID matching
	var cut_positions = data.get("cut_tree_positions", [])
	for pos_arr in cut_positions:
		if pos_arr is Array and pos_arr.size() >= 3:
			var cpos := Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
			if main.has_method("_hide_multimesh_tree_at"):
				main._hide_multimesh_tree_at(cpos)
			if main.has_method("_create_cut_tree_remains"):
				main._create_cut_tree_remains(cpos)
	# Dropped items — spawn visuals
	var dropped = data.get("dropped_items", [])
	for drop in dropped:
		var drop_id := str(drop.get("id", ""))
		if drop_id.is_empty() or main.world_actions_by_id.has(drop_id):
			continue
		# Skip if this item was already picked up (depleted)
		if main._depleted_action_ids.has(drop_id):
			continue
		var dpos_raw = drop.get("pos", [0.0, 0.06, 0.0])
		var dpos: Vector3
		if dpos_raw is Array:
			dpos = Vector3(float(dpos_raw[0]), float(dpos_raw[1]), float(dpos_raw[2]))
		else:
			dpos = dpos_raw
		var drop_at := str(drop.get("action_type", ""))
		var drop_name := str(drop.get("name", ""))
		var drop_type := str(drop.get("type", ""))
		if drop_at == "wolf_meat_raw":
			if main.has_method("_spawn_raw_meat_visual"):
				main._spawn_raw_meat_visual(drop_id, drop_name, dpos)
		elif drop_name == "Antorcha" and drop_type == "tool_torch":
			if main.has_method("_spawn_placed_torch"):
				var torch_dur := float(drop.get("durability", 120.0))
				var torch_lit := bool(drop.get("lit", false))
				main._spawn_placed_torch(drop_id, dpos, torch_dur, torch_lit)
		else:
			if main.has_method("_spawn_dropped_item_visual"):
				var drop_color := Color(0, 0, 0, 0)
				var color_arr = drop.get("color")
				if color_arr is Array and color_arr.size() >= 4:
					drop_color = Color(float(color_arr[0]), float(color_arr[1]), float(color_arr[2]), float(color_arr[3]))
				main._spawn_dropped_item_visual(drop_id, drop_name, drop_type, float(drop.get("weight", 0.1)), int(drop.get("qty", 1)), float(drop.get("use", 0.0)), dpos, drop_color)
		main._dropped_items.append(drop)
	# Built campfires
	var campfires = data.get("built_campfires", [])
	for cf in campfires:
		var cf_id := str(cf.get("id", ""))
		if cf_id.is_empty() or main.world_actions_by_id.has(cf_id):
			continue
		var cf_pos_raw = cf.get("pos", [0.0, 0.0, 0.0])
		var cf_pos: Vector3
		if cf_pos_raw is Array:
			cf_pos = Vector3(float(cf_pos_raw[0]), float(cf_pos_raw[1]), float(cf_pos_raw[2]))
		else:
			cf_pos = cf_pos_raw
		if main.has_method("_spawn_player_campfire_with_id"):
			main._spawn_player_campfire_with_id(cf_id, cf_pos)
		main._built_campfires.append(cf)
	# Lit campfires
	var lit = data.get("lit_campfires", [])
	for lc in lit:
		var lc_id := str(lc.get("id", ""))
		if lc_id.is_empty() or not main.world_actions_by_id.has(lc_id):
			continue
		var action = main.world_actions_by_id[lc_id]
		if not action.get_meta("lit", false):
			var lc_pos_raw = lc.get("pos", [0.0, 0.0, 0.0])
			var lc_pos: Vector3
			if lc_pos_raw is Array:
				lc_pos = Vector3(float(lc_pos_raw[0]), float(lc_pos_raw[1]), float(lc_pos_raw[2]))
			else:
				lc_pos = lc_pos_raw
			var lc_fire_name := str(lc.get("fire_name", ""))
			if main.has_method("_create_campfire_fire"):
				main._create_campfire_fire(lc_pos + Vector3(0, 0.15, 0), lc_fire_name)
			action.set_meta("lit", true)
			action.set_meta("fire_name", lc_fire_name)
			action.action_type = "cook"
			action.display_name = "Fogata encendida"
			action.repeatable = true
		main._lit_campfires.append(lc)
	# Built shelters
	var shelters = data.get("built_shelters", [])
	for sh in shelters:
		var sh_id := str(sh.get("id", ""))
		if sh_id.is_empty() or main.world_actions_by_id.has(sh_id):
			continue
		var sh_pos_raw = sh.get("pos", [0.0, 0.0, 0.0])
		var sh_pos: Vector3
		if sh_pos_raw is Array:
			sh_pos = Vector3(float(sh_pos_raw[0]), float(sh_pos_raw[1]), float(sh_pos_raw[2]))
		else:
			sh_pos = sh_pos_raw
		if main.has_method("_spawn_player_shelter_with_id"):
			main._spawn_player_shelter_with_id(sh_id, sh_pos)
		main._built_shelters.append(sh)
	# Open doors
	var open_doors = data.get("open_doors", [])
	main._pending_open_doors = open_doors.duplicate()
	if main.has_method("_apply_pending_doors"):
		main._apply_pending_doors()
	# Dead wildlife — mark existing animals as dead or skip respawn
	var dead_wl = data.get("dead_wildlife", [])
	for dw in dead_wl:
		var dw_name := str(dw.get("name", ""))
		var dw_type := str(dw.get("type", "wolf"))
		var dw_gutted := bool(dw.get("gutted", false))
		var dw_pos_raw = dw.get("pos", [0.0, 0.0, 0.0])
		var dw_pos: Vector3
		if dw_pos_raw is Array:
			dw_pos = Vector3(float(dw_pos_raw[0]), float(dw_pos_raw[1]), float(dw_pos_raw[2]))
		else:
			dw_pos = dw_pos_raw
		var dw_rot := float(dw.get("rot", 0.0))
		# Find the animal by name in the current scene
		var found := false
		for node in main.get_tree().get_nodes_in_group("wildlife"):
			if node == null or not is_instance_valid(node):
				continue
			if node.name == dw_name:
				node.set("_is_dead", true)
				node.set("_gutted", dw_gutted)
				node.set("health", 0.0)
				node.set("_rot_timer", float(dw.get("rot_timer", 300.0)))
				node.global_position = dw_pos
				node.rotation.y = dw_rot
				if node.has_method("_lie_corpse_flat"):
					node._lie_corpse_flat()
				found = true
				break
		if not found:
			# Store for post-wildlife-creation application
			if "_pending_dead_wildlife" not in main:
				main._pending_dead_wildlife = []
			main._pending_dead_wildlife.append(dw)

static func _color_to_str(c: Color) -> String:
	return "%.4f,%.4f,%.4f" % [c.r, c.g, c.b]

static func _str_to_color(s: String) -> Color:
	if s.is_empty():
		return Color(0, 0, 0, 0)
	var parts := s.split(",")
	if parts.size() < 3:
		return Color(0, 0, 0, 0)
	return Color(float(parts[0]), float(parts[1]), float(parts[2]))
