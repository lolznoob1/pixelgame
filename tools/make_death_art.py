"""Death animations: every character swells, cracks and bursts into red goo and chunks of itself.
Run from the project root:  python3 tools/make_death_art.py
Writes assets/characters/death/<name>_death_heavy.png (heavy weapons: the explosion): 8 frames of 48x48 side by side (384x48).
The persistent puddle on the ground is drawn by the game (weapons/goo_splat.gd), the last frame just matches it.
Preview: tools/previews/death_sheets_heavy.png
"""
import math, os, random
import numpy as np
from PIL import Image

S = 48
CX, CY = 24, 23          # center of the character in the frame
GROUND = 32              # y of the feet
FRAMES = 8

GOO_HI, GOO, GOO_MID, GOO_DK, GOO_OUT = (244, 78, 78), (206, 28, 42), (160, 18, 34), (112, 12, 28), (62, 6, 18)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5

CHARS = {
    "player": ("assets/characters/hooded_warrior_spritesheet_128x144.png", (0, 0)),
    "enemy1": ("assets/characters/habbo_spritesheet_64x80.png", (0, 0)),
    "enemy2": ("assets/characters/habbo_characters_spritesheet_320x160.png", (0, 112)),
    "enemy3": ("assets/characters/habbo_characters_spritesheet_320x160.png", (0, 48)),
}


def blank():
    return np.zeros((S, S, 4), np.uint8)


def put(img, x, y, c, a=255):
    x, y = int(x), int(y)
    if 0 <= x < S and 0 <= y < S:
        img[y, x] = (c[0], c[1], c[2], a)


def square(img, x, y, size, c):
    for dy in range(size):
        for dx in range(size):
            put(img, x + dx, y + dy, c)


def blob_field(shape_blobs):
    """Union of discs -> field in 0..1 (1 = deep inside), shaped (S, S)."""
    ys, xs = np.mgrid[0:S, 0:S]
    field = np.zeros((S, S))
    for bx, by, br in shape_blobs:
        d = np.hypot(xs - bx, ys - by)
        field = np.maximum(field, 1.0 - d / max(br, 0.1))
    return field


def paint_goo(img, field, flat=1.0, gap=0.0):
    """Shades a blob field with the goo palette (dithered bands) and a dark outline."""
    ys, xs = np.mgrid[0:S, 0:S]
    f = field + BAYER[ys % 4, xs % 4] * 0.12
    if gap > 0:                                   # holes: the cloud is breaking up
        f = f - gap * (0.5 + 0.5 * np.sin(xs * 1.7 + ys * 2.3))
    inside = (field > 0.0) & (f > 0.0)       # the dither only roughens the edge, it must not create goo elsewhere
    bands = [(0.62, GOO_HI), (0.38, GOO), (0.18, GOO_MID), (0.0, GOO_DK)]
    for t, c in reversed(bands):
        img[inside & (f > t)] = (*c, 255)
    # outline
    ins = inside
    edge = np.zeros_like(ins)
    edge[1:, :] |= ins[:-1, :]; edge[:-1, :] |= ins[1:, :]; edge[:, 1:] |= ins[:, :-1]; edge[:, :-1] |= ins[:, 1:]
    img[edge & ~ins] = (*GOO_OUT, 255)


def tint(c, toward, amount):
    return tuple(int(c[i] * (1 - amount) + toward[i] * amount) for i in range(3))


def make_sheet(name, src, pos, seed):
    rng = random.Random(seed)
    sheet = Image.open(src).convert("RGBA").crop((pos[0], pos[1], pos[0] + 16, pos[1] + 16))
    px = np.array(sheet)
    pal = [tuple(px[y, x][:3]) for y in range(16) for x in range(16) if px[y, x][3] > 0]

    # ---- the pieces that fly: chunks of the character mixed with goo
    chunks = []
    for i in range(26):
        ang = rng.uniform(0, math.tau)
        speed = rng.uniform(13, 24)
        size = rng.choice([1, 1, 2, 2, 3])
        col = rng.choice(pal) if rng.random() < 0.5 else rng.choice([GOO, GOO_MID, GOO_HI, GOO_DK])
        chunks.append((ang, speed, size, col, rng.uniform(0.6, 1.3)))
    droplets = [(rng.uniform(0, math.tau), rng.uniform(10, 27)) for _ in range(18)]
    cloud = []   # blobs of the goo cloud: (angle, radius fraction, size fraction)
    for i in range(9):
        cloud.append((rng.uniform(0, math.tau), rng.uniform(0.0, 0.7), rng.uniform(0.35, 0.6)))
    splat_spots = [(rng.uniform(0, math.tau), rng.uniform(0.2, 1.0), rng.uniform(0.15, 0.35)) for _ in range(10)]
    crack_angles = [rng.uniform(0, math.tau) for _ in range(6)]

    frames = []
    for k in range(FRAMES):
        img = blank()

        if k <= 1:
            # the character swells (and flashes), then cracks open
            scale = 1.0 if k == 0 else 1.35
            size = int(round(16 * scale))
            big = Image.fromarray(px).resize((size, size), Image.NEAREST)
            bx, by = CX - size // 2 + (1 if k == 0 else 0), CY - size // 2
            arr = np.array(big)
            for yy in range(size):
                for xx in range(size):
                    c = arr[yy, xx]
                    if c[3] == 0: continue
                    col = tint(tuple(c[:3]), (255, 255, 255), 0.75) if k == 0 else tint(tuple(c[:3]), GOO, 0.55)
                    put(img, bx + xx, by + yy, col)
            if k == 1:                                            # dark cracks radiating from the middle
                for a in crack_angles:
                    for r in range(0, 11):
                        put(img, CX + math.cos(a) * r + rng.choice([0, 0, 1]), CY + math.sin(a) * r, GOO_OUT)
        else:
            t = (k - 2) / 5.0                                     # 0..1 over frames 2..7
            # --- goo cloud
            cloud_r = [12, 17, 20, 18, 14, 0][min(k - 2, 5)]
            if cloud_r > 0:
                blobs = [(CX, CY, cloud_r * 0.6)]
                for ang, rad, sz in cloud:
                    blobs.append((CX + math.cos(ang) * cloud_r * rad, CY + math.sin(ang) * cloud_r * rad * 0.85, cloud_r * sz))
                paint_goo(img, blob_field(blobs), gap=0.0 if k <= 4 else 0.25 * (k - 4))
                if k == 2:                                        # the white-hot core of the burst
                    for yy in range(S):
                        for xx in range(S):
                            if math.hypot(xx - CX, yy - CY) < 4: put(img, xx, yy, (255, 214, 214))

            # --- ground puddle (grows over the last frames)
            if k >= 5:
                pr = [9, 15, 19][k - 5]
                blobs = [(CX, GROUND, pr * 0.55)]
                for ang, rad, sz in splat_spots:
                    blobs.append((CX + math.cos(ang) * pr * rad * 1.1, GROUND + math.sin(ang) * pr * rad * 0.28, pr * sz * 0.5))
                puddle = blank()
                field = blob_field(blobs)
                ys, xs = np.mgrid[0:S, 0:S]
                field = np.where(np.abs(ys - GROUND) < pr * 0.42, field, 0)       # flatten: it lies on the ground
                paint_goo(puddle, field)
                mask = puddle[..., 3] > 0
                img[mask] = puddle[mask]

            # --- chunks flying out, falling, landing
            ease = [0.45, 0.75, 1.0, 1.12, 1.18, 1.2][min(k - 2, 5)]
            for ang, speed, size, col, grav in chunks:
                x = CX + math.cos(ang) * speed * ease
                y = CY + math.sin(ang) * speed * ease * 0.9
                if k >= 4:
                    y += grav * 2.2 * (k - 3) ** 2
                landed = y >= GROUND + 1 or k >= 7
                if landed:
                    y = GROUND + (ang % 3) - 1
                    col = tint(col, GOO_MID, 0.6)
                square(img, x, y, size + (1 if landed else 0), col)

            # --- small droplets
            if 3 <= k <= 6:
                for ang, dist in droplets:
                    x = CX + math.cos(ang) * dist * (0.6 + 0.12 * (k - 2))
                    y = CY + math.sin(ang) * dist * 0.8 * (0.6 + 0.12 * (k - 2)) + (k - 3) * 2
                    put(img, x, y, GOO if (ang * 10) % 2 < 1 else GOO_HI)
        frames.append(Image.fromarray(img))
    return frames


os.makedirs("assets/characters/death", exist_ok=True)
os.makedirs("tools/previews", exist_ok=True)
all_frames = {}
for i, (name, (src, pos)) in enumerate(CHARS.items()):
    frames = make_sheet(name, src, pos, seed=100 + i)
    sheet = Image.new("RGBA", (S * FRAMES, S), (0, 0, 0, 0))
    for k, f in enumerate(frames):
        sheet.paste(f, (k * S, 0))
    sheet.save(f"assets/characters/death/{name}_death_heavy.png")
    all_frames[name] = sheet

Z = 3
prev = Image.new("RGBA", (S * FRAMES * Z, S * len(CHARS) * Z), (150, 154, 150, 255))
for r, (name, sheet) in enumerate(all_frames.items()):
    big = sheet.resize((sheet.width * Z, sheet.height * Z), Image.NEAREST)
    prev.paste(big, (0, r * S * Z), big)
prev.save("tools/previews/death_sheets_heavy.png")
print("death sheets generated:", list(all_frames))
