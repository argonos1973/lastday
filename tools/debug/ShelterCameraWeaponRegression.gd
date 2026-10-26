extends SceneTree
const ItemData = preload("res://scripts/Item.gd")
class TestPlayer extends "res://scripts/PlayerController.gd":
 func _ready() -> void: pass
 func _recalculate_carry_capacity() -> void: pass
 func _update_crosshair(_enabled: bool) -> void: pass
class TestWorld extends "res://scripts/Main.gd":
 func _ready() -> void: pass
 func _exit_tree() -> void: pass
var failures := 0
func check(ok: bool, message: String) -> void:
 if not ok: failures += 1
 print(("PASS " if ok else "FAIL ") + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var world := TestWorld.new()
 root.add_child(world)
 world.set_process(false)
 var player := TestPlayer.new()
 world.add_child(player)
 player.set_process(false)
 player.set_physics_process(false)
 player.inventory = preload("res://scripts/Inventory.gd").new()
 player.add_child(player.inventory)
 player.inventory.changed.connect(player._on_inventory_changed)
 var drops: Array = []
 player.item_dropped.connect(func(n, _t, _w, _q, _u, _p, _c, _b, _s): drops.append(n))
 for weapon in [player.RIFLE_NAME, player.M4_NAME]:
  var rifle = ItemData.create(weapon, "weapon_rifle", 3.0)
  player.receive_pickup_item(rifle)
  check(player.get_back_item_data(0).get("name") == weapon, "pickup stores " + weapon)
  player.use_back_item(0)
  var held = player.get_held_item()
  player.inventory.add_item(ItemData.create("Trapos", "resource", .05))
  check(player.get_held_item() == held, "pickup other cargo retains held weapon")
  player.drop_inventory_item(0)
  check(player.get_held_item() == held and player._held_item_external, "drop other cargo retains external weapon")
  player.store_held_on_back(0)
  player.inventory.add_item(ItemData.create("Trapos", "resource", .05))
  player.drop_inventory_item(0)
  check(player.get_back_item_data(0).get("name") == weapon, "drop other cargo retains shoulder weapon")
  player._stored_back_items[0] = null
 check(drops == ["Trapos", "Trapos", "Trapos", "Trapos"], "only requested cargo is dropped")
 var equipment := preload("res://scripts/PlayerEquipment.gd").new()
 world.add_child(equipment)
 var socket := Node3D.new()
 world.add_child(socket)
 var left := Node3D.new()
 var right := Node3D.new()
 socket.add_child(left)
 socket.add_child(right)
 equipment.register_socket("backpack", socket)
 equipment._attach_visual("backpack", "Mochila", Node3D.new())
 equipment._attach_visual("backpack", "Mochila militar", Node3D.new())
 await process_frame
 check(is_instance_valid(left) and is_instance_valid(right) and socket.get_child_count() == 3, "backpack replacement preserves both weapon visuals")
 for yaw in [0.0, PI/2.0, PI]:
  var origin := Vector3(20, 4, 30)
  var basis := Basis(Vector3.UP, yaw)
  world._built_shelters = [{"pos": origin, "yaw": yaw}]
  for z in [-1.0, 0.0, 1.0]:
   var pos := origin + basis * Vector3(0, 0, z * world.SHELTER_SCALE)
   var cam := world.constrain_shelter_camera(pos, pos + Vector3(3, 4, 5))
   var local := basis.inverse() * (cam - origin) / world.SHELTER_SCALE
   var roof := .22 + (local.z + 1.55) / 2.8 * 1.72
   check(local.y <= roof - .19 and absf(local.z-z) <= .181 and absf(local.x) <= .181, "camera stays with player below rotated shelter roof")
  var outside := origin + Vector3(10, 0, 10)
  var free_camera := outside + Vector3(0, 2, 4)
  check(world.constrain_shelter_camera(outside, free_camera) == free_camera, "outside camera remains unrestricted")
 world.queue_free()
 await process_frame
 print("ShelterCameraWeaponRegression failures=", failures)
 quit(1 if failures else 0)
