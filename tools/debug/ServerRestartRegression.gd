extends SceneTree

# Verifies that a dedicated-server restart really produces a fresh world:
# - boot deletes server_savegame.json (+ .bak) so open doors / drops / depleted
#   loot from the previous session are never restored
# - the stop flag is PID-scoped: a flag written for a dead/other server is not
#   honored (and not eaten) by a fresh instance, so a pending stop request can
#   never be lost — the old server still quits and cannot become a zombie
#
# The stop flag lives in the real user:// dir; it is preserved around the test.

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)

var failures := 0
var _flag_path := ""

func check(ok: bool, message: String) -> void:
	if ok:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func _write_flag(text: String) -> void:
	var f := FileAccess.open(_flag_path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func run() -> void:
	var sgm = root.get_node_or_null("/root/SaveGameManager")
	check(sgm != null, "SaveGameManager autoload available")
	if sgm == null:
		quit(1)
		return
	_flag_path = ProjectSettings.globalize_path("user://stop_server.flag")

	# Preserve a pre-existing flag/save; start clean.
	var had_flag := FileAccess.file_exists(_flag_path)
	var flag_backup := ""
	if had_flag:
		var bf := FileAccess.open(_flag_path, FileAccess.READ)
		if bf != null:
			flag_backup = bf.get_as_text()
			bf.close()
	DirAccess.remove_absolute(_flag_path)
	var had_server_save: bool = sgm.has_server_save()
	var old_server_save: Dictionary = sgm.load_server_game() if had_server_save else {}
	var had_bak := FileAccess.file_exists(ProjectSettings.globalize_path("user://saves/server_savegame.bak.json"))
	var bak_backup := ""
	if had_bak:
		var bf2 := FileAccess.open(ProjectSettings.globalize_path("user://saves/server_savegame.bak.json"), FileAccess.READ)
		if bf2 != null:
			bak_backup = bf2.get_as_text()
			bf2.close()

	# --- Boot wipe: a save full of world state must not survive a restart ---
	var fake := {
		"world": {
			"open_doors": ["Casa abandonada 1 Door", "Casa abandonada 3 Door"],
			"dropped_items": [{"id": "drop_old_1", "name": "Mochila", "type": "backpack", "pos": [1.0, 0.4, 2.0]}],
			"depleted_action_ids": ["loot_fake_1", "mushroom_7"],
			"built_campfires": [{"id": "cf_1", "pos": [5.0, 0.0, 5.0]}]
		},
		"players": {"cid_x": {"pos": [0, 0, 0]}}
	}
	var sf := FileAccess.open(ProjectSettings.globalize_path("user://saves/server_savegame.json"), FileAccess.WRITE)
	check(sf != null, "can write fake server save")
	if sf == null:
		quit(1)
		return
	sf.store_string(JSON.stringify(fake))
	sf.close()
	var sbf := FileAccess.open(ProjectSettings.globalize_path("user://saves/server_savegame.bak.json"), FileAccess.WRITE)
	sbf.store_string(JSON.stringify(fake))
	sbf.close()

	var world: Node = World.new()
	root.add_child(world)

	# Boot sequence in the same order as Main._ready dedicated branch.
	sgm.delete_server_save()
	check(not sgm.has_server_save(), "boot deletes server_savegame.json")
	check(not FileAccess.file_exists(ProjectSettings.globalize_path("user://saves/server_savegame.bak.json")), "boot deletes server_savegame.bak.json")
	SaveGameHooks.preload_saved_world_state(world)
	world._load_server_world_state()
	check(world._server_door_states.is_empty(), "no open doors survive a restart")
	check(world._dropped_items.is_empty(), "no dropped items survive a restart")
	check(world._depleted_action_ids.is_empty(), "no depleted loot ids survive a restart")
	check(world._built_campfires.is_empty(), "no campfires survive a restart")
	check(world._server_saved_players.is_empty(), "no player records survive a restart")

	# --- Stop flag semantics ---
	var my_pid := OS.get_process_id()
	var other_pid := 4000000000 # impossibly high PID

	check(world._consume_server_stop_flag() == false, "no flag -> no stop")

	_write_flag("%d\n" % my_pid)
	check(world._consume_server_stop_flag() == true, "flag naming my PID -> stop")
	check(not FileAccess.file_exists(_flag_path), "consumed flag file removed")

	_write_flag("%d\n" % other_pid)
	check(world._consume_server_stop_flag() == false, "flag naming another PID -> ignored")
	check(FileAccess.file_exists(_flag_path), "flag for another PID is left in place (not eaten)")

	_write_flag("%d\n%d\n" % [other_pid, my_pid])
	check(world._consume_server_stop_flag() == true, "multi-PID flag containing mine -> stop")
	if FileAccess.file_exists(_flag_path):
		var rest := FileAccess.open(_flag_path, FileAccess.READ).get_as_text().strip_edges()
		check(rest == str(other_pid), "my PID removed from flag, other PID kept")

	_write_flag("")
	check(world._consume_server_stop_flag() == true, "empty flag -> legacy kill-all honored")
	check(not FileAccess.file_exists(_flag_path), "empty flag removed after consume")

	_write_flag("not-a-pid")
	check(world._consume_server_stop_flag() == true, "unparseable flag -> kill-all honored")

	# Stale flag (>30 s) targeting another PID gets cleaned up.
	_write_flag("%d\n" % other_pid)
	OS.execute("touch", ["-t", "200001010000.00", _flag_path])
	check(world._consume_server_stop_flag() == false, "stale flag for dead PID -> ignored")
	check(not FileAccess.file_exists(_flag_path), "stale flag for dead PID removed")

	# Boot cleanup keeps a fresh flag (it may be a pending stop for a live server).
	_write_flag("%d\n" % other_pid)
	world._cleanup_stale_stop_flag()
	check(FileAccess.file_exists(_flag_path), "fresh flag for another PID survives boot cleanup")

	world.queue_free()

	# Restore flag/saves
	DirAccess.remove_absolute(_flag_path)
	if had_flag:
		_write_flag(flag_backup)
	sgm.delete_server_save()
	if had_server_save and not old_server_save.is_empty():
		var rf := FileAccess.open(ProjectSettings.globalize_path("user://saves/server_savegame.json"), FileAccess.WRITE)
		rf.store_string(JSON.stringify(old_server_save))
		rf.close()
	if had_bak:
		var rb := FileAccess.open(ProjectSettings.globalize_path("user://saves/server_savegame.bak.json"), FileAccess.WRITE)
		rb.store_string(bak_backup)
		rb.close()

	if failures == 0:
		print("ALL PASS")
	quit(1 if failures > 0 else 0)
