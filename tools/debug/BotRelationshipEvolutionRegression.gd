extends SceneTree
const Manager = preload("res://scripts/SurvivorBotManager.gd")
var errors := 0
func check(ok: bool, label: String):
	if not ok:
		errors += 1
		push_error(label)
func _initialize(): call_deferred("run")
func run():
	var manager := Manager.new()
	root.add_child(manager)
	var rels := {"bot_902":{"harm_t":90000,"scar_t":90000,"trust":-.5}}
	manager._restore_relationship_clocks(rels,{"saved_tick_msec":100000,"saved_unix":1000.0},1000,1005.0)
	check(rels.bot_902.harm_t == -14000, "restart retains 15 second injury age even with negative rebased tick")
	check(rels.bot_902.trust == -.5, "restarting preserves trust")
	manager._restore_relationship_clocks(rels,{},1000,1005.0)
	check(not rels.bot_902.has("harm_t") and rels.bot_902.trust == -.5, "legacy clock migration preserves grudge without stale uptime")
	manager.record_social_event(901,"bot_902","Carlos","ally",.03,"equipo")
	var rel := manager.get_bot_relationship(901,"bot_902")
	var trust := float(rel.trust)
	for i in 20:
		manager.record_social_event(901,"bot_902","Carlos","ally",.03,"equipo")
	check(rel.trust == trust and rel.get("shared_experiences",0) == 1, "duplicate proximity observations do not farm friendship")
	check(rel.helped == 0, "shared time is not counted as a rescue or gift")
	manager.record_social_event(901,"bot_902","Carlos","help",.3,"food")
	check(rel.trust > trust and rel.helped == 1, "real help improves relationship immediately")
	manager.record_social_event(901,"bot_902","Carlos","attack",.3,"betrayal")
	rel.bond_t = Time.get_ticks_msec()-30000
	trust = rel.trust
	manager.record_social_event(901,"bot_902","Carlos","ally",.05,"convive")
	check(rel.trust == trust, "proximity cannot erase a fresh attack")
	rel.attacked = 9 # Real accumulated history must not be capped on every restart.
	manager.force_memory_io = true
	manager.memory_path = "res://build/tmp/bot_evolution_memory.json"
	manager._ai_save_memory()
	manager._ai_flush_writes()
	var loaded := Manager.new()
	root.add_child(loaded)
	loaded.force_memory_io = true
	loaded.memory_path = manager.memory_path
	loaded._ai_load_memory()
	var restored := loaded.get_bot_relationship(901,"bot_902")
	check(restored.trust == rel.trust and restored.helped == 1 and restored.attacked == 9, "disk roundtrip preserves help, betrayal and trust")
	check(restored.get("shared_experiences",0) == 1, "shared history persists between sessions")
	check(abs((Time.get_ticks_msec()-int(restored.harm_t))-(Time.get_ticks_msec()-int(rel.harm_t))) < 1000, "disk roundtrip preserves injury age")
	manager.free()
	loaded.free()
	print("BOT_EVOLUTION errors=",errors)
	quit(errors)
