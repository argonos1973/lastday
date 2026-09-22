"""Build a compact debris lean-to with a continuous roof and natural overlaps."""
from pathlib import Path
import math
import random
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/models/props/branch_shelter.glb'
SOURCE = Path('/Users/sami/Documents/Codex/2026-09-08/rev/outputs/refugio_ramas.blend')
random.seed(47)
bpy.ops.wm.read_factory_settings(use_empty=True)

def material(name, color, texture=None, normal=None, tint=False):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value = (*color, 1)
    bs.inputs['Roughness'].default_value = .95
    if texture:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(ROOT / texture), check_existing=True)
        if tint:
            mix = m.node_tree.nodes.new('ShaderNodeMix')
            mix.data_type = 'RGBA'
            mix.blend_type = 'MULTIPLY'
            mix.inputs['Factor'].default_value = 1.0
            mix.inputs['B'].default_value = (*color, 1)
            m.node_tree.links.new(tex.outputs['Color'], mix.inputs['A'])
            m.node_tree.links.new(mix.outputs['Result'], bs.inputs['Base Color'])
        else:
            m.node_tree.links.new(tex.outputs['Color'], bs.inputs['Base Color'])
    if normal:
        tex = m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.image = bpy.data.images.load(str(ROOT / normal), check_existing=True)
        tex.image.colorspace_settings.name = 'Non-Color'
        n = m.node_tree.nodes.new('ShaderNodeNormalMap')
        n.inputs['Strength'].default_value = .65
        m.node_tree.links.new(tex.outputs['Color'], n.inputs['Color'])
        m.node_tree.links.new(n.outputs[0], bs.inputs['Normal'])
    return m

bark = material('Weathered bark', (.22, .15, .09), 'assets/external/polyhaven/pine_tree_01/textures/pine_tree_01_bark_diff_4k.png')
debris = material('Layered forest litter', (.28, .23, .10), 'assets/external/polyhaven/forest_leaves_02/textures/forest_leaves_02_diffuse_2k.jpg', 'assets/external/polyhaven/forest_leaves_02/textures/forest_leaves_02_nor_gl_2k.jpg')
rope = material('Plant fibre lashings', (.34, .25, .13))
LEAF_TEX = 'assets/external/polyhaven/forest_leaves_02/textures/forest_leaves_02_diffuse_2k.jpg'
leaves = [material('Dry leaf %d' % i, c, LEAF_TEX, tint=True) for i, c in enumerate([(.30,.26,.10),(.38,.28,.11),(.45,.34,.14),(.32,.32,.11)])]
green = [material('Camouflage foliage %d' % i, c, LEAF_TEX, tint=True) for i,c in enumerate([(.16,.22,.06),(.20,.27,.075),(.24,.31,.09),(.17,.24,.07)])]
rock = material('Mossy field stones', (.09,.105,.055))
parts = []

# Author in game coordinates (Y up), convert to Blender Z up.
def v(p): return Vector((p[0], -p[2], p[1]))

def branch(name, a, b, radius=.045, mat=bark):
    a, b = v(a), v(b)
    bpy.ops.mesh.primitive_cone_add(vertices=9, radius1=radius, radius2=radius*.76, depth=(b-a).length, location=(a+b)*.5)
    o = bpy.context.object
    o.name = name
    o.rotation_euler = (b-a).to_track_quat('Z','Y').to_euler()
    o.data.materials.append(mat)
    for poly in o.data.polygons: poly.use_smooth = len(poly.vertices) == 4
    parts.append(o)
    return o

def mesh(name, verts, faces, mat, uv_scale=1):
    data = bpy.data.meshes.new(name)
    data.from_pydata([v(p) for p in verts], [], faces)
    data.update()
    o = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(o)
    data.materials.append(mat)
    uv = data.uv_layers.new()
    side = max(p[0] for p in verts)-min(p[0] for p in verts) < .001
    for poly in data.polygons:
        for idx, loop in enumerate(poly.loop_indices):
            p = verts[data.loops[loop].vertex_index]
            uv.data[loop].uv = ((p[2] if side else p[0])*uv_scale, (p[1] if side else p[2]+p[1]*.5)*uv_scale)
    parts.append(o)
    return o

def lashing(center, axis, radius):
    axis = v(axis).normalized()
    for i in range(5):
        bpy.ops.mesh.primitive_torus_add(major_radius=radius, minor_radius=.007, major_segments=16, minor_segments=5, location=v(center)+axis*(i-2)*.017)
        o = bpy.context.object
        o.name = 'Fibre binding'
        o.rotation_euler = axis.to_track_quat('Z','Y').to_euler()
        o.data.materials.append(rope)
        parts.append(o)

def height(z): return .22 + (z+1.55)/2.8*1.72

# Eleven structural poles: two uprights, one ridge and eight roof rafters.
for x in [-1.13,1.13]:
    branch('Forked support', (x,-.07,1.03),(x+.025,2.06,1.03),.085)
    branch('Fork', (x,1.70,1.03),(x-.13,2.10,1.03),.045)
    branch('Diagonal brace', (x,.52,1.03),(x,1.50,.38),.04)
    lashing((x,1.93,1.03),(0,1,0),.10)
branch('Ridge beam',(-1.43,1.93,1.03),(1.43,1.95,1.03),.075)
for i in range(8):
    x = -1.28+i*2.56/7
    branch('Roof rafter',(x,.16,-1.64),(x,2.07,1.34),.043)
    lashing((x,1.98,1.07),(0,.55,.84),.06)
for z in [-1.55,-1.3,-1.05,-.8,-.55,-.3,-.05,.2,.45,.7,.95,1.2]:
    branch('Woven roof batten',(-1.40,height(z)+.03,z),(1.40,height(z)+.03,z),.023)

# Continuous backing means the shelter has no see-through holes in rain.
mesh('Dense debris roof', [(-1.5,height(-1.67),-1.67),(1.5,height(-1.67),-1.67),(1.5,height(1.4),1.4),(-1.5,height(1.4),1.4)], [(0,1,2,3)], debris, 1.2)
# Overlapping irregular shingle-like bundles. Each has a thick, ragged lower lip.
for row in range(8):
    z = -1.60+row*.39
    for col in range(12):
        x = -1.53+col*.255+random.uniform(-.035,.035)
        w = random.uniform(.28,.35)
        length = random.uniform(.51,.64)
        bottom = z-random.uniform(0,.10)
        top = min(z+length,1.46)
        y0, y1 = height(bottom)+.10+row*.004, height(top)+.09+row*.004
        mesh('Overlapping leaf bundle', [(x,y0,bottom),(x+w*.5,y0-.02,bottom-.055),(x+w,y0,bottom+.025),(x+w,y1,top),(x,y1,top),(x,y0-.085,bottom),(x+w,y0-.085,bottom+.025)], [(0,1,2,3,4),(0,5,6,2,1)], debris, 2)

# Triangular windbreaks on the sides, leaving the high front open.
for x in [-1.21,1.21]:
    mesh('Side windbreak',[(x,.08,-1.5),(x,.12,.72),(x,1.66,.72)],[(0,1,2)],debris,1.5)
    for j in range(22):
        z = -1.48+j*.115
        branch('Side woven twig',(x,.10,z),(x,height(z)-.05,z),.019)
    for j in range(7):
        branch('Side cross weave',(x,.10+j*.05,-1.4),(x,.18+j*.27,.72),.016)
    for j in range(4):
        branch('Side cross weave',(x,-.02+j*.04,-1.45),(x,.10+j*.30,.68),.013)

# Batch real leaf geometry by material: irregular foliage on
# roof and walls, and overhanging boughs that hide the straight frame edges.
leaf_batches = {}
def leaf(center, normal, size, mat):
    n = Vector(normal).normalized()
    tangent = n.cross(Vector((1,0,0)) if abs(n.x)<.9 else Vector((0,1,0))).normalized()
    bitangent = n.cross(tangent)
    angle = random.uniform(0,math.tau)
    a = (tangent*math.cos(angle)+bitangent*math.sin(angle))*size
    b = n.cross(a)*.46
    c = Vector(center)
    c.y = min(c.y, 2.20)
    verts,faces = leaf_batches.setdefault(mat,([],[]))
    base = len(verts)
    verts.extend([c+a*math.cos(j*math.tau/8)+b*math.sin(j*math.tau/8) for j in range(8)])
    verts.append(c+n*random.uniform(.008,.019))
    faces.extend([(base+j,base+(j+1)%8,base+8) for j in range(8)])

# Fallen leaves spill past the threshold and dissolve the rectangular outline.
for i in range(900):
    x,z = random.uniform(-1.85,1.85),random.uniform(-2.0,1.85)
    if abs(x)>1.17 or z>1.10 or z< -1.45:
        leaf((x,random.uniform(.01,.035),z),(0,1,0),random.uniform(.05,.115),random.choice(leaves))
# Dense roof canopy: two overlapping layers so the rafters never show through.
for i in range(3200):
    x,z = random.uniform(-1.57,1.57),random.uniform(-1.72,1.48)
    leaf((x,height(z)+random.uniform(.16,.26),z),(random.uniform(-.3,.3),1,-.61),random.uniform(.075,.15),random.choice(green if random.random()<.78 else leaves))
for i in range(1400):
    x,z = random.uniform(-1.62,1.62),random.uniform(-1.75,1.20)
    leaf((x,height(z)+random.uniform(.18,.30),z),(random.uniform(-.4,.4),1,-.55),random.uniform(.08,.16),random.choice(green if random.random()<.82 else leaves))
# Leaf skirt where the low back edge nearly touches the ground.
for i in range(500):
    x = random.uniform(-1.6,1.6)
    z = random.uniform(-1.95,-1.45)
    leaf((x,random.uniform(.02,.16),z),(random.uniform(-.4,.4),1,random.uniform(-.4,.4)),random.uniform(.06,.13),random.choice(green if random.random()<.5 else leaves))
for side in [-1,1]:
    for i in range(1500):
        z = random.uniform(-1.5,.93)
        y = random.uniform(.06,max(.07,height(z)-.06))
        leaf((side*random.uniform(1.22,1.33),y,z),(side,.2,0),random.uniform(.07,.15),random.choice(green))
    # Boughs tied against the posts conceal the pale vertical silhouette.
    for i in range(9):
        y = .16+i*.22
        a = Vector((side*1.14,y,1.10))
        b = Vector((side*(1.37+random.uniform(0,.18)),y+.28,1.19))
        branch('Camouflage bough',a,b,.012)
        for j in range(30):
            p = a.lerp(b,random.random())+Vector((random.uniform(-.10,.10),random.uniform(-.1,.1),random.uniform(-.05,.05)))
            leaf(p,(side*.3,.35,1),random.uniform(.08,.14),random.choice(green))
# Boughs along the ridge and front lip break the straight silhouette.
for i in range(10):
    x = -1.45+i*.32+random.uniform(-.06,.06)
    a = Vector((x,height(1.05)+.02,1.02))
    b = Vector((x+random.uniform(-.25,.25),height(1.30)+random.uniform(.02,.13),1.38+random.uniform(0,.14)))
    branch('Ridge bough',a,b,.011)
    for j in range(22):
        p = a.lerp(b,random.random())+Vector((random.uniform(-.09,.09),random.uniform(-.06,.06),random.uniform(-.05,.05)))
        leaf(p,(random.uniform(-.3,.3),.4,.9),random.uniform(.07,.13),random.choice(green))
for i in range(6):
    x = -1.5+i*.6+random.uniform(-.12,.12)
    a = Vector((x,height(-1.6)+.02,-1.62))
    b = Vector((x+random.uniform(-.2,.2),.04,-1.85-random.uniform(0,.15)))
    branch('Back skirt bough',a,b,.010)
    for j in range(16):
        p = a.lerp(b,random.random())+Vector((random.uniform(-.08,.08),random.uniform(-.03,.08),random.uniform(-.05,.05)))
        leaf(p,(random.uniform(-.3,.3),.6,-.7),random.uniform(.06,.12),random.choice(green if random.random()<.6 else leaves))
for mat,(verts,faces) in leaf_batches.items():
    mesh('Batched '+mat.name,verts,faces,mat)

for x,z in [(-1.2,1.02),(1.2,1.02),(-1.3,-1.50),(1.3,-1.50)]:
    for j in range(3):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=v((x+random.uniform(-.10,.10),.05,z+random.uniform(-.10,.10))))
        o=bpy.context.object
        o.name='Footing stone'
        o.scale=(.13,.11,.075)
        o.data.materials.append(rock)
        parts.append(o)

# One mesh / material surfaces for efficient rendering and atomic dismantling.
bpy.ops.object.select_all(action='DESELECT')
for o in parts: o.select_set(True)
bpy.context.view_layer.objects.active=parts[0]
bpy.ops.object.join()
o=bpy.context.object
o.name='BranchShelter'
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.mesh.normals_make_consistent(inside=False)
bpy.ops.object.mode_set(mode='OBJECT')
OUT.parent.mkdir(parents=True,exist_ok=True)
for image in bpy.data.images:
    if image.size[0] > 2048 or image.size[1] > 2048:
        ratio = 2048/max(image.size)
        image.scale(int(image.size[0]*ratio),int(image.size[1]*ratio))
bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_image_format='JPEG',export_jpeg_quality=90)
SOURCE.parent.mkdir(parents=True,exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE))
print('SHELTER_EXPORTED',OUT,len(o.data.polygons))
