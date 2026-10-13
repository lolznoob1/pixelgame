"""HUD bottle gauge art and the ability item icon. Run from the project root:  python3 tools/make_ui_art.py

  assets/ui/bottle_empty.png   16x22 glass bottle, empty
  assets/ui/bottle_full.png    same bottle with water in the body and shoulder (rows 5..19)
  assets/items/ability_core.png  16x16 crystal, the "ability item" drop
The gauge (ui/ability_gauge.gd) draws the empty bottle and reveals the full one from the bottom up.
To use other art for another character, keep the same idea: two textures of the same size, plus the rows where the
water is (fill_top / fill_bottom on the player).
"""
import numpy as np
from PIL import Image, ImageDraw

W, H = 16, 22
OUT = (30, 20, 40, 255)
# (first inner x, last inner x) per row; rows without an entry are not part of the glass
SPANS = {2: (7, 8), 3: (7, 8), 4: (7, 8), 5: (6, 9), 6: (5, 10)}
for r in range(7, 18): SPANS[r] = (3, 12)
SPANS[18] = (4, 11); SPANS[19] = (5, 10)
WATER_TOP, WATER_BOTTOM = 5, 20       # rows 5..19

def build(water):
    img = np.zeros((H, W, 4), np.uint8)
    inner = np.zeros((H, W), bool)
    for y, (x0, x1) in SPANS.items(): inner[y, x0:x1 + 1] = True
    # glass body
    img[inner] = (206, 232, 246, 70)
    if water:
        for y in range(WATER_TOP, WATER_BOTTOM):
            x0, x1 = SPANS[y]
            for x in range(x0, x1 + 1):
                img[y, x] = (70, 150, 225, 255)
            # lighter left side, darker bottom: gives the water some volume
            img[y, x0] = (120, 190, 250, 255)
            if y >= WATER_BOTTOM - 3: 
                for x in range(x0 + 1, x1 + 1): img[y, x] = (52, 118, 200, 255)
    # highlights on the glass
    for y in range(8, 13): img[y, 4] = (255, 255, 255, 190)
    img[9, 11] = (255, 255, 255, 150); img[10, 11] = (255, 255, 255, 150)
    # cork
    cork = np.zeros((H, W), bool); cork[0:2, 6:10] = True
    img[cork] = (176, 116, 64, 255); img[0, 6:10] = (206, 146, 86, 255)
    # outline around glass + cork
    solid = inner | cork
    edge = np.zeros_like(solid)
    edge[1:, :] |= solid[:-1, :]; edge[:-1, :] |= solid[1:, :]; edge[:, 1:] |= solid[:, :-1]; edge[:, :-1] |= solid[:, 1:]
    img[edge & ~solid] = OUT
    return Image.fromarray(img)

build(False).save("assets/ui/bottle_empty.png")
build(True).save("assets/ui/bottle_full.png")

# ---- ability core: a glowing crystal
core = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); d = ImageDraw.Draw(core)
for r, a in ((7, 45), (6, 70)):                                       # soft glow
    d.ellipse((8 - r, 8 - r, 8 + r, 8 + r), fill=(120, 220, 255, a))
d.polygon([(8, 1), (2, 7), (8, 8)], fill=(176, 128, 255, 255))
d.polygon([(8, 1), (13, 7), (8, 8)], fill=(214, 178, 255, 255))
d.polygon([(2, 7), (8, 8), (8, 14)], fill=(112, 72, 204, 255))
d.polygon([(13, 7), (8, 8), (8, 14)], fill=(142, 98, 228, 255))
d.line([(8, 1), (2, 7), (8, 14), (13, 7), (8, 1)], fill=OUT)
for (x, y) in [(6, 4), (7, 3), (5, 6)]: d.point((x, y), fill=(255, 255, 255, 255))
core.save("assets/items/ability_core.png")

# preview
S = 8
prev = Image.new("RGBA", (W * S * 2 + 16 * S + 48, H * S + 16), (70, 70, 80, 255))
for i, im in enumerate((Image.open("assets/ui/bottle_empty.png"), Image.open("assets/ui/bottle_full.png"), core)):
    big = im.resize((im.width * S, im.height * S), Image.NEAREST)
    prev.paste(big, (8 + i * (W * S + 16), 8), big)
prev.save("tools/previews/ui_art.png")
print("ui art generated")
