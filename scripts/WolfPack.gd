extends RefCounted
## One small, authoritative pack. No process callback, world scan or new actors.
const MAX_MEMBERS := 4
var id := ""
var members: Array[Node3D] = []
var leader: Node3D

func _init(pack_id := "") -> void:
	id = pack_id

static func active(wolf) -> bool:
	return is_instance_valid(wolf) and not wolf.is_queued_for_deletion() \
		and wolf.get("_is_dead") != true and wolf.get("is_puppet") != true \
		and str(wolf.get("tamed_to")).is_empty()

func prune() -> void:
	for i in range(members.size() - 1, -1, -1):
		if not active(members[i]):
			members.remove_at(i)
	if not active(leader):
		leader = null

func add(wolf: Node3D) -> bool:
	prune()
	if members.has(wolf):
		return true
	if members.size() >= MAX_MEMBERS:
		return false
	if leader == null:
		members.push_front(wolf)
		leader = wolf
		wolf.set_black_coat(true)
	else:
		members.append(wolf)
	return true

func remove(wolf: Node3D) -> void:
	members.erase(wolf)
	if leader == wolf:
		leader = null

func guide() -> Node3D:
	if active(leader):
		return leader
	# Survivors stay together until the normal population respawn replaces
	# the black leader. Do not magically recolor a grey wolf on promotion.
	for wolf in members:
		if active(wolf):
			return wolf
	return null

func patrol(wolf: Node3D) -> Dictionary:
	var front := guide()
	if front == null:
		return {}
	if front == wolf:
		var pace := 1.0
		for mate in members:
			if mate != wolf and active(mate):
				var d := wolf.global_position.distance_squared_to(mate.global_position)
				if d > 20.0 * 20.0 and d < 90.0 * 90.0:
					pace = 0.6
		return {"target": wolf.patrol_points[wolf.target_index], "speed": wolf.move_speed * pace}
	var slot := maxi(0, members.find(wolf) - 1)
	var offsets := [Vector3(-3, 0, -4), Vector3(3.5, 0, -6), Vector3(-1, 0, -8)]
	var goal: Vector3 = front.global_position + front.global_basis * offsets[slot % offsets.size()]
	if not wolf._is_position_allowed(goal):
		# Narrow banks/doorways: fall into single file instead of trying to
		# occupy an offset inside water or a wall. Movement still uses nav.
		goal = front.global_position - front.global_basis.z * (4.0 + slot * 2.5)
		if not wolf._is_position_allowed(goal):
			goal = front.global_position
	var distance := wolf.global_position.distance_to(goal)
	if distance < 2.0:
		return {"target": wolf.global_position, "speed": 0.0}
	return {"target": goal, "speed": wolf.move_speed * clampf(1.0 + distance * 0.07, 1.0, 2.6)}

func hunting_prey(wolf: Node3D) -> Node3D:
	for mate in members:
		if mate == wolf or not active(mate) or str(mate.get("_state")) != "chase_prey":
			continue
		if wolf.global_position.distance_squared_to(mate.global_position) > 55.0 * 55.0:
			continue
		var prey = mate.get("_chase_target")
		if is_instance_valid(prey) and prey is Node3D and prey.get("_is_dead") != true \
				and wolf.global_position.distance_squared_to(prey.global_position) < 45.0 * 45.0:
			return prey
	return null
