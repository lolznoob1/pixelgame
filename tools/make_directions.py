"""Generates 8-direction sprite sheets (turn-around views) from the front-facing character sheets.

Run from the project root:   python3 tools/make_directions.py
Output: assets/characters/dirs/<name>_dirs.png  (+ previews in tools/previews)

Sheet layout: one block per animation (idle, walk, [sprint]) stacked vertically,
each block = 8 rows (directions, order below) x N columns (frames), 16x16 px cells.
"""
import math, os
from PIL import Image

DIRS = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
# view parameters: (front_visible, side, head_scale, body_scale, pony_side)
VIEWS = {
    "s":  dict(front=True,  side=0,  hs=1.00, bs=1.00, pony=+1),
    "se": dict(front=True,  side=+1, hs=0.88, bs=0.90, pony=0),
    "e":  dict(front=True,  side=+1, hs=0.70, bs=0.72, pony=-1, profile=True),
    "ne": dict(front=False, side=+1, hs=0.88, bs=0.90, pony=-1),
    "n":  dict(front=False, side=0,  hs=1.00, bs=1.00, pony=-1),
    "nw": dict(front=False, side=-1, hs=0.88, bs=0.90, pony=0),
    "w":  dict(front=True,  side=-1, hs=0.70, bs=0.72, pony=+1, profile=True),
    "sw": dict(front=True,  side=-1, hs=0.88, bs=0.90, pony=+1),
}
HEAD_ROWS = range(0, 9)    # rows 0..8
BODY_ROWS = range(9, 16)   # rows 9..15
OUTLINE_ROWS_TOP = 1

def rgb(c): return (c[0], c[1], c[2], 255)

CHARS = {
  "enemy1": dict(src="assets/characters/habbo_spritesheet_64x80.png",
      anims={"idle": ((0, 0), 4), "walk": ((0, 16), 4)},
      hair=[(248,217,102),(214,168,54)], face=[(245,201,160),(30,30,30),(217,165,119)],
      skin=(245,201,160), eye=(30,30,30), mouth=(217,165,119), face_rows=[5,6,7], pony=False,
      body_swap={(42,90,160):(58,123,213)}),
  "enemy2": dict(src="assets/characters/habbo_characters_spritesheet_320x160.png",
      anims={"idle": ((0, 112), 3), "walk": ((64, 112), 4)},
      hair=[(240,125,185),(200,82,142)], face=[(255,224,196),(40,140,80),(214,96,120)],
      skin=(255,224,196), eye=(40,140,80), mouth=(214,96,120), face_rows=[5,6,7], pony=True,
      body_swap={(160,40,44):(214,60,60)}),
  "enemy3": dict(src="assets/characters/habbo_characters_spritesheet_320x160.png",
      anims={"idle": ((0, 48), 4), "walk": ((64, 48), 4)},
      hair=[(214,168,54)], face=[(110,72,50),(40,140,80),(85,52,36)],
      skin=(110,72,50), eye=(40,140,80), mouth=(85,52,36), face_rows=[4,5,6,7], pony=False,
      body_swap={}),
  "player": dict(src="assets/characters/hooded_warrior_spritesheet_128x144.png",
      anims={"idle": ((0, 0), 4), "walk": ((0, 16), 4), "sprint": ((0, 32), 4)},
      hair=[(30,30,40),(64,64,84)], face=[(12,12,18),(84,84,100)],
      skin=(84,84,100), eye=(12,12,18), mouth=(84,84,100), face_rows=[5,6,7], pony=False,
      body_swap={(244,204,64):(30,30,40)}),
}

def frame_of(sheet, pos, i):
    x, y = pos
    return sheet.crop((x + i * 16, y, x + i * 16 + 16, y + 16)).convert("RGBA")

def squeeze_cols(img, rows, scale):
    """Horizontally rescales the given rows around the centre using nearest sampling."""
    if scale >= 0.999:
        return img.copy()
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    new_w = max(2, round(16 * scale))
    left = (16 - new_w) // 2
    src, dst = img.load(), out.load()
    for y in rows:
        for tx in range(new_w):
            sx = min(15, int((tx + 0.5) / new_w * 16))
            dst[left + tx, y] = src[sx, y]
    return out

def silhouette(img, y):
    px = img.load()
    xs = [x for x in range(16) if px[x, y][3] > 0]
    return (min(xs), max(xs)) if xs else (8, 8)

def make_view(spec, frame, view_name):
    v = VIEWS[view_name]
    px = frame.load()
    hair = [rgb(c) for c in spec["hair"]]; face = [rgb(c) for c in spec["face"]]
    skin, eye, mouth = rgb(spec["skin"]), rgb(spec["eye"]), rgb(spec["mouth"])
    hair_main = hair[0]
    face_rows = spec["face_rows"]

    # ---- split into layers ----
    head = Image.new("RGBA", (16, 16), (0, 0, 0, 0)); body = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pony_px = []
    hp, bp = head.load(), body.load()
    for y in range(16):
        for x in range(16):
            c = px[x, y]
            if c[3] == 0: continue
            if y in HEAD_ROWS:
                if spec["pony"] and x >= 13:
                    pony_px.append((x - 13, y, c)); continue
                hp[x, y] = c
            else:
                bp[x, y] = c

    # ---- back of the head / body details ----
    back = not v["front"]
    if back:
        for y in face_rows:
            for x in range(16):
                if hp[x, y] in face:
                    hp[x, y] = hair_main
        for x in range(16):                       # remove chin/neck details of the face too
            if hp[x, 8][3] > 0 and hp[x, 8] in face: hp[x, 8] = hair_main
        for y in BODY_ROWS:
            for x in range(16):
                c = bp[x, y]
                if c[3] > 0 and c[:3] in spec["body_swap"]:
                    bp[x, y] = rgb(spec["body_swap"][c[:3]])
                if c[3] > 0 and rgb(c[:3]) == rgb(spec.get("emblem", (-1,-1,-1))): pass
        if spec is CHARS["player"]:
            for y in BODY_ROWS:
                for x in range(16):
                    if bp[x, y][:3] == (244, 204, 64): bp[x, y] = rgb((30, 30, 40))
        # enemies: hands/arms keep their colour, shirt collar detail removed above

    # ---- scale head and body separately ----
    head_s = squeeze_cols(head, HEAD_ROWS, v["hs"])
    body_s = squeeze_cols(body, BODY_ROWS, v["bs"])
    hs = head_s.load()

    # ---- facing details on the head ----
    side = v["side"]
    if v.get("profile"):
        # profile: skin only on the front half, hair at the back, a single eye and the mouth
        for y in face_rows:
            x0, x1 = silhouette(head_s, y)
            if x1 - x0 < 3: continue
            inner = range(x0 + 1, x1)                         # without outline
            front_x = (x1 - 1) if side > 0 else (x0 + 1)
            back_x  = (x0 + 1) if side > 0 else (x1 - 1)
            mid = (x0 + x1) / 2.0
            for x in inner:
                is_front = (x >= mid) if side > 0 else (x <= mid)
                hs[x, y] = skin if is_front else hair_main
            if y == face_rows[len(face_rows) // 2]:          # eye row
                hs[front_x - side, y] = eye
            if y == face_rows[-1]:
                hs[front_x, y] = mouth
    elif v["front"] and side != 0:
        # three-quarter front: shift the features toward the facing side, one column of hair on the far side
        for y in face_rows:
            x0, x1 = silhouette(head_s, y)
            row = {x: hs[x, y] for x in range(x0 + 1, x1)}
            for x, c in row.items():
                if c in (eye, mouth) and eye != skin:
                    nx = x + side
                    if x0 < nx < x1:
                        hs[x, y] = skin
                        hs[nx, y] = c
            far = (x0 + 1) if side > 0 else (x1 - 1)
            hs[far, y] = hair_main
    elif back and side != 0:
        # three-quarter back: a sliver of cheek on the facing side
        y = face_rows[len(face_rows) // 2]
        x0, x1 = silhouette(head_s, y)
        near = (x1 - 1) if side > 0 else (x0 + 1)
        hs[near, y] = skin
        hs[near, face_rows[-1]] = skin

    # ---- ponytail ----
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    out.alpha_composite(body_s); out.alpha_composite(head_s)
    if pony_px and v["pony"] != 0:
        y_ref = 5
        x0, x1 = silhouette(head_s, y_ref)
        op = out.load()
        for dx, y, c in pony_px:
            X = (x1 + 1 + dx) if v["pony"] > 0 else (x0 - 1 - dx)
            if 0 <= X < 16: op[X, y] = c
    return out

def build_sheet(name, spec):
    sheet = Image.open(spec["src"]).convert("RGBA")
    order = list(spec["anims"].items())
    max_frames = max(n for _, (_, n) in order)
    out = Image.new("RGBA", (max_frames * 16, len(order) * 8 * 16), (0, 0, 0, 0))
    for block, (anim, (pos, n)) in enumerate(order):
        for di, d in enumerate(DIRS):
            for f in range(n):
                src = frame_of(sheet, pos, f)
                if anim == "sprint" and d in ("e", "w"):
                    img = src if d == "e" else src.transpose(Image.FLIP_LEFT_RIGHT)   # original side-run frames
                elif anim == "sprint":
                    wpos, wn = spec["anims"]["walk"]
                    img = make_view(spec, frame_of(sheet, wpos, f % wn), d)           # walk frames, faster in game
                else:
                    img = make_view(spec, src, d)
                out.paste(img, (f * 16, (block * 8 + di) * 16))
    return out, order

if __name__ == "__main__":
    os.makedirs("assets/characters/dirs", exist_ok=True)
    for name, spec in CHARS.items():
        sheet, order = build_sheet(name, spec)
        sheet.save(f"assets/characters/dirs/{name}_dirs.png")
        print(name, sheet.size, [(a, n) for a, (_, n) in order])
        # preview: first frame of every direction for idle + walk, enlarged
        S = 6
        prev = Image.new("RGBA", (8 * 16 * S + 90, 3 * 16 * S + 12), (70, 70, 80, 255))
        for blk in range(min(3, len(order))):
            for di in range(8):
                cell = sheet.crop((0, (blk * 8 + di) * 16, 16, (blk * 8 + di) * 16 + 16)).resize((16 * S, 16 * S), Image.NEAREST)
                prev.paste(cell, (8 + di * 16 * S + 0, 6 + blk * 16 * S), cell)
        os.makedirs("tools/previews", exist_ok=True)
        prev.save(f"tools/previews/{name}_preview.png")
