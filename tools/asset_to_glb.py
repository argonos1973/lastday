#!/usr/bin/env python3
import argparse
import base64
import json
import math
import struct
from pathlib import Path


COMPONENT_FLOAT = 5126
COMPONENT_UNSIGNED_SHORT = 5123
COMPONENT_UNSIGNED_INT = 5125
TARGET_ARRAY_BUFFER = 34962
TARGET_ELEMENT_ARRAY_BUFFER = 34963


def _align(data: bytearray, alignment: int = 4) -> int:
    pad = (-len(data)) % alignment
    if pad:
        data.extend(b"\x00" * pad)
    return pad


def _read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _parse_float_list(values: list[str], count: int, default: float = 0.0) -> list[float]:
    out = []
    for i in range(count):
        try:
            out.append(float(values[i]))
        except Exception:
            out.append(default)
    return out


def load_mtl(path: Path) -> dict:
    materials: dict[str, dict] = {}
    current = None
    if not path.exists():
        return materials
    for raw_line in _read_text(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        key = parts[0].lower()
        values = parts[1:]
        if key == "newmtl" and values:
            current = " ".join(values)
            materials[current] = {"base_color": [0.8, 0.8, 0.8, 1.0], "texture": None}
        elif current and key == "kd":
            rgb = _parse_float_list(values, 3, 0.8)
            materials[current]["base_color"] = [rgb[0], rgb[1], rgb[2], materials[current]["base_color"][3]]
        elif current and key in ("d", "tr") and values:
            try:
                alpha = float(values[0])
                if key == "tr":
                    alpha = 1.0 - alpha
                materials[current]["base_color"][3] = max(0.0, min(1.0, alpha))
            except ValueError:
                pass
        elif current and key == "map_kd" and values:
            texture_name = " ".join(values)
            materials[current]["texture"] = (path.parent / texture_name).resolve()
    return materials


def _resolve_index(value: str, source_len: int) -> int | None:
    if value == "":
        return None
    idx = int(value)
    if idx < 0:
        return source_len + idx
    return idx - 1


def _face_vertex(token: str, vertex_count: int, uv_count: int, normal_count: int) -> tuple[int, int | None, int | None]:
    parts = token.split("/")
    v = _resolve_index(parts[0], vertex_count)
    vt = _resolve_index(parts[1], uv_count) if len(parts) > 1 else None
    vn = _resolve_index(parts[2], normal_count) if len(parts) > 2 else None
    if v is None:
        raise ValueError(f"Face vertex has no position: {token}")
    return v, vt, vn


def _normal_from_triangle(a: list[float], b: list[float], c: list[float]) -> list[float]:
    ux, uy, uz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
    vx, vy, vz = c[0] - a[0], c[1] - a[1], c[2] - a[2]
    nx, ny, nz = uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx
    length = math.sqrt(nx * nx + ny * ny + nz * nz)
    if length <= 0.000001:
        return [0.0, 1.0, 0.0]
    return [nx / length, ny / length, nz / length]


def load_obj(path: Path) -> tuple[dict, dict]:
    positions: list[list[float]] = []
    normals: list[list[float]] = []
    uvs: list[list[float]] = []
    materials: dict[str, dict] = {"default": {"base_color": [0.8, 0.8, 0.8, 1.0], "texture": None}}
    current_material = "default"
    meshes: dict[str, dict] = {}

    def mesh_for(material_name: str) -> dict:
        if material_name not in meshes:
            meshes[material_name] = {
                "vertices": [],
                "normals": [],
                "uvs": [],
                "indices": [],
                "lookup": {},
            }
        return meshes[material_name]

    for raw_line in _read_text(path).splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parts = line.split()
        key = parts[0].lower()
        values = parts[1:]
        if key == "v":
            positions.append(_parse_float_list(values, 3))
        elif key == "vn":
            normals.append(_parse_float_list(values, 3))
        elif key == "vt":
            uv = _parse_float_list(values, 2)
            uvs.append([uv[0], 1.0 - uv[1]])
        elif key == "mtllib" and values:
            mtl_path = path.parent / " ".join(values)
            materials.update(load_mtl(mtl_path))
        elif key == "usemtl" and values:
            current_material = " ".join(values)
            if current_material not in materials:
                materials[current_material] = {"base_color": [0.8, 0.8, 0.8, 1.0], "texture": None}
        elif key == "f" and len(values) >= 3:
            parsed = [_face_vertex(v, len(positions), len(uvs), len(normals)) for v in values]
            for i in range(1, len(parsed) - 1):
                tri = [parsed[0], parsed[i], parsed[i + 1]]
                fallback_normal = _normal_from_triangle(positions[tri[0][0]], positions[tri[1][0]], positions[tri[2][0]])
                mesh = mesh_for(current_material)
                for v_idx, uv_idx, n_idx in tri:
                    key_tuple = (v_idx, uv_idx, n_idx)
                    if key_tuple not in mesh["lookup"]:
                        mesh["lookup"][key_tuple] = len(mesh["vertices"])
                        mesh["vertices"].append(positions[v_idx])
                        mesh["uvs"].append(uvs[uv_idx] if uv_idx is not None and 0 <= uv_idx < len(uvs) else [0.0, 0.0])
                        mesh["normals"].append(normals[n_idx] if n_idx is not None and 0 <= n_idx < len(normals) else fallback_normal)
                    mesh["indices"].append(mesh["lookup"][key_tuple])

    meshes = {name: mesh for name, mesh in meshes.items() if mesh["indices"]}
    if not meshes:
        raise ValueError(f"No mesh faces found in {path}")
    return meshes, materials


def _min_max(values: list[list[float]]) -> tuple[list[float], list[float]]:
    cols = list(zip(*values))
    return [min(c) for c in cols], [max(c) for c in cols]


def _append_accessor(gltf: dict, blob: bytearray, data: bytes, component_type: int, count: int, type_name: str, target: int, min_value=None, max_value=None) -> int:
    _align(blob)
    offset = len(blob)
    blob.extend(data)
    view_index = len(gltf["bufferViews"])
    gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(data), "target": target})
    accessor = {"bufferView": view_index, "componentType": component_type, "count": count, "type": type_name}
    if min_value is not None:
        accessor["min"] = min_value
    if max_value is not None:
        accessor["max"] = max_value
    accessor_index = len(gltf["accessors"])
    gltf["accessors"].append(accessor)
    return accessor_index


def _pack_floats(values: list[list[float]]) -> bytes:
    flat = [item for row in values for item in row]
    return struct.pack("<" + "f" * len(flat), *flat)


def _pack_indices(indices: list[int]) -> tuple[bytes, int]:
    if not indices:
        return b"", COMPONENT_UNSIGNED_SHORT
    if max(indices) <= 65535:
        return struct.pack("<" + "H" * len(indices), *indices), COMPONENT_UNSIGNED_SHORT
    return struct.pack("<" + "I" * len(indices), *indices), COMPONENT_UNSIGNED_INT


def _image_mime(path: Path) -> str:
    suffix = path.suffix.lower()
    if suffix in (".jpg", ".jpeg"):
        return "image/jpeg"
    if suffix == ".webp":
        return "image/webp"
    return "image/png"


def build_glb(meshes: dict, materials: dict) -> bytes:
    gltf = {
        "asset": {"version": "2.0", "generator": "Un dia mas asset_to_glb.py"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0}],
        "meshes": [{"primitives": []}],
        "materials": [],
        "accessors": [],
        "bufferViews": [],
        "buffers": [{"byteLength": 0}],
    }
    blob = bytearray()
    texture_by_path: dict[Path, int] = {}

    for material_name in meshes.keys():
        source = materials.get(material_name, materials.get("default", {}))
        material = {
            "name": material_name,
            "pbrMetallicRoughness": {
                "baseColorFactor": source.get("base_color", [0.8, 0.8, 0.8, 1.0]),
                "metallicFactor": 0.0,
                "roughnessFactor": 0.8,
            },
        }
        tex_path = source.get("texture")
        if tex_path and Path(tex_path).exists():
            tex_path = Path(tex_path)
            if tex_path not in texture_by_path:
                image_bytes = tex_path.read_bytes()
                _align(blob)
                offset = len(blob)
                blob.extend(image_bytes)
                view_index = len(gltf["bufferViews"])
                gltf["bufferViews"].append({"buffer": 0, "byteOffset": offset, "byteLength": len(image_bytes)})
                gltf.setdefault("images", []).append({"bufferView": view_index, "mimeType": _image_mime(tex_path), "name": tex_path.name})
                image_index = len(gltf["images"]) - 1
                gltf.setdefault("textures", []).append({"source": image_index})
                texture_by_path[tex_path] = len(gltf["textures"]) - 1
            material["pbrMetallicRoughness"]["baseColorTexture"] = {"index": texture_by_path[tex_path]}
        gltf["materials"].append(material)

    material_indices = {name: idx for idx, name in enumerate(meshes.keys())}
    for material_name, mesh in meshes.items():
        pos_min, pos_max = _min_max(mesh["vertices"])
        position_accessor = _append_accessor(gltf, blob, _pack_floats(mesh["vertices"]), COMPONENT_FLOAT, len(mesh["vertices"]), "VEC3", TARGET_ARRAY_BUFFER, pos_min, pos_max)
        normal_accessor = _append_accessor(gltf, blob, _pack_floats(mesh["normals"]), COMPONENT_FLOAT, len(mesh["normals"]), "VEC3", TARGET_ARRAY_BUFFER)
        uv_accessor = _append_accessor(gltf, blob, _pack_floats(mesh["uvs"]), COMPONENT_FLOAT, len(mesh["uvs"]), "VEC2", TARGET_ARRAY_BUFFER)
        index_bytes, component = _pack_indices(mesh["indices"])
        index_accessor = _append_accessor(gltf, blob, index_bytes, component, len(mesh["indices"]), "SCALAR", TARGET_ELEMENT_ARRAY_BUFFER)
        gltf["meshes"][0]["primitives"].append({
            "attributes": {"POSITION": position_accessor, "NORMAL": normal_accessor, "TEXCOORD_0": uv_accessor},
            "indices": index_accessor,
            "material": material_indices[material_name],
            "mode": 4,
        })

    _align(blob)
    gltf["buffers"][0]["byteLength"] = len(blob)
    json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
    json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
    total_length = 12 + 8 + len(json_bytes) + 8 + len(blob)
    return (
        struct.pack("<4sII", b"glTF", 2, total_length)
        + struct.pack("<I4s", len(json_bytes), b"JSON")
        + json_bytes
        + struct.pack("<I4s", len(blob), b"BIN\x00")
        + bytes(blob)
    )


def convert_obj(source: Path, output_dir: Path) -> Path:
    meshes, materials = load_obj(source)
    output_dir.mkdir(parents=True, exist_ok=True)
    out = output_dir / f"{source.stem}.glb"
    out.write_bytes(build_glb(meshes, materials))
    return out


def iter_sources(path: Path) -> list[Path]:
    if path.is_file():
        return [path]
    return sorted([p for p in path.rglob("*") if p.suffix.lower() in (".obj", ".fbx")])


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert compatible local assets to GLB without Blender.")
    parser.add_argument("input", help="OBJ file or folder containing OBJ/FBX assets")
    parser.add_argument("-o", "--output-dir", default="assets/external/converted_glb", help="Folder for generated GLB files")
    args = parser.parse_args()

    source_root = Path(args.input).expanduser().resolve()
    output_dir = Path(args.output_dir).expanduser().resolve()
    if not source_root.exists():
        print(f"Input not found: {source_root}")
        return 1

    converted = 0
    failed = 0
    skipped = 0
    for source in iter_sources(source_root):
        if source.suffix.lower() == ".fbx":
            print(f"SKIP FBX {source.name}: FBX needs an FBX importer library; this converter is Blender-free and handles OBJ/MTL.")
            skipped += 1
            continue
        try:
            out = convert_obj(source, output_dir)
            print(f"OK {source.name} -> {out}")
            converted += 1
        except Exception as exc:
            print(f"FAIL {source}: {exc}")
            failed += 1
    print(f"Done. converted={converted} skipped={skipped} failed={failed}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
