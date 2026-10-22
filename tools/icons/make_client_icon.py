#!/usr/bin/env python3
"""Genera el icono del cliente Last Day (icns + ico + png de referencia).

Recorta la hoguera y el superviviente del arte de carga del campamento y
compone un badge cuadrado legible a tamaños pequeños.
"""
import os
import subprocess
from PIL import Image, ImageDraw, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets/loading/02_campamento_camiseta_azul.png")
OUT = os.path.join(ROOT, "tools/icons")

img = Image.open(SRC).convert("RGBA")
w, h = img.size
# Recorte cuadrado centrado en la hoguera y el personaje (tercio izquierdo).
cx = int(w * 0.30)
cy = int(h * 0.62)
side = min(h, int(w * 0.42))
img = img.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))
img = img.resize((1024, 1024), Image.LANCZOS)
# Un poco más de luz en la hoguera y contraste para que se lea en miniatura.
img = ImageEnhance.Brightness(img).enhance(1.18)
img = ImageEnhance.Contrast(img).enhance(1.10)
img = ImageEnhance.Color(img).enhance(1.05)

# Viñeta suave para fundir el icono con el fondo del dock.
overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
for i in range(90):
    a = int(120 * (i / 90.0) ** 2)
    od.rectangle((i, i, 1024 - i, 1024 - i), outline=(0, 0, 0, a))
img = Image.alpha_composite(img, overlay)

img.save(os.path.join(OUT, "client_icon_1024.png"))

# --- macOS .icns ---
iconset = os.path.join(OUT, "LastDay.iconset")
os.makedirs(iconset, exist_ok=True)
for size in (16, 32, 64, 128, 256, 512, 1024):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(iconset, f"icon_{size}x{size}.png"))
for size in (16, 32, 128, 256, 512):
    img.resize((size * 2, size * 2), Image.LANCZOS).save(os.path.join(iconset, f"icon_{size}x{size}@2x.png"))
icns = os.path.join(OUT, "LastDay.icns")
subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns], check=True)

# --- Windows .ico (multiresolución) ---
img.save(os.path.join(OUT, "LastDay.ico"), sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])

print("OK:", icns)
