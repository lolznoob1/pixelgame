"""Finds buildings, containers, silos, tanks, fountains and trees on the city background.
Run from the project root:   python3 tools/detect_obstacles.py
Writes tools/obstacles.json (image pixel coordinates) and tools/previews/obstacles_overlay.png.
Then run tools/apply_obstacles.py to put the collision shapes into main.tscn.

How it works (the art is pixel art with a tiny fixed palette):
  - The map is a grid of blocks surrounded by a light gray sidewalk frame.
  - Buildings / containers / tanks are drawn with a 1 px dark navy outline: filling the closed outline loops
    gives their footprints (without shadows). Thin pipes are cut away with a morphological opening.
  - Silos are big discs in a light blue-gray palette, trees are discs in a saturated green palette
    (overlapping trees are split with a distance transform).
  - Residential lawn blocks are skipped for buildings: their houses are handled by the 'Houses' node.
"""
import json, math, os, sys
import numpy as np, cv2
from scipy import ndimage as ndi
from PIL import Image

SRC = "assets/world/tiles/city_background_3600x1600.png"
a = np.array(Image.open(SRC).convert("RGB")); H, W, _ = a.shape

def colors(*cs):
    m = np.zeros((H, W), bool)
    for c in cs: m |= np.all(a == np.array(c), axis=2)
    return m

# ---------------------------------------------------------------- blocks (sidewalk frames)
frame = colors((184, 184, 192))
fm = cv2.morphologyEx(frame.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((5, 5), np.uint8))
lab, n = ndi.label(fm)
blocks = []
for sl in ndi.find_objects(lab):
    h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
    if h >= 150 and w >= 200: blocks.append((sl[1].start, sl[0].start, sl[1].stop, sl[0].stop))
blocks.sort(key=lambda b: (round(b[1] / 200), b[0]))
print(len(blocks), "blocks", file=sys.stderr)

lawn_c = colors((88,148,84),(84,158,80),(82,142,80),(78,136,76),(100,160,92),(51,85,48),(52,88,50))
interior = lambda b: (b[0] + 8, b[1] + 8, b[2] - 8, b[3] - 8)
valid = np.zeros((H, W), bool); valid_all = np.zeros((H, W), bool)
res_blocks = []
for bi, b in enumerate(blocks):
    x0, y0, x1, y1 = interior(b)
    valid_all[y0:y1, x0:x1] = True
    if lawn_c[y0:y1, x0:x1].mean() > 0.35: res_blocks.append(bi)
    else: valid[y0:y1, x0:x1] = True

rects, circles = [], []

# ---------------------------------------------------------------- 1) outline loops -> buildings, containers, tanks
outline = colors((18, 22, 34))
closed = cv2.morphologyEx(outline.astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool)
filled = ndi.binary_fill_holes(closed) & valid
lab, n = ndi.label(filled)

def add_component(x, y, area, w, h):
    if max(w, h) <= 32 and abs(w - h) <= 3 and 0.65 <= area / float(w * h) <= 0.85:   # round, small: a tank
        circles.append([x + w / 2.0, y + h / 2.0, max(w, h) / 2.0, "tank"]); return
    rects.append([x, y, w, h, "building"])

PAD = 12
for i, sl in enumerate(ndi.find_objects(lab), start=1):
    comp = (lab[sl] == i); area = int(comp.sum())
    if area < 40: continue
    h, w = comp.shape; x, y = sl[1].start, sl[0].start
    if area / float(w * h) >= 0.88 or area < 400:
        add_component(x, y, area, w, h); continue
    # merged / L-shaped: cut thin pipes with an opening, take the parts
    padded = np.pad(comp.astype(np.uint8), PAD)
    opened = cv2.morphologyEx(padded, cv2.MORPH_OPEN, cv2.getStructuringElement(cv2.MORPH_RECT, (9, 9)))[PAD:-PAD, PAD:-PAD]
    l2, n2 = ndi.label(opened)
    for j, sl2 in enumerate(ndi.find_objects(l2), start=1):
        c2 = (l2[sl2] == j); a2 = int(c2.sum())
        if a2 < 40: continue
        h2, w2 = c2.shape
        add_component(x + sl2[1].start, y + sl2[0].start, a2, w2, h2)

# ---------------------------------------------------------------- 2) silos
SILO = [(176,182,194),(168,174,186),(196,202,212),(150,156,168),(146,152,164)]
silo = cv2.morphologyEx(colors(*SILO).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)).astype(bool) & valid
lab, n = ndi.label(silo)
for i, sl in enumerate(ndi.find_objects(lab), start=1):
    h = sl[0].stop - sl[0].start; w = sl[1].stop - sl[1].start
    area = int((lab[sl] == i).sum())
    if 14 <= w <= 64 and abs(w - h) <= 4 and 0.62 <= area / float(w * h) <= 0.9:
        circles.append([sl[1].start + w / 2.0, sl[0].start + h / 2.0, max(w, h) / 2.0 + 1.0, "silo"])

# ---------------------------------------------------------------- 3) trees
TREE = [(52,124,60),(60,150,90),(34,92,48),(22,60,34),(48,120,72),(46,110,56)]
tree_m = cv2.morphologyEx(colors(*TREE).astype(np.uint8), cv2.MORPH_CLOSE, np.ones((3, 3), np.uint8)) & valid_all.astype(np.uint8)
tree_m = ndi.binary_fill_holes(tree_m).astype(np.uint8)   # the bright highlight inside a canopy is not a tree color
dt = ndi.distance_transform_edt(tree_m)
lab, n = ndi.label(tree_m)
for i, sl in enumerate(ndi.find_objects(lab), start=1):
    comp = lab[sl] == i; area = int(comp.sum()); h, w = comp.shape
    if area < 30 or max(h, w) > 64: continue
    if area / float(h * w) < 0.5 or max(h, w) / max(1, min(h, w)) > 1.8: continue
    d = dt[sl] * comp
    mx = (d == ndi.maximum_filter(d, size=7)) & (d >= 3.0)
    picked = []
    for (py, px) in sorted(np.argwhere(mx).tolist(), key=lambda p: -d[p[0], p[1]]):
        r = d[py, px]
        if all(math.hypot(py - q[0], px - q[1]) > 0.8 * max(r, q[2]) for q in picked): picked.append((py, px, r))
    for py, px, r in picked:
        circles.append([sl[1].start + px + 0.5, sl[0].start + py + 0.5, float(r) + 1.0, "tree"])

# ---------------------------------------------------------------- 4) hand-measured extras (not outlined / outside the blocks)
for x, y, w, h in [(1534, 1437, 120, 25), (1684, 1437, 120, 25), (1858, 1437, 96, 25), (1984, 1437, 120, 25)]:
    rects.append([x, y, w, h, "building"])                      # the four railway platform canopies
circles.append([1924.0, 696.0, 19.5, "fountain"])               # park fountain
circles.append([1840.0, 1264.0, 16.5, "fountain"])              # station plaza fountain

# ---------------------------------------------------------------- 5) remove duplicates (shapes inside bigger shapes)
def inside_rect(cx, cy, r):
    return any(x - 1 <= cx - r and cx + r <= x + w + 1 and y - 1 <= cy - r and cy + r <= y + h + 1 for x, y, w, h, _ in rects)
circles = [c for c in circles if not (c[3] in ("tank", "tree") and inside_rect(c[0], c[1], c[2]))]
def rect_inside_silo(x, y, w, h):
    return any(math.hypot(x - c[0], y - c[1]) <= c[2] and math.hypot(x + w - c[0], y + h - c[1]) <= c[2] for c in circles if c[3] == "silo")
rects = [r for r in rects if not rect_inside_silo(*r[:4])]

counts = {k: sum(1 for c in circles if c[3] == k) for k in ("tree", "silo", "tank", "fountain")}
print(len(rects), "rects,", len(circles), "circles", counts, file=sys.stderr)
json.dump({"rects": rects, "circles": circles, "blocks": blocks, "res_blocks": res_blocks}, open("tools/obstacles.json", "w"))

os.makedirs("tools/previews", exist_ok=True)
ov = a.copy()
for x, y, w, h, k in rects: cv2.rectangle(ov, (x, y), (x + w, y + h), (255, 0, 255), 2)
for cx, cy, r, k in circles:
    cv2.circle(ov, (int(round(cx)), int(round(cy))), int(round(r)), {"tree": (0, 255, 255), "silo": (255, 255, 0), "tank": (255, 128, 0), "fountain": (80, 160, 255)}[k], 2)
Image.fromarray(ov).resize((1800, 800), Image.LANCZOS).save("tools/previews/obstacles_overlay.png")
