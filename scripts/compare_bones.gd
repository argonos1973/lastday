extends SceneTree

func _init() -> void:
	var gltf := GLTFDocument.new()
	var state := GLTFState.new()
	gltf.append_from_file(ProjectSettings.globalize_path("res://assets/adapted/player_with_clothes.glb"), state)
	var scene := gltf.generate_scene(state)
	
	var meshes := {}
	var stack := [scene]
	while not stack.is_empty():
		var n = stack.pop_back()
		if n is MeshInstance3D:
			meshes[String(n.name)] = n
		for c in n.get_children():
			stack.append(c)
	
	# Analyze soldier_torso vertex distribution
	var smi = meshes.get("soldier_torso")
	var tmi = meshes.get("Tops")
	if smi == null:
		print("soldier_torso NOT FOUND")
		quit()
		return
	
	var smesh = smi.mesh as ArrayMesh
	var tmesh = tmi.mesh as ArrayMesh
	var sverts: PackedVector3Array = smesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var tverts: PackedVector3Array = tmesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	
	# Count vertices in different regions
	var s_arms = 0  # |X| > 0.3
	var s_torso = 0  # |X| <= 0.3
	var s_neck = 0  # Y > 1.4
	var s_high = 0  # Y > 1.3
	var t_arms = 0
	var t_torso = 0
	var t_neck = 0
	var t_high = 0
	
	for v in sverts:
		if abs(v.x) > 0.3:
			s_arms += 1
		else:
			s_torso += 1
		if v.y > 1.4:
			s_neck += 1
		if v.y > 1.3:
			s_high += 1
	
	for v in tverts:
		if abs(v.x) > 0.3:
			t_arms += 1
		else:
			t_torso += 1
		if v.y > 1.4:
			t_neck += 1
		if v.y > 1.3:
			t_high += 1
	
	print("soldier_torso: ", sverts.size(), " verts, arms=", s_arms, " torso=", s_torso, " neck(y>1.4)=", s_neck, " high(y>1.3)=", s_high)
	print("Tops:          ", tverts.size(), " verts, arms=", t_arms, " torso=", t_torso, " neck(y>1.4)=", t_neck, " high(y>1.3)=", t_high)
	
	# Print Y range for both
	var smin_y = INF; var smax_y = -INF
	var tmin_y = INF; var tmax_y = -INF
	for v in sverts:
		smin_y = min(smin_y, v.y); smax_y = max(smax_y, v.y)
	for v in tverts:
		tmin_y = min(tmin_y, v.y); tmax_y = max(tmax_y, v.y)
	print("soldier_torso Y: ", smin_y, " - ", smax_y)
	print("Tops Y:          ", tmin_y, " - ", tmax_y)
	
	# Check bone weights of soldier_torso
	var sbones: PackedInt32Array = smesh.surface_get_arrays(0)[Mesh.ARRAY_BONES]
	var sweights: PackedFloat32Array = smesh.surface_get_arrays(0)[Mesh.ARRAY_WEIGHTS]
	print("soldier_torso bones entries: ", sbones.size(), " weights entries: ", sweights.size())
	
	quit()

