extends SceneTree
## Dead-animal corpse thumbnails: 'Lobo muerto'/'Ciervo muerto'/'Zorro muerto'
## must resolve to the species model and render visible pixels through
## ItemThumbnail3D — the same component used by the survival inventory and
## the shelter/container UI. Whole-corpse drops must spawn the same model.
## Skinned GLBs (the wolf) are flattened to a static bind-pose copy inside
## ItemThumbnail3D; without that the SubViewport culls them to a blank icon.
## Run WITHOUT --headless for the pixel assertions (headless keeps the
## structural checks only).

var failures := 0
var test_world = null

class TestWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _count_meshes(node: Node) -> int:
	var n := 0
	if node is MeshInstance3D:
		n += 1
	for c in node.get_children():
		n += _count_meshes(c)
	return n

func _count_solid_pixels(img: Image) -> int:
	var n := 0
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.01:
				n += 1
	return n

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var Thumb = preload("res://scripts/ItemThumbnail3D.gd")
	test_world = TestWorld.new()
	root.add_child(test_world)
	current_scene = test_world
	var can_render := DisplayServer.get_name() != "headless"

	var cases := {
		"Lobo muerto": GameConst.WOLF_MODEL,
		"Ciervo muerto": GameConst.DEER_MODEL,
		"Zorro muerto": GameConst.FOX_MODEL,
	}
	for item_name in cases:
		var expected: String = cases[item_name]
		var paths: Array = test_world._get_drop_model_paths(item_name, "material")
		check(paths.size() > 0, "%s: no thumbnail paths" % item_name)
		check(paths.has(expected), "%s: resolved to %s, expected %s" % [item_name, str(paths), expected])
		check(ResourceLoader.exists(expected), "%s: model file missing: %s" % [item_name, expected])
		if not ResourceLoader.exists(expected):
			continue
		var ps: PackedScene = load(expected)
		check(ps != null, "%s: model failed to load" % item_name)
		if ps == null:
			continue
		var inst := ps.instantiate()
		check(_count_meshes(inst) > 0, "%s: model has no MeshInstance3D" % item_name)

		var thumb: SubViewportContainer = Thumb.new()
		thumb.custom_minimum_size = Vector2(96, 96)
		thumb.size = Vector2(96, 96)
		root.add_child(thumb)
		await process_frame
		await process_frame
		thumb.set_model(paths, 1.0)
		for i in 6:
			await process_frame
		# The skinned source meshes must be replaced by static copies so the
		# renderer does not cull the model at bind-space AABBs.
		var hidden_skinned := 0
		var flat_copies := 0
		var st := [thumb._model_root]
		while not st.is_empty():
			var n = st.pop_back()
			for c in n.get_children():
				st.append(c)
			if n is MeshInstance3D:
				if n.skin != null and not n.visible:
					hidden_skinned += 1
				elif n.skin == null and n.visible:
					flat_copies += 1
		if _count_meshes(inst) > 0:
			check(flat_copies > 0, "%s: no visible static mesh in thumbnail" % item_name)
		inst.free()

		if can_render:
			var vp: SubViewport = thumb.get_child(0)
			var img := vp.get_texture().get_image()
			check(_count_solid_pixels(img) > 50, "%s: thumbnail rendered blank" % item_name)
		thumb.queue_free()

	# 'Animal muerto' generic fallback must still resolve to a real model.
	var generic: Array = test_world._get_drop_model_paths("Animal muerto", "material")
	check(generic.size() > 0 and ResourceLoader.exists(generic[0]),
		"Animal muerto: fallback path missing: %s" % str(generic))

	if failures == 0:
		print("DEAD_ANIMAL_THUMBNAIL_ERRORS=0")
	else:
		print("DEAD_ANIMAL_THUMBNAIL_ERRORS=%d" % failures)
	quit(1 if failures > 0 else 0)
