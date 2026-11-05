# Pine sapling

Source: [Pine Sapling Medium](https://polyhaven.com/a/pine_sapling_medium), Poly Haven.
Authors: Rico Cilliers (modeling), Rob Tuytel (photography). License: CC0.

Derived from variant c, LOD2, with mesh reduction and textures resized to 1024 pixels.
Rebuild with `tools/blender/prepare_pine_sapling.py` after opening the original
`build/tmp/pine_sapling_source/source.blend` with its `textures` directory.
The full source is deliberately excluded from the game export.

Status: evaluation asset, not referenced by the map. The current reduced variant
has 58,958 triangles. Its needle silhouette still needs improvement before it
replaces existing trees. Preview with `tools/debug/PineSaplingPreview.gd`.

The converter promotes the source's Geometry Nodes `UVMap` corner vector
attribute to a real UV layer and bakes the bark mapping scale. Omitting this
step exports incorrect needle and bark textures.
