extends SceneTree

class ServerWorld extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
	func _exit_tree() -> void:
		pass

func _initialize() -> void:
	var w := ServerWorld.new()
	root.add_child(w)
	w.river_segments_data = w._default_river_segments()
	var pts := [
		["corpse", 250.47, -261.58],
		["loot0 Camiseta", 253.18, -260.99],
		["loot1 Pantalones", 252.56, -260.60],
		["loot2 Zapatillas", 250.10, -259.49],
		["loot3 Lata atun", 249.43, -260.04],
		["loot4 Zapatillas", 248.70, -261.91],
		["loot5 Lata guiso", 249.65, -263.15],
		["loot6 Cerillas", 250.88, -263.61],
		["loot7 Cuchillo", 251.40, -263.79],
	]
	for p in pts:
		var d: float = w.get_river_depth_at(Vector3(p[1], 0, p[2]))
		print("%s (%.1f, %.1f) depth=%.3f water=%s" % [p[0], p[1], p[2], d, str(d > 0.02)])
	quit()
