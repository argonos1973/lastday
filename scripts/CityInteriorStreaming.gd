extends Node3D
## Only static interior visuals stream. Persistent anchors retain collisions,
## interaction areas and node paths; shared mesh/material resources stay cached.
const LOAD_DISTANCE := 35.0
const UNLOAD_DISTANCE := 55.0
var _entries: Array[Dictionary] = []
var _timer := 0.2

func register_interior(interior: Node3D) -> void:
 var visuals := Node3D.new()
 visuals.name = "StreamedVisuals"
 var meshes: Array[MeshInstance3D] = []
 var bounds := AABB()
 var first := true
 for node in interior.find_children("*", "MeshInstance3D", true, false):
  var mesh := node as MeshInstance3D
  # Animated meshes need their original hierarchy and are never detached.
  if mesh.mesh == null or mesh.skin != null or mesh.get_script() != null:
   continue
  var copy := mesh.duplicate(0) as MeshInstance3D
  for child in copy.get_children():
   copy.remove_child(child)
   child.free()
  copy.transform = interior.global_transform.affine_inverse() * mesh.global_transform
  copy.visible = mesh.is_visible_in_tree()
  # The whole interior now has a distance budget, not individual prop origins.
  copy.visibility_range_end = 0.0
  copy.visibility_range_end_margin = 0.0
  visuals.add_child(copy)
  copy.owner = visuals
  var box := copy.transform * mesh.get_aabb()
  bounds = box if first else bounds.merge(box)
  first = false
  meshes.append(mesh)
 if meshes.is_empty():
  visuals.free()
  return
 var packed := PackedScene.new()
 if packed.pack(visuals) != OK:
  visuals.free()
  return
 visuals.free()
 # Replace mesh nodes with transform anchors without touching their children.
 # This includes GLBs that have collision bodies parented under the mesh.
 for mesh in meshes:
  var anchor := Node3D.new()
  anchor.name = mesh.name
  anchor.transform = mesh.transform
  anchor.visible = mesh.visible
  mesh.replace_by(anchor)
  mesh.free()
 _entries.append({"anchor": interior, "scene": packed, "bounds": bounds,
  "visual": null, "wanted": false, "distance": INF})

func _process(delta: float) -> void:
 var camera := get_viewport().get_camera_3d()
 if camera == null:
  return
 _timer += delta
 if _timer >= 0.2:
  _timer = 0.0
  update_observer(camera.global_position)
 # Instantiate at most one interior per frame, nearest first after teleporting.
 var nearest: Dictionary = {}
 for entry in _entries:
  if entry.wanted and not is_instance_valid(entry.visual):
   if nearest.is_empty() or entry.distance < nearest.distance:
    nearest = entry
 if not nearest.is_empty():
  load_visual(nearest)

func update_observer(position_world: Vector3) -> void:
 for entry in _entries:
  if not is_instance_valid(entry.anchor):
   entry.wanted = false
   continue
  var bounds: AABB = entry.anchor.global_transform * entry.bounds
  var nearest := position_world.clamp(bounds.position, bounds.end)
  entry.distance = position_world.distance_to(nearest)
  var loaded := is_instance_valid(entry.visual)
  entry.wanted = entry.distance <= (UNLOAD_DISTANCE if loaded else LOAD_DISTANCE)
  if loaded and not entry.wanted:
   # No gameplay node is a child of this branch.
   entry.visual.get_parent().remove_child(entry.visual)
   entry.visual.queue_free()
   entry.visual = null

func load_visual(entry: Dictionary) -> void:
 if not is_instance_valid(entry.anchor) or is_instance_valid(entry.visual):
  return
 var visual: Node3D = entry.scene.instantiate()
 entry.anchor.add_child(visual)
 entry.visual = visual
