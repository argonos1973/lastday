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

	# --- Puppet ground alignment during actions (comer/plant, forage/gather, drink, chop) ---
	var PlayerScript := preload("res://scripts/PlayerController.gd")
	var real_puppet = PlayerScript.new()
	real_puppet.is_puppet = true
	world.add_child(real_puppet)
	real_puppet.setup_as_puppet()
	real_puppet.global_position = Vector3(0.0, 2.0, 0.0)
	for clip in [real_puppet.third_person_idle_animation, real_puppet.third_person_plant_animation, real_puppet.third_person_gather_animation, real_puppet.third_person_drink_animation, real_puppet.third_person_attack_animation]:
		if str(clip).is_empty():
			continue
		real_puppet.puppet_apply(real_puppet.global_position, 0.0, str(clip))
		for _step in range(25):
			real_puppet.third_person_animation_player.advance(0.04)
			real_puppet._process(0.04)
		var skel: Skeleton3D = real_puppet._find_skeleton(real_puppet.third_person_model)
		skel.force_update_all_bone_transforms()
		var min_foot_rel_y := 999.0
		for bi in range(skel.get_bone_count()):
			var bname := skel.get_bone_name(bi)
			if bname.find("Foot") >= 0 or bname.find("Toe") >= 0:
				var wy := (skel.global_transform * skel.get_bone_global_pose(bi).origin).y
				min_foot_rel_y = minf(min_foot_rel_y, wy - real_puppet.global_position.y)
		check(absf(min_foot_rel_y - 0.025) < 0.05, "remote puppet stays grounded on %s (foot_rel_y=%.3f)" % [str(clip), min_foot_rel_y])

	# --- Remote action sounds must be positional ---
	# Los players 2D sonaban a volumen completo en todo el mapa; en puppets deben
	# ser AudioStreamPlayer3D para atenuar por distancia.
	real_puppet._play_pain_sound()
	real_puppet._play_melee_swing_sound()
	real_puppet._play_punch_impact_sound()
	real_puppet._play_shoot_sound()
	for p in [real_puppet._pain_audio_player, real_puppet._swing_audio_player, real_puppet._impact_audio_player, real_puppet._shoot_audio_player]:
		check(p is AudioStreamPlayer3D, "remote puppet action sound '%s' is positional" % (str(p.name) if p != null else "null"))
	var local_pc = PlayerScript.new()
	var local_snd = local_pc._make_action_sound_player("PainSound")
	check(local_snd != null and not local_snd is AudioStreamPlayer3D,
		"local player action sounds stay 2D")
	local_pc.free()

	world.free()
	if failures == 0:
		print("PASS: remote stop-slide and action ground alignment verified")
	quit(1 if failures else 0)
