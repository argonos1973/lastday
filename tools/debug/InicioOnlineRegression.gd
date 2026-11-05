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
	menu.queue_free()
	await process_frame
	print("INICIO_ONLINE errors=",errors)
	quit(0 if errors==0 else 1)
