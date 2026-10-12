"""Enterable civic clock tower. Godot metres, Y up; all stairs have smooth colliders.
Stairs switch back floor to floor: even flights climb the east lane towards +z,
odd flights return on the west lane towards -z, split by a papered spine wall.
Interior finishes reuse the city houses' ruined wallpaper, boards and ceiling."""
import bpy, bmesh, math, random
import numpy as np
from pathlib import Path
R=Path(__file__).resolve().parents[2];O=R/'assets/models/environment/city';rng=random.Random(8271)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def v(p):return (p[0],-p[2],p[1])
def mat(name,c,texture=None,tint=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Roughness'].default_value=.9
 if texture:
  im=bpy.data.images.load(str(R/texture),check_existing=True).copy();im.name=name;im.scale(1024,1024)
  if tint:
   # glTF drops Mix nodes, so the tint is baked into the packed pixels.
   px=np.empty(len(im.pixels),dtype=np.float32);im.pixels.foreach_get(px);px=px.reshape(-1,4);px[:,:3]*=tint;im.pixels.foreach_set(px.ravel())
  im.pack();t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im
  m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
 return m
stone=mat('Tower_aged_stone',(.52,.49,.43),'assets/textures/overgrowth/village_lime_albedo.png')
concrete=mat('Tower_concrete',(.35,.34,.3),'assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg')
wood=mat('Tower_old_oak',(.22,.15,.09),'assets/textures/overgrowth/village_wood_albedo.png',(.62,.36,.20))
brick=mat('Tower_exposed_brick',(.3,.16,.1),'assets/external/textures/red_brick_03/red_brick_03_diff_4k.jpg')
bronze=mat('Tower_verdigris',(.055,.11,.10));gold=mat('Clock_brass',(.64,.51,.25));black=mat('Clock_enamel',(.025,.031,.029));iron=mat('Tower_iron',(.09,.08,.065))
# Same baked interior textures as the houses (create_city_interior_kit.py).
TEXI='assets/textures/city_interior/'
floor=mat('Tower_floor_ruin',(.3,.23,.16),TEXI+'floor_ruin.png')
ceiling=mat('Tower_ceiling_ruin',(.62,.6,.54),TEXI+'ceiling_ruin.png')
papers=[mat('Tower_wallpaper_%d'%i,(.5,.5,.5),TEXI+'wallpaper_ruin_%d.png'%i) for i in range(4)]
UVM={}
def mesh(name,verts,faces,m):
 me=bpy.data.meshes.new(name);me.from_pydata([v(p) for p in verts],[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o)
 if m:me.materials.append(m)
 uv=me.uv_layers.new()
 for poly in me.polygons:
  axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[a for a in range(3) if a!=axis]
  for li in poly.loop_indices:
   co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]/9,co[axes[1]]/9)
 return o
def box(name,p,s,m,solid=True,uvm=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.name=('Solid_' if solid else 'Detail_')+name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 # Interior finishes tile like the houses (~3 m wallpaper/boards, 2.4 m floor).
 uvm=uvm or (3.2 if m in papers or m is ceiling else 2.4 if m is floor else 9)
 for poly in o.data.polygons:
  axis=max(range(3),key=lambda a:abs(poly.normal[a]));axes=[a for a in range(3) if a!=axis]
  for li in poly.loop_indices:
   co=o.data.vertices[o.data.loops[li].vertex_index].co+o.location;o.data.uv_layers.active.data[li].uv=(co[axes[0]]/uvm,co[axes[1]]/uvm)
 return o
def wedge(name,x0,x1,y0,z0,y1,z1):
 # Closed stair wedge rising from (z0,y0) to (z1,y1); underside sealed so the
 # capsule can neither walk under a flight nor pop up through its slope.
 pts=[(x0,y0,z0),(x1,y0,z0),(x0,y1,z1),(x1,y1,z1),(x0,y0,z1),(x1,y0,z1)]
 me=bpy.data.meshes.new(name);me.from_pydata([v(p) for p in pts],[],[(0,1,3,2),(2,3,5,4),(0,2,4),(1,5,3),(0,4,5,1)])
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();me.update()
 o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return o
def cbox(name,p,s):
 bpy.ops.mesh.primitive_cube_add(size=1,location=v(p));o=bpy.context.object;o.name='Collision_'+name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);return o
def paperwall(z,y,width,paper,door=False,H=4.0):
 # Wallpaper on the inner face of a framewall, leaving its real openings.
 holes=[(-width*.5+1.0,-width*.5+2.4,1.0,3.25),(width*.5-2.4,width*.5-1.0,1.0,3.25)]
 if door:holes.append((-1.6,1.6,0,3.4))
 at=-width/2+.16
 for a,b,lo,hi in sorted(holes):
  if a-.1>at:box('Paper',((at+a-.1)/2,y+H/2,z),(a-.1-at,H,.02),paper,False)
  if lo>0:box('Paper',((a+b)/2,y+(lo-.03)/2,z),(b-a,lo-.03,.02),paper,False)
  box('Paper',((a+b)/2,y+(hi+.03+H)/2,z),(b-a,H-hi-.03,.02),paper,False)
  at=b+.1
 if at<width/2-.16:box('Paper',((at+width/2-.16)/2,y+H/2,z),(width/2-.16-at,H,.02),paper,False)
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
box('HallFloor',(0,-.05,0),(18,.18,16),floor)
framewall(-8,0,18,4.2,True);framewall(8,0,18,4.2)
for x in [-9,9]:box('HallSide',(x,2.1,0),(.3,4.2,16),stone)
paperwall(-7.83,0,18,papers[0],True);paperwall(7.83,0,18,papers[0])
for x in [-8.83,8.83]:box('Paper',(x,2.0,0),(.02,4.0,15.6),papers[0],False)
# Counters flank a central aisle, clear of the west stair lane (x>1.2).
for x in [-6.0,-1.4]:
 box('CounterBase',(x,.57,-2.2),(3.0,1.14,1.0),wood)
 box('CounterTop',(x,1.18,-2.2),(3.2,.12,1.18),concrete)
 for xx in [x-1.0,x,x+1.0]:box('CounterPanel',(xx,.58,-2.73),(.9,.78,.035),wood,False)
for x in [-7.8,-6.0,-4.2]:
 box('ArchiveSide',(x,1.5,6.8),(.09,3,.55),wood)
for y in [.45,1.15,1.85,2.55]:box('ArchiveShelf',(-6, y,6.8),(3.7,.08,.55),wood)
for x in [-7.5,7.5]:box('WingRoof',(x,4.1,0),(3,.2,16),concrete)
for z in [-7,7]:box('WingRoof',(0,4.1,z),(12,.2,2),concrete)
for x in [-7.5,7.5]:box('Ceiling',(x,3.99,0),(3,.02,16),ceiling,False)
for z in [-7,7]:box('Ceiling',(0,3.99,z),(12,.02,2),ceiling,False)
FH=4.2;N=7;ZS=4.4
# Two stair lanes in the east half of the shaft. Flight L climbs lane A
# (east) towards +z when L is even, lane B (west) towards -z when odd, so each
# flight starts on the landing where the previous one ended.
LANE={'A':(3.55,5.85),'B':(1.25,3.45)};LANE_FLOOR={'A':(3.5,6.0),'B':(1.2,3.5)}
def lane(level):return 'A' if level%2==0 else 'B'
for level in range(N+1):
 y=level*FH;paper=papers[level%4]
 if level:
  # Main floor, both end landings, and the lane the next flight leaves from;
  # the lane the previous flight arrived through stays open as a stairwell.
  box('FloorMain',(-2.4,y-.10,0),(7.2,.2,12),floor)
  for z in [-5.2,5.2]:box('FloorLanding',(3.6,y-.10,z),(4.8,.2,1.6),floor)
  f0,f1=LANE_FLOOR[lane(level)];box('FloorLane',((f0+f1)/2,y-.10,0),(f1-f0,.2,2*ZS),floor)
  box('Ceiling',(-2.4,y-.21,0),(7.2,.02,11.9),ceiling,False)
  for z in [-5.2,5.2]:box('Ceiling',(3.6,y-.21,z),(4.8,.02,1.6),ceiling,False)
  box('Ceiling',((f0+f1)/2,y-.21,0),(f1-f0,.02,2*ZS),ceiling,False)
  # Stop across the far end of the open stairwell (where the arriving flight
  # started, one storey below).
  a0,a1=LANE_FLOOR[lane(level-1)];zend=-ZS if (level-1)%2==0 else ZS
  zstop=zend-.04*(1 if zend>0 else -1)
  cbox('StairwellStop_%d'%level,((a0+a1)/2,y+.55,zstop),(a1-a0,1.1,.06))
  box('StairwellRail',((a0+a1)/2,y+1.0,zstop),(a1-a0,.06,.06),iron,False)
  for xx in [a0+.15,(a0+a1)/2,a1-.15]:box('StairwellPost',(xx,y+.5,zstop),(.05,1.0,.05),iron,False)
 if level<N:
  x0,x1=LANE[lane(level)];d=1 if level%2==0 else -1;z0=-ZS*d
  for k in range(24):
   h=FH*(k+1)/24;box('StairStep',((x0+x1)/2,y+h/2,z0+d*(k+.5)*2*ZS/24),(x1-x0,h,2*ZS/24),wood,False,2.4)
  wedge('Collision_StairRamp_%d'%level,x0,x1,y,z0,y+FH,-z0)
 if level and level<N:
  framewall(-6,y,12,FH);framewall(6,y,12,FH)
  for x in [-6,6]:box('ShaftSide',(x,y+FH/2,0),(.3,FH,12),stone)
  paperwall(-5.83,y,12,paper);paperwall(5.83,y,12,paper)
  for x in [-5.83,5.83]:box('Paper',(x,y+2.0,0),(.02,4.0,11.6),paper,False)
  for z in [-6.18,6.18]:box('Cornice',(0,y,z),(12.55,.20,.45),concrete,False)
  for x in [-6.18,6.18]:box('Cornice',(x,y,0),(.45,.20,12.55),concrete,False)
  for x in [-5.8,5.8]:
   for z in [-6.18,6.18]:box('Quoin',(x,y+FH/2,z),(.5,FH,.22),concrete,False)
# Papered spine between the lanes (rising 1.1 m above the top floor as a
# parapet), the west lane wall from the first floor up, and a hall-level wall
# along the east side of the first flight.
box('StairSpine',(3.5,(N*FH+1.1)/2,0),(.1,N*FH+1.1,2*ZS),papers[1])
box('StairLaneWall',(1.2,(FH+N*FH)/2,0),(.1,(N-1)*FH,2*ZS),papers[2])
box('HallStairWall',(6.0,FH/2,0),(.1,FH,2*ZS),papers[0])
# Top floor: the open east lane borders the gallery.
cbox('TopStairwellStop',(5.97,N*FH+.55,0),(.06,1.1,2*ZS))
box('TopStairwellRail',(5.97,N*FH+1.0,0),(.06,.06,2*ZS),iron,False)
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
