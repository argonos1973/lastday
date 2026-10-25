extends SceneTree
# Regresión del alijo de refugio/mochila: apilado (merge por can_stack_with)
# y transferencia unitaria sobre los dicts serializados (to_dict/from_dict).

const MainScript = preload("res://scripts/Main.gd")
const ItemScript = preload("res://scripts/Item.gd")

var failures := 0

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", label)

func _unit_dict(item_name: String, qty: int = 1, wetness: float = 0.0) -> Dictionary:
	var it = ItemScript.create(item_name, "food", 0.1, qty, 10.0)
	it.wetness = wetness
	return it.to_dict()

func _init() -> void:
	var m = MainScript.new()
	# Apilar: dos unidades iguales funden en una entrada de cantidad 2.
	var contents: Array = []
	_check(not m._stash_merge_or_append(contents, _unit_dict("Seta roja")), "primer item se añade como entrada nueva")
	_check(contents.size() == 1, "una entrada tras el primer item")
	_check(m._stash_merge_or_append(contents, _unit_dict("Seta roja")), "segunda unidad funde en la pila")
	_check(contents.size() == 1 and int(contents[0].get("quantity", 0)) == 2, "la pila acumula quantity=2")
	_check(m._stash_can_merge(contents, _unit_dict("Seta roja")), "_stash_can_merge detecta la pila compatible")
	# Un item distinto crea entrada nueva.
	_check(not m._stash_merge_or_append(contents, _unit_dict("Higo")), "item distinto no funde")
	_check(contents.size() == 2, "el item distinto ocupa su propia entrada")
	# Estado divergente bloquea la fusión (mojada vs seca).
	_check(not m._stash_merge_or_append(contents, _unit_dict("Seta roja", 1, 0.9)), "seta mojada no funde con seca")
	_check(contents.size() == 3, "la seta mojada es entrada aparte")
	# La durabilidad funde por media ponderada.
	var worn: Array = []
	var a = ItemScript.create("S", "food", 0.1, 3, 0.0)
	a.durability = 90.0
	var b = ItemScript.create("S", "food", 0.1, 1, 0.0)
	b.durability = 50.0
	m._stash_merge_or_append(worn, a.to_dict())
	m._stash_merge_or_append(worn, b.to_dict())
	_check(worn.size() == 1 and int(worn[0].get("quantity", 0)) == 4, "durabilidad: pila fusionada qty=4")
	_check(absf(float(worn[0].get("durability", 0.0)) - 80.0) < 0.01, "durabilidad media ponderada = 80")
	m.free()
	if failures == 0:
		print("PASS: stash stacks merge, wet/divergent states stay apart, durability averages")
	else:
		print("StashStackRegression failures=%d" % failures)
	quit(failures)
