extends SceneTree
class Animal extends WildlifeController:
 func _process(_delta): pass
var failures := 0
func check(ok: bool, label: String):
 if not ok:
  failures += 1
  push_error(label)
func _initialize(): call_deferred("run")
func run():
 var stage := Node3D.new()
 root.add_child(stage)
 current_scene = stage
 for kind in ["wolf", "deer"]:
  var animal := Animal.new()
  stage.add_child(animal)
  animal.setup(kind, [Vector3.ZERO])
  var ap: AnimationPlayer = animal._animation_player
  for gait in ["walk", "trot", "run", "gallop"]:
   animal._play_animation_by_name(gait)
   var multiplier := 3.2 if gait in ["run", "gallop"] else (1.65 if gait == "trot" else 1.0)
   animal._update_animation_speed(animal.move_speed * multiplier)
   check(is_equal_approx(ap.speed_scale, 1.0), kind + " " + gait + " authored cadence")
   check(not "frighten" in ap.current_animation.to_lower(), "transition must not loop")
   ap.advance(.1)
   var pos := ap.current_animation_position
   animal._play_animation_by_name(gait)
   check(is_equal_approx(pos, ap.current_animation_position), "same gait must not restart")
  animal._puppet_desired_anim = "gallop"
  check(animal._puppet_locomotion_gait(animal.move_speed * 2.2) == "gallop", "preserve gallop and run hysteresis")
  animal._play_animation_by_name("trot")
  check(animal._puppet_locomotion_gait(animal.move_speed * 2.2) == "trot", "trot hysteresis")
  animal._play_animation_by_name("idle")
  animal._update_animation_speed(20)
  check(is_equal_approx(ap.speed_scale, 1.0), "rest cadence")
  if kind == "wolf":
   animal._play_animation_by_name("attack")
   animal._update_animation_speed(20)
   check(is_equal_approx(ap.speed_scale, 1.0), "attack cadence")
  animal.free()
 stage.free()
 print("WildlifeGaitRegression failures=", failures)
 quit(1 if failures else 0)
