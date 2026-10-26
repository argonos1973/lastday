extends SceneTree
class Wolf extends "res://scripts/WildlifeController.gd":
 func _ready() -> void: pass
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var wolf := Wolf.new()
 root.add_child(wolf)
 wolf.set_process(false)
 wolf.animal_type = "wolf"
 var model: Node3D = load(GameConst.WOLF_MODEL).instantiate()
 wolf.add_child(model)
 wolf._animation_player = wolf._find_animation_player(model)
 assert(wolf._animation_player != null)
 for key in ["idle", "sit", "lie", "eat", "walk", "trot", "run"]:
  wolf._play_animation_by_name(key)
  assert(wolf._animation_player.current_animation.to_lower().contains(key), "Missing animation: " + key)
 wolf._wolf_eating_timer = 8
 wolf._play_animation_by_name("idle")
 assert(wolf.current_anim_keyword == "eat")
 assert(wolf._animation_player.speed_scale == 1)
 wolf._animation_player.speed_scale = 2.5
 wolf._play_animation_by_name("eat")
 assert(wolf._animation_player.speed_scale == 1, "Repeated rest requests must reset locomotion speed")
 var clip := wolf._animation_player.get_animation(wolf._animation_player.current_animation)
 assert(clip.length >= 3.9 and clip.loop_mode == Animation.LOOP_LINEAR)
 wolf.is_puppet = true
 wolf.puppet_apply(Vector3.ZERO, 0, "eat", false, false)
 assert(wolf._animation_player.current_animation.to_lower().contains("eat"))
 wolf._wolf_eating_timer = 0
 wolf._play_animation_by_name("walk")
 assert(wolf.current_anim_keyword == "walk")
 wolf.queue_free()
 await process_frame
 print("PASS wolf eat: exported loop, idle override, speed, network puppet and resume walking")
 quit()
