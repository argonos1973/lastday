extends "res://scripts/EquippableItem.gd"
class_name WorldItem

func _ready() -> void:
	can_be_equipped = false
	can_be_taken_to_hands = true
	super._ready()
