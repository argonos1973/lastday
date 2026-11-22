extends RefCounted
## Cosmetic context only: the existing pickup claim owns the world transaction.
## One shared clip, existing item models, no world scans or server-side rendering.
const DURATION := 1.4
const GRAB_TIME := 0.7
const PREFIX := "ground_item|"
const ItemScript = preload("res://scripts/Item.gd")

var actor: Node3D
var action_id := ""
var phase := ""
var item
var elapsed := 0.0
var grabbed := false
var hidden_visuals: Array = []
var source_action: Node3D

static func packet(kind: String, id: String, item_name: String, item_type: String, time := 0.0) -> String:
	return PREFIX + "|".join([kind, id.uri_encode(), item_name.uri_encode(), item_type.uri_encode(), "%.2f" % clampf(time, 0.0, 10.0)])

static func decode(value: String) -> PackedStringArray:
	if not value.begins_with(PREFIX) or value.length() > 1024:
		return PackedStringArray()
	var fields := value.trim_prefix(PREFIX).split("|")
	if fields.size() not in [4, 5] or fields[0] not in ["pickup", "eat"]:
		return PackedStringArray()
	for i in range(1, 4):
		fields[i] = fields[i].uri_decode()
	return fields

func setup(owner_actor: Node3D, fields: PackedStringArray) -> void:
	actor = owner_actor
	phase = fields[0]
	elapsed = clampf(float(fields[4]), 0.0, 10.0) if fields.size() > 4 else 0.0
	action_id = fields[1]
	item = ItemScript.create(fields[2], fields[3], 0.1, 1, 0.0)
	_cache_source_visuals()
	apply_equipment()
	_set_grabbed(phase == "eat" or elapsed >= GRAB_TIME)

func _measure_world_aabb(root: Node) -> AABB:
	var has_any := false
	var combined := AABB()
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Node3D and not (n as Node3D).visible:
			continue
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var world_box := mi.global_transform * mi.get_aabb()
			combined = world_box if not has_any else combined.merge(world_box)
			has_any = true
		for c in n.get_children():
			stack.append(c)
	return combined

func _cache_source_visuals() -> void:
	var world := actor.get_tree().current_scene
	if world == null or not ("world_actions_by_id" in world):
		return
	var action = world.world_actions_by_id.get(action_id)
	if not is_instance_valid(action) or actor.global_position.distance_to(action.global_position) > 6.0:
		return
	source_action = action
	if item != null:
		if action.has_meta("item_pelt"):
			item.set_meta("pelt_species", str(action.get_meta("item_pelt")))
		if action.has_meta("item_color"):
			item.set_meta("clothing_color", action.get_meta("item_color"))
		if action.has_meta("item_camo"):
			item.set_meta("clothing_camo", bool(action.get_meta("item_camo")))
	var measured := AABB()
	var has_measured := false
	for visual_name in str(action.get_meta("visual_name", "")).split("|", false):
		var visual := world.get_node_or_null(NodePath(visual_name))
		if visual is Node3D:
			hidden_visuals.append([visual, visual.visible])
			var vbox := _measure_world_aabb(visual)
			if vbox.size.length_squared() > 0.0001:
				measured = vbox if not has_measured else measured.merge(vbox)
				has_measured = true
	if has_measured and item != null:
		item.set_meta("_ground_aabb_size", measured.size)
	var marker = action.get("_mesh_instance")
	if is_instance_valid(marker):
		hidden_visuals.append([marker, marker.visible])

func apply_equipment() -> void:
	if not is_instance_valid(actor) or actor.third_person_model == null:
		return
	actor._sync_third_person_equipment(item, true)
	actor._fit_held_prop_to_palm(item)
	actor._update_hand_socket()
	if is_instance_valid(actor._rifle_left_arm_ik):
		actor._rifle_left_arm_ik.active = false
	_update_hand_visibility()

func _update_hand_visibility() -> void:
	for property in ["third_person_hand_item_root", "_rifle_root", "_bow_root", "_torch_hand_root"]:
		if property in actor:
			var node = actor.get(property)
			if is_instance_valid(node) and node is Node3D:
				node.visible = grabbed

func _set_grabbed(value: bool) -> void:
	grabbed = value
	_update_hand_visibility()
	if grabbed:
		for entry in hidden_visuals:
			if is_instance_valid(entry[0]):
				var owners: Dictionary = entry[0].get_meta("_ground_gesture_owners", {})
				if owners.is_empty():
					entry[0].set_meta("_ground_gesture_visible", entry[0].visible)
				owners[actor.get_instance_id()] = true
				entry[0].set_meta("_ground_gesture_owners", owners)
				entry[0].visible = false
	else:
		_restore_source()

func tick(delta: float) -> void:
	elapsed += delta
	if not grabbed and elapsed >= GRAB_TIME:
		_set_grabbed(true)

func change_phase(value: String) -> void:
	phase = value
	elapsed = 0.0
	_set_grabbed(value == "eat")

func close() -> void:
	# These sockets are reused by the real equipment after a cancellation,
	# including cancellations before the temporary object became visible.
	grabbed = true
	_update_hand_visibility()
	_restore_source()
	hidden_visuals.clear()

func _restore_source() -> void:
	for entry in hidden_visuals:
		if not is_instance_valid(entry[0]) or entry[0].is_queued_for_deletion():
			continue
		var owners: Dictionary = entry[0].get_meta("_ground_gesture_owners", {})
		if not owners.has(actor.get_instance_id()):
			continue
		owners.erase(actor.get_instance_id())
		if owners.is_empty():
			if is_instance_valid(source_action) and not source_action.get("depleted"):
				entry[0].visible = bool(entry[0].get_meta("_ground_gesture_visible", entry[1]))
			entry[0].remove_meta("_ground_gesture_visible")
			entry[0].remove_meta("_ground_gesture_owners")
		else:
			entry[0].set_meta("_ground_gesture_owners", owners)
