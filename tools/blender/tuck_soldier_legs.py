import bpy
from pathlib import Path

# Pulls the soldier_legs belt/pouch geometry inward where the shirt hem covers
# it. The mesh's load-bearing kit protrudes to ~0.50 m while the Tops hem only
# reaches ~0.42 m, so kit tabs and buckles stabbed through the shirt in-game.
# Verts below z=1.75 keep their shape; from there up they ease toward the body
# axis (x,y -> 55%) so everything above the hem line (z ~1.9) sits well inside
# the grown shirt surface.

ROOT = Path(__file__).resolve().parents[2]
GLB = ROOT / "assets/characters/adapted/player_with_clothes.glb"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(GLB))

obj = bpy.data.objects.get("soldier_legs")
if obj is None:
    raise SystemExit("soldier_legs not found")

mat_w = obj.matrix_world
inv = mat_w.inverted()
moved = 0
for v in obj.data.vertices:
    w = mat_w @ v.co
    if w.z > 1.75:
        t = min(1.0, (w.z - 1.75) / 0.30)
        f = 1.0 + (0.55 - 1.0) * t
        w.x *= f
        w.y *= f
        v.co = inv @ w
        moved += 1
print("TUCKED", moved, "verts")

bpy.ops.export_scene.gltf(
    filepath=str(GLB),
    export_format="GLB",
    export_yup=True,
    export_apply=False,
    export_animations=True,
    export_skins=True,
    export_morph=True,
)
print("EXPORTED", GLB)
