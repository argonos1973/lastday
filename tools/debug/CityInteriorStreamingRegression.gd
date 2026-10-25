extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
 if not ok: failures += 1
 print(("PASS " if ok else "FAIL ") + label)
func _initialize() -> void:
 call_deferred("run")
func run() -> void:
 var block := preload("res://scripts/CityBlock.gd").new()
 root.add_child(block)
 block.set_process(false)
 block.position = Vector3(41, 2, 700)
 block.rotation.y = .3
 var stream := preload("res://scripts/CityInteriorStreaming.gd").new()
 root.add_child(stream)
 stream.set_process(false)
 for index in [0, 3, 16]:
  var house: Node3D = block.load_building(index)
  var interior: Node3D = house.get_node("Interior")
  var meshes := interior.find_children("*", "MeshInstance3D", true, false)
  var expected: Array[AABB] = []
  for mesh in meshes:
   expected.append(mesh.global_transform * mesh.get_aabb())
  var bodies := interior.find_children("*", "CollisionObject3D", true, false)
  var transforms: Array[Transform3D] = []
  for body in bodies: transforms.append(body.global_transform)
  var door: Node3D = house.get_node(str(block.BUILDINGS[index].id) + "_door")
  door.is_open = true
  stream.register_interior(interior)
  check(interior.find_children("*", "MeshInstance3D", true, false).is_empty(), "distant visual nodes removed %d" % index)
  var entry: Dictionary = stream._entries.back()
  stream.update_observer(house.global_position + Vector3(0, 4, 0))
  check(entry.wanted, "interior requested near upper floor %d" % index)
  stream.load_visual(entry)
  var restored := interior.find_children("*", "MeshInstance3D", true, false)
  check(restored.size() == expected.size(), "all meshes restored %d" % index)
  var aligned := restored.size() == expected.size()
  for i in range(restored.size()):
   var actual: AABB = restored[i].global_transform * restored[i].get_aabb()
   aligned = aligned and actual.position.distance_to(expected[i].position) < 0.001 and actual.size.distance_to(expected[i].size) < 0.001
  check(aligned, "rotated/scaled furniture placement preserved %d" % index)
  var box: AABB = interior.global_transform * entry.bounds
  stream.update_observer(box.end + Vector3(45, 0, 0))
  check(is_instance_valid(entry.visual), "hysteresis retains loaded interior %d" % index)
  stream.update_observer(box.end + Vector3(60, 0, 0))
  check(not is_instance_valid(entry.visual), "far visual branch unloaded %d" % index)
  for i in range(bodies.size()):
   check(is_instance_valid(bodies[i]) and bodies[i].global_transform.is_equal_approx(transforms[i]), "collision/interaction identity and position retained")
  check(door.is_open and door.get_parent() == house, "door state and hierarchy retained %d" % index)
  var beds := interior.find_children("BedInteractable", "Area3D", true, false)
  check(not beds.is_empty() and beds[0].is_in_group("interactable"), "sleep interaction retained %d" % index)
  stream.update_observer(house.global_position)
  stream.load_visual(entry)
  check(interior.find_children("*", "MeshInstance3D", true, false).size() == expected.size(), "second approach no missing/duplicate props %d" % index)
 stream.queue_free()
 block.queue_free()
 await process_frame
 print("CityInteriorStreamingRegression failures=", failures)
 quit(1 if failures else 0)
