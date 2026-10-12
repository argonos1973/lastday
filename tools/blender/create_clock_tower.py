"""Enterable civic clock tower. Godot metres, Y up; all stairs have smooth colliders."""
import bpy, math, random
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=R/'assets/models/environment/city';rng=random.Random(8271)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def v(p):return (p[0],-p[2],p[1])
def mat(name,c,texture=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.9
 if texture:
  im=bpy.data.images.load(str(R/texture),check_existing=True).copy();im.name=name;im.scale(1024,1024);im.pack();t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(.48,.45,.40,1);m.node_tree.links.new(t.outputs['Color'],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],p.inputs['Base Color'])
 return m
stone=mat('Tower_aged_stone',(.52,.49,.43),'assets/textures/overgrowth/village_lime_albedo.png')
concrete=mat('Tower_concrete',(.35,.34,.3),'assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg')
wood=mat('Tower_old_oak',(.22,.15,.09),'assets/textures/overgrowth/village_wood_albedo.png')
brick=mat('Tower_exposed_brick',(.3,.16,.1),'assets/external/textures/red_brick_03/red_brick_03_diff_4k.jpg')
bronze=mat('Tower_verdigris',(.055,.11,.10));gold=mat('Clock_brass',(.64,.51,.25));black=mat('Clock_enamel',(.025,.031,.029));iron=mat('Tower_iron',(.09,.08,.065))
def mesh(name,verts,faces,m):
 me=bpy.data.meshes.new(name);me.from_pydata([v(p) for p in verts],[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 if m:me.materials.append(m)
 uv=me.uv_layers.new()
 for poly in me.polygons:
  axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[a for a in range(3) if a!=axis]
  for li in poly.loop_indices:
   co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]/9,co[axes[1]]/9)
 return o
def box(name,p,s,m,solid=True):
 bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.name=('Solid_' if solid else 'Detail_')+name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 for poly in o.data.polygons:
  axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[a for a in range(3) if a!=axis]
  for li in poly.loop_indices:
   co=o.data.vertices[o.data.loops[li].vertex_index].co+o.location;o.data.uv_layers.active.data[li].uv=(co[axes[0]]/9,co[axes[1]]/9)
 return o
def framewall(z,y,width,height,door=False):
 holes=[(-width*.5+1.0,-width*.5+2.4,1.0,3.25),(width*.5-2.4,width*.5-1.0,1.0,3.25)]
 if door:holes.append((-1.6,1.6,0,3.4))
 at=-width/2
 for a,b,lo,hi in sorted(holes):
  if a>at:box('Pier',((at+a)/2,y+height/2,z),(a-at,height,.3),stone)
  if lo>0:box('Sill',((a+b)/2,y+lo/2,z),(b-a,lo,.3),stone)
  box('Lintel',((a+b)/2,y+(hi+height)/2,z),(b-a,height-hi,.3),stone)
  for x in [a,b]:box('WindowReveal',(x,y+(lo+hi)/2,z-.18),(.12,hi-lo,.12),concrete,False)
  box('WindowSill',((a+b)/2,y+lo,z),(b-a+.2,.09,.50),concrete,False)
  at=b
 if at<width/2:box('Pier',((at+width/2)/2,y+height/2,z),(width/2-at,height,.3),stone)
# Large ground-floor public hall, open main entrance facing the plaza (north).
box('HallFloor',(0,-.09,0),(18,.18,16),concrete)
framewall(-8,0,18,4.2,True);framewall(8,0,18,4.2)
for x in [-9,9]:box('HallSide',(x,2.1,0),(.3,4.2,16),stone)
# Counters flank a broad central aisle and do not touch the stair approach.
for x in [-5.8,.6]:
 box('CounterBase',(x,.57,-2.2),(3.7,1.14,1.0),wood)
 box('CounterTop',(x,1.18,-2.2),(3.9,.12,1.18),concrete)
 for xx in [x-1.1,x,x+1.1]:box('CounterPanel',(xx,.58,-2.73),(.95,.78,.035),wood,False)
for x in [-7.8,-6.0,-4.2]:
 box('ArchiveSide',(x,1.5,6.8),(.09,3,.55),wood)
for y in [.45,1.15,1.85,2.55]:box('ArchiveShelf',(-6, y,6.8),(3.7,.08,.55),wood)
for x in [-7.5,7.5]:box('WingRoof',(x,4.1,0),(3,.2,16),concrete)
for z in [-7,7]:box('WingRoof',(0,4.1,z),(12,.2,2),concrete)
FH=4.2;N=7
for level in range(N+1):
 y=level*FH
 if level:
  box('FloorMain',(-1.5,y-.10,0),(9,.2,12),wood)
  for z in [-5.5,5.5]:box('FloorLanding',(4.5,y-.10,z),(3,.2,1),wood)
 # Stacked parallel flights remain 4.2 m apart; the west corridor returns to each start.
 if level<N:
  start=-5.0;end=5.0
  for k in range(24):
   t=(k+1)/24;box('StairTread',(4.5,y+FH*t-.075,start+(end-start)*(k+.5)/24),(1.9,.15,10/24),wood,False)
  verts=[(3.55,y,start),(5.45,y,start),(3.55,y+FH,end),(5.45,y+FH,end)]
  faces=[(0,2,3,1)] if end>start else [(0,1,3,2)]
  mesh('Collision_StairRamp_%d'%level,verts,faces,None)
  # Inner rail follows flight; no rail across either landing.
  for k in range(1,10):
   t=k/10;box('StairBaluster',(3.36,y+FH*t+.5,start+(end-start)*t),(.06,1,.06),iron)
 if level and level<N:
  framewall(-6,y,12,FH);framewall(6,y,12,FH)
  for x in [-6,6]:box('ShaftSide',(x,y+FH/2,0),(.3,FH,12),stone)
  for z in [-6.18,6.18]:box('Cornice',(0,y,z),(12.55,.20,.45),concrete,False)
  for x in [-6.18,6.18]:box('Cornice',(x,y,0),(.45,.20,12.55),concrete,False)
  for x in [-5.8,5.8]:
   for z in [-6.18,6.18]:box('Quoin',(x,y+FH/2,z),(.5,FH,.22),concrete,False)
# Observation gallery, with real parapets outside floor edges.
for x in [-6.25,6.25]:box('Gallery',(x,29.3,0),(.5,.2,13),concrete)
for z in [-6.25,6.25]:box('Gallery',(0,29.3,z),(12,.2,.5),concrete)
for side in [-1,1]:
 for q in range(-6,7):
  box('GalleryPost',(side*6.45,29.95,q),(.07,1.1,.07),iron)
  box('GalleryPost',(q,29.95,side*6.45),(.07,1.1,.07),iron)
 box('GalleryRail',(side*6.45,30.5,0),(.08,.08,13),iron)
 box('GalleryRail',(0,30.5,side*6.45),(13,.08,.08),iron)
# Belfry supports leave the gallery accessible from the top stair landing.
for x in [-3.4,3.4]:
 for z in [-3.4,3.4]:box('BelfryPier',(x,31.5,z),(.5,4.2,.5),stone)
box('BelfryCornice',(0,33.7,0),(8.0,.3,8.0),concrete)
spire=[];faces=[]
for height,radius in [(33.85,4.3),(34.5,3.3),(36.6,2.0),(38.0,.65),(38.8,.48),(39.1,.01)]:
 for x,z in [(-1,-1),(1,-1),(1,1),(-1,1)]:spire.append((x*radius,height,z*radius))
for ring in range(5):
 for side in range(4):faces.append((ring*4+side,ring*4+(side+1)%4,(ring+1)*4+(side+1)%4,(ring+1)*4+side))
mesh('Detail_CopperSpire',spire,faces,bronze)
box('Finial',(0,40,0),(.13,2.4,.13),gold,False)
# Four black clock dials. Hand objects retain their own origins for runtime rotation.
for face in range(4):
 angle=face*math.pi/2
 def orient(p):
  x,y,z=p;return (x*math.cos(angle)+z*math.sin(angle),y,-x*math.sin(angle)+z*math.cos(angle))
 center=orient((0,27.3,-6.22))
 bpy.ops.mesh.primitive_torus_add(major_radius=1.77,minor_radius=.075,major_segments=48,minor_segments=6,location=v(center),rotation=(math.pi/2,0,angle));bpy.context.object.name='Detail_ClockRim';bpy.context.object.data.materials.append(gold)
 verts=[orient((0,27.3,-6.22))]+[orient((math.sin(i*math.tau/64)*1.72,27.3+math.cos(i*math.tau/64)*1.72,-6.22)) for i in range(65)]
 mesh('Detail_ClockDial_%d'%face,verts,[(0,i+1,i+2) for i in range(64)],black)
 for tick in range(12):
  a=tick*math.tau/12;r=1.46
  p=orient((math.sin(a)*r,27.3+math.cos(a)*r,-6.25));o=box('ClockMark',p,(.065,.24,.06),gold,False);o.rotation_euler=(0,-a,angle)
 for kind,length,width in [('Hour',.92,.10),('Minute',1.35,.065)]:
  # Blender parent supplies face yaw; child vertices are local to the clock centre.
  local=[(-width/2,-.18,0),(width/2,-.18,0),(width/2,length*.82,0),(0,length,0),(-width/2,length*.82,0)]
  o=mesh('Clock%s_%d'%(kind,face),local,[(4,3,2,1,0)],gold);o.location=v(orient((0,27.3,-6.30)));o.rotation_euler.z=angle
# Recessed civic portico: pillars and stepped cornice frame the broad entrance.
for x in [-2.1,2.1]:
 box('EntranceColumn',(x,1.7,-8.45),(.38,3.4,.55),concrete)
 box('ColumnBase',(x,.12,-8.45),(.64,.24,.76),concrete)
 box('ColumnCapital',(x,3.4,-8.45),(.68,.22,.75),concrete)
box('PorticoCornice',(0,3.65,-8.45),(5.4,.28,1.0),concrete)
# Jagged areas of exposed brick, avoiding the door and windows.
mesh('Detail_ExposedBrick',[(-6.5,.1,-8.17),(-4.5,.1,-8.17),(-4.4,1.1,-8.17),(-4.8,1.25,-8.17),(-4.75,1.9,-8.17),(-5.2,2.3,-8.17),(-5.5,1.9,-8.17),(-6.1,2.1,-8.17),(-6.2,1.3,-8.17),(-6.5,1.1,-8.17)],[tuple(reversed(range(10)))],brick)
# Merge static surfaces by collision role, retaining the seven stair ramps and hands.
for prefix in ['Solid_','Detail_']:
 objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(prefix)]
 bpy.ops.object.select_all(action='DESELECT')
 for o in objs:o.select_set(True)
 bpy.context.view_layer.objects.active=objs[0];bpy.ops.object.join();objs[0].name=prefix+'Tower'
(R/'outputs/city').mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(R/'outputs/city/clock_tower.blend'))
bpy.ops.export_scene.gltf(filepath=str(O/'clock_tower.glb'),export_format='GLB',export_animations=False)
print('CLOCK_TOWER_READY')
