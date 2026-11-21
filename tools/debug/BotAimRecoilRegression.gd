extends SceneTree

# Regresion de punteria/retroceso de bots: las mismas limitaciones fisicas que
# el jugador (adquisicion lenta, respiracion, postura, fatiga, retroceso
# acumulado en rafaga, energia minima) + proyectil fisico con capsula.
const MgrScript = preload("res://scripts/SurvivorBotManager.gd")

var failures := 0

func check(ok: bool, msg: String) -> void:
	if ok: print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

class Arena extends Node3D:
	var distant_cover := false
	var shots: Array = []
	var day_cycle: DayNightCycle
	var _lit_campfires: Array = []
	var world_actions_by_id: Dictionary = {}
	func _has_clear_shot(_a: Vector3, _b: Vector3) -> bool:
		return not distant_cover
	func raycast_distant_props(_a: Vector3, _b: Vector3) -> Dictionary:
		return {}
	func _net_player_shot_rifle(_id: int, _o: Vector3, _d: Vector3, _w: Vector3) -> void:
		shots.append(_d)
	func _net_primitive_shot(_id: int, _o: Vector3, _d: Vector3, _i: String, _s: float) -> void:
		pass
	# Autoridad del servidor: aplica el daño al proxy del peer (espejo
	# simplificado de Main._net_damage_player).
	func _net_damage_player(peer_id: int, amount: float, _attacker: int, _weapon: String) -> void:
		for n in get_tree().get_nodes_in_group("net_player_proxy"):
			if int(n.get_meta("peer_id", 0)) == peer_id:
				var hp := maxf(0.0, float(n.get_meta("proxy_health", 100.0)) - amount)
				n.set_meta("proxy_health", hp)
				return

class Manager extends MgrScript:
	var moves := 0
	func _has_clear_shot(_a: Vector3, _b: Vector3) -> bool:
		return not (world as Arena).distant_cover
	func _move_bot_towards(_b: Dictionary, _t: Vector3, _s: float, _d: float, _a: String) -> void:
		moves += 1
	func _is_step_blocked(_a: Vector3, _b: Vector3, _c := false) -> bool:
		return false

func _mk_proxy(inv: Array = [], ammo := {}) -> Node3D:
	var p := Node3D.new()
	p.set_meta("saved_inventory", inv)
	p.set_meta("proxy_health", 100.0)
	p.set_meta("proxy_dead", false)
	if not ammo.is_empty():
		p.set_meta("bot_gun_ammo", ammo)
	return p

func _mk_bot(proxy: Node3D, extra := {}) -> Dictionary:
	var b := {"proxy": proxy, "bot_id": 9901, "held_item": "Fusil de asalto",
		"health": 100.0, "energy": 100.0, "shoot_cooldown": 0.0, "attack_cooldown": 0.0,
		"is_aiming": false, "crouching": false, "prone": false, "sitting": false,
		"sleeping": false, "dead": false, "anim": "", "strafe_timer": 0.0,
		"strafe_dir": 1.0, "rot": 0.0, "_mem": {"stats": {}}, "_foe_mem": {}}
	for k in extra.keys():
		b[k] = extra[k]
	return b

func _aim_err_deg(b: Dictionary, desired_from: Node3D, origin: Vector3) -> float:
	var a = b.get("_aim")
	if not (a is Dictionary):
		return 999.0
	var desired := (desired_from.global_position + Vector3(0, 1.02, 0) - origin).normalized()
	return rad_to_deg(Vector3(a["dir"]).angle_to(desired))

func _sample_hits(mgr: Manager, arena: Arena, options: Dictionary) -> int:
	# Use the game's actual proxy-capsule intersection for the aim comparison.
	# This deliberately gives the bot perfect breath control and recovered recoil:
	# even this best case must not produce perfect tracking in poor visibility.
	seed(73129)
	var dist := float(options.get("distance", 25.0))
	var kind := str(options.get("kind", "m4"))
	arena.day_cycle.time_of_day = 23.0 if bool(options.get("night", false)) else 12.0
	var shooter := _mk_proxy()
	var target := _mk_proxy()
	arena.add_child(shooter)
	arena.add_child(target)
	shooter.position = Vector3(300, 0, 0)
	target.set_meta("torch_lit", bool(options.get("lit", false)))
	target.set_meta("crouching", bool(options.get("target_low", false)))
	target.add_to_group("net_player_proxy")
	var b := _mk_bot(shooter, {"is_aiming": true,
		"held_item": "Rifle francotirador" if kind == "sniper" else "Fusil de asalto",
		"prone": bool(options.get("prone", false)),
		"crouching": bool(options.get("crouching", false)),
		"anim": "walk" if bool(options.get("moving", false)) else ""})
	var probe := preload("res://scripts/RifleProjectile.gd").new()
	arena.add_child(probe)
	probe.set_physics_process(false)
	probe.shooter = shooter
	var origin := shooter.position + Vector3.UP * (0.3 if b.prone else (1.0 if b.crouching else 1.4))
	var hits := 0
	var unavailable := 0
	var t := 0.0
	for sample in 420:
		for tick in 17:
			t += 0.07
			var speed := float(options.get("target_speed", 0.0))
			var lateral := sin(t * 1.5) * speed / 1.5
			target.position = shooter.position + Vector3(lateral, 0, dist)
			# Supply a measured velocity history to the accelerated simulation;
			# the production tracker uses wall time, not this test's simulated time.
			b["_foe_track"] = {"id": target.get_instance_id(), "msec": Time.get_ticks_msec(),
				"tpos": target.position, "vel": Vector3(cos(t * 1.5) * speed, 0, 0)}
			mgr._bot_aim_tick(b, target, dist, true, 0.07, kind)
		if not mgr._bot_within_aim_sight(b, target, shooter.position.distance_to(target.position)):
			unavailable += 1
			continue
		var a: Dictionary = b["_aim"]
		a["hold_on"] = true
		a["rp"] = 0.0
		a["ry"] = 0.0
		if bool(options.get("exact_reference", false)):
			a["dir"] = (mgr._bot_aim_point(b, target, dist, kind) - origin).normalized()
		var dir := mgr._bot_aim_fire_dir(b, kind, mgr._bot_current_spread_deg(b, kind == "m4"))
		probe._refresh_proxy_candidates()
		if probe._proxy_segment_hit(origin, origin + dir * (dist + 10.0)).get("node") == target:
			hits += 1
	print("AIM_SAMPLE ", options, " hits=", hits, "/420 not_visible=", unavailable)
	check(unavailable == 0, "comparison target remains inside its effective visibility range")
	probe.free()
	target.free()
	shooter.free()
	arena.day_cycle.time_of_day = 12.0
	return hits

func _check_night_aim(mgr: Manager, arena: Arena) -> void:
	var proxy := _mk_proxy([{"name": "Fusil de asalto", "type": "weapon", "quantity": 1}],
		{"m4_magazine": 30, "m4_reserve": 0, "magazine": 0, "reserve": 0})
	var target := _mk_proxy()
	arena.add_child(proxy)
	arena.add_child(target)
	target.position = Vector3(0, 0, 45)
	var b := _mk_bot(proxy, {"is_aiming": true})
	for i in 10:
		mgr._bot_aim_tick(b, target, 45.0, true, 0.1, "m4")
	var seen: Vector3 = b["_aim"]["last_pt"]
	arena.day_cycle.time_of_day = 23.0
	target.position.x += 2.0
	check(not mgr._bot_fire_ready(b, target, 45.0, true, 0.2, "m4"),
		"clear geometric LOS is insufficient for an unlit distant target at night")
	check(Vector3(b["_aim"]["last_pt"]).is_equal_approx(seen),
		"losing night visibility preserves the last observation instead of tracking the live torso")
	check(float(b["_aim"]["settle"]) == 0.0, "loss of visibility requires reacquisition")
	b["prone"] = true
	check(not mgr._bot_within_aim_sight(b, target, 45.0),
		"lying prone on the ground cannot grant extra night vision")
	b["prone"] = false
	mgr._ai_note_foe_scan(b, target)
	check((b["_foe_mem"] as Dictionary).is_empty(),
		"hearing a target in darkness cannot record its live position as visually seen")
	var ammo := mgr._bot_gun_loaded(mgr._bot_gun_ammo(proxy), "Fusil de asalto")
	check(not mgr._bot_fire_rifle_round(b, target, 26.0, "Fusil de asalto"),
		"an already queued burst round revalidates night visibility")
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(proxy), "Fusil de asalto") == ammo and b.energy == 100.0,
		"an invisible target costs neither a round nor shot energy")
	target.set_meta("torch_lit", true)
	var reacquired := false
	for i in 12:
		reacquired = mgr._bot_fire_ready(b, target, 45.0, true, 0.1, "m4") or reacquired
	check(reacquired, "a torch reveals the target again after acquisition")
	mgr._bot_fire_rifle_at(b, target, 26.0, "Fusil de asalto")
	var after_first := mgr._bot_gun_loaded(mgr._bot_gun_ammo(proxy), "Fusil de asalto")
	target.set_meta("torch_lit", false)
	await create_timer(0.22).timeout
	check(after_first == ammo - 1 and mgr._bot_gun_loaded(mgr._bot_gun_ammo(proxy), "Fusil de asalto") == after_first,
		"the real burst callbacks stop when the target extinguishes its light")
	target.set_meta("torch_lit", true)
	arena.distant_cover = true
	check(not mgr._bot_fire_rifle_round(b, target, 26.0, "Fusil de asalto"),
		"a target's light never authorizes shooting through a wall")
	arena.distant_cover = false
	target.set_meta("torch_lit", false)
	var fire := Node3D.new()
	arena.add_child(fire)
	fire.set_meta("lit", true)
	arena.world_actions_by_id["test_fire"] = fire
	arena._lit_campfires = [{"id": "test_fire", "pos": target.position}]
	check(mgr._bot_within_aim_sight(b, target, 45.0), "a nearby burning campfire makes the target visible")
	fire.set_meta("lit", false)
	check(not mgr._bot_within_aim_sight(b, target, 45.0), "an extinguished fire gives no visibility bonus")
	arena._lit_campfires.clear()
	arena.world_actions_by_id.clear()
	fire.free()
	target.free()
	proxy.free()
	arena.day_cycle.time_of_day = 12.0
	var reference := _sample_hits(mgr, arena, {"exact_reference": true})
	var daylight := _sample_hits(mgr, arena, {})
	var darkness := _sample_hits(mgr, arena, {"night": true})
	var illuminated := _sample_hits(mgr, arena, {"night": true, "lit": true})
	var sprinting := _sample_hits(mgr, arena, {"night": true, "target_speed": 6.0})
	var near := _sample_hits(mgr, arena, {"night": true, "distance": 10.0})
	var far := _sample_hits(mgr, arena, {"distance": 40.0})
	var moving := _sample_hits(mgr, arena, {"moving": true})
	var low := _sample_hits(mgr, arena, {"night": true, "distance": 20.0, "target_low": true})
	var sniper_day := _sample_hits(mgr, arena, {"kind": "sniper", "distance": 50.0, "prone": true})
	var sniper_night := _sample_hits(mgr, arena, {"kind": "sniper", "distance": 50.0, "prone": true, "night": true})
	check(reference == 420, "the previous exact-torso reference hits every stationary capsule")
	check(daylight < reference and daylight > 210, "daylight aim remains dangerous but is not a perfect lock")
	check(darkness < daylight * 0.75 and darkness > 20, "darkness reduces hits without forcing every shot to miss")
	check(illuminated > darkness * 1.2 and illuminated < reference, "lighting helps without granting perfect aim")
	check(sprinting < darkness * 0.85, "target movement defeats delayed night tracking")
	check(near > darkness * 1.5, "close targets remain easier to hit than distant silhouettes")
	check(far < daylight * 0.85, "aim error grows with distance")
	check(moving < daylight * 0.9, "moving the shooter worsens aim")
	check(low < near, "a smaller crouched target is not given a standing hit capsule")
	check(sniper_night < sniper_day * 0.75 and sniper_night > 10,
		"prone sniper and held breath still have night recognition error")

func _initialize() -> void:
	seed(73129)
	var arena := Arena.new()
	root.add_child(arena)
	arena.day_cycle = DayNightCycle.new()
	arena.add_child(arena.day_cycle)
	# _initialize runs before READY enables _process automatically. Disable
	# the node's process mode so real wall time cannot replace the test night
	# while the delayed burst callbacks run.
	arena.day_cycle.process_mode = Node.PROCESS_MODE_DISABLED
	arena.day_cycle.time_of_day = 12.0
	var mgr := Manager.new()
	arena.add_child(mgr)
	mgr.world = arena
	await process_frame

	# ---- 1-5) Dispersion por postura/movimiento: mismas reglas del jugador
	var p1 := _mk_proxy([{"name": "Fusil de asalto", "type": "weapon", "quantity": 1}],
		{"m4_magazine": 30, "m4_reserve": 90, "magazine": 0, "reserve": 0})
	arena.add_child(p1)
	var b1 := _mk_bot(p1)
	# De pie sin apuntar: 0.6 * M4_SPREAD_MULT
	var s_stand := mgr._bot_current_spread_deg(b1, true)
	b1["is_aiming"] = true
	var s_aim := mgr._bot_current_spread_deg(b1, true)
	b1["crouching"] = true
	var s_crouch := mgr._bot_current_spread_deg(b1, true)
	b1["crouching"] = false; b1["prone"] = true
	var s_prone := mgr._bot_current_spread_deg(b1, true)
	b1["prone"] = false; b1["anim"] = "walk"
	var s_walk := mgr._bot_current_spread_deg(b1, true)
	b1["anim"] = "run"
	var s_run := mgr._bot_current_spread_deg(b1, true)
	b1["anim"] = ""
	check(s_stand > s_aim, "apuntar mejora la dispersion de pie")
	check(is_equal_approx(s_crouch, 0.012 * PlayerController.M4_SPREAD_MULT), "agachado = 0.012 como el jugador")
	check(is_equal_approx(s_prone, 0.006 * PlayerController.M4_SPREAD_MULT), "tumbado = 0.006 como el jugador")
	check(s_walk > s_aim * 2.0, "caminar multiplica la dispersion")
	check(s_run > s_aim * 2.0, "correr multiplica la dispersion")

	# ---- Adquisicion gradual: la mira nunca salta al objetivo
	var foe1 := Node3D.new()
	arena.add_child(foe1)
	foe1.global_position = Vector3(0, 0, 30)
	await process_frame
	var b2 := _mk_bot(p1)
	var err0 := mgr._bot_aim_tick(b2, foe1, 30.0, true, 0.016, "m4")
	# No es un lock instantaneo: la adquisicion acaba de empezar y, en media,
	# la mira arranca desviada del objetivo (±14 deg de offset inicial).
	check(float(b2["_aim"]["settle"]) < mgr._bot_acquire_sec(b2),
		"la mira no se clava al objetivo en el primer tick (err %.2f deg)" % err0)
	var err_sum := 0.0
	for i in 10:
		var bz := _mk_bot(p1)
		err_sum += mgr._bot_aim_tick(bz, foe1, 30.0, true, 0.016, "m4")
	check(err_sum / 10.0 > 2.0, "la mira arranca desviada en media (%.1f deg)" % (err_sum / 10.0))
	var converged := false
	for i in 60:
		var e := mgr._bot_aim_tick(b2, foe1, 30.0, true, 0.05, "m4")
		if e < 0.5:
			converged = true
			break
	check(converged, "la mira converge al objetivo en tiempo finito")

	# ---- 6) Energia baja: mas oscilacion y giro mas lento
	var p2 := _mk_proxy([], {})
	arena.add_child(p2)
	var b_low := _mk_bot(p2, {"energy": 8.0, "is_aiming": true})
	var b_full := _mk_bot(p2, {"energy": 100.0, "is_aiming": true})
	var sway_low := mgr._bot_breath_offsets(b_low, "m4").length()
	var sway_full := mgr._bot_breath_offsets(b_full, "m4").length()
	# amplitud media: con energia baja el doble o mas
	var amp_low := 0.0; var amp_full := 0.0
	for i in 40:
		b_low["_aim"]["breath_t"] = i * 0.2
		b_full["_aim"]["breath_t"] = i * 0.2
		amp_low = maxf(amp_low, mgr._bot_breath_offsets(b_low, "m4").length())
		amp_full = maxf(amp_full, mgr._bot_breath_offsets(b_full, "m4").length())
	check(amp_low > amp_full * 1.5, "sin energia la respiracion descompone la mira (%.4f vs %.4f)" % [amp_low, amp_full])
	# sin energia no hay disparo (puerta del jugador)
	var b_tired := _mk_bot(p1, {"energy": 1.0})
	mgr._bot_fire_rifle_round(b_tired, foe1, 26.0, "Fusil de asalto")
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p1), "Fusil de asalto") == 30,
		"sin energia no sale ninguna bala")

	# ---- 7) Rafaga M4: retroceso acumulado entre balas
	var p3 := _mk_proxy([{"name": "Fusil de asalto", "type": "weapon", "quantity": 1}],
		{"m4_magazine": 30, "m4_reserve": 90, "magazine": 0, "reserve": 0})
	arena.add_child(p3)
	var b3 := _mk_bot(p3)
	b3["is_aiming"] = true
	mgr._bot_aim_tick(b3, foe1, 20.0, true, 1.0, "m4")
	var rp0 := float(b3["_aim"]["rp"])
	mgr._bot_fire_rifle_round(b3, foe1, 26.0, "Fusil de asalto")
	var rp1 := float(b3["_aim"]["rp"])
	mgr._bot_fire_rifle_round(b3, foe1, 26.0, "Fusil de asalto")
	var rp2 := float(b3["_aim"]["rp"])
	check(rp1 > rp0 and rp2 > rp1, "rafaga acumula retroceso (%.3f -> %.3f -> %.3f)" % [rp0, rp1, rp2])
	# Las direcciones de salida divergen: cada bala paga el retroceso previo
	var log3: Array = b3.get("_shot_log", [])
	check(log3.size() == 2, "dos balas registradas en la rafaga")
	if log3.size() == 2:
		var dd := rad_to_deg((log3[0]["dir"] as Vector3).angle_to(log3[1]["dir"]))
		check(dd > 0.4, "las balas de la rafaga divergen por el retroceso (%.2f deg)" % dd)

	# ---- 8) Francotirador: mas retroceso que el M4
	var p4 := _mk_proxy([{"name": "Rifle francotirador", "type": "weapon", "quantity": 1}],
		{"m4_magazine": 0, "m4_reserve": 0, "magazine": 5, "reserve": 20})
	arena.add_child(p4)
	var b4 := _mk_bot(p4, {"held_item": "Rifle francotirador"})
	b4["is_aiming"] = true
	mgr._bot_aim_tick(b4, foe1, 40.0, true, 1.0, "sniper")
	mgr._bot_fire_rifle_round(b4, foe1, 48.0, "Rifle francotirador")
	var rp_sn := float(b4["_aim"]["rp"])
	check(rp_sn > deg_to_rad(PlayerController.M4_RECOIL) * 1.2,
		"el francotirador patea mas que el M4 (%.3f rad)" % rp_sn)

	# ---- 9-10) Objetivo en movimiento / cambio de objetivo
	var foe2 := Node3D.new()
	arena.add_child(foe2)
	var b5 := _mk_bot(p1)
	for i in 8:
		mgr._bot_aim_tick(b5, foe1, 20.0, true, 0.05, "m4")
	var err_static := mgr._bot_aim_tick(b5, foe1, 20.0, true, 0.05, "m4")
	var last_sample: Vector3 = b5["_aim"]["sample_pt"]
	b5["_aim"]["sample_t"] = 0.16
	foe1.global_position += Vector3(6.0, 0.0, 0.0)  # sprint lateral brusco
	mgr._bot_aim_tick(b5, foe1, 20.0, true, 0.05, "m4")
	check(Vector3(b5["_aim"]["sample_pt"]).is_equal_approx(last_sample),
		"un cambio brusco no actualiza la observacion antes del tiempo de reaccion")
	var err_move := 0.0
	for i in 4:
		err_move = maxf(err_move, mgr._bot_aim_tick(b5, foe1, 20.0, true, 0.05, "m4"))
	check(err_move > err_static + 0.5, "el blanco en carrera rompe la mira al ser observado de nuevo (%.2f -> %.2f deg)" % [err_static, err_move])
	foe2.global_position = foe1.global_position + Vector3(10, 0, 5)
	mgr._bot_aim_tick(b5, foe2, 20.0, true, 0.05, "m4")
	check(float(b5["_aim"]["settle"]) < 0.1, "cambiar de blanco reinicia la adquisicion")
	check(float(b5["_aim"]["shock"]) > 0.1, "cambiar de blanco descompone algo la mira")

	# ---- 11-13) Muro / perdida de vista: ultima posicion conocida, no la viva
	var b6 := _mk_bot(p1)
	for i in 8:
		mgr._bot_aim_tick(b6, foe1, 20.0, true, 0.05, "m4")
	b6["_foe_mem"] = {"pos": foe1.global_position, "t": 0, "conf": 1.0, "src": "sight"}
	foe1.global_position += Vector3(50.0, 0.0, 0.0)  # desaparece tras el muro
	mgr._bot_aim_tick(b6, foe1, 20.0, false, 0.05, "m4")
	var last_pt: Vector3 = b6["_aim"]["last_pt"]
	check(last_pt.distance_to(foe1.global_position) > 40.0,
		"sin linea de tiro la mira va a la ULTIMA posicion conocida, no a la viva")

	# ---- 12) Impacto recibido: la sacudida frena el giro
	# Misma mira inicial fija: solo cambia la sacudida — el error residual
	# tras un tick mide directamente la velocidad de correccion.
	foe1.global_position = Vector3(0, 0, 30)
	var b7 := _mk_bot(p1)
	mgr._bot_aim_st(b7)
	b7["_aim"]["dir"] = Vector3(1.0, 0.0, 0.0)
	b7["_aim"]["shock"] = 1.5
	var b8 := _mk_bot(p1)
	mgr._bot_aim_st(b8)
	b8["_aim"]["dir"] = Vector3(1.0, 0.0, 0.0)
	seed(201)
	var err7 := mgr._bot_aim_tick(b7, foe1, 20.0, true, 0.016, "m4")
	seed(201)
	var err8 := mgr._bot_aim_tick(b8, foe1, 20.0, true, 0.016, "m4")
	check(err7 > err8, "recibir un impacto frena la correccion de la mira (%.2f vs %.2f deg)" % [err7, err8])
	# 14) El retroceso se recupera con el tiempo
	b8["_aim"]["rp"] = 0.12
	for i in 40:
		mgr._bot_aim_decay(b8, 0.05)
	check(float(b8["_aim"]["rp"]) < 0.005, "el retroceso decae hasta cero en reposo")

	# ---- 15) Proyectil fisico real: la capsula del proxy recibe el impacto
	var victim := Node3D.new()
	victim.set_meta("peer_id", 777)
	victim.set_meta("proxy_health", 100.0)
	victim.set_meta("proxy_dead", false)
	victim.add_to_group("net_player_proxy")
	arena.add_child(victim)
	victim.global_position = Vector3(0, 0, 15)
	var shooter := Node3D.new()
	arena.add_child(shooter)
	await process_frame
	var b9 := _mk_bot(shooter)
	var dir_hit := ((victim.global_position + Vector3(0, 0.9, 0)) - Vector3(0, 1.4, 0)).normalized()
	mgr._bot_launch_projectile(b9, Vector3(0, 1.4, 0), dir_hit, "Fusil de asalto", 400.0, 150.0, 30.0, false, "rifle", 0.12, Vector3.ZERO)
	for i in 20:
		await physics_frame
	check(float(victim.get_meta("proxy_health", 100.0)) < 100.0,
		"el proyectil fisico hiere al proxy sin cuerpo fisico (hp=%.0f)" % float(victim.get_meta("proxy_health", 100.0)))
	# Y un tiro al aire no hiere a nadie
	var victim2 := Node3D.new()
	victim2.set_meta("peer_id", 778)
	victim2.set_meta("proxy_health", 100.0)
	victim2.set_meta("proxy_dead", false)
	victim2.add_to_group("net_player_proxy")
	arena.add_child(victim2)
	victim2.global_position = Vector3(3, 0, 15)
	await process_frame
	mgr._bot_launch_projectile(b9, Vector3(0, 1.4, 0), Vector3(0, 0, -1), "Fusil de asalto", 400.0, 150.0, 30.0, false, "rifle", 0.12, Vector3.ZERO)
	for i in 20:
		await physics_frame
	check(float(victim2.get_meta("proxy_health", 100.0)) == 100.0,
		"la bala que no intersecta no hace daño (antes acertaba por randf)")

	# ---- Dispersion estadistica a 10/30/50 m: error angular * distancia
	var p5 := _mk_proxy([], {})
	arena.add_child(p5)
	var b10 := _mk_bot(p5)
	b10["is_aiming"] = true
	for i in 30:
		mgr._bot_aim_tick(b10, foe1, 30.0, true, 0.05, "m4")
	for dist in [10.0, 30.0, 50.0]:
		var worst := 0.0
		for i in 40:
			var d := mgr._bot_aim_fire_dir(b10, "m4", mgr._bot_current_spread_deg(b10, true))
			var err := rad_to_deg(Vector3(b10["_aim"]["dir"]).angle_to(d))
			worst = maxf(worst, err)
		var dev: float = tan(deg_to_rad(worst)) * dist
		check(dev < dist * 0.06, "dispersion acotada a %.0f m (peor %.2f m)" % [dist, dev])

	await _check_night_aim(mgr, arena)
	print("BotAimRecoilRegression failures=%d" % failures)
	quit(1 if failures > 0 else 0)
