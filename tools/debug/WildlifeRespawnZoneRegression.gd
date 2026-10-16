extends SceneTree
# Verifies per-species respawn cooldown and death-zone exclusion in Main.gd:
# - _note_wildlife_death blocks the species respawn for WILDLIFE_RESPAWN_DELAY
#   (BEAR_RESPAWN_DELAY for bears) counted from the last death.
# - _far_from_death_sites rejects spawn points near a pending death site.
# - _wildlife_mark_replaced releases the oldest pending death zone per spawn.

var _fails := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: " + label)
	else:
		_fails += 1
		printerr("FAIL: " + label)

func _init() -> void:
	var main_script: GDScript = load("res://scripts/Main.gd")
	var m: Node = main_script.new()

	_check(m._wildlife_respawn_ready("wolf"), "no deaths recorded -> wolf respawn ready")
	_check(m._wildlife_respawn_ready("bear"), "no deaths recorded -> bear respawn ready")

	m._note_wildlife_death("wolf", Vector3(100.0, 0.0, 100.0))
	_check(not m._wildlife_respawn_ready("wolf"), "wolf respawn blocked right after a wolf death")
	_check(m._wildlife_respawn_ready("bear"), "wolf death does not block bear respawn")
	_check(m._wildlife_respawn_ready("deer"), "wolf death does not block deer respawn")

	# Cooldown elapsed -> ready again even though the site is still queued.
	m._wildlife_death_time["wolf"] = Time.get_unix_time_from_system() - m.WILDLIFE_RESPAWN_DELAY - 1.0
	_check(m._wildlife_respawn_ready("wolf"), "wolf respawn ready once the delay elapsed")

	# Death-zone exclusion: the queued site blocks nearby spawn points.
	_check(not m._far_from_death_sites("wolf", Vector3(150.0, 0.0, 120.0)),
		"wolf spawn point 55m from the death site is rejected")
	_check(m._far_from_death_sites("wolf", Vector3(100.0, 0.0, 100.0 + m.WILDLIFE_RESPAWN_AVOID_RADIUS + 10.0)),
		"wolf spawn point beyond the avoid radius is accepted")

	# A second wolf death elsewhere adds a second blocked zone.
	m._note_wildlife_death("wolf", Vector3(-300.0, 0.0, -300.0))
	_check(not m._far_from_death_sites("wolf", Vector3(-320.0, 0.0, -310.0)),
		"second wolf death site also blocks its zone")

	# Each respawn releases only the oldest pending death zone.
	m._wildlife_mark_replaced("wolf")
	_check(m._wildlife_death_sites["wolf"].size() == 1, "one respawn releases only the oldest death site")
	_check(m._far_from_death_sites("wolf", Vector3(150.0, 0.0, 120.0)),
		"released death zone no longer blocks spawns")
	_check(not m._far_from_death_sites("wolf", Vector3(-320.0, 0.0, -310.0)),
		"still-pending death zone keeps blocking spawns")

	# Bears use the longer delay and the territory-sized avoid radius.
	m._note_wildlife_death("bear", Vector3(-230.0, 0.0, -210.0))
	_check(not m._wildlife_respawn_ready("bear"), "bear respawn blocked right after a bear death")
	m._wildlife_death_time["bear"] = Time.get_unix_time_from_system() - m.WILDLIFE_RESPAWN_DELAY - 1.0
	_check(not m._wildlife_respawn_ready("bear"), "bear still blocked after the generic delay (longer bear delay)")
	m._wildlife_death_time["bear"] = Time.get_unix_time_from_system() - m.BEAR_RESPAWN_DELAY - 1.0
	_check(m._wildlife_respawn_ready("bear"), "bear respawn ready once the bear delay elapsed")
	_check(not m._far_from_death_sites("bear", Vector3(-230.0, 0.0, -210.0)),
		"bear death blocks its own territory anchor")
	_check(m._far_from_death_sites("bear", Vector3(210.0, 0.0, 140.0)),
		"bear death does not block a distant territory anchor")

	m.free()
	print("ERRORS=%d" % _fails)
	quit(_fails)
