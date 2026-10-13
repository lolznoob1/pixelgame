"""Art for the needs: sandwich (hunger) and beer (thirst). Run from the project root:  python3 tools/make_needs_art.py

  assets/ui/sandwich_stages.png   11 frames of 16 x 22 (the size of the bottle sprite): the sandwich with more
                                  and more bites taken out of it. Frame 0 = whole (hunger 100), frame 10 = crumbs (0).
  assets/ui/beer_empty.png        16 x 22 empty glass mug
  assets/ui/beer_full.png         the same mug full of beer (the HUD draws it from the bottom up, plus the foam)
  assets/items/sandwich.png       16 x 16 item icon (the same size as every other item)
  assets/items/beer.png           16 x 16 item icon
Preview: tools/previews/needs_art.png
"""
import math
import numpy as np
from PIL import Image

OUT = (60, 32, 20, 255)
W, H = 16, 22

# ------------------------------------------------------------------ the sandwich (tall: a stack of layers)
def sandwich_layers():
    """Returns (colors HxWx4 without outline, mask HxW)."""
    col = np.zeros((H, W, 4), np.uint8); mask = np.zeros((H, W), bool)
    def row(y, x0, x1, c):
        for x in range(x0, x1 + 1):
            col[y, x] = (*c, 255); mask[y, x] = True
    BUN, BUN_HI, BUN_DK = (226, 164, 84), (246, 204, 130), (186, 122, 58)
    SEED = (252, 238, 196)
    LET, LET_DK = (118, 196, 72), (76, 154, 52)
    TOM, TOM_HI = (222, 66, 54), (246, 116, 100)
    CHE, CHE_DK = (252, 206, 72), (226, 166, 40)
    HAM, HAM_HI = (240, 142, 142), (252, 182, 176)
    y0 = 1
    # toothpick with a red tip
    for y in range(0, 5): col[y0 + y - 1 + 0, 8] = (226, 196, 130, 255); mask[y0 + y - 1, 8] = True
    col[0, 8] = (214, 56, 56, 255); col[0, 7] = (214, 56, 56, 255); mask[0, 7] = True
    # top bun (dome)
    spans = [(6, 9), (4, 11), (3, 12), (2, 13), (2, 13), (2, 13)]
    for i, (a, b) in enumerate(spans): row(y0 + 2 + i, a, b, BUN)
    for (x, y) in [(5, 3), (6, 3), (4, 4), (3, 5), (5, 4)]: col[y0 + y - 1 + 1, x] = (*BUN_HI, 255)
    row(y0 + 7, 2, 13, BUN_DK)
    for (x, y) in [(6, 3), (9, 4), (11, 5), (4, 5), (8, 6)]: col[y0 + y, x] = (*SEED, 255)
    # lettuce (wavy, wider than the bun)
    for x in range(1, 15):
        row(y0 + 8, x, x, LET if x % 2 else LET_DK)
    for x in range(0, 16):
        row(y0 + 9, x, x, LET if x % 3 else LET_DK)
    # tomato
    row(y0 + 10, 2, 13, TOM); row(y0 + 11, 2, 13, TOM)
    for (x, y) in [(4, 10), (5, 10), (9, 11), (10, 11)]: col[y0 + y, x] = (*TOM_HI, 255)
    # cheese with drips
    row(y0 + 12, 1, 14, CHE); row(y0 + 13, 1, 14, CHE_DK)
    row(y0 + 14, 2, 3, CHE); row(y0 + 14, 12, 13, CHE); row(y0 + 15, 2, 2, CHE)
    # ham
    row(y0 + 14, 4, 11, HAM); row(y0 + 15, 3, 12, HAM)
    for (x, y) in [(5, 14), (6, 14)]: col[y0 + y, x] = (*HAM_HI, 255)
    # lettuce, bottom bun
    row(y0 + 16, 1, 14, LET_DK)
    spans = [(2, 13), (2, 13), (2, 13), (3, 12)]
    for i, (a, b) in enumerate(spans): row(y0 + 17 + i, a, b, BUN if i < 3 else BUN_DK)
    row(y0 + 17, 2, 13, BUN_HI)
    return col, mask

BITES = [(14.5, 5.0, 3.3), (0.5, 12.0, 3.5), (14.5, 16.0, 3.7), (1.0, 6.0, 3.9), (13.0, 11.0, 4.7),
         (3.0, 17.0, 4.7), (9.0, 4.0, 5.6), (7.0, 13.0, 7.0), (7.0, 17.0, 8.0), (8.0, 12.0, 13.0)]

def sandwich_stage(k):
    col, mask = sandwich_layers()
    mask = mask.copy()
    for (cx, cy, r) in BITES[:k]:
        for y in range(H):
            for x in range(W):
                if math.hypot(x - cx, y - cy) <= r: mask[y, x] = False
    img = np.zeros((H, W, 4), np.uint8)
    img[mask] = col[mask]
    if k >= 10:                                        # only crumbs are left
        for (x, y, c) in [(5, 19, (226, 164, 84)), (9, 20, (214, 150, 74)), (7, 18, (246, 204, 130))]:
            img[y, x] = (*c, 255); mask[y, x] = True
    out = img.copy()
    for y in range(H):
        for x in range(W):
            if mask[y, x]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and mask[ny, nx]: out[y, x] = OUT; break
    return Image.fromarray(out)

strip = Image.new("RGBA", (W * 11, H), (0, 0, 0, 0))
for k in range(11): strip.paste(sandwich_stage(k), (k * W, 0))
strip.save("assets/ui/sandwich_stages.png")

# ------------------------------------------------------------------ the beer mug (16 x 22)
GLASS = (206, 232, 246, 70)
BEER, BEER_HI, BEER_DK = (236, 170, 36), (252, 210, 90), (200, 120, 20)
MUG_OUT = (30, 20, 40, 255)

def mug(beer):
    img = np.zeros((H, W, 4), np.uint8)
    interior = np.zeros((H, W), bool)
    interior[4:20, 3:11] = True                         # the glass body
    solid = interior.copy()
    handle = np.zeros((H, W), bool)
    handle[6:8, 11:14] = True; handle[8:15, 13:15] = True; handle[14:16, 11:14] = True    # a ring on the right
    solid |= handle
    img[interior] = GLASS
    img[handle] = (176, 204, 222, 255)
    if beer:
        for y in range(4, 20):
            for x in range(3, 11):
                c = BEER
                if x == 3: c = BEER_HI
                if y >= 17: c = BEER_DK
                img[y, x] = (*c, 255)
        for (x, y) in [(5, 8), (8, 12), (6, 15), (9, 7), (7, 10)]: img[y, x] = (255, 232, 150, 255)   # bubbles
    for y in range(5, 18): img[y, 4] = (255, 255, 255, 170) if not beer else img[y, 4]                  # highlight on the glass
    if not beer:
        for y in range(5, 11): img[y, 4] = (255, 255, 255, 190)
    edge = np.zeros_like(solid)
    for y in range(H):
        for x in range(W):
            if solid[y, x]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < W and 0 <= ny < H and solid[ny, nx]: edge[y, x] = True; break
    img[edge] = MUG_OUT
    # the hole of the handle is outlined too
    return Image.fromarray(img)

mug(False).save("assets/ui/beer_empty.png")
mug(True).save("assets/ui/beer_full.png")

# ------------------------------------------------------------------ item icons (16 x 16)
def icon_sandwich():
    img = np.zeros((16, 16, 4), np.uint8); mask = np.zeros((16, 16), bool)
    def row(y, x0, x1, c):
        for x in range(x0, x1 + 1): img[y, x] = (*c, 255); mask[y, x] = True
    row(2, 4, 11, (226, 164, 84)); row(3, 2, 13, (226, 164, 84)); row(4, 2, 13, (226, 164, 84)); row(5, 2, 13, (186, 122, 58))
    for (x, y) in [(5, 3), (8, 3), (11, 4), (4, 4)]: img[y, x] = (252, 238, 196, 255)
    for x in range(1, 15): row(6, x, x, (118, 196, 72) if x % 2 else (76, 154, 52))
    row(7, 2, 13, (222, 66, 54)); row(8, 2, 13, (252, 206, 72)); row(9, 3, 12, (240, 142, 142))
    row(10, 1, 14, (76, 154, 52)); row(11, 2, 13, (226, 164, 84)); row(12, 2, 13, (226, 164, 84)); row(13, 3, 12, (186, 122, 58))
    out = img.copy()
    for y in range(16):
        for x in range(16):
            if mask[y, x]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 16 and 0 <= ny < 16 and mask[ny, nx]: out[y, x] = (30, 20, 40, 255); break
    return Image.fromarray(out)

def icon_beer():
    img = np.zeros((16, 16, 4), np.uint8); solid = np.zeros((16, 16), bool)
    for y in range(3, 14):
        for x in range(3, 11):
            c = (236, 170, 36) if x > 3 else (252, 210, 90)
            if y >= 12: c = (200, 120, 20)
            img[y, x] = (*c, 255); solid[y, x] = True
    for y in (1, 2):
        for x in range(3, 12):
            img[y, x] = (255, 252, 240, 255) if y == 1 else (240, 224, 184, 255); solid[y, x] = True
    for (x, y) in [(5, 6), (8, 9), (6, 11)]: img[y, x] = (255, 232, 150, 255)
    handle = np.zeros((16, 16), bool); handle[5:7, 11:14] = True; handle[7:12, 13:15] = True; handle[11:13, 11:14] = True
    img[handle] = (176, 204, 222, 255); solid |= handle
    out = img.copy()
    for y in range(16):
        for x in range(16):
            if solid[y, x]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < 16 and 0 <= ny < 16 and solid[ny, nx]: out[y, x] = (30, 20, 40, 255); break
    return Image.fromarray(out)

icon_sandwich().save("assets/items/sandwich.png"); icon_beer().save("assets/items/beer.png")

# ------------------------------------------------------------------ preview
S = 6
prev = Image.new("RGBA", (W * 11 * S // 2 + 20, H * S + 16 * S + 60), (70, 70, 80, 255))
big = strip.resize((W * 11 * S // 2, H * S // 2), Image.NEAREST); prev.paste(big, (10, 10), big)
x = 10
for im in (Image.open("assets/ui/sandwich_stages.png").crop((0, 0, W, H)), Image.open("assets/ui/beer_empty.png"), Image.open("assets/ui/beer_full.png"),
           Image.open("assets/items/sandwich.png"), Image.open("assets/items/beer.png")):
    b = im.resize((im.width * S, im.height * S), Image.NEAREST); prev.paste(b, (x, H * S // 2 + 30), b); x += im.width * S + 12
prev.save("tools/previews/needs_art.png")
print("needs art generated")
