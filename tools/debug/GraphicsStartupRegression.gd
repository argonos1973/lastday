extends SceneTree
const G = preload("res://scripts/GraphicsSettings.gd")
class FakeNet extends Node:
	signal connection_succeeded
	signal connection_failed
	signal auth_rejected(reason)
	signal all_players_ready
	signal player_name_required
	signal server_character_locked(id)
	var is_dedicated_server := false
	var pending_player_name := ""
	var joined := false
	func join_game(_ip: String, _password: String) -> bool:
		joined = true
		return true
class Menu extends "res://scripts/Inicio.gd":
	var launched := false
	func _on_single_player() -> void: launched = true
	func _process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass
var errors := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		errors += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	# No live networking or saved-game reads/writes in automatic startup tests.
	for node_name in ["NetworkManager", "SaveGameManager"]:
		var old := root.get_node_or_null(node_name)
		if old != null:
			root.remove_child(old)
			old.free()
	var net := FakeNet.new()
	net.name = "NetworkManager"
	net.is_dedicated_server = OS.get_cmdline_user_args().has("--dedicated")
	root.add_child(net)
	G.config_path = "res://build/tmp/graphics_effective.cfg"
	G.invalidate_cache()
	var menu := Menu.new()
	root.add_child(menu)
	if net.is_dedicated_server:
		# _ready retorna antes de tocar graficos ni auto-arranques y difiere
		# la carga del mundo; el swap llega a instanciar Main.tscn pero
		# Main._ready aborta al instante en FakeNet.player_connected (antes
		# del world gen) — el ruido del SCRIPT ERROR es esperado aqui.
		await create_timer(0.2).timeout
		check(not menu.launched and not net.joined, "Dedicated boot skips graphics and auto-start")
		print("GRAPHICS_STARTUP errors=", errors, " args=", OS.get_cmdline_user_args())
		quit(errors)
		return
	await create_timer(1.2).timeout
	check(is_equal_approx(root.scaling_3d_scale, 0.75), "Automatic startup applies saved scale")
	if DisplayServer.get_name() != "headless":
		check(DisplayServer.window_get_size() == Vector2i(1280,720), "Automatic startup applies saved resolution")
		check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "Automatic startup applies VSync")
	if OS.get_cmdline_user_args().has("--client"):
		check(net.joined, "Client startup keeps connection route")
	else:
		check(menu.launched, "Automatic single/cinematic route still starts")
	print("GRAPHICS_STARTUP errors=", errors, " args=", OS.get_cmdline_user_args(), " effective=",G.effective_snapshot(root))
	menu.free()
	quit(errors)
