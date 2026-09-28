extends RefCounted

# The authoritative inventory remains flat for crafting, saves and networking.
# Compartments address resources, never the current filtered/sorted indices.
static func compartments(player) -> Array:
	var result: Array = [{"id": "pockets", "name": "BOLSILLOS", "capacity": player.BASE_CARRY_SLOTS}]
	var bonuses := {"torso": player.TORSO_CARRY_SLOTS, "legs": player.LEGS_CARRY_SLOTS,
		"head": player.HEAD_CARRY_SLOTS}
	for slot in bonuses:
		var garment: String = str(player._equipped_slots.get(slot, ""))
		if garment.is_empty():
			continue
		var capacity: int = bonuses[slot]
		if "militar" in garment or "camuflaje" in garment:
			capacity += int({"torso": 3, "legs": 2}.get(slot, 0))
		result.append({"id": slot, "name": garment.to_upper(), "capacity": capacity})
	if not player.equipped_backpack.is_empty():
		result.append({"id": "backpack", "name": player.equipped_backpack.to_upper(), "capacity": player.SMALL_BACKPACK_SLOTS})
	return result

static func arrange(items: Array, containers: Array) -> Dictionary:
	var groups := {}
	for container in containers:
		groups[container.id] = []
	var pending: Array = []
	for item in items:
		var placed := false
		for container in containers:
			if item.cargo_location == container.id and groups[container.id].size() < container.capacity:
				groups[container.id].append(item)
				placed = true
				break
		if not placed:
			pending.append(item)
	for item in pending:
		var placed := false
		for container in containers:
			if groups[container.id].size() < container.capacity:
				item.cargo_location = container.id
				groups[container.id].append(item)
				placed = true
				break
		if not placed:
			if not groups.has("overflow"):
				groups.overflow = []
			groups.overflow.append(item)
	return groups

# Hover validation must not assign cargo locations or emit inventory changes.
static func can_move(item, destination: String, inventory, containers: Array) -> bool:
	if not inventory.items.has(item):
		return false
	var capacities := {}
	var counts := {}
	for container in containers:
		capacities[container.id] = container.capacity
		counts[container.id] = 0
	if not capacities.has(destination):
		return false
	var assigned := {}
	var pending: Array = []
	for entry in inventory.items:
		var location: String = entry.cargo_location
		if capacities.has(location) and counts[location] < capacities[location]:
			counts[location] += 1
			assigned[entry] = location
		else:
			pending.append(entry)
	for entry in pending:
		for container in containers:
			if counts[container.id] < capacities[container.id]:
				counts[container.id] += 1
				assigned[entry] = container.id
				break
	return assigned.get(item, "") == destination or counts[destination] < capacities[destination]

static func move(item, destination: String, inventory, containers: Array) -> bool:
	if not can_move(item, destination, inventory, containers):
		return false
	var groups := arrange(inventory.items, containers)
	for container in containers:
		if container.id == destination:
			if item.cargo_location == destination:
				return true
			if groups[destination].size() >= container.capacity:
				return false
			item.cargo_location = destination
			inventory.changed.emit()
			return true
	return false
