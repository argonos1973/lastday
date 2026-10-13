class_name WildlifeRoutes
extends RefCounted

static func build_circular_route(rng: RandomNumberGenerator, radius: float, angle_offset: float, num_points: int, jitter: float, is_allowed: Callable) -> Array:
	var route: Array = []
	for i in range(num_points):
		var angle := angle_offset + TAU * float(i) / float(num_points)
		var r := radius + rng.randf_range(-jitter, jitter)
		var pos := Vector3(cos(angle) * r, 0.0, sin(angle) * r)
		pos.x = clamp(pos.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
		pos.z = clamp(pos.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
		if not is_allowed.call(pos):
			pos = find_allowed_near(pos, 26.0, is_allowed)
		route.append(pos)
	return route

static func build_roaming_route(rng: RandomNumberGenerator, start: Vector3, num_points: int, step_min: float, step_max: float, is_allowed: Callable, include_start := false) -> Array:
	var route: Array = []
	var cursor := start
	if include_start:
		if not is_allowed.call(cursor):
			cursor = find_allowed_near(cursor, 105.0, is_allowed)
		route.append(cursor)
	var heading := rng.randf_range(0.0, TAU)
	var limit := GameConst.WORLD_LIMIT
	var limit_z := GameConst.WORLD_LIMIT_Z
	for _i in range(num_points):
		heading += rng.randf_range(-0.9, 0.9)
		var step := rng.randf_range(step_min, step_max)
		var candidate := cursor + Vector3(cos(heading) * step, 0.0, sin(heading) * step)
		if abs(candidate.x) > limit or candidate.z < -limit or candidate.z > limit_z:
			heading = atan2(-cursor.z, -cursor.x) + rng.randf_range(-0.6, 0.6)
			candidate = cursor + Vector3(cos(heading) * step, 0.0, sin(heading) * step)
		candidate.x = clamp(candidate.x, -limit, limit)
		candidate.z = clamp(candidate.z, -limit, limit_z)
		if not is_allowed.call(candidate):
			candidate = find_allowed_near(candidate, 26.0, is_allowed)
		route.append(candidate)
		cursor = candidate
	return route

static func build_territory_route(rng: RandomNumberGenerator, center: Vector3, num_points: int, min_radius: float, max_radius: float, territory_radius: float, is_allowed: Callable) -> Array:
	# Predators patrol a bounded home range instead of using the world-wide
	# roaming route, which otherwise drifts into towns over time.
	var route: Array = []
	var cursor := center
	var phase := rng.randf_range(0.0, TAU)
	for i in range(num_points):
		var base_angle := phase + TAU * float(i) / float(maxi(num_points, 1))
		var candidate := cursor
		var found := false
		for attempt in range(12):
			var angle := base_angle + rng.randf_range(-0.5, 0.5) + float(attempt) * 0.31
			var radius := rng.randf_range(min_radius, max_radius)
			candidate = center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.x = clamp(candidate.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
			candidate.z = clamp(candidate.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
			if Vector2(candidate.x - center.x, candidate.z - center.z).length() <= territory_radius and is_allowed.call(candidate):
				found = true
				break
		if found:
			route.append(candidate)
			cursor = candidate
		else:
			# Keep the route inside the home range when a river, lake, or building
			# blocks every candidate around this section.
			route.append(cursor)
	return route

static func build_zigzag_route(rng: RandomNumberGenerator, corner_a: Vector3, corner_b: Vector3, num_points: int, jitter: float, is_allowed: Callable) -> Array:
	var route: Array = []
	for i in range(num_points):
		var t := float(i) / float(num_points - 1) if num_points > 1 else 0.0
		var base := corner_a.lerp(corner_b, t)
		var perp := (corner_b - corner_a).cross(Vector3.UP).normalized() if (corner_b - corner_a).length() > 0.01 else Vector3.RIGHT
		var offset := perp * rng.randf_range(-jitter, jitter)
		var pos := base + offset
		pos.x = clamp(pos.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
		pos.z = clamp(pos.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
		if not is_allowed.call(pos):
			pos = find_allowed_near(pos, 26.0, is_allowed)
		route.append(pos)
	return route

static func find_allowed_near(origin: Vector3, max_radius: float, is_allowed: Callable) -> Vector3:
	for radius in [2.0, 4.0, 6.0, 9.0, 13.0, 18.0, 26.0]:
		if radius > max_radius and max_radius > 0.0:
			break
		for i in range(16):
			var angle := TAU * float(i) / 16.0
			var candidate := origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.x = clamp(candidate.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
			candidate.z = clamp(candidate.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
			if is_allowed.call(candidate):
				return candidate
	# Some water bodies (the lake is ~130 m across) are wider than max_radius.
	# Keep expanding instead of returning a disallowed point in the water.
	for radius in [36.0, 48.0, 62.0, 80.0, 105.0, 140.0]:
		for i in range(24):
			var angle := TAU * float(i) / 24.0
			var candidate := origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
			candidate.x = clamp(candidate.x, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT)
			candidate.z = clamp(candidate.z, -GameConst.WORLD_LIMIT, GameConst.WORLD_LIMIT_Z)
			if is_allowed.call(candidate):
				return candidate
	return origin

static func random_pos_far_from(origin: Vector3, min_dist: float, world_range: float) -> Vector3:
	var pos := Vector3.ZERO
	for _attempt in range(50):
		pos = Vector3(randf_range(-world_range, world_range), 0.0, randf_range(-world_range, world_range))
		if Vector2(pos.x, pos.z).distance_to(Vector2(origin.x, origin.z)) >= min_dist:
			break
	return pos

static func random_pos_far_from_all(origin: Vector3, others: Array, min_dist: float, min_from_others: float, world_range: float, is_allowed: Callable) -> Vector3:
	var pos := Vector3.ZERO
	for _attempt in range(80):
		pos = Vector3(randf_range(-world_range, world_range), 0.0, randf_range(-world_range, world_range))
		if Vector2(pos.x, pos.z).distance_to(Vector2(origin.x, origin.z)) < min_dist:
			continue
		var ok := true
		for other in others:
			if Vector2(pos.x, pos.z).distance_to(Vector2(other.x, other.z)) < min_from_others:
				ok = false
				break
		if ok and not is_allowed.call(pos):
			ok = false
		if ok:
			break
	return pos
