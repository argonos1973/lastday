extends MeshInstance3D
class_name TrackPrint

# Huella de animal sobre el terreno. Cosmetico por cliente: cada cliente ve al
# animal interpolado y dibuja su rastro local; no se sincroniza el historial
# de pisadas ni se reconstruye para jugadores que llegan después.

const MAX_TRACKS := 400
const LIFETIME := 180.0
const FADE_TIME := 55.0

static var _tracks: Array = []
static var _textures: Dictionary = {}

var _age := 0.0
var _base_alpha := 1.0

static func tracks_enabled() -> bool:
	return not OS.has_feature("dedicated_server")

static func spawn(parent: Node, pos: Vector3, yaw: float, kind: String, size: float, normal: Vector3 = Vector3.UP) -> void:
	if parent == null or not tracks_enabled():
		return
	var t: MeshInstance3D = (load("res://scripts/TrackPrint.gd") as GDScript).new()
	t.name = "TrackPrint_" + kind
	t.add_to_group("track_prints")
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _texture(kind)
	m.albedo_color = Color(0.11, 0.09, 0.06, 0.55)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	quad.material = m
	t.mesh = quad
	t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	t.set("_base_alpha", m.albedo_color.a)
	parent.add_child(t)
	t.global_position = pos
	# yaw apunta al sentido de la marcha; la textura dibuja los dedos hacia
	# arriba, que tras tumbar el quad queda mirando a yaw+PI.
	var up := normal.normalized()
	var forward := Vector3(sin(yaw), 0, cos(yaw))
	forward = (forward - up * forward.dot(up)).normalized()
	var right := forward.cross(up).normalized()
	t.global_basis = Basis(right, forward, up)
	_tracks.append(t)
	while _tracks.size() > MAX_TRACKS:
		var old = _tracks.pop_front()
		if is_instance_valid(old):
			old.queue_free()

func _exit_tree() -> void:
	_tracks.erase(self)

func _process(delta: float) -> void:
	_age += delta
	var remain := LIFETIME - _age
	if remain <= 0.0:
		queue_free()
		return
	if remain < FADE_TIME:
		var m := (mesh as QuadMesh).material as StandardMaterial3D
		if m != null:
			var c := m.albedo_color
			c.a = _base_alpha * (remain / FADE_TIME)
			m.albedo_color = c

# --- Texturas procedurales (blanco con alpha; el tinte va en el material) ---

static func _texture(kind: String) -> Texture2D:
	if _textures.has(kind):
		return _textures[kind]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	match kind:
		"hoof":
			# Pezuña hendida: dos lóbulos alargados apuntando al frente + espolones.
			_stamp(img, size, 52, 54, 10, 27, -0.16)
			_stamp(img, size, 76, 54, 10, 27, 0.16)
			_stamp(img, size, 52, 96, 4.5, 7, 0.0)
			_stamp(img, size, 76, 96, 4.5, 7, 0.0)
		_:
			# Zarpa: almohadilla central abajo, 4 dedos en arco arriba, garras.
			_stamp(img, size, 64, 84, 21, 15, 0.0)
			_stamp(img, size, 33, 48, 8.5, 12, -0.28)
			_stamp(img, size, 50, 33, 9, 12.5, -0.08)
			_stamp(img, size, 78, 33, 9, 12.5, 0.08)
			_stamp(img, size, 95, 48, 8.5, 12, 0.28)
			_stamp(img, size, 32, 32, 2.5, 4.5, -0.28)
			_stamp(img, size, 48, 17, 2.5, 4.5, -0.08)
			_stamp(img, size, 80, 17, 2.5, 4.5, 0.08)
			_stamp(img, size, 96, 32, 2.5, 4.5, 0.28)
	_textures[kind] = ImageTexture.create_from_image(img)
	return _textures[kind]

static func _stamp(img: Image, size: int, cx: float, cy: float, rx: float, ry: float, rot: float) -> void:
	var cos_r := cos(rot)
	var sin_r := sin(rot)
	var rad := maxf(rx, ry) + 2.0
	var x0 := clampi(int(floor(cx - rad)), 0, size - 1)
	var x1 := clampi(int(ceil(cx + rad)), 0, size)
	var y0 := clampi(int(floor(cy - rad)), 0, size - 1)
	var y1 := clampi(int(ceil(cy + rad)), 0, size)
	for y in range(y0, y1):
		for x in range(x0, x1):
			var dx := float(x) - cx
			var dy := float(y) - cy
			var lx := dx * cos_r + dy * sin_r
			var ly := -dx * sin_r + dy * cos_r
			var e := (lx * lx) / (rx * rx) + (ly * ly) / (ry * ry)
			var a := clampf(1.0 - e, 0.0, 1.0)
			a = smoothstep(0.0, 0.45, a)
			if a > 0.001:
				var p := Color(1, 1, 1, maxf(img.get_pixel(x, y).a, a))
				img.set_pixel(x, y, p)
