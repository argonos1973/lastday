extends SceneTree
# Preview de los clips de paso lateral (strafe) con fusil — lo que ven otros
# jugadores y los puppets de bots al desplazarse de lado mirando al frente.
#   Godot --path . --script tools/debug/StrafeAnimPreview.gd [-- --walk]
# --walk muestra riflewalk como referencia. Escribe
# build/previews/strafe_{left,right,walk}_f{0..3}.png — 4 fases por clip.

const ItemData = preload("res://scripts/Item.gd")

class Actor extends "res://scripts/PlayerController.gd":
	func _ready() -> void: pass
	func _physics_process(_delta: float) -> void: pass

func _initialize() -> void:
	call_deferred("run")

const OUT_DIR := "res://build/previews"

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.set_process(false)
	actor.equip_clothing("Chaqueta militar digital")
	actor.equip_clothing("Pantalones cargo con rodilleras")
	actor._puppet_held = "Rifle francotirador"
	actor._update_puppet_held_item("Rifle francotirador")
	actor._rifle_in_hands = true
	actor._has_rifle = true
	var player: AnimationPlayer = actor.third_person_animation_player
	var skel: Skeleton3D = actor._find_skeleton(actor.third_person_model)
	print("strafe_L='%s' has=%s  strafe_R='%s' has=%s  walk='%s' has=%s" % [
		actor._rifle_strafe_left_animation, player != null and player.has_animation(actor._rifle_strafe_left_animation),
		actor._rifle_strafe_right_animation, player != null and player.has_animation(actor._rifle_strafe_right_animation),
		actor._rifle_walk_animation, player != null and player.has_animation(actor._rifle_walk_animation)])
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, -20, 0)
	light.shadow_enabled = true
	root.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.14, 0.16, 0.18)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.55
	root.add_child(env)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	root.add_child(camera)
	# Posea una fase para que el esqueleto tome altura real antes de medir el centro.
	var first_anim := actor._rifle_strafe_left_animation
	if player != null and not first_anim.is_empty() and player.has_animation(first_anim):
		player.play(first_anim, 0.0)
		player.advance(0.1)
		if skel != null:
			skel.force_update_all_bone_transforms()
	var front := (actor.global_basis * Vector3.FORWARD).normalized()
	var right := front.cross(Vector3.UP).normalized()
	var neck_w := actor.global_position + Vector3.UP * 1.35
	if skel != null and skel.find_bone("mixamorig_Neck") >= 0:
		neck_w = (skel.global_transform * skel.get_bone_global_pose(skel.find_bone("mixamorig_Neck"))).origin
	var center := neck_w - Vector3.UP * 0.35
	# Tres cuartos frontal-lateral: la zancada cruzada se lee de frente.
	camera.position = center + (front * 0.9 + right * 1.0).normalized() * 3.6 + Vector3.UP * 0.3
	camera.look_at(center)
	var specs: Array = [["left", actor._rifle_strafe_left_animation], ["right", actor._rifle_strafe_right_animation]]
	if "--walk" in OS.get_cmdline_user_args():
		specs.append(["walk", actor._rifle_walk_animation])
	var phases := [0.10, 0.35, 0.60, 0.85]
	for spec in specs:
		var tag: String = spec[0]
		var anim: String = spec[1]
		if anim.is_empty() or not player.has_animation(anim):
			print("MISSING ", tag, " -> ", anim)
			continue
		var clip := player.get_animation(anim)
		var prev_t := 0.0
		for i in phases.size():
			var t: float = clip.length * phases[i]
			player.play(anim, 0.0)
			player.advance(maxf(0.0, t - prev_t))
			prev_t = t
			if skel != null:
				skel.force_update_all_bone_transforms()
			for k in 3:
				actor._update_rifle_ik(skel, 1.0 / 60.0)
				actor._on_skeleton_updated()
				if skel != null:
					skel.force_update_all_bone_transforms()
			actor._update_rifle_strap(1.0 / 30.0)
			await create_timer(0.15).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s/strafe_%s_f%d.png" % [OUT_DIR, tag, i])
	print("STRAFE_PREVIEW_DONE")
	actor.stats.free()
	actor.free()
	quit(0)
