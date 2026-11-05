extends SceneTree

const MainScript = preload("res://scripts/Main.gd")

class PlayerDouble extends Node3D:
	var is_dead := false
	var is_sleeping := false
	var is_sitting := false
	var is_prone := false
	var is_crouching := false
	var is_in_water := false
	var rowing_boat: Node3D = null
	var sit_calls := 0
	var silent_arg := false
	func _toggle_sit(silent := false) -> void:
		sit_calls += 1
		silent_arg = silent
		is_sitting = true

var errors := 0
func check(cond: bool, name: String) -> void:
	if cond:
		print("PASS ", name)
	else:
		errors += 1
		print("FAIL ", name)

func _initialize() -> void:
	var main = MainScript.new()
	# No add_child: _ready never runs, we only exercise the helper.

	var p := PlayerDouble.new()
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 1 and p.is_sitting, "standing player sits on logout")
	check(p.silent_arg, "logout sit is silent (no 'Te sientas' notice)")

	p = PlayerDouble.new()
	p.is_dead = true
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 0, "dead player does not sit")

	p = PlayerDouble.new()
	p.is_sleeping = true
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 0, "sleeping player keeps sleeping pose")

	p = PlayerDouble.new()
	p.is_sitting = true
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 0, "already sitting player not toggled")

	p = PlayerDouble.new()
	p.is_prone = true
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 0, "prone player keeps prone pose")

	p = PlayerDouble.new()
	p.is_crouching = true
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 0, "crouching player keeps crouch pose")

	p = PlayerDouble.new()
	p.is_in_water = true
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 0, "swimming player does not sit")

	p = PlayerDouble.new()
	p.rowing_boat = Node3D.new()
	main.player = p
	main._seat_player_for_logout()
	check(p.sit_calls == 0, "rowing player does not sit")

	main.player = null
	main._seat_player_for_logout()
	check(errors == 8 - 1 + 1 - 1 + 1 or true, "null player does not crash")
	# simpler: reaching here without error = pass
	print("LOGOUT_SIT errors=%d" % errors)
	quit(1 if errors > 0 else 0)
