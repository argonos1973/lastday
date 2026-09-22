#!/usr/bin/env python3
"""Genera tools/icons/LastDayServer.icns a partir del arte de carga."""
import os
from PIL import Image, ImageDraw, ImageFont, ImageEnhance

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets/loading/03_lobos_camiseta_verde.png")
OUT = os.path.join(ROOT, "tools/icons")

img = Image.open(SRC).convert("RGBA")
w, h = img.size
# Recorte cuadrado centrado en la manada de lobos (tercio derecho de la imagen)
cx = int(w * 0.72)
cy = int(h * 0.55)
side = min(h, int(w * 0.6))
img = img.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))
img = img.resize((1024, 1024), Image.LANCZOS)
img = ImageEnhance.Brightness(img).enhance(0.82)
img = ImageEnhance.Color(img).enhance(0.85)

# Viñeta oscura en los bordes para que el badge destaque
overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))
od = ImageDraw.Draw(overlay)
od.rectangle((0, 0, 1024, 120), fill=(0, 0, 0, 70))
od.rectangle((0, 904, 1024, 1024), fill=(0, 0, 0, 110))
img = Image.alpha_composite(img, overlay)

d = ImageDraw.Draw(img)
# Badge inferior derecho: placa oscura + "SRV" verde
d.rounded_rectangle((624, 780, 1004, 984), radius=42, fill=(12, 18, 12, 232),
                    outline=(90, 160, 80, 255), width=8)
font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 150)
d.text((814, 876), "SRV", font=font, fill=(140, 210, 110, 255), anchor="mm")
# Tres barras tipo servidor en la placa
for i in range(3):
    y = 820 + i * 60
    d.rounded_rectangle((668, y, 668 + 36, y + 30), radius=8, fill=(140, 210, 110, 255))

img.save(os.path.join(OUT, "server_icon_1024.png"))

iconset = os.path.join(OUT, "LastDayServer.iconset")
os.makedirs(iconset, exist_ok=True)
for size in (16, 32, 64, 128, 256, 512, 1024):
    img.resize((size, size), Image.LANCZOS).save(os.path.join(iconset, f"icon_{size}x{size}.png"))
for size in (16, 32, 128, 256, 512):
    img.resize((size * 2, size * 2), Image.LANCZOS).save(os.path.join(iconset, f"icon_{size}x{size}@2x.png"))
print("iconset listo:", iconset)
