extends RefCounted
## Traversal points on the actual tower ramps/ladder landings, in world metres.
## Shared by exploration, squad overwatch and ambushes; no visual nodes required.

static var _summit_routes: Array = []

static func summit_routes() -> Array:
	if not _summit_routes.is_empty():
		return _summit_routes
	var base := Vector3(HighMountainZone.SUMMIT_CENTER.x, HighMountainZone.SUMMIT_HEIGHT, HighMountainZone.SUMMIT_CENTER.y)
	var yaw := deg_to_rad(HighMountainZone.BASE_YAW_DEG)
	var watch_origin := base + HighMountainZone.WATCH_TOWER_OFFSET.rotated(Vector3.UP, yaw) - Vector3(0, 1.145 * 0.85, 0)
	var watch: Array = []
	# Corner landings are explicit: skipping one cuts across the solid shaft.
	for p in [Vector3(.55,1.145,-6.5), Vector3(.55,1.145,-2.5), Vector3(-.3,1.145,-2.5), Vector3(-1.9,2.01,-2.5),
		Vector3(-2.5,2.01,-2.5), Vector3(-2.5,2.01,-1.9), Vector3(-2.5,4.25,1.9),
		Vector3(-2.5,4.25,2.5), Vector3(-1.9,4.25,2.5), Vector3(1.9,6.49,2.5),
		Vector3(2.5,6.49,2.5), Vector3(2.5,6.49,1.9), Vector3(2.5,8.73,-1.68),
		Vector3(2.5,8.73,-2.5), Vector3(1.9,8.73,-2.5), Vector3(-1.92,10.99,-2.5),
		Vector3(-2.5,10.99,-2.5), Vector3(-2.5,10.99,0.0)]:
		watch.append(watch_origin + (p * .85).rotated(Vector3.UP, yaw) + Vector3(0,.035,0))
	_summit_routes.append({"id":"summit_watch", "points":watch, "center":watch_origin, "radius":6.0})
	var comms_origin := base + HighMountainZone.COMMS_TOWER_OFFSET.rotated(Vector3.UP, yaw)
	var ladder: Array = []
	var last_angle := 0.0
	var last_radius := 0.0
	for f in HighMountainZone.LADDER_FLIGHTS_META:
		var bottom_angle := float(f[3]) + float(f[8])
		var bottom_radius := float(f[6])
		if not ladder.is_empty():
			# Walk round the platform, never straight through the concrete shaft.
			_append_arc(ladder, comms_origin, yaw, float(f[1]) + .06, last_angle, bottom_angle, last_radius, bottom_radius)
		else:
			ladder.append(_ring_point(comms_origin, yaw, float(f[1]) + .06, bottom_angle, 9.1))
			ladder.append(_ring_point(comms_origin, yaw, float(f[1]) + .06, bottom_angle, bottom_radius))
		var climb_radius := float(f[4]) + .54
		ladder.append(_ring_point(comms_origin, yaw, float(f[1]) + .06, float(f[3]), climb_radius))
		ladder.append(_ring_point(comms_origin, yaw, float(f[2]) + .06, float(f[3]), climb_radius))
		last_angle = float(f[3]) + float(f[7])
		last_radius = float(f[5])
		ladder.append(_ring_point(comms_origin, yaw, float(f[2]) + .06, last_angle, last_radius))
	_append_arc(ladder, comms_origin, yaw, 52.06, last_angle, 135.0, last_radius, last_radius)
	_summit_routes.append({"id":"summit_comms", "points":ladder, "center":comms_origin, "radius":9.5})
	return _summit_routes

static func _ring_point(origin: Vector3, yaw: float, height: float, degrees: float, radius: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return origin + Vector3(sin(angle)*radius, height, cos(angle)*radius).rotated(Vector3.UP, yaw)

static func _append_arc(points: Array, origin: Vector3, yaw: float, height: float, from_angle: float, to_angle: float, from_r: float, to_r: float) -> void:
	var angle := rad_to_deg(angle_difference(deg_to_rad(from_angle), deg_to_rad(to_angle)))
	var steps := maxi(1, int(ceil(absf(angle) / 8.0)))
	for i in range(1, steps + 1):
		var t := float(i) / float(steps)
		points.append(_ring_point(origin, yaw, height, from_angle + angle*t, lerpf(from_r, to_r, t)))

static func contains(route: Dictionary, pos: Vector3, elevated_only: bool = false) -> bool:
	var points: Array = route["points"]
	var foot: Vector3 = points[0]
	var center: Vector3 = route.get("center", foot)
	return Vector2(pos.x-center.x, pos.z-center.z).length() <= float(route["radius"]) \
		and pos.y >= foot.y + (.45 if elevated_only else -.5) and pos.y <= (points.back() as Vector3).y + 1.5

static func waypoint(cur: Vector3, goal: Vector3, points: Array, goal_on_tower: bool) -> Vector3:
	# Project onto segments, not vertices: nearest-vertex + 1 used to skip
	# corners halfway through a flight and cut straight through tower walls.
	var here := _project(cur, points)
	var target := _project(goal, points) if goal_on_tower else {"progress":0.0, "point":points[0]}
	var projection: Vector3 = here["point"]
	if cur.distance_squared_to(projection) > .04:
		return projection
	var progress: float = here["progress"]
	var end_progress: float = target["progress"]
	var ascending := end_progress >= progress
	if absf(end_progress-progress) < .001 or cur.distance_to(target["point"]) < .12:
		return goal
	var idx := int(floor(progress))+1 if ascending else int(ceil(progress))-1
	if idx >= 0 and idx < points.size() and cur.distance_to(points[idx]) < .12:
		idx += 1 if ascending else -1
	if (ascending and float(idx) > end_progress) or (not ascending and float(idx) < end_progress):
		return target["point"]
	return points[clampi(idx,0,points.size()-1)]

static func _project(pos: Vector3, points: Array) -> Dictionary:
	var best := INF
	var result := {"progress":0.0, "point":points[0]}
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var ab: Vector3 = points[i+1]-a
		var t := clampf((pos-a).dot(ab)/maxf(ab.length_squared(),.0001),0.0,1.0)
		var q := a+ab*t
		var dist := pos.distance_squared_to(q)
		if dist < best:
			best = dist
			result = {"progress":float(i)+t, "point":q}
	return result

static func on_corridor(pos: Vector3, points: Array, width: float = .55) -> bool:
	return pos.distance_squared_to(_project(pos,points)["point"]) <= width*width
