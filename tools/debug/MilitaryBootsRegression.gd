extends SceneTree
# Military boots regression: the "Botas militares" clothing item must be wired
# into every table so it equips, previews, drops and protects bare feet like
# the survival boots. Also verifies the skinned mesh + pickup GLB exist.

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)

func run() -> void:
	var pc = load("res://scripts/PlayerController.gd")
	var mf = load("res://scripts/MaterialFactory.gd")
	var isi = load("res://scripts/InicioSaveIntegration.gd")
	var it = load("res://scripts/Item.gd")

	# --- item registration ---
	check(pc.SURVIVAL_CLOTHING.has("Botas militares"), "SURVIVAL_CLOTHING missing Botas militares")
	var cfg: Dictionary = pc.SURVIVAL_CLOTHING.get("Botas militares", {})
	check(String(cfg.get("mesh", "")) == "military_boots", "SURVIVAL_CLOTHING mesh != military_boots")
	check("Shoes" in cfg.get("hides", []), "Botas militares must hide Shoes")
	check("Desnudo_feet" in cfg.get("skin_hides", []), "Botas militares must hide Desnudo_feet")
	check("Body_feet" in cfg.get("body_hides", []), "Botas militares must hide Body_feet")
	check(pc.CLOTHING_SLOTS.get("Botas militares", "") == "feet", "CLOTHING_SLOTS feet")
	check(pc.DEFAULT_SKIN_HIDES.get("Botas militares", []) == ["Desnudo_feet"], "DEFAULT_SKIN_HIDES")
	check(pc.CLOTHING_COVERED_ZONES.get("Botas militares", []) == ["pies"], "CLOTHING_COVERED_ZONES")
	check(float(pc.CLOTHING_WARMTH.get("Botas militares", 0.0)) > 0.0, "CLOTHING_WARMTH")
	check(pc.CLOTHING_HEAT_RETENTION.has("Botas militares"), "CLOTHING_HEAT_RETENTION")

	# --- preview/save tables ---
	check(isi._SURV_CLOTH.get("Botas militares", "") == "military_boots", "_SURV_CLOTH")
	check(isi._SKIN_HIDES.get("Botas militares", []) == ["Desnudo_feet"], "_SKIN_HIDES")
	check(isi._BODY_HIDES.get("Botas militares", []) == ["Body_feet"], "_BODY_HIDES")

	# --- storage + material kind ---
	check(int(it.CLOTHING_STORAGE.get("Botas militares", -1)) == 0, "CLOTHING_STORAGE")
	check(mf.clothing_kind_for_mesh("military_boots") == "mboots", "clothing_kind_for_mesh")
	check(mf._cloth_prefix("mboots") == "garment_mboots", "_cloth_prefix")
	var mat: StandardMaterial3D = mf.make_clothing_material("mboots", Color(0.10, 0.10, 0.075))
	check(mat != null, "make_clothing_material mboots")
	if mat != null:
		check(mat.albedo_texture != null, "mboots albedo texture missing")
		check(mat.normal_texture != null, "mboots normal texture missing")
		check(mat.ao_texture != null, "mboots ao texture missing")

	# --- skinned mesh inside the character GLB ---
	var scn: Node = load("res://assets/characters/adapted/player_with_clothes.glb").instantiate()
	var mil: MeshInstance3D = null
	for mi in scn.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "military_boots":
			mil = mi
	check(mil != null, "military_boots mesh missing in player_with_clothes.glb")
	if mil != null:
		check(mil.skin != null, "military_boots not skinned")
		var arr: Array = mil.mesh.surface_get_arrays(0)
		check(arr[ArrayMesh.ARRAY_BONES] != null, "military_boots no bone indices")
		check(arr[ArrayMesh.ARRAY_WEIGHTS] != null, "military_boots no weights")
		var wgts: PackedFloat32Array = arr[ArrayMesh.ARRAY_WEIGHTS]
		var weighted := 0
		for wgt in wgts:
			if wgt > 0.0:
				weighted += 1
		check(weighted > wgts.size() * 0.3, "military_boots mostly unweighted")
		var aabb := mil.get_aabb()
		check(aabb.size.y > 0.40, "military_boots shaft too short")
		check(aabb.position.y < 0.01, "military_boots sole not at ground")
	scn.free()

	# --- rigid pickup pair for world drops ---
	var pk: Node = load("res://assets/characters/adapted/pickup_military_boots.glb").instantiate()
	var pm := 0
	var pa := AABB()
	for mi in pk.find_children("*", "MeshInstance3D", true, false):
		pm += 1
		pa = pa.merge(mi.get_aabb())
	check(pm > 0, "pickup GLB has no mesh")
	check(pa.size.x < 1.5 and pa.size.y < 1.5, "pickup GLB not meter-scale")
	pk.free()

	if failures == 0:
		print("MilitaryBoots regression: 0 failures")
	else:
		print("MilitaryBoots regression: ", failures, " failures")
	quit(1 if failures > 0 else 0)
