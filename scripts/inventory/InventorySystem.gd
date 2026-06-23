extends Node
class_name InventorySystem

signal changed
signal item_used(item: ItemResource)
signal item_equipped(item: ItemResource)
signal message(text: String)

@export var base_slots := 8
@export var base_weight := 12.0

var items: Array[ItemResource] = []
var equipped := {
	"head": null,
	"torso": null,
	"legs": null,
	"feet": null,
	"hands": null,
	"backpack": null,
	"vest": null,
	"weapon": null,
	"tool": null
}

func add_item(item: ItemResource) -> bool:
	if item == null or item.quantity <= 0:
		return false
	if get_total_weight() + item.get_total_weight() > get_max_weight():
		message.emit("Demasiado peso.")
		return false
	var remaining := item.quantity
	for existing in items:
		if remaining <= 0:
			break
		if existing.can_stack_with(item) and existing.quantity < existing.max_stack:
			var room := existing.max_stack - existing.quantity
			var moved: int = min(room, remaining)
			existing.quantity += moved
			remaining -= moved
	while remaining > 0:
		if items.size() >= get_max_slots():
			message.emit("No queda espacio.")
			changed.emit()
			return false
		var stack_size: int = min(item.max_stack, remaining)
		items.append(item.duplicate_stack(stack_size))
		remaining -= stack_size
	changed.emit()
	return true

func remove_index(index: int, amount := 1) -> ItemResource:
	if index < 0 or index >= items.size():
		return null
	var source := items[index]
	var taken: int = min(amount, source.quantity)
	var removed := source.duplicate_stack(taken)
	source.quantity -= taken
	if source.quantity <= 0:
		items.remove_at(index)
	changed.emit()
	return removed

func drop_index(index: int) -> ItemResource:
	return remove_index(index, 999999)

func use_index(index: int, stats: PlayerStats) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item := items[index]
	if item.equipable:
		return equip_index(index)
	if not item.usable:
		message.emit("No se puede usar ahora.")
		return false
	match item.item_type:
		"food":
			if stats != null:
				stats.consume_food(item.use_value)
			remove_index(index)
		"water":
			if stats != null:
				stats.consume_water(item.use_value)
			remove_index(index)
		"medicine":
			if stats != null:
				stats.heal(item.use_value)
				if item.item_name.to_lower().find("venda") >= 0:
					stats.stop_bleeding()
			remove_index(index)
		_:
			message.emit("No tiene efecto.")
			return false
	item_used.emit(item)
	return true

func equip_index(index: int) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item := items[index]
	if not item.equipable:
		message.emit("No se puede equipar.")
		return false
	var slot := _slot_for_item(item)
	if slot.is_empty():
		message.emit("No tiene ranura de equipo.")
		return false
	equipped[slot] = item
	item_equipped.emit(item)
	message.emit("Equipado: %s." % item.item_name)
	changed.emit()
	return true

func get_equipped_warmth() -> float:
	var total := 0.0
	for item in equipped.values():
		if item is ItemResource:
			total += item.warmth * clamp(item.condition / 100.0, 0.0, 1.0)
	return total

func get_max_slots() -> int:
	var slots := base_slots
	for item in equipped.values():
		if item is ItemResource:
			slots += item.storage_bonus
	return max(base_slots, slots)

func get_max_weight() -> float:
	return base_weight + float(max(0, get_max_slots() - base_slots)) * 0.75

func get_total_weight() -> float:
	var total := 0.0
	for item in items:
		total += item.get_total_weight()
	return total

func to_array() -> Array:
	var data := []
	for item in items:
		data.append(item.to_dict())
	return data

func from_array(data: Array) -> void:
	items.clear()
	for raw in data:
		if raw is Dictionary:
			items.append(ItemResource.from_dict(raw))
	changed.emit()

func _slot_for_item(item: ItemResource) -> String:
	if item.item_type == "clothing":
		return item.clothing_slot
	if item.item_type == "backpack":
		return "backpack"
	if item.item_type == "weapon":
		return "weapon"
	if item.item_type == "tool":
		return "tool"
	return ""
