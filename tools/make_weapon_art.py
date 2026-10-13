"""Generates the rocket launcher art. Run from the project root:  python3 tools/make_weapon_art.py

  assets/weapons/rocket_launcher.png   16x16 icon (also used for the pickup and the hotbar)
  assets/weapons/sword.png             16x16 icon for the hotbar
  assets/weapons/rocket_frames.png     3 frames of the flying rocket, 14x7 each
  assets/weapons/explosion_sheet.png   9 frames, 128x128 each
  assets/characters/player_rocket.png  the player holding the launcher: row 0 idle (4 frames), row 1 fire (4 frames)
Previews are written to tools/previews/.
"""
import math, os
import numpy as np
from PIL import Image

OUT = (30, 20, 40, 255)

def outline(img, color=OUT):
    a = np.array(img); alpha = a[..., 3] > 0; out = a.copy(); h, w = alpha.shape
    for y in range(h):
        for x in range(w):
            if alpha[y, x]: continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and alpha[ny, nx]: out[y, x] = color; break
    return Image.fromarray(out).copy()

# ------------------------------------------------------------------ launcher (side view, facing right)
TUBE, TUBE_L, TUBE_D = (92, 106, 66, 255), (122, 138, 88, 255), (60, 70, 46, 255)
RIM = (44, 48, 36, 255); GRIP = (96, 66, 50, 255); METAL = (150, 156, 172, 255)
NOSE, NOSE_D = (214, 72, 52, 255), (150, 44, 36, 255)

def draw_launcher(img, x0, y0, loaded=True, flash=False):
    """Tube x0..x0+9 (3 px thick, rows y0..y0+2), warhead x0+10..x0+12, rear flare, grip and sight."""
    px = img.load(); W, H = img.size
    def put(x, y, c):
        if 0 <= x < W and 0 <= y < H: px[x, y] = c
    for x in range(x0, x0 + 10):
        put(x, y0, TUBE_L); put(x, y0 + 1, TUBE); put(x, y0 + 2, TUBE_D)
    for y in range(y0 - 1, y0 + 4):                 # rear flare
        put(x0, y, RIM)
    put(x0 + 1, y0 - 1, TUBE_D); put(x0 + 1, y0 + 3, TUBE_D)
    put(x0 + 9, y0, RIM); put(x0 + 9, y0 + 1, RIM); put(x0 + 9, y0 + 2, RIM)   # front rim
    put(x0 + 4, y0 - 1, RIM); put(x0 + 5, y0 - 1, METAL)                        # sight
    put(x0 + 5, y0 + 3, GRIP); put(x0 + 5, y0 + 4, GRIP); put(x0 + 6, y0 + 3, GRIP)  # grip
    if loaded:                                       # the rocket's nose sticks out of the tube
        for (dx, dy, c) in [(10, 0, NOSE_D), (10, 1, NOSE), (10, 2, NOSE_D), (11, 1, NOSE), (11, 0, NOSE_D), (11, 2, NOSE_D), (12, 1, NOSE)]:
            put(x0 + dx, y0 + dy, c)
    if flash:                                        # muzzle flash at the front
        for (dx, dy, c) in [(10, 1, (255, 250, 210, 255)), (11, 1, (255, 220, 100, 255)), (12, 1, (255, 160, 50, 255)),
                            (11, 0, (255, 160, 50, 255)), (11, 2, (255, 160, 50, 255)), (13, 1, (255, 200, 80, 255))]:
            put(x0 + dx, y0 + dy, c)

# ---- icon
icon = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
draw_launcher(icon, 1, 6)
icon = outline(icon)
os.makedirs("assets/weapons", exist_ok=True); os.makedirs("tools/previews", exist_ok=True)
icon.save("assets/weapons/rocket_launcher.png"); icon.save("assets/items/rocket_launcher.png")

# ---- sword icon (diagonal)
sw = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); sp = sw.load()
for i in range(9):                                   # blade
    sp[4 + i, 11 - i] = (205, 212, 224, 255)
    if i > 0 and i < 8: sp[3 + i, 11 - i] = (150, 158, 176, 255)
sp[13, 2] = (235, 240, 250, 255); sp[12, 3] = (235, 240, 250, 255)   # tip highlight
for (x, y) in [(3, 11), (4, 12), (5, 10), (2, 10), (4, 10), (3, 12)]: sp[x, y] = (214, 168, 60, 255)  # guard
for (x, y) in [(2, 13), (1, 14)]: sp[x, y] = (110, 70, 44, 255)                                        # hilt
sp[0, 15] = (214, 168, 60, 255)
sw = outline(sw); sw.save("assets/weapons/sword.png")

# ------------------------------------------------------------------ rocket frames (3 x 14x7)
frames = Image.new("RGBA", (42, 7), (0, 0, 0, 0))
def rocket(frame):
    im = Image.new("RGBA", (14, 7), (0, 0, 0, 0)); p = im.load()
    for x in range(4, 11):
        p[x, 2] = (205, 208, 218, 255); p[x, 3] = (160, 164, 178, 255); p[x, 4] = (120, 124, 140, 255)
    for (x, y) in [(11, 2), (11, 3), (11, 4), (12, 3), (13, 3)]: p[x, y] = NOSE
    p[11, 2] = NOSE_D; p[11, 4] = NOSE_D
    for (x, y) in [(4, 1), (5, 1), (4, 5), (5, 5), (3, 0), (3, 6)]: p[x, y] = NOSE_D       # fins
    body = outline(im)
    q = body.load()
    flame = [[(3, 3, (255, 245, 200)), (2, 3, (255, 210, 90)), (1, 3, (255, 150, 40)), (0, 3, (230, 90, 35)),
              (2, 2, (255, 190, 70)), (2, 4, (255, 190, 70)), (1, 2, (255, 130, 40)), (1, 4, (255, 130, 40))],
             [(3, 3, (255, 245, 200)), (2, 3, (255, 210, 90)), (1, 3, (255, 150, 40)),
              (2, 2, (255, 170, 60)), (2, 4, (255, 170, 60))],
             [(3, 3, (255, 255, 235)), (2, 3, (255, 230, 120)), (1, 3, (255, 170, 50)), (0, 3, (255, 120, 40)), (0, 2, (230, 90, 35)),
              (2, 2, (255, 200, 80)), (2, 4, (255, 200, 80)), (1, 2, (255, 140, 45)), (1, 4, (255, 140, 45))]][frame]
    for (x, y, c) in flame: q[x, y] = (*c, 255)
    return body
for i in range(3): frames.paste(rocket(i), (i * 14, 0))
frames.save("assets/weapons/rocket_frames.png")

# ------------------------------------------------------------------ explosion (9 frames, 128x128)
N, S = 9, 128
RADII = [10, 24, 36, 44, 48, 48, 46, 43, 40]
rs = np.random.RandomState(11)
PHASE = rs.uniform(0, math.tau, 6)
BAYER = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.5
ys, xs = np.mgrid[0:S, 0:S]
cx = cy = S / 2 - 0.5
dx, dy = xs - cx, ys - cy
rr = np.hypot(dx, dy); th = np.arctan2(dy, dx)
bayer = np.tile(BAYER, (S // 4, S // 4))

def noise(freq, phase, speed, i):
    return np.sin(freq * th + phase + speed * i)

def explosion_frame(i):
    age = i / (N - 1)
    R = RADII[i]
    wob = (0.09 * noise(2, PHASE[0], 0.8, i) + 0.06 * noise(3, PHASE[1], -0.6, i) + 0.045 * noise(5, PHASE[2], 1.1, i))
    boundary = R * (1.0 + wob)
    s = rr / np.maximum(boundary, 1)
    heat = (1.0 - s) * 1.5 * (1.0 - 0.72 * age) + bayer * 0.10
    img = np.zeros((S, S, 4), np.uint8)
    inside = s < 1.0
    bands = [(0.78, (255, 252, 215)), (0.60, (255, 226, 105)), (0.43, (255, 160, 52)), (0.27, (232, 92, 36)),
             (0.14, (160, 48, 36)), (-9.0, (110, 52, 40))]
    for thresh, col in reversed(bands):
        m = inside & (heat > thresh)
        img[m] = (*col, 255)
    # a little dark smoke around the fire in the later frames
    if i >= 5:
        smoke_r = boundary * (1.0 + 0.07 * age)
        wisp = 0.5 + 0.5 * np.sin(7 * th + PHASE[3] + 0.9 * i) * np.sin(4 * th + PHASE[4] - 0.5 * i)
        sm = (rr < smoke_r) & (~inside) & (wisp + bayer * 0.35 > 0.55)
        img[sm] = (*(74, 62, 68), 255)
    # embers flying out
    if 1 <= i <= 5:
        er = np.random.RandomState(100 + i)
        for _ in range(14):
            a = er.uniform(0, math.tau); d = R * er.uniform(1.12, 1.38)
            x, y = int(cx + math.cos(a) * d), int(cy + math.sin(a) * d)
            if 0 <= x < S and 0 <= y < S: img[y, x] = (255, 214, 96, 255); 
    out = Image.fromarray(img)
    # dark outline around the whole blob
    return outline(out, (46, 28, 32, 255))

sheet = Image.new("RGBA", (N * S, S), (0, 0, 0, 0))
for i in range(N): sheet.paste(explosion_frame(i), (i * S, 0))
sheet.save("assets/weapons/explosion_sheet.png")

# ------------------------------------------------------------------ player holding the launcher
pl = Image.open("assets/characters/hooded_warrior_spritesheet_128x144.png").convert("RGBA")
HOOD = {(8, 8, 12), (30, 30, 40), (64, 64, 84), (12, 12, 18), (84, 84, 100), (92, 66, 50)}
def frame_without_rifle(i):
    fr = pl.crop((i * 16, 96, i * 16 + 16, 112)); px = fr.load()
    for y in range(16):
        for x in range(16):
            c = px[x, y]
            if c[3] == 0 or c[:3] in HOOD: continue            # transparent or part of the hooded body
            px[x, y] = (30, 30, 40, 255) if x <= 9 else (0, 0, 0, 0)   # rifle pixel: body behind it, or nothing
    return fr
def top_row(fr):
    a = np.array(fr)[..., 3] > 0
    return int(np.argmax(a.any(axis=1)))
sheet_p = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
tops = [top_row(frame_without_rifle(i)) for i in range(4)]
for i in range(4):
    bob = tops[i] - tops[0]
    base = frame_without_rifle(i)
    idle = base.copy(); draw_launcher(idle, 3, 8 + bob, loaded=True)
    sheet_p.paste(idle, (i * 16, 0))
    # fire: loaded -> flash + recoil -> empty tube settles
    fire = base.copy()
    recoil = [0, 2, 1, 0][i]
    draw_launcher(fire, 3 - recoil, 8 + bob, loaded=(i == 0), flash=(i == 1))
    if i in (1, 2):                                    # a puff of backblast smoke at the shoulder
        for (x, y) in ([(0, 9), (0, 10), (1, 11)] if i == 1 else [(0, 10)]): fire.putpixel((x, y), (190, 190, 196, 255))
    sheet_p.paste(fire, (i * 16, 16))
sheet_p.save("assets/characters/player_rocket.png")

# ------------------------------------------------------------------ previews
S1 = 6
prev = Image.new("RGBA", (16 * S1 * 2 + 60 + 42 * S1, 16 * S1 * 2 + 20), (70, 70, 80, 255))
for k, im in enumerate((icon, sw)):
    b = im.resize((16 * S1, 16 * S1), Image.NEAREST); prev.paste(b, (8 + k * (16 * S1 + 10), 8), b)
fr = frames.resize((42 * S1, 7 * S1), Image.NEAREST); prev.paste(fr, (16 * S1 * 2 + 40, 20), fr)
prev.save("tools/previews/weapon_icons.png")
big = sheet_p.resize((64 * 8, 32 * 8), Image.NEAREST); bg = Image.new("RGBA", big.size, (70, 70, 80, 255)); bg.paste(big, (0, 0), big)
bg.save("tools/previews/player_rocket.png")
ex = Image.new("RGBA", (N * S // 2, S // 2), (70, 70, 80, 255))
small = sheet.resize((N * S // 2, S // 2), Image.NEAREST); ex.paste(small, (0, 0), small); ex.save("tools/previews/explosion.png")
print("art generated")
