# Clothing pipeline: ropa survival (UE5) -> rig Mixamo -> Godot 4

Adapta la ropa del personaje `survival_characte.glb` (riggeado al esqueleto
UE5/Manny en A-pose) al esqueleto **Mixamo** de `inicio.glb` (T-pose), de forma
que cada prenda **deforma con las animaciones Mixamo** del juego. Los objetos
**rígidos** (mochila) se exportan aparte para colgarlos de un `BoneAttachment3D`.

## Componentes

| Archivo | Qué hace |
|---|---|
| `bone_map_ue5_to_mixamo.py` | Mapa de huesos UE5 -> Mixamo + clasificación de mallas (ropa / rígido / cuerpo / helper) |
| `blender_adapt_survival_clothes_to_mixamo.py` | Importa ambos, escala, **retarget A-pose -> T-pose**, remapea vertex groups, transfiere pesos, shrinkwrap, ata al armature Mixamo y genera informe |
| `blender_export_godot_glb.py` | Exporta `player_with_clothes.glb` (personaje + ropa, un solo esqueleto) + un `gear_<slot>.glb` por rígido + `gear_manifest.json` |

## Decisiones clave (por qué funciona)

- **El rig UE5 importado da a todos los huesos un *tail* +Y sin sentido** (heurística
  del importador glTF). Por eso el retarget **NO usa direcciones de hueso**, sino
  los vectores *cabeza-joint -> cabeza-del-hijo* (las posiciones de joint sí son
  correctas). Ver `retarget_pose()`.
- Al reatar la ropa al esqueleto Mixamo se **hornea la transformación mundial en
  los vértices** antes de reemparentar, evitando que la prenda salte al origen.
- La ropa se exporta **skinneada al mismo `Skeleton3D`** => deforma sola. Los
  rígidos van **separados** => `BoneAttachment3D` en Godot.

## Uso (Blender headless)

```bash
BLENDER=/Applications/Blender.app/Contents/MacOS/Blender

# 1) Adaptar (genera outputs/adapted_player.blend + outputs/adapt_report.txt)
$BLENDER --background --python clothing_pipeline/blender_adapt_survival_clothes_to_mixamo.py -- \
  --mixamo inicio.glb --survival survival_characte.glb \
  --out outputs/adapted_player.blend --report outputs/adapt_report.txt

# 2) Exportar para Godot (assets/characters/adapted/*.glb + gear_manifest.json)
$BLENDER --background outputs/adapted_player.blend \
  --python clothing_pipeline/blender_export_godot_glb.py -- \
  --out-dir assets/characters/adapted
```

Flags útiles del adapt: `--no-retarget`, `--no-shrinkwrap`, `--no-datatransfer`.

## Uso (Godot 4)

- `scenes/player/Player.tscn` con `scripts/player/player_equipment.gd`
  (`class_name ClothingEquipment`) carga el glb en runtime y construye:

```
Player (Node3D, ClothingEquipment)
 └ CharacterModel  (player_with_clothes.glb)
    └ ... > Skeleton3D
       ├ Body / Hair / Eyes / Tops / Bottoms / Shoes   (cuerpo + ropa Mixamo)
       ├ cloth_torso / cloth_legs / cloth_hands / cloth_feet  (ropa adaptada, deformable)
       └ Attach_backpack (BoneAttachment3D -> mixamorig:Spine2)
          └ gear_backpack (rígido)
```

API:

```gdscript
eq.equip_cloth("torso")      # muestra la prenda (toggle de visibilidad)
eq.unequip_cloth("legs")
eq.equip_gear("backpack")    # crea BoneAttachment3D + instancia el glb rígido
eq.unequip_gear("backpack")
```

Datos en `scripts/player/equipment_data.gd` (`class_name ClothingEquipmentData`):
slots, nombres de malla y qué ropa Mixamo ocultar al equipar cada prenda.

## Verificación

```bash
work/godot4.7/Godot.app/Contents/MacOS/Godot --headless --path . \
  -s res://scripts/player/_verify_equipment.gd
```

Comprueba esqueleto (67 huesos), que las 4 prendas están **skinned** y visibles, y
que el rígido cuelga de un `BoneAttachment3D`. Debe imprimir `RESULT: PASS`.
```
```

## Informe de ajuste (último run)

Todas las prendas `[OK]` (centro vertical dentro de la banda esperada del cuerpo):
`cloth_torso` z=2.53, `cloth_legs` z=1.55, `cloth_feet` z=0.40, `cloth_hands` z=2.88.
