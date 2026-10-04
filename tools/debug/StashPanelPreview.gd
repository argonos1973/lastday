extends SceneTree

# Preview visual del panel de alijo (refugio/mochila): thumbnails 3D,
# estado por objeto y leyenda de cierre. Uso:
#   Godot --path . --script tools/debug/StashPanelPreview.gd
# (sin --headless: hace falta render real para los thumbnails)

const ItemScript = preload("res://scripts/Item.gd")

class TestPlayer extends "res://scripts/PlayerController.gd":
	func _create_body() -> void:
		pass
	func _capture_mouse() -> void:
		pass

class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _save_world_change_silent() -> void:
		pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	var hud = load("res://scripts/HUD.gd").new()
	root.add_child(hud)
	world.hud = hud
	var player := TestPlayer.new()
	root.add_child(player)
	world.player = player
	player._initializing = false

	# Inventario variado para la seccion "Meter".
	player.inventory.add_item(ItemScript.create("Palo", "resource", 0.3, 4, 0.0))
	var axe = ItemScript.create("Hacha", "tool_axe", 1.2, 1, 0.0)
	axe.durability = 34.0
	player.inventory.add_item(axe)
	var wet = ItemScript.create("Chaqueta camuflaje", "clothing", 1.1, 1, 0.2)
	wet.wetness = 0.9
	player.inventory.add_item(wet)

	# Alijo de refugio con contenido variado (comida, casco, ropa mojada).
	var action = world._create_world_action("stash_prev", "shelter", "Refugio", Vector3.ZERO, Vector3.ONE, Color.WHITE, false, false)
	action.display_name = "Refugio"
	var meat = ItemScript.create("Carne cruda de ciervo", "food", 0.5, 1, 0.0)
	meat.spoilage = 62.0
	var casco = ItemScript.create("Casco militar", "clothing", 0.9, 1, 0.05)
	var lata = ItemScript.create("Lata de atun", "food", 0.3, 2, 0.0)
	var rotten = ItemScript.create("Higo", "food", 0.1, 3, 0.0)
	rotten.spoilage = 100.0
	var worn = ItemScript.create("Guantes militares", "clothing", 0.4, 1, 0.1)
	worn.durability = 22.0
	worn.wetness = 0.6
	action.set_meta("contents", [meat.to_dict(), casco.to_dict(), lata.to_dict(), rotten.to_dict(), worn.to_dict()])

	world._backpack_action = action
	world._refresh_backpack_ui()

	# Deja renderizar el panel y los thumbnails antes de capturar.
	for i in range(12):
		await process_frame
	var img := root.get_texture().get_image()
	img.save_png("/tmp/lastday_stash_preview.png")
	print("PREVIEW_SAVED /tmp/lastday_stash_preview.png")
	quit(0)
