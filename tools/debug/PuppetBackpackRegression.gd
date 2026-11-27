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
	# Visible long equipment on the shoulders is also public sync state. A bot
	# or human using food/tools can therefore keep its rifle visible on the back
	# instead of appearing unarmed whenever it leaves the hands.
	puppet.puppet_apply_visuals("", "Hacha", "")
	puppet.puppet_apply_back_items([
		{"name": "Fusil de asalto", "type": "weapon_rifle"},
		{"name": "Arco reforzado", "type": "weapon_bow"},
	])
	await process_frame
	var back_rifle: Node3D = puppet._stored_back_visuals[0]
	var back_bow: Node3D = puppet._stored_back_visuals[1]
	check(is_instance_valid(back_rifle) and back_rifle.is_visible_in_tree(),
		"synced rifle appears on the remote puppet shoulder")
	check(is_instance_valid(back_bow) and back_bow.is_visible_in_tree(),
		"synced bow appears on the other remote puppet shoulder")
	# Unchanged packets do not rebuild the models every network tick.
	puppet.puppet_apply_back_items([
		{"name": "Fusil de asalto", "type": "weapon_rifle"},
		{"name": "Arco reforzado", "type": "weapon_bow"},
	])
	await process_frame
	check(puppet._stored_back_visuals[0] == back_rifle and puppet._stored_back_visuals[1] == back_bow,
		"unchanged shoulder sync does not rebuild visuals")
	# A model rebuild/wipe is self-healed on the next packet with the same data.
	back_rifle.free()
	puppet.puppet_apply_back_items([
		{"name": "Fusil de asalto", "type": "weapon_rifle"},
		{"name": "Arco reforzado", "type": "weapon_bow"},
	])
	await process_frame
	check(is_instance_valid(puppet._stored_back_visuals[0]),
		"wiped shoulder rifle visual is rebuilt from the same sync state")
	# Backpack refreshes coexist with those shoulder visuals instead of wiping
	# them for a frame whenever the backpack state is rebuilt.
	puppet.puppet_apply_back_items([
		{"name": "Fusil de asalto", "type": "weapon_rifle"},
		{},
	])
	puppet.puppet_apply_visuals("", "Hacha", "Mochila")
	await process_frame
	check(is_instance_valid(puppet._stored_back_visuals[0]),
		"backpack rebuild preserves the synced shoulder rifle")
	# Clearing the public state removes the shoulder equipment.
	puppet.puppet_apply_back_items([{}, {}])
	await process_frame
	check(puppet._stored_back_visuals[0] == null and puppet._stored_back_visuals[1] == null,
		"cleared shoulder sync removes remote back weapons")

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
