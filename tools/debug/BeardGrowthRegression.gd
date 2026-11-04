extends SceneTree

const Grooming = preload("res://scripts/CharacterGrooming.gd")

var _failures := 0
var _notices: Array = []

func check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: ", msg)
	else:
		_failures += 1
		print("FAIL: ", msg)

class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _physics_process(_d): pass

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	# 1) Umbrales de crecimiento por tiempo sobrevivido
	check(Grooming.beard_stage(0.0) == 0, "0 s -> Sin barba")
	check(Grooming.beard_stage(3599.0) == 0, "59 min -> aun sin barba")
	check(Grooming.beard_stage(3600.0) == 1, "1 h -> Barba de 3 dias")
	check(Grooming.beard_stage(10800.0) == 2, "3 h -> Barba corta")
	check(Grooming.beard_stage(21600.0) == 3, "6 h -> Barba poblada")
	check(Grooming.beard_stage(43200.0) == 4, "12 h -> Barba larga")

	# 2) Identidad codificada name|style:stage -> decodifica de vuelta
	var wire := Grooming.encode_identity("Remy", "short", 3)
	check(wire == "Remy|short:3", "encode_identity produce '%s'" % wire)
	check(Grooming.stage_from_identity(wire, 0.0) == 3, "stage_from_identity decodifica stage 3")
	check(Grooming.stage_from_identity("Remy", 2.0 * 3600.0) == 1, "sin stage en el nombre usa fallback por segundos (1)")
	check(Grooming.base_name_from_identity(wire) == "Remy", "base_name limpia la identidad")

	# 3) Aplicacion real sobre el modelo: GrowingBeard aparece y crece con el stage
	var actor := Actor.new()
	root.add_child(actor)
	actor.set_process(false)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	check(actor.third_person_model != null, "Modelo third_person instanciado para grooming")

	Grooming.apply(actor.third_person_model, "short", Color(0.2, 0.12, 0.05), 0)
	var beard := actor.third_person_model.find_child("GrowingBeard", true, false) as MeshInstance3D
	check(beard != null, "Nodo GrowingBeard creado")
	check(beard != null and not beard.visible, "Sin barba (stage 0): GrowingBeard oculto")

	var prev_verts := -1
	var monotonic_ok := true
	for stage in [1, 2, 3, 4]:
		Grooming.apply(actor.third_person_model, "short", Color(0.2, 0.12, 0.05), stage)
		var bm := beard.mesh as ArrayMesh
		if bm == null or bm.get_surface_count() == 0:
			monotonic_ok = false
			break
		var verts: int = bm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		check(verts > 0, "Stage %d: malla de barba con %d vertices" % [stage, verts])
		if verts <= 0 or (prev_verts > 0 and verts < prev_verts * 0.5):
			monotonic_ok = false
		prev_verts = verts
	check(beard.visible, "GrowingBeard visible con stage > 0")
	check(monotonic_ok, "La malla de barba existe y crece coherentemente por stage")

	# 4) Tick de crecimiento en PlayerController: detecta el cambio de stage y avisa
	actor.is_puppet = false
	actor.notice.connect(func(t): _notices.append(t))
	actor.stats.survival_seconds = 3590.0
	actor._beard_stage = 0
	actor._tick_beard_growth(2.1)
	check(actor._beard_stage == 0, "A 59:50 sigue sin barba tras tick")
	actor.stats.survival_seconds = 3610.0
	actor._tick_beard_growth(2.1)
	check(actor._beard_stage == 1, "Cruzar 1 h de supervivencia sube a stage 1 en el tick")
	check(_notices.size() == 1 and "barba" in _notices[0].to_lower(), "Aviso 'Te ha crecido la barba' emitido")
	actor.stats.survival_seconds = 11000.0
	actor._tick_beard_growth(2.1)
	check(actor._beard_stage == 2, "A las 3 h pasa a stage 2 en el tick")

	# 5) Identidad con rasurado: _shaved_at_seconds descuenta tiempo acumulado
	actor._shaved_at_seconds = 10000.0
	actor.stats.survival_seconds = 11000.0
	actor._tick_beard_growth(2.1)
	check(actor._beard_stage == 0, "Tras rasurar (_shaved_at_seconds=10000) a los 11000 s la barba vuelve a 0")

	actor.queue_free()
	await process_frame
	print("BeardGrowthRegression: %d failures" % _failures)
	quit(1 if _failures > 0 else 0)
