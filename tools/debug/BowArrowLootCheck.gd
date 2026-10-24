extends SceneTree
# Verifies bows and arrows spawn as loot in village houses and city buildings:
# all five item types must appear in both districts, positions must stay inside
# the building footprint, and a second generation with the same seeds must
# produce identical ids/names/positions (deterministic world gen).
const CITY := preload("res://scripts/CityExpansion.gd")

class World extends "res://scripts/Main.gd":
	var generated: Dictionary = {}
	func _ready(): set_process(false)
	func _exit_tree(): pass
	func _create_pickup_item(data: Dictionary) -> void:
		generated[str(data.id)] = {"name": data.name, "pos": data.pos, "floor_y": float(data.get("floor_y", 0.0))}

func _initialize(): call_deferred("run")

const HOUSE_LOOT_DATA := [
	{"origin": Vector3(-25, 0, -18), "w": 11.4, "d": 9.4},
	{"origin": Vector3(-38, 0, 18), "w": 14.0, "d": 11.0},
	{"origin": Vector3(23, 0, 18), "w": 9.0, "d": 7.5},
	{"origin": Vector3(42, 0, 26), "w": 12.5, "d": 10.0},
	{"origin": Vector3(-12, 0, 42), "w": 8.0, "d": 7.0},
	{"origin": Vector3(-35, 0, -40), "w": 10.5, "d": 8.5},
	{"origin": Vector3(30, 0, -35), "w": 13.0, "d": 10.0},
	{"origin": Vector3(-45, 0, -5), "w": 9.5, "d": 8.0},
	{"origin": Vector3(35, 0, -8), "w": 11.0, "d": 9.0},
	{"origin": Vector3(-20, 0, 30), "w": 7.5, "d": 6.5},
]

const WANT := ["Arco de madera", "Arco reforzado", "Flecha de madera", "Flecha de piedra", "Flecha de hueso"]

func _inside_house(pos: Vector3) -> bool:
	for hd in HOUSE_LOOT_DATA:
		var o: Vector3 = hd["origin"]
		if absf(pos.x - o.x) < float(hd["w"]) * 0.5 and absf(pos.z - o.z) < float(hd["d"]) * 0.5:
			return true
	return false

func _inside_city(pos: Vector3) -> bool:
	for d in CITY.BLOCK.BUILDINGS:
		var o: Vector3 = pos - CITY.CENTER - d["position"]
		if absf(o.x) < 6.2 and absf(o.z) < 6.2:
			return true
	return false

func _gen(seed: int) -> World:
	var world := World.new()
	root.add_child(world)
	world._world_rng.seed = seed
	world._create_house_loot()
	return world

func run() -> void:
	var failures := 0
	var w1 := _gen(GameConst.WORLD_SEED)
	var w2 := _gen(GameConst.WORLD_SEED)
	# Determinism: same ids -> same name and position on both generations.
	if w1.generated.size() != w2.generated.size():
		failures += 1
		push_error("conteo distinto entre generaciones: %d vs %d" % [w1.generated.size(), w2.generated.size()])
	for id in w1.generated:
		if not w2.generated.has(id):
			failures += 1
			push_error("id falta en la 2a generacion: " + id)
			continue
		var a: Dictionary = w1.generated[id]
		var b: Dictionary = w2.generated[id]
		if a["name"] != b["name"] or (a["pos"] as Vector3).distance_to(b["pos"]) > 0.0001:
			failures += 1
			push_error("loot no deterministico: %s (%s vs %s)" % [id, a["name"], b["name"]])
	var village_names := {}
	var city_names := {}
	var village_bow_houses := 0
	var village_arrow_houses := 0
	var city_bow_bldgs := 0
	var city_arrow_bldgs := 0
	for id in w1.generated:
		var e: Dictionary = w1.generated[id]
		if id.begins_with("house_loot_bow_") or id.begins_with("house_loot_arrow_"):
			village_names[e["name"]] = true
			if id.begins_with("house_loot_bow_"): village_bow_houses += 1
			else: village_arrow_houses += 1
			if not _inside_house(e["pos"]):
				failures += 1
				push_error("loot de arco/flecha fuera de casa del pueblo: %s en %s" % [id, e["pos"]])
		elif id.begins_with("city_loot_bow_") or id.begins_with("city_loot_arrow_"):
			city_names[e["name"]] = true
			if id.begins_with("city_loot_bow_"): city_bow_bldgs += 1
			else: city_arrow_bldgs += 1
			if not _inside_city(e["pos"]):
				failures += 1
				push_error("loot de arco/flecha fuera de vivienda de ciudad: %s en %s" % [id, e["pos"]])
	for n in WANT:
		if not village_names.has(n):
			failures += 1
			push_error("falta en casas del pueblo: " + n)
		if not city_names.has(n):
			failures += 1
			push_error("falta en casas de la ciudad: " + n)
	if village_bow_houses < 1 or village_arrow_houses < 1 or city_bow_bldgs < 1 or city_arrow_bldgs < 1:
		failures += 1
		push_error("sin arcos/flechas generados")
	print("BOW_LOOT village_bows=%d village_arrows=%d city_bows=%d city_arrows=%d village_types=%d/%d city_types=%d/%d failures=%d" % [
		village_bow_houses, village_arrow_houses, city_bow_bldgs, city_arrow_bldgs,
		village_names.size(), WANT.size(), city_names.size(), WANT.size(), failures])
	w1.free()
	w2.free()
	quit(1 if failures else 0)
