#!/usr/bin/env python3
"""Generates seamless fur tiles for the pelt clothing shader.

Each species' albedo atlas is a UV unwrap on a flat background — sampling it
directly (e.g. triplanar) would paint garments with the background fill and
face/claw islands. This crops a dense fur island per species and mirror-tiles
it 2x2 so the result repeats without seams.

Usage: python3 tools/blender/make_pelt_fur_tiles.py
Output: assets/textures/pelt/fur_<species>.png
"""
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "textures", "pelt")

# (source atlas, uv rect x0,y0,x1,y1 of a dense fur island — picked by hand,
# verified visually via a contact sheet of crops)
PICKS = {
    "lobo": ("assets/external/wolf/WolfAnimated_T_Wolf.png", (0.20, 0.30, 0.45, 0.55)),
    "ciervo": ("assets/models/wildlife/deer_T_Deer.png", (0.15, 0.20, 0.40, 0.55)),
    "zorro": ("assets/models/wildlife/fox_Fox.png", (0.42, 0.50, 0.75, 0.80)),
    "oso": ("assets/models/wildlife/bear_T_Bear.png", (0.15, 0.33, 0.52, 0.62)),
}

TILE = 512


def mirror_tile(crop: Image.Image) -> Image.Image:
    w, h = crop.size
    m = Image.new("RGB", (w * 2, h * 2))
    m.paste(crop, (0, 0))
    m.paste(crop.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    m.paste(crop.transpose(Image.FLIP_TOP_BOTTOM), (0, h))
    m.paste(crop.transpose(Image.FLIP_LEFT_RIGHT).transpose(Image.FLIP_TOP_BOTTOM), (w, h))
    return m.resize((TILE, TILE))


def make_bird_tile() -> Image.Image:
    """simple_bird.glb has flat-color materials (no albedo texture), so its
    'pelt' tile is synthesized: soft noise + feather vane streaks tinted in the
    Bird_Body material color."""
    random.seed(7)
    base = (111, 110, 121)  # Bird_Body albedo (0.434, 0.429, 0.474) * 255
    w = h = TILE
    im = Image.new("RGB", (w, h), base)
    px = im.load()
    for y in range(h):
        for x in range(w):
            n = random.gauss(0, 14)
            streak = int(18 * random.random()) if (x // 3 + y) % 7 == 0 else 0
            v = int(n + streak - streak * 0.5)
            px[x, y] = (
                min(255, max(0, base[0] + v)),
                min(255, max(0, base[1] + v)),
                min(255, max(0, base[2] + v + 4)),
            )
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    d = ImageDraw.Draw(im)
    for yy in range(0, h, 14):
        d.line([(0, yy), (w, yy + 20)], fill=(base[0] - 18, base[1] - 18, base[2] - 16), width=2)
    return mirror_tile(im.filter(ImageFilter.GaussianBlur(1.2)))


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, (rel, (x0, y0, x1, y1)) in PICKS.items():
        im = Image.open(os.path.join(ROOT, rel)).convert("RGB")
        w, h = im.size
        crop = im.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
        out = os.path.join(OUT_DIR, f"fur_{name}.png")
        mirror_tile(crop).save(out)
        print(f"{name}: {out}")
    out = os.path.join(OUT_DIR, "fur_ave.png")
    make_bird_tile().save(out)
    print(f"ave: {out} (synthesized — bird GLB carries flat-color materials)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
