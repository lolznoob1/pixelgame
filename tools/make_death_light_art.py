"""Death for LIGHT weapons (sword, AK-47): the character is hit, tips over and collapses into a bloody heap,
while a fine mist of tiny red droplets sprays over a wide area. (Heavy weapons: the explosion in make_death_art.py.)
Run from the project root:  python3 tools/make_death_light_art.py
Writes assets/characters/death/<name>_death_light.png: 8 frames of 48x48 (384x48).
The sheet always falls toward +x; the game flips it to fall in the direction of the hit.
The last frame (a corpse) stays on the ground for a while. Preview: tools/previews/death_light_sheets.png
"""
import math, os, random
import numpy as np
from PIL import Image

S = 48
CX, FEET = 24, 31          # center x of the character, y of the feet (the pivot of the fall)
GROUND = 33
FRAMES = 8

BRIGHT, MID, DARK, BROWN = (238, 42, 50), (192, 26, 38), (132, 14, 28), (112, 40, 34)
POOL_DK, POOL_MID, POOL, POOL_HI, OUTL = (92, 8, 22), (136, 12, 28), (176, 20, 34), (224, 60, 66), (52, 10, 18)
CHARS = {
    "player": ("assets/characters/hooded_warrior_spritesheet_128x144.png", (0, 0)),
    "enemy1": ("assets/characters/habbo_spritesheet_64x80.png", (0, 0)),
    "enemy2": ("assets/characters/habbo_characters_spritesheet_320x160.png", (0, 112)),
    "enemy3": ("assets/characters/habbo_characters_spritesheet_320x160.png", (0, 48)),
}


def new_canvas():
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def put(img, x, y, c, a=255):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < S and 0 <= y < S:
        img.putpixel((x, y), (c[0], c[1], c[2], a))


def blend(img, color, amount):
    a = np.array(img).astype(float)
    m = a[..., 3] > 0
    for i in range(3):
        a[..., i][m] = a[..., i][m] * (1 - amount) + color[i] * amount
    return Image.fromarray(a.astype(np.uint8))


def ellipse(img, cx, cy, rx, ry, color_fn):
    for y in range(S):
        for x in range(S):
            d = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
            if d <= 1.0:
                put(img, x, y, color_fn(d))


def outline_mask(img, color):
    a = np.array(img); alpha = a[..., 3] > 0
    out = a.copy()
    for y in range(S):
        for x in range(S):
            if alpha[y, x]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < S and 0 <= ny < S and alpha[ny, nx]:
                    out[y, x] = (*color, 255); break
    return Image.fromarray(out)


def pool(img, rx, ry):
    """A blood pool lying on the ground."""
    layer = new_canvas()
    ellipse(layer, CX + 3, GROUND - 1, rx, ry, lambda d: POOL_DK if d > 0.72 else (POOL_MID if d > 0.38 else POOL))
    for (dx, dy) in [(-2, -1), (-1, -1), (0, 0)]:
        put(layer, CX + 1 + dx * 2, GROUND - 2 + dy, POOL_HI)       # wet shine
    layer = outline_mask(layer, OUTL)
    img.alpha_composite(layer)


def make_sheet(name, src, pos, seed):
    rng = random.Random(seed)
    sprite = Image.open(src).convert("RGBA").crop((pos[0], pos[1], pos[0] + 16, pos[1] + 16))
    px = np.array(sprite)
    pal = [tuple(px[y, x][:3]) for y in range(16) for x in range(16) if px[y, x][3] > 0]
    body = new_canvas(); body.paste(sprite, (CX - 8, FEET - 15))

    # ---- the fine spray: many tiny droplets flying out of the chest, landing on the ground
    drops = []
    for i in range(70):
        ang = math.radians(rng.uniform(-82, 38))
        speed = rng.uniform(7, 30)
        size = rng.choices([(1, 1), (2, 1), (2, 2)], weights=[75, 15, 10])[0]
        col = rng.choice([BRIGHT, BRIGHT, MID, MID, DARK, BROWN])
        drops.append((math.cos(ang) * speed, math.sin(ang) * speed, size, col, rng.uniform(0, 0.25)))
    sx, sy = CX + 1, FEET - 9       # the wound (chest)

    def draw_drops(img, k, landed_layer=None):
        t0 = k * 0.62
        for vx, vy, size, col, delay in drops:
            t = t0 - delay
            if t < 0: continue
            x = sx + vx * t; y = sy + vy * t + 0.5 * 26 * t * t
            if y >= GROUND + 1:                                     # it landed: a flat dot on the ground
                x = sx + vx * (math.sqrt(max(0.0, (GROUND - sy) * 2 / 26 + (vy / 26) ** 2)) + vy / 26) if False else x
                y = GROUND + (vx * 7) % 2
                col = tuple(int(c * 0.8) for c in col)
            for dx in range(size[0]):
                for dy in range(size[1]):
                    put(img, x + dx, y + dy, col)

    def spurt(img, k):                                              # bigger blobs at the wound while it is fresh
        if k > 3: return
        for i in range(5 - k):
            a = math.radians(rng.uniform(-60, 30)); r = 2 + k * 3 + rng.uniform(0, 3)
            for dx in (0, 1):
                for dy in (0, 1): put(img, sx + math.cos(a) * r + dx, sy + math.sin(a) * r + dy, BRIGHT if i % 2 else MID)

    def heap(img, size_x, size_y):
        """The corpse: the character's pieces jumbled into a flat heap, streaked with blood."""
        layer = new_canvas()
        hx, hy = CX + 4, GROUND - 3
        for i in range(34):
            a = rng.uniform(0, math.tau); r = math.sqrt(rng.uniform(0, 1))
            cx_, cy_ = hx + math.cos(a) * size_x * r, hy + math.sin(a) * size_y * r
            col = rng.choice(pal) if rng.random() < 0.55 else rng.choice([MID, DARK, BRIGHT, BROWN])
            rad = rng.choice([1, 1, 2])
            for dy in range(-rad, rad + 1):
                for dx in range(-rad, rad + 1):
                    if dx * dx + dy * dy <= rad * rad + 1: put(layer, cx_ + dx, cy_ + dy, col)
        # blood streaks across it
        for i in range(10): put(layer, hx + rng.uniform(-size_x, size_x), hy + rng.uniform(-size_y, size_y), rng.choice([BRIGHT, MID]))
        layer = outline_mask(layer, OUTL)
        # keep only a heap-shaped silhouette (clip anything that strayed too far)
        a = np.array(layer)
        for y in range(S):
            for x in range(S):
                if ((x - hx) / (size_x + 3)) ** 2 + ((y - hy) / (size_y + 3)) ** 2 > 1.0: a[y, x, 3] = 0
        img.alpha_composite(Image.fromarray(a))
        for (dx, dy) in [(-3, -2), (1, -3), (4, -1)]: put(img, hx + dx, hy + dy, (255, 196, 188))     # a bit of shine on the flesh

    frames = []
    for k in range(FRAMES):
        img = new_canvas()
        if k <= 4:
            # --- the body is hit and falls (clockwise around the feet: toward +x)
            if k == 0:
                f = blend(body, (255, 255, 255), 0.7)
                shifted = new_canvas(); shifted.paste(f, (-1, 0)); f = shifted
                put(f, sx, sy, BRIGHT); put(f, sx + 1, sy + 1, MID); put(f, sx - 1, sy, DARK)
            else:
                angle = [0, 10, 32, 62, 90][k]
                f = body.rotate(-angle, resample=Image.NEAREST, center=(CX, FEET))
                if k == 4:                                       # lying: flatten it onto the ground
                    a = np.array(f); flat = np.zeros_like(a)
                    for y in range(S):
                        ny = int(round(GROUND - (GROUND - y) * 0.62))
                        if 0 <= ny < S: flat[ny] = np.where(a[y][..., 3:4] > 0, a[y], flat[ny])
                    f = Image.fromarray(flat)
                if k >= 3: f = blend(f, MID, 0.18 * (k - 2))
            if k >= 4: pool(img, 6 + (k - 4) * 3, 2.2)
            img.alpha_composite(f)
        elif k == 5:
            # --- the body sinks together, the pool spreads
            pool(img, 11, 3.6)
            a = np.array(blend(body.rotate(-90, resample=Image.NEAREST, center=(CX, FEET)), MID, 0.5))
            flat = np.zeros_like(a)
            for y in range(S):
                ny = int(round(GROUND - (GROUND - y) * 0.42))
                if 0 <= ny < S: flat[ny] = np.where(a[y][..., 3:4] > 0, a[y], flat[ny])
            img.alpha_composite(Image.fromarray(flat))
        else:
            # --- the corpse: a heap on a big pool
            pool(img, [13, 15][k - 6], [4.2, 4.8][k - 6])
            heap(img, 8 if k == 6 else 9, 3.2 if k == 6 else 3.6)
        spurt(img, k)
        draw_drops(img, k)
        frames.append(img)
    return frames


os.makedirs("assets/characters/death", exist_ok=True)
os.makedirs("tools/previews", exist_ok=True)
sheets = {}
for i, (name, (src, pos)) in enumerate(CHARS.items()):
    frames = make_sheet(name, src, pos, seed=300 + i)
    sheet = Image.new("RGBA", (S * FRAMES, S), (0, 0, 0, 0))
    for k, f in enumerate(frames): sheet.paste(f, (k * S, 0))
    sheet.save(f"assets/characters/death/{name}_death_light.png")
    sheets[name] = sheet
Z = 3
prev = Image.new("RGBA", (S * FRAMES * Z, S * len(CHARS) * Z), (150, 154, 150, 255))
for r, (name, sh) in enumerate(sheets.items()):
    big = sh.resize((sh.width * Z, sh.height * Z), Image.NEAREST); prev.paste(big, (0, r * S * Z), big)
prev.save("tools/previews/death_light_sheets.png")
print("light death sheets generated")
