"""
blender_fix_clothing_all.py
===========================

Comprehensive fix for multiple clothing issues:
  1. Jacket collar: flatten spiky vertices + heavy smooth
  2. Shoes pickup: compute sole-down rotation from foot bone direction
  3. Render gloves for inspection

Run:
  /Applications/Blender.app/Contents/MacOS/Blender --background \
    --python clothing_pipeline/blender_fix_clothing_all.py -- \
    --glb assets/characters/adapted/player_with_clothes.glb \
    --out-dir assets/characters/adapted \
    --render-dir /tmp/clothing_fix_renders
"""

import bpy
import sys
import os
import math
import mathutils


def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    glb = "assets/characters/adapted/player_with_clothes.glb"
    out_dir = "assets/characters/adapted"
    render_dir = "/tmp/clothing_fix_renders"
    i = 0
    while i < len(argv):
        if argv[i] == "--glb":
            glb = argv[i + 1]; i += 2
        elif argv[i] == "--out-dir":
            out_dir = argv[i + 1]; i += 2
        elif argv[i] == "--render-dir":
            render_dir = argv[i + 1]; i += 2
        else:
            i += 1
    return os.path.abspath(glb), os.path.abspath(out_dir), os.path.abspath(render_dir)


def setup_render(scene, out_dir):
    try:
        scene.render.engine = 'BLENDER_EEVEE_NEXT'
    except Exception:
        scene.render.engine = 'BLENDER_EEVEE'
    scene.render.resolution_x = 600
    scene.render.resolution_y = 600
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.55, 0.6, 1)
    scene.world = w
    ld = bpy.data.lights.new("Sun", 'SUN')
    ld.energy = 3
    lo = bpy.data.objects.new("Sun", ld)
    bpy.context.collection.objects.link(lo)
    lo.rotation_euler = (math.radians(50), 0, math.radians(30))
    os.makedirs(out_dir, exist_ok=True)
    cd = bpy.data.cameras.new("C")
    cam = bpy.data.objects.new("C", cd)
    bpy.context.collection.objects.link(cam)
    scene.camera = cam
    return cam


def bounds(obj):
    mn = mathutils.Vector((1e9, 1e9, 1e9))
    mx = mathutils.Vector((-1e9, -1e9, -1e9))
    for v in obj.bound_box:
        w = obj.matrix_world @ mathutils.Vector(v)
        for i in range(3):
            mn[i] = min(mn[i], w[i])
            mx[i] = max(mx[i], w[i])
    return mn, mx, (mn + mx) / 2


def render(scene, cam, name, eye, look):
    cam.location = eye
    d = (mathutils.Vector(look) - mathutils.Vector(eye))
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = os.path.join(os.path.dirname(scene.render.filepath), name)
    bpy.ops.render.render(write_still=True)
    print(f"RENDERED {scene.render.filepath}")


# ===========================================================================
# 1. FIX JACKET COLLAR (more aggressive)
# ===========================================================================
def fix_jacket_collar(glb_path, render_dir):
    print("\n=== [1] FIX JACKET COLLAR ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)

    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    jacket = bpy.data.objects.get("cloth_torso")
    if jacket is None:
        print("  [FATAL] cloth_torso not found")
        return

    zs = [v.co.z for v in jacket.data.vertices]
    z_min, z_max = min(zs), max(zs)
    z_span = z_max - z_min
    # Collar band = top 25%
    band_lo = z_max - 0.25 * z_span
    # Target collar height = 85% of the way up (flatten spikes above this)
    target_z = z_max - 0.15 * z_span
    print(f"  jacket z [{z_min:.3f}, {z_max:.3f}] band_lo={band_lo:.3f} target_z={target_z:.3f}")

    # Step 1: Clamp spiky vertices - any collar vertex above target_z gets pulled down
    clamped = 0
    for v in jacket.data.vertices:
        if v.co.z >= band_lo and v.co.z > target_z:
            v.co.z = target_z + (v.co.z - target_z) * 0.3  # pull 70% of the way down
            clamped += 1
    print(f"  clamped {clamped} spiky vertices")

    # Step 2: Build vertex group for smoothing
    vg = jacket.vertex_groups.get("collar_fix")
    if vg is None:
        vg = jacket.vertex_groups.new(name="collar_fix")
    count = 0
    for v in jacket.data.vertices:
        if v.co.z >= band_lo:
            t = (v.co.z - band_lo) / max(1e-6, (z_max - band_lo))
            vg.add([v.index], min(1.0, t), 'REPLACE')
            count += 1
    print(f"  collar_fix group: {count} verts")

    # Step 3: Heavy smooth on collar
    bpy.ops.object.select_all(action='DESELECT')
    jacket.select_set(True)
    bpy.context.view_layer.objects.active = jacket

    smooth = jacket.modifiers.new("CollarSmooth", 'SMOOTH')
    smooth.vertex_group = "collar_fix"
    smooth.factor = 1.0
    smooth.iterations = 40
    while jacket.modifiers[0].name != smooth.name:
        bpy.ops.object.modifier_move_up(modifier=smooth.name)
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    print("  applied heavy CollarSmooth")

    # Ensure armature modifier still present
    if not any(m.type == 'ARMATURE' for m in jacket.modifiers):
        am = jacket.modifiers.new("Armature", 'ARMATURE')
        am.object = arm

    # Render to verify
    scene = bpy.context.scene
    cam = setup_render(scene, render_dir)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o.name not in {"Body", "cloth_torso"}
    for o in bpy.data.objects:
        if o.name == "cloth_torso":
            m = bpy.data.materials.new("JK")
            m.diffuse_color = (0.2, 0.5, 0.15, 1)
            o.data.materials.clear()
            o.data.materials.append(m)
    mn, mx, c = bounds(jacket)
    neck = mathutils.Vector((c.x, c.y, mx.z - 0.1))
    render(scene, cam, "jacket_collar_back.png",
           (neck.x, neck.y + 0.7, neck.z + 0.15), neck)
    render(scene, cam, "jacket_collar_angle.png",
           (neck.x + 0.4, neck.y + 0.6, neck.z + 0.25), neck)
    render(scene, cam, "jacket_front.png",
           (c.x, c.y - 1.2, c.z + 0.1), c)

    # Re-export full character GLB
    meshes = [o for o in bpy.data.objects if o.type == 'MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for o in ([arm] + meshes):
        o.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format='GLB',
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_image_format='AUTO',
        export_materials='EXPORT',
        export_skins=True,
        export_animations=False,
        export_extras=True,
    )
    print(f"  re-exported -> {glb_path}")


# ===========================================================================
# 2. FIX SHOES PICKUP ORIENTATION
# ===========================================================================
def fix_shoes_pickup(glb_path, out_dir, render_dir):
    print("\n=== [2] FIX SHOES PICKUP ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)

    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    shoes = bpy.data.objects.get("Shoes")
    if shoes is None:
        print("  [FATAL] Shoes mesh not found")
        return

    # Compute foot bone direction to determine the rotation needed
    # to make the sole face down.
    left_foot = arm.data.bones.get("mixamorig:LeftFoot")
    if left_foot is None:
        left_foot = arm.data.bones.get("LeftFoot")
    if left_foot is not None:
        head_w = arm.matrix_world @ left_foot.head_local
        tail_w = arm.matrix_world @ left_foot.tail_local
        direction = tail_w - head_w
        angle_from_horizontal = math.atan2(-direction.z, -direction.y)
        print(f"  foot direction: {direction}")
        print(f"  angle from horizontal: {math.degrees(angle_from_horizontal):.1f} deg")
        rot_x = angle_from_horizontal
    else:
        print("  [WARN] no foot bone, using 41.4 deg fallback")
        rot_x = math.radians(41.4)

    # Copy the mesh (do NOT apply armature — keep original cm-scale vertices)
    bpy.ops.object.select_all(action='DESELECT')
    copy = shoes.copy()
    copy.data = shoes.data.copy()
    bpy.context.collection.objects.link(copy)
    copy.select_set(True)
    bpy.context.view_layer.objects.active = copy

    # Remove all modifiers from the copy (we don't want armature in the pickup)
    for mod in list(copy.modifiers):
        copy.modifiers.remove(mod)

    # Apply the object's transform (bakes location/rotation/scale into vertices)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Rotate to make the sole face down (compensate plantarflexed rest pose)
    copy.rotation_euler = (rot_x, 0, 0)
    bpy.context.view_layer.update()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Scale down from centimetres to metres
    copy.scale = (0.01, 0.01, 0.01)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    # Center on origin
    bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY', center='BOUNDS')
    copy.location = (0, 0, 0)
    bpy.context.view_layer.update()

    # Export
    path = os.path.join(out_dir, "pickup_default_shoes.glb")
    bpy.ops.object.select_all(action='DESELECT')
    copy.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format='GLB',
        use_selection=True,
        export_apply=False,
        export_yup=True,
        export_image_format='AUTO',
        export_materials='EXPORT',
        export_skins=False,
        export_animations=False,
    )
    print(f"  shoes pickup -> {path}")

    # Render to verify
    scene = bpy.context.scene
    cam = setup_render(scene, render_dir)
    mn, mx, c = bounds(copy)
    print(f"  shoes bounds: mn={mn} mx={mx} dims={mx - mn}")
    span = max((mx - mn).x, (mx - mn).y, (mx - mn).z)
    render(scene, cam, "shoes_fixed_side.png",
           (c.x + span * 1.5, c.y, c.z), c)
    render(scene, cam, "shoes_fixed_persp.png",
           (c.x + span, c.y - span, c.z + span * 0.7), c)
    render(scene, cam, "shoes_fixed_front.png",
           (c.x, c.y - span * 1.5, c.z), c)


# ===========================================================================
# 3. RENDER GLOVES FOR INSPECTION
# ===========================================================================
def render_gloves(glb_path, render_dir):
    print("\n=== [3] RENDER GLOVES ===")
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=glb_path)

    arm = next((o for o in bpy.data.objects if o.type == 'ARMATURE'), None)
    for o in bpy.data.objects:
        if o.type == 'ARMATURE':
            o.data.pose_position = 'REST'
    bpy.context.view_layer.update()

    gloves = bpy.data.objects.get("cloth_hands")
    if gloves is None:
        print("  [WARN] cloth_hands not found")
        return

    scene = bpy.context.scene
    cam = setup_render(scene, render_dir)
    for o in bpy.data.objects:
        if o.type == 'MESH':
            o.hide_render = o.name not in {"Body", "cloth_hands"}
    for o in bpy.data.objects:
        if o.name == "cloth_hands":
            m = bpy.data.materials.new("GL")
            m.diffuse_color = (0.27, 0.17, 0.09, 1)
            o.data.materials.clear()
            o.data.materials.append(m)
    mn, mx, c = bounds(gloves)
    print(f"  gloves bounds: mn={mn} mx={mx} dims={mx - mn}")
    span = max((mx - mn).x, (mx - mn).y, (mx - mn).z)
    render(scene, cam, "gloves_front.png",
           (c.x, c.y - span * 1.5, c.z), c)
    render(scene, cam, "gloves_persp.png",
           (c.x + span, c.y - span, c.z + span * 0.7), c)
    render(scene, cam, "gloves_side.png",
           (c.x + span * 1.5, c.y, c.z), c)


# ===========================================================================
# MAIN
# ===========================================================================
def main():
    glb, out_dir, render_dir = parse_args()
    print(f"=== FIX CLOTHING ALL ===")
    print(f"  glb: {glb}")
    print(f"  out_dir: {out_dir}")
    print(f"  render_dir: {render_dir}")

    fix_jacket_collar(glb, render_dir)
    fix_shoes_pickup(glb, out_dir, render_dir)
    render_gloves(glb, render_dir)

    print("\n=== ALL DONE ===")


if __name__ == "__main__":
    main()
