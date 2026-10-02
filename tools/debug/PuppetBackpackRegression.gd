extends SceneTree

const PlayerScript = preload("res://scripts/PlayerController.gd")

class FakeWorld extends Node3D:
	# The puppet's _ready runs the local-player path which touches main.hud.
	var hud = null

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := FakeWorld.new()
	root.add_child(world)
	current_scene = world
	var puppet = PlayerScript.new()
	puppet.is_puppet = true
	world.add_child(puppet)
	puppet.setup_as_puppet()
	await process_frame
	check(puppet.third_person_back_item_root != null, "puppet has a backpack socket")
	check(puppet.inventory == null and puppet.equipment == null, "puppet has no inventory/equipment (regression precondition)")
	if failures > 0:
		quit(1)
		return
	# Remote wears the inventory backpack -> BackpackAsset appears on the socket.
	puppet.puppet_apply_visuals("", "", "Mochila pequena")
	await process_frame
	var bp_root: Node3D = puppet.third_person_back_item_root
	check(bp_root.get_node_or_null("BackpackAsset") != null, "synced backpack visible on remote puppet")
	# Held-item changes in the same packet must not leave the backpack gone.
	puppet.puppet_apply_visuals("", "Cuchillo", "Mochila pequena")
	await process_frame
	check(bp_root.get_node_or_null("BackpackAsset") != null, "backpack survives held-item change")
	# Any wipe path (model rebuild, socket resync) is self-healed on the next
	# sync tick even though the synced backpack name did not change.
	var bp_asset := bp_root.get_node_or_null("BackpackAsset")
	bp_root.remove_child(bp_asset)
	bp_asset.free()
	puppet.puppet_apply_visuals("", "Cuchillo", "Mochila pequena")
	await process_frame
	check(bp_root.get_node_or_null("BackpackAsset") != null, "wiped backpack visual is rebuilt on next sync")
	# The world-pickup "Mochila" (equipment socket path) also shows remotely.
	puppet.puppet_apply_visuals("", "", "Mochila")
	await process_frame
	check(bp_root.get_node_or_null("BackpackAsset") != null, "socket backpack name also builds the visual")
	# Remote drops the backpack -> visual removed and state cleared.
	puppet.puppet_apply_visuals("", "", "")
	await process_frame
	check(bp_root.get_node_or_null("BackpackAsset") == null, "unequipped backpack removed from puppet")
	check(puppet._puppet_backpack == "" and puppet.equipped_backpack == "", "puppet backpack state cleared")
	# Local equip of the socket "Mochila" registers equipped_backpack so it
	# gains capacity and travels in sync_player_state.
	var player := PlayerScript.new()
	world.add_child(player)
	await process_frame
	check(player.equipment != null and player.inventory != null, "local player has inventory and equipment")
	var bp_item = preload("res://scripts/BackpackItem.gd").new()
	var bp_mesh := MeshInstance3D.new()
	bp_mesh.mesh = BoxMesh.new()
	bp_item.add_child(bp_mesh)
	world.add_child(bp_item)
	var cap_before: int = player._compute_carry_capacity().slots
	bp_item.interact(player)
	await process_frame
	check(player.equipped_backpack == "Mochila", "socket backpack registers equipped_backpack")
	check(player._compute_carry_capacity().slots > cap_before, "socket backpack grants carry capacity")
	world.free()
	if failures == 0:
		print("PASS: remote backpack survives sync changes, self-heals and the socket mochila syncs")
	quit(1 if failures else 0)
