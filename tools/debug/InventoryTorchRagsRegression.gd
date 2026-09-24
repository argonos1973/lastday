extends SceneTree
# Regression: unlit torches stack, Trapos have a visible inventory icon, and
# clothing thumbnails use the same color the garment has when worn.
# Run: Godot --headless --path . --script tools/debug/InventoryTorchRagsRegression.gd

const ItemScript = preload("res://scripts/Item.gd")
const InventoryScript = preload("res://scripts/Inventory.gd")
const HUDScript = preload("res://scripts/HUD.gd")
const HudIconScript = preload("res://scripts/HudIcon.gd")
const ItemThumbnailScript = preload("res://scripts/ItemThumbnail3D.gd")

var failures := 0

func check(cond: bool, label: String) -> void:
	if cond:
		print("PASS: ", label)
	else:
		failures += 1
		print("FAIL: ", label)

func _init() -> void:
	# --- Torch stacking -------------------------------------------------------
	var crafted = ItemScript.create("Antorcha", "tool_torch", 0.3, 1, 0.0)
	crafted.durability = 600.0
	crafted.max_durability = 600.0
	var picked = ItemScript.create("Antorcha", "tool_torch", 0.3, 1, 0.0)
	picked.durability = 400.0
	picked.max_durability = 600.0
	picked.set_meta("torch_lit", false)
	check(crafted.can_stack_with(picked), "crafted torch stacks with picked-up unlit torch")
	check(picked.can_stack_with(crafted), "picked-up unlit torch stacks with crafted torch")

	var picked2 = ItemScript.create("Antorcha", "tool_torch", 0.3, 1, 0.0)
	picked2.durability = 200.0
	picked2.max_durability = 600.0
	picked2.set_meta("torch_lit", false)
	check(picked.can_stack_with(picked2), "two picked-up unlit torches stack")

	var lit = ItemScript.create("Antorcha", "tool_torch", 0.3, 1, 0.0)
	lit.durability = 500.0
	lit.max_durability = 600.0
	lit.set_meta("torch_lit", true)
	check(not lit.can_stack_with(picked), "lit torch does not stack with unlit")
	var lit2 = lit.duplicate_stack()
	check(not lit.can_stack_with(lit2), "lit torch does not stack with another lit torch")

	var inv = InventoryScript.new()
	inv.add_item(crafted)
	inv.add_item(picked)
	inv.add_item(picked2)
	check(inv.items.size() == 1, "unlit torches merge into one stack")
	if inv.items.size() == 1:
		check(int(inv.items[0].quantity) == 3, "stack keeps all units (x3)")
		check(absf(float(inv.items[0].durability) - 400.0) < 0.01, "durability merges by weighted average")
	check(inv.add_item(lit), "lit torch still fits in inventory")
	check(inv.items.size() == 2, "lit torch occupies its own slot")

	# --- Lighting a stack splits one burning unit -----------------------------
	var pc := PlayerController.new()
	pc.inventory = InventoryScript.new()
	var stack = ItemScript.create("Antorcha", "tool_torch", 0.3, 4, 0.0)
	stack.durability = 600.0
	stack.max_durability = 600.0
	pc.inventory.items.append(stack)
	pc._held_item_reference = stack
	var held = pc._split_torch_for_lighting(stack)
	check(held != stack, "lit unit is a separate item")
	check(int(stack.quantity) == 3, "unlit remainder keeps 3 units")
	check(int(held.quantity) == 1, "lit unit is a single torch")
	check(pc.get_held_item() == held, "held reference points at the lit unit")
	held.set_meta("torch_lit", true)
	check(pc.inventory.items.size() == 2, "inventory holds unlit stack plus lit unit")
	var one = ItemScript.create("Antorcha", "tool_torch", 0.3, 1, 0.0)
	one.durability = 600.0
	one.max_durability = 600.0
	pc._split_torch_for_lighting(one)
	check(int(one.quantity) == 1, "single torch is not split")
	pc.free()

	# --- Trapos icon ----------------------------------------------------------
	var hud := HUDScript.new()
	root.add_child(hud)
	var rags = ItemScript.create("Trapos", "resource", 0.05, 2, 0.0)
	check(hud._item_icon_shape(rags) == "cloth", "Trapos use the cloth icon shape")
	var rag_color: Color = hud._item_thumbnail_color(rags)
	check(rag_color.v > 0.3, "Trapos thumbnail color is light enough to be seen")
	var icon := HudIconScript.new()
	icon.set_shape(hud._item_icon_shape(rags))
	icon.set_icon_color(rag_color.lightened(0.55))
	icon.size = Vector2(36, 30)
	root.add_child(icon)
	icon.queue_redraw()
	check(icon.shape == "cloth", "HudIcon accepts the cloth shape")
	icon.free()

	# --- Clothing thumbnail colors ---------------------------------------------
	var shirt = ItemScript.create("Camiseta", "clothing", 0.2, 1, 0.0)
	var worn_color := Color(0.65, 0.20, 0.15)
	shirt.set_meta("clothing_color", worn_color)
	var sc := hud._clothing_thumbnail_colors(shirt)
	check(sc["tint"] == worn_color, "Camiseta thumbnail tint equals the stored clothing color")

	var camo_pants = ItemScript.create("Pantalones camuflaje", "clothing", 0.4, 1, 0.0)
	var cp := hud._clothing_thumbnail_colors(camo_pants)
	check(cp["tint"].a == 0.0 and cp["camo"].a > 0.0, "camo pants thumbnail uses camo material")
	var looted_camo = ItemScript.create("Pantalones camuflaje", "clothing", 0.4, 1, 0.0)
	looted_camo.set_meta("clothing_color", Color(0.8, 0.7, 0.3))
	var lc := hud._clothing_thumbnail_colors(looted_camo)
	check(lc["tint"] == Color(0.8, 0.7, 0.3) and lc["camo"].a == 0.0, "loot color overrides camo like the worn path")

	var jacket = ItemScript.create("Chaqueta de campaña verde", "clothing", 0.6, 1, 0.0)
	jacket.set_meta("clothing_color", Color(1, 0, 0))
	var jc := hud._clothing_thumbnail_colors(jacket)
	check(jc["tint"].a == 0.0 and jc["camo"].a == 0.0, "field jackets keep authored materials")

	var blue_pants = ItemScript.create("Pantalones militares azules", "clothing", 0.4, 1, 0.0)
	var bp := hud._clothing_thumbnail_colors(blue_pants)
	check(bp["tint"] == Color(0.02, 0.04, 0.08), "military variant tint matches worn config")

	var plain_soldier = ItemScript.create("Pantalones militares", "clothing", 0.4, 1, 0.0)
	var ps := hud._clothing_thumbnail_colors(plain_soldier)
	check(ps["tint"] == Color(0.15, 0.18, 0.12), "plain soldier pants use the worn default green")

	# --- Thumbnail tint applied to the model ----------------------------------
	var thumb := ItemThumbnailScript.new()
	root.add_child(thumb)
	await process_frame
	thumb.set_model(["res://assets/characters/adapted/pickup_default_tops.glb"], 1.0, Vector3.ZERO, 1.0, "", worn_color)
	var found_tinted := false
	for m in thumb._model_root.find_children("*", "MeshInstance3D", true, false):
		var mat = (m as MeshInstance3D).material_override
		if mat != null and mat is StandardMaterial3D and (mat as StandardMaterial3D).albedo_color.is_equal_approx(worn_color):
			found_tinted = true
	check(found_tinted, "clothing thumbnail mesh carries the worn albedo color")
	thumb.free()
	hud.free()

	if failures == 0:
		print("ALL CHECKS PASSED")
	else:
		print("FAILURES: ", failures)
	quit(1 if failures > 0 else 0)
