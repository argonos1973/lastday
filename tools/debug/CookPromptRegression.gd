extends SceneTree

class FakeItem:
	var item_name := ""
	var item_type := "food"
	func _init(n := "") -> void:
		item_name = n

class FakeInventory:
	var items: Array = []
	func has_item_name(n: String, _qty: int = 1) -> bool:
		for it in items:
			if it != null and it.item_name == n:
				return true
		return false

class FakePlayer extends CharacterBody3D:
	var inventory = FakeInventory.new()
	var held = null
	func get_held_item():
		return held

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await physics_frame
	var action := WorldAction.new()
	root.add_child(action)
	action.setup("cf1", "cook", "Fogata encendida", Vector3(1.2, 0.8, 1.2), Color(0.12, 0.08, 0.04), true, false)
	var player := FakePlayer.new()
	root.add_child(player)
	# Holding the skewer -> cook prompt
	player.held = FakeItem.new("Carne ensartada")
	check(action.get_interaction_text(player).contains("Cocinar carne ensartada"), "Cook prompt while holding skewer")
	player.held = FakeItem.new("Pez ensartado")
	check(action.get_interaction_text(player).contains("Cocinar pez ensartado"), "Cook prompt while holding fish skewer")
	# Skewer in inventory but not in hand -> still shows an indication
	player.held = FakeItem.new("Palo afilado")
	player.inventory.items = [FakeItem.new("Carne ensartada")]
	var hint := action.get_interaction_text(player)
	check(not hint.is_empty() and hint.contains("[F]"), "Indication shown when skewer is only in inventory")
	# No skewer anywhere -> hint instead of silence
	player.held = null
	player.inventory.items = []
	hint = action.get_interaction_text(player)
	check(not hint.is_empty() and hint.contains("ensartad"), "Lit campfire always shows a hint")
	# While cooking the campfire stays silent (the countdown informs instead)
	action.set_meta("cooking", true)
	check(action.get_interaction_text(player).is_empty(), "No prompt while cooking is in progress")
	action.set_meta("cooking", false)
	check(not action.get_interaction_text(player).is_empty(), "Prompt returns after cooking ends")
	# Sharpened stick must not look like a knife in drops/inventory
	var world = load("res://scripts/Main.gd").new()
	var paths = world._get_drop_model_paths("Palo afilado", "tool_spear")
	world.free()
	check(paths.size() > 0 and not str(paths[0]).contains("Knife"), "Sharpened stick uses a stick model, not the knife")
	if failures == 0:
		print("PASS: cook prompts and sharpened-stick icon")
	quit(1 if failures else 0)
