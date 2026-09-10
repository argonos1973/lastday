extends SceneTree
const Cases = preload("res://tools/debug/TestGameplayBugs.gd")
const Bullet = preload("res://scripts/RifleProjectile.gd")
const Bird = preload("res://scripts/BirdController.gd")
const Inv = preload("res://scripts/Inventory.gd")
const ItemData = preload("res://scripts/Item.gd")
class World extends Node3D:
	var drops := 0
	func _spawn_ground_pickup(_n, _t, _p, _w, _q, _u, _id, _a): drops += 1
class TestBird extends Bird:
	func _build_bird(): _build_primitive_bird()
class Fisher extends Cases.TestPlayer:
	func _get_fishing_water_state() -> Dictionary: return {"near": true, "facing": true}
var checks := 0
var failed := 0
var hits: Array = []
func check(ok: bool, message: String):
	checks += 1
	if not ok:
		failed += 1
		push_error(message)
func _initialize(): call_deferred("run")
func fire(world: Node3D, pos: Vector3, direction: Vector3):
	var bullet := Bullet.new()
	bullet.velocity = direction * 800.0
	bullet.impact.connect(func(c, _p, _d): hits.append(c))
	world.add_child(bullet)
	bullet.global_position = pos
	return bullet
func run():
	var world := World.new()
	root.add_child(world)
	current_scene = world
	var bird := TestBird.new()
	world.add_child(bird)
	bird.position = Vector3(0, 5, -10)
	bird.set_process(false)
	await physics_frame
	await physics_frame
	fire(world, Vector3(0, 5.2, 0), Vector3.FORWARD)
	await create_timer(0.08).timeout
	check(hits.size() == 1 and hits[0].get_parent() == bird, "Actual bird hitbox receives rifle trajectory")
	hits.clear()
	fire(world, Vector3(0, 8, 0), Vector3.FORWARD)
	await create_timer(0.25).timeout
	check(hits.is_empty(), "Shooting above bird misses in 3D")
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	world.add_child(wall)
	wall.position = Vector3(0, 5, -5)
	await physics_frame
	await physics_frame
	fire(world, Vector3(0, 5.2, 0), Vector3.FORWARD)
	await create_timer(0.08).timeout
	check(hits.size() == 1 and hits[0] == wall, "Cover stops projectile before bird")
	wall.queue_free()
	var projectile = fire(world, Vector3(20, 50, 0), Vector3.FORWARD)
	await physics_frame
	await physics_frame
	check(is_instance_valid(projectile) and projectile.traveled < 150 and projectile.position.y < 50, "Finite flight time and gravity")
	bird._velocity = Vector3(2, 0, 0)
	bird.take_damage(200, false)
	check(bird._is_dead and not bird._landed, "Killed bird starts falling without teleporting")
	for i in range(120): bird._update_falling(1.0 / 60.0)
	check(bird._landed and bird.is_in_group("interactable"), "Fallen bird can be interacted with")
	var player := Fisher.new()
	world.add_child(player)
	player.inventory = Inv.new()
	player.add_child(player.inventory)
	player.position = bird.position
	bird.interact(player)
	check(world.drops == 0, "Butchering needs a tool")
	player.inventory.add_item(ItemData.create("Cuchillo", "weapon", 0.1))
	bird.interact(player)
	bird.interact(player)
	check(world.drops == 1, "Bird yields raw meat once")
	var rod = ItemData.create("Caña simple", "tool_fishing", 0.3)
	player.inventory.add_item(rod)
	rod = player.inventory.items[1]
	player._select_held_item(1)
	player._is_fishing = true
	player._fishing_session = 10
	check(player._fishing_attempt_valid(10, rod, player.position), "Valid fishing attempt")
	check(not player._fishing_attempt_valid(9, rod, player.position), "Previous fishing coroutine cannot finish new session")
	check(not player._fishing_attempt_valid(10, rod, player.position + Vector3(3,0,0)), "Walking away cancels catch")
	player.is_dead = true
	check(not player._fishing_attempt_valid(10, rod, player.position), "Death prevents catch")
	player.is_dead = false
	player._select_held_item(0)
	check(not player._fishing_attempt_valid(10, rod, player.position), "Changing held object cancels catch")
	var meat = ItemData.create("Carne cruda", "food", 0.3, 1, 15.0)
	check(meat.is_perishable(), "Bird meat spoils")
	player.inventory.add_item(meat)
	player.inventory.add_item(ItemData.create("Palo afilado", "tool_spear", 0.3))
	var craft = preload("res://scripts/CraftingSystem.gd")
	check(craft.craft(craft.RECIPES[6], player.inventory), "Bird meat can be skewered for cooking")
	player.inventory.add_item(ItemData.create("Rifle", "weapon_rifle", 4.0))
	player._select_held_item(player.inventory.items.size() - 1)
	player._rifle_magazine = 0
	player._rifle_reserve_ammo = 5
	player._reload_rifle()
	check(player._is_reloading and player._rifle_magazine == 0, "Reload takes time")
	player._select_held_item(0)
	await create_timer(3.1).timeout
	check(player._rifle_magazine == 0 and player._rifle_reserve_ammo == 5, "Changing weapon cancels reload without consuming ammo")
	player._initialize_rifle_ammo()
	check(player._rifle_magazine == 5 and player._rifle_reserve_ammo == 15, "Initial ammo granted once")
	player._rifle_magazine = 0
	player._rifle_reserve_ammo = 0
	player._initialize_rifle_ammo()
	check(player._rifle_magazine == 0 and player._rifle_reserve_ammo == 0, "Exhausted ammo never refills by equipping")
	var saved := preload("res://scripts/SaveGameHooks.gd").collect_player_data(player)
	check(saved.rifle_ammo.initialized and saved.rifle_ammo.magazine == 0 and saved.rifle_ammo.reserve == 0, "Save preserves exhausted ammunition")
	world.queue_free()
	await process_frame
	print("HUNTING_FISHING: %d checks, %d failures" % [checks, failed])
	quit(1 if failed else 0)
