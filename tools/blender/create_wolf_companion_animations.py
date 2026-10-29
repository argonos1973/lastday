"""Add seated, lying and standing rest loops to the existing wolf rig."""
import bpy, math, json, struct
from mathutils import Vector, Matrix
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/external/wolf/WolfAnimated.glb'))
a=next(o for o in bpy.data.objects if o.type=='ARMATURE')
# Fur cutouts need depth writes in Godot; alpha blending sorts the entire
# animated mesh as one transparent object and exposes inner mouth surfaces.
for mat in bpy.data.materials:
 mat.blend_method='CLIP';mat.alpha_threshold=.35
for o in list(bpy.data.objects):
 if o.type=='MESH' and not any(m.type=='ARMATURE' for m in o.modifiers): bpy.data.objects.remove(o,do_unlink=True)
for track in a.animation_data.nla_tracks: track.mute=True
a.animation_data.action=None
for p in a.pose.bones:p.matrix_basis.identity()
bpy.context.view_layer.update()
rest={p.name:p.matrix.copy() for p in a.pose.bones}
def update():bpy.context.view_layer.update()
def aim(n,child,target):
 p=a.pose.bones[n];origin=p.matrix.translation.copy()
 old=rest[child].translation-rest[n].translation
 q=old.normalized().rotation_difference((Vector(target)-origin).normalized())
 p.matrix=Matrix.Translation(origin)@q.to_matrix().to_4x4()@rest[n].to_3x3().to_4x4();update()
def ik(n1,n2,n3,goal,pole):
 p=a.pose.bones[n1].matrix.translation.copy();goal=Vector(goal)
 l1=(rest[n2].translation-rest[n1].translation).length;l2=(rest[n3].translation-rest[n2].translation).length
 v=goal-p;d=min(max(v.length,abs(l1-l2)+.01),l1+l2-.01);axis=v.normalized()
 side=Vector(pole)-p;side=(side-axis*side.dot(axis)).normalized()
 along=(l1*l1-l2*l2+d*d)/(2*d);mid=p+axis*along+side*math.sqrt(max(0,l1*l1-along*along))
 aim(n1,n2,mid);aim(n2,n3,p+axis*d)
def pose(kind,breath):
 for p in a.pose.bones:p.matrix_basis.identity()
 update()
 if kind=='eat':
  # Keep the hind feet planted; lower the shoulders and flex the neck toward food.
  p=a.pose.bones['Spine1']
  p.matrix=Matrix.Translation(rest['Spine1'].translation)@Matrix.Rotation(math.radians(23+breath),4,'X')@rest['Spine1'].to_3x3().to_4x4();update()
  for side,sign in [('L',1),('R',-1)]:
   front='LegF'+side
   ik(front+'1',front+'2',front+'3',(sign*13,-52,17),(sign*15,-20,28))
   aim(front+'3',front+'Ankle',(sign*13,-56,5))
   p=a.pose.bones[front+'Ankle'];p.matrix=Matrix.Translation(p.matrix.translation)@rest[front+'Ankle'].to_3x3().to_4x4();update()
  p=a.pose.bones['Neck1'];origin=p.matrix.translation.copy()
  p.matrix=Matrix.Translation(origin)@Matrix.Rotation(math.radians(57+breath*3),4,'X')@rest['Neck1'].to_3x3().to_4x4();update()
  p=a.pose.bones['Jaw'];g=p.matrix.copy()
  p.matrix=Matrix.Translation(g.translation)@Matrix.Rotation(math.radians(4+7*(breath+1)/2),4,'X')@g.to_3x3().to_4x4();update()
  return
 if kind=='idle':
  p=a.pose.bones['Chest'];p.scale.y=1+breath*.006;update();return
 tilt=math.radians(-36) if kind=='sit' else math.radians(-3)
 pelvis=rest['Pelvis'].translation.copy();pelvis.z=30 if kind=='sit' else 23
 a.pose.bones['Pelvis'].matrix=Matrix.Translation(pelvis)@Matrix.Rotation(tilt,4,'X')@rest['Pelvis'].to_3x3().to_4x4();update()
 for side,sign in [('L',1),('R',-1)]:
  front='LegF'+side;back='LegB'+side
  ankle=Vector((sign*12,-43,5)) if kind=='sit' else Vector((sign*13,-87,5))
  wrist=ankle+Vector((0,4,12)) if kind=='sit' else ankle+Vector((0,12,4))
  ik(front+'1',front+'2',front+'3',wrist,(sign*14,0,30) if kind=='sit' else (sign*14,-30,-40))
  aim(front+'3',front+'Ankle',ankle)
  p=a.pose.bones[front+'Ankle'];p.matrix=Matrix.Translation(p.matrix.translation)@rest[front+'Ankle'].to_3x3().to_4x4();update()
  hock=Vector((sign*16,36,9)) if kind=='sit' else Vector((sign*17,46,9))
  ik(back+'1',back+'2',back+'3',hock,(sign*20,-30,15))
  aim(back+'3',back+'Ankle',(sign*16,15 if kind=='sit' else 25,5))
  p=a.pose.bones[back+'Ankle'];p.matrix=Matrix.Translation(p.matrix.translation)@rest[back+'Ankle'].to_3x3().to_4x4();update()
 # Tail rests beside the haunch, never through the floor.
 for i in range(1,4):
  n='Tail'+str(i);child='Tail'+str(i+1);v=a.pose.bones[n].matrix.translation
  aim(n,child,v+Vector((8,18,-max(0,v.z-8)*.55)))
 p=a.pose.bones['Chest'];p.scale.y*=1+breath*.006;update()
 # Keep the head alert and level in the seated loop.
 if kind=='sit':
  p=a.pose.bones['Neck1'];p.matrix=Matrix.Translation(p.matrix.translation)@rest['Neck1'].to_3x3().to_4x4();update()
def _s(x):x=min(1,max(0,x));return x*x*(3-2*x)
def pose_attack(t):
 # Lunge-and-bite cycle: coil back with open jaws (0-0.35), throw forward and
 # snap shut (0.35-0.55), recover to stance (0.55-1.0). Loops while in range.
 for p in a.pose.bones:p.matrix_basis.identity()
 update()
 coil=_s(t/.35)
 lun=_s((t-.35)/.20)
 rec=_s((t-.55)/.45)
 wind=coil*(1-lun)
 fwd=lun*(1-rec)
 jaw=min(1,max(0,wind-lun*1.6))
 pel=rest['Pelvis'].translation.copy()
 pel.y+=wind*7-fwd*9
 pel.z-=wind*5
 pel.x+=0
 a.pose.bones['Pelvis'].matrix=Matrix.Translation(pel)@rest['Pelvis'].to_3x3().to_4x4();update()
 p=a.pose.bones['Spine1']
 p.matrix=Matrix.Translation(rest['Spine1'].translation)@Matrix.Rotation(math.radians(-6*wind+16*fwd),4,'X')@rest['Spine1'].to_3x3().to_4x4();update()
 for side,sign in [('L',1),('R',-1)]:
  front='LegF'+side;back='LegB'+side
  wrist=(sign*13,-43-fwd*24,8+fwd*5)
  ik(front+'1',front+'2',front+'3',wrist,(sign*14,-15,30))
  aim(front+'3',front+'Ankle',(sign*13,-50-fwd*22,5))
  p=a.pose.bones[front+'Ankle'];p.matrix=Matrix.Translation(p.matrix.translation)@rest[front+'Ankle'].to_3x3().to_4x4();update()
  hock=(sign*16,36+wind*9,9-wind*4)
  ik(back+'1',back+'2',back+'3',hock,(sign*20,-30,15))
  aim(back+'3',back+'Ankle',(sign*16,18+fwd*8,5))
  p=a.pose.bones[back+'Ankle'];p.matrix=Matrix.Translation(p.matrix.translation)@rest[back+'Ankle'].to_3x3().to_4x4();update()
 p=a.pose.bones['Neck1'];o=p.matrix.translation.copy()
 p.matrix=Matrix.Translation(o)@Matrix.Rotation(math.radians(-16*wind+34*fwd),4,'X')@rest['Neck1'].to_3x3().to_4x4();update()
 p=a.pose.bones['Jaw'];g=p.matrix.copy()
 p.matrix=Matrix.Translation(g.translation)@Matrix.Rotation(math.radians(30*jaw),4,'X')@g.to_3x3().to_4x4();update()
 for i in range(1,4):
  n='Tail'+str(i);child='Tail'+str(i+1);v=a.pose.bones[n].matrix.translation
  aim(n,child,v+Vector((4+6*fwd,10,-6)))

new=[]
for kind in ['idle','sit','lie','eat']:
 action=bpy.data.actions.new('Wolf_'+kind);a.animation_data.action=action
 for frame in (list(range(1,122,5)) if kind=='eat' else [1,31,61,91,121]):
  bpy.context.scene.frame_set(frame);pose(kind,math.sin((frame-1)/120*math.tau*(6 if kind=='eat' else 1)))
  for p in a.pose.bones:
   p.rotation_mode='QUATERNION'
   for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(prop,frame=frame,group=p.name)
 new.append(action)
 a.animation_data.action=None
 track=a.animation_data.nla_tracks.new();track.name=action.name;track.strips.new(action.name,1,action);track.mute=True
action=bpy.data.actions.new('Wolf_attack');a.animation_data.action=action
for frame in range(1,33):
 bpy.context.scene.frame_set(frame);pose_attack((frame-1)/31.0)
 for p in a.pose.bones:
  p.rotation_mode='QUATERNION'
  for prop in ['location','rotation_quaternion','scale']:p.keyframe_insert(prop,frame=frame,group=p.name)
new.append(action)
a.animation_data.action=None
track=a.animation_data.nla_tracks.new();track.name='Wolf_attack';track.strips.new('Wolf_attack',1,action);track.mute=True
for t in a.animation_data.nla_tracks:t.mute=False
bpy.context.scene.render.fps=30
bpy.context.scene.frame_start=1;bpy.context.scene.frame_end=121
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'tools/blender/sources/wolf_companion.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/animals/wolf_companion.glb'),export_format='GLB',export_animations=True,export_animation_mode='NLA_TRACKS')
# Blender 4.2 maps the legacy CLIP flag to blended export. Enforce glTF
# MASK explicitly, retaining the binary buffers and all animation offsets.
output = ROOT/'assets/models/animals/wolf_companion.glb'
data = output.read_bytes()
json_len, chunk_type = struct.unpack_from('<II', data, 12)
assert chunk_type == 0x4E4F534A
payload = json.loads(data[20:20+json_len])
for material in payload.get('materials', []):
 material['alphaMode'] = 'MASK'
 material['alphaCutoff'] = .35
encoded = json.dumps(payload, separators=(',', ':')).encode()
encoded += b' ' * (-len(encoded) % 4)
tail = data[20+json_len:]
output.write_bytes(struct.pack('<III', 0x46546C67, 2, 20+len(encoded)+len(tail)) + struct.pack('<II', len(encoded), chunk_type) + encoded + tail)
# Studio previews of the actual deformed mesh, with no auxiliary skeletons.
for t in a.animation_data.nla_tracks:t.mute=True
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16
scene.render.resolution_x=1000;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.color=(.18,.18,.18)
bpy.ops.mesh.primitive_plane_add(size=200);ground=bpy.context.object;ground.location.z=.015
mat=bpy.data.materials.new('Studio ground');mat.diffuse_color=(.11,.14,.16,1);ground.data.materials.append(mat)
bpy.ops.object.light_add(type='AREA',location=(2,-3,5));bpy.context.object.data.energy=600;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=4
bpy.ops.object.light_add(type='AREA',location=(-3,1,3));bpy.context.object.data.energy=350;bpy.context.object.data.size=3
bpy.ops.object.camera_add(location=(3.0,-3.5,1.9));cam=bpy.context.object;scene.camera=cam
cam.rotation_euler=(Vector((0,-.3,.5))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.8
for kind,action in zip(['idle','sit','lie','eat','attack'],new):
 a.animation_data.action=action;scene.frame_set(14 if kind=='attack' else 31);update()
 scene.render.filepath=str(ROOT/f'build/tmp/wolf_{kind}.png');bpy.ops.render.render(write_still=True)
print('WOLF_COMPANION_DONE')
