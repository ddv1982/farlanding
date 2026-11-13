"""Emberfall — Caldera: black basalt cut by rivers of lava, around a low caldera.

A 240 m map of cracked basalt plains about half a metre up. Two lava rivers run out of
the central caldera to the map's edge and are never crossable except by three rock
bridges. The caldera is a walkable plateau reached by three ramps; the richest Flux
vents sit on it, and they erupt. Both bases sit on ash shelves away from the lava. A
jagged rim closes the map.

LAVA_LEVEL = -0.9 m (the lava sheet); the river beds are at -2.0 m.
Heights come from `height(x, y)` (Blender x, y; Godot x, -z).
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

import fl

SIZE = 240.0
STEP = 1.5
WALL = 11.0
LAVA_LEVEL = -0.9
PLAINS = 0.6
BED = -2.0

# Lava rivers: centre lines (Blender x, y) from the caldera's foot to the rim.
RIVERS = [
    [(-16.0, 14.0), (-44.0, 34.0), (-70.0, 30.0), (-96.0, 52.0), (-120.0, 56.0)],
    [(18.0, -12.0), (46.0, -26.0), (60.0, -54.0), (92.0, -62.0), (120.0, -84.0)],
    [(14.0, 18.0), (34.0, 44.0), (30.0, 76.0), (48.0, 120.0)],
]
RIVER_HALF_WIDTH = 6.5
# Rock bridges: centre x, y, half length along the river.
BRIDGES = [(-58.0, 31.0, 8.0), (52.0, -40.0, 8.0), (32.0, 60.0, 8.0)]
# The caldera: a walkable plateau (centre x, y, radius x, y, height) and its ramps
# (start outside, end on top, half width).
CALDERA = (0.0, 0.0, 24.0, 20.0, 3.4)
# Each ramp tops out at the plateau's edge, not inside it: ending further in left
# a lip the edge of the plateau stood above.
RAMPS = [((-34.0, -14.0), (-22.0, -8.5), 10.0), ((6.0, -34.0), (3.5, -21.0), 10.0),
         ((42.0, -3.0), (27.0, 0.0), 10.0)]
# Ash shelves, a little higher: centre x, y, radius x, y, height. The first two are
# the bases (Concord south-west, Combine north-east).
SHELVES = [(-80.0, -85.0, 26.0, 20.0, 1.6), (80.0, 80.0, 26.0, 20.0, 1.6),
           (-84.0, -4.0, 14.0, 16.0, 1.3), (84.0, -6.0, 13.0, 15.0, 1.3),
           (-20.0, -78.0, 15.0, 11.0, 1.3), (-36.0, 84.0, 16.0, 11.0, 1.3)]
# Spires, impassable: centre x, y, radius x, y, height.
SPIRES = [(-50.0, -36.0, 7.0, 6.0, 9.0), (44.0, 16.0, 6.0, 7.0, 10.0), (-8.0, 46.0, 6.0, 5.0, 8.0),
          (70.0, 34.0, 6.0, 6.0, 8.5), (-74.0, 62.0, 6.0, 7.0, 9.5), (24.0, -70.0, 7.0, 5.0, 8.0),
          (96.0, -20.0, 5.0, 6.0, 7.5)]


def _smooth(edge0: float, edge1: float, x: float) -> float:
    t = min(max((x - edge0) / (edge1 - edge0), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def _fbm(x: float, y: float, scale: float, octaves: int = 4) -> float:
    return noise.fractal(Vector((x / scale, y / scale, 0.0)), 1.0, 2.0, octaves)


def _blob(x: float, y: float, cx: float, cy: float, rx: float, ry: float, edge: float) -> float:
    wobble = 1.0 + 0.2 * _fbm(x + cx * 3.1, y - cy * 1.7, 9.0, 3)
    d = math.hypot((x - cx) / (rx * wobble), (y - cy) / (ry * wobble))
    return _smooth(-edge, 0.0, (1.0 - d) * min(rx, ry))


def _river_distance(x: float, y: float) -> float:
    best = 1e9
    for line in RIVERS:
        for (ax, ay), (bx, by) in zip(line, line[1:]):
            dx, dy = bx - ax, by - ay
            t = min(max(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy), 0.0), 1.0)
            best = min(best, math.hypot(x - ax - t * dx, y - ay - t * dy))
    return best


def height(x: float, y: float) -> float:
    # Basalt plains: broad swells with sharp little steps (cooled flows).
    swell = 0.2 * _fbm(x, y, 44.0)
    steps = 0.12 * math.floor(3.0 * (0.5 + 0.5 * _fbm(x, y, 16.0, 2))) / 3.0
    h = PLAINS + swell + steps
    for cx, cy, rx, ry, top in SHELVES:
        mask = _blob(x, y, cx, cy, rx, ry, 8.0)
        h = max(h, h + mask * (top - h))
    # Lava rivers with steep banks; bridges are slabs left standing across them.
    width = RIVER_HALF_WIDTH * (1.0 + 0.2 * _fbm(x, y, 20.0, 2))
    river = _smooth(width + 2.5, width - 1.0, _river_distance(x, y))
    for cx, cy, half in BRIDGES:
        river *= 1.0 - _smooth(half + 3.0, half - 1.0, math.hypot(x - cx, y - cy))
    h = h + river * (BED - h)
    cx, cy, rx, ry, top = CALDERA
    plateau = _blob(x, y, cx, cy, rx, ry, 2.5)
    for (ax, ay), (bx, by), half_width in RAMPS:
        dx, dy = bx - ax, by - ay
        length = math.hypot(dx, dy)
        t = ((x - ax) * dx + (y - ay) * dy) / (length * length)
        side = abs((x - ax) * dy - (y - ay) * dx) / length
        ramp = min(max(t, 0.0), 1.0) * _smooth(half_width, half_width - 3.0, side)
        if -0.05 <= t <= 1.3:
            plateau = max(plateau, ramp)
    h = max(h, h + plateau * (top - h))
    for sx, sy, rx, ry, top in SPIRES:
        h += _blob(x, y, sx, sy, rx, ry, 2.0) * (top + 0.9 * _fbm(x, y, 5.0, 2))
    edge = SIZE / 2.0 - max(abs(x), abs(y))
    rim = _smooth(15.0 + 5.0 * _fbm(x, y, 18.0, 2), 4.0, edge)
    return h + rim * (WALL - h + 1.8 * _fbm(x, y, 8.0, 2))


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
    mesh = bpy.data.meshes.new("emberfall_caldera_ground")
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = True
    mesh.materials.append(bpy.data.materials.get("fl_terrain_emberfall")
                          or bpy.data.materials.new("fl_terrain_emberfall"))
    # "-col" makes Godot generate a static trimesh collider on import.
    obj = bpy.data.objects.new("emberfall_caldera_ground-col", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def build_rocks(seed: int = 37, attempts: int = 2600):
    """Decorative clinker at the spires' feet and along the lava banks, cinders on the plains."""
    rng = random.Random(seed)
    bm = bmesh.new()
    uv_layer = bm.loops.layers.uv.new("palette")
    half = SIZE / 2.0 - 6.0
    for _ in range(attempts):
        x, y = rng.uniform(-half, half), rng.uniform(-half, half)
        z = height(x, y)
        slope = math.hypot(height(x + 1.0, y) - z, height(x, y + 1.0) - z)
        if 0.14 < slope < 0.9:
            radius = rng.uniform(0.3, 1.0)
        elif slope <= 0.14 and z > 0.2 and rng.random() < 0.09:
            radius = rng.uniform(0.1, 0.28)
        else:
            continue
        verts = bmesh.ops.create_icosphere(bm, subdivisions=1, radius=radius)["verts"]
        squash = Vector((rng.uniform(0.7, 1.3), rng.uniform(0.7, 1.3), rng.uniform(0.4, 0.75)))
        spin = Matrix.Rotation(rng.uniform(0.0, math.tau), 4, "Z")
        for v in verts:
            v.co = Vector((v.co.x * squash.x, v.co.y * squash.y, v.co.z * squash.z))
            v.co += Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(-1, 1))) * radius * 0.16
            v.co = spin @ v.co + Vector((x, y, z + radius * 0.15))
        u, v_coord = fl.swatch_uv("black" if rng.random() < 0.6 else "graphite")
        for face in {f for v in verts for f in v.link_faces}:
            for loop in face.loops:
                loop[uv_layer].uv = (u, v_coord)
    mesh = bpy.data.meshes.new("emberfall_rocks")
    bm.to_mesh(mesh)
    bm.free()
    mesh.materials.append(bpy.data.materials.get(fl.ATLAS_MATERIAL)
                          or bpy.data.materials.new(fl.ATLAS_MATERIAL))
    obj = bpy.data.objects.new("emberfall_rocks", mesh)
    bpy.context.scene.collection.objects.link(obj)
    return obj


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
