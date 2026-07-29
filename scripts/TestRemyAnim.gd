extends SceneTree

func _init():
	print("=== TEST REMY ANIM ===")
	
	var gs_script = load("res://scripts/GameState.gd")
	var gs = gs_script.new()
	gs.name = "GameState"
	root.add_child(gs)
	gs._ready()
	
	var nm_script = load("res://scripts/NetworkManager.gd")
	var nm = nm_script.new()
	nm.name = "NetworkManager"
	root.add_child(nm)
	
	var gsession_script = load("res://scripts/GameSession.gd")
	var gsession = gsession_script.new()
	gsession.name = "GameSession"
	root.add_child(gsession)
	
	var pc_script = load("res://scripts/PlayerController.gd")
	var player = pc_script.new()
	player.name = "Player"
	player.position = Vector3(0, 0.4, 0)
	root.add_child(player)
	
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	
	# Check animation player state
	if player.third_person_animation_player != null:
		var ap = player.third_person_animation_player
		print("is_playing=", ap.is_playing())
		print("current_anim=", ap.current_animation)
		print("current_pos=", ap.current_animation_position)
		
		# Check skeleton bone poses
		var skel = player._find_skeleton(player.third_person_model)
		if skel != null:
			print("Bone count: ", skel.get_bone_count())
			# Print Hips details
			var hips_idx = skel.find_bone("mixamorig_Hips")
			if hips_idx == -1:
				hips_idx = skel.find_bone("mixamorig:Hips")
			if hips_idx != -1:
				var rest_e = skel.get_bone_rest(hips_idx).basis.get_euler()
				var pose_e = skel.get_bone_pose(hips_idx).basis.get_euler()
				print("Hips rest_euler=", rest_e)
				print("Hips pose_euler=", pose_e)
				print("Hips rest_quat=", skel.get_bone_rest(hips_idx).basis.get_rotation_quaternion())
				print("Hips pose_quat=", skel.get_bone_pose(hips_idx).basis.get_rotation_quaternion())
			# Print key bones
			for i in range(skel.get_bone_count()):
				var bn = skel.get_bone_name(i)
				if bn.find("Arm") >= 0 or bn.find("UpLeg") >= 0 or bn.find("Spine") >= 0:
					var rest_e = skel.get_bone_rest(i).basis.get_euler()
					var pose_e = skel.get_bone_pose(i).basis.get_euler()
					print("Bone ", bn, " rest=", rest_e, " pose=", pose_e)
	
	player.queue_free()
	gs.queue_free()
	nm.queue_free()
	gsession.queue_free()
	await process_frame
	quit()
