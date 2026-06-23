extends StaticBody3D
class_name LootContainer

const ItemScript = preload("res://scripts/Item.gd")

@export var container_id := ""
@export var display_name := "Contenedor"
@export var opened := false

var loot_table := [
	{"item": ["Lata de comida", "food", 0.35, 1, 32.0], "chance": 0.18},
	{"item": ["Botella de agua", "water", 0.5, 1, 38.0], "chance": 0.16},
	{"item": ["Venda", "medical", 0.12, 1, 24.0], "chance": 0.11},
	{"item": ["Pilas", "battery", 0.08, 1, 90.0], "chance": 0.12},
	{"item": ["Comida caducada", "food", 0.32, 1, 16.0], "chance": 0.12},
	{"item": ["Agua turbia", "water", 0.45, 1, 18.0], "chance": 0.10}
]

func setup(id: String, label: String, size: Vector3, color: Color) -> void:
	container_id = id
	display_name = label
	_make_box(size, color)
	add_to_group("loot_containers")
	add_to_group("interactable")

func interact(player) -> void:
	if opened:
		player.notice.emit("%s ya esta vacio." % display_name)
		return
	opened = true
	var found := PackedStringArray()
	for entry in loot_table:
		if randf() <= float(entry["chance"]):
			var raw: Array = entry["item"]
			var item = ItemScript.create(str(raw[0]), str(raw[1]), float(raw[2]), int(raw[3]), float(raw[4]))
			if player.inventory.add_item(item):
				found.append(item.item_name)
	if found.is_empty():
		player.notice.emit("%s no tiene nada util." % display_name)
	else:
		player.notice.emit("Encontrado: %s." % ", ".join(found))

func get_interaction_text(_player = null) -> String:
	return "%s - E" % display_name

func to_dict() -> Dictionary:
	return {
		"id": container_id,
		"opened": opened
	}

func from_dict(data: Dictionary) -> void:
	opened = bool(data.get("opened", opened))

func _make_box(size: Vector3, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position.y = size.y * 0.5
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	mesh_instance.material_override = material
	add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	collision.position.y = size.y * 0.5
	add_child(collision)
