#!/usr/bin/env python3
"""Generates high-resolution (1024x1024) seamless fur textures for pelt clothing,
ground hides and animal-head headdresses directly from each hunted animal's
authored albedo atlas (`WolfAnimated_T_Wolf.png`, `deer_T_Deer.png`,
`fox_Fox.png`, `bear_T_Bear.png`).

Instead of small crops or synthetic 1px lines (which look like knitted fabric when
tiled across a jacket), this extracts the full dorsal-to-flank body hide of each
animal, aligns the hair flow vertically, and feathers only the outer margin so
the photographic fur clumps of the 3D animal remain 100% intact.
"""
import math
import os
import random
import sys

from PIL import Image, ImageEnhance, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT_DIR = os.path.join(ROOT, "assets", "textures", "pelt")

TILE = 1024

# (atlas_path, (x0, y0, x1, y1), rotation_to_make_hair_vertical, contrast_boost)
PICKS = {
    # Wolf body hide: dark ash-grey dorsal mane in the center with silver/buff flanks
    "lobo": ("assets/external/wolf/WolfAnimated_T_Wolf.png", (0.27, 0.25, 0.62, 0.68), None, 1.08),
    # Deer body hide: warm tawny-russet dorsal fur grading into lighter buckskin flanks
    "ciervo": ("assets/models/wildlife/deer_T_Deer.png", (0.46, 0.18, 0.72, 0.64), Image.Transpose.ROTATE_270, 1.10),
    # Fox body hide: vibrant orange-red dorsal pelt with warm cream flank accents
    "zorro": ("assets/models/wildlife/fox_Fox.png", (0.40, 0.50, 0.76, 0.82), Image.Transpose.ROTATE_270, 1.12),
    # Bear body hide: dense dark grizzly-brown fur clumps matching the bear head
    "oso": ("assets/models/wildlife/bear_T_Bear.png", (0.25, 0.36, 0.60, 0.74), None, 1.10),
}


def make_seamless_hide(src_img: Image.Image, rect, rot, contrast: float) -> Image.Image:
    w, h = src_img.size
    x0, y0, x1, y1 = rect
    crop = src_img.crop((int(x0 * w), int(y0 * h), int(x1 * w), int(y1 * h)))
    if rot is not None:
        crop = crop.transpose(rot)

    # Extract a slightly larger region (TILE + 2 * MARGIN) so we can wrap-feather
    # just the border without blurring the central 80% of the real animal hide.
    margin = int(TILE * 0.16)
    big = TILE + margin
    resized = crop.resize((big, big), Image.Resampling.LANCZOS)
    if abs(contrast - 1.0) > 1e-3:
        resized = ImageEnhance.Contrast(resized).enhance(contrast)
    src_px = resized.load()

    out = Image.new("RGB", (TILE, TILE))
    out_px = out.load()

    for y in range(TILE):
        # Seamless vertical wrap in the last `margin` pixels
        ty = 0.0
        if y >= TILE - margin:
            u = (y - (TILE - margin)) / float(margin)
            ty = 0.5 - 0.5 * math.cos(math.pi * u)
        for x in range(TILE):
            tx = 0.0
            if x >= TILE - margin:
                v = (x - (TILE - margin)) / float(margin)
                tx = 0.5 - 0.5 * math.cos(math.pi * v)

            c00 = src_px[x + margin, y + margin]
            if tx == 0.0 and ty == 0.0:
                out_px[x, y] = c00
                continue

            c10 = src_px[x - (TILE - margin), y + margin] if tx > 0.0 else c00
            c01 = src_px[x + margin, y - (TILE - margin)] if ty > 0.0 else c00
            c11 = src_px[x - (TILE - margin), y - (TILE - margin)] if (tx > 0.0 and ty > 0.0) else c00

            r0 = c00[0] * (1.0 - tx) + c10[0] * tx
            g0 = c00[1] * (1.0 - tx) + c10[1] * tx
            b0 = c00[2] * (1.0 - tx) + c10[2] * tx

            r1 = c01[0] * (1.0 - tx) + c11[0] * tx
            g1 = c01[1] * (1.0 - tx) + c11[1] * tx
            b1 = c01[2] * (1.0 - tx) + c11[2] * tx

            r = int(r0 * (1.0 - ty) + r1 * ty)
            g = int(g0 * (1.0 - ty) + g1 * ty)
            b = int(b0 * (1.0 - ty) + b1 * ty)
            out_px[x, y] = (max(0, min(255, r)), max(0, min(255, g)), max(0, min(255, b)))

    return out


def make_bird_tile() -> Image.Image:
    random.seed(7)
    base = (111, 110, 121)
    w = h = 512
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
    return im.filter(ImageFilter.GaussianBlur(0.8))


def main() -> int:
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, (rel, rect, rot, contrast) in PICKS.items():
        im = Image.open(os.path.join(ROOT, rel)).convert("RGB")
        out = os.path.join(OUT_DIR, f"fur_{name}.png")
        make_seamless_hide(im, rect, rot, contrast).save(out)
        print(f"{name}: {out}")
    out = os.path.join(OUT_DIR, "fur_ave.png")
    make_bird_tile().save(out)
    print(f"ave: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
