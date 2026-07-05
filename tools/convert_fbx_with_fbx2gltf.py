#!/usr/bin/env python3
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
LOCAL_BIN = PROJECT_ROOT / "tools" / "bin" / "FBX2glTF"


def find_converter() -> Path | None:
    candidates = [
        LOCAL_BIN,
        PROJECT_ROOT / "FBX2glTF",
        PROJECT_ROOT / "FBX2glTF-darwin-x64",
        Path("/opt/homebrew/bin/FBX2glTF"),
        Path("/usr/local/bin/FBX2glTF"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate
    found = shutil.which("FBX2glTF") or shutil.which("fbx2gltf")
    return Path(found) if found else None


def ensure_local_install(converter: Path) -> Path:
    LOCAL_BIN.parent.mkdir(parents=True, exist_ok=True)
    if converter.resolve() != LOCAL_BIN.resolve():
        shutil.copy2(converter, LOCAL_BIN)
    LOCAL_BIN.chmod(0o755)
    return LOCAL_BIN


def iter_fbx(input_path: Path) -> list[Path]:
    if input_path.is_file():
        return [input_path]
    return sorted(input_path.glob("*.fbx"))


def run_converter(converter: Path, source: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    attempts = [
        [str(converter), "-i", str(source), "-o", str(output), "-b"],
        [str(converter), str(source), "-o", str(output), "-b"],
        [str(converter), "--input", str(source), "--output", str(output), "--binary"],
    ]
    last_error = ""
    for command in attempts:
        result = subprocess.run(command, cwd=PROJECT_ROOT, text=True, capture_output=True)
        if result.returncode == 0 and output.exists():
            return
        last_error = (result.stderr or result.stdout or "").strip()
    raise RuntimeError(last_error or f"FBX2glTF could not convert {source.name}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Convert FBX files to GLB with FBX2glTF.")
    parser.add_argument("input", nargs="?", default=".", help="FBX file or folder. Defaults to project root.")
    parser.add_argument("-o", "--output-dir", default=".", help="Output folder. Defaults to project root.")
    parser.add_argument("--install-only", action="store_true", help="Only install a local FBX2glTF binary.")
    args = parser.parse_args()

    converter = find_converter()
    if converter is None:
        print("FBX2glTF not found. Put the downloaded FBX2glTF binary in the project root and run this again.")
        return 1
    converter = ensure_local_install(converter)
    print(f"Using {converter}")

    if args.install_only:
        return 0

    input_path = (PROJECT_ROOT / args.input).resolve()
    output_dir = (PROJECT_ROOT / args.output_dir).resolve()
    sources = iter_fbx(input_path)
    if not sources:
        print(f"No FBX files found in {input_path}")
        return 1

    failed = 0
    for source in sources:
        output = output_dir / f"{source.stem}.glb"
        try:
            run_converter(converter, source, output)
            print(f"OK {source.name} -> {output.relative_to(PROJECT_ROOT)}")
        except Exception as exc:
            failed += 1
            print(f"FAIL {source.name}: {exc}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
