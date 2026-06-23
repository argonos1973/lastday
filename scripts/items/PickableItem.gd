extends StaticBody3D
class_name PickableItem

@export var item: ItemResource
@export var action_label := "Recoger"
@export var remove_on_pickup := true

func get_interaction_text(_player := null) -> String:
	if item == null:
		return ""
	return "[E] %s %s" % [action_label, item.item_name]

func interact(player: Node) -> void:
	if item == null:
		return
	var inventory = player.get("inventory") if player != null else null
	if inventory == null or not inventory.has_method("add_item"):
		return
	if inventory.add_item(item):
		if player.has_signal("notice"):
			player.notice.emit("Recoges %s." % item.item_name)
		if player.has_method("equip_item_by_name"):
			player.equip_item_by_name(item.item_name)
		if remove_on_pickup:
			queue_free()
