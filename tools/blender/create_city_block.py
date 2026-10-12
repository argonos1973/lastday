"""Four enterable pilot buildings. Coordinates below are Godot metres (Y up).
FH = floor-to-floor height; TH = total wall height above the foundation."""
import bpy, bmesh, math, random
random.seed(812)
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/environment/city'
OUT.mkdir(parents=True,exist_ok=True)
FH=3.9; TH=FH*2

def mat(name,color):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.85
 return m

def textured(m, relative, name, tint=None):
 im=bpy.data.images.load(str(ROOT/relative),check_existing=True)
 im=im.copy(); im.name=name; im.scale(1024,1024); im.pack()
 tex=m.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=im
 bsdf=m.node_tree.nodes.get('Principled BSDF')
 if tint is None:
  m.node_tree.links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
 else:
  # Grey source textures get their own hue per material (furniture, floor,
  # stairs) instead of every wooden surface sharing one flat grey.
  mix=m.node_tree.nodes.new('ShaderNodeMix'); mix.data_type='RGBA'; mix.blend_type='MULTIPLY'
  mix.inputs['Factor'].default_value=1.0; mix.inputs[7].default_value=(*tint,1)
  m.node_tree.links.new(tex.outputs['Color'],mix.inputs[6])
  m.node_tree.links.new(mix.outputs[2],bsdf.inputs['Base Color'])
 return m

UV_METRES={'GroundFloor':2.4,'UpperFloorMain':2.4,'UpperLanding':2.4,'UpperFrontFloor':2.4,'LandingBridge':2.4,'Wallpaper':3.2,'Ceiling':3.0}
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
   uvm=UV_METRES.get(name,2.8)
   o.data.uv_layers.active.data[loop].uv=(co[axes[0]]/uvm,co[axes[1]]/uvm)
 return o

def wedge(name,x0,x1,yl,zl,yh,zh,yb):
 # Closed stair wedge: slope from (zl,yl) up to (zh,yh), base at yb under the
 # high end. Normals recomputed so either climbing direction collides.
 pts=[(x0,yl,zl),(x1,yl,zl),(x0,yh,zh),(x1,yh,zh),(x0,yb,zh),(x1,yb,zh)]
 me=bpy.data.meshes.new(name);me.from_pydata([(x,-z,y) for x,y,z in pts],[],[(0,1,3,2),(2,3,5,4),(0,2,4),(1,5,3),(0,4,5,1)])
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(me);bm.free();me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);return ob

def cbox(name,p,s):
 # Collision-only box: stays outside the Solid_/Detail_ visual joins, gets
 # trimesh collision + hidden by CityBlock._collisions.
 bpy.ops.mesh.primitive_cube_add(size=1,location=(p[0],-p[2],p[1]));o=bpy.context.object;o.name='Collision_'+name;o.scale=(s[0],s[2],s[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 return o

def wall(z,front,fmat=None):
 # Real openings: no invisible full-wall collider behind windows/entrance.
 fmat=fmat or wood
 face=z+(.16 if z>0 else -.16)
 openings=[(-4.25,-2.75,.95,2.55),(2.75,4.25,.95,2.55)]
 if front: openings.append((-.9,.9,.12,2.95))
 for level in range(2):
  holes=sorted(openings if level==0 else [(-4.25,-2.75,.95,2.55),(2.75,4.25,.95,2.55)])
  at=-6
  for a,b,lo,hi in holes:
   if a>at: box('Pier',( (at+a)/2,level*FH+FH/2,z),(a-at,FH,.28),plaster)
   if lo>0: box('SillWall',((a+b)/2,level*FH+lo/2,z),(b-a,lo,.28),plaster)
   box('Lintel',((a+b)/2,level*FH+(hi+FH)/2,z),(b-a,FH-hi,.28),plaster)
   if lo> .5:
    box('WindowSill',((a+b)/2,level*FH+lo,z),(b-a+.18,.09,.48),stone)
    for x in [a,b]: box('WindowFrame',(x,level*FH+(lo+hi)/2,z),(.065,hi-lo,.1),fmat)
    for y in [lo,hi]: box('WindowFrame',((a+b)/2,level*FH+y,z),(b-a,.06,.1),fmat)
    cy=level*FH+(lo+hi)/2
    if rng.random()>.35: box('WindowMullion',((a+b)/2,cy,z),(.05,hi-lo,.08),fmat)
    # Decay: rain streaks below sills, boards across some openings, glass shards.
    if rng.random()<.4:
     for sx in rng.sample([a+.11,b-.11],rng.choice([1,2])):
      box('Shard',(sx,level*FH+lo+.09,z),(.09,.19,.05),glass,False)
    if rng.random()<.38:
     for pb in range(rng.choice([2,3])):
      box('Board',((a+b)/2+rng.uniform(-.2,.2),level*FH+lo+.28+pb*.6+rng.uniform(-.05,.05),face),(b-a+.6+rng.uniform(-.2,.4),.23,.08),wood,False,rot=(0,rng.uniform(-.06,.06),0))
   at=b
  if at<6: box('Pier',((at+6)/2,level*FH+FH/2,z),(6-at,FH,.28),plaster)

for idx,color in enumerate([(.56,.49,.37),(.39,.45,.42),(.57,.38,.29),(.50,.53,.55)]):
 bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
 rng=random.Random(idx*31+7)
 plaster=mat('Weathered_plaster',color); stone=mat('Foundation',(.23,.24,.23)); wood=mat('Dark_wood',(.17,.105,.065)); floor=mat('Floor_boards',(.30,.23,.16)); metal=mat('Iron',(.075,.085,.08)); fabric=mat('Faded_fabric',(.22,.28,.22))
 grime=mat('Grime',(.10,.115,.09)); soot=mat('Soot',(.045,.05,.045)); moss=mat('Moss',(.06,.13,.05)); brick=mat('Bare_brick',(.33,.18,.13)); glass=mat('Glass_shard',(.5,.68,.72)); char=mat('Charred_wood',(.05,.045,.04))
 textured(plaster,'assets/textures/city_interior/facade_lime_%d.png'%(idx//2) if idx%2==0 else 'assets/external/textures/red_brick_03/red_brick_03_diff_4k.jpg','Ruined_facade_%d'%idx)
 textured(stone,'assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg','Old_concrete_%d'%idx)
 textured(wood,'assets/textures/overgrowth/village_wood_albedo.png','Old_wood_%d'%idx,tint=(.62,.36,.20))
 box('GroundFloor',(0,.02,0),(12,.2,12),floor)
 wall(6,True,char if idx==1 else None); wall(-6,False)
 for x in [-6,6]:
  box('SideWallBase',(x,2.4,0),(.28,4.8,12),plaster)
  for za,zb in [(-6,-2),(1.3,6)]: box('BrokenSideUpper',(x,6.3,(za+zb)/2),(.28,3.0,zb-za),plaster)
  for k in range(8):
   z=-2+k*.45;h=rng.uniform(.08,.65)
   box('JaggedWallEdge',(x,4.8+h/2,z),(.31,h,.45),plaster)

 # Continuous floor cornice, recessed dark window surrounds and brick piers.
 for z in [-6.19,6.19]:
  box('StringCourse',(0,3.89,z),(12.18,.12,.19),stone,False)
  for x in [-5.86,5.86]: box('CornerPilaster',(x,3.9,z),(.24,7.8,.15),stone,False)
 for x in [-6.19,6.19]: box('SideCornice',(x,3.89,0),(.19,.12,12),stone,False)
 # Upper floor leaves an open 2.4 x 7.4 m stairwell on the right.
 box('UpperFloorMain',(-1.45,FH-.08,0),(9.1,.2,12),floor)
 box('UpperLanding',(4.55,FH-.08,-4.4),(2.9,.2,3.2),floor)
 box('UpperFrontFloor',(4.55,FH-.08,5.25),(2.9,.2,1.5),floor)
 for level in range(2):
  # Two usable rooms on the left, door gap 1.4 m wide.
  for a,b in [(-6,-3.5),(-2.1,2.9)]: box('RoomPartition',((a+b)/2,level*FH+1.9,-1),(b-a,3.7,.16),plaster)
  box('RoomDoorLintel',(-2.8,level*FH+3.12,-1),(1.4,1.25,.16),plaster)
 # Stair treads and a smooth, matching collision wedge for CharacterBody3D.
 # Flat-roof houses switch back: the first flight takes the east lane of the
 # stairwell and the roof flight returns along the west lane behind a spine.
 flat=idx in [1,2]
 n=20
 sx0,sx1=(4.58,5.84) if flat else (3.57,5.43)
 for k in range(n):
  h=(k+1)*3.8/n
  box('Step',((sx0+sx1)/2,.12+h/2,4.5-(k+.5)*6.4/n),(sx1-sx0,h,6.4/n),wood,False)
 wedge('Collision_StairRamp',sx0,sx1,.12,4.5,FH+.02,-1.9,.0)
 # Short landing bridges final stair height to back-room floor.
 if flat:
  box('LandingBridge',(4.48,FH-.08,-2.35),(2.76,.2,.9),floor)
  box('UpperStairBase',(3.81,FH-.08,1.3),(1.42,.2,6.4),floor)
 else:
  box('LandingBridge',(4.5,FH-.08,-2.35),(1.85,.2,.9),floor)
  for z in [-1.8,-.6,.6,1.8,3,4.3]: box('RailPost',(3.35,FH+.52,z),(.055,1.0,.055),metal)
  box('StairwellRail',(3.35,FH+1.02,1.25),(.07,.07,6.25),metal)
 roof_top=TH+.18
 if flat:
  # Roof flight: from the back landing (where the first flight arrives) back
  # towards the front, on the west lane, out through an opening in the slab.
  rise=roof_top-(FH+.02)
  for k in range(n):
   h=(k+1)*rise/n
   box('RoofStep',(3.85,FH+.02+h/2,-1.9+(k+.5)*6.4/n),(1.26,h,6.4/n),wood,False)
  wedge('Collision_StairRampRoof',3.22,4.48,FH+.02,-1.9,roof_top,4.5,FH-.02)
  # West guard of the roof flight (also the rail on that side of the opening).
  cbox('RoofStairGuard',(3.16,(FH+roof_top+1.1)/2,1.3),(.06,roof_top+1.1-FH,6.4))
  for k in range(9):
   t=(k+.5)/9;box('RoofStairPost',(3.17,FH+.02+t*rise+.5,-1.9+t*6.4),(.05,1.0,.05),metal,False)
  slope=math.atan2(rise,6.4)
  box('RoofStairHandrail',(3.17,FH+.02+rise/2+1.0,1.3),(.06,.06,math.hypot(6.4,rise)),metal,False,rot=(-slope,0,0))
  box('RoofMain',(-1.45,roof_top-.1,0),(9.1,.2,12),stone)
  box('RoofBackLanding',(4.55,roof_top-.1,-4.4),(2.9,.2,3.2),stone)
  box('RoofBackBridge',(4.48,roof_top-.1,-2.35),(2.76,.2,.9),stone)
  box('RoofOverFirstFlight',(5.26,roof_top-.1,1.3),(1.48,.2,6.4),stone)
  box('RoofFrontLanding',(4.55,roof_top-.1,5.25),(2.9,.2,1.5),stone)
  # Stop across the low end of the opening.
  cbox('RoofOpeningStop',(3.83,roof_top+.55,-1.93),(1.36,1.1,.06))
  box('RoofOpeningRail',(3.83,roof_top+1.0,-1.93),(1.36,.06,.06),metal,False)
  for x in [3.25,3.83,4.41]:box('RoofOpeningPost',(x,roof_top+.5,-1.93),(.05,1.0,.05),metal,False)
 else:
  # Pitched slate roofs have no roof access: a closed ceiling slab under the attic.
  box('RoofMain',(0,roof_top-.1,0),(12.2,.2,12),stone)

 # Parapets: some are broken into segments with gaps (fachada derruida).
 for x in [-6.05,6.05]:
  if rng.random()<.4:
   half=rng.uniform(3.5,4.5); gap=12.3-2*half
   for s in [-1,1]: box('Parapet',(x,TH+.4,s*(gap/2+half/2)),(.18,.5,half),plaster)
  else: box('Parapet',(x,TH+.4,0),(.18,.5,12.3),plaster)
 for z in [-6.05,6.05]:
  if rng.random()<.4:
   half=rng.uniform(3.5,4.5); gap=12.3-2*half
   for s in [-1,1]: box('Parapet',(s*(gap/2+half/2),TH+.4,z),(half,.5,.18),plaster)
  else: box('Parapet',(0,TH+.4,z),(12.3,.5,.18),plaster)
 # Interior shell only: furniture/clutter are real models placed by CityBlock.gd
 # (interior kit). Ruined wallpaper, dirty boards and a stained ceiling are
 # textures baked by tools/blender/create_city_interior_kit.py.
 TEXI='assets/textures/city_interior/'
 textured(floor,TEXI+'floor_ruin.png','Floor_ruin_%d'%idx)
 ceiling=textured(mat('Ceiling_%d'%idx,(.62,.60,.54)),TEXI+'ceiling_ruin.png','Ceiling_ruin_%d'%idx)
 for level in range(2):
  y=.12+level*FH
  paper=textured(mat('Wallpaper_%d_%d'%(idx,level),(.5,.5,.5)),TEXI+'wallpaper_ruin_%d.png'%((idx+level*2)%4),'Paper_%d_%d'%(idx,level))
  if level==0: paper0=paper
  # Partitions are papered on both faces (bare facade plaster inside looked
  # like the outside wall).
  for a,b in [(-6,-3.5),(-2.1,2.9)]:
   for pz in [-1.09,-.91]:
    cx=(a+b)/2+(.14 if a<-5 else 0); w=b-a-(.28 if a<-5 else 0)
    box('Wallpaper',(cx,y+1.9,pz),(w,3.6,.02),paper,False)
  # Side walls: solid to y~4.8; above that the jagged breach must stay open.
  for s in [-1,1]:
   box('Wallpaper',(s*5.83,y+(1.9 if level==0 else .4),0),(.05,3.6 if level==0 else .68,11.5),paper,False)
   box('Baseboard',(s*5.80,y+.10,0),(.04,.14,11.5),wood,False)
  # Front/back walls keep the real openings: wallpaper only in the solid bands.
  for sz in [5.82,-5.82]:
   front_door = sz > 0 and level == 0
   low = [(-5.75,-.95),(.95,5.75)] if front_door else [(-5.75,5.75)]
   mid = [(-5.75,-4.3),(-2.7,-.95),(.95,2.7),(4.3,5.75)] if front_door else [(-5.75,-4.3),(-2.7,2.7),(4.3,5.75)]
   for a,b in low: box('Wallpaper',((a+b)/2,y+.5,sz),(b-a,.9,.05),paper,False)
   for a,b in mid: box('Wallpaper',((a+b)/2,y+1.75,sz),(b-a,1.6,.05),paper,False)
   box('Wallpaper',(0,y+3.5,sz),(11.5,.7,.05),paper,False)
   for a,b in low: box('Baseboard',((a+b)/2,y+.10,sz),(b-a,.14,.04),wood,False)
  if level==0:
   # Stained ceiling under the upper floor; the stairwell stays open.
   box('Ceiling',(-1.45,FH-.19,0),(9.1,.02,11.9),ceiling,False)
  # Rusty radiators under the front windows, hanging bare bulb cords.
  for wx in [-3.5,3.5]:
   for k in range(5): box('Radiator',(wx-.4+k*.2,y+.45,5.62),(.08,.75,.12),metal,False)
  for lx in [-3.4,.4]: box('LampCord',(lx,y+3.42,1.2),(.02,.5,.02),char,False)
  # Fully open door leaf beside the partition gap. Blender Z is up: yaw about Z.
  # Hinge on the west jamb (x=-3.45), leaf swung 90 deg into the front room.
  ang=math.radians(90)
  box('RoomDoor',(-3.45+.55*math.cos(ang),y+1.15,-1.0+.55*math.sin(ang)),(1.1,2.1,.05),wood,True,rot=(0,0,-ang))
 # Paper the stair side facing the room so it reads as a finished wall, not a
 # stretched wood panel.
 if flat:
  # Spine between the two lanes: ground floor up to a 1 m parapet on the roof.
  box('StairSpine',(4.52,(roof_top+1.0)/2,1.3),(.08,roof_top+1.0,6.4),paper0)
 else:
  for k in range(n):
   h=(k+1)*3.8/n
   box('StairSide',(3.556,.12+h/2,4.5-(k+.5)*6.4/n),(.02,h,6.4/n),paper0,False)
 # Frames align with the current floor height; the 1.4 m opening stays clear.
 for level in range(2):
  y=.12+level*FH
  for x in [-3.54,-2.06]: box('InteriorDoorTrim',(x,y+1.2,-.89),(.075,2.4,.06),wood,False)
 # Plinth, entrance frame and shallow threshold ramp.
 for x in [-5.95,5.95]: box('CornerStone',(x,3.9,6.18),(.28,7.8,.1),stone,False)
 for x in [-.96,.96]: box('DoorFrame',(x,1.57,6.15),(.1,2.9,.15),char if idx==1 else wood)
 box('DoorFrameTop',(0,3.0,6.15),(2.02,.1,.15),char if idx==1 else wood)
 # A continuous threshold wedge, instead of a vertical 10 cm step.
 verts=[(-1.1,-6.85,0),(1.1,-6.85,0),(-1.1,-5.9,.12),(1.1,-5.9,.12)]
 me=bpy.data.meshes.new('Threshold');me.from_pydata(verts,[],[(0,1,3,2)]);me.materials.append(stone)
 ob=bpy.data.objects.new('Solid_EntranceRamp',me);bpy.context.collection.objects.link(ob)
 # Broken masonry, rusty pipework and damaged parapet vary each building.
 rust=mat('Rust',(.19,.085,.035))
 for x in [-5.5,5.5]: box('Drainpipe',(x,3.95,6.32),(.09,7.8,.09),rust,False)
 # Facade overgrowth (moss decals, ivy sheets) is dressed in Godot by
 # CityBlock._dress_facade using the village textures — not baked here.
 for k in range(7):
  x=random.uniform(-5.5,5.5)
  box('BrokenParapet',(x,TH+.62,-6),(random.uniform(.25,.65),random.uniform(.15,.5),.23),plaster,False)
 box('Chimney',(-4,TH+.9,-4.5),(.85,1.5,.85),plaster,False)
 box('ChimneyCap',(-4,TH+1.68,-4.5),(1,.1,1),stone,False)
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
     verts.extend([(x,-z,10.45-abs(z)*.37),(x+1,-z,10.45-abs(z)*.37),(x+1,-z1,10.45-abs(z1)*.37),(x,-z1,10.45-abs(z1)*.37)])
     faces.append((n,n+1,n+2,n+3) if side==-1 else (n+3,n+2,n+1,n))
  me=bpy.data.meshes.new('SlateRoof');me.from_pydata(verts,[],faces);me.update()
  ob=bpy.data.objects.new('Detail_SlateRoof',me);bpy.context.collection.objects.link(ob);me.materials.append(slate)
  uv=me.uv_layers.new()
  for poly in me.polygons:
   for li in poly.loop_indices:
    co=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(co.x/2,co.y/2)
  for x in [-6,6]:
   me=bpy.data.meshes.new('Gable');me.from_pydata([(x,6,8.0),(x,-6,8.0),(x,0,10.45)],[],[(0,1,2)]);me.materials.append(plaster)
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
