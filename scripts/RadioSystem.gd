extends Node
class_name RadioSystem

signal message_received(message: String)

var messages := [
	"No vengais al norte.",
	"Necesito ayuda. Estoy en la estacion.",
	"Si alguien escucha esto, quedan suministros en la gasolinera.",
	"Hay gente armada cerca de la carretera.",
	"El punto de radio aun tiene baterias.",
	"No encendais luces despues de medianoche."
]
var last_message := ""

func emit_night_message() -> String:
	last_message = messages.pick_random()
	message_received.emit(last_message)
	return last_message

func listen() -> String:
	if last_message.is_empty():
		return emit_night_message()
	message_received.emit(last_message)
	return last_message

func to_dict() -> Dictionary:
	return {"last_message": last_message}

func from_dict(data: Dictionary) -> void:
	last_message = str(data.get("last_message", ""))
