extends SceneTree

const SBM = preload("res://scripts/SurvivorBotManager.gd")

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("  PASS  %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)

func _make_proxy(inv: Array, rifle_ammo := {}) -> Node3D:
	var p := Node3D.new()
	p.set_meta("saved_inventory", inv)
	if not rifle_ammo.is_empty():
		p.set_meta("saved_extra", {"rifle_ammo": rifle_ammo})
	root.add_child(p)
	return p

class StubWildlife extends Node3D:
	var _is_dead := false
	var hits := 0
	func take_damage(_d, _a, _b) -> void:
		hits += 1

func _initialize() -> void:
	print("=== BotGunAmmoRegression ===")
	await process_frame
	var mgr: SurvivorBotManager = SBM.new()
	root.add_child(mgr)

	# --- Siembra desde saved_extra.rifle_ammo (mismo schema que el spawn) ---
	var p1 := _make_proxy(
		[{"name": "Fusil de asalto", "type": "weapon", "quantity": 1}],
		{"m4_magazine": 30, "m4_reserve": 90, "magazine": 5, "reserve": 20})
	var ammo := mgr._bot_gun_ammo(p1)
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 30, "M4 sembrado cargador 30")
	check(mgr._bot_gun_reserve(ammo, "Fusil de asalto") == 90, "M4 sembrado reserva 90")
	check(mgr._bot_gun_loaded(ammo, "Rifle francotirador") == 5, "Sniper sembrado cargador 5")

	# --- Disparo consume bala a bala ---
	var b := {"proxy": p1, "shoot_cooldown": 0.0}
	for i in 30:
		check(mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "M4 tiro %d sale" % (i + 1))
	ammo = mgr._bot_gun_ammo(p1)
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 0, "M4 cargador agotado tras 30 tiros")

	# --- Cargador vacio + reserva: recarga (no dispara) y tarda como el jugador ---
	check(not mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "M4 con cargador 0 no dispara (recarga)")
	check(float(b["shoot_cooldown"]) == SBM.BOT_GUN_RELOAD_TIME, "M4 recarga cuesta %.1f s" % SBM.BOT_GUN_RELOAD_TIME)
	ammo = mgr._bot_gun_ammo(p1)
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 30 and mgr._bot_gun_reserve(ammo, "Fusil de asalto") == 60,
		"M4 recarga mueve 30 de reserva (60 quedan)")
	b["shoot_cooldown"] = 0.0
	check(mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "M4 dispara tras la recarga")
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p1), "Fusil de asalto") == 29, "M4 post-recarga descuenta del cargador")

	# --- Sin reserva pero con item de municion del calibre: lo convierte ---
	ammo = mgr._bot_gun_ammo(p1)
	ammo["m4_magazine"] = 0
	ammo["m4_reserve"] = 0
	mgr._bot_gun_ammo_save(p1, ammo)
	var inv: Array = p1.get_meta("saved_inventory", [])
	inv.append({"name": "Balas 5,56", "type": "ammo", "quantity": 2, "use_value": 30})
	p1.set_meta("saved_inventory", inv)
	check(not mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "M4 seco+item: recarga, no dispara")
	ammo = mgr._bot_gun_ammo(p1)
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 30 and mgr._bot_gun_reserve(ammo, "Fusil de asalto") == 0,
		"M4 item 5,56 -> reserva -> cargador")
	inv = p1.get_meta("saved_inventory", [])
	check(inv.size() == 2 and int(inv[1].get("quantity", 0)) == 1, "M4 consumio un item de municion")

	# --- Item de calibre equivocado no alimenta el M4 ---
	ammo = mgr._bot_gun_ammo(p1)
	ammo["m4_magazine"] = 0
	ammo["m4_reserve"] = 0
	mgr._bot_gun_ammo_save(p1, ammo)
	inv = p1.get_meta("saved_inventory", [])
	inv.append({"name": "Cargador de fusil", "type": "ammo", "quantity": 5})
	p1.set_meta("saved_inventory", inv)
	# La "Balas 5,56" restante (qty 1) SI alimenta: la quitamos para el test de seco.
	inv.remove_at(1)
	p1.set_meta("saved_inventory", inv)
	check(not mgr._bot_gun_any_ammo(p1, "Fusil de asalto"), "M4 seco: Cargador de fusil (7.62) no cuenta")
	check(not mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "M4 totalmente seco no dispara")
	check(mgr._bot_gun_any_ammo(p1, "Rifle francotirador"), "Sniper si ve su item 7.62")
	inv = p1.get_meta("saved_inventory", [])
	check(inv.size() == 2 and str(inv[1].get("name", "")) == "Cargador de fusil",
		"Item 7.62 intacto tras intento de M4")

	# --- Sniper: mismo ciclo con su calibre ---
	var p2 := _make_proxy(
		[{"name": "Rifle francotirador", "type": "weapon", "quantity": 1},
		 {"name": "Cargador de fusil", "type": "ammo", "quantity": 1, "use_value": 7}],
		{"m4_magazine": 30, "m4_reserve": 90, "magazine": 5, "reserve": 0})
	var b2 := {"proxy": p2, "shoot_cooldown": 0.0}
	for i in 5:
		mgr._bot_gun_prepare_shot(b2, "Rifle francotirador")
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p2), "Rifle francotirador") == 0, "Sniper cargador 0 tras 5 tiros")
	check(not mgr._bot_gun_prepare_shot(b2, "Rifle francotirador"), "Sniper seco convierte item y recarga")
	ammo = mgr._bot_gun_ammo(p2)
	check(mgr._bot_gun_loaded(ammo, "Rifle francotirador") == 5 and mgr._bot_gun_reserve(ammo, "Rifle francotirador") == 2,
		"Sniper cargo 5, reserva queda 2 (use_value=7)")
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 30, "M4 intocable por la recarga del sniper")

	# --- Seleccion de arma respeta la municion ---
	var p3 := _make_proxy([
		{"name": "Fusil de asalto", "type": "weapon", "quantity": 1},
		{"name": "Cuchillo", "type": "tool", "quantity": 1}],
		{"m4_magazine": 0, "m4_reserve": 0, "magazine": 5, "reserve": 20})
	var b3 := {"proxy": p3}
	var pick: Dictionary = mgr._pick_fight_weapon(b3, 10.0)
	check(str(pick.get("kind", "")) != "rifle", "pick_fight_weapon salta M4 seco")
	check(mgr._best_weapon_name(p3) == "Cuchillo", "best_weapon_name salta M4 seco")
	ammo = mgr._bot_gun_ammo(p3)
	ammo["m4_magazine"] = 5
	mgr._bot_gun_ammo_save(p3, ammo)
	check(mgr._best_weapon_name(p3) == "Fusil de asalto", "best_weapon_name recupera M4 con balas")
	pick = mgr._pick_fight_weapon(b3, 10.0)
	check(str(pick.get("kind", "")) == "rifle" and str(pick.get("name", "")) == "Fusil de asalto",
		"pick_fight_weapon recupera rifle con balas")

	# --- Persistencia: saved_extra.rifle_ammo refleja lo consumido ---
	var saved: Dictionary = (p3.get_meta("saved_extra", {}) as Dictionary).get("rifle_ammo", {})
	check(int(saved.get("m4_magazine", -1)) == 5, "saved_extra.rifle_ammo persiste m4_magazine")

	# --- Rafaga M4: hasta 3 balas reales por disparo (como el jugador) ---
	mgr.world = Node3D.new()  # stub: sin _net_player_shot_rifle ni net
	root.add_child(mgr.world)
	var p4 := _make_proxy([{"name": "Fusil de asalto", "type": "weapon", "quantity": 1}],
		{"m4_magazine": 30, "m4_reserve": 90, "magazine": 5, "reserve": 20})
	var t4 := StubWildlife.new()
	t4.add_to_group("wildlife")
	root.add_child(t4)
	t4.global_position = Vector3(0, 0, 6)
	var b4 := {"proxy": p4, "bot_id": 901, "held_item": "Fusil de asalto", "health": 100.0, "shoot_cooldown": 0.0}
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	await create_timer(0.35).timeout
	var spent := 30 - mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto")
	check(spent == 3, "M4 rafaga consume 3 balas (%d)" % spent)

	# Rafaga corta: el cargador manda (2 balas -> 2 proyectiles, no 3)
	var ammo4 := mgr._bot_gun_ammo(p4)
	ammo4["m4_magazine"] = 2
	mgr._bot_gun_ammo_save(p4, ammo4)
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	await create_timer(0.35).timeout
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto") == 0,
		"M4 rafaga corta: cargador 2 -> 0 (no inventa la 3a)")

	# Monotiro del francotirador: 1 bala por disparo
	var p5 := _make_proxy([{"name": "Rifle francotirador", "type": "weapon", "quantity": 1}],
		{"m4_magazine": 30, "m4_reserve": 90, "magazine": 5, "reserve": 10})
	var t5 := StubWildlife.new()
	t5.add_to_group("wildlife")
	root.add_child(t5)
	t5.global_position = Vector3(50, 0, 6)
	var b5 := {"proxy": p5, "bot_id": 902, "held_item": "Rifle francotirador", "health": 100.0, "shoot_cooldown": 0.0}
	mgr._bot_fire_rifle_at(b5, t5, 40.0, "Rifle francotirador")
	await create_timer(0.35).timeout
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p5), "Rifle francotirador") == 4,
		"Sniper monotiro consume 1 bala")

	# Mientras recarga no puede disparar (ni rafaga ni monotiro)
	ammo4 = mgr._bot_gun_ammo(p4)
	ammo4["m4_magazine"] = 0
	ammo4["m4_reserve"] = 30
	mgr._bot_gun_ammo_save(p4, ammo4)
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	check(bool(b4.get("gun_reloading", false)), "recarga marca gun_reloading")
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto") == 30,
		"recarga llena el cargador sin disparar")
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	await create_timer(0.35).timeout
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto") == 30,
		"durante gun_reloading no sale ni una bala")
	b4["gun_reloading"] = false
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	await create_timer(0.35).timeout
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto") == 27,
		"tras la recarga la rafaga vuelve (30->27)")

	p1.free(); p2.free(); p3.free(); p4.free(); p5.free(); t4.free(); t5.free()
	mgr.world.free()
	mgr.free()
	if failures == 0:
		print("BotGunAmmoRegression: ALL PASS")
	else:
		print("BotGunAmmoRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
