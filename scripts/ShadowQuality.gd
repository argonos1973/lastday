extends RefCounted
## Client-only shadow presets. Gameplay, visibility and collisions are unchanged.
const CONFIG_PATH := "user://graphics.cfg"
const PRESETS := [
 {"distance": 35.0, "forest": 28.0, "local": 4.0, "atlas": 1024},
 {"distance": 55.0, "forest": 42.0, "local": 6.0, "atlas": 2048},
 {"distance": 85.0, "forest": 65.0, "local": 6.0, "atlas": 2048},
]

static func selected() -> int:
 return preload("res://scripts/GraphicsSettings.gd").index_value("shadows", 1, 3)

static func save_selection(index: int) -> Error:
 return preload("res://scripts/GraphicsSettings.gd").write_values({"shadows": clampi(index, 0, 2)})

static func apply(sun: DirectionalLight3D, viewport: Viewport, index: int) -> void:
 index = clampi(index, 0, 2)
 var preset: Dictionary = PRESETS[index]
 sun.shadow_enabled = true
 sun.directional_shadow_max_distance = preset.distance
 if index == 0:
  sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
  sun.directional_shadow_blend_splits = false
 else:
  sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if index == 2 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
  sun.directional_shadow_split_1 = 0.15 if index == 2 else 0.3
  sun.directional_shadow_blend_splits = true
 sun.directional_shadow_fade_start = 0.8
 RenderingServer.directional_shadow_atlas_set_size(preset.atlas, true)
 viewport.positional_shadow_atlas_size = 512 if index == 0 else 1024
