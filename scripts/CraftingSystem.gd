extends Node
class_name CraftingSystem

const ItemScript = preload("res://scripts/Item.gd")

# Each recipe: { "inputs": { "item_name": amount, ... }, "output": { "name": ..., "type": ..., "weight": ..., "use_value": ... }, "label": "..." }
const RECIPES := [
	{
		"inputs": { "Palo": 1, "Cuchillo": 1 },
		"output": { "name": "Palo afilado", "type": "tool_spear", "weight": 0.3, "use_value": 0.0 },
		"label": "Afilar palo con cuchillo/hacha"
	},
	{
		"inputs": { "Palo afilado": 1, "Carne cruda": 1 },
		"output": { "name": "Caña de pescar", "type": "tool_fishing", "weight": 0.4, "use_value": 0.0 },
		"label": "Crear caña de pescar con cebo"
	},
	{
		"inputs": { "Palo afilado": 1, "Piedra": 1 },
		"output": { "name": "Lanza", "type": "weapon", "weight": 0.8, "use_value": 15.0 },
		"label": "Crear lanza con punta de piedra"
	},
	{
		"inputs": { "Palo": 1, "Cuerda": 1 },
		"output": { "name": "Caña simple", "type": "tool_fishing", "weight": 0.3, "use_value": 0.0 },
		"label": "Crear caña simple"
	},
	{
		"inputs": { "Tronco": 1, "Cuchillo": 1 },
		"output": { "name": "Palo", "type": "resource", "weight": 0.15, "use_value": 0.0, "quantity": 2 },
		"label": "Tallar tronco con cuchillo/hacha para hacer 2 palos"
	},
	{
		"inputs": { "Palo afilado": 1, "Carne cruda de lobo": 1 },
		"output": { "name": "Carne ensartada", "type": "food", "weight": 0.4, "use_value": 15.0 },
		"label": "Ensartar carne de lobo en palo"
	},
	{
		"inputs": { "Palo afilado": 1, "Carne cruda": 1 },
		"output": { "name": "Carne ensartada", "type": "food", "weight": 0.5, "use_value": 20.0 },
		"label": "Ensartar carne en palo"
	},
	{
		"inputs": { "Tronco": 2, "Palo": 1 },
		"output": { "name": "Fogata", "type": "campfire", "weight": 0.0, "use_value": 0.0 },
		"label": "Construir fogata con troncos"
	},
	{
		"inputs": { "Palo": 11 },
		"output": { "name": "Refugio", "type": "shelter", "weight": 0.0, "use_value": 0.0 },
		"label": "Construir refugio con palos"
	},
	{
		"inputs": { "Palo": 1, "Trapos": 1 },
		"output": { "name": "Antorcha", "type": "tool_torch", "weight": 0.3, "use_value": 0.0, "durability": 120.0, "max_durability": 120.0 },
		"label": "Crear antorcha con palo y trapos"
	},
	{
		"inputs": { "Chaqueta militar": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 3 },
		"label": "Cortar chaqueta militar con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Chaqueta militar azul": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 3 },
		"label": "Cortar chaqueta militar azul con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Chaqueta militar negra II": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 3 },
		"label": "Cortar chaqueta militar negra con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Pantalones militares": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 2 },
		"label": "Cortar pantalones militares con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Pantalones militares azules": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 2 },
		"label": "Cortar pantalones militares azules con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Pantalones militares negros II": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 2 },
		"label": "Cortar pantalones militares negros con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Pantalones camuflaje": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 2 },
		"label": "Cortar pantalones camuflaje con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Pantalones camuflaje desert": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 2 },
		"label": "Cortar pantalones camuflaje desert con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Guantes militares": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 1 },
		"label": "Cortar guantes militares con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Camiseta": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 2 },
		"label": "Cortar camiseta con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Pantalones": 1, "Cuchillo": 1 },
		"output": { "name": "Trapos", "type": "resource", "weight": 0.05, "use_value": 0.0, "quantity": 2 },
		"label": "Cortar pantalones con cuchillo para hacer trapos"
	},
	{
		"inputs": { "Lata de guiso": 1, "Cuchillo": 1 },
		"output": { "name": "Lata de guiso abierta", "type": "food", "weight": 0.5, "use_value": 35.0, "quantity": 1, "durability": 0.0 },
		"label": "Abrir lata de guiso con cuchillo"
	},
	{
		"inputs": { "Lata de atun": 1, "Cuchillo": 1 },
		"output": { "name": "Lata de atun abierta", "type": "food", "weight": 0.3, "use_value": 18.0, "quantity": 1, "durability": 0.0 },
		"label": "Abrir lata de atun con cuchillo"
	},
	{
		"inputs": { "Lata de comida": 1, "Cuchillo": 1 },
		"output": { "name": "Lata de comida abierta", "type": "food", "weight": 0.35, "use_value": 32.0, "quantity": 1, "durability": 0.0 },
		"label": "Abrir lata de comida con cuchillo"
	},
]

# Returns all recipes that can be crafted with the given inventory items
static func get_available_recipes(inventory_items: Array) -> Array:
	var available := []
	for recipe in RECIPES:
		if _can_craft(recipe, inventory_items):
			available.append(recipe)
	return available

# Returns all recipes that use the given item name as an input
static func get_recipes_for_item(item_name: String, item_type: String = "") -> Array:
	var result := []
	for recipe in RECIPES:
		if recipe["inputs"].has(item_name):
			result.append(recipe)
		else:
			for input_name in recipe["inputs"]:
				if _is_substitute(input_name, item_name):
					result.append(recipe)
					break
				elif input_name == "ANY_CLOTHING" and item_type == "clothing":
					result.append(recipe)
					break
	return result

static func can_craft_with(recipe: Dictionary, inventory_items: Array) -> bool:
	return _can_craft(recipe, inventory_items)

static func consume_inputs(recipe: Dictionary, inventory) -> void:
	for input_name in recipe["inputs"]:
		var needed: int = recipe["inputs"][input_name]
		if _is_tool(input_name):
			continue
		if input_name == "ANY_CLOTHING":
			_consume_clothing(inventory, needed)
		else:
			inventory.consume_item_name(input_name, needed)
			inventory.changed.emit()

static func _can_craft(recipe: Dictionary, inventory_items: Array) -> bool:
	for input_name in recipe["inputs"]:
		var needed: int = recipe["inputs"][input_name]
		var have := 0
		for item in inventory_items:
			if _matches_input(input_name, item):
				have += item.quantity
		if have < needed:
			return false
	return true

static func _matches_input(input_name: String, item) -> bool:
	if input_name == "ANY_CLOTHING":
		return str(item.item_type) == "clothing"
	if str(item.item_name) == input_name or _is_substitute(input_name, str(item.item_name)):
		return true
	return false

static func craft(recipe: Dictionary, inventory) -> bool:
	if not _can_craft(recipe, inventory.items):
		return false
	# Consume inputs (tools are not consumed, only resources)
	for input_name in recipe["inputs"]:
		var needed: int = recipe["inputs"][input_name]
		# Don't consume tools (knife, etc.) but reduce their durability
		if _is_tool(input_name):
			for item in inventory.items:
				if item != null and str(item.item_name) == input_name and item.has_method("reduce_durability"):
					item.reduce_durability(3.0)
					break
			continue
		if input_name == "ANY_CLOTHING":
			_consume_clothing(inventory, needed)
		else:
			inventory.consume_item_name(input_name, needed)
	# Create output
	var out = recipe["output"]
	var qty: int = int(out.get("quantity", 1))
	var new_item = ItemScript.create(out["name"], out["type"], out["weight"], qty, out["use_value"])
	if out.has("durability"):
		new_item.durability = float(out["durability"])
		new_item.max_durability = float(out.get("max_durability", out["durability"]))
	inventory.add_item(new_item)
	return true

static func _consume_clothing(inventory, amount: int) -> void:
	var consumed := 0
	for item in inventory.items:
		if consumed >= amount:
			break
		if str(item.item_type) == "clothing":
			var take: int = min(item.quantity, amount - consumed)
			item.quantity -= take
			consumed += take
			if item.quantity <= 0:
				inventory.items.erase(item)
	inventory.changed.emit()

static func _is_tool(item_name: String) -> bool:
	return item_name in ["Cuchillo", "Hacha", "Azada", "Pala", "Martillo", "Pico", "Cerillas"]

# Returns true if 'have' can substitute for 'needed' in a recipe (e.g. Hacha for Cuchillo)
static func _is_substitute(needed: String, have: String) -> bool:
	if needed == "Cuchillo" and have == "Hacha":
		return true
	return false

static func get_recipe_label(recipe: Dictionary) -> String:
	return recipe.get("label", "Combinar")

static func get_recipe_inputs_text(recipe: Dictionary) -> String:
	var parts := []
	for input_name in recipe["inputs"]:
		var amount: int = recipe["inputs"][input_name]
		if _is_tool(input_name):
			parts.append("%s (no se gasta)" % input_name)
		elif input_name == "ANY_CLOTHING":
			parts.append("%dx Ropa (cualquiera)" % amount)
		else:
			parts.append("%dx %s" % [amount, input_name])
	return " + ".join(parts)
