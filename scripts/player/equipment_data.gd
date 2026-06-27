extends RefCounted
class_name ClothingEquipmentData

## Static definitions for the survival-character equipment, adapted to the Mixamo
## rig by the Blender pipeline (clothing_pipeline/). Two kinds of equipment:
##
##  * CLOTHING (deformable): cloth_torso / cloth_legs / cloth_hands / cloth_feet.
##    These meshes are skinned to the SAME Mixamo Skeleton3D inside
##    player_with_clothes.glb, so they deform with every animation automatically.
##    Equipping/unequipping is just toggling MeshInstance3D.visible -- NEVER use
##    BoneAttachment3D for clothing.
##
##  * RIGID GEAR (e.g. backpack): exported as its own glb and attached to a single
##    bone with a BoneAttachment3D. These do NOT deform.

## res:// path of the adapted character (Mixamo rig + adapted clothing).
const PLAYER_MODEL_PATH := "res://assets/characters/adapted/player_with_clothes.glb"

## Folder that holds the rigid gear glb files + the manifest.
const ADAPTED_DIR := "res://assets/characters/adapted"
const GEAR_MANIFEST_PATH := "res://assets/characters/adapted/gear_manifest.json"

## Clothing slots -> mesh node name inside the player glb + Mixamo body meshes to
## hide while the garment is worn (prevents the default Mixamo clothes clipping
## through the survival garment).
const CLOTHING := {
	"torso": {
		"mesh": "cloth_torso",
		"label": "Chaqueta",
		"hides_body": ["Tops"],
	},
	"legs": {
		"mesh": "cloth_legs",
		"label": "Vaqueros",
		"hides_body": ["Bottoms"],
	},
	"hands": {
		"mesh": "cloth_hands",
		"label": "Guantes",
		"hides_body": [],
	},
	"feet": {
		"mesh": "cloth_feet",
		"label": "Botas",
		"hides_body": ["Shoes"],
	},
}

## Rigid gear slots. attach_bone / transform may be overridden by the manifest
## (gear_manifest.json) produced by the export script.
const GEAR := {
	"backpack": {
		"scene": "res://assets/characters/adapted/gear_backpack.glb",
		"label": "Mochila",
		"attach_bone": "mixamorig:Spine2",
		# local offset applied to the BoneAttachment3D child (tweak in editor)
		"position": Vector3(0.0, 0.06, -0.14),
		"rotation_degrees": Vector3(0.0, 0.0, 0.0),
		"scale": Vector3.ONE,
	},
}

## Names of the default Mixamo body meshes (kept visible unless hidden by a
## garment's hides_body list). Useful for resets.
const BODY_MESHES := ["Body", "Bottoms", "Tops", "Shoes", "Hair", "Eyes", "Eyelashes"]


static func clothing_slots() -> Array:
	return CLOTHING.keys()


static func gear_slots() -> Array:
	return GEAR.keys()


static func cloth_mesh_name(slot: String) -> String:
	return String(CLOTHING.get(slot, {}).get("mesh", ""))


## Load attach-bone overrides from gear_manifest.json if it exists, returning a
## dictionary slot -> {file, attach_bone}. Falls back to the GEAR constants.
static func load_gear_manifest() -> Dictionary:
	var result := {}
	if FileAccess.file_exists(ProjectSettings.globalize_path(GEAR_MANIFEST_PATH)) \
			or ResourceLoader.exists(GEAR_MANIFEST_PATH) \
			or FileAccess.file_exists(GEAR_MANIFEST_PATH):
		var f := FileAccess.open(GEAR_MANIFEST_PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				result = parsed
	return result
