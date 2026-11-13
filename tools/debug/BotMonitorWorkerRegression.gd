extends SceneTree
class Manager extends "res://scripts/SurvivorBotManager.gd":
 var builds := 0
 func _ai_memory_enabled() -> bool: return true
 func get_full_web_status() -> Dictionary:
  builds += 1
  return {"sequence":builds}
 func _status_write_worker(snapshot: Dictionary) -> void:
  var file := FileAccess.open("res://build/tmp/monitor_worker_test.json",FileAccess.WRITE)
  file.store_string(JSON.stringify(snapshot))
func _initialize(): call_deferred("run")
func run():
 var manager := Manager.new()
 root.add_child(manager)
 manager.memory_path = "res://build/tmp/monitor_worker_memory.json"
 for iteration in range(30):
  manager._ai_save_live_status()
  manager._ai_save_memory()
  while not WorkerThreadPool.is_task_completed(manager._status_write_task) or not WorkerThreadPool.is_task_completed(manager._mem_write_task):
   await process_frame
 manager._ai_flush_writes()
 var result = JSON.parse_string(FileAccess.get_file_as_string("res://build/tmp/monitor_worker_test.json"))
 var ok: bool = result.sequence == 30 and manager._status_write_task == -1 and manager._mem_write_task == -1
 print("BotMonitorWorkerRegression errors=",0 if ok else 1)
 manager.free()
 quit(0 if ok else 1)
