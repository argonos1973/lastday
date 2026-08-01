extends SceneTree

func _init():
	var args = OS.get_cmdline_user_args()
	if args.size() < 1:
		print("Usage: -- <fbx_path>")
		quit()
		return
	var fbx_path = args[0]
	print("Loading: ", fbx_path)
	var res = load(fbx_path)
	if res == null:
		print("Failed to load as resource")
		quit()
		return
	var scene = res.instantiate()
	if scene == null:
		print("Failed to instantiate")
		quit()
		return
	print("Scene root: ", scene.name)
	var stack = [scene]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is MeshInstance3D:
			var aabb = n.mesh.get_aabb() if n.mesh != null else null
			var sz = aabb.size if aabb != null else Vector3.ZERO
			print("MESH: ", n.name, " aabb_size=(", sz.x, ", ", sz.y, ", ", sz.z, ") skin=", n.skin != null, " mesh=", n.mesh != null)
		if n is Skeleton3D:
			print("SKELETON: ", n.name, " bones=", n.get_bone_count())
			for i in range(mini(5, n.get_bone_count())):
				print("  bone[", i, "]=", n.get_bone_name(i))
		for c in n.get_children():
			stack.append(c)
	scene.free()
	quit()
