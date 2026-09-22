extends SceneTree

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
	func _apply_character_colors() -> void:
		pass
	func restore_held_item(_item_name: String, _index: int = -1, _item_data: Dictionary = {}) -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := TestPlayer.new()
	root.add_child(player)
	var failures := 0
	for position in [Vector3(9, 0.5, 6), Vector3(-120, 4, 85), Vector3(258, 2, -264)]:
		player.velocity = Vector3(1, -8, 2)
		SaveGameHooks.apply_saved_player_data(player, {"pos": [position.x, position.y, position.z], "rot": 0.75})
		if not player.global_position.is_equal_approx(position):
			failures += 1
			push_error("Saved position overwritten: expected %s, got %s" % [position, player.global_position])
		if player.velocity != Vector3.ZERO or not is_equal_approx(player.rotation.y, 0.75):
			failures += 1
			push_error("Restore must reset velocity and preserve rotation")
	player.free()
	if failures == 0:
		print("PASS: saved positions preserved without modifying player save files")
	quit(1 if failures else 0)
