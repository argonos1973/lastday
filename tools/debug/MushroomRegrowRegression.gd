extends SceneTree

# Regresion del rebrote de setas: al comer una seta queda programada para
# rebrotar MUSHROOM_REGROW_SECONDS despues; el tick periodico la recrea en la
# misma posicion y limpia el estado de agotada (servidor y clientes via
# _net_world_action_respawned).

const WorldActionScript = preload("res://scripts/WorldAction.gd")

class TestWorld extends "res://scripts/Main.gd":
	var pickup_calls: Array = []
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass
	# Sustituye la creacion real (GLB, suelo, seeds) por una WorldAction minima.
	func _create_mushroom_pickup(id: String, pos: Vector3) -> void:
		if _depleted_action_ids.has(id):
			return
		pickup_calls.append({"id": id, "pos": pos})
		var a = WorldActionScript.new()
		a.setup(id, "eat_food", "Seta amanita", Vector3(0.2, 0.2, 0.2), Color(0.8, 0.15, 0.1), false, false)
		add_child(a)
		a.global_position = pos
		world_actions_by_id[id] = a

var failures := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world

	# Una seta comida queda agotada y programada para rebrotar en 24 h reales.
	var pos := Vector3(12.5, 0.04, -30.0)
	var mush := WorldActionScript.new()
	mush.setup("mushroom_0", "eat_food", "Seta amanita", Vector3(0.2, 0.2, 0.2), Color(0.8, 0.15, 0.1), false, false)
	world.add_child(mush)
	mush.global_position = pos
	world.world_actions_by_id["mushroom_0"] = mush
	var before := Time.get_unix_time_from_system()
	mush.mark_depleted()
	check(world._depleted_action_ids.has("mushroom_0"), "La seta agotada entra en _depleted_action_ids")
	var entry: Dictionary = (world._mushroom_regrow as Dictionary).get("mushroom_0", {})
	check(not entry.is_empty(), "La seta agotada queda programada en _mushroom_regrow")
	check((entry.get("pos", Vector3.INF) as Vector3).distance_to(pos) < 0.01,
		"El rebrote recuerda la posicion exacta (pos=%s)" % str(entry.get("pos")))
	check(float(entry.get("until", 0.0)) >= before + 86000.0
			and float(entry.get("until", 0.0)) <= before + 90000.0,
		"El rebrote queda a ~24 h reales (until=%.0f)" % float(entry.get("until", 0.0)))

	# Una piedra agotada NO entra en el ciclo de rebrote.
	var stone := WorldActionScript.new()
	stone.setup("stone_77", "stone", "Piedras", Vector3(0.6, 0.4, 0.6), Color(0.3, 0.3, 0.3), false, false)
	world.add_child(stone)
	stone.global_position = Vector3(1, 0, 1)
	world.world_actions_by_id["stone_77"] = stone
	stone.mark_depleted()
	check(not world._mushroom_regrow.has("stone_77"), "Las acciones que no son setas no rebrotan")

	# Antes de las 24 h el tick no hace nada.
	world._check_mushroom_regrow()
	check(world.pickup_calls.is_empty() and world._depleted_action_ids.has("mushroom_0"),
		"El tick no rebrota antes de tiempo")

	# Cumplidas las 24 h: misma posicion, accion nueva y estado limpio.
	entry["until"] = Time.get_unix_time_from_system() - 1.0
	world._check_mushroom_regrow()
	check(world.pickup_calls.size() == 1 and str((world.pickup_calls[0] as Dictionary).get("id", "")) == "mushroom_0"
			and ((world.pickup_calls[0] as Dictionary).get("pos", Vector3.INF) as Vector3).distance_to(pos) < 0.01,
		"Tras 24 h la seta rebrota en su sitio (calls=%d)" % world.pickup_calls.size())
	check(not world._depleted_action_ids.has("mushroom_0") and not world._mushroom_regrow.has("mushroom_0"),
		"El rebrote limpia el estado de agotada")
	var grown = world.world_actions_by_id.get("mushroom_0")
	check(grown != null and is_instance_valid(grown) and not bool(grown.get("depleted")),
		"La seta rebrotada vuelve a ser interactuable")

	# Cliente: recibe el rebrote por _net_world_action_respawned y lo aplica.
	var client := TestWorld.new()
	root.add_child(client)
	client._depleted_action_ids.append("mushroom_9")
	client._mushroom_regrow["mushroom_9"] = {"pos": Vector3(3, 0, 3), "until": Time.get_unix_time_from_system() + 50000.0}
	client._net_world_action_respawned("mushroom_9", Vector3(3, 0, 3))
	check(client.pickup_calls.size() == 1 and not client._depleted_action_ids.has("mushroom_9"),
		"El cliente recrea la seta al recibir el rebrote")
	client._net_world_action_respawned("stone_5", Vector3(9, 0, 9))
	check(client.pickup_calls.size() == 1, "El cliente ignora rebrotes que no son setas")

	client.queue_free()
	world.queue_free()
	print("MushroomRegrowRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
