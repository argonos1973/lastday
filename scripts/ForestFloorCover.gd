extends RefCounted
## Canopy litter mask: generated once from the real forest, no gameplay changes.
static func apply(world: Node3D, positions: Array) -> void:
	var image := Image.create(512,704,false,Image.FORMAT_R8)
	var minimum := Vector2(-world.MAP_EXTENT,-world.MAP_EXTENT)
	var span := Vector2(world.MAP_EXTENT*2.0,world.MAP_EXTENT+preload("res://scripts/CityExpansion.gd").SOUTH_LIMIT)
	for pos: Vector3 in positions:
		var center := (Vector2(pos.x,pos.z)-minimum)/span*Vector2(512,704)
		for z in range(maxi(0,int(center.y)-4),mini(704,int(center.y)+5)):
			for x in range(maxi(0,int(center.x)-4),mini(512,int(center.x)+5)):
				var distance := ((Vector2(x+.5,z+.5)-center)*span/Vector2(512,704)).length()
				var cover := 1.0-smoothstep(1.2,7.0,distance)
				if cover > image.get_pixel(x,z).r:
					image.set_pixel(x,z,Color(cover,0,0))
	var texture := ImageTexture.create_from_image(image)
	var materials: Array = [preload("res://scripts/MaterialFactory.gd").make_forest_ground_material()]
	if world._cached_leafy_material != null: materials.append(world._cached_leafy_material)
	var south := world.get_node_or_null("SouthernTerrain") as MeshInstance3D
	if south != null: materials.append(south.material_override)
	for material: ShaderMaterial in materials:
		material.set_shader_parameter("canopy_mask",texture)
		material.set_shader_parameter("canopy_minimum",minimum)
		material.set_shader_parameter("canopy_span",span)
		material.set_shader_parameter("canopy_enabled",true)
