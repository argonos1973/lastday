extends SceneTree
## Boots the real Main world headless (skipping the Inicio menu, which needs a
## window). With LD_COMBAT_PROF=1 the SurvivorBotManager probe driver arms three
## rifle bots on the player and dumps per-shot segment timings every 10 s.
##   LD_COMBAT_PROF=1 work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . --script tools/debug/CombatProbeWorld.gd

func _initialize() -> void:
	print("=== CombatProbeWorld: loading Main.tscn ===")
	var scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
