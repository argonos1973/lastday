"""Build a metric, textured infantry helmet with a hollow shell and four-point harness."""
import bpy, math, os
from mathutils import Vector
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../..'))
OUT = os.path.join(ROOT, 'outputs')
os.makedirs(OUT, exist_ok=True)
GLB = os.path.join(ROOT, 'assets/models/equipment/military_helmet.glb')
for ob in list(bpy.data.objects):
    bpy.data.objects.remove(ob, do_unlink=True)
scene = bpy.context.scene
scene.unit_settings.system = 'METRIC'
scene.unit_settings.scale_length = 1.0
parts=[]

def material(name, color, roughness=.8, metal=0):
    m=bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=roughness
    p.inputs['Metallic'].default_value=metal
    m.diffuse_color=(*color,1)
    return m

cover=material('Woodland ripstop cover',(.18,.22,.12),.89)
t=cover.node_tree.nodes.new('ShaderNodeTexImage')
t.image=bpy.data.images.load(os.path.join(ROOT,'assets/textures/clothing/camouflage_woodland.png'))
# Embed a 1k copy — the source map is 2k and the GLB ships its own image.
t.image.scale(1024, 1024)
cover.node_tree.links.new(t.outputs['Color'],cover.node_tree.nodes['Principled BSDF'].inputs['Base Color'])
normal=cover.node_tree.nodes.new('ShaderNodeTexImage')
normal.image=bpy.data.images.load(os.path.join(ROOT,'assets/textures/clothing/cloth_denim_normal.png'))
normal.image.scale(512, 512)
normal.image.colorspace_settings.name='Non-Color'
normalmap=cover.node_tree.nodes.new('ShaderNodeNormalMap');normalmap.inputs['Strength'].default_value=.20
cover.node_tree.links.new(normal.outputs['Color'],normalmap.inputs['Color'])
cover.node_tree.links.new(normalmap.outputs['Normal'],cover.node_tree.nodes['Principled BSDF'].inputs['Normal'])
inner=material('Interior olive composite',(.075,.088,.052),.92)
trim=material('Rubber edge binding',(.033,.043,.027),.78)
webbing=material('Olive woven webbing',(.10,.13,.065),.94)
thread=material('Cover stitched seams',(.065,.085,.04),.95)
metal=material('Blackened steel hardware',(.045,.051,.038),.4,.65)
polymer=material('Olive mounting hardware',(.12,.14,.073),.72)
padmat=material('Interior comfort foam',(.038,.043,.035),.99)

# Front points towards Blender -Y. Rim dips over ears and nape, with a raised brow.
N,RINGS=96,24
RX,RY,RZ,CZ=.132,.151,.126,.009

def rim_height(a):
    front=max(0,-math.sin(a))
    side=abs(math.cos(a))
    return -.033 + .047*front**4 - .009*side**6

def cap(a, u, offset=0):
    theta=math.acos((rim_height(a)-CZ)/RZ)*u
    p=Vector((RX*math.sin(theta)*math.cos(a),RY*math.sin(theta)*math.sin(a),CZ+RZ*math.cos(theta)))
    n=Vector((p.x/(RX*RX),p.y/(RY*RY),(p.z-CZ)/(RZ*RZ))).normalized()
    return p+n*offset

vertices=[(0,0,CZ+RZ)]
for j in range(1,RINGS+1):
    for i in range(N):vertices.append(tuple(cap(2*math.pi*i/N,j/RINGS)))
faces=[]
for i in range(N):faces.append((0,1+i,1+(i+1)%N))
for j in range(RINGS-1):
    for i in range(N):
        a=1+j*N+i;b=1+j*N+(i+1)%N
        faces.append((a,a+N,b+N,b))
mesh=bpy.data.meshes.new('Helmet shell topology');mesh.from_pydata(vertices,[],faces);mesh.update()
ob=bpy.data.objects.new('Helmet_Shell',mesh);scene.collection.objects.link(ob);parts.append(ob)
ob.data.materials.append(cover);ob.data.materials.append(inner)
uv=mesh.uv_layers.new(name='UVMap')
# Spherical panel UVs keep patch proportions consistent down the sides.
for poly in mesh.polygons:
    poly.use_smooth=True
    indices=[mesh.loops[li].vertex_index for li in poly.loop_indices]
    us=[((idx-1)%N)/N if idx else 0.0 for idx in indices]
    nonpole=[u for idx,u in zip(indices,us) if idx]
    if max(nonpole)-min(nonpole)>.5:
        us=[u+1 if u<.5 else u for u in us]
    if 0 in indices:
        us[indices.index(0)]=sum(u for idx,u in zip(indices,us) if idx)/2
    for li,idx,u in zip(poly.loop_indices,indices,us):
        ring=((idx-1)//N+1) if idx else 0
        uv.data[li].uv=(u,1-ring/RINGS*.38)
solid=ob.modifiers.new('6 mm composite shell','SOLIDIFY');solid.thickness=.006;solid.offset=-1;solid.material_offset=1;solid.use_even_offset=True
bevel=ob.modifiers.new('Soft shell rim','BEVEL');bevel.width=.001;bevel.segments=2

def tube(name, points, radius, mat, cyclic=False):
    cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.resolution_u=2
    cu.bevel_depth=radius;cu.bevel_resolution=2
    sp=cu.splines.new('POLY');sp.points.add(len(points)-1)
    for p,co in zip(sp.points,points):p.co=(*co,1)
    sp.use_cyclic_u=cyclic
    obj=bpy.data.objects.new(name,cu);scene.collection.objects.link(obj);obj.data.materials.append(mat);parts.append(obj)
    return obj

tube('Continuous rubber rim',[cap(2*math.pi*i/N,1,.0003) for i in range(N)],.0034,trim,True)
# Six stitched panels, with short paired stitch segments following the dome.
for panel in range(6):
    a=panel*math.tau/6+math.pi/6
    tube('Cover panel seam %02d'%panel,[cap(a,j/70,.0007) for j in range(3,71)],.00045,thread)
    for j in range(9,66,3):
        tube('Stitch %02d_%02d'%(panel,j),[cap(a-.008,j/70,.001),cap(a-.008,(j+1)/70,.001)],.00016,thread)

def box(name, pos, size, mat, bevel=.002):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos)
    o=bpy.context.object;o.name=name;o.dimensions=size
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(mat)
    if bevel:
        b=o.modifiers.new('Rounded manufactured edges','BEVEL');b.width=bevel;b.segments=3
        o.modifiers.new('Weighted face normals','WEIGHTED_NORMAL')
    parts.append(o);return o

def screw(name, pos, axis):
    bpy.ops.mesh.primitive_cylinder_add(vertices=16,radius=.0032,depth=.0018,location=pos)
    o=bpy.context.object;o.name=name;o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
    o.data.materials.append(metal);parts.append(o)
    b=o.modifiers.new('Screw bevel','BEVEL');b.width=.0005;b.segments=2
    return o

# Side attachment rails, flush against the rounded shell.
for side in [-1,1]:
    a0=0 if side==1 else math.pi
    points=[cap(a0+(j/20-.5)*.78,.85,.003) for j in range(21)]
    tube('Side rail %d'%side,points,.005,polymer)
    for j in [2,18]:
        p=points[j]+Vector((side*.003,0,0));screw('Rail screw',p,(side,0,.1))
    for j in range(4,18,3):
        p=points[j]+Vector((side*.004,0,0))
        tube('Rail slot',[p+Vector((0,-.002,-.0025)),p+Vector((0,.002,.0025))],.0012,trim)

# Small frontal bracket and retaining plate, without logos or insignia.
mount=box('Front equipment mount',(0,-.141,.055),(.041,.005,.037),polymer,.004)
mount.rotation_euler.x=math.radians(-17)
box('Front mount recess',(0,-.145,.057),(.019,.003,.017),trim,.002)
for x in [-.014,.014]:screw('Front mount fastener',(x,-.147,.061),(0,-1,.25))

# Interior suspension cushions leave the cavity open and visible from below.
for a in [0,math.pi*.5,math.pi,math.pi*1.5]:
    p=cap(a,.62,-.014)
    cushion=box('Removable suspension pad',p,(.042,.058,.014),padmat,.007)
    cushion.rotation_euler=(Vector((0,0,CZ))-p).to_track_quat('Z','Y').to_euler()
box('Crown comfort pad',(0,0,.11),(.065,.08,.015),padmat,.007)

def ribbon(name, points, width, mat):
    pts=[Vector(p) for p in points];verts=[]
    for i,p in enumerate(pts):
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(i-1,0)]).normalized()
        # Side webbing lies near the sagittal plane, exposing its woven face.
        side=tangent.cross(Vector((1,0,0))).normalized()
        if name == 'Chin support strap':
            across=Vector((0,1,0))
            side=(across-tangent*tangent.dot(across)).normalized()
        if side.length < .1:side=Vector((0,1,0))
        verts.extend([tuple(p-side*width/2),tuple(p+side*width/2)])
    fs=[(2*i,2*i+1,2*i+3,2*i+2) for i in range(len(pts)-1)]
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],fs);me.update()
    o=bpy.data.objects.new(name,me);scene.collection.objects.link(o);parts.append(o);o.data.materials.append(mat)
    so=o.modifiers.new('Webbing thickness','SOLIDIFY');so.thickness=.0012
    be=o.modifiers.new('Soft strap edges','BEVEL');be.width=.0005;be.segments=2
    return o

for side in [-1,1]:
    front=Vector((side*.108,-.065,-.023));back=Vector((side*.105,.069,-.035))
    junction=Vector((side*.088,-.028,-.118))
    ribbon('Front harness %d'%side,[front,(side*.102,-.048,-.076),junction],.012,webbing)
    ribbon('Rear harness %d'%side,[back,(side*.097,.04,-.085),junction],.012,webbing)
    for p in [front,back]:screw('Harness anchor',p,(side,0,0))
    buckle=box('Strap adjuster %d'%side,junction,(.004,.019,.024),polymer,.002)
    box('Adjuster opening %d'%side,junction+Vector((side*.0025,0,0)),(.001,.009,.011),trim,.001)
# Curved chin section spans the two strap junctions beneath the wearer.
chin=[(.088*math.cos(t),-.028-.035*math.sin(t),-.118-.033*math.sin(t)) for t in [i*math.pi/32 for i in range(33)]]
ribbon('Chin support strap',chin,.017,webbing)
chinpad=box('Chin comfort pad',(0,-.061,-.148),(.052,.021,.009),padmat,.004)

# Export meshes only, baking manufacturing modifiers but preserving real metre units.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=ob
bpy.ops.object.convert(target='MESH')
parts=list(bpy.context.selected_objects)
bpy.ops.export_scene.gltf(filepath=GLB,export_format='GLB',use_selection=True,export_apply=True,export_yup=True,export_animations=False)

# Studio lighting and floor are preview-only and not present in the GLB.
floor=material('Studio neutral',(.105,.12,.115),.91)
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.164));bpy.context.object.data.materials.append(floor);bpy.context.object.name='Studio floor (not exported)'
scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs['Color'].default_value=(.22,.25,.28,1)
scene.world.node_tree.nodes['Background'].inputs['Strength'].default_value=.5
for name,pos,power,size in [('Key',(-.5,-.55,.8),28,.65),('Fill',(.6,-.1,.35),12,.6),('Rim',(.1,.55,.55),20,.5)]:
    ld=bpy.data.lights.new(name,'AREA');lo=bpy.data.objects.new(name,ld);scene.collection.objects.link(lo)
    lo.location=pos;ld.energy=power;ld.shape='DISK';ld.size=size
    lo.rotation_euler=(Vector((0,0,.015))-lo.location).to_track_quat('-Z','Y').to_euler()
camdata=bpy.data.cameras.new('Helmet Camera');camera=bpy.data.objects.new('Helmet Camera',camdata);scene.collection.objects.link(camera)
camera.location=(.40,-.59,.28);target=Vector((0,0,.006));camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camdata.type='ORTHO';camdata.ortho_scale=.48;scene.camera=camera
scene.render.engine='BLENDER_EEVEE_NEXT';scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
scene.view_settings.view_transform='AgX'
scene.render.image_settings.file_format='PNG';scene.render.filepath=os.path.join(OUT,'casco_militar.png')
bpy.ops.render.render(write_still=True)
# Keep the actual helmet selected when opening the editable project.
bpy.ops.object.select_all(action='DESELECT')
for o in parts:o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_distance=.6
            area.spaces.active.region_3d.view_location=(0,0,.01)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(OUT,'casco_militar.blend'))
print('HELMET_GLB',GLB)
print('HELMET_TRIANGLES',sum(len(o.data.polygons) for o in parts))
