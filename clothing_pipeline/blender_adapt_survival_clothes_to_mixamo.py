"""
blender_adapt_survival_clothes_to_mixamo.py
===========================================

Adapt the deformable clothing of survival_characte.glb (Unreal-Engine-5 rig,
A-pose) so it deforms with a Mixamo character rig (T-pose), WITHOUT using
BoneAttachment3D for the clothing. Rigid gear (the backpack) is kept as a
separate mesh for BoneAttachment3D in Godot.

Pipeline (per clothing mesh: Jacket, Jeans, Gloves, Shoes):
  1.  Import the Mixamo character (target) and survival_characte.glb (source).
  2.  Uniformly scale + translate the survival rig so it matches the Mixamo rig
      (hips height + torso length), so both live in the same world space.
  3.  RETARGET the survival rig pose A-pose -> Mixamo T-pose using a hierarchical
      per-bone direction match, then APPLY the Armature modifier on each clothing
      mesh so the clothing geometry is frozen in the Mixamo T-pose.
  4.  RENAME / MERGE the clothing vertex groups from UE5 names to Mixamo names
      (twist / corrective / metacarpal helper bones are folded into their parent
      so no skin weight is lost). Unmapped groups are removed.
  5.  Bind each clothing mesh to the Mixamo armature with a fresh Armature
      modifier and parent it under the Mixamo armature.
  6.  (optional) DATA TRANSFER vertex-group weights from the Mixamo body mesh by
      nearest face, to clean / normalise the skinning.
  7.  (optional) SHRINKWRAP each garment onto the Mixamo body (outside, small
      offset) to reduce clipping, then apply.
  8.  Write a human-readable report flagging anything that needs manual fixing.
  9.  Save a .blend so the export script can pick it up.

Run headless, e.g.:

  /Applications/Blender.app/Contents/MacOS/Blender --background \
     --python clothing_pipeline/blender_adapt_survival_clothes_to_mixamo.py -- \
     --mixamo inicio.glb \
     --survival survival_characte.glb \
     --out outputs/adapted_player.blend \
     --report outputs/adapt_report.txt

Flags:
  --no-retarget     skip the A->T pose retarget (debug)
  --no-datatransfer skip the data-transfer weight cleanup
  --no-shrinkwrap   skip the shrinkwrap conform pass
"""

import bpy
import sys
import os
import math

# --- locate the shared bone-map module next to this script -----------------
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)
import bone_map_ue5_to_mixamo as BM  # noqa: E402

from mathutils import Vector, Matrix  # noqa: E402


# ===========================================================================
# argument parsing (everything after the standalone "--")
# ===========================================================================
def parse_args():
    argv = sys.argv
    argv = argv[argv.index("--") + 1:] if "--" in argv else []
    opts = {
        "mixamo": "inicio.glb",
        "survival": "survival_characte.glb",
        "out": "outputs/adapted_player.blend",
        "report": "outputs/adapt_report.txt",
        "retarget": True,
        # Data-transfer is OFF by default: re-projecting weights from the Mixamo
        # body corrupts the garment skinning (spikes at the shoulders). The
        # authored UE5 weights remapped to Mixamo bones are higher quality.
        # Pass --datatransfer to opt back in for debugging.
        "datatransfer": False,
        # Shrinkwrap is OFF by default: NEAREST_SURFACEPOINT projection shreds
        # open garments (the jacket front) onto the wrong body surface, turning
        # them into spikes/shards. Pass --shrinkwrap to opt back in for debugging.
        "shrinkwrap": False,
    }
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--mixamo":
            opts["mixamo"] = argv[i + 1]; i += 2
        elif a == "--survival":
            opts["survival"] = argv[i + 1]; i += 2
        elif a == "--out":
            opts["out"] = argv[i + 1]; i += 2
        elif a == "--report":
            opts["report"] = argv[i + 1]; i += 2
        elif a == "--no-retarget":
            opts["retarget"] = False; i += 1
        elif a == "--no-datatransfer":
            opts["datatransfer"] = False; i += 1
        elif a == "--datatransfer":
            opts["datatransfer"] = True; i += 1
        elif a == "--no-shrinkwrap":
            opts["shrinkwrap"] = False; i += 1
        elif a == "--shrinkwrap":
            opts["shrinkwrap"] = True; i += 1
        else:
            i += 1
    return opts


REPORT = []


def log(msg):
    print(msg)
    REPORT.append(msg)


# ===========================================================================
# scene helpers
# ===========================================================================
def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_glb(path):
    """Import a glb and return (new_objects, armature, meshes)."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    arm = next((o for o in new if o.type == 'ARMATURE'), None)
    meshes = [o for o in new if o.type == 'MESH']
    return new, arm, meshes


def bone_world_head(arm, bone_name):
    b = arm.data.bones.get(bone_name)
    if not b:
        return None
    return arm.matrix_world @ b.head_local


def bone_world_dir(arm, bone_name):
    b = arm.data.bones.get(bone_name)
    if not b:
        return None
    head = arm.matrix_world @ b.head_local
    tail = arm.matrix_world @ b.tail_local
    v = (tail - head)
    return v.normalized() if v.length > 1e-9 else None


# ===========================================================================
# step 2 - scale + align survival rig to the mixamo rig
# ===========================================================================
def align_survival_to_mixamo(surv_arm, mx_arm):
    """Uniformly scale + translate the survival armature (and its children) so
    its hips/head match the Mixamo hips/head. Returns the applied scale."""
    s_hips = bone_world_head(surv_arm, "pelvis")
    s_head = bone_world_head(surv_arm, "head")
    m_hips = bone_world_head(mx_arm, "mixamorig:Hips")
    m_head = bone_world_head(mx_arm, "mixamorig:Head")
    if not all([s_hips, s_head, m_hips, m_head]):
        log("  [WARN] could not find hips/head on both rigs; skipping align")
        return 1.0

    s_torso = (s_head - s_hips).length
    m_torso = (m_head - m_hips).length
    scale = (m_torso / s_torso) if s_torso > 1e-6 else 1.0

    # scale about world origin then translate hips to match
    surv_arm.scale = surv_arm.scale * scale
    bpy.context.view_layer.update()
    new_hips = bone_world_head(surv_arm, "pelvis")
    surv_arm.location += (m_hips - new_hips)
    bpy.context.view_layer.update()

    log(f"  scale survival x{scale:.4f}  (torso {s_torso:.3f} -> {m_torso:.3f})")
    return scale


# ===========================================================================
# step 3 - retarget A-pose -> T-pose by hierarchical direction match
# ===========================================================================
def retarget_pose(surv_arm, mx_arm):
    """Morph the survival rig from A-pose to the Mixamo T-pose.

    IMPORTANT: the survival rig comes from a UE5 glTF, where the glTF importer
    gives every bone a meaningless +Y tail. We therefore CANNOT use bone tail
    directions. Instead we use the JOINT HEAD POSITIONS (which are correct) and
    align, for each bone, the vector (head_of_main_child - head_of_bone) to the
    same vector measured on the Mixamo rig. Processed parents-first so each limb
    chain folds into the T-pose."""
    # mixamo rest world head positions
    mx_head = {}
    for b in mx_arm.data.bones:
        mx_head[b.name] = mx_arm.matrix_world @ b.head_local

    surv_arm.data.pose_position = 'POSE'
    bpy.context.view_layer.update()

    # parents-first ordering of survival bones
    ordered, seen = [], set()

    def visit(bone):
        if bone.name in seen:
            return
        if bone.parent:
            visit(bone.parent)
        seen.add(bone.name)
        ordered.append(bone)

    for b in surv_arm.data.bones:
        visit(b)

    def main_child(bone):
        """Pick the survival child that continues the limb chain: the mapped
        child with the longest rest segment whose Mixamo bone differs from this
        bone's Mixamo bone (so folded helper children are ignored)."""
        mb = BM.resolve_bone(bone.name)
        best, best_len = None, -1.0
        for c in bone.children:
            mc = BM.resolve_bone(c.name)
            if not mc or mc == mb or mc not in mx_head:
                continue
            seg = (c.head_local - bone.head_local).length
            if seg > best_len:
                best, best_len = c, seg
        return best

    applied = 0
    for bone in ordered:
        mb = BM.resolve_bone(bone.name)
        if not mb or mb not in mx_head:
            continue
        child = main_child(bone)
        if child is None:
            continue
        mc = BM.resolve_bone(child.name)
        pbone = surv_arm.pose.bones.get(bone.name)
        pchild = surv_arm.pose.bones.get(child.name)
        if not pbone or not pchild:
            continue
        # current survival limb direction (world) using joint heads
        cur = (surv_arm.matrix_world @ pchild.head) - (surv_arm.matrix_world @ pbone.head)
        tgt = mx_head[mc] - mx_head[mb]
        if cur.length < 1e-6 or tgt.length < 1e-6:
            continue
        cur.normalize(); tgt.normalize()
        rot = cur.rotation_difference(tgt)  # world-space rotation
        # convert to the bone's object space and apply about the head
        rot_obj = (surv_arm.matrix_world.inverted().to_3x3()
                   @ rot.to_matrix() @ surv_arm.matrix_world.to_3x3())
        # Snap the joint head onto the Mixamo joint position (in survival
        # armature space) as well as matching direction. Rotation-only retarget
        # left the survival joints up to ~0.25u off the Mixamo joints (survival
        # bone lengths differ), which tore garment seams open at the wrists and
        # shoulders. Snapping the heads closes those gaps.
        arm_head = surv_arm.matrix_world.inverted() @ mx_head[mb]
        new_basis = (rot_obj @ pbone.matrix.to_3x3()).to_4x4()
        new_basis.translation = arm_head
        pbone.matrix = new_basis
        bpy.context.view_layer.update()
        applied += 1
    log(f"  retarget: aligned {applied} survival limb segments to Mixamo joints")


def bake_to_world(clothing, surv_arm):
    """Freeze each mesh into WORLD space:
      1. apply the survival Armature modifier (bakes the retargeted T-pose),
      2. clear the parent keeping the world transform,
      3. apply object loc/rot/scale so the vertices live in world coordinates
         and the object matrix becomes identity.
    After this the clothing geometry is aligned with the Mixamo body and can be
    safely re-parented to the Mixamo armature without shifting."""
    for obj in clothing:
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        mod = next((m for m in obj.modifiers if m.type == 'ARMATURE'), None)
        if mod is None:
            mod = obj.modifiers.new("SurvArm", 'ARMATURE')
            mod.object = surv_arm
        try:
            bpy.ops.object.modifier_apply(modifier=mod.name)
        except RuntimeError as e:
            log(f"  [WARN] could not bake pose on {obj.name}: {e}")
        # keep world transform when detaching from the survival armature
        try:
            bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        except RuntimeError:
            obj.parent = None
        # bake the world transform into the vertices -> matrix becomes identity
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ===========================================================================
# step 4 - rename / merge vertex groups UE5 -> Mixamo
# ===========================================================================
def remap_vertex_groups(obj):
    """Build new Mixamo-named vertex groups by summing weights of every UE5
    group that maps to them, then delete the old groups. Returns (n_mapped,
    n_dropped, dropped_names)."""
    # gather per-vertex weights bucketed by target mixamo name
    mesh = obj.data
    target_weights = {}   # mixamo_name -> {vert_index: weight}
    dropped = set()
    src_groups = {vg.index: vg.name for vg in obj.vertex_groups}

    for vidx, v in enumerate(mesh.vertices):
        for g in v.groups:
            src_name = src_groups.get(g.group)
            if src_name is None:
                continue
            mx = BM.resolve_bone(src_name)
            if mx is None:
                dropped.add(src_name)
                continue
            target_weights.setdefault(mx, {})
            target_weights[mx][vidx] = target_weights[mx].get(vidx, 0.0) + g.weight

    # wipe all existing groups
    for vg in list(obj.vertex_groups):
        obj.vertex_groups.remove(vg)

    # create mixamo groups and assign summed weights
    for mx, weights in target_weights.items():
        vg = obj.vertex_groups.new(name=mx)
        for vidx, w in weights.items():
            vg.add([vidx], min(w, 1.0), 'REPLACE')

    n_mapped = len(target_weights)
    return n_mapped, len(dropped), sorted(dropped)


# ===========================================================================
# step 5 - bind clothing to the mixamo armature
# ===========================================================================
def bind_to_mixamo(obj, mx_arm):
    """Parent the (world-baked, identity-matrix) clothing to the Mixamo armature
    without moving it, and add a fresh Armature modifier."""
    for m in [m for m in obj.modifiers if m.type == 'ARMATURE']:
        obj.modifiers.remove(m)
    obj.parent = mx_arm
    # object verts are already in world space (matrix == identity); cancel the
    # parent so the world transform stays at identity.
    obj.matrix_parent_inverse = mx_arm.matrix_world.inverted()
    obj.matrix_basis = Matrix()
    mod = obj.modifiers.new("Armature", 'ARMATURE')
    mod.object = mx_arm
    mod.use_vertex_groups = True


# ===========================================================================
# step 6 - data-transfer weight cleanup from the mixamo body
# ===========================================================================
def data_transfer_weights(obj, body):
    if body is None:
        log(f"  [WARN] no Mixamo body mesh found for data transfer on {obj.name}")
        return
    bpy.context.view_layer.objects.active = obj
    mod = obj.modifiers.new("WeightTransfer", 'DATA_TRANSFER')
    mod.object = body
    mod.use_vert_data = True
    mod.data_types_verts = {'VGROUP_WEIGHTS'}
    mod.vert_mapping = 'POLYINTERP_NEAREST'
    # make sure target groups exist on obj (they do from remap); transfer layers
    try:
        bpy.ops.object.datalayout_transfer(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except RuntimeError as e:
        log(f"  [WARN] data transfer failed on {obj.name}: {e}")
        if mod.name in [m.name for m in obj.modifiers]:
            obj.modifiers.remove(mod)


# ===========================================================================
# step 7 - shrinkwrap conform
# ===========================================================================
def shrinkwrap_conform(obj, body, offset=0.01, subdivide=False):
    if body is None:
        return
    bpy.context.view_layer.objects.active = obj

    # Optionally add a subdivision surface BEFORE shrinkwrap so low-poly garments
    # (especially gloves) have enough vertices to conform to the body curvature.
    if subdivide:
        sub = obj.modifiers.new("SubdivPre", 'SUBSURF')
        sub.levels = 1
        sub.render_levels = 1
        try:
            bpy.ops.object.modifier_apply(modifier=sub.name)
        except RuntimeError as e:
            log(f"  [WARN] subdiv failed on {obj.name}: {e}")
            if sub.name in [m.name for m in obj.modifiers]:
                obj.modifiers.remove(sub)

    mod = obj.modifiers.new("Conform", 'SHRINKWRAP')
    mod.target = body
    mod.wrap_method = 'NEAREST_SURFACEPOINT'
    mod.wrap_mode = 'OUTSIDE'
    mod.offset = offset
    # keep the shrinkwrap BEFORE the armature in the stack
    try:
        # move to top then apply so geometry conforms in rest pose
        while obj.modifiers[0].name != mod.name:
            bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    except RuntimeError as e:
        log(f"  [WARN] shrinkwrap failed on {obj.name}: {e}")
        if mod.name in [m.name for m in obj.modifiers]:
            obj.modifiers.remove(mod)

    # Light smooth to clean up shrinkwrap artifacts on tight garments
    if subdivide:
        smooth = obj.modifiers.new("SmoothPost", 'SMOOTH')
        smooth.factor = 0.2
        smooth.iterations = 1
        try:
            while obj.modifiers[0].name != smooth.name:
                bpy.ops.object.modifier_move_up(modifier=smooth.name)
            bpy.ops.object.modifier_apply(modifier=smooth.name)
        except RuntimeError:
            if smooth.name in [m.name for m in obj.modifiers]:
                obj.modifiers.remove(smooth)


# ===========================================================================
# fit metric for the report
# ===========================================================================
def _wbbox(obj):
    w = [obj.matrix_world @ v.co for v in obj.data.vertices]
    mn = Vector((min(v.x for v in w), min(v.y for v in w), min(v.z for v in w)))
    mx = Vector((max(v.x for v in w), max(v.y for v in w), max(v.z for v in w)))
    return mn, mx, (mn + mx) * 0.5, (mx - mn)


def fit_metric(obj, body):
    """Meaningful fit check per garment: compares the garment's vertical band and
    horizontal span against the Mixamo body, and flags only real problems
    (garment centre far from the expected body band). Limbs legitimately extend
    beyond the torso in X, so X is reported but not flagged."""
    if body is None:
        return "no-body"
    b_mn, b_mx, b_c, b_s = _wbbox(body)
    g_mn, g_mx, g_c, g_s = _wbbox(obj)

    slot = str(obj.get("cloth_slot", "")) or BM.clothing_slot(obj.name)
    # expected vertical band (fraction of body height) per slot
    bands = {
        "torso": (0.45, 0.95),
        "legs":  (0.05, 0.55),
        "feet":  (0.00, 0.12),
        "hands": (0.40, 0.95),  # hands sit around shoulder height in T-pose
    }
    lo, hi = bands.get(slot, (0.0, 1.0))
    band_lo = b_mn.z + lo * b_s.z
    band_hi = b_mn.z + hi * b_s.z
    band_mid = (band_lo + band_hi) * 0.5
    dz = g_c.z - band_mid
    tol = 0.20 * b_s.z
    status = "OK" if abs(dz) <= tol else "CHECK"
    flag = "" if status == "OK" else "  [CHECK fit]"
    return (f"[{status}] z-centre={g_c.z:+.2f} (expected~{band_mid:+.2f}, dz={dz:+.2f}) "
            f"span=({g_s.x:.2f},{g_s.y:.2f},{g_s.z:.2f}){flag}")


# ===========================================================================
# step 8.5 - give the (untextured, pure-white) survival garments sensible colors
# ===========================================================================
# survival_characte.glb ships the clothing with flat white materials and no
# textures, so in-game every garment looks like a white blob. Assign a believable
# weathered base colour + cloth roughness per slot.
GARMENT_COLORS = {
    "torso": (0.21, 0.24, 0.17, 1.0),   # olive-drab survival jacket
    "legs":  (0.16, 0.21, 0.31, 1.0),   # faded denim jeans
    "hands": (0.27, 0.17, 0.09, 1.0),   # brown leather gloves
    "feet":  (0.09, 0.09, 0.08, 1.0),   # dark rubber/leather boots
}


def colorize_garments(clothing):
    for obj in clothing:
        slot = str(obj.get("cloth_slot", "")) or BM.clothing_slot(obj.name)
        color = GARMENT_COLORS.get(slot, (0.3, 0.3, 0.3, 1.0))
        if not obj.data.materials:
            mat = bpy.data.materials.new(name="garment_%s" % slot)
            obj.data.materials.append(mat)
        for mat in obj.data.materials:
            if mat is None:
                continue
            mat.use_nodes = True
            bsdf = next((n for n in mat.node_tree.nodes
                         if n.type == 'BSDF_PRINCIPLED'), None)
            if bsdf is None:
                bsdf = mat.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
            bsdf.inputs["Base Color"].default_value = color
            if "Roughness" in bsdf.inputs:
                bsdf.inputs["Roughness"].default_value = 0.85
            if "Metallic" in bsdf.inputs:
                bsdf.inputs["Metallic"].default_value = 0.0
            mat.diffuse_color = color
        log(f"  colorized {obj.name} ({slot}) -> {tuple(round(c, 2) for c in color)}")


# ===========================================================================
# main
# ===========================================================================
def main():
    opts = parse_args()
    log("=== ADAPT survival clothing -> Mixamo rig ===")
    log(f"mixamo   = {opts['mixamo']}")
    log(f"survival = {opts['survival']}")

    reset_scene()

    log("\n[1] import Mixamo target")
    _, mx_arm, mx_meshes = import_glb(opts["mixamo"])
    if mx_arm is None:
        log("  [FATAL] no armature in Mixamo file"); write_report(opts); return
    mx_arm.name = "MixamoArmature"
    body = next((m for m in mx_meshes if m.name.split(".")[0] in ("Body", "Body3")), None)
    if body is None and mx_meshes:
        body = max(mx_meshes, key=lambda m: len(m.data.vertices))
    log(f"  mixamo armature='{mx_arm.name}' bones={len(mx_arm.data.bones)} body='{body.name if body else None}'")

    log("\n[2] import survival source")
    _, surv_arm, surv_meshes = import_glb(opts["survival"])
    if surv_arm is None:
        log("  [FATAL] no armature in survival file"); write_report(opts); return

    clothing = [m for m in surv_meshes if BM.classify_mesh(m.name) == "clothing"]
    rigid = [m for m in surv_meshes if BM.classify_mesh(m.name) == "rigid"]
    discard = [m for m in surv_meshes if BM.classify_mesh(m.name) in ("body", "helper", "unknown")]
    # also discard the Mixamo bounding-helper icosphere if present
    discard += [m for m in mx_meshes if m.name.split(".")[0] in BM.HELPER_MESHES]

    # rename to predictable slot-based names for the Godot scene/nodes,
    # storing the slot as a property so later steps don't depend on the name
    for m in clothing:
        slot = BM.clothing_slot(m.name)
        m["cloth_slot"] = slot
        m.name = "cloth_" + slot
    for m in rigid:
        slot = BM.rigid_slot(m.name)
        m["rigid_slot"] = slot
        m.name = "gear_" + slot
    log(f"  clothing = {[m.name for m in clothing]}")
    log(f"  rigid    = {[m.name for m in rigid]}")
    log(f"  discard  = {[m.name for m in discard]}")

    log("\n[3] align + scale survival to Mixamo")
    align_survival_to_mixamo(surv_arm, mx_arm)

    if opts["retarget"]:
        log("\n[4] retarget A-pose -> T-pose")
        retarget_pose(surv_arm, mx_arm)
        log("    bake retargeted pose into clothing geometry (world space)")
        bake_to_world(clothing + rigid, surv_arm)
    else:
        log("\n[4] retarget skipped (--no-retarget)")
        log("    baking world transform into clothing geometry")
        bake_to_world(clothing + rigid, surv_arm)

    log("\n[5] remap vertex groups UE5 -> Mixamo + bind to Mixamo armature")
    for obj in clothing:
        n_map, n_drop, dropped = remap_vertex_groups(obj)
        bind_to_mixamo(obj, mx_arm)
        log(f"  {obj.name}: mapped={n_map} groups, dropped={n_drop}")
        if n_map == 0:
            log(f"     [MANUAL] {obj.name} ended with 0 Mixamo groups -> needs manual weighting")

    if opts["datatransfer"]:
        log("\n[6] data-transfer weight cleanup from Mixamo body")
        for obj in clothing:
            _slot = str(obj.get("cloth_slot", "")) or BM.clothing_slot(obj.name)
            # Skip data-transfer for gloves: the Mixamo body may lack detailed
            # finger geometry, so nearest-polygon transfer would overwrite the
            # carefully remapped UE5 finger weights with generic hand weights,
            # making gloves deform as a rigid block.
            if _slot == "hands":
                log(f"  {obj.name}: skipping data-transfer (preserve finger weights)")
                continue
            data_transfer_weights(obj, body)

    if opts["shrinkwrap"]:
        log("\n[7] shrinkwrap conform to body")
        for obj in clothing:
            _slot = str(obj.get("cloth_slot", "")) or BM.clothing_slot(obj.name)
            # Per-slot shrinkwrap strategy:
            #   hands: very tight (0.0) + subdivision for better finger conform
            #   feet:  tight (0.003)
            #   torso: snug (0.006) to close shoulder gaps
            #   legs:  slightly loose (0.010) for natural drape
            if _slot == "hands":
                off = 0.0
                sub = True
            elif _slot == "feet":
                off = 0.003
                sub = False
            elif _slot == "torso":
                off = 0.006
                sub = False
            else:
                off = 0.010
                sub = False
            shrinkwrap_conform(obj, body, off, subdivide=sub)
            # re-bind armature removed by apply order? ensure armature present
            if not any(m.type == 'ARMATURE' for m in obj.modifiers):
                bind_to_mixamo(obj, mx_arm)

    log("\n[8] fit report")
    for obj in clothing:
        log(f"  {obj.name}: {fit_metric(obj, body)}")

    log("\n[8.5] colorize untextured survival garments")
    colorize_garments(clothing)

    # tag rigid gear with its intended attach bone for the export script
    for obj in rigid:
        slot = str(obj.get("rigid_slot", ""))
        obj["attach_bone"] = BM.RIGID_ATTACH_BONE.get(slot, "mixamorig:Spine2")
        # detach rigid gear from the survival armature (it becomes a static mesh)
        for m in [mm for mm in obj.modifiers if mm.type == 'ARMATURE']:
            obj.modifiers.remove(m)
        obj.parent = None
        log(f"  rigid '{obj.name}' -> slot={slot} attach_bone={obj['attach_bone']}")

    # discard survival body/helper meshes and the survival armature
    log("\n[9] cleanup survival body + armature")
    for obj in discard:
        bpy.data.objects.remove(obj, do_unlink=True)
    # the survival armature is no longer needed (clothing now on Mixamo rig)
    bpy.data.objects.remove(surv_arm, do_unlink=True)

    # save blend
    out = os.path.abspath(opts["out"])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=out)
    log(f"\nSaved adapted scene -> {out}")
    write_report(opts)


def write_report(opts):
    path = os.path.abspath(opts["report"])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write("\n".join(REPORT) + "\n")
    print(f"Report written -> {path}")


if __name__ == "__main__":
    main()
