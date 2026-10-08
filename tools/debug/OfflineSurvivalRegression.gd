extends SceneTree
const Main = preload("res://scripts/Main.gd")
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, label: String) -> void:
	print("PASS " if value else "FAIL ", label)
	if not value: failures += 1
func run() -> void:
	var world := Main.new()
	root.add_child(world)

	# Parking a proxy stamps offline_since_unix inside saved_extra.
	var proxy := Node3D.new()
	proxy.set_meta("client_id", "cid_test")
	proxy.set_meta("saved_extra", {"stats_extra": {"survival_seconds": 100.0}, "tamed_wolf": "wolf_1"})
	root.add_child(proxy)
	world.server_proxies[77] = proxy
	var before := Time.get_unix_time_from_system()
	world._on_remote_player_disconnected(77)
	var parked_extra: Dictionary = proxy.get_meta("saved_extra", {})
	check(parked_extra.has("offline_since_unix"), "disconnect stamps the offline time")
	check(float(parked_extra.get("offline_since_unix", 0.0)) >= before, "stamp is the disconnect moment")
	check(world.proxy_by_client_id.has("cid_test"), "proxy stays parked by client id")
	check(str(parked_extra.get("tamed_wolf", "")) == "wolf_1", "stamp merge keeps other extra fields")

	# The restore injects the parked gap into survival_seconds.
	parked_extra["offline_since_unix"] = Time.get_unix_time_from_system() - 600.0
	var merged: Dictionary = world._apply_offline_survival_time(parked_extra)
	check(absf(float(merged["stats_extra"]["survival_seconds"]) - 700.0) < 2.0, "offline gap counts toward survival time")
	check(absf(float(parked_extra["stats_extra"]["survival_seconds"]) - 100.0) < 0.001, "stored record is not mutated")
	check(str(merged.get("tamed_wolf", "")) == "wolf_1", "injection preserves the rest of extra")

	# Parked bodies decay their needs very slowly (~25x slower than online).
	var dp := Node3D.new()
	dp.set_meta("saved_hunger", 50.0)
	dp.set_meta("saved_thirst", 30.0)
	dp.set_meta("saved_extra", {"stats_extra": {"sleep": 80.0, "energy": 60.0}})
	root.add_child(dp)
	world._apply_offline_stat_decay(dp, 10.0)
	check(absf(float(dp.get_meta("saved_hunger")) - 49.95) < 0.001, "offline hunger decays slowly")
	check(absf(float(dp.get_meta("saved_thirst")) - 29.96) < 0.001, "offline thirst decays slowly")
	var dp_se: Dictionary = dp.get_meta("saved_extra", {}).get("stats_extra", {})
	check(absf(float(dp_se.get("sleep", -1.0)) - 79.97) < 0.001, "offline sleep decays slowly")
	check(absf(float(dp_se.get("energy", -1.0)) - 59.975) < 0.001, "offline energy decays slowly")
	# Decay is floored at zero — a long offline stay weakens but never kills.
	dp.set_meta("saved_hunger", 0.01)
	dp.set_meta("saved_thirst", 0.01)
	world._apply_offline_stat_decay(dp, 1000.0)
	check(float(dp.get_meta("saved_hunger")) == 0.0, "offline hunger floors at zero")
	check(float(dp.get_meta("saved_thirst")) == 0.0, "offline thirst floors at zero")
	var bare := Node3D.new()
	root.add_child(bare)
	world._apply_offline_stat_decay(bare, 10.0)
	check(float(bare.get_meta("saved_hunger")) < 100.0, "bare proxy gets decayed needs too")

	# Online records (no stamp) pass through unchanged.
	var online: Dictionary = world._apply_offline_survival_time({"stats_extra": {"survival_seconds": 55.0}})
	check(absf(float(online["stats_extra"]["survival_seconds"]) - 55.0) < 0.001, "no stamp keeps the saved value")
	var empty_extra: Dictionary = world._apply_offline_survival_time({})
	check(float(empty_extra.get("stats_extra", {}).get("survival_seconds", 0.0)) == 0.0, "empty extra stays empty")

	world.queue_free()
	print("failures=%d" % failures)
	quit(1 if failures > 0 else 0)
