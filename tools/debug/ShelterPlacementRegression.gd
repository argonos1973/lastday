extends SceneTree
class World extends "res://scripts/Main.gd":
	var water := false
	var slope := false
	func _ready() -> void: set_process(false)
	func _exit_tree() -> void: pass
	func _save_world_change_silent() -> void: pass
	func get_river_depth_at(_pos: Vector3) -> float: return 1.0 if water else 0.0
	func _get_exact_ground_y(x: float, _z: float, _from_y: float = 500.0) -> float: return x if slope else 0.0

class Player extends "res://scripts/PlayerController.gd":
	func _create_body() -> void: pass
	func _capture_mouse() -> void: pass
	func play_action_animation(_action_name: String, _duration := 1.1) -> void: pass

var errors := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		errors += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var actor := CharacterBody3D.new()
	world.add_child(actor)
	await physics_frame
	var pos := Vector3(0, 0, -4)
	check(world.shelter_placement_error(pos, 0, actor).is_empty(), "Flat clear ground accepted")
	world.water = true
	check(not world.shelter_placement_error(pos, 0, actor).is_empty(), "Water rejected")
	world.water = false
	world.slope = true
	check(not world.shelter_placement_error(pos, 0, actor).is_empty(), "Uneven footprint rejected")
	world.slope = false
	check(not world.shelter_placement_error(Vector3(0, 0, -20), 0, actor).is_empty(), "Remote placement rejected")
	var obstacle := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3.ONE
	collider.shape = shape
	obstacle.add_child(collider)
	world.add_child(obstacle)
	obstacle.position = pos + Vector3.UP
	await physics_frame
	await physics_frame
	check(not world.shelter_placement_error(pos, 0, actor).is_empty(), "Occupied footprint rejected")
	obstacle.free()
	await physics_frame
	world._spawn_player_shelter_with_id("test", pos, PI / 2)
	check(world._built_shelters.size() == 1, "Spawn registers stash on every peer")
	check(is_equal_approx(world.get_node("PlayerShelter_test").rotation.y, PI / 2), "Visual rotation uses radians correctly")
	world._spawn_player_shelter_with_id("test", pos, PI / 2)
	check(world._built_shelters.size() == 1, "Repeated spawn is idempotent")
	check(not world.shelter_placement_error(pos, 0, actor).is_empty(), "Overlapping shelter rejected")
	world._net_backpack_contents_synced("test", [{"name": "Palo", "quantity": 3}])
	check(world._built_shelters[0].contents.size() == 1, "Synced stash retained for world snapshots")
	check(not world._net_shelter_dismantled("test"), "Stocked shelter cannot be dismantled")
	world._net_backpack_contents_synced("test", [])
	check(world._net_shelter_dismantled("test"), "Empty shelter can be dismantled")
	check(world._built_shelters.is_empty(), "Dismantled shelter removed from snapshots")
	var player := Player.new()
	world.add_child(player)
	world.player = player
	player.set_physics_process(false)
	player.inventory.items.clear()
	player.inventory.items.append(load("res://scripts/Item.gd").create("Palo", "resource", 0.3, 11, 0.0))
	world.begin_shelter_placement(player, {}, false)
	check(player.inventory.has_item_name("Palo", 11), "Preview spends no materials")
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	world.get_node("ShelterPlacement").handle_input(cancel)
	await process_frame
	check(player.inventory.has_item_name("Palo", 11) and not world.has_node("ShelterPlacement"), "Cancellation preserves materials")
	world.begin_shelter_placement(player, {}, false)
	var preview = world.get_node("ShelterPlacement")
	preview.global_position = pos
	preview.yaw = PI / 4
	preview.confirm()
	check(not player.inventory.has_item_name("Palo", 1), "Confirmation consumes exactly eleven sticks")
	check(world._built_shelters.size() == 1, "Confirmation creates one shelter")
	check(is_equal_approx(float(world._built_shelters[0].yaw), PI / 4), "Chosen orientation persisted")
	preview.confirm()
	check(world._built_shelters.size() == 1, "Repeated confirmation cannot duplicate construction")
	world.free()
	print("SHELTER_PLACEMENT_ERRORS=", errors)
	quit(1 if errors else 0)
