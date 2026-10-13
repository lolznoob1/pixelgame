"""Writes the obstacles from tools/obstacles.json into main.tscn as collision shapes.
Run from the project root after tools/detect_obstacles.py:   python3 tools/apply_obstacles.py
It can be run again: the nodes it created (Buildings, Containers, Silos, Trees) are replaced.

Image pixel -> world: x = px - 443, y = py - 412  (the Background sprite is centered at (1357, 388)).
Trees: the collision circle is 80 % of the canopy so you can brush past the leaves.
"""
import json, re

OX, OY = 443, 412
TREE_FACTOR = 0.8
GROUPS = ["Buildings", "Containers", "Silos", "Trees"]

d = json.load(open("tools/obstacles.json"))
t = open("main.tscn", encoding="utf-8").read()

# ---- remove what an earlier run created ----
blocks = re.split(r"(?=^\[)", t, flags=re.M)
keep = []
for blk in blocks:
    m = re.match(r'\[node name="([^"]+)" type="[^"]+" parent="([^"]+)"', blk)
    if m and (m.group(1) in GROUPS or m.group(2) in GROUPS):
        continue
    m2 = re.match(r'\[sub_resource type="\w+" id="((?:Rect|Circle)ob_[^"]+)"\]', blk)
    if m2:
        continue
    keep.append(blk)
t = "".join(keep)

# ---- classify ----
containers, buildings = [], []
for x, y, w, h, kind in d["rects"]:
    (containers if (w == 310 and h == 22) else buildings).append((x, y, w, h))
silos = [(cx, cy, r) for cx, cy, r, k in d["circles"] if k in ("silo", "tank", "fountain")]
trees = [(cx, cy, max(3.0, round(r * TREE_FACTOR * 2) / 2.0)) for cx, cy, r, k in d["circles"] if k == "tree" and r >= 3.5]

sub = {}
def rect_id(w, h):
    i = f"Rectob_{w}x{h}"; sub[i] = f'[sub_resource type="RectangleShape2D" id="{i}"]\nsize = Vector2({w}, {h})\n\n'; return i
def circle_id(r):
    i = f"Circleob_{int(round(r * 10))}"; sub[i] = f'[sub_resource type="CircleShape2D" id="{i}"]\nradius = {r:g}\n\n'; return i

def fmt(v): return f"{v:g}"
nodes = ""
def group(name, prefix, entries, kind):
    global nodes
    nodes += f'[node name="{name}" type="StaticBody2D" parent="."]\nscript = ExtResource("6_houses")\n\n'
    for n, e in enumerate(entries, start=1):
        if kind == "rect":
            x, y, w, h = e; pos = (x + w / 2.0 - OX, y + h / 2.0 - OY); sid = rect_id(w, h)
        else:
            cx, cy, r = e; pos = (cx - OX, cy - OY); sid = circle_id(r)
        nodes += (f'[node name="{prefix}{n:03d}" type="CollisionShape2D" parent="{name}"]\n'
                  f'position = Vector2({fmt(pos[0])}, {fmt(pos[1])})\nshape = SubResource("{sid}")\n\n')

group("Buildings", "Building", buildings, "rect")
group("Containers", "Container", containers, "rect")
group("Silos", "Silo", silos, "circle")
group("Trees", "Tree", trees, "circle")

anchor = '[node name="main" type="Node2D"'
assert t.count(anchor) == 1
t = t.replace(anchor, "".join(sub.values()) + anchor)
marker = '[connection signal="pressed"'
assert t.count(marker) == 1
t = t.replace(marker, nodes + marker)
open("main.tscn", "w", encoding="utf-8").write(t)
print(f"{len(buildings)} buildings, {len(containers)} container rows, {len(silos)} silos/tanks/fountains, {len(trees)} trees; "
      f"{len(sub)} shared shape resources")
