extends SceneTree
# Regresion: el servidor dedicado debe crear las mismas acciones cosechables
# (pick_fruit, fell_bush) que el cliente — con los mismos ids, porque los ids
# son el contrato de sincronizacion (depleted_action_ids viaja por red).
# Antes de este cambio el servidor no generaba frutales ni arbustos: los bots
# no podian comer fruta ni conseguir semillas/palos para los huertos.

class FakeNet extends RefCounted:
	var is_dedicated_server := false
	var is_connected := false
	var is_host := false

class HarvestWorld extends "res://scripts/Main.gd":
	func _ready(): set_process(false)
	func _exit_tree(): pass
	func _save_world_change_silent(): pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0
	func _get_ground_height(_pos: Vector3) -> float: return 0.0
	# Terreno plano y sin rios/carreteras: el test solo quiere las acciones.
	func _is_inside_river_band(_pos: Vector3, _margin: float = 0.0) -> bool: return false
	func _is_on_road(_pos: Vector3) -> bool: return false

var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1

func _collect_ids(world: HarvestWorld) -> Dictionary:
	var ids := {"pick_fruit": {}, "fell_bush": {}}
	for aid in world.world_actions_by_id.keys():
		var a = world.world_actions_by_id[aid]
		var t := str(a.get("action_type"))
		if ids.has(t):
			ids[t][str(aid)] = a
	return ids

func run() -> void:
	var ded := HarvestWorld.new()
	ded.net = FakeNet.new()
	ded.net.is_dedicated_server = true
	root.add_child(ded)
	ded._military_tent_pos = Vector3(200.0, 0.0, 200.0)
	ded.HOUSE_FOOTPRINTS.append({"origin": ded._military_tent_pos, "w": 9.0, "d": 12.0})
	ded._create_fruit_trees()
	ded._create_harvestable_bushes()

	var client := HarvestWorld.new()
	client.net = FakeNet.new()
	root.add_child(client)
	client._military_tent_pos = Vector3(200.0, 0.0, 200.0)
	client.HOUSE_FOOTPRINTS.append({"origin": client._military_tent_pos, "w": 9.0, "d": 12.0})
	client._create_fruit_trees()
	client._create_harvestable_bushes()

	var d := _collect_ids(ded)
	var c := _collect_ids(client)
	print("ded pick_fruit=%d fell_bush=%d | client pick_fruit=%d fell_bush=%d" % [d["pick_fruit"].size(), d["fell_bush"].size(), c["pick_fruit"].size(), c["fell_bush"].size()])

	check(d["pick_fruit"].size() > 0, "dedicated server creates pick_fruit actions")
	check(d["fell_bush"].size() > 0, "dedicated server creates fell_bush actions")
	check(c["pick_fruit"].size() > 0, "client creates pick_fruit actions")
	check(c["fell_bush"].size() > 0, "client creates fell_bush actions")
	check(d["pick_fruit"].size() == c["pick_fruit"].size(), "pick_fruit count matches client/server")
	check(d["fell_bush"].size() == c["fell_bush"].size(), "fell_bush count matches client/server")

	var missing_on_ded := 0
	for aid in c["pick_fruit"].keys():
		if not d["pick_fruit"].has(aid):
			missing_on_ded += 1
	check(missing_on_ded == 0, "every client pick_fruit id exists on the server")
	missing_on_ded = 0
	for aid in c["fell_bush"].keys():
		if not d["fell_bush"].has(aid):
			missing_on_ded += 1
	check(missing_on_ded == 0, "every client fell_bush id exists on the server")

	# Metas que consumen los bots en _find_forage_target/_bot_forage_complete.
	var some_fruit = d["pick_fruit"].values()[0]
	check(str(some_fruit.get("action_type")) == "pick_fruit", "server fruit action has pick_fruit type")
	check(some_fruit.has_meta("fruit_ready_time"), "server fruit action carries fruit_ready_time")
	check(some_fruit.has_meta("fruit_type_name"), "server fruit action carries fruit_type_name")
	check(str(some_fruit.get_meta("fruit_type_name")) in ["Naranja", "Higo"], "fruit type is Naranja or Higo")
	var some_bush = d["fell_bush"].values()[0]
	check(str(some_bush.get("action_type")) == "fell_bush", "server bush action has fell_bush type")

	# Las posiciones tambien deben coincidir (los bots caminan hasta ellas).
	var pos_mismatch := 0
	for aid in d["pick_fruit"].keys():
		if c["pick_fruit"].has(aid):
			var pa: Vector3 = d["pick_fruit"][aid].global_position
			var pb: Vector3 = c["pick_fruit"][aid].global_position
			if pa.distance_to(pb) > 0.01:
				pos_mismatch += 1
	check(pos_mismatch == 0, "pick_fruit positions identical client/server")

	ded.queue_free()
	client.queue_free()
	await process_frame
	print("FAILURES=%d" % failures)
	quit(1 if failures > 0 else 0)
