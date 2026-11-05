"""Open Poly Haven pine_sapling_medium_1k.blend, then run this script.
Source + textures in build/tmp/pine_sapling_source; outputs one optimized GLB.
CC0 source: https://polyhaven.com/a/pine_sapling_medium
"""
import bpy, pathlib, numpy as np
root=pathlib.Path(bpy.data.filepath).parent
project=root.parent.parent.parent
out=project/'assets/models/environment/pines/pine_sapling_medium.glb'
out.parent.mkdir(parents=True,exist_ok=True)
obj=bpy.data.objects['pine_sapling_medium_c_LOD2']
for other in list(bpy.data.objects):
 if other!=obj:bpy.data.objects.remove(other,do_unlink=True)
for collection in obj.users_collection: collection.hide_viewport=False;collection.hide_render=False
bpy.context.scene.collection.objects.link(obj) if obj.name not in bpy.context.scene.collection.objects else None
obj.hide_set(False);obj.hide_viewport=False;obj.hide_render=False
obj.location=(0,0,0)
bpy.context.view_layer.objects.active=obj
obj.select_set(True)
obj.name='PineSapling'
# Geometry Nodes stores UVMap as a vector attribute, not an exportable UV layer.
attribute=obj.data.attributes['UVMap']
coords=np.empty(len(attribute.data)*3,dtype=np.float32)
attribute.data.foreach_get('vector',coords)
coords=coords.reshape(-1,3)[:,:2].copy()
for polygon in obj.data.polygons:
 if polygon.material_index==1:
  coords[polygon.loop_start:polygon.loop_start+polygon.loop_total]*=np.array([1.2,.1])
obj.data.attributes.remove(attribute)
uv=obj.data.uv_layers.new(name='UVMap')
uv.data.foreach_set('uv',coords.ravel())

def texture(kind,suffix):
 im=bpy.data.images.load(str(root/'textures'/f'pine_sapling_medium_{kind}_{suffix}_1k.png'),check_existing=True)
 if max(im.size)>1024:im.scale(1024,1024)
 return im
mats={}
for kind in ['bark','twig']:
 mat=bpy.data.materials.new('Pine_'+kind);mat.use_nodes=True
 nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
 outnode=nodes.new('ShaderNodeOutputMaterial');bsdf=nodes.new('ShaderNodeBsdfPrincipled');links.new(bsdf.outputs['BSDF'],outnode.inputs['Surface'])
 bsdf.inputs['Roughness'].default_value=.86
 im=texture(kind,'diff')
 if kind=='twig':
  alpha=texture(kind,'alpha');alpha.colorspace_settings.name='Non-Color'
  pixels=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4);pixels[:,3]=np.array(alpha.pixels[:],dtype=np.float32).reshape(-1,4)[:,0]
  pixels[:,:3]=np.where(pixels[:,:3]<=.0031308,pixels[:,:3]*12.92,1.055*np.power(pixels[:,:3],1.0/2.4)-.055)
  packed=bpy.data.images.new('PineTwigRGBA',width=im.size[0],height=im.size[1],alpha=True)
  packed.pixels.foreach_set(pixels.ravel());packed.filepath_raw=str(root/'twig_rgba.png');packed.file_format='PNG';packed.save();packed.pack();im=packed
  mat.surface_render_method='DITHERED';mat.use_backface_culling=False
 tex=nodes.new('ShaderNodeTexImage');tex.image=im;links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
 if kind=='twig':links.new(tex.outputs['Alpha'],bsdf.inputs['Alpha'])
 nor=nodes.new('ShaderNodeTexImage');nor.image=texture(kind,'nor_gl');nor.image.colorspace_settings.name='Non-Color'
 normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.6;links.new(nor.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
 mats[kind]=mat
for i,mat in enumerate(obj.data.materials):obj.data.materials[i]=mats['twig' if mat and 'twig' in mat.name else 'bark']
mod=obj.modifiers.new('Game reduction','DECIMATE');mod.ratio=.70;mod.use_collapse_triangulate=True
bpy.ops.object.modifier_apply(modifier=mod.name)
obj.data.calc_loop_triangles()
print('OPTIMIZED_PINE triangles=',len(obj.data.loop_triangles),'size=',list(obj.dimensions),flush=True)
bpy.ops.export_scene.gltf(filepath=str(out),export_format='GLB',use_selection=True,export_apply=True,export_animations=False)
print('PINE_OUTPUT',out,flush=True)
