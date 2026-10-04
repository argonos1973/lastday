extends RefCounted

# Render slightly behind incoming snapshots, interpolating every frame instead
# of repeatedly easing towards the last packet. Never extrapolate through walls
# or water when packets stop arriving.
const BUFFER_SECONDS := 0.22
const TELEPORT_DISTANCE := 20.0
var clock := 0.0
var samples: Array[Dictionary] = []

func push(body: Node3D, pos: Vector3, yaw: float, snap := false) -> void:
	if snap or samples.is_empty() or pos.distance_to(samples.back()["pos"]) > TELEPORT_DISTANCE:
		samples.clear()
		body.global_position = pos
		body.rotation.y = yaw
	if not samples.is_empty() and is_equal_approx(float(samples.back()["time"]), clock):
		samples.pop_back()
	samples.append({"time": clock, "pos": pos, "yaw": yaw})
	while samples.size() > 16:
		samples.pop_front()

func advance(body: Node3D, delta: float) -> void:
	clock += maxf(delta, 0.0)
	if samples.is_empty():
		return
	var render_time := clock - BUFFER_SECONDS
	while samples.size() > 2 and float(samples[1]["time"]) <= render_time:
		samples.pop_front()
	var a: Dictionary = samples[0]
	var b: Dictionary = samples[1] if samples.size() > 1 else a
	var span := float(b["time"]) - float(a["time"])
	var weight := clampf((render_time - float(a["time"])) / span, 0.0, 1.0) if span > 0.00001 else 1.0
	body.global_position = (a["pos"] as Vector3).lerp(b["pos"], weight)
	body.rotation.y = lerp_angle(float(a["yaw"]), float(b["yaw"]), weight)
