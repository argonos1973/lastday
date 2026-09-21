class_name NavPathfinding
extends RefCounted

var _grid: Dictionary = {}
var _grid_size := 484 # Covers the wildlife world limits (-480 to +480 m).
var _cell_size := 2.0
var _built := false
var _door_open_cache: Dictionary = {}
var _search := AStarGrid2D.new()

func world_to_grid(pos: Vector3) -> Vector2i:
	return Vector2i(int(round(pos.x / _cell_size)) + _grid_size / 2, int(round(pos.z / _cell_size)) + _grid_size / 2)

func grid_to_world(cell: Vector2i) -> Vector3:
	return Vector3(float(cell.x - _grid_size / 2) * _cell_size, 0.0, float(cell.y - _grid_size / 2) * _cell_size)

func build(blockers: Array, river_segments: Array) -> void:
	_grid.clear()
	for blocker in blockers:
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var radius: float = float(blocker.get("radius", 1.8))
		if blocker.has("house_bounds"):
			var bounds: Rect2 = blocker["house_bounds"]
			var expanded := bounds.grow(3.5)
			var min_cell := world_to_grid(Vector3(expanded.position.x, 0.0, expanded.position.y))
			var max_cell := world_to_grid(Vector3(expanded.position.x + expanded.size.x, 0.0, expanded.position.y + expanded.size.y))
			for gx in range(min_cell.x, max_cell.x + 1):
				for gy in range(min_cell.y, max_cell.y + 1):
					if gx >= 0 and gx < _grid_size and gy >= 0 and gy < _grid_size:
						_grid[Vector2i(gx, gy)] = true
			continue
		var center_cell := world_to_grid(blocker_pos)
		var cell_radius := int(ceil(radius / _cell_size)) + 1
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
				if cell.x < 0 or cell.x >= _grid_size or cell.y < 0 or cell.y >= _grid_size:
					continue
				var world_pos := grid_to_world(cell)
				if Vector2(world_pos.x - blocker_pos.x, world_pos.z - blocker_pos.z).length() <= radius:
					_grid[cell] = true
	_block_river_cells(river_segments)
	_search.region = Rect2i(0, 0, _grid_size, _grid_size)
	_search.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_search.update()
	for x in range(_grid_size):
		for z in range(_grid_size):
			var cell := Vector2i(x, z)
			_search.set_point_solid(cell, is_cell_blocked(cell))
	_built = true

func _block_river_cells(river_segments: Array) -> void:
	for segment in river_segments:
		var size: Vector2 = segment["size"]
		var center: Vector3 = segment["center"]
		var yaw: float = deg_to_rad(float(segment["yaw"]))
		var along := Vector3(cos(yaw), 0.0, -sin(yaw))
		var across := Vector3(sin(yaw), 0.0, cos(yaw))
		# Match the movement water boundary, with room for a grid cell's corners.
		var margin := 1.2 + _cell_size * 0.71
		var half_length := size.x * (0.425 if size.x >= 60.0 else 0.5) + margin
		var half_width := size.y * (0.425 if size.x >= 60.0 else 0.5) + margin
		var steps_l := int(ceil(half_length * 4.0 / _cell_size)) + 1
		var steps_w := int(ceil(half_width * 4.0 / _cell_size)) + 1
		for i in range(steps_l + 1):
			var local_along: float = lerp(-half_length, half_length, float(i) / float(steps_l))
			for j in range(steps_w + 1):
				var local_across: float = lerp(-half_width, half_width, float(j) / float(steps_w))
				if size.x >= 60.0 and pow(local_along / half_length, 2) + pow(local_across / half_width, 2) > 1.0:
					continue
				var world_pos: Vector3 = center + along * local_along + across * local_across
				var cell := world_to_grid(world_pos)
				if cell.x >= 0 and cell.x < _grid_size and cell.y >= 0 and cell.y < _grid_size:
					_grid[cell] = true

func is_cell_blocked(cell: Vector2i) -> bool:
	if cell.x < 1 or cell.x >= _grid_size - 1 or cell.y < 1 or cell.y >= _grid_size - 1:
		return true
	if not _grid.has(cell):
		return false
	if _door_open_cache.has(cell):
		return false
	return true

func find_path(start: Vector3, goal: Vector3) -> Array:
	if not _built:
		return [goal]
	var start_cell := world_to_grid(start)
	var goal_cell := world_to_grid(goal)
	if is_cell_blocked(goal_cell):
		goal_cell = _nearest_free_cell(goal_cell)
	if is_cell_blocked(start_cell):
		start_cell = _nearest_free_cell(start_cell)
	if is_cell_blocked(start_cell) or is_cell_blocked(goal_cell):
		return []
	if start_cell == goal_cell:
		return [grid_to_world(goal_cell)]
	return _astar(start_cell, goal_cell, start)

func _nearest_free_cell(cell: Vector2i) -> Vector2i:
	for radius in range(1, 10):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if abs(dx) != radius and abs(dy) != radius:
					continue
				var candidate := Vector2i(cell.x + dx, cell.y + dy)
				if not is_cell_blocked(candidate):
					return candidate
	return cell

func _astar(start_cell: Vector2i, goal_cell: Vector2i, start_world: Vector3) -> Array:
	# A partial path leads to the reachable shore when the target is in water
	# or on a disconnected bank. Never fall back to walking straight through it.
	var cells := _search.get_id_path(start_cell, goal_cell, true)
	var path: Array = []
	for cell in cells:
		path.append(grid_to_world(cell))
	if path.size() > 1 and _is_path_clear(start_world, path[1]):
		path.pop_front()
	return _smooth_path(path)

func _get_neighbors(cell: Vector2i) -> Array:
	return [
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x, cell.y + 1),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x + 1, cell.y + 1),
		Vector2i(cell.x + 1, cell.y - 1),
		Vector2i(cell.x - 1, cell.y + 1),
		Vector2i(cell.x - 1, cell.y - 1)
	]

func _reconstruct_path(came_from: Dictionary, current: Vector2i, start_world: Vector3) -> Array:
	var cells: Array = [current]
	while came_from.has(current):
		current = came_from[current]
		cells.push_front(current)
	var path: Array = []
	for i in range(cells.size()):
		if i == 0:
			continue
		path.append(grid_to_world(cells[i]))
	if path.is_empty():
		path.append(grid_to_world(cells[0]))
	return _smooth_path(path)

func _smooth_path(path: Array) -> Array:
	if path.size() <= 2:
		return path
	var smoothed: Array = [path[0]]
	var current_idx := 0
	while current_idx < path.size() - 1:
		var farthest := current_idx + 1
		for j in range(path.size() - 1, current_idx + 1, -1):
			if _is_path_clear(path[current_idx], path[j]):
				farthest = j
				break
		smoothed.append(path[farthest])
		current_idx = farthest
	return smoothed

func _is_path_clear(a: Vector3, b: Vector3) -> bool:
	var diff := b - a
	diff.y = 0.0
	var dist := diff.length()
	if dist < 0.01:
		return true
	var dir := diff.normalized()
	var steps := int(ceil(dist / (_cell_size * 0.25)))
	var previous := world_to_grid(a)
	for i in range(steps + 1):
		var pos := a + dir * (dist * float(i) / float(steps))
		var cell := world_to_grid(pos)
		if is_cell_blocked(cell):
			return false
		if cell.x != previous.x and cell.y != previous.y:
			if is_cell_blocked(Vector2i(cell.x, previous.y)) or is_cell_blocked(Vector2i(previous.x, cell.y)):
				return false
		previous = cell
	return true

func update_door_cache(blockers: Array, is_in_doorway: Callable, is_in_barn_doorway: Callable) -> void:
	var previous := _door_open_cache.duplicate()
	_door_open_cache.clear()
	for blocker in blockers:
		var blocker_pos: Vector3 = blocker.get("pos", Vector3.ZERO)
		var is_barn_always_open: bool = blocker.get("barn_door_always_open", false) == true
		var door = blocker.get("door", null)
		if not is_barn_always_open:
			if door == null or not is_instance_valid(door):
				continue
			if door.get("is_open") != true:
				continue
		if blocker.has("house_bounds"):
			var bounds: Rect2 = blocker["house_bounds"]
			var expanded := bounds.grow(3.5)
			var min_cell := world_to_grid(Vector3(expanded.position.x, 0.0, expanded.position.y))
			var max_cell := world_to_grid(Vector3(expanded.position.x + expanded.size.x, 0.0, expanded.position.y + expanded.size.y))
			for gx in range(min_cell.x, max_cell.x + 1):
				for gy in range(min_cell.y, max_cell.y + 1):
					if gx < 0 or gx >= _grid_size or gy < 0 or gy >= _grid_size:
						continue
					var cell := Vector2i(gx, gy)
					if not _grid.has(cell):
						continue
					var world_pos := grid_to_world(cell)
					if is_barn_always_open:
						if is_in_barn_doorway.call(world_pos, blocker):
							_door_open_cache[cell] = true
					elif is_in_doorway.call(world_pos, blocker_pos):
						_door_open_cache[cell] = true
			continue
		var radius: float = float(blocker.get("radius", 1.8))
		var center_cell := world_to_grid(blocker_pos)
		var cell_radius := int(ceil(radius / _cell_size)) + 1
		for dx in range(-cell_radius, cell_radius + 1):
			for dy in range(-cell_radius, cell_radius + 1):
				var cell := Vector2i(center_cell.x + dx, center_cell.y + dy)
				if cell.x < 0 or cell.x >= _grid_size or cell.y < 0 or cell.y >= _grid_size:
					continue
				if not _grid.has(cell):
					continue
				var world_pos := grid_to_world(cell)
				var local_x := world_pos.x - blocker_pos.x
				var local_z := world_pos.z - blocker_pos.z
				if abs(local_x) <= 1.5 and local_z >= -5.2 and local_z <= 10.0:
					_door_open_cache[cell] = true
	if _built:
		for cell in previous:
			_search.set_point_solid(cell, is_cell_blocked(cell))
		for cell in _door_open_cache:
			_search.set_point_solid(cell, is_cell_blocked(cell))
