extends SceneTree
# Real integration test: instantiate the actual PlayerController exactly as the
# game does, then exercise the survival-clothing equip path and assert the cloth
# meshes toggle visibility on the loaded player_with_clothes.glb model.

func _init() -> void:
	_run()

func _run() -> void:
	var PC = load("res://scripts/PlayerController.gd")
	var p = PC.new()
	get_root().add_child(p)
	# let _ready + deferred model load + animation setup complete
	for i in range(8):
		await process_frame
	var loaded := str(p.third_person_loaded_path)
	print("OK  loaded model = ", loaded)
	print("OK  cached cloth nodes = ", p._survival_cloth_nodes.size(), " body nodes = ", p._survival_body_nodes.size())

	var ok := true
	# torso
	p.equip_clothing("Chaqueta survival")
	var torso = p._survival_cloth_nodes.get("cloth_torso")
	var tops = p._survival_body_nodes.get("Tops")
	if torso != null and torso.visible:
		print("OK  equip Chaqueta -> cloth_torso visible")
	else:
		print("FAIL cloth_torso not visible after equip"); ok = false
	if tops != null and not tops.visible:
		print("OK  default Tops hidden")
	else:
		print("FAIL Tops still visible"); ok = false

	p.equip_clothing("Vaqueros survival")
	var legs = p._survival_cloth_nodes.get("cloth_legs")
	if legs != null and legs.visible:
		print("OK  equip Vaqueros -> cloth_legs visible")
	else:
		print("FAIL cloth_legs not visible"); ok = false

	p.equip_clothing("Botas survival")
	var feet = p._survival_cloth_nodes.get("cloth_feet")
	if feet != null and feet.visible:
		print("OK  equip Botas -> cloth_feet visible")
	else:
		print("FAIL cloth_feet not visible"); ok = false

	# animation present?
	var ap = p.third_person_animation_player
	if ap != null and ap.get_animation_list().size() > 0:
		print("OK  animation player has ", ap.get_animation_list().size(), " anims, idle='", p.third_person_idle_animation, "'")
	else:
		print("FAIL no animations on third person player"); ok = false

	print("==== RESULT: ", ("PASS" if ok else "FAIL"), " ====")
	quit()
