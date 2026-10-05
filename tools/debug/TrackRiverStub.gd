extends Node3D

# Stub de escena para AnimalTracksRegression: expone get_river_depth_at como
# Main.gd para probar que los puppets consultan el rio (su _water_depth no se
# actualiza — _update_water_depth es rama de IA).
var depth := 0.0
var strip_water := false
var slope := 0.0

func get_river_depth_at(_world_pos: Vector3) -> float:
	return 1.0 if strip_water and _world_pos.z > 1.0 and _world_pos.z < 2.0 else (0.0 if strip_water else depth)

func _get_exact_ground_y(x: float, z: float) -> float:
	return slope * (x + z)
