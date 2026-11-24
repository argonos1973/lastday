extends SceneTree

class FakeNet extends Node:
	var sent: Array = []
	var players := {}
	func relay_actor_chat(_id: int, _name: String, message: String, to_id: int, _to_name: String = "") -> void:
		sent.append({"to": to_id, "text": message})

class Arena extends Node3D:
	var server_proxies := {}
	var net: FakeNet

class Manager extends SurvivorBotManager:
	func _tts_enqueue_job(_id: int, _name: String, _to: int, _to_name: String, _text: String) -> void: pass

var checks := 0
var errors := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(label)

func _initialize() -> void: call_deferred("run")
func run() -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var net := FakeNet.new()
	arena.add_child(net)
	arena.net = net
	var m := Manager.new()
	arena.add_child(m)
	m.world = arena
	var proxy := Node3D.new()
	var teacher := Node3D.new()
	arena.add_child(proxy)
	arena.add_child(teacher)
	arena.server_proxies[8] = teacher
	var b := {"bot_id": 902, "proxy": proxy, "name": "Carlos", "faction": "friendly", "thirst": 20.0}
	m.bots[902] = b
	m._ensure_bot_memory(902)
	# Llenar el historial antes de contestar reproduce el límite real del
	# monitor: enviar otro mensaje ya no aumenta el tamaño de chat_log.
	for i in m.BOT_CHAT_LOG_MAX:
		m.chat_log.append({"kind": "greet", "text": "viejo %d" % i})
	teacher.position = Vector3(5, 0, 5)
	m.on_chat_received(902, 8, "Profe", "aqui hay agua, bebe de esta fuente")
	check(net.sent.size() == 1, "first teaching gets an acknowledgement")
	check(m.chat_log.size() == m.BOT_CHAT_LOG_MAX and m.chat_log.back().kind == "teach", "reply survives a full bounded chat history")
	check(b.drink_at == teacher.position, "the taught water source is used")
	# Una segunda fuente válida usa la misma frase de confirmación. El
	# antispam no debe silenciar una respuesta solicitada por el jugador.
	teacher.position = Vector3(65, 0, 65)
	b.drink_walk_t = 11.9
	b._drink_best_d = 0.5
	m.on_chat_received(902, 8, "Profe", "aqui hay agua, bebe de esta fuente")
	check(net.sent.size() == 2, "a second teaching gets a reply even when its wording repeats")
	check(b.drink_at == teacher.position, "the second teaching changes the water destination")
	check(b._mem.known_locations.size() == 2, "both separate water sources are retained")
	check(b.drink_walk_t == 0.0 and b._drink_best_d == INF, "a new destination does not inherit the previous route timeout")
	var ally := {"proxy":proxy, "_mem":{"known_locations":{
		"taught:dry":{"kind":"water", "pos":[65,0,65]},
		"taught:spring":{"kind":"water", "pos":[76,0,65]}}}}
	m.bots[901] = ally
	m._forget_false_water_report(b, teacher.position)
	check(not ally._mem.known_locations.has("taught:dry") and ally._mem.known_locations.has("taught:spring"),
		"retracting the shared dry tip does not erase another spring")
	check(m._known_water_pos(ally) == Vector3(76,0,65), "allies can use a shared water hint regardless of its memory key")
	# Las conversaciones espontáneas conservan su filtro antirrepetición.
	m._bot_chat_send(b, 8, "Profe", "Buenos días.", "greet")
	var sent_before := net.sent.size()
	m._bot_chat_send(b, 8, "Profe", "Buenos días.", "greet")
	check(net.sent.size() == sent_before, "duplicate unsolicited greeting is still suppressed")
	m.bots.clear()
	arena.free()
	print("BotTeachReplyRegression checks=", checks, " errors=", errors)
	quit(1 if errors else 0)
