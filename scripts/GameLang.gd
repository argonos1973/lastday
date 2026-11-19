extends RefCounted
## Idioma de la interfaz, persistido en user://ui.cfg (seccion "ui",
## clave "lang": "es"|"en"). Las cadenas se piden en el momento de
## pintar con GameLang.t("Español", "English"), asi un cambio de idioma
## solo necesita reasignar los textos de los controles visibles.
const CONFIG_PATH := "user://ui.cfg"
const LANGS: Array[String] = ["es", "en"]
static var config_path := CONFIG_PATH # Overridable por tests de regresion.
static var _cached := ""

static func lang() -> String:
	if _cached.is_empty():
		var c := ConfigFile.new()
		var v := ""
		if c.load(config_path) == OK:
			v = str(c.get_value("ui", "lang", ""))
		_cached = v if v in LANGS else ("en" if OS.get_locale_language() == "en" else "es")
	return _cached

static func save_lang(code: String) -> Error:
	if not (code in LANGS):
		return ERR_INVALID_PARAMETER
	var c := ConfigFile.new()
	c.load(config_path)
	c.set_value("ui", "lang", code)
	var err := c.save(config_path)
	if err == OK:
		_cached = code
	return err

static func invalidate_cache() -> void:
	_cached = ""

static func is_en() -> bool:
	return lang() == "en"

static func t(es: String, en: String) -> String:
	return en if is_en() else es

# Etiquetas de las opciones del engranaje: pares [es, en] en el mismo
# orden que los indices que espera el panel de Inicio.
const _OPTS := {
	"screen": [["Pantalla: ventana", "Screen: window"], ["Pantalla: completa", "Screen: fullscreen"]],
	"shadow": [["Sombras: bajas", "Shadows: low"], ["Sombras: equilibradas", "Shadows: balanced"], ["Sombras: altas", "Shadows: high"]],
	"detail": [["Detalles: bajos", "Detail: low"], ["Detalles: normales", "Detail: normal"], ["Detalles: altos", "Detail: high"]],
	"profile": [["Perfil: rendimiento", "Profile: performance"], ["Perfil: equilibrado", "Profile: balanced"], ["Perfil: calidad", "Profile: quality"], ["Perfil: personalizado", "Profile: custom"]],
	"lang": [["Idioma: Español", "Language: Español"], ["Idioma: English", "Language: English"]],
}

static func opt_list(key: String) -> Array:
	var out: Array = []
	for pair in _OPTS.get(key, []):
		out.append(t(pair[0], pair[1]))
	return out

static func opt_label(key: String, index: int) -> String:
	var pairs: Array = _OPTS.get(key, [])
	if index < 0 or index >= pairs.size():
		return ""
	return t(pairs[index][0], pairs[index][1])
