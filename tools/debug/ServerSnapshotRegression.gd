extends SceneTree

class TestWorld extends "res://scripts/Main.gd":
	func _ready():
		set_process(false)
		set_physics_process(false)
	func _exit_tree(): pass

class CaptureSave extends Node:
	var gate := Semaphore.new()
	var captured := {}
	func save_server_game(world: Dictionary, _players: Dictionary) -> bool:
		gate.wait()
		captured = world.duplicate(true)
		return true

func _initialize(): call_deferred("run")
func run():
	# Swap the persistence service with a gated in-memory writer. No save files.
	var original := root.get_node("SaveGameManager")
	root.remove_child(original)
	var capture := CaptureSave.new()
	capture.name = "SaveGameManager"
	root.add_child(capture)
	var world := TestWorld.new()
	root.add_child(world)
	world._built_shelters = [{"id": "snapshot_shelter", "pos": Vector3.ZERO, "contents": [{"quantity": 3}]}]
	world._dropped_items = [{"id": "snapshot_bag", "pos": Vector3.ZERO, "contents": [{"quantity": 2}]}]
	world._save_server_world()
	world._built_shelters[0]["contents"][0]["quantity"] = 99
	world._dropped_items[0]["contents"].clear()
	capture.gate.post()
	world._wait_pending_server_save()
	var ok: bool = capture.captured["built_shelters"][0]["contents"][0]["quantity"] == 3
	ok = ok and capture.captured["dropped_items"][0]["contents"].size() == 1
	world.free()
	capture.free()
	root.add_child(original)
	print("ServerSnapshotRegression: ", "ALL PASS" if ok else "FAIL: shared nested snapshot")
	quit(0 if ok else 1)
