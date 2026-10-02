extends SceneTree

# Regresion del preview de personajes en Inicio:
# - Idle.fbx se carga, retargeta al rig del preview y queda reproduciendo.
# - Conectar a un servidor con personaje vivo (server_character_locked) crea/
#   actualiza la tarjeta saved_server con el equipo real y bloquea el picker.
# - needs_name (personaje nuevo o muerto) mantiene la seleccion libre.
# - "Un jugador" deja el picker libre siempre.
# Uso: Godot --headless --path . --script tools/debug/PreviewLockRegression.gd

var _failures := 0

class FakeSGM extends Node:
	# Simula un SaveGameManager con partida local y save de servidor.
	func has_save() -> bool:
		return true
	func has_server_save() -> bool:
		return true
	func load_server_game() -> Dictionary:
		return {"players": {"cid1": {"char_name": "SrvChar", "top_color": "0.4,0.4,0.4"}}}
	func get_saved_character_config() -> Dictionary:
		return {"id": "saved", "name": "Local", "top": Color(0.3,0.3,0.3),
			"bottom": Color(0.2,0.2,0.2), "shoes": Color(0.1,0.1,0.1),
			"hair": Color(0.2,0.15,0.1), "skin": Color(0.8,0.7,0.6),
			"is_saved": true}

func _ok(cond: bool, msg: String) -> void:
	if cond:
		print("PASS: %s" % msg)
	else:
		_failures += 1
		push_error("FAIL: %s" % msg)

func _initialize() -> void:
	call_deferred("_run")

func _find_skel(n: Node) -> Skeleton3D:
	if n is Skeleton3D:
		return n
	for c in n.get_children():
		var r = _find_skel(c)
		if r != null:
			return r
	return null

func _run() -> void:
	var InicioScript = load("res://scripts/Inicio.gd")
	var inicio: Control = InicioScript.new()

	# --- 1) Idle.fbx carga y tiene pistas de hueso mixamorig ---
	var anim: Animation = inicio._load_preview_idle_animation()
	_ok(anim != null, "Idle.fbx produces an Animation")
	if anim == null:
		quit(1)
		return
	_ok(anim.length > 0.0, "idle animation has length %.2f" % anim.length)
	var found_bone_track := false
	for t in range(anim.get_track_count()):
		if str(anim.track_get_path(t)).find("mixamorig") >= 0:
			found_bone_track = true
			break
	_ok(found_bone_track, "idle animation targets mixamorig bones")

	# --- 2) Retarget sobre Remy.glb: preview/idle queda sonando ---
	var remy: Node3D = load("res://assets/characters/Remy.glb").instantiate()
	inicio._play_preview_animation(remy)
	var player: AnimationPlayer = inicio._find_animation_player(remy)
	_ok(player != null, "preview model gets an AnimationPlayer")
	_ok(player != null and player.has_animation("preview/idle"), "preview/idle exists on model player")
	_ok(player != null and str(player.current_animation) == "preview/idle", "preview/idle is playing")
	_ok(player != null and player.is_playing(), "animation player is playing")
	var retargeted: Animation = player.get_animation("preview/idle") if player != null else null
	var skel := _find_skel(remy)
	var ok_paths := 0
	if retargeted != null and skel != null:
		for t in range(retargeted.get_track_count()):
			var p := str(retargeted.track_get_path(t))
			var colon := p.find(":")
			if colon < 0:
				continue
			if skel.find_bone(p.substr(colon + 1)) == -1:
				continue
			ok_paths += 1
	_ok(retargeted != null and retargeted.get_track_count() > 0, "retargeted idle keeps tracks (%d)" % (retargeted.get_track_count() if retargeted else -1))
	_ok(ok_paths > 0, "retargeted tracks resolve on Remy skeleton (%d)" % ok_paths)
	_ok(retargeted != null and retargeted.loop_mode == Animation.LOOP_LINEAR, "idle loops")
	# La toma mixamo_com lleva "mirar alrededor" en cuello/cabeza — el menu
	# debe mantener la cabeza al frente: esas pistas no se retargetan.
	var head_tracks := 0
	if retargeted != null:
		for t in range(retargeted.get_track_count()):
			var p := str(retargeted.track_get_path(t))
			if p.find("Head") >= 0 or p.find("Neck") >= 0:
				head_tracks += 1
	_ok(head_tracks == 0, "head/neck tracks dropped (idle must face forward)")
	# La pose realmente cambia al avanzar el player (no es un play muerto).
	if player != null and skel != null:
		var spine_idx := skel.find_bone("mixamorig_Spine")
		if spine_idx == -1:
			spine_idx = 0
		var q0 := skel.get_bone_pose_rotation(spine_idx)
		player.advance(0.6)
		var q1 := skel.get_bone_pose_rotation(spine_idx)
		_ok(q0 != q1, "bone pose moves when idle advances")
	remy.free()

	# --- 3) Instancia en arbol (UI real) para probar el bloqueo ---
	root.add_child(inicio)
	_ok(inicio._btn_prev != null and inicio._btn_next != null, "nav buttons exist")
	_ok(not inicio._mp_locked, "picker starts unlocked")
	var free_count: int = inicio.CHAR_CONFIGS.size()
	inicio._char_index = 1
	inicio._on_char_prev()
	_ok(inicio._char_index == 0, "nav works while unlocked")

	# --- 4) Reclaim del servidor: tarjeta bloqueada con equipo vivo ---
	var payload := {
		"char_name": "Sami",
		"top": Color(0.4, 0.5, 0.2), "bottom": Color(0.2, 0.2, 0.25),
		"shoes": Color(0.1, 0.1, 0.1), "hair": Color(0.3, 0.2, 0.1),
		"skin": Color(0.8, 0.7, 0.6),
		"top_camo": false, "bottom_camo": false,
		"equipped_clothing": "Chaqueta militar,Pantalones militares,Botas survival,Sombrero de pescador",
		"equipped_backpack": "Mochila pequena",
		"held_item": "Cuchillo",
		"inventory": [],
		"survival_seconds": 1500.0,
	}
	inicio._on_server_character_locked(payload)
	_ok(inicio._mp_locked, "picker locked after server reclaim")
	var locked_idx: int = inicio._char_index
	_ok(str(inicio.CHAR_CONFIGS[locked_idx].get("id", "")) == "saved_server", "locked index is the saved_server card")
	_ok(str(inicio.CHAR_CONFIGS[locked_idx].get("name", "")) == "Sami", "locked card uses server name")
	_ok(inicio.CHAR_CONFIGS[locked_idx].get("server_pd") != null, "locked card embeds live equipment payload")
	_ok(inicio._btn_prev.disabled and inicio._btn_next.disabled, "nav buttons disabled while locked")
	_ok(str(inicio._char_title_label.text).find("SERVIDOR") >= 0, "title shows server-character state")
	# Nav guard: arrows must not move the card while locked.
	inicio._on_char_next()
	_ok(inicio._char_index == locked_idx, "next arrow ignored while locked")
	inicio._on_char_prev()
	_ok(inicio._char_index == locked_idx, "prev arrow ignored while locked")
	# GameSession got the server card applied.
	var gsess = root.get_node_or_null("GameSession")
	if gsess != null:
		_ok(str(gsess.selected_character_id) == "saved_server", "GameSession carries saved_server id")
		_ok(str(gsess.get_meta("char_name", "")) == "Sami", "GameSession carries server char name")
	# Total de tarjetas: +1 si no existia, o igual si el save local ya puso una.
	_ok(inicio.CHAR_CONFIGS.size() == free_count or inicio.CHAR_CONFIGS.size() == free_count + 1,
		"card count sane after upsert (%d -> %d)" % [free_count, inicio.CHAR_CONFIGS.size()])

	# --- 5) El payload server_pd alimenta el preview de equipo ---
	var SaveInt = load("res://scripts/InicioSaveIntegration.gd")
	var pd: Dictionary = SaveInt._saved_player_data(inicio, inicio.CHAR_CONFIGS[locked_idx])
	_ok(str(pd.get("clothing", "")) == "Chaqueta militar,Pantalones militares,Botas survival,Sombrero de pescador",
		"server_pd feeds clothing to preview")
	var ef: Dictionary = SaveInt._equipment_fields(pd)
	_ok(str(ef.get("equipped_backpack", "")) == "Mochila pequena", "equipment fields carry backpack")
	_ok(str(ef.get("held_item", "")) == "Cuchillo", "equipment fields carry held item")
	_ok(int(ef.get("survival_seconds", 0)) == 1500, "equipment fields carry survival time")

	# Un payload sin colores reales (registro sin apariencia -> alpha 0) no
	# debe pintar la tarjeta de negro: conserva los colores ya conocidos.
	var bare := {"char_name": "Sami", "top": Color(0,0,0,0), "skin": Color(0,0,0,0)}
	var idx2: int = inicio._upsert_server_card(bare)
	var cfg2: Dictionary = inicio.CHAR_CONFIGS[idx2]
	_ok((cfg2["top"] as Color).a > 0.0, "zero-alpha top falls back to known color")
	_ok((cfg2["skin"] as Color).a > 0.0, "zero-alpha skin falls back to known color")
	_ok((cfg2["top"] as Color) == Color(0.4, 0.5, 0.2), "keeps previous card colors when payload has none")
	# Una tarjeta ya ennegrecida por un payload anterior se cura a defaults.
	inicio.CHAR_CONFIGS[idx2]["skin"] = Color(0,0,0,0)
	var idx3: int = inicio._upsert_server_card(bare)
	_ok(inicio.CHAR_CONFIGS[idx3]["skin"] == Color(0.8, 0.7, 0.6), "stale zero-alpha card color heals to default")

	# --- 6) needs_name (personaje nuevo/muerto): picker libre ---
	inicio._set_picker_locked(false)
	_ok(not inicio._mp_locked, "unlock releases the flag")
	_ok(not inicio._btn_prev.disabled and not inicio._btn_next.disabled, "nav re-enabled")
	_ok(str(inicio._char_title_label.text) == "SELECCIONA PERSONAJE", "title restored")

	# --- 7) Join pick: las tarjetas guardadas no son elegibles ---
	# Añade una tarjeta de partida local junto a la saved_server ya insertada.
	inicio.CHAR_CONFIGS.insert(1, {
		"id": "saved", "name": "Local", "top": Color(0.3, 0.3, 0.3),
		"bottom": Color(0.2, 0.2, 0.2), "shoes": Color(0.1, 0.1, 0.1),
		"hair": Color(0.2, 0.15, 0.1), "skin": Color(0.8, 0.7, 0.6),
		"is_saved": true,
	})
	inicio._char_index = 0
	inicio._prejoin_card_id = "saved"
	inicio._mode = "join"
	inicio._clamp_to_selectable_card()
	_ok(not inicio._is_mp_save_card(inicio.CHAR_CONFIGS[inicio._char_index]),
		"join clamps off the saved_server card")
	# Navegacion completa: nunca aterriza en tarjetas guardadas.
	var seen_ids := {}
	for _i in range(inicio.CHAR_CONFIGS.size()):
		inicio._on_char_next()
		seen_ids[str(inicio.CHAR_CONFIGS[inicio._char_index].get("id", ""))] = true
	_ok(not seen_ids.has("saved") and not seen_ids.has("saved_server"),
		"join nav never lands on save cards (saw %s)" % str(seen_ids.keys()))
	_ok(seen_ids.has("remy") and seen_ids.has("dris"), "join nav still reaches base characters")
	# De vuelta al menu (fallo/cancel/single): la tarjeta del servidor se
	# retira y se restaura la tarjeta previa al join.
	inicio._mode = ""
	inicio._exit_join_pick()
	var ss_left := false
	for c in inicio.CHAR_CONFIGS:
		if str(c.get("id", "")) == "saved_server":
			ss_left = true
	_ok(not ss_left, "leaving join removes the transient server card")
	_ok(str(inicio.CHAR_CONFIGS[inicio._char_index].get("id", "")) == "saved",
		"leaving join restores the previously selected card")
	inicio._on_char_next()
	inicio._on_char_prev()
	_ok(str(inicio.CHAR_CONFIGS[inicio._char_index].get("id", "")) == "saved",
		"menu nav reaches the local save card again")
	inicio._prejoin_card_id = ""
	inicio._mode = "join"
	inicio._on_char_prev()
	_ok(not inicio._is_mp_save_card(inicio.CHAR_CONFIGS[inicio._char_index]),
		"join prev arrow also skips save cards")
	inicio._mode = ""

	# --- 8) saved_server nunca existe en reposo ---
	# Limpia las tarjetas insertadas por los tests anteriores.
	for i in range(inicio.CHAR_CONFIGS.size() - 1, -1, -1):
		var cid := str(inicio.CHAR_CONFIGS[i].get("id", ""))
		if cid == "saved" or cid == "saved_server":
			inicio.CHAR_CONFIGS.remove_at(i)
	var fsgm := FakeSGM.new()
	fsgm.name = "SaveGameManager"
	root.add_child(fsgm)
	SaveInt.maybe_insert_saved_character(inicio)
	var srv_count := 0
	var saved_count := 0
	for c in inicio.CHAR_CONFIGS:
		var cid := str(c.get("id", ""))
		if cid == "saved_server":
			srv_count += 1
		elif cid == "saved":
			saved_count += 1
	_ok(srv_count == 0, "resting picker never gets a saved_server card")
	_ok(saved_count == 1, "local save card still offered for single player")

	# El reclaim la inserta (locked); salir del join la retira de nuevo.
	inicio._mode = "join"
	var lock_idx: int = inicio._upsert_server_card(payload)
	_ok(str(inicio.CHAR_CONFIGS[lock_idx].get("id", "")) == "saved_server",
		"reclaim inserts the server card")
	inicio._char_index = 2
	inicio._prejoin_card_id = "marc"
	inicio._exit_join_pick()
	var still_there := false
	for c in inicio.CHAR_CONFIGS:
		if str(c.get("id", "")) == "saved_server":
			still_there = true
	_ok(not still_there, "exit join removes the transient server card")
	_ok(str(inicio.CHAR_CONFIGS[inicio._char_index].get("id", "")) == "marc",
		"exit join restores the prejoin card")
	fsgm.queue_free()

	inicio.queue_free()
	print("PreviewLockRegression: %s" % ("ALL PASS" if _failures == 0 else "%d FAILURES" % _failures))
	quit(1 if _failures > 0 else 0)
