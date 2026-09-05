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

func merge_stacks() -> void:
	var i := 0
	while i < items.size():
		var j := i + 1
		while j < items.size():
			if items[i].can_stack_with(items[j]):
				items[i].quantity += items[j].quantity
				items.remove_at(j)
			else:
				j += 1
		i += 1
	changed.emit()

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

func _fmt_restore(old_h: float, new_h: float, old_t: float, new_t: float, old_hp: float, new_hp: float) -> String:
	var parts: Array = []
	var hd := new_h - old_h
	var td := new_t - old_t
	var hdmg := new_hp - old_hp
	if hd > 0.1:
		parts.append("Hambre +%.0f" % hd)
	if td > 0.1:
		parts.append("Sed +%.0f" % td)
	if hdmg > 0.1:
		parts.append("Salud +%.0f" % hdmg)
	if parts.is_empty():
		return ""
	return " (" + ", ".join(parts) + ")"

func use_index(index: int, stats) -> bool:
	if index < 0 or index >= items.size():
		return false
	var item = items[index]
	match item.item_type:
		"food":
			if item.item_name.begins_with("Lata de ") and item.durability > 0.0:
				item_used.emit("Necesitas abrir la lata con un cuchillo o hacha antes de comer.")
				return false
			# Spoiled food sickness check
			if item.is_perishable() and item.spoil_state() == 2 and stats.has_method("get_sick"):
				stats.get_sick(80.0)
				item_used.emit("Comes comida podrida. Te sientes muy mal del estomago.")
			elif item.is_perishable() and item.spoil_state() == 1 and stats.has_method("get_sick"):
				stats.get_sick(30.0)
				item_used.emit("Comes comida en mal estado. Te sientes mal.")
			# Overeat check: eating when already full
			if stats.hunger >= stats.max_stat - 2.0:
				stats.overeat_count += 1
				if stats.overeat_count >= 3 and stats.has_method("get_sick"):
					stats.get_sick(45.0)
					stats.overeat_count = 0
					item_used.emit("Has comido demasiado. Te sientes mal del estomago.")
				else:
					item_used.emit("No tienes mas hambre pero comes de todas formas. Te sientes pesado.")
				stats.changed.emit()
				remove_index(index)
				return true
			if item.item_name == "Carne cruda de lobo":
				var _oh: float = float(stats.hunger)
				var _ot: float = float(stats.thirst)
				var _ohp: float = float(stats.health)
				stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
				stats.thirst = min(stats.max_stat, stats.thirst + item.use_value * 0.10)
				if stats.has_method("get_sick"):
					stats.get_sick(60.0)
				stats.changed.emit()
				item_used.emit("Comes carne cruda de lobo. Te sientes mal del estomago." + _fmt_restore(_oh, float(stats.hunger), _ot, float(stats.thirst), _ohp, float(stats.health)))
				remove_index(index)
				return true
			if item.item_name == "Carne asada en palo":
				var _oh: float = float(stats.hunger)
				var _ot: float = float(stats.thirst)
				var _ohp: float = float(stats.health)
				stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
				stats.thirst = min(stats.max_stat, stats.thirst + item.use_value * 0.10)
				stats.health = min(stats.max_health, stats.health + max(5.0, item.use_value * 0.4))
				if stats.has_method("add_hot_food"):
					stats.add_hot_food(1)
				stats.changed.emit()
				item_used.emit("Comes carne asada separada del palo. Calienta tu cuerpo." + _fmt_restore(_oh, float(stats.hunger), _ot, float(stats.thirst), _ohp, float(stats.health)))
				remove_index(index)
				add_item(ItemScript.create("Palo", "material", 0.3, 1, 0.0))
				return true
			if item.item_name == "Naranja":
				var _oh: float = float(stats.hunger)
				var _ot: float = float(stats.thirst)
				var _ohp: float = float(stats.health)
				stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
				stats.thirst = min(stats.max_stat, stats.thirst + item.use_value * 0.80)
				stats.health = min(stats.max_health, stats.health + max(2.0, item.use_value * 0.2))
				stats.changed.emit()
				item_used.emit("Comes una naranja. Calma el hambre y la sed." + _fmt_restore(_oh, float(stats.hunger), _ot, float(stats.thirst), _ohp, float(stats.health)))
				remove_index(index)
				return true
			if item.item_name == "Higo":
				var _oh: float = float(stats.hunger)
				var _ot: float = float(stats.thirst)
				var _ohp: float = float(stats.health)
				stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
				stats.thirst = min(stats.max_stat, stats.thirst + item.use_value * 0.70)
				stats.health = min(stats.max_health, stats.health + max(5.0, item.use_value * 0.5))
				stats.changed.emit()
				item_used.emit("Comes un higo. Nutritivo y reconfortante." + _fmt_restore(_oh, float(stats.hunger), _ot, float(stats.thirst), _ohp, float(stats.health)))
				remove_index(index)
				return true
			if item.item_name.begins_with("Lata de "):
				var _oh: float = float(stats.hunger)
				var _ot: float = float(stats.thirst)
				var _ohp: float = float(stats.health)
				stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
				stats.thirst = min(stats.max_stat, stats.thirst + item.use_value * 0.15)
				stats.health = min(stats.max_health, stats.health + max(3.0, item.use_value * 0.35))
				stats.changed.emit()
				item_used.emit("Comes %s. Te hidrata un poco." % item.item_name + _fmt_restore(_oh, float(stats.hunger), _ot, float(stats.thirst), _ohp, float(stats.health)))
				remove_index(index)
				return true
			if item.item_name.begins_with("Seta"):
				var _oh: float = float(stats.hunger)
				var _ot: float = float(stats.thirst)
				var _ohp: float = float(stats.health)
				stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
				stats.thirst = min(stats.max_stat, stats.thirst + item.use_value * 0.30)
				stats.health = min(stats.max_health, stats.health + max(3.0, item.use_value * 0.35))
				stats.changed.emit()
				item_used.emit("Comes una seta. Humeda y nutritiva." + _fmt_restore(_oh, float(stats.hunger), _ot, float(stats.thirst), _ohp, float(stats.health)))
				remove_index(index)
				return true
			var _oh: float = float(stats.hunger)
			var _ot: float = float(stats.thirst)
			var _ohp: float = float(stats.health)
			stats.hunger = min(stats.max_stat, stats.hunger + item.use_value)
			stats.thirst = min(stats.max_stat, stats.thirst + item.use_value * 0.20)
			stats.health = min(stats.max_health, stats.health + max(3.0, item.use_value * 0.35))
			item_used.emit("Comida consumida. Te recuperas un poco." + _fmt_restore(_oh, float(stats.hunger), _ot, float(stats.thirst), _ohp, float(stats.health)))
			remove_index(index)
			return true
		"water":
			# Overdrink check: drinking when already hydrated
			if stats.thirst >= stats.max_stat - 2.0:
				stats.overdrink_count += 1
				if stats.overdrink_count >= 3 and stats.has_method("get_sick"):
					stats.get_sick(40.0)
					stats.overdrink_count = 0
					item_used.emit("Has bebido demasiado agua. Te sientes mal.")
				else:
					item_used.emit("No tienes sed pero bebes de todas formas. Te sientes hinchado.")
				stats.changed.emit()
				if item.item_name == "Botella de agua":
					return true
				remove_index(index)
				return true
			if item.item_name == "Botella de agua":
				var drink_pct := 0.25
				var remaining_pct: float = float(item.durability_pct())
				if remaining_pct <= 0.0:
					item_used.emit("La botella esta vacia.")
					return false
				var actual_drink: float = min(drink_pct, remaining_pct)
				var thirst_restore: float = float(item.use_value) * actual_drink
				var _ohp: float = float(stats.health)
				var _ot: float = float(stats.thirst)
				stats.thirst = min(stats.max_stat, stats.thirst + thirst_restore)
				if stats.thirst > 35.0:
					stats.health = min(stats.max_health, stats.health + max(2.0, thirst_restore * 0.15))
				item.reduce_durability(float(item.max_durability) * actual_drink)
				var new_pct := int(float(item.durability_pct()) * 100.0)
				var _r: String = _fmt_restore(0.0, 0.0, _ot, float(stats.thirst), _ohp, float(stats.health))
				if item.is_broken():
					item_used.emit("Bebes el ultimo agua de la botella." + _r)
					remove_index(index)
					add_item(ItemScript.create("Botella de plastico", "misc", 0.1, 1, 0.0))
				else:
					item_used.emit("Bebes agua de la botella. Queda %d%%." % new_pct + _r)
				stats.changed.emit()
				return true
			var _ot: float = float(stats.thirst)
			var _ohp: float = float(stats.health)
			stats.thirst = min(stats.max_stat, stats.thirst + item.use_value)
			if stats.thirst > 35.0:
				stats.health = min(stats.max_health, stats.health + max(2.0, item.use_value * 0.15))
			item_used.emit("Agua bebida." + _fmt_restore(0.0, 0.0, _ot, float(stats.thirst), _ohp, float(stats.health)))
			remove_index(index)
			return true
		"medical":
			var _ohp: float = float(stats.health)
			stats.health = min(stats.max_health, stats.health + item.use_value)
			item_used.emit("Venda usada." + _fmt_restore(0.0, 0.0, 0.0, 0.0, _ohp, float(stats.health)))
			remove_index(index)
			return true
		"clothing":
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
