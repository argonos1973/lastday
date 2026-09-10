extends Node3D
## Game ballistics: finite flight time, gravity and drag. Swept segments stop at cover.
signal impact(collider, position: Vector3, distance: float)
var velocity := Vector3.ZERO
var wind_velocity := Vector3.ZERO
var max_distance := 150.0
var excluded: Array[RID] = []
var traveled := 0.0

func _physics_process(delta: float) -> void:
	var remaining := delta
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 240.0)
		remaining -= step
		var acceleration := Vector3(0, -9.81, 0) - (velocity - wind_velocity) * 0.12
		var displacement := velocity * step + acceleration * (0.5 * step * step)
		velocity += acceleration * step
		displacement = displacement.limit_length(max_distance - traveled)
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + displacement)
		query.exclude = excluded
		query.collide_with_areas = true
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			traveled += global_position.distance_to(hit.position)
			impact.emit(hit.collider, hit.position, traveled)
			queue_free()
			return
		global_position += displacement
		traveled += displacement.length()
		if traveled >= max_distance - 0.001 or velocity.length_squared() < 1.0:
			queue_free()
			return
