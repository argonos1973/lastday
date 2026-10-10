extends RefCounted
const SOURCE := "res://assets/animations/walking_up_stairs.glb"
const NAME := "stairs/ascending"
static func install(actor: Node3D) -> String:
 var player: AnimationPlayer = actor.third_person_animation_player
 var target: Skeleton3D = actor._find_skeleton(actor.third_person_model)
 if player == null or target == null: return ""
 if player.has_animation(NAME): return NAME
 var source: Node3D = (load(SOURCE) as PackedScene).instantiate()
 var rig: Skeleton3D = actor._find_skeleton(source)
 var source_player: AnimationPlayer = actor._find_animation_player(source)
 var original: Animation
 if rig != null and source_player != null:
  for key in source_player.get_animation_list():
   var candidate := source_player.get_animation(key)
   if key != "RESET" and candidate.length>.1 and (original == null or candidate.length>original.length): original=candidate
 if original == null:
  source.free()
  return ""
 var animation := original.duplicate(true) as Animation
 # Retarget before changing track names, preserving the source bone rest frame.
 for track in range(animation.get_track_count()-1,-1,-1):
  var bone: String = actor._extract_mixamo_bone_name(str(animation.track_get_path(track)))
  var resolved: String = actor._resolve_mixamo_bone_name(target,bone)
  if resolved.is_empty() or animation.track_get_type(track)!=Animation.TYPE_ROTATION_3D:
   animation.remove_track(track)
   continue
  var source_index := rig.find_bone(bone)
  if source_index<0:
   animation.remove_track(track)
   continue
  var target_index := target.find_bone(resolved)
  var correction := target.get_bone_rest(target_index).basis.get_rotation_quaternion()*rig.get_bone_rest(source_index).basis.get_rotation_quaternion().inverse()
  for key in animation.track_get_key_count(track):
   animation.track_set_key_value(track,key,correction*animation.track_get_key_value(track,key))
 actor._retarget_animation_to_character_skeleton(animation)
 # The source ascends ~1m per cycle. Physics owns all translation; no root climb.
 animation.loop_mode=Animation.LOOP_LINEAR
 actor._smooth_loop_boundary(animation)
 var library := AnimationLibrary.new()
 library.add_animation("ascending",animation)
 player.add_animation_library("stairs",library)
 source.free()
 return NAME
