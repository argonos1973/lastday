extends SceneTree

# Balaclava/death-loot clothing_color regression.
#
# Bug: Item.to_dict() serializes clothing_color as [r,g,b,a] but
# _clothing_drop_color rebuilt it as Color(r,g,b) — losing alpha. A stored
# transparent [0,0,0,0] resurrected as opaque, was copied to the ground
# pickup's item_color meta, then back onto the item as clothing_color on
# pickup. The worn visual and inventory thumbnail then replaced the authored
# balaclava fabric texture with a flat material (white/flat look).
#
# Fix: texture-driven garments never honor clothing_color
# (PlayerController.clothing_accepts_color), _clothing_drop_color preserves
# alpha, and the corrupted meta stops propagating at every read/write site.
#
# Run:
#   work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . \
#     --script tools/debug/BalaclavaColorRegression.gd

class TestMain extends "res://scripts/Main.gd":
	func _ready() -> void: pass
	func _process(_d) -> void: pass
	func _settle_drop_pos(p: Vector3) -> Vector3: return p
	func _spread_overlapping_drop_pos(p: Vector3) -> Vector3: return p
	func _is_water_drop_position(_p: Vector3) -> bool: return false
	func _pos_on_rowboat_deck(_p) -> bool: return false
	func _save_world_change_silent() -> void: pass
	func _is_loot_sheltered(_p) -> bool: return false

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass

var _fail := 0
var _checks := 0
var _main: TestMain
var _actor: Actor

func ok(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_fail += 1
		push_error("FAIL: " + label)
	else:
		print("PASS: " + label)

func _collect(node: Node, out: Array) -> void:
	for c in node.get_children():
		out.append(c)
		_collect(c, out)

func _find_worn_meshes(worn_name: String) -> Array:
	var out: Array = []
	var node = _actor.third_person_model.get_node_or_null(worn_name)
	if node == null:
		return out
	_collect(node, out)
	if node is MeshInstance3D:
		out.push_front(node)
	return out

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_main = TestMain.new()
	root.add_child(_main)
	_main.net = null
	_actor = Actor.new()
	root.add_child(_actor)
	_actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	_actor.inventory = preload("res://scripts/Inventory.gd").new()
	_actor.add_child(_actor.inventory)
	_actor.setup_as_puppet()
	await process_frame
	await process_frame

	# --- 1. clothing_accepts_color table -----------------------------------
	ok(not PlayerController.clothing_accepts_color("Pasamontañas"), "balaclava rejects color")
	ok(not PlayerController.clothing_accepts_color("Pasamontañas navideño"), "xmas balaclava rejects color")
	ok(not PlayerController.clothing_accepts_color("Casco militar"), "helmet rejects color")
	ok(not PlayerController.clothing_accepts_color("Sombrero de pescador"), "fisherman hat rejects color")
	ok(not PlayerController.clothing_accepts_color("Chaqueta de cuadros"), "plaid jacket rejects color (authored texture)")
	ok(not PlayerController.clothing_accepts_color("Gorra militar"), "autumn hat rejects color")
	ok(not PlayerController.clothing_accepts_color("Chaleco táctico"), "plate carrier rejects color")
	ok(not PlayerController.clothing_accepts_color("Chaqueta de otoño"), "autumn jacket rejects color")
	ok(PlayerController.clothing_accepts_color("Camiseta"), "Camiseta accepts color")
	ok(PlayerController.clothing_accepts_color("Pantalones militares"), "soldier legs accept color")
	ok(PlayerController.clothing_accepts_color("Guantes militares"), "cloth hands accept color")
	ok(PlayerController.clothing_accepts_color("Chaqueta de piel"), "tinted fur jacket accepts color")
	ok(PlayerController.clothing_accepts_color("Gorro de piel"), "tinted CLOTHING_VISUALS entry accepts color")
	ok(PlayerController.clothing_accepts_color("Pantalones camuflaje"), "camo entry accepts color")

	# --- 2. _clothing_drop_color -------------------------------------------
	var pdata := {}
	var c1: Color = _main._clothing_drop_color("Pasamontañas", pdata, {"clothing_color": [0.0, 0.0, 0.0, 0.0]})
	ok(c1.a <= 0.0, "death-loot color for stored transparent balaclava stays transparent (got %s)" % c1)
	var c2: Color = _main._clothing_drop_color("Pasamontañas", pdata, {"clothing_color": [1.0, 1.0, 1.0, 1.0]})
	ok(c2.a <= 0.0, "death-loot color for stored WHITE balaclava is purged (got %s)" % c2)
	var c3: Color = _main._clothing_drop_color("Camiseta", pdata, {"clothing_color": [0.2, 0.3, 0.4, 0.0]})
	ok(c3.a <= 0.0, "Camiseta array keeps alpha 0 (got %s)" % c3)
	var c4: Color = _main._clothing_drop_color("Camiseta", pdata, {"clothing_color": [0.2, 0.3, 0.4, 1.0]})
	ok(c4.a > 0.9 and absf(c4.r - 0.2) < 0.01, "Camiseta array keeps its dye (got %s)" % c4)
	var c5: Color = _main._clothing_drop_color("Camiseta", {"top_color": Color(0.9, 0.1, 0.1)}, {})
	ok(c5.r > 0.8, "Camiseta falls back to victim pdata color (got %s)" % c5)

	# --- 3. Corrupted item: worn visual keeps texture ----------------------
	var item = preload("res://scripts/Item.gd").create("Pasamontañas", "clothing", 0.25, 1, 0.0)
	item.set_meta("clothing_color", Color(1.0, 1.0, 1.0))  # corrupted death-loot meta
	_actor.inventory.add_item(item)
	var cur_col := _actor.get_current_clothing_color("Pasamontañas")
	ok(cur_col.a <= 0.0, "get_current_clothing_color ignores corrupted balaclava meta (got %s)" % cur_col)
	# A legit dye on Camiseta still works
	var top_item = preload("res://scripts/Item.gd").create("Camiseta", "clothing", 0.3, 1, 0.0)
	top_item.set_meta("clothing_color", Color(0.9, 0.8, 0.1))
	_actor.inventory.add_item(top_item)
	var top_col := _actor.get_current_clothing_color("Camiseta")
	ok(top_col.r > 0.8, "Camiseta keeps its stored dye (got %s)" % top_col)

	_actor.equip_clothing("Pasamontañas", item.get_meta("clothing_color"), item)
	await process_frame
	var worn_meshes := _find_worn_meshes("Worn_Pasamontañas")
	ok(not worn_meshes.is_empty(), "worn balaclava visual spawned")
	var _tex_ok := false
	for mi in worn_meshes:
		if mi is MeshInstance3D and mi.material_override == null:
			var m0 = mi.get_active_material(0)
			if m0 is StandardMaterial3D and m0.albedo_texture != null:
				_tex_ok = true
	ok(_tex_ok, "worn balaclava keeps authored fabric texture (no flat override)")

	# --- 4. Thumbnail colors ------------------------------------------------
	var hud = preload("res://scripts/HUD.gd").new()
	var thumb: Dictionary = hud._clothing_thumbnail_colors(item)
	ok((thumb["tint"] as Color).a <= 0.0 and (thumb["camo"] as Color).a <= 0.0, "corrupted balaclava thumbnail is texture-driven (got %s)" % thumb)
	var top_thumb: Dictionary = hud._clothing_thumbnail_colors(top_item)
	ok((top_thumb["tint"] as Color).r > 0.8, "Camiseta thumbnail keeps dye")
	hud.free()

	# --- 5. Death-loot ground pickup self-heals -----------------------------
	var dcol: Color = _main._clothing_drop_color("Pasamontañas", pdata, item.to_dict())
	_main._spawn_ground_pickup("Pasamontañas", "clothing", Vector3(3, 0.1, 3), 0.25, 1, 0.0, "death_loot_reg", "", 0.0, dcol)
	await process_frame
	var action = _main.world_actions_by_id.get("death_loot_reg")
	ok(action != null and not action.has_meta("item_color"), "ground pickup carries no item_color for balaclava")
	var picked = preload("res://scripts/Item.gd").create("Pasamontañas", "clothing", 0.25, 1, 0.0)
	if action != null and str(picked.item_type) == "clothing" and action.has_meta("item_color") and PlayerController.clothing_accepts_color("Pasamontañas"):
		picked.set_meta("clothing_color", action.get_meta("item_color"))
	ok(not picked.has_meta("clothing_color"), "picked-up balaclava is clean of clothing_color")

	# --- 6. Ground visual retains fabric texture ----------------------------
	var pickup_vis = _main.get_node_or_null("Pickup_death_loot_reg")
	if pickup_vis == null:
		var kids: Array = []
		_collect(_main, kids)
		for k in kids:
			if String(k.name).contains("death_loot_reg"):
				pickup_vis = k
	var _pickup_tex := false
	if pickup_vis != null:
		var inner: Array = []
		_collect(pickup_vis, inner)
		if pickup_vis is MeshInstance3D:
			inner.push_front(pickup_vis)
		for cc in inner:
			if cc is MeshInstance3D and cc.material_override == null:
				var sm = cc.get_active_material(0)
				if sm is StandardMaterial3D and sm.albedo_texture != null:
					_pickup_tex = true
	ok(_pickup_tex, "death-loot ground pickup renders the fabric texture")

	# --- 7. Legacy 3-element arrays also lose the bug -----------------------
	var c6: Color = _main._clothing_drop_color("Pasamontañas", pdata, {"clothing_color": [0.0, 0.0, 0.0]})
	ok(c6.a <= 0.0, "3-element balaclava array purged too (got %s)" % c6)

	print("======================================")
	print("BalaclavaColorRegression: %d checks, %d failures" % [_checks, _fail])
	if _fail == 0:
		print("ALL PASS")
	quit(1 if _fail > 0 else 0)
