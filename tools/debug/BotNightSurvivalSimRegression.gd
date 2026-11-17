extends SceneTree

# BotNightSurvivalSimRegression — simulacion nocturna prolongada y acelerada.
#
# Conduce la capa REAL de supervivencia/decisiones de los bots
# (_bot_survival_tick + _maintain_bot_needs + el gate de sueno de _tick_bot
# replicado al detalle) sobre un mundo mock sin nav: el movimiento se
# simula como desplazamiento lineal a la velocidad ordenada, pero las
# reglas fisicas (SurvivalStats: hambre, sed, sueño, energia, temperatura,
# humedad, lluvia, calor de fogata) son las del juego — nada se regala.
#
# Diez escenarios de noche completa (21:30 -> 6:12) con informe por
# superviviente: temperatura, salud, hambre, sed, sueño, energia, humedad,
# refugio/fuente de calor, decisiones, objetivos fallidos, tiempo de
# supervivencia y causa de muerte si la hay.

const SurvivorBotManagerScript = preload("res://scripts/SurvivorBotManager.gd")
const WorldActionScript = preload("res://scripts/WorldAction.gd")

var failures := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

class FakeDayCycle extends Node:
	var time_of_day := 21.5
	var ambient_temp := 8.0
	var weather_darkness := 0.0
	func get_ambient_temperature() -> float:
		return ambient_temp
	func is_night() -> bool:
		return DayNightCycle.is_night_at(time_of_day)
	func is_dark() -> bool:
		return DayNightCycle.is_dark_at(time_of_day, weather_darkness)

class FakeNet extends Node:
	var is_host := true
	var is_connected := true
	var is_dedicated_server := true
	var peer = null
	var players := {}
	var animals := {}
	var authoritative_weather := {}
	var relay_log: Array = []
	func get_my_id() -> int:
		return 1
	func peer_alive(_pid: int) -> bool:
		return false
	func snapshot_recipients() -> Array[int]:
		return []
	func relay_actor_chat(sender_id: int, sender_name: String, text: String, target_peer_id: int, target_name: String = "") -> void:
		relay_log.append({"from_id": sender_id, "from": sender_name, "to_id": target_peer_id, "to": target_name, "text": text})
	func relay_actor_voice(_a: int, _b: String, _c: PackedByteArray, _d: int, _e: String = "") -> void:
		pass
	func relay_actor_voice_mp3(_a: int, _b: String, _c: PackedByteArray, _d: int, _e: String = "") -> void:
		pass

class SimWorld extends "res://scripts/Main.gd":
	var water_rect := Rect2(100000.0, 100000.0, 8.0, 8.0)
	var flat_water_depth := 1.0
	var house_pts: Array = []
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
		# Mismo perfil que Main.get_river_depth_at para tramos rectos: somero
		# en la orilla y hondo en el eje. Sin el, la orilla calculada por
		# _nearest_water_pos (0.35 m dentro del borde) saltaba a profunda y
		# la caminata a beber se abortaba como meta inalcanzable.
		for seg in river_segs:
			if not (seg is Dictionary):
				continue
			var c: Vector3 = seg.get("center", Vector3.ZERO)
			var sz: Vector2 = seg.get("size", Vector2.ZERO)
			var yaw := deg_to_rad(float(seg.get("yaw", 0.0)))
			var along := Vector3(cos(yaw), 0.0, -sin(yaw))
			var across := Vector3(sin(yaw), 0.0, cos(yaw))
			var off := pos - c
			var lf := off.dot(along)
			var ls := off.dot(across)
			var hl := sz.x * 0.5
			var hw2 := sz.y * 0.5
			if absf(lf) <= hl and absf(ls) <= hw2:
				var sd := 1.0 - absf(ls) / maxf(0.01, hw2)
				var ld := 1.0 - absf(lf) / maxf(0.01, hl)
				return clampf(minf(sd, ld) * 3.0, 0.18, 2.5)
		return flat_water_depth if water_rect.has_point(Vector2(pos.x, pos.z)) else 0.0
	func _is_near_river(pos: Vector3, margin: float = 0.5) -> bool:
		return water_rect.grow(margin).has_point(Vector2(pos.x, pos.z))
	func _is_player_in_house(pos: Vector3) -> bool:
		for hp in house_pts:
			if Vector2(pos.x - (hp as Vector3).x, pos.z - (hp as Vector3).z).length() <= 5.0:
				return true
		return false
	func _is_in_open_house(_pos: Vector3) -> bool:
		return false
	func _is_on_road(_pos: Vector3) -> bool:
		return false
	func _is_near_built_shelter(pos: Vector3, _margin: float = 4.0) -> bool:
		for sh in _built_shelters:
			var sp = sh.get("pos")
			if sp is Vector3 and Vector2(pos.x - sp.x, pos.z - sp.z).length() <= 4.0:
				return true
		return false
	func _default_river_segments() -> Array:
		return river_segs
	func _net_world_action_completed(aid: String, spawns: Array, _c: String, _d: Vector3, _e: int = 0) -> bool:
		if not aid.is_empty() and not _depleted_action_ids.has(aid):
			_depleted_action_ids.append(aid)
		var act = world_actions_by_id.get(aid)
		if act != null and is_instance_valid(act):
			act.mark_depleted()
			world_actions_by_id.erase(aid)
		# Los drops existen de verdad (la leña del arbusto talado, la carne
		# del cadáver): como en Main._track_dropped_item van a _dropped_items
		# para que el sentido de saqueo los recoja del suelo.
		for s in spawns:
			if not (s is Dictionary):
				continue
			var sid := str(s.get("id", ""))
			if sid.is_empty() or _dropped_items.any(func(d): return str(d.get("id", "")) == sid):
				continue
			_dropped_items.append((s as Dictionary).duplicate(true))
		return true
	func _net_campfire_built(cid: String, pos: Vector3, _owner: int = 0) -> bool:
		var cf := Node3D.new()
		cf.position = pos
		add_child(cf)
		world_actions_by_id[cid] = cf
		return true
	func _net_campfire_lit(cid: String, fire_name: String, pos: Vector3, _owner: int = 0) -> bool:
		if not world_actions_by_id.has(cid):
			return false
		var cfo = world_actions_by_id[cid]
		if cfo is Object:
			cfo.set_meta("lit", true)
		for lc in _lit_campfires:
			if str(lc.get("id", "")) == cid:
				lc["fire_name"] = fire_name
				lc["pos"] = pos
				return true
		_lit_campfires.append({"id": cid, "fire_name": fire_name, "pos": pos})
		if not campfire_positions.has(pos):
			campfire_positions.append(pos)
		return true
	# La lluvia de Main.gd (_extinguish_fire_by_name): el objeto SOBREVIVE
	# apagado (lit=false, accion "light_campfire") — no da calor ni luz y
	# no puede atraer al bot como refugio termico.
	func rain_out_campfire(cid: String) -> void:
		var cf = world_actions_by_id.get(cid)
		var pos: Vector3 = (cf as Node3D).global_position if cf is Node3D else Vector3.INF
		if cf is Object:
			cf.set_meta("lit", false)
			cf.remove_meta("fire_name")
		for i in range(_lit_campfires.size() - 1, -1, -1):
			if str(_lit_campfires[i].get("id", "")) == cid:
				_lit_campfires.remove_at(i)
		if pos != Vector3.INF:
			var bi := -1
			var bd := INF
			for i in range(campfire_positions.size()):
				var d := (campfire_positions[i] as Vector3).distance_to(pos)
				if d < bd:
					bd = d
					bi = i
			if bi >= 0 and bd < 2.0:
				campfire_positions.remove_at(bi)
	# La expiracion real de Main.gd: el objeto desaparece y se purga el
	# registro encendido + la posicion de calor del fuego muerto.
	func expire_campfire(cid: String) -> void:
		var cf = world_actions_by_id.get(cid)
		var pos: Vector3 = (cf as Node3D).global_position if cf != null else Vector3.INF
		if cf != null:
			world_actions_by_id.erase(cid)
			cf.queue_free()
		for i in range(_lit_campfires.size() - 1, -1, -1):
			if str(_lit_campfires[i].get("id", "")) == cid:
				_lit_campfires.remove_at(i)
		if pos != Vector3.INF:
			var bi := -1
			var bd := INF
			for i in range(campfire_positions.size()):
				var d: float = (campfire_positions[i] as Vector3).distance_to(pos)
				if d < bd:
					bd = d
					bi = i
			if bi >= 0 and bd < 2.0:
				campfire_positions.remove_at(bi)

class SimMgr extends SurvivorBotManagerScript:
	# Sin nav en el sim: el movimiento es desplazamiento lineal a la
	# velocidad ordenada (la decision — a donde y a que velocidad — es
	# real; solo la locomocion se simplifica a campo abierto).
	func _move_bot_towards(b: Dictionary, goal: Vector3, speed: float, delta: float, anim_name: String) -> void:
		var proxy: Node3D = b["proxy"]
		var cur := proxy.global_position
		var d := Vector2(goal.x - cur.x, goal.z - cur.z).length()
		var step := speed * delta
		var np := cur
		if d <= step:
			np = Vector3(goal.x, cur.y, goal.z)
		elif d > 0.01:
			var dir := Vector2(goal.x - cur.x, goal.z - cur.z) / d
			np = cur + Vector3(dir.x * step, 0.0, dir.y * step)
		proxy.global_position = np
		b["pos"] = np
		b["anim"] = anim_name
		b["sitting"] = false
	func _is_step_blocked(_a: Vector3, _b: Vector3, _deep: bool = false) -> bool:
		return false

# Manager sin overrides de locomocion: usa _move_bot_towards real — A* de
# NavPathfinding, pasos bloqueados por blockers/rios y la inercia de un
# jugador. Para los escenarios que exigen rodear obstaculos de verdad.
class NavSimMgr extends SurvivorBotManagerScript:
	pass

func _initialize() -> void:
	call_deferred("run")

var _prev_env: Dictionary = {}

# Mundo + manager + bots frescos por escenario. use_nav=true instancia el
# manager con locomocion real (A* + blockers) en vez del desplazamiento
# lineal del sim.
func _new_world(temp := 8.0, weather := {}, use_nav := false) -> Dictionary:
	# El escenario anterior muere aqui: proxies, acciones y mundo se
	# liberan con el arbol, no quedan ObjectDB colgados al salir.
	for key in ["world", "net"]:
		var old = _prev_env.get(key)
		if old != null and is_instance_valid(old):
			old.free()
	var world := SimWorld.new()
	root.add_child(world)
	var fnet := FakeNet.new()
	fnet.name = "NetworkManager"
	root.add_child(fnet)
	world.net = fnet
	fnet.authoritative_weather = weather
	var dc := FakeDayCycle.new()
	world.add_child(dc)
	world.day_cycle = dc
	dc.ambient_temp = temp
	var mgr: SurvivorBotManagerScript = NavSimMgr.new() if use_nav else SimMgr.new()
	mgr.name = "SurvivorBotManager"
	world.add_child(mgr)
	world.survivor_bot_mgr = mgr
	mgr.setup(world)
	# Memoria limpia: las lecciones acumuladas del archivo real sesgarian
	# la comparativa entre escenarios.
	mgr._memory.clear()
	for bid in mgr.bots:
		var fresh := {}
		mgr._memory[bid] = fresh
		mgr.bots[bid]["_mem"] = fresh
	_prev_env = {"world": world, "net": fnet}
	return {"world": world, "mgr": mgr, "dc": dc, "net": fnet}

# Estado base limpio y posicion de partida para un bot.
func _place_bot(b: Dictionary, pos: Vector3, stats := {}) -> void:
	var proxy: Node3D = b["proxy"]
	proxy.global_position = pos
	b["pos"] = pos
	b["hunger"] = float(stats.get("hunger", 85.0))
	b["thirst"] = float(stats.get("thirst", 85.0))
	b["health"] = float(stats.get("health", 100.0))
	b["energy"] = float(stats.get("energy", 90.0))
	b["aggro_target"] = null
	b["hide_timer"] = 0.0
	b["flee_until"] = 0.0
	b["sleeping"] = false
	b["drink_at"] = Vector3.INF
	b["campfire_id"] = ""
	b["campfire_pos"] = Vector3.INF
	b["shelter_id"] = str(stats.get("shelter_id", ""))
	b["shelter_pos"] = stats.get("shelter_pos", Vector3.INF)
	b["team_leader_id"] = int(stats.get("team_leader_id", 0))
	b["follow_mode"] = str(stats.get("follow_mode", "stay"))
	b.erase("_night_emergency_origin")
	b.erase("_night_wander")
	b.erase("_forage")
	b.erase("_bad_water")
	b.erase("_fire_veto")
	b.erase("_fire_band")
	var st: SurvivalStats = b["vstats"]
	st.health = float(b["health"])
	st.hunger = float(b["hunger"])
	st.thirst = float(b["thirst"])
	st.energy = float(b["energy"])
	st.sleep = float(stats.get("sleep", 70.0))
	st.body_temperature = float(stats.get("body_temperature", 36.6))
	st.wetness = float(stats.get("wetness", 0.0))
	proxy.set_meta("saved_inventory", stats.get("inventory", []))

# Inventario real del bot como {nombre: cantidad} — para comparar contra el
# inventario inicial y detectar recursos inventados.
func _inv_totals(b: Dictionary) -> Dictionary:
	var out := {}
	for it in (b["proxy"] as Node3D).get_meta("saved_inventory", []):
		if it is Dictionary:
			var nm := str(it.get("name", ""))
			out[nm] = float(out.get(nm, 0.0)) + float(it.get("quantity", 1))
	return out

func _spawn_food_action(world: SimWorld, aid: String, pos: Vector3, use_value := 14.0) -> void:
	var seta := WorldActionScript.new()
	seta.setup(aid, "eat_food", "Seta amanita", Vector3(0.2, 0.2, 0.2), Color(0.8, 0.15, 0.1), false, false)
	seta.set_meta("item_name", "Seta amanita")
	seta.set_meta("item_type", "food")
	seta.set_meta("item_use_value", use_value)
	seta.set_meta("item_quantity", 1)
	world.add_child(seta)
	seta.global_position = pos
	world.world_actions_by_id[aid] = seta

# Nodo de material real (arbusto a talar / piedra suelta): el rescate por
# frio y la recogida normal los buscan por action_type en _cached_mat_ids.
func _spawn_mat_action(world: SimWorld, aid: String, atype: String, pos: Vector3) -> void:
	var node := WorldActionScript.new()
	node.setup(aid, atype, atype, Vector3(1.0, 1.0, 1.0), Color(0.4, 0.3, 0.2), false, false)
	world.add_child(node)
	node.global_position = pos
	world.world_actions_by_id[aid] = node

# Bucle de noche: replica el orden real de _tick_bot — gate de sueño,
# tick fisico, cascada de necesidades — con delta acelerado.
const DT := 1.0

func simulate(env: Dictionary, bots: Array, events: Array = [], max_steps := 34000) -> Array:
	var world: SimWorld = env["world"]
	var mgr: SurvivorBotManagerScript = env["mgr"]
	var dc: FakeDayCycle = env["dc"]
	var reports: Array = []
	for b in bots:
		reports.append({"bot_id": int(b["bot_id"]), "name": str(b.get("name", "?")), "acts": {},
			"act_first": {}, "slept": false, "cause": "", "survived_s": 0.0,
			"failed_goals": 0, "peak_wet": 0.0, "dawn_clean": true})
	var step := 0
	while step < max_steps:
		# La noche del sim acaba cuando vuelve la luz util (mismo criterio
		# de oscuridad que usan los bots), no al toque de reloj.
		var is_night: bool = dc.is_dark()
		if not is_night and step > 0:
			break
		for i in range(bots.size()):
			var b: Dictionary = bots[i]
			var r: Dictionary = reports[i]
			var st: SurvivalStats = b["vstats"]
			var proxy: Node3D = b["proxy"]
			if st == null or st.dead or bool(proxy.get_meta("proxy_dead", false)):
				continue
			# El tick real completo: sentidos, combat/amenazas, gate de sueño,
			# fisica SurvivalStats, necesidades y la cascada campamento/
			# forrajeo/vagabundeo — solo la locomocion (nav) es simulada.
			var bad_water_before: int = (b.get("_bad_water", []) as Array).size()
			mgr._tick_bot(b, DT)
			if st.dead or bool(proxy.get_meta("proxy_dead", false)):
				r["cause"] = str(mgr._memory.get(int(b["bot_id"]), {}).get("last_death_cause", "unknown"))
				r["survived_s"] = float(r["survived_s"]) + DT
				continue
			r["failed_goals"] = int(r["failed_goals"]) + maxi(0, (b.get("_bad_water", []) as Array).size() - bad_water_before)
			var act := str(b.get("_act", "idle"))
			r["acts"][act] = int(r["acts"].get(act, 0)) + 1
			# Orden de aparicion de cada acto: la prioridad entre sistemas se
			# verifica sobre la secuencia real, no sobre conteos finales.
			if not (r["act_first"] as Dictionary).has(act):
				(r["act_first"] as Dictionary)[act] = step
			# Ventana de amenaza: todo acto con un enemigo encima va aparte —
			# regular la fogata mientras te atacan es un bug de prioridades.
			if b.get("aggro_target") != null or b.get("_s_predator") is Node3D or b.get("_s_foe") is Node3D:
				r["threat_ticks"] = int(r.get("threat_ticks", 0)) + 1
				var ta: Dictionary = r.get("threat_acts", {})
				ta[act] = int(ta.get(act, 0)) + 1
				r["threat_acts"] = ta
			if bool(b.get("sleeping", false)):
				r["slept"] = true
			if b.has("_sleep_veto"):
				var vt: Dictionary = r.get("sleep_vetoes", {})
				vt[str(b["_sleep_veto"])] = int(vt.get(str(b["_sleep_veto"]), 0)) + 1
				r["sleep_vetoes"] = vt
			r["peak_wet"] = maxf(float(r["peak_wet"]), st.wetness)
			r["survived_s"] = float(r["survived_s"]) + DT
		for ev in events:
			if int(ev.get("at", -1)) == step:
				ev["fn"].call()
			elif int(ev.get("every", -1)) > 0 and step % int(ev["every"]) == 0:
				ev["fn"].call()
		dc.time_of_day = fmod(dc.time_of_day + DT / 3600.0, 24.0)
		step += 1
	return reports

func _report_line(r: Dictionary, b: Dictionary) -> String:
	var st: SurvivalStats = b["vstats"]
	var proxy: Node3D = b["proxy"]
	return "    %s | vivo=%s causa=%s | hp=%.0f hambre=%.0f sed=%.0f sueño=%.0f en=%.0f temp=%.2f moj=%.2f | acts=%s | slept=%s vetoes=%s | fallos=%d | %.1f h" % [
		r["name"], "SI" if not st.dead else "NO", r["cause"] if str(r["cause"]) != "" else "-",
		st.health, st.hunger, st.thirst, st.sleep, st.energy, st.body_temperature, st.wetness,
		str(r["acts"]), str(r.get("slept", false)), str(r.get("sleep_vetoes", {})), int(r["failed_goals"]), float(r["survived_s"]) / 3600.0]

# S16 aislado: la replica del bug de Kael (latas + hacha, hambre letal).
# Se invoca desde run() o directo con --only-s16 para iterar rapido.
func _s16() -> void:
	# ---- S16: lata cerrada + hacha — la cena en la mochila ----
	# El bug real de Kael: con hambre letal, dos latas y un hacha el bot
	# forrajeaba en bucle y moria sin abrir nunca la comida que llevaba.
	print("S16: lata cerrada con abrelatas")
	var env := _new_world(21.0)
	var w = env["world"]
	var mgr = env["mgr"]
	# Madrugada: la mecanica a probar (abrir y comer la lata) ocurre en
	# minutos — una noche entera solo mediria el drenaje generico.
	(env["dc"] as FakeDayCycle).time_of_day = 5.3
	var b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"hunger": 20.0, "thirst": 85.0, "sleep": 70.0,
		"inventory": [
			{"name": "Lata de guiso", "type": "food", "weight": 0.5, "quantity": 6, "use_value": 0.0},
			{"name": "Lata de atun", "type": "food", "weight": 0.3, "quantity": 1, "use_value": 0.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 8, "use_value": 45.0},
			{"name": "Hacha", "type": "tool_axe", "weight": 1.5, "quantity": 1, "use_value": 0.0}]})
	var reps := simulate(env, [b])
	print(_report_line(reps[0], b))
	var st16: SurvivalStats = b["vstats"]
	var inv16 := _inv_totals(b)
	check(not st16.dead, "S16 sobrevive abriendo su propia lata")
	check(st16.hunger > 25.0, "S16 comio de la lata abierta (hambre %.0f)" % st16.hunger)
	check(float(inv16.get("Lata de guiso", 0.0)) < 1.0 or float(inv16.get("Lata de atun", 0.0)) < 1.0,
		"S16 abrio al menos una lata (inv=%s)" % str(inv16))

func run() -> void:
	seed(911)
	var t0 := Time.get_ticks_msec()
	if "--only-s16" in OS.get_cmdline_args():
		_s16()
		print("BotNightSurvivalSimRegression errors=%d (%.1f s)" % [failures, (Time.get_ticks_msec() - t0) / 1000.0])
		quit(1 if failures else 0)
		return

	# ---- S1: refugio + comida + agua + fogata — la noche resuelta ----
	# La noche del juego es hora real (~8.5 h): la despensa del refugio es la
	# de un superviviente asentado, no un cheat — el drenaje real exige
	# ~700 de hambre y ~1200 de sed por noche (SurvivalStats.tick).
	print("S1: refugio, provisiones y fogata")
	var env := _new_world(8.0)
	var w: SimWorld = env["world"]
	var mgr: SurvivorBotManagerScript = env["mgr"]
	var home := Vector3(0.0, 0.4, 0.0)
	w._built_shelters = [{"id": "s1_sh", "pos": home, "contents": [
		{"name": "Seta amanita", "type": "food", "weight": 0.1, "quantity": 60, "use_value": 14.0},
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 40, "use_value": 45.0}]}]
	w._net_campfire_built("s1_cf", home + Vector3(1.5, 0.0, 0.0))
	w._net_campfire_lit("s1_cf", "fire_s1", home + Vector3(1.5, 0.0, 0.0))
	var b: Dictionary = mgr.bots[901]
	_place_bot(b, home, {"shelter_id": "s1_sh", "shelter_pos": home, "sleep": 40.0,
		"inventory": [
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 2, "use_value": 45.0},
			{"name": "Seta amanita", "type": "food", "weight": 0.1, "quantity": 3, "use_value": 14.0}]})
	var reps := simulate(env, [b])
	print(_report_line(reps[0], b))
	check(not (b["vstats"] as SurvivalStats).dead, "S1 el bot con campamento resuelto sobrevive la noche")
	check(bool(reps[0]["slept"]), "S1 durmio en su refugio")

	# ---- S2: sin refugio ni antorcha, pero con material — enciende fuego ----
	print("S2: sin refugio ni antorcha (con material de fuego)")
	env = _new_world(8.0)
	w = env["world"]
	mgr = env["mgr"]
	w.river_segs = [{"center": Vector3(50.0, 0.0, 30.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(45.0, 25.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"sleep": 55.0, "inventory": [
		{"name": "Palo", "type": "resource", "weight": 0.3, "quantity": 4, "use_value": 0.0},
		{"name": "Piedra", "type": "resource", "weight": 0.4, "quantity": 3, "use_value": 0.0},
		{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0},
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 10, "use_value": 45.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	check(not (b["vstats"] as SurvivalStats).dead, "S2 sin refugio ni antorcha sobrevive")
	check(not str(b.get("_act", "")) == "need_light" or (b["vstats"] as SurvivalStats).sleep > 55.0,
		"S2 no quedo petrificado en need_light toda la noche")

	# ---- S3: hipotermia — marcha de emergencia al refugio ----
	print("S3: hipotermia")
	env = _new_world(4.0)
	w = env["world"]
	mgr = env["mgr"]
	var house := Vector3(90.0, 0.4, 0.0)
	w.house_pts = [house]
	w.wildlife_blockers = [{"house_bounds": Rect2(85.0, -5.0, 10.0, 10.0)}]
	w.river_segs = [{"center": Vector3(45.0, 0.0, 30.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(40.0, 25.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"body_temperature": 34.9, "sleep": 50.0,
		"inventory": [{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0}]})
	var d0 := Vector2(90.0, 0.0).length()
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st3: SurvivalStats = b["vstats"]
	var proxy3: Node3D = b["proxy"]
	var d_end := Vector2(proxy3.global_position.x - house.x, proxy3.global_position.z - house.z).length()
	check(not st3.dead, "S3 el helado sobrevive")
	check(d_end < d0 - 30.0 or st3.body_temperature > 35.2,
		"S3 marco hacia el refugio o se recupero (d %.0f->%.0f, temp %.1f)" % [d0, d_end, st3.body_temperature])
	check(int((reps[0]["acts"] as Dictionary).get("rest", 0)) > 0,
		"S3 eligio refugio/descanso, no patrulla en el sitio (acts=%s)" % str(reps[0]["acts"]))

	# ---- S4: mojado bajo lluvia — se moja y prioriza secarse ----
	print("S4: mojado bajo lluvia")
	env = _new_world(9.0, {"weather_code": 7, "temperature": 9.0, "rain": 0.9, "snow": 0.0,
		"cloud_cover": 1.0, "wind_speed": 4.0, "wind_direction": 0.0})
	w = env["world"]
	mgr = env["mgr"]
	w.house_pts = [Vector3(60.0, 0.4, 0.0)]
	w.wildlife_blockers = [{"house_bounds": Rect2(55.0, -5.0, 10.0, 10.0)}]
	w.river_segs = [{"center": Vector3(30.0, 0.0, -40.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(25.0, -45.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"wetness": 0.35, "sleep": 60.0,
		"inventory": [{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st4: SurvivalStats = b["vstats"]
	check(not st4.dead, "S4 el mojado sobrevive la lluvia")
	check(float(reps[0]["peak_wet"]) >= 0.35, "S4 la lluvia moja de verdad (pico %.2f)" % float(reps[0]["peak_wet"]))
	check(st4.wetness <= float(reps[0]["peak_wet"]) + 0.01, "S4 no se seca por arte de magia")

	# ---- S5: reclutado que necesita dormir ----
	print("S5: reclutado agotado")
	env = _new_world(8.0)
	w = env["world"]
	mgr = env["mgr"]
	w.house_pts = [Vector3(25.0, 0.4, 0.0)]
	w.wildlife_blockers = [{"house_bounds": Rect2(20.0, -5.0, 10.0, 10.0)}]
	w.river_segs = [{"center": Vector3(15.0, 0.0, -35.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(10.0, -40.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"sleep": 9.0, "team_leader_id": 1, "follow_mode": "follow",
		"inventory": [
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 15, "use_value": 45.0},
			{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	check(bool(reps[0]["slept"]), "S5 el reclutado durmio pese a seguir al jugador")
	check(int(b["team_leader_id"]) == 1, "S5 conserva su equipo tras dormir")
	check(not (b["vstats"] as SurvivalStats).dead, "S5 sobrevive")

	# ---- S6: hambre y sed criticas — expedicion dirigida ----
	print("S6: hambre/sed criticas")
	env = _new_world(13.0)
	w = env["world"]
	mgr = env["mgr"]
	w.river_segs = [{"center": Vector3(100.0, 0.0, 0.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(95.0, -5.0, 10.0, 10.0)
	for i in range(24):
		_spawn_food_action(w, "s6_seta%d" % i, Vector3(60.0 + i % 4, 0.4, float(i - 7)), 30.0)
	for i in range(24):
		_spawn_food_action(w, "s6_setab%d" % i, Vector3(-40.0 + i % 4, 0.4, float(i - 7)), 30.0)
	for i in range(24):
		_spawn_food_action(w, "s6_setac%d" % i, Vector3(10.0, 0.4, 40.0 + i % 6), 30.0)
	# Leña y piedra de verdad en la zona: al volver empapado del rio el
	# rescate por frio corta el arbusto, recoge los palos del suelo, junta
	# las piedras y enciende la fogata donde esta — sin caminar a ciegas.
	for i in range(4):
		_spawn_mat_action(w, "s6_bush%d" % i, "fell_bush", Vector3(14.0 + i * 3.0, 0.4, -12.0 - i * 2.0))
	for i in range(3):
		_spawn_mat_action(w, "s6_stone%d" % i, "stone", Vector3(10.0 + i * 2.0, 0.4, -8.0 + i * 3.0))
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"hunger": 12.0, "thirst": 9.0, "sleep": 60.0,
		"inventory": [{"name": "Cuchillo", "type": "weapon", "weight": 0.4, "quantity": 1, "use_value": 0.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st6: SurvivalStats = b["vstats"]
	check(not st6.dead, "S6 sobrevive alcanzando las fuentes dirigidas")
	# Se mide que BEBIO (actos reales en el rio y sed por encima de la
	# letal de partida), no un nivel final arbitrario: sin comer de mas ya
	# no recibe agua "gratis" de la comida y amanece con la sed que toca.
	check(int(reps[0]["acts"].get("drink", 0)) > 0 and st6.thirst > 15.0,
		"S6 bebio en el rio a 100 m (sed 9 -> %.0f, %d ticks bebiendo)" % [st6.thirst, int(reps[0]["acts"].get("drink", 0))])
	check(st6.hunger > 12.0, "S6 forrajeo la seta a 120 m (hambre %.0f)" % st6.hunger)

	# ---- S7: la fogata se apaga a media noche ----
	print("S7: fogata que expira")
	env = _new_world(3.0)
	w = env["world"]
	mgr = env["mgr"]
	var fire := Vector3(12.0, 0.4, 0.0)
	w._net_campfire_built("s7_cf", fire)
	w._net_campfire_lit("s7_cf", "fire_s7", fire)
	w.house_pts = [Vector3(60.0, 0.4, 0.0)]
	w.wildlife_blockers = [{"house_bounds": Rect2(55.0, -5.0, 10.0, 10.0)}]
	w.river_segs = [{"center": Vector3(20.0, 0.0, -30.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(15.0, -35.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"sleep": 70.0, "body_temperature": 35.6,
		"inventory": [{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0}]})
	b["campfire_id"] = "s7_cf"
	b["campfire_pos"] = fire
	reps = simulate(env, [b], [{"at": 400, "fn": func(): w.expire_campfire("s7_cf")}])
	print(_report_line(reps[0], b))
	var st7: SurvivalStats = b["vstats"]
	check(not st7.dead, "S7 sobrevive a la fogata apagada")
	check(w._lit_campfires.is_empty(), "S7 el fuego expiro de verdad")
	check(not str(b["campfire_id"]) == "s7_cf" or Vector2(b["proxy"].global_position.x - fire.x, b["proxy"].global_position.z - fire.z).length() > 8.0,
		"S7 detecta el fuego muerto: referencia limpia o busca otra fuente")

	# C4: lluvia — la estructura de la fogata sobrevive APAGADA (lit=false).
	# No puede dar calor, ni luz, ni valer de refugio termico.
	env = _new_world(3.0)
	w = env["world"]
	mgr = env["mgr"]
	var fire_ro := Vector3(10.0, 0.4, 0.0)
	w._net_campfire_built("ro_cf", fire_ro)
	w._net_campfire_lit("ro_cf", "fire_ro", fire_ro)
	b = mgr.bots[901]
	_place_bot(b, fire_ro + Vector3(2.0, 0.0, 0.0), {"body_temperature": 35.0, "sleep": 60.0,
		"inventory": [{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 8, "use_value": 30.0}]})
	w.rain_out_campfire("ro_cf")
	check(w.campfire_positions.is_empty(), "C4 fuego apagado por lluvia no calienta (positions=%d)" % w.campfire_positions.size())
	check(mgr._nearest_lit_campfire_pos(fire_ro + Vector3(2.0, 0, 0), 8.0) == Vector3.INF,
		"C4 el objeto apagado no cuenta como fogata encendida")
	check(mgr._nearest_safe_refuge(b, 30.0) == Vector3.INF,
		"C4 el fuego apagado no atrae como refugio termico")
	var st_ro: SurvivalStats = b["vstats"]
	var t_before := st_ro.body_temperature
	for i in range(120):
		mgr._bot_survival_tick(b, 1.0)
	check(st_ro.body_temperature <= t_before + 0.05,
		"C4 junto a las brasas frias no se recupera temp (%.2f->%.2f)" % [t_before, st_ro.body_temperature])
	# Una entrada encendida que sobreviva (cache obsoleto) sobre un objeto
	# apagado tampoco vale: _campfire_entry_alive exige objeto valido y
	# realmente encendido.
	w._lit_campfires.append({"id": "ro_cf", "fire_name": "fire_ro", "pos": fire_ro})
	check(not mgr._campfire_entry_alive(w._lit_campfires[-1]), "C4 entrada encendida obsoleta se invalida")
	check(mgr._nearest_lit_campfire_pos(fire_ro + Vector3(2.0, 0, 0), 8.0) == Vector3.INF,
		"C4 la entrada obsoleta no engana al buscador de lumbre")
	w._lit_campfires.clear()

	# ---- S8: lobos/enemigo mientras duerme ----
	print("S8: amenaza durante el sueño")
	env = _new_world(8.0)
	w = env["world"]
	mgr = env["mgr"]
	w.house_pts = [Vector3(0.0, 0.4, 0.0)]
	w.wildlife_blockers = [{"house_bounds": Rect2(-5.0, -5.0, 10.0, 10.0)}]
	w._net_campfire_built("s8_cf", Vector3(4.0, 0.4, 0.0))
	w._net_campfire_lit("s8_cf", "fire_s8", Vector3(4.0, 0.4, 0.0))
	w.river_segs = [{"center": Vector3(40.0, 0.0, -30.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(35.0, -35.0, 10.0, 10.0)
	var wolf := Node3D.new()
	w.add_child(wolf)
	wolf.global_position = Vector3(6.0, 0.4, 0.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"sleep": 45.0,
		"inventory": [
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 15, "use_value": 45.0},
			{"name": "Seta amanita", "type": "food", "weight": 0.1, "quantity": 160, "use_value": 14.0}]})
	var woke_mid := [false]
	reps = simulate(env, [b], [{"at": 300, "fn": func():
		b["aggro_target"] = wolf
		b["aggro_timer"] = 60.0},
		{"at": 330, "fn": func():
		# Despertar medido dentro de la ventana: el estado final no vale, el
		# bot puede volver a dormir (y debe) cuando la amenaza pasa.
		woke_mid[0] = not bool(b.get("sleeping", false))},
		{"at": 360, "fn": func():
		# La amenaza rompe el contacto: el bot reacciono y sobrevivio.
		b["aggro_target"] = null
		b["aggro_timer"] = 0.0}])
	print(_report_line(reps[0], b))
	check(bool(reps[0]["slept"]), "S8 llego a dormir antes del ataque")
	check(woke_mid[0], "S8 el aggro lo desperto")
	check(not (b["vstats"] as SurvivalStats).dead, "S8 sobrevive a la amenaza")
	# Prioridad combate>termostato: con el lobo encima nunca ejecuta
	# warm_up/cool_off — la regulacion termica cede a la amenaza.
	var tacts: Dictionary = reps[0].get("threat_acts", {})
	check(int(reps[0].get("threat_ticks", 0)) > 0, "S8 la ventana de amenaza se registro")
	check(int(tacts.get("warm_up", 0)) + int(tacts.get("cool_off", 0)) == 0,
		"S8 no regula la distancia al fuego bajo amenaza (threat_acts=%s)" % str(tacts))
	wolf.queue_free()

	# ---- S9: sin materiales para fuego, frio — refugio alternativo ----
	print("S9: sin materiales, frio")
	env = _new_world(4.0)
	w = env["world"]
	mgr = env["mgr"]
	w.house_pts = [Vector3(120.0, 0.4, 0.0)]
	w.wildlife_blockers = [{"house_bounds": Rect2(115.0, -5.0, 10.0, 10.0)}]
	w.river_segs = [{"center": Vector3(60.0, 0.0, -30.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(55.0, -35.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"body_temperature": 35.5, "sleep": 55.0,
		"inventory": [{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 100, "use_value": 30.0}]})
	var inv9_0 := _inv_totals(b)
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st9: SurvivalStats = b["vstats"]
	var proxy9: Node3D = b["proxy"]
	check(not st9.dead, "S9 sobrevive sin poder encender fuego")
	# No inventa recursos: sin materiales no construye nada, y el inventario
	# final es un subconjunto del inicial (comio, no conjuro).
	# No inventa recursos: sin materiales no construye nada — el loot de su
	# propia muerte (death_loot_*) es una mecanica valida y no cuenta.
	var s9_ids := []
	for aid9 in w.world_actions_by_id.keys():
		if str(aid9).begins_with("death_loot_"):
			continue
		var a9 = w.world_actions_by_id[aid9]
		var label := "?"
		if a9 is Object:
			label = str(a9.get_meta("item_name", a9.get("action_type")))
		s9_ids.append("%s:%s" % [str(aid9), label])
	check(str(b["campfire_id"]).is_empty() and s9_ids.is_empty() and w._lit_campfires.is_empty(),
		"S9 no inventa fogatas (cf=%s acciones=%s lit=%d)" % [b["campfire_id"], str(s9_ids), w._lit_campfires.size()])
	var inv9_1 := _inv_totals(b)
	var invented := false
	for nm in inv9_1:
		if float(inv9_1[nm]) > float(inv9_0.get(nm, 0.0)):
			invented = true
	check(not invented, "S9 el inventario no crece sin fuentes (%s -> %s)" % [str(inv9_0), str(inv9_1)])
	check(Vector2(proxy9.global_position.x - 120.0, proxy9.global_position.z).length() < 15.0,
		"S9 alcanzo el refugio alternativo (d=%.0f a la casa)" % Vector2(proxy9.global_position.x - 120.0, proxy9.global_position.z).length())

	# ---- S10: sobrevive al amanecer y retoma su actividad ----
	print("S10: hasta el amanecer")
	env = _new_world(9.0)
	w = env["world"]
	mgr = env["mgr"]
	var home10 := Vector3(0.0, 0.4, 0.0)
	w._built_shelters = [{"id": "s10_sh", "pos": home10, "contents": [
		{"name": "Seta amanita", "type": "food", "weight": 0.1, "quantity": 60, "use_value": 14.0},
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 40, "use_value": 45.0}]}]
	var fire10 := Vector3(4.0, 0.4, 0.0)
	w._net_campfire_built("s10_cf", fire10)
	w._net_campfire_lit("s10_cf", "fire_s10", fire10)
	b = mgr.bots[901]
	_place_bot(b, home10, {"shelter_id": "s10_sh", "shelter_pos": home10, "sleep": 50.0,
		"inventory": [
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 4, "use_value": 45.0},
			{"name": "Seta amanita", "type": "food", "weight": 0.1, "quantity": 4, "use_value": 14.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st10: SurvivalStats = b["vstats"]
	check(not st10.dead, "S10 llega al amanecer")
	check(not (env["dc"] as FakeDayCycle).is_night(), "S10 la simulacion cruzo el amanecer")
	# El sim corta en el borde del alba: la gate `not is_night and sleep>55`
	# necesita unos ticks mas para disparar el despertar real.
	var dc10: FakeDayCycle = env["dc"]
	for i in range(120):
		mgr._tick_bot(b, DT)
		dc10.time_of_day = fmod(dc10.time_of_day + DT / 3600.0, 24.0)
	check(not bool(b["sleeping"]) and st10.sleep > 55.0,
		"S10 despierta al clarear con el deposito recuperado (sueño %.0f, sleeping=%s)" % [st10.sleep, str(b["sleeping"])])

	# ---- S11: despensa escasa — el forrajeo es la unica forma de vivir ----
	# Dos raciones no bastan para una noche real: si la cadena de forrajeo
	# letal no recoge las setas del mundo, la inanicion es matematica. El
	# refugio cercano le da donde dormir entre recolectas (el frio no es
	# lo que se examina aqui).
	print("S11: inventario escaso, forrajeo obligado")
	env = _new_world(12.0)
	w = env["world"]
	mgr = env["mgr"]
	w.house_pts = [Vector3(8.0, 0.4, 0.0)]
	w.wildlife_blockers = [{"house_bounds": Rect2(3.0, -5.0, 10.0, 10.0)}]
	w.river_segs = [{"center": Vector3(45.0, 0.0, -35.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(40.0, -40.0, 10.0, 10.0)
	var setas11 := 0
	for i in range(40):
		_spawn_food_action(w, "s11_seta%d" % i, Vector3(20.0 + i % 5, 0.4, 15.0 + i / 5), 30.0)
		setas11 += 1
	for i in range(30):
		_spawn_food_action(w, "s11_setab%d" % i, Vector3(-15.0 - i % 5, 0.4, -20.0 + i / 5), 30.0)
		setas11 += 1
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"hunger": 55.0, "thirst": 60.0, "sleep": 65.0,
		"inventory": [{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 2, "use_value": 30.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st11: SurvivalStats = b["vstats"]
	check(not st11.dead, "S11 sobrevive a despensa escasa forrajeando")
	check(w.world_actions_by_id.size() < setas11,
		"S11 recogio comida real del mundo (%d->%d acciones)" % [setas11, w.world_actions_by_id.size()])
	# Sin luz propia la puerta de oscuridad solo permite expediciones de
	# forrajeo en ventana letal (hambre<14): la cadena le mantiene oscilando
	# en la banda 14-40 toda la noche — sobrevive fuera de la inanicion,
	# pero no amanece con la panza llena (el >30 era de antes de la puerta).
	check(st11.hunger > 14.0, "S11 el forrajeo letal le saco de la inanicion (%.0f)" % st11.hunger)

	# ---- S12: navegacion real — muro entre el bot y su refugio ----
	# NavSimMgr no tiene overrides: usa _move_bot_towards real con el A* de
	# NavPathfinding sobre una rejilla donde el muro bloquea el paso. Un
	# sim de locomocion lineal atravesaria el muro; aqui hay que rodearlo.
	print("S12: nav real, muro hacia el refugio")
	env = _new_world(9.0, {}, true)
	w = env["world"]
	mgr = env["mgr"]
	# Muro vertical en x=30 desde z=-40 hasta z=+10 (hueco al norte): la
	# ruta directa a la casa del este esta cortada.
	for zi in range(-40, 11, 2):
		w._register_wildlife_blocker(Vector3(30.0, 0.0, float(zi)), 1.4)
	w.bot_nav = NavPathfinding.new()
	w.bot_nav.build(w.wildlife_blockers, [])
	var home12 := Vector3(70.0, 0.4, 0.0)
	w._built_shelters = [{"id": "s12_sh", "pos": home12, "contents": [
		{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 40, "use_value": 30.0},
		{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 25, "use_value": 45.0}]}]
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"shelter_id": "s12_sh", "shelter_pos": home12,
		"hunger": 50.0, "thirst": 50.0, "sleep": 60.0,
		"inventory": [
			{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 8, "use_value": 30.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 4, "use_value": 45.0}]})
	var wall_viol := [0]
	var max_z := [0.0]
	reps = simulate(env, [b], [{"every": 1, "fn": func():
		var p: Vector3 = (b["proxy"] as Node3D).global_position
		if p.x > 28.5 and p.x < 31.5 and p.z > -38.0 and p.z < 10.0:
			wall_viol[0] += 1
		if p.z > max_z[0]:
			max_z[0] = p.z}])
	print(_report_line(reps[0], b))
	var st12: SurvivalStats = b["vstats"]
	var proxy12: Node3D = b["proxy"]
	var d12 := Vector2(proxy12.global_position.x - home12.x, proxy12.global_position.z - home12.z).length()
	check(not st12.dead, "S12 sobrevive la noche con nav real")
	check(wall_viol[0] == 0, "S12 jamas atraviesa el muro (viol=%d)" % wall_viol[0])
	check(max_z[0] > 11.5, "S12 rodeo el muro por el hueco norte (z_max=%.1f)" % max_z[0])
	check(d12 < 10.0, "S12 llego a su refugio al otro lado (d=%.0f)" % d12)

	# ---- S13: hipotermico DENTRO del rio — la orilla manda sobre la lumbre ----
	# Antes el termostato corria primero: un helado en agua profunda podia
	# intentar "acercarse a la fogata" desde el rio. Ahora el escape al
	# somero es la primera decision del tick, siempre.
	print("S13: agua profunda con fogata cerca")
	env = _new_world(8.0)
	w = env["world"]
	mgr = env["mgr"]
	w.water_rect = Rect2(-5.0, -5.0, 10.0, 10.0) # depth 3.0 > FORD_MAX 2.55
	w.flat_water_depth = 3.0
	# Estanque bebible al sur de la lumbre: en el mapa real toda masa de agua
	# tiene su segmento — sin el, el bot moria de sed con la orilla del lago
	# al lado porque _nearest_water_pos no tenia fuente que localizar.
	w.river_segs = [{"center": Vector3(20.0, 0.0, -25.0), "size": Vector2(8.0, 8.0), "yaw": 0.0}]
	w._net_campfire_built("s13_cf", Vector3(20.0, 0.4, 0.0))
	w._net_campfire_lit("s13_cf", "fire_s13", Vector3(20.0, 0.4, 0.0))
	w.house_pts = [Vector3(30.0, 0.4, 0.0)]
	w.wildlife_blockers = [{"house_bounds": Rect2(25.0, -5.0, 10.0, 10.0)}]
	b = mgr.bots[901]
	_place_bot(b, Vector3(0.0, 0.4, 0.0), {"body_temperature": 35.0, "wetness": 0.9,
		"sleep": 60.0, "inventory": [
			{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 10, "use_value": 45.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st13: SurvivalStats = b["vstats"]
	var af13: Dictionary = reps[0]["act_first"]
	var i_esc13 := int(af13.get("water_escape", -1))
	check(i_esc13 >= 0, "S13 el escape de agua profunda ocurrio")
	check(af13.get("warm_up", 1 << 30) is int and i_esc13 >= 0 and int(af13.get("warm_up", 1 << 30)) > i_esc13 \
		and int(af13.get("cool_off", 1 << 30)) > i_esc13,
		"S13 salio del agua ANTES de regular la lumbre (esc=%d warm=%s cool=%s)" % [
			i_esc13, str(af13.get("warm_up", "-")), str(af13.get("cool_off", "-"))])
	check(float(w.get_river_depth_at((b["proxy"] as Node3D).global_position)) <= 0.55,
		"S13 termino fuera del agua profunda")
	check(not st13.dead, "S13 sobrevive: escapa, se seca y se calienta")

	# ---- S14: fogata amurallada — veto y fuente de calor alternativa ----
	# NavSimMgr trae _is_step_blocked real (blockers de verdad). Un cerco de
	# obstaculos cubre TODO el anillo termico: el destino imposible se veta
	# y el bot busca la otra lumbre en vez de empujar el muro toda la noche.
	print("S14: fogata inaccesible, calor alternativo")
	env = _new_world(9.0, {}, true)
	w = env["world"]
	mgr = env["mgr"]
	var fp14 := Vector3(30.0, 0.4, 0.0)
	for i in range(16):
		var a := TAU * float(i) / 16.0
		w._register_wildlife_blocker(fp14 + Vector3(cos(a) * 3.9, 0.0, sin(a) * 3.9), 1.2)
	w._net_campfire_built("s14_cf", fp14)
	w._net_campfire_lit("s14_cf", "fire_s14", fp14)
	var alt14 := Vector3(95.0, 0.4, 0.0)
	w._net_campfire_built("s14_alt", alt14)
	w._net_campfire_lit("s14_alt", "fire_s14alt", alt14)
	# Rio real junto a la alternativa: la sed de una noche entera exige una
	# fuente, no solo la mochila.
	w.river_segs = [{"center": Vector3(112.0, 0.0, 0.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(107.0, -5.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(10.0, 0.4, 0.0), {"body_temperature": 34.2, "sleep": 55.0,
		"inventory": [
			{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 10, "use_value": 45.0}]})
	var veto14 := [false]
	reps = simulate(env, [b], [{"every": 1, "fn": func():
		if not (b.get("_fire_veto", {}) as Dictionary).is_empty():
			veto14[0] = true}])
	print(_report_line(reps[0], b))
	var st14: SurvivalStats = b["vstats"]
	var proxy14: Node3D = b["proxy"]
	var d_walled := Vector2(proxy14.global_position.x - fp14.x, proxy14.global_position.z - fp14.z).length()
	var d_alt := Vector2(proxy14.global_position.x - alt14.x, proxy14.global_position.z - alt14.z).length()
	check(veto14[0], "S14 la fogata amurallada quedo vetada al no tener anillo libre")
	check(d_alt < 10.0 and d_walled > 12.0,
		"S14 busco la fuente alternativa, no se quedo contra el muro (alt=%.0f wall=%.0f)" % [d_alt, d_walled])
	check(not st14.dead, "S14 sobrevive calentandose en la alternativa")

	# ---- S15: fogata parcialmente tapada — el veto NO se dispara ----
	# Muro solo al este del anillo: los puntos libres del oeste son
	# alcanzables, asi que no hay veto — el termostato funciona normal.
	print("S15: fogata con muro parcial")
	env = _new_world(9.0, {}, true)
	w = env["world"]
	mgr = env["mgr"]
	var fp15 := Vector3(30.0, 0.4, 0.0)
	for i in range(5):
		var a := -PI * 0.25 + PI * 0.125 * float(i) # ~45° de arco al este
		w._register_wildlife_blocker(fp15 + Vector3(cos(a) * 3.9, 0.0, sin(a) * 3.9), 1.2)
	w._net_campfire_built("s15_cf", fp15)
	w._net_campfire_lit("s15_cf", "fire_s15", fp15)
	w.house_pts = [Vector3(20.0, 0.4, 0.0)]
	# La casa se registra, no se asigna: machacar wildlife_blockers aqui
	# dejaria los indices de _blocker_grid apuntando a entradas muertas.
	var h15 := w._register_wildlife_blocker(Vector3(20.0, 0.0, 0.0), 5.0)
	w.wildlife_blockers[h15]["house_bounds"] = Rect2(15.0, -5.0, 10.0, 10.0)
	# Rio al norte para la sed de la noche (fuera del muro parcial y de la
	# casa): beber a la orilla sigue siendo una salida normal.
	w.river_segs = [{"center": Vector3(30.0, 0.0, -18.0), "size": Vector2(10.0, 10.0), "yaw": 0.0}]
	w.water_rect = Rect2(25.0, -23.0, 10.0, 10.0)
	b = mgr.bots[901]
	_place_bot(b, Vector3(12.0, 0.4, 0.0), {"body_temperature": 35.0, "sleep": 55.0,
		"inventory": [
			{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 90, "use_value": 30.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 10, "use_value": 45.0}]})
	reps = simulate(env, [b])
	print(_report_line(reps[0], b))
	var st15: SurvivalStats = b["vstats"]
	check((b.get("_fire_veto", {}) as Dictionary).is_empty(),
		"S15 el muro parcial no veto la fogata (anillo libre por el oeste)")
	check(int(reps[0]["acts"].get("warm_up", 0)) + int(reps[0]["acts"].get("cool_off", 0)) > 0,
		"S15 el termostato regulo distancia de verdad (acts=%s)" % str(reps[0]["acts"]))
	check(not st15.dead, "S15 sobrevive regulando por el lado libre")

	_s16()

	print("BotNightSurvivalSimRegression errors=%d (%.1f s)" % [failures, (Time.get_ticks_msec() - t0) / 1000.0])
	quit(1 if failures else 0)
