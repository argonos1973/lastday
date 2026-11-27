extends SceneTree

const SBM = preload("res://scripts/SurvivorBotManager.gd")

var failures := 0
var checks := 0

func check(cond: bool, label: String) -> void:
	checks += 1
	if cond:
		print("  PASS  %s" % label)
	else:
		failures += 1
		print("  FAIL  %s" % label)

func _make_proxy(inv: Array, rifle_ammo := {}) -> Node3D:
	var p := Node3D.new()
	p.set_meta("is_ai_bot", true)
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

class TestWorld extends "res://scripts/Main.gd":
	var shots := 0
	func _ready() -> void: pass
	func _process(_d: float) -> void: pass
	func _physics_process(_d: float) -> void: pass
	func _save_world_change_silent() -> void: pass
	func _save_server_world() -> void: pass
	func _net_player_shot_rifle(_id: int, _pos: Vector3, _dir: Vector3, _wind: Vector3 = Vector3.ZERO) -> void:
		shots += 1
	func _net_player_hit_event(_id: int, _kind: String, _pos: Vector3) -> void: pass

class TestPlayer extends "res://scripts/PlayerController.gd":
	var test_item
	func _ready() -> void: pass
	func _process(_d: float) -> void: pass
	func _physics_process(_d: float) -> void: pass
	func get_held_item(): return test_item
	func _play_reload_sound() -> void: pass
	func _on_inventory_changed() -> void: pass
	func _on_stats_changed() -> void: pass

func _check_daily_firearms(mgr: SurvivorBotManager, template: Dictionary) -> void:
	var m4 := {"name":"Fusil de asalto", "type":"weapon_rifle", "quantity":1, "weight":3.1}
	var rifle := {"name":"Rifle francotirador", "type":"weapon", "quantity":1, "weight":4.0}
	var m4_ammo := {"name":"Cargador de M4", "type":"ammo", "quantity":1, "weight":0.45, "use_value":30.0}
	var rifle_ammo := {"name":"Cargador de fusil", "type":"ammo", "quantity":1, "weight":0.4, "use_value":5.0}
	var knife := {"name":"Cuchillo", "type":"weapon", "quantity":1, "weight":0.35}
	var p := _make_proxy([m4, rifle, m4_ammo, rifle_ammo, knife],
		{"initialized":true, "m4_initialized":true, "m4_magazine":30, "m4_reserve":0, "magazine":5, "reserve":0})
	var b := template.duplicate(true)
	b["proxy"] = p
	b["shelter_id"] = "daily_firearms"
	b["clothing"] = ""
	b["backpack"] = "Mochila militar"
	b["_mem"] = {}
	var sh := {"id":b.shelter_id, "pos":Vector3.ZERO, "contents":[]}
	mgr.world._built_shelters.append(sh)
	mgr._bot_sync_own_shelter_stash(b)
	check(_has_all(p, ["Fusil de asalto", "Rifle francotirador", "Cargador de M4", "Cargador de fusil"]),
		"equipo diario: conserva ambos fusiles y sus calibres cuando caben")
	check(mgr._bot_sync_own_shelter_stash(b) == 0, "equipo diario: la siguiente visita al alijo es estable")
	p.set_meta("saved_inventory", [m4.duplicate(true)])
	sh["contents"] = [rifle.duplicate(true), rifle_ammo.duplicate(true)]
	mgr._bot_sync_own_shelter_stash(b)
	check(_has_all(p, ["Fusil de asalto", "Rifle francotirador", "Cargador de fusil"]),
		"equipo diario: recupera el segundo fusil guardado si lo puede llevar")
	b["backpack"] = ""
	p.set_meta("saved_inventory", [m4.duplicate(true), m4_ammo.duplicate(true), knife.duplicate(true),
		{"name":"Venda", "type":"medical", "quantity":1, "weight":0.1}])
	sh["contents"] = []
	mgr._bot_sync_own_shelter_stash(b)
	check(_has_all(p, ["Fusil de asalto", "Cargador de M4"]) and mgr._bot_inv_stored_count(p.get_meta("saved_inventory")) <= 3,
		"equipo diario: ante tres huecos conserva el fusil y su municion antes que el cuchillo")
	p.set_meta("saved_inventory", [m4.duplicate(true), rifle.duplicate(true), m4_ammo.duplicate(true)])
	sh["contents"] = []
	mgr._bot_sync_own_shelter_stash(b)
	check(_has_all(p, ["Fusil de asalto", "Cargador de M4"]) and mgr._bot_item_count(p, "Rifle francotirador") == 0,
		"equipo diario: almacena el segundo fusil cuando los dos exceden el peso real")
	check(not mgr._own_shelter_has_needed_item(b),
		"equipo diario: un fusil secundario que no cabe no lo hace volver constantemente al refugio")
	p.set_meta("saved_inventory", [knife.duplicate(true), m4_ammo.duplicate(true),
		{"name":"Manzana", "type":"food", "quantity":1, "weight":0.2}])
	mgr._bot_gun_ammo_save(p, {"initialized":true, "m4_initialized":true,
		"m4_magazine":0, "m4_reserve":0, "magazine":0, "reserve":0})
	sh["contents"] = [m4.duplicate(true)]
	mgr._bot_sync_own_shelter_stash(b)
	check(_has_all(p, ["Fusil de asalto", "Cargador de M4"]) and mgr._bot_inv_stored_count(p.get_meta("saved_inventory")) <= 3,
		"equipo diario: hace sitio para recuperar el unico fusil sin guardar su unica municion")
	check(mgr._bot_gun_ammo(p).m4_magazine == 0 and mgr._bot_item_count(p, "Cargador de M4") == 1,
		"equipo diario: cambiar objetos con el alijo no inventa balas")
	var stable_inv: Array = p.get_meta("saved_inventory").duplicate(true)
	var stable_stash: Array = mgr._get_shelter_contents(b.shelter_id).duplicate(true)
	for repeat in 5:
		mgr._bot_sync_own_shelter_stash(b)
	check(p.get_meta("saved_inventory") == stable_inv and mgr._get_shelter_contents(b.shelter_id) == stable_stash,
		"equipo diario: el intercambio por capacidad no oscila en visitas repetidas")
	var duplicate_guns := m4.duplicate(true)
	duplicate_guns["quantity"] = 2
	p.set_meta("saved_inventory", [duplicate_guns, m4_ammo.duplicate(true)])
	sh["contents"] = []
	mgr._bot_sync_own_shelter_stash(b)
	check(mgr._bot_item_count(p, "Fusil de asalto") == 1 and mgr._bot_item_count(p, "Cargador de M4") == 1,
		"equipo diario: un duplicado apilado no expulsa la municion ni los dos fusiles")
	var broken := m4.duplicate(true)
	broken["durability"] = 0.0
	p.set_meta("saved_inventory", [broken, knife.duplicate(true), m4_ammo.duplicate(true)])
	sh["contents"] = [m4.duplicate(true)]
	mgr._bot_sync_own_shelter_stash(b)
	check(mgr._best_weapon_name(p) == "Fusil de asalto" and mgr._bot_item_count(p, "Cargador de M4") == 1,
		"equipo diario: reemplaza el fusil roto por el util del alijo")
	for i in range(mgr.world._built_shelters.size() - 1, -1, -1):
		if str(mgr.world._built_shelters[i].get("id", "")) == b.shelter_id:
			mgr.world._built_shelters.remove_at(i)
	p.free()

func _has_all(proxy: Node3D, names: Array) -> bool:
	for item_name in names:
		var found := false
		for item in proxy.get_meta("saved_inventory", []):
			if item is Dictionary and item.get("name") == item_name and int(item.get("quantity", 1)) > 0:
				found = true
		if not found:
			return false
	return true

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
	var b := {"proxy": p1, "held_item": "Fusil de asalto", "shoot_cooldown": 0.0}
	for i in 30:
		check(mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "M4 tiro %d sale" % (i + 1))
	ammo = mgr._bot_gun_ammo(p1)
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 0, "M4 cargador agotado tras 30 tiros")

	# --- Cargador vacio + reserva: recarga (no dispara) y tarda como el jugador ---
	check(not mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "M4 con cargador 0 no dispara (recarga)")
	check(float(b["shoot_cooldown"]) == SBM.BOT_GUN_RELOAD_TIME, "M4 recarga cuesta %.1f s" % SBM.BOT_GUN_RELOAD_TIME)
	ammo = mgr._bot_gun_ammo(p1)
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 0 and mgr._bot_gun_reserve(ammo, "Fusil de asalto") == 90,
		"M4 no adelanta las balas al iniciar la recarga")
	mgr._bot_tick_gun_reload(b, SBM.BOT_GUN_RELOAD_TIME - 0.01)
	check(not mgr._bot_gun_prepare_shot(b, "Fusil de asalto") and int(ammo["m4_magazine"]) == 0,
		"M4 sigue vacio y no dispara antes de completar la recarga")
	mgr._bot_tick_gun_reload(b, 0.02)
	ammo = mgr._bot_gun_ammo(p1)
	check(mgr._bot_gun_loaded(ammo, "Fusil de asalto") == 30 and mgr._bot_gun_reserve(ammo, "Fusil de asalto") == 60,
		"M4 recarga mueve 30 de reserva (60 quedan)")
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
	mgr._bot_tick_gun_reload(b, SBM.BOT_GUN_RELOAD_TIME)
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
	var b2 := {"proxy": p2, "held_item": "Rifle francotirador", "shoot_cooldown": 0.0}
	for i in 5:
		mgr._bot_gun_prepare_shot(b2, "Rifle francotirador")
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p2), "Rifle francotirador") == 0, "Sniper cargador 0 tras 5 tiros")
	check(not mgr._bot_gun_prepare_shot(b2, "Rifle francotirador"), "Sniper seco convierte item y recarga")
	mgr._bot_tick_gun_reload(b2, SBM.BOT_GUN_RELOAD_TIME)
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

	# --- Ventaja de combate: exige municion real ---
	var pk := _make_proxy([
		{"name": "Fusil de asalto", "type": "weapon", "quantity": 1},
		{"name": "Cuchillo", "type": "tool", "quantity": 1}],
		{"m4_magazine": 0, "m4_reserve": 0, "magazine": 0, "reserve": 0})
	var foe_k := Node3D.new()
	root.add_child(foe_k)
	foe_k.position = Vector3(0, 0, 30)
	foe_k.set_meta("saved_held_item", "Fusil de asalto")
	# has_rifle=true a proposito: lleva el fusil EN LA MANO, pero vacio.
	var bk := {"proxy": pk, "health": 35.0, "has_rifle": true}
	check(mgr._bot_gun_ammo_state(pk, "Fusil de asalto") == "empty", "estado de municion: fusil seco = empty")
	check(mgr._bot_usable_gun(pk).is_empty(), "fusil sin balas no es un arma de fuego utilizable")
	check(not mgr._bot_has_ranged_weapon(pk), "fusil seco no cuenta como arma a distancia")
	check(not mgr._has_combat_edge(bk, foe_k), "Kael 35 hp + fusil descargado vs enemigo armado: SIN ventaja tactica")
	check(str(mgr._pick_fight_weapon(bk, 30.0).get("name", "")) == "Cuchillo", "con el fusil seco valora el arma alternativa")
	var ammo_k: Dictionary = mgr._bot_gun_ammo(pk)
	ammo_k["m4_reserve"] = 30
	mgr._bot_gun_ammo_save(pk, ammo_k)
	check(mgr._bot_gun_ammo_state(pk, "Fusil de asalto") == "reserve", "estado de municion: solo reserva = reserve (hay que recargar)")
	foe_k.position = Vector3(0, 0, 18)
	check(not mgr._has_combat_edge(bk, foe_k), "cargador vacio + enemigo a 18 m: la recarga de 2.2 s no da ventaja")
	foe_k.position = Vector3(0, 0, 40)
	check(mgr._has_combat_edge(bk, foe_k), "cargador vacio pero enemigo a 40 m: hay margen para recargar")
	ammo_k["m4_magazine"] = 12
	mgr._bot_gun_ammo_save(pk, ammo_k)
	foe_k.position = Vector3(0, 0, 18)
	check(mgr._bot_gun_ammo_state(pk, "Fusil de asalto") == "loaded" and mgr._has_combat_edge(bk, foe_k),
		"con balas en el cargador la ventaja a distancia vuelve")
	bk["health"] = 15.0
	check(not mgr._has_combat_edge(bk, foe_k), "moribundo (<20 hp) no hay ventaja ni con el cargador lleno")
	foe_k.free()
	pk.free()

	# --- Persistencia: saved_extra.rifle_ammo refleja lo consumido ---
	var saved: Dictionary = (p3.get_meta("saved_extra", {}) as Dictionary).get("rifle_ammo", {})
	check(int(saved.get("m4_magazine", -1)) == 5, "saved_extra.rifle_ammo persiste m4_magazine")

	# --- Rafaga M4: hasta 3 balas reales por disparo (como el jugador) ---
	mgr.world = TestWorld.new()
	root.add_child(mgr.world)
	mgr.world.survivor_bot_mgr = mgr
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
	check(mgr.world.shots == 3, "M4 comunica exactamente tres proyectiles")

	# Rafaga corta: el cargador manda (2 balas -> 2 proyectiles, no 3)
	var ammo4 := mgr._bot_gun_ammo(p4)
	ammo4["m4_magazine"] = 2
	mgr._bot_gun_ammo_save(p4, ammo4)
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	await create_timer(0.35).timeout
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto") == 0,
		"M4 rafaga corta: cargador 2 -> 0 (no inventa la 3a)")
	check(mgr.world.shots == 5, "dos balas restantes producen solo dos proyectiles")

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
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto") == 0,
		"recarga deja el cargador vacio hasta terminar")
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	await create_timer(0.35).timeout
	check(mgr.world.shots == 6,
		"durante gun_reloading no sale ni una bala")
	mgr._bot_tick_gun_reload(b4, SBM.BOT_GUN_RELOAD_TIME)
	mgr._bot_fire_rifle_at(b4, t4, 20.0, "Fusil de asalto")
	await create_timer(0.35).timeout
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(p4), "Fusil de asalto") == 27,
		"tras la recarga la rafaga vuelve (30->27)")

	await _verify_pickup_and_parity(mgr)
	await _verify_reload_interruptions(mgr, p4, t4, b4)
	_verify_vest_pickups(mgr)
	p1.free(); p2.free(); p3.free(); p4.free(); p5.free(); t4.free(); t5.free()
	mgr.world.free()
	mgr.free()
	if failures == 0:
		print("BotGunAmmoRegression: ALL PASS (%d checks)" % checks)
	else:
		print("BotGunAmmoRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)

func _verify_pickup_and_parity(mgr: SurvivorBotManager) -> void:
	var actor := TestPlayer.new()
	root.add_child(actor)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.inventory.max_slots = 30
	actor.inventory.max_weight = 100.0
	actor.stats = SurvivalStats.new()
	var p := _make_proxy([])
	var initial: Dictionary = mgr._bot_gun_ammo(p)
	check(int(initial.m4_magazine) + int(initial.m4_reserve) + int(initial.magazine) + int(initial.reserve) == 0,
		"bot sin fusiles no tiene reservas ocultas al nacer")
	p.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "quantity": 1}])
	var gun = preload("res://scripts/Item.gd").create("Fusil de asalto", "weapon_rifle", 3.1, 1, 0.0)
	actor.test_item = gun
	actor._initialize_rifle_ammo()
	initial = mgr._bot_gun_ammo(p)
	check(int(initial.m4_magazine) == actor._m4_magazine and int(initial.m4_reserve) == actor._m4_reserve_ammo,
		"M4 empieza con la misma dotacion unica que el humano")
	actor.test_item = preload("res://scripts/Item.gd").create("Rifle francotirador", "weapon_rifle", 4.0, 1, 0.0)
	actor._initialize_rifle_ammo()
	(p.get_meta("saved_inventory") as Array).append({"name": "Rifle francotirador", "type": "weapon_rifle", "quantity": 1})
	initial = mgr._bot_gun_ammo(p)
	check(int(initial.magazine) == actor._rifle_magazine and int(initial.reserve) == actor._rifle_reserve_ammo,
		"Sniper empieza con la misma dotacion que el humano (sin cargador extra)")
	var b := {"proxy": p, "bot_id": 903, "held_item": "Fusil de asalto", "has_rifle": true,
		"health": 100.0, "hunger": 100.0, "thirst": 100.0, "clothing": "", "backpack": "Mochila militar",
		"torch_lit": false, "shoot_cooldown": 0.0, "shelter_id": "", "campfire_id": ""}
	_check_daily_firearms(mgr, b)
	mgr._bot_gun_ammo_save(p, {"m4_magazine": 0, "m4_reserve": 0, "magazine": 0, "reserve": 0})
	p.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "quantity": 1}])
	# World pickup -> inventory -> reserve -> timed reload -> spent rounds.
	var loot := {"id": "ammo_cycle", "name": "Balas 5,56", "type": "ammo", "qty": 2, "use": 7.0,
		"weight": 0.2, "pos": [1.0, 0.0, 0.0]}
	mgr.world._dropped_items.append(loot)
	check(mgr._find_nearby_valuable_loot(b, 10.0).get("id", "") == "ammo_cycle", "el bot detecta la municion real cercana")
	p.position = Vector3(8, 0, 0)
	mgr._collect_loot_entry(b, loot)
	check(mgr._bot_item_count(p, "Balas 5,56") == 0 and mgr.world._dropped_items.has(loot), "no recoge municion a distancia")
	p.position = Vector3.ZERO
	b["backpack"] = ""
	p.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "quantity": 1, "weight": 5.0}])
	mgr._collect_loot_entry(b, loot)
	check(mgr._bot_item_count(p, "Balas 5,56") == 0 and mgr.world._dropped_items.has(loot),
		"la municion que excede el peso permitido permanece en el mundo")
	b["backpack"] = "Mochila militar"
	mgr._collect_loot_entry(b, loot)
	check(mgr._bot_item_count(p, "Balas 5,56") == 2 and mgr.world._depleted_action_ids.has("ammo_cycle")
		and not mgr.world._dropped_items.has(loot), "recoge dos paquetes y desaparecen del mundo")
	mgr._collect_loot_entry(b, loot)
	check(mgr._bot_item_count(p, "Balas 5,56") == 2, "un snapshot atrasado no duplica municion")
	var partition: Dictionary = mgr._bot_partition_inventory_for_shelter(b, p.get_meta("saved_inventory"))
	check((partition.keep as Array).any(func(it): return it.get("name") == "Balas 5,56"),
		"el alijo conserva municion 5,56 util aunque el nombre use coma")
	# Retirar municion del refugio no debe volver a guardarla por su alias.
	mgr.world._built_shelters.append({"id": "ammo_stash", "pos": Vector3.ZERO,
		"contents": [{"name": "Municion de asalto", "type": "ammo", "quantity": 1, "use_value": 30.0}]})
	b["shelter_id"] = "ammo_stash"
	check(mgr._bot_sync_own_shelter_stash(b) > 0 and mgr._bot_item_count(p, "Municion de asalto") == 1
		and mgr._get_shelter_contents("ammo_stash").is_empty(), "retira del refugio la municion de su calibre y se la queda")
	# Restore the two-package scenario after checking shelter transfer.
	p.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "quantity": 1},
		{"name": "Balas 5,56", "type": "ammo", "quantity": 2, "use_value": 7.0}])
	check(not mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "el paquete recogido inicia recarga, no dispara")
	check(mgr._bot_item_count(p, "Balas 5,56") == 1 and int(mgr._bot_gun_ammo(p).m4_reserve) == 7,
		"consume un paquete y respeta use_value=7")
	mgr._bot_tick_gun_reload(b, SBM.BOT_GUN_RELOAD_TIME)
	for i in 7:
		check(mgr._bot_gun_prepare_shot(b, "Fusil de asalto"), "bala recogida %d sale" % (i + 1))
	check(int(mgr._bot_gun_ammo(p).m4_magazine) == 0, "solo salen las siete balas del primer paquete")
	var restored := _make_proxy((p.get_meta("saved_inventory") as Array).duplicate(true),
		(p.get_meta("saved_extra") as Dictionary).rifle_ammo.duplicate(true))
	check(int(mgr._bot_gun_ammo(restored).m4_magazine) == 0 and int(mgr._bot_gun_ammo(restored).m4_reserve) == 0,
		"recrear el proxy conserva el agotamiento sin regalar municion")
	restored.free()
	# All accepted ammo aliases and quantities go through the real player use.
	for nm in ["Cargador de M4", "Balas 5.56", "Balas 5,56", "Municion de asalto", "Cargador de fusil", "Caja de balas"]:
		var weapon := "Fusil de asalto" if PlayerController.ammo_item_is_m4(nm) else "Rifle francotirador"
		for value in [0.0, 7.0]:
			actor._m4_reserve_ammo = 0
			actor._rifle_reserve_ammo = 0
			actor.inventory.items.clear()
			var item = preload("res://scripts/Item.gd").create(nm, "ammo", 0.2, 2, value)
			actor.inventory.items.append(item)
			actor._load_ammo_item(item, 0)
			p.set_meta("saved_inventory", [{"name": nm, "type": "ammo", "quantity": 2, "use_value": value}])
			var ammo := {"m4_magazine": 0, "m4_reserve": 0, "magazine": 0, "reserve": 0}
			mgr._bot_gun_load_ammo_item(p, ammo, weapon)
			check(int(ammo.m4_reserve) == actor._m4_reserve_ammo and int(ammo.reserve) == actor._rifle_reserve_ammo
				and mgr._bot_item_count(p, nm) == item.quantity, "humano y bot convierten igual %s (use=%.0f)" % [nm, value])
	# Reload parity while both clocks run: no early credit, same final totals.
	p.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon_rifle", "quantity": 1}])
	mgr._bot_gun_ammo_save(p, {"m4_magazine": 5, "m4_reserve": 11, "magazine": 0, "reserve": 0})
	actor.test_item = gun
	actor._m4_magazine = 5
	actor._m4_reserve_ammo = 11
	actor._reload_rifle()
	mgr._bot_start_gun_reload(b, "Fusil de asalto")
	check(actor._m4_magazine == 5 and int(mgr._bot_gun_ammo(p).m4_magazine) == 5,
		"ambos conservan el cargador parcial mientras recargan")
	for posture in ["crouching", "sitting", "prone"]:
		var visual := {"anim": "idle", "held_item": "Fusil de asalto", "has_rifle": true, "gun_reloading": true}
		visual[posture] = true
		check(mgr._bot_effective_net_anim(visual) == "reload", "recarga visible en " + posture)
	check(mgr._bot_effective_net_anim({"anim": "idle", "_throw_pending": {}}) == "throw", "preparacion de lanza usa el gesto de lanzamiento")
	await create_timer(GameConst.GUN_RELOAD_TIME + 0.05).timeout
	mgr._bot_tick_gun_reload(b, GameConst.GUN_RELOAD_TIME)
	check(actor._m4_magazine == 16 and int(mgr._bot_gun_ammo(p).m4_magazine) == actor._m4_magazine
		and int(mgr._bot_gun_ammo(p).m4_reserve) == actor._m4_reserve_ammo, "ambos terminan con 16 balas y cero reserva")
	actor.inventory.free()
	actor.stats.free()
	actor.free()
	p.free()

func _verify_reload_interruptions(mgr: SurvivorBotManager, proxy: Node3D, target: Node3D, b: Dictionary) -> void:
	for cause in ["weapon", "movement", "death", "damage"]:
		mgr._bot_gun_ammo_save(proxy, {"m4_magazine": 0, "m4_reserve": 11, "magazine": 0, "reserve": 0})
		b["held_item"] = "Fusil de asalto"
		b["health"] = 100.0
		b["anim"] = "idle"
		b["energy"] = 0.0
		proxy.set_meta("proxy_dead", false)
		var shots_before := int(mgr.world.shots)
		mgr._bot_fire_rifle_at(b, target, 20.0, "Fusil de asalto")
		check(bool(b.get("gun_reloading", false)) and float(b.energy) == 0.0, "recarga sin pagar energia de disparo (%s)" % cause)
		mgr._bot_tick_gun_reload(b, 1.0)
		match cause:
			"weapon": b["held_item"] = "Cuchillo"
			"movement": proxy.position.x += 1.0
			"death": proxy.set_meta("proxy_dead", true)
			"damage":
				mgr.bots[int(b.bot_id)] = b
				b["team_leader_id"] = 0
				mgr.on_bot_damaged(int(b.bot_id), 1.0, 0, "melee")
				mgr.bots.erase(int(b.bot_id))
		mgr._bot_tick_gun_reload(b, 2.0)
		var ammo: Dictionary = mgr._bot_gun_ammo(proxy)
		check(not bool(b.gun_reloading) and int(ammo.m4_magazine) == 0 and int(ammo.m4_reserve) == 11,
			"%s cancela la recarga sin transferir ni perder balas" % cause)
		check(int(mgr.world.shots) == shots_before, "recarga interrumpida no lanza proyectiles (%s)" % cause)
	proxy.set_meta("proxy_dead", false)
	b["held_item"] = "Fusil de asalto"
	b["health"] = 100.0
	b["energy"] = 100.0
	mgr._bot_start_gun_reload(b, "Fusil de asalto")
	mgr._bot_tick_gun_reload(b, 1.0)
	check(int(mgr._bot_gun_ammo(proxy).m4_magazine) == 0, "reanudar exige otra recarga completa")
	mgr._bot_tick_gun_reload(b, GameConst.GUN_RELOAD_TIME)
	check(int(mgr._bot_gun_ammo(proxy).m4_magazine) == 11, "reanudar carga solo las once balas disponibles")
	# Death stops pending rounds even before the ordinary bot tick notices it.
	var start_shots := int(mgr.world.shots)
	mgr._bot_fire_rifle_at(b, target, 20.0, "Fusil de asalto")
	proxy.set_meta("proxy_dead", true)
	await create_timer(0.25).timeout
	check(int(mgr.world.shots) == start_shots + 1 and int(mgr._bot_gun_ammo(proxy).m4_magazine) == 10,
		"muerte del proxy cancela las balas pendientes de la rafaga")
	proxy.set_meta("proxy_dead", false)
	# A cancelled reload must not revive callbacks from the previous burst.
	mgr._bot_gun_ammo_save(proxy, {"m4_magazine": 5, "m4_reserve": 10, "magazine": 0, "reserve": 0})
	start_shots = int(mgr.world.shots)
	mgr._bot_fire_rifle_at(b, target, 20.0, "Fusil de asalto")
	check(mgr._bot_start_gun_reload(b, "Fusil de asalto"), "recarga interrumpe rafaga en curso")
	mgr._bot_cancel_gun_reload(b)
	await create_timer(0.25).timeout
	check(int(mgr.world.shots) == start_shots + 1 and int(mgr._bot_gun_ammo(proxy).m4_magazine) == 4,
		"cancelar la recarga no resucita las balas pendientes de la rafaga anterior")

func _verify_vest_pickups(mgr: SurvivorBotManager) -> void:
	var p := _make_proxy([])
	var b := {"proxy": p, "bot_id": 904, "held_item": "", "has_rifle": false, "health": 100.0,
		"hunger": 100.0, "thirst": 100.0, "clothing": "", "backpack": "Mochila militar", "torch_lit": false}
	for dropped in [false, true]:
		b["clothing"] = ""
		p.set_meta("saved_inventory", [])
		p.set_meta("saved_clothing", "")
		var id := "vest_ammo_%s" % dropped
		var action := preload("res://scripts/WorldAction.gd").new()
		action.action_id = id
		mgr.world.add_child(action)
		action.position = Vector3(1, 0, 0)
		if dropped: action.set_meta("player_dropped", true)
		mgr.world.world_actions_by_id[id] = action
		var entry := {"id": id, "name": "Chaleco táctico", "type": "clothing", "qty": 1, "pos": [1.0, 0.0, 0.0]}
		mgr.world._dropped_items.append(entry)
		var before := int(mgr._bot_gun_ammo(p).reserve)
		mgr._collect_loot_entry(b, entry)
		var expected := before + (0 if dropped else GameConst.RIFLE_MAG_SIZE * 5)
		check(int(mgr._bot_gun_ammo(p).reserve) == expected and "Chaleco táctico" in str(b.clothing).split(","),
			"chaleco %s: mismas municiones que el humano" % ("soltado" if dropped else "del mundo"))
		mgr._collect_loot_entry(b, entry)
		check(int(mgr._bot_gun_ammo(p).reserve) == expected, "repetir recogida de chaleco no duplica balas")
		action.free()
		if not dropped:
			p.set_meta("saved_inventory", [{"name": "Rifle francotirador", "type": "weapon_rifle", "quantity": 1}])
			check(int(mgr._bot_gun_ammo(p).reserve) == 25, "primer fusil tras el chaleco conserva las 25 balas sin sumar otras 15")
	p.free()
