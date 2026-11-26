extends RefCounted
## Outcome validation against authoritative inventory, stats and live actors.
## Manager supplies existing world/relationship/combat queries, never another planner.
const Diagnostics = preload("res://scripts/bot_ai/BotPlanDiagnostics.gd")
const PURPOSES := ["general", "gear", "food", "water", "ammo", "clothing", "tools", "weapons", "meat"]

static func note_acquisition(m, b: Dictionary, name: String, type: String) -> void:
	b["_loot_n"] = int(b.get("_loot_n", 0)) + 1
	if type == "food":
		b["_loot_food_n"] = int(b.get("_loot_food_n", 0)) + 1
	var kind := category(name, type)
	var counts: Dictionary = b.get("_plan_loot", {})
	counts[kind] = int(counts.get(kind, 0)) + 1
	b["_plan_loot"] = counts
	b["_plan_last_item"] = name
	var directive: Dictionary = b.get("ai_directive", {})
	if not directive.is_empty():
		directive["evidence"] = result(m, b, directive)
		Diagnostics.event(b, directive, "loot_result", str(directive["evidence"]["reason"]),
			"SATISFIED" if bool(directive["evidence"]["complete"]) else "PENDING")

static func purpose(d: Dictionary) -> String:
	if str(d.get("goal", "")) == "gear_up_at_military_base":
		return "gear"
	if d.has("purpose"):
		return str(d["purpose"])
	# Un paso de saqueo militar sin proposito explicito no se satisface con el
	# primer objeto recogido: su finalidad es completar el equipo militar real.
	var target := str(d.get("target", ""))
	if str(d.get("action", "")) == "scavenge" and (target == "military" or target.begins_with("military:")):
		return "gear"
	var goal := str(d.get("goal", "")).to_lower()
	for pair in [["ammo", "ammo"], ["munition", "ammo"], ["clothing", "clothing"], ["tool", "tools"], ["weapon", "weapons"], ["water", "water"], ["meat", "meat"], ["food", "food"]]:
		if pair[0] in goal:
			return pair[1]
	return "general"

static func decent_weapon(m, proxy: Node3D) -> String:
	if not is_instance_valid(proxy):
		return ""
	# Same ammunition and durability rules as combat; inspect each candidate
	# so a higher-ranked stone weapon cannot hide a useful steel knife.
	for it in proxy.get_meta("saved_inventory", []):
		if not it is Dictionary or int(it.get("quantity", 1)) <= 0 or float(it.get("durability", 100.0)) <= 0:
			continue
		var name := str(it.get("name", ""))
		if name in ["Hacha", "Cuchillo"]:
			return name
		if name in ["Fusil de asalto", "Rifle francotirador"] and m._bot_gun_any_ammo(proxy, name):
			return name
		if name in ["Arco reforzado", "Arco de madera"] and m._bot_arrow_count(proxy) > 0:
			return name
	return ""

# Equipo militar real, no solo "algo con lo que defenderse". Un cuchillo o un
# arco bastan para sobrevivir al primer dia, pero no deben cerrar una mision
# llamada gear_up_at_military_base: el objetivo es salir con arma de fuego
# municionada y parte del uniforme/equipo militar.
const MILITARY_FIREARMS := ["Fusil de asalto", "Rifle francotirador"]
const MILITARY_GEAR_NAMES := [
	"Pantalones militares", "Pantalones militares azules", "Pantalones militares negros II",
	"Pantalones camuflaje", "Pantalones camuflaje desert",
	"Chaqueta militar", "Chaqueta militar azul", "Chaqueta militar negra II",
	"Chaqueta camuflaje", "Chaqueta camuflaje desert", "Chaqueta militar digital",
	"Guantes militares", "Botas militares", "Casco militar", "Gorra militar",
	"Chaleco táctico", "Mochila militar",
]

static func military_firearm(m, proxy: Node3D) -> String:
	if not is_instance_valid(proxy):
		return ""
	for it in proxy.get_meta("saved_inventory", []):
		if not it is Dictionary or int(it.get("quantity", 1)) <= 0 or float(it.get("durability", 100.0)) <= 0:
			continue
		var name := str(it.get("name", ""))
		if name in MILITARY_FIREARMS and m._bot_gun_any_ammo(proxy, name):
			return name
	return ""

static func military_gear_count(proxy: Node3D) -> int:
	if not is_instance_valid(proxy):
		return 0
	var seen := {}
	for it in proxy.get_meta("saved_inventory", []):
		if it is Dictionary and int(it.get("quantity", 1)) > 0:
			var nm := str(it.get("name", ""))
			if nm in MILITARY_GEAR_NAMES:
				seen[nm] = true
	var bp := str(proxy.get_meta("saved_backpack", ""))
	if bp in MILITARY_GEAR_NAMES:
		seen[bp] = true
	var extra: Dictionary = proxy.get_meta("saved_extra", {})
	var worn: Dictionary = extra.get("worn_clothing", {})
	for nm in worn.keys():
		if str(nm) in MILITARY_GEAR_NAMES:
			seen[str(nm)] = true
	for nm in str(proxy.get_meta("saved_clothing", "")).split(",", false):
		if nm in MILITARY_GEAR_NAMES:
			seen[nm] = true
	return seen.size()

static func military_loadout_complete(m, proxy: Node3D) -> bool:
	return not military_firearm(m, proxy).is_empty() and military_gear_count(proxy) >= 2

static func near(b: Dictionary, pos, radius: float) -> bool:
	var proxy = b.get("proxy")
	if not is_instance_valid(proxy) or not pos is Vector3 or not pos.is_finite():
		return false
	var cur: Vector3 = proxy.global_position
	return absf(cur.y - pos.y) < 2.4 and Vector2(cur.x - pos.x, cur.z - pos.z).length() < radius

static func bind_gear_target(m, b: Dictionary, d: Dictionary) -> bool:
	var best := INF
	var known: Dictionary = b.get("_mem", {}).get("known_locations", {})
	for id in known:
		var entry = known[id]
		if not entry is Dictionary or str(entry.get("kind", "")) != str(d.get("target", "military")):
			continue
		var a = entry.get("pos", [])
		if not a is Array or a.size() != 3:
			continue
		var pos := Vector3(float(a[0]), float(a[1]), float(a[2]))
		if not pos.is_finite() or m._is_goal_blacklisted(b, pos) or m._is_poi_unreachable(b, str(id)):
			continue
		var candidate := d.duplicate()
		candidate["_dest_pos"] = pos
		if m._ai_goal_recently_failed(b, candidate, ["timeout"]):
			continue
		# Una marca de arma recogida no vacía automáticamente la zona: cima,
		# torres y ciudad tienen varias fuentes separadas. El veto fuerte de dos
		# solo aplica a las tiendas clásicas con rifle+M4 en el mismo punto.
		var taken_n := (entry.get("firearm_ids_taken", []) as Array).size()
		var pos_sig := "%d:%d" % [int(pos.x), int(pos.z)]
		var capacity := 2
		if pos_sig in ["159:680", "171:675", "39:750", "-43:-48"]:
			capacity = 1
		elif pos.x < -200.0 and pos.z < -200.0:
			capacity = 99
		if taken_n >= capacity:
			continue
		var dist: float = b["proxy"].global_position.distance_to(pos)
		var score := dist + gear_route_water_penalty(m, b["proxy"].global_position, pos)
		if score < best:
			best = score
			d["_dest_pos"] = pos
			d["_dest_id"] = str(id)
	return best != INF

# Distancia sola no basta para elegir una base militar: cruzar el rio exterior
# fuera de un vado convierte una incursion corta en una emergencia hipotermica.
# Los vados de carretera ya quedan someros en get_river_depth_at, asi que solo
# penalizamos agua profunda realmente atravesada por la linea de aproximacion.
static func gear_route_water_penalty(m, from_pos: Vector3, to_pos: Vector3) -> float:
	if m == null or m.world == null or not m.world.has_method("get_river_depth_at"):
		return 0.0
	var length := Vector2(to_pos.x - from_pos.x, to_pos.z - from_pos.z).length()
	if length < 8.0:
		return 0.0
	var samples := mini(48, maxi(2, int(ceil(length / 6.0))))
	var deep_samples := 0
	var max_depth := 0.0
	for i in range(1, samples):
		var probe: Vector3 = from_pos.lerp(to_pos, float(i) / float(samples))
		var depth := float(m.world.get_river_depth_at(probe))
		max_depth = maxf(max_depth, depth)
		if depth >= 0.8:
			deep_samples += 1
	if deep_samples == 0:
		return 0.0
	return minf(180.0, float(deep_samples) * 24.0 + max_depth * 25.0)

static func ally_valid(m, b: Dictionary, id: int) -> bool:
	if id == int(b.get("bot_id", 0)) or not m.bots.has(id):
		return false
	var other: Dictionary = m.bots[id]
	var proxy = other.get("proxy")
	return is_instance_valid(proxy) and not bool(proxy.get_meta("proxy_dead", false)) \
		and m._bot_pair_can_cooperate(int(b.get("bot_id", 0)), id)

static func bind_ally(m, b: Dictionary, d: Dictionary) -> bool:
	var best := INF
	var id := int(d.get("_ally_id", 0))
	if id != 0:
		if not ally_valid(m, b, id):
			return false
	else:
		for candidate in m.bots:
			if ally_valid(m, b, int(candidate)):
				var p: Vector3 = m.bots[candidate]["proxy"].global_position
				var dist: float = b["proxy"].global_position.distance_to(p)
				if dist < best:
					best = dist
					id = int(candidate)
	if id == 0:
		return false
	d["_ally_id"] = id
	d["mode"] = "pos"
	d["pos"] = m.bots[id]["proxy"].global_position
	d["_dest_pos"] = d["pos"]
	d["_dest_id"] = "bot_%d" % id
	return true

static func viable(m, b: Dictionary, d: Dictionary, now: int) -> String:
	var proxy = b.get("proxy")
	if not is_instance_valid(proxy) or bool(proxy.get_meta("proxy_dead", false)):
		return "actor_dead"
	var destination = d.get("pos", d.get("_dest_pos", Vector3.INF))
	if str(d.get("action", "")) in ["explore", "scavenge", "hunt"] and destination is Vector3 and destination.is_finite():
		if m._is_goal_blacklisted(b, destination) or m._is_poi_unreachable(b, str(d.get("_dest_id", ""))):
			return "nav_blocked"
	if str(d.get("action", "")) == "seek_ally":
		if not d.has("_ally_id") and not bind_ally(m, b, d):
			return "ally_unavailable"
		var id := int(d.get("_ally_id", 0))
		if not ally_valid(m, b, id):
			return "ally_unavailable"
		if now >= int(d.get("_ally_refresh_ms", 0)):
			d["_ally_refresh_ms"] = now + 3000
			var pos: Vector3 = m.bots[id]["proxy"].global_position
			if pos.distance_to(d.get("pos", Vector3.INF)) > 4.0:
				d["pos"] = pos
				d["_dest_pos"] = pos
				d["_prog_ref_m"] = proxy.global_position.distance_to(pos)
				b["path_timer"] = 0.0
	if str(d.get("action", "")) in ["return_home", "rest", "fortify_camp"]:
		var home: Vector3 = b.get("shelter_pos", Vector3.INF)
		var camp: Vector3 = b.get("camp_spot", Vector3.INF)
		var dest: Vector3 = d.get("pos", Vector3.INF)
		if not dest.is_finite() and not home.is_finite() and not camp.is_finite():
			return "home_unavailable"
		if dest.is_finite() and dest.distance_to(home) > 22.0 and dest.distance_to(camp) > 22.0:
			# Legacy explicit positions remain valid if no home was bound.
			if bool(d.get("_home_bound", false)):
				return "home_unavailable"
	return ""

static func baseline(b: Dictionary) -> Dictionary:
	var st = b.get("vstats")
	var stats: Dictionary = b.get("_mem", {}).get("stats", {})
	return {
		"loot": int(b.get("_loot_n", 0)), "food": int(b.get("_loot_food_n", 0)),
		"hunger": float(b.get("hunger", 100.0)), "thirst": float(b.get("thirst", 100.0)),
		"kills": int(stats.get("kills_prey", 0)) + int(stats.get("kills_predator", 0)),
		"prey": int(stats.get("kills_prey", 0)), "categories": b.get("_plan_loot", {}).duplicate(),
		"sleep": float(st.sleep) if st != null else 100.0,
		"shelter": not str(b.get("shelter_id", "")).is_empty(),
		"fire": not str(b.get("campfire_id", "")).is_empty(),
	}

static func category(name: String, type: String) -> String:
	if type == "food":
		return "meat" if "Carne" in name or "Pez" in name else "food"
	if type in ["drink", "water"]: return "water"
	if type.begins_with("ammo"): return "ammo"
	if PlayerController.CLOTHING_SLOTS.has(name): return "clothing"
	if type.begins_with("weapon") or type == "tool_spear": return "weapons"
	if type.begins_with("tool"): return "tools"
	if type == "clothing": return "clothing"
	return "general"

static func gained(b: Dictionary, d: Dictionary, kind: String) -> bool:
	var current: Dictionary = b.get("_plan_loot", {})
	var start: Dictionary = d.get("_ev0", {}).get("categories", {})
	return int(current.get(kind, 0)) > int(start.get(kind, 0))

static func has_usable_category(proxy: Node3D, kind: String) -> bool:
	for item in proxy.get_meta("saved_inventory", []):
		if item is Dictionary and int(item.get("quantity", 1)) > 0 and float(item.get("durability", 100.0)) > 0.0 \
				and category(str(item.get("name", "")), str(item.get("type", ""))) == kind:
			return true
	return false

static func result(m, b: Dictionary, d: Dictionary) -> Dictionary:
	var action := str(d.get("action", ""))
	var need := purpose(d)
	var ev0: Dictionary = d.get("_ev0", {})
	var proxy = b.get("proxy")
	var done := false
	var reason := "destination_pending"
	if not is_instance_valid(proxy):
		return {"complete": false, "reason": "actor_unavailable"}
	if bool(d.get("_home_bound", false)):
		var invalid := viable(m, b, d, Time.get_ticks_msec())
		if not invalid.is_empty():
			return {"complete": false, "reason": invalid, "purpose": need}
	var dest = d.get("pos", d.get("_dest_pos", Vector3.INF))
	var weapon := decent_weapon(m, proxy) if need in ["gear", "weapons"] else ""
	if need == "gear":
		done = military_loadout_complete(m, proxy)
		reason = "military_loadout" if done else "military_equipment_pending"
	else:
		match action:
			"seek_ally":
				var id := int(d.get("_ally_id", 0))
				done = ally_valid(m, b, id) and near(b, m.bots[id]["proxy"].global_position, 9.0)
				reason = "ally_met" if done else "ally_not_met"
			"return_home":
				done = near(b, dest, 9.0)
				var sh: Vector3 = b.get("shelter_pos", Vector3.INF)
				done = done and (sh == Vector3.INF or (dest as Vector3).distance_to(sh) < 22.0)
				reason = "home_reached" if done else "home_pending"
			"rest":
				var st = b.get("vstats")
				done = st != null and st.sleep > 78.0 and st.energy >= 65.0 and float(b.get("health", 100.0)) > 85.0
				done = done and (not dest is Vector3 or not dest.is_finite() or near(b, dest, 10.0))
				reason = "recovered" if done else "recovery_pending"
			"forage":
				done = gained(b, d, "food") or gained(b, d, "meat")
				# Old directives used the food-only acquisition counter.
				if not ev0.has("categories"):
					done = done or int(b.get("_loot_food_n", 0)) > int(ev0.get("food", b.get("_loot_food_n", 0)))
				if ev0.is_empty() or float(ev0.get("hunger", 100.0)) < 72.0:
					done = done or float(b.get("hunger", 100.0)) >= 75.0
				if need == "water":
					done = gained(b, d, "water") or float(b.get("thirst", 100.0)) >= 75.0
				reason = "need_satisfied" if done else "useful_food_pending"
			"hunt":
				var stats: Dictionary = b.get("_mem", {}).get("stats", {})
				done = int(stats.get("kills_prey", 0)) > int(ev0.get("prey", stats.get("kills_prey", 0)))
				if need in ["food", "meat"]:
					done = done and gained(b, d, "meat")
				reason = "hunt_result" if done else "prey_or_meat_pending"
			"scavenge":
				if need in ["weapons"]:
					done = gained(b, d, "weapons") and not weapon.is_empty()
				elif need != "general":
					done = gained(b, d, need) or (need == "food" and gained(b, d, "meat"))
					if need in ["ammo", "clothing", "tools"]:
						done = done and has_usable_category(proxy, need)
				else:
					done = int(b.get("_loot_n", 0)) > int(ev0.get("loot", b.get("_loot_n", 0)))
				reason = "useful_loot" if done else "requested_loot_pending"
			"explore":
				done = near(b, dest, 10.0)
				if str(d.get("mode", "")) == "poi":
					done = done and bool(d.get("_visit_done", false))
				reason = "destination_visited" if done else "destination_pending"
			"fortify_camp":
				done = near(b, dest, 9.0) and (ev0.is_empty() or not str(b.get("shelter_id", "")).is_empty() or not str(b.get("campfire_id", "")).is_empty())
				reason = "camp_ready" if done else "camp_pending"
			"avoid_zone":
				done = not (d.get("avoid_kinds", []) as Array).has(m._poi_kind_near(proxy.global_position))
				reason = "zone_left" if done else "danger_zone"
	return {"complete": done, "reason": reason, "purpose": need, "weapon": weapon,
		"last_item": str(b.get("_plan_last_item", ""))}
