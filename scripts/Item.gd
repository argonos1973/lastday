extends Resource
class_name Item

@export var item_name := ""
@export var item_type := ""
@export var weight := 0.0
@export var quantity := 1
@export var use_value := 0.0
@export var durability := 100.0
@export var max_durability := 100.0
@export var storage_capacity := 0
var spoilage := 0.0
var spoilage_rate := 0.0

const PERISHABLE_FOODS := {
	"Carne cruda de lobo": 0.5,
	"Carne asada en palo": 0.3,
	"Carne ensartada": 0.4,
	"Naranja": 0.25,
	"Higo": 0.25,
	"Bayas silvestres": 0.35,
	"Seta amanita": 0.3,
	"Seta boletus": 0.3,
	"Seta champinon": 0.3,
	"Carne humana": 0.6,
}

const CLOTHING_STORAGE := {
	"Camiseta": 2,
	"Pantalones": 3,
	"Zapatillas": 0,
	"Guantes survival": 1,
	"Botas survival": 0,
	"Pantalones militares": 4,
	"Guantes militares": 1,
	"Pantalones militares azules": 4,
	"Pantalones militares negros II": 4,
	"Pantalones camuflaje": 4,
	"Pantalones camuflaje desert": 4,
	"Guantes de trabajo": 1,
	"Sombrero de pescador": 1,
}

static func create(new_name: String, new_type: String, new_weight: float, new_quantity := 1, new_use_value := 0.0):
	var item = load("res://scripts/Item.gd").new()
	item.item_name = new_name
	item.item_type = new_type
	item.weight = new_weight
	item.quantity = new_quantity
	item.use_value = new_use_value
	if new_type == "clothing" and CLOTHING_STORAGE.has(new_name):
		item.storage_capacity = CLOTHING_STORAGE[new_name]
	return item

func duplicate_stack():
	var dup = load("res://scripts/Item.gd").create(item_name, item_type, weight, quantity, use_value)
	dup.durability = durability
	dup.max_durability = max_durability
	dup.storage_capacity = storage_capacity
	dup.spoilage = spoilage
	dup.spoilage_rate = spoilage_rate
	for key in get_meta_list():
		dup.set_meta(key, get_meta(key))
	return dup

func can_stack_with(other) -> bool:
	if other == null or item_name != other.item_name or item_type != other.item_type or use_value != other.use_value:
		return false
	if is_perishable() and absf(spoilage - other.spoilage) > 5.0:
		return false
	return true

func to_dict() -> Dictionary:
	var d := {
		"name": item_name,
		"type": item_type,
		"weight": weight,
		"quantity": quantity,
		"use_value": use_value,
		"durability": durability,
		"max_durability": max_durability,
		"storage_capacity": storage_capacity
	}
	if is_perishable():
		d["spoilage"] = spoilage
	if has_meta("clothing_color"):
		var c: Color = get_meta("clothing_color")
		d["clothing_color"] = [c.r, c.g, c.b, c.a]
	return d

static func from_dict(data: Dictionary):
	var item = load("res://scripts/Item.gd").create(
		str(data.get("name", "")),
		str(data.get("type", "")),
		float(data.get("weight", 0.0)),
		int(data.get("quantity", 1)),
		float(data.get("use_value", 0.0))
	)
	item.durability = float(data.get("durability", 100.0))
	item.max_durability = float(data.get("max_durability", 100.0))
	item.storage_capacity = int(data.get("storage_capacity", 0))
	item.spoilage = float(data.get("spoilage", 0.0))
	if item.item_type == "clothing" and item.storage_capacity == 0 and CLOTHING_STORAGE.has(item.item_name):
		item.storage_capacity = CLOTHING_STORAGE[item.item_name]
	if data.has("clothing_color"):
		var c_arr = data["clothing_color"]
		if c_arr is Array and c_arr.size() >= 3:
			item.set_meta("clothing_color", Color(float(c_arr[0]), float(c_arr[1]), float(c_arr[2]), float(c_arr[3]) if c_arr.size() > 3 else 1.0))
	return item

func is_broken() -> bool:
	return durability <= 0.0

func reduce_durability(amount: float) -> void:
	durability = max(0.0, durability - amount)

func durability_pct() -> float:
	if max_durability <= 0.0:
		return 1.0
	return durability / max_durability

func is_perishable() -> bool:
	if item_type != "food":
		return false
	if item_name.begins_with("Lata de "):
		return false
	return PERISHABLE_FOODS.has(item_name)

func get_spoilage_rate() -> float:
	if not is_perishable():
		return 0.0
	return PERISHABLE_FOODS[item_name]

func spoil_state() -> int:
	# 0 = fresh, 1 = edible, 2 = rotten
	if spoilage >= 100.0:
		return 2
	if spoilage >= 50.0:
		return 1
	return 0

func spoil_state_label() -> String:
	match spoil_state():
		2:
			return "PODRIDO"
		1:
			return "CADUCADO"
		_:
			return "FRESCO"

func spoil_state_color() -> Color:
	match spoil_state():
		2:
			return Color(0.8, 0.2, 0.15)
		1:
			return Color(0.92, 0.78, 0.30)
		_:
			return Color(0.5, 0.8, 0.3)

func tick_spoilage(delta: float) -> void:
	if not is_perishable():
		return
	var rate := get_spoilage_rate()
	if rate <= 0.0:
		return
	spoilage = min(100.0, spoilage + rate * delta)
