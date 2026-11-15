extends SceneTree

# BotDaySurvivalSimRegression — jornada diurna y tacticas de combate.
#
# Conduce el _tick_bot REAL de Elena, Carlos y Kael sobre el mundo mock del
# sim nocturno (SurvivalStats reales, locomocion lineal). Lo unico que este
# sim aporta de mas es una linea de vision con paredes (segmentos 2D) para
# poder probar percepcion: quien no tiene LOS ni pista sonora no existe.
#
# Doce escenarios. Cada uno imprime un informe por bot: salud, hambre, sed,
# sueño, energia, municion y recursos consumidos, enemigos realmente
# detectados y la FUENTE de cada pista (vista / sonido / comunicacion),
# decisiones (atacar, retirarse, cobertura), disparos e impactos, daño
# recibido y provocado, causa de muerte y bloqueos de conducta.
#
# Limites conocidos (no se ocultan): la locomocion es lineal (sin A*), y
# varias ventanas tacticas del juego van en milisegundos REALES (busqueda
# de enemigo perdido, histeresis de doma, enfriamiento de avisos) — donde
# un escenario necesita que "pase el tiempo" lo dice y lo fuerza a mano.

const SurvivorBotManagerScript = preload("res://scripts/SurvivorBotManager.gd")
const WorldActionScript = preload("res://scripts/WorldAction.gd")
const NightSim = preload("res://tools/debug/BotNightSurvivalSimRegression.gd")

var failures := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

# Reloj del mundo con las MISMAS reglas que DayNightCycle (fuente unica).
class DayClock extends Node:
	var time_of_day := 6.0
	var ambient_temp := 16.0
	var weather_darkness := 0.0
	func get_ambient_temperature() -> float:
		return ambient_temp
	func is_night() -> bool:
		return DayNightCycle.is_night_at(time_of_day)
	func is_dark() -> bool:
		return DayNightCycle.is_dark_at(time_of_day, weather_darkness)
	func get_phase() -> String:
		return DayNightCycle.phase_at(time_of_day)

class DayWorld extends NightSim.SimWorld:
	var shots := {}        # bot_id -> balas disparadas
	var dmg_dealt := {}    # bot_id -> daño provocado a jugadores
	func _net_player_shot_rifle(shooter_id: int, _o: Vector3, _d: Vector3, _w: Vector3 = Vector3.ZERO) -> void:
		shots[shooter_id] = int(shots.get(shooter_id, 0)) + 1
	# Daño a un "jugador" de prueba: baja su vida y avisa a los testigos,
	# igual que el camino real de Main._net_damage_player.
	func _net_damage_player(target_peer_id: int, amount: float, sender: int, _weapon: String = "melee") -> void:
		var p = server_proxies.get(target_peer_id)
		if p == null or not is_instance_valid(p):
			return
		p.set_meta("proxy_health", maxf(0.0, float(p.get_meta("proxy_health", 100.0)) - amount))
		dmg_dealt[sender] = float(dmg_dealt.get(sender, 0.0)) + amount
		if survivor_bot_mgr != null:
			survivor_bot_mgr.note_actor_wounded(target_peer_id)

class DayMgr extends SurvivorBotManagerScript:
	var walls: Array = []      # [[Vector2, Vector2], ...] paredes opacas
	var hits := {}             # bot_id -> impactos conseguidos
	var bot_dmg := {}          # bot_id -> daño provocado a otros bots
	func _has_clear_shot(a: Vector3, c: Vector3) -> bool:
		var a2 := Vector2(a.x, a.z)
		var c2 := Vector2(c.x, c.z)
		for w in walls:
			if Geometry2D.segment_intersects_segment(a2, c2, w[0], w[1]) != null:
				return false
		return true
	func _crosses_wall(a: Vector3, c: Vector3) -> bool:
		for w in walls:
			if Geometry2D.segment_intersects_segment(Vector2(a.x, a.z), Vector2(c.x, c.z), w[0], w[1]) != null:
				return true
		return false
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
		# Las paredes del sim son opacas Y solidas: nadie las atraviesa.
		if _crosses_wall(cur, np):
			b["anim"] = "idle"
			return
		proxy.global_position = np
		b["pos"] = np
		b["anim"] = anim_name
		b["sitting"] = false
		proxy.set_meta("moving", true)
	func _is_step_blocked(a: Vector3, c: Vector3, _deep: bool = false) -> bool:
		return _crosses_wall(a, c)
	func _apply_bot_damage_to_target(b: Dictionary, target: Node3D, amount: float, weapon: String) -> void:
		var bid := int(b["bot_id"])
		if weapon == "rifle":
			hits[bid] = int(hits.get(bid, 0)) + 1
		if target != null and is_instance_valid(target) and target.is_in_group("ai_survivor_bot"):
			bot_dmg[bid] = float(bot_dmg.get(bid, 0.0)) + amount
		super._apply_bot_damage_to_target(b, target, amount, weapon)

# Animal de prueba (presa o lobo salvaje) con la interfaz que lee el bot.
class Beast extends Node3D:
	var animal_type := "deer"
	var _is_dead := false
	var tamed_to := ""
	var _tame_progress := {}
	var _state := "patrol"
	var _player: Node3D = null
	var _wolf_hunger := 10.0
	var _wolf_hunger_threshold := 50.0
	var health := 60.0
	var damage_taken := 0.0
	var hits_taken := 0
	var _gutted := false
	func take_damage(amount: float, _knife: bool = false, _attacker: Node = null) -> void:
		damage_taken += amount
		hits_taken += 1
		health -= amount
		if health <= 0.0:
			_is_dead = true

func _initialize() -> void:
	call_deferred("run")

var _prev_env: Dictionary = {}

func _new_world(tod := 12.0, temp := 16.0) -> Dictionary:
	for key in ["world", "net"]:
		var old = _prev_env.get(key)
		if old != null and is_instance_valid(old):
			old.free()
	var world := DayWorld.new()
	root.add_child(world)
	var fnet := NightSim.FakeNet.new()
	fnet.name = "NetworkManager"
	root.add_child(fnet)
	world.net = fnet
	var dc := DayClock.new()
	world.add_child(dc)
	world.day_cycle = dc
	dc.ambient_temp = temp
	dc.time_of_day = tod
	var mgr := DayMgr.new()
	mgr.name = "SurvivorBotManager"
	world.add_child(mgr)
	world.survivor_bot_mgr = mgr
	mgr.setup(world)
	mgr._memory.clear()
	for bid in mgr.bots:
		var fresh := {}
		mgr._memory[bid] = fresh
		mgr.bots[bid]["_mem"] = fresh
		mgr._ensure_bot_memory(int(bid), mgr.bots[bid].get("cfg", {}))
		# Todos lejos y quietos por defecto: cada escenario coloca a los suyos.
		_place_bot(mgr.bots[bid], Vector3(-400.0 - float(int(bid) - 901) * 60.0, 0.4, -400.0), {})
	_prev_env = {"world": world, "net": fnet}
	return {"world": world, "mgr": mgr, "dc": dc, "net": fnet}

func _place_bot(b: Dictionary, pos: Vector3, stats := {}) -> void:
	var proxy: Node3D = b["proxy"]
	proxy.global_position = pos
	b["pos"] = pos
	b["hunger"] = float(stats.get("hunger", 85.0))
	b["thirst"] = float(stats.get("thirst", 85.0))
	b["health"] = float(stats.get("health", 100.0))
	b["energy"] = float(stats.get("energy", 90.0))
	b["aggro_target"] = null
	b["aggro_timer"] = 0.0
	b["hide_timer"] = 0.0
	b["flee_until"] = 0.0
	b["sleeping"] = false
	b["sitting"] = false
	b["drink_at"] = Vector3.INF
	b["campfire_id"] = ""
	b["campfire_pos"] = Vector3.INF
	b["shelter_id"] = str(stats.get("shelter_id", ""))
	b["shelter_pos"] = stats.get("shelter_pos", Vector3.INF)
	b["team_leader_id"] = int(stats.get("team_leader_id", 0))
	b["follow_mode"] = str(stats.get("follow_mode", "stay"))
	b["sense_t"] = 0.0
	b["_ambush"] = {}
	b["_ambush_cd_until"] = 0.0
	b["_foe_mem"] = {}
	b["_s_foe"] = null
	b["_s_predator"] = null
	b["_last_attacker_msec"] = -999999
	b["_wolf_bite_msec"] = -999999
	b["_lost_foe_until_msec"] = 0
	b["_tame_pause_until"] = 0.0
	b["tame_cooldown"] = 0.0
	b["_tame_wait_t"] = 0.0
	b["shoot_cooldown"] = 0.0
	b["attack_cooldown"] = 0.0
	b["gun_reloading"] = false
	b["eat_cooldown"] = 0.0
	var st: SurvivalStats = b["vstats"]
	st.dead = false
	st.health = float(b["health"])
	st.hunger = float(b["hunger"])
	st.thirst = float(b["thirst"])
	st.energy = float(b["energy"])
	st.sleep = float(stats.get("sleep", 90.0))
	st.body_temperature = float(stats.get("body_temperature", 36.6))
	st.wetness = 0.0
	st.bleeding = 0.0
	st.blood = 100.0
	st.sick = false
	b["sick_timer"] = 0.0
	proxy.set_meta("proxy_dead", false)
	proxy.set_meta("proxy_health", float(b["health"]))
	proxy.set_meta("saved_inventory", stats.get("inventory", []))
	proxy.remove_meta("bot_gun_ammo")
	proxy.set_meta("saved_extra", {"rifle_ammo": stats.get("rifle_ammo", {"m4_magazine": 0, "m4_reserve": 0, "magazine": 0, "reserve": 0})})
	var held := str(stats.get("held", ""))
	b["held_item"] = held
	b["has_rifle"] = held.begins_with("Fusil") or held.begins_with("Rifle")
	proxy.set_meta("saved_held_item", held)

# "Jugador" de prueba: un proxy de red con solo lo que se ve desde fuera.
func _spawn_human(env: Dictionary, pid: int, pos: Vector3, held := "", backpack := "") -> Node3D:
	var world: DayWorld = env["world"]
	var p := Node3D.new()
	world.add_child(p)
	p.global_position = pos
	p.add_to_group("net_player_proxy")
	p.set_meta("peer_id", pid)
	p.set_meta("has_real_pos", true)
	p.set_meta("proxy_health", 100.0)
	p.set_meta("saved_held_item", held)
	p.set_meta("saved_backpack", backpack)
	p.set_meta("char_name", "Humano%d" % pid)
	world.server_proxies[pid] = p
	return p

func _spawn_food(world: DayWorld, aid: String, pos: Vector3, use_value := 30.0) -> void:
	# Como en Main: la vegetacion de suelo no nace dentro del agua (y la
	# locomocion lineal del sim no sabe abandonar una meta sumergida).
	if world._is_near_river(pos, 3.0) or world.get_river_depth_at(pos) > 0.0:
		return
	for seg in world.river_segs:
		var c: Vector3 = seg["center"]
		if absf(pos.x - c.x) < 9.0 and absf(pos.z - c.z) < 9.0:
			return
	var seta := WorldActionScript.new()
	seta.setup(aid, "eat_food", "Seta amanita", Vector3(0.2, 0.2, 0.2), Color(0.8, 0.15, 0.1), false, false)
	seta.set_meta("item_name", "Seta amanita")
	seta.set_meta("item_type", "food")
	seta.set_meta("item_use_value", use_value)
	seta.set_meta("item_quantity", 1)
	world.add_child(seta)
	seta.global_position = pos
	world.world_actions_by_id[aid] = seta

# Agua repartida como en el mapa real (rios, lago, fuentes): una charca
# vadeable cada ~220 m. Sin esto el mundo mock es un desierto y la sed
# mata por geografia, no por decisiones.
func _pond_grid() -> Array:
	var segs: Array = []
	for gx in range(-2, 3):
		for gz in range(-2, 5):
			segs.append({"center": Vector3(60.0 + float(gx) * 220.0, 0.0, 40.0 + float(gz) * 220.0), "size": Vector2(10.0, 10.0), "yaw": 0.0})
	return segs

func _inv_totals(b: Dictionary) -> Dictionary:
	var out := {}
	for it in (b["proxy"] as Node3D).get_meta("saved_inventory", []):
		if it is Dictionary:
			var nm := str(it.get("name", ""))
			out[nm] = float(out.get(nm, 0.0)) + float(it.get("quantity", 1))
	return out

func _ammo_total(mgr: DayMgr, b: Dictionary) -> int:
	var a: Dictionary = mgr._bot_gun_ammo(b["proxy"])
	return int(a.get("m4_magazine", 0)) + int(a.get("m4_reserve", 0)) + int(a.get("magazine", 0)) + int(a.get("reserve", 0)) \
		+ mgr._bot_arrow_count(b["proxy"])

# Bucle generico: ticks reales con registro de todo lo que pide el informe.
# opts: {"dt", "steps", "until": Callable(step)->bool, "events": [{at|every, fn}], "advance_clock": bool}
func simulate(env: Dictionary, bots: Array, opts: Dictionary) -> Array:
	var mgr: DayMgr = env["mgr"]
	var dc: DayClock = env["dc"]
	var dt := float(opts.get("dt", 0.2))
	var steps := int(opts.get("steps", 200))
	var events: Array = opts.get("events", [])
	var reps: Array = []
	for b in bots:
		reps.append({"bot_id": int(b["bot_id"]), "name": str(b.get("name", "?")), "acts": {}, "phase_acts": {},
			"src": {"seen": 0, "heard": 0, "told": 0}, "sensed_ticks": 0, "sensed_blind": 0,
			"flee_ticks": 0, "dmg_taken": 0.0, "ammo0": _ammo_total(mgr, b), "inv0": _inv_totals(b),
			"cause": "", "t": 0.0, "static_run": 0, "max_static": 0, "torch_light_viol": 0,
			"night_acts_by_day": 0, "last_src_t": -1, "start": (b["proxy"] as Node3D).global_position})
	var step := 0
	while step < steps:
		if opts.has("until") and (opts["until"] as Callable).call(step):
			break
		var phase := dc.get_phase() if not dc.is_dark() else "night"
		for i in range(bots.size()):
			var b: Dictionary = bots[i]
			var r: Dictionary = reps[i]
			var st: SurvivalStats = b["vstats"]
			var proxy: Node3D = b["proxy"]
			if st.dead or bool(proxy.get_meta("proxy_dead", false)):
				continue
			var hp0 := float(b["health"])
			var p0 := proxy.global_position
			proxy.set_meta("moving", false)
			mgr._tick_bot(b, dt)
			r["t"] = float(r["t"]) + dt
			if st.dead or bool(proxy.get_meta("proxy_dead", false)):
				r["cause"] = str(mgr._memory.get(int(b["bot_id"]), {}).get("last_death_cause", "unknown"))
				continue
			var act := str(b.get("_act", "idle"))
			r["acts"][act] = int(r["acts"].get(act, 0)) + 1
			var pa: Dictionary = r["phase_acts"].get(phase, {})
			pa[act] = int(pa.get(act, 0)) + 1
			r["phase_acts"][phase] = pa
			r["dmg_taken"] = float(r["dmg_taken"]) + maxf(0.0, hp0 - float(b["health"]))
			if float(b.get("flee_until", 0.0)) > 0.0:
				r["flee_ticks"] = int(r["flee_ticks"]) + 1
			# Deteccion real: cada tick con un enemigo sensado se comprueba
			# que haya vista u oido que lo justifique (si no, es trampa).
			var sf = b.get("_s_foe")
			if sf != null and is_instance_valid(sf):
				r["sensed_ticks"] = int(r["sensed_ticks"]) + 1
				var dd := proxy.global_position.distance_to((sf as Node3D).global_position)
				# El escaneo de sentidos va cada ~0.25 s (tiempo de reaccion):
				# solo cuenta como trampa seguirlo "sintiendo" mas de 0.5 s.
				if not mgr._has_clear_shot(proxy.global_position, (sf as Node3D).global_position) and not mgr._can_bot_hear_actor(b, sf, dd):
					r["blind_run"] = float(r.get("blind_run", 0.0)) + dt
					if float(r["blind_run"]) > 0.5:
						r["sensed_blind"] = int(r["sensed_blind"]) + 1
				else:
					r["blind_run"] = 0.0
			else:
				r["blind_run"] = 0.0
			# Fuente de cada pista nueva en la ficha de intel
			var fm: Dictionary = b.get("_foe_mem", {})
			if not fm.is_empty() and int(fm.get("t", -1)) != int(r["last_src_t"]):
				r["last_src_t"] = int(fm.get("t", -1))
				var sname := str(fm.get("src", "seen"))
				r["src"][sname] = int(r["src"].get(sname, 0)) + 1
			# Antorcha solo cuando hace falta; conducta nocturna solo de noche
			if bool(b.get("torch_lit", false)) and not dc.is_dark():
				r["torch_light_viol"] = int(r["torch_light_viol"]) + 1
			if not dc.is_dark() and act in ["need_light", "night_supplies"]:
				r["night_acts_by_day"] = int(r["night_acts_by_day"]) + 1
			# Bloqueo: quiere moverse (acto de marcha) y no avanza
			if act in ["explore", "wander", "loot", "hunt", "forage", "return_home", "mats"] \
					and proxy.global_position.distance_to(p0) < 0.02:
				r["static_run"] = int(r["static_run"]) + 1
				r["max_static"] = maxi(int(r["max_static"]), int(r["static_run"]))
			else:
				r["static_run"] = 0
		for ev in events:
			if int(ev.get("at", -1)) == step:
				ev["fn"].call()
			elif int(ev.get("every", -1)) > 0 and step % int(ev["every"]) == 0:
				ev["fn"].call()
		if bool(opts.get("advance_clock", true)):
			dc.time_of_day = fmod(dc.time_of_day + dt / 3600.0, 24.0)
		step += 1
	return reps

func _report(env: Dictionary, r: Dictionary, b: Dictionary) -> String:
	var mgr: DayMgr = env["mgr"]
	var world: DayWorld = env["world"]
	var st: SurvivalStats = b["vstats"]
	var bid := int(b["bot_id"])
	var inv1 := _inv_totals(b)
	var used := {}
	var inv0: Dictionary = r["inv0"]
	for k in inv0.keys():
		var dq := float(inv0[k]) - float(inv1.get(k, 0.0))
		if dq > 0.0:
			used[k] = dq
	var gained := {}
	for k in inv1.keys():
		var dg := float(inv1[k]) - float(inv0.get(k, 0.0))
		if dg > 0.0:
			gained[k] = dg
	var shots := int(world.shots.get(bid, 0))
	var hits := int(mgr.hits.get(bid, 0))
	return "    %s | vivo=%s causa=%s | hp=%.0f hambre=%.0f sed=%.0f sueño=%.0f en=%.0f | municion %d->%d | gastado=%s obtenido=%s | detectado=%d ticks (sin vista/oido=%d) pistas=%s | acts=%s huida=%d ticks | disparos=%d impactos=%d (%s) | daño recibido=%.0f provocado=%.0f | bloqueo max=%d ticks | %.2f h" % [
		r["name"], "SI" if not (st.dead or bool((b["proxy"] as Node3D).get_meta("proxy_dead", false))) else "NO", r["cause"] if str(r["cause"]) != "" else "-",
		float(b["health"]), st.hunger, st.thirst, st.sleep, st.energy,
		int(r["ammo0"]), _ammo_total(mgr, b), str(used), str(gained),
		int(r["sensed_ticks"]), int(r["sensed_blind"]), str(r["src"]),
		str(r["acts"]), int(r["flee_ticks"]),
		shots, hits, ("%.0f%%" % (100.0 * float(hits) / float(shots))) if shots > 0 else "s/d",
		float(r["dmg_taken"]), float(world.dmg_dealt.get(bid, 0.0)) + float(mgr.bot_dmg.get(bid, 0.0)),
		int(r["max_static"]), float(r["t"]) / 3600.0]

func _knife() -> Dictionary:
	return {"name": "Cuchillo", "type": "weapon", "weight": 0.2, "quantity": 1, "use_value": 10.0, "durability": 80.0, "max_durability": 80.0}

func _m4() -> Dictionary:
	return {"name": "Fusil de asalto", "type": "weapon", "weight": 3.2, "quantity": 1, "use_value": 0.0, "durability": 100.0, "max_durability": 100.0}

func run() -> void:
	seed(4242)
	var t0 := Time.get_ticks_msec()
	var env: Dictionary
	var w: DayWorld
	var mgr: DayMgr
	var dc: DayClock
	var reps: Array

	# ================= D1: jornada completa, los tres =====================
	# Del amanecer (06:00) hasta bien entrada la noche (22:00). Kael vive
	# lejos: aqui se mide la rutina, no el combate.
	print("D1: jornada completa de los tres (06:00 -> 22:00)")
	env = _new_world(6.3, 15.0)
	w = env["world"]
	mgr = env["mgr"]
	dc = env["dc"]
	w.river_segs = _pond_grid()
	# El hambre real drena ~0.1/s: una jornada de 16 h pide ~5800 puntos.
	# La despensa cubre parte (como en el sim nocturno) y el resto sale del
	# monte: setas alrededor de cada campamento.
	# Monte con forraje disperso por todo el mapa que recorren (los bots
	# exploran POIs a cientos de metros): escaso, no un buffet a la puerta.
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(3600):
		_spawn_food(w, "d1_s%d" % i, Vector3(rng.randf_range(-430.0, 430.0), 0.4, rng.randf_range(-430.0, 850.0)))
	var day_inv := func() -> Array:
		return [
			{"name": "Carne seca", "type": "food", "weight": 0.25, "quantity": 150, "use_value": 30.0},
			{"name": "Botella de agua llena", "type": "water", "weight": 0.5, "quantity": 3, "use_value": 45.0},
			{"name": "Palo", "type": "material", "weight": 0.3, "quantity": 6, "use_value": 0.0},
			{"name": "Piedra", "type": "material", "weight": 0.4, "quantity": 4, "use_value": 0.0},
			{"name": "Trapos", "type": "material", "weight": 0.1, "quantity": 3, "use_value": 0.0},
			_knife()]
	var elena: Dictionary = mgr.bots[901]
	var carlos: Dictionary = mgr.bots[902]
	var kael: Dictionary = mgr.bots[903]
	_place_bot(elena, Vector3(0.0, 0.4, 0.0), {"inventory": day_inv.call(), "sleep": 95.0})
	_place_bot(carlos, Vector3(25.0, 0.4, 10.0), {"inventory": day_inv.call(), "sleep": 95.0})
	_place_bot(kael, Vector3(380.0, 0.4, 400.0), {"inventory": day_inv.call(), "sleep": 95.0})
	var phases_seen: Array = []
	reps = simulate(env, [elena, carlos, kael], {"dt": 1.0, "steps": 60000,
		"until": func(_s): return dc.time_of_day >= 22.0,
		"events": [{"every": 60, "fn": func():
			var ph := dc.get_phase() if not dc.is_dark() else "night"
			if phases_seen.is_empty() or str(phases_seen[-1]) != ph:
				phases_seen.append(ph)}]})
	var trio := [elena, carlos, kael]
	for i in range(3):
		print(_report(env, reps[i], trio[i]))
		for ph in ["dawn", "day", "prep", "dusk", "night"]:
			print("        %-5s %s" % [ph, str(reps[i]["phase_acts"].get(ph, {}))])
	check(phases_seen == ["dawn", "day", "prep", "dusk", "night"],
		"D1 el reloj recorre amanecer->dia->preparacion->crepusculo->noche sin saltos (%s)" % str(phases_seen))
	for i in range(3):
		var r1: Dictionary = reps[i]
		var b1: Dictionary = trio[i]
		check(not (b1["vstats"] as SurvivalStats).dead, "D1 %s sobrevive del amanecer a la noche" % r1["name"])
		check(int(r1["night_acts_by_day"]) == 0, "D1 %s no usa conducta nocturna con luz (%d ticks)" % [r1["name"], int(r1["night_acts_by_day"])])
		check(int(r1["torch_light_viol"]) == 0, "D1 %s no enciende la antorcha con luz suficiente (%d ticks)" % [r1["name"], int(r1["torch_light_viol"])])
		var day_acts: Dictionary = r1["phase_acts"].get("day", {})
		var day_total := 0
		for k in day_acts.keys():
			day_total += int(day_acts[k])
		check(day_total > 0 and int(day_acts.get("rest", 0)) < int(float(day_total) * 0.9),
			"D1 %s tiene actividad diurna real, no pasa el dia tumbado (rest %d/%d)" % [r1["name"], int(day_acts.get("rest", 0)), day_total])
		var dusk_acts: Dictionary = r1["phase_acts"].get("dusk", {})
		check(not dusk_acts.is_empty() and int(dusk_acts.get("need_light", 0)) == 0,
			"D1 %s sigue operativo en el crepusculo con luz util (%s)" % [r1["name"], str(dusk_acts)])
		check(int(r1["max_static"]) < 600, "D1 %s sin bloqueos largos de navegacion (max %d s)" % [r1["name"], int(r1["max_static"])])

	# ================= D2: escasez de comida y agua =======================
	print("D2: escasez de comida y agua")
	env = _new_world(9.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	dc = env["dc"]
	w.river_segs = _pond_grid()
	# Escasez real: sin provisiones y con el forraje disperso por el monte
	# (media seta por cada 30 m a la redonda), no amontonado a la puerta.
	var setas2_live := func() -> int:
		var n := 0
		for k in w.world_actions_by_id.keys():
			if str(k).begins_with("d2_s"):
				n += 1
		return n
	var setas2 := 0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 5
	for i in range(520):
		_spawn_food(w, "d2_s%d" % i, Vector3(rng2.randf_range(-300.0, 300.0), 0.4, rng2.randf_range(-200.0, 800.0)))
	setas2 = setas2_live.call()
	elena = mgr.bots[901]
	_place_bot(elena, Vector3(0.0, 0.4, 0.0), {"hunger": 45.0, "thirst": 28.0, "inventory": [_knife()]})
	reps = simulate(env, [elena], {"dt": 1.0, "steps": 7200})
	print(_report(env, reps[0], elena))
	var st2: SurvivalStats = elena["vstats"]
	check(not st2.dead, "D2 sobrevive 2 h de escasez sin provisiones")
	check(st2.thirst > 28.0, "D2 fue a beber al rio (sed 28 -> %.0f)" % st2.thirst)
	check(setas2_live.call() < setas2, "D2 forrajeo comida real del mundo (%d -> %d setas)" % [setas2, setas2_live.call()])
	var inv2 := _inv_totals(elena)
	check(float(inv2.get("Carne seca", 0.0)) == 0.0 and float(inv2.get("Botella de agua llena", 0.0)) == 0.0,
		"D2 no inventa provisiones (%s)" % str(inv2))

	# ================= D3: caza y aprovechamiento =========================
	print("D3: caza de una presa")
	env = _new_world(11.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	carlos = mgr.bots[902]
	_place_bot(carlos, Vector3(0.0, 0.4, 0.0), {"hunger": 50.0, "inventory": [_m4(), _knife()],
		"rifle_ammo": {"m4_magazine": 20, "m4_reserve": 0, "magazine": 0, "reserve": 0}, "held": "Fusil de asalto"})
	var deer := Beast.new()
	w.add_child(deer)
	deer.add_to_group("wildlife")
	deer.global_position = Vector3(22.0, 0.4, 0.0)
	reps = simulate(env, [carlos], {"dt": 0.2, "steps": 600, "until": func(_s): return deer._is_dead})
	print(_report(env, reps[0], carlos))
	check(int(reps[0]["acts"].get("hunt", 0)) > 0, "D3 con hambre y presa a la vista decide cazar")
	check(deer.damage_taken > 0.0, "D3 hirio a la presa (daño %.0f en %d impactos)" % [deer.damage_taken, deer.hits_taken])
	check(_ammo_total(mgr, carlos) < int(reps[0]["ammo0"]) and _ammo_total(mgr, carlos) >= 0,
		"D3 la caza gasta municion real (%d -> %d)" % [int(reps[0]["ammo0"]), _ammo_total(mgr, carlos)])
	check(int(w.shots.get(902, 0)) == int(reps[0]["ammo0"]) - _ammo_total(mgr, carlos),
		"D3 una bala por disparo: %d disparos = %d balas" % [int(w.shots.get(902, 0)), int(reps[0]["ammo0"]) - _ammo_total(mgr, carlos)])
	if deer._is_dead:
		reps = simulate(env, [carlos], {"dt": 0.2, "steps": 400})
		print("        tras abatirla: acts=%s inventario=%s" % [str(reps[0]["acts"]), str(_inv_totals(carlos))])
		check(int(reps[0]["acts"].get("gut", 0)) > 0 or float(_inv_totals(carlos).get("Carne cruda", 0.0)) > 0.0
				or _inv_totals(carlos).keys().any(func(k): return str(k).begins_with("Carne")),
			"D3 aprovecha la pieza abatida (desuella / obtiene carne)")
	else:
		check(false, "D3 abate a la presa dentro del tiempo del escenario")

	# ================= D4: saqueo con enemigos cerca ======================
	print("D4: botin en el suelo con un bandido armado a la vista")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	elena = mgr.bots[901]
	kael = mgr.bots[903]
	mgr._set_bot_faction(elena, "friendly") # aliada (convencida): los bandidos son sus enemigos
	_place_bot(elena, Vector3(0.0, 0.4, 0.0), {"inventory": [_knife()]})
	_place_bot(kael, Vector3(0.0, 0.4, 26.0), {"inventory": [_m4(), _knife()], "held": "Fusil de asalto",
		"rifle_ammo": {"m4_magazine": 30, "m4_reserve": 30, "magazine": 0, "reserve": 0}})
	w._dropped_items.append({"id": "d4_lata", "name": "Lata de guiso", "type": "food", "weight": 0.5, "qty": 1, "use": 35.0, "pos": [10.0, 0.4, 0.0]})
	var d4_start := (elena["proxy"] as Node3D).global_position.distance_to((kael["proxy"] as Node3D).global_position)
	reps = simulate(env, [elena, kael], {"dt": 0.2, "steps": 150})
	print(_report(env, reps[0], elena))
	print(_report(env, reps[1], kael))
	check(int(reps[0]["sensed_ticks"]) > 0 and int(reps[0]["sensed_blind"]) == 0, "D4 Elena detecta al bandido por sus propios sentidos")
	var d4_bandido_muerto := float((kael["proxy"] as Node3D).get_meta("proxy_health", 100.0)) <= 0.0
	check(int(reps[0]["acts"].get("loot", 0)) == 0 or d4_bandido_muerto,
		"D4 con el enemigo encima no se pone a saquear — salvo que ya este muerto (loot=%d, bandido_muerto=%s)" % [int(reps[0]["acts"].get("loot", 0)), str(d4_bandido_muerto)])
	check(int(reps[0]["acts"].get("foe", 0)) + int(reps[0]["acts"].get("cover", 0)) > 0, "D4 reacciona a la amenaza (acts=%s)" % str(reps[0]["acts"]))
	var d4_end := (elena["proxy"] as Node3D).global_position.distance_to((kael["proxy"] as Node3D).global_position)
	var d4_melee := float(mgr.bot_dmg.get(901, 0.0)) > 0.0
	check(int(reps[0]["acts"].get("cover", 0)) > 0 or int(reps[0]["flee_ticks"]) > 0 or d4_end < d4_start or d4_melee,
		"D4 con cuchillo contra fusil: se cubre, huye o cierra distancia — no se queda al descubierto (cover=%d huida=%d, melee=%s, d %.0f->%.0f)" % [int(reps[0]["acts"].get("cover", 0)), int(reps[0]["flee_ticks"]), str(d4_melee), d4_start, d4_end])
	check(int(reps[1]["sensed_blind"]) == 0 and int(w.shots.get(903, 0)) > 0, "D4 el bandido la ve y abre fuego con municion real (%d disparos)" % int(w.shots.get(903, 0)))

	# ================= D5: enemigos tras una pared ========================
	print("D5: enemigo oculto tras una pared a 8 m")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	kael = mgr.bots[903]
	_place_bot(kael, Vector3(0.0, 0.4, 0.0), {"inventory": [_m4(), _knife()], "held": "Fusil de asalto",
		"rifle_ammo": {"m4_magazine": 30, "m4_reserve": 30, "magazine": 0, "reserve": 0}})
	var hidden := _spawn_human(env, 21, Vector3(8.0, 0.4, 0.0), "", "Mochila")
	mgr.walls = [[Vector2(4.0, -30.0), Vector2(4.0, 30.0)]]
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 150, "events": [{"every": 1, "fn": func(): kael["sense_t"] = minf(float(kael["sense_t"]), 0.2)}]})
	print(_report(env, reps[0], kael))
	check(int(reps[0]["sensed_ticks"]) == 0, "D5 quieto y en silencio tras la pared: no lo detecta")
	check(int(w.shots.get(903, 0)) == 0 and kael.get("aggro_target") == null, "D5 ni dispara ni fija objetivo a traves de la pared")
	check(int(reps[0]["acts"].get("ambush", 0)) == 0 and (kael.get("_ambush", {}) as Dictionary).is_empty(), "D5 no monta emboscada contra quien no percibe")
	check((kael.get("_foe_mem", {}) as Dictionary).is_empty(), "D5 no guarda ninguna pista del oculto")
	# Ahora camina: los pasos SI son una pista sonora valida
	hidden.set_meta("moving", true)
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 25})
	print(_report(env, reps[0], kael))
	check(int(reps[0]["sensed_ticks"]) > 0 and int(reps[0]["sensed_blind"]) == 0, "D5 al andar tras la pared lo oye (pista sonora valida)")
	check(int(reps[0]["src"].get("seen", 0)) == 0, "D5 oirlo no le da la posicion exacta 'vista' (pistas=%s)" % str(reps[0]["src"]))
	check(int(w.shots.get(903, 0)) == 0, "D5 no dispara a ciegas a traves de la pared")

	# ================= D6: emboscada a un jugador acompañado ==============
	print("D6: emboscada contra jugador acompañado")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	kael = mgr.bots[903]
	_place_bot(kael, Vector3(0.0, 0.4, 0.0), {"inventory": [_knife()]})
	(kael["_mem"] as Dictionary)["relationships"] = {}
	var mark := _spawn_human(env, 31, Vector3(0.0, 0.4, 36.0), "", "Mochila")
	var buddy := _spawn_human(env, 32, Vector3(4.0, 0.4, 38.0), "Hacha", "")
	check(mgr._find_ambush_target(kael).is_empty(), "D6 un bandido solo no embosca a quien va acompañado")
	buddy.global_position = Vector3(300.0, 0.4, 300.0)
	var plan6 := mgr._find_ambush_target(kael)
	check(int(plan6.get("target_id", 0)) == 31, "D6 cuando la presa se queda sola si es objetivo")
	kael["_ambush"] = plan6
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 40})
	print(_report(env, reps[0], kael))
	check(int(reps[0]["acts"].get("ambush", 0)) > 0, "D6 acecha a la presa (acts=%s)" % str(reps[0]["acts"]))
	check((kael["proxy"] as Node3D).global_position.distance_to(mark.global_position) < 36.0, "D6 el acecho se acerca a la presa")
	# Equipo: el miembro recibe el plan con lo que sabe su lider
	carlos = mgr.bots[902]
	carlos["faction"] = "hostile"
	(carlos["proxy"] as Node3D).set_meta("bot_faction", "hostile")
	_place_bot(carlos, Vector3(-6.0, 0.4, 0.0), {"inventory": [_knife()], "team_leader_id": 903})
	mgr.walls = [[Vector2(-3.0, 2.0), Vector2(-3.0, 60.0)]] # Carlos no ve a la presa
	kael["_ambush"] = mgr._find_ambush_target(kael) if (kael["_ambush"] as Dictionary).is_empty() else kael["_ambush"]
	mgr._ensure_bot_memory(902)["relationships"]["bot_903"] = {"id": "bot_903", "name": "Kael", "trust": 0.6, "hostility": 0.0, "fear": 0.0, "helped": 4, "attacked": 0}
	mgr._ensure_bot_memory(903)["relationships"]["bot_902"] = {"id": "bot_902", "name": "Carlos", "trust": 0.6, "hostility": 0.0, "fear": 0.0, "helped": 4, "attacked": 0}
	carlos["_soc_t"] = 0.0
	mgr._bot_social_update(carlos)
	check(int(carlos["team_leader_id"]) == 903, "D6 Carlos sigue en la banda de Kael")
	var amb_c: Dictionary = carlos.get("_ambush", {})
	check(int(amb_c.get("target_id", 0)) == 31 and amb_c.get("pos") == (kael["_ambush"] as Dictionary).get("pos"),
		"D6 emboscada coordinada: el miembro recibe la presa y la ultima posicion que conoce su lider")
	check(not mgr._bot_perceives_actor(carlos, mark, 52.0), "D6 el miembro no percibe a la presa por si mismo (solo sabe lo comunicado)")

	# ================= D7: emboscada con tregua ===========================
	print("D7: emboscada contra una victima con tregua")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	kael = mgr.bots[903]
	_place_bot(kael, Vector3(0.0, 0.4, 0.0), {"inventory": [_knife()]})
	var ally := _spawn_human(env, 41, Vector3(0.0, 0.4, 30.0), "", "Mochila")
	kael["_truce_peer"] = 41
	kael["_truce_t"] = 9999.0
	reps = simulate(env, [kael], {"dt": 0.5, "steps": 60})
	print(_report(env, reps[0], kael))
	check(int(reps[0]["acts"].get("ambush", 0)) == 0 and (kael.get("_ambush", {}) as Dictionary).is_empty(), "D7 con tregua valida no organiza emboscada")
	check(int(reps[0]["sensed_ticks"]) == 0 and int(reps[0]["acts"].get("foe", 0)) == 0, "D7 tampoco le ataca durante la tregua")
	check(is_equal_approx(float(ally.get_meta("proxy_health", 100.0)), 100.0), "D7 la victima con tregua no recibe daño")
	kael["_truce_t"] = 0.0
	kael["_truce_peer"] = 0
	(kael["proxy"] as Node3D).global_position = Vector3(0.0, 0.4, 0.0) # se habia ido a lo suyo
	check(int(mgr._find_ambush_target(kael).get("target_id", 0)) == 41, "D7 caducada la tregua vuelve a ser presa posible")

	# ================= D8: combate con municion limitada ==================
	print("D8: combate con 6 balas")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	kael = mgr.bots[903]
	_place_bot(kael, Vector3(0.0, 0.4, 0.0), {"inventory": [_m4(), _knife()], "held": "Fusil de asalto",
		"rifle_ammo": {"m4_magazine": 6, "m4_reserve": 0, "magazine": 0, "reserve": 0}})
	var target8 := _spawn_human(env, 51, Vector3(0.0, 0.4, 24.0), "Hacha", "Mochila")
	target8.set_meta("proxy_health", 100000.0) # diana: interesa el consumo, no la muerte
	kael["aggro_target"] = target8
	kael["aggro_timer"] = 60.0
	reps = simulate(env, [kael], {"dt": 0.1, "steps": 400, "events": [{"every": 20, "fn": func():
		kael["aggro_target"] = target8
		kael["aggro_timer"] = 60.0}]})
	await create_timer(0.5).timeout # rafagas en vuelo
	print(_report(env, reps[0], kael))
	var ammo8: Dictionary = mgr._bot_gun_ammo(kael["proxy"])
	check(int(w.shots.get(903, 0)) == 6, "D8 dispara exactamente las 6 balas que tiene (disparos=%d)" % int(w.shots.get(903, 0)))
	check(int(ammo8.get("m4_magazine", -1)) == 0 and int(ammo8.get("m4_reserve", -1)) == 0, "D8 la municion queda en 0, nunca negativa")
	check(not mgr._bot_has_ranged_weapon(kael["proxy"]) and str(mgr._pick_fight_weapon(kael, 20.0).get("kind", "")) == "melee",
		"D8 con el fusil seco pasa al arma alternativa")
	check(not mgr._has_combat_edge(kael, target8) or (kael["proxy"] as Node3D).global_position.distance_to(target8.global_position) > 12.0 and false,
		"D8 sin balas deja de contar con ventaja a distancia")
	var shots8 := int(w.shots.get(903, 0))
	reps = simulate(env, [kael], {"dt": 0.1, "steps": 100})
	check(int(w.shots.get(903, 0)) == shots8, "D8 no dispara balas inexistentes despues de vaciar el cargador")

	# ================= D9: herido que debe retirarse ======================
	print("D9: Kael herido (35 hp) con el fusil descargado frente a un enemigo armado")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	kael = mgr.bots[903]
	_place_bot(kael, Vector3(0.0, 0.4, 0.0), {"health": 35.0, "inventory": [_m4(), _knife()], "held": "Fusil de asalto"})
	var gunman := _spawn_human(env, 61, Vector3(0.0, 0.4, 28.0), "Fusil de asalto", "")
	check(not mgr._has_combat_edge(kael, gunman), "D9 fusil vacio + 35 hp: no se cree con superioridad tactica")
	var d9_0 := (kael["proxy"] as Node3D).global_position.distance_to(gunman.global_position)
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 60, "advance_clock": false})
	print(_report(env, reps[0], kael))
	var d9_1 := (kael["proxy"] as Node3D).global_position.distance_to(gunman.global_position)
	check(int(reps[0]["flee_ticks"]) > 0 and d9_1 > d9_0 + 10.0, "D9 se retira en vez de cargar (d %.0f -> %.0f m, huida %d ticks)" % [d9_0, d9_1, int(reps[0]["flee_ticks"])])
	check(int(w.shots.get(903, 0)) == 0, "D9 no dispara un arma vacia")
	# Contraste: el mismo Kael sano y con el cargador lleno SI pelea
	_place_bot(kael, Vector3(0.0, 0.4, 0.0), {"health": 100.0, "inventory": [_m4(), _knife()], "held": "Fusil de asalto",
		"rifle_ammo": {"m4_magazine": 30, "m4_reserve": 30, "magazine": 0, "reserve": 0}})
	gunman.global_position = Vector3(0.0, 0.4, 28.0)
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 40, "advance_clock": false})
	await create_timer(0.4).timeout
	print(_report(env, reps[0], kael))
	check(int(w.shots.get(903, 0)) > 0 and int(reps[0]["flee_ticks"]) == 0, "D9 sano y con balas combate: la retirada depende de sus posibilidades reales")

	# ================= D10: doma interrumpida por un ataque ===============
	print("D10: Elena doma un lobo y recibe disparos")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	elena = mgr.bots[901]
	kael = mgr.bots[903]
	mgr._set_bot_faction(elena, "friendly")
	_place_bot(elena, Vector3(0.0, 0.4, 0.0), {"inventory": [
		{"name": "Carne cruda de ciervo", "type": "food", "weight": 0.3, "quantity": 3, "use_value": 15.0}, _knife()]})
	var wolf := Beast.new()
	wolf.animal_type = "wolf"
	wolf._state = "wary"
	w.add_child(wolf)
	wolf.add_to_group("wildlife")
	wolf.global_position = Vector3(9.0, 0.4, 0.0)
	reps = simulate(env, [elena], {"dt": 0.2, "steps": 15})
	check(int(reps[0]["acts"].get("tame", 0)) > 0, "D10 en calma empieza la doma (acts=%s)" % str(reps[0]["acts"]))
	var bait_left := mgr._bot_tame_bait_count(elena["proxy"])
	check(bait_left == 2, "D10 solto el primer cebo (quedan %d)" % bait_left)
	wolf._tame_progress = {"901": 1} # el lobo acredita la primera toma
	# Kael abre fuego desde 30 m, a la vista
	_place_bot(kael, Vector3(0.0, 0.4, 30.0), {"inventory": [_m4()], "held": "Fusil de asalto",
		"rifle_ammo": {"m4_magazine": 30, "m4_reserve": 0, "magazine": 0, "reserve": 0}})
	mgr.on_bot_damaged(901, 18.0, 903, "rifle")
	reps = simulate(env, [elena], {"dt": 0.2, "steps": 30})
	print(_report(env, reps[0], elena))
	check(int(reps[0]["acts"].get("tame", 0)) == 0, "D10 bajo fuego interrumpe la doma (acts=%s)" % str(reps[0]["acts"]))
	check(int(reps[0]["acts"].get("foe", 0)) + int(reps[0]["acts"].get("cover", 0)) + int(reps[0]["flee_ticks"]) > 0, "D10 reacciona al ataque: combate, cobertura o huida")
	check(int(reps[0]["acts"].get("predator", 0)) == 0 and wolf.hits_taken == 0, "D10 no la emprende con el lobo manso que estaba domando")
	check(int(wolf._tame_progress.get("901", 0)) == 1 and mgr._bot_tame_bait_count(elena["proxy"]) == bait_left, "D10 conserva el progreso y el cebo")
	# El peligro pasa (Kael se va; la histeresis de 8 s reales se da por cumplida)
	_place_bot(kael, Vector3(-400.0, 0.4, -400.0), {})
	(elena["proxy"] as Node3D).global_position = Vector3(0.0, 0.4, 0.0)
	wolf.global_position = Vector3(9.0, 0.4, 0.0)
	for k in ["aggro_target", "_s_foe"]:
		elena[k] = null
	elena["flee_until"] = 0.0
	elena["hide_timer"] = 0.0
	elena["_last_attacker_msec"] = -999999
	elena["_tame_pause_until"] = 0.0
	elena["_lost_foe_until_msec"] = 0
	elena["health"] = 82.0
	(elena["vstats"] as SurvivalStats).health = 82.0
	elena["tame_cooldown"] = 0.0
	reps = simulate(env, [elena], {"dt": 0.2, "steps": 20})
	check(int(reps[0]["acts"].get("tame", 0)) > 0 and mgr._bot_tame_bait_count(elena["proxy"]) < bait_left,
		"D10 a salvo retoma la doma con el cebo que le faltaba (acts=%s)" % str(reps[0]["acts"]))
	# Y si el lobo se revuelve, es un depredador como cualquiera
	wolf._state = "chase_player"
	wolf._player = elena["proxy"]
	wolf.global_position = Vector3(7.0, 0.4, 0.0)
	elena["_tame_wait_t"] = 0.0
	elena["tame_cooldown"] = 0.0
	reps = simulate(env, [elena], {"dt": 0.2, "steps": 10})
	check(int(reps[0]["acts"].get("predator", 0)) > 0 and int(reps[0]["acts"].get("tame", 0)) == 0,
		"D10 lobo agresivo: reacciona como ante un depredador (acts=%s)" % str(reps[0]["acts"]))

	# ================= D11: defensa de un compañero =======================
	print("D11: Kael ataca a Elena; Carlos, su compañero, no ve al agresor")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	elena = mgr.bots[901]
	carlos = mgr.bots[902]
	kael = mgr.bots[903]
	mgr._set_bot_faction(elena, "friendly")
	mgr._set_bot_faction(carlos, "friendly")
	_place_bot(elena, Vector3(0.0, 0.4, 0.0), {"inventory": [_knife()]})
	_place_bot(carlos, Vector3(-30.0, 0.4, 0.0), {"team_leader_id": 901, "follow_mode": "stay", "inventory": [_m4(), _knife()], "held": "Fusil de asalto",
		"rifle_ammo": {"m4_magazine": 30, "m4_reserve": 30, "magazine": 0, "reserve": 0}})
	_place_bot(kael, Vector3(0.0, 0.4, 20.0), {"inventory": [_knife()]})
	mgr.walls = [[Vector2(-15.0, -40.0), Vector2(-15.0, 60.0)]] # pared entre Carlos y la pelea
	check(mgr._find_combat_foe(elena) == kael["proxy"], "D11 Elena si ve al bandido que tiene a 20 m")
	check(mgr._find_combat_foe(carlos) == null, "D11 Carlos no detecta por si mismo al bandido que esta junto a su lider")
	var kael_pos0 := (kael["proxy"] as Node3D).global_position
	# Kael golpea a Elena: mismo orden que Main (_net_damage_player)
	mgr.note_actor_wounded(901)
	mgr.on_bot_damaged(901, 12.0, 903, "melee")
	mgr.rally_bot_team(901, kael["proxy"])
	var fm11: Dictionary = carlos.get("_foe_mem", {})
	check(str(fm11.get("src", "")) == "told" and float(fm11.get("conf", 1.0)) < 1.0, "D11 Carlos recibe un aviso (fuente=comunicacion, fiabilidad %.2f)" % float(fm11.get("conf", 1.0)))
	check((fm11.get("pos", Vector3.INF) as Vector3).distance_to(kael_pos0) <= 10.5, "D11 el aviso lleva la ultima posicion que conoce Elena")
	(kael["proxy"] as Node3D).global_position = Vector3(40.0, 0.4, 60.0) # el agresor se mueve tras el golpe
	var d11_0 := (carlos["proxy"] as Node3D).global_position.distance_to(kael_pos0)
	reps = simulate(env, [carlos], {"dt": 0.2, "steps": 40, "advance_clock": false})
	print(_report(env, reps[0], carlos))
	var d11_1 := (carlos["proxy"] as Node3D).global_position.distance_to(kael_pos0)
	check(int(reps[0]["sensed_blind"]) == 0, "D11 Carlos nunca 'siente' al enemigo sin verlo ni oirlo")
	check(int(reps[0]["acts"].get("search_foe", 0)) > 0 and d11_1 < d11_0 - 5.0,
		"D11 acude a la posicion comunicada a defender a su compañera (d %.0f -> %.0f, acts=%s)" % [d11_0, d11_1, str(reps[0]["acts"])])
	check((carlos.get("_lost_foe_pos", Vector3.INF) as Vector3).distance_to((kael["proxy"] as Node3D).global_position) > 30.0
			or int(carlos.get("_lost_foe_until_msec", 0)) == 0,
		"D11 busca donde le dijeron, no donde el agresor esta ahora")

	# ================= D12: enemigo perdido de vista ======================
	print("D12: enemigo perdido de vista y busqueda en la ultima posicion conocida")
	env = _new_world(12.0, 16.0)
	w = env["world"]
	mgr = env["mgr"]
	kael = mgr.bots[903]
	_place_bot(kael, Vector3(0.0, 0.4, 0.0), {"inventory": [_m4(), _knife()], "held": "Fusil de asalto",
		"rifle_ammo": {"m4_magazine": 30, "m4_reserve": 30, "magazine": 0, "reserve": 0}})
	var runner := _spawn_human(env, 71, Vector3(0.0, 0.4, 30.0), "Hacha", "Mochila")
	runner.set_meta("proxy_health", 100000.0)
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 15, "advance_clock": false})
	check(int(reps[0]["sensed_ticks"]) > 0 and int(reps[0]["src"].get("seen", 0)) > 0, "D12 lo detecta a la vista (pistas=%s)" % str(reps[0]["src"]))
	var last_seen := runner.global_position
	# Se mete tras una pared y se aleja en silencio
	mgr.walls = [[Vector2(-60.0, 34.0), Vector2(60.0, 34.0)]]
	runner.global_position = Vector3(45.0, 0.4, 70.0)
	kael["aggro_target"] = runner
	kael["aggro_timer"] = 30.0
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 50, "advance_clock": false})
	await create_timer(0.4).timeout
	print(_report(env, reps[0], kael))
	check(int(reps[0]["sensed_blind"]) == 0 and kael.get("aggro_target") == null, "D12 al perderlo de vista suelta el objetivo vivo (sin radar)")
	check(int(reps[0]["acts"].get("search_foe", 0)) > 0, "D12 pasa a buscarlo (acts=%s)" % str(reps[0]["acts"]))
	var anchor12: Vector3 = kael.get("_lost_foe_pos", Vector3.INF)
	check(anchor12 != Vector3.INF and anchor12.distance_to(last_seen) < 12.0 and anchor12.distance_to(runner.global_position) > 30.0,
		"D12 la busqueda va a la ultima posicion CONOCIDA, no a la real")
	var evs12: Array = (mgr._ensure_bot_memory(903) as Dictionary).get("events", [])
	check(evs12.any(func(e): return str(e.get("type", "")) == "lost_foe"), "D12 el enemigo perdido queda en su memoria")
	# La ventana de busqueda va en tiempo real: se da por agotada
	kael["_lost_foe_until_msec"] = Time.get_ticks_msec() - 1
	reps = simulate(env, [kael], {"dt": 0.2, "steps": 20, "advance_clock": false})
	check(int(reps[0]["acts"].get("search_foe", 0)) <= 1 and int(reps[0]["sensed_ticks"]) == 0,
		"D12 sin indicios abandona la busqueda y sigue con su vida (acts=%s)" % str(reps[0]["acts"]))

	print("BotDaySurvivalSimRegression errors=%d (%.1f s)" % [failures, (Time.get_ticks_msec() - t0) / 1000.0])
	for key in ["world", "net"]:
		var old = _prev_env.get(key)
		if old != null and is_instance_valid(old):
			old.free()
	quit(1 if failures else 0)
