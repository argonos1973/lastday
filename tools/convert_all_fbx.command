#!/bin/zsh
set -u

cd "$(dirname "$0")/.."

mkdir -p tools/bin
if [[ -f "FBX2glTF-macos-x86_64.zip" ]]; then
  rm -rf /tmp/un_dia_mas_fbx2gltf
  mkdir -p /tmp/un_dia_mas_fbx2gltf
  unzip -o "FBX2glTF-macos-x86_64.zip" -d /tmp/un_dia_mas_fbx2gltf >/dev/null
  cp /tmp/un_dia_mas_fbx2gltf/FBX2glTF-macos-x86_64/FBX2glTF-macos-x86_64 tools/bin/FBX2glTF
fi

if [[ ! -f tools/bin/FBX2glTF ]]; then
  echo "No encuentro FBX2glTF. Deja FBX2glTF-macos-x86_64.zip en la raiz del proyecto."
  read -k 1 "?Pulsa una tecla para cerrar..."
  exit 1
fi

chmod +x tools/bin/FBX2glTF
xattr -d com.apple.quarantine tools/bin/FBX2glTF 2>/dev/null || true

echo "Convirtiendo FBX a GLB..."
failed=0
for src in *.fbx; do
  [[ -f "$src" ]] || continue
  out="${src:r}.glb"
  echo "  $src -> $out"
  if tools/bin/FBX2glTF -i "$src" -o "$out" -b >/tmp/un_dia_mas_fbx2gltf.log 2>&1; then
    continue
  fi
  if tools/bin/FBX2glTF "$src" -o "$out" -b >/tmp/un_dia_mas_fbx2gltf.log 2>&1; then
    continue
  fi
  if tools/bin/FBX2glTF --input "$src" --output "$out" --binary >/tmp/un_dia_mas_fbx2gltf.log 2>&1; then
    continue
  fi
  echo "  ERROR convirtiendo $src"
  cat /tmp/un_dia_mas_fbx2gltf.log
  failed=1
done

if [[ "$failed" == "0" ]]; then
  echo "Conversion terminada."
else
  echo "Conversion terminada con errores."
fi

read -k 1 "?Pulsa una tecla para cerrar..."
exit "$failed"
