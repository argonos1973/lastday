extends SceneTree
const ItemData = preload("res://scripts/Item.gd")
class World extends "res://scripts/Main.gd":
 func _ready(): set_process(false)
 func _exit_tree(): pass
 func _save_world_change_silent(): pass
 func get_river_depth_at(_pos: Vector3) -> float: return 0.0
 func _get_exact_ground_y(_x: float, _z: float, _from_y: float = 500.0) -> float: return 0.0
class Actor extends "res://scripts/PlayerController.gd":
 func _ready(): pass
 func _process(_dt): pass
 func _physics_process(_dt): pass
 func _setup_third_person_animation(_model): pass
var errors := 0
func check(ok: bool, message: String):
 if not ok:
  errors += 1
  push_error(message)
func _initialize(): call_deferred("run")
func run():
 var world := World.new()
 root.add_child(world)
 current_scene = world
 var actor := Actor.new()
 world.add_child(actor)
 world.player = actor
 actor.stats = preload("res://scripts/SurvivalStats.gd").new()
 actor.inventory = preload("res://scripts/Inventory.gd").new()
 actor.add_child(actor.inventory)
 actor.setup_as_puppet()
 var shirt = ItemData.create("Camiseta", "clothing", 0.3, 1, 0.0)
 shirt.set_meta("clothing_camo", true)
 var restored = ItemData.from_dict(shirt.to_dict())
 check(restored.get_meta("clothing_camo", false), "Camouflage survives inventory serialization")
 actor.inventory.items.append(restored)
 actor.equip_clothing("Camiseta", Color(0.2, 0.3, 0.2), restored)
 var top: MeshInstance3D = actor._survival_body_nodes["Tops"]
 check(top.material_override.albedo_texture == preload("res://scripts/MaterialFactory.gd").CAMO_WOODLAND, "Equipped shirt retains its own camouflage")
 actor.equip_clothing("Chaqueta camuflaje", Color(0.2, 0.3, 0.2))
 var jacket: MeshInstance3D = actor._survival_cloth_nodes["soldier_torso"]
 check(jacket.material_override.albedo_texture == preload("res://scripts/MaterialFactory.gd").CAMO_WOODLAND, "Saved tint cannot erase jacket camouflage")
 check(jacket.mesh.get_aabb().position.y < 2.05, "Jacket hem overlaps trousers")
 check(jacket.material_override.grow_amount < 0.02, "Jacket is not inflated by centimetre/metre mismatch")
 actor.set_meta("last_dropped_camo", true)
 world._on_item_dropped("Pantalones", "clothing", 0.4, 1, 0.0, Vector3(3, 0, 0))
 var entry: Dictionary = world._dropped_items.back()
 check(entry.get("camo", false), "Dropped garment stores camouflage in world state")
 var action = world.world_actions_by_id[entry.id]
 check(action.get_meta("item_camo", false), "Pickup exposes camouflage for the next owner")
 var visual = world.get_node(action.get_meta("visual_name"))
 var meshes = visual.find_children("*", "MeshInstance3D", true, false)
 check(not meshes.is_empty() and meshes[0].material_override.albedo_texture == preload("res://scripts/MaterialFactory.gd").CAMO_WOODLAND, "Dropped garment displays camouflage")
 actor.third_person_hand_item_root = Node3D.new()
 actor.add_child(actor.third_person_hand_item_root)
 actor._build_third_person_rifle()
 actor.is_puppet = false
 actor.camera = Camera3D.new()
 actor.add_child(actor.camera)
 actor._is_aiming = true
 var skel := actor._find_skeleton(actor.third_person_model)
 for pitch in [-0.4, 0.0, 0.4]:
  actor.camera.rotation.x = pitch
  actor._update_rifle_ik(skel, 0.016)
  var barrel: Vector3 = (actor._rifle_muzzle.global_position - actor._rifle_stock_ref.global_position).normalized()
  check(barrel.dot(-actor.camera.global_basis.z.normalized()) > 0.999, "Rifle barrel follows sight pitch")
 actor.stats.free()
 world.free()
 print("EQUIPMENT_APPEARANCE_ERRORS=", errors)
 quit(1 if errors else 0)
