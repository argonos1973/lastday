extends SceneTree
class Cover extends Node3D:
	var pending := [0,1,2,3,4,5,6,7]
	var focus := Vector3.INF
	var focus_updates := 0
	func update_focus(position_world: Vector3, _detail: float):
		focus = position_world
		focus_updates += 1
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
	func _world_entry_render_positions(original_position: Vector3) -> Array[Vector3]:
		return [Vector3(20, 2, 20), original_position]
	func _update_near_ground_cover():
		if not _near_ground_cover.pending.is_empty(): _near_ground_cover.pending.pop_front()
	func update_cover_real(): super._update_near_ground_cover()
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
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(2,3,7)
	camera.rotation = Vector3(-.2,.4,.1)
	camera.fov = 73.0
	camera.cull_mask = 1 | (1 << 17)
	camera.make_current()
	var original_view := camera.global_transform
	var original_player: Transform3D = world.player.transform
	var directions := {}
	var positions := {}
	var view_settings := [true]
	var observe_draw := func():
		var active := root.get_camera_3d()
		if active != null and active != camera:
			directions[active.global_basis.z.snapped(Vector3.ONE * .001)] = true
			positions[active.global_position] = true
			view_settings[0] = view_settings[0] and active.fov == camera.fov and active.cull_mask == camera.cull_mask and world.player.transform.is_equal_approx(original_player)
	RenderingServer.frame_post_draw.connect(observe_draw)
	await world._prepare_world_entry_render()
	RenderingServer.frame_post_draw.disconnect(observe_draw)
	if DisplayServer.get_name() != "headless" and (directions.size() != 8 or positions.size() != 2 or not positions.has(original_view.origin) or not view_settings[0]):
		errors += 1;push_error("Entry must render distant views and spawn in eight directions without moving the player")
	if root.get_camera_3d() != camera or not camera.global_transform.is_equal_approx(original_view) or not world.player.transform.is_equal_approx(original_player):
		errors += 1;push_error("Render warmup must restore the camera without moving the player or changing their view")
	if world.get_node_or_null("EntryRenderWarmup") != null:
		errors += 1;push_error("Render warmup must release its temporary camera")
	var grass := MultiMeshInstance3D.new()
	world.add_child(grass)
	world._grass_batch_nodes.append(grass)
	world.update_cover_real()
	var cover = world._near_ground_cover
	if cover.focus != world.player.global_position:
		errors += 1;push_error("Normal camera anchors ground cover to the player")
	camera.global_position = Vector3(-7,3,0)
	world.update_cover_real()
	if cover.focus != world.player.global_position:
		errors += 1;push_error("Orbiting the camera must not move ground-cover focus")
	camera.global_position = Vector3(100,30,100)
	world.update_cover_real()
	if cover.focus != camera.global_position:
		errors += 1;push_error("Detached views still request ground cover at the camera")
	var updates: int = cover.focus_updates
	world._entry_render_focus = Vector3.ONE
	world.update_cover_real()
	if cover.focus_updates != updates:
		errors += 1;push_error("Render preparation must not rebuild distant ground cover")
	world._entry_render_focus = Vector3.INF
	camera.global_transform = original_view
	world._grass_batch_nodes.clear()
	world._near_ground_cover.pending=[1,2,3]
	world._scene_quitting=true
	await world._prepare_world_entry_details()
	await world._prepare_world_entry_render()
	if world._near_ground_cover.pending.size()!=3: errors+=1;push_error("Disconnect/quit cancels the entry preparation")
	world.queue_free();for i in 4:await process_frame
	print("WORLD_ENTRY errors=",errors)
	quit(1 if errors else 0)
