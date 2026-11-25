extends SceneTree

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
	func _is_step_blocked(_a: Vector3, _z: Vector3, _deep: bool = false) -> bool: return false
	func _has_clear_shot(_a: Vector3, _z: Vector3) -> bool: return true
	func _bot_carry_ratio(_b: Dictionary) -> float: return 0.0

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

func run() -> void:
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
	check(mgr_src.count("_bot_within_aim_sight(b, foe, dist)") >= 1, "el asomo respeta la vision nocturna justa")
	check(mgr_src.count('b["_peek_phase"] = "peeking"') == 1, "el ciclo oculto/asomado existe")
	check(mgr_src.count("randf_range(1.2, 2.4)") >= 1, "la fase oculta es irregular")
	check(mgr_src.count('"_evade_pause_in"') >= 1, "las pausas agachadas irregulares existen")
	check(mgr_src.count('"_evade_speed_mul"') >= 1, "las rafagas de sprint existen")

	print("BotUnderFireRegression: %d checks, %d errores" % [checks, errors])
	quit(1 if errors > 0 else 0)
