extends StaticBody3D
class_name EquippableItem

@export var item_name := "Objeto"
@export_enum("loot", "backpack", "weapon", "clothing", "door") var item_type := "loot"
@export var can_be_taken_to_hands := false
@export var can_be_equipped := true
@export_enum("backpack", "head", "chest", "primary_weapon", "secondary_weapon", "belt") var equipment_slot := "backpack"
@export_file("*.tscn", "*.glb", "*.gltf") var world_model := ""
@export_file("*.tscn", "*.glb", "*.gltf") var equipped_model := ""
@export var equipped_scene: PackedScene
@export var hands_scene: PackedScene
@export var pickup_text := ""
@export var equipped_position := Vector3.ZERO
@export var equipped_rotation := Vector3.ZERO
@export var equipped_scale := Vector3.ONE

func _ready() -> void:
	add_to_group("interactable")

func interact(player) -> void:
	if player == null:
		return
	if can_be_equipped and player.get("equipment") != null:
		var equipment = player.get("equipment")
		equipment.socket_offsets[equipment_slot] = equipped_position
		equipment.socket_rotations[equipment_slot] = equipped_rotation
		equipment.socket_scales[equipment_slot] = equipped_scale
		if equipment.has_method("equip_item") and equipment.equip_item(self):
			if player.has_signal("notice"):
				player.notice.emit("%s equipada en slot %s" % [item_name, equipment_slot])
			queue_free()
			return
		if player.has_signal("notice"):
			player.notice.emit(_blocked_text(player))
		return
	if can_be_taken_to_hands and player.get("hands") != null:
		var hands = player.get("hands")
		if hands.has_method("put_item_in_hands") and hands.put_item_in_hands(self):
			if player.has_signal("notice"):
				player.notice.emit("%s en manos." % item_name)
			queue_free()
		elif player.has_signal("notice"):
			player.notice.emit("Ya tienes un objeto en las manos")

func get_interaction_text(player = null) -> String:
	if player != null:
		if can_be_equipped:
			if player.get("equipment") != null:
				var equipment = player.get("equipment")
				if equipment.has_method("is_slot_free") and not equipment.is_slot_free(equipment_slot):
					return _blocked_text(player)
			return "Equipar %s" % item_name
		if can_be_taken_to_hands:
			if player.get("hands") != null:
				var hands = player.get("hands")
				if hands.has_method("has_item_in_hands") and hands.has_item_in_hands():
					return "Ya tienes un objeto en las manos"
			return "Coger en manos %s" % item_name
	if not pickup_text.is_empty():
		return pickup_text
	return "Recoger %s" % item_name

func _blocked_text(_player = null) -> String:
	if equipment_slot == "backpack":
		return "Ya tienes una mochila equipada"
	return "Ya tienes un objeto equipado en este slot"
