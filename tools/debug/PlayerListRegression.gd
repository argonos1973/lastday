extends SceneTree

# Regression: the HUD players panel lists connected players by character name
# (char_name preferred over the session name), marks dead entries, skips
# offline ones, marks the local player and toggles visibility.

var failures := 0

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _initialize() -> void:
	print("=== PlayerListRegression ===")
	await process_frame
	var HudScript = load("res://scripts/HUD.gd")
	var hud = HudScript.new()
	root.add_child(hud)
	hud.root = Control.new()
	hud.add_child(hud.root)

	var net = root.get_node_or_null("/root/NetworkManager")
	check(net != null, "NetworkManager autoload present")
	net.is_connected = true
	net.players = {
		1: {"name": "Jugador_1"},
		101: {"name": "Jugador_101", "char_name": "Ana"},
		102: {"name": "Bob", "anim": "dead_melee"},
		103: {"name": "Ghost", "offline": true},
	}

	hud._build_players_panel()
	check(hud.players_panel != null, "players panel built")
	check(not hud.players_panel.visible, "players panel starts hidden")
	check(hud.players_hint != null and hud.players_hint.visible, "players hint visible in multiplayer")

	hud.toggle_players_list()
	check(hud.players_panel.visible, "toggle shows the panel")
	check(not hud.players_hint.visible, "hint hides while the list is open")

	var texts: Array = []
	for c in hud.players_list_box.get_children():
		if c is Label:
			texts.append((c as Label).text)
	var joined := "|".join(texts)
	check(joined.find("Ana") >= 0, "char_name preferred over session name")
	check(joined.find("Jugador_101") < 0, "session name not shown when char_name exists")
	check(joined.find("Jugador_1 (tú)") >= 0, "local player marked")
	check(joined.find("Bob †") >= 0 or joined.find("Bob") >= 0 and joined.find("†") >= 0, "dead player marked")
	check(joined.find("Ghost") < 0, "offline player skipped")
	check(texts.size() == 4, "title + 3 online players rendered (got %d)" % texts.size())
	check(texts[0] == "JUGADORES (3)", "title shows online count")

	hud.toggle_players_list()
	check(not hud.players_panel.visible, "toggle hides the panel")

	# Single player: no connection, toggle does nothing
	net.is_connected = false
	net.peer = null
	net.players = {}
	hud.toggle_players_list()
	check(not hud.players_panel.visible, "no list without a connection")

	hud.free()
	if failures == 0:
		print("PlayerListRegression: ALL PASS")
	else:
		print("PlayerListRegression: %d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
