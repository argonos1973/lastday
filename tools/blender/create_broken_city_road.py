"""Broken asphalt and sidewalks with real missing surface, exported in metres."""
import bpy, math, random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
rng=random.Random(491)
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
def material(name,color,texture=None):
 m=bpy.data.materials.new(name);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.96
 if texture:
  im=bpy.data.images.load(str(ROOT/texture));im.scale(1024,1024);im.pack()
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im
  mix=m.node_tree.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*color,1)
  m.node_tree.links.new(t.outputs['Color'],mix.inputs[1]);m.node_tree.links.new(mix.outputs[0],p.inputs['Base Color'])
 return m
# Tint baked into pixels: glTF does not export arbitrary Blender node graphs.
def textured(name,tint):
 m=material(name,tint)
 im=bpy.data.images.load(str(ROOT/'assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg')).copy();im.scale(512,512)
 px=list(im.pixels)
 for i in range(0,len(px),4):
  for c in range(3):px[i+c]*=tint[c]
 im.pixels[:]=px;im.name=name;im.pack()
 t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im
 m.node_tree.links.new(t.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
 return m
asphalt=textured('Fractured_asphalt',(.27,.29,.29));gravel=textured('Exposed_aggregate',(.55,.43,.30));concrete=textured('Broken_concrete',(.62,.60,.54))
def mesh(name,verts,faces,mat):
 me=bpy.data.meshes.new(name);me.from_pydata([(x,-z,y) for x,y,z in verts],[],faces);me.update()
 ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);me.materials.append(mat)
 uv=me.uv_layers.new()
 for poly in me.polygons:
  for li in poly.loop_indices:
   v=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(v.x/2.5,v.y/2.5)
 return ob
holes=[]
for axis in [0,1]:
 for j in range(19):
  a=rng.uniform(-38,38);b=rng.uniform(-4.6,4.6)
  holes.append((a if axis==0 else b,b if axis==0 else a,rng.uniform(.65,2.0)))
def road(x,z):return (abs(x)<40 and abs(z)<6) or (abs(z)<40 and abs(x)<6)
def pavement(x,z):return (abs(x)<32 and 6<abs(z)<10) or (abs(z)<32 and 6<abs(x)<10)
for name,mat in [('Asphalt',asphalt),('Sidewalk',concrete),('Aggregate',gravel)]:
 verts=[];faces=[];step=.65
 for ix in range(-62,62):
  for iz in range(-62,62):
   x=(ix+.5)*step;z=(iz+.5)*step
   isroad=road(x,z);ispave=pavement(x,z) and not isroad
   if not (isroad if name=='Asphalt' else ispave if name=='Sidewalk' else isroad or ispave):continue
   near=min(math.hypot(x-hx,z-hz)-r for hx,hz,r in holes)
   # Broad holes expose a lower gravel bed. Ragged cracks branch across the street.
   crack=abs(math.sin(x*.61+math.sin(z*.8))*1.3+math.sin(z*.93))<.085
   if name=='Asphalt' and (near<rng.uniform(-.22,.12) or crack):continue
   if name=='Sidewalk' and (rng.random()<.13 or (near<.2 and rng.random()<.7)):continue
   y=.008 if name=='Aggregate' else .105 if name=='Asphalt' else .15
   corners=[]
   for dx,dz in [(-.5,-.5),(.5,-.5),(.5,.5),(-.5,.5)]:
    # Shared deterministic lattice prevents overlapping patches; offset makes jagged edges.
    gx=(ix+(1 if dx>0 else 0));gz=(iz+(1 if dz>0 else 0))
    jx=math.sin(gx*37.1+gz*11.8)*.15;jz=math.cos(gx*13.4+gz*29.2)*.15
    h=0 if name=='Aggregate' else .025*math.sin(gx*2+gz*3)
    corners.append((x+dx*step+jx,y+h,z+dz*step+jz))
   n=len(verts);verts+=corners;faces.extend([(n,n+2,n+1),(n,n+3,n+2)])
 mesh('Solid_'+name,verts,faces,mat)
# Loose angular asphalt chunks around the potholes, below ankle height.
verts=[];faces=[]
for hx,hz,r in holes:
 for k in range(9):
  a=rng.random()*math.tau;x=hx+math.cos(a)*r;z=hz+math.sin(a)*r
  if not road(x,z):continue
  size=rng.uniform(.1,.35);n=len(verts)
  verts.extend([(x-size,.015,z-size),(x+size,.015,z-size*.6),(x+size*.5,.015,z+size),(x,.13+rng.random()*.07,z)])
  faces.extend([(n,n+1,n+3),(n+1,n+2,n+3),(n+2,n,n+3)])
mesh('Detail_AsphaltRubble',verts,faces,asphalt)
out=ROOT/'assets/models/environment/city';src=ROOT/'outputs/city'
bpy.ops.wm.save_as_mainfile(filepath=str(src/'broken_road.blend'))
bpy.ops.export_scene.gltf(filepath=str(out/'broken_road.glb'),export_format='GLB',export_animations=False)
print('BROKEN_ROAD_READY',len(holes),'pothole regions')
