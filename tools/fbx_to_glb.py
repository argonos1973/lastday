#!/usr/bin/env python3
"""Convert FBX animation files to GLB using Blender."""
import sys
import os
import bpy

def convert_fbx_to_glb(fbx_path, glb_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=fbx_path)
    bpy.ops.export_scene.gltf(filepath=glb_path, export_format='GLB')

if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(args) < 2:
        print("Usage: blender --background --python fbx_to_glb.py -- <input.fbx> <output.glb>")
        sys.exit(1)
    convert_fbx_to_glb(args[0], args[1])
    print(f"OK {args[0]} -> {args[1]}")
