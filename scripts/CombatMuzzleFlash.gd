extends Node3D
## Reused per actor. No per-round nodes, materials or SceneTree timers.
## Solo el destello de luz: las chispas particuladas se eliminaron.
var light: OmniLight3D
var remaining := 0.0
var marker: WeakRef

var owner_body: Node3D = null

func _ready() -> void:
	top_level = true
	owner_body = get_parent() as Node3D
	light = OmniLight3D.new()
	light.light_color = Color(1,.72,.3)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	add_child(light)
	# Siempre procesando: en reposo la luz (energía 0, invisible) sigue al
	# portador, así los materiales cercanos ya dibujan la variante "con luz
	# posicional" y el primer fogonazo no compila pipelines en pleno combate.
	set_process(true)

func warm_up() -> void:
	pass

func burst(at: Vector3, direction: Vector3, muzzle: Node3D = null) -> void:
	marker = weakref(muzzle) if is_instance_valid(muzzle) else null
	global_position = muzzle.global_position if is_instance_valid(muzzle) else at
	remaining = .15
	light.light_energy = 5.0
	set_process(true)

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	var muzzle = marker.get_ref() if marker != null else null
	if is_instance_valid(muzzle):
		global_position = muzzle.global_position
	elif remaining <= 0.0 and is_instance_valid(owner_body):
		# En reposo acompaña al portador a la altura del pecho.
		global_position = owner_body.global_position + Vector3(0.0, 1.2, 0.0)
	if remaining > 0.0:
		remaining -= delta
	if remaining <= 0.0:
		light.light_energy = 0.0
		marker = null
