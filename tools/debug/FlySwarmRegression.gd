extends SceneTree

class TestMain extends "res://scripts/Main.gd":
	func _save_world_change_silent() -> void:
		pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# The swarm itself: fly meshes + positional buzz audio
	var swarm := FlySwarm.new()
	root.add_child(swarm)
	var fly_meshes := 0
	var audio: AudioStreamPlayer3D = null
	for c in swarm.get_children():
		if c is MeshInstance3D:
			fly_meshes += 1
		elif c is AudioStreamPlayer3D:
			audio = c
	check(fly_meshes >= 6, "Swarm shows several orbiting flies")
	check(audio != null and audio.stream != null, "Swarm carries a looping buzz sound")
	if audio != null and audio.stream is AudioStreamWAV:
		check(audio.stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "Buzz loops seamlessly")
	# Flies actually orbit
	var first: MeshInstance3D = swarm.get_child(0)
	var p0: Vector3 = first.position
	swarm._process(0.5)
	check(first.position != p0, "Flies orbit around the swarm origin")
	# Rotten dropped meat: flies appear at spoilage 100, then the drop decays away
	var main := TestMain.new()
	root.add_child(main)
	var pickup := Node3D.new()
	pickup.name = "Pickup_rot_meat_1"
	main.add_child(pickup)
	main._dropped_items.append({"id": "rot_meat_1", "name": "Carne cruda de lobo", "type": "food", "spoilage": 99.0, "wear": 0.0, "pos": [0.0, 0.0, 0.0]})
	main._update_loot_wear()
	check(pickup.get_node_or_null("FlySwarm") != null, "Flies gather on fully rotten meat")
	var guard := 0
	while main._dropped_items.size() > 0 and guard < 60:
		main._update_loot_wear()
		guard += 1
	check(main._dropped_items.is_empty(), "Rotten meat is removed after the rot countdown")
	check(main._depleted_action_ids.has("rot_meat_1"), "Removed meat is marked depleted")
	# Depleting an action removes its swarm
	var action := WorldAction.new()
	action.action_id = "wa_1"
	var swarm2 := FlySwarm.new()
	swarm2.name = "FlySwarm"
	action.add_child(swarm2)
	root.add_child(action)
	action.mark_depleted()
	await process_frame
	check(not is_instance_valid(swarm2), "Picking up the item removes its flies")
	main.free()
	swarm.free()
	action.free()
	if failures == 0:
		print("PASS: flies gather on rotten meat and vanish with it")
	quit(1 if failures else 0)
