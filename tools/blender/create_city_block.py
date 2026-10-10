"""Four enterable pilot buildings. Coordinates below are Godot metres (Y up)."""
import bpy, math, random
random.seed(812)
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/environment/city'
OUT.mkdir(parents=True,exist_ok=True)

def mat(name,color):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.85
 return m

def textured(m, relative, name):
 im=bpy.data.images.load(str(ROOT/relative),check_existing=True)
 im=im.copy(); im.name=name; im.scale(1024,1024); im.pack()
 tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im
 m.node_tree.links.new(tex.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
 return m

def box(name,p,s,m,collision=True,rot=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(p[0],-p[2],p[1])); o=bpy.context.object; o.name=('Solid_' if collision else 'Detail_')+name
 o.scale=(s[0],s[2],s[1]); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(m)
 if rot is not None: o.rotation_euler=rot
 if name in ['Pier','Lintel','SillWall','WindowSill','DoorFrame','BrokenSideUpper','SideWallBase','BrokenRoof']:
  bevel=o.modifiers.new('Worn_masonry_edges','BEVEL');bevel.width=.018;bevel.segments=2
  bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
 # Metric planar UVs keep masonry at the same scale on every wall segment.
 for poly in o.data.polygons:
  axis=max(range(3),key=lambda a:abs(poly.normal[a])); axes=[a for a in range(3) if a!=axis]
  for loop in poly.loop_indices:
   co=o.data.vertices[o.data.loops[loop].vertex_index].co+o.location
   o.data.uv_layers.active.data[loop].uv=(co[axes[0]]/2.8,co[axes[1]]/2.8)
 return o

def wall(z,front,fmat=None):
 # Real openings: no invisible full-wall collider behind windows/entrance.
 fmat=fmat or wood
 face=z+(.16 if z>0 else -.16)
 openings=[(-4.25,-2.75,.95,2.55),(2.75,4.25,.95,2.55)]
 if front: openings.append((-.9,.9,.12,2.55))
 for level in range(2):
  holes=sorted(openings if level==0 else [(-4.25,-2.75,.95,2.55),(2.75,4.25,.95,2.55)])
  at=-6
  for a,b,lo,hi in holes:
   if a>at: box('Pier',( (at+a)/2,level*3.2+1.6,z),(a-at,3.2,.28),plaster)
   if lo>0: box('SillWall',((a+b)/2,level*3.2+lo/2,z),(b-a,lo,.28),plaster)
   box('Lintel',((a+b)/2,level*3.2+(hi+3.2)/2,z),(b-a,3.2-hi,.28),plaster)
   if lo> .5:
    box('WindowSill',((a+b)/2,level*3.2+lo,z),(b-a+.18,.09,.48),stone)
    for x in [a,b]: box('WindowFrame',(x,level*3.2+(lo+hi)/2,z),(.065,hi-lo,.1),fmat)
    for y in [lo,hi]: box('WindowFrame',((a+b)/2,level*3.2+y,z),(b-a,.06,.1),fmat)
    cy=level*3.2+(lo+hi)/2
    if rng.random()>.35: box('WindowMullion',((a+b)/2,cy,z),(.05,hi-lo,.08),fmat)
    # Decay: rain streaks below sills, boards across some openings, glass shards.
    if rng.random()<.4:
     for sx in rng.sample([a+.11,b-.11],rng.choice([1,2])):
      box('Shard',(sx,level*3.2+lo+.09,z),(.09,.19,.05),glass,False)
    if rng.random()<.38:
     for pb in range(rng.choice([2,3])):
      box('Board',((a+b)/2+rng.uniform(-.2,.2),level*3.2+lo+.28+pb*.6+rng.uniform(-.05,.05),face),(b-a+.6+rng.uniform(-.2,.4),.23,.08),wood,False,rot=(0,rng.uniform(-.06,.06),0))
   at=b
  if at<6: box('Pier',((at+6)/2,level*3.2+1.6,z),(6-at,3.2,.28),plaster)

for idx,color in enumerate([(.56,.49,.37),(.39,.45,.42),(.57,.38,.29),(.50,.53,.55)]):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 rng=random.Random(idx*31+7)
 plaster=mat('Weathered_plaster',color); stone=mat('Foundation',(.23,.24,.23)); wood=mat('Dark_wood',(.17,.105,.065)); floor=mat('Floor_boards',(.30,.23,.16)); metal=mat('Iron',(.075,.085,.08)); fabric=mat('Faded_fabric',(.22,.28,.22))
 grime=mat('Grime',(.10,.115,.09)); soot=mat('Soot',(.045,.05,.045)); moss=mat('Moss',(.15,.23,.11)); brick=mat('Bare_brick',(.33,.18,.13)); glass=mat('Glass_shard',(.5,.68,.72)); char=mat('Charred_wood',(.05,.045,.04))
 textured(plaster,'assets/textures/overgrowth/village_lime_albedo.png' if idx%2==0 else 'assets/external/textures/red_brick_03/red_brick_03_diff_4k.jpg','Ruined_facade_%d'%idx)
 textured(stone,'assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg','Old_concrete_%d'%idx)
 textured(wood,'assets/textures/overgrowth/village_wood_albedo.png','Old_wood_%d'%idx)
 textured(floor,'assets/textures/overgrowth/village_wood_albedo.png','Floor_wood_%d'%idx)
 box('GroundFloor',(0,.02,0),(12,.2,12),floor)
 wall(6,True,char if idx==1 else None); wall(-6,False)
 for x in [-6,6]:
  box('SideWallBase',(x,2.05,0),(.28,4.1,12),plaster)
  for za,zb in [(-6,-2),(1.3,6)]: box('BrokenSideUpper',(x,5.25,(za+zb)/2),(.28,2.3,zb-za),plaster)
  for k in range(8):
   z=-2+k*.45;h=rng.uniform(.08,.65)
   box('JaggedWallEdge',(x,4.1+h/2,z),(.31,h,.45),plaster)

 # Continuous floor cornice, recessed dark window surrounds and brick piers.
 for z in [-6.19,6.19]:
  box('StringCourse',(0,3.19,z),(12.18,.12,.19),stone,False)
  for x in [-5.86,5.86]: box('CornerPilaster',(x,3.15,z),(.24,6.3,.15),stone,False)
 for x in [-6.19,6.19]: box('SideCornice',(x,3.19,0),(.19,.12,12),stone,False)
 # Upper floor leaves an open 2.4 x 7.4 m stairwell on the right.
 box('UpperFloorMain',(-1.45,3.12,0),(9.1,.2,12),floor)
 box('UpperLanding',(4.55,3.12,-4.4),(2.9,.2,3.2),floor)
 box('UpperFrontFloor',(4.55,3.12,5.5),(2.9,.2,1),floor)
 for level in range(2):
  # Two usable rooms on the left, door gap 1.4 m wide.
  for a,b in [(-6,-3.5),(-2.1,2.9)]: box('RoomPartition',((a+b)/2,level*3.2+1.55,-1),(b-a,3.1,.16),plaster)
  box('RoomDoorLintel',(-2.8,level*3.2+2.8,-1),(1.4,.6,.16),plaster)
  for k in range(18): box('FloorJoint',(-5.85+k*.49,level*3.2+.126,0),(.009,.006,11.8),wood,False)
 # Stair treads and a smooth, matching collision ramp for CharacterBody3D.
 n=20
 for k in range(n):
  h=(k+1)*3.1/n
  box('Step',(4.5,.12+h/2,4.5-(k+.5)*6.4/n),(1.85,h,6.4/n),wood,False)
 verts=[(x,-z,y) for x,y,z in [(3.57,.12,4.5),(5.43,.12,4.5),(3.57,3.22,-1.9),(5.43,3.22,-1.9),(3.57,.0,-1.9),(5.43,.0,-1.9)]]
 me=bpy.data.meshes.new('Ramp'); me.from_pydata(verts,[],[(0,1,3,2),(2,3,5,4),(0,2,4),(1,5,3),(0,4,5,1)]); me.update(); ob=bpy.data.objects.new('Collision_StairRamp',me); bpy.context.collection.objects.link(ob)
 # Short landing bridges final stair height to back-room floor.
 box('LandingBridge',(4.5,3.12,-2.35),(1.85,.2,.9),floor)
 for z in [-1.8,-.6,.6,1.8,3,4.3]: box('RailPost',(3.35,3.72,z),(.055,1.0,.055),metal)
 box('StairwellRail',(3.35,4.22,1.25),(.07,.07,6.25),metal)
 # Roof and parapet; roof supported by perimeter, interiors unobstructed.
 if idx==2:
  # Tejado hundido: agujero de ~2.3x2.3 m con borde carbonizado y escombro abajo.
  for p,s in [((-1.875,6.46,0),(8.65,.24,12.4)),((5.475,6.46,0),(1.45,.24,12.4)),((3.6,6.46,-1.875),(2.3,.24,8.65)),((3.6,6.46,5.475),(2.3,.24,1.45))]: box('Roof',p,s,stone)
  for p,s in [((3.6,6.47,2.42),(2.5,.22,.1)),((3.6,6.47,4.78),(2.5,.22,.1)),((2.42,6.47,3.6),(.1,.22,2.5)),((4.78,6.47,3.6),(.1,.22,2.5))]: box('CharEdge',p,s,char,False)
  for k in range(6): box('Debris',(3.6+rng.uniform(-.8,.8),3.34,3.6+rng.uniform(-.8,.8)),(rng.uniform(.3,.8),rng.uniform(.12,.3),rng.uniform(.3,.7)),rng.choice([stone,char,wood]),False,rot=(0,0,rng.uniform(0,3)))
 else: # A collapsed roof bay over the rear room; staircase and upper floor remain intact.
  for p0,s0 in [((1.9,6.46,0),(8.6,.24,12.4)),((-4.3,6.46,3),(3.8,.24,6.4)),((-4.3,6.46,-5.7),(3.8,.24,1.0))]:
   box('BrokenRoof',p0,s0,stone)
  for k in range(9):
   box('RoofFracture',(-2.4,6.48,-4.7+k*.5),(rng.uniform(.2,.8),.27,.48),stone)

 # Parapets: some are broken into segments with gaps (fachada derruida).
 for x in [-6.05,6.05]:
  if rng.random()<.4:
   half=rng.uniform(3.5,4.5); gap=12.3-2*half
   for s in [-1,1]: box('Parapet',(x,6.8,s*(gap/2+half/2)),(.18,.5,half),plaster)
  else: box('Parapet',(x,6.8,0),(.18,.5,12.3),plaster)
 for z in [-6.05,6.05]:
  if rng.random()<.4:
   half=rng.uniform(3.5,4.5); gap=12.3-2*half
   for s in [-1,1]: box('Parapet',(s*(gap/2+half/2),6.8,z),(half,.5,.18),plaster)
  else: box('Parapet',(0,6.8,z),(12.3,.5,.18),plaster)
 for level in range(2):
  y=.12+level*3.2
  looted = idx>=1 and (level==0 or idx==3)
  if looted:
   # Mesa volcada + patas sueltas; el sitio fue saqueado.
   box('Table',(-2.5,y+.5,1.7),(1.6,.09,.8),wood,True,rot=(math.radians(78),0,math.radians(14)))
   for x,z in [(-3.4,1.2),(-1.7,2.0)]: box('TableLeg',(x,y+.12,z),(.08,.24,.08),wood,False,rot=(0,0,rng.uniform(0,3)))
   box('Mattress',(-3.2,y+.1,-2.6),(1.45,.2,2.2),fabric,True,rot=(0,0,math.radians(24)))
   box('BedFrame',(-4.3,y+.3,-3.8),(1.5,.4,2.3),wood)
   for k in range(rng.randint(6,9)):
    box('Debris',(rng.uniform(-5,2.6),y+rng.uniform(.04,.14),rng.uniform(-5.2,5.2)),(rng.uniform(.15,.55),rng.uniform(.05,.22),rng.uniform(.15,.45)),rng.choice([wood,brick,fabric,stone]),False,rot=(0,0,rng.uniform(0,3)))
  else:
   box('Table',(-3,y+.76,2.7),(1.6,.09,.8),wood)
   for x in [-3.65,-2.35]:
    for z in [2.4,3.0]: box('TableLeg',(x,y+.37,z),(.08,.74,.08),wood)
   box('BedFrame',(-4.3,y+.3,-3.8),(1.5,.4,2.3),wood)
   box('Mattress',(-4.3,y+.59,-3.8),(1.45,.2,2.2),fabric)
   box('Pillow',(-4.3,y+.73,-4.55),(1.05,.12,.45),fabric,False)
  for sy in [.25,.85,1.45,2.05]: box('Shelf',(1.6,y+sy,-5.65),(2,.07,.45),wood)
  for sx in [.6,2.6]: box('ShelfSide',(sx,y+1.12,-5.65),(.08,2.1,.45),wood)
 # Plinth, entrance frame and shallow threshold ramp.
 for x in [-5.95,5.95]: box('CornerStone',(x,3.2,6.18),(.28,6.4,.1),stone,False)
 for x in [-.96,.96]: box('DoorFrame',(x,1.33,6.15),(.1,2.48,.15),char if idx==1 else wood)
 box('DoorFrameTop',(0,2.6,6.15),(2.02,.1,.15),char if idx==1 else wood)
 box('EntranceStep',(0,.05,6.35),(2.2,.1,.7),stone)
 # Broken masonry, rusty pipework and damaged parapet vary each building.
 rust=mat('Rust',(.19,.085,.035))
 for x in [-5.5,5.5]: box('Drainpipe',(x,3.3,6.32),(.09,6.3,.09),rust,False)
 for k in range(32):
  x=random.uniform(-5.7,5.7)
  if abs(x)<1.8: continue # keep entrance free
  z=random.uniform(6.4,7.9)
  ob=box('Rubble',(x,.13,z),(random.uniform(.14,.55),random.uniform(.08,.25),random.uniform(.1,.45)),stone,False)
  ob.rotation_euler.z=random.random()*3
 for k in range(7):
  x=random.uniform(-5.5,5.5)
  box('BrokenParapet',(x,7.02,-6),(random.uniform(.25,.65),random.uniform(.15,.5),.23),plaster,False)
 box('Chimney',(-4,7.3,-4.5),(.85,1.5,.85),plaster,False)
 box('ChimneyCap',(-4,8.08,-4.5),(1,.1,1),stone,False)
 # Rusted, leaning boards on selected windows, while entry remains open.
 for x in [-4.35,3.95]:
  ob=box('BrokenShutter',(x,2.0,6.3),(.18,1.3,.08),wood,False); ob.rotation_euler.y=.16*(idx-1)
 # Two former houses retain pitched slate roofs; the other pair are flat-roof blocks.
 if idx in [0,3]:
  slate=mat('Weathered_slate',(.19,.2,.21));textured(slate,'assets/textures/overgrowth/village_slate_albedo.png','Slate_%d'%idx)
  verts=[];faces=[]
  for side in [-1,1]:
   for ix in range(13):
    for iz in range(6):
     if (ix in [3,4] and iz in [2,3]) or (idx==3 and ix>9 and iz<2):continue
     x=-6.5+ix;z=side*iz;z1=side*(iz+1)
     n=len(verts)
     verts.extend([(x,-z,9.05-abs(z)*.37),(x+1,-z,9.05-abs(z)*.37),(x+1,-z1,9.05-abs(z1)*.37),(x,-z1,9.05-abs(z1)*.37)])
     faces.append((n,n+1,n+2,n+3) if side==-1 else (n+3,n+2,n+1,n))
  me=bpy.data.meshes.new('SlateRoof');me.from_pydata(verts,[],faces);me.update()
  ob=bpy.data.objects.new('Detail_SlateRoof',me);bpy.context.collection.objects.link(ob);me.materials.append(slate)
  uv=me.uv_layers.new()
  for poly in me.polygons:
   for li in poly.loop_indices:
    co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(co.x/2,co.y/2)
  for x in [-6,6]:
   me=bpy.data.meshes.new('Gable');me.from_pydata([(x,6,6.6),(x,-6,6.6),(x,0,9.05)],[],[(0,1,2)]);me.materials.append(plaster)
   ob=bpy.data.objects.new('Detail_Gable',me);bpy.context.collection.objects.link(ob)
 # Join by role: one collision mesh per building instead of hundreds of bodies.
 for prefix in ['Solid_','Detail_']:
  objs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith(prefix)]
  bpy.ops.object.select_all(action='DESELECT')
  for o in objs:o.select_set(True)
  bpy.context.view_layer.objects.active=objs[0]; bpy.ops.object.join(); objs[0].name=prefix+'Building'

 source_dir=ROOT/'outputs/city'; source_dir.mkdir(parents=True,exist_ok=True)
 bpy.ops.wm.save_as_mainfile(filepath=str(source_dir/f'building_{idx+1}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(OUT/f'building_{idx+1}.glb'),export_format='GLB',export_animations=False)
print('CITY_ASSETS_READY')
