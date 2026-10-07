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
        check(specs.size() >= (36 if size.x>60 else 7),"population includes lake")
        world.river_segments_data = [{"center":origin,"size":size,"yaw":37.0}]
        if size.x > 60:
            var bands := [0,0,0]
            for spec in specs:
                var offset: Vector3 = spec.center-origin
                var radius := Vector2(offset.dot(spec.along)/size.x,offset.dot(spec.across)/size.y).length()
                bands[0 if radius<.16 else (1 if radius<.34 else 2)] += 1
            check(bands[0]>=8 and bands[1]>=8 and bands[2]>=8,"fish cover center, middle and shoreline")
            var lake_mesh := world._make_lake_mesh(size)
            var vertices: PackedVector3Array = lake_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
            var maximum := 0.0
            for v in vertices:
                maximum = maxf(maximum,Vector2(v.x/size.x,v.z/size.y).length())
            check(is_equal_approx(maximum,.425),"rendered lake matches swimming and boat boundary")
            var rim_vertices := 0
            for v in vertices:
                if is_equal_approx(Vector2(v.x/size.x,v.z/size.y).length(),.425):
                    rim_vertices += 1
            check(rim_vertices >= 129,"lake perimeter has enough segments for smooth close-up shores")
            check(world.has_method("_make_lake_bed_mesh"),"lake has a sloping bed instead of a flat abyss")
            if world.has_method("_make_lake_bed_mesh"):
                var bed: ArrayMesh = world.call("_make_lake_bed_mesh",size)
                var arrays := bed.surface_get_arrays(0)
                var bed_vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
                var bed_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
                var bed_uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
                var bed_colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
                var profile_matches := true
                var upward_normals := true
                var metre_uvs := true
                var shallow_vertices := 0
                var coverage := 0.0
                for i in range(bed_vertices.size()):
                    var v := bed_vertices[i]
                    var radius := Vector2(v.x/(size.x*.425),v.z/(size.y*.425)).length()
                    coverage = maxf(coverage,radius)
                    profile_matches = profile_matches and absf(v.y + clampf((1.0-radius)*5.5,.18,4.0) + .025) < .001
                    upward_normals = upward_normals and bed_normals[i].y > .9
                    metre_uvs = metre_uvs and bed_uvs[i].is_equal_approx(Vector2(v.x,v.z)/3.0)
                    if radius >= .9 and radius <= 1.0 and v.y > -.6:
                        shallow_vertices += 1
                check(profile_matches,"lake bed follows the existing swimming depth profile")
                check(upward_normals,"lake bed normals face the water")
                check(metre_uvs,"lake pebbles retain their scale across the basin")
                check(shallow_vertices > 200,"shallow shelf has multiple supporting rings")
                check(coverage > 1.05,"lake bed extends beneath the shore without holes")
                check(bed_colors.size() == bed_vertices.size() and bed_colors[0].r < bed_colors[-1].r,"bed darkens gradually toward deep water")
                check(bed_vertices.size() < 5000,"lake bed geometry stays bounded")
            var excludes_trees := true
            for i in range(64):
                var a := TAU*i/64.0
                var p: Vector3 = origin + specs[0].along*cos(a)*size.x*.424 + specs[0].across*sin(a)*size.y*.424
                excludes_trees = excludes_trees and not world._can_place_ground_vegetation(p,2.0)
            check(excludes_trees,"tree exclusion covers the full visible lake perimeter")
            var rng_state := world._world_rng.state
            var shore_trees: Array = world._lake_forest_specs(origin,size,37.0)
            check(shore_trees.size() > 100 and shore_trees.size() < 260,"bounded forest belt around lake")
            check(shore_trees == world._lake_forest_specs(origin,size,37.0),"shore forest is deterministic")
            check(world._world_rng.state == rng_state,"shore forest leaves gameplay RNG unchanged")
            var dry_trees := true
            var spaced_trees := true
            for i in range(shore_trees.size()):
                var tree_pos: Vector3 = shore_trees[i].position
                dry_trees = dry_trees and world._can_place_ground_vegetation(tree_pos,2.8)
                for j in range(i):
                    spaced_trees = spaced_trees and tree_pos.distance_to(shore_trees[j].position) >= 2.8
            check(dry_trees,"shore forest respects water and building clearance")
            check(spaced_trees,"shore trunks do not overlap")
        var species := {}
        var contained := true
        var small := true
        var smooth := true
        var submerged := true
        var above_bed := true
        var actual_scale := true
        for spec in specs:
            var fish := Fish.new()
            fish.setup(spec.center,spec.along,spec.across,spec.length,spec.width,spec.seed,spec.species)
            species[fish.species] = true
            small = small and fish.body_length >= .17 and fish.body_length < .48
            var visual := fish.get_child(0) as Node3D
            if visual is MeshInstance3D:
                actual_scale = actual_scale and is_equal_approx(visual.get_aabb().size.z*visual.scale.z,fish.body_length)
            else:
                actual_scale = false
            for t in range(0,600,3):
                var p := fish.pose_at(float(t))
                contained = contained and world.get_river_depth_at(p)>.05
                submerged = submerged and p.y < origin.y+.02 and p.y>origin.y-.5
                if size.x >= 60.0 and visual is MeshInstance3D:
                    var belly_y: float = p.y - visual.get_aabb().size.y * visual.scale.y * .5
                    above_bed = above_bed and belly_y > origin.y - world.get_river_depth_at(p) - .025
                smooth = smooth and p.distance_to(fish.pose_at(float(t)+.0167))<.02
            fish.free()
        check(species.size()==3,"three distinct meshes")
        check(small and actual_scale,"actual mesh length 17–48 cm including root mesh")
        check(contained and submerged,"paths stay underwater inside rotated banks for 10 minutes")
        if size.x >= 60.0:
            check(above_bed,"fish remain above the sloping lake bed throughout their paths")
        check(smooth,"continuous paths without wrap teleport")
        var mask := world._make_water_channel_mask().get_image()
        var pixel := Vector2i((Vector2(origin.x,origin.z)/1000.0+Vector2(.5,.5))*4096.0)
        check(mask.get_pixelv(pixel).r>.5,"terrain exposes underwater channel")
        check(mask.get_pixel(0,0).r<.5,"dry terrain remains intact")
    for is_lake in [false,true]:
        var water := RiverWater.new()
        water.mesh = PlaneMesh.new()
        water.material_override = MaterialFactory.make_river_water_material()
        water.set_is_lake(is_lake)
        root.add_child(water)
        var material := water.material_override as ShaderMaterial
        check(is_equal_approx(material.get_shader_parameter("normal_scale"),.045 if is_lake else .34),"calm lake normals without changing river flow")
        check(is_equal_approx(material.get_shader_parameter("roughness_scale"),.045 if is_lake else .16),"lake reflection roughness stays separate from rivers")
        check(material.get_shader_parameter("use_foam") == not is_lake,"lake is foam-free and river keeps foam")
        if is_lake:
            check(water._reflection.update_mode == ReflectionProbe.UPDATE_ONCE,"lake reflections remain cached")
        water.free()
    check(Network.accepts_player_state(true,42,42),"server accepts own player")
    check(not Network.accepts_player_state(true,42,43),"server rejects impersonation")
    check(Network.accepts_player_state(false,1,42),"client accepts server relay")
    check(not Network.accepts_player_state(false,43,42),"client rejects direct peer spoof")
    world.free()
    print("WATER_FISH_REGRESSION failures=",failures)
    quit(1 if failures else 0)
