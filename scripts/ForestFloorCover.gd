extends RefCounted
## Canopy litter mask: generated once from the real forest, no gameplay changes.
static func apply(world: Node3D, positions: Array) -> void:
	var image := Image.create(512,704,false,Image.FORMAT_R8)
	var minimum := Vector2(-world.MAP_EXTENT,-world.MAP_EXTENT)
	var span := Vector2(world.MAP_EXTENT*2.0,world.MAP_EXTENT+preload("res://scripts/CityExpansion.gd").SOUTH_LIMIT)
	var pixel_size := span / Vector2(512,704)
	var radius_pixels := Vector2(11.0,11.0) / pixel_size
	for pos: Vector3 in positions:
		var center := (Vector2(pos.x,pos.z)-minimum)/span*Vector2(512,704)
		for z in range(maxi(0,floori(center.y-radius_pixels.y)),mini(704,ceili(center.y+radius_pixels.y))):
			for x in range(maxi(0,floori(center.x-radius_pixels.x)),mini(512,ceili(center.x+radius_pixels.x))):
				var distance_squared := ((Vector2(x+.5,z+.5)-center)*pixel_size).length_squared()
				if distance_squared >= 121.0: continue
				var distance := sqrt(distance_squared)
				var cover := 1.0-smoothstep(1.6,11.0,distance)
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
