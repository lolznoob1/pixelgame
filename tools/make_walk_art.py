"""Walking animations for the armed player (side view). Run from the project root:  python3 tools/make_walk_art.py

Reads  assets/characters/hooded_warrior_spritesheet_128x144.png  (row y=96: idle with the AK-47)
and    assets/characters/player_rocket.png                      (row 0: idle with the rocket launcher)
Writes assets/characters/player_walk_armed.png                  64x32: row 0 = walk_gun, row 1 = walk_rocket (4 frames each)
Preview: tools/previews/player_walk_armed.png

The robe hides the legs, so a walk cycle is: the body bobs up and down by one pixel and the boots step
(wide stride, passing with one boot lifted, wide stride, passing with the other boot lifted).
"""
import os
import numpy as np
from PIL import Image

BOOT = (92, 66, 50)
ROBE = (30, 30, 40, 255)
BOOT_PX = (92, 66, 50, 255)

# boots per phase: list of (x, y) pixels (each boot is 2 px wide)
PHASES = [
    [(3, 15), (4, 15), (9, 15), (10, 15)],          # wide stride
    [(7, 15), (8, 15), (5, 14), (6, 14)],           # passing, back boot lifted and swinging forward
    [(3, 15), (4, 15), (9, 15), (10, 15)],          # wide stride (the other leg forward)
    [(5, 15), (6, 15), (8, 14), (9, 14)],           # passing, front boot lifted
]
BOB = [0, 1, 0, 1]   # body goes up by 1 px while passing


def remove_boots(frame):
    img = frame.copy(); px = img.load()
    for y in (14, 15):
        for x in range(16):
            c = px[x, y]
            if c[3] > 0 and c[:3] == BOOT:
                above = px[x, y - 1] if y > 0 else (0, 0, 0, 0)
                px[x, y] = ROBE if above[3] > 0 else (0, 0, 0, 0)
    return img


def top_row(frame):
    a = np.array(frame)[..., 3] > 0
    return int(np.argmax(a.any(axis=1)))


def walk_frame(base, phase):
    body = remove_boots(base)
    bob = BOB[phase] if top_row(body) >= 1 else 0              # never push the head out of the frame
    shifted = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); shifted.paste(body, (0, -bob), body)
    px = shifted.load()
    if bob:                                                       # the hem rises with the body: close the gap above the boots
        for x in range(16):
            if px[x, 14][3] == 0 and px[x, 13][3] > 0: px[x, 14] = ROBE
    for (x, y) in PHASES[phase]:
        px[x, y] = BOOT_PX
    return shifted


def build():
    pl = Image.open("assets/characters/hooded_warrior_spritesheet_128x144.png").convert("RGBA")
    rk = Image.open("assets/characters/player_rocket.png").convert("RGBA")
    out = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for i in range(4):
        gun_idle = pl.crop((i * 16, 96, i * 16 + 16, 112))
        rocket_idle = rk.crop((i * 16, 0, i * 16 + 16, 16))
        out.paste(walk_frame(gun_idle, i), (i * 16, 0))
        out.paste(walk_frame(rocket_idle, i), (i * 16, 16))
    out.save("assets/characters/player_walk_armed.png")

    # preview: idle row above the walk row, for both weapons
    S = 8
    prev = Image.new("RGBA", (4 * 16 * S + 24, 4 * 16 * S + 40), (70, 70, 80, 255))
    for r, (src_img, y0, walk_row) in enumerate([(pl, 96, 0), (rk, 0, 1)]):
        for i in range(4):
            idle = src_img.crop((i * 16, y0, i * 16 + 16, y0 + 16)).resize((16 * S, 16 * S), Image.NEAREST)
            walk = out.crop((i * 16, walk_row * 16, i * 16 + 16, walk_row * 16 + 16)).resize((16 * S, 16 * S), Image.NEAREST)
            prev.paste(idle, (8 + i * 16 * S, 8 + r * 2 * (16 * S + 8)), idle)
            prev.paste(walk, (8 + i * 16 * S, 8 + r * 2 * (16 * S + 8) + 16 * S + 4), walk)
    os.makedirs("tools/previews", exist_ok=True)
    prev.save("tools/previews/player_walk_armed.png")

build()
print("walk art generated")
