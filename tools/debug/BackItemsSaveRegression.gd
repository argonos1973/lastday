extends SceneTree

const ItemScript = preload("res://scripts/Item.gd")
const SaveHooks = preload("res://scripts/SaveGameHooks.gd")

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var player := TestPlayer.new()
	root.add_child(player)
	# Store a rifle on the back — it leaves the inventory
	var rifle = ItemScript.create("Rifle francotirador", "weapon_rifle", 3.5, 1, 0.0)
	player.inventory.items.append(rifle)  # bypass capacity — we test save/load, not slots
	check(player._store_inventory_rifle_on_back(), "Rifle stores on a shoulder slot")
	check(not _inventory_has_type(player, "weapon_rifle"), "Stored rifle leaves the inventory")
	var data: Dictionary = SaveHooks.collect_player_data(player)
	var back_items: Array = data.get("back_items", [])
	check(back_items.size() == 2 and str(back_items[0].get("name", "")) == "Rifle francotirador", "Back items are serialized")
	var inventory_names := []
	for d in data.get("inventory", []):
		inventory_names.append(str(d.get("name", "")))
	check(not inventory_names.has("Rifle francotirador"), "Saved inventory does not duplicate the stored rifle")
	# Restore onto a fresh player
	var restored := TestPlayer.new()
	root.add_child(restored)
	SaveHooks.apply_saved_player_data(restored, data)
	check(restored._has_stored_back_item_type("weapon_rifle"), "Back rifle survives the load")
	check(not _inventory_has_type(restored, "weapon_rifle"), "Restored back rifle does not duplicate into inventory")
	check(restored.use_back_item(0), "Back item returns to the hands after load")
	var held = restored.get_held_item()
	check(held != null and str(held.item_name) == "Rifle francotirador", "The held item after load is the saved rifle")
	# Held back equipment is external: it leaves the inventory and its saved
	# index is -1. Saving now must keep the full payload so the next load does
	# not lose the rifle — the regression that deleted it on continue.
	var held_data: Dictionary = SaveHooks.collect_player_data(restored)
	check(str(held_data.get("held_item", "")) == "Rifle francotirador", "Held rifle is named in the save")
	check(int(held_data.get("held_index", 0)) == -1, "External held rifle saves index -1")
	var held_payload = held_data.get("held_item_data", {})
	check(held_payload is Dictionary and str(held_payload.get("type", "")) == "weapon_rifle", "Held rifle payload is serialized")
	var held_restored := TestPlayer.new()
	root.add_child(held_restored)
	SaveHooks.apply_saved_player_data(held_restored, held_data)
	var held2 = held_restored.get_held_item()
	check(held2 != null and str(held2.item_name) == "Rifle francotirador", "Externally held rifle survives the load")
	check(not _inventory_has_type(held_restored, "weapon_rifle"), "External held rifle is not duplicated into inventory")
	check(not held_restored._has_stored_back_item_type("weapon_rifle"), "External held rifle is not duplicated onto the back")
	# Legacy saves only kept the held name — the rifle must still come back.
	var legacy_held := TestPlayer.new()
	root.add_child(legacy_held)
	SaveHooks.apply_saved_player_data(legacy_held, {
		"pos": [1.0, 0.0, 2.0], "inventory": [],
		"held_item": "Rifle francotirador", "held_index": -1,
	})
	var legacy_rifle = legacy_held.get_held_item()
	check(legacy_rifle != null and str(legacy_rifle.item_name) == "Rifle francotirador", "Legacy save rebuilds the held rifle by name")
	# Old saves without back_items must not break
	var legacy := TestPlayer.new()
	root.add_child(legacy)
	SaveHooks.apply_saved_player_data(legacy, {"pos": [1.0, 0.0, 2.0], "inventory": []})
	check(not legacy._has_stored_back_item_type("weapon_rifle"), "Legacy saves without back_items load cleanly")
	player.free()
	restored.free()
	held_restored.free()
	legacy_held.free()
	legacy.free()
	if failures == 0:
		print("PASS: back-stored items survive save and load")
	quit(1 if failures else 0)

func _inventory_has_type(player: Node, item_type: String) -> bool:
	for item in player.inventory.items:
		if item != null and str(item.item_type) == item_type:
			return true
	return false
