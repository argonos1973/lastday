extends Node3D
## Game ballistics: finite flight time, gravity and drag. Swept segments stop at cover.
signal impact(collider, position: Vector3, distance: float, normal: Vector3)
signal expired(position: Vector3)
var velocity := Vector3.ZERO
var wind_velocity := Vector3.ZERO
var max_distance := 150.0
var excluded: Array[RID] = []
var traveled := 0.0
# Per-ammo ballistics: light fletched shafts bleed speed much faster than
# bullets and weathercock into the velocity vector along the arc.
var drag_coeff := 0.12
var align_flight := false
var launch_speed := 0.0

func _physics_process(delta: float) -> void:
	if is_queued_for_deletion(): return
	var remaining := delta
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 240.0)
		remaining -= step
		var acceleration := Vector3(0, -9.81, 0) - (velocity - wind_velocity) * drag_coeff
		var displacement := velocity * step + acceleration * (0.5 * step * step)
		velocity += acceleration * step
		displacement = displacement.limit_length(max_distance - traveled)
		var query := PhysicsRayQueryParameters3D.create(global_position, global_position + displacement, 5)
		query.exclude = excluded
		query.collide_with_areas = true
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		# Las Area3D que no son hitboxes de daño (zonas de interaccion,
		# triggers, volumenes) no detienen la bala: se atraviesan.
		while not hit.is_empty() and _is_passthrough_area(hit.collider):
			excluded.append(hit.rid)
			query.exclude = excluded
			hit = get_world_3d().direct_space_state.intersect_ray(query)
		var world := get_tree().current_scene
		if world != null and world.has_method("raycast_distant_props"):
			var endpoint: Vector3 = hit.position if not hit.is_empty() else global_position+displacement
			var distant: Dictionary = world.raycast_distant_props(global_position, endpoint)
			if not distant.is_empty(): hit = distant
		# Transparent rivers/lakes have no physics surface: stop at the water
		# before a submerged terrain hit, and use the existing splash/ripple FX.
		var end: Vector3 = hit.position if not hit.is_empty() else global_position+displacement
		if world != null and world.has_method("get_river_surface_y_at") and world.has_method("get_river_depth_at"):
			var surface_y: float = world.get_river_surface_y_at(end)
			if global_position.y > surface_y and end.y <= surface_y:
				var t := (global_position.y-surface_y)/maxf(.00001,global_position.y-end.y)
				var water_point := global_position.lerp(end,t)
				if float(world.get_river_depth_at(water_point)) > .02:
					if world.has_method("_play_water_drop_effect"): world._play_water_drop_effect(water_point)
					queue_free()
					return
		if not hit.is_empty():
			traveled += global_position.distance_to(hit.position)
			impact.emit(hit.collider, hit.position, traveled, hit.normal)
			queue_free()
			return
		global_position += displacement
		traveled += displacement.length()
		# Fletching stabilizes the shaft: the nose tracks the velocity vector,
		# so a spent arrow visibly tips down along the falling arc.
		if align_flight and velocity.length_squared() > 9.0:
			var fwd := velocity.normalized()
			var up_ref := Vector3.UP if absf(fwd.y) < 0.97 else Vector3.FORWARD
			look_at(global_position + fwd, up_ref)
		if traveled >= max_distance - 0.001 or velocity.length_squared() < 1.0:
			expired.emit(global_position)
			queue_free()
			return

func _is_passthrough_area(collider) -> bool:
	# Solo las hitboxes de daño detienen la bala; el resto de areas son
	# volumenes de interaccion/triggers que no deben interceptarla.
	if not (collider is Area3D):
		return false
	return not ("hitbox" in str((collider as Node).name).to_lower())
