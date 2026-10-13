"""HUD coin and counter font. Run from the project root:  python3 tools/make_coin_art.py

  assets/ui/coin_spin.png    12 frames of 16 x 22 (the same size as the bottle sprite): the coin turning around once
  assets/ui/coin_digits.png  11 glyphs of 12 x 16: digits 0-9 and an "x", a chunky orange-gradient pixel font
                             (silver "x") with a dark outline, like the coin counter in the reference picture
The coin looks like the coin you pick up (gold disc, darker ring, dark outline, highlight).
"""
import math
import numpy as np
from PIL import Image

OUT = (30, 20, 40, 255)
GOLD, RING, HI, SHADE = (250, 205, 40, 255), (200, 150, 20, 255), (255, 245, 170, 255), (222, 172, 28, 255)

# ------------------------------------------------------------------ the coin (16 x 22, a slightly tall oval)
W, H = 16, 22
cx, cy, ax, by = 7.5, 10.5, 7.5, 10.5
def dist(x, y): return ((x - cx) / ax) ** 2 + ((y - cy) / by) ** 2
base = np.zeros((H, W, 4), np.uint8)
inside = np.zeros((H, W), bool)
for y in range(H):
    for x in range(W):
        if dist(x, y) <= 1.0: inside[y, x] = True
edge = np.zeros_like(inside)
for y in range(H):
    for x in range(W):
        if inside[y, x]:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < W and 0 <= ny < H) or not inside[ny, nx]: edge[y, x] = True
for y in range(H):
    for x in range(W):
        if not inside[y, x]: continue
        d = dist(x, y)
        if edge[y, x]: base[y, x] = OUT
        elif 0.30 <= d <= 0.50: base[y, x] = RING                  # the darker ring inside the face, like the pickup coin
        else: base[y, x] = GOLD
        if not edge[y, x] and d > 0.72 and (x - cx) + (y - cy) > 6: base[y, x] = SHADE   # a touch darker at the lower right rim
for (x, y) in [(3, 5), (4, 4), (4, 5), (3, 6), (5, 3)]: base[y, x] = HI                 # highlight, upper left
coin = Image.fromarray(base)

def squeezed(img, width):
    """Horizontal squeeze with exact edge columns (nearest neighbour would lose the outline)."""
    src = np.array(img); out = np.zeros((H, width, 4), np.uint8)
    for x in range(width):
        sx = round(x * (W - 1) / max(width - 1, 1))
        out[:, x] = src[:, sx]
    return Image.fromarray(out)

def edge_on():
    img = np.zeros((H, W, 4), np.uint8)
    for y in range(H):
        half = 1 if y in (0, H - 1) else 1
        x0 = 7
        if y in (0, H - 1):
            img[y, 7:9] = OUT
        else:
            img[y, 6] = OUT; img[y, 9] = OUT
            img[y, 7] = RING; img[y, 8] = GOLD
    for y in (4, 5, 6): img[y, 8] = HI
    return Image.fromarray(img)

sheet = Image.new("RGBA", (W * 12, H), (0, 0, 0, 0))
for k in range(12):
    theta = k * 30
    c = math.cos(math.radians(theta))
    wfac = abs(c)
    if wfac < 0.2:
        frame = edge_on()
    else:
        width = max(2, round(W * wfac))
        img = squeezed(coin, width)
        if c < 0: img = img.transpose(Image.FLIP_LEFT_RIGHT)        # the back side: the highlight is on the other side
        frame = Image.new("RGBA", (W, H), (0, 0, 0, 0)); frame.paste(img, ((W - width) // 2, 0))
    sheet.paste(frame, (k * W, 0))
sheet.save("assets/ui/coin_spin.png")

# ------------------------------------------------------------------ the digit font (5x7 bitmaps, doubled, with a gradient and outline)
FONT = {
 "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
 "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
 "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
 "3": [".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."],
 "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
 "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
 "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
 "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
 "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
 "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
 "x": ["#...#", ".#.#.", "..#..", ".#.#.", "#...#"],
}
GW, GH = 12, 16
DIGIT_GRADIENT = [(255, 238, 120), (255, 238, 120), (255, 214, 70), (255, 190, 50), (255, 160, 36), (255, 136, 30), (244, 104, 26),
                  (236, 84, 22), (222, 64, 20), (206, 46, 20), (190, 34, 22), (170, 28, 24), (150, 24, 24), (150, 24, 24)]
DIGIT_OUT = (92, 14, 10, 255); DIGIT_HI = (255, 252, 200, 255)
X_GRADIENT = [(236, 236, 248), (222, 222, 240), (206, 206, 228), (186, 186, 214), (166, 166, 198), (146, 146, 182),
              (128, 128, 166), (112, 112, 150), (100, 100, 138), (100, 100, 138)]
X_OUT = (44, 36, 70, 255); X_HI = (255, 255, 255, 255)

def glyph(ch):
    rows = FONT[ch]; w5, h7 = 5, len(rows)
    mask = np.zeros((h7 * 2, w5 * 2), bool)
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == "#": mask[y * 2:y * 2 + 2, x * 2:x * 2 + 2] = True
    gh, gw = mask.shape
    tile = np.zeros((GH, GW, 4), np.uint8)
    ox, oy = (GW - gw) // 2, 1 + (GH - 2 - gh) // 2 + (3 if ch == "x" else 0)
    grad, outc, hic = (X_GRADIENT, X_OUT, X_HI) if ch == "x" else (DIGIT_GRADIENT, DIGIT_OUT, DIGIT_HI)
    solid = np.zeros((GH, GW), bool)
    for y in range(gh):
        for x in range(gw):
            if mask[y, x]:
                solid[oy + y, ox + x] = True
                col = grad[min(y, len(grad) - 1)]
                tile[oy + y, ox + x] = (*col, 255)
                if (x == 0 or not mask[y, x - 1]) and (y < gh - 2): tile[oy + y, ox + x] = hic      # bright left edge of every stroke
    for y in range(GH):                                                                                  # outline
        for x in range(GW):
            if solid[y, x]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < GW and 0 <= ny < GH and solid[ny, nx]: tile[y, x] = outc; break
    return Image.fromarray(tile)

digits = Image.new("RGBA", (GW * 11, GH), (0, 0, 0, 0))
for i, ch in enumerate("0123456789x"):
    digits.paste(glyph(ch), (i * GW, 0))
digits.save("assets/ui/coin_digits.png")

# ------------------------------------------------------------------ preview
S = 6
prev = Image.new("RGBA", (W * 12 * S // 2 + 40, H * S + GH * S + 40), (60, 90, 150, 255))
sp = sheet.resize((W * 12 * S // 2, H * S // 2), Image.NEAREST); prev.paste(sp, (10, 10), sp)
text = "x999"
line = Image.new("RGBA", (GW * len(text), GH), (0, 0, 0, 0))
for i, ch in enumerate(text): line.paste(digits.crop((("0123456789x".index(ch)) * GW, 0, ("0123456789x".index(ch)) * GW + GW, GH)), (i * GW, 0))
cf = coin.resize((W * S, H * S), Image.NEAREST); prev.paste(cf, (10, H * S // 2 + 24), cf)
ln = line.resize((line.width * S, line.height * S), Image.NEAREST); prev.paste(ln, (10 + W * S + 12, H * S // 2 + 24 + (H * S - GH * S) // 2), ln)
prev.save("tools/previews/coin_art.png")
print("coin art generated")
