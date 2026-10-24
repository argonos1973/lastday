extends SceneTree

## Renders every weapon / craftable item icon through ItemThumbnail3D (the same
## component the inventory uses) into build/web/icons/*.png for the downloads
## page. Run WITH a GPU (no --headless): the SubViewport must actually render.

class World extends "res://scripts/Main.gd":
	func _ready() -> void:
		set_process(false)
		set_physics_process(false)

# [icon_file, item_name, item_type, pelt]
const ITEMS := [
	["rifle", "Rifle francotirador", "weapon_rifle", ""],
	["m4", "Fusil de asalto", "weapon_rifle", ""],
	["arco_madera", "Arco de madera", "weapon_bow", ""],
	["arco_reforzado", "Arco reforzado", "weapon_bow", ""],
	["flecha_madera", "Flecha de madera", "weapon_arrow", ""],
	["flecha_piedra", "Flecha de piedra", "weapon_arrow", ""],
	["flecha_hueso", "Flecha de hueso", "weapon_arrow", ""],
	["flecha_improvisada", "Flecha improvisada", "weapon_arrow", ""],
	["cuchillo", "Cuchillo", "weapon", ""],
	["cuchillo_piedra", "Cuchillo de piedra", "weapon", ""],
	["cuchillo_hueso", "Cuchillo de hueso", "weapon", ""],
	["lanza", "Lanza", "weapon", ""],
	["lanza_hueso", "Lanza de hueso", "weapon", ""],
	["palo_afilado", "Palo afilado", "weapon", ""],
	["boleadoras", "Boleadoras", "weapon", ""],
	["antorcha", "Antorcha", "tool_torch", ""],
	["cana_pescar", "Caña de pescar", "tool_fishing", ""],
	["hacha", "Hacha", "tool_axe", ""],
	["hacha_piedra", "Hacha de piedra", "tool_axe", ""],
	["pico", "Pico", "tool_pickaxe", ""],
	["pala", "Pala", "tool_shovel", ""],
	["martillo", "Martillo", "tool_hammer", ""],
	["azada", "Azada", "tool_hoe", ""],
	["palo", "Palo", "resource", ""],
	["tronco", "Tronco", "resource", ""],
	["piedra", "Piedra", "resource", ""],
	["piedra_afilada", "Piedra afilada", "resource", ""],
	["cuerda", "Cuerda", "resource", ""],
	["tendon", "Tendón", "resource", ""],
	["hueso", "Hueso", "resource", ""],
	["pluma", "Pluma", "resource", ""],
	["trapos", "Trapos", "resource", ""],
	["piel", "Piel de lobo", "resource", "wolf"],
	["carne_ensartada", "Carne ensartada", "food", ""],
	["carne_cruda", "Carne cruda de ciervo", "food", ""],
	["carne_seca", "Carne seca", "food", ""],
	["pez", "Pez crudo", "food", ""],
	["pez_ensartado", "Pez ensartado", "food", ""],
	["lata_guiso", "Lata de guiso", "food", ""],
	["lata_atun", "Lata de atun", "food", ""],
	["fogata", "Fogata", "campfire", ""],
	["refugio", "Refugio", "shelter", ""],
	["chaqueta_piel", "Chaqueta de piel", "clothing", ""],
	["pantalones_piel", "Pantalones de piel", "clothing", ""],
	["botas_piel", "Botas de piel", "clothing", ""],
	["guantes_piel", "Guantes de piel", "clothing", ""],
	["gorro_piel", "Gorro de piel", "clothing", ""],
	["tocado_piel", "Tocado de piel animal", "clothing", "wolf"],
	["semillas", "Semillas", "seed", ""],
	["cerillas", "Caja de cerillas", "tool_matches", ""],
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var out_dir := "build/web/icons"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var world := World.new()
	var th := ItemThumbnail3D.new()
	th.custom_minimum_size = Vector2(256, 256)
	th.size = Vector2(256, 256)
	root.add_child(th)
	th._viewport.size = Vector2i(256, 256)
	for i in 4:
		await process_frame

	var failures := 0
	for e in ITEMS:
		var file: String = e[0]
		var iname: String = e[1]
		var itype: String = e[2]
		var pelt: String = e[3]
		var paths: Array = world._get_drop_model_paths(iname, itype, pelt)
		var scale_v: float = world._get_drop_scale(iname, itype)
		var proc_kind := "rag" if iname == "Trapos" else iname
		th.set_model(paths, scale_v, Vector3.ZERO, 1.0, "", Color(0, 0, 0, 0), Color(0, 0, 0, 0), pelt, proc_kind)
		for i in 5:
			await process_frame
		var img := th._viewport.get_texture().get_image()
		if img == null or img.is_empty():
			push_error("no image for " + iname)
			failures += 1
			continue
		var used := img.get_used_rect()
		if used.size.x <= 0 or used.size.y <= 0:
			push_error("blank icon: " + iname)
			failures += 1
		var err := img.save_png(out_dir + "/" + file + ".png")
		if err != OK:
			push_error("save failed " + file + " err=" + str(err))
			failures += 1
		print("ICON ", file, " used=", used.size)

	world.free()
	print("ICONS_DONE failures=", failures)
	quit(1 if failures > 0 else 0)
