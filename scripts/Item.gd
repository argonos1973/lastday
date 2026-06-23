extends Resource
class_name Item

@export var item_name := ""
@export var item_type := ""
@export var weight := 0.0
@export var quantity := 1
@export var use_value := 0.0

static func create(new_name: String, new_type: String, new_weight: float, new_quantity := 1, new_use_value := 0.0):
	var item = load("res://scripts/Item.gd").new()
	item.item_name = new_name
	item.item_type = new_type
	item.weight = new_weight
	item.quantity = new_quantity
	item.use_value = new_use_value
	return item

func duplicate_stack():
	return load("res://scripts/Item.gd").create(item_name, item_type, weight, quantity, use_value)

func can_stack_with(other) -> bool:
	return other != null and item_name == other.item_name and item_type == other.item_type and use_value == other.use_value

func to_dict() -> Dictionary:
	return {
		"name": item_name,
		"type": item_type,
		"weight": weight,
		"quantity": quantity,
		"use_value": use_value
	}

static func from_dict(data: Dictionary):
	return load("res://scripts/Item.gd").create(
		str(data.get("name", "")),
		str(data.get("type", "")),
		float(data.get("weight", 0.0)),
		int(data.get("quantity", 1)),
		float(data.get("use_value", 0.0))
	)
