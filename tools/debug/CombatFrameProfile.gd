extends SceneTree
## Editor-binary entry point for the combat frame profile. The scenarios live in
## CombatProfileRunner.gd (a Node) so the exported release client can run the
## very same code through the start menu's opt-in --combat-profile flag.
##   work/godot4.7/Godot.app/Contents/MacOS/Godot --path . --script tools/debug/CombatFrameProfile.gd -- [--out=/abs/file.json] [--soak=600] [--only=a,b] [--secs=8]

func _initialize() -> void:
	root.add_child.call_deferred(load("res://tools/debug/CombatProfileRunner.gd").new())
