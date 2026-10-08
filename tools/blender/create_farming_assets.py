"""Reproducible Blender farming set, metres/Z-up; export to Godot Y-up.
Run: Blender --background --factory-startup --python tools/blender/create_farming_assets.py
"""
from pathlib import Path
import math, random
import bpy
import numpy as np
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'assets/models/props/farming'
PREVIEW=ROOT/'outputs/farming'
OUT.mkdir(parents=True,exist_ok=True); PREVIEW.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
rng=random.Random(76141)
assets={}
stash=bpy.data.collections.new('Exported assets'); bpy.context.scene.collection.children.link(stash)

def mat(name,col,rough=.85):
    m=bpy.data.materials.new(name);m.diffuse_color=(*col,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Roughness'].default_value=rough
    return m

def image_mat(name,pixels,rough=.85):
    m=mat(name,(1,1,1),rough); im=bpy.data.images.new(name,width=pixels.shape[1],height=pixels.shape[0])
    im.pixels.foreach_set(pixels.astype(np.float32).ravel()); im.pack()
    n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=im
    m.node_tree.links.new(n.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    return m

# Exportable leaf veins and linen weave: actual texture maps, not Blender-only nodes.
n=512; yy,xx=np.mgrid[0:n,0:n]/(n-1); noise=np.random.default_rng(41)
vein=np.exp(-((xx-.5)/.012)**2)
side=np.exp(-(np.sin((yy-abs(xx-.5)*.6)*math.pi*11)/.055)**2)*.25
shade=.76+.16*np.sin(yy*math.pi)+.07*noise.random((n,n))
pix=np.ones((n,n,4));pix[:,:,:3]=shade[:,:,None]*np.array([.19,.37,.075]);pix[:,:,:3]+=(vein*.08+side*.06)[:,:,None]
LEAF=image_mat('Leaf_veins',pix);LEAF.use_backface_culling=False
pix=np.ones((n,n,4));weave=.80+.09*np.sin(xx*math.pi*180)+.055*np.sin(yy*math.pi*180)+.06*noise.random((n,n))
pix[:,:,:3]=weave[:,:,None]*np.array([.54,.40,.24]);CLOTH=image_mat('Linen_weave',pix)
SOIL=mat('Cultivated_earth',(.16,.105,.065))
for suffix,socket in [('Color','Base Color'),('Roughness','Roughness')]:
    path=ROOT/f'assets/textures/dirt_road/Ground038_1K-JPG_{suffix}.jpg'
    im=bpy.data.images.load(str(path))
    if suffix=='Color':
        pixels=np.array(im.pixels[:],dtype=np.float32).reshape(-1,4);pixels[:,:3]*=np.array([.38,.27,.17]);im.pixels.foreach_set(pixels.ravel());im.update()
    im.pack();tex=SOIL.node_tree.nodes.new('ShaderNodeTexImage');tex.image=im
    if suffix=='Roughness': im.colorspace_settings.name='Non-Color'
    SOIL.node_tree.links.new(tex.outputs['Color'],SOIL.node_tree.nodes.get('Principled BSDF').inputs[socket])
# Tint scan through vertex colors is exported by glTF and keeps clods dark.
soil_bsdf=SOIL.node_tree.nodes.get('Principled BSDF')
STEM=mat('Living_stems',(.19,.27,.065));CORD=mat('Twine',(.36,.25,.125));SEED=mat('Ochre_seeds',(.47,.32,.13))
RED=mat('Ripe_fruit',(.58,.055,.021),.42);GREEN=mat('Unripe_fruit',(.30,.39,.065),.55)
STONE=mat('Soil_grit',(.24,.22,.18));PAPER=mat('Seed_label',(.70,.61,.40));INK=mat('Label_ink',(.10,.13,.045))

def mesh(name,vs,fs,material,uv=None):
    me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.update();ob=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(ob);me.materials.append(material)
    layer=me.uv_layers.new()
    for poly in me.polygons:
        poly.use_smooth=True
        for li in poly.loop_indices:
            vi=me.loops[li].vertex_index
            layer.data[li].uv=uv[vi] if uv else (vs[vi][0]*2,vs[vi][1]*2)
    return ob

def ball(name,p,scale,m,sub=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=p);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(m)
    for f in o.data.polygons:f.use_smooth=True
    return o

def tube(name,points,radius,m):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=radius;cu.bevel_resolution=1;cu.resolution_u=1
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for q,p in zip(sp.points,points):q.co=(*p,1)
    ob=bpy.data.objects.new(name,cu);bpy.context.scene.collection.objects.link(ob);cu.materials.append(m)
    bpy.context.view_layer.objects.active=ob;ob.select_set(True);bpy.ops.object.convert(target='MESH');ob.select_set(False)

def leaf(base,yaw,length,width,lift):
    # Thin serrated blade with folded midrib, droop, and UV-aligned veins.
    vs=[];uv=[];fs=[]
    for j in range(13):
        t=j/12;w=width*math.sin(math.pi*t)**.8*(1+.09*(-1)**j)
        for k in [-1,0,1]:
            x=k*w*.5;y=t*length;z=lift*t-.028*t*t-abs(k)*w*.10
            vs.append((base[0]+x*math.cos(yaw)-y*math.sin(yaw),base[1]+x*math.sin(yaw)+y*math.cos(yaw),base[2]+z));uv.append(((k+1)*.5,t))
    for j in range(12):
        for k in range(2):
            a=j*3+k;fs.append((a,a+1,a+4,a+3))
    mesh('Serrated_leaf',vs,fs,LEAF,uv)

def finish(name):
    obs=list(bpy.context.scene.collection.objects)
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
    for c in list(o.users_collection):c.objects.unlink(o)
    stash.objects.link(o);o.hide_render=True;o.hide_set(True);assets[name]=o

for stage,h in enumerate([.085,.20,.34,.46]):
    r=random.Random(10+stage)
    pts=[(math.sin(t*3)*h*.10,math.cos(t*4)*h*.07,h*t) for t in [0,.25,.5,.75,1]]
    tube('Main_stem',pts,.0015+stage*.0007,STEM)
    count=[2,5,8,10][stage]
    for i in range(count):
        t=.30+.65*i/max(1,count-1);yaw=i*2.399+.4
        base=Vector((math.sin(t*3)*h*.10,math.cos(t*4)*h*.07,h*t))
        branch=Vector((-math.sin(yaw),math.cos(yaw),.30))*(.018+stage*.014)
        tip=base+branch;tube('Petiole',[base,tip],.0013,STEM)
        length=(.038+stage*.022)*r.uniform(.8,1.12)
        leaf(tip,yaw,length,length*.50,r.uniform(.005,.025))
        if stage>0:
            for sign in [-1,1]:leaf(base+branch*.55,yaw+sign*.95,length*.70,length*.35,.013)
    if stage>=2:
        for i in range(3 if stage==2 else 5):
            a=i*2.4;z=h*(.36+.095*i);p=Vector((math.cos(a)*.055,math.sin(a)*.055,z));tube('Fruit_stalk',[(0,0,z+.015),p],.0018,STEM)
            rad=.016 if stage==2 else r.uniform(.021,.028)
            ball('Tomato',p,(rad,rad,rad*.9),GREEN if stage==2 or i==0 else RED,2)
            for k in range(5):leaf(p+Vector((0,0,rad*.8)),k*math.tau/5,.015,.004,-.007)
    finish('crop_stage_'+str(stage))

# Continuous surface. Three worked ridges rise out of a ragged soil apron.
def soil_z(x,y):
    edge=max(0,min(1,(.60-max(abs(x),abs(y)))/.10))
    ridge=sum(math.exp(-((x-c)/.095)**2) for c in [-.34,0,.34])
    return -.009+edge*(.032+.060*ridge)+.004*math.sin(x*38+y*17)*edge
vs=[];fs=[];N=49
for j in range(N):
    for i in range(N):
        x=-.60+1.20*i/(N-1);y=-.60+1.20*j/(N-1)
        if i in [0,N-1]:x+=rng.uniform(-.020,.020)
        if j in [0,N-1]:y+=rng.uniform(-.020,.020)
        vs.append((x,y,soil_z(x,y)))
for j in range(N-1):
    for i in range(N-1):a=j*N+i;fs.append((a,a+1,a+N+1,a+N))
mesh('Worked_soil',vs,fs,SOIL)
for i in range(110):
    x,y=rng.uniform(-.55,.55),rng.uniform(-.55,.55);rad=rng.uniform(.005,.018)
    ball('Earth_clod',(x,y,soil_z(x,y)+rad*.3),(rad,rad*rng.uniform(.6,1.4),rad*.6),SOIL if i%9 else STONE)
for i in range(14):
    x,y=rng.uniform(-.5,.5),rng.uniform(-.5,.5);z=soil_z(x,y)+.003
    tube('Old_root',[(x,y,z),(x+.035,y+.01,z+.001),(x+.06,y+.005,z)],.0007,CORD)
finish('farm_plot')
ball('Loose_earth',(0,0,.02),(.22,.21,.035),SOIL,3);finish('crop_soil_mound')

# Soft open linen packet: irregular cross sections, gathered neck and visible seeds.
vs=[];fs=[];uv=[];rings=[(0,.052),(.012,.066),(.055,.064),(.095,.058),(.118,.037),(.137,.032),(.150,.040)]
for j,(z,r) in enumerate(rings):
    for i in range(48):
        a=i*math.tau/48;rr=r*(1+.045*math.sin(a*7+j*.6)+.027*math.cos(a*11))
        vs.append((rr*math.cos(a),rr*.62*math.sin(a),z));uv.append((i/47,j/6))
for j in range(6):
    for i in range(48):a=j*48+i;b=j*48+(i+1)%48;fs.append((a,b,b+48,a+48))
sack=mesh('Gathered_linen',vs,fs,CLOTH,uv)
solid=sack.modifiers.new('Cloth thickness','SOLIDIFY');solid.thickness=.0012
bpy.context.view_layer.objects.active=sack;bpy.ops.object.modifier_apply(modifier=solid.name)
for sign in [-1,1]:
    tube('Stitched_seam',[(sign*r*1.01,0,z) for z,r in rings],.0008,CORD)
for z in [.124,.127]:tube('Drawstring',[(.035*math.cos(i*math.tau/48),.023*math.sin(i*math.tau/48),z) for i in range(49)],.0012,CORD)
tube('Tie_ends',[(.032,0,.127),(.052,-.018,.113),(.05,-.03,.087)],.0013,CORD)
ball('Seed_fill',(0,0,.136),(.030,.019,.003),SEED,2)
for i in range(60):
    a=rng.random()*math.tau;r=.028*math.sqrt(rng.random());p=(r*math.cos(a),r*.62*math.sin(a),.141+rng.uniform(-.002,.002))
    o=ball('Seed',p,(.0021,.0036,.0013),SEED,1);o.rotation_euler.z=rng.random()*math.tau
for i in range(14):
    p=(rng.uniform(-.075,.075),rng.uniform(-.070,-.048),.002)
    o=ball('Spilled_seed',p,(.0022,.0038,.0015),SEED,1);o.rotation_euler.z=rng.random()*math.tau
# Sewn label facing the front; text is geometry and survives export.
mesh('Label',[(-.037,-.047,.048),(.037,-.047,.048),(.037,-.047,.091),(-.037,-.047,.091)],[(0,1,2,3)],PAPER,[(0,0),(1,0),(1,1),(0,1)])
for text,z,size in [('SEMILLAS',.075,.010),('HUERTO',.060,.008)]:
    cu=bpy.data.curves.new('Label_text','FONT');cu.body=text;cu.size=size;cu.align_x='CENTER';cu.extrude=.0001
    o=bpy.data.objects.new('Label_text',cu);bpy.context.scene.collection.objects.link(o);o.location=(0,-.048,z);o.rotation_euler=(math.pi/2,0,0);cu.materials.append(INK)
    bpy.context.view_layer.objects.active=o;o.select_set(True);bpy.ops.object.convert(target='MESH');o.select_set(False)
finish('farm_seed_pouch')
for i in range(11):ball('Berry',(rng.uniform(-.035,.035),rng.uniform(-.025,.025),.012),(.012,.011,.010),RED,2)
leaf((0,0,.02),1.5,.065,.025,.006);finish('farm_berries')

# Editable gallery and two rendered detail previews.
scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=1400;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new("Farm_preview_world");scene.world.color=(.20,.20,.20)
for name in ['farm_plot','farm_seed_pouch']:
    o=assets[name];o.hide_render=False;o.hide_set(False)
assets['farm_seed_pouch'].location=(.80,-.48,0)
for x in [-.34,0,.34]:
    for y in [-.30,0,.30]:
        o=assets['crop_stage_3'].copy();o.data=assets['crop_stage_3'].data;stash.objects.link(o);o.hide_render=False;o.hide_set(False);o.location=(x,y,.073);o.rotation_euler.z=rng.random()*math.tau;o.scale=(rng.uniform(.87,1.05),)*3
for i in range(4):
    o=assets['crop_stage_'+str(i)];o.hide_render=False;o.hide_set(False);o.location=(-.65+i*.40,.95,0)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.025));bpy.context.object.data.materials.append(mat('Preview_ground',(.095,.12,.065)))
bpy.ops.object.light_add(type='AREA',location=(1,-2,4));bpy.context.object.data.energy=400;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=4
bpy.ops.object.camera_add(location=(1.9,-2.6,2.1));cam=bpy.context.object;scene.camera=cam;cam.rotation_euler=(Vector((0,.2,.15))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=2.8
bpy.ops.wm.save_as_mainfile(filepath=str(PREVIEW/'cultivo.blend'))
scene.render.filepath=str(PREVIEW/'cultivo.png');bpy.ops.render.render(write_still=True)
cam.location=(1.02,-.84,.28);cam.rotation_euler=(Vector((.80,-.48,.075))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.26
scene.render.filepath=str(PREVIEW/'semillas.png');bpy.ops.render.render(write_still=True)
print('FARMING_ASSETS_DONE')
