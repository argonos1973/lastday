extends SceneTree

const MainScript = preload("res://scripts/Main.gd")
const HighMountainZone = preload("res://scripts/HighMountainZone.gd")

class TestWorld extends MainScript:
	func _ready() -> void:
		pass
	func _process(_d: float) -> void:
		pass

class TestActor extends "res://scripts/PlayerController.gd":
	func _ready() -> void:
		pass
	func _process(_d: float) -> void:
		pass
	func _physics_process(_d: float) -> void:
		pass

var failures := 0

func check(ok: bool, msg: String) -> void:
	if ok:
		print("PASS: ", msg)
	else:
		failures += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var world := TestWorld.new()
	root.add_child(world)
	current_scene = world

	# 1) Alturas analíticas de la cordillera, meseta y carretera serpenteante que rodea la montaña
	var summit_y := HighMountainZone.ground_height_at(Vector3(HighMountainZone.SUMMIT_CENTER.x, 0.0, HighMountainZone.SUMMIT_CENTER.y))
	check(absf(summit_y - 56.0) < 0.05, "Meseta de la cima a +56.0 m (got %.2f)" % summit_y)
	var peak0_pos: Vector2 = HighMountainZone.PEAKS[0]["pos"]
	var peak0_y := HighMountainZone.ground_height_at(Vector3(peak0_pos.x, 0.0, peak0_pos.y))
	check(peak0_y >= 75.0, "Pico alpino principal >= 75 m (got %.2f)" % peak0_y)
	var south_flank_y := HighMountainZone.ground_height_at(Vector3(-348.0, 0.0, -258.0))
	var west_flank_y := HighMountainZone.ground_height_at(Vector3(-468.0, 0.0, -346.0))
	var north_flank_y := HighMountainZone.ground_height_at(Vector3(-380.0, 0.0, -448.0))
	check(south_flank_y > 8.0 and west_flank_y > south_flank_y + 12.0 and north_flank_y > west_flank_y + 10.0,
		"Carretera rodea la montaña subiendo progresivamente Sur(%.1fm)->Oeste(%.1fm)->Norte(%.1fm)" % [south_flank_y, west_flank_y, north_flank_y])

	# 2) Instanciar la zona de alta montaña + base militar + torre Green Mountain + bosque alpino
	await HighMountainZone.create(world, false)
	await physics_frame
	await physics_frame

	var hm_node := world.get_node_or_null("HighMountainZone")
	check(hm_node != null, "HighMountainZone instanciado")
	var road_mi := hm_node.get_node_or_null("HighMountainRoad") as MeshInstance3D if hm_node != null else null
	check(road_mi != null and road_mi.mesh != null, "Carretera HighMountainRoad instanciada hasta la cima")
	check(HighMountainZone.on_road(Vector3(9.0, 0.0, -205.0), 0.5), "Carretera arranca sobre la calzada principal Norte-Sur en (9, -205)")
	check(HighMountainZone.on_road(Vector3(1.0, 0.0, -220.0), 0.5), "Curva de desvio hacia el Oeste pasando por (1, -220)")
	check(HighMountainZone.on_road(Vector3(-348.0, 0.0, -258.0), 0.5), "Carretera bordea la ladera Sur de la montaña (-348, -258)")
	check(HighMountainZone.on_road(Vector3(-468.0, 0.0, -346.0), 0.5), "Carretera bordea la ladera Oeste de la montaña (-468, -346)")
	check(HighMountainZone.on_road(Vector3(-380.0, 0.0, -448.0), 0.5), "Carretera bordea la ladera Norte de la montaña (-380, -448)")
	check(HighMountainZone.on_road(Vector3(-350.0, 56.0, -350.0), 0.5), "Carretera llega hasta la puerta de la Base Militar de la cima (-350, -350)")
	var alpine_mms := hm_node.find_children("MountainAlpineForestMM_*", "MultiMeshInstance3D", false, false) if hm_node != null else []
	var alpine_trees := 0
	for m in alpine_mms:
		if not str(m.name).ends_with("_leaves") and (m as MultiMeshInstance3D).multimesh != null:
			alpine_trees += (m as MultiMeshInstance3D).multimesh.instance_count
	check(alpine_trees >= 250, "Bosque alpino plantado en la montaña y alrededor de la base (%d árboles)" % alpine_trees)
	var massif_mi := hm_node.get_node_or_null("HighMountainMassif") as MeshInstance3D if hm_node != null else null
	check(massif_mi != null and massif_mi.material_override is ShaderMaterial, "HighMountainMassif usa ShaderMaterial PBR de montaña")
	var outcrop_mms := hm_node.find_children("MountainRockOutcropsMM_*", "MultiMeshInstance3D", false, false) if hm_node != null else []
	var outcrop_total := 0
	var rocks_on_road := 0
	for om in outcrop_mms:
		var omm := (om as MultiMeshInstance3D).multimesh
		if omm == null:
			continue
		outcrop_total += omm.instance_count
		for j in range(omm.instance_count):
			var rock_origin := omm.get_instance_transform(j).origin
			if HighMountainZone.on_road(rock_origin, 0.5):
				rocks_on_road += 1
	check(outcrop_total >= 25, "Afloramientos rocosos y escarpes de granito instanciados en laderas y taludes (%d rocas)" % outcrop_total)
	check(rocks_on_road == 0, "Ninguna roca invade la calzada de la carretera de montaña (%d)" % rocks_on_road)
	var comms_tower := hm_node.get_node_or_null("GreenMountainCommsTower") as Node3D if hm_node != null else null
	check(comms_tower != null, "GreenMountainCommsTower instanciada en la cima")
	if comms_tower != null:
		var tower_bodies := comms_tower.find_children("*", "StaticBody3D", true, false)
		check(tower_bodies.size() <= 3, "Colisiones de la torre fusionadas eficientemente (%d StaticBody3D)" % tower_bodies.size())
	var watch_tower := world.get_node_or_null("SummitMilitaryWatchTower") as Node3D
	check(watch_tower != null, "Torre de vigilancia actual instanciada en la base de la cima")
	var tent0 := world.get_node_or_null("SummitMilitaryTent_0") as Node3D
	var tent1 := world.get_node_or_null("SummitMilitaryTent_1") as Node3D
	check(tent0 != null and tent1 != null, "Tiendas militares instanciadas en la cima")
	if tent0 != null and tent1 != null:
		check(absf(tent0.global_position.y - HighMountainZone.SUMMIT_HEIGHT) < 4.0 and absf(tent1.global_position.y - HighMountainZone.SUMMIT_HEIGHT) < 4.0,
			"Tiendas militares apoyadas en el suelo de la meseta (+56 m), sin flotar (y=%.2f, %.2f)" % [tent0.global_position.y, tent1.global_position.y])

	# Verificar que la aguja supera los 65 m locales (> 120 m sobre el valle, edificio más alto del juego)
	var detail_mesh := comms_tower.find_child("Detail_CommsTower", true, false) as MeshInstance3D if comms_tower != null else null
	var top_local_y := detail_mesh.get_aabb().end.y if detail_mesh != null else 0.0
	var top_world_y := (comms_tower.global_position.y if comms_tower != null else 0.0) + top_local_y
	check(top_local_y > 66.0 and top_world_y > 122.0, "Torre Green Mountain es el edificio más alto: %.1f m local / %.1f m mundial" % [top_local_y, top_world_y])

	# 3) Verificar que los 6 pisos circulares tienen colisión de suelo firme para establecerse
	var space := world.get_world_3d().direct_space_state
	var deck_heights := [14.0, 19.5, 25.0, 31.0, 41.0, 52.0]
	var deck_radii := [5.4, 5.2, 5.0, 4.4, 2.7, 2.4]
	for d_i in range(deck_heights.size()):
		var dy: float = HighMountainZone.SUMMIT_HEIGHT + deck_heights[d_i]
		var dr: float = deck_radii[d_i]
		# Probar en el lado opuesto a las escotillas (ángulo 180° local)
		var probe_dir := Vector3(0.0, 0.0, -dr).rotated(Vector3.UP, deg_to_rad(HighMountainZone.BASE_YAW_DEG))
		var probe_xz := comms_tower.global_position + probe_dir
		var rq := PhysicsRayQueryParameters3D.create(
			Vector3(probe_xz.x, dy + 1.5, probe_xz.z),
			Vector3(probe_xz.x, dy - 1.5, probe_xz.z)
		)
		rq.collision_mask = 1
		var hit := space.intersect_ray(rq)
		check(not hit.is_empty() and absf((hit["position"] as Vector3).y - dy) < 0.35,
			"Piso %d (cota +%.1f m / %.1f m mundial) tiene suelo sólido transitable" % [d_i + 1, deck_heights[d_i], dy])

	# 4) Verificar animación de escalera de mano y subida por los 6 tramos hasta arriba del todo
	var ladders := get_nodes_in_group("ladder_volume")
	check(ladders.size() == 6, "6 tramos de escalera de mano registrados (got %d)" % ladders.size())

	var actor := TestActor.new()
	world.add_child(actor)
	actor.stats = preload("res://scripts/SurvivalStats.gd").new()
	actor.add_child(actor.stats)
	actor.inventory = preload("res://scripts/Inventory.gd").new()
	actor.add_child(actor.inventory)
	actor.setup_as_puppet()
	actor.is_puppet = false

	var ap: AnimationPlayer = actor.third_person_animation_player
	check(ap != null and ap.has_animation("ladder/climbing"), "Animación 'ladder/climbing' instalada en el personaje")

	# Simular subida por LOS 6 TRAMOS (0..5) y verificar que cada desembarco cae sobre suelo firme
	for f_idx in range(6):
		var lnode := hm_node.get_node_or_null("CommsTowerLadderVolume_%d" % f_idx) as Node3D
		var cxz: Vector2 = lnode.get_meta("ladder_center_xz")
		var y_bot: float = float(lnode.get_meta("ladder_bottom_y"))
		var y_top: float = float(lnode.get_meta("ladder_top_y"))
		actor.global_position = Vector3(cxz.x, y_bot + 0.1, cxz.y)
		actor.is_climbing_ladder = false
		var climbed := actor._update_ladder_climb_physics(Vector2(0.0, -1.0), 0.1)
		check(climbed and actor.is_climbing_ladder, "Engancha escalera de mano tramo %d al pulsar W" % f_idx)
		actor._update_third_person_animation(true, 0.1)
		check(ap.current_animation == "ladder/climbing", "Reproduce animación ladder/climbing en tramo %d" % f_idx)
		var guard := 0
		while actor.is_climbing_ladder and guard < 250:
			actor._update_ladder_climb_physics(Vector2(0.0, -1.0), 0.1)
			guard += 1
		check(not actor.is_climbing_ladder and absf(actor.global_position.y - (y_top + 0.08)) < 0.25,
			"Desembarca en el piso superior del tramo %d a y=%.2f m" % [f_idx, actor.global_position.y])
		var land_rq := PhysicsRayQueryParameters3D.create(
			actor.global_position + Vector3(0.0, 0.8, 0.0),
			actor.global_position - Vector3(0.0, 1.2, 0.0)
		)
		land_rq.collision_mask = 1
		var land_hit := space.intersect_ray(land_rq)
		check(not land_hit.is_empty() and absf((land_hit["position"] as Vector3).y - y_top) < 0.35,
			"Punto de desembarco superior del tramo %d tiene suelo sólido debajo (evita caída al vacío)" % f_idx)

	# Verificar enganche en escotilla superior al caminar de frente con W y bajada completa con S
	var top_ladder := hm_node.get_node_or_null("CommsTowerLadderVolume_4") as Node3D
	var top_cxz: Vector2 = top_ladder.get_meta("ladder_center_xz")
	var top_y1: float = float(top_ladder.get_meta("ladder_top_y"))
	var top_y0: float = float(top_ladder.get_meta("ladder_bottom_y"))
	actor.global_position = Vector3(top_cxz.x, top_y1 + 0.08, top_cxz.y)
	actor.is_climbing_ladder = false
	var grabbed_top_w := actor._update_ladder_climb_physics(Vector2(0.0, -1.0), 0.05)
	check(grabbed_top_w and actor.is_climbing_ladder, "Caminar con W hacia una escotilla superior engancha la escalera en vez de caer por el hueco")
	var down_guard := 0
	while actor.is_climbing_ladder and down_guard < 250:
		actor._update_ladder_climb_physics(Vector2(0.0, 1.0), 0.1)
		down_guard += 1
	check(not actor.is_climbing_ladder and absf(actor.global_position.y - (top_y0 + 0.06)) < 0.25,
		"Bajada con S desembarca en el piso inferior a y=%.2f m" % actor.global_position.y)

	# 5) Verificar que las tiendas militares de la cima y el búnker dan cobijo (_is_player_in_house)
	if tent0 != null and tent1 != null:
		check(world._is_player_in_house(tent0.global_position + Vector3(0.0, 0.5, 0.0)), "Tienda militar 0 de la cima cuenta como cobijo interior")
		check(world._is_player_in_house(tent1.global_position + Vector3(0.0, 0.5, 0.0)), "Tienda militar 1 de la cima cuenta como cobijo interior")

	world.free()
	print("HighMountainTowerRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
