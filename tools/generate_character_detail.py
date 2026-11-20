"""Recover the Remy eyelash cutout lost during FBX conversion.

The full body atlas is unnecessary for this tiny surface: keep its UV layout
in a 512px mask shared by all characters. Geometry and skin weights are untouched.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT / "assets/characters/Remy_Remy_alpha_1.png")
alpha = source.getchannel("A").resize((512, 512), Image.Resampling.LANCZOS)
result = Image.new("RGBA", alpha.size, (42, 31, 24, 255))
result.putalpha(alpha)
result.save(ROOT / "assets/textures/clothing/eyelashes.png", optimize=True)
