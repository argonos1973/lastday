extends SceneTree
class Cover extends Node3D:
	var pending := [0,1,2,3,4,5,6,7]
class Player extends Node3D:
	var third_person_model := Node3D.new()
	var third_person_ground_offset := 0.0
	func _ready(): add_child(third_person_model)
class Avatar extends Node3D:
	var third_person_model: Node3D
	var third_person_ground_offset := 0.0
	var setups := 0
	func setup_as_puppet(): setups += 1
class Net extends Node:
	var is_connected := true
	var is_host := false
	var is_dedicated_server := false
	var players := {}
	var animals := {}
class World extends "res://scripts/Main.gd":
	func _ready(): set_process(false); set_physics_process(false)
	func _exit_tree(): pass
	func _update_near_ground_cover():
		if not _near_ground_cover.pending.is_empty(): _near_ground_cover.pending.pop_front()
func _initialize(): call_deferred("run")
func run():
	var world := World.new(); root.add_child(world); current_scene = world
	world.net=Net.new();world.add_child(world.net)
	world.player=Player.new();world.add_child(world.player)
	world._near_ground_cover=Cover.new();world.add_child(world._near_ground_cover)
	world._loading_overlay=CanvasLayer.new();world.add_child(world._loading_overlay)
	var avatars := []
	for i in 4:
		var avatar := Avatar.new();world.add_child(avatar);avatars.append(avatar);world._pending_puppets.append(avatar)
	var errors := 0
	world._process_pending_puppets();world._process_pending_puppets()
	var count := 0
	for avatar in avatars: count += avatar.setups
	if count != 1: errors += 1;push_error("Loading admits only one avatar per frame, including repeated calls")
	if DisplayServer.get_name() != "headless":
		world.net.animals={"wolf_a":{"t":"wolf","x":0.0,"y":0.0,"z":0.0},"wolf_b":{"t":"wolf","x":3.0,"y":0.0,"z":0.0}}
		world._update_puppet_animals();world._update_puppet_animals()
		if world.puppet_animals.size()!=1: errors+=1;push_error("Repeated calls must not spawn two animal models in a frame")
	var resumed := [0]
	var count_frame := func(): resumed[0] += 1
	process_frame.connect(count_frame)
	await world._prepare_world_entry_details()
	process_frame.disconnect(count_frame)
	if resumed[0] < 7: errors += 1;push_error("Entry must yield while the nearby cover is being built")
	if not world._near_ground_cover.pending.is_empty() or not world._pending_puppets.is_empty(): errors += 1;push_error("Entry returned before local detail / actors were ready")
	if DisplayServer.get_name() != "headless" and world.puppet_animals.size()!=2: errors+=1;push_error("Entry must finish the initial animal snapshot")
	world._near_ground_cover.pending=[1,2,3]
	world._scene_quitting=true
	await world._prepare_world_entry_details()
	if world._near_ground_cover.pending.size()!=3: errors+=1;push_error("Disconnect/quit cancels the entry preparation")
	world.queue_free();for i in 4:await process_frame
	print("WORLD_ENTRY errors=",errors)
	quit(1 if errors else 0)
