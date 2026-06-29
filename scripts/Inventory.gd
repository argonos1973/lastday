extends Node
class_name Inventory

const ItemScript = preload("res://scripts/Item.gd")

signal changed
signal item_used(message: String)

@export var max_slots := 10
@export var max_weight := 18.0
var items: Array = []

func add_item(item) -> bool:
	if item == null or item.quantity <= 0:
		return false
	if get_total_weight() + item.weight * item.quantity > max_weight:
		item_used.emit("Demasiado peso.")
		return false
	for existing in items:
		if existing.can_stack_with(item):
			existing.quantity += item.quantity
			changed.emit()
			return true
	if items.size() >= max_slots:
		item_used.emit("No queda espacio.")
		return false
	items.append(item.duplicate_stack())
	changed.emit()
	return true

func remove_index(index: int, amount := 1):
	if index < 0 or index >= items.size():
		return null
	var item = items[index]
	var removed = ItemScript.create(item.item_name, item.item_type, item.weight, min(amount, item.quantity), item.use_value)
	item.quantity -= removed.quantity
	if item.quantity <= 0:
		items.remove_at(index)
	changed.emit()
	return removed

func use_index(index: int, stats) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item = items[index]
	match item.item_type:
		"food":
			stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
			stats.health = min(stats.max_health, stats.health + max(1.0, item.use_value * 0.12))
			item_used.emit("Comida consumida. Te recuperas un poco.")
			remove_index(index)
			return true
		"water":
			stats.thirst = min(stats.max_stat, stats.thirst + item.use_value)
			if stats.thirst > 35.0:
				stats.health = min(stats.max_health, stats.health + max(0.5, item.use_value * 0.04))
			item_used.emit("Agua bebida.")
			remove_index(index)
			return true
		"medical":
			stats.health = min(stats.max_health, stats.health + item.use_value)
			item_used.emit("Venda usada.")
			remove_index(index)
			return true
		"clothing":
			if stats.has_method("equip_warmth"):
				stats.equip_warmth(item.use_value)
			item_used.emit("Te abrigas mejor.")
			return true
		"battery":
			item_used.emit("Las pilas se colocan solas al encender la linterna.")
			return false
		_:
			item_used.emit("No se puede usar ahora.")
			return false

func has_item_type(item_type: String) -> bool:
	for item in items:
		if item.item_type == item_type and item.quantity > 0:
			return true
	return false

func has_item_name(item_name: String, amount := 1) -> bool:
	return get_item_count(item_name) >= amount

func get_item_count(item_name: String) -> int:
	var total := 0
	for item in items:
		if item.item_name == item_name:
			total += item.quantity
	return total

func consume_item_name(item_name: String, amount: int) -> bool:
	if get_item_count(item_name) < amount:
		return false
	var remaining := amount
	var index := 0
	while index < items.size() and remaining > 0:
		if items[index].item_name == item_name:
			var taken: int = min(remaining, items[index].quantity)
			items[index].quantity -= taken
			remaining -= taken
			if items[index].quantity <= 0:
				items.remove_at(index)
				continue
		index += 1
	changed.emit()
	return true

func consume_one_type(item_type: String) -> bool:
	for i in range(items.size()):
		if items[i].item_type == item_type and items[i].quantity > 0:
			remove_index(i)
			return true
	return false

func get_total_weight() -> float:
	var total := 0.0
	for item in items:
		total += item.weight * item.quantity
	return total

func to_array() -> Array:
	var data := []
	for item in items:
		data.append(item.to_dict())
	return data

func from_array(data: Array) -> void:
	items.clear()
	for raw_item in data:
		if raw_item is Dictionary:
			items.append(ItemScript.from_dict(raw_item))
	changed.emit()
