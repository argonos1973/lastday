"""
bone_map_ue5_to_mixamo.py
=========================

Shared data + helpers used by the Blender pipeline scripts.

The survival_characte.glb rig is an Unreal-Engine-5 ("Manny/Quinn") skeleton
(160 bones: pelvis, spine_01..05, clavicle_*, upperarm_*, lowerarm_*, thigh_*,
calf_*, foot_*, ball_*, IK + twist + corrective helper bones).

The player rig is a Mixamo skeleton (67 bones: mixamorig:Hips, Spine/Spine1/
Spine2, LeftArm, LeftForeArm, ...).

This module provides:
  * UE5 -> Mixamo bone-name mapping (with "fold to parent" rules for the UE5
    twist / corrective / metacarpal / extra-spine bones that Mixamo lacks).
  * Classification of the survival meshes into deformable clothing, rigid gear,
    body parts (discarded) and helpers (discarded).
  * Default rigid-gear -> Mixamo attachment-bone hints used by Godot.

It is plain Python (no bpy import) so it can be unit-checked outside Blender,
and it is imported by the adapt / export scripts via sys.path manipulation.
"""

# ---------------------------------------------------------------------------
# 1. Mesh classification
# ---------------------------------------------------------------------------
# Deformable clothing that must end up sharing the Mixamo Skeleton3D.
CLOTHING_MESHES = {
    "Jacket": "torso",
    "Jeans":  "legs",
    "Gloves": "hands",
    "Shoes":  "feet",
}

# Rigid gear: exported as separate meshes, attached in Godot via BoneAttachment3D.
RIGID_MESHES = {
    "Backpack": "backpack",
}

# Body / head meshes that belong to the survival character and are discarded
# (the Mixamo character already provides its own body + head).
BODY_MESHES = {
    "Body3", "Eye", "Eyebrows", "Eyeleash", "Hair", "Mouth1",
}

# Pure helpers (bounding icosphere etc.) that are always discarded.
HELPER_MESHES = {
    "Icosphere",
}

# ---------------------------------------------------------------------------
# 2. Rigid gear -> Mixamo attachment bone (for BoneAttachment3D in Godot)
# ---------------------------------------------------------------------------
RIGID_ATTACH_BONE = {
    "backpack": "mixamorig:Spine2",   # high on the back
    "helmet":   "mixamorig:Head",
    "weapon":   "mixamorig:RightHand",
    "bat":      "mixamorig:RightHand",
    "flashlight": "mixamorig:RightHand",
    "canteen":  "mixamorig:Hips",
}

# ---------------------------------------------------------------------------
# 3. UE5 -> Mixamo direct bone-name map (deforming bones only)
# ---------------------------------------------------------------------------
# Spine: UE5 has 5 spine bones, Mixamo only 3. spine_04/05 fold into Spine2.
_DIRECT = {
    "pelvis":   "mixamorig:Hips",
    "spine_01": "mixamorig:Spine",
    "spine_02": "mixamorig:Spine1",
    "spine_03": "mixamorig:Spine2",
    "spine_04": "mixamorig:Spine2",
    "spine_05": "mixamorig:Spine2",
    "neck_01":  "mixamorig:Neck",
    "neck_02":  "mixamorig:Neck",
    "head":     "mixamorig:Head",
}

# Arms, legs, hands per side. {ue_template: mixamo_template}; {S} side token.
_LIMB = {
    "clavicle_{s}": "mixamorig:{S}Shoulder",
    "upperarm_{s}": "mixamorig:{S}Arm",
    "lowerarm_{s}": "mixamorig:{S}ForeArm",
    "hand_{s}":     "mixamorig:{S}Hand",
    "thigh_{s}":    "mixamorig:{S}UpLeg",
    "calf_{s}":     "mixamorig:{S}Leg",
    "foot_{s}":     "mixamorig:{S}Foot",
    "ball_{s}":     "mixamorig:{S}ToeBase",
}

# Fingers: UE5 <finger>_01/02/03_{s} -> Mixamo <Finger>1/2/3.
_FINGERS = {
    "thumb":  "Thumb",
    "index":  "Index",
    "middle": "Middle",
    "ring":   "Ring",
    "pinky":  "Pinky",
}

_SIDE = {"l": "Left", "r": "Right"}


def _build_direct_map():
    """Return the full UE5->Mixamo dict for the bones that map 1:1."""
    m = dict(_DIRECT)
    for side, S in _SIDE.items():
        for ue_t, mx_t in _LIMB.items():
            m[ue_t.format(s=side)] = mx_t.format(S=S)
        for ue_f, mx_f in _FINGERS.items():
            for i in (1, 2, 3):
                m[f"{ue_f}_0{i}_{side}"] = f"mixamorig:{S}Hand{mx_f}{i}"
            # metacarpal folds into the hand (Mixamo has no metacarpals)
            m[f"{ue_f}_metacarpal_{side}"] = f"mixamorig:{S}Hand"
    return m


DIRECT_MAP = _build_direct_map()


# ---------------------------------------------------------------------------
# 4. "Fold to parent" rules for UE5 helper bones Mixamo does not have
# ---------------------------------------------------------------------------
# Any UE5 bone whose name contains one of these tokens has its skin weight
# folded into the nearest mapped ancestor (see resolve_bone) instead of being
# dropped, so no skin weight is lost.
_FOLD_TOKENS = (
    "twist", "twistcor", "corrective", "correctiveroot",
    "_out_", "_in_", "_fwd_", "_bck_", "_lwr_",
    "tricep", "bicep", "knee", "kneeback", "ankle",
    "latissimus", "pec", "scap", "wrist_inner", "wrist_outer",
)

# Bones that are dropped entirely (no skin influence on clothing anyway).
_DROP_TOKENS = ("ik_", "interaction", "center_of_mass", "weapon_")


def is_dropped(ue_bone: str) -> bool:
    n = ue_bone.lower()
    return any(tok in n for tok in _DROP_TOKENS)


def _strip_to_parent_candidate(ue_bone: str) -> str:
    """
    Given a UE5 helper bone name, return a plausible parent UE5 bone name by
    removing the helper suffix tokens, so we can look it up in DIRECT_MAP.
    e.g. lowerarm_twist_02_l -> lowerarm_l ; thigh_correctiveRoot_r -> thigh_r
    """
    n = ue_bone.lower()
    side = ""
    if n.endswith("_l"):
        side = "_l"
    elif n.endswith("_r"):
        side = "_r"
    base = n[: -len(side)] if side else n
    # cut at the first fold token
    for tok in ("_twistcor", "_twist", "_correctiveroot", "_corrective",
                "_kneeback", "_knee", "_tricep", "_bicep", "_out", "_in",
                "_fwd", "_bck", "_lwr", "_latissimus", "_pec", "_scap"):
        idx = base.find(tok)
        if idx != -1:
            base = base[:idx]
            break
    return base + side


def resolve_bone(ue_bone: str):
    """
    Map a UE5 bone name to a Mixamo bone name.

    Returns the Mixamo bone name, or None if the bone should be dropped.
    Helper / twist / corrective bones are folded into the nearest mapped
    ancestor so their skin weight is preserved on the clothing.
    """
    if not ue_bone:
        return None
    if ue_bone in DIRECT_MAP:
        return DIRECT_MAP[ue_bone]
    if is_dropped(ue_bone):
        return None
    n = ue_bone.lower()
    if any(tok in n for tok in _FOLD_TOKENS):
        cand = _strip_to_parent_candidate(ue_bone)
        if cand in DIRECT_MAP:
            return DIRECT_MAP[cand]
        # last resort: try removing one trailing token group repeatedly
        parts = cand.rsplit("_", 1)
        while len(parts) == 2:
            shorter = parts[0] + ("_" + cand[-1] if cand.endswith(("_l", "_r")) else "")
            if shorter in DIRECT_MAP:
                return DIRECT_MAP[shorter]
            parts = parts[0].rsplit("_", 1)
    return None


def classify_mesh(name: str) -> str:
    """Return one of: 'clothing', 'rigid', 'body', 'helper', 'unknown'."""
    base = name.split(".")[0]
    if base in CLOTHING_MESHES:
        return "clothing"
    if base in RIGID_MESHES:
        return "rigid"
    if base in BODY_MESHES:
        return "body"
    if base in HELPER_MESHES:
        return "helper"
    return "unknown"


def clothing_slot(name: str) -> str:
    return CLOTHING_MESHES.get(name.split(".")[0], "")


def rigid_slot(name: str) -> str:
    return RIGID_MESHES.get(name.split(".")[0], "")


if __name__ == "__main__":
    # Quick self-check when run with a plain python interpreter.
    print(f"DIRECT_MAP entries: {len(DIRECT_MAP)}")
    for sample in ["pelvis", "spine_04", "upperarm_l", "lowerarm_twist_02_l",
                   "thigh_correctiveRoot_r", "index_02_r", "pinky_metacarpal_l",
                   "ik_foot_l", "weapon_r", "calf_knee_l"]:
        print(f"  {sample:26s} -> {resolve_bone(sample)}")
