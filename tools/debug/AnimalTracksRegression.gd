extends SceneTree

# Animal tracks regression: ground wildlife drops alternating paw/hoof prints
# every stride while it walks, skips water/dead/idle, and TrackPrint fades and
# frees itself at end of life. Client-side cosmetic — no net needed.
# Uso: godot --headless --path . --script tools/debug/AnimalTracksRegression.gd

const WildlifeScript = preload("res://scripts/WildlifeController.gd")
const TrackPrintScript = preload("res://scripts/TrackPrint.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _n_tracks() -> int:
	return get_nodes_in_group("track_prints").size()

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene

	# Lobo caminando recto hacia +Z: una huella por zancada (~0.48 m).
	var wolf = WildlifeScript.new()
	wolf.animal_type = "wolf"
	scene.add_child(wolf)
	wolf._update_tracks()  # ancla inicial
	var step := 0.1
	for i in range(30):
		wolf.global_position += Vector3(0, 0, step)
		wolf._update_tracks()
	var n := _n_tracks()
	# 30 * 0.1 = 3.0 m recorridos / 0.48 stride → ~6 huellas
	check(n >= 5 and n <= 8, "Wolf drops ~6 prints over 3 m (got %d)" % n)
	# Alternancia lateral: huellas a ambos lados de la linea x=0.
	var left := 0
	var right := 0
	for t in get_nodes_in_group("track_prints"):
		var x := (t as Node3D).global_position.x
		if x < -0.01:
			left += 1
		elif x > 0.01:
			right += 1
	check(left >= 2 and right >= 2, "Prints alternate left/right of the path (L=%d R=%d)" % [left, right])
	# Orientacion: cada huella mira hacia la marcha (yaw=0 -> rotation.y ~ PI).
	var tp = get_nodes_in_group("track_prints")[0] as Node3D
	check(absf(fposmod(tp.rotation.y, TAU) - PI) < 0.01, "Print yaw faces travel direction")
	# Avance real: huellas posteriores estan mas adelante en +Z.
	var zvals: Array = []
	for t in get_nodes_in_group("track_prints"):
		zvals.append((t as Node3D).global_position.z)
	zvals.sort()
	check(zvals.back() - zvals.front() > 2.0, "Trail spans the walked distance")

	# Quieto: sin huellas nuevas.
	var still = _n_tracks()
	for i in range(10):
		wolf._update_tracks()
	check(_n_tracks() == still, "Idle animal drops no prints")

	# Agua: vadear no deja rastro.
	wolf._water_depth = 0.5
	for i in range(30):
		wolf.global_position += Vector3(0, 0, step)
		wolf._update_tracks()
	check(_n_tracks() == still, "Wading animal drops no prints")
	wolf._water_depth = 0.0

	# Muerto: sin huellas.
	wolf._is_dead = true
	for i in range(30):
		wolf.global_position += Vector3(0, 0, step)
		wolf._update_tracks()
	check(_n_tracks() == still, "Dead animal drops no prints")

	# Ciervo usa pezuña (kind=hoof) — distinto stride y textura.
	var deer = WildlifeScript.new()
	deer.animal_type = "deer"
	scene.add_child(deer)
	var before_deer := _n_tracks()
	for i in range(30):
		deer.global_position += Vector3(step, 0, 0)
		deer._update_tracks()
	var deer_prints := _n_tracks() - before_deer
	# 30 * 0.1 = 3.0 m / 0.62 stride → ~4-5 huellas
	check(deer_prints >= 4 and deer_prints <= 6, "Deer drops ~5 prints over 3 m (got %d)" % deer_prints)

	# TrackPrint envejece y se libera sola (fade al final de la vida).
	tp._age = TrackPrintScript.LIFETIME - 10.0
	tp._process(11.0)
	await process_frame
	check(not is_instance_valid(tp) or tp.is_queued_for_deletion(), "Expired print frees itself")

	# Cap global: no crece sin limite (queue_free es diferido — contar vivos).
	for i in range(TrackPrintScript.MAX_TRACKS + 20):
		TrackPrintScript.spawn(scene, Vector3(i * 0.1, 0, 0), 0.0, "paw", 0.1)
	var live := 0
	for t in get_nodes_in_group("track_prints"):
		if not (t as Node).is_queued_for_deletion():
			live += 1
	check(live <= TrackPrintScript.MAX_TRACKS + 5, "Track cap holds near MAX_TRACKS (live=%d)" % live)

	scene.free()
	if failures == 0:
		print("AnimalTracksRegression: ALL CHECKS PASSED")
	else:
		push_error("AnimalTracksRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
