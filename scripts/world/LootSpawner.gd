extends Node3D
class_name LootSpawner

@export_enum("house", "garage", "hospital", "police", "forest", "industrial") var loot_zone := "house"
@export var spawn_chance := 0.28
@export var spawn_radius := 1.2
@export var spawn_once := true

var spawned := false

func spawn_loot(table: Dictionary) -> void:
	if spawned and spawn_once:
		return
	if randf() > spawn_chance:
		return
	var entries: Array = table.get(loot_zone, [])
	if entries.is_empty():
		return
	var picked: ItemResource = _pick_weighted(entries)
	if picked == null:
		return
	var pickup := PickableItem.new()
	pickup.name = "Pickable_%s" % picked.item_name.replace(" ", "_")
	pickup.item = picked.duplicate_stack()
	pickup.position = Vector3(randf_range(-spawn_radius, spawn_radius), 0.08, randf_range(-spawn_radius, spawn_radius))
	add_child(pickup)
	_add_debug_mesh(pickup)
	spawned = true

func _pick_weighted(entries: Array) -> ItemResource:
	var total := 0.0
	for entry in entries:
		total += float(entry.get("weight", 1.0))
	var roll := randf() * max(total, 0.01)
	for entry in entries:
		roll -= float(entry.get("weight", 1.0))
		if roll <= 0.0:
			return entry.get("item", null)
	return entries.back().get("item", null)

func _add_debug_mesh(pickup: PickableItem) -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.35, 0.12, 0.22)
	mesh_instance.mesh = mesh
	mesh_instance.position.y = 0.08
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.28, 0.24, 0.16)
	material.roughness = 0.9
	mesh_instance.material_override = material
	pickup.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 0.22, 0.32)
	collision.shape = shape
	collision.position.y = 0.12
	pickup.add_child(collision)
