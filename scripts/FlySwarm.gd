extends Node3D
class_name FlySwarm

# Enjambre de moscas sobre carne podrida o cadaveres. Nodo autocontenido:
# las moscas orbitan con vaiven erratico y un AudioStreamPlayer3D emite el
# zumbido en loop con atenuacion posicional. Se libera con el nodo padre.

const FLY_COUNT := 9
const BUZZ_PATH := "res://assets/audio/moscas.wav"
const CULL_DIST := 60.0

var _flies: Array = []
var _audio: AudioStreamPlayer3D = null
var _player: Node3D = null
var _cull_timer := 0.0
var _t := 0.0

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.015, 0.015, 0.015)
	mat.roughness = 1.0
	for i in range(FLY_COUNT):
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = 0.012
		sp.height = 0.024
		mi.mesh = sp
		mi.material_override = mat
		add_child(mi)
		_flies.append({
			"node": mi,
			"radius": randf_range(0.10, 0.30),
			"speed": randf_range(2.5, 5.5) * (1.0 if randf() < 0.5 else -1.0),
			"phase": randf() * TAU,
			"hphase": randf() * TAU,
			"hamp": randf_range(0.03, 0.11),
		})
	var stream: AudioStream = load(BUZZ_PATH)
	if stream != null:
		if stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.data.size() / 2)
		_audio = AudioStreamPlayer3D.new()
		_audio.stream = stream
		_audio.unit_size = 1.5
		_audio.max_distance = 18.0
		_audio.volume_db = -8.0
		add_child(_audio)
		_audio.play()

func _process(delta: float) -> void:
	_t += delta
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = 1.0
		_player = null
		var scene := get_tree().current_scene
		if scene != null and scene.get("player") != null:
			_player = scene.player
	if _player != null and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) > CULL_DIST:
			return
	for f in _flies:
		var n: MeshInstance3D = f["node"]
		if not is_instance_valid(n):
			continue
		f["phase"] = float(f["phase"]) + float(f["speed"]) * delta
		var rr: float = float(f["radius"]) * (1.0 + 0.35 * sin(_t * 3.1 + float(f["phase"]) * 2.0))
		var wob := sin(_t * 7.0 + float(f["hphase"])) * 0.05 + sin(_t * 13.0 + float(f["phase"])) * 0.03
		n.position = Vector3(
			cos(float(f["phase"])) * rr + wob,
			0.08 + sin(_t * 5.3 + float(f["hphase"])) * float(f["hamp"]),
			sin(float(f["phase"])) * rr - wob
		)
