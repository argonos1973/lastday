extends Resource
class_name ItemResource

@export var item_name := ""
@export_enum("food", "water", "medicine", "weapon", "ammo", "tool", "clothing", "backpack", "misc") var item_type := "misc"
@export var weight := 0.1
@export var quantity := 1
@export var max_stack := 1
@export var icon: Texture2D
@export_multiline var description := ""
@export var usable := false
@export var equipable := false
@export var use_value := 0.0

@export_group("Clothing")
@export var clothing_slot := ""
@export var warmth := 0.0
@export var water_resistance := 0.0
@export var storage_bonus := 0
@export var condition := 100.0

@export_group("Weapon")
@export var damage := 0.0
@export var range := 1.6
@export var durability := 100.0
@export var noise := 0.0
@export var ammo_type := ""
@export var magazine_size := 0
@export var reload_time := 0.0

func duplicate_stack(amount := -1) -> ItemResource:
	var copy := duplicate(true) as ItemResource
	if amount >= 0:
		copy.quantity = amount
	return copy

func can_stack_with(other: ItemResource) -> bool:
	if other == null:
		return false
	return item_name == other.item_name and item_type == other.item_type and max_stack > 1

func get_total_weight() -> float:
	return weight * float(quantity)

func to_dict() -> Dictionary:
	return {
		"item_name": item_name,
		"item_type": item_type,
		"weight": weight,
		"quantity": quantity,
		"max_stack": max_stack,
		"description": description,
		"usable": usable,
		"equipable": equipable,
		"use_value": use_value,
		"clothing_slot": clothing_slot,
		"warmth": warmth,
		"water_resistance": water_resistance,
		"storage_bonus": storage_bonus,
		"condition": condition,
		"damage": damage,
		"range": range,
		"durability": durability,
		"noise": noise,
		"ammo_type": ammo_type,
		"magazine_size": magazine_size,
		"reload_time": reload_time
	}

static func from_dict(data: Dictionary) -> ItemResource:
	var item := ItemResource.new()
	item.item_name = str(data.get("item_name", ""))
	item.item_type = str(data.get("item_type", "misc"))
	item.weight = float(data.get("weight", 0.1))
	item.quantity = int(data.get("quantity", 1))
	item.max_stack = int(data.get("max_stack", 1))
	item.description = str(data.get("description", ""))
	item.usable = bool(data.get("usable", false))
	item.equipable = bool(data.get("equipable", false))
	item.use_value = float(data.get("use_value", 0.0))
	item.clothing_slot = str(data.get("clothing_slot", ""))
	item.warmth = float(data.get("warmth", 0.0))
	item.water_resistance = float(data.get("water_resistance", 0.0))
	item.storage_bonus = int(data.get("storage_bonus", 0))
	item.condition = float(data.get("condition", 100.0))
	item.damage = float(data.get("damage", 0.0))
	item.range = float(data.get("range", 1.6))
	item.durability = float(data.get("durability", 100.0))
	item.noise = float(data.get("noise", 0.0))
	item.ammo_type = str(data.get("ammo_type", ""))
	item.magazine_size = int(data.get("magazine_size", 0))
	item.reload_time = float(data.get("reload_time", 0.0))
	return item
