extends SceneTree
const Fish = preload("res://scripts/FishController.gd")
const Network = preload("res://scripts/NetworkManager.gd")
const Main = preload("res://scripts/Main.gd")
var failures := 0
func _initialize() -> void:
    call_deferred("run")
func check(value: bool, label: String) -> void:
    print("PASS " if value else "FAIL ",label)
    if not value: failures += 1
func run() -> void:
    var world := Main.new()
    for size in [Vector2(14,5.5),Vector2(150,90)]:
        var origin := Vector3(32,.085,-24)
        var specs := Fish.school_specs(origin,size,37.0)
        check(specs == Fish.school_specs(origin,size,37.0),"deterministic school " + str(size))
        check(specs.size() >= (24 if size.x>60 else 3),"population includes lake")
        world.river_segments_data = [{"center":origin,"size":size,"yaw":37.0}]
        var species := {}
        var contained := true
        var small := true
        var smooth := true
        var submerged := true
        var actual_scale := true
        for spec in specs:
            var fish := Fish.new()
            fish.setup(spec.center,spec.along,spec.across,spec.length,spec.width,spec.seed,spec.species)
            species[fish.species] = true
            small = small and fish.body_length >= .10 and fish.body_length < .29
            var visual := fish.get_child(0) as Node3D
            if visual is MeshInstance3D:
                actual_scale = actual_scale and is_equal_approx(visual.get_aabb().size.z*visual.scale.z,fish.body_length)
            else:
                actual_scale = false
            for t in range(0,600,3):
                var p := fish.pose_at(float(t))
                contained = contained and world.get_river_depth_at(p)>.05
                submerged = submerged and p.y < origin.y-.15 and p.y>origin.y-.5
                smooth = smooth and p.distance_to(fish.pose_at(float(t)+.0167))<.02
            fish.free()
        check(species.size()==3,"three distinct meshes")
        check(small and actual_scale,"actual mesh length 11–28 cm including root mesh")
        check(contained and submerged,"paths stay underwater inside rotated banks for 10 minutes")
        check(smooth,"continuous paths without wrap teleport")
        var mask := world._make_water_channel_mask().get_image()
        var pixel := Vector2i((Vector2(origin.x,origin.z)/1000.0+Vector2(.5,.5))*4096.0)
        check(mask.get_pixelv(pixel).r>.5,"terrain exposes underwater channel")
        check(mask.get_pixel(0,0).r<.5,"dry terrain remains intact")
    check(Network.accepts_player_state(true,42,42),"server accepts own player")
    check(not Network.accepts_player_state(true,42,43),"server rejects impersonation")
    check(Network.accepts_player_state(false,1,42),"client accepts server relay")
    check(not Network.accepts_player_state(false,43,42),"client rejects direct peer spoof")
    world.free()
    print("WATER_FISH_REGRESSION failures=",failures)
    quit(1 if failures else 0)
