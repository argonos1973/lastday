extends SceneTree

# Regression: joining players get a timed HUD toast. Only joins AFTER the
# local player's first player-list sync are announced ("X se ha conectado");
# players already online are summarized once ("En el servidor: ..."). A peer
# still awaiting a name (needs_name) is announced when the name arrives, the
# local player is never announced, offline entries are skipped, and repeated
# list updates never re-announce the same peer.

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

class FakeHud:
	var notices: Array = []
	func show_notice(text: String, duration: float = 4.0) -> void:
		notices.append(text)

func _initialize() -> void:
	print("=== JoinToastRegression ===")
	await process_frame
	var net = root.get_node_or_null("/root/NetworkManager")
	check(net != null, "NetworkManager autoload present")
	var MainScript = load("res://scripts/Main.gd")
	var main = MainScript.new()
	# Not added to the tree: _ready would build the whole world.
	main.net = net
	var hud := FakeHud.new()
	main.hud = hud

	net.is_connected = true
	net.is_host = false
	var my_id: int = net.get_my_id()
	net.players = {
		my_id: {"name": "Yo"},
		101: {"name": "Ana", "char_name": "Ana"},
	}
	main._on_player_list_updated()
	check(hud.notices.size() == 1, "first sync summarizes existing players once")
	check(hud.notices.size() > 0 and hud.notices[0].begins_with("En el servidor:"), "summary notice lists who was already in")
	check(hud.notices.size() > 0 and hud.notices[0].find("Ana") >= 0, "summary names the existing player")
	check(hud.notices.size() > 0 and hud.notices[0].find("Yo") < 0, "local player excluded from summary")

	# A fresh character joins but still awaits a name -> no toast yet.
	hud.notices.clear()
	net.players[102] = {"name": "Jugador_102", "needs_name": true}
	main._on_player_list_updated()
	check(hud.notices.is_empty(), "needs_name join not announced before naming")

	# The name arrives with the next broadcast -> announced by real name.
	net.players[102] = {"name": "Luis", "char_name": "Luis"}
	main._on_player_list_updated()
	check(hud.notices.size() == 1, "one toast when the name arrives")
	check(hud.notices.size() > 0 and hud.notices[0] == "Luis se ha conectado", "toast uses the submitted char_name")

	# Repeated list updates must not re-announce.
	hud.notices.clear()
	main._on_player_list_updated()
	main._on_player_list_updated()
	check(hud.notices.is_empty(), "no duplicate announcements")

	# Reconnecting (living character reclaimed): real name at register, no
	# needs_name -> announced immediately on the next list.
	net.players[103] = {"name": "Maria", "char_name": "Maria"}
	main._on_player_list_updated()
	check(hud.notices.size() == 1 and hud.notices[0] == "Maria se ha conectado", "reclaim join announced immediately")

	# Offline entries (disconnected but kept) are never announced.
	hud.notices.clear()
	net.players[104] = {"name": "Ghost", "offline": true}
	main._on_player_list_updated()
	check(hud.notices.is_empty(), "offline entry never announced")

	# Without a HUD (dedicated server / loading) nothing crashes and the peer
	# is still consumed so a later sync does not misfire.
	hud.notices.clear()
	main.hud = null
	net.players[105] = {"name": "Tardio", "char_name": "Tardio"}
	main._on_player_list_updated()
	main.hud = hud
	main._on_player_list_updated()
	check(hud.notices.is_empty(), "join seen while hud was null stays silent")

	main.free()
	if failures == 0:
		print("JoinToastRegression: ALL PASS")
	else:
		print("JoinToastRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
