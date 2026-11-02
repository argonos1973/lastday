extends SceneTree
var failures := 0
func check(c, m):
	if c: print("PASS: ", m)
	else: failures += 1; print("FAIL: ", m)
func _init():
	var s = SurvivalStats.new()
	s.health = 80.0; s.blood = 100.0; s.hunger = 80.0; s.thirst = 80.0; s.sleep = 90.0
	# 1 stack: ~0.45 blood/s (drains blood bar, not health directly while blood > 0)
	s.apply_bleeding(1.0)
	for i in range(100): s.tick(0.1, false, 20.0, true, 0.0, false, false, false)
	var drained: float = 100.0 - s.blood
	check(drained > 3.5 and drained < 5.5, "1 stack drains ~4.5 blood/10s (got %.2f)" % drained)
	check(absf(s.bleeding - 1.0) < 0.01, "bleeding stays (no self-clot)")
	# health regen blocked while bleeding
	var before_hp: float = s.health
	var before_blood: float = s.blood
	for i in range(50): s.tick(0.1, false, 20.0, true, 0.0, false, false, false)
	check(s.blood < before_blood and s.health <= before_hp, "blood drains and no HP regen while bleeding")
	# bandage stops bleeding -> blood and HP regenerate when fed/hydrated
	s.stop_bleeding()
	before_hp = s.health
	before_blood = s.blood
	for i in range(100): s.tick(0.1, false, 20.0, true, 0.0, false, false, false)
	check(s.blood > before_blood and s.health > before_hp, "blood and HP regen after bandage (blood %.1f->%.1f, hp %.1f->%.1f)" % [before_blood, s.blood, before_hp, s.health])
	# empty blood drains health
	s.blood = 0.0
	s.apply_bleeding(1.0)
	before_hp = s.health
	for i in range(50): s.tick(0.1, false, 20.0, true, 0.0, false, false, false)
	check(s.health < before_hp, "0 blood drains health (%.2f->%.2f)" % [before_hp, s.health])
	# stacking + cap
	for i in range(10): s.apply_bleeding(1.0)
	check(s.bleeding <= 5.0, "bleeding capped at 5 (got %.2f)" % s.bleeding)
	# serialize round trip (blood + bleeding)
	s.blood = 42.5
	var d := s.to_dict()
	var s2 = SurvivalStats.new(); s2.from_dict(d)
	check(absf(s2.bleeding - s.bleeding) < 0.01 and absf(s2.blood - 42.5) < 0.01, "blood + bleeding survive save round-trip")
	# recipe exists
	var found := false
	for r in CraftingSystem.RECIPES:
		if r.get("output", {}).get("name", "") == "Venda" and int(r.get("inputs", {}).get("Trapos", 0)) >= 3:
			found = true
	check(found, "crafting recipe 3 Trapos -> Venda")
	check(ResourceLoader.exists("res://assets/models/props/bandage_roll.glb"), "bandage_roll.glb imported")
	print("BleedingRegression: %d failures" % failures)
	quit(1 if failures > 0 else 0)
