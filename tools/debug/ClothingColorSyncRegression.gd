extends SceneTree

# Remote clothing colors + remote tree depletion regression:
# - puppet_apply_visuals must tint equipped clothing with the sender's
#   per-item loot colors (synced via sync_player_state's clothing_colors arg)
# - a color-only change (same clothing names) must re-apply the tint
# - _net_world_action_completed for a never-activated tree must record the
#   depletion and hide the batched MultiMesh instance
# - _clothing_colors_from_items rebuilds aligned colors from inventory dicts
#   for offline proxy display

const PlayerScript = preload("res://scripts/PlayerController.gd")
const ItemScript = preload("res://scripts/Item.gd")
const MainScript = preload("res://scripts/Main.gd")

class FakeWorld extends Node3D:
	var hud = null

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func _tops_color(puppet) -> Color:
	var tops: MeshInstance3D = puppet._survival_body_nodes.get("Tops")
	if tops == null or tops.material_override == null:
		return Color(0, 0, 0, 0)
	return (tops.material_override as StandardMaterial3D).albedo_color

func run() -> void:
	var world := FakeWorld.new()
	root.add_child(world)
	current_scene = world
	var puppet = PlayerScript.new()
	puppet.is_puppet = true
	world.add_child(puppet)
	puppet.setup_as_puppet()
	await process_frame
	check(puppet._survival_body_nodes.has("Tops"), "puppet exposes Tops body mesh")

	# Remote player equips a red Camiseta -> puppet Tops tinted red.
	puppet.puppet_apply_visuals("Camiseta", "", "", [Color(1.0, 0.2, 0.3, 1.0)])
	await process_frame
	var red := Color(1.0, 0.2, 0.3, 1.0)
	check(_tops_color(puppet).is_equal_approx(red), "equipped clothing color applied to puppet mesh")

	# Same clothing name but a new loot color -> tint updates (re-equip).
	var green := Color(0.1, 0.8, 0.2, 1.0)
	puppet.puppet_apply_visuals("Camiseta", "", "", [green])
	await process_frame
	check(_tops_color(puppet).is_equal_approx(green), "color-only change re-applies tint")

	# No colors array (older sender / missing data) -> still equips, no crash.
	puppet.puppet_apply_visuals("Pantalones", "", "")
	await process_frame
	check(puppet._puppet_clothing == "Pantalones", "clothing applies without color payload")

	# Local player: slot-aware color lookup prefers the equipped_slot item.
	var player := PlayerScript.new()
	world.add_child(player)
	await process_frame
	check(player.inventory != null, "local player has inventory")
	var worn = ItemScript.create("Camiseta", "clothing", 0.5, 1, 0.0)
	worn.set_meta("clothing_color", Color(0.9, 0.1, 0.1, 1.0))
	worn.set_meta("equipped_slot", "torso")
	var packed = ItemScript.create("Camiseta", "clothing", 0.5, 1, 0.0)
	packed.set_meta("clothing_color", Color(0.1, 0.1, 0.9, 1.0))
	player.inventory.items.append(packed)
	player.inventory.items.append(worn)
	var slot_color: Color = player.get_current_clothing_color("Camiseta", "torso")
	check(slot_color.is_equal_approx(Color(0.9, 0.1, 0.1, 1.0)), "slot lookup returns the worn item color")

	# Main stub: remote tree depletion without a local WorldAction. Headless
	# MultiMesh buffers never materialize (transforms read back as identity),
	# so the tree entry sits at the origin and we assert the hide was recorded.
	var main = MainScript.new()
	world.add_child(main)
	var tree_pos := Vector3.ZERO
	main._tree_entries_by_id[42] = {"pos": tree_pos, "id": 42, "visual_name": "Tree_42", "active": false, "multimesh": true}
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BoxMesh.new()
	mm.instance_count = 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	world.add_child(mmi)
	main._forest_multimesh_nodes.append(mmi)
	var ok: bool = main._net_world_action_completed("fell_tree_42", [], "", Vector3.ZERO)
	check(ok, "remote fell_tree accepted without local action")
	check(main._depleted_action_ids.has("fell_tree_42"), "depletion recorded for never-activated tree")
	check(main._hidden_tree_transforms.has(Vector3.ZERO), "batched MultiMesh tree hide recorded remotely")

	# Offline proxy colors: aligned colors rebuilt from inventory dicts.
	var items_data: Array = [
		{"name": "Camiseta", "type": "clothing", "clothing_color": [0.9, 0.1, 0.1, 1.0]},
		{"name": "Pantalones", "type": "clothing", "clothing_color": [0.2, 0.2, 0.8, 1.0]},
	]
	var cols: Array = main._clothing_colors_from_items("Camiseta,Pantalones", items_data)
	check(cols.size() == 2 and (cols[0] as Color).is_equal_approx(Color(0.9, 0.1, 0.1, 1.0)), "offline clothing color for first item")
	check(cols.size() == 2 and (cols[1] as Color).is_equal_approx(Color(0.2, 0.2, 0.8, 1.0)), "offline clothing color for second item")
	var miss: Array = main._clothing_colors_from_items("Chaqueta", items_data)
	check(miss.size() == 1 and (miss[0] as Color).a <= 0.0, "missing item yields transparent color")

	world.free()
	if failures == 0:
		print("PASS: clothing colors sync to puppets and remote tree cuts hide batched instances")
	quit(1 if failures else 0)
