extends SceneTree
var failures := 0
func check(c, m):
	if c: print("PASS: ", m)
	else: failures += 1; print("FAIL: ", m)
func _init():
	var s = SurvivalStats.new()
	s.health = 100.0; s.hunger = 80.0; s.thirst = 80.0; s.sleep = 90.0
	# 1 stack: ~0.45 HP/s
	s.apply_bleeding(1.0)
	for i in range(100): s.tick(0.1, false, 20.0, true, 0.0, false, false, false)
	var drained: float = 100.0 - s.health
	check(drained > 3.5 and drained < 5.5, "1 stack bleeds ~4.5/10s (got %.2f)" % drained)
	check(absf(s.bleeding - 1.0) < 0.01, "bleeding stays (no self-clot)")
	# regen blocked while bleeding
	var before: float = s.health
	for i in range(50): s.tick(0.1, false, 20.0, true, 0.0, false, false, false)
	check(s.health < before, "no regen while bleeding (%.2f->%.2f)" % [before, s.health])
	# bandage stops it and regen resumes
	s.stop_bleeding()
	before = s.health
	for i in range(100): s.tick(0.1, false, 20.0, true, 0.0, false, false, false)
	check(s.health > before, "regen resumes after bandage (%.2f->%.2f)" % [before, s.health])
	# stacking + cap
	for i in range(10): s.apply_bleeding(1.0)
	check(s.bleeding <= 5.0, "bleeding capped at 5 (got %.2f)" % s.bleeding)
	# serialize round trip
	var d := s.to_dict()
	var s2 = SurvivalStats.new(); s2.from_dict(d)
	check(absf(s2.bleeding - s.bleeding) < 0.01, "bleeding survives save round-trip")
	# recipe exists
	var found := false
	for r in CraftingSystem.RECIPES:
		if r.get("output", {}).get("name", "") == "Venda" and int(r.get("inputs", {}).get("Trapos", 0)) >= 3:
			found = true
	check(found, "crafting recipe 3 Trapos -> Venda")
	check(ResourceLoader.exists("res://assets/models/props/bandage_roll.glb"), "bandage_roll.glb imported")
	print("BleedingRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
