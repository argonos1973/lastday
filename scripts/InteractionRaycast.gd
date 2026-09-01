extends RayCast3D
class_name InteractionRaycast

@export var interaction_distance := 0.5:
	set(value):
		interaction_distance = max(0.05, value)
		target_position = Vector3(0.0, 0.0, -interaction_distance)

# In third person the camera is behind the player, so this trace only finds what
# is under the reticle. The final pickup distance is still checked against the
# player and limited by interaction_distance.
@export var camera_trace_distance := 7.0

func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -interaction_distance)
	collide_with_areas = true
	collide_with_bodies = true

func get_interactable(player: Node3D, camera: Camera3D, screen_offset := Vector2.ZERO):
	var collider: Object = _get_collider_from_camera(player, camera, screen_offset)
	if collider != null:
		var target: Object = _find_interactable_owner(collider)
		if target != null and _is_close_enough(player, target):
			return target
	# Fallback: find nearest interactable within interaction distance
	return _find_nearest_interactable(player)

func get_default_text(target, player = null) -> String:
	if target != null and target.has_method("get_interaction_text"):
		return str(target.call("get_interaction_text", player))
	if target != null:
		return "Pulsa E para interactuar"
	return ""

func _get_collider_from_camera(player: Node3D, camera: Camera3D, screen_offset: Vector2) -> Object:
	if camera == null or camera.get_world_3d() == null:
		return null
	var viewport: Viewport = camera.get_viewport()
	if viewport == null:
		return null
	var aim_point: Vector2 = viewport.get_visible_rect().size * 0.5 + screen_offset
	var origin: Vector3 = camera.project_ray_origin(aim_point)
	var end: Vector3 = origin + camera.project_ray_normal(aim_point) * camera_trace_distance
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, end)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	var exclude_rids: Array[RID] = [player.get_rid()]
	_collect_child_collision_rids(player, exclude_rids)
	query.exclude = exclude_rids
	var result: Dictionary = camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return null
	return result.get("collider", null)

func _find_interactable_owner(node: Object) -> Object:
	var cursor: Object = node
	while cursor != null:
		if cursor.is_in_group("interactable") or cursor.has_method("interact"):
			return cursor
		cursor = cursor.get_parent() if cursor is Node else null
	return null

func _collect_child_collision_rids(node: Node, rids: Array[RID]) -> void:
	for child in node.get_children():
		if child is CollisionObject3D:
			rids.append((child as CollisionObject3D).get_rid())
		_collect_child_collision_rids(child, rids)

func _is_close_enough(player: Node3D, target: Object) -> bool:
	if player == null or not target is Node3D:
		return false
	var target_pos := (target as Node3D).global_position
	var player_pos := player.global_position
	var flat_distance := Vector2(player_pos.x, player_pos.z).distance_to(Vector2(target_pos.x, target_pos.z))
	var reach_padding := 0.0
	if target is CollisionObject3D:
		for child in (target as Node).get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
				var box := (child as CollisionShape3D).shape as BoxShape3D
				reach_padding = max(reach_padding, max(box.size.x, box.size.z) * 0.5)
	# árboles y arbustos requieren estar muy cerca
	if target is WorldAction:
		var wa := target as WorldAction
		if wa.action_type == "fell_tree":
			return flat_distance <= 2.0
		elif wa.action_type == "fell_bush":
			return flat_distance <= 1.5
	return flat_distance <= interaction_distance + reach_padding

func _find_nearest_interactable(player: Node3D) -> Object:
	if player == null or player.get_tree() == null:
		return null
	var player_pos := player.global_position
	var best: Object = null
	var best_dist := 999.0
	for node in player.get_tree().get_nodes_in_group("interactable"):
		if not (node is Node3D):
			continue
		if node is WorldAction:
			var wa := node as WorldAction
			if wa.depleted and not wa.repeatable:
				continue
			# Only use fallback for choppable objects and pickup items
			if wa.action_type != "fell_tree" and wa.action_type != "fell_bush" and wa.action_type != "cut_log" and wa.action_type != "pickup_item" and wa.action_type != "eat_food" and wa.action_type != "light_campfire" and wa.action_type != "cook":
				continue
		var node_pos := (node as Node3D).global_position
		var flat_dist := Vector2(player_pos.x, player_pos.z).distance_to(Vector2(node_pos.x, node_pos.z))
		var reach := 0.0
		var max_dist := interaction_distance
		if node is CollisionObject3D:
			for child in (node as Node).get_children():
				if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
					var box := (child as CollisionShape3D).shape as BoxShape3D
					reach = max(reach, max(box.size.x, box.size.z) * 0.5)
		if node is WorldAction:
			var wa2 := node as WorldAction
			if wa2.action_type == "fell_tree":
				max_dist = 2.0
			elif wa2.action_type == "fell_bush":
				max_dist = 1.5
		var total_dist := flat_dist - reach
		if total_dist < max_dist and total_dist < best_dist:
			# Los árboles talables tienen la colisión deshabilitada, así que
			# el raycast de línea de visión pasa a través de ellos pero puede
			# chocar con otros árboles del bosque denso. Se omite la comprobación
			# para árboles y arbustos: si el jugador está bastante cerca, basta.
			if node is WorldAction:
				var wa3 := node as WorldAction
				if wa3.action_type == "fell_tree" or wa3.action_type == "fell_bush" or wa3.action_type == "cut_log":
					# Verificar que el jugador está mirando hacia el árbol
					var dir_to_node := (node_pos - player_pos).normalized()
					dir_to_node.y = 0.0
					var player_forward := -player.global_transform.basis.z
					player_forward.y = 0.0
					player_forward = player_forward.normalized()
					if player_forward.dot(dir_to_node) < 0.6:
						continue
					best_dist = total_dist
					best = node
					continue
			if not _has_line_of_sight(player, node):
				continue
			var dir_to_node2 := (node_pos - player_pos)
			dir_to_node2.y = 0.0
			if dir_to_node2.length() > 0.2:
				dir_to_node2 = dir_to_node2.normalized()
				var player_forward2 := -player.global_transform.basis.z
				player_forward2.y = 0.0
				player_forward2 = player_forward2.normalized()
				if player_forward2.dot(dir_to_node2) < 0.3:
					continue
			best_dist = total_dist
			best = node
	return best

func _has_line_of_sight(player: Node3D, target: Node3D) -> bool:
	var space_state := player.get_world_3d().direct_space_state
	if space_state == null:
		return true
	var from: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var to: Vector3 = target.global_position + Vector3(0, 1.0, 0)
	# Adjust target point to center of collision box if available
	if target is CollisionObject3D:
		for child in (target as Node).get_children():
			if child is CollisionShape3D and (child as CollisionShape3D).shape is BoxShape3D:
				var col := child as CollisionShape3D
				var box := col.shape as BoxShape3D
				to = target.global_position + col.position + Vector3(0, box.size.y * 0.5, 0)
				break
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var exclude_rids: Array[RID] = [player.get_rid()]
	_collect_child_collision_rids(player, exclude_rids)
	if target is CollisionObject3D:
		exclude_rids.append((target as CollisionObject3D).get_rid())
		_collect_child_collision_rids(target, exclude_rids)
	query.exclude = exclude_rids
	var result: Dictionary = space_state.intersect_ray(query)
	return result.is_empty()
