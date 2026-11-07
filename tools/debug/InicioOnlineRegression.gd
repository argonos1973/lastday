extends SceneTree
class FakeNet extends RefCounted:
	var is_connected := true
	var closed := false
	func close_connection() -> void:
		closed = true
		is_connected = false
class Menu extends "res://scripts/Inicio.gd":
	var starts := 0
	var joins := 0
	var prompts := 0
	func _ready() -> void:
		_online_menu = true
		_status_label = Label.new()
		add_child(_status_label)
	func _process(_delta: float) -> void: pass
	func _update_char_view() -> void: pass
	func _apply_char_selection() -> void: pass
	func _connect_menu_server() -> void:
		joins += 1
		_joining = true
	func _prompt_player_name() -> void: prompts += 1
	func _start_game() -> void:
		starts += 1
		_started = true
var errors := 0
func check(ok: bool, label: String) -> void:
	if not ok: errors += 1
	print("PASS " if ok else "FAIL ",label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var menu := Menu.new()
	root.add_child(menu)
	menu._mode="join"
	menu._net=FakeNet.new()
	menu._session_ready=true
	menu._mp_locked=true
	menu._maybe_start_game()
	check(menu.starts==0,"Recovered character waits for Play")
	menu._on_play()
	menu._on_play()
	check(menu.starts==1,"Play enters recovered character only once")
	menu._started=false
	menu._on_net_failed()
	menu._on_play()
	menu._on_play()
	check(menu.joins==1,"Retry does not duplicate connection attempts")
	menu._play_requested=false
	menu._net=FakeNet.new()
	var net = menu._net
	menu._on_player_name_required()
	check(not net.closed and menu._name_request_pending and menu.prompts==0,"Menu keeps new registration until Play")
	menu._on_play()
	menu._mode="join"
	menu._net=FakeNet.new()
	menu._on_player_name_required()
	check(menu.prompts==1,"New player enters naming flow after Play")
	menu._name_request_pending=false
	menu._session_ready=false
	menu._maybe_start_game()
	check(menu.starts==1,"Transport alone cannot start world")
	menu._on_net_ready()
	await create_timer(.4).timeout
	check(menu.starts==2,"Accepted registration starts requested game")
	# Estado periodico: en reposo el menu reconecta cada intervalo para pedir
	# el estado del personaje; se pausa con join en curso, Play o prompt.
	menu._started=false
	menu._mode="join"
	menu._play_requested=false
	menu._name_request_pending=false
	menu._joining=false
	menu._net=FakeNet.new()
	var joins_before: int = menu.joins
	menu._tick_server_status(menu.SERVER_STATUS_INTERVAL)
	check(menu.joins==joins_before+1,"Menu repolls server on status interval")
	menu._joining=false
	menu._play_requested=true
	menu._tick_server_status(menu.SERVER_STATUS_INTERVAL)
	check(menu.joins==joins_before+1,"Status poll pauses once Play is requested")
	menu._play_requested=false
	menu._name_request_pending=true
	menu._tick_server_status(menu.SERVER_STATUS_INTERVAL)
	check(menu.joins==joins_before+1,"Status poll pauses while name prompt pending")
	menu._name_request_pending=false
	# Un reclaim que murio hace que el servidor pida nombre: la tarjeta
	# bloqueada se libera y el picker cae en una tarjeta elegible para join.
	menu.CHAR_CONFIGS.push_front({"id":"saved_server","name":"Ana","hair_style":"short","top":Color(1,0,0),"bottom":Color(0,0,1),"shoes":Color(0.2,0.2,0.2),"hair":Color(0,0,0),"skin":Color(0.8,0.7,0.6),"is_saved":true,"is_server_save":true,"server_pd":{}})
	menu._char_index=0
	menu._mp_locked=true
	menu._on_player_name_required()
	check(not menu._mp_locked,"Dead reclaim unlocks the picker")
	var server_card_left := false
	for cfg in menu.CHAR_CONFIGS:
		if str(cfg.get("id","")) == "saved_server":
			server_card_left = true
	check(not server_card_left,"Dead reclaim drops the server card")
	check(menu._card_selectable(menu.CHAR_CONFIGS[menu._char_index]),"Picker lands on a joinable card")
	menu._name_request_pending=false
	# Una consulta de estado se cierra sola al resolverse: el menu no retiene
	# la conexion ni el slot entre sondeos.
	menu._status_poll=true
	menu._mode="join"
	menu._net=FakeNet.new()
	var status_net = menu._net
	menu._maybe_start_game()
	check(status_net.closed and menu._net==null and not menu._status_poll,"Status poll releases the connection once resolved")
	# El connection_failed rezagado del cierre local no deshace el estado.
	menu._on_net_failed()
	check(not menu._closing_status,"Late connection_failed from status close is swallowed")
	menu.queue_free()
	await process_frame
	print("INICIO_ONLINE errors=",errors)
	quit(0 if errors==0 else 1)
