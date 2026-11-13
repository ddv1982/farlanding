"""Hollow Meridian — The Deck: the plated floor of an Antecedent megastructure.

A 240 m map of flat stone decks on three levels, cut by two straight chasms with no
bottom. Each chasm is crossed by two bridges. A square dais stands at the centre,
reached by four ramps: the Beacon Core sits on it. Two terraces overlook the long
approaches. Rows of pylons (impassable, their own collider mesh) break up the decks.
Both bases sit on the lowest deck in opposite corners. Sheer walls close the map.

The layout is point-symmetric about the centre. Everything is axis-aligned on purpose:
it was built, not grown.
Heights come from `height(x, y)` (Blender x, y; Godot x, -z).
"""

import math
import os

import bmesh
import bpy

import fl

SIZE = 240.0
STEP = 1.0
WALL = 12.0
DECK = 0.5
VOID = -14.0

# Chasms: centre x, y, half size x, y. Bridges are decks left standing across them.
CHASMS = [(-40.0, 38.0, 80.0, 6.0), (40.0, -38.0, 80.0, 6.0)]
BRIDGES = [(-70.0, 38.0, 6.0, 8.0), (-12.0, 38.0, 6.0, 8.0),
           (70.0, -38.0, 6.0, 8.0), (12.0, -38.0, 6.0, 8.0)]
# The dais: centre x, y, half size, height; ramps run out from the middle of each side.
DAIS = (0.0, 0.0, 17.0, 3.0)
RAMP_LENGTH = 12.0
RAMP_HALF_WIDTH = 5.0
# Terraces: centre x, y, half size x, y, height, and the ramp's side (dx, dy).
TERRACES = [(-84.0, 76.0, 20.0, 16.0, 2.0, (0.0, -1.0)), (84.0, -76.0, 20.0, 16.0, 2.0, (0.0, 1.0))]
# Pylons: centre x, y (5 m square, 9 m tall).
_HALF_PYLONS = [(-40.0, -8.0), (-40.0, 10.0), (-64.0, -40.0), (-22.0, -62.0), (-22.0, -92.0),
                (-100.0, 14.0), (-100.0, -20.0), (-52.0, 70.0), (-16.0, 82.0), (26.0, 60.0),
                (56.0, 92.0)]
PYLONS = _HALF_PYLONS + [(-x, -y) for x, y in _HALF_PYLONS]
PYLON_HALF = 2.5
PYLON_HEIGHT = 9.0
# Antecedent engines (the map's power): suggested spots, x, y.
_HALF_ENGINES = [(-52.0, -70.0), (-96.0, -48.0), (-30.0, 20.0), (-84.0, 76.0)]
ENGINES = _HALF_ENGINES + [(-x, -y) for x, y in _HALF_ENGINES]


def _smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _rect(x: float, y: float, cx: float, cy: float, hx: float, hy: float, edge: float) -> float:
    """1 inside the rectangle, falling to 0 over `edge` metres outside it."""
    outside = max(abs(x - cx) - hx, abs(y - cy) - hy)
    return _smooth(edge, 0.0, outside)


def _ramp(x: float, y: float, ax: float, ay: float, dx: float, dy: float,
          length: float, half_width: float) -> float:
    """0 at (ax, ay) rising to 1 `length` metres along (dx, dy), `half_width` each side."""
    along = (x - ax) * dx + (y - ay) * dy
    side = abs((x - ax) * dy - (y - ay) * dx)
    if along < 0.0 or along > length + 1.0:
        return 0.0
    return min(along / length, 1.0) * _smooth(half_width + 0.8, half_width, side)


def height(x: float, y: float) -> float:
    h = DECK
    cx, cy, half, top = DAIS
    lift = _rect(x, y, cx, cy, half, half, 0.8)
    for dx, dy in ((1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)):
        reach = half + RAMP_LENGTH
        lift = max(lift, _ramp(x, y, cx + dx * reach, cy + dy * reach, -dx, -dy,
                               RAMP_LENGTH, RAMP_HALF_WIDTH))
    h += lift * (top - DECK)
    for tx, ty, hx, hy, t_top, (dx, dy) in TERRACES:
        lift = _rect(x, y, tx, ty, hx, hy, 0.8)
        reach_x, reach_y = dx * (hx + 9.0), dy * (hy + 9.0)
        lift = max(lift, _ramp(x, y, tx + reach_x, ty + reach_y, -dx, -dy, 9.0, 6.0))
        h += lift * (t_top - DECK)
    for cx, cy, hx, hy in CHASMS:
        cut = _rect(x, y, cx, cy, hx, hy, 0.9)
        for bx, by, bhx, bhy in BRIDGES:
            cut *= 1.0 - _rect(x, y, bx, by, bhx, bhy, 0.6)
        h += cut * (VOID - h)
    edge = SIZE / 2.0 - max(abs(x), abs(y))
    return h + _smooth(7.0, 5.0, edge) * (WALL - h)


def _atlas_material():
    return (bpy.data.materials.get(fl.ATLAS_MATERIAL)
            or bpy.data.materials.new(fl.ATLAS_MATERIAL))


def _link(name: str, bm, material, smooth: bool):
    mesh = bpy.data.meshes.new(name.replace("-col", ""))
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build():
    fl.reset_scene()
    count = int(SIZE / STEP) + 1
    bm = bmesh.new()
    rows = []
    for j in range(count):
        y = -SIZE / 2.0 + j * STEP
        rows.append([bm.verts.new((-SIZE / 2.0 + i * STEP, y, height(-SIZE / 2.0 + i * STEP, y)))
                     for i in range(count)])
    for j in range(count - 1):
        for i in range(count - 1):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    material = (bpy.data.materials.get("fl_terrain_hollow")
                or bpy.data.materials.new("fl_terrain_hollow"))
    # "-col" makes Godot generate a static trimesh collider on import.
    return _link("hollow_meridian_ground-col", bm, material, smooth=False)


def _box(bm, uv_layer, centre, size, swatch: str) -> None:
    made = bmesh.ops.create_cube(bm, size=1.0)["verts"]
    for v in made:
        v.co.x = v.co.x * size[0] + centre[0]
        v.co.y = v.co.y * size[1] + centre[1]
        v.co.z = v.co.z * size[2] + centre[2]
    u, v_coord = fl.swatch_uv(swatch)
    for face in {f for v in made for f in v.link_faces}:
        for loop in face.loops:
            loop[uv_layer].uv = (u, v_coord)


def build_pylons():
    """Square stone pylons with brass bands and one lit seam each. Colliders."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("palette")
    side = PYLON_HALF * 2.0
    for px, py in PYLONS:
        base = height(px, py)
        _box(bm, uv_layer, (px, py, base + PYLON_HEIGHT / 2.0), (side, side, PYLON_HEIGHT), "stone")
        _box(bm, uv_layer, (px, py, base + 0.4), (side + 0.8, side + 0.8, 0.8), "stone_dark")
        _box(bm, uv_layer, (px, py, base + PYLON_HEIGHT - 1.2), (side + 0.3, side + 0.3, 0.5), "brass")
        _box(bm, uv_layer, (px, py, base + PYLON_HEIGHT + 0.3), (side - 1.2, side - 1.2, 0.6), "stone_dark")
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            _box(bm, uv_layer, (px + dx * PYLON_HALF, py + dy * PYLON_HALF, base + 4.2),
                 (0.16 if dx else 0.5, 0.16 if dy else 0.5, 5.0), "glow_white")
    return _link("hollow_pylons-col", bm, _atlas_material(), smooth=False)


def build_trim():
    """Brass kerbs along the chasm edges and round the dais; lit strips on the bridges."""
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("palette")
    for cx, cy, hx, hy in CHASMS:
        for side in (-1.0, 1.0):
            _box(bm, uv_layer, (cx, cy + side * (hy + 1.2), DECK + 0.12), (hx * 2.0, 0.5, 0.3), "brass")
    for bx, by, bhx, bhy in BRIDGES:
        for side in (-1.0, 1.0):
            _box(bm, uv_layer, (bx + side * (bhx - 0.4), by, DECK + 0.1), (0.3, bhy * 2.0, 0.24),
                 "glow_white")
    cx, cy, half, top = DAIS
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        for end in (-1.0, 1.0):
            length = half - RAMP_HALF_WIDTH - 1.0
            offset = end * (RAMP_HALF_WIDTH + 1.0 + length / 2.0)
            _box(bm, uv_layer,
                 (cx + dx * (half - 0.4) + dy * offset, cy + dy * (half - 0.4) + dx * offset,
                  top + 0.15),
                 (0.5 if dx else length, 0.5 if dy else length, 0.34), "brass")
    return _link("hollow_trim", bm, _atlas_material(), smooth=False)


def export(obj, extra=()) -> str:
    out_dir = os.path.join(fl.ASSETS, "models", "terrain")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, obj.data.name + ".glb")
    for other in bpy.context.scene.objects:
        other.select_set(other is obj or other in extra)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True,
                              export_yup=True, export_materials="EXPORT",
                              export_animations=False)
    return path
