extends Node3D
## Reused per actor. No per-round nodes, materials or SceneTree timers.
## Solo el destello de luz: las chispas particuladas se eliminaron.
var light: OmniLight3D
var remaining := 0.0
var marker: WeakRef

func _ready() -> void:
	top_level = true
	light = OmniLight3D.new()
	light.light_color = Color(1,.72,.3)
	light.light_energy = 0.0
	light.omni_range = 7.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	add_child(light)
	set_process(false)

func warm_up() -> void:
	pass

func burst(at: Vector3, direction: Vector3, muzzle: Node3D = null) -> void:
	marker = weakref(muzzle) if is_instance_valid(muzzle) else null
	global_position = muzzle.global_position if is_instance_valid(muzzle) else at
	remaining = .15
	light.light_energy = 5.0
	set_process(true)

func _process(delta: float) -> void:
	var muzzle = marker.get_ref() if marker != null else null
	if is_instance_valid(muzzle):
		global_position = muzzle.global_position
	remaining -= delta
	if remaining <= 0.0:
		light.light_energy = 0.0
		marker = null
		set_process(false)
