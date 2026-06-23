extends "res://scripts/EquippableItem.gd"
class_name BackpackItem

func _ready() -> void:
	item_name = "Mochila"
	item_type = "backpack"
	can_be_equipped = true
	can_be_taken_to_hands = false
	equipment_slot = "backpack"
	pickup_text = "Equipar Mochila"
	super._ready()
