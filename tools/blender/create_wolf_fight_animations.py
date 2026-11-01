"""Realistic wolf fight clips on the wolf_companion rig.

Adds Wolf_threaten (low circling menace loop), rewrites Wolf_attack
(coil -> explosive lunge -> jaw snap -> clamp tug -> release) and adds
Wolf_shake (clamped kill-bite head shake used against prey). Runs from
the project root:

  /Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup \
      --python tools/blender/create_wolf_fight_animations.py

Re-exports assets/models/animals/wolf_companion.glb keeping every
existing clip and renders check frames to build/tmp/.
"""
import bpy, math, json, struct
from mathutils import Vector, Matrix
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/animals/wolf_companion.glb'
bpy.ops.wm.open_mainfile(filepath=str(ROOT / 'tools/blender/sources/wolf_companion.blend'))
a = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for t in a.animation_data.nla_tracks:
    t.mute = True
a.animation_data.action = None
for p in a.pose.bones:
    p.matrix_basis.identity()
bpy.context.view_layer.update()
rest = {p.name: p.matrix.copy() for p in a.pose.bones}

def update():
    bpy.context.view_layer.update()

def aim(n, child, target):
    p = a.pose.bones[n]; origin = p.matrix.translation.copy()
    old = rest[child].translation - rest[n].translation
    q = old.normalized().rotation_difference((Vector(target) - origin).normalized())
    p.matrix = Matrix.Translation(origin) @ q.to_matrix().to_4x4() @ rest[n].to_3x3().to_4x4(); update()

def ik(n1, n2, n3, goal, pole):
    p = a.pose.bones[n1].matrix.translation.copy(); goal = Vector(goal)
    l1 = (rest[n2].translation - rest[n1].translation).length
    l2 = (rest[n3].translation - rest[n2].translation).length
    v = goal - p; d = min(max(v.length, abs(l1 - l2) + .01), l1 + l2 - .01); axis = v.normalized()
    side = Vector(pole) - p; side = (side - axis * side.dot(axis)).normalized()
    along = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    mid = p + axis * along + side * math.sqrt(max(0, l1 * l1 - along * along))
    aim(n1, n2, mid); aim(n2, n3, p + axis * d)

def _s(x):
    x = min(1, max(0, x)); return x * x * (3 - 2 * x)

def _rot(bone, deg, axis='X'):
    p = a.pose.bones[bone]
    p.matrix = Matrix.Translation(p.matrix.translation) @ Matrix.Rotation(math.radians(deg), 4, axis) @ p.matrix.to_3x3().to_4x4(); update()

def _yaw_head(deg):
    # Twist the head on its own axis for shakes and scanning glances.
    for n in ['Head', 'Neck2']:
        if n in a.pose.bones:
            p = a.pose.bones[n]; g = p.matrix.copy()
            p.matrix = Matrix.Translation(g.translation) @ Matrix.Rotation(math.radians(deg), 4, 'Z') @ g.to_3x3().to_4x4(); update()
            return

def _legs(front_wrist, front_ankle, hock, back_ankle, sx=13, sbx=16):
    for side, sign in [('L', 1), ('R', -1)]:
        f = 'LegF' + side; b = 'LegB' + side
        ik(f + '1', f + '2', f + '3', (sign * sx, front_wrist[1], front_wrist[2]), (sign * (sx + 1), -15, 30))
        aim(f + '3', f + 'Ankle', (sign * sx, front_ankle[1], front_ankle[2]))
        p = a.pose.bones[f + 'Ankle']; p.matrix = Matrix.Translation(p.matrix.translation) @ rest[f + 'Ankle'].to_3x3().to_4x4(); update()
        ik(b + '1', b + '2', b + '3', (sign * sbx, hock[1], hock[2]), (sign * (sbx + 4), -30, 15))
        aim(b + '3', b + 'Ankle', (sign * sbx, back_ankle[1], back_ankle[2]))
        p = a.pose.bones[b + 'Ankle']; p.matrix = Matrix.Translation(p.matrix.translation) @ rest[b + 'Ankle'].to_3x3().to_4x4(); update()

def _tail(dx, dy, dz):
    for i in range(1, 4):
        n = 'Tail' + str(i); child = 'Tail' + str(i + 1)
        if n in a.pose.bones and child in a.pose.bones:
            v = a.pose.bones[n].matrix.translation
            aim(n, child, v + Vector((dx, dy, dz)))

def _jaw(deg):
    p = a.pose.bones['Jaw']; g = p.matrix.copy()
    p.matrix = Matrix.Translation(g.translation) @ Matrix.Rotation(math.radians(deg), 4, 'X') @ g.to_3x3().to_4x4(); update()

def _ears_flat(f):
    # Pin both ears back against the skull (bones are EarL1/EarR1 chains).
    for n in ['EarL1', 'EarR1']:
        if n in a.pose.bones:
            _rot(n, -58 * f)

def _snarl(f):
    # Curl the lip corners up and back to bare the teeth while jaws are open.
    for n in ['MouthL', 'MouthR']:
        if n in a.pose.bones and n + '_end' in a.pose.bones:
            v = a.pose.bones[n].matrix.translation
            aim(n, n + '_end', v + Vector((0, 5.5 * f, 4.5 * f)))

def pose_attack(t):
    """Coil 0-.22, lunge .22-.32, jaw snap .32-.42, clamp+tug .42-.72, release."""
    for p in a.pose.bones: p.matrix_basis.identity()
    update()
    coil = _s(t / .22); lun = _s((t - .22) / .10); snap = _s((t - .32) / .10)
    rec = _s((t - .72) / .28)
    wind = coil * (1 - lun); fwd = lun * (1 - rec); hold = snap * (1 - rec)
    clamp = hold * _s((t - .42) / .08)  # tug window while jaws stay shut
    shake = math.sin(min(1, max(0, (t - .45) / .30)) * math.tau * 2) * 9 * clamp
    pel = rest['Pelvis'].translation.copy()
    pel.y += wind * 9 - fwd * 16 - clamp * 3
    pel.z -= wind * 9 - fwd * 2 + clamp * 2
    a.pose.bones['Pelvis'].matrix = Matrix.Translation(pel) @ rest['Pelvis'].to_3x3().to_4x4(); update()
    _rot('Spine1', -8 * wind + 10 * fwd + clamp * 4)
    _legs((0, -43 - fwd * 20 + wind * 7, 8 + fwd * 2 - wind * 2),
          (0, -50 - fwd * 18 + wind * 6, 5),
          (0, 36 + wind * 11 - fwd * 5, 9 - wind * 5 + fwd * 2),
          (0, 18 + wind * 6, 5))
    _rot('Neck1', -14 * wind + 10 * fwd - 10 * snap + clamp * 12)
    _yaw_head(shake)
    _jaw(48 * max(wind, fwd) * (1 - snap) + 10 * rec * (1 - _s((t - .88) / .12)))
    _snarl(max(wind, fwd) * (1 - snap))
    _ears_flat(0.7 * max(wind, clamp))
    _tail(4 + 6 * fwd, 8 + 18 * fwd, -4)

def pose_threaten(ph):
    """Low circling menace: crouched, head level-low, slow sway, tail tucked."""
    for p in a.pose.bones: p.matrix_basis.identity()
    update()
    sway = math.sin(ph * math.tau); br = math.sin(ph * math.tau * 2)
    pel = rest['Pelvis'].translation.copy()
    pel.x += sway * 4.5; pel.y += 5; pel.z -= 14 + br * 1.5
    a.pose.bones['Pelvis'].matrix = Matrix.Translation(pel) @ rest['Pelvis'].to_3x3().to_4x4(); update()
    _rot('Spine1', 12 + br * 2)
    _rot('Chest', 4)
    _rot('Chest', sway * 6, 'Z')
    _legs((0, -40, 6), (0, -48, 4), (0, 34, 8), (0, 16, 4), sx=15, sbx=17)
    _rot('Neck1', -36 + br * 3)
    _yaw_head(sway * 10)
    _jaw(14 + 6 * (br + 1) / 2)
    _snarl(0.7)
    _ears_flat(0.85)
    _tail(2, -14, -12)

def pose_shake(t):
    """Clamped kill-bite on downed prey: braces, then whips its head side to side."""
    for p in a.pose.bones: p.matrix_basis.identity()
    update()
    settle = _s(t / .12); out = _s((t - .88) / .12)
    sh = math.sin(min(1, max(0, (t - .12) / .76)) * math.tau * 3.0) * 30 * settle * (1 - out)
    pel = rest['Pelvis'].translation.copy()
    pel.x += sh * 0.10; pel.y += 7 * settle * (1 - out); pel.z += 2 * settle * (1 - out)
    a.pose.bones['Pelvis'].matrix = Matrix.Translation(pel) @ rest['Pelvis'].to_3x3().to_4x4(); update()
    _rot('Spine1', 14 * settle * (1 - out))
    _rot('Chest', -sh * 0.16, 'Z')
    _legs((0, -58, 5), (0, -62, 4), (0, 40, 12), (0, 26, 6), sx=18, sbx=18)
    _rot('Neck1', 30 * settle * (1 - out))
    _yaw_head(sh)
    _jaw(2 + 14 * out)
    _tail(0, 16 * settle * (1 - out), 6)

def bake(name, frames, fn, step=1):
    action = bpy.data.actions.new(name); a.animation_data.action = action
    for frame in range(1, frames + 1, step):
        bpy.context.scene.frame_set(frame); fn((frame - 1) / (frames - 1))
        for p in a.pose.bones:
            p.rotation_mode = 'QUATERNION'
            for prop in ['location', 'rotation_quaternion', 'scale']:
                p.keyframe_insert(prop, frame=frame, group=p.name)
    for fc in action.fcurves:
        for key in fc.keyframe_points:
            key.interpolation = 'BEZIER'; key.handle_left_type = key.handle_right_type = 'AUTO_CLAMPED'
    a.animation_data.action = None
    track = a.animation_data.nla_tracks.new(); track.name = name
    track.strips.new(name, 1, action); track.mute = False
    return action

# Replace the old one-note lunge with the full bite cycle. Tracks go first:
# orphan strips tolerate a removed action but not the other way round, and
# stale actions from a previous run would force .001-suffixed duplicates.
CLIPS = ('Wolf_attack', 'Wolf_threaten', 'Wolf_shake')
for tr in list(a.animation_data.nla_tracks):
    if tr.name in CLIPS:
        a.animation_data.nla_tracks.remove(tr)
for act in list(bpy.data.actions):
    if act.name.split('.')[0] in CLIPS:
        bpy.data.actions.remove(act)

bake('Wolf_attack', 38, pose_attack)
bake('Wolf_threaten', 121, pose_threaten, step=5)
bake('Wolf_shake', 50, pose_shake)
for t in a.animation_data.nla_tracks:
    t.mute = False
bpy.context.scene.render.fps = 30
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'tools/blender/sources/wolf_companion.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format='GLB',
                          export_animations=True, export_animation_mode='NLA_TRACKS')
# Fur cutouts must stay alpha-MASK or Godot sorts the whole body transparent.
data = OUT.read_bytes()
json_len, chunk_type = struct.unpack_from('<II', data, 12)
payload = json.loads(data[20:20 + json_len])
for material in payload.get('materials', []):
    material['alphaMode'] = 'MASK'; material['alphaCutoff'] = .35
encoded = json.dumps(payload, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
tail = data[20 + json_len:]
OUT.write_bytes(struct.pack('<III', 0x46546C67, 2, 20 + len(encoded) + len(tail)) + struct.pack('<II', len(encoded), chunk_type) + encoded + tail)

# Turntable stills for visual verification (EEVEE is enough for pose checks).
for t in a.animation_data.nla_tracks:
    t.mute = True
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 900; scene.render.resolution_y = 600
scene.world = bpy.data.worlds.new('Studio'); scene.world.color = (.2, .2, .2)
bpy.ops.mesh.primitive_plane_add(size=200); bpy.context.object.location.z = .015
bpy.ops.object.light_add(type='AREA', location=(2, -3, 5)); bpy.context.object.data.energy = 700; bpy.context.object.data.size = 4
bpy.ops.object.camera_add(location=(3.2, -3.8, 1.7)); cam = bpy.context.object; scene.camera = cam
cam.rotation_euler = (Vector((0, -.2, .6)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
checks = {'attack': (bpy.data.actions['Wolf_attack'], [9, 12, 20, 30]),
          'threaten': (bpy.data.actions['Wolf_threaten'], [1, 31, 61]),
          'shake': (bpy.data.actions['Wolf_shake'], [6, 18, 30])}
for name, (act, frs) in checks.items():
    a.animation_data.action = act
    for fr in frs:
        scene.frame_set(fr); update()
        scene.render.filepath = str(ROOT / f'build/tmp/wolf_fight_{name}_{fr}.png')
        bpy.ops.render.render(write_still=True)
print('WOLF_FIGHT_DONE')
