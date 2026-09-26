extends Node3D
class_name FishController

const Loader = preload("res://scripts/SimpleObjLoader.gd")
const FishShader = preload("res://shaders/fish_skin.gdshader")
const MODEL_PATHS := [
    "res://assets/external/quaternius_fish_obj/OBJ/Fish1.obj",
    "res://assets/external/quaternius_fish_obj/OBJ/Fish2.obj",
    "res://assets/external/quaternius_fish_obj/OBJ/Fish3.obj",
]
# Más luminosos que el agua para que el pez se distinga nadando bajo la superficie.
const COLORS := [Color(.34,.44,.38),Color(.44,.41,.26),Color(.36,.45,.48)]
var center := Vector3.ZERO
var along := Vector3.RIGHT
var across := Vector3.BACK
var length := 8.0
var width := 1.5
var speed := .6
var phase := 0.0
var species := 0
var body_length := .18
var _time := 0.0
var _visual: Node3D
var _materials: Array[ShaderMaterial] = []
static var _models: Dictionary = {}

static func school_specs(origin: Vector3, size: Vector2, yaw: float) -> Array:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash([origin,size,yaw,"fish_v2"])
    var lake := size.x >= 60.0
    var count := rng.randi_range(24,36) if lake else rng.randi_range(3,5)
    var forward := Vector3(cos(deg_to_rad(yaw)),0,-sin(deg_to_rad(yaw)))
    var side := Vector3(sin(deg_to_rad(yaw)),0,cos(deg_to_rad(yaw)))
    var result: Array = []
    for i in range(count):
        var p := origin + forward*rng.randf_range(-.18,.18)*size.x + side*rng.randf_range(-.15,.15)*size.y
        if lake:
            var angle := TAU*float(i)/count + rng.randf_range(-.05,.05)
            var radius := rng.randf_range(.31,.37)
            p = origin + forward*cos(angle)*size.x*radius + side*sin(angle)*size.y*radius
        # El lomo cresta la superficie: sumergidos son invisibles y solo se ve
        # una línea finísima — las "rayas" eran los peces medio ocultos.
        var half_h: float = [.16,.22,.28][i%3]*.22
        p.y = origin.y + rng.randf_range(.0,.025) - half_h
        result.append({"center":p,"along":forward,"across":side,"length":rng.randf_range(1.8,4.0) if lake else size.x*rng.randf_range(.15,.30),"width":1.0 if lake else size.y*.22,"seed":rng.randi(),"species":i%3})
    return result

func setup(new_center: Vector3, new_along: Vector3, new_across: Vector3, swim_length: float, swim_width: float, seed_value: int = 1, variant: int = 0) -> void:
    center = new_center
    along = new_along.normalized()
    across = new_across.normalized()
    length = swim_length
    width = swim_width
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    species = posmod(variant,3)
    body_length = [.16,.22,.28][species]*rng.randf_range(.78,1.12)
    speed = rng.randf_range(.22,.48)
    phase = rng.randf_range(0,TAU)
    _build_fish()
    update_pose(0.0)

func pose_at(seconds: float) -> Vector3:
    var p := phase + seconds*speed/maxf(length*.42,1.0)
    # Alternate shallow passes with gentle dives; avoid every fish cresting
    # the surface simultaneously for its entire route.
    var dive := (sin(seconds*.32+phase)+1.0)*.065
    return center + along*sin(p)*length*.42 + across*cos(p*.5+phase)*width*.30 + Vector3.UP*(sin(p*1.7)*.015-dive)

func update_pose(seconds: float) -> void:
    position = pose_at(seconds)
    var direction := pose_at(seconds+.05)-position
    if direction.length_squared() > .0000001:
        rotation.y = atan2(direction.x,direction.z)
    if _visual != null:
        _visual.rotation.y = sin(seconds*(7.0+species)+phase)*.045
    for material in _materials:
        material.set_shader_parameter("swim_time",seconds*(7.0+species)+phase)

func _process(delta: float) -> void:
    _time += delta
    var network := get_node_or_null("/root/NetworkManager")
    var seconds := _time
    if network != null and network.get("is_connected") == true:
        seconds = float(network.get("water_world_time"))
    update_pose(seconds)

func _build_fish() -> void:
    if not _models.has(species):
        var model := Loader.new().load_node3d(MODEL_PATHS[species],COLORS[species])
        if model != null:
            var packed := PackedScene.new()
            # Loader children already belong to the loaded root in normal use;
            # explicit ownership keeps every surface in the cached scene.
            for child in model.find_children("*","",true,false):
                child.owner = model
            packed.pack(model)
            _models[species] = packed
            model.free()
    if not _models.has(species):
        return
    _visual = (_models[species] as PackedScene).instantiate()
    add_child(_visual)
    var bounds := AABB()
    var first := true
    var parts := _visual.find_children("*","MeshInstance3D",true,false)
    if _visual is MeshInstance3D:
        parts.push_front(_visual)
    for part in parts:
        var mi := part as MeshInstance3D
        var box := mi.transform*mi.get_aabb()
        bounds = box if first else bounds.merge(box)
        first = false
        var mat := ShaderMaterial.new()
        mat.shader = FishShader
        mat.set_shader_parameter("back_color",COLORS[species])
        mat.set_shader_parameter("model_min",mi.get_aabb().position)
        mat.set_shader_parameter("model_size",mi.get_aabb().size)
        mat.set_shader_parameter("pattern",species)
        _materials.append(mat)
        mi.material_override = mat
    var ratio := body_length/maxf(bounds.size.z,.001)
    _visual.scale = Vector3.ONE*ratio
    _visual.position = -bounds.get_center()*ratio
