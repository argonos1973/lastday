extends SceneTree

## Verifies the survival-clothing equip routing in PlayerController without a full
## player setup: loads the adapted model, runs _init_survival_clothing, then
## checks each garment shows its skinned mesh and hides the matching Mixamo mesh.

func _init() -> void:
	var ok := true
	var pc = load("res://scripts/PlayerController.gd").new()

	# load the adapted model at runtime (same as the game does)
	var path := "res://assets/characters/adapted/player_with_clothes.glb"
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(ProjectSettings.globalize_path(path), state) != OK:
		print("FAIL: could not load adapted model"); quit(1); return
	var model := doc.generate_scene(state)
	get_root().add_child(model)

	pc._init_survival_clothing(model)
	print("OK  cached cloth nodes=%d, body nodes=%d" % [
		pc._survival_cloth_nodes.size(), pc._survival_body_nodes.size()])

	# all garments hidden right after init
	for mesh_name in pc._survival_cloth_nodes:
		var mi: MeshInstance3D = pc._survival_cloth_nodes[mesh_name]
		if mi.visible:
			print("FAIL: %s should start hidden" % mesh_name); ok = false

	# equip each survival garment and verify visibility + body hiding
	var cases := {
		"Chaqueta survival": {"mesh": "cloth_torso", "hide": "Tops"},
		"Vaqueros survival": {"mesh": "cloth_legs", "hide": "Bottoms"},
		"Guantes survival": {"mesh": "cloth_hands", "hide": ""},
		"Botas survival": {"mesh": "cloth_feet", "hide": "Shoes"},
	}
	for item_name in cases:
		var c: Dictionary = cases[item_name]
		pc._wear_survival_clothing(item_name, true)
		var mi: MeshInstance3D = pc._survival_cloth_nodes.get(c["mesh"])
		if mi == null or not mi.visible:
			print("FAIL: %s -> %s not visible after equip" % [item_name, c["mesh"]]); ok = false
		else:
			print("OK  equip '%s' -> %s visible" % [item_name, c["mesh"]])
		if c["hide"] != "":
			var bn: MeshInstance3D = pc._survival_body_nodes.get(c["hide"])
			if bn != null and bn.visible:
				print("FAIL: default '%s' still visible while %s worn" % [c["hide"], item_name]); ok = false
			elif bn != null:
				print("OK  default '%s' hidden while %s worn" % [c["hide"], item_name])

	# unequip torso restores the default Tops
	pc._wear_survival_clothing("Chaqueta survival", false)
	var torso: MeshInstance3D = pc._survival_cloth_nodes.get("cloth_torso")
	var tops: MeshInstance3D = pc._survival_body_nodes.get("Tops")
	if torso != null and torso.visible:
		print("FAIL: cloth_torso still visible after unequip"); ok = false
	if tops != null and not tops.visible:
		print("FAIL: Tops not restored after unequip"); ok = false
	else:
		print("OK  unequip torso restores default Tops")

	print("\n==== RESULT: %s ====" % ("PASS" if ok else "FAIL"))
	pc.free()
	quit(0 if ok else 1)
