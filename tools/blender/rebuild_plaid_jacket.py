"""Build plaid on the fitted field-jacket shell; bake fabric for glTF/Godot."""
from pathlib import Path
import math
import bpy
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/characters/adapted/jackets'
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=str(OUT/'military_jacket_olive.glb'))
arm=next(o for o in bpy.data.objects if o.type=='ARMATURE')
coat=next(o for o in bpy.data.objects if o.type=='MESH' and any(m.type=='ARMATURE' for m in o.modifiers))
arm.data.pose_position='REST'
coat.name='plaid_jacket'
# Bake a woven tartan in rest-space, so pattern remains attached to animated cloth.
image=bpy.data.images.new('Plaid_fabric_baked',width=2048,height=2048,alpha=False)
for mat in coat.data.materials:
    mat.use_nodes=True
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
    for link in list(nt.links):
        if link.to_node==bs: nt.links.remove(link)
    bs.inputs['Roughness'].default_value=.9
    if 'zipper' not in mat.name.lower() and 'button' not in mat.name.lower():
        coord=nt.nodes.new('ShaderNodeTexCoord')
        sep=nt.nodes.new('ShaderNodeSeparateXYZ');nt.links.new(coord.outputs['Generated'],sep.inputs[0])
        stripes=[]
        for axis,freq in [('X',18),('Y',12)]:
            mul=nt.nodes.new('ShaderNodeMath');mul.operation='MULTIPLY';mul.inputs[1].default_value=freq
            nt.links.new(sep.outputs[axis],mul.inputs[0])
            fract=nt.nodes.new('ShaderNodeMath');fract.operation='FRACT';nt.links.new(mul.outputs[0],fract.inputs[0])
            ramp=nt.nodes.new('ShaderNodeValToRGB');cr=ramp.color_ramp;cr.interpolation='CONSTANT'
            colors=[(0,(.39,.29,.15,1)),(.08,(.07,.065,.05,1)),(.11,(.62,.52,.33,1)),(.38,(.16,.022,.016,1)),(.63,(.045,.047,.05,1)),(.73,(.62,.52,.33,1)),(.85,(.16,.022,.016,1)),(.90,(.62,.52,.33,1))]
            cr.elements.remove(cr.elements[1]);cr.elements[0].position=0;cr.elements[0].color=colors[0][1]
            for pos,color in colors[1:]:cr.elements.new(pos).color=color
            nt.links.new(fract.outputs[0],ramp.inputs[0]);stripes.append(ramp)
        mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX';mix.inputs[0].default_value=.5
        for i,ramp in enumerate(stripes):nt.links.new(ramp.outputs[0],mix.inputs[i+1])
        nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;nt.nodes.active=tex
bpy.ops.object.select_all(action='DESELECT');coat.select_set(True);bpy.context.view_layer.objects.active=coat
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=1
scene.render.bake.use_pass_direct=False;scene.render.bake.use_pass_indirect=False;scene.render.bake.use_pass_color=True;scene.render.bake.margin=12
bpy.ops.object.bake(type='DIFFUSE')
image.pack()
for mat in coat.data.materials:
    nt=mat.node_tree;bs=nt.nodes.get('Principled BSDF')
    for link in list(nt.links):
        if link.to_node==bs and link.to_socket==bs.inputs['Base Color']:nt.links.remove(link)
    tex=nt.nodes.new('ShaderNodeTexImage');tex.image=image;nt.links.new(tex.outputs['Color'],bs.inputs['Base Color'])
arm.select_set(True)
bpy.ops.export_scene.gltf(filepath=str(OUT/'military_jacket_plaid.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=True)
world=coat.matrix_world.copy();coat.parent=None;coat.matrix_world=world
for mod in list(coat.modifiers):coat.modifiers.remove(mod)
bpy.ops.object.select_all(action='DESELECT');coat.select_set(True);bpy.context.view_layer.objects.active=coat
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
center=sum((Vector(v) for v in coat.bound_box),Vector())/8
for v in coat.data.vertices:v.co-=center
bpy.ops.export_scene.gltf(filepath=str(OUT/'pickup_jacket_plaid.glb'),export_format='GLB',use_selection=True,export_animations=False,export_skins=False)
print('PLAID_REBUILT')
