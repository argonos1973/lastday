#!/usr/bin/env python3
"""Genera la pantalla de arranque (boot splash) del cliente Last Day.

Usa el arte del campamento a pantalla completa, lo oscurece ligeramente y
estampa el título del juego en la parte inferior.
"""
import os
from PIL import Image, ImageDraw, ImageEnhance, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets/loading/02_campamento_camiseta_azul.png")
OUT = os.path.join(ROOT, "assets/loading/splash_lastday.png")
W, H = 1920, 1080

img = Image.open(SRC).convert("RGB")
# Cover-fit al lienzo 16:9
src_ratio = img.width / img.height
dst_ratio = W / H
if src_ratio > dst_ratio:
    new_w = int(img.height * dst_ratio)
    x0 = (img.width - new_w) // 2
    img = img.crop((x0, 0, x0 + new_w, img.height))
else:
    new_h = int(img.width / dst_ratio)
    y0 = (img.height - new_h) // 2
    img = img.crop((0, y0, img.width, y0 + new_h))
img = img.resize((W, H), Image.LANCZOS)
img = ImageEnhance.Brightness(img).enhance(0.9)

# Degradado inferior para apoyar el título.
fade = Image.new("L", (W, H), 0)
fd = ImageDraw.Draw(fade)
for y in range(int(H * 0.62), H):
    fd.line((0, y, W, y), fill=int(190 * ((y - H * 0.62) / (H * 0.38))))
img = Image.composite(Image.new("RGB", (W, H), (4, 6, 8)), img, fade)

d = ImageDraw.Draw(img)
try:
    title_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 148)
    sub_font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 44)
except OSError:
    title_font = ImageFont.load_default()
    sub_font = ImageFont.load_default()
d.text((W // 2, H - 170), "LAST DAY", font=title_font,
       fill=(214, 226, 210, 255), anchor="mm", stroke_width=3, stroke_fill=(10, 14, 10, 255))
d.text((W // 2, H - 92), "supervivencia multijugador", font=sub_font,
       fill=(150, 170, 145, 255), anchor="mm")

img.save(OUT, "PNG")
print("OK:", OUT)
