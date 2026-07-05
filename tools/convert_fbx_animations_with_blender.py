import sys
from pathlib import Path

import bpy


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def convert(source: Path, target: Path) -> None:
    clear_scene()
    bpy.ops.import_scene.fbx(filepath=str(source))
    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(target),
        export_format="GLB",
        export_animations=True,
        export_frame_range=True,
        export_nla_strips=True,
        export_materials="EXPORT",
    )


def main() -> int:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    if len(args) < 2 or len(args) % 2 != 0:
        print("Usage: blender --background --python tools/convert_fbx_animations_with_blender.py -- input.fbx output.glb [...]")
        return 1
    for index in range(0, len(args), 2):
        source = Path(args[index]).expanduser().resolve()
        target = Path(args[index + 1]).expanduser().resolve()
        if not source.exists():
            print(f"Missing source: {source}")
            return 2
        print(f"Converting {source.name} -> {target}")
        convert(source, target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
