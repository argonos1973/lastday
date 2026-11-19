extends SceneTree
## Regresion de GameLang: idioma persistido en user://ui.cfg, t() y las
## listas de etiquetas del engranaje siguen el idioma activo. El config se
## redirige a una ruta temporal para no tocar las preferencias reales.
const GameLang = preload("res://scripts/GameLang.gd")

var _fail := 0

func _check(cond: bool, msg: String) -> void:
	if cond:
		print("PASS ", msg)
	else:
		_fail += 1
		printerr("FAIL ", msg)

func _init() -> void:
	GameLang.config_path = "user://test_gamelang.cfg"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameLang.config_path))
	GameLang.invalidate_cache()

	# Sin fichero guardado: cae al idioma del SO (en solo si el locale es en).
	var expected_default := "en" if OS.get_locale_language() == "en" else "es"
	_check(GameLang.lang() == expected_default, "default por locale=%s" % expected_default)

	_check(GameLang.save_lang("en") == OK, "save en")
	_check(GameLang.lang() == "en", "lang() en")
	_check(GameLang.is_en(), "is_en")
	_check(GameLang.t("Puerta", "Door") == "Door", "t() en")
	_check(GameLang.opt_label("screen", 1) == "Screen: fullscreen", "opt_label en")
	_check(GameLang.opt_list("profile")[0] == "Profile: performance", "opt_list en")
	_check(GameLang.opt_list("lang").size() == 2, "opt_list lang 2 items")

	# Persistencia: una "sesion" nueva lee el valor del disco.
	GameLang.invalidate_cache()
	_check(GameLang.lang() == "en", "persistencia tras invalidate")

	_check(GameLang.save_lang("es") == OK, "save es")
	_check(GameLang.lang() == "es", "lang() es")
	_check(not GameLang.is_en(), "not is_en")
	_check(GameLang.t("Puerta", "Door") == "Puerta", "t() es")
	_check(GameLang.opt_label("shadow", 0) == "Sombras: bajas", "opt_label es")

	_check(GameLang.save_lang("fr") == ERR_INVALID_PARAMETER, "codigo invalido rechazado")
	_check(GameLang.lang() == "es", "idioma intacto tras rechazo")

	# Valor corrupto en disco -> fallback del SO.
	var c := ConfigFile.new()
	c.load(GameLang.config_path)
	c.set_value("ui", "lang", "klingon")
	c.save(GameLang.config_path)
	GameLang.invalidate_cache()
	_check(GameLang.lang() == expected_default, "valor corrupto -> locale")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameLang.config_path))
	GameLang.invalidate_cache()

	if _fail > 0:
		printerr("GameLangRegression: %d fallos" % _fail)
		quit(1)
	else:
		print("GameLangRegression: 0 fallos")
		quit(0)
