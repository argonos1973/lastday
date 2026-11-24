extends SceneTree

# Ejercita movimiento real del manager sin cargar el mapa ni tocar partidas.
class MotionManager extends SurvivorBotManager:
	var obstacle := ""
	var ground_height := 0.0
	func _ground_y(_x: float, _z: float, _from_y: float = -INF) -> float: return ground_height
	func _resolve_mountain_road_waypoint(_cur: Vector3, goal: Vector3) -> Vector3: return goal
	func _resolve_building_interior_waypoint(_b: Dictionary, _cur: Vector3, goal: Vector3) -> Vector3: return goal
	func _is_in_any_building_3d(_pos: Vector3) -> bool: return false
	func _is_pos_blocked(_pos: Vector3, _radius: float = 0.42, _deep: bool = false) -> bool: return false
	func _is_step_blocked(a: Vector3, z: Vector3, _deep: bool = false) -> bool:
		return obstacle == "enclosed" or (obstacle == "front" and absf(z.x - a.x) < 0.01)
	func _bot_carry_ratio(_b: Dictionary) -> float: return 0.0

class WaterWorld extends Node3D:
	var bot_nav = null
	var depth := 3.0
	func get_river_depth_at(pos: Vector3) -> float: return depth if pos.x > 4.0 else 0.0
	func _get_exact_ground_y(_x: float, _z: float) -> float: return 0.025

class BendNav extends RefCounted:
	var calls := 0
	func find_path(start: Vector3, goal: Vector3) -> Array:
		calls += 1
		return [start.lerp(goal, 0.5) + Vector3(0, 0, 2), goal]

class CombatManager extends MotionManager:
	var clear_los := true
	var shots := 0
	var melee_hits := 0
	var moving_shots := 0
	var cover_calls := 0
	var cover_goal := Vector3(4, 0, 0)
	var target: Node3D
	func _has_clear_shot(_a: Vector3, _z: Vector3) -> bool: return clear_los
	func _find_ballistic_cover(_b: Dictionary, _foe: Node3D) -> Vector3:
		cover_calls += 1
		return cover_goal
	func _bot_aim_tick(b: Dictionary, _foe: Node3D, _dist: float, _los: bool, _delta: float, _kind: String) -> float:
		_bot_aim_st(b)["settle"] = 2.0
		return 0.0
	func _bot_fire_rifle_at(b: Dictionary, _foe: Node3D, _dmg: float, _weapon := "") -> void:
		shots += 1
		if _bot_is_moving(b): moving_shots += 1
	func _find_actor_by_peer_id(_id: int) -> Node3D: return target
	func _bot_ambush_forbidden(_b: Dictionary, _id: int) -> bool: return false
	func rally_bot_team(_id: int, _target: Node3D) -> void: pass
	func _bot_melee_dodge_chance(_speed: float) -> float: return 0.0
	func _apply_bot_damage_to_target(_b: Dictionary, _target: Node3D, _amount: float, _weapon: String) -> void:
		melee_hits += 1

var errors := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(message)

func bot(p: Node3D, id: int = 901) -> Dictionary:
	return {"proxy": p, "bot_id": id, "pos": p.position, "rot": 0.0,
		"health": 100.0, "hunger": 90.0, "thirst": 90.0, "energy": 100.0,
		"anim": "idle", "has_rifle": true, "held_item": "Fusil de asalto",
		"path": [], "path_idx": 0, "path_timer": 0.0, "stuck_timer": 0.0,
		"stuck_count": 0, "last_move_pos": p.position, "strafe_dir": 1.0,
		"strafe_timer": 0.0, "shoot_cooldown": 0.0, "attack_cooldown": 0.0,
		"_mem": {"personality": {}, "stats": {}}}

func _initialize() -> void: call_deferred("run")

func test_escort_motion(manager: MotionManager) -> void:
	var leader := Node3D.new()
	var follower := Node3D.new()
	root.add_child(leader)
	root.add_child(follower)
	var b := bot(follower)
	b["team_leader_id"] = 77
	b["torch_lit"] = false
	leader.set_meta("anim", "walk")
	var slot := manager._bot_formation_slot(b, leader, leader.position)
	follower.position = slot + Vector3.BACK * 7.0
	var changes := 0
	var last := ""
	for i in 160:
		leader.position.z -= 5.2 * 0.05
		manager._tick_teammate_behavior(b, leader, 0.05)
		if last != "" and b.anim != last:
			changes += 1
		last = b.anim
	check(changes <= 6 and absf(follower.position.z - (leader.position.z + slot.z)) < 8.0,
		"steady leader: follower keeps up without flickering walk/run (%d changes in 8 s)" % changes)
	var idle_ticks := 0
	for i in 120:
		leader.position.z -= 2.0 * 0.05
		manager._tick_teammate_behavior(b, leader, 0.05)
		if i >= 60 and b.anim == "idle":
			idle_ticks += 1
	check(idle_ticks == 0, "slow walking leader: escort matches pace rather than stopping between steps (%d idle ticks)" % idle_ticks)
	# Strafe backwards with positions delivered every fourth tick; looking
	# over a shoulder must not swap the formation to the other side.
	leader.rotation.y = PI
	var wrong_side_ticks := 0
	for i in 40:
		if i % 4 == 0:
			leader.position.z -= 0.4
		manager._tick_teammate_behavior(b, leader, 0.05)
		var target := manager._bot_formation_slot(b, leader, leader.position)
		if (target - leader.position).dot(slot) <= 0.0:
			wrong_side_ticks += 1
	check(wrong_side_ticks == 0, "formation holds travel heading between position updates (%d flipped slots)" % wrong_side_ticks)
	print("ESCORT_MOTION gait_changes=%d idle_ticks=%d flipped_slots=%d" % [changes, idle_ticks, wrong_side_ticks])
	for i in 4:
		leader.position.z += 0.4
		manager._tick_teammate_behavior(b, leader, 0.05)
	check((manager._bot_formation_slot(b, leader, leader.position) - leader.position).dot(slot) < 0.0,
		"formation changes sides when the leader actually turns back")
	follower.free()
	leader.free()

func run() -> void:
	var manager := CombatManager.new()
	root.add_child(manager)
	var proxy := Node3D.new()
	var foe := Node3D.new()
	root.add_child(proxy)
	root.add_child(foe)
	proxy.set_meta("saved_inventory", [{"name": "Fusil de asalto", "type": "weapon", "quantity": 1}])
	proxy.set_meta("bot_gun_ammo", {"m4_magazine": 30, "m4_reserve": 60, "magazine": 0, "reserve": 0})
	var b := bot(proxy)
	manager.obstacle = "enclosed"
	manager._move_bot_towards(b, Vector3(0, 0, -20), 6.4, 0.1, "run")
	check(proxy.position == Vector3.ZERO, "all blocked steering candidates must not move through the wall")
	check(b.anim == "idle" and b._speed == 0.0 and b._mdir == Vector3.ZERO, "a blocked bot stops animation and velocity")
	check(not proxy.get_meta("moving", true) and not proxy.get_meta("sprinting", true), "blocked bot does not broadcast running footsteps")
	var recovery_detour := false
	for i in 20:
		manager._move_bot_towards(b, Vector3(0, 0, -20), 6.4, 0.1, "run")
		if not b.path.is_empty() and b.path[0] != proxy.position: recovery_detour = true
	check(b.stuck_count >= 1 and recovery_detour, "blocked bot still plans a nonzero recovery detour")
	manager.obstacle = "front"
	b = bot(proxy)
	manager._move_bot_towards(b, Vector3(0, 0, -20), 3.0, 0.1, "walk")
	check(absf(proxy.position.x) > 0.01, "bot takes a free steering direction")
	check((b._mdir as Vector3).dot(proxy.position.normalized()) > 0.999, "network direction follows the actual deflected movement")
	manager._move_bot_towards(b, proxy.position, 3.0, 0.1, "walk")
	check(b.anim == "idle" and b._speed == 0.0, "arrival resets the previous locomotion state")
	manager.obstacle = ""
	proxy.position = Vector3.ZERO
	b = bot(proxy)
	b.crouching = true
	manager._move_bot_towards(b, Vector3(0, 0, -20), 6.4, 0.5, "run")
	check(proxy.position.length() <= 1.001 and b.anim == "walk", "crouched movement never inherits sprint speed")
	check(manager._bot_effective_net_anim(b) == "sneak_walk", "crouch locomotion reaches the client as walking, not static sneak")
	b = bot(proxy)
	manager.ground_height = 2.0
	manager._move_bot_towards(b, Vector3(0, 2, -20), 3.0, 0.1, "walk")
	check(float(b._speed) <= 3.0, "a vertical ground correction cannot accelerate horizontal walking")
	# Reproduce ocho ticks consecutivos sin pausas de reloj real: los ajustes
	# de altura alternos antes alimentaban la aceleración del tick siguiente.
	proxy.position = Vector3.ZERO
	b = bot(proxy)
	var max_walk_speed := 0.0
	for i in 8:
		manager.ground_height = 1.0 if i % 2 == 0 else 0.0
		manager._move_bot_towards(b, Vector3(20, 0, 0), 3.4, 0.1, "walk")
		max_walk_speed = maxf(max_walk_speed, float(b._speed))
	check(max_walk_speed <= 3.401 and proxy.position.x <= 3.4 * 0.8 + 0.001, "eight ground adjustments cannot turn 3.4 m/s walking into sprinting")
	print("WALK_HEIGHT_PROBE x=%.3f max_speed=%.3f" % [proxy.position.x, max_walk_speed])
	manager.ground_height = 0.0
	proxy.position = Vector3.ZERO
	b = bot(proxy)
	var water := WaterWorld.new()
	root.add_child(water)
	manager.world = water
	b._speed = 6.0
	b.anim = "run"
	manager._move_bot_towards(b, Vector3(8, 0, 0), 6.4, 0.1, "run")
	check(proxy.position == Vector3.ZERO and b._speed == 0.0 and b.anim == "idle", "unfordable water stops both displacement and the old sprint state")
	# El mismo destino con un metro de agua sí permite vadear, con velocidad
	# reducida. No confundir la profundidad visual con el límite del juego.
	water.depth = 1.0
	b = bot(proxy)
	for i in 50:
		manager._move_bot_towards(b, Vector3(8, 0, 0), 3.4, 0.1, "walk")
	check(proxy.position.x > 7.5 and b._speed <= 3.401, "one metre of water is fordable without excess speed")
	manager.world = null
	water.free()
	test_escort_motion(manager)

	# A cached bend belongs to the previous trip, not to the new retreat.
	var nav_world := WaterWorld.new()
	nav_world.depth = 0.0
	nav_world.bot_nav = BendNav.new()
	root.add_child(nav_world)
	manager.world = nav_world
	proxy.position = Vector3.ZERO
	b = bot(proxy)
	manager._move_bot_towards(b, Vector3(30,0,0), 6.2, 0.1, "run")
	var turn_x := proxy.position.x
	manager._move_bot_towards(b, Vector3(-30,0,0), 6.2, 0.1, "run")
	check(proxy.position.x < turn_x, "new destination behind the bot: first step follows the new route, not the old bend")
	for i in 6:
		manager._move_bot_towards(b, Vector3(-30.0-i*0.05,0,0), 6.2, 0.1, "run")
	check(nav_world.bot_nav.calls == 2, "small forward goal changes reuse the new path (%d searches)" % nav_world.bot_nav.calls)
	manager.world = null
	nav_world.free()

	# Combat cadence: actual movement, a fixed sidestep target, weapon facing,
	# stationary firing intervals and a finite turn when the foe changes side.
	proxy.position = Vector3.ZERO
	foe.position = Vector3(0, 0, -18)
	b = bot(proxy)
	manager._engage_foe(b, foe, 0.1)
	var first_goal: Vector3 = b._combat_step.goal
	check(b.anim == "walk" and manager.shots == 0, "rifle starts a short reposition without firing on the move")
	check(absf(b.rot) < 0.1 and absf(proxy.position.x) > 0.01, "torso keeps the foe in front during lateral movement")
	check(manager._bot_effective_net_anim(b).contains("Strafe"), "rifle lateral movement selects a strafe animation")
	manager._engage_foe(b, foe, 0.1)
	check(b._combat_step.goal == first_goal, "sidestep destination stays fixed instead of moving away every tick")
	var moving_ticks := 0
	var idle_ticks := 0
	for i in 60:
		b.shoot_cooldown = maxf(0.0, b.shoot_cooldown - 0.1)
		manager._engage_foe(b, foe, 0.1)
		if b.anim == "walk": moving_ticks += 1
		if b.anim == "idle": idle_ticks += 1
	check(moving_ticks > 10 and idle_ticks > 10, "combat alternates movement and stable firing intervals")
	check(manager.shots > 0 and manager.moving_shots == 0, "rifle fires only during stable holds")
	proxy.position = Vector3.ZERO
	b = bot(proxy)
	foe.position = Vector3(0, 0, 35)
	var before := manager.shots
	manager._engage_foe(b, foe, 0.1)
	check(absf(b.rot) <= deg_to_rad(22.01), "acquiring a foe behind the bot does not snap its body 180 degrees")
	check(manager.shots == before, "rifle does not fire backwards before the body faces its target")
	for i in 12: manager._engage_foe(b, foe, 0.1)
	check(manager.shots > before, "bot can fire after completing the turn")
	check(manager._bot_has_firing_heading(b, proxy.position + Vector3(0, 10, 0)), "vertical targets do not require an arbitrary horizontal heading")
	b.gun_reloading = true
	before = manager.shots
	manager._engage_foe(b, foe, 0.1)
	check(manager.cover_calls > 0 and not b.is_aiming and manager.shots == before, "reloading bot seeks cover and suspends firing")
	check(manager._bot_effective_net_anim(b) == "riflerun", "running reload keeps moving legs rather than a static full-body clip")
	manager._stop_bot_motion(b)
	check(manager._bot_effective_net_anim(b) == "reload", "stationary reload sends the intent that the client resolves for its posture")
	manager.cover_goal = Vector3.INF
	b["_cover_goal"] = Vector3.INF
	b["_cover_scan_t"] = 0.0
	manager._engage_foe(b, foe, 0.1)
	check(not manager._bot_is_moving(b) and manager.shots == before, "without cover the bot holds still to finish reloading instead of cancelling it forever")
	manager.cover_goal = Vector3(4, 0, 0)
	b.has_rifle = false
	b.gun_reloading = false
	b._bow_drawing = true
	b.anim = "walk"
	check(manager._bot_effective_net_anim(b) == "bow/" + PlayerController.THIRD_PERSON_EXTERNAL_BOW_AIM_WALK_ANIMATION, "bow drawing uses walking legs while moving")
	b.anim = "run"
	check(manager._bot_effective_net_anim(b) == "run", "emergency sprint is not replaced by the slower bow aim walk")
	b.anim = "walk"
	b._bow_drawing = false
	b._bow_shot_anim_until = Time.get_ticks_msec() + 900
	check(manager._bot_effective_net_anim(b) == "walk", "bow release does not freeze the legs during retreat")
	b.anim = "idle"
	check(manager._bot_effective_net_anim(b) == "bow/" + PlayerController.THIRD_PERSON_EXTERNAL_BOW_SHOOT_ANIMATION, "stationary bow release retains the shooting animation")

	# Cached cover cannot trap a bot at an already abandoned destination.
	proxy.position = Vector3.ZERO
	b = bot(proxy)
	b._cover_foe = foe.get_instance_id()
	b._cover_goal = Vector3(4, 0, 0)
	b._cover_scan_t = 1.4
	b._unreachable = [{"pos": Vector3(4, 0, 0), "until": Time.get_ticks_msec() / 1000.0 + 60.0}]
	manager.cover_goal = Vector3(30, 0, 0)
	before = manager.cover_calls
	manager._bot_seek_ballistic_cover(b, foe, 0.1)
	check(manager.cover_calls > before and b._cover_goal == manager.cover_goal, "blacklisted cover is replaced before the scan timeout")
	proxy.position = manager.cover_goal
	manager.clear_los = false
	b._unreachable = []
	manager._bot_seek_ballistic_cover(b, foe, 0.1)
	check(b.crouching and b.anim == "idle" and b._speed == 0.0, "holding actual cover clears old running velocity")

	# Team flanks and perception: heard footsteps never update exact hidden
	# target coordinates or start an assault through a wall.
	proxy.position = Vector3.ZERO
	foe.position = Vector3(0, 0, -30)
	manager.target = foe
	manager.clear_los = true
	b = bot(proxy, 901)
	var mate := Node3D.new()
	root.add_child(mate)
	var mb := bot(mate, 902)
	mb.team_leader_id = 901
	manager.bots = {901: b, 902: mb}
	b._ambush = {"target_id": 5, "pos": foe.position, "seen_msec": Time.get_ticks_msec()}
	mb._ambush = b._ambush.duplicate()
	var g1 := manager._bot_ambush_approach(b, foe.position, 12.5)
	var g2 := manager._bot_ambush_approach(mb, foe.position, 12.5)
	check(g1.x * g2.x < 0.0 and g1.distance_to(foe.position) < 12.5, "teammates approach opposite flanks inside assault distance")
	proxy.position.x += 0.5
	check(manager._bot_ambush_approach(b, foe.position, 12.5) == g1, "ambush waypoint does not wobble with each step")
	check(manager._bot_try_ambush(b, 0.1) and b.crouching and b.held_item == "Fusil de asalto", "stalking bot equips its weapon and moves crouched")
	var last_known: Vector3 = b._ambush.pos
	manager.clear_los = false
	foe.position = Vector3(0, 0, -5)
	foe.set_meta("moving", true)
	check(manager._bot_try_ambush(b, 0.1) and b.get("aggro_target") == null, "audible close enemy behind a wall does not trigger assault")
	check(b._ambush.pos == last_known, "sound behind a wall does not reveal exact live position")
	manager.clear_los = true
	check(manager._bot_try_ambush(b, 0.1) and b.aggro_target == foe and b._ambush.is_empty(), "assault starts once the target is visible and in range")
	b.aggro_target = null
	b._ambush = {"target_id": 5, "pos": last_known, "seen_msec": Time.get_ticks_msec() - 20000}
	manager.clear_los = false
	check(not manager._bot_try_ambush(b, 0.1) and not b.has("_ambush_route"), "lost target abandons both ambush and cached flank")

	# Velocity estimate is independent of the number of aim/burst calls.
	foe.position = Vector3(0.8, 0, 0)
	b._foe_track = {"id": foe.get_instance_id(), "msec": Time.get_ticks_msec() - 200, "tpos": Vector3.ZERO, "vel": Vector3.ZERO}
	var vel := manager._bot_target_velocity(b, foe)
	check(absf(vel.x - 4.0) < 0.15, "observed target running speed uses its real sample interval")
	var anchor: Vector3 = b._foe_track.tpos
	foe.position.x += 0.02
	check(manager._bot_target_velocity(b, foe) == vel and b._foe_track.tpos == anchor, "successive aim calls retain the velocity sample and its anchor")
	check(manager._bot_target_velocity(b, mate) == Vector3.ZERO, "switching enemies does not inherit the old target velocity")
	b._foe_track = {"id": foe.get_instance_id(), "msec": Time.get_ticks_msec() - 200, "tpos": Vector3(-100, 0, 0)}
	check(manager._bot_target_velocity(b, foe) == Vector3.ZERO, "teleport is rejected as target speed")
	b._foe_track = {"id": foe.get_instance_id(), "msec": Time.get_ticks_msec() - 6000, "tpos": foe.position - Vector3(24, 0, 0)}
	check(manager._bot_target_velocity(b, foe) == Vector3.ZERO, "stale observations do not imply that a lost target kept running")
	# Exercise the actual engage/movement path with a stationary human target.
	# Disable random dodge only; range, weapon choice and movement stay real.
	for melee in ["", "Cuchillo", "Hacha", "Lanza"]:
		proxy.set_meta("saved_inventory", [] if melee.is_empty() else [{"name": melee, "type": "weapon", "quantity": 1}])
		var close := 1.2 if melee in ["", "Cuchillo"] else (1.6 if melee == "Hacha" else 2.0)
		for distance in [3.5, 2.5, close + 0.3]:
			proxy.position = Vector3.ZERO; foe.position = Vector3(0, 0, -distance)
			b = bot(proxy); manager.clear_los = true; manager.melee_hits = 0
			manager._engage_foe(b, foe, .05)
			check(manager.melee_hits == 0, melee + " cannot hit across a visible gap at " + str(distance))
			check(proxy.position.z < 0 and b.anim == "run", melee + " continues closing the distance")
		proxy.position = Vector3.ZERO; foe.position = Vector3(0, 0, -close)
		b = bot(proxy); manager.melee_hits = 0
		manager._engage_foe(b, foe, .05)
		check(manager.melee_hits == 1 and b.held_item == melee, melee + " lands a close hit with the weapon it displays")
		check(not b.has_rifle and not manager._bot_is_moving(b), melee + " stops to strike")
		manager.clear_los = false; b.attack_cooldown = 0; manager.melee_hits = 0
		manager._engage_foe(b, foe, .05)
		check(manager.melee_hits == 0, melee + " cannot hit through cover")
		manager.clear_los = true; foe.position = Vector3(0, 2.0, -close); b.attack_cooldown = 0
		manager._engage_foe(b, foe, .05)
		check(manager.melee_hits == 0, melee + " cannot hit an elevated target")
	proxy.set_meta("saved_inventory", [])
	proxy.position = Vector3.ZERO; foe.position = Vector3(0, 0, -.2)
	b = bot(proxy); manager.melee_hits = 0
	manager._engage_foe(b, foe, 1.0)
	check(proxy.position.distance_to(foe.position) > 1.4 and manager.melee_hits == 0, "separation step rechecks reach at the actual strike position")
	proxy.position = Vector3.ZERO; foe.position = Vector3(0, 0, -3.5)
	b = bot(proxy)
	for i in 20:
		manager._engage_foe(b, foe, .05)
		if manager.melee_hits > 0: break
	check(manager.melee_hits == 1 and proxy.position.distance_to(foe.position) <= 1.4, "unarmed bot closes the gap and can still land a nearby punch")
	manager.bots.clear()
	for n in [manager, proxy, foe, mate]: n.free()
	print("BotCombatMovementRegression checks=", checks, " errors=", errors)
	quit(1 if errors else 0)
