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
var spin_speed := 0.0
# Entidades sin cuerpo fisico (net_player_proxy / ai_survivor_bot son
# Node3D puros en el servidor): el rayo de fisicas nunca los toca, asi que
# cada subpaso comprueba ademas la capsula vertical del superviviente.
var shooter: Node3D = null
# One query per projectile, reused by every swept integration step.
var _ray_query := PhysicsRayQueryParameters3D.new()

func _physics_process(delta: float) -> void:
	var _cpt := Time.get_ticks_usec()
	if is_queued_for_deletion(): return
	var _prof := CombatProf.enabled
	var _pt := 0
	_refresh_proxy_candidates()
	if _prof: CombatProf.mark("proj.refresh_candidates", _cpt)
	_p_ray = 0; _p_props = 0; _p_cap = 0; _p_water = 0; _p_steps = 0
	var space := get_world_3d().direct_space_state
	var world := get_tree().current_scene
	var has_distant_props := world != null and world.has_method("raycast_distant_props")
	var has_water := world != null and world.has_method("get_river_surface_y_at") and world.has_method("get_river_depth_at")
	var query := _ray_query
	query.collision_mask = 5
	query.exclude = excluded
	query.collide_with_areas = true
	query.hit_from_inside = true
	var remaining := delta
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 240.0)
		remaining -= step
		var acceleration := Vector3(0, -9.81, 0) - (velocity - wind_velocity) * drag_coeff
		var displacement := velocity * step + acceleration * (0.5 * step * step)
		velocity += acceleration * step
		displacement = displacement.limit_length(max_distance - traveled)
		query.from = global_position
		query.to = global_position + displacement
		if _prof: _pt = Time.get_ticks_usec(); _p_steps += 1
		var hit := space.intersect_ray(query)
		# Las Area3D que no son hitboxes de daño (zonas de interaccion,
		# triggers, volumenes) no detienen la bala: se atraviesan.
		while not hit.is_empty() and _is_passthrough_area(hit.collider):
			excluded.append(hit.rid)
			query.exclude = excluded
			hit = space.intersect_ray(query)
		if _prof: var _n := Time.get_ticks_usec(); _p_ray += _n - _pt; _pt = _n
		if has_distant_props:
			var endpoint: Vector3 = hit.position if not hit.is_empty() else global_position+displacement
			var distant: Dictionary = world.raycast_distant_props(global_position, endpoint)
			if not distant.is_empty(): hit = distant
		if _prof: var _n2 := Time.get_ticks_usec(); _p_props += _n2 - _pt; _pt = _n2
		# Transparent rivers/lakes have no physics surface: stop at the water
		# before a submerged terrain hit, and use the existing splash/ripple FX.
		var end: Vector3 = hit.position if not hit.is_empty() else global_position+displacement
		# Supervivientes sin cuerpo fisico: si la capsula esta mas cerca que
		# el impacto de la raycast, la bala los alcanza a ellos primero.
		var cap := _proxy_segment_hit(global_position, end)
		if _prof: var _n3 := Time.get_ticks_usec(); _p_cap += _n3 - _pt; _pt = _n3
		if not cap.is_empty() and (hit.is_empty() or global_position.distance_to(cap.position) < global_position.distance_to(hit.position)):
			traveled += global_position.distance_to(cap.position)
			if _prof: _prof_flush(); _pt = Time.get_ticks_usec()
			impact.emit(cap.node, cap.position, traveled, cap.normal)
			if _prof: CombatProf.mark("proj.impact_handler", _pt); CombatProf.mark("proj.capsule_impact", _cpt)
			queue_free()
			return
		if has_water:
			var surface_y: float = world.get_river_surface_y_at(end)
			if global_position.y > surface_y and end.y <= surface_y:
				var t := (global_position.y-surface_y)/maxf(.00001,global_position.y-end.y)
				var water_point := global_position.lerp(end,t)
				if float(world.get_river_depth_at(water_point)) > .02:
					if world.has_method("_play_water_drop_effect"): world._play_water_drop_effect(water_point)
					if _prof: _prof_flush(); CombatProf.mark("proj.water_impact", _cpt)
					queue_free()
					return
		if _prof: var _n4 := Time.get_ticks_usec(); _p_water += _n4 - _pt; _pt = _n4
		if not hit.is_empty():
			traveled += global_position.distance_to(hit.position)
			if _prof: _prof_flush(); _pt = Time.get_ticks_usec()
			impact.emit(hit.collider, hit.position, traveled, hit.normal)
			if _prof: CombatProf.mark("proj.impact_handler", _pt); CombatProf.mark("proj.phys_impact", _cpt)
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
		elif spin_speed != 0.0:
			rotate_y(spin_speed * step)
		if traveled >= max_distance - 0.001 or velocity.length_squared() < 1.0:
			expired.emit(global_position)
			if _prof: _prof_flush(); CombatProf.mark("proj.phys_expired", _cpt)
			queue_free()
			return
	if _prof: _prof_flush(); CombatProf.mark("proj.phys_frame", _cpt)

# Profiler-only accumulators (usec) for one physics tick of this projectile.
var _p_ray := 0
var _p_props := 0
var _p_cap := 0
var _p_water := 0
var _p_steps := 0

func _prof_flush() -> void:
	if _p_steps <= 0:
		return
	CombatProf.add("proj.godot_ray", _p_ray, _p_steps)
	CombatProf.add("proj.distant_props", _p_props, _p_steps)
	CombatProf.add("proj.capsule_search", _p_cap, _p_steps)
	CombatProf.add("proj.water_query", _p_water, _p_steps)
	_p_steps = 0

func _is_passthrough_area(collider) -> bool:
	# Solo las hitboxes de daño detienen la bala; el resto de areas son
	# volumenes de interaccion/triggers que no deben interceptarla.
	if not (collider is Area3D):
		return false
	return not ("hitbox" in str((collider as Node).name).to_lower())

# --- Capsulas de supervivientes sin fisica ----------------------------------
# En el servidor, jugadores y bots son Node3D invisibles para el rayo: un
# segmento los atraviesa sin registrarse. Este test los trata como capsulas
# verticales (radio ~0.36, altura por postura) — misma forma que tiene el
# cuerpo del jugador local para las balas ajenas. Los nodos que ya ofrecen
# colision (marionetas remote_player con HeadHitbox/BodyHitbox) los cubre el
# rayo de fisicas; se saltan para no contar el impacto dos veces.
const PROXY_HIT_RADIUS := 0.36
const PROXY_HIT_TOP_STAND := 1.72
const PROXY_HIT_TOP_LOW := 1.25   # agachado / sentado
const PROXY_HIT_TOP_LYING := 0.55 # tumbado / durmiendo

# Candidatos de capsula recogidos UNA vez por _physics_process — el test por
# subpaso (1/240 s) solo hace geometria, sin consultas de grupo ni metas.
# Se refresca en _refresh_proxy_candidates() en caso de que el nodo viva
# varios frames (poco habitual, vuelo <1 s).
var _proxy_candidates: Array = []

func _refresh_proxy_candidates() -> void:
	_proxy_candidates.clear()
	var tree := get_tree()
	if tree == null:
		return
	var seen := {}
	for grp in ["net_player_proxy", "ai_survivor_bot", "remote_player"]:
		for n in tree.get_nodes_in_group(grp):
			if not (n is Node3D) or n == shooter or not is_instance_valid(n):
				continue
			var nid := int(n.get_instance_id())
			if seen.has(nid):
				continue
			seen[nid] = true
			if n.get("is_dead") == true or bool(n.get_meta("proxy_dead", false)):
				continue
			if _node_has_collision(n):
				continue
			var base := (n as Node3D).global_position
			var top := PROXY_HIT_TOP_STAND
			if n.get("is_prone") == true or bool(n.get_meta("prone", false)) or bool(n.get_meta("sleeping", false)):
				top = PROXY_HIT_TOP_LYING
			elif bool(n.get_meta("crouching", false)) or bool(n.get_meta("sitting", false)) or bool(n.get_meta("saved_sitting", false)):
				top = PROXY_HIT_TOP_LOW
			_proxy_candidates.append([n, base, base + Vector3(0.0, 0.10, 0.0), base + Vector3(0.0, top, 0.0), top])

func _proxy_segment_hit(from: Vector3, to: Vector3) -> Dictionary:
	var best := {}
	var best_from := INF
	for cand in _proxy_candidates:
		var base: Vector3 = cand[1]
		var top: float = cand[4]
		# Descarte rapido: el punto mas cercano posible en su capsula esta a
		# dist(base,from) - altura del eje; si ya hay algo mejor, fuera.
		if base.distance_to(from) - top > best_from:
			continue
		var pair := _seg_seg_closest(from, to, cand[2], cand[3])
		if (pair[0] as Vector3).distance_to(pair[1]) > PROXY_HIT_RADIUS:
			continue
		var d_from := from.distance_to(pair[0])
		if d_from < best_from:
			best_from = d_from
			# Cabeza: el tercio superior de la capsula.
			var head: bool = (pair[1] as Vector3).y >= base.y + top - 0.35
			best = {"node": cand[0], "position": pair[0], "normal": (pair[0] - pair[1]).normalized(), "head": head}
	return best

# El nodo ya tiene colision propia (marioneta con hitboxes): el rayo la cubre.
func _node_has_collision(n: Node) -> bool:
	if n is CollisionObject3D:
		return true
	for c in n.get_children():
		if _node_has_collision(c):
			return true
	return false

# Puntos mas cercanos entre dos segmentos (p,q): devuelve [punto_en_p, punto_en_q].
func _seg_seg_closest(p0: Vector3, p1: Vector3, q0: Vector3, q1: Vector3) -> Array:
	var d1 := p1 - p0
	var d2 := q1 - q0
	var r := p0 - q0
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a < 0.000001 and e < 0.000001:
		return [p0, q0]
	if a < 0.000001:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e < 0.000001:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var bb := d1.dot(d2)
			var den := a * e - bb * bb
			if den > 0.000001:
				s = clampf((bb * f - c * e) / den, 0.0, 1.0)
			t = (bb * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((bb - c) / a, 0.0, 1.0)
	return [p0 + d1 * s, q0 + d2 * t]
