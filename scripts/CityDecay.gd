extends Node3D
## Deterministic dressing outside the clear walking/door/stair routes.
## Village-style overgrowth: short green grass reclaiming the yards and street
## edges — no rubble fields.
const GRASS_VARIANTS := 4
var _wind_time := 0.0
var _wind_material: ShaderMaterial = null

func _process(delta: float) -> void:
 _wind_time += delta
 if _wind_material != null:
  _wind_material.set_shader_parameter("time_var", _wind_time)

func _ready() -> void:
 var rng := RandomNumberGenerator.new()
 rng.seed = 812
 # Same tufts as the village houses: curved blade ribbons in a few variants,
 # instanced with per-tuft colours and the shared wind shader.
 var queues: Array = []
 for v in range(GRASS_VARIANTS): queues.append([])
 var placed := 0
 while placed < 1500:
  var x: float
  var z: float
  if placed % 5 == 0: # fringe along the edges of both streets
   x = rng.randf_range(-34,34)
   z = rng.randf_range(7.2,10.8) * (-1 if placed % 2 else 1)
   if placed % 10 == 0: var t := x; x = z; z = t
  else: # yards: off the streets, outside the building footprints
   x = rng.randf_range(-40,40) * (1 if placed % 2 else -1)
   z = rng.randf_range(-30,30)
   if absf(x) < 6.6 or absf(z) < 6.6: continue
   if absf(absf(x)-16) < 6.5 and absf(absf(z)-17) < 6.5: continue
  var h := rng.randf_range(.30,.72)
  var r := rng.randf_range(.20,.42)
  var c := Color(.15,.30,.10).lerp(Color(.32,.42,.14),rng.randf()).darkened(rng.randf_range(0.0,.12))
  var variant := rng.randi() % GRASS_VARIANTS
  var basis := Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(Vector3(r,h,r))
  (queues[variant] as Array).append(Transform3D(basis,Vector3(x,.02,z)))
  (queues[variant] as Array).append(c)
  placed += 1
 for v in range(GRASS_VARIANTS):
  var entries: Array = queues[v]
  var mm := MultiMesh.new()
  mm.transform_format = MultiMesh.TRANSFORM_3D
  mm.use_colors = true
  mm.mesh = _tuft_mesh(0xC17 + v * 701)
  mm.instance_count = entries.size() / 2
  for k in range(mm.instance_count):
   mm.set_instance_transform(k, entries[k * 2])
   mm.set_instance_color(k, entries[k * 2 + 1])
  var mi := MultiMeshInstance3D.new()
  mi.multimesh = mm
  mi.material_override = _grass_material()
  mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  add_child(mi)
 for pos in [Vector3(-28,0,-27),Vector3(28,0,26),Vector3(-29,0,22),Vector3(28,0,-26)]:
  _branch(pos,pos+Vector3(.2,6,0),.16)
  var trunk := StaticBody3D.new()
  trunk.position = pos + Vector3(.1,3,.1)
  var trunk_shape := CollisionShape3D.new()
  var cylinder := CylinderShape3D.new()
  cylinder.radius=.16; cylinder.height=6
  trunk_shape.shape=cylinder
  trunk.add_child(trunk_shape)
  add_child(trunk)
  for j in range(8):
   var start: Vector3 = pos+Vector3(0,2.3+j*.45,0)
   var end: Vector3 = start+Vector3(cos(j*2.4)*2,1.2,sin(j*2.4)*2)
   _branch(start,end,.055)
   _branch(end,end+Vector3(.4,.9,.35),.021)

# Normalised tuft (height 1, radius 1): the same ribbon-blade build the
# village grass batches use in Main._build_grass_variant_mesh.
func _tuft_mesh(variant_seed: int) -> ArrayMesh:
 var rng := RandomNumberGenerator.new()
 rng.seed = variant_seed
 var vertices := PackedVector3Array()
 var indices := PackedInt32Array()
 var uvs := PackedVector2Array()
 var blade_count := 16 + rng.randi() % 9
 for i in range(blade_count):
  var angle := rng.randf_range(0.0, TAU)
  var spread := sqrt(rng.randf()) * 0.95
  var base := Vector3(cos(angle) * spread, 0.0, sin(angle) * spread)
  var blade_height := rng.randf_range(0.48, 1.2)
  var blade_width := rng.randf_range(0.035, 0.085)
  var lean := Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.22, 0.68)
  var right := Vector3(-sin(angle), 0, cos(angle)) * blade_width
  var start_index := vertices.size()
  for segment in range(3):
   var t := float(segment) / 3.0
   var center := base + Vector3.UP * blade_height * t + lean * t * t
   var width := right * (1.0 - t * 0.82)
   vertices.append(center - width)
   vertices.append(center + width)
   uvs.append(Vector2(0, t))
   uvs.append(Vector2(1, t))
  vertices.append(base + Vector3.UP * blade_height + lean)
  uvs.append(Vector2(0.5, 1))
  for segment in range(2):
   var j := start_index + segment * 2
   indices.append_array(PackedInt32Array([j, j + 1, j + 2, j + 1, j + 3, j + 2]))
  indices.append_array(PackedInt32Array([start_index + 4, start_index + 5, start_index + 6]))
 var arrays := []
 arrays.resize(Mesh.ARRAY_MAX)
 arrays[Mesh.ARRAY_VERTEX] = vertices
 arrays[Mesh.ARRAY_INDEX] = indices
 arrays[Mesh.ARRAY_TEX_UV] = uvs
 var mesh := ArrayMesh.new()
 mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
 var surface := SurfaceTool.new()
 surface.create_from(mesh, 0)
 surface.generate_normals()
 return surface.commit()

# The village wind shader (Main._ensure_wind_shader) so the block grass moves
# and dries out exactly like the village's.
func _grass_material() -> ShaderMaterial:
 if _wind_material == null:
  var sh := Shader.new()
  sh.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_opaque, diffuse_burley;

uniform sampler2D albedo_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float wind_strength = 0.15;
uniform float wind_speed = 1.5;
uniform float wind_frequency = 2.0;
uniform float time_var = 0.0;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float height_factor = UV.y * UV.y;
	float wind_phase = dot(world_xz, vec2(0.7, 0.45)) * wind_frequency + time_var * wind_speed;
	float gust = sin(wind_phase) + 0.35 * sin(wind_phase * 0.43 + time_var * 0.7);
	vec3 wind = vec3(gust, 0.0, gust * 0.45) * wind_strength * height_factor;
	VERTEX += inverse(mat3(MODEL_MATRIX)) * wind;
	float distance_to_camera = distance(MODEL_MATRIX[3].xz, CAMERA_POSITION_WORLD.xz);
	VERTEX.y *= 1.0 - smoothstep(48.0, 68.0, distance_to_camera);
}

void fragment() {
	float patch = texture(albedo_tex, world_xz * 0.018).r;
	float blade = mix(0.69, 1.12, smoothstep(0.0, 0.85, UV.y));
	float vein = 0.90 + 0.10 * sin(UV.x * 3.14159);
	vec3 dry_tint = mix(vec3(0.90, 1.0, 0.86), vec3(1.15, 1.02, 0.74), smoothstep(0.48, 0.7, patch));
	ALBEDO = albedo_color.rgb * COLOR.rgb * dry_tint * blade * vein;
	NORMAL = normalize((FRONT_FACING ? NORMAL : -NORMAL) + vec3(0.0, 0.18, 0.0));
	ROUGHNESS = 0.94;
	SPECULAR = 0.12;
	BACKLIGHT = ALBEDO * 0.28 * UV.y;
}
"""
  _wind_material = ShaderMaterial.new()
  _wind_material.shader = sh
  _wind_material.set_shader_parameter("albedo_tex", MaterialFactory.forest_variation_texture())
  _wind_material.set_shader_parameter("albedo_color", Color(1, 1, 1, 1))
  _wind_material.set_shader_parameter("wind_strength", 0.12)
  _wind_material.set_shader_parameter("wind_speed", 1.8)
  _wind_material.set_shader_parameter("wind_frequency", 1.5)
 return _wind_material

func _branch(a: Vector3,b: Vector3,radius: float) -> void:
 var mi := MeshInstance3D.new()
 var cylinder := CylinderMesh.new()
 cylinder.top_radius=radius*.3
 cylinder.bottom_radius=radius
 cylinder.height=a.distance_to(b)
 cylinder.radial_segments=6
 mi.mesh=cylinder
 var material := StandardMaterial3D.new()
 material.albedo_color=Color(.12,.10,.08)
 mi.material_override=material
 mi.position=(a+b)*.5
 mi.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
 add_child(mi)
