"""Fit user-provided static garments to the game's Mixamo rest pose."""
from pathlib import Path
import bpy
import sys
from mathutils import Vector
from mathutils.kdtree import KDTree
ROOT=Path(__file__).resolve().parents[2]
SRC=ROOT/'tools/blender/sources/root_clothes'
OUT=ROOT/'assets/characters/adapted/civil'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/characters/adapted/player_with_clothes.glb'))
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE'); arm.data.pose_position='REST'
refs={o.name:o for o in bpy.data.objects if o.type=='MESH'}
def smooth(a,b,x):
 t=max(0,min(1,(x-a)/(b-a))); return t*t*(3-2*t)
def bounds(objs):
 pts=[o.matrix_world@v.co for o in objs for v in o.data.vertices]
 return Vector([min(p[i] for p in pts) for i in range(3)]),Vector([max(p[i] for p in pts) for i in range(3)])
for filename,stem,samples in [('low_poly_military_jacket_tactical_top.glb','digital_field_jacket',['Body_arms','Desnudo_torso']),('clothes_pants.glb','cargo_kneepad_pants',['Desnudo_legs','Bottoms'])]:
 if '--pants-only' in sys.argv and stem!='cargo_kneepad_pants':continue
 before=set(bpy.data.objects); bpy.ops.import_scene.gltf(filepath=str(SRC/filename)); objs=[o for o in set(bpy.data.objects)-before if o.type=='MESH']
 for o in objs:
  world=o.matrix_world.copy(); o.parent=None; o.matrix_world=world
  bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
 lo,hi=bounds(objs)
 for o in objs:
  for v in o.data.vertices:
   p=v.co.copy()
   if stem=='digital_field_jacket':
    # Source sleeves slope down from the shoulder; straighten around their
    # actual axis before transferring weights, preserving cuff cross sections.
    side=1 if p.x>=0 else -1;x=abs(p.x)
    trunk=Vector((p.x*2.18,p.y*1.95+.02,1.93+(p.z-.9904)*1.52))
    shoulder=Vector((.235,.018,1.685));axis=Vector((.38,0,-.455)).normalized();radial=Vector((-axis.z,0,axis.x))
    rel=Vector((x,p.y,p.z))-shoulder
    sleeve=Vector((side*(.39+rel.dot(axis)*1.86),.11+rel.y*1.7,2.999+rel.dot(radial)*1.7))
    v.co=trunk.lerp(sleeve,smooth(.20,.32,x)*smooth(.58,.69,x+.25*p.z))
   else:
    # Model arrives in centimetres, centered slightly off its symmetry axis.
    q=Vector(((p.x-(lo.x+hi.x)*.5)*.0195,(p.y-(lo.y+hi.y)*.5)*.0175+.035,.24+(p.z-lo.z)/(hi.z-lo.z)*1.90))
    # Source has splayed legs and rearward ankles. Match the rest-pose
    # leg axes, not just the overall bounding box, so cuffs surround boots.
    side=1 if q.x>=0 else -1
    lower=1.0-smooth(.55,1.80,q.z)
    source_axis=.335-.15*smooth(.45,1.95,q.z)
    target_axis=.185
    radial=abs(q.x)-source_axis
    q.x=side*(source_axis+(target_axis-source_axis)*lower+radial*(1-.16*lower))
    q.y-=.085*lower
    v.co=q
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();g=objs[0];g.name=stem
 if g.data.has_custom_normals:bpy.ops.mesh.customdata_custom_splitnormals_clear()
 for f in g.data.polygons:f.use_smooth=True
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
 for mat in g.data.materials:
  if mat and mat.use_nodes:
   bs=next((n for n in mat.node_tree.nodes if n.type=='BSDF_PRINCIPLED'),None)
   for node in mat.node_tree.nodes:
    if node.type=='NORMAL_MAP':node.inputs['Strength'].default_value=.35
   if bs:
    for key,val in [('Roughness',.88),('Metallic',0.0)]:
     for link in list(bs.inputs[key].links):mat.node_tree.links.remove(link)
     bs.inputs[key].default_value=val
 g.vertex_groups.clear()
 for bone in arm.data.bones:g.vertex_groups.new(name=bone.name)
 points=[]
 for name in samples:
  o=refs[name]
  for v in o.data.vertices:
   weights={o.vertex_groups[w.group].name:w.weight for w in v.groups if w.weight>.001}
   if weights:points.append((o.matrix_world@v.co,weights))
 kd=KDTree(len(points))
 for i,(p,w) in enumerate(points):kd.insert(p,i)
 kd.balance()
 for v in g.data.vertices:
  weights={}
  for _,i,d in kd.find_n(v.co,8):
   for name,w in points[i][1].items():
    if g.vertex_groups.get(name):weights[name]=weights.get(name,0)+w/max(.025,d)**2
  strongest=sorted(weights.items(),key=lambda v:v[1],reverse=True)[:4];total=sum(w for _,w in strongest)
  assert total>0
  for name,w in strongest:g.vertex_groups[name].add([v.index],w/total,'REPLACE')
 mod=g.modifiers.new('Character_skeleton','ARMATURE');mod.object=arm;world=g.matrix_world.copy();g.parent=arm;g.matrix_world=world
 bpy.ops.object.select_all(action='DESELECT');g.select_set(True);arm.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(stem+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=True)
 pickup=g.copy();pickup.data=g.data.copy();bpy.context.collection.objects.link(pickup);pickup.parent=None;pickup.matrix_world=g.matrix_world.copy()
 for m in list(pickup.modifiers):pickup.modifiers.remove(m)
 center=sum((Vector(c) for c in pickup.bound_box),Vector())/8
 for v in pickup.data.vertices:v.co-=center
 bpy.ops.object.select_all(action='DESELECT');pickup.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/('pickup_'+stem+'.glb')),export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
 bpy.data.objects.remove(pickup,do_unlink=True)
 print('ROOT_GARMENT_EXPORTED',stem,len(g.data.vertices),flush=True)
