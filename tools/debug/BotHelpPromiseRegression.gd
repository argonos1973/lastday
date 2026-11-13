extends SceneTree

# Regresion de la promesa de auxilio ("ya voy" -> llegar de verdad):
#  - Un grito de ayuda entre bots fija _meet_id + _meet_promise en el receptor.
#  - Un LIDER de equipo mantiene la promesa y viaja al aliado (antes se borraba).
#  - Si el _meet_id muere sin llegar (desvio, plan, caducidad), el que pedia
#    socorro lo apunta como "refused" — suma para abandonar/echar del grupo.
#  - Llegar (<=26 m), victima muerta o grito fuera de alcance NO cuenta.
#  - Cada "refused" registrado erosiona la sociabilidad del que se nego.
#  - refused >= 3 del lider -> el miembro abandona el grupo ("dejado tirado").
#  - Proponer alianza no crea promesa de rescate (no cuenta).

const SurvivorBotManagerScript = preload("res://scripts/SurvivorBotManager.gd")

var failures := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

class FakeDayCycle extends Node:
	var time_of_day := 14.0
	var ambient_temp := 15.0
	var weather_darkness := 0.0
	func get_ambient_temperature() -> float:
		return ambient_temp
	func is_night() -> bool:
		return time_of_day < 6.2 or time_of_day > 19.3

class FakeNet extends Node:
	var is_host := true
	var is_connected := false
	var is_dedicated_server := false
	var peer = null
	var players := {}
	var animals := {}
	var authoritative_weather := {}
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return true
	func snapshot_recipients() -> Array[int]:
		return []
	func relay_actor_chat(_sender_id: int, _sender_name: String, _text: String, _target_peer_id: int, _target_name: String = "") -> void:
		pass

class TestWorld extends "res://scripts/Main.gd":
	var water_rect := Rect2(100000.0, 100000.0, 4.0, 4.0)
	var water_depth := 1.0
	var road_rect := Rect2(200000.0, 200000.0, 4.0, 4.0)
	var river_segs: Array = []
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass
	func _save_world_change_silent() -> void:
		pass
	func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float:
		return 0.4
	func get_river_depth_at(pos: Vector3) -> float:
		return water_depth if water_rect.has_point(Vector2(pos.x, pos.z)) else 0.0
	func _is_on_road(pos: Vector3) -> bool:
		return road_rect.has_point(Vector2(pos.x, pos.z))
	func _is_player_in_house(_pos: Vector3) -> bool:
		return false
	func _default_river_segments() -> Array:
		return river_segs
	func _can_place_ground_vegetation(_pos: Vector3, _river_margin := 0.8, _short_grass := false) -> bool:
		return true

func _initialize() -> void:
	call_deferred("run")

func _make_world() -> Array:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world
	var fnet := FakeNet.new()
	fnet.name = "NetworkManager"
	root.add_child(fnet)
	world.net = fnet
	var dc := FakeDayCycle.new()
	world.add_child(dc)
	world.day_cycle = dc
	return [world, fnet]

func run() -> void:
	var mem_path := "user://test_bot_help_promise_mem.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(mem_path))
	var w := _make_world()
	var world: TestWorld = w[0]

	var mgr := SurvivorBotManagerScript.new()
	mgr.name = "SurvivorBotManager"
	world.add_child(mgr)
	world.survivor_bot_mgr = mgr
	mgr.memory_path = mem_path
	mgr.setup(world)
	check(mgr.bots.size() == 3, "Se crean los 3 bots")

	var carlos: Dictionary = mgr.bots[902]
	var kael: Dictionary = mgr.bots[903]
	var cproxy: Node3D = carlos["proxy"]
	var kproxy: Node3D = kael["proxy"]
	# Carlos lidera, Kael le sigue (el caso real reportado)
	kael["team_leader_id"] = 902
	kproxy.set_meta("team_leader_id", 902)
	# Confianza suficiente para que el grito enganche (puerta: >0.10).
	# OJO: hay que crear la relacion con _chat_touch_rel — get_bot_relationship
	# devuelve un dict nuevo no persistido cuando la relacion aun no existe.
	var rel_ck := mgr._chat_touch_rel(902, "bot_903", "Kael")
	rel_ck["trust"] = 0.9
	rel_ck["hostility"] = 0.0
	var rel_kc := mgr._chat_touch_rel(903, "bot_902", "Carlos")
	rel_kc["trust"] = 0.9
	rel_kc["hostility"] = 0.0
	# Kael a 100 m: cerca para oir el grito, lejos de "ya estoy aqui"
	cproxy.global_position = Vector3(0, 0.4, 0)
	kproxy.global_position = Vector3(100, 0.4, 0)

	# --- 1) El grito de socorro crea la promesa ---
	mgr.on_chat_received(902, 903, "Kael", "socorro, un lobo me mata")
	check(int(carlos.get("_meet_id", 0)) == 903, "El grito fija _meet_id hacia el aliado")
	check(int((carlos.get("_meet_promise", {}) as Dictionary).get("id", 0)) == 903
		and str((carlos.get("_meet_promise", {}) as Dictionary).get("kind", "")) == "help",
		"La promesa de auxilio queda registrada")

	# --- 2) El LIDER mantiene la promesa y viaja (antes se borraba al instante) ---
	carlos["_soc_t"] = 0.0
	mgr._bot_social_update(carlos)
	check(int(carlos.get("_meet_id", 0)) == 903, "El lider mantiene el meet de rescate")
	var et: Vector3 = carlos.get("explore_target", Vector3.INF)
	check(et != Vector3.INF and et.distance_to(kproxy.global_position) < 5.0,
		"El lider fija explore_target en la posicion del aliado")

	# --- 3) Promesa rota = negativa registrada en la victima ---
	var refused_before := int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0))
	var soc_before := float((carlos.get("_mem", {}) as Dictionary).get("personality", {}).get("sociability", 0.7))
	carlos["_meet_id"] = 0  # su plan cambia: la promesa muere sin llegar
	mgr._meet_promise_check(carlos)
	var rel_kc2 := mgr.get_bot_relationship(903, "bot_902")
	check(int(rel_kc2.get("refused", 0)) == refused_before + 1, "La promesa rota suma 'refused' en la victima")
	check(float(rel_kc2.get("trust", 1.0)) < 0.9, "La confianza de la victima hacia el lider cae")
	var soc_after := float((carlos.get("_mem", {}) as Dictionary).get("personality", {}).get("sociability", 0.7))
	check(soc_after < soc_before, "Negar ayuda reduce la sociabilidad del que se nego")
	check((carlos.get("_meet_promise", {}) as Dictionary).is_empty(), "La promesa consumida se limpia")

	# --- 4) Llegar a tiempo NO cuenta ---
	mgr.on_chat_received(902, 903, "Kael", "ayuda, sigo aqui")
	check(int((carlos.get("_meet_promise", {}) as Dictionary).get("id", 0)) == 903, "Nueva promesa tras el grito")
	cproxy.global_position = kproxy.global_position + Vector3(12.0, 0.0, 0.0) # llego a <26 m
	carlos["_meet_id"] = 0
	var refused2 := int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0))
	mgr._meet_promise_check(carlos)
	check(int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0)) == refused2,
		"Llegar a <26 m resuelve la promesa sin negativa")
	cproxy.global_position = Vector3(0, 0.4, 0)

	# --- 5) Victima muerta o grito inalcanzable: no es desplante ---
	kproxy.set_meta("proxy_dead", true)
	carlos["_meet_promise"] = {"id": 903, "kind": "help", "t": Time.get_ticks_msec()}
	carlos["_meet_id"] = 0
	mgr._meet_promise_check(carlos)
	check(int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0)) == refused2,
		"Si la victima murio en el camino no cuenta")
	kproxy.set_meta("proxy_dead", false)
	kproxy.global_position = Vector3(700, 0.4, 0) # grito oido a >450 m
	carlos["_meet_promise"] = {"id": 903, "kind": "help", "t": Time.get_ticks_msec()}
	carlos["_meet_id"] = 0
	mgr._meet_promise_check(carlos)
	check(int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0)) == refused2,
		"Un grito inalcanzable (>450 m) no cuenta")
	kproxy.global_position = Vector3(100, 0.4, 0)

	# --- 6) Promesa caducada (2 min sin llegar) cuenta aunque _meet_id siga ---
	carlos["_meet_promise"] = {"id": 903, "kind": "help", "t": Time.get_ticks_msec() - 130000}
	carlos["_meet_id"] = 903
	mgr._meet_promise_check(carlos)
	check(int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0)) == refused2 + 1,
		"La promesa que caduca sin llegar cuenta como negativa")

	# --- 7) refused >= 3 del lider: el miembro abandona el grupo ---
	rel_kc["refused"] = 3
	rel_kc["trust"] = 0.9
	kael["_soc_t"] = 0.0
	mgr._bot_social_update(kael)
	check(int(kael.get("team_leader_id", 0)) == 0, "El miembro abandona al lider que le dejo tirado (refused>=3)")

	# --- 8) refused explicito por chat tambien erosiona sociabilidad ---
	mgr._get_bot_personality(carlos)["sociability"] = 0.70
	var soc3 := float(mgr._get_bot_personality(carlos).get("sociability", 0.7))
	mgr.record_social_event(903, "bot_902", "Carlos", "refused", 0.25, "denied_give")
	check(float(mgr._get_bot_personality(carlos).get("sociability", 0.7)) < soc3,
		"El 'no' explicito por chat tambien baja la sociabilidad")

	# --- 9) Una propuesta de alianza no crea promesa de rescate ---
	carlos["_meet_id"] = 0
	carlos["_meet_promise"] = {}
	var refused3 := int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0))
	mgr.on_chat_received(902, 903, "Kael", "hagamos una alianza, vamos juntos")
	check(int(carlos.get("_meet_id", 0)) == 903, "La alianza fija el meet igual")
	check((carlos.get("_meet_promise", {}) as Dictionary).is_empty(),
		"La alianza NO crea promesa de rescate")
	carlos["_meet_id"] = 0
	mgr._meet_promise_check(carlos)
	check(int(mgr.get_bot_relationship(903, "bot_902").get("refused", 0)) == refused3,
		"El meet de alianza perdido no cuenta como negativa")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(mem_path))
	print("BotHelpPromiseRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
