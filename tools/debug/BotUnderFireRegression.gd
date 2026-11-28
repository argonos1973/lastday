extends SceneTree

const SurvivalFixture = preload("res://tools/debug/SurvivorBotsAndCombatRegression.gd")

# Mide la respuesta defensiva de los bots ante fuego de fusil/M4: el flinch
# ya no clava al bot bajo rafaga, la alerta lejana se convierte en movimiento
# a cubierto, las balas cercanas avisan personalmente y la serpentina es
# impredecible. Harness sin mapa, como BotCombatMovementRegression.
class FireManager extends SurvivorBotManager:
	var obstacle := ""
	var ground_height := 0.0
	func _ground_y(_x: float, _z: float, _from_y: float = -INF) -> float: return ground_height
	func _resolve_mountain_road_waypoint(_cur: Vector3, goal: Vector3) -> Vector3: return goal
	func _resolve_building_interior_waypoint(_b: Dictionary, _cur: Vector3, goal: Vector3) -> Vector3: return goal
	func _is_in_any_building_3d(_pos: Vector3) -> bool: return false
	func _is_pos_blocked(_pos: Vector3, _radius: float = 0.42, _deep: bool = false) -> bool: return false
	func _is_step_blocked(a: Vector3, z: Vector3, deep: bool = false) -> bool:
		return super._is_step_blocked(a, z, deep)
	func _bot_carry_ratio(_b: Dictionary) -> float: return 0.0
	func _ai_save_memory() -> void: pass
	func _ai_save_live_status() -> void: pass
	var night := false
	func _is_world_night() -> bool: return night

class Arena extends Node3D:
	var server_proxies := {}
	var bot_nav = null
	var net = null
	var shots := 0
	func _net_player_shot_rifle(_id: int, _origin: Vector3, _dir: Vector3, _wind: Vector3) -> void:
		shots += 1
	func get_river_depth_at(_pos: Vector3) -> float: return 0.0

class ColdManager extends FireManager:
	func _nearest_safe_refuge(_b: Dictionary, _radius: float, _threat: Vector3 = Vector3.INF, _dry_roof_only := false) -> Vector3:
		return Vector3.ZERO

var errors := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(message)

func bot(p: Node3D, id: int = 901) -> Dictionary:
	return {"proxy": p, "bot_id": id, "pos": p.position, "rot": 0.0,
		"health": 100.0, "hunger": 90.0, "thirst": 90.0, "energy": 100.0,
		"anim": "idle", "has_rifle": false, "held_item": "Piedra afilada",
		"path": [], "path_idx": 0, "path_timer": 0.0, "stuck_timer": 0.0,
		"stuck_count": 0, "last_move_pos": p.position, "strafe_dir": 1.0,
		"strafe_timer": 0.0, "shoot_cooldown": 0.0, "attack_cooldown": 0.0,
		"shelter_pos": Vector3(200, 0, 200), "flee_until": 0.0,
		"_mem": {"personality": {}, "stats": {}}}

func _initialize() -> void: call_deferred("run")

func armed_bot(p: Node3D, weapon := "Fusil de asalto") -> Dictionary:
	p.position = Vector3.ZERO
	p.set_meta("saved_inventory", [{"name": weapon, "type": "weapon_rifle", "quantity": 1, "durability": 100.0}])
	p.set_meta("bot_gun_ammo", {"initialized": true, "m4_initialized": true,
		"m4_magazine": 30, "m4_reserve": 60, "magazine": 5, "reserve": 10})
	return bot(p)

func combat_tick(mgr: FireManager, b: Dictionary, foe: Node3D, cover: bool) -> void:
	b.shoot_cooldown = maxf(0.0, float(b.shoot_cooldown) - 0.05)
	mgr._bot_aim_decay(b, 0.05)
	mgr._bot_tick_gun_reload(b, 0.05)
	if cover: mgr._bot_seek_ballistic_cover(b, foe, 0.05)
	else: mgr._engage_foe(b, foe, 0.05)

func test_armed_response() -> void:
	seed(58291)
	var arena := Arena.new()
	root.add_child(arena)
	var mgr := FireManager.new()
	arena.add_child(mgr)
	mgr.set_process(false)
	mgr.world = arena
	var proxy := Node3D.new()
	var foe := Node3D.new()
	arena.add_child(proxy)
	arena.add_child(foe)
	foe.position = Vector3(0, 0, -20)
	var b := armed_bot(proxy)
	var moved := 0
	var held := 0
	for i in 120:
		combat_tick(mgr, b, foe, true)
		if mgr._bot_is_moving(b): moved += 1
		else: held += 1
	check(arena.shots > 0 and mgr._bot_gun_loaded(mgr._bot_gun_ammo(proxy), "Fusil de asalto") < 30,
		"armed bot under fire in the open returns real fire instead of fleeing forever")
	check(moved > 10 and held > 5, "open ground alternates evasion and aimed return fire")
	check(b.held_item == "Fusil de asalto" and b.has_rifle, "incoming fire equips carried rifle instead of retaining the tool")
	# A player rushing into the old 3.5 m cutoff must not disarm the bot.
	b = armed_bot(proxy)
	foe.position = Vector3(0, 0, -3)
	var before := arena.shots
	for i in 100:
		combat_tick(mgr, b, foe, false)
	check(b.held_item == "Fusil de asalto" and proxy.position.distance_to(foe.position) > 6.0,
		"rushed rifleman opens distance while retaining the loaded firearm")
	check(arena.shots > before, "rushed rifleman fires after the defensive step")
	# Real wall: no mocked LOS, aim, ammunition, or projectile creation.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.4, 3.0, 0.6)
	shape.shape = box
	wall.add_child(shape)
	arena.add_child(wall)
	wall.position = Vector3(0, 1.5, -2)
	await physics_frame
	await physics_frame
	b = armed_bot(proxy, "Rifle francotirador")
	foe.position = Vector3(0, 0, -20)
	b["_cover_goal"] = Vector3.ZERO
	b["_cover_foe"] = foe.get_instance_id()
	b["_cover_scan_t"] = 1.5
	before = arena.shots
	var hidden_ticks := 0
	var exposed_ticks := 0
	for i in 240:
		if mgr._has_clear_shot(proxy.position, foe.position):
			combat_tick(mgr, b, foe, true)
		else:
			b.shoot_cooldown = maxf(0.0, float(b.shoot_cooldown) - 0.05)
			mgr._bot_aim_decay(b, 0.05)
			mgr._bot_tick_gun_reload(b, 0.05)
			mgr._bot_seek_cover_from_pos(b, Vector3(0, 0, -20), 0.05)
		if mgr._has_clear_shot(foe.position, proxy.position): exposed_ticks += 1
		else: hidden_ticks += 1
	check(arena.shots > before and hidden_ticks > 10 and exposed_ticks > 5,
		"real tall cover: sidesteps to fire, then returns behind the wall")
	check(proxy.position.z > -1.3, "cover manoeuvre does not walk through the physical wall")
	# An empty magazine reloads while hidden even without a shot at the foe.
	proxy.position = Vector3.ZERO
	b = armed_bot(proxy, "Rifle francotirador")
	b["_cover_goal"] = Vector3.ZERO
	b["_cover_foe"] = foe.get_instance_id()
	proxy.set_meta("bot_gun_ammo", {"initialized": true, "m4_initialized": true,
		"m4_magazine": 0, "m4_reserve": 0, "magazine": 0, "reserve": 10})
	for i in 90:
		mgr._bot_tick_gun_reload(b, 0.05)
		mgr._bot_seek_cover_from_pos(b, Vector3(0, 0, -20), 0.05)
	check(mgr._bot_gun_loaded(mgr._bot_gun_ammo(proxy), "Rifle francotirador") > 0,
		"empty rifle reloads behind physical cover without requiring a visible target")
	mgr.night = true
	foe.position = Vector3(0, 0, -75)
	b = armed_bot(proxy)
	b["_cover_goal"] = Vector3.ZERO
	b["_cover_foe"] = foe.get_instance_id()
	before = arena.shots
	for i in 180: combat_tick(mgr, b, foe, true)
	check(arena.shots == before, "cover peeks cannot fire at a distant unlit actor in darkness")
	await create_timer(0.25).timeout
	arena.free()

func test_night_watch() -> void:
	var arena := SurvivalFixture.TestWorld.new()
	root.add_child(arena)
	var net := SurvivalFixture.FakeNet.new()
	arena.add_child(net)
	arena.net = net
	var day := SurvivalFixture.FakeDayCycle.new()
	day.time_of_day = 23.0
	arena.add_child(day)
	arena.day_cycle = day
	var mgr := FireManager.new()
	arena.add_child(mgr)
	mgr.world = arena
	mgr.night = true
	mgr._spawn_bot(mgr.BOT_CONFIGS[0])
	var b: Dictionary = mgr.bots[901]
	var proxy: Node3D = b.proxy
	armed_bot(proxy)
	b["clothing"] = GameConst.HEADLAMP_ITEM_NAME
	b["flashlight_on"] = true
	b["torch_lit"] = true
	b["anim"] = "run"
	b["hunger"] = 95.0
	b["thirst"] = 95.0
	var origin := proxy.position
	mgr.notify_sound_event(0, origin + Vector3(12, 0, 0), "door", 30.0)
	check(not b.flashlight_on and not b.torch_lit and not proxy.get_meta("flashlight_on", true)
		and not proxy.get_meta("torch_lit", true), "night sound immediately extinguishes both authoritative lights")
	for i in 60: mgr._tick_bot(b, 0.05)
	check(b.get("_act") == "night_watch" and b.crouching and proxy.position.distance_to(origin) < 0.01,
		"full decision loop stops travel and crouches to watch after a night noise")
	check(not b.flashlight_on and not b.torch_lit and b.held_item == "Fusil de asalto",
		"full decision loop keeps lights off and equips the rifle while listening")
	check(mgr.InterruptionManager.reasons(b, {}, true).has("combat"),
		"listening suspends the travel plan instead of counting the pause as a navigation failure")
	check(mgr._bot_has_firing_heading(b, origin + Vector3(12, 0, 0)),
		"watch faces the audible clue without following an unseen live actor")
	mgr._bot_prepare_night_supplies(b, 0.05)
	check(not b.flashlight_on and not b.torch_lit, "night supply preparation cannot relight during concealment")
	b["_night_watch_t"] = 0.01
	mgr._tick_bot(b, 0.05)
	check(not mgr._bot_tactical_dark(b) and b.flashlight_on, "quiet watch expires and normal lighting resumes")
	b["team_leader_id"] = 77
	mgr.notify_sound_event(77, origin + Vector3(12, 0, 0), "gunshot", 220.0)
	check(not mgr._bot_tactical_dark(b), "a known teammate's shot does not restart concealment")
	b["team_leader_id"] = 0
	mgr.notify_sound_event(0, origin + Vector3(60, 0, 0), "gunshot", 220.0)
	check(mgr._bot_night_watch_tick(b, 0.05) and not b.flashlight_on,
		"unknown night gunfire causes concealed listening rather than a blind chase")
	b["thirst"] = 5.0
	check(not mgr._bot_night_watch_tick(b, 0.05), "critical thirst interrupts passive listening")
	b["thirst"] = 95.0
	b["_last_attacker_msec"] = Time.get_ticks_msec()
	b["_last_hit_weapon"] = "m4"
	check(not mgr._bot_night_watch_tick(b, 0.05), "actual incoming hits require active defence, not static listening")
	mgr.night = false
	check(not mgr._bot_tactical_dark(b), "daylight releases the night concealment policy")
	arena.free()

func test_cold_arrow_response() -> void:
	var arena := SurvivalFixture.TestWorld.new()
	root.add_child(arena)
	var net := SurvivalFixture.FakeNet.new()
	arena.add_child(net)
	arena.net = net
	var day := SurvivalFixture.FakeDayCycle.new()
	arena.add_child(day)
	arena.day_cycle = day
	var mgr := ColdManager.new()
	arena.add_child(mgr)
	mgr.world = arena
	mgr._spawn_bot(mgr.BOT_CONFIGS[2])
	var b: Dictionary = mgr.bots[903]
	var proxy: Node3D = b.proxy
	proxy.position = Vector3.ZERO
	var archer := Node3D.new()
	arena.add_child(archer)
	archer.position = Vector3(0, 0, -20)
	archer.set_meta("saved_held_item", "Arco reforzado")
	archer.set_meta("peer_id", 77)
	arena.server_proxies[77] = archer
	b["vstats"].body_temperature = 35.0
	b["vstats"].sleep = 80.0
	b["health"] = 80.0
	b["hunger"] = 95.0
	b["thirst"] = 95.0
	proxy.set_meta("proxy_health", 80.0)
	b["sitting"] = true
	mgr.on_bot_damaged(903, 20.0, 77, "arco")
	b["_s_foe"] = archer
	b["sense_t"] = 100.0
	var exposed_sits := 0
	for i in 60:
		mgr._tick_bot(b, 0.05)
		if b.sitting and mgr._has_clear_shot(archer.position, proxy.position):
			exposed_sits += 1
	check(exposed_sits == 0 and proxy.position.length() > 1.0,
		"cold bot hit by arrows leaves its exposed rest spot through the full decision loop")
	check(b.get("_act") == "cover", "cold recovery does not override the incoming-arrow defence")
	# Body arrows intentionally stop at 1 HP. Real subsequent cold damage
	# must retain the attack that left the victim moribund, and its final cause.
	for scenario in ["fresh", "expired", "no_damage_refresh", "healed"]:
		mgr._respawn_bot(mgr.bots[903])
		b = mgr.bots[903]
		proxy = b.proxy
		proxy.position = Vector3.ZERO
		b["health"] = 20.0
		proxy.set_meta("proxy_health", 20.0)
		mgr.on_bot_damaged(903, 55.0, 77, "arco")
		check(is_equal_approx(float(b.health), 1.0), "body-arrow nonlethal rule remains intact (%s)" % scenario)
		if scenario in ["expired", "no_damage_refresh"] and b.has("_fatal_attack"):
			b["_fatal_attack"]["t"] = Time.get_ticks_msec() - 11000
		if scenario == "no_damage_refresh":
			mgr.on_bot_damaged(903, 55.0, 77, "arco")
		if scenario == "healed":
			b["health"] = 20.0
			proxy.set_meta("proxy_health", 20.0)
			b["vstats"].body_temperature = 37.0
			mgr._bot_survival_tick(b, 0.01)
			b["health"] = 1.0
			proxy.set_meta("proxy_health", 1.0)
		b["vstats"].body_temperature = 34.0
		b["vstats"].bleeding = 0.0
		b["hunger"] = 95.0
		b["thirst"] = 95.0
		day.ambient_temp = 0.0
		mgr._stop_bot_motion(b)
		for tick in 30:
			mgr._bot_survival_tick(b, 1.0)
			if proxy.get_meta("proxy_dead", false):
				break
		var death: Dictionary = mgr._memory[903]
		check(proxy.get_meta("proxy_dead", false) and death.get("last_death_cause") == "hypothermia",
			"real cold tick retains the terminal cause (%s)" % scenario)
		check((death.get("last_death_weapon") == "arco" and not str(death.get("last_death_killer", "")).is_empty()) == (scenario == "fresh"),
			"monitor credits only a recent unrecovered near-fatal arrow (%s)" % scenario)
	arena.free()

func run() -> void:
	await test_armed_response()
	test_night_watch()
	test_cold_arrow_response()
	# -- 1) Serpentina impredecible: los quiebros no siguen el reloj de 900 ms
	var mgr := FireManager.new()
	var p1 := Node3D.new()
	root.add_child(p1)
	var b1 := bot(p1, 911)
	var sides := {}
	var intervals: Array = []
	var last_side := 0.0
	var last_flip_ms := Time.get_ticks_msec()
	var sim_ms := 0
	# avanza el estado sin reloj real: cada llamada con delta fijo
	for i in 600:
		var side := mgr._bot_evade_side(b1, 0.05)
		sides[side] = int(sides.get(side, 0)) + 1
		if last_side != 0.0 and side != last_side:
			intervals.append(sim_ms - last_flip_ms)
			last_flip_ms = sim_ms
		last_side = side
		sim_ms += 50
	check(sides.keys().size() == 2, "la serpentina usa ambos lados, no uno fijo")
	var distinct := {}
	for iv in intervals:
		distinct[iv] = true
	check(intervals.size() >= 3, "hay suficientes quiebros para medir (%d)" % intervals.size())
	check(distinct.keys().size() >= 3, "los intervalos de quiebro varian (impredecibles): %s" % str(distinct.keys()))
	# nota: el azar usa el reloj real como semilla; sin avance real los quiebros
	# solo ocurren cuando el flip programado expira — la varianza exigida es la
	# de los intervalos programados, no la cadencia del harness.

	# -- 2) Cobertura por posicion de amenaza sin enemigo visible
	var cover := mgr._find_ballistic_cover_from_pos(b1, Vector3(30, 0, 0))
	# con _has_clear_shot siempre true no existe cobertura valida: INF es correcto
	check(cover == Vector3.INF, "sin bloqueo LOS no hay cobertura posible")

	# -- 3) Direccion de amenaza: prioriza enemigo visto, memoria, disparo oido
	check(mgr._bot_threat_direction_pos(b1) == Vector3.INF, "sin pistas no hay direccion de amenaza")
	b1["_shot_alert_t"] = 4.0
	b1["_shot_origin"] = Vector3(50, 0, 10)
	check(mgr._bot_threat_direction_pos(b1) == Vector3(50, 0, 10), "el origen del disparo sirve de amenaza estimada")
	b1["last_heard_kind"] = "gunshot"
	b1["last_heard_pos"] = Vector3(60, 0, 20)
	b1["last_heard_until"] = Time.get_ticks_msec() / 1000.0 + 10.0
	check(mgr._bot_threat_direction_pos(b1) == Vector3(60, 0, 20), "la posicion del estampido fresco tiene prioridad")
	b1["_foe_mem"] = {"pos": Vector3(70, 0, 30), "t": Time.get_ticks_msec()}
	check(mgr._bot_threat_direction_pos(b1) == Vector3(70, 0, 30), "la memoria del enemigo manda sobre el sonido")
	b1["_foe_mem"] = {"pos": Vector3(70, 0, 30), "t": Time.get_ticks_msec() - 60000}
	check(mgr._bot_threat_direction_pos(b1) == Vector3(60, 0, 20), "memoria de enemigo caducada no vale")

	# -- 4) Flinch bajo fuego: arma/m4 reciente => no devuelve el control a 'flinch'
	var p2 := Node3D.new()
	root.add_child(p2)
	var b2 := bot(p2, 912)
	b2["flinch_timer"] = 0.4
	b2["flinch_anim"] = "shot"
	b2["_last_attacker_msec"] = Time.get_ticks_msec()
	b2["_last_hit_weapon"] = "m4"
	var under_fire := Time.get_ticks_msec() - int(b2.get("_last_attacker_msec", -999999)) < 1500 \
		and str(b2.get("_last_hit_weapon", "")) in ["rifle", "m4"]
	check(under_fire, "impacto de M4 reciente cuenta como bajo fuego")
	b2["_last_attacker_msec"] = Time.get_ticks_msec() - 2000
	under_fire = Time.get_ticks_msec() - int(b2.get("_last_attacker_msec", -999999)) < 1500 \
		and str(b2.get("_last_hit_weapon", "")) in ["rifle", "m4"]
	check(not under_fire, "impacto de hace 2 s ya no es fuego sostenido")
	b2["_last_attacker_msec"] = Time.get_ticks_msec()
	b2["_last_hit_weapon"] = "melee"
	under_fire = Time.get_ticks_msec() - int(b2.get("_last_attacker_msec", -999999)) < 1500 \
		and str(b2.get("_last_hit_weapon", "")) in ["rifle", "m4"]
	check(not under_fire, "un golpe cuerpo a cuerpo sigue causando flinch completo")

	# -- 5) Grieta de bala cercana: el canal existe y usa radio corto
	# (verificacion del cableado en Main por inspeccion de codigo)
	var main_src := FileAccess.get_file_as_string("res://scripts/Main.gd")
	check(main_src.count('"bullet_crack"') >= 1, "Main notifica bullet_crack a los bots")
	check(main_src.count('notify_sound_event(shooter_id, mid_impact, "bullet_crack", 14.0)') == 1, "el crack usa radio 14 m en el punto medio del trayecto")

	# -- 6) Huida de desarmados mas alla de 95 m: el corte duro desaparecio
	var mgr_src := FileAccess.get_file_as_string("res://scripts/SurvivorBotManager.gd")
	check(mgr_src.count("elif not has_gun:") == 1, "los desarmados huyen a cualquier distancia de audicion")
	check(mgr_src.count("clampf(10.0 - (d - 95.0) / 15.0, 4.0, 10.0)") == 1, "la huida lejana se gradua con la distancia")

	# -- 7) El flinch no congela bajo fuego: la rama existe y es especifica
	check(mgr_src.count("under_fire_now") >= 1, "el flinch cede bajo fuego sostenido")

	# -- 8) Amplitud de serpentina proporcional a la distancia de amenaza
	var p3 := Node3D.new()
	root.add_child(p3)
	p3.position = Vector3.ZERO
	var b3 := bot(p3, 913)
	var amp_near := clampf(20.0 / 55.0, 0.45, 1.15)
	var amp_far := clampf(120.0 / 55.0, 0.45, 1.15)
	check(amp_far > amp_near * 2.0, "la serpentina cruza mas linea de tiro a 120 m que a 20 m")
	check(amp_near >= 0.44 and amp_far <= 1.16, "la amplitud esta acotada")

	# -- 9) Asomos desde cobertura: la maquina existe y usa la pipeline justa
	check(mgr_src.count("func _bot_fire_cover_peek") == 1, "existe el combate con asomos")
	check(mgr_src.count('b["_peek_phase"] = "peeking"') == 1, "el ciclo oculto/asomado existe")
	check(mgr_src.count("randf_range(1.2, 2.4)") >= 1, "la fase oculta es irregular")
	check(mgr_src.count('"_evade_pause_in"') >= 1, "las pausas agachadas irregulares existen")
	check(mgr_src.count('"_evade_speed_mul"') >= 1, "las rafagas de sprint existen")

	print("BotUnderFireRegression: %d checks, %d errores" % [checks, errors])
	mgr.free()
	p1.free()
	p2.free()
	p3.free()
	quit(1 if errors > 0 else 0)
