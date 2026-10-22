extends SceneTree
const ItemScript = preload("res://scripts/Item.gd")
class Actor extends "res://scripts/PlayerController.gd":
	func _ready(): pass
	func _process(_d): pass
	func _physics_process(_d): pass
class World extends Node3D:
	var hud = null
var errors:=0
func check(ok: bool, message: String):
	if not ok: errors+=1;push_error(message)
func run():
	var world:=World.new();root.add_child(world);current_scene=world
	var actor:=Actor.new();world.add_child(actor)
	actor.stats=preload("res://scripts/SurvivalStats.gd").new()
	actor.inventory=preload("res://scripts/Inventory.gd").new();actor.add_child(actor.inventory)
	actor.hands=preload("res://scripts/PlayerHands.gd").new();actor.add_child(actor.hands)
	actor.setup_as_puppet()
	actor.inventory.changed.connect(actor._on_inventory_changed)
	actor.equip_clothing("Camiseta");actor.equip_clothing("Pantalones")
	var rifle=ItemScript.create(actor.RIFLE_NAME,"weapon_rifle",3.5,1,0)
	rifle.wetness=37;rifle.durability=62
	var m4=ItemScript.create(actor.M4_NAME,"weapon_rifle",3.1,1,0)
	check(actor.receive_pickup_item(rifle),"First rifle accepted")
	check(actor.get_back_item_data(0).get("name")==actor.RIFLE_NAME,"First pickup occupies first shoulder")
	check(actor.receive_pickup_item(m4),"Second rifle accepted")
	check(actor.get_back_item_data(1).get("name")==actor.M4_NAME,"Second pickup occupies remaining shoulder")
	check(actor.receive_pickup_item(rifle),"Third rifle accepted in inventory")
	check(actor.inventory.items.size()==1,"Both shoulders full: third rifle stays in inventory")
	check(actor.get_back_item_data(0).get("wetness")==37,"Shoulder transfer preserves item payload")
	actor._select_held_item(0)
	check(actor.get_held_item()!=null and actor.inventory.items.is_empty(),"Inventory rifle transfers to hands exactly once")
	actor._store_held_item()
	check(actor.get_held_item()==null and actor.inventory.items.size()==1,"Full shoulders: held rifle returns to inventory")
	for slot in 2:
		check(is_instance_valid(actor._stored_back_visuals[slot]) and actor._stored_back_visuals[slot].is_visible_in_tree(),"Shoulder visual survives storing a held item")
	actor._stored_back_visuals[0].free()
	actor._sync_held_item()
	check(is_instance_valid(actor._stored_back_visuals[0]),"Missing shoulder visual is rebuilt from equipment data")
	for i in 5:
		check(actor.use_back_item(0),"Use shoulder rifle")
		check(actor.store_held_on_back(),"Return rifle to shoulder")
		check(actor._back_slot_count()==2 and actor.inventory.items.size()==1 and actor.get_held_item()==null,"Repeated transfers conserve all three rifles")
	actor.inventory.max_slots=0
	check(not actor.receive_pickup_item(m4),"Full inventory and shoulders rejects pickup without consuming world item")
	actor.stats.free();world.free();print("RIFLE_STORAGE_ERRORS=",errors);quit(1 if errors else 0)
func _initialize(): call_deferred("run")
