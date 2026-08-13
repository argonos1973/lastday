class_name NodeUtils
extends RefCounted

static func collect_mesh_instances(root: Node, result: Array) -> void:
	if root is MeshInstance3D:
		result.append(root)
	for child in root.get_children():
		collect_mesh_instances(child, result)

static func raycast_ground_y(space_state: PhysicsDirectSpaceState3D, pos: Vector3, from_y: float = 100.0) -> float:
	var query := PhysicsRayQueryParameters3D.create(Vector3(pos.x, from_y, pos.z), Vector3(pos.x, -200.0, pos.z))
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit := space_state.intersect_ray(query)
	if not hit.is_empty():
		return float(hit["position"].y)
	return 0.0

static func get_node_world_aabb_height(node: Node3D) -> float:
	node.force_update_transform()
	var meshes := []
	collect_mesh_instances(node, meshes)
	var min_y := 1000000.0
	var max_y := -1000000.0
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.force_update_transform()
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		min_y = min(min_y, world_aabb.position.y)
		max_y = max(max_y, world_aabb.position.y + world_aabb.size.y)
	if max_y > min_y:
		return max_y - min_y
	return 0.0

static func get_node_world_aabb_min_y(node: Node3D) -> float:
	node.force_update_transform()
	var meshes := []
	collect_mesh_instances(node, meshes)
	var min_y := 1000000.0
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.force_update_transform()
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		min_y = min(min_y, world_aabb.position.y)
	if min_y < 1000000.0:
		return min_y
	return 0.0

static func compute_node_world_aabb(node: Node3D) -> AABB:
	node.force_update_transform()
	var meshes := []
	collect_mesh_instances(node, meshes)
	var combined := AABB()
	var first := true
	for mesh_node in meshes:
		var mi := mesh_node as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.force_update_transform()
		var world_aabb: AABB = mi.global_transform * mi.get_aabb()
		if first:
			combined = world_aabb
			first = false
		else:
			combined = combined.merge(world_aabb)
	if first:
		return AABB(node.global_position, Vector3.ZERO)
	return combined

static func shuffled_paths(paths: Array) -> Array:
	var shuffled := paths.duplicate()
	shuffled.shuffle()
	return shuffled
