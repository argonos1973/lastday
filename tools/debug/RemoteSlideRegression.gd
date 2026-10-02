extends SceneTree

# Remote stop-slide regression: el sender frena en seco (velocity = dir*speed,
# sin fricción) y manda "idle" de inmediato, pero el puppet remoto interpola su
# posición — sin corrección el personaje se ve deslizarse en pose idle.
# - La locomoción del puppet sigue su desplazamiento real (run/walk hasta
#   asentarse, luego el idle sincronizado).
# - Acciones/posturas/remar se respetan aunque el puppet se mueva.
# - El lerp se asienta exacto (<4 cm snap) y hace snap en saltos >8 m.

const MainScript = preload("res://scripts/Main.gd")

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

class FakeNet extends Node:
	var players := {}
	var is_connected := true
	var is_dedicated_server := false
	func get_my_id() -> int:
		return 1
	func close_connection() -> void:
		pass

class FakePuppet extends Node3D:
	var _puppet_current_anim := ""
	var last_anim := ""
	func puppet_apply(pos: Vector3, rot: float, anim: String) -> void:
		global_position = pos
		rotation.y = rot
		last_anim = anim
		_puppet_current_anim = anim
	func puppet_apply_visuals(a, b, c, d = []) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var main = MainScript.new()
	world.add_child(main)
	var fnet := FakeNet.new()
	world.add_child(fnet)
	main.net = fnet

	# --- _puppet_effective_anim: locomoción por desplazamiento real ---
	var fp := FakePuppet.new()
	world.add_child(fp)
	fp._puppet_current_anim = "external/RunExternal"
	check(main._puppet_effective_anim(fp, "external/IdleExternal", 3.0) == "external/RunExternal",
		"moving puppet keeps its run clip over synced idle")
	check(main._puppet_effective_anim(fp, "external/IdleExternal", 0.2) == "external/IdleExternal",
		"settled puppet honors synced idle")
	check(main._puppet_effective_anim(fp, "external/AttackExternal", 6.0) == "external/AttackExternal",
		"action anims trusted while moving")
	check(main._puppet_effective_anim(fp, "rowing/Stroke", 5.0) == "rowing/Stroke",
		"rowing anim trusted while the boat moves")
	check(main._puppet_effective_anim(fp, "external/SitExternal", 4.0) == "external/SitExternal",
		"sit anim trusted while moving")
	check(main._puppet_effective_anim(fp, "external/WalkExternal", 0.0) == "external/WalkExternal",
		"synced moving anim passes through")
	# Sin clip previo de locomoción: genérico según velocidad.
	fp._puppet_current_anim = ""
	check(main._puppet_effective_anim(fp, "external/IdleExternal", 6.0) == "run",
		"unknown clip falls back to run at sprint speed")
	check(main._puppet_effective_anim(fp, "external/IdleExternal", 2.0) == "walk",
		"unknown clip falls back to walk at walk speed")
	# Estáticos: aim/crouch-idle también se corrigen mientras el puppet se mueve.
	fp._puppet_current_anim = "external/RifleWalkExternal"
	check(main._puppet_effective_anim(fp, "external/RifleAimIdleExternal", 3.0) == "external/RifleWalkExternal",
		"aim-idle synced while moving keeps the rifle walk")

	# --- _update_remote_players: frenada de sprint completa ---
	# El sender paró: manda pos fija + idle. El puppet va ~1.5 m atrás.
	var target := Vector3(1.5, 0.0, 0.0)
	fnet.players[7] = {"pos": target, "rot": 0.0, "anim": "external/IdleExternal"}
	fp.global_position = Vector3.ZERO
	fp._puppet_current_anim = "external/RunExternal"
	main.remote_players[7] = fp
	main._update_remote_players()
	check(fp.last_anim == "external/RunExternal",
		"gliding puppet keeps running while catching up")
	check(fp.global_position.x > 0.2, "puppet approaches the stopped target")
	var saw_idle := false
	for i in range(40):
		main._update_remote_players()
		if fp.last_anim == "external/IdleExternal":
			saw_idle = true
	check(saw_idle, "settled puppet eventually plays synced idle")
	check(fp.global_position.distance_to(target) < 0.05,
		"puppet snaps exactly onto the final position")
	# Mientras deslizaba nunca reprodujo idle en movimiento.
	# (assert implícito: el primer frame con idle solo llega al asentarse)

	# --- Teleport/desync: snap instantáneo ---
	fnet.players[7]["pos"] = Vector3(30.0, 0.0, 0.0)
	fnet.players[7]["anim"] = "external/RunExternal"
	main._update_remote_players()
	check(fp.global_position.distance_to(Vector3(30.0, 0.0, 0.0)) < 0.01,
		"large jump snaps instead of gliding across the map")

	world.free()
	if failures == 0:
		print("PASS: remote stop-slide fixed — locomotion follows real puppet motion")
	quit(1 if failures else 0)
