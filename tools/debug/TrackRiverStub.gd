extends Node3D

# Stub de escena para AnimalTracksRegression: expone get_river_depth_at como
# Main.gd para probar que los puppets consultan el rio (su _water_depth no se
# actualiza — _update_water_depth es rama de IA).
var depth := 0.0

func get_river_depth_at(_world_pos: Vector3) -> float:
	return depth
