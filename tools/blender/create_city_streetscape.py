"""Level-one district street furniture, in metres; +Z Blender becomes Godot +Y."""
import bpy, math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/environment/city'
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def material(name,color,texture=None):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=.91
 if texture:
  im=bpy.data.images.load(str(ROOT/texture));im=im.copy();im.scale(512,512);im.pack();im.name=name
  t=m.node_tree.nodes.new('ShaderNodeTexImage');t.image=im;m.node_tree.links.new(t.outputs['Color'],p.inputs['Base Color'])
 return m
stone=material('City_concrete',(.39,.38,.34),'assets/external/textures/concrete_floor_02/concrete_floor_02_diff_4k.jpg')
wood=material('City_bench_wood',(.22,.16,.1),'assets/textures/overgrowth/village_wood_albedo.png')
iron=material('City_oxidised_iron',(.11,.09,.075))
def box(name,pos,size,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=(pos[0],-pos[2],pos[1]));o=bpy.context.object;o.name=name;o.scale=(size[0],size[2],size[1]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 bevel=o.modifiers.new('Worn_edges','BEVEL');bevel.width=.018;bevel.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
 return o
def save(name):
 bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'outputs/city'/f'{name}.blend'))
 bpy.ops.export_scene.gltf(filepath=str(OUT/f'{name}.glb'),export_format='GLB',export_animations=False)
# Dry ornamental fountain, broken spout; open plaza leaves circulation around it.
for x in [-2.1,2.1]:box('Solid_BasinSide',(x,.30,0),(.22,.6,4.4),stone)
for z in [-2.1,2.1]:box('Solid_BasinEnd',(0,.3,z),(4.0,.6,.22),stone)
box('Solid_BasinFloor',(0,.06,0),(4.1,.12,4.1),stone)
box('Solid_Monument',(0,.9,0),(.9,1.7,.9),stone)
box('Detail_Cap',(0,1.80,0),(1.2,.16,1.2),stone)
for z in [-6,6]:
 for x in [-.85,.85]:box('Solid_BenchLeg',(x,.27,z),(.12,.54,.55),iron)
 for dz in [-.21,-.07,.07,.21]:box('Solid_BenchSeat',(0,.56,z+dz),(2.3,.065,.12),wood)
 for y in [.8,1.03]:box('Solid_BenchBack',(0,y,z+.30),(2.3,.15,.07),wood)
 for x in [-7,7]:
  box('Solid_LampPost',(x,1.8,z),(.1,3.6,.1),iron)
  box('Detail_LampHead',(x,3.63,z),(.48,.12,.48),iron)
  box('Detail_LampGlass',(x,3.46,z),(.3,.24,.3),stone)
save('district_plaza')
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
# Two-metre module: 12 cm raised centre, bevelled approaches on all sides.
verts=[(-1,1,0),(1,1,0),(1,-1,0),(-1,-1,0),(-.65,.8,.12),(.65,.8,.12),(.65,-.8,.12),(-.65,-.8,.12)]
me=bpy.data.meshes.new('Pavement');me.from_pydata(verts,[],[(0,3,7,4),(3,2,6,7),(2,1,5,6),(1,0,4,5),(4,7,6,5)]);me.update();me.materials.append(stone)
o=bpy.data.objects.new('Solid_Pavement',me);bpy.context.collection.objects.link(o)
bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project();bpy.ops.object.mode_set(mode='OBJECT')
save('district_pavement')
print('STREETSCAPE_READY')
